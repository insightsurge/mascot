# Known users of mascot

Read this before changing anything exported or anything a user can see. Add a row when a new app, site or
package starts using mascot, with a way to check it still works. A PR that may affect a row gets the
`consumer-impact` label and says how each affected user was checked.

| User | Repo or location | Uses | Version | How to check it still works | Status |
|---|---|---|---|---|---|
| R Engineering Playbook site (first suggested user; the engine's birthplace) | its own repository | Today: its own engine in `tools/animate/` (trailers, thumbnails, popup player), not this package. Planned: the Quarto shortcode in 0.2.0 (#37), later trailers (#56) | none yet | Checked by the package creator: render the site; open an article in light and dark; trailers still play | planned |
| The package creator's Shiny apps | to be added, one row per app | Planned: `mascot()` in the UI and `update_mascot()` in the server, busy mood, light/dark | none yet | The app starts, the mascot renders, a mood change works (a shinytest2 smoke test) | planned |

## Visible changes to the built-in characters
- 2026-10-19, Sela's final palette set (#379): her own colours are lilac with deep violet hair, named
  `lilac_violet` (`"original"` still works); her pink look is now `orchid`, with a plum rim and deeper hair.
  Her palettes are `orchid`, `coral_navy`, `azure`, `peach_ink`, `lilac_soft`, `mist_navy`, `desert_clay`,
  `forest`, `apricot_navy`, `blush_plum`, `lilac_dusk` and `sea_green`. Use `coral_navy` instead of `coral`
  and `peach_ink` instead of `peach`; `azure` has updated colours. No known user picks Sela.
- 2026-10-19, Tessa's new look (#359): a slimmer teal hexagon, hair, a small bow and studs, a chest badge showing the
  mood, arms hanging down; her own colours are called `night_teal` (`"original"` still works) and her palettes are
  `sea_green`, `forest`, `spring`, `peach`, `coral_navy`, `desert_coral`, `rose_soft`, `lilac_soft` and `mist_navy`.
  Her old palettes `nordic`, `coral` and `azure` are gone. A known user that picks Tessa and no palette sees the new look;
  one that names an old palette now gets an error (or a warning from `update_mascot()`) that lists the new ones.

## Rules
- The playbook site switches from `tools/animate/` to this package only after its output has been compared
  and approved, first installed from GitHub, later from CRAN, pinned by version.
- Before 0.1.0 the API may change freely; after 0.1.0, deprecate before removing (at least one release).
