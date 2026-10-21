# Dark-mode switching

A bslib page with `input_dark_mode()`, switched between light and dark from the server with
`bslib::toggle_dark_mode()`. One mascot has light and dark body colours and the default mode (it follows the page); one is fixed to light.
Built-in characters have one colour set, so without a `dark` colour nothing visible changes.

Tries to break:

- Theme changes that come from the page (`data-bs-theme` on `<html>`), not from `update_mascot()`.

Should hold:

- The first mascot switches mode and body colour with the page and back; the fixed mascot stays light; updates still
  apply while the page is dark.

From the checkout root, run `Rscript tools/stress/run-stress.R 08` with the
R environment described in the parent README. See [../RESULTS.md](../RESULTS.md) for observed results.

Reproduction sequence:

1. Click Dark, then Light: the first mascot's colours follow; the second stays light.
2. Click Dark, then Update: the first mascot turns happy with "Update 1" and stays dark.
