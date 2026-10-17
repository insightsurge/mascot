"""Read-only, selected checks for R1a documentation; not the package validator.

Run from the repository root: python3 -I docs/character-format/check.py
The same failures remain active under -O. Uses only the standard library.
"""
from pathlib import Path
import copy
import json
import math
import re
import sys
import subprocess


class Problem(ValueError):
    def __init__(self, code, path, message):
        self.code, self.path = code, path
        super().__init__(f"{code} at {path}: {message}")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise Problem("input_type", "$." + key, "duplicate JSON key")
        result[key] = value
    return result


def finite(value, path="$", depth=0):
    if isinstance(value, float) and not math.isfinite(value):
        raise Problem("non_finite", path, "number must be finite")
    if isinstance(value, dict):
        for key, child in value.items():
            finite(child, path + "." + key, depth + 1)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            finite(child, f"{path}[{index}]", depth + 1)


def decode(raw, max_bytes=None):
    if max_bytes is not None and len(raw) > max_bytes:
        raise Problem("budget", "$", "UTF-8 input byte limit exceeded")
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise Problem("input_type", "$", str(error)) from error
    finite(value)
    return value


def load(path, max_bytes=None):
    return decode(path.read_bytes(), max_bytes)


def problem_if(condition, code, path, message):
    if condition:
        raise Problem(code, path, message)


TOP_KEYS = set("format_version id name family description resolved family_definition palette_sources pronouns requires colours colour_descriptions follows brand contrast modes palettes paints shapes ground outline parts anchors face poses moods gestures motion effects lod accessories wear note".split())
ROOT_CHANNELS = {"lift", "rotate", "scale_x", "scale_y", "flip"}
PART_CHANNELS = {"x", "y", "rotate", "scale_x", "scale_y", "opacity", "visible", "variant"}
FACE_CHANNELS = {"look_x", "look_y", "blink", "eyes", "mouth", "brows", "open", "lid", "blush"}


def selected_character_checks(data, policy):
    """Limited structure/references only, intentionally not full schema semantics."""
    problem_if(not isinstance(data, dict), "input_type", "$", "expected object")
    problem_if(type(data.get("format_version")) is not int, "input_type", "$.format_version", "expected integer")
    problem_if(data["format_version"] != 1, "version", "$.format_version", "unsupported version")
    problem_if(not isinstance(data.get("requires"), list), "input_type", "$.requires", "expected array")
    for index, capability in enumerate(data["requires"]):
        problem_if(capability not in policy["capabilities"], "capability", f"$.requires[{index}]", "unsupported capability")
    # Reserved capabilities (contract 3.18) report "capability" where a fixed-field object uses them, before any other
    # key check, as the package checker does. Map keys (ids, roles) are data and are never checked.
    reserved = set(policy["reserved_unsupported"])

    def reserved_keys(value, path):
        if isinstance(value, dict):
            for key in value:
                problem_if(key in reserved, "capability", f"{path}.{key}", "not supported by this version of mascot")

    reserved_keys(data, "$")
    for index, part in enumerate(data.get("parts") or []):
        reserved_keys(part, f"$.parts[{index}]")
        for item_index, item in enumerate((part or {}).get("items") or []):
            reserved_keys(item, f"$.parts[{index}].items[{item_index}]")
    for group in ("accessories", "palettes"):
        for name, entry in (data.get(group) or {}).items():
            reserved_keys(entry, f"$.{group}.{name}")
    for key in data:
        problem_if(key not in TOP_KEYS, "unknown_key", "$." + key, "unknown top-level field")
    for key in ("id", "name", "family", "description"):
        problem_if(not isinstance(data.get(key), str) or not data[key], "input_type", "$." + key, "expected nonempty string")
    for key in ("colours", "ground", "moods"):
        problem_if(not isinstance(data.get(key), dict), "input_type", "$." + key, "expected object")
    problem_if(not isinstance(data.get("parts"), list), "input_type", "$.parts", "expected array")
    part_ids = [part["id"] for part in data["parts"]]
    require(len(part_ids) == len(set(part_ids)), "duplicate part ids")
    parts = {part["id"]: part for part in data["parts"]}
    for accessory in data.get("wear", []):
        definition = data.get("accessories", {}).get(accessory)
        problem_if(definition is None, "missing_reference", "$.wear", "unknown accessory")
        for part in definition["parts"]:
            expanded = f"wear_{accessory}_{part['id']}"
            require(expanded not in parts, "expanded accessory id collision")
            parts[expanded] = part
    roles = set(data["colours"])
    for index, part in enumerate(data["parts"]):
        parent = part.get("parent", "root")
        problem_if(parent != "root" and parent not in parts, "missing_reference", f"$.parts[{index}].parent", "unknown parent")
        at = part.get("at", [0, 0])
        problem_if(not isinstance(at, list) or len(at) != 2, "input_type", f"$.parts[{index}].at", "expected two coordinates")
        for component, number in enumerate(at):
            problem_if(type(number) not in (int, float), "input_type", f"$.parts[{index}].at[{component}]", "expected number")
        for item_index, item in enumerate(part.get("items", [])):
            for field in ("fill", "stroke"):
                colour = item.get(field)
                if isinstance(colour, str):
                    problem_if(colour not in roles, "missing_reference", f"$.parts[{index}].items[{item_index}].{field}", "unknown colour role")
    # Cycles in the ordinary authored part tree are checked without recursion.
    for part in data["parts"]:
        seen, current = set(), part["id"]
        while current != "root":
            require(current not in seen, "cyclic part parent")
            seen.add(current)
            current = parts[current].get("parent", "root")
    for name, anchor in data.get("anchors", {}).items():
        problem_if(anchor["part"] not in parts, "missing_reference", f"$.anchors.{name}.part", "unknown owning part")
        for variant in anchor.get("variants", {}):
            require(variant in parts[anchor["part"]].get("variants", {}), "anchor override names unknown variant")
    face = data.get("face")
    if face is not None:
        problem_if(face["part"] not in parts, "missing_reference", "$.face.part", "unknown face owner")
        if data.get("resolved"):
            require(face.get("kit_definition", {}).get("id") == face["kit"], "resolved face lacks matching embedded kit")
        if face.get("clip"):
            owner, item_id = face["clip"].split(".", 1)
            require(owner in parts and item_id in {item.get("id") for item in parts[owner].get("items", [])}, "unknown face clip")
    for mood in policy["core_moods"]:
        problem_if(mood not in data["moods"], "missing_reference", "$.moods." + mood, "missing core mood")
    for mood in data["moods"].values():
        require(bool(mood.get("status")), "mood has no status")
    family = data.get("family_definition")
    if family:
        require(family["id"] == data["family"], "family id mismatch")
        require(not (set(family.get("defaults", {})) & {"parts", "anchors", "ground", "accessories", "wear"}), "family defaults invent anatomy")
    if data.get("resolved"):
        require(family is not None and family.get("defaults") == {}, "resolved family must be a metadata snapshot")
        require(set(data.get("palette_sources", {})) == set(data.get("palettes", {})), "palette provenance keys differ")
        require(all(value in ("family", "character") for value in data["palette_sources"].values()), "invalid palette origin")
        require(all(value is not None for value in data.get("palettes", {}).values()), "resolved palette is null")
    gestures = data.get("gestures", {})
    if family and not data.get("resolved"):
        gestures = {**family.get("defaults", {}).get("gestures", {}), **gestures}
    require({"nod", "wave"} <= gestures.keys(), "required callable gestures absent")
    for name, gesture in gestures.items():
        duration = gesture["frames"]
        problem_if(type(duration) is not int, "input_type", f"$.gestures.{name}.frames", "expected integer")
        problem_if(not 1 <= duration <= policy["motion"]["action_frames"][1], "budget", f"$.gestures.{name}.frames", "action frame limit exceeded")
        for channel, track in gesture["tracks"].items():
            owner, separator, field = channel.rpartition(".")
            valid = bool(separator) and ((owner == "root" and field in ROOT_CHANNELS) or (owner == "face" and face is not None and field in FACE_CHANNELS) or (owner == "effects" and field in {"sweat", "sparkle"}) or (owner in parts and field in PART_CHANNELS))
            # This selected check admits declared missing anatomy with a named
            # fallback. R1c must prove the entire fallback playable and acyclic.
            waived = owner in gesture.get("needs", []) and gesture.get("fallback") in gestures
            problem_if(not valid and not waived, "invalid_channel", f"$.gestures.{name}.tracks.{channel}", "unknown target")
            keys = track["keys"] if isinstance(track, dict) else track
            require(len(keys) >= 2 and keys[0][0] == 0 and keys[-1][0] == 1, "track endpoints must span 0..1")
            require(all(a[0] < b[0] for a, b in zip(keys, keys[1:])), "track times must strictly increase")


def check_limits(policy, proposal):
    rows = {
        "active_parts": "Declared active parts, including attachment parts",
        "painted_items": "Expanded painted items, including face/effects",
        "paint_passes": "Fill/stroke/outline/glow passes",
        "path_numbers": "Expanded path numbers",
        "clip_applications": "Clip applications",
        "gradient_uses": "Gradient uses",
        "glow_emitters": "Glow emitters, including emissive face glyphs",
        "blur_design_units": "Blur radius in design units",
        "inflated_glow_area_ratio": "Sum of inflated glow rectangles / canvas area",
    }
    for key, title in rows.items():
        match = re.search(r"^\| " + re.escape(title) + r" \| ([\d.]+) \| ([\d.]+) \| ([\d.]+) \|$", proposal, re.M)
        require(match is not None, "missing proposal limit row: " + title)
        require([policy["bands"][band][key] for band in ("full", "small", "micro")] == [float(x) for x in match.groups()], "limit table differs: " + key)
    input_matches = {
        "utf8_bytes": (r"Input bounds: (\d+) KiB UTF-8 file", 1024),
        "nesting_depth": (r"KiB UTF-8 file, depth (\d+)", 1),
        "structural_nodes": (r"depth \d+, ([\d,]+) structural nodes", 1),
        "declared_parts": (r"structural nodes, (\d+) declared parts", 1),
        "moods": (r"declared parts, (\d+) moods", 1),
        "gestures": (r"moods, (\d+) gestures", 1),
        "keys_per_track": (r"gestures, (\d+) keys per track", 1),
        "tracks_per_gesture": (r"keys per track, (\d+) tracks per gesture", 1),
        "effect_triggers_per_gesture": (r"tracks per gesture, (\d+) effect triggers per gesture", 1),
    }
    for key, (pattern, multiplier) in input_matches.items():
        match = re.search(pattern, proposal)
        require(match is not None, "missing input limit: " + key)
        number = 10 if match[1] == "ten" else int(match[1].replace(",", ""))
        require(policy["input"][key] == number * multiplier, "input limit differs: " + key)
    require(policy["policy_version"] == 2 and policy["operation_manifest_version"] == 2 and policy["format_version"] == 1, "policy version differs")
    require(policy["status"] == "design_limits_not_measured_performance", "policy overstates evidence")
    require(policy["motion"]["key_time_range"] == [0, 1] and policy["motion"]["minimum_keys"] == 2, "track key limits differ")
    easing = re.search(r"Allowed easings (.*?)\. Their formulas", proposal).group(1).split("/")
    require(policy["motion"]["easings"] == easing, "easing vocabulary differs")
    require(policy["geometry"]["local_bounds"] == {"x": [-150, 150], "y": [-270, 30]}, "local frame bounds differ")
    require(policy["motion"]["action_frames"] == [1, 150] and "Any integer frame duration is 1..150" in proposal, "duration policy differs")
    require(policy["motion"]["frames_per_second"] == 30 and "at30fps" in proposal, "frame rate differs")
    require(policy["geometry"]["frame"] == [300, 300] and policy["geometry"]["ground_origin"] == [150, 270], "frame origin differs")
    require(policy["geometry"]["coordinate_range"] == [-4096, 4096] and "+/-4096" in proposal, "coordinate range differs")
    require(policy["geometry"]["scale_range"] == [-16, 16] and "scales within[-16,16]" in proposal, "scale range differs")
    require(policy["geometry"]["singular_determinant_below"] == 1e-12 and "|det|<1e-12" in proposal, "singular threshold differs")
    require(policy["core_moods"] == ["idle", "thinking", "happy", "worried", "celebrating"], "core moods differ")
    supported = re.search(r"Supported capabilities in0.1.0: (.*?)\. requires", proposal).group(1).split(", ")
    require(policy["capabilities"] == supported, "capabilities differ")
    unsupported = re.search(r"Reserved unsupported fields/capabilities: (.*?)\. Report", proposal).group(1).split(", ")
    require(policy["reserved_unsupported"] == unsupported, "reserved capabilities differ")
    require([(policy["bands"][b]["css_width_min_inclusive"], policy["bands"][b]["css_width_max_exclusive"], policy["bands"][b]["reference_css_width"]) for b in ("full", "small", "micro")] == [(128, None, 160), (48, 128, 96), (0, 48, 24)], "band policy differs")
    require(policy["contrast"] == {"minimum_meaningful_graphic": 3, "aim_new_art": 4.5}, "contrast policy differs")


def check():
    root = Path(__file__).resolve().parent
    proposal = (root.parent / "engine-format-proposal.md").read_text(encoding="utf-8")
    contract = (root / "contract.md").read_text(encoding="utf-8")
    blocks = {
        "resource": proposal[proposal.index("### 2.4 Resource and performance contract"):proposal.index("E5c must exit non-zero")],
        "format": proposal[proposal.index("## 3. The format (v1)"):proposal.index("#### R-settled desired state and delivery")],
        "accessory and capability": proposal[proposal.index("### 3.17 Addressable accessories"):proposal.index("### 3.19 Tessa face migration acceptance")],
        "resolution and validation": proposal[proposal.index("## 5. Families, identity and resolution"):proposal.index("## 8. R and host integration")],
    }
    for name, text in blocks.items():
        marker = "<!-- BEGIN source " + name + " rules -->\n"
        end = "<!-- END source " + name + " rules -->"
        require(contract.count(marker) == 1 and contract.count(end) == 1, "missing contract source block")
        require(contract.split(marker)[1].split(end)[0] == text, "contract drift: " + name)
    policy = load(root / "limits.json")
    check_limits(policy, proposal)
    manifest = load(root / "fixtures/manifest.json")
    require(manifest["status"] == "reference_expectations_not_validator_acceptance", "manifest overstates evidence")
    fixture_root = root / "fixtures"
    require((fixture_root / manifest["source"]["proposal"]).resolve() == (root.parent / "engine-format-proposal.md").resolve(), "manifest proposal pointer differs")
    ids, paths, valid, invalid = set(), set(), {}, []
    for fixture in manifest["fixtures"]:
        require(fixture["id"] not in ids and fixture["file"] not in paths, "duplicate manifest fixture")
        ids.add(fixture["id"])
        paths.add(fixture["file"])
        path = (fixture_root / fixture["file"]).resolve()
        require(path.is_relative_to(fixture_root), "fixture escapes its directory")
        require(path.is_file(), "missing fixture " + fixture["file"])
        if fixture["expected"] == "reject":
            invalid.append(fixture)
        else:
            require(fixture["expected"] == "valid_after_full_check", "unearned fixture acceptance")
            if fixture["kind"] == "character":
                totals = fixture["expanded_work_totals"]
                require(isinstance(totals, dict) and totals["file"] == "../budgets.json", "missing reference-count certificate")
            else:
                require(fixture["expanded_work_totals"] is None, "kit/family cannot have whole-character totals")
            data = load(path, policy["input"]["utf8_bytes"])
            if fixture["kind"] == "character":
                selected_character_checks(data, policy)
            valid[fixture["id"]] = data
    require(paths == {str(path.relative_to(fixture_root)) for path in fixture_root.rglob("*.json") if path.name != "manifest.json"}, "unlisted or missing JSON fixture")
    proposal_examples = [json.loads(block, object_pairs_hook=unique) for block in re.findall(r"```json\n(.*?)\n```", proposal, re.S)]
    for expected, fixture_id in zip(proposal_examples, ("classic", "screen", "tessa", "alpha_visor", "visorfolk")):
        require(valid[fixture_id] == expected, "extracted proposal data differs: " + fixture_id)
    require(len(proposal_examples) == 5, "proposal example inventory changed")
    for fixture in invalid:
        try:
            data = load(fixture_root / fixture["file"], policy["input"]["utf8_bytes"])
            selected_character_checks(data, policy)
        except Problem as error:
            require((error.code, error.path) == (fixture["code"], fixture["path"]), f"wrong expected diagnostic for {fixture['id']}: {error}")
        else:
            raise ValueError("invalid fixture was not rejected: " + fixture["id"])
    # Expected merge is checked against known source data, without pretending this
    # restricted reference calculation is the future general-purpose resolver.
    source, expected, family = valid["study_bot_source"], valid["study_bot_expected"], valid["visorfolk"]
    require(source["family_definition"] == family, "source family drift")
    merged = copy.deepcopy(source)
    merged["resolved"] = True
    merged["family_definition"] = {**{key: family[key] for key in ("id", "name", "description")}, "defaults": {}}
    merged["face"]["kit_definition"] = valid["screen"]
    for field in ("gestures", "palettes"):
        merged[field] = {**copy.deepcopy(family["defaults"][field]), **source[field]}
    merged["palette_sources"] = {"sea_glass": "character", "night_screen": "family"}
    require(merged == expected, "Study Bot expected snapshot differs from this specific merge")
    require(list(expected["gestures"]) == ["rock", "nod", "wave", "greet"], "gesture merge order differs")
    for name, target in (("nod", "nod_joint"), ("wave", "hand_r")):
        candidate = expected["gestures"][name]
        require(candidate["needs"] == [target] and candidate["fallback"] == "rock", "fallback expectation differs")
        require(target not in {part["id"] for part in expected["parts"]}, "family invented a missing part")
    require(expected["face"]["kit_definition"] == valid["screen"], "expected screen snapshot differs")
    probe = valid["anchor_probe"]
    require(probe["face"] is None, "faceless example acquired a face")
    pin, panel = probe["anchors"]["badge"], probe["parts"][0]
    scenarios = {case["id"]: case for case in manifest["scenarios"]}
    require(len(scenarios) == len(manifest["scenarios"]), "duplicate scenario ids")
    for case in manifest["scenarios"]:
        for field in ("file", "source", "expected_file"):
            if field in case:
                require(case[field] in paths, "scenario references an unlisted file")
    for name, at in (("anchor_default", pin["at"]), ("anchor_variant", pin["variants"]["raised"]["at"])):
        position = [a + b for a, b in zip(panel["at"], at)]
        require(position == scenarios[name]["expect"]["ground_relative_anchor"], "anchor numeric expectation differs")
    require(probe["accessories"]["badge"]["anchor"] == "badge" and probe["wear"] == ["badge"], "badge is not attached to the custom anchor")
    require("panel" in probe["lod"]["micro"]["hide"], "micro owner is not hidden")
    require(scenarios["faceless_moods"]["expect"]["statuses"] == {key: value["status"] for key, value in probe["moods"].items()}, "faceless status expectations differ")
    # Generated size and JSON-type cases keep the checked-in corpus small.
    generated = {case["id"]: case for case in manifest["generated_cases"]}
    oversize = copy.deepcopy(probe)
    case = generated["oversize_utf8"]
    oversize[case["construction"]["field"]] = case["construction"]["repeat"] * case["construction"]["count"]
    try:
        decode(json.dumps(oversize).encode("utf-8"), policy["input"]["utf8_bytes"])
    except Problem as error:
        require((error.code, error.path) == (case["code"], case["path"]), "oversize diagnostic differs")
    else:
        raise ValueError("oversize input was not rejected")
    require(isinstance(probe["parts"], list) and len(probe["parts"]) == 1 and probe["palette_sources"] == {}, "singleton array or empty object lost")
    discrete = generated["null_discrete_track_endpoints"]["construction"]["value"]["panel.variant"]
    require(discrete == {"mode": "set", "keys": [[0, None], [0.4, "raised", "step"], [1, None]]}, "mixed/null track rows differ")
    count_result = subprocess.run([sys.executable, "-I", *( ["-O"] if sys.flags.optimize else []), str(root / "budget.py"), "--check"], capture_output=True, text=True)
    require(count_result.returncode == 0, "accounting checks failed: " + (count_result.stderr or count_result.stdout).strip())
    counts = load(root / "budgets.json")
    require(counts["accounting_version"] == counts["operation_manifest_version"] == policy["operation_manifest_version"] == 2 and counts["policy_version"] == policy["policy_version"], "accounting/policy version pair differs")
    require(counts["method"] == "separable_componentwise_upper_bound", "accounting method differs")
    # Every distinct resolved character has exactly one row for each band.
    expected_counts = {f["expanded_work_totals"]["character"] for f in manifest["fixtures"]
                       if f["kind"] == "character" and f["expected"] != "reject"}
    require(len(counts["rows"]) == 3 * len(expected_counts), "reference-count inventory differs")
    require({(row["character"], row["band"]) for row in counts["rows"]} ==
            {(character, band) for character in expected_counts for band in ("full", "small", "micro")},
            "reference-count character/band inventory differs")
    for fixture in manifest["fixtures"]:
        if fixture.get("expected") != "reject" and fixture["kind"] == "character":
            require(len([row for row in counts["rows"] if row["character"] == fixture["expanded_work_totals"]["character"]]) == 3, "manifest count pointer misses a character")
    print(f"PASS: 4 synchronised core contract blocks; shared limit table; {len(valid)} reference files; {len(invalid)} deliberate invalid files with selected expected code/path; Study Bot snapshot; anchor coordinates; JSON-type cases.")
    print("NOT RUN: complete schema/validator, independent R1c/JS reproduction of reference counts and conservative area bounds, conservative fit/contrast, R/save/read, renderer/visuals, Shiny transport, performance, CRAN/gates, CI or tarball. Accounting-policy review remains before R1a acceptance; Q1/U1/I1 unchanged.")


if __name__ == "__main__":
    try:
        check()
    except (ValueError, KeyError, IndexError, TypeError, OSError, AttributeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1) from error
