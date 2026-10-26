# The example apps: a map for contributors

mascot ships its example apps in [`inst/examples/`](../inst/examples/). `mascot_examples()` lists them and
`mascot_example()` runs one or returns the path of its `app.R` (both in [`R/examples.R`](../R/examples.R)). Most of
this page is about the studio, the largest of them: it shows every exported function and argument, so it changes
whenever the API does. Read the studio sections before you change an exported function or argument: the studio
changes in the same PR (the rule is in [`AGENTS.md`](../AGENTS.md), section "Keep mascot studio up to date").

This page lives in `docs/` because `mascot_example()` copies an app's folder to users, and contributor notes don't
belong there.

## The apps

| Name in `mascot_examples()` | Folder | What it shows | Needs |
|---|---|---|---|
| `studio` | `studio/` | Every exported function and argument, live (the rest of this page) | bslib, knitr |
| `form-check` | `form-check/app.R` | A worried mascot names invalid fields and turns happy when both pass | bslib |
| `long-task` | `long-task/app.R` | Thinking during a slow step, then success or a lasting error bubble | bslib, promises, later |
| `modules` | `modules/app.R` | Two module mascots and a floating one the parent owns | bslib |
| `theme` | `studio/` (the theme view) | One character themed with live feedback | bslib |
| `golem` | `golem/` (`app.R` and `R/`) | Function-built UI, golem runtime options, nested modules | golem |
| `rhino` | `rhino/` (`app.R` and `app/view/`) | Plain Shiny view modules in a rhino-shaped folder | nothing extra |

`inst/examples/characters/study_bot.json` is not an app: it is the character file that the help examples in
[`R/character-api.R`](../R/character-api.R) read.

The scenario apps are plain Shiny and use only exported functions, so they change only when the behaviour they show
changes. Their tests:

- [`test-examples.R`](../tests/testthat/test-examples.R), on CRAN too: `mascot_examples()` lists the apps in this
  order; each folder holds only its expected files; every R file parses; each page draws offline (no `http` link
  other than the two navbar links).
- [`test-examples-browser.R`](../tests/testthat/test-examples-browser.R), never on CRAN: each scenario app runs in
  Chrome and does what its row above says.

To add an app: put it in its own folder with an `app.R`, add a row to `mascot_examples()` (name, title,
description, and "Requires ..." for any extra package), and update the expected list and folder contents in
`test-examples.R`, a browser test in `test-examples-browser.R`, `mascot_examples()`'s help, and `NEWS.md`. A new
app gets a `-extended.R` file only when it has detailed tests (see "Adding tests for a new example app" in
[`tests/README.md`](../tests/README.md)).

## The studio: how it opens, and its views


`mascot_studio()` ([`R/studio.R`](../R/studio.R)) and `mascot_example("studio")` ([`R/examples.R`](../R/examples.R))
both run the same folder. `mascot_example("theme")` runs it too, opened on the theme view.

One app serves three views. `?view=` in the address chooses one, and `mascot_studio(view =)` passes the same value
on the page request.

| View | What it shows | Page | Server |
|---|---|---|---|
| `studio` | One function at a time: controls, help, guide and code | `studio_view_ui()` and `studio_page()` in `app.R` | `studio_server()` and `examples_server()` in `app.R` |
| `examples` | The same page, opened on the bundled examples instead of the live mascot | the same page | the same server |
| `theme` | One character, themed with live feedback | `theme_view_ui()` in `R/theme-ui.R` | `theme_view_server()` in `R/theme-server.R` |

The routing is in [`R/views.R`](../inst/examples/studio/R/views.R) and at the end of `app.R`:

- `studio_view_titles` names the views. `mascot_studio()` reads its valid `view` values from it.
- `studio_views()` gives each view a `ui(query)` and a `server(input, output, session)`.
- `ui()` in `app.R` picks the page from the request's query string (`view_from_request()`). `server()` picks the
  view once, when the session starts (`view_from_client()`), and runs only that view's server.
- The studio's "More" menu links to each view (`studio_right_rail()` in `R/ui.R`).

The preview page (`mascot_preview()`) is not a view: it is a host mode of the studio page, chosen under "Host mode".

## The studio's files

Shiny sources every file in `R/` before `app.R` attaches mascot, so files in `R/` hold functions and plain data
only. They call mascot as `mascot::` or inside functions that run later.

| File | What it holds |
|---|---|
| `app.R` | The studio page (`studio_page()`), its server (`studio_server()`, `examples_server()`), the starting state and the routing |
| `R/views.R` | The list of views and the routing helpers |
| `R/guide.R` | `studio_guide`: per exported function, its category, the vignette section to read next and its arguments; `studio_categories` |
| `R/data.R` | `defaults` (the starting value of each `mascot()` argument), `studio_controls` (for every exported argument, the input ids that try it or the reason it has none), bubble examples, the starting menu |
| `R/panels.R` | The Controls: one `panel_*()` per category, with an `arg_field()` per argument |
| `R/code.R` | The code builders (`code_mood()`, `code_bubble()`, ...): each returns the shortcut and the helper form of an argument; `format_call()` prints them |
| `R/ui.R` | Building blocks of the page: argument fields, function cards, the Guide and Help panels, the rail and search, call chips, and the live diagrams the guide pages use (`size_ruler()`, `placement_map()`, `roles_table()`, ...) |
| `R/guide-md.R` | Knits one guide page (`guide/<function>.Rmd`) for the studio |
| `R/shared-help.R` | Reads the package's help pages at run time: descriptions, arguments, return values, examples |
| `R/shared-data.R` | The characters and palettes the views offer, from mascot's listings |
| `R/shared-colours.R` | Colour pickers and the colour roles module, for every view. The module numbers each drawing of its pickers, drops an edit from an older drawing or the value a picker reports when it is drawn, and draws a value's warning with its picker |
| `R/shared-layout.R` | The sentence bar and the window frame around a preview |
| `R/shared-run.R` | `run_real_call()`: runs a mascot call and reports errors, warnings and messages |
| `R/shared-check.R` | The contrast check, the palette swap and a folder for built preview pages |
| `R/shared-ui.R` | Shared buttons (`studio_button()`, `copy_button()`); `copy_gate()`, which answers a Copy click once every waiting input is applied; `stamp_output()`, which marks what an output was drawn for; `update_choice()`, which updates a linked control with the revision of the choice it answers |
| `R/theme-ui.R`, `R/theme-server.R` | The theme view's page and server; the top of `theme-ui.R` lists every shared part it uses |
| `guide/<function>.Rmd` | The guide page of each exported function, knitted by the studio and by the website |
| `guide/guide-helpers.R`, `guide/guide-shared.R` | Helpers for the guide pages, in plain R and htmltools so the website can use them too |
| `guide/guide-mistakes.R` | The "common mistakes" calls of each guide page and their real messages |
| `guide/guide.css` | Styles of the guide's diagrams on the website (the studio's own copy is in `www/studio.css`) |
| `www/tokens.css`, `www/shared.css` | Colour and spacing tokens, and the styles every view shares |
| `www/studio.css`, `www/studio.js` | The studio view's styles and browser code (layout, chips, search, the live frame) |
| `www/theme.css` | The theme view's styles |
| `www/inputs.js` | The colour picker input, copy buttons, event buttons and busy buttons, for every view. It sends any waiting colour before Copy, an action button or a palette or character change (`flushColours()`), keeps the revision counter of linked controls, and lets a view add a step before Copy (`mascotStudioInputs.beforeCopy()`) |
| `www/mascot-mark.svg` | The logo mark on the rail |

## Keeping the page and the server in step

In a Shiny app the page changes at once and the server answers a moment later, so a quick click can act on an earlier
state: a debounced colour picker, Copy of code the server writes, a control the server sets back, a frame that loads
later (#548, #550, #574). Five rules close that gap, and one kind of browser test checks them. They live in one place each; read them
there:

- the app side, rules 1 to 5: [`.claude/rules/r-code.md`](../.claude/rules/r-code.md), "Shiny apps";
- the page side: [`.claude/rules/js-css.md`](../.claude/rules/js-css.md), the bullet on the page script of a Shiny app;
- the reasons: [`docs/standards.md`](standards.md), section 3, "Shiny apps: the page and the server in step";
- the test: [`tests/README.md`](../tests/README.md), "Testing actions in a Shiny app".

The studio's tools for them, to reuse in any view: `copy_gate()`, `stamp_output()` and `update_choice()` in
`R/shared-ui.R`, `busy_done_mark()` in `R/shared-check.R`, and `mascotStudioInputs.beforeCopy()` in `www/inputs.js`.

## Changing an exported function or argument

The words come from the help pages: `R/shared-help.R` reads them while the app runs. Update the roxygen and run
`devtools::document()`; never copy help text into the studio.

For a new or changed argument, work through these files in this order:

1. **Guide data, `R/guide.R`.** The function's `guide_entry()` lists its arguments. Add or rename the
   argument; `try` names the category where it can be tried, when that differs from the function's.
2. **Controls, `R/panels.R`.** Add an `arg_field(fn, arg, <input>)` to the function's panel. The input id must be
   unique on the page.
3. **Control map, `R/data.R`.** Add the input ids to the function's entry in `studio_controls`, or
   `fixed_arg("<reason>")` when the argument has no control. For a `mascot()` or `update_mascot()` argument, also
   check `defaults`.
4. **Code builders, `R/code.R`.** Teach the function's `code_*()` builder the new argument, so the printed code and
   the evaluated call both carry it.
5. **Server, `app.R`.** Read the new input inside `studio_server()`: in the observer that sends the live update
   (`send()`), and in `output$code_function`, which prints the selected function's code. `mascot_preview()`'s
   arguments go through `preview_args()` instead. When the server can set the control itself, add its id to the
   echo list (`echo_to_control()`): that is how the server avoids echoing the control the user just used (rule 3 in
   "Keeping the page and the server in step").
6. **Pictures, `guide/<function>.Rmd` and `R/ui.R`.** Update the guide page when the argument changes what it shows.
   A live diagram is a function in `R/ui.R`, rendered by an output in `app.R`, that the page shows only `in_studio()`.

7. **Tests, `tests/testthat/test-studio-extended.R`.** Every input id in `studio_controls` needs a row in "each
   studio control's update, generated code and default" (the row sets the input and names the code it expects), or
   a reason in that test's `exempt` list.

For a new `mascot()` argument, also add it to `defaults` in `R/data.R` (a test compares `defaults` with `mascot()`'s
formals), check `studio_route()` in `R/ui.R` (which helper its call chip opens) and the chip's controls in
`www/studio.js` (search for `chipArgument`).

A new exported function needs all of the above, plus:

- an entry in `studio_guide` (`R/guide.R`) and in `studio_controls` (`R/data.R`);
- its guide page, `guide/<function>.Rmd`;
- the website's stub for that page, `vignettes/articles/guide-<function>.Rmd` (copy another stub and change the
  name).

A removed function or argument comes out of the same places.

Then open the studio (`devtools::load_all()`, then `mascot_studio()`), try the change, and say so in the PR's checks.
The tests catch a missing function, argument or control, and check the controls they have rows for; they don't
catch a changed default or behaviour that no row covers.

## Which studio tests catch what

The studio's tests come in four kinds, by where they run. How the kinds work is in
[`tests/README.md`](../tests/README.md); what each CI job runs is in
[`.github/workflows/README.md`](../.github/workflows/README.md).

| Tests | Files | Where they run | What they catch |
|---|---|---|---|
| Completeness and detail | [`test-studio-extended.R`](../tests/testthat/test-studio-extended.R), `test-studio-app-extended.R`, `test-studio-shared-extended.R`, `test-studio-theme-extended.R` | Locally, the coverage job, the off-CRAN job and the weekly extended-tests run; not on CRAN or in R CMD check | An export or argument missing from `studio_guide` or `studio_controls`, a mapped control with no update row, a `mascot()` argument missing from `defaults` or with no call chip route, prose in `guide.R`, help text that doesn't come from the help pages, code that doesn't parse, a missing website stub, a theme view that uses a part it doesn't list, a view missing from the `mascot_studio()` guide page; and in `test-studio-shared-extended.R`, the colour module's timing (an edit before a redraw, the value a picker reports when it is drawn) |
| Examples | [`test-examples.R`](../tests/testthat/test-examples.R) | Everywhere, CRAN included | A missing guide page, a file in the studio folder that isn't `app.R`, `R/`, `guide/` or `www/`, a file in `www/` that the app never uses |
| Smoke | [`test-studio.R`](../tests/testthat/test-studio.R), `test-studio-theme.R` | Everywhere, CRAN included | `mascot_studio()`'s arguments, the routing between views, and that each view's page draws |
| Browser | `test-studio-browser.R`, `test-studio-app-browser.R`, `test-studio-theme-browser.R`, and the studio's narrow layout and palette tests in `test-examples-browser.R` | Locally with Chrome and in the off-CRAN job; not on CRAN or in R CMD check | What a user sees and clicks: controls, chips, panels, search, updates of the live mascot; and the "do X, then Y at once" tests: a change and an action with no wait between them, held apart with the helpers in `helper-studio.R` (`hold_studio_inputs()`, `hold_studio_replies()` and the rest) |

`Rscript tools/cran-gate.R tests` and `devtools::test()` run all of them; the browser tests need Chrome.

## Adding a view to the studio

A view is a page of the same app, such as the planned builder. To add one:

1. Add its name and page title to `studio_view_titles` in `R/views.R`, and a `list(ui =, server =)` to
   `studio_views()`, in the same order (the function stops when the names differ).
2. Put its page in `R/<view>-ui.R`, as `<view>_view_ui(query)`, and its server in `R/<view>-server.R`, as
   `<view>_view_server(input, output, session)`. Use the `R/shared-*.R` parts, never `www/studio.js` or the studio's
   own functions in `app.R`, and list the parts it uses at the top of its UI file, as `R/theme-ui.R` does. Two
   controls that show the same choice are linked: update them with `update_choice()`, which carries the page's
   revision counter.
3. Load `tokens.css`, `shared.css`, then its own `www/<view>.css`, and `inputs.js` before any script of its own.
4. Document the new `view` value in `mascot_studio()`'s roxygen (`R/studio.R`) and in the view table of
   `guide/mascot_studio.Rmd` (a test checks that the page names every view), with a `NEWS.md` bullet.
   `mascot_studio()` accepts the value as soon as `studio_view_titles` has it. Add a link to the "More" menu in
   `studio_right_rail()` (`R/ui.R`).
5. If `mascot_example()` should open it too, as with `"theme"`, add it to the listing in `R/examples.R`.
6. If the view gets its own exported launcher (a `mascot_builder()`, say), that function is an export like any
   other: it needs everything in "Changing an exported function or argument".
7. Add tests: a smoke test in `test-studio-<view>.R`, the detailed tests in `test-studio-<view>-extended.R` and the
   browser tests in `test-studio-<view>-browser.R` (see "Adding tests for a new example app" in
   [`tests/README.md`](../tests/README.md)). Each action of the view (Copy, Download, Build, Check) gets one "do X,
   then Y at once" browser test. The routing tests in `test-studio.R` ("mascot_studio() views")
   may need the new view.
