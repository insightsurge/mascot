---
name: cran-gate
description: Run mascot's CRAN gate (tools/cran-gate.R) and act on its summary. Use before committing or opening a PR, when the user says /cran-gate, "run the gate", "is it CRAN-clean?", or asks to run the tests/coverage ("/cran-gate tests") or the full pre-release check ("/cran-gate full").
---

# /cran-gate

One script checks what CRAN and our house rules need; this skill runs it and reads only its summary.

```bash
Rscript tools/cran-gate.R [fast|tests|full|lint] [--update-wordlist]
```

| Mode | Runs | When |
|---|---|---|
| `fast` (default) | tools, Air, Biome, docs in sync, lintr, `\value`, spelling, `R CMD check --as-cran --no-tests` (`NOT_CRAN=false`) | before every commit |
| `tests` | tests with `NOT_CRAN=true` (Chrome tests run) and coverage (at least 90%) | when asked, and before a PR that touches `R/` or `tests/` |
| `full` | everything, plus the CRAN-like check with tests and the built tarball (size, `inst/` files shipped) | before a release, or when asked |
| `lint` | the static steps only | what CI's lint job runs |

## How to run it
1. Run from the package root. In a worktree, first point R at the main checkout's dev packages:
   `export R_LIBS=$(cd <main checkout> && Rscript -e 'cat(.libPaths()[1])' 2>/dev/null)` (renv keeps a package
   project's library outside the repo). The `tools` step prints `.libPaths()[1]` so you can see which was used.
2. Read only the PASS/FAIL/SKIP lines and the summary. Open the log (path printed) only for a failing step.
3. Fix the cause, then re-run. Typical fixes: `air format .`; `devtools::document()` then commit `man/` and
   `NAMESPACE`; the lint named in the line; `@returns` on the listed functions; the misspelt word.
4. **Spelling:** never run `--update-wordlist` on your own. Show the founder the unknown words; add them only after
   they agree the words are correct (names, technical terms), then commit `inst/WORDLIST`.
5. A gate pass isn't the whole PR gate: CI also runs R CMD check on 5 platforms, coverage and the no-Suggests check.

## Report
Give the summary in the PR template's terms, e.g. "`/cran-gate` fast: all passed (biome skipped: no JS/CSS yet);
`/cran-gate tests`: 5 expectations, coverage 100%". Say plainly what failed or was skipped and why.
