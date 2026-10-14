# Internal checked-character registry (R2)

An internal, process-lifetime store for format v1 checked character recipes in `mascot`.

## Purpose and scope

The internal character registry stores validated, self-contained character recipes
that have passed semantic verification (`character_format_check()`). Once integrated,
it will provide a safe boundary between format decoding and downstream consumers
(rendering, Shiny widgets, and HTML export; none is connected yet).

Scope is strictly internal:
- No public API changes; public character selection continues to route through `mascot_character()`.
- Process-lifetime store held in a package-private environment (`character_data_store`).
- No options, `.GlobalEnv` state, or file-system side effects.
- Built-in character catalogues (`R/characters.R`) remain separate until integration I1.

## Interface

The registry provides internal helpers (`@noRd`):

- `character_data_verify(x)`: Re-checks character recipe data with `character_format_check()`.
  Caller-supplied classes, resolved flags, and manifest attributes are not trusted.
  Returns newly verified data with canonical identity.
- `character_data_register(x)`: Verifies and registers a character recipe. Re-registering
  identical canonical content is idempotent. Conflicting content, or an id reserved for a
  shipped or planned built-in (`tessa`, `neer`, `alpha_visor`, `knurl`), errors with code
  `identity` at `$.id`. Registration within an active Shiny reactive
  domain is prohibited and errors with code `registry` at `$`. Returns verified data invisibly.
- `character_data_get(id)`: Returns the entry verified at registration, without checking it
  again (R copies a list when it is changed, so caller changes cannot reach the store). Unknown identifiers raise
  `missing_reference` at `$.id`. Retrieval is permitted inside and outside reactive domains.
- `character_data_ids()`: Returns a character vector of custom registered character identifiers
  in deterministic registration order.
- `character_data_reset(state = NULL)`: Test and lifecycle helper to clear or restore store state.

## Behaviour

1. **Verified once**: An unchecked list, forged `mascot_character_data` class, or
   mutated manifest cannot bypass the check at registration, the only write to the store.
2. **Separate values**: Caller modifications to retrieved structures do not affect the store.
3. **Registration timing**: Process state cannot be modified during active reactive execution
   (`shiny::getDefaultReactiveDomain()` is checked before state modification).
4. **Idempotence**: Re-registering identical content produces no duplicate entries in
   `character_data_ids()`.

Tests snapshot and restore the prior registry state. They do not clear another caller's entries at teardown. Character ids use the format v1 two-to-32-character rule.
