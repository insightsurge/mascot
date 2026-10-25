# mascot 0.1.0

First CRAN release.

mascot adds a live character to a Shiny app or a Quarto page. The character is drawn in code in the browser, shows a mood that you set from R, and gives a short wiggle when the mood changes. Status text sits beside every mascot, so the face never carries meaning alone. You can design your own characters as well as use the built-in ones.

## Mascots in apps and pages

* `mascot()` places a mascot in a Shiny UI or a rendered Quarto or R Markdown page, floating in a corner or inline in the page. `update_mascot()` changes its mood, status, bubble, gesture, size, placement, theme, motion or character from the Shiny server, also inside modules, `golem` and rhino-style apps.

* Each `mascot()` argument takes a plain value or a helper: `mascot_mood()`, `mascot_status()`, `mascot_bubble()` (a speech bubble), `mascot_gesture()` (a nod or a wave), `mascot_size()`, `mascot_placement()` (corners, inline, minimising and dragging; `drag = "free"` is *experimental*), `mascot_theme()`, `mascot_motion_settings()`, `mascot_character()`, and for clicks `mascot_action()` (one action) or `mascot_popup_menu()` (a menu).

* Four built-in characters: Tessa and Sela (two hexagons, stable), and Knurl (a robot) and Neer (a water elemental), both *experimental*. They share five moods, `"idle"`, `"thinking"`, `"happy"`, `"worried"` and `"celebrating"`, and the `nod` and `wave` gestures. `mascot_characters()`, `mascot_families()`, `mascot_moods()`, `mascot_gestures()`, `mascot_anchors()`, `mascot_palettes()` and `mascot_colour_roles()` list what each character offers.

* Colours: each character has named palettes, and `mascot_theme()` takes your own colours for light and dark mode, the primary and secondary colours of a `bslib::bs_theme()`, or CSS variables. Two of these are *experimental*: which parts of a character a `bs_theme()` colours, and CSS variables, may change in a later release. Mascots follow the page's light or dark mode. `?mascot_styling` lists the classes and CSS variables you can style.

## Accessibility

* A mascot without a click is a picture; with `mascot_action()` or `mascot_popup_menu()` it is a button with a name for screen readers, works with the keyboard and sets `input$<id>_click` or `input$<id>_menu`.

* The visitor's reduced-motion setting always wins: the face changes without the wiggle. `mascot_motion_settings()` and `motion = FALSE` turn movement down further.

## The studio and examples

* `mascot_studio()` (*experimental*) opens a local app that demonstrates every exported function and argument with every character: change the controls, watch the mascot and copy the matching R code. `mascot_studio(view = "theme")` opens a page for theming one character, with a contrast check of every mood in light and dark mode.

* `mascot_examples()` lists the bundled example apps and `mascot_example()` runs one: checking a form, showing a long task's progress, working in modules, theming, and apps built with `golem` or in a rhino-style structure.

* `mascot_preview()` (*experimental*) shows an offline page that compares a character's moods and sizes in light and dark colours, with contrast findings.

## Your own characters (experimental)

* A character is a JSON file in character format version 1. `mascot_read_character()` reads one and `mascot_check_character()` checks one, with messages that say what to fix; pass the result to `mascot_character()`. The "Write your own character" article walks through it. These functions and the format are *experimental*: the functions' arguments, results and messages may change in a later release, and what the format accepts may grow, while format version 1 files keep loading.

## Built for `GxP` work

* Everything a mascot needs ships with the package: nothing is loaded from the internet, so apps work offline and behind firewalls. The drawing is deterministic: the engine never reads the clock to draw and uses no random numbers, so the same state always draws the same picture. Status text sits beside every mascot, and reduced motion is honoured.

## Before 0.1.0

* Versions 0.0.1 and 0.0.2 were development milestones on GitHub, not released on CRAN, and exported no R functions. While 0.1.0 was developed, some functions and arguments were renamed or removed, so code written against a development version installed from GitHub may need small changes. The pull requests on GitHub record each change.

# mascot 0.0.2

Development milestone; not released on CRAN.

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

Development milestone; not released on CRAN.

* First development version: the package skeleton, with no user-facing features yet (#23).
