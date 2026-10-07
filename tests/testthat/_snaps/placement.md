# mascot_placement() / checks all flags, corners, unknown fields and explicit inline options

    Code
      mascot_placement(position = "top-left")
    Condition
      Error in `mascot_placement()`:
      ! `position` only works with `floating = TRUE`.

---

    Code
      mascot_placement(TRUE, position = "left")
    Condition
      Error in `mascot_placement()`:
      ! `position` must be one of "top-left", "top-right", "bottom-left", or "bottom-right".
      x "left" is not a position.

---

    Code
      mascot_placement(minimise = TRUE)
    Condition
      Error in `mascot_placement()`:
      ! `minimise` only works with `floating = TRUE`.

