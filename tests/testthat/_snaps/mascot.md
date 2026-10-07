# mascot() / returns the accessible tag structure and a runtime dependency

    Code
      cat(html)
    Output
      <div class="mascot" id="helper" tabindex="-1" data-character="tessa" data-mood="idle" data-status="mood">
        <script type="application/json" data-mascot-character="tessa">[character JSON]</script>
        <canvas class="mascot-canvas" role="img" tabindex="0" aria-label="Tessa, idle"></canvas>
        <div class="mascot-status" role="status">Idle</div>
        <div class="mascot-bubble-region" role="status" aria-live="polite" aria-atomic="true">
          <div class="mascot-bubble" hidden data-html="false" data-closable="true" data-duration="5">
            <div class="mascot-bubble-text"></div>
          </div>
        </div>
      </div>

# mascot() / attributes choice errors to mascot and rejects every invalid argument

    Code
      mascot(id = "a", mood = "hapy")
    Condition
      Error in `mascot()`:
      ! `mood` must be one of "idle", "thinking", "happy", "worried", or "celebrating".
      x "hapy" is not a mood.

---

    Code
      mascot("missing", "a")
    Condition
      Error in `mascot()`:
      ! `character` must be one of "tessa".
      x "missing" is not a character.

