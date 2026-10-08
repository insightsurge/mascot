# mascot 0.0.2.9000

* `mascot_preview()` compares moods, light/dark colours and small drawings on an offline page, with contrast findings on the page and in R (#175).

* `mascot_examples()` lists five bundled Shiny apps, with a shared layout and separate scenarios for learning each feature (#177).
* `mascot_example()` opens the requested app or returns its source path without copying files (#178).
* The Get started article walks through the existing helpers, modules and personalising Tessa, with runnable examples and screenshots of themes and menu actions (#177).

* Mascot menus fit short screens and keep keyboard focus on the visible control after placement changes (#208).
* Minimise controls use a neutral glowing border, appear on hover or keyboard focus, and hide while the mascot menu is open; touch controls and restore remain reachable (#208).
* Shiny examples show live theme and motion settings, a colour reset and a complete module menu (#208).

* `mascot_popup_menu()` adds app-defined choices through `popup_menu`, with a Shiny input for every choice, optional keyboard controls and a held look-up pose while open (#143).

* `mascot()` and `updateMascot()` gain `motion` to stop animation or, with
  `mascot_motion(swap = FALSE)`, make character changes instant. The visitor's
  reduced-motion preference is always honoured (#203).

* `mascot()` and `updateMascot()` accept brand colours, named colour lists and light/dark themes through `mascot_theme()`; experimental CSS variables follow the source page (#202).
* `mascot_colour_roles()` lists each character's original colours and brand slots (#202).

* `mascot()` and `updateMascot()` accept pixel or percentage sizes, with narrow-screen sizes and a simpler small drawing through `mascot_size()` (#201).
* `mascot_placement()` places mascots inline or in a floating corner, above Shiny notifications; optional minimise controls keep updates and messages ready for return (#201).

* `mascot()` and `updateMascot()` gain message bubbles with `mascot_bubble()`: escaped text, explicit HTML or
  self-contained tags, a close button, and a timer that pauses on hover or focus; `duration = Inf` (or `NULL`) keeps a
  message until it is closed. Space is reserved above the mascot, so a bubble never moves the page (#196).
* `updateMascot()` gains one-off nod and wave gestures; `mascot_gesture()` chooses one and `mascot_gestures()` lists them (#196).

* `mascot()` adds Tessa to a page with a mood and a status line that follows the mood or shows your own text (#190).
* `updateMascot()` changes a mascot's character, mood and status together, including inside Shiny modules (#190).
* `mascot_character()`, `mascot_mood()` and `mascot_status()` describe a mascot's settings;
  `mascot_moods()` lists the available moods and what they mean (#190).

# mascot 0.0.2

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
* Characters can be swapped with a short hand-over: the old character waves and fades out, then the
  new one fades in and waves (about two seconds; a plain swap with reduced motion or when switched off).
  Quick repeated swaps end on the newest character only, and a swap that cannot be drawn changes
  nothing (#147).

# mascot 0.0.1

* First development version: the package skeleton, with no user-facing features yet (#23).
