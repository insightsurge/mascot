---
paths:
  - "inst/**"
---

# Files the package ships (inst/)

Labels as in `r-code.md` (CRAN / house). Reasons and sources: `docs/standards.md`.

- **CRAN:** the copyright of every shipped file is clear: `inst/COPYRIGHTS` lists each non-R file (path, source,
  copyright holder, licence); third-party holders also get a `cph` entry with a `comment` in `Authors@R`.
- **CRAN:** fonts are OFL: ship each font's `OFL.txt` beside it (with its copyright line), use WOFF2 subsets, keep
  the file names (no Reserved Font Name applies to Space Grotesk or JetBrains Mono; recheck for a new font).
- **CRAN:** `inst/` must not use R's reserved names (`R`, `data`, `demo`, `exec`, `libs`, `man`, `help`, `html`,
  `Meta`, `src`); file names are ASCII, portable, not differing only by case, paths under 100 bytes.
- **house:** the built tarball stays under 5 MB (CRAN: under 10 MB if possible); the gate's `full` mode checks the
  size and that every `inst/` file is in the tarball.

## Acceptance checklist for the engine port (#9) and every new asset
- [ ] The file is in the built tarball (`Rscript tools/cran-gate.R full`, step `tarball`).
- [ ] It is listed in `inst/COPYRIGHTS` with its origin (the engine: Harsh Verma, MIT, first written in the
      playbook's `tools/animate/`), holder and licence; third parties have `cph`/`ctb` entries.
- [ ] It loads offline from the installed package (no network, no CDN).
- [ ] Its path is portable and case-correct, and it is referenced through `htmlDependency()` or `system.file()`.
