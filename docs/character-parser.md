# Internal character reader (R1b)

The reader is internal and is not connected to the current UI. It returns structural recipe data, never a fully checked character. Family/kit resolution, cross-references, fallback/contrast and drawing work are separate R1c responsibilities. No new function is exported.

`character_format_parse(x, from = "list")` accepts a raw R list; internal tests also use explicit text/file modes. Files are read only up to the byte limit plus one byte. UTF-8, JSON syntax, lexical container depth, decoded duplicate keys and node limits are checked before constructing the JSON value tree. The closed structural grammar is shipped in inst/format/character-v1.json.

Container depth counts the root object/array as one; scalar leaves do not add a container level. A structural node is one JSON value, including each container, scalar and null; object key strings are not extra values. The byte/depth/node limits report the root path $. Other diagnostics use zero-based array indices and decoded object keys, following the design. Unicode escape spellings compare after decoding; no additional Unicode normalisation is performed. Raw R input is bounded iteratively before schema recursion and again after typed array normalisation.

Schema-driven normalisation preserves JSON {} versus [], nullable members and singleton arrays. An unnamed R character/numeric vector is accepted for an array-typed field; length one does not make it a scalar JSON field. Empty R lists at object-typed fields become named empty objects. JSON objects/arrays retain their original distinction. These structural rules do not certify that references exist or that the character can render. Numeric tuning trees reject data frames and discard caller attributes, retaining only list names. Arrays below their structural minimum report `input_type`; exceeding the track-key input quota intentionally reports `budget`. Grammar factoring preserves accepted values, with this explicit ceiling diagnostic distinction.

Malformed descriptions raise mascot_error_character inheriting mascot_error, with code/path/value/fix fields. File failures raise mascot_error_file, retaining the supplied path, read operation and original cause. Internal argument assertion failures follow the existing checkmate convention.

The format design is documented in [the engine proposal](https://github.com/insightsurge/mascot/blob/918893f2e900867d93154e9d50c2ecdf820a5a69/docs/engine-format-proposal.md) and [the core contract](https://github.com/insightsurge/mascot/blob/918893f2e900867d93154e9d50c2ecdf820a5a69/docs/character-format/contract.md). New engine, registry, public builder and Shiny queue work follow their own units; this reader does not approve Q1 or replace the current character path.

## Where the copied data comes from

Several package files are copies of the reference files in `docs/character-format/` on the design branch
([pinned](https://github.com/insightsurge/mascot/blob/918893f2e900867d93154e9d50c2ecdf820a5a69/docs/character-format)). That folder is the source; change it first, then copy:

| Package file | Source on the design branch | Copy |
|---|---|---|
| `inst/format/policy-v1.json` | `character-format/limits.json` | same data, without `evidence` and with its own `status` |
| `inst/format/kits/classic.json`, `screen.json` | `character-format/fixtures/kits/` | same data |
| `tests/testthat/fixtures/format/tessa.json`, `alpha_visor.json`, `anchor_probe.json` | `character-format/fixtures/characters/` | identical |
| `tests/testthat/fixtures/format/study_bot.json` | `character-format/fixtures/source/study_bot.json` | same data |
| `tests/testthat/fixtures/format/study_bot-resolved.json` | `character-format/fixtures/expected/study_bot.json` | same data |
| `tests/testthat/fixtures/format/invalid/*.json` | `character-format/fixtures/invalid/` | identical |
| `tests/testthat/fixtures/format/diagnostic-expected.json` | the invalid-file entries of `character-format/fixtures/manifest.json` | extracted |
| `tests/testthat/fixtures/format/work-expected.json` | `character-format/budgets.json`, written by `python3 -I character-format/budget.py` | identical |

`work-expected.json` is computed by the Python reference, independently of the R code, so the work tests do not
mirror the implementation. After changing a source file, rerun `python3 -I docs/character-format/check.py` and
`budget.py` on the design branch, copy the result, and run the `character-` tests.

## Checked data and built-in provenance

`character_format_check(..., builtin = FALSE)` rejects reserved built-in ids on every custom input path, including direct lists and saved snapshots. Only an internal loader of shipped recipes may pass `builtin = TRUE`; neither an id nor a caller attribute grants built-in provenance. The flag also selects the built-in face contrast promise, independently of the id. No public API exposes it and no live built-in loader uses this format path yet.

The checker completes per-band work and fit budget proofs before evaluating contrast promises, so a recipe with both defects reports the budget first.
