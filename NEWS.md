# mascot (development version)

## New features

* `mascot()` adds a character with a mood, a status line and an optional message bubble to a Shiny app or Quarto page. It floats in the bottom-right corner by default (#190, #223).
  * `placement = "inline"` places it in the page flow; a corner name or `mascot_placement()` gives the other options (#223).
  * `bubble` shows a message (#196), `size` takes pixels, a percentage or `mascot_size()` (#201), `theme` takes colours, a `bslib::bs_theme()` or `mascot_theme()` (#202), `motion = FALSE` stops animation (#203), and `popup_menu` adds a click menu (#143, #225).

* `mascot_bubble()` sets a speech bubble with escaped text, or HTML only through `htmltools::HTML()` or tags (#196).
  * `duration` is in seconds (default `5`); `duration = Inf` or `NULL` keeps the bubble until it is closed, replaced or cleared. `closable = FALSE` hides the close button; Escape still closes the bubble (#196).
  * The countdown pauses while the mascot is hidden or minimised, while the pointer is over the bubble, and while keyboard focus is inside the mascot, then resumes with the time left (#196, #199, #229).
  * Space is reserved above the mascot, so a bubble never moves the page (#196).
  * While a bubble shows, the mascot looks towards it: up when it is above, down when it is below a top-corner mascot. Only the pupils move, at once and without animation, so eyes without visible pupils keep their look (#241).

* `mascot_character()` chooses a character by name. Only Tessa is built in (#190).

* `mascot_colour_roles()` lists a character's colour roles with their colours, the leaders they follow and their shade (#202, #213).

* `mascot_example()` runs one bundled example app, or with `run = FALSE` returns the path to its `app.R` without copying any file (#178).

* `mascot_examples()` lists the five bundled Shiny apps in teaching order. The studio comes first; each other app is a copyable `app.R` for one scenario, built with `bslib` cards (#177, #213).

* `mascot_gesture()` plays one movement once, without changing the mood: `"nod"` acknowledges an action and `"wave"` greets. Use it on its own or pass a plain name to `updateMascot()` (#196).

* `mascot_gestures()` lists the gestures, with a description of each (#196).

* `mascot_mood()` chooses a mood for `mascot()` and `updateMascot()`; `"idle"` is the default (#190).

* `mascot_moods()` lists the built-in moods and what each means. Every character uses the same moods (#190).

* `mascot_motion()` turns off all animation with `animate = FALSE`, or only the character-swap transition with `swap = FALSE`. A visitor's reduced-motion preference is always honoured (#203).

* `mascot_placement()` sets where a mascot sits: a floating corner (`"bottom-right"` by default, `"top-left"`, `"top-right"` or `"bottom-left"`) or `"inline"` (#201, #223).
  * A floating mascot sits 1rem from the window edges, above fixed navigation bars and below modals. A bottom-right mascot moves above Shiny notifications while they show (#201).
  * `minimise = TRUE` (the default for floating mascots) shows a minimise control. It appears on hover or keyboard focus, stays visible on touch screens, and hides while the mascot menu is open. A minimised mascot becomes a round restore button; updates still apply and bubble countdowns pause until it is restored (#201, #208, #229).
  * `drag = "snap"` lets visitors drag a floating mascot, or its minimised restore button, to the nearest corner on release. The new corner becomes its `position` (#220).
  * *Experimental:* `drag = "free"` keeps the mascot where it is dropped, at least 1rem inside the window. The reported position and how to restore it may still change (#220, #224).
  * In Shiny, each drop sets `input$<id>_position`: a corner name after a snap, or a list with `x` and `y` after a free drop (#220).
  * Inline mascots ignore `minimise` and `drag`; an explicitly supplied value gives an informational message, not an error (#229).

* `mascot_popup_menu()` adds a click menu of app-defined items. A chosen item sets `input$<id>_menu` to its ID, so choosing the same item twice triggers the input twice (#143, #213).
  * `direction` is `"auto"` (the default), `"top"`, `"bottom"`, `"left"` or `"right"`. The menu opens from the mascot's on-screen position, and falls back to the opposite side when the chosen side has no room (#225).
  * Opening the menu closes a speech bubble, and a new bubble closes an open menu (#225).
  * Enter and Space toggle the focused menu control; the arrow keys, Home and End move between items, and Escape closes the menu (#213).
  * While the menu is open, the mascot looks towards it: up, down, left or right, on the side where the menu actually opened, after any fallback. The menu fits short screens and keeps keyboard focus on the visible control (#143, #208, #241).

* `mascot_preview()` (*experimental*) shows an offline page that compares moods, sizes and light and dark colours, with contrast findings on the page and in R (#175, #213). It starts no Shiny app and writes no files; printing the page opens the Viewer or a browser.
  * Rows are moods; columns are the requested size, then 48, 32 and 24 CSS pixels (#175).
  * Light and dark backgrounds are checked separately. Contrast warnings have the class `mascot_contrast` (#213).
  * Each cell is wide enough for its bubble, so bubbles no longer cover neighbouring cells at any size (#244).

* `mascot_size()` sets the size in CSS pixels (at least 24) or as a percentage: of the parent width when inline, or of the window width when floating (#201).
  * `small_screen` sets a different size for screens up to 575.98 pixels wide (#201).

* `mascot_status()` sets the status text beside the mascot. The text is always plain, and `NULL` (the default) follows the mood (#190).

* `mascot_studio()` (*experimental*) opens the studio, an app for exploring the package: a Guide to every exported function and argument, with explanations and the code to copy; a Code tray with UI, Server, App and Log tabs; and a canvas that shows the live mascot, or the page `mascot_preview()` returns when that function is selected (#38, #218).
  * `view = "examples"` opens the bundled examples instead. `fn` starts on a named function's Guide entry, and `character` chooses the character (#38).
  * `run = FALSE` returns the app without launching it.
  * Show bubble sits right under the message box, and always shows the example just chosen, even when clicked at once (#249).

* `mascot_theme()` sets a character's colours and its light or dark mode (#202, #213).
  * Colours you supply are kept exactly. Roles you leave out follow the character's declared leaders, such as `body`, in priority order; `mascot_colour_roles()` lists them (#213).
  * `mode = "auto"` (the default) follows the page's light or dark mode, and uses light mode when the page gives no signal (#213).
  * A chosen colour below 3:1 contrast with its background gives a warning and is kept. `bslib::bs_theme()` contrast checks use the light and dark backgrounds separately (#213).
  * A `bslib::bs_theme()` fills a character's brand colours with its primary and secondary colours (#202).
  * *Experimental:* `css` maps colour roles to CSS variables, such as `list(body = "--team-blue")`. The browser reads them, so R cannot check their values (#202).

* `updateMascot()` changes a mascot from the Shiny server: its character, mood, status, bubble, size, placement, theme, motion, click menu and gesture. Arguments left as `NULL` stay unchanged (#190, #196, #201, #202, #203, #143).
  * An update sent before the mascot appears is kept until it does. The latest state is kept for a later first mascot with the same ID (#193), and only the latest early gesture plays, once (#200).
  * A new `placement` replaces any position the visitor dragged the mascot to (#220).
  * Invalid values give a warning and leave the mascot unchanged. In Shiny development mode, a mascot that is not found because of a module namespace gets a one-time warning that names the fix (#215).

## Minor improvements and fixes

* The mascot helper objects (`mascot_bubble()`, `mascot_theme()` and the others) print and format readably (#213).
* `mascot()` without an `id` explains that the first argument is the character, and shows `mascot(id = "helper")` (#215).
* Every size draws the full character. The separate small-size drawing from 0.0.2 is removed, because below 72 pixels it looked worse than the full face (#219).
* The speech bubble follows the page's light or dark signal, like the drawing; a dark system setting alone keeps it light (#215).
* The Shiny examples show live theme and motion settings, a colour reset and a complete module menu (#208). The long-task example runs its slow step with `shiny::ExtendedTask`, so the app stays responsive, and every example has a title, a one-line purpose and a light and dark switch (#215).
* The Get started article walks through the helpers, modules and personalising Tessa, with runnable examples and screenshots of themes and menu actions (#177).

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
