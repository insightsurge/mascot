# Async observers

ExtendedTask with a delayed promise, three competing observers and renderUI.

Tries to break:

- Updates during asynchronous work and after replacement.

Should hold:

- The explicit last observer wins; task completion and re-render retain the intended state without unexpected warnings.

From the checkout root, run `Rscript tools/stress/run-stress.R 03` with the
R environment described in the parent README. See [../RESULTS.md](../RESULTS.md) for observed results.

Reproduction sequence:

1. Start the task. While it is running, click First observer, then Second observer.
2. Re-render during work, then click Complete task. Its promise resolves through
   `later` after 0.2 seconds; wait for task status success and the Complete status.
   Completion is gated so browser scheduling cannot finish the task before the in-flight checks.
3. Re-render again, then click First observer and Final observer. Final must remain.
4. Inspect browser/server logs for unexpected warnings or errors.
