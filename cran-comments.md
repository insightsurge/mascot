## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Test environments

* Local: macOS 26.6 (Apple silicon), R 4.6.1 patched: `R CMD check --as-cran`.
* GitHub Actions: macOS and Windows with R release; Ubuntu with R devel, release, the previous release and 4.1.0
  (the oldest version in `Depends`).
* win-builder: R devel.
* mac-builder: R release.

All gave 0 errors and 0 warnings; the only note is the new-submission note above.

## About the package

mascot adds a character drawn in code to a 'Shiny' app or a 'Quarto' page; the character shows a mood set from R
and moves when the mood changes. The JavaScript and CSS that draw it are plain, unminified files in `inst/www/`,
written for the package; no third-party code ships.

The README and the Get started vignette say the package is "built for GxP work". GxP is the collective name for the "good practice" quality
rules in regulated industries such as pharmaceuticals (for example Good Clinical Practice and Good Manufacturing
Practice). The phrase does not claim that the package is validated. It describes design choices that teams working
under these rules look for: everything ships with the package (nothing is loaded from the internet), the drawing is
deterministic, a status text sits beside every mascot so its mood never carries meaning alone, and the user's
reduced-motion setting is honoured.

Tests that need a browser (Chrome through 'chromote' and 'shinytest2') and snapshot tests are skipped on CRAN; they
run on GitHub Actions.

## Reverse dependencies

This is a new package, so there are no reverse dependencies.
