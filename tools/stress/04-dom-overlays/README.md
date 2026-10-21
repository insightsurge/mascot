# DOM churn and overlays

MutationObserver rewrites, 200 clones and resize events, mascot movement, a custom input binding, notifications, modal, progress, sidebar and fixed overlay.

Tries to break:

- Drawing, status, updates and menu hit testing amid unrelated page code.

Should hold:

- The original canvas has painted pixels; status and updates survive; a menu item receives pointer hits above the overlay.

From the checkout root, run `Rscript tools/stress/run-stress.R 04` with the
R environment described in the parent README. See [../RESULTS.md](../RESULTS.md) for observed results.

Reproduction sequence:

1. Click Mutate page; it creates the notification, toggles the sidebar and runs page JS.
2. Click Update; inspect painted canvas pixels and Update 1 status.
3. Open the menu. The runner checks the menu item's centre with `elementFromPoint()`
   to detect an overlay intercepting pointer hits.
4. Click Progress, then Open modal. The runner sends a server input while the modal
   is open and checks Update 2 without closing it. Inspect canvas and status as well.
