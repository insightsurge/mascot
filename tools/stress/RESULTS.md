# Stress results: issue #172

**Run:** 2026-10-21, branch `test/172-stress-apps`, `Rscript tools/stress/run-stress.R` on macOS arm64.
R 4.6.1, shiny 1.14.0, shinytest2 0.5.1, chromote 0.5.1, bslib 0.12.0, Chrome 155.0.8059.85 (headless).

**Result: 50 PASS, 2 KNOWN, 0 FAIL, 0 SKIP** (11 static syntax checks and 39 browser checks pass). The two KNOWN
checks are package defects the runner found, tracked in #426 and #427. Small probe apps found two more problems
outside the runner: see [Findings](#findings).

## What held (browser checks)

| Scenario | What it did to the mascot | Result |
| --- | --- | --- |
| 01 many modules and tabs (plain, golem-style, rhino-style) | Eight nested modules in tabs, rapid tab clicks, an update in every module, then one more in module 4 | Every mascot kept its own mood and status; none updated another (3 layouts x 2 checks) |
| 02 `renderUI()` / `insertUI()` replacement, motion on | 20 re-renders with updates between them, update while absent then insert, a duplicate id, a stale envelope with a higher revision; a swap to Sela with a bubble and a nod, then 3 re-renders; the bubble dismissed, then a re-render; a floating mascot re-rendered 5 times and removed | Latest state kept after every re-render; the duplicate never took ownership; the stale update was ignored; character and bubble survived re-renders and no re-render offered the nod again; the dismissed bubble stayed dismissed; exactly one floating mascot at a time, none left after removal; one duplicate warning (at most 2 allowed) |
| 03 async (`ExtendedTask`, three observers) | Three observers updating one id before, during and after a delayed task, plus a re-render | Final state was the intended one; no warning storm |
| 04 heavy JavaScript and overlays | 200 DOM mutations, a custom input binding, notifications, a modal and progress, a high z-index overlay | The mascot kept drawing (canvas has pixels), kept its status, its menu stayed reachable above the overlay, updates applied while a modal was open |
| 05 slow server, bursts, reconnect, motion on | A 2.5 second handler with queued clicks; 200 updates in one flush, every 50th also swapping the character, opening a bubble and nodding; rapid inputs; a closed websocket and a reconnect | Only the last state remained (Neer, "Burst 200", "Bubble 200") and the page stayed responsive; the worried "connection lost" face appeared; after reconnecting into a new session the page kept its last state. Updates after the reconnect: KNOWN, #426 |
| 06 updates from outside a reactive event | `update_mascot()` from a promise chain and from a `later()` callback, with nothing else happening | The promise update arrived. The `later()` update waits for the next input: KNOWN, #427 |
| 07 modules added and removed at run time | 40 cards inserted ten at a time, each a module with a fresh id and an update sent in the same flush as its UI; the 25 oldest removed; one update for every card | Each card showed its own update; removed cards stayed gone; the live ones took the shared update and showed the new face when scrolled into view. The package kept 40 per-id records for 40 ids, 15 of them live (kept until the session ends, by design) |
| 08 dark-mode switching | `bslib::toggle_dark_mode()` from the server, dark and back, then an update while dark | The mascot with light and dark colours switched mode and body colour both ways; the fixed light mascot stayed light; the update applied in dark mode |
| 09 bookmark and restore | URL bookmark of a note, then a reload from the bookmark URL with `onRestore()` updating the mascot | The URL held the note and no mascot input; the restored page showed "Restored stress" |

## How the runner got here (for the next person)
The first browser run (outside the sandbox) gave 13 PASS and 18 FAIL, and the first fixes gave 24 PASS and 6 FAIL. All
failures were mistakes in the harness, not in the package:
- `set_inputs()` was used on action buttons (use `click()`).
- A driver method was called with an argument it does not take.
- The replacement check waited for `snapshot.mount_token` to change. The token is derived from the mascot's content,
  so an identical re-render keeps it. The element's `snapshot.generation` is what changes on every remount.

Adding scenarios 06 to 09 and the new checks in 02 and 05 (2026-10-21) gave five first-run failures; three were the
harness again:
- Cards below the window kept their old face: the package pauses drawing for off-screen mascots by design. The
  check now scrolls each card into view first, which also tests that the face catches up.
- A bookmark button with its own id bookmarks only through `session$doBookmark()`, and bookmarked action buttons
  replay their observers on restore. Real apps exclude buttons from the bookmark; scenario 09 now does.
- Built-in characters have one colour set, so dark mode changes nothing visible without a `dark` colour. Scenario 08
  now gives one (`mascot_theme()` takes colours as a list).

The other two failures were real package defects, now #426 and #427.
Lesson: when a check times out, print the real host state (the runner does) and read it before suspecting the package;
then prove a suspected defect with a small app outside the runner.

## Findings
Found by the runner (shown as KNOWN until fixed):

| Check | What happens | Issue |
| --- | --- | --- |
| 05: updates after a reconnect | After Shiny reconnects into a new server session (as `allowReconnect(TRUE)` does on Shiny Server and Connect), the mascot keeps its last state but ignores every later `update_mascot()` until a reload | #426 (bug) |
| 06: an update from `later()` | `update_mascot()` from a `later()` callback reaches the page only after the next input; Shiny's `updateTextInput()` arrives on its own | #427 (bug) |

Found afterwards by small probe apps, run by hand in headless Chrome and not part of the runner:

| Probe | What happened | Follow-up |
| --- | --- | --- |
| A mascot inside `renderUI()` cached with `bindCache()`, then a page reload (a second session gets the cached HTML) | The second visitor's mascot is stuck: worried, "Mascot UI baseline could not be verified", and it ignores `update_mascot()` | #424 (bug) |
| 200 `mascot()` calls with different ids | About 0.1 s per call (20.5 s for 200; no faster the second time). Shiny and bslib components take 0.3 to 6 ms | #425 (performance) |
| Page content removed by JavaScript without `Shiny.unbindAll()`, then put back with `Shiny.bindAll()` | The returning mascot never starts ("duplicate live mascot id"). With `Shiny.unbindAll()` first, it works | Not supported, no issue: Shiny asks apps to unbind inputs before removing them |

The scenarios for #424 and #425 will be added with their fixes.

Things the checks do not cover: real network loss on a deployed server, touch devices, cached UI (#424), and pages
with many mascots (build time measured in #425; drawing hundreds at once not tried).

## Result lines of the final run
```
01-modules syntax: R files parse (static check only)
01-modules/golem syntax: R files parse (static check only)
01-modules/rhino syntax: R files parse (static check only)
02-replacement syntax: R files parse (static check only)
03-async syntax: R files parse (static check only)
04-dom-overlays syntax: R files parse (static check only)
05-slow-reconnect syntax: R files parse (static check only)
06-later syntax: R files parse (static check only)
07-dynamic-modules syntax: R files parse (static check only)
08-dark-mode syntax: R files parse (static check only)
09-bookmark syntax: R files parse (static check only)
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
02-replacement swap, bubble and nod survive replacement; the nod plays once: held; 3 replacement envelopes, none offered the nod again
02-replacement a dismissed bubble stays dismissed through replacement: held
02-replacement floating mascot replaced and removed: held
02-replacement no unexpected warning or error storm: held; 1 expected warnings, at most 2
03-async observers during ExtendedTask: held
03-async observer after completion and replacement: held
03-async no unexpected warning or error storm: held
04-dom-overlays DOM churn and custom input binding: held
04-dom-overlays menu reachable above fixed overlay: held
04-dom-overlays progress and modal updates: held
04-dom-overlays no unexpected warning or error storm: held
05-slow-reconnect slow handler with queued clicks: held
05-slow-reconnect 200 updates with swaps, bubbles and nods in one flush: held
05-slow-reconnect rapid inputs settle and page responds: held
05-slow-reconnect websocket loss shows worried status: held
05-slow-reconnect reconnect into a new session keeps the page's last state: held
KNOWN 05-slow-reconnect updates reach the mascot after reconnect: #426
05-slow-reconnect no unexpected warning or error storm: held; 4 expected warnings, at most 4
KNOWN 06-later update from later() arrives without another input: #427
06-later update from a promise arrives without another input: held
06-later no unexpected warning or error storm: held
07-dynamic-modules thirty added cards each start with their own update: held
07-dynamic-modules removed cards are gone; the rest update and catch up when scrolled into view: held; 40 ids created, 15 live, 40 records kept by the package
07-dynamic-modules no unexpected warning or error storm: held
08-dark-mode auto theme follows the page into dark and back: held
08-dark-mode a fixed light theme ignores the page: held
08-dark-mode updates apply in dark mode: held
08-dark-mode no unexpected warning or error storm: held
09-bookmark the bookmark URL carries the note but not the mascot: held
09-bookmark a restored session sets the mascot from onRestore(): held
09-bookmark no unexpected warning or error storm: held
```
