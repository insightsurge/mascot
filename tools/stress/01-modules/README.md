# Modules and tabs

Eight nested modules in each of plain Shiny, golem and rhino-shaped apps.

Tries to break:

- Rapid tab switches and namespace isolation.

Should hold:

- Every mascot receives only its own mood and status; updating one leaves seven unchanged.

From the checkout root, run `Rscript tools/stress/run-stress.R 01` with the
R environment described in the parent README.

Reproduction sequence:

1. In each layout, switch tabs 1 through 8 quickly, then update every module once.
2. Each status must identify its own namespaced id and count 1, with a happy mood.
3. Update the fourth module again. Only it becomes worried with count 2.
4. The runner checks all eight desired moods, displayed moods and status strings.
