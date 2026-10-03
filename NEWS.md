# mascot 0.0.0.9001

* The drawing engine starts: Tessa, the R Engineering Playbook's hexagon character, is drawn in the
  browser exactly as on the playbook site. No exported functions yet (#9, #24).
* Characters are described as data: Tessa's look and her five moods live in
  `inst/characters/tessa.json`, and the engine draws a character from such a description (#66).
* The engine draws any character from its description: optional arms and feet, a face that can sit
  anywhere, shared attachment points, several accessories at once, colours set per drawing (hex or
  `rgb()`), and a small-size drawing that keeps the mood readable at 48 px (#52).

# mascot 0.0.0.9000

* First development version: the package skeleton, with no user-facing features yet (#23).
