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
