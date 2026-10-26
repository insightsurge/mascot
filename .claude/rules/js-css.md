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
  messages (`mascot:update`) for `update_mascot()`, addressed by (namespaced) id and kept in R until the element is bound.
  No `mascotOutput()`/`renderMascot()`, no htmlwidgets.
- **house:** one global namespace (`window.mascot`), guard against loading twice, state kept per element, several
  mascots per page, no listeners left behind.
- **house:** the engine is versioned with the package (`window.mascot.version`, passed from R on the first engine
  script); character files keep `format_version` 1.
- **house:** configuration through `data-*` attributes or a `<script type="application/json">` block. No `eval`,
  `new Function`, inline `<script>`, inline `style=` for layout or `javascript:` URLs (mascot adds no inline script
  of its own; Shiny itself still uses some).
- **house:** the page script of a Shiny app the package ships (`inst/examples/*/www/`) keeps the page and the server
  in step. The five rules, with their server side, are in `r-code.md`, "Shiny apps"; in the page:
  1. what the page copies or shows as a result is what the server drew, never a value it reads from its own controls
     (`copy()` in `inputs.js` copies the code output's text once the server has answered the ticket);
  2. an action, and a choice that redraws inputs, sends any input still waiting before its own event
     (`mascotStudioInputs.beforeCopy(() => Shiny.setInputValue(id, el.value))`; an immediate `setInputValue()`
     cancels the input's pending debounce);
  3. a value the server sets on a control, and the value a control reports when it is bound, don't count as the
     user's choice and aren't sent back as one;
  4. the page numbers its choices and ignores a server update whose revision is older than its latest choice
     (`if (msg.revision < latest) return;`), but still applies new options such an update carries (a select's list
     for another character);
  5. a busy button waits for the `data-busy-done` mark of its own click and for any frame in the result to load, or
     for a visible error on its output (a silent validation error is no answer), not for `shiny:idle` or
     `shiny:value`, which come before the value is drawn.
- **house:** panels follow Bootstrap's CSS variables (`--bs-body-color`, `--bs-body-bg`, `--bs-border-color`) by
  default; public `--mascot-panel-*` and `--mascot-restore-*` colour hooks (`?mascot_styling`) win over them and copied
  page colours. Other mascot custom properties use the private `--_mascot-*` prefix. Follow the page for dark mode
  (`[data-bs-theme]`, then Quarto's
  `quarto-dark`/`quarto-light` body classes); with no signal, light. bslib stays in Suggests.
- **house (WCAG 2.2):** status text beside every mascot in a `role="status"` element (the mood never carries meaning
  alone); when not clickable, the canvas has `role="img"` and an `aria-label` naming the mood (no keyboard stop); with a
  click, a native button named by its label wraps it (#257); `prefers-reduced-motion` is honoured in
  CSS and JS (swap the wiggle for an instant change or a short fade) and R can switch animation off; no automatic
  animation longer than 5 s; graphics colours keep 3:1 contrast in light and dark.
- **house:** ES2015+ for evergreen browsers (Chrome, Edge, Firefox, Safari); Biome formats and lints (`biome.json`,
  2 spaces, width 120, single quotes); the gate's `biome` step and CI run it.
- **house:** every new file here is listed in `inst/COPYRIGHTS` (see `bundled-files.md`).
- **house:** every change in `inst/www/` adds an entry to `vignettes/articles/engine-changelog.Rmd`.
