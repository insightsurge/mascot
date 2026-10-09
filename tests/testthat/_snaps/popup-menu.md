# mascot_popup_menu() / rejects every invalid item, id and flag with the argument named

    Code
      mascot_popup_menu(c(`bad id` = "Help"))
    Condition
      Error in `mascot_popup_menu()`:
      ! `items` names must be unique, non-empty ids without whitespace; use c(about = 'About this app').
