# Eight modules in a rhino-shaped app

Tries to break:

- Nested module namespace isolation during rapid tab switches.
- Dependency loading with separate UI, server and module files.

Should hold:

- All eight mascots show their own namespaced id and count after updates.
- Updating the fourth mascot leaves the other seven unchanged.

Run `Rscript tools/stress/run-stress.R 01` from the checkout root, using the R
environment in the stress index. For manual use, load this checkout with
`pkgload::load_all(".")` then run this folder with `shiny::runApp()`.
Switch tabs 1 through 8, click each Change button, then click tab 4's button again.
The rhino layout uses plain Shiny, without rhino or box.
