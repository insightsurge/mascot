# Internal character reader (R1b)

The reader is internal and is not connected to the current UI. It returns structural recipe data, never a fully checked character. Family/kit resolution, cross-references, fallback/contrast and drawing work are separate R1c responsibilities. No new function is exported.

`character_format_parse(x, from = "list")` accepts a raw R list; internal tests also use explicit text/file modes. Files are read only up to the byte limit plus one byte. UTF-8, JSON syntax, lexical container depth, decoded duplicate keys and node limits are checked before constructing the JSON value tree. The closed structural grammar is shipped in inst/format/character-v1.json.

Container depth counts the root object/array as one; scalar leaves do not add a container level. A structural node is one JSON value, including each container, scalar and null; object key strings are not extra values. The byte/depth/node limits report the root path $. Other diagnostics use zero-based array indices and decoded object keys, following the design. Unicode escape spellings compare after decoding; no additional Unicode normalisation is performed. Raw R input is bounded iteratively before schema recursion and again after typed array normalisation.

Schema-driven normalisation preserves JSON {} versus [], nullable members and singleton arrays. An unnamed R character/numeric vector is accepted for an array-typed field; length one does not make it a scalar JSON field. Empty R lists at object-typed fields become named empty objects. JSON objects/arrays retain their original distinction. These structural rules do not certify that references exist or that the character can render.

Malformed descriptions raise mascot_error_character inheriting mascot_error, with code/path/value/fix fields. File failures raise mascot_error_file, retaining the supplied path, read operation and original cause. Internal argument assertion failures follow the existing checkmate convention.

The format design is documented in [the engine proposal](https://github.com/insightsurge/mascot/blob/design/engine-format/docs/engine-format-proposal.md). New engine, registry, public builder and Shiny queue work follow their own units; this reader does not approve Q1 or replace the current character path.
