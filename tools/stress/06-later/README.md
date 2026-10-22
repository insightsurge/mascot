# Updates from later() and promises

`update_mascot()` called half a second after an event, from a `later::later()` callback (with an explicit
`session`) and from a promise chain started in an observer. Nothing else happens on the page in between.

Tries to break:

- Updates are sent when Shiny flushes the session. With no input arriving, does a flush still happen?

Should hold:

- Each update reaches the mascot without any further click.

From the checkout root, run `Rscript tools/stress/run-stress.R 06` with the
R environment described in the parent README.

Reproduction sequence:

1. Click "Update from later()" once and wait: the mascot turns happy with "From later 1".
2. Click "Update from a promise" once and wait: thinking, "From promise 1".
