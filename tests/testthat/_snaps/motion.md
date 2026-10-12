# mascot_motion_settings() / rejects every invalid flag and extra argument with mascot_error

    Code
      as_motion_arg("sometimes", environment())
    Condition
      Error:
      ! `motion` must be TRUE, FALSE or a mascot_motion_settings() object; got "sometimes".

# mascot_motion_settings() / prints only the supplied settings and returns the helper invisibly

    Code
      print(mascot_motion_settings(messages = "menu", others = FALSE))
    Output
      mascot_motion_settings(messages = "menu", others = FALSE)

