# Modules added and removed at run time

Cards inserted with `insertUI()` ten at a time, each a module with its own mascot and a fresh id, then the five
oldest removed with `removeUI()`, repeatedly. Every card's module sends an update in the same flush as its UI,
and every card listens to one shared "update everyone" button, including cards already removed.

Tries to break:

- Updates sent before a mascot exists, many ids in one session, and updates for mascots that are gone.

Should hold:

- Each new card shows its own "ready" update; the remaining cards take the shared update; removed cards stay gone.
- The runner reports how many per-id records the package keeps. They are kept until the session ends, by design;
  the number shows how that grows in a long session.

From the checkout root, run `Rscript tools/stress/run-stress.R 07` with the
R environment described in the parent README.

Reproduction sequence:

1. Click "Add 10 cards" three times: cards 1 to 30 each show "cardN ready".
2. Click "Remove the 5 oldest" five times: cards 26 to 30 remain.
3. Click "Update every card": cards 26 to 30 show "cardN round 1".
4. Click "Add 10 cards": cards 31 to 40 show "cardN ready".
