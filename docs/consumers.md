# Known users of mascot

Read this before changing anything exported or anything a user can see. Add a row when a new app, site or
package starts using mascot, with a way to check it still works. A PR that may affect a row gets the
`consumer-impact` label and says how each affected user was checked.

| User | Repo or location | Uses | Version | How to check it still works | Status |
|---|---|---|---|---|---|
| R Engineering Playbook site (first suggested user; the engine's birthplace) | insightsurge/r-engineering-playbook | Today: its own engine in `tools/animate/` (trailers, thumbnails, popup player), not this package. Planned: the Quarto shortcode (#37), later trailers (#56) | none yet | Render the site; open an article in light and dark; trailers still play. Its handoff lists every use of the engine (`dev/handoffs/brand-ui/animation-engine-package.md`) | planned |
| The founder's Shiny apps | to be added, one row per app | Planned: `mascotOutput()`/`renderMascot()`, `updateMascot()`, `watch_validator()`, busy mood, light/dark | none yet | The app starts, the mascot renders, a mood change works (a shinytest2 smoke test) | planned |
| Tanmay (R package author, outside trial) | to be added | Trial of 0.1.0 before CRAN (#43) | GitHub | Their feedback issues are closed | planned |

## Rules
- The playbook site switches from `tools/animate/` to this package only after its output has been compared
  and approved, first installed from GitHub, later from CRAN, pinned by version.
- Before 0.1.0 the API may change freely; after 0.1.0, deprecate before removing (at least one release).
