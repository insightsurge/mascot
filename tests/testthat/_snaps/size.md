# mascot_size() / rejects every invalid size and flag with a useful message

    Code
      mascot_size("24px")
    Condition
      Error in `mascot_size()`:
      ! `size` must be a finite number of pixels at least 24 or a positive percentage such as "20%"; got "24px".

---

    Code
      mascot_size(23)
    Condition
      Error in `mascot_size()`:
      ! `size` must be a finite number of pixels at least 24 or a positive percentage such as "20%"; got 23.

---

    Code
      mascot_size(120, small_screen = "bad")
    Condition
      Error in `mascot_size()`:
      ! `small_screen` must be a finite number of pixels at least 24 or a positive percentage such as "20%"; got "bad".

