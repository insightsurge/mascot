# mascot_theme() / rejects malformed maps, reserved roles, colours and helper fields

    Code
      mascot_theme(light = list(bdoy = "blue"))
    Condition
      Error in `mascot_theme()`:
      ! `theme$light` has unknown or reserved colour roles: "bdoy". Valid roles: outline, feature, eye_white, shine, teeth, eyelid, tongue, body, body_highlight, rim, limb, sleeve, blush, blush_strong, accessory, accessory_detail, sparkle, sparkle_outline, sweat, shadow.

# mascot_theme() / warns once per supplied role and mode without altering low-contrast colours

    Code
      value <- as_theme_arg(mascot_theme(light = list(body = "white"), dark = list(
        rim = "#212529")), environment())
    Condition
      Warning:
      Colour for role "body" in light mode has contrast below 3:1 against "#ffffff"; the colour is kept.
      Warning:
      Colour for role "rim" in dark mode has contrast below 3:1 against "#212529"; the colour is kept.
