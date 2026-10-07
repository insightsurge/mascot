# updateMascot() / warns for every invalid value, without sending any part of an update

    Code
      updateMascot("helper", character = "neer", mood = "hapy", status = "", session = session)
    Condition
      Warning:
      `updateMascot()` left mascot "helper" unchanged.
      x `character` must be one of "tessa"; "neer" is not a character.
      x `mood` must be one of "idle", "thinking", "happy", "worried", "celebrating"; "hapy" is not a mood.
      x `status` must be a non-empty string or a mascot_status() object; use mascot_status() to follow the mood.

# updateMascot() / errors on code mistakes before inspecting runtime values

    Code
      updateMascot("helper", typo = 1, session = session)
    Condition
      Error in `updateMascot()`:
      ! Unexpected arguments: "typo".
      i Use `id`, `character`, `mood`, `status` and `session`; `session` must be named.

---

    Code
      updateMascot("helper", NULL, NULL, NULL, session)
    Condition
      Error in `updateMascot()`:
      ! Unexpected arguments: "unnamed".
      i Use `id`, `character`, `mood`, `status` and `session`; `session` must be named.

