# Shiny stress apps

Run from this checkout's root with `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE` and `R_LIBS`
set to your existing development library.
Do not restore renv or install packages to run these apps.

```sh
Rscript tools/stress/run-stress.R
Rscript tools/stress/run-stress.R 02
Rscript tools/stress/run-stress.R --strict
```

The optional two-digit prefix selects a scenario. Scenario 01 runs three layouts.
The runner copies apps to `tempdir()` and prepends `pkgload::load_all()` with the
checkout root inside each app's launch. It exercises checkout R code and assets,
not an installed mascot. Browser profiles, logs and screenshots stay in `tempdir()`.
The child apps inherit the caller's R library. No app uses external network services.
The runner temporarily sets `NOT_CRAN=true` to allow these explicit browser trials.

| App | Tries to break | Run |
| --- | --- | --- |
| `01-modules/app.R` | Eight nested modules, fast tabs, independent mood/status | runner `01` |
| `01-modules/golem/app.R` | Function-built golem UI/server, eight nested modules | runner `01` |
| `01-modules/rhino/app.R` | Separate `app/view` environments, eight nested modules; no rhino dependency | runner `01` |
| `02-replacement/app.R` | Replacement, absent updates, duplicates, stale envelopes; swaps, bubbles and a nod across replacements; a floating mascot replaced and removed | runner `02` |
| `03-async/app.R` | Delayed ExtendedTask, three observers, re-render | runner `03` |
| `04-dom-overlays/app.R` | DOM churn, custom input binding, overlays and menu reachability | runner `04` |
| `05-slow-reconnect/app.R` | Slow handler, a burst with swaps, bubbles and nods, rapid inputs, a reconnect into a new session | runner `05` |
| `06-later/app.R` | Updates from a `later()` callback and a promise, with nothing else happening on the page | runner `06` |
| `07-dynamic-modules/app.R` | Forty modules added and removed at run time, each with a fresh id | runner `07` |
| `08-dark-mode/app.R` | bslib dark-mode switching from the server; a fixed light theme beside it | runner `08` |
| `09-bookmark/app.R` | URL bookmarking and an update from `onRestore()` | runner `09` |
| `10-cache/app.R` | A mascot in a `renderUI()` cached with `bindCache()`, shown to a second session | runner `10` |

Motion is on in 02 and 05-09, so updates, swaps and replacements land while the mascot animates.
01, 03, 04 and 10 keep `motion = FALSE`; they test wiring, not animation.

For interactive inspection, first run `pkgload::load_all(".")`, then
`shiny::runApp("tools/stress/02-replacement")` (substitute any app folder above).
Use the buttons to reproduce the sequence documented in the scenario README.
The golem layout needs golem; the rhino layout uses plain Shiny only.

## How the runner is organised

- `run-stress.R` holds only what every scenario shares: starting the app, the `check()`, `state()`, `replace()`,
  `skip()` and `known()` helpers, and the final warning check.
- Each scenario's checks live next to its app in `checks.R`, as a `stress_checks(ctx)` function. The golem and rhino
  layouts use `01-modules/checks.R`. A `checks.R` may set `stress_expected_warnings` (a pattern and a maximum count)
  for warnings the scenario causes on purpose; more than the maximum fails, so a storm of them still fails.

## Results

Each assertion prints one line:

- `PASS|FAIL <app> <check>: <detail>`. A failure exits non-zero.
- `KNOWN <app> <check>: #<issue>`: the check fails because of an open package issue. It doesn't fail the run. Once
  the issue is fixed the check passes and prints `FAIL ... now passes`, so the fix PR removes the marker.
- `SKIP`: missing shinytest2, chromote or Chrome, including failure to start Chrome. A SKIP exits zero, so never
  read a zero exit as a stress pass when SKIP lines appear. With `--strict` (for a CI job, if one is added), any SKIP exits non-zero.

Static syntax checks are explicitly labelled and do not count as browser passes. Failures include the actual host
state (character, mood, status, bubble, the drawn frame, snapshot) and the Shiny inputs beside the expected condition.
The menu test uses pointer hit testing, not just a programmatic open-state assertion.
The stale-update test reuses a real complete server envelope from the previous mount,
raises its revision and changes its payload, retaining the obsolete generation.
Scenario 05 uses `session$allowReconnect("force")`, which Shiny provides for testing reconnects locally: as on Shiny
Server or Connect, the page reconnects into a new server session.

Read each run's assertion lines and final summary for failures, known issues and skips.
Package code is never fixed by these tools; confirmed failures belong in follow-up issues.
