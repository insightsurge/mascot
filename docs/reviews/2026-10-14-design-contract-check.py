"""Static checks for the revised design examples, not the future validator/renderer.

Run from the repository root:
    python3 -I docs/reviews/2026-10-14-design-contract-check.py

Uses only the Python standard library; writes nothing. A failed explicit check or
parse returns non-zero, including under python3 -O. Includes a limited queue reference model, not Shiny transport tests. Does not check expanded work budgets or appearance.
"""
from pathlib import Path
import json
import copy
import math
import re
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


# Reference model for selected design cases. This is not package code or a Shiny
# transport simulator; validators here cover only mood/preset membership.
class PendingCalls:
    independent = {"bubble", "status", "size", "placement", "motion"}

    @staticmethod
    def guard(patch):
        # Limited membership descriptor for this model, not a full prepare().
        descriptor = {}
        if patch.get("mood") not in (None, "idle", "thinking", "happy", "worried", "celebrating"):
            descriptor["mood"] = patch["mood"]
        if patch.get("theme") and patch["theme"].get("preset") not in (None, "original"):
            descriptor["preset"] = patch["theme"]["preset"]
        for field in ("gesture", "click"):
            if field in patch:
                descriptor[field] = patch[field]
        return json.dumps(descriptor, sort_keys=True)

    def __init__(self):
        self.sequence = 0
        self.context = None
        self.segments = [{"anchor": None, "buckets": {}}]
        self.owners = {}
        self.calls = {}

    def add(self, patch):
        self.sequence += 1
        sequence = self.sequence
        new_context = patch.get("character", self.context)
        changed = new_context != self.context
        if changed and len(self.segments) == 20:
            return False
        guard = self.guard(patch)
        independent = set(patch) <= self.independent
        if not independent and not changed:
            buckets = self.segments[-1]["buckets"]
            if guard not in buckets and len(buckets) == 20:
                return False
        if changed:
            self.context = new_context
            self.segments.append({"anchor": sequence, "buckets": {}})
        if independent:
            calls, owners, anchor = self.calls, self.owners, None
        else:
            segment = self.segments[-1]
            bucket = segment["buckets"].setdefault(guard, {"calls": {}, "owners": {}})
            calls, owners, anchor = bucket["calls"], bucket["owners"], segment["anchor"]
        calls[sequence] = copy.deepcopy(patch)  # Never split a retained mixed call.
        for field in patch:
            owners[field] = sequence
        keep = set(owners.values()) | ({anchor} if anchor is not None else set())
        for old in list(calls):
            if old not in keep:
                del calls[old]
        return True

    def retained(self):
        calls = dict(self.calls)
        for segment in self.segments:
            for bucket in segment["buckets"].values():
                calls.update(bucket["calls"])
        return sorted(calls.items())

    def dispatch(self, capacity):
        batch = self.retained()[:capacity]
        emitted = {sequence for sequence, _ in batch}
        for calls, owners in [(self.calls, self.owners)] + [
            (bucket["calls"], bucket["owners"]) for segment in self.segments
            for bucket in segment["buckets"].values()
        ]:
            for sequence in emitted:
                calls.pop(sequence, None)
            for field in list(owners):
                if owners[field] in emitted:
                    del owners[field]
        for segment in self.segments:
            if segment["anchor"] in emitted:
                segment["anchor"] = None
        for segment in self.segments:
            segment["buckets"] = {guard: bucket for guard, bucket in segment["buckets"].items()
                                  if bucket["calls"]}
        return batch


def model_fallback(characters, old_character, mood, target):
    visited = set()
    while mood not in characters[target]["moods"]:
        if mood in visited:
            return "idle"
        visited.add(mood)
        mood = characters.get(old_character, {}).get("moods", {}).get(mood, {}).get("fallback", "idle")
    return mood


def model_apply(characters, state, patch):
    target = patch.get("character", state["character"])
    if target not in characters:
        return dict(state), False
    if "mood" in patch and patch["mood"] not in characters[target]["moods"]:
        return dict(state), False
    theme = patch.get("theme")
    if theme and theme.get("preset") not in (None, "original") and theme["preset"] not in characters[target].get("palettes", {}):
        return dict(state), False
    next_state = dict(state)
    next_state.update(patch)
    if "character" in patch and "mood" not in patch:
        next_state["mood"] = model_fallback(characters, state["character"], state["mood"], target)
    return next_state, True


def model_restore(characters, ui, checkpoint, owned):
    result = dict(ui)
    for field in owned:
        if field != "gesture":
            result[field] = checkpoint[field]
    if "character" in owned or "mood" in owned:
        result["mood"] = model_fallback(
            characters, checkpoint["character"], checkpoint["mood"], result["character"]
        )
    return result


def model_liveness(current, mount, lifecycle):
    if current is None or mount > current[0]:
        return mount, lifecycle
    if mount < current[0]:
        return current
    return mount, "unmounted" if "unmounted" in (current[1], lifecycle) else "ready"


def check_queue_model(characters):
    baseline = {"character": "tessa", "mood": "idle", "bubble": "Baseline", "status": "Ready", "theme": None}
    cases = []
    buffer = PendingCalls()
    # No mount and a full wire window both supply zero dispatch capacity.
    for index in range(1, 1001):
        require(buffer.add({"status": str(index)}), "ordinary stalled call rejected")
    require(len(buffer.retained()) == 1, "ordinary stalled calls were not compacted")
    require(buffer.dispatch(0) == [] and len(buffer.retained()) == 1, "full window lost buffered state")
    state = dict(baseline)
    for _, patch in buffer.dispatch(20):
        state, accepted = model_apply(characters, state, patch)
        require(accepted, "valid status rejected")
    require(state["status"] == "1000", "remount did not receive newest buffered status")
    cases.append("1000 stalled updates")

    buffer = PendingCalls()
    buffer.add({"bubble": "Earlier"})
    buffer.add({"theme": {"preset": "ocean"}, "bubble": "Hi"})
    state = dict(baseline)
    for _, patch in buffer.dispatch(20):
        state, _ = model_apply(characters, state, patch)
    require(state["bubble"] == "Earlier" and state["theme"] is None, "invalid preset leaked coupled bubble")
    cases.append("invalid preset whole-call rejection")

    buffer = PendingCalls()
    buffer.add({"mood": "not_a_mood", "bubble": "Hi"})
    buffer.add({"status": "Later"})
    state = dict(baseline)
    for _, patch in buffer.dispatch(20):
        state, _ = model_apply(characters, state, patch)
    require(state["bubble"] == "Baseline" and state["mood"] == "idle" and state["status"] == "Later",
            "invalid mood leaked fields or discarded a separate valid call")
    cases.append("invalid mood preserves unrelated call")

    buffer = PendingCalls()
    buffer.add({"theme": {"preset": "ocean"}, "bubble": "Hi", "status": "Bad"})
    buffer.add({"status": "Good"})
    retained = buffer.retained()
    require("status" in retained[0][1] and "theme" in retained[0][1], "mixed guard was split by an overwrite")
    state = dict(baseline)
    for _, patch in buffer.dispatch(20):
        state, _ = model_apply(characters, state, patch)
    require(state["status"] == "Good" and state["bubble"] == "Baseline", "partial ownership leaked a rejected field")
    cases.append("overwritten field retains complete guard")

    buffer = PendingCalls()
    for index in range(19):
        target = "alpha_visor" if index % 2 == 0 else "tessa"
        require(buffer.add({"character": target}), "character segment rejected within bound")
    before = buffer.retained()
    require(not buffer.add({"character": "tessa", "bubble": "Overflow"}), "segment overflow accepted")
    require(buffer.retained() == before, "segment overflow partially changed buffer")
    field_count = 10
    require(len(before) <= 20 * (20 * field_count + 1) + field_count, "whole-call buffer exceeds stated bound")
    cases.append("character order and atomic segment bound")

    buffer = PendingCalls()
    buffer.add({"theme": {"preset": "sea_glass"}, "bubble": "Earlier"})
    buffer.add({"theme": {"preset": "ocean"}, "bubble": "Hi"})
    state = dict(baseline, character="alpha_visor")
    for _, patch in buffer.dispatch(20):
        state, _ = model_apply(characters, state, patch)
    require(state["bubble"] == "Earlier" and state["theme"] == {"preset": "sea_glass"},
            "new invalid guard erased a valid older pending candidate")
    cases.append("different guards preserve valid predecessor")
    buffer = PendingCalls()
    for index in range(20):
        require(buffer.add({"theme": {"preset": f"uncertain_{index}"}}), "guard rejected within bound")
    before = buffer.retained()
    require(not buffer.add({"theme": {"preset": "uncertain_overflow"}, "bubble": "Overflow"}), "guard bound ignored")
    require(buffer.retained() == before, "guard capacity rejection was partial")
    cases.append("atomic unresolved-guard bound")
    buffer.dispatch(20)
    require(buffer.add({"theme": {"preset": "fresh_after_drain"}}), "drained guards still consume capacity")
    cases.append("drained guard capacity released")
    buffer = PendingCalls()
    for index in range(1000):
        require(buffer.add({"theme": {"preset": "ocean"}, "bubble": str(index)}), "identical guard failed to compact")
    require(len(buffer.retained()) == 1, "identical guard created an unbounded history")
    cases.append("1000 identical mixed guards")
    buffer.dispatch(20)
    require(buffer.add({"theme": {"preset": "new_guard_after_dispatch"}}), "empty bucket retained capacity")
    cases.append("empty guard capacity released")

    buffer = PendingCalls()
    patch = {"theme": {"preset": "ocean"}, "bubble": "Hi"}
    buffer.add(patch)
    patch["theme"]["preset"] = "changed_outside_queue"
    require(buffer.retained()[0][1]["theme"]["preset"] == "ocean", "buffered original was mutated externally")
    cases.append("immutable original patch")
    lifecycle = model_liveness(None, 1, "ready")
    lifecycle = model_liveness(lifecycle, 1, "unmounted")
    require(model_liveness(lifecycle, 1, "ready") == (1, "unmounted"), "old ready revived removed mount")
    lifecycle = model_liveness(lifecycle, 2, "ready")
    require(model_liveness(lifecycle, 1, "unmounted") == (2, "ready"), "old unsubscribe hid new mount")
    cases.append("out-of-order lifecycle state")

    ui = dict(baseline)
    checkpoint = dict(baseline, character="alpha_visor", mood="processing", bubble="Saved", theme=None)
    restored = model_restore(characters, ui, checkpoint, {"character", "bubble"})
    require(restored["character"] == "alpha_visor" and restored["mood"] == "processing", "server character lost remount precedence")
    require(restored["bubble"] == "Saved", "server-owned bubble lost")
    cases.append("server character wins")
    restored = model_restore(characters, ui, checkpoint, {"mood"})
    require(restored["character"] == "tessa" and restored["mood"] == "thinking", "UI winner or retained-mood fallback differs")
    cases.append("UI character wins and mood falls back")
    ui = dict(baseline, character="alpha_visor", mood="happy", theme={"preset": "sea_glass"})
    restored = model_restore(characters, ui, checkpoint, {"theme"})
    require(restored["character"] == "alpha_visor" and restored["mood"] == "happy" and restored["theme"] is None,
            "unowned UI values or explicit server theme reset lost")
    cases.append("UI defaults and owned reset")
    require("gesture" not in model_restore(characters, ui, dict(checkpoint, gesture="nod"), {"gesture"}),
            "checkpoint gesture replayed")
    cases.append("no gesture replay")
    print(f"PASS: {len(cases)} selected Python queue/atomicity/precedence model cases; not R/JS/Shiny transport tests.")



def check():
    docs = Path("docs")
    text = (docs / "engine-format-proposal.md").read_text(encoding="utf-8")
    values = [json.loads(block, object_pairs_hook=unique) for block in
              re.findall(r"```json\n(.*?)\n```", text, re.S)]
    require(len(values) == 5, "expected five complete JSON examples")
    classic, screen, tessa, robot, family = values
    require([v["id"] for v in values] == ["classic", "screen", "tessa", "alpha_visor", "visorfolk"], 'JSON example ids/order differ')
    for name in ("determined", "angry", "frown", "worried", "sad"):
        style = classic["brow_styles"][name]
        numbers = [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", style["d"])]
        require(len(numbers) == 4 and numbers[0] < 0 < numbers[2], 'brow endpoints must straddle the right-eye origin')
        inner_higher = numbers[1] < numbers[3]
        require(inner_higher == (name in ("worried", "sad")), name)
        require(style["width"] == 5, 'slanted brow width must be five')
    require(classic["defaults"] == {"eyes": "open", "mouth": "smile", "brows": "none", "blush": 1}, 'classic defaults differ')
    require(classic["eye_styles"]["worried"]["pupil"]["at"] == [0, -2], 'worried pupil offset differs')
    for name, radii in (("happy", [15, 6]), ("closed", [15, 3])):
        lashes = classic["eye_styles"][name]["lashes"]
        require(lashes["radii"] == radii, 'lash radii differ')
        require(all(math.isclose(a, math.radians(b)) for a, b in zip(lashes["angles"], [-32, -62])), 'happy/closed lash angles differ')
    for kit in (classic, screen):
        require("closed" in kit["eye_styles"], 'kit needs a closed eye style')
        for field, styles in (("eyes", "eye_styles"), ("mouth", "mouth_styles"), ("brows", "brow_styles")):
            require(kit["defaults"][field] in kit[styles], 'kit default style is missing')
        for mouth in kit["mouth_styles"].values():
            require(len(mouth["box"]) == 2 and min(mouth["box"]) > 0, 'mouth box must have two positive half-sizes')
            require(all(item["shape"] in ("path", "ellipse", "polyline") for item in mouth["items"]), 'mouth contains an unsupported primitive')
        for effect in kit["effects"].values():
            modes = {"sweat_drop": ("progress", "track"), "sparkle_star": ("pulse", "track")}
            require(effect["mode"] in modes[effect["op"]], 'effect operation/mode pair is invalid')
            if effect["mode"] != "track":
                require("frames" not in effect and "tracks" not in effect, 'non-track effect carries timing fields')
    # Half-size mapping preserves the old flat mouth's endpoints and width.
    flat = classic["mouth_styles"]["flat"]
    coords = [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", flat["items"][0]["d"])]
    require([coords[i] * flat["box"][i % 2] for i in range(4)] == [-11, 8, 11, 8], 'flat mouth endpoints differ')
    require(flat["items"][0]["width"] == 3.5, 'flat mouth stroke width differs')
    for name in ("grit", "determined"):
        require(all(item["join"] == "miter" for item in classic["mouth_styles"][name]["items"]),
                f"{name} mouth must preserve miter joins")
    require(any(pair["fg"] == "glow" and pair["bg"] == "screen"
                and pair.get("bg_paint") == "visor_glass" for pair in robot["contrast"]),
            "alpha_visor must declare the visor background paint")
    for character, kit in ((tessa, classic), (robot, screen)):
        require(character["resolved"] and character["face"]["kit_definition"] == kit, 'embedded resolved kit differs')
        require(character["family_definition"]["defaults"] == {}, 'resolved family snapshot carries defaults')
        require(set(character.get("palettes", {})) == set(character["palette_sources"]), 'palette provenance keys differ')
        parts = {p["id"] for p in character["parts"]}
        require(len(parts) == len(character["parts"]), 'duplicate part ids')
        require(all(p.get("parent", "root") in parts | {"root"} for p in character["parts"]), 'part parent is missing')
        require(all(a["part"] in parts for a in character["anchors"].values()), 'anchor owner is missing')
        require(set(("idle", "thinking", "happy", "worried", "celebrating")) <= character["moods"].keys(), 'character lacks a core mood')
        for gesture in character["gestures"].values():
            for track in gesture["tracks"].values():
                keys = track if isinstance(track, list) else track["keys"]
                require(keys[0][0] == 0 and keys[-1][0] == 1, 'track must run from zero to one')
                require(all(a[0] < b[0] for a, b in zip(keys, keys[1:])), 'track keys are not strictly increasing')
    require(robot["palettes"] == family["defaults"]["palettes"], 'robot palettes differ from the family fixture')
    require(all(origin == "family" for origin in robot["palette_sources"].values()), 'robot palette origin must be family')
    require(all(channel in {"root.rotate", "root.lift", "root.scale_x", "root.scale_y"} for gesture in family["defaults"]["gestures"].values()
               for channel in gesture["tracks"]), 'family gesture uses an unsupported root channel')
    section = text.split("## 9.")[1].split("T1 canonical")[0]
    prerequisites = {}
    for line in section.splitlines():
        if not line.startswith("| ") or line.startswith("| Unit"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        require(len(cells) == 4, "malformed build-plan row")
        unit, dependency_cell = cells[:2]
        require(unit not in prerequisites, f"duplicate unit {unit}")
        prerequisites[unit] = dependency_cell
    graph = {}
    for unit, dependency_cell in prerequisites.items():
        tokens = [token.strip() for token in dependency_cell.split(",")]
        require(all(tokens), f"empty prerequisite token for {unit}")
        require(len(tokens) == len(set(tokens)), f"duplicate prerequisite for {unit}")
        if tokens == ["none"]:
            graph[unit] = set()
            continue
        for token in tokens:
            require(token in prerequisites, f"unknown prerequisite {token!r} for {unit}")
        graph[unit] = set(tokens)
    require({"Q1", "CHOICE", "FREEZE", "U1", "C1", "C2", "C3", "C4", "C5"} <= graph.keys(), 'choice/freeze/case dependencies differ')
    require("B1" not in graph["I1"] and "R2" in graph["I1"], 'I1 must use R2 rather than B1')
    require({"M3", "M6", "S1/R5"} <= graph["CHOICE"], 'choice/freeze/case dependencies differ')
    require("Q1" in graph["U1"], "U1 must depend on independent queue approval")
    require("Q1" not in graph["R1a"] and "Q1" not in graph["R1b"], "queue gate must not block core contracts/validator")
    visiting, done = set(), set()

    def visit(node):
        require(node in graph, f"unknown prerequisite {node}")
        require(node not in visiting, f"dependency cycle {node}")
        if node in done:
            return
        visiting.add(node)
        for dependency in graph[node]:
            visit(dependency)
        visiting.remove(node)
        done.add(node)

    for node in graph:
        visit(node)
    check_queue_model({character["id"]: character for character in (tessa, robot)})
    builder = (docs / "r-builder-proposal.md").read_text(encoding="utf-8")
    require('mode = NULL' in builder and 'list(c(' not in builder, 'builder track-mode or list-row contract differs')
    require('gestures = list(nod, wave, greet)' in builder, 'builder local fallback candidates differ')
    require('mascot_add_anchor(character, anchor,' in builder, 'anchor editor signature differs')
    for name in ("engine-format-proposal.md", "r-builder-proposal.md", "r-api-decisions-0.1.0.md"):
        require(all(line == line.rstrip() for line in (docs / name).read_text(encoding="utf-8").splitlines()), 'document has trailing whitespace')
    print(f"PASS: five duplicate-free JSON examples; strict prerequisite tokens; optimisation-safe checks; brow slopes, selected face/mouth data, kit snapshots, palette provenance, root family gestures, references/endpoints and {len(graph)}-node acyclic plan.")
    print("NOT RUN: full format/work-budget validator, R, gates, renderer, screenshots, performance, CI or tarball.")


if __name__ == "__main__":
    try:
        check()
    except (ValueError, KeyError, IndexError, TypeError, OSError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1) from error
