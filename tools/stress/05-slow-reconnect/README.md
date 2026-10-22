# Slow work and reconnection

A 2.5-second handler with queued clicks, 200 calls per flush (every 50th also swapping the character, opening a
bubble and nodding), 80 rapid inputs and a real websocket close followed by a reconnect. Motion is on.

Tries to break:

- Last-state coalescing while the mascot animates, responsiveness, and the mascot after a reconnect.

Should hold:

- The final update wins (Neer, happy, "Burst 200", bubble "Bubble 200"); disconnect displays worried and the
  documented connection-loss text; after the reconnect the page keeps its last state and takes the next update.

From the checkout root, run `Rscript tools/stress/run-stress.R 05` with the
R environment described in the parent README.

Reproduction sequence:

1. Click Slow update six times quickly; wait for Slow 6 and the handled count of 6.
2. Click 200 updates; only the last state should remain: Neer, happy, "Burst 200", with the "Bubble 200" bubble.
3. The runner submits 80 inputs five milliseconds apart, then another input to confirm response.
4. In the browser console, call `Shiny.shinyapp.$socket.close()`.
   The runner records the actual disconnect event, worried frame and connection-loss text.
5. Shiny reconnects within a few seconds. The app uses `session$allowReconnect("force")`, which Shiny provides
   for testing reconnects locally: as with `allowReconnect(TRUE)` on Shiny Server or Connect, the page reconnects
   into a new server session (the runner checks that the session id changed). Rapid 81 must still show, and
   Rapid 82 must apply. Shiny sends every input to the new session again, so the app's `slow` and `burst`
   observers run again there; the new session's state (Neer, from the repeated burst) is what the next update builds on.

After the reconnect, Shiny's own client logs that the `handled` output is "in an unexpected state"; those lines come
from Shiny, not the mascot, and up to four are allowed.
