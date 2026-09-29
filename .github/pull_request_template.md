Closes #

## What changed

## Checks
- [ ] `air format .` and `lintr::lint_package()`
- [ ] `devtools::test()`: new behaviour has BDD-style tests (`describe()` / `it()`); Shiny behaviour has shinytest2 tests
- [ ] `covr::package_coverage()`: at least 90%, not lower than `main`
- [ ] Every new or changed function checks its arguments with checkmate (and those checks are tested)
- [ ] `devtools::check(args = "--as-cran")`: 0 errors, 0 warnings, 0 notes
- [ ] `NEWS.md` bullet added for any user-facing change, ending with `(#issue)` (rules in CLAUDE.md)
- [ ] `pkgdown::build_site()` looked at (docs, exports or examples changed)
- [ ] Known users (`docs/consumers.md`) checked; `consumer-impact` label if any may be affected
- [ ] PR labelled (type + area) for the release notes
