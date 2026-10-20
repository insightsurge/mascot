# mascot

[![R-CMD-check](https://github.com/insightsurge/mascot/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/insightsurge/mascot/actions/workflows/R-CMD-check.yaml)

Live, mood-driven mascots for R: a character drawn in code that shows a mood in your Shiny app or Quarto site and
animates when the mood changes. You set its mood from your server code, for example while your app computes or a form
fails validation. It follows light and dark mode, and takes its colours from your brand. No AI needed to use it.

**Status:** early development, before 0.1.0. Not on CRAN yet.

**Experimental (may change in 0.1.x):** Knurl and Neer, `mascot_studio()`, `mascot_preview()`, `mascot_theme(css =)`, `drag = "free"`, the mapping of `bs_theme()` colours to a character's parts, and the character file format. Tessa and Sela are stable.

**Make your own character: coming soon.** In 0.1.0 a character file can be read and checked (experimental); saving and registering characters and palettes follow in 0.1.x.

- Scope, users and planned releases: [`docs/scope.md`](https://github.com/insightsurge/mascot/blob/main/docs/scope.md)
- Known users: [`docs/consumers.md`](https://github.com/insightsurge/mascot/blob/main/docs/consumers.md)
- Plan: the milestones and the epic tree under issue #1

## Installation

mascot is not on CRAN yet, and its GitHub repository is private for now. Once it is public, install the
development version with:

```r
# install.packages("pak")
pak::pak("insightsurge/mascot")
```

## Development

How to set up, the workflow and the checks every change passes: [`CONTRIBUTING.md`](.github/CONTRIBUTING.md).
The engineering standards, with the CRAN rules and our own: [`docs/standards.md`](https://github.com/insightsurge/mascot/blob/main/docs/standards.md).

## Licence

MIT © Harsh Verma. See [`LICENSE.md`](LICENSE.md).
