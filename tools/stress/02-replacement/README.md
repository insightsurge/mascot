# Replacement and duplicate IDs

Twenty renderUI replacements, absent updates, insertUI and deliberate duplicate IDs.

Tries to break:

- Retained state, binding ownership and obsolete generations.

Should hold:

- Replacements restore the latest state; the first live duplicate stays authoritative; a complete stale envelope cannot alter a new mount or another id.

From the checkout root, run `Rscript tools/stress/run-stress.R 02` with the
R environment described in the parent README. See [../RESULTS.md](../RESULTS.md) for observed results.

Reproduction sequence:

1. Click Update, then Re-render; repeat twenty times.
2. Click Remove, Update while absent, then Insert. The new mascot must show the latest update.
3. Click Duplicate then Update. Only the first live same-id binding is authoritative;
   the independent `other` mascot must still say Untouched.
4. The runner saves a real server envelope, removes both copies, re-renders, and
   delivers that old envelope with a higher revision and a visibly different payload.
   The replacement must keep the retained current state.
