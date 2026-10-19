# mascot_theme() / rejects malformed maps, reserved roles, colours and helper fields

    Code
      mascot_theme(light = list(bdoy = "blue"))
    Condition
      Error in `mascot_theme()`:
      ! `theme$light` has unknown or reserved colour roles: "bdoy". Did you mean "body"? Valid roles: "outline", "feature", "eye_white", "shine", "teeth", "eyelid", "tongue", "body", "body_highlight", "rim", "limb", "sleeve", "blush", "blush_strong", "accessory", "accessory_detail", "sparkle", "sparkle_outline", "sweat", "shadow", "outline_second", "hand", "body_shade", "rim_light", "rim_shade", "hair", "hair_shade", "hair_light", "accessory_light", "badge", "badge_icon", "iris", "iris_tint", "mouth_in", "iris_dark", "hair_purple", "hair_dark", "fringe_pink", "fringe_cyan", "chip_a", "chip_b", "chip_conflict", "star", "arm", "arm_highlight", "gold", "sweat_deep", "body_shine", "copper", "copper_light", "copper_shine", "screen", "screen_glow", "eye_glow", "outline_light", "trim", "arm_body", "arm_socket", "spanner_handle", "spanner_head", "clamp_base", "antenna", "lamp", "lamp_thinking", "lamp_happy", "lamp_worried", "lamp_celebrating", "shine_translucent", "hub_spoke", "hub_rim_light", "hub_rim_mid", "hub_rim_dark", "tyre_dark", "tyre_mid", "tyre_tick", "body_light", "body_deep", "band", "ivory", "brow", "shell_light", "shell_base", "shell_foot", "shell_rib", "sweat_light", "sweat_base", "water_top", "water_bottom". See `mascot_colour_roles()` for each character's roles.

# mascot_theme() / warns once per supplied role and mode without altering low-contrast colours

    Code
      value <- as_theme_arg(mascot_theme(light = list(body = "white"), dark = list(
        rim = "#212529")), environment())
    Condition
      Warning:
      Colour for role "body" in light mode has contrast below 3:1 against "#ffffff"; the colour is kept.
      Warning:
      Colour for role "rim" in dark mode has contrast below 3:1 against "#212529"; the colour is kept.

