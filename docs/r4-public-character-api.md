# R4 plan: the public character API for 0.1.0

Status: design, revised after an independent design review (GPT-6 Astra, 2026-10-17; changes listed in section 11).
Nothing here is implemented. The format and engine are in
[engine-format-proposal.md](engine-format-proposal.md) (plan row R4, section 9); the earlier API recommendations are
in [r-api-decisions-0.1.0.md](r-api-decisions-0.1.0.md) (sections 5 and 10) and
[r-builder-proposal.md](r-builder-proposal.md). This plan changes one earlier recommendation (decision D1) and says
why.

## 1. Goal, in user scenarios

The package's selling point is that a user can have their own mascot, not only Tessa. R4 decides which part of that
is public in 0.1.0 and builds it, with the studio in the same change.

1. **An app author picks a built-in character.** `mascot("helper", character = "tessa")`, as today. Lists show what
   that character can do: `mascot_moods("tessa")`, `mascot_gestures("tessa")`, `mascot_colour_roles("tessa")`,
   `mascot_anchors("tessa")`, `mascot_palettes("tessa")`.
2. **An app author has a character file** (written by hand, by the separate builder app later, or by the user's own
   AI skill). They read and check it, look at it, and use it:
   `bot <- mascot_read_character("study_bot.json")`, `mascot_preview(bot)`, `mascot("helper", character = bot)`,
   and from the server `update_mascot("helper", mood = "worried")`.
3. **The file has a mistake.** The check stops at the first problem and says where, what and how to fix it:
   `$.anchors.tool_grip.part names elbow, which is not a declared part. Declare the part or choose another.`
4. **One character in many apps or modules.** `mascot_register_character(bot)` at app start-up; afterwards
   `mascot(character = "study_bot")` works anywhere in that R process, and `mascot_characters()` lists it.
5. **A character made inside a running app** (for one visitor) is passed as an object; it never enters the shared
   process registry, so visitors never see each other's characters.
6. **The author changes a character and saves it.** The editable form is the JSON file (or the plain R list
   `jsonlite::read_json()` gives); the author edits that, checks it again with `mascot_check_character()`, and saves
   the checked result: `mascot_save_character(bot, "study_bot.json")`. A checked object is opaque: its fields are not
   an editing API, and a modified object is refused.
7. **The founder reviews it all in the studio**: a "Your character" panel loads a file, shows the check result, and
   previews every mood, gesture, size and mode.

## 2. Today (feat/character-foundation at 7b5725f)

- Exported: `mascot_character(id)`, `mascot_characters(..., family)`, `mascot_families()`, `mascot_anchors(character)`,
  `mascot_palettes(character)`, `mascot_moods(character)`, `mascot_gestures(character)`,
  `mascot_colour_roles(character)`, `mascot_preview(character, ...)`.
- Internal: `character_format_check(x, from, families, kits, builtin)` (the one checker, stop at first problem with
  code/path/value/fix), `character_data_register(x)`, the catalogue (`character_catalogue_*`), the class
  `mascot_character_data` (checked, resolved data with an integrity check on every use).
- I1 (#307) runs any checked format-v1 character in the real host; M1 (in progress) moves Tessa onto the same path.
- U1 (#305) deliberately rejects checked character data in the public `mascot()` / `update_mascot()` arguments until
  this unit decides the public surface.

## 3. Decisions for the founder (each with a recommendation)

**D1. Which authoring operations are public in 0.1.0?**
- (A) As r-api-decisions section 5 recommended: only selection by id is public; read/check/register/save stay
  internal until 0.1.x. A user with a character file has no supported route in 0.1.0.
- **(B, recommended) A small, file-first route is public and marked experimental:** `mascot_read_character()`,
  `mascot_check_character()`, `mascot_register_character()`, `mascot_save_character()`, and checked objects accepted
  by every function that takes a character. The R constructors (`mascot_build_character()`, `mascot_part()`, ...)
  and `mascot_remix()` stay internal until 0.1.x.
- *Why B:* the format is the contract users, the builder app and AI skills all write; a checked JSON file is the
  smallest public surface that delivers the selling point, and the checker already exists. The constructors are a
  large surface (twelve functions) whose names and argument shapes would freeze too early. A user who needs a
  custom mascot soon (a real need) gets one without private functions.
- *Cost of B:* four new experimental exports, their docs, studio and tests; the format becomes a published promise
  from 0.1.0 (format version 1 is already versioned, with reserved capabilities refused clearly by C5 #306).

**D2. Is the character file format itself documented publicly in 0.1.0?** **Recommended: yes, as a website article
("Write your own character"), marked experimental,** linking the format reference. Without it, the public read route
is unusable in practice. The article stays off CRAN (vignettes/articles/), so the package stays small.

**D6. When the authoring functions become public (new, from the review).** The plan's FREEZE row says the format is
frozen before public authoring exports, and FREEZE depends on work that itself needs R4. **Recommended:** split R4.
*R4a* builds everything in this plan as internal functions, fully tested, with the studio panel behind an internal
switch. *R4b*, after FREEZE and the parity gate (#304), only promotes them: exports, roxygen with experimental badges,
the article, `_pkgdown.yml`, NEWS. Promotion is then a small, low-risk change, and nothing public waits on artwork.

**D3. Lifecycle labels.** **Recommended:** selection (`mascot_character()`, listings, accepting a checked object in
`mascot()`/`update_mascot()`) is stable; the four authoring operations are experimental (lifecycle badge, a line in
each help page, and a NEWS note). Experimental means the names and arguments may change in 0.1.x with a deprecation
period; the format version 1 files themselves keep loading, with one stated exception: a documented security or
resource-safety correction may reject a file that loaded before, with its own diagnostic code and a migration note.
Three versions are kept apart: the format version (meaning of the data), the capability set (what this package
draws) and the admission policy version (the policy file: budgets and input bounds).

**D4. Registration in a running app.** **Recommended (as already designed):** `mascot_register_character()` is for
app start-up and development; it errors inside an active Shiny reactive domain with a message that says to pass the
object instead. Re-registering identical content is a no-op; the same id with other content, or a built-in id, errors.

**D5. Studio.** **Recommended:** a "Your character" panel: a file input (the browser sends the file to the studio's
own R session, which Shiny keeps as a temporary file for that session; run locally, it never leaves the computer;
hosted, it reaches only that server; it is never sent to any other service), the check result (first problem with path and fix, or "checked"), and the existing preview grid
and controls switching to that character. The generated code shows `mascot_read_character("<file name>")`. No
editing in the studio (that is the separate builder app).

## 4. API specification (recommended option B)

All four are experimental, start with checkmate assertions for every argument, use cli for other conditions with the
classes in r-api-decisions section 1, and have `@returns` and offline `@examples` (examples use a file shipped in
`inst/examples/characters/` and `tempdir()` only).

| Signature | Contract |
|---|---|
| `mascot_read_character(path)` | Reads one local JSON file the user names (no URLs, no globbing), bounded by the format's input policy (the policy file, inst/format/policy-v1.json; limits.json in the design repository), checks it with the one checker, returns a `mascot_character_data` object visibly. File problems: `mascot_error_file` with the path. Content problems: `mascot_error_character` with code, path, value and fix. |
| `mascot_check_character(x)` | `x` is a JSON string, a parsed list, or a `mascot_character_data` (rechecked for integrity). Returns the checked object visibly; never fixes or recolours silently. Not given a file path (that is read's job, so a string is never ambiguous). |
| `mascot_register_character(x)` | `x` is checked data. Binds its id in this R process; returns the id invisibly. Errors in an active reactive domain, for a built-in id, or for the same id with different content. |
| `mascot_save_character(x, path, ..., overwrite = FALSE)` | `x` is checked data; writes the complete resolved JSON to the user's path atomically (temporary file beside it, then rename); an existing file errors unless `overwrite = TRUE`. Returns the path invisibly. Writes nowhere else. |

**Source and resolved files.** A source file may refer to a family's current defaults; the checked object and the
saved file are resolved and self-contained (family defaults and kits embedded). The saved, resolved file is the
portable artefact to deploy and archive; keep the source too if you want to edit it later. A package upgrade can
change how a source file resolves, never how a saved resolved file draws (apart from the security exception above).

**Identity.** A character's content identity is its canonical resolved content: independent of file location, JSON
key order and provenance. The process registry binds an id to one content identity: registering the same content
again is a no-op, other content under the same id errors. Objects passed directly never touch the registry; caches
are keyed by content identity, never by id alone, so two visitors' different objects that both say `study_bot` stay
apart. A mounted mascot cannot switch to different content under the same character id (U1 rule): give the edited
character a new id.

A print method for `mascot_character_data` shows id, name, family, moods, gestures, sizes it supports and where it came
from (file path, registry or object); it never dumps the JSON.

**Accepting a character everywhere.** Each function that takes a character accepts the same three forms through one
internal resolver: an id string (built-in or registered), `mascot_character(id)`, or checked data.

| Function | Change |
|---|---|
| `mascot(character =)`, `update_mascot(character =)` | Accept checked data publicly (U1's internal route becomes public). Unknown id: the error lists built-in and registered ids. |
| `mascot_preview(character =)` | Accepts all three forms; wording "every size draws the full character" becomes "small sizes may hide details the character marks for small sizes" (founder decision 3, 2026-10-17). |
| `mascot_moods()`, `mascot_gestures()`, `mascot_colour_roles()`, `mascot_anchors()`, `mascot_palettes()` | Accept all three forms and describe that character. |
| `mascot_characters(..., family = NULL)` | Lists built-in and registered characters, with a `built_in` column (exists). |
| `mascot_families()` | Lists built-in families and the family snapshots of registered characters (a `character` column names the registered character; `NA` for built-in rows). A registered character's embedded family is metadata, never a new source of defaults; two registered characters with the same family id and different snapshot labels are both listed with their character id, and built-in labels win for the family row. |
| `mascot_theme(preset =)` | Unchanged here; palettes are unit S1/R5. |

Moods and gestures: `mascot_mood("x")` and `mascot_gesture("x")` keep checking syntax only (lowercase id); membership
is checked against the actual character in `mascot()`, `update_mascot()` and `mascot_preview()`, with the error
listing that character's moods or gestures (as U1's rework does). The documented moods of built-ins are unchanged;
`mascot_moods()` without an argument keeps returning the five shared moods.

## 5. Safety, limits and users

- No network anywhere; reading only the path the user names; writing only the path the user names.
- Per-visitor characters are objects and never enter the process registry; registration is refused inside a
  reactive domain.
- A checked object is rechecked for integrity at every boundary (R lists can be mutated).
- Text in a character file (names, descriptions, status lines) is always drawn as text, never as HTML.
- The same bounds apply whether a character arrives as a JSON string, a parsed list or a checked object.
- Save validates the serialised output before it replaces anything.
- An installed help topic `?mascot_character_format` gives a compact offline guide to the format (the website
  article is the long version).
- The 0.1.0 format refuses reserved capabilities (C5 #306) and over-budget drawing (E5b #303): a file that works in
  0.1.0 keeps working; a file using later features is refused with a clear message, never half drawn.
- Known users (docs/consumers.md): nothing they use changes; Tessa stays the default.

## 6. Studio, docs and NEWS (studio in R4a; docs and NEWS in R4b)

- Studio: the "Your character" panel (D5), every new argument form demonstrated, completeness tests in
  test-examples.R extended to the four functions.
- Docs: roxygen for the four functions (experimental badge), "Write your own character" website article with one
  complete small character file (the Study Bot of r-builder-proposal section 4, written as JSON) checked in the
  article's build, `_pkgdown.yml` reference section "Your own characters", NEWS bullets.
- `inst/examples/characters/study_bot.json` shipped for examples and the studio (small; counted in the tarball).

## 7. Tests and acceptance

- Each function: every assertion, every documented error class and field, the happy path, offline examples.
- Read: missing file, directory, too large, invalid JSON, duplicate keys, reserved capability, over budget, valid.
- Check: list vs string vs object; mutated object refused; never modifies input.
- Register: idempotent, conflicting content, built-in id, inside `shiny::testServer()` refused, listing includes it.
- Save: round trip equal (identity, family metadata, palette sources), overwrite refused, failure leaves the original
  and cleans its temporary file, path reported exactly.
- Every character-taking function with all three forms; unknown id lists choices.
- Real Shiny: a registered character and an object character in two modules of one app; two sessions do not share
  object characters; update_mascot() swaps between Tessa (after M1) and a custom character.
- Studio: load the shipped file, a broken file (diagnostic shown), preview every mood.
- Gate: fast, tests (coverage not lower), T1 default unchanged by R4.

## 8. Format questions before FREEZE (from the review; not built in R4)

- **Accessory part names are ambiguous:** `wear_<accessory>_<local_id>` with snake_case ids makes accessory `a_b` part
  `c` and accessory `a` part `b_c` both `wear_a_b_c`. Recommended: forbid `__` in ids and expand as
  `wear__<accessory>__<local_id>`, decided before FREEZE.
- **One accessory on two unlike bodies:** prove explicit size, orientation, role and layer mapping on one bounded
  case before FREEZE; keep automatic fitting out; narrow any "any character can wear any item" wording in scope.md.
- **Multiple instances of one accessory:** state that 0.1.0 supports one instance per accessory id.

## 9. Not in R4

R constructors and remix (0.1.x, experimental), the builder app, shared accessories across characters (`wardrobe`)
and character inheritance (`extends`) (after 0.1.0; their place in the format is decided with their design),
palette APIs (S1/R5), new built-in characters (M3-M7).

## 10. Build order (slices, each reviewable)

R4a (internal; can start now, M1 first for the Tessa/custom swap cases):

1. One internal resolver for the three forms; listings and preview accept all three (no new exports).
2. `mascot_check_character()` and `mascot_read_character()` with errors, print method, examples file.
3. `mascot_register_character()` and listings of registered characters and families.
4. `mascot_save_character()` with atomic write.
5. `mascot()` / `update_mascot()` accept checked data (internal route until R4b); Shiny scenarios.
6. Studio panel behind an internal switch; the `?mascot_character_format` topic drafted.

R4b (after FREEZE and #304 parity): exports and experimental badges, the article, `_pkgdown.yml`, NEWS, the release
integration checks (section 12).

## 11. Changes after the design review (GPT-6 Astra, 2026-10-17)

Accepted: compatibility promise with a security exception and three separate versions (A1); a real editing workflow
through the JSON source, objects opaque (A2); source vs resolved artefact and content identity (A3, A4, D2 of the
review); accurate studio upload wording (A5); inert text, equal bounds, validated save, installed format guide (A6);
accessory namespace and composition proof as format questions before FREEZE (B2, B3); R4 split into internal build and
later promotion (C1, new D6); #304 parity as a gate (C2); a release integration row (C3); family snapshot listing rule
(D5 of the review). Kept: option B and the generic engine and resolved-file architecture, which the review endorsed.

## 12. Release integration (new plan row suggested by the review)

Before 0.1.0: scope.md, the API decisions, this plan and the NEWS tell one story (characters shipped, what authoring
is public); an outside author follows the article from a clean R session; installed examples run offline; package
size checked; saving works on Windows, macOS and Linux; CRAN checks clean. Quarto delivery stays in 0.2.0.

## 13. Risks

- Publishing the format early: mitigated by format_version, reserved capabilities refused, and experimental labels
  on the operations (not on the file format version itself).
- Users relying on a file that a later checker rejects: the checker may only get stricter in a new format version
  (contract: admission ceilings may rise, not fall, for a matching accounting version).
- Studio file input in a deployed studio: the studio is a local review tool; it reads the file in the R session and
  stores nothing.
