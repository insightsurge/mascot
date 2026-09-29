# mascot: scope (draft, 2026-09-29)

An R package for **live, mood-driven mascots** in Shiny apps and Quarto sites. A character (a hexagon mascot
drawn in code) shows a mood and animates when the mood changes: a short wiggle, then the new face. It works
out of the box, with no AI: AI only helps later with optional skills (wiring the mascot into an app, building
a theme from a brand, and, much later, writing trailer stories).

The idea and the engine come from the R Engineering Playbook site, where the character Tessa stars in short
trailers. That site is the package's first user.

## Target users and use cases, by confidence

| Confidence | User | Use cases |
|---|---|---|
| High | Shiny developers | Mood reacts to form validation (`shinyvalidate`); a busy mood instead of a spinner; empty-state hints; message bubbles ("Take a break, this part is long"); brand colours and light/dark mode for free |
| High | The R Engineering Playbook site (first user) | Mascot in articles through a Quarto shortcode, following the site's light/dark toggle |
| High | Open-source package maintainers | A mascot for their package: README and pkgdown hero; later avatars, hex stickers, release clips |
| High | Teachers and workshop authors | Mascot in Quarto slides and tutorials; cheering learners on in Shiny exercises |
| Medium | Pharma and other regulated teams | Data-review and QC apps with a calm mascot; offline and reproducible; no AI images (pharma theme pack after 0.1.0) |
| Medium | R coders using AI coding agents | A skill wires the mascot into their app or builds their theme |
| Medium | Quarto, pkgdown and blogdown site owners | Shortcode, themes from `_brand.yml` |
| Low | Marketing and data-comms teams working in R | Launch clips (needs trailers, much later) |
| Low | R user groups and conferences | Event mascots |

## Works without AI (0.1.0)
Characters and moods with smooth transitions; a busy mood driven by Shiny's own busy events; reacting to a
`shinyvalidate` validator; message bubbles; light and dark mode following bslib's `input_dark_mode()`, Quarto's
toggle or the system setting; themes from `_brand.yml`, a `bs_theme()` or CSS; a floating, fixed or
dismissible card; a Quarto shortcode; a gallery app with a character chooser.

## Releases (draft)
| Release | Theme | Contents |
|---|---|---|
| 0.1.0 | Live mascot | Three characters in the built-in theme pack (default, Tessa, a male character); moods with wiggle-then-change; Shiny widget, `updateMascot()`, validator binding, busy mood, message bubble, float/fixed/dismiss, light/dark; Quarto extension; gallery; AI skills for Claude, Codex and Gemini |
| 0.2.0 | Static assets + pharma | Pharma theme pack (moods, `calm` style, props), if 0.1.0 gets a good reaction; avatars (PNG/SVG); hex stickers |
| 0.3.0 | Builder | A visual character builder; more shapes; SVG and Lottie export |
| Later | Trailer base, then trailers | Scenes, props and an export pipeline built on the static helpers; light/dark video pairs; then trailers; storyboard YAML after that |
| Later | Packs as packages | Theme packs split into their own packages |

## Principles
- Draw everything in code, in the user's brand colours; no AI images.
- Accessible: readable status text beside every mood, reduced motion respected, the card can be dismissed.
- The package never calls an AI model; skills are files the user's own agent runs.
- Wording: "built for GxP work", never "validated" or "compliant".
