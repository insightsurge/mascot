"""Reference accounting for the current R1a corpus, not a renderer/validator.

Default/--check recomputes budgets.json and fails on drift. --write deliberately
updates that documentation artefact. No R, browser, network or package imports.
"""
from pathlib import Path
import copy
import json
import math
import re
import sys

ROOT = Path(__file__).resolve().parent


def require(value, message):
    if not value:
        raise ValueError(message)


def unique(pairs):
    value = {}
    for key, item in pairs:
        require(key not in value, "duplicate JSON key: " + key)
        value[key] = item
    return value


def load(path):
    value=json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique)
    pending=[value]
    while pending:
        current=pending.pop()
        if isinstance(current,float):require(math.isfinite(current), "non-finite number in accounting input")
        elif isinstance(current,dict):pending.extend(current.values())
        elif isinstance(current,list):pending.extend(current)
    return value


def blank():
    return dict.fromkeys(("active_parts", "painted_items", "paint_passes", "path_numbers", "clip_applications", "gradient_uses", "glow_emitters", "blur_design_units", "inflated_glow_area_ratio"), 0)


def combine(*costs):
    result = blank()
    for cost in costs:
        for key in result:
            if key == "blur_design_units":
                result[key] = max(result[key], cost[key])
            else:
                result[key] += cost[key]
    return result


def path_values(text):
    pattern = r"[MLQCZ]|[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?"
    require(not re.sub(pattern, "", text).replace(",", "").strip(), "unsupported path token")
    tokens = re.findall(pattern, text)
    require(tokens and tokens[0] == "M", "path must start with M")
    values = [float(token) for token in tokens if token not in {"M", "L", "Q", "C", "Z"}]
    require(all(math.isfinite(x) for x in values), "non-finite path number")
    # Each command may have repeated complete operand groups.
    i = 0
    while i < len(tokens):
        command = tokens[i]
        require(command in {"M", "L", "Q", "C", "Z"}, "missing path command")
        i += 1
        start = i
        while i < len(tokens) and tokens[i] not in {"M", "L", "Q", "C", "Z"}:
            i += 1
        arity = {"M": 2, "L": 2, "Q": 4, "C": 6, "Z": 0}[command]
        require((i == start if arity == 0 else i > start and (i - start) % arity == 0), "incomplete path operands")
    return values


class Counter:
    def __init__(self, character, band, operations, external_scale=1):
        require(operations['operation_manifest_version'] == 2, 'unsupported accounting version')
        self.character, self.band, self.operations = character, band, operations
        self.numbers = operations["primitive_numbers"]
        self.outline = copy.deepcopy(character.get("outline", {}))
        self.outline.update(self.outline.get("lod", {}).get(band, {}))
        self.outline.update(character.get("lod", {}).get(band, {}).get("outline", {}))
        self.lod = character.get("lod", {}).get(band, {})
        self.external_scale = external_scale
        self.glow_on = self.lod.get("glow", band != "micro")
        require(not character.get("face", {}).get("styles") if character.get("face") else True, "reference profile does not yet expand replacement face styles")
        require(not character.get("face", {}).get("tune") if character.get("face") else True, "reference profile does not yet expand face tuning")
        require(not any(m.get("items") or m.get("reduced") for m in character["moods"].values()), "reference profile needs explicit mood item/reduced expansion")
        require(not character.get("shapes") or all(v["shape"] != "ref" for v in character["shapes"].values()), "ref chains are not allowed")
        for gesture in character.get("gestures", {}).values():
            require(not gesture.get("effects"), "reference profile does not yet expand gesture effect triggers")
            for channel in gesture["tracks"]:
                require(channel.endswith((".rotate", ".scale_x", ".scale_y", ".x", ".y", ".lift")), "reference profile needs additional track reachability rules: " + channel)
        require(character.get('face') is not None or not character.get('effects'), 'faceless characters cannot map kit effects')
        if character.get('face'):
            for effect in character['face']['kit_definition'].get('effects', {}).values():
                for item in effect.get('items', []) + effect.get('reduced_items', []):
                    require('clip' not in item, 'kit effect items cannot contain character-specific clips')
        self.original_parts = {p["id"]: p for p in character["parts"]}
        self.clip_bound_cache = {}
        require(all(p.get("visible", True) and p.get("opacity", 1) > 0 for p in self.original_parts.values()), "reference profile needs explicit default-invisible/zero-opacity reachability")

    def expand(self, item):
        if item["shape"] != "ref":
            return item
        definition = self.character["shapes"][item["use"]]
        require(definition["shape"] != "ref", "ref chain")
        return {**definition, **{k: v for k, v in item.items() if k not in ("shape", "use")}}

    def operands(self, item):
        item = self.expand(item)
        shape = item["shape"]
        if shape == "path":
            return len(path_values(item["d"]))
        if shape == "polyline":
            return len(item["points"]) * self.numbers["polyline_per_point"]
        if shape in ("polygon", "hexagon"):
            n = 6 if shape == "hexagon" else item["sides"]
            return n * self.numbers["rounded_polygon_per_vertex" if item.get("corner", 0) else "polygon_per_vertex"]
        require(shape in ("circle", "ellipse", "rect", "round_rect", "arc"), "unsupported primitive: " + shape)
        return self.numbers[shape]

    def item(self, item):
        item = self.expand(item)
        cost = blank()
        if item.get("alpha", 1) <= 0:
            return cost
        fill, stroke = item.get("fill") is not None, item.get("stroke") is not None and item.get("width", 2.5) > 0
        outlines = 0
        if item.get("outline"):
            outlines += int(self.outline.get("width", 0) > 0)
            outlines += int(bool(self.outline.get("second")) and self.outline["second"].get("width", 0) > 0)
        cost["paint_passes"] = int(fill) + int(stroke) + outlines
        if not cost["paint_passes"]:
            return cost
        cost["painted_items"], cost["path_numbers"] = 1, self.operands(item)
        cost["gradient_uses"] = int(isinstance(item.get("fill"), dict)) + int(isinstance(item.get("stroke"), dict))
        return cost

    def clip(self, target):
        cost = blank()
        cost["clip_applications"], cost["path_numbers"] = 1, self.operands(target)
        return cost

    def local_box(self, item):
        """Conservative primitive/control-point box, before any item transform."""
        require(item["shape"] != "ref", "reference glow bounds need explicit ref-transform expansion")
        item = self.expand(item)
        shape, x, y = item["shape"], item.get("x", 0), item.get("y", 0)
        require(not item.get("transform"), "glow profile needs transformed-item bounds")
        if shape == "path":
            values = path_values(item["d"])
            xs, ys = values[::2], values[1::2]
            box = [min(xs), min(ys), max(xs), max(ys)]
        elif shape in ("circle", "arc"):
            r = item["r"]
            box = [x-r, y-r, x+r, y+r]
        elif shape == "ellipse":
            # A circle enclosing the ellipse is valid for arbitrary local rotation.
            r = max(item["rx"], item["ry"])
            box = [x-r, y-r, x+r, y+r]
        elif shape in ("rect", "round_rect"):
            box = [x, y, x+item["w"], y+item["h"]]
        elif shape == "polyline":
            xs, ys = zip(*item["points"])
            box = [min(xs), min(ys), max(xs), max(ys)]
        else:
            raise ValueError("glow bounds unsupported for " + shape)
        width = item.get("width", 2.5) if item.get("stroke") is not None else 0
        if item.get("outline"):
            width = max(width, self.outline.get("width", 0), (self.outline.get("second") or {}).get("width", 0))
        # Miter tips require their own bounded miter-limit policy, not half-width.
        require(width == 0 or item.get("join", "round") in ("round", "bevel"), "glow profile cannot prove miter stroke bounds")
        require(not item.get('outline') or self.outline.get('join', 'round') in ('round', 'bevel'), 'glow profile cannot prove miter outline bounds')
        pad = width / 2
        return [box[0]-pad, box[1]-pad, box[2]+pad, box[3]+pad]

    def scale_bound(self, owner):
        factor = self.external_scale
        while True:
            part = {} if owner == "root" else self.original_parts[owner]
            rest = part.get("scale", 1)
            rest = rest if isinstance(rest, list) else [rest, rest]
            bounds = []
            for index, axis in enumerate(("scale_x", "scale_y")):
                channel = owner + "." + axis
                bases = [rest[index]]
                bases.extend(pose[channel] for pose in self.character.get("poses", {}).values() if channel in pose)
                bases.extend(mood.get("channels", {})[channel] for mood in self.character["moods"].values() if channel in mood.get("channels", {}))
                values = bases[:]
                for gesture in self.character.get("gestures", {}).values():
                    if channel not in gesture["tracks"]:
                        continue
                    track = gesture["tracks"][channel]
                    mode, keys = (track.get("mode", "add"), track["keys"]) if isinstance(track, dict) else ("add", track)
                    require(all(len(key) < 3 or key[2] in ("linear", "ease_in", "ease_out", "ease_in_out", "step") for key in keys), "non-monotone/unknown easing")
                    offsets = [key[1] for key in keys if key[1] is not None]
                    values.extend(base + offset for base in bases for offset in offsets) if mode == "add" else values.extend(offsets)
                bounds.append(max(abs(value) for value in values))
            factor *= max(bounds)
            idle = self.character.get("motion", {}).get("idle", {})
            if owner == idle.get("breathe_part", "root"):
                factor *= 1 + idle.get("breathe", 0.012)
            if owner == "root":
                return factor
            owner = part.get("parent", "root")

    def emission_operations(self, items):
        # A solid emitter colour replaces source paints. Merge subpaths only
        # when operation, alpha, width, cap and join are compatible.
        groups = set()
        for raw in items:
            item = self.expand(raw)
            if item.get('alpha', 1) <= 0:
                continue
            alpha = item.get('alpha', 1)
            local = set()
            if item.get('fill') is not None:
                local.add(('fill', alpha))
            if item.get('stroke') is not None and item.get('width', 2.5) > 0:
                local.add(('stroke', alpha, item.get('width', 2.5), item.get('cap', 'round'), item.get('join', 'round')))
            if item.get('outline'):
                for outline in (self.outline, self.outline.get('second') or {}):
                    if outline.get('width', 0) > 0:
                        local.add(('stroke', alpha, outline['width'], self.outline.get('cap', 'round'), self.outline.get('join', 'round')))
            groups.update(local or {('fill', alpha)})  # Emission-only silhouette.
        return len(groups)

    def glow(self, items, definition, owner, face_scale=1):
        cost = blank()
        require(all(item['shape'] != 'ref' for item in items), 'reference glow bounds need explicit ref-transform expansion')
        items = [self.expand(item) for item in items]
        items = [item for item in items if item.get('alpha', 1) > 0]
        if not self.glow_on or definition.get('alpha', 1) <= 0 or not items:
            return cost
        boxes = [self.local_box(item) for item in items]
        width = max(b[2] for b in boxes) - min(b[0] for b in boxes)
        height = max(b[3] for b in boxes) - min(b[1] for b in boxes)
        diameter = math.hypot(width, height) * self.scale_bound(owner) * face_scale
        blur = definition['blur']
        passes = self.emission_operations(items)
        cost['inflated_glow_area_ratio'] = passes * (diameter + 6 * blur) ** 2 / 90000
        cost['glow_emitters'], cost['paint_passes'], cost['blur_design_units'] = 1, passes, blur
        # Solid named emission colour uses no source gradient invocation.
        for item in items:
            if self.item(item)['painted_items'] == 0:
                cost['painted_items'] += 1
                cost['path_numbers'] += self.operands(item)
        return cost

    def eye(self, style):
        face, cost, items = self.character["face"], blank(), []
        flags = self.lod.get("face", {})
        op = style["op"]
        lashes = style.get("lashes") if face.get("eyes", {}).get("lashes", True) and flags.get("lashes", True) else None
        if op == "eye_ellipse":
            pupil = style["pupil"]
            sclera = {"shape":"ellipse", "rx":style["rx"], "ry":style["ry"], "fill":style.get("fill", "eye_white")}
            if style.get("outline", {}).get("width", 0) > 0:
                sclera.update(stroke=style["outline"]["colour"], width=style["outline"]["width"])
            items.append(sclera)
            iris = face.get("eyes", {}).get("iris") is not None and flags.get("iris", True)
            if iris and pupil["r"] > 0:
                items.append({"shape":"circle", "r":pupil["r"], "fill":"iris"})
            if pupil["r"] > 0:
                items.append({"shape":"circle", "r":pupil["r"]*(0.65 if iris else 1), "fill":"feature"})
                for glint in pupil.get("glints", [{"at":[-0.35,-0.4], "r":0.22}]):
                    if glint["r"] > 0:
                        items.append({"shape":"circle", "r":pupil["r"]*glint["r"], "fill":"shine"})
            # Positive held lid is legal independently of blink; full blink would
            # select closed, but face.lid alone can keep this ellipse operation.
            items.append({"shape":"rect", "x":-1.2*style["rx"], "y":-1.2*style["ry"], "w":2.4*style["rx"], "h":2.4*style["ry"], "fill":"eyelid"})
            if style.get("lid_edge", {}).get("width", 0) > 0:
                items.append({"shape":"polyline", "points":[[-1.2*style["rx"],0],[1.2*style["rx"],0]], "stroke":style["lid_edge"]["colour"], "width":style["lid_edge"]["width"]})
            cost = self.clip({"shape":"ellipse", "rx":max(style["rx"]-1,0), "ry":max(style["ry"]-1,0)})
        elif op == "eye_dots":
            items = [{"shape":"circle", "x":x, "y":y, "r":style["r"], "fill":style.get("fill","feature")} for x,y in style["centres"]]
        elif op == "eye_path":
            items = [{"shape":"path", "d":style["d"], "fill":style.get("fill","feature"), "stroke":style.get("stroke"), "width":style.get("width",2)}]
        elif op == "eye_arc":
            items = [{"shape":"arc", "r":style["r"], "start":style["start"], "end":style["end"], "y":style.get("y",0), "stroke":style.get("stroke","feature"), "width":style.get("width",5), "fill":style.get("fill")}]
        else:
            raise ValueError("unknown eye operation " + op)
        if lashes:
            items += [{"shape":"polyline", "points":[[0,0],[1,1]], "stroke":"feature", "width":lashes.get("width",3)} for _ in lashes["angles"]]
        cost = combine(cost, *(self.item(item) for item in items))
        return cost, items

    def face_maxima(self, parts, visible):
        face = self.character.get("face")
        if face is None or face["part"] not in visible:
            return {metric:(0,{}) for metric in blank()}
        flags, kit = self.lod.get("face", {}), face["kit_definition"]
        if kit.get("glow"):
            require(all(style["op"] != "eye_ellipse" and not style.get("lashes") for style in kit["eye_styles"].values()), "reference glow bounds do not cover ellipse eyes/lashes")
        eyes = {name:(self.eye(style),style.get("hide_brows",False)) for name,style in kit["eye_styles"].items()}
        brows = {}
        for name, style in kit["brow_styles"].items():
            require(style["op"] == "brow_path", "unknown brow operation")
            item = {"shape":"path", "d":style["d"], "stroke":style.get("stroke","feature"), "width":style.get("width",3.5)}
            brows[name] = (self.item(item),item) if flags.get("brows",True) and style.get("width",3.5)>0 else (blank(),None)
        mouths = {}
        for name, style in kit["mouth_styles"].items():
            require(style["op"] == "mouth_path", "unknown mouth operation")
            items = copy.deepcopy(style["items"])
            bx,by = style.get("box",[20,12])
            for item in items:
                require(item["shape"] in ("path","ellipse","polyline"), "unsupported mouth primitive")
                if item["shape"] == "path":
                    index = 0
                    def scaled(match):
                        nonlocal index
                        value = float(match[0]) * (bx if index%2==0 else by)
                        index += 1
                        return str(value)
                    item["d"] = re.sub(r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?",scaled,item["d"])
                elif item["shape"] == "ellipse":
                    for key,multiplier in (("x",bx),("y",by),("rx",bx),("ry",by)):
                        item[key]=item.get(key,0)*multiplier
                else:
                    item["points"]=[[x*bx,y*by] for x,y in item["points"]]
            mouths[name]=(combine(*(self.item(item) for item in items)),items)
        constant=blank()
        if face.get("clip"):
            owner,item_id=face["clip"].split(".",1)
            require(owner==face["part"], "reference profile needs coupled cross-owner face-clip geometry")
            constant=combine(constant,self.clip_max(face["clip"], parts)[0])
        if face.get("blush"):
            constant=combine(constant,self.item({"shape":"ellipse","rx":1,"ry":1,"fill":"blush"}),self.item({"shape":"ellipse","rx":1,"ry":1,"fill":"blush"}))
        scale=face.get("scale",1)*flags.get("scale",1)
        # Per-style bounds avoid an eyes x eyes x brows x mouths product.
        eye_bounds = {name: (combine(cost, self.glow(items, kit['glow'], face['part'], scale) if kit.get('glow') else blank()), hidden) for name, ((cost, items), hidden) in eyes.items()}
        brow_bounds = {name: combine(cost, self.glow([item], kit['glow'], face['part'], scale) if kit.get('glow') and item else blank()) for name, (cost, item) in brows.items()}
        mouth_bounds = {name: combine(cost, self.glow(items, kit['glow'], face['part'], scale) if kit.get('glow') else blank()) for name, (cost, items) in mouths.items()}
        best = {}
        for metric in blank():
            _, brow_name = max((cost[metric], name) for name, cost in brow_bounds.items())
            eye_best = (-1, None)
            for name, (cost, hidden) in eye_bounds.items():
                extra = 0 if hidden else brow_bounds[brow_name][metric]
                value = max(cost[metric], extra) if metric == 'blur_design_units' else cost[metric] + extra
                if value > eye_best[0]:
                    eye_best = (value, name)
            mouth_best = (-1, None)
            for name, cost in mouth_bounds.items():
                if cost[metric] > mouth_best[0]:
                    mouth_best = (cost[metric], name)
            value = max(constant[metric], eye_best[0], mouth_best[0]) if metric == 'blur_design_units' else constant[metric] + 2 * eye_best[0] + mouth_best[0]
            best[metric] = (value, {'eyes': [eye_best[1], eye_best[1]], 'brows': brow_name, 'mouth': mouth_best[1], 'positive_lid': True, 'positive_blush': bool(face.get('blush')), 'method': 'separable_component_bound'})
        return best

    def variant_items(self, name, part):
        selected = self.lod.get('variants', {}).get(name)
        names = [selected] if selected is not None else ['default'] + list(part.get('variants', {}))
        for variant in names:
            yield variant, part.get('items', []) if variant == 'default' else part['variants'][variant]

    def clip_max(self, target, parts, source_id=None, source_variant=None):
        owner, item_id = target.split('.', 1)
        key = (target, source_variant if owner == source_id else None)
        if key in self.clip_bound_cache:
            return self.clip_bound_cache[key]
        require(owner in parts, 'reference profile needs cross-slot clip ownership')
        options = []
        for variant, items in self.variant_items(owner, parts[owner]):
            if owner == source_id and variant != source_variant:
                continue
            item = next(item for item in items if item.get('id') == item_id)
            options.append((self.clip(item), {'target': target, 'variant': variant}))
        self.clip_bound_cache[key] = self.component_max(options)
        return self.clip_bound_cache[key]

    @staticmethod
    def component_max(options):
        best = {metric: (-1, None) for metric in blank()}
        for cost, state in options:
            for metric, value in cost.items():
                if value > best[metric][0]:
                    best[metric] = (value, state)
        require(all(value >= 0 for value, _ in best.values()), 'no component choices')
        return ({metric: value for metric, (value, _) in best.items()},
                {metric: state for metric, (_, state) in best.items()})

    def shown(self, name, parts):
        part = parts[name]
        if name in self.lod.get('hide', []) or self.band not in part.get('lod', ['full', 'small', 'micro']):
            return False
        parent = part.get('parent', 'root')
        return parent == 'root' or self.shown(parent, parts)

    def part_bound(self, name, part, parts):
        if not self.shown(name, parts):
            return blank(), {metric: {'part': name, 'hidden': True} for metric in blank()}, 1
        options = []
        for variant, items in self.variant_items(name, part):
            cost = blank()
            cost['active_parts'] = 1  # Includes visible empty pivots.
            clip_proofs = []
            for raw in items:
                item = self.expand(raw)
                if self.band not in item.get('lod', ['full', 'small', 'micro']) or f"{name}.{item.get('id')}" in self.lod.get('hide', []):
                    continue
                item_cost = self.item(item)
                glow = part.get('glow')
                emission = blank()
                if glow and glow['item'] == item.get('id'):
                    require(name in self.original_parts, 'reference profile needs attachment glow scale bounds')
                    emission = self.glow([raw], glow, name)
                if item_cost['painted_items'] == 0 and emission['painted_items'] == 0:
                    continue
                cost = combine(cost, item_cost, emission)
                if item.get('clip'):
                    owner = item['clip'].split('.', 1)[0]
                    require(self.shown(owner, parts), 'reference profile requires explicit clip-only active-part closure')
                    clip_cost, proof = self.clip_max(item['clip'], parts, name, variant)
                    cost = combine(cost, clip_cost)
                    clip_proofs.append(proof)
            options.append((cost, {'part': name, 'variant': variant, 'clip_bounds': clip_proofs}))
        cost, proofs = self.component_max(options)
        proofs = {metric: {**state, 'clip_bounds': [proof[metric] for proof in state['clip_bounds']] if metric in ('path_numbers', 'clip_applications') else []} for metric, state in proofs.items()}
        return cost, proofs, len(options)

    def body_components(self):
        # Sum local maxima, never enumerate the Cartesian product of parts/slots.
        for name, part in self.original_parts.items():
            yield name, self.part_bound(name, part, self.original_parts)
        slots = {}
        for name, accessory in self.character.get('accessories', {}).items():
            require(not accessory.get('lod'), 'reference profile needs accessory-level band expansion')
            slots.setdefault(accessory['slot'], []).append(name)
        for slot, names in slots.items():
            options = [(blank(), {'wear': None})]
            count = 1
            for name in names:
                accessory = self.character['accessories'][name]
                owner = self.character['anchors'][accessory['anchor']]['part']
                parts = dict(self.original_parts)
                expanded_names = []
                for part in accessory['parts']:
                    expanded = copy.deepcopy(part)
                    part_id = f"wear_{name}_{part['id']}"
                    expanded['parent'] = (f"wear_{name}_{part['parent']}" if part.get('parent', 'root') != 'root' else owner)
                    parts[part_id] = expanded
                    expanded_names.append(part_id)
                cost, local_proofs = blank(), {}
                for part_id in expanded_names:
                    local, proofs, evaluated = self.part_bound(part_id, parts[part_id], parts)
                    cost = combine(cost, local)
                    local_proofs[part_id] = proofs
                    count += evaluated
                options.append((cost, {'wear': name, 'parts': local_proofs}))
            cost, proofs = self.component_max(options)
            proofs = {metric: {'wear': state['wear'], 'parts': {name: local[metric] for name, local in state.get('parts', {}).items()}} for metric, state in proofs.items()}
            yield 'slot:' + slot, (cost, proofs, count)
        shadow = self.character.get('ground', {}).get('shadow')
        if shadow and shadow.get('alpha', 1) > 0:
            cost = self.item({'shape': 'ellipse', 'rx': shadow['rx'], 'ry': shadow['ry'], 'fill': shadow.get('colour', 'shadow')})
            yield 'shadow', (cost, {metric: {'shadow': True} for metric in blank()}, 1)
        face = self.character.get('face')
        if face:
            for name, placement in self.character.get('effects', {}).items():
                owner = self.character['anchors'][placement['anchor']]['part']
                if not self.shown(owner, self.original_parts):
                    continue
                effect = face['kit_definition']['effects'][name]
                require(effect['mode'] in ('progress', 'pulse'), 'reference profile needs track-effect accounting')
                options = [('ordinary', effect['items'])]
                if effect['mode'] != 'progress':
                    options.append(('reduced', effect.get('reduced_items', [])))
                cost, proofs = self.component_max((combine(*(self.item(item) for item in items)), {'effect': name, 'mode': mode}) for mode, items in options)
                yield 'effect:' + name, (cost, proofs, len(options))

    def maxima(self):
        result = blank()
        witnesses = {metric: {'components': []} for metric in blank()}
        evaluated = 0
        for name, (cost, proofs, count) in self.body_components():
            result = combine(result, cost)
            evaluated += count
            for metric in result:
                if cost[metric] > 0:
                    witnesses[metric]['components'].append({'component': name, 'bound': cost[metric], 'choice': proofs[metric]})
        face_best = self.face_maxima(self.original_parts, {name for name in self.original_parts if self.shown(name, self.original_parts)})
        result = combine(result, {metric: value for metric, (value, _) in face_best.items()})
        for metric in result:
            witnesses[metric]['face'] = face_best[metric][1]
        result['inflated_glow_area_ratio'] = (math.ceil(math.nextafter(result['inflated_glow_area_ratio'], math.inf) * 1e12) / 1e12 if result['inflated_glow_area_ratio'] else 0.0)
        return result, witnesses, evaluated

def calculate():
    operations,policy=load(ROOT/'operations.json'),load(ROOT/'limits.json')
    require(operations['operation_manifest_version']==2,'unsupported accounting version')
    require(operations['primitive_numbers']=={'circle':5,'ellipse':7,'rect':4,'round_rect':8,'arc':5,'polyline_per_point':2,'polygon_per_vertex':2,'rounded_polygon_per_vertex':6,'path_commands':{'M':2,'L':2,'Q':4,'C':6,'Z':0}},'primitive counting policy differs')
    require(policy['operation_manifest_version']==2 and policy['policy_version']==2,'unsupported policy/accounting pair')
    result={'accounting_version':2,'operation_manifest_version':2,'policy_version':2,'method':'separable_componentwise_upper_bound','status':'reference_counts_and_conservative_authored_glow_bounds_not_validator_or_runtime_evidence','limits':'limits.json','operations':'operations.json','rows':[],'runtime_scale_stress':[]}
    for file in ('characters/tessa.json','characters/alpha_visor.json','expected/study_bot.json','characters/anchor_probe.json'):
        character=load(ROOT/'fixtures'/file)
        for band in ('full','small','micro'):
            counter=Counter(character,band,operations)
            maxima,witnesses,options=counter.maxima()
            exceeded=[metric for metric,value in maxima.items() if value>policy['bands'][band][metric]]
            result['rows'].append({'character':character['id'],'file':file,'band':band,'maxima':maxima,'witnesses':witnesses,'evaluated_body_component_choices':options,'exceeded':exceeded,'structural_counts':'separable_componentwise_upper_bound','glow_area':'conservative_authored_upper_bound','semantic_visual_runtime_acceptance':'not_run'})
        # The same authored scale bound with an additional external uniform root
        # scale illustrates why file acceptance cannot skip live budget guards.
        stress,_,_=Counter(character,'small',operations,external_scale=16).maxima()
        result['runtime_scale_stress'].append({'character':character['id'],'band':'small','external_root_scale':16,'glow_area_upper_bound':stress['inflated_glow_area_ratio'],'limit':policy['bands']['small']['inflated_glow_area_ratio'],'bound_exceeds_limit':stress['inflated_glow_area_ratio']>policy['bands']['small']['inflated_glow_area_ratio'],'interpretation':'reject_entire_transform_update_before_apply_unless_tighter_proof_passes; this is not a runtime execution'})
    return result


def check_rows(result, policy):
    for row in result['rows']:
        if row['exceeded']:
            metric = row['exceeded'][0]
            path = '$'
            witness = json.dumps(row['witnesses'][metric], sort_keys=True)
            raise ValueError(f"budget at {path} ({row['band']}): {row['character']} {metric} bound {row['maxima'][metric]} exceeds {policy['bands'][row['band']][metric]}; fix: simplify {metric} in {row['band']}; component choices {witness}")


def self_test():
    operations=load(ROOT/'operations.json')
    tessa=load(ROOT/'fixtures/characters/tessa.json')
    robot=load(ROOT/'fixtures/characters/alpha_visor.json')
    probe=load(ROOT/'fixtures/characters/anchor_probe.json')
    completed=[]
    def expect(name, actual, expected):
        require(all(actual[key]==value for key,value in expected.items()), f"{name}: {actual} differs from hand-calculated {expected}")
        completed.append(name)
    full=Counter(tessa,'full',operations)
    expect('fill_and_detail_stroke',full.item({'shape':'circle','r':2,'fill':'body','stroke':'outline'}),{'painted_items':1,'paint_passes':2,'path_numbers':5})
    expect('primary_and_secondary_outline',Counter(robot,'full',operations).item({'shape':'circle','r':2,'fill':'body','outline':True}),{'painted_items':1,'paint_passes':3,'path_numbers':5})
    expect('micro_removes_secondary_outline',Counter(robot,'micro',operations).item({'shape':'circle','r':2,'fill':'body','outline':True}),{'paint_passes':2,'path_numbers':5})
    expect('normalised_round_rect',full.item({'shape':'round_rect','x':0,'y':0,'w':5,'h':5,'r':2,'fill':'body'}),{'path_numbers':8})
    expect('sharp_polygon',full.item({'shape':'hexagon','r':5,'fill':'body'}),{'path_numbers':12})
    expect('rounded_polygon',full.item({'shape':'hexagon','r':5,'corner':1,'fill':'body'}),{'path_numbers':36})
    expect('scientific_path_operands',full.item({'shape':'path','d':'M1e-3 -2E-3 L3 4','stroke':'feature'}),{'path_numbers':4,'painted_items':1})
    expect('two_point_polyline',full.item({'shape':'polyline','points':[[0,0],[1,1]],'stroke':'feature'}),{'path_numbers':4})
    expect('clip_only_hidden_geometry',full.clip({'shape':'circle','r':5}),{'painted_items':0,'paint_passes':0,'path_numbers':5,'clip_applications':1})
    repeated=copy.deepcopy(probe)
    repeated['shapes']={'disc':{'shape':'circle','r':5,'fill':{'paint':'shared'}}}
    ref_counter=Counter(repeated,'full',operations)
    expect('repeated_refs_and_gradients',combine(*(ref_counter.item({'shape':'ref','use':'disc'}) for _ in range(3))),{'painted_items':3,'paint_passes':3,'path_numbers':15,'gradient_uses':3})
    glyph=Counter(robot,'small',operations)
    scan,items=glyph.eye(robot['face']['kit_definition']['eye_styles']['scan'])
    expect('two_dots_one_emission_group',combine(scan,glyph.glow(items,robot['face']['kit_definition']['glow'],'head')),{'painted_items':2,'paint_passes':3,'path_numbers':10,'glow_emitters':1})
    ellipse,_=full.eye(tessa['face']['kit_definition']['eye_styles']['open'])
    expect('ellipse_eye_including_edge_and_shared_clip',ellipse,{'painted_items':9,'paint_passes':10,'path_numbers':49,'clip_applications':1})
    micro,_,_=Counter(tessa,'micro',operations).maxima()
    expect('corrected_tessa_micro',micro,{'painted_items':29,'paint_passes':41,'path_numbers':272,'clip_applications':2})
    old=copy.deepcopy(tessa)
    old['lod']['micro']['hide']=['wear_bow_ornament']
    old_micro,_,_=Counter(old,'micro',operations).maxima()
    expect('old_clip_failure',old_micro,{'painted_items':33,'paint_passes':46,'path_numbers':292})
    require(old_micro['painted_items']>load(ROOT/'limits.json')['bands']['micro']['painted_items'],'old clip case did not exceed limit')
    normal,_,_=full.maxima()
    independent=copy.deepcopy(tessa)
    independent['accessories']['clip']['slot']='separate_pin'
    both,_,_=Counter(independent,'full',operations).maxima()
    expect('accessory_slot_exclusivity',{'same_slot':normal['painted_items'],'separate_slots':both['painted_items']},{'same_slot':42,'separate_slots':46})
    variant=copy.deepcopy(probe)
    second=copy.deepcopy(variant['parts'][0]['items'][0]);second['id']='second'
    variant['parts'][0]['variants']['raised'].append(second)
    variant_max,_,_=Counter(variant,'full',operations).maxima()
    expect('variants_are_not_added',variant_max,{'painted_items':3})
    hidden,_,_=Counter(probe,'micro',operations).maxima()
    expect('hidden_owner_suppresses_badge',hidden,{'active_parts':0,'painted_items':0,'path_numbers':0})
    try:
        full.item({'shape':'unimplemented_shape','fill':'body'})
    except ValueError:
        completed.append('unknown_primitive_fails')
    else:
        raise ValueError('unknown primitive was silently accepted')
    unknown=copy.deepcopy(probe)
    unknown['gestures']['rock']['tracks']['panel.opacity']=[[0,0],[1,0]]
    try:
        Counter(unknown,'full',operations)
    except ValueError:
        completed.append('unsupported_state_space_fails')
    else:
        raise ValueError('unsupported state-space construct was silently accepted')
    baseline,_,_=Counter(robot,'small',operations).maxima()
    stress,_,_=Counter(robot,'small',operations,external_scale=16).maxima()
    require(baseline['inflated_glow_area_ratio']<=0.5<stress['inflated_glow_area_ratio'],'external scale test failed to distinguish authored bound')
    completed.append('external_scale_is_not_authored_certificate')
    micro_glow,_,_=Counter(robot,'micro',operations).maxima()
    expect('micro_disables_glow',micro_glow,{'glow_emitters':0,'blur_design_units':0,'inflated_glow_area_ratio':0.0})
    transparent=copy.deepcopy(robot)
    transparent['parts'][5]['items'][1]['alpha']=0
    transparent_counts,_,_=Counter(transparent,'full',operations).maxima()
    expect('zero_alpha_emitter_is_suppressed',transparent_counts,{'glow_emitters':3,'painted_items':36})
    # Review counterexamples: fail closed for deliberately unsupported syntax.
    clipped = copy.deepcopy(tessa)
    clipped['face']['kit_definition']['effects']['sparkle']['items'][0]['clip'] = 'body.rim'
    try:
        Counter(clipped, 'micro', operations)
    except ValueError as error:
        require('kit effect items' in str(error), 'wrong effect-clip refusal')
        completed.append('H1_effect_clip_refused')
    else:
        raise ValueError('effect clip silently undercounted')
    band_variant = copy.deepcopy(probe)
    band_variant['lod'] = {'small': {'variants': {'panel': 'default'}}}
    band_variant['parts'][0]['variants']['raised'] += [copy.deepcopy(band_variant['parts'][0]['items'][0]) for _ in range(5)]
    expect('H3_band_variant_wins', Counter(band_variant, 'small', operations).maxima()[0], {'painted_items': 2})
    emit = Counter(robot, 'full', operations)
    expect('M1_fill_stroke_are_two_blur_operations', emit.glow([{'shape': 'circle', 'r': 2, 'fill': 'feature', 'stroke': 'feature', 'width': 2}], {'blur': 3}, 'head'), {'paint_passes': 2, 'glow_emitters': 1})
    expect('solid_glow_does_not_reinvoke_source_gradient', emit.glow([{'shape': 'circle', 'r': 2, 'fill': {'paint': 'lamp_grad'}}], {'blur': 3, 'colour': 'light'}, 'head'), {'gradient_uses': 0, 'paint_passes': 1})
    expect('emission_only_geometry_is_counted', emit.glow([{'shape': 'circle', 'r': 2}], {'blur': 3}, 'head'), {'painted_items': 1, 'path_numbers': 5, 'paint_passes': 1})
    breathing = copy.deepcopy(probe)
    breathing['parts'][0]['scale'] = 0.5
    breathing['motion'] = {'idle': {'breathe': 0.012, 'breathe_part': 'panel'}}
    require(math.isclose(Counter(breathing, 'full', operations).scale_bound('panel'), 0.506), 'breathing must multiply the current scale')
    completed.append('M3_breathing_is_multiplicative')
    pivots = copy.deepcopy(probe)
    pivots['parts'][0]['items'] = []
    pivots['parts'][0].pop('variants', None)
    expect('L1_empty_visible_pivot_is_active', Counter(pivots, 'full', operations).maxima()[0], {'active_parts': 2})
    faceless = copy.deepcopy(probe)
    faceless['effects'] = {'sparkle': {'anchor': 'badge'}}
    try:
        Counter(faceless, 'full', operations)
    except ValueError as error:
        require('faceless' in str(error), 'wrong faceless-effect refusal')
        completed.append('L3_faceless_kit_effect_refused')
    else:
        raise ValueError('faceless mapped effects counted as free')
    many = copy.deepcopy(probe)
    many['parts'] = [dict(copy.deepcopy(probe['parts'][0]), id=f'p{i}', parent='root') for i in range(64)]
    many['anchors'], many['accessories'], many['wear'], many['lod'] = {}, {}, [], {}
    _, _, choices = Counter(many, 'full', operations).maxima()
    require(choices == 128, '64 two-variant parts should evaluate 128 local choices')
    completed.append('M4_no_variant_cartesian_product')
    coupled = copy.deepcopy(many)
    coupled['parts'] = [
        {'id': 'target', 'items': [{'id': 'mask', 'shape': 'circle', 'r': 2, 'fill': 'ink'}, {'shape': 'circle', 'r': 1, 'fill': 'ink'}],
         'variants': {'large_mask': [{'id': 'mask', 'shape': 'path', 'd': 'M0 0 L1 1 L2 2 L3 3', 'fill': 'ink'}]}},
        {'id': 'source', 'items': [{'shape': 'circle', 'r': 1, 'fill': 'ink', 'clip': 'target.mask'}]}]
    expect('M4_clip_geometry_separable_upper_bound', Counter(coupled, 'full', operations).maxima()[0], {'path_numbers': 23})
    # Derived accounting probes, not complete semantic rejection fixtures.
    policy = load(ROOT/'limits.json')
    for band, limit in policy['bands'].items():
        for metric in blank():
            ch = copy.deepcopy(many)
            ch['parts'] = [{'id': 'panel', 'items': []}]
            ch['outline'] = {'width': 2, 'colour': 'ink', 'second': {'width': 4, 'colour': 'ink'}}
            ch['lod'] = {'micro': {'glow': True}}
            item = {'shape': 'circle', 'r': 1, 'fill': 'ink'}
            if metric == 'active_parts':
                ch['parts'] = [{'id': f'p{i}', 'items': []} for i in range(limit[metric] + 1)]
            elif metric == 'painted_items':
                ch['parts'][0]['items'] = [dict(item) for _ in range(limit[metric] + 1)]
            elif metric == 'paint_passes':
                ch['parts'][0]['items'] = [dict(item, stroke='ink', width=1, outline=True) for _ in range(limit[metric] // 4 + 1)]
            elif metric == 'path_numbers':
                ch['parts'][0]['items'] = [{'shape': 'path', 'd': 'M0 0' + ' L1 1' * (limit[metric] // 2), 'fill': 'ink'}]
            elif metric == 'clip_applications':
                ch['parts'][0]['items'] = [dict(item, clip='panel.mask') for _ in range(limit[metric] + 1)] + [{'id': 'mask', 'shape': 'circle', 'r': 2}]
            elif metric == 'gradient_uses':
                ch['parts'][0]['items'] = [dict(item, fill={'paint': 'gradient'}) for _ in range(limit[metric] + 1)]
            elif metric == 'glow_emitters':
                ch['parts'] = [{'id': f'p{i}', 'items': [dict(item, id='lamp')], 'glow': {'item': 'lamp', 'colour': 'ink', 'blur': 1}} for i in range(limit[metric] + 1)]
            else:
                ch['parts'][0]['items'] = [dict(item, id='lamp')]
                ch['parts'][0]['glow'] = {'item': 'lamp', 'colour': 'ink', 'blur': limit['blur_design_units'] + 1 if metric == 'blur_design_units' else limit['blur_design_units']}
                if metric == 'inflated_glow_area_ratio':
                    ch['parts'][0]['items'] = [{'id': 'lamp', 'shape': 'rect', 'x': -100, 'y': -200, 'w': 200, 'h': 200, 'fill': 'ink'}]
            values, witnesses, _ = Counter(ch, band, operations).maxima()
            require(values[metric] > limit[metric], f'{band}/{metric} did not exceed its cap')
            row = {'character': ch['id'], 'band': band, 'maxima': values, 'witnesses': witnesses, 'exceeded': [key for key, value in values.items() if value > limit[key]]}
            try:
                check_rows({'rows': [row]}, policy)
            except ValueError as error:
                require('budget at $ (' + band + ')' in str(error) and 'fix:' in str(error), 'drawing-budget diagnostic lost its band/fix')
            else:
                raise ValueError('over-budget accounting row accepted')
            completed.append('budget_boundary_' + band + '_' + metric)
    print(f'PASS: {len(completed)} hand-calculated/reference accounting cases, including review regressions, 27 per-band counter boundary probes, slot/variant exclusivity, hidden clip geometry, glyph emission and unsupported-state refusals. Not R/JS/runtime tests.')


def main():
    mode=sys.argv[1:] or ['--check']
    require(mode in (['--check'],['--write'],['--self-test']),'usage: budget.py [--check|--write|--self-test]')
    if mode==['--self-test']:
        self_test()
        return
    result=calculate()
    target=ROOT/'budgets.json'
    check_rows(result, load(ROOT/'limits.json'))
    if mode==['--write']:
        target.write_text(json.dumps(result,indent=2,allow_nan=False)+'\n',encoding='utf-8')
    else:
        require(load(target)==result,'budgets.json differs from recomputed reference counts')
    for row in result['rows']:
        values=row['maxima']
        print(f"{row['character']} {row['band']}: items={values['painted_items']} passes={values['paint_passes']} numbers={values['path_numbers']} clips={values['clip_applications']} glow={values['glow_emitters']} area<={values['inflated_glow_area_ratio']}; exceeded={','.join(row['exceeded']) or 'none'}")
    # Invalid reference data is reportable evidence, not a successful acceptance.
    if any(row['exceeded'] for row in result['rows']):
        raise ValueError('reference recipe exceeds the agreed limits')
    print('PASS: 12 reference rows recomputed; separable componentwise integer upper bounds and conservative authored glow-area bounds. No renderer, full validator, frame-fit or performance evidence.')


if __name__=='__main__':
    try:
        main()
    except (ValueError,KeyError,TypeError,IndexError,OSError,StopIteration) as error:
        print('FAIL: '+str(error),file=sys.stderr)
        raise SystemExit(1) from error
