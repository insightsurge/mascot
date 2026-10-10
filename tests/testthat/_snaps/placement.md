# mascot_placement() / checks positions, flags, unknown fields and minimising an inline mascot

    Code
      mascot_placement("left")
    Condition
      Error in `mascot_placement()`:
      ! `position` must be one of "inline", "top-left", "top-right", "bottom-left", or "bottom-right".
      x "left" is not a position.

---

    Code
      mascot_placement(minimise = TRUE)
    Condition
      Error in `mascot_placement()`:
      ! `minimise` needs a corner `position`; an inline mascot cannot be minimised.
      i Use `mascot_placement("bottom-right", minimise = TRUE)`.

# mascot_placement() / rejects TRUE, unknown and malformed drag values and dragging an inline mascot

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
      mascot_placement(drag = "snap")
    Condition
      Error in `mascot_placement()`:
      ! `drag` needs a corner `position`; an inline mascot cannot be dragged.
      i Use `mascot_placement("bottom-right", drag = "snap")`.

---

    Code
      mascot(id = "a", placement = list(position = "top-left", drag = TRUE))
    Condition
      Error in `mascot()`:
      ! `placement$drag` must be FALSE, "snap" or "free"; got TRUE. Use "snap" to move to the nearest corner or "free" to stay where dropped.

