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
  to other sites, fonts from the package via `@font-face`.
- **house:** deterministic drawing: seeded RNG, no `Math.random()`, no clock-driven drawing; drawn in code in the
  theme's colours; no AI-generated images.
- **house:** wiring: `htmltools::htmlDependency()` (built at runtime, `version` = package version) + a Shiny output
  binding registered once under a package-qualified name + custom messages (`mascot:update`) for
  `updateMascot()`, addressed by (namespaced) id and queued until the element is bound. No htmlwidgets.
- **house:** one global namespace (`window.mascot`), guard against loading twice, state kept per element, several
  mascots per page, no listeners left behind.
- **house:** configuration through `data-*` attributes or a `<script type="application/json">` block. No `eval`,
  `new Function`, inline `<script>`, inline `style=` for layout or `javascript:` URLs (mascot adds no inline script
  of its own; Shiny itself still uses some).
- **house:** colours from Bootstrap's CSS variables (`--bs-body-color`, `--bs-body-bg`, `--bs-primary`, ...) with
  mascot's own `--mascot-*` variables as the fallback; follow `[data-bs-theme]` and the system preference for dark
  mode. bslib stays in Suggests.
- **house (WCAG 2.2):** status text beside every mascot in a `role="status"` element (the mood never carries meaning
  alone); the canvas has `role="img"` and an `aria-label` naming the mood; `prefers-reduced-motion` is honoured in
  CSS and JS (swap the wiggle for an instant change or a short fade) and R can switch animation off; no automatic
  animation longer than 5 s; graphics colours keep 3:1 contrast in light and dark.
- **house:** ES2015+ for evergreen browsers (Chrome, Edge, Firefox, Safari); Biome formats and lints (`biome.json`,
  2 spaces, width 120, single quotes); the gate's `biome` step and CI run it.
- **house:** every new file here is listed in `inst/COPYRIGHTS` (see `bundled-files.md`).
