# Replacement and duplicate IDs

Twenty renderUI replacements, absent updates, insertUI and deliberate duplicate IDs; then a character swap with a
bubble and a nod carried across replacements, and a floating mascot replaced and removed. Motion is on.

Tries to break:

- Retained state, binding ownership and obsolete generations.
- Event-like updates across replacement: a gesture must play once, and a dismissed bubble must stay dismissed.
- Floating mascots, which the page moves to the end of `<body>` and must still remove with their output.

Should hold:

- Replacements restore the latest state; the first live duplicate stays authoritative; a complete stale envelope cannot alter a new mount or another id.
- After a swap to Sela with a bubble and a nod, re-renders keep Sela and the bubble, and no re-render offers the nod again.
- A dismissed bubble stays dismissed through a re-render.
- Exactly one floating mascot exists after each re-render, with the latest update; none remains after its output is removed.
- Duplicate-id warnings are expected here; more than two fail the run.

From the checkout root, run `Rscript tools/stress/run-stress.R 02` with the
R environment described in the parent README.

Reproduction sequence:

1. Click Update, then Re-render; repeat twenty times.
2. Click Remove, Update while absent, then Insert. The new mascot must show the latest update.
3. Click Duplicate then Update. Only the first live same-id binding is authoritative;
   the independent `other` mascot must still say Untouched.
4. The runner saves a real server envelope, removes both copies, re-renders, and
   delivers that old envelope with a higher revision and a visibly different payload.
   The replacement must keep the retained current state.
5. Click "Swap, bubble and nod", wait for the nod, then Re-render three times: still Sela, celebrating, "Rich",
   with the "Saved" bubble; the nod does not play again.
6. Close the bubble, then Re-render: the bubble stays closed.
7. Click "Update floating" then "Re-render floating", five times; then "Remove floating": no floating mascot is left.
