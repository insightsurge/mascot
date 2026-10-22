# mascot engineering standards

This page records the rules that `mascot` follows to be accepted on CRAN and to stay easy to review, and the reasons
for them. It is the long version. Short rule files live in `.claude/rules/` and link back here.

Each rule carries a label:

- **CRAN**: required by CRAN policy, Writing R Extensions or `R CMD check`. No exceptions.
- **house**: our own standard. A justified exception is allowed, with a comment next to the code saying why.

Source codes used in the tables (full names are in section 10): POL = CRAN Repository Policy, CHK = CRAN submission
checklist, WRE = Writing R Extensions, INTS = R Internals, COOK = CRAN Cookbook, RPKGS = R Packages (2nd edition),
WCAG = Web Content Accessibility Guidelines.

The package is built for GxP work. That is a design aim (readable code, deterministic output, offline, tested), not a
claim about the package's status.

## 1. CRAN acceptance criteria

### 1.1 DESCRIPTION

| Rule | Label | Source |
|---|---|---|
| One named maintainer with a working email address (a person, not a list) | CRAN | POL |
| `Authors@R` gives every author a role; other copyright holders are listed with `cph` | CRAN | POL |
| The licence is in CRAN's licence database; for MIT use `MIT + file LICENSE` with the YEAR and COPYRIGHT HOLDER stub | CRAN | COOK |
| Title in Title Case, without "in R" or "A package for", and without a final full stop | CRAN | COOK |
| Description has two or more sentences and does not start with the package name or "This package" | CRAN | COOK, CHK |
| Software names in single quotes ('Shiny', 'Quarto', 'JavaScript'); functions written `foo()`; URLs in `<...>` | CRAN | COOK, CHK |
| Acronyms such as GxP are explained (in `cran-comments.md` if not in the text) | CRAN | COOK |
| `URL` and `BugReports` resolve (the repository is public before submission) | CRAN | CHK |
| `Language: en-GB`, and the text is spelt in British English | house | - |
| Strong dependencies are on CRAN; `Suggests` packages are used conditionally | CRAN | POL |
| No `LazyData` unless there is a `data/` directory | CRAN | WRE |

### 1.2 Code behaviour

| Rule | Label | Source |
|---|---|---|
| Write only to `tempdir()`, or to a path the user passes; never to the home directory or clipboard | CRAN | POL |
| Do not modify the global environment | CRAN | POL |
| Restore options, `par()` and the working directory with `on.exit()` or `withr::local_*()` | CRAN | COOK |
| No side effects on load or attach | house | - |
| Messages go through `message()` or cli, never `print()` or `cat()` | CRAN | COOK |
| No fixed `set.seed()` inside functions; expose a `seed` argument if R-side randomness is needed | CRAN | COOK |
| `TRUE` and `FALSE`, never `T` and `F`; no `options(warn = -1)`; no `installed.packages()` | CRAN | COOK |
| Do not start browsers or viewers in examples or tests unless they are closed again | CRAN | POL |
| Use at most two cores | CRAN | POL |
| Nothing is downloaded at run time; internet use, if any, fails gracefully. `mascot` uses no network at all | CRAN | POL |
| No `:::` into base packages and no `.Internal()`; avoid `:::` into any other package too | CRAN | POL |
| Send no data about the user's session anywhere | CRAN | POL |
| Every function checks its arguments first with checkmate; per-node/recursive helpers may reuse caller-checked inputs under the exception in `.claude/rules/r-code.md` (top-level helpers need a comment; inner closures may reuse the enclosing checked inputs) | house | - |
| Other messages, warnings and errors use cli | house | - |
| Every top-level `mascot()` argument takes a plain shortcut or a `mascot_*()` helper (bslib style); every helper and listing function uses `mascot_` for autocomplete and to avoid clashes. Check new exports against base R, shiny, bslib and ggplot2 | house | - |

Building UI with `mascot()` or helpers errors on invalid values; `update_mascot()` warns and leaves the
mascot unchanged. cli conditions have `mascot_error`, `mascot_warning` or `mascot_message` classes;
ignored updates also have `mascot_update_ignored`, contrast warnings have `mascot_contrast`, and inline
placement messages have `mascot_placement_ignored`. Checkmate assertion errors retain their own classes.
R contrast warnings appear in Shiny development mode, previews and the studio by default;
`options(mascot.contrast_warnings = TRUE)` or `FALSE` forces them on or off everywhere. Colours are kept.

### 1.3 Files and size

| Rule | Label | Source |
|---|---|---|
| Source is included for every component | CRAN | POL |
| No binary executables | CRAN | POL |
| Tarball under 10 MB if at all possible; installed size under 5 MB (larger is a NOTE) | CRAN | POL, INTS |
| Our tarball target is under 5 MB; the gate fails above it | house | - |
| Portable file names: ASCII, no spaces, no names differing only by case, paths of at most 100 bytes | CRAN | WRE |
| No stray top-level or hidden files; every config file is listed in `.Rbuildignore` | CRAN | INTS |
| Leave no files in the check directory, temporary directory or home directory | CRAN | INTS |
| Do not use reserved names inside `inst/` (`R`, `data`, `demo`, `exec`, `libs`, `man`, `help`, `html`, `Meta`, `src`) | CRAN | WRE |
| `docs/`, `tools/`, `dev/` and tool config files are build-ignored | house | - |

### 1.4 Documentation and examples

| Rule | Label | Source |
|---|---|---|
| Every function's help page has a `\value` section (`@returns` in roxygen2) | CRAN | COOK |
| Every export has `@examples` that run offline | house | - |
| Each example runs in a few seconds; unwrap examples that take under five seconds | CRAN | POL, COOK |
| `\dontrun{}` only when the code truly cannot run; `\donttest{}` sparingly and with a reason; Shiny apps under `if (interactive())` | CRAN | COOK |
| Edit the `.R` files and re-run `document()`; never edit `.Rd` files or `NAMESPACE` by hand | CRAN | COOK |
| Use https and canonical URLs; no relative links to README or LICENSE inside Rd files | CRAN | CHK |
| `NEWS.md` parses, and each release has a `# mascot x.y.z` section | CRAN | INTS |

### 1.5 Tests

| Rule | Label | Source |
|---|---|---|
| Tests use little CPU time | CRAN | POL |
| No Chrome (chromote or shinytest2) on CRAN: `skip_on_cran()` and a skip when `chromote::find_chrome()` returns `NULL` | CRAN | shinytest2 docs |
| CRAN checks with only the declared packages and also checks without `Suggests`; every use of a `Suggests` package is guarded | CRAN | INTS |
| Tests that write files use `withr::local_tempdir()` and leave nothing behind | CRAN | INTS |
| Coverage of R code is at least 70 percent (CRAN does not measure coverage) | house | - |

### 1.6 JavaScript, CSS, fonts and third-party files

| Rule | Label | Source |
|---|---|---|
| Nothing in the policy singles out minified JavaScript; the general rule applies: source, or something that can easily be converted back to source | CRAN | POL, WRE |
| We ship plain, unminified JS and CSS in `inst/`, with no build step | house | - |
| If a build ever arrives (TypeScript, npm libraries): keep sources in git, build-ignore them, and ship both the unminified file and the `.min.js` and source map | house | - |
| The copyright of every bundled component is clear and unambiguous | CRAN | POL |
| Other copyright holders appear as `cph` roles, or in a `Copyright:` field pointing to `inst/COPYRIGHTS` | CRAN | POL, WRE |
| No CDN and no run-time downloads: JS, CSS and fonts are bundled | CRAN | POL |
| OFL fonts are redistributable with their licence text; the Reserved Font Name clause matters only for modified fonts | house | OFL 1.1 text |

### 1.7 Submission

| Rule | Label | Source |
|---|---|---|
| Submit through the web form, with `R CMD check --as-cran` run on the built tarball with current R-devel | CRAN | POL, CHK |
| No warnings; every note is explained in `cran-comments.md` (the "New submission" note is expected) | CRAN | CHK |
| Do not resubmit while a submission is pending; raise the version on each resubmission | CRAN | CHK |
| Reply to a reviewer by resubmitting with an explanation | CRAN | CHK |
| 0 errors, 0 warnings, 0 notes before every PR, not only before submission | house | - |

## 2. Absolute don'ts and common reviewer requests

Never do any of the following. Each one is a policy line or a standard reviewer request.

- Write outside `tempdir()` or a path the user passed; touch the home directory or the clipboard.
- Change the user's global environment, options, `par()` or working directory without restoring them.
- Start a browser, viewer or app in an example or test; use Chrome (chromote or shinytest2) on CRAN.
- Use the network at run time, in examples, tests or vignettes; load anything from a CDN.
- Use more than two cores.
- Ship binaries, or code whose source is not in the package; bundle anything with unclear copyright.
- Call `q()` or `.Internal()`; use `:::` into base packages; alter another package's namespace.
- Use `print()` or `cat()` for messages, `T` or `F`, `set.seed()` inside functions, `options(warn = -1)`,
  `installed.packages()`, or `library()` and `require()` in package code.
- Use `\dontrun{}` for code that can run.
- Send anything about the user's session anywhere.
- Say "validated" or "GxP compliant" about the package (the phrase is "built for GxP work"), or let a mood carry
  meaning on its own (house rules).

The CRAN Cookbook lists what reviewers ask for most often. Check each before submitting:

- More detail in `Description`.
- Unwrap examples that run in under five seconds.
- `\dontrun{}` changed to `\donttest{}`.
- A missing `\value` section.
- Software names not in single quotes.
- Title not in Title Case.
- Options not restored with `on.exit()` after a change.
- Temporary files left behind.
- Writing to the home directory.
- A long check time.
- Acronyms not explained.
- A missing `cph` role.
- Relative or non-canonical URLs.
- Spelling.

## 3. The UI engine (JavaScript and CSS)

The engine is most of what a user sees, so it has its own rules. All of these are **house** rules unless marked.

**Files and build**

- Plain, unminified, readable JavaScript (ES2015 or later) and CSS in `inst/`, with no build step, no bundler and no
  modules. Readable JS is its own source, which satisfies CRAN's source rule (**CRAN**) and lets a reviewer read
  exactly what runs. It also needs no Node in CI. shinyjs and htmlwidgets ship hand-written JS the same way.
- No CDN and no external request of any kind (**CRAN**, see 1.2).
- Deterministic drawing: a seeded random number generator, no `Math.random`, no clock-driven drawing. The same input
  gives the same frames, which makes tests possible.
- Target current versions of Chrome, Edge, Firefox and Safari, and say so in the docs.

**Architecture**

- Three layers: an `htmltools::htmlDependency()` built inside a function at run time (never with `system.file()` at
  build time), with `version` equal to the package version; a Shiny input binding registered once as `mascot.mascot`,
  mounting on subscribe and cleaning up on unsubscribe; and custom messages (`mascot:update`) addressed by the
  module-namespaced id and queued in JS until the element is bound. Only input bindings have these lifecycle hooks,
  and Shiny's duplicate-id check then covers mascots. No `mascotOutput()` or `renderMascot()`.
- No htmlwidgets. It adds a dependency built around plots, and its Shiny proxy pattern is custom messages anyway.
  Revisit only if a standalone viewer or print method is wanted.
- One namespace, `window.mascot`. Guard against double loading, keep state per element, support several mascots on
  one page, and leave no global listeners behind.
- The engine is versioned with the package: `window.mascot.version` is the package version, which R passes as a
  `data-mascot-version` attribute on the first engine script, and a page that loads a second engine of another
  version warns in the console. Character files keep their own `format_version`, 1 (see section 9).
- Configuration comes through `data-*` attributes (or a `<script type="application/json">` data block).
- No `eval`, no `new Function`, no inline `<script>` of our own, no inline `style=` for layout.

**Theming**

- Panels follow the page's Bootstrap `--bs-*` colours by default. Public `--mascot-panel-*` and
  `--mascot-restore-*` colour hooks take priority over
  both Bootstrap and copied page colours, including in bslib apps. The deliberate public list lives in
  `?mascot_styling`; every other mascot custom property uses the private `--_mascot-*` prefix. Character colours
  are controlled by `mascot_theme()`.
- Follow dark mode by watching `data-bs-theme` and Quarto's body classes; with no signal, light (a plain page in
  an OS dark mode stays light, so the drawing and the bubble match the page).
- bslib is in `Suggests`, never `Imports`. 0.1.0 ships no fonts: the status text and speech bubble use the host
  page's font (the app's bslib theme, the Quarto or pkgdown site), never a font service.

**Accessibility**

- Status text sits beside every mascot in an element with `role="status"`. The mood never carries meaning alone
  (WCAG 1.4.1, 4.1.3). Validator errors may use `role="alert"`.
- When not clickable, the canvas has `role="img"` and an `aria-label` naming the mood, or is marked decorative when
  the text says it all, and it is no keyboard stop. With a click, a native button named by the action's label (or
  the menu's) wraps it, so screen readers say what a click does (#257).
- `prefers-reduced-motion` is honoured in CSS and JS: the wiggle becomes an instant change or a short fade. An R
  argument also switches animation off (WCAG 2.3.3).
- No automatic animation lasts longer than five seconds without a way to pause it (WCAG 2.2.2). The wiggle is short
  and there is no endless idle loop by default.
- Theme colours are checked for contrast, at least 3:1 for graphics, in light and dark (WCAG 1.4.11).

**Content Security Policy (CSP), stated honestly**

The docs say "mascot adds no inline script of its own". They do not say it works under any strict CSP, because Shiny
itself still uses inline scripts.

**Keep JS small**: decisions live in R, where they can be unit-tested. JS is tested through shinytest2 and the
widget's rendered output (section 6). Every change in `inst/www/` adds an entry to
`vignettes/articles/engine-changelog.Rmd`.

## 4. Bundled files and licences

- `inst/COPYRIGHTS` lists every bundled file: what it is, where it came from, who holds the copyright and under which
  licence. It records the engine (the package creator, MIT) and, once any are bundled, each font. 0.1.0 bundles no
  fonts; they may come with static images and trailers in later releases.
  `inst/COPYRIGHTS` is the file Writing R Extensions names (**CRAN**).
- Where third parties contributed code, list them with `ctb` or `cph`.

**When fonts are bundled:**

- Each font folder must have its own `OFL.txt`. Both fonts (Hanken Grotesk and JetBrains Mono, the website's fonts) are under
  the SIL Open Font Licence 1.1 and have no Reserved Font Name (checked 2026-10-22), so subset files keep their names.
- Each font project is added to `Authors@R` with the `cph` role and a `comment` saying which font it is (the pattern
  bslib uses). `Copyright: See inst/COPYRIGHTS` may be added if a reviewer asks (**CRAN**).
- Fonts are subset to the Latin range and shipped as WOFF2 to keep the tarball small (**house**).

**Acceptance checklist for bundled JS, CSS, font or Lua files:**

1. Every shipped JS, CSS, font and Lua file is present in the built tarball (the gate's tarball step checks that
   each file under `inst/` is shipped).
2. Each file is recorded in `inst/COPYRIGHTS` with source, holder and licence.
3. The file loads offline from the installed package, with no network request.
4. Paths are portable and case-correct: ASCII, no spaces, at most 100 bytes, and the case in the code matches the
   case on disk (a mismatch works on macOS and Windows and fails on Linux).
5. The installed size stays under the target, and the size check in R CMD check passes.

## 5. Documentation and dependencies

**Documentation** (roxygen2 with markdown):

- Every function has `@returns` (**CRAN**; the gate's `\value` step lists exports without it).
- Every export has `@examples` that run offline and quickly (**house**). Shiny apps and anything that opens a browser
  sit under `if (interactive())`.
- Edit the `.R` source, run `devtools::document()`, and commit `man/` and `NAMESPACE`. The gate fails if
  `document()` changes anything.
- URLs use https and are canonical. Software names in `DESCRIPTION` are in single quotes.
- Wording: no hype, no unmeasured numbers, "built for GxP work" and never "validated" or "GxP compliant", and no
  employer, client or internal system named (**house**).
- Every user-facing change adds a bullet to `NEWS.md` in the same PR (tidyverse style, see `CLAUDE.md`).

**Dependencies:**

- Keep `Imports` small: checkmate, cli, htmltools, jsonlite and shiny. Each additional import needs a
  reason (**house**).
- Call functions as `pkg::fn()`. No `library()` or `require()` in package code (**CRAN**).
- Optional and development packages use `Suggests`: bslib (>= 0.6.0), chromote, covr, golem, knitr, later, lifecycle,
  promises, rmarkdown, shinytest2 (>= 0.5.0), testthat (>= 3.0.0) and withr. Optional features check availability
  with `requireNamespace()` before use. Tests use `skip_if_not_installed()` (**CRAN**).
- Avoid `:::` into shiny or bslib: it is fragile, and reviewers flag it (**CRAN** for base packages, house for the
  rest).

### Lifecycle and status words

**House.** The lifecycle badge is used only for experimental and deprecated. Other promises weaker than "stable"
use plain words in help pages:
- **informal:** the shape is not promised (example: the palettes text in `mascot_characters()`).
- **add-only:** ids and columns may be added, never removed or renamed.
- **reserved:** a name held back so nothing else can take it (example: `wear`, `minimal`, `pastel`, `vivid`, `corporate`, `earthy`, `night`, `original`).
- **dev-mode only:** appears only in Shiny development mode.

**Experimental in 0.1.0:**
- Knurl and Neer
- `mascot_studio()`
- `mascot_preview()`
- `mascot_theme(css =)`
- `mascot_placement(drag = "free")`
- which parts of a character a `bs_theme()` colours
- `mascot_read_character()` and `mascot_check_character()`
- the character file format

## 6. Testing

- **A pyramid.** Most tests are fast unit tests. Above them sit `shiny::testServer()` tests for server logic, and
  above those a small number of shinytest2 tests for what a user sees.
- **BDD style** (testthat 3rd edition). One test file per R file. `describe()` names the function or behaviour and
  `it()` states the expected behaviour in plain words, so the test names read as requirements.
- **Every argument check has a test** showing it fails with a clear message. Every bug fix gets a test.
- **Snapshots** (`expect_snapshot()`) for printed output and generated HTML. Review every snapshot change in the PR
  like code.
- **shinytest2 assertions are on values, DOM state and status text, not on screenshots.** Use `app$get_value()`,
  `app$expect_values()`, and `app$get_js()` reading the engine's exposed state (current mood, frame number, a hash of
  the draw-call list), `data-*` attributes and the `role="status"` text. Because frames are deterministic, a hash of
  the draw calls is a stable target across operating systems. A pixel hash is only for one pinned Chrome. Apps live
  in `tests/testthat/apps/<name>/app.R`.
- **Skips.** Every shinytest2 file starts with `skip_on_cran()`, `skip_if_not_installed("shinytest2")` and a skip
  when `chromote::find_chrome()` returns `NULL`, and stops the app with `withr::defer(app$stop())`.
- **Files.** Tests that write files use `withr::local_tempdir()`.
- **Coverage is at least 70 percent, measured with covr on R code only.** This is our rule: CRAN's policy and
  `R CMD check` say nothing about coverage. The limit is `Config/cran-gate/coverage` in `DESCRIPTION`. covr does not
  see JS, so JS is covered by the shinytest2 behaviour tests. A PR never lowers coverage. `# nocov` is only for code
  that cannot run in a test, with a comment saying why.
- **No jest or vitest for now.** If pure JS functions grow (colour maths, easing), `node --test` needs no dependency.
- **Guardrails are tested too.** Each gate step has a probe in the gate's self-test that plants a defect and
  expects the step to fail, and a clean copy must pass (section 7.2).

## 7. The quality pipeline

### 7.1 One rule, three places

Each rule is written once, in git (`air.toml`, `.lintr`, `biome.json`, the gate script, the workflows). Three layers
run it:

| Layer | When it runs | Status |
|---|---|---|
| Editor settings (`.claude/settings.json`) | While an assistant works in the repo: permission rules deny force-push, pushes to `main`, `--no-verify` and hand edits to `NAMESPACE`, `man/`, `renv/`, `LICENSE`; merging a PR (`gh pr merge`) asks for confirmation each time; attribution lines are off. Formatting is a one-line instruction (`air format .`) | In place |
| The gate (`Rscript tools/cran-gate.R`, section 7.2) | On demand, before a commit or PR | In place |
| CI | On every PR and push to `main` (the full platform matrix on `main`, weekly and on demand); it cannot be skipped | In place |

The editor settings are a guard rail rather than enforcement. CI is the gate. There is no pre-commit
framework for now (section 8). The repository is private on a plan without branch protection, so the rule is: CI
green, then ask before merging.

### 7.2 The gate

How to run it, which mode when, every option, the exit codes and the run folder: `tools/README.md` (and
`Rscript tools/cran-gate.R --help`; `--list` shows each mode's steps). This section keeps the reasons.

**The gate is a generic, self-contained script.** `tools/cran-gate.R` and its self-test `tools/test-cran-gate.R`
name nothing about mascot, so another R package can copy them as they are. What is specific to a package is kept
out of the script:

- CRAN checks always run. Style checks run when the package has the tool's settings file (`air.toml`, `.lintr`,
  `biome.json`) and are skipped with a reason otherwise. mascot has all three.
- Settings are `Config/cran-gate/*` fields in `DESCRIPTION`: `coverage` (default 70, which mascot uses), `tarball-mb`
  (default 5, at most 9 because CRAN's limit is 10; mascot keeps 5) and `extra-dirs` (more folders to format-check
  and lint; mascot lists `tools`, which holds the gate itself).

A missing tool stops the gate, never a silent skip. The gate writes to the repository in two deliberate cases only:
`document()` may rewrite `man/`, `NAMESPACE` and `DESCRIPTION` (the step then fails and names the files), and
`--update-wordlist` rewrites `inst/WORDLIST`, which is never run without showing the words first (see 7.4).

**The gate's self-test.** A check that cannot fail protects nothing, so the gate has its own test,
`tools/test-cran-gate.R`. Each probe copies the package (or a tiny generated one) to `tempdir()`, plants one defect
(an unformatted file, code with lints, a misspelt word, a failing test, untested code, a check note, a file in `inst/`
that the build leaves out, a missing tool) and runs the gate on the copy; the probe passes when the gate fails that
step. A clean copy must pass, and the repository is never changed. Probes for steps a package does not use are
skipped, so the self-test works in any package. A new gate step gets its probe in the same pull request.

### 7.3 CI workflows

What each workflow runs, and the gate mode that reproduces it locally: `tools/README.md` ("The gate and CI").

Every pull request runs the full matrix (macOS, Windows and four Ubuntu R versions); keep new jobs on Ubuntu unless
the platform is the point.

The site is built from `main` only, never on pull requests (#127): a site build may need packages that outside
contributors' pull requests can't install. Ubuntu runners are pinned (`ubuntu-26.04`; macOS and Windows use
`-latest`) so an image change is a deliberate edit. Workflows take the least permissions they need and cancel
superseded runs (except a release, and secret scans on `main`). Every job has a `timeout-minutes`, a few times its
longest recent run, so a hung step can't hold a runner for hours. Actions from `actions/` and `r-lib/` are pinned by
major tag; other third-party actions by full commit SHA with a `# vX.Y.Z` comment, because a tag can be moved and a
SHA cannot. Dependabot updates both kinds and rewrites the version comment. Keep the Air and Biome versions in
`lint.yaml` and `gate-self-test.yaml` in step with the local installs and with `biome.json`.

### 7.4 Tools

- **Air** (R formatter, https://posit-dev.github.io/air/). `air.toml` sets `line-width = 120`, the width our docs and
  lintr already use.
- **Biome** (formatter and linter for JS and CSS, https://biomejs.dev). `biome.json` covers `inst/**/*.js` and
  `inst/**/*.css`: two-space indent, width 120, single quotes, the `recommended` lint rules. It is build-ignored. The
  gate skips it only while `inst/` has no JS or CSS; once there is any, it is required and a missing binary fails.
- **lintr** (`.lintr`). Line length 120. Object names are `snake_case` or symbols. The `:::`, `<<-` and `->>` operators are flagged. The banned
  function list is short and each entry has a reason:

  | Banned | Reason | Label |
  |---|---|---|
  | `library`, `require` | Declare the package and call `pkg::fn()`; use `requireNamespace()` for optional packages | CRAN |
  | `attach` | Do not change the user's search path | CRAN |
  | `setwd` | Use `withr::local_dir()` or a path argument | CRAN |
  | `Sys.setenv` | Use `withr::local_envvar()` | CRAN |
  | `print`, `cat` | Use cli for messages (a `print()` method may use `# nolint`) | CRAN |
  | `set.seed` | Take a `seed` argument instead | CRAN |
  | `source` | Put code in `R/` | house |
  | `browser`, `debug`, `debugonce` | Remove debugging code | house |

  Files under `tests/` are exempt from the banned function list and from `object_usage_linter`. `dev/` and `renv/` are
  not linted. A `# nolint` comment must say why.
- **Spelling.** `spelling::spell_check_package()` with `Language: en-GB` and `inst/WORDLIST`. The gate fails on any
  unknown word, and there is no `tests/spelling.R`, so there is one policy in one place. Words go into the word list
  only after review (names, technical terms), never automatically.

## 8. What we left out on purpose

| Left out | Why |
|---|---|
| Pre-commit framework | One maintainer and no shared clone yet; it needs a Python tool. The gate and CI cover the same checks. Revisit when others commit |
| Codecov | The repository is private. The 70 percent gate runs inside the coverage workflow. Optional once public |
| Screenshot tests in the test suite and CI | They differ between operating systems and Chrome versions. Values, DOM state and draw-call hashes are stable. |
| jest or vitest | JS logic is kept small and tested through shinytest2. `node --test` is the fallback if pure functions grow |
| TypeScript and a build step | Only needed for TypeScript or npm libraries. Plain JS is its own source and needs no Node in CI |
| htmlwidgets | An extra dependency built around plots; `htmlDependency()` plus an output binding is enough |
| Minimum and maximum dependency matrices | Overkill for a package with few imports and no users yet |
| revdepcheck | No package depends on `mascot` yet |
| Licence-audit, CLA and codemeta bots | One maintainer and the licence record is `inst/COPYRIGHTS`; a bot adds upkeep without a reader |
| Posit's shiny-workflows | bslib's own workflow calls that setup overkill for most R packages; we copy r-lib's standard workflows |

## 9. Releases

Releases, CRAN submissions and their checklist are the package creator's. A contributor never changes the version
or the release headings in `NEWS.md`.

### Package versions

- Patch releases contain compatible fixes, including fixes to experimental features.
- Minor releases add features and deprecations. Before 1.0.0, announced breaking changes also use a minor release.
- Deprecations are kept for at least one release before removal.
- A CRAN release is tagged after CRAN accepts it.

### Character format compatibility

The format is experimental and its future direction is open; these points hold either way. Additions (new optional
keys, wider ranges, new categories) stay in format version 1, so existing files keep working. A file that uses an
addition lists it in `requires`, and an older version of mascot then stops with an error naming it instead of drawing
it wrongly. Only a change that would break existing files introduces format version 2; retiring an older format
version is announced in NEWS at least one release ahead. The checker may only get stricter in a new format version,
except for a documented security or resource-safety fix, which comes with a diagnostic and migration guidance. Files
are never modified or upgraded silently. Resolved files are self-contained.

## 10. Sources

- **POL:** CRAN Repository Policy, <https://cran.r-project.org/web/packages/policies.html>
- **CHK:** CRAN submission checklist, <https://cran.r-project.org/web/packages/submission_checklist.html>
- **WRE:** Writing R Extensions, <https://cran.r-project.org/doc/manuals/r-release/R-exts.html>
- **INTS:** R Internals (the `_R_CHECK_*_` settings, including `_R_CHECK_SUGGESTS_ONLY_`),
  <https://cran.r-project.org/doc/manuals/r-release/R-ints.html>
- **COOK:** CRAN Cookbook, <https://contributor.r-project.org/cran-cookbook/>
- **RPKGS:** R Packages (2e), <https://r-pkgs.org>
- shinytest2, using it in a package (CRAN's request about chromote),
  <https://rstudio.github.io/shinytest2/articles/use-package.html>
- r-lib/actions (`check-r-package`, the `check-no-suggests` example), <https://github.com/r-lib/actions>
- Air, <https://posit-dev.github.io/air/>; Biome, <https://biomejs.dev>; lintr, <https://lintr.r-lib.org>
- **WCAG** 2.2 (1.4.1, 1.4.11, 2.2.2, 2.3.3, 4.1.3), <https://www.w3.org/TR/WCAG22/>
- SIL Open Font License 1.1, <https://openfontlicense.org>
- Examples of practice: bslib (<https://github.com/rstudio/bslib>: bundled fonts, `LICENSE.note`, `cph` entries) and
  teal (<https://github.com/insightsengineering/teal>: `.lintr`, CI)
- R Validation Hub: riskmetric, <https://pharmar.github.io/riskmetric/>
