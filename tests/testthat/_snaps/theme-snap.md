# mascot_theme() / warns once per supplied role and mode without altering low-contrast colours

    Code
      value <- as_theme_arg(mascot_theme(light = list(body = "white"), dark = list(
        rim = "#212529")), environment())
    Condition
      Warning:
      Colour for role "body" in light mode has contrast below 3:1 against "#ffffff"; the colour is kept.
      Warning:
      Colour for role "rim" in dark mode has contrast below 3:1 against "#212529"; the colour is kept.

