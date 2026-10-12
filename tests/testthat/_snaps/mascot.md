# mascot() / returns the accessible tag structure and a runtime dependency

    Code
      cat(html)
    Output
      <div class="mascot" id="helper" tabindex="-1" data-character="tessa" data-mood="idle" data-status="mood" data-size="160" data-small-screen="auto" data-floating="true" data-position="bottom-right" data-minimise="true" data-drag="false" data-reduced="auto" data-swap="true">
        <script type="application/json" data-mascot-character="tessa">[character JSON]</script>
        <canvas class="mascot-canvas" role="img" aria-label="Tessa, idle"></canvas>
        <div class="mascot-status" role="status">Idle</div>
        <div class="mascot-bubble-region" role="status" aria-live="polite" aria-atomic="true">
          <div class="mascot-panel mascot-bubble" hidden data-html="false" data-closable="true" data-duration="5">
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
      mascot("a", character = "missing")
    Condition
      Error in `mascot()`:
      ! `character` must be one of "tessa".
      x "missing" is not a character.

# mascot() size and placement / writes data attributes without inline layout styles and normalises shortcuts

    Code
      mascot(id = "a", placement = "fixed")
    Condition
      Error in `mascot()`:
      ! `placement` must be one of "inline", "top-left", "top-right", "bottom-left", "bottom-right", a named list with position, minimise and drag fields, or a mascot_placement() object; got "fixed".

---

    Code
      mascot()
    Condition
      Error in `mascot()`:
      ! `id` is missing; every mascot needs one.
      i Supply an id, such as `mascot("helper")`.

---

    Code
      mascot("a", character = "typo")
    Condition
      Error in `mascot()`:
      ! `character` must be one of "tessa".
      x "typo" is not a character.

# mascot() size and placement / silently disables inline defaults and informs about explicit list controls

    Code
      invisible(mascot(id = "a", placement = list(position = "inline", minimise = TRUE)))
    Message
      `minimise` has no effect on an inline mascot.

---

    Code
      invisible(mascot(id = "a", placement = list(position = "inline", drag = "snap")))
    Message
      `drag` has no effect on an inline mascot.

---

    Code
      invisible(mascot(id = "a", placement = mascot_placement("inline", minimise = TRUE)))
    Message
      `minimise` has no effect on an inline mascot.

---

    Code
      invisible(mascot(id = "a", placement = mascot_placement("inline", drag = "free")))
    Message
      `drag` has no effect on an inline mascot.

# mascot() themes / embeds both palettes with auto by default and preserves explicit modes

    Code
      mascot(id = "bad", theme = list(bdoy = "blue"))
    Condition
      Error in `mascot()`:
      ! `theme` has unknown or reserved colour roles: "bdoy". Valid roles: outline, feature, eye_white, shine, teeth, eyelid, tongue, body, body_highlight, rim, limb, sleeve, blush, blush_strong, accessory, accessory_detail, sparkle, sparkle_outline, sweat, shadow.

# with_mascot_asserts() / keeps the original assertion message once and adds mascot_error

    Code
      conditionMessage(wrapped)
    Output
      [1] "Assertion on 'value' failed: Must be of type 'string', not 'double'."

