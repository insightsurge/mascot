# mascot_action() / rejects values caught by `...`, including a flag given by position

    Code
      mascot_action("Open help", FALSE, href = "#help")
    Condition
      Error in `mascot_action()`:
      ! Unexpected arguments: "unnamed" and "href".
      i Name the optional arguments: `tooltip` and `disabled`.

# mascot_action() / prints the call's fields

    Code
      print(mascot_action("Open help"))
    Output
      mascot_action(label = "Open help", tooltip = TRUE, disabled = FALSE)

# the click argument / rejects a named vector, the old menu shortcut, with a hint to wrap it

    Code
      mascot(id = "helper", click = c(help = "Help", about = "About"))
    Condition
      Error in `mascot()`:
      ! `click` got a named vector; for a menu, wrap it in mascot_popup_menu(), such as click = mascot_popup_menu(c(help = "Help")).

# the click argument / rejects anything but one non-empty label or a helper

    Code
      mascot(id = "helper", click = TRUE)
    Condition
      Error in `mascot()`:
      ! `click` must be one non-empty label such as "Open help", a mascot_action() or mascot_popup_menu() object, or NULL for no click.
