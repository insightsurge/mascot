---
paths:
  - "inst/**/*.js"
  - "inst/**/*.css"
  - "inst/**/*.lua"
---

# The UI engine: JS, CSS (and the Quarto Lua)

Labels as in `r-code.md` (CRAN / house). Reasons and sources: `docs/standards.md`.

- **CRAN:** source for everything: plain, readable, unminified JS and CSS in `inst/www/`; no build step, no bundler,
  no `node_modules`, no minified files without their source. Everything ships in the package: no CDN, no requests
  to other sites. **house:** no bundled fonts in 0.1.0: text (status line, speech bubble) uses the host page's font
  (the Shiny app's bslib theme, the Quarto or pkgdown site), read from the page, like the colours.
- **house:** deterministic drawing: seeded RNG, no `Math.random()`, no clock-driven drawing; drawn in code in the
  theme's colours; no AI-generated images.
- **house:** wiring: `htmltools::htmlDependency()` (built at runtime, `version` = package version) + a Shiny input
  binding `mascot.mascot` (mount on subscribe, clean up on unsubscribe; Shiny then checks duplicate ids) + custom
  messages (`mascot:update`) for `update_mascot()`, addressed by (namespaced) id and queued until the element is bound.
  No `mascotOutput()`/`renderMascot()`, no htmlwidgets.
- **house:** one global namespace (`window.mascot`), guard against loading twice, state kept per element, several
  mascots per page, no listeners left behind.
- **house:** configuration through `data-*` attributes or a `<script type="application/json">` block. No `eval`,
  `new Function`, inline `<script>`, inline `style=` for layout or `javascript:` URLs (mascot adds no inline script
  of its own; Shiny itself still uses some).
- **house:** panels follow Bootstrap's CSS variables (`--bs-body-color`, `--bs-body-bg`, `--bs-border-color`) by
  default; public `--mascot-panel-*` and `--mascot-restore-*` colour hooks (`?mascot_styling`) win over them and copied
  page colours. Other mascot custom properties use the private `--_mascot-*` prefix. Follow the page for dark mode
  (`[data-bs-theme]`, then Quarto's
  `quarto-dark`/`quarto-light` body classes); with no signal, light (founder, 2026-10-09). bslib stays in Suggests.
- **house (WCAG 2.2):** status text beside every mascot in a `role="status"` element (the mood never carries meaning
  alone); when not clickable, the canvas has `role="img"` and an `aria-label` naming the mood (no keyboard stop); with a
  click, a native button named by its label wraps it (#257); `prefers-reduced-motion` is honoured in
  CSS and JS (swap the wiggle for an instant change or a short fade) and R can switch animation off; no automatic
  animation longer than 5 s; graphics colours keep 3:1 contrast in light and dark.
- **house:** ES2015+ for evergreen browsers (Chrome, Edge, Firefox, Safari); Biome formats and lints (`biome.json`,
  2 spaces, width 120, single quotes); the gate's `biome` step and CI run it.
- **house:** every new file here is listed in `inst/COPYRIGHTS` (see `bundled-files.md`).
