# mascot_preview() / warns once, keeps colours and lists independent contrast findings in R and on the page

    Code
      page <- mascot_preview(mood = "idle", theme = list(body = "white"))
    Condition
      Warning:
      Preview colours have contrast below 3:1; the colours are kept.
      i body: #FFFFFF against #FFFFFF, 1.00:1 (light).

# mascot_preview() / shares build-time errors for every shortcut and malformed helper

    Code
      mascot_preview(character = "typo")
    Condition
      Error in `mascot_preview()`:
      ! `character` must be one of "tessa", "sela", "knurl", or "neer".
      x "typo" is not a character.

---

    Code
      mascot_preview(mood = "typo")
    Condition
      Error in `mascot_preview()`:
      ! `mood` must be one of "idle", "thinking", "happy", "worried", or "celebrating".
      x "typo" is not a mood.

---

    Code
      mascot_preview(theme = list(eye_whit = "red"))
    Condition
      Error in `mascot_preview()`:
      ! `theme` has unknown or reserved colour roles: "eye_whit". Did you mean "eye_white"? Valid roles: "outline", "feature", "eye_white", "shine", "teeth", "eyelid", "tongue", "body", "body_highlight", "rim", "limb", "sleeve", "blush", "blush_strong", "accessory", "accessory_detail", "sparkle", "sparkle_outline", "sweat", "shadow", "outline_second", "hand", "body_shade", "rim_light", "rim_shade", "hair", "hair_shade", "hair_light", "accessory_light", "badge", "badge_icon", "iris", "iris_tint". See `mascot_colour_roles()` for each character's roles.

