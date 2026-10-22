# mascot: scope

mascot adds live, mood-driven characters to Shiny apps and Quarto HTML pages. A character drawn in code shows a
mood and gives a short wiggle when the mood changes, with status text beside it. The package works offline and is
built for GxP work: it supports an app's field errors and results without replacing them.

## Characters in 0.1.0

| Character | Meaning | Nature | Appearance | Status |
|---|---|---|---|---|
| **Tessa**, she/her | from tessellation | calm, hardworking, curious and patient; the maker | a teal hexagon with a silver rim, hair, a small bow, studs, arms and a chest badge showing the mood; her own colours are `night_teal` | the default, stable |
| **Sela**, she/her | a second hexagon | the organiser | a lilac hexagon with deep violet hair and time blocks; her own colours are `lilac_violet` | stable |
| **Knurl**, it/its | a robot | the repair bot | a wheeled chassis with a visor and a clamp arm holding a spanner | experimental |
| **Neer** (नीर), she/her | water | calm, observant, clear and welcoming; says in a few words what changed | a water-blue wave crest with a shell, small arms and feet | experimental |

Tessa and Sela have stable ids, names, moods, gesture names and colour role names. Knurl and Neer may change.
All four share five moods (`idle`, `thinking`, `happy`, `worried` and `celebrating`), a wave and a nod, light and
dark mode, and palette presets.

## What 0.1.0 provides

- A Shiny widget, `mascot()`, with moods set from the server through `update_mascot()`, for example while a task
  runs or a form needs attention.
- A short wiggle on mood changes, one-off gestures and motion controls that respect reduced-motion settings.
- Status text, message bubbles and a click action or menu. A mascot can float in a window corner or sit inline.
  Floating mascots can be minimised and restored, with corner snapping or experimental free dragging.
- Light and dark mode following `bslib::input_dark_mode()` and Quarto's toggle. A page with no theme signal stays
  light; the system setting alone does not change it.
- Themes from palettes, explicit light and dark colours, CSS variables or `bslib::bs_theme()`.
  A `_brand.yml` file can be supplied through `bs_theme(brand =)`.
- Bundled example apps and an experimental studio that demonstrates every exported function and argument.
- Experimental functions to read and check a local character file, preview the checked character offline and use
  it in Shiny. The studio accepts built-in characters only. Saving and registering characters and palettes are
  planned for a later release.
- Static mascots in rendered Quarto HTML pages: the mood and status are set when the page is rendered, with no live
  Shiny updates. A Quarto shortcode is planned for 0.2.0.

The experimental features are Knurl and Neer, `mascot_studio()`, `mascot_preview()`, `mascot_theme(css =)`,
`drag = "free"`, the mapping of `bs_theme()` colours to character parts, `mascot_read_character()`,
`mascot_check_character()` and the character file format. The format's compatibility promise is in the
[engineering standards](https://github.com/insightsurge/mascot/blob/main/docs/standards.md#9-releases).

## Who it is for

| User | Use cases |
|---|---|
| Shiny developers | Forms, long tasks, queues, empty-state hints, message bubbles and brand colours |
| Package maintainers | A mascot in documentation and pkgdown pages |
| Teachers and workshop authors | Quarto tutorials and Shiny exercises |
| Pharma and other regulated teams | Data-entry, review and QC apps with offline drawing, clear status text and controlled motion |
| Quarto, pkgdown and blogdown site owners | Static mascots and light/dark themes; a shortcode is planned |
| R developers using coding assistants | Planned integration and theming skills |
| Marketing and data communications teams, user groups and conferences | Planned static assets, event mascots and release clips |

[Known users](https://github.com/insightsurge/mascot/blob/main/docs/consumers.md) lists adoption and checks for each
app or site.

## Planned releases

These are plans, not available features or delivery guarantees.

| Release | Focus |
|---|---|
| 0.1.0 | First CRAN release: the characters, Shiny interface, themes, examples and experimental studio and character-file functions described above |
| After 0.1.0 | Public functions for saving and registering characters and palettes |
| 0.2.0 | Quarto extension and shortcode; Shiny busy events and `shinyvalidate` binding; integration and theming skills; shared outfits, accessories and held items; PNG/SVG avatars and hex stickers; a pharma pack with calm palettes, motion and wording defaults |
| 0.3.0 | Ojas (ओजस्, he/him), a character named for vitality and radiance, in sunrise gold with arms and feet, with his shape to be decided; a visual character builder, more shapes, SVG and Lottie export |
| Later | Optional hints in the bubble, a "what's this?" mode, hints on validation errors and dragging onto elements; custom app events; trailers and storyboard YAML built on static helpers; packs of palettes and optional defaults distributed as packages |

## Principles

- Draw characters in code, using the user's colours, with no external model service.
- Keep readable status text beside each mood, honour reduced motion, and let visitors minimise the floating
  mascot. Hints never replace or hide an error message.
- Keep interaction quiet by default: nothing pops up uninvited.
- Check arguments with checkmate, test Shiny behaviour with shinytest2, and keep at least 70% R line coverage.
- Use the wording "built for GxP work".
