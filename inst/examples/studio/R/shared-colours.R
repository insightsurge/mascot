# Colours that every view of the studio app shares: plain helpers built from mascot's listings, the colour pickers,
# and the pickers as a Shiny module (colour_roles_ui() and colour_roles_server()).

# The colours a user changed: each role's value that differs from the role's listed colour, in lower case and
# named by role. values holds the pickers' values by role; a role with no value has no picker yet.
changed_colours <- function(values, roles) {
  checkmate::assert_list(values, types = c("character", "null"))
  if (length(values)) {
    checkmate::assert_names(names(values), type = "unique")
  }
  checkmate::assert_data_frame(roles)
  checkmate::assert_names(names(roles), must.include = c("role", "colour"))
  picked <- vapply(
    roles$role,
    function(role) {
      value <- values[[role]]
      if (is.null(value)) NA_character_ else value
    },
    character(1)
  )
  keep <- !is.na(picked) & tolower(picked) != tolower(roles$colour)
  stats::setNames(tolower(picked[keep]), roles$role[keep])
}

# A character's colour roles with a palette applied. Listing them takes a moment, and the palette cards and the
# colour groups ask for every palette, so each listing is kept for the R session (built-in characters and palettes
# do not change while an app runs).
palette_roles_cache <- new.env(parent = emptyenv())
palette_roles <- function(character, palette = "original") {
  checkmate::assert_string(character, min.chars = 1)
  checkmate::assert_string(palette, min.chars = 1)
  key <- paste(character, palette, sep = "\r")
  if (is.null(palette_roles_cache[[key]])) {
    palette_roles_cache[[key]] <- mascot::mascot_colour_roles(character, palette = palette)
  }
  palette_roles_cache[[key]]
}

# The leaders (roles that follow no other role) whose colour a palette changes, in the character's role order.
palette_leaders <- function(character, palette) {
  checkmate::assert_string(character, min.chars = 1)
  checkmate::assert_string(palette, min.chars = 1)
  own <- palette_roles(character)
  listed <- palette_roles(character, palette)
  changed <- tolower(listed$colour[match(own$role, listed$role)]) != tolower(own$colour)
  own$role[is.na(own$follows) & changed]
}

# The parts a person changes first: the character's brand roles (the parts a bs_theme() colours), then the leaders
# that one of its palettes changes. A character with neither gets its leaders.
main_colour_roles <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  own <- palette_roles(character)
  palettes <- mascot::mascot_palettes(character)
  changed <- unlist(lapply(palettes$name[palettes$source != "native"], palette_leaders, character = character))
  brand <- own$role[!is.na(own$brand)]
  main <- c(brand, setdiff(own$role[own$role %in% changed], brand))
  if (length(main)) main else own$role[is.na(own$follows)]
}

# The colour pickers' groups: "Main colours" (main_colour_roles()), then "More parts": every other role, grouped by
# the name before its first underscore (body_shade and body_highlight under body), in the order of the roles.
colour_groups <- function(roles, character) {
  checkmate::assert_data_frame(roles)
  checkmate::assert_names(names(roles), must.include = "role")
  checkmate::assert_string(character, min.chars = 1)
  main <- intersect(main_colour_roles(character), roles$role)
  rest <- setdiff(roles$role, main)
  prefix <- sub("_.*$", "", rest)
  list(`Main colours` = main, `More parts` = split(rest, factor(prefix, levels = unique(prefix))))
}

# One card per palette in mascot_palettes() order: its name, the value a palette menu uses ("original" for the
# character's own colours), its description, and swatches named by role. The swatches are the brand roles, then the
# leaders the palette changes; the character's own colours show the main colours (main_colour_roles()).
palette_cards <- function(character) {
  checkmate::assert_string(character, min.chars = 1)
  palettes <- mascot::mascot_palettes(character)
  own <- palette_roles(character)
  brand <- own$role[!is.na(own$brand)]
  lapply(seq_len(nrow(palettes)), function(i) {
    native <- palettes$source[[i]] == "native"
    value <- if (native) "original" else palettes$name[[i]]
    listed <- palette_roles(character, value)
    parts <- if (native) main_colour_roles(character) else c(brand, setdiff(palette_leaders(character, value), brand))
    list(
      name = palettes$name[[i]],
      value = value,
      description = palettes$description[[i]],
      swatches = stats::setNames(listed$colour[match(parts, listed$role)], parts)
    )
  })
}

# ---- Colour pickers -------------------------------------------------------------------------

colour_input <- function(id, value, label, ...) {
  checkmate::assert_string(id, min.chars = 1)
  checkmate::assert_string(value)
  checkmate::assert_string(label)
  # A colour picker holds only #rrggbb. A role listed with transparency (rgba(...)) gets a text box with the
  # listed value instead, so it is never turned into a solid colour that would be sent as an override.
  solid <- grepl("^#[0-9a-fA-F]{6}$", value)
  shiny::tags$input(
    id = id,
    type = if (solid) "color" else "text",
    class = if (solid) {
      "pg-colour form-control form-control-color"
    } else {
      "pg-colour pg-colour-text form-control form-control-sm"
    },
    value = value,
    title = if (solid) label else paste0(label, " (translucent: edit the text, for example ", value, ")"),
    `aria-label` = label,
    spellcheck = if (!solid) "false",
    ...
  )
}

# One role's picker with its name, what it follows and a reset button. ns() names the picker and the reset event
# for a module. resolved adds the round swatch that shows the colour in use now; only a page that reads the drawn
# mascot's state can fill it (the studio does, from its live frame). leader is the word for a role that follows no
# other: the studio uses the help pages' "leader"; a page for app authors can say "own colour". The picker carries
# its listed colour (data-default) and is marked is-changed while it differs (inputs.js keeps that mark current), and
# the hint of a role that follows no other is marked pg-role-leader, so a page can style both.
role_picker <- function(mode, role, roles, value = NULL, resolved = TRUE, ns = shiny::NS(NULL), leader = "leader") {
  checkmate::assert_choice(mode, c("light", "dark"))
  checkmate::assert_data_frame(roles)
  checkmate::assert_choice(role, roles$role)
  checkmate::assert_string(value, null.ok = TRUE)
  checkmate::assert_flag(resolved)
  checkmate::assert_function(ns)
  checkmate::assert_string(leader, min.chars = 1)
  row <- roles[roles$role == role, ]
  follows <- if (is.na(row$follows)) leader else paste0("follows ", row$follows, " (", row$shade, ")")
  changed <- !is.null(value) && !identical(tolower(value), tolower(row$colour))
  shiny::div(
    class = if (changed) "pg-role is-changed" else "pg-role",
    `data-default` = row$colour,
    colour_input(
      ns(paste0(mode, "_", role)),
      if (is.null(value)) row$colour else value,
      paste(role, "in", mode, "mode")
    ),
    shiny::div(
      class = "pg-role-text",
      shiny::tags$code(role),
      shiny::div(class = if (is.na(row$follows)) "pg-muted pg-role-leader" else "pg-muted", follows)
    ),
    if (resolved) {
      shiny::tags$span(
        class = "pg-resolved",
        `data-role` = role,
        `data-mode` = mode,
        `data-default` = row$colour,
        title = "In use now"
      )
    },
    shiny::tags$button(
      type = "button",
      class = "btn btn-link btn-sm pg-role-reset",
      `data-event` = ns("reset_colour"),
      `data-value` = paste0(mode, ":", role),
      `aria-label` = paste("Reset", role, "in", mode, "mode"),
      "\u00d7"
    )
  )
}

# The pickers for one mode, in the groups of colour_groups(): Main colours open, More parts folded with a heading
# per group of parts. resolved, ns and leader as in role_picker().
role_pickers <- function(
  mode,
  roles,
  values = list(),
  name = mascot::mascot_character()$name,
  character = formals(mascot::mascot)$character,
  resolved = TRUE,
  ns = shiny::NS(NULL),
  leader = "leader"
) {
  checkmate::assert_choice(mode, c("light", "dark"))
  checkmate::assert_data_frame(roles)
  checkmate::assert_list(values)
  checkmate::assert_string(name)
  checkmate::assert_string(character, min.chars = 1)
  checkmate::assert_flag(resolved)
  checkmate::assert_function(ns)
  checkmate::assert_string(leader, min.chars = 1)
  role_groups <- colour_groups(roles, character)
  picker <- function(role) {
    role_picker(mode, role, roles, values[[role]], resolved = resolved, ns = ns, leader = leader)
  }
  more <- role_groups$`More parts`
  panels <- c(
    if (length(role_groups$`Main colours`)) {
      list(bslib::accordion_panel("Main colours", lapply(role_groups$`Main colours`, picker), value = "Main colours"))
    },
    if (length(more)) {
      list(bslib::accordion_panel(
        "More parts",
        lapply(names(more), function(group) {
          shiny::div(
            class = "pg-role-group",
            shiny::tags$h4(class = "pg-role-group-title", group),
            lapply(more[[group]], picker)
          )
        }),
        value = "More parts"
      ))
    }
  )
  shiny::tagList(
    shiny::div(
      class = "pg-hint",
      paste0(
        "Each picker starts at ",
        name,
        "'s colour. Change one to add it to the theme. Use \u00d7 to go back to the character's colour.",
        if (resolved) " The round swatch shows the colour in use now."
      )
    ),
    do.call(
      bslib::accordion,
      c(panels, list(open = if (length(role_groups$`Main colours`)) "Main colours" else "More parts"))
    ),
    shiny::tags$button(
      type = "button",
      class = "btn btn-sm btn-outline-primary",
      `data-event` = ns("reset_mode"),
      `data-value` = mode,
      paste("Reset", mode, "colours")
    )
  )
}

# Keep explicit overrides for shared roles; untouched pickers adopt the new palette.
reconcile_colour_values <- function(old_roles, roles, values) {
  checkmate::assert_data_frame(old_roles, null.ok = TRUE)
  checkmate::assert_data_frame(roles)
  checkmate::assert_list(values)
  stats::setNames(
    lapply(roles$role, function(role) {
      value <- values[[role]]
      if (is.null(old_roles) || !role %in% old_roles$role || is.null(value)) {
        return(NULL)
      }
      old <- old_roles$colour[match(role, old_roles$role)]
      if (tolower(value) == tolower(old)) NULL else value
    }),
    roles$role
  )
}

# ---- Colour roles as a Shiny module -----------------------------------------------------------------------------

# The colour pickers of colour_roles_server(), one piece per mode and one for the CSS variable, for the caller to
# lay out (the studio puts them in its Light, Dark and CSS variables tabs).
colour_roles_ui <- function(id, modes = c("light", "dark"), css = TRUE) {
  checkmate::assert_string(id, min.chars = 1)
  checkmate::assert_subset(modes, c("light", "dark"), empty.ok = FALSE)
  checkmate::assert_flag(css)
  ns <- shiny::NS(id)
  pieces <- lapply(stats::setNames(modes, modes), function(mode) shiny::uiOutput(ns(mode)))
  if (css) {
    pieces$css <- shiny::uiOutput(ns("css"))
  }
  pieces
}

# Colour pickers for every role of a character, in light and dark mode, and the parts that read a CSS variable.
# character and palette are reactives (a character id and a palette value, "original" for its own colours). css is
# the variable the CSS part offers, named with its starting value (c(`--brand` = "#7b4fd6")), or NULL for none.
# resolved shows each role's colour in use now, and leader names a role that follows no other (see role_picker()).
# Returns light, dark and css: reactives of the changed values (role = colour, role = variable), css_values: a
# reactive of the variable's value, and three functions: reset(mode = NULL, role = NULL) puts pickers back to the
# listed colours (with no arguments, every picker, and no part reads the variable); set(mode, role, value) sets one;
# clear_css() makes no part read the variable.
colour_roles_server <- function(id, character, palette, css = NULL, resolved = FALSE, leader = "leader") {
  checkmate::assert_string(id, min.chars = 1)
  checkmate::assert_class(character, "reactive")
  checkmate::assert_class(palette, "reactive")
  checkmate::assert_character(css, len = 1, any.missing = FALSE, names = "unique", null.ok = TRUE)
  checkmate::assert_flag(resolved)
  checkmate::assert_string(leader, min.chars = 1)
  shiny::moduleServer(id, function(input, output, session) {
    modes <- c("light", "dark")
    roles <- shiny::reactive(palette_roles(character(), palette()))
    # The colours the user changed, by mode, for the roles last drawn.
    picked <- shiny::reactiveValues(light = base::character(), dark = base::character())
    # The roles the pickers were last drawn with, and each picker's value when last read. Not reactive: only the
    # observers below change them, and nothing is drawn again because they change.
    shown <- new.env(parent = emptyenv())
    shown$roles <- NULL
    shown$values <- list()
    drawn <- shiny::reactiveVal(0L)
    # A new character or palette: keep the colours the user changed for roles the new listing has too, then draw.
    # The first drawing keeps every colour already picked (a set() before it), since no listing came before.
    shiny::observeEvent(roles(), {
      for (mode in modes) {
        now <- as.list(shiny::isolate(picked[[mode]]))
        kept <- if (is.null(shown$roles)) now else reconcile_colour_values(shown$roles, roles(), now)
        picked[[mode]] <- changed_colours(Filter(Negate(is.null), kept), roles())
      }
      shown$roles <- roles()
      drawn(shiny::isolate(drawn()) + 1L)
    })
    # A picker changed in the browser. Only a picker whose value changed since it was last read is a new choice:
    # right after a drawing the inputs still hold the old pickers' values, and a late value from an old picker can
    # still arrive, so the others are not read again against the new listing.
    shiny::observe({
      drawn()
      listed <- shown$roles
      shiny::req(listed)
      for (mode in modes) {
        now <- shiny::isolate(picked[[mode]])
        for (role in listed$role) {
          name <- paste0(mode, "_", role)
          value <- input[[name]]
          if (is.null(value) || identical(value, shown$values[[name]])) {
            next
          }
          shown$values[[name]] <- value
          now <- now[names(now) != role]
          if (tolower(value) != tolower(listed$colour[match(role, listed$role)])) {
            now[[role]] <- tolower(value)
          }
        }
        picked[[mode]] <- now
      }
    })
    pickers <- function(mode) {
      shiny::req(shown$roles)
      role_pickers(
        mode,
        shown$roles,
        as.list(shiny::isolate(picked[[mode]])),
        mascot::mascot_character(shiny::isolate(character()))$name,
        shiny::isolate(character()),
        resolved = resolved,
        ns = session$ns,
        leader = leader
      )
    }
    output$light <- shiny::bindEvent(shiny::renderUI(pickers("light")), drawn())
    output$dark <- shiny::bindEvent(shiny::renderUI(pickers("dark")), drawn())
    output$css <- shiny::bindEvent(
      shiny::renderUI({
        shiny::req(shown$roles, !is.null(css))
        shiny::tagList(
          shiny::div(
            class = "pg-css",
            colour_input(
              session$ns("css_value"),
              if (is.null(shiny::isolate(input$css_value))) unname(css) else shiny::isolate(input$css_value),
              paste("Value of", names(css)),
              `data-css-var` = names(css)
            ),
            shiny::tags$code(names(css))
          ),
          shiny::checkboxGroupInput(
            session$ns("css_roles"),
            "Parts that read the variable",
            shown$roles$role,
            selected = intersect(shiny::isolate(input$css_roles), shown$roles$role),
            inline = TRUE
          )
        )
      }),
      drawn()
    )
    for (name in c("light", "dark", "css")) {
      shiny::outputOptions(output, name, suspendWhenHidden = FALSE)
    }
    set <- function(mode, role, value) {
      checkmate::assert_choice(mode, modes)
      checkmate::assert_string(role, min.chars = 1)
      checkmate::assert_string(value, min.chars = 1)
      # In a running app Shiny adds the module's prefix to the input's name.
      session$sendInputMessage(paste0(mode, "_", role), list(value = value))
      listed <- shiny::isolate(roles())
      now <- shiny::isolate(picked[[mode]])
      now <- now[names(now) != role]
      colour <- listed$colour[match(role, listed$role)]
      if (!is.na(colour) && tolower(value) != tolower(colour)) {
        now[[role]] <- tolower(value)
      }
      picked[[mode]] <- now
      invisible(NULL)
    }
    reset <- function(mode = NULL, role = NULL) {
      checkmate::assert_choice(mode, modes, null.ok = TRUE)
      checkmate::assert_string(role, min.chars = 1, null.ok = TRUE)
      listed <- shiny::isolate(roles())
      for (each in if (is.null(mode)) modes else mode) {
        for (part in intersect(if (is.null(role)) listed$role else role, listed$role)) {
          set(each, part, listed$colour[match(part, listed$role)])
        }
      }
      if (is.null(mode) && is.null(role)) {
        clear_css()
      }
      invisible(NULL)
    }
    shiny::observeEvent(input$reset_colour, {
      parts <- strsplit(input$reset_colour, ":", fixed = TRUE)[[1]]
      shiny::req(length(parts) == 2L, parts[[1]] %in% modes, parts[[2]] %in% roles()$role)
      reset(parts[[1]], parts[[2]])
    })
    shiny::observeEvent(input$reset_mode, {
      shiny::req(input$reset_mode %in% modes)
      reset(input$reset_mode)
    })
    # The parts that read the variable: the checkboxes' choice, or none right after clear_css(), before the browser
    # reports the cleared checkboxes.
    css_parts <- shiny::reactiveVal(base::character())
    shiny::observeEvent(input$css_roles, css_parts(as.character(input$css_roles)), ignoreNULL = FALSE)
    clear_css <- function() {
      if (!is.null(css)) {
        css_parts(base::character())
        shiny::updateCheckboxGroupInput(session, "css_roles", selected = base::character())
      }
      invisible(NULL)
    }
    list(
      light = shiny::reactive(changed_colours(as.list(picked$light), roles())),
      dark = shiny::reactive(changed_colours(as.list(picked$dark), roles())),
      css = shiny::reactive({
        parts <- if (is.null(css)) base::character() else intersect(css_parts(), roles()$role)
        stats::setNames(rep(if (is.null(css)) base::character() else names(css), length(parts)), parts)
      }),
      css_values = shiny::reactive({
        if (is.null(css)) {
          stats::setNames(base::character(), base::character())
        } else {
          stats::setNames(if (is.null(input$css_value)) unname(css) else input$css_value, names(css))
        }
      }),
      reset = reset,
      set = set,
      clear_css = clear_css
    )
  })
}
