# update_mascot() / warns for every invalid value, without sending any part of an update

    Code
      update_mascot("helper", character = "neer", mood = "hapy", status = "",
        session = session)
    Condition
      Warning:
      `update_mascot()` left mascot "helper" unchanged.
      x `character` must be one of "tessa"; "neer" is not a character.
      x `mood` must be one of "idle", "thinking", "happy", "worried", "celebrating"; "hapy" is not a mood.
      x `status` must be a non-empty string or a mascot_status() object; use mascot_status() to follow the mood.

---

    Code
      update_mascot("helper", mood = "ha!py", session = session)
    Condition
      Warning:
      `update_mascot()` left mascot "helper" unchanged.
      x `mood` must be one of "idle", "thinking", "happy", "worried", "celebrating"; "ha!py" is not a mood.

# update_mascot() / errors on code mistakes before inspecting runtime values

    Code
      update_mascot("helper", typo = 1, session = session)
    Condition
      Error in `update_mascot()`:
      ! Unexpected arguments: "typo".
      i Name the optional arguments: `character`, `mood`, `status`, `bubble`, `size`, `placement`, `theme`, `motion`, `click`, `gesture`, and `session`.

---

    Code
      update_mascot("helper", NULL, NULL, NULL, NULL, session)
    Condition
      Error in `update_mascot()`:
      ! Unexpected arguments: "unnamed", "unnamed", "unnamed", "unnamed", and "unnamed".
      i Name the optional arguments: `character`, `mood`, `status`, `bubble`, `size`, `placement`, `theme`, `motion`, `click`, `gesture`, and `session`.

# update_mascot() size and placement / informs about explicit inline controls and still sends the complete update

    Code
      update_mascot("a", placement = list(position = "inline", minimise = TRUE),
      session = session)
    Message
      `minimise` has no effect on an inline mascot.

---

    Code
      update_mascot("a", placement = list(position = "inline", drag = "snap"),
      session = session)
    Message
      `drag` has no effect on an inline mascot.

---

    Code
      update_mascot("a", placement = mascot_placement("inline", minimise = TRUE),
      session = session)
    Message
      `minimise` has no effect on an inline mascot.

---

    Code
      update_mascot("a", placement = mascot_placement("inline", drag = "free"),
      session = session)
    Message
      `drag` has no effect on an inline mascot.

