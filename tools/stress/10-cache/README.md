# A mascot in a cached renderUI()

A mascot built inside `renderUI()`, with `shiny::bindCache()` on the output. The first session builds the HTML;
every later session in the same R process receives the cached HTML.

Tries to break:

- The mascot's mount token belongs to the session that built it. Does a second session still verify the cached
  mascot and accept updates?

Should hold:

- The first session shows "Cached" and takes an update.
- After a page reload (a new session) the mascot shows "Cached" again, not the "could not be verified" notice,
  and takes an update.

From the checkout root, run `Rscript tools/stress/run-stress.R 10` with the
R environment described in the parent README.

Reproduction sequence:

1. Click "Update the mascot": the mascot turns happy with "Updated 1".
2. Reload the page: the mascot shows "Cached".
3. Click "Update the mascot": happy, "Updated 1".
