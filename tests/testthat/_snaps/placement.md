# mascot_placement() / checks positions, flags and unknown fields

    Code
      mascot_placement("left")
    Condition
      Error in `mascot_placement()`:
      ! `position` must be one of "inline", "top-left", "top-right", "bottom-left", or "bottom-right".
      x "left" is not a position.

# mascot_placement() / rejects TRUE, unknown and malformed drag values

    Code
      mascot_placement("bottom-right", drag = TRUE)
    Condition
      Error in `mascot_placement()`:
      ! `drag` must be `FALSE`, "snap" or "free".
      x `TRUE` is not accepted: choose how the mascot behaves when dropped.
      i Use "snap" to move to the nearest corner or "free" to stay where dropped.

---

    Code
      mascot_placement("bottom-right", drag = "fixed")
    Condition
      Error in `mascot_placement()`:
      ! `drag` must be `FALSE`, "snap" or "free".
      x "fixed" is not a drag mode.
      i Use "snap" to move to the nearest corner or "free" to stay where dropped.

---

    Code
      mascot(id = "a", placement = list(position = "top-left", drag = TRUE))
    Condition
      Error in `mascot()`:
      ! `placement$drag` must be FALSE, "snap" or "free"; got TRUE. Use "snap" to move to the nearest corner or "free" to stay where dropped.

# mascot_placement() / silently disables inline defaults and informs about each explicit control

    Code
      invisible(mascot_placement("inline", minimise = TRUE))
    Message
      `minimise` has no effect on an inline mascot.

---

    Code
      invisible(mascot_placement("inline", drag = "snap"))
    Message
      `drag` has no effect on an inline mascot.

---

    Code
      invisible(mascot_placement("inline", minimise = TRUE, drag = "free"))
    Message
      `minimise` has no effect on an inline mascot.
      `drag` has no effect on an inline mascot.
