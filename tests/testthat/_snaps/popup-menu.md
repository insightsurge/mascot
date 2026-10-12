# mascot_popup_menu() / rejects every invalid item, id, label and tooltip value with the argument named

    Code
      mascot_popup_menu(c(`bad id` = "Help"))
    Condition
      Error in `mascot_popup_menu()`:
      ! `items` names must be unique, non-empty ids without whitespace; use c(about = 'About this app').

# mascot_popup_menu() / rejects values caught by `...`, including a direction given by position

    Code
      mascot_popup_menu(c(a = "A"), "top", extra = TRUE)
    Condition
      Error in `mascot_popup_menu()`:
      ! Unexpected arguments: "unnamed" and "extra".
      i Name the optional arguments: `direction` and `label`.

# mascot_popup_menu() / rejects invalid directions and malformed helpers with snapshots

    Code
      mascot_popup_menu(direction = "center")
    Condition
      Error in `mascot_popup_menu()`:
      ! `direction` must be one of "auto", "top", "bottom", "left", or "right".
      x "center" is not a direction.

