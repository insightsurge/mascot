# Slow work and reconnection

A 2.5-second handler with queued clicks, 200 calls per flush, 80 rapid inputs and a real websocket close.

Tries to break:

- Last-state coalescing, responsiveness and retained state across reconnect.

Should hold:

- The final update wins; disconnect displays worried and the documented connection-loss text; reconnect restores state and accepts the next input.

From the checkout root, run `Rscript tools/stress/run-stress.R 05` with the
R environment described in the parent README. See [../RESULTS.md](../RESULTS.md) for observed results.

Reproduction sequence:

1. Click Slow update six times quickly; wait for Slow 6 and the handled count of 6.
2. Click 200 updates; only Burst 200 (happy) should remain.
3. The runner submits 80 inputs five milliseconds apart, then another input to confirm response.
4. In the browser console, call `Shiny.shinyapp.$socket.close()`.
   The runner records the actual disconnect event, worried frame and connection-loss text.
5. On a transport supporting session resumption, wait for the websocket to reconnect.
   Rapid 81 must return, and Rapid 82 must apply. Local `runApp()` uses a raw
   websocket without session resumption, so the runner explicitly skips this
   recovery assertion there. `session$allowReconnect(TRUE)` requests reconnection
   only when the transport supports it. Forcing a new session would not test the
   package's retained session state.
