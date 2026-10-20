# Stress results: issue #172

**Run:** 2026-10-20, branch `test/172-stress-apps`, `Rscript tools/stress/run-stress.R` on macOS arm64.
R 4.6.1, shiny 1.14.0, shinytest2 0.5.1, chromote 0.5.1, bslib 0.12.0, Chrome 155.0.8059.85 (headless).

**Result: 30 PASS, 0 FAIL** (7 static syntax checks and 23 browser checks). The mascot's Shiny wiring held in
all five scenarios. No package defect was found.

## What held (browser checks)

| Scenario | What it did to the mascot | Result |
| --- | --- | --- |
| 01 many modules and tabs (plain, golem-style, rhino-style) | Eight nested modules in tabs, rapid tab clicks, an update in every module, then one more in module 4 | Every mascot kept its own mood and status; none updated another (3 layouts x 2 checks) |
| 02 `renderUI()` / `insertUI()` replacement | 20 re-renders with updates between them, update while the mascot is absent then insert, a duplicate id, a stale envelope replayed with a higher revision | Latest state kept after every re-render; the duplicate never took ownership; the stale update was ignored; no warning storm |
| 03 async (`ExtendedTask`, three observers) | Three observers updating one id before, during and after a delayed task, plus a re-render | Final state was the intended one; no warning storm |
| 04 heavy JavaScript and overlays | 200 DOM mutations, a custom input binding, notifications, a modal and progress, a high z-index overlay | The mascot kept drawing (canvas has pixels), kept its status, its menu stayed reachable above the overlay, updates applied while a modal was open |
| 05 slow server, bursts, disconnect | A 2 to 3 second handler with queued clicks, 200 updates in one flush, rapid inputs, a closed websocket | Only the last state remained and the page stayed responsive; the worried "connection lost" face appeared |

The reconnect check covers the disconnect face; recovery of a *resumed* session is skipped when the transport cannot
resume sessions (a normal local `runApp()` cannot). This is a limit of the test, not a pass for session recovery.

## How the runner got here (for the next person)
The first browser run (outside the sandbox) gave 13 PASS and 18 FAIL, and the first fixes gave 24 PASS and 6 FAIL. All
failures were mistakes in the harness, not in the package:
- `set_inputs()` was used on action buttons (use `click()`).
- A driver method was called with an argument it does not take.
- The replacement check waited for `snapshot.mount_token` to change. The token is derived from the mascot's content,
  so an identical re-render keeps it. The element's `snapshot.generation` is what changes on every remount.
Lesson: when a check times out, print the real host state (the runner now does) and read it before suspecting the package.

## Findings
None. Things the checks do not cover: real network loss and session resumption on a deployed server, touch devices,
and apps with many hundreds of mascots.

## All PASS lines of the final run
```
01-modules syntax: R files parse (static check only)
01-modules/golem syntax: R files parse (static check only)
01-modules/rhino syntax: R files parse (static check only)
02-replacement syntax: R files parse (static check only)
03-async syntax: R files parse (static check only)
04-dom-overlays syntax: R files parse (static check only)
05-slow-reconnect syntax: R files parse (static check only)
01-modules eight modules isolated after rapid tabs: held
01-modules no unexpected warning or error storm: held
01-modules/golem eight modules isolated after rapid tabs: held
01-modules/golem no unexpected warning or error storm: held
01-modules/rhino eight modules isolated after rapid tabs: held
01-modules/rhino no unexpected warning or error storm: held
02-replacement twenty replacements retain latest state: held
02-replacement update while absent then insert: held
02-replacement duplicate does not take ownership: held
02-replacement old generation cannot update replacement: held
02-replacement no unexpected warning or error storm: held
03-async observers during ExtendedTask: held
03-async observer after completion and replacement: held
03-async no unexpected warning or error storm: held
04-dom-overlays DOM churn and custom input binding: held
04-dom-overlays menu reachable above fixed overlay: held
04-dom-overlays progress and modal updates: held
04-dom-overlays no unexpected warning or error storm: held
05-slow-reconnect slow handler with queued clicks: held
05-slow-reconnect 200 updates in one flush: held
05-slow-reconnect rapid inputs settle and page responds: held
05-slow-reconnect websocket loss shows worried status: held
05-slow-reconnect no unexpected warning or error storm: held
```
