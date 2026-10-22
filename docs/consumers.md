# Known users of mascot

Read this before changing anything exported or anything a user can see. Add a row when an app, site or package
starts using mascot, including its version and a way to check it still works. A PR that may affect a row gets the
`consumer-impact` label and says how each affected user was checked.

| User | Uses | Version | How to check it still works | Status |
|---|---|---|---|---|
| The package creator's playbook site | Its own animation engine for trailers, thumbnails and a popup player. Planned: the Quarto shortcode in 0.2.0 (#37), later trailers (#56) | none yet | The package creator renders the site, opens an article in light and dark, and checks that trailers play. Switch to mascot only after comparing and approving the output; install from GitHub, then CRAN, pinned by version | planned |
| The package creator's Shiny apps (one row per app when adopted) | Planned: `mascot()` in the UI and `update_mascot()` in the server, busy mood and light/dark mode | none yet | The app starts, the mascot renders and a mood change works, covered by a shinytest2 smoke test | planned |
