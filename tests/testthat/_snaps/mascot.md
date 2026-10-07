# mascot() / returns the accessible tag structure and a runtime dependency

    Code
      cat(html)
    Output
      <div class="mascot" id="helper" data-character="tessa" data-mood="idle" data-status="mood">
        <script type="application/json" data-mascot-character="tessa">[character JSON]</script>
        <canvas class="mascot-canvas" role="img" aria-label="Tessa, idle"></canvas>
        <div class="mascot-status" role="status">Idle</div>
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

