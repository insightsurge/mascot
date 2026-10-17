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
      ! `character` must be one of "tessa", "sela", or "knurl".
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
      ! `theme` has unknown or reserved colour roles: "eye_whit". Did you mean "eye_white"? See `mascot_colour_roles()` for each character's roles.

