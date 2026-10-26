# The studio app: a map for contributors

The studio is a Shiny app in [`inst/examples/studio/`](../inst/examples/studio/). It shows every exported function
and argument working on a live mascot, with the help page beside it and the code to copy. Read this page before
you change an exported function or argument: the studio changes in the same PR (the rule is in
[`AGENTS.md`](../AGENTS.md), section "Keep mascot studio up to date").

This page lives in `docs/` because `mascot_example("studio")` copies the studio folder to users, and contributor
notes don't belong there.

## How it opens, and its views

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

## The files

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
| `R/shared-colours.R` | Colour pickers and the colour roles module, for every view |
| `R/shared-layout.R` | The sentence bar and the window frame around a preview |
| `R/shared-run.R` | `run_real_call()`: runs a mascot call and reports errors, warnings and messages |
| `R/shared-check.R` | The contrast check, the palette swap and a folder for built preview pages |
| `R/shared-ui.R` | Shared buttons (`studio_button()`, `copy_button()`) |
| `R/theme-ui.R`, `R/theme-server.R` | The theme view's page and server; the top of `theme-ui.R` lists every shared part it uses |
| `guide/<function>.Rmd` | The guide page of each exported function, knitted by the studio and by the website |
| `guide/guide-helpers.R`, `guide/guide-shared.R` | Helpers for the guide pages, in plain R and htmltools so the website can use them too |
| `guide/guide-mistakes.R` | The "common mistakes" calls of each guide page and their real messages |
| `guide/guide.css` | Styles of the guide's diagrams on the website (the studio's own copy is in `www/studio.css`) |
| `www/tokens.css`, `www/shared.css` | Colour and spacing tokens, and the styles every view shares |
| `www/studio.css`, `www/studio.js` | The studio view's styles and browser code (layout, chips, search, the live frame) |
| `www/theme.css` | The theme view's styles |
| `www/inputs.js` | The colour picker input, copy buttons and event buttons, for every view |
| `www/mascot-mark.svg` | The logo mark on the rail |

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
   echo list (`echo_to_control()`).
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

## Which tests catch what

The studio's tests come in four kinds, by where they run. How the kinds work is in
[`tests/README.md`](../tests/README.md); what each CI job runs is in
[`.github/workflows/README.md`](../.github/workflows/README.md).

| Tests | Files | Where they run | What they catch |
|---|---|---|---|
| Completeness and detail | [`test-studio-extended.R`](../tests/testthat/test-studio-extended.R), `test-studio-app-extended.R`, `test-studio-shared-extended.R`, `test-studio-theme-extended.R` | Locally, the coverage job, the off-CRAN job and the weekly extended-tests run; not on CRAN or in R CMD check | An export or argument missing from `studio_guide` or `studio_controls`, a mapped control with no update row, a `mascot()` argument missing from `defaults` or with no call chip route, prose in `guide.R`, help text that doesn't come from the help pages, code that doesn't parse, a missing website stub, a theme view that uses a part it doesn't list, a view missing from the `mascot_studio()` guide page |
| Examples | [`test-examples.R`](../tests/testthat/test-examples.R) | Everywhere, CRAN included | A missing guide page, a file in the studio folder that isn't `app.R`, `R/`, `guide/` or `www/`, a file in `www/` that the app never uses |
| Smoke | [`test-studio.R`](../tests/testthat/test-studio.R), `test-studio-theme.R` | Everywhere, CRAN included | `mascot_studio()`'s arguments, the routing between views, and that each view's page draws |
| Browser | `test-studio-browser.R`, `test-studio-app-browser.R`, `test-studio-theme-browser.R` | Locally with Chrome and in the off-CRAN job; not on CRAN or in R CMD check | What a user sees and clicks: controls, chips, panels, search, updates of the live mascot |

`Rscript tools/cran-gate.R tests` and `devtools::test()` run all of them; the browser tests need Chrome.

## Adding a view

A view is a page of the same app, such as the planned builder. To add one:

1. Add its name and page title to `studio_view_titles` in `R/views.R`, and a `list(ui =, server =)` to
   `studio_views()`, in the same order (the function stops when the names differ).
2. Put its page in `R/<view>-ui.R`, as `<view>_view_ui(query)`, and its server in `R/<view>-server.R`, as
   `<view>_view_server(input, output, session)`. Use the `R/shared-*.R` parts, never `www/studio.js` or the studio's
   own functions in `app.R`, and list the parts it uses at the top of its UI file, as `R/theme-ui.R` does.
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
   [`tests/README.md`](../tests/README.md)). The routing tests in `test-studio.R` ("mascot_studio() views")
   may need the new view.
