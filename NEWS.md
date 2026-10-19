# mascot (development version)

## Breaking changes

* `mascot_preview()` removes the inert `placement` and `click` arguments. Remove them from preview calls; comparison columns now use 160, 96 and 24 pixels after the requested size (#350).

* `mascot_popup_menu()` no longer sets `input$<id>_click` when its menu opens or closes. Handle choices through `input$<id>_menu`; use `mascot_action()` for a single action that sets the click count (#349).

* `mascot_gesture(name)` accepts only `name`; its unused `...` is removed (#349).

* `mascot_action()`, `mascot_popup_menu()` and `mascot_bubble()` reject explicitly supplied options when their main argument (`label`, `items` or `text`) is `NULL`. Supply the main argument with those options, or call the helper without options to remove the click or bubble (#349).

* `mascot_character(id = "tessa")` names its argument `id`, as every other function that addresses a character does; `name =` is no longer accepted and has no alias. Pass the id positionally or as `id =` (#296).

* `mascot_motion_settings()` replaces `mascot_motion()` without an alias; all settings must be named and `animate` is removed. Use `motion = FALSE` to stop everything (#239).

* The pre-CRAN API puts `id` first in `mascot()`, names the server function `update_mascot()` without an alias, and requires arguments after `...` to be named. Dragging uses `"none"`, `"snap"` or `"free"`; untimed bubbles use `duration = Inf`, and floating placement uses a corner such as `"bottom-right"`. These choices settle the small API now: adding later is cheap, removing is costly (#259).

## New features

* Tessa has a new look: a slimmer teal hexagon with a silver ring that shimmers now and then, hair with a side fringe, a small bow, small studs, arms that hang down and a chest badge whose icon shows her mood. She keeps her five moods, her wave and nod, her status lines and every anchor name, and gains anchors for her fringe, lock and studs. Her colours gain roles for the hair (`hair`, `hair_shade`, `hair_light`), the badge (`badge`, `badge_icon`), the iris, the body shade and the ring's light and dark ends, and the bow now has its own `accessory` colour instead of following the rim. Her old palettes `nordic`, `coral` and `azure` are replaced (#359).
* Tessa's own colours are named `night_teal`, with `"original"` still selecting them; `mascot_palettes("tessa")` lists `night_teal` first, and her other palettes are `sea_green`, `forest`, `spring`, `peach`, `coral_navy`, `desert_coral`, `rose_soft`, `lilac_soft` and `mist_navy`. A character file may name its own colours with `native_palette`, and a palette may carry a `group` for sorting in documentation (#358, #359).
* An unknown palette in `mascot()` (an error) or `update_mascot()` (a warning) now names the other characters that have a palette of that name (#358).
* `mascot_popup_menu()` gains `disabled = FALSE`. With `TRUE`, the button stays reachable by keyboard and screen readers announce it as unavailable; it opens nothing and sends no input (#350).
* `mascot()`, `update_mascot()` and `mascot_preview()` accept palette id strings
  through `theme`; `mascot_theme()` gains `palette`, with role and CSS overrides
  applied on top. Character swaps keep shared palette ids or warn and restore
  original colours while retaining explicit colours for shared roles (#336).
* Built-in characters gain named palettes; the Knurl palettes `sea_glass` and `night_screen`
  are replaced by `orbit`, `carbon`, `cobalt_droid` and `crimson` (#336).
* `mascot_colour_roles()` gains `palette`; `mascot_palettes()` now defaults to
  all characters, with a final `character` column. `mascot_characters()` adds a
  final `palettes` column, and printed themes show their palette (#336).
* The studio top bar gains Palette, Mood and Gesture drop-downs and a Play
  button; choices refresh with the character (#336).

* Every character must now have a `wave` and a `nod` gesture that visibly move. `wave` must move a part other than `root` (an arm, a hand, a fin), so it is more than a tilt of the whole body; `nod` may move any part, `root` included. A character that breaks this is refused with a message naming the gesture (#328).

* When a Shiny connection drops, each mascot immediately shows its worried mood and a readable connection message above the Shiny disconnect overlay. It restores the latest mood and status when Shiny reconnects (#70).

* `mascot_mood()` and `mascot_gesture()` now check only the form of an id (lowercase letters, digits and underscores). `mascot()`, `update_mascot()` and `mascot_preview()` check it against the chosen character and list that character's moods or gestures when it is wrong, so `mascot_mood("hapy")` alone no longer errors but `mascot("helper", mood = "hapy")` does (#309).

* Tessa is now drawn and animated by the same engine as every other character. She keeps her five moods, the wiggle on a mood change, her gestures, bow and clip, and every colour role name a theme can use; a few small face details are drawn slightly differently, and at the smallest sizes her bow and clip are hidden. The restore button now reads "Restore Tessa, <status>" instead of the mood's id (#308).

* Mascots work in nested Shiny modules, function-built user interfaces in `golem` and rhino-shaped view modules. Bundled `golem` and `rhino` examples each show two independent nested modules (#133).

* Minimising and restoring a mascot sets `input$<id>_minimised` in its owning module (#133).

* `mascot(id, ..., character = "tessa")` requires an id first; arguments after it are named. `mascot()` adds a character with a mood, a status line and an optional message bubble to a Shiny app or Quarto page. It floats in the bottom-right corner by default (#190, #223).
  * `placement = "inline"` places it in the page flow; a corner name or `mascot_placement()` gives the other options (#223).
  * `bubble` shows a message (#196), `size` takes pixels, a percentage or `mascot_size()` (#201), `theme` takes colours, a `bslib::bs_theme()` or `mascot_theme()` (#202), `motion = FALSE` stops animation (#203), and `click` says what a click does: one action with a label, or a menu (#257).
  * Without `click`, the mascot is a picture: no keyboard stop and no events. With one, it is a button named for screen readers, and every action activation (a click or tap, Enter or Space, a screen reader's activate command) sets `input$<id>_click` to a count. Holding a key down counts once, and a drag never counts (#237, #257).

* `mascot_action()` makes the mascot a button for one action of the app, such as opening a help panel; `click = "Open help"` is the short form. Its label names the button for screen readers and shows in a tooltip on hover and keyboard focus, which Escape hides; `tooltip = FALSE` turns the tooltip off. `disabled = TRUE` keeps the button but sends nothing: it stays reachable with the keyboard, and screen readers announce it as unavailable (#257).

* `mascot_bubble(text = NULL, ..., duration = 5, closable = TRUE)` names its options and rejects `duration = NULL`; use `Inf` instead. It sets a speech bubble with escaped text, or HTML only through `htmltools::HTML()` or tags (#196).
  * `duration` is in seconds (default `5`); `duration = Inf` keeps the bubble until it is closed, replaced or cleared. `closable = FALSE` hides the close button; Escape still closes the bubble (#196).
  * The countdown pauses while the mascot is hidden or minimised, while the pointer is over the bubble, and while keyboard focus is inside the mascot, then resumes with the time left (#196, #199, #229).
  * Space is reserved above the mascot, so a bubble never moves the page (#196).
  * While a bubble shows, the mascot looks towards it: up when it is above, down when it is below a top-corner mascot. Only the pupils move, at once and without animation, so eyes without visible pupils keep their look (#241).

* `mascot_character()` chooses a character by id (#190).

* Three more built-in characters: Sela, a second hexagon; Knurl, a robot; and Neer, a water elemental. `mascot_characters()` gains a `lifecycle` column. Tessa and Sela are stable: their id, name, five moods, gesture names, colour role names and palette names stay the same in every release, while their drawing, motion and exact colours may be polished. Knurl and Neer are experimental: anything about them may change, and neither is removed without a warning one release before. The character file format and the functions for making your own characters are experimental too (#317, #318, #319, #26).

* `mascot_colour_roles()` lists a character's colour roles with their colours, the leaders they follow and their shade (#202, #213).
  * It gains a `description` column and a `brand` column naming the `bslib` primary or secondary slot a role fills. The first four columns are unchanged (#296).
  * `character` also accepts a `mascot_character()` helper.

* `mascot_characters(..., family = NULL)`, `mascot_families()`, `mascot_anchors(character = "tessa")` and `mascot_palettes(character = "tessa")` list the characters this R session knows, their families, a character's attachment points and its colour palettes. Every listing is a base data frame whose first column is the value you pass on, and later versions only add columns at the end. (#296).

* `mascot_example(name, ..., run = TRUE)` requires `run` to be named. It runs one bundled example app, or with `run = FALSE` returns the path to its `app.R` without copying any file (#178).

* `mascot_examples()` lists the bundled Shiny apps in teaching order. The studio comes first; each other app is a copyable `app.R` for one scenario, built with `bslib` cards (#177, #213).

* `mascot_gesture(name)` rejects extra arguments. It plays one movement once, without changing the mood: `"nod"` acknowledges an action and `"wave"` greets. Use it on its own or pass a plain name to `update_mascot()` (#196).

* `mascot_gestures(character = NULL)` lists the gestures, with a description of each (#196). It gains `fallback` and `frames` columns; with a `character`, `frames` is the length of the movement that plays, so a wave that falls back to a rock reports the rock's length. (#296).

* `mascot_mood()` chooses a mood for `mascot()` and `update_mascot()`; `"idle"` is the default (#190).

* `mascot_moods(character = NULL)` lists the built-in moods and what each means (#190). It gains `status`, `shared` and `fallback` columns; with a `character`, it lists that character's moods, the five shared ones first. (#296).

* `mascot_motion_settings()` independently controls `idle`, `mood_change`, `gestures`, `swap`, `minimising`, `restoring` and `messages`. Unnamed switches, including future ones, follow `others`; named switches win. Messages can move for selected panels, and minimise/restore gain short transitions. The visitor's reduced-motion preference always wins (#239).

* `update_mascot()` skips gestures when `gestures = FALSE` while applying the mood, bubble and status in the same update; Shiny development mode reports the skipped gesture (#239).

* `mascot_placement(position = "bottom-right", ..., minimise = TRUE, drag = "none")` names its options and rejects logical dragging values. It sets where a mascot sits: a floating corner (`"bottom-right"` by default, `"top-left"`, `"top-right"` or `"bottom-left"`) or `"inline"` (#201, #223).
  * A floating mascot sits 1rem from the window edges, above fixed navigation bars and below modals. A bottom-right mascot moves above Shiny notifications while they show (#201).
  * `minimise = TRUE` (the default for floating mascots) shows a minimise control. It appears on hover or keyboard focus, stays visible on touch screens, and hides while the mascot menu is open. A minimised mascot becomes a round restore button; updates still apply and bubble countdowns pause until it is restored (#201, #208, #229).
  * `drag = "snap"` lets visitors drag a floating mascot, or its minimised restore button, to the nearest corner on release. The new corner becomes its `position` (#220).
  * *Experimental:* `drag = "free"` keeps the mascot where it is dropped, at least 1rem inside the window. The reported position and how to restore it may still change (#220, #224).
  * In Shiny, each drop sets `input$<id>_position`: a corner name after a snap, or a list with `x` and `y` after a free drop (#220).
  * Inline mascots ignore `minimise` and `drag`; an explicitly supplied value gives an informational message, not an error (#229).

* `mascot_popup_menu()` makes a click open a menu of app-defined items: pass it as `click`. A chosen item sets `input$<id>_menu` to its ID, so choosing the same item twice triggers the input twice (#143, #213, #257).
  * `direction` is `"auto"` (the default), `"top"`, `"bottom"`, `"left"` or `"right"`. The menu opens from the mascot's on-screen position, and falls back to the opposite side when the chosen side has no room (#225).
  * Opening the menu closes a speech bubble, and a new bubble closes an open menu (#225).
  * Opening and closing the menu never set `input$<id>_click`. `label` names the menu button for screen readers and shows in a tooltip, which `tooltip = FALSE` turns off; without it, the button is named after the character, such as "Tessa, menu" (#257).
  * Enter and Space toggle the focused menu control, once while the key is held down; the arrow keys, Home and End move between items, and Escape closes the menu (#213, #257).
  * While the menu is open, the mascot looks towards it: up, down, left or right, on the side where the menu actually opened, after any fallback. The menu fits short screens and keeps keyboard focus on the visible control (#143, #208, #241).

* `mascot_preview(character = "tessa", ...)` (*experimental*) names its options and shows an offline page that compares moods, sizes and light and dark colours, with contrast findings on the page and in R (#175, #213). It starts no Shiny app and writes no files; printing the page opens the Viewer or a browser.
  * Rows are moods; columns are the requested size, then 160, 96 and 24 CSS pixels (#175, #350).
  * Light and dark backgrounds are checked separately. Contrast warnings have the class `mascot_contrast` (#213).
  * Each cell is wide enough for its bubble, so bubbles no longer cover neighbouring cells at any size (#244).

* `mascot_size(size = 160, ..., small_screen = "auto")` sets the size in CSS pixels (at least 24) or as a percentage: of the parent width when inline, or of the window width when floating (#201).
  * `small_screen = "auto"` (the default) scales floating mascots down on phones (at most 96 pixels) while leaving inline mascots unchanged. `small_screen = NULL` keeps the same size on every screen (#261).

* `mascot_status()` sets the status text beside the mascot. The text is always plain, and `NULL` (the default) follows the mood (#190).

* `mascot_studio(view = "studio", ..., fn = NULL, character = "tessa", run = TRUE)` (*experimental*) opens the studio, an app for exploring the package: a Guide to every exported function and argument, with explanations and the code to copy; a Code tray with UI, Server, App and Log tabs; and a canvas that shows the live mascot, or the page `mascot_preview()` returns when that function is selected (#38, #218).
  * `view = "examples"` opens the bundled examples instead. `fn` starts on a named function's Guide entry, and `character` chooses the character (#38).
  * `run = FALSE` returns the app without launching it.
  * Show bubble sits right under the message box, and always shows the example just chosen, even when clicked at once (#249).

* `mascot_theme(..., light = NULL, dark = NULL, mode = "auto", css = NULL)` sets a character's colours and its light or dark mode (#202, #213).
  * Colours you supply are kept exactly. Roles you leave out follow the character's declared leaders, such as `body`, in priority order; `mascot_colour_roles()` lists them (#213).
  * `mode = "auto"` (the default) follows the page's light or dark mode, and uses light mode when the page gives no signal (#213).
  * A chosen colour below 3:1 contrast with its background is kept; R warns in development mode, previews and the studio unless the contrast option overrides it. `bslib::bs_theme()` contrast checks use the light and dark backgrounds separately (#213).
  * A `bslib::bs_theme()` fills a character's brand colours with its primary and secondary colours (#202).
  * *Experimental:* `css` maps colour roles to CSS variables, such as `list(body = "--team-blue")`. The browser reads them, so R cannot check their values (#202).

* `update_mascot(id, ..., session = shiny::getDefaultReactiveDomain())` names every update option; `NULL` leaves it unchanged and empty helpers reset settings. `update_mascot()` changes a mascot from the Shiny server: its character, mood, status, bubble, size, placement, theme, motion, click and gesture. Arguments left as `NULL` stay unchanged (#190, #196, #201, #202, #203, #143).
  * An update sent before the mascot appears is kept until it does. The latest state is kept for a later first mascot with the same ID (#193), and only the latest early gesture plays, once (#200).
  * A new `placement` replaces any position the visitor dragged the mascot to (#220).
  * Invalid values give a warning and leave the mascot unchanged. In Shiny development mode, a mascot that is not found because of a module namespace gets a one-time warning that names the fix (#215).

## Minor improvements and fixes

* Exported examples assign mascot tags instead of printing the embedded character data (#350).

* `mascot_motion_settings()` reports invalid `messages` panel names with class `mascot_error_choice` (#350).

* `update_mascot()` help lists every helper reset and explains that each supplied setting replaces the whole group. Module warnings consistently name the local mascot id (#350).

* Checked character data gains a compact `format()` method; `print()` assertion failures carry `mascot_error` (#350).

* `mascot()` preserves specific error classes and their choice fields for handlers.
  Malformed mood ids list the chosen character's moods as well as the lowercase
  rule; unexpected arguments count unnamed values and list named ones (#350).

* `mascot_placement()` prints logical drag values without quotes and explains
  the `"none"`, `"snap"` and `"free"` modes in errors (#350).

* Mascot conditions are listed in the package help, including choice, authoring and development diagnostics (#350).

* Palette ids reserve `minimal`, `pastel`, `vivid`, `corporate`, `earthy` and `night` for style aliases (#350).

* Shiny excludes private mascot state inputs from bookmarks even when the app
  later replaces its exclusions, including inside modules, and shows the
  development problem overlay when a buffered update fails at mount (#350).

* Theme errors list valid roles, invalid contrast-warning options warn once, and theme mode, drag and studio choices carry `mascot_error_choice` (#350).

* `mascot_motion_settings(others = FALSE)` uses the same reduced-motion poses and instant drag transitions as `motion = FALSE` when no named switch enables movement (#349).

* `mascot_popup_menu()` includes `tooltip` in its unexpected-argument hint (#349).

* `update_mascot()` catches `mascot_error` conditions raised by inline helpers, warns with `mascot_update_ignored` and ignores the whole update so an observer can continue (#349).

* `mascot_anchors("neer")` now lists 14 attachment points. The help explains
  what anchors are for and that characters may have none (#360).

* Click menus and other panels opening below a mascot leave room for its status text, including wrapped lines, and fall back to another side when there is not enough room (#344).

* Tessa's default status now uses a sentence for each mood, so apps that use her default status show the new text beside her and to screen readers (#142).

* `mascot_studio()` shows its canvas and mascot on narrow screens again; on screens narrower than 576 pixels the main area was empty (#341).

* `update_mascot()` changes survive a mascot being re-rendered: a replaced mascot comes back as the server last set it, a gesture plays only once and a dismissed bubble stays dismissed, also in Quarto and R Markdown documents that run Shiny (#305).

* Mascot layout reads batch into one animation frame per burst of page changes; unrelated changes are ignored unless an inline bubble needs refitting. Animating mascots pause drawing while scrolled outside the viewport; see the engine changelog on the package website (#295).

* Minimised mascots restore sharp without interaction: the canvas backing size matches its displayed size times the device pixel ratio, and the character is redrawn on restore, including when animated, with `restoring = FALSE` and under reduced motion (#275).

* `update_mascot()` accepts `session$ns()` ids without adding the module namespace twice, including when replaying updates after a mascot reappears (#133).

* The help of `update_mascot()` shows how to make the mascot react to an app's state with an observer: a long computation run as a `shiny::ExtendedTask`, and form validation (#272).

* Styling has five public classes, shared panel colours (`--mascot-panel-bg`, `--mascot-panel-color`, `--mascot-panel-border`), restore-button colours (`--mascot-restore-bg`, `--mascot-restore-fg`, `--mascot-restore-glow`) and `--mascot-z-index` (default 1031), documented in `?mascot_styling`. User colours win over page and Bootstrap colours; other custom properties use the private `--_mascot-*` prefix (#260).

* The studio's sidebars use an opaque page background on phones, hiding the floating mascot beneath them in light and dark mode (#265).

* Helper print methods show calls using only non-default public arguments; their fields are internal. Listings return base data frames with stable existing columns and the accepted value in the first column (#259).

* R conditions carry `mascot_error`, `mascot_warning` or `mascot_message`; ignored updates also carry `mascot_update_ignored`. R contrast warnings appear in development mode, previews and the studio by default, with `mascot.contrast_warnings` forcing them on or off everywhere (#259).

* The speech bubble, the menu and the action tooltip share one look and appear motion, in the page's light or dark colours; the menu and the tooltip also share one placement next to the character. The bubble keeps its own placement, which works before the page's scripts run (#233).

* `mascot_theme()` reads short hex colours such as `"#000"`, which `bslib::bs_theme()` can return, on every supported R version, and the studio runs on R 4.1 to 4.3 (#255).
* The mascot helper objects (`mascot_bubble()`, `mascot_theme()` and the others) print and format readably (#213).
* `mascot()` without an `id` explains that every mascot needs one and shows `mascot("helper")` (#259).
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
