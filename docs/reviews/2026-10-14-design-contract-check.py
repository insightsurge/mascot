"""Static checks for the revised design examples, not the future validator/renderer.

Run from the repository root:
    python3 -I docs/reviews/2026-10-14-design-contract-check.py

Uses only the Python standard library; writes nothing. A failed explicit check or
parse returns non-zero, including under python3 -O. Does not check expanded work budgets or appearance.
"""
from pathlib import Path
import json
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
        require(set(("idle", "thinking", "happy", "worried", "celebrating")) <= character["moods"].keys(), 'worried pupil offset differs')
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
    require({"CHOICE", "FREEZE", "U1", "C1", "C2", "C3", "C4", "C5"} <= graph.keys(), 'choice/freeze/case dependencies differ')
    require("B1" not in graph["I1"] and "R2" in graph["I1"], 'I1 must use R2 rather than B1')
    require({"M3", "M6", "S1/R5"} <= graph["CHOICE"], 'choice/freeze/case dependencies differ')
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
