# mascot 0.0.2.9000

* `mascot_popup_menu()` gains `direction`: the menu opens from the mascot's on-screen position towards `"auto"` (the default), `"top"`, `"bottom"`, `"left"` or `"right"`, and falls back to another side when there is no room (#225).
* Mascot menus open next to the character instead of above its empty canvas area, and only one popup shows at a time: opening the menu closes the bubble, and a new bubble closes the menu (#225).
* `mascot()` and `mascot_placement()` float in the bottom-right corner by default, as an assistant in the corner of the app; use `placement = "inline"` to place a mascot in the page (#223).
* `mascot_placement()` gains `drag`: visitors can drag a floating mascot, which snaps to the nearest corner or stays where dropped; the server receives `input$<id>_position` (#220).
* `mascot_size()` loses `simplify_when_small`, and characters no longer have a separate small-size drawing: below 72 pixels the simplified face looked worse than the full one, so every size now draws the full character (#219).
* `mascot_placement()` takes one `position` (`"inline"` or a corner) and `minimise`, replacing `floating` + `position`, so the two can no longer contradict each other; shortcuts are unchanged (#215).
* `mascot("helper")` without an `id` now explains that the first argument is the character and shows `mascot(id = "helper")` (#215).
* In Shiny development mode, an update that never finds its mascot because of a namespace slip (`helper` versus `first-helper`) warns once and says how to fix it: `ns()` in the module UI, or update from inside the module (#215).
* The speech bubble follows the page's light/dark signal like the drawing; a dark system setting alone keeps it light (#215).
* The long-task example runs its slow step with `shiny::ExtendedTask`, so the app stays responsive; every example has a title, a one-line purpose and a light/dark switch (#215).
* `updateMascot()` keeps the latest state for a later first mascot and replacements with the same id (#193).
* Timed bubbles pause while a mascot is hidden and resume with the remaining time (#199).
* `updateMascot()` keeps the latest early gesture and plays it once when the mascot appears (#200).

* `mascot_theme()` follows the page by default; absent a page signal, it uses light mode (#213).
* Themes colour a character through declared follow rules; supplied roles stay exact, and `mascot_colour_roles()` lists leaders and shades (#213).
* `bs_theme()` contrast checks and `mascot_preview()` use the light and dark backgrounds separately; contrast warnings have class `mascot_contrast` (#213).
* `mascot_popup_menu()` always supports Enter and Space on its toggle; remove the unreleased `key_bindings` argument (#213).
* Mascot helpers gain readable `format()` and `print()` methods (#213).
* Bundled examples are self-contained, copyable `app.R` files using `bslib` cards (#213).


* `mascot_preview()` compares moods, light/dark colours and sizes on an offline page, with contrast findings on the page and in R (#175).

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

* `mascot()` and `updateMascot()` accept pixel or percentage sizes, with narrow-screen sizes through `mascot_size()` (#201).
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
