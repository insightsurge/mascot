# Shiny stress apps (#172)

Run from this checkout's root with `RENV_CONFIG_AUTOLOADER_ENABLED=FALSE` and `R_LIBS`
set to your existing development library (see the repository's working instructions).
Do not restore renv or install packages to run these apps.

```sh
Rscript tools/stress/run-stress.R
Rscript tools/stress/run-stress.R 02
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
| `02-replacement/app.R` | Replacement, absent updates, duplicates and stale envelopes | runner `02` |
| `03-async/app.R` | Delayed ExtendedTask, three observers, re-render | runner `03` |
| `04-dom-overlays/app.R` | DOM churn, custom input binding, overlays and menu reachability | runner `04` |
| `05-slow-reconnect/app.R` | Slow handler, bursts, rapid inputs, websocket reconnect | runner `05` |

For interactive inspection, first run `pkgload::load_all(".")`, then
`shiny::runApp("tools/stress/02-replacement")` (substitute any app folder above).
Use the buttons to reproduce the sequence documented in the scenario README and runner.
The golem layout needs golem; the rhino layout uses plain Shiny only.

Each assertion prints `PASS|FAIL <app> <check>: <detail>`. A failure exits non-zero.
Static syntax checks are explicitly labelled and do not count as browser passes.
Missing shinytest2, chromote or Chrome, including failure to start Chrome, produces
`SKIP` and exits zero. Launch and assertion errors after browser startup are failures.
Do not infer a successful stress run from a zero exit status when SKIP lines appear.
The recovery assertion in scenario 05 is also explicitly skipped when the websocket
transport cannot resume sessions (the local raw-websocket transport). The actual
socket-close/disconnected-mood assertion still runs. A new session would not prove
retained state replay. Failures include actual host mood/status, controller state,
mount snapshots and Shiny inputs beside the expected wait condition.
Duplicate-ID diagnostics are expected only in scenario 02; other warnings/errors fail.
The menu test uses pointer hit testing, not just a programmatic open-state assertion.
The stale-update test reuses a real complete server envelope from the previous mount,
raises its revision and changes its payload, retaining the obsolete generation.

[RESULTS.md](RESULTS.md) records observations and limitations. Package code is never
fixed by these tools; confirmed failures belong in follow-up issues.
