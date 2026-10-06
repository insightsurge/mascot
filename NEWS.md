# mascot 0.0.0.9001

* The drawing engine starts: Tessa, a hexagon character first drawn for an earlier project, is drawn in
  the browser exactly as there. No exported functions yet (#9, #24).
* Characters are described as data: Tessa's look and her five moods live in
  `inst/characters/tessa.json`, and the engine draws a character from such a description (#66).
* The engine draws any character from its description: optional arms and feet, a face that can sit
  anywhere, shared attachment points, several accessories at once, colours set per drawing (hex or
  `rgb()`), and a small-size drawing that keeps the mood readable at 48 pixels (#52).
* Moods move: after a change of mood the character wiggles (or hops) and the face changes halfway; it
  blinks and breathes for up to five seconds after each change, then rests; it can nod and wave; and
  with reduced motion switched on, the face simply changes. A held pose (for example looking up) stays
  until cleared (#27).

# mascot 0.0.0.9000

* First development version: the package skeleton, with no user-facing features yet (#23).
