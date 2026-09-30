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
| Every function, exported or internal, checks its arguments first with checkmate | house | - |
| Other messages, warnings and errors use cli | house | - |

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
| Coverage of R code is at least 90 percent | house | - |

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
  build time), with `version` equal to the package version so browsers fetch new files after an upgrade; a Shiny
  output binding registered once under a package-qualified name for `mascotOutput()` and `renderMascot()`; and custom
  messages (for example `mascot:update`) for `updateMascot()`, addressed by the module-namespaced id and queued in JS
  until the element is bound.
- No htmlwidgets. It adds a dependency built around plots, and its Shiny proxy pattern is custom messages anyway.
  Revisit only if a standalone viewer or print method is wanted.
- One namespace, `window.mascot`. Guard against double loading, keep state per element, support several mascots on
  one page, and leave no global listeners behind.
- Configuration comes through `data-*` attributes (or a `<script type="application/json">` data block).
- No `eval`, no `new Function`, no inline `<script>` of our own, no inline `style=` for layout.

**Theming**

- Colours are read from CSS variables when drawing: Bootstrap 5.3's `--bs-*` variables (`--bs-body-color`,
  `--bs-body-bg`, `--bs-primary`, `--bs-border-color`), with `--mascot-*` variables as the fallback. This works with
  bslib, in Quarto (also Bootstrap 5) and on plain pages.
- Follow dark mode by watching `data-bs-theme` and the system preference.
- bslib is in `Suggests`, never `Imports`. 0.1.0 ships no fonts: the status text and speech bubble use the host
  page's font (the app's bslib theme, the Quarto or pkgdown site), never a font service.

**Accessibility**

- Status text sits beside every mascot in an element with `role="status"`. The mood never carries meaning alone
  (WCAG 1.4.1, 4.1.3). Validator errors may use `role="alert"`.
- The canvas has `role="img"` and an `aria-label` naming the mood, or is marked decorative when the text says it all.
- `prefers-reduced-motion` is honoured in CSS and JS: the wiggle becomes an instant change or a short fade. An R
  argument also switches animation off (WCAG 2.3.3).
- No automatic animation lasts longer than five seconds without a way to pause it (WCAG 2.2.2). The wiggle is short
  and there is no endless idle loop by default.
- Theme colours are checked for contrast, at least 3:1 for graphics, in light and dark (WCAG 1.4.11).

**Content Security Policy (CSP), stated honestly**

The docs say "mascot adds no inline script of its own". They do not say it works under any strict CSP, because Shiny
itself still uses inline scripts.

**Keep JS small**: decisions live in R, where they can be unit-tested. JS is tested through shinytest2 and the
widget's rendered output (section 6).

## 4. Bundled files and licences

- `inst/COPYRIGHTS` lists every bundled file: what it is, where it came from, who holds the copyright and under which
  licence. It records the engine (Harsh Verma, MIT, born in the playbook site's `tools/animate/`) and, once any are
  bundled, each font. 0.1.0 bundles no fonts; they may come with static images and trailers (later releases).
  `inst/COPYRIGHTS` is the file Writing R Extensions names (**CRAN**).
- Each font folder has its own `OFL.txt`. Both fonts are under the SIL Open Font Licence 1.1 and have no Reserved
  Font Name (checked 2026-09-29), so subset files keep their names.
- Each font project is added to `Authors@R` with the `cph` role and a `comment` saying which font it is (the pattern
  bslib uses). `Copyright: See inst/COPYRIGHTS` may be added if a reviewer asks (**CRAN**).
- Fonts are subset to the Latin range and shipped as WOFF2 to keep the tarball small (**house**).
- Where third parties contributed code, list them with `ctb` or `cph`.

**Acceptance checklist for the engine port** (and for any later JS, CSS, font or Lua file):

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

- Keep `Imports` small: htmltools, shiny, checkmate, cli, and perhaps rlang or jsonlite. Each new import needs a
  reason (**house**).
- Call functions as `pkg::fn()`. No `library()` or `require()` in package code (**CRAN**).
- Optional features use `Suggests` (chromote, av, shinyvalidate, shinytest2, quarto, bslib, spelling) and are guarded
  with `rlang::check_installed()` or `requireNamespace()`. Tests use `skip_if_not_installed()` (**CRAN**).
- Avoid `:::` into shiny or bslib: it is fragile, and reviewers flag it (**CRAN** for base packages, house for the
  rest).

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
- **Coverage is at least 90 percent, measured with covr on R code only.** covr does not see JS, so JS is covered by
  the shinytest2 behaviour tests. A PR never lowers coverage. `# nocov` is only for code that cannot run in a test,
  with a comment saying why.
- **No jest or vitest for now.** If pure JS functions grow (colour maths, easing), `node --test` needs no dependency.
- **Guardrails are tested too.** Each gate step has a probe in the gate's self-test that plants a defect and
  expects the step to fail, and a clean copy must pass (section 7.2).

## 7. The quality pipeline

### 7.1 One rule, three places

Each rule is written once, in git (`air.toml`, `.lintr`, `biome.json`, the gate script, the workflows). Three layers
run it:

| Layer | When it runs | Status |
|---|---|---|
| Editor settings (`.claude/settings.json`) | While an assistant works in the repo: permission rules deny force-push, pushes to `main`, `--no-verify` and hand edits to `NAMESPACE`, `man/`, `renv/`, `LICENSE`; merging a PR (`gh pr merge`) asks the maintainer for confirmation each time; attribution lines are off. Formatting is a one-line instruction (`air format .`) | In place |
| The gate (`/cran-gate`, section 7.2) | On demand, before a commit or PR | In place |
| CI | On every PR and push to `main` (the full platform matrix on `main`, weekly and on demand); it cannot be skipped | In place |

The editor settings are a guard rail rather than enforcement. CI is the gate. There is no pre-commit
framework for now (section 8). The repository is private on a plan without branch protection, so the rule is: CI
green, then ask before merging.

### 7.2 The gate

```sh
Rscript .claude/skills/cran-gate/scripts/cran-gate.R [fast|tests|full|lint] [--update-wordlist]
```

Run it from the package root. Each step prints `PASS`, `FAIL` or `SKIP` with a detail. Full output goes to a log file
in `tempdir()`, whose path is printed. The script exits with status 1 if any step fails. A missing tool is a failure,
never a silent skip. The script checks its own arguments with checkmate and is linted like any other code.

**The gate is a generic, self-contained skill.** The folder `.claude/skills/cran-gate/` (instructions, the script and
its self-test; the same copy in `.agents/skills/` for Codex and Gemini) names nothing about mascot, so another R
package can copy it as it is. What is specific to a package is kept out of the skill:

- CRAN checks always run. Style checks run when the package has the tool's settings file (`air.toml`, `.lintr`,
  `biome.json`) and are skipped with a reason otherwise. mascot has all three.
- Settings are `Config/cran-gate/*` fields in `DESCRIPTION`: `coverage` (default 80; mascot sets 90), `tarball-mb`
  (default 5, at most 9 because CRAN's limit is 10; mascot keeps 5) and `extra-dirs` (more folders to format-check
  and lint; mascot lists `tools` and the gate's own scripts).

| Step | fast | tests | full | lint | What it does |
|---|---|---|---|---|---|
| `tools` | yes | yes | yes | yes | Checks that the needed R packages, Air (when there is an `air.toml`) and Biome (when there is a `biome.json` and `inst/` has JS or CSS) are installed; prints `.libPaths()[1]` |
| `air` | yes |  | yes | yes | `air format --check` on the package and the extra folders |
| `biome` | yes |  | yes | yes | `biome ci inst`; SKIP only while `inst/` has no JS or CSS |
| `docs` | yes |  | yes | yes | Runs `devtools::document()` and fails if `man/`, `NAMESPACE` or `DESCRIPTION` changed (the roxygen version fields are ignored) |
| `lintr` | yes |  | yes | yes | `lintr::lint_package()` and `lintr::lint_dir()` on each extra folder; any lint fails |
| `value` | yes |  | yes | yes | Fails for any exported function of the package that has no help page or no `\value` |
| `spelling` | yes |  | yes | yes | `spelling::spell_check_package()`; any unknown word fails |
| `check_fast` | yes |  |  |  | `R CMD check --as-cran --no-tests` with `NOT_CRAN=false`; fails on any error, warning or note |
| `tests` |  | yes | yes |  | `devtools::test()` with `NOT_CRAN=true`, so Chrome tests run |
| `coverage` |  | yes | yes |  | `covr::package_coverage()`; fails under the limit in `DESCRIPTION` (90 percent here) |
| `check_full` |  |  | yes |  | CRAN-like `R CMD check --as-cran` with tests and `NOT_CRAN=false`; fails on any error, warning or note |
| `tarball` |  |  | yes |  | Builds the tarball; fails over the size limit (5 MB here) or if any `inst/` file is missing from it |

Notes:

- `tests` mode is tests and coverage only. The PR gate is `fast` plus `tests` (or `full`), plus CI.
- `--update-wordlist` adds unknown words to `inst/WORDLIST` and is never run without showing the words first (see 7.4).
- The gate writes to the repository in two deliberate cases: `document()` may rewrite `man/`, `NAMESPACE` and
  `DESCRIPTION` (the step then fails and names the files), and `--update-wordlist` rewrites `inst/WORDLIST`.
- In a git worktree, set `R_LIBS` to the main checkout's library, since renv keeps that library outside the repo.
  The `tools` step prints which library is in use.
- A setting outside its range (for example `tarball-mb: 12`) stops the gate with `FAIL settings`.

**The gate's self-test.** A check that cannot fail protects nothing, so the gate has its own test:
`test-cran-gate.R [all|static|heavy]`, beside the gate. Each probe copies the package to `tempdir()`, plants one defect
(an unformatted file, code with lints, a misspelt word, a failing test, untested code, a check note, a file
in `inst/` that the build leaves out, a missing tool) and runs the gate on the copy. The probe passes when the gate
exits 1 with `FAIL` for the step that should catch the defect; a clean copy must pass. One probe also shows that the
`tests` step runs with `NOT_CRAN=true` and the CRAN-like check with `NOT_CRAN=false`. The repository is never changed.
Probes for steps a package does not use are skipped, so the self-test works in any package. Run it after changing the gate, `.lintr`, `air.toml` or `biome.json`; a new gate step gets its probe in the same pull
request. `static` takes seconds, `all` about a minute today.

### 7.3 CI workflows


**Temporary while the repo is private (#113).** Private repos get a limited number of Actions minutes (macOS counts
10x, Windows 2x), and on 2026-09-30 they ran out. Until the repo is public, pull requests run `R CMD check` on Ubuntu
only, docs-only changes skip the R jobs, and the site builds only when something it shows changes. When the repo goes
public, before the CRAN submission, these workarounds are removed and every pull request runs all five platforms
again (#115).

| Workflow file | What it runs | What it blocks |
|---|---|---|
| `R-CMD-check.yaml` | `R CMD check --as-cran`: Ubuntu (R release) on pull requests; macOS and Windows (release) and Ubuntu (R-devel, release, oldrel-1) on pushes to `main`, every Monday and on demand, to save Actions minutes; `error-on: note`; `NOT_CRAN` unset, so Chrome tests skip as on CRAN | Any error, warning or note (on a PR: Ubuntu release; on `main` and weekly: all five platforms, including R-devel) |
| `test-coverage.yaml` | covr on Ubuntu with `NOT_CRAN=true`, so Chrome tests count | Coverage under 90 percent; no code yet means no gate yet |
| `lint.yaml` | Air 0.11.0, Biome 2.5.14, then the gate in `lint` mode | Formatting, JS and CSS lint, docs out of sync, lints, missing `\value`, unknown words |
| `gate-self-test.yaml` | The gate's self-test (`all`), only when the gate, its self-test, `.lintr`, `air.toml` or `biome.json` change, and on demand | A gate step that no longer fails on the defect it exists to catch |
| `check-no-suggests.yaml` | `R CMD check --as-cran` with only hard dependencies installed (plus testthat, knitr and rmarkdown) and a step that prints which `Suggests` are installed | Any unguarded use of a `Suggests` package; CRAN runs this check too |
| `pkgdown.yaml` | `pkgdown::check_pkgdown()` and the site build (`tools/build-site.R`), uploaded as an artifact | A broken site configuration or build; no deploy until the repo is public |
| `gitleaks.yml` | Secret scan over the full history | A committed secret |
| `release.yml` | On a change to `DESCRIPTION` on `main`: tags `vx.y.z` and creates a GitHub release from the `NEWS.md` section | Nothing; it does nothing for a development version |

Ubuntu runners are pinned (`ubuntu-26.04`; macOS and Windows use `-latest`), all workflows use `permissions: read-all`
(gitleaks and release ask for the little more they need), and cancel superseded runs. Keep the Air and Biome versions in
`lint.yaml` and `gate-self-test.yaml` in step with the local installs and with `biome.json`.

### 7.4 Tools

- **Air** (R formatter, https://posit-dev.github.io/air/). `air.toml` sets `line-width = 120`, the width our docs and
  lintr already use.
- **Biome** (formatter and linter for JS and CSS, https://biomejs.dev). `biome.json` covers `inst/**/*.js` and
  `inst/**/*.css`: two-space indent, width 120, single quotes, the `recommended` lint rules. It is build-ignored. The
  gate skips it only while `inst/` has no JS or CSS; once there is any, it is required and a missing binary fails.
- **lintr** (`.lintr`). Line length 120. Object names are `snake_case` or symbols, plus the Shiny names
  `mascotOutput`, `renderMascot` and `updateMascot`. The `:::`, `<<-` and `->>` operators are flagged. The banned
  function list is short and each entry has a reason:

  | Banned | Reason | Label |
  |---|---|---|
  | `library`, `require` | Declare the package and call `pkg::fn()`; use `requireNamespace()` or `rlang::check_installed()` | CRAN |
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
| Codecov | The repository is private. The 90 percent gate runs inside the coverage workflow. Optional once public |
| Screenshot tests | They differ between operating systems and Chrome versions. Values, DOM state and draw-call hashes are stable |
| jest or vitest | JS logic is kept small and tested through shinytest2. `node --test` is the fallback if pure functions grow |
| TypeScript and a build step | Only needed for TypeScript or npm libraries. Plain JS is its own source and needs no Node in CI |
| htmlwidgets | An extra dependency built around plots; `htmlDependency()` plus an output binding is enough |
| Minimum and maximum dependency matrices | Overkill for a package with few imports and no users yet |
| revdepcheck | No package depends on `mascot` yet |
| Licence-audit, CLA and codemeta bots | One maintainer and the licence record is `inst/COPYRIGHTS`; a bot adds upkeep without a reader |
| Posit's shiny-workflows | bslib's own workflow calls that setup overkill for most R packages; we copy r-lib's standard workflows |

## 9. Pre-submission checklist (M6)

Run these before submitting to CRAN:

1. The gate's `full` mode passes (`/cran-gate full`).
2. `urlchecker::url_check()` reports nothing.
3. `spelling::spell_check_package()` reports nothing.
4. `devtools::check(remote = TRUE, manual = TRUE)` gives 0 errors, 0 warnings and 0 notes apart from the expected
   "New submission" note.
5. `devtools::check_win_devel()`, `devtools::check_mac_release()` and `rhub::rhub_check()` are clean.
6. `cran-comments.md` lists test environments and results, explains GxP, and says there are no reverse dependencies.
7. The `NEWS.md` heading is `# mascot 0.1.0` and the version is set with `usethis::use_version()`.
8. `inst/COPYRIGHTS`, each `OFL.txt` and the `cph` entries agree with what is in `inst/`.
9. The repository is public, `URL` and `BugReports` resolve, and the website is live. CI runs the full platform
   matrix on every pull request again (the private-repo workarounds are removed, #115).
10. `riskmetric` has been run on the package and the score recorded.
11. Submit with `devtools::submit_cran()`. After acceptance: the release workflow tags the release, then bump back to a
    `.9000` development version.

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
