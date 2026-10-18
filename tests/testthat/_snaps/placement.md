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
      ! `drag` must be one of "none", "snap", or "free".
      x "TRUE" is not a drag mode (TRUE is not accepted); use drag = "none" for no dragging.

---

    Code
      mascot_placement("bottom-right", drag = "fixed")
    Condition
      Error in `mascot_placement()`:
      ! `drag` must be one of "none", "snap", or "free".
      x "fixed" is not a drag mode; use drag = "none" for no dragging.

---

    Code
      mascot(id = "a", placement = list(position = "top-left", drag = TRUE))
    Condition
      Error in `mascot()`:
      ! `placement$drag` must be "none", "snap" or "free"; got TRUE. Use drag = "none" for no dragging.

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

