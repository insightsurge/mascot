"""Static checks for the revised design examples, not the future validator/renderer.

Run from the repository root:
    python3 -I docs/reviews/2026-10-14-design-contract-check.py

Uses only the Python standard library; writes nothing. A failed assertion or
parse returns non-zero. Does not check expanded work budgets or appearance.
"""
from pathlib import Path
import json
import math
import re


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
    assert len(values) == 5, "expected five complete JSON examples"
    classic, screen, tessa, robot, family = values
    assert [v["id"] for v in values] == ["classic", "screen", "tessa", "alpha_visor", "visorfolk"]
    for name in ("determined", "angry", "frown", "worried", "sad"):
        style = classic["brow_styles"][name]
        numbers = [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", style["d"])]
        assert len(numbers) == 4 and numbers[0] < 0 < numbers[2]
        inner_higher = numbers[1] < numbers[3]
        assert inner_higher == (name in ("worried", "sad")), name
        assert style["width"] == 5
    assert classic["defaults"] == {"eyes": "open", "mouth": "smile", "brows": "none", "blush": 1}
    assert classic["eye_styles"]["worried"]["pupil"]["at"] == [0, -2]
    for name, radii in (("happy", [15, 6]), ("closed", [15, 3])):
        lashes = classic["eye_styles"][name]["lashes"]
        assert lashes["radii"] == radii
        assert all(math.isclose(a, math.radians(b)) for a, b in zip(lashes["angles"], [-32, -62]))
    for kit in (classic, screen):
        assert "closed" in kit["eye_styles"]
        for field, styles in (("eyes", "eye_styles"), ("mouth", "mouth_styles"), ("brows", "brow_styles")):
            assert kit["defaults"][field] in kit[styles]
        for mouth in kit["mouth_styles"].values():
            assert len(mouth["box"]) == 2 and min(mouth["box"]) > 0
            assert all(item["shape"] in ("path", "ellipse", "polyline") for item in mouth["items"])
        for effect in kit["effects"].values():
            modes = {"sweat_drop": ("progress", "track"), "sparkle_star": ("pulse", "track")}
            assert effect["mode"] in modes[effect["op"]]
            if effect["mode"] != "track":
                assert "frames" not in effect and "tracks" not in effect
    # Half-size mapping preserves the old flat mouth's endpoints and width.
    flat = classic["mouth_styles"]["flat"]
    coords = [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?", flat["items"][0]["d"])]
    assert [coords[i] * flat["box"][i % 2] for i in range(4)] == [-11, 8, 11, 8]
    assert flat["items"][0]["width"] == 3.5
    for character, kit in ((tessa, classic), (robot, screen)):
        assert character["resolved"] and character["face"]["kit_definition"] == kit
        assert character["family_definition"]["defaults"] == {}
        assert set(character.get("palettes", {})) == set(character["palette_sources"])
        parts = {p["id"] for p in character["parts"]}
        assert len(parts) == len(character["parts"])
        assert all(p.get("parent", "root") in parts | {"root"} for p in character["parts"])
        assert all(a["part"] in parts for a in character["anchors"].values())
        assert set(("idle", "thinking", "happy", "worried", "celebrating")) <= character["moods"].keys()
        for gesture in character["gestures"].values():
            for track in gesture["tracks"].values():
                keys = track if isinstance(track, list) else track["keys"]
                assert keys[0][0] == 0 and keys[-1][0] == 1
                assert all(a[0] < b[0] for a, b in zip(keys, keys[1:]))
    assert robot["palettes"] == family["defaults"]["palettes"]
    assert all(origin == "family" for origin in robot["palette_sources"].values())
    assert all(channel.startswith("root.") for gesture in family["defaults"]["gestures"].values()
               for channel in gesture["tracks"])
    section = text.split("## 9.")[1].split("T1 canonical")[0]
    graph = {}
    for line in section.splitlines():
        if not line.startswith("| ") or line.startswith("| Unit"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        graph[cells[0]] = set(re.findall(r"\b(?:R\d[a-z]?|E\d[a-z]?|T\d|B\d|I\d|U\d|M\d[a-z]?|MR|C\d|S\d|CHOICE|FREEZE)(?:/R\d)?\b", cells[1]))
    assert {"CHOICE", "FREEZE", "U1", "C1", "C2", "C3", "C4", "C5"} <= graph.keys()
    assert "B1" not in graph["I1"] and "R2" in graph["I1"]
    assert {"M3", "M6", "S1/R5"} <= graph["CHOICE"]
    visiting, done = set(), set()

    def visit(node):
        assert node in graph, f"unknown prerequisite {node}"
        assert node not in visiting, f"dependency cycle {node}"
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
    assert 'mode = NULL' in builder and 'list(c(' not in builder
    assert 'gestures = list(nod, wave, greet)' in builder
    assert 'mascot_add_anchor(character, anchor,' in builder
    for name in ("engine-format-proposal.md", "r-builder-proposal.md", "r-api-decisions-0.1.0.md"):
        assert all(line == line.rstrip() for line in (docs / name).read_text(encoding="utf-8").splitlines())
    print(f"PASS: five duplicate-free JSON examples; brow slopes, selected face/mouth data, kit snapshots, palette provenance, root family gestures, references/endpoints and {len(graph)}-node acyclic plan.")
    print("NOT RUN: full format/work-budget validator, R, gates, renderer, screenshots, performance, CI or tarball.")


if __name__ == "__main__":
    check()
