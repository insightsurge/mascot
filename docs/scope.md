# mascot: scope (draft, updated 2026-09-29)

An R package for **live, mood-driven mascots** in Shiny apps and Quarto sites. A character drawn in code shows a
mood and animates when the mood changes: a short wiggle, then the new face. It works out of the box, with no AI.
AI only helps through optional skills, which the user's own agent runs: wiring the mascot into an app, building a
theme from a brand, and, much later, writing trailer stories.

The idea and the engine come from the R Engineering Playbook site, where the character Tessa stars in short
trailers. That site is the package's first user (`docs/consumers.md`).

## The characters
One new built-in character per release, each with its own shape, colours, personality and voice, all drawn on
one multi-character engine. Moods, light and dark mode and (from 0.2.0) a shared wardrobe work for every character.

| Character | Meaning | Nature | Look (picks for now) | Release |
|---|---|---|---|---|
| **Neer** (नीर), she/her | water | calm, observant, clear, welcoming; says in few words what changed | a wave crest with small arms and feet, water blues | 0.1.0, the default |
| **Tessa**, she/her | from tessellation | calm, hardworking, always learning; the maker | the R hex sticker in forest green with an ochre rim (decided: the playbook's character) | 0.2.0 |
| **Ojas** (ओजस्), he/him | vitality, radiance | shiny, forgiving, bright, wise; says a mistake can be mended | sunrise gold with arms and feet; shape still open | 0.3.0 |

The full design of each character (options, colour themes with contrast, moods, accessories, motion, voices,
risks) is in the character design records, kept on the `design-assets` branch (`characters/`).

## Target users and use cases, by confidence

| Confidence | User | Use cases |
|---|---|---|
| High | Shiny developers | Mood reacts to form validation (`shinyvalidate`); a busy mood instead of a spinner; empty-state hints; message bubbles ("Take a break, this part is long"); brand colours and light/dark mode for free; later, a quiet hint giver that explains inputs and outputs |
| High | The R Engineering Playbook site (first user) | Mascot in articles through a Quarto shortcode, following the site's light/dark toggle |
| High | Open-source package maintainers | A mascot for their package: README and pkgdown hero; later avatars, hex stickers, release clips |
| High | Teachers and workshop authors | Mascot in Quarto slides and tutorials; cheering learners on in Shiny exercises; hints for terms |
| Medium | Pharma and other regulated teams | Data-entry, review and QC apps with a calm mascot; later hints that explain field definitions, units and ranges; offline and reproducible; no AI images (pharma theme pack after 0.1.0) |
| Medium | R coders using AI coding agents | A skill wires the mascot into their app or builds their theme |
| Medium | Quarto, pkgdown and blogdown site owners | Shortcode, themes from `_brand.yml` |
| Low | Marketing and data-comms teams working in R | Launch clips (needs trailers, later) |
| Low | R user groups and conferences | Event mascots |

## Works without AI (0.1.0)
Neer and the five moods (idle, thinking, happy, worried, celebrating) with smooth transitions; a busy mood driven
by Shiny's own busy events; reacting to a `shinyvalidate` validator; message bubbles; light and dark mode following
bslib's `input_dark_mode()`, Quarto's toggle or the system setting; themes from `_brand.yml`, a `bs_theme()` or CSS;
a floating, fixed, inline or dismissible card that never covers Shiny's own messages; a Quarto shortcode; a gallery
app with a character chooser.

## Releases (draft)
| Release | Theme | Contents |
|---|---|---|
| 0.1.0 | Live mascot | Neer on a multi-character engine; moods with wiggle-then-change; light/dark; themes; the Shiny widget, `updateMascot()`, validator binding, busy mood, message bubble, placement; a Quarto extension; the gallery; AI skills for Claude, Codex and Gemini; groundwork for hints |
| 0.2.0 | Tessa and static assets | Tessa; a shared wardrobe (outfits, accessories, held items any character can wear); avatars (PNG/SVG); hex stickers; the pharma theme pack, if 0.1.0 is received well |
| 0.3.0 | Ojas and the builder | Ojas; a visual character builder; more shapes; SVG and Lottie export |
| Later | Hints and app events | A quiet hint giver, off by default: a help list in the bubble, a "what's this?" mode, hints when validation fails, dragging the mascot onto an element; reactions to custom app events |
| Later | Trailers | A trailer base built on the static helpers, then trailers, then storyboard YAML |
| Later | Packs as packages | Theme packs split into their own packages |

## Principles
- Draw everything in code, in the user's brand colours; no AI images.
- Accessible: readable status text beside every mood, reduced motion respected, the card can be dismissed; hints
  never replace or hide an error message.
- Quiet by default: nothing pops up uninvited.
- The package never calls an AI model; skills are files the user's own agent runs.
- Tested and defensive: at least 70% test coverage, shinytest2 for Shiny behaviour, arguments checked with checkmate.
- Wording: "built for GxP work", never "validated" or "compliant".
