# mascot() / returns the accessible tag structure and a runtime dependency

    Code
      cat(html)
    Output
      <div class="mascot" id="helper" tabindex="-1" data-mount-token="[UI specification token]" data-character="tessa" data-mood="idle" data-status="mood" data-size="160" data-small-screen="auto" data-floating="true" data-position="bottom-right" data-minimise="true" data-drag="false" data-reduced="auto" data-idle="true" data-mood-change="true" data-gestures="true" data-swap="true" data-minimising="true" data-restoring="true" data-messages="bubble,tooltip,menu" data-others="true" data-mascot-version="[package version]">
        <script type="application/json" data-mascot-character="tessa">[character JSON]</script>
        <script type="application/json" data-mascot-baseline="">[UI baseline]</script>
        <canvas class="mascot-canvas" role="img" aria-label="Tessa, Resting, ready for the next piece."></canvas>
        <div class="mascot-status" role="status">Resting, ready for the next piece.</div>
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
      mascot(id = "a", mood = "ha!py")
    Condition
      Error in `mascot()`:
      ! `mood` must be a lowercase id; "ha!py" is not a mood.
      i Choose "idle", "thinking", "happy", "worried", or "celebrating".

---

    Code
      mascot("a", character = "missing")
    Condition
      Error in `mascot()`:
      ! `character` must be one of "tessa", "sela", "knurl", or "neer".
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
      ! `character` must be one of "tessa", "sela", "knurl", or "neer".
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
      ! `theme` has unknown or reserved colour roles: "bdoy". Did you mean "body"? Valid roles: "outline", "feature", "eye_white", "shine", "teeth", "eyelid", "tongue", "body", "body_highlight", "rim", "limb", "sleeve", "blush", "blush_strong", "accessory", "accessory_detail", "sparkle", "sparkle_outline", "sweat", "shadow", "outline_second", "hand", "body_shade", "rim_light", "rim_shade", "hair", "hair_shade", "hair_light", "accessory_light", "badge", "badge_icon", "iris", "iris_tint". See `mascot_colour_roles()` for each character's roles.

# with_mascot_asserts() / keeps the original assertion message once and adds mascot_error

    Code
      conditionMessage(wrapped)
    Output
      [1] "Assertion on 'value' failed: Must be of type 'string', not 'double'."

# review fixes for construction diagnostics and documentation / counts unnamed arguments and keeps named arguments listed

    Code
      mascot("helper", 1, 2, typo = 3)
    Condition
      Error in `mascot()`:
      ! Unexpected arguments: 2 unnamed arguments, "typo".
      i Name the optional arguments: `character`, `mood`, `status`, `bubble`, `size`, `placement`, `theme`, `motion`, and `click`.

---

    Code
      mascot("helper", 1)
    Condition
      Error in `mascot()`:
      ! Unexpected arguments: an unnamed argument.
      i Name the optional arguments: `character`, `mood`, `status`, `bubble`, `size`, `placement`, `theme`, `motion`, and `click`.

