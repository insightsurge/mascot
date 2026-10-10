# The explanations shown in the studio: one entry per exported function and per argument.
# tests/testthat/test-examples.R fails when an export or an argument has no entry here, so the
# studio grows with the package. Shiny sources this file before app.R attaches mascot, so it
# holds plain data only.

playground_categories <- list(
  look = list(
    title = "Character and mood",
    summary = "Who is drawn and how they feel. A mood changes the face, the pose and the default status text."
  ),
  messages = list(
    title = "Messages",
    summary = "Words beside the mascot: a status line that is always there, and a speech bubble for news."
  ),
  motion = list(
    title = "Motion and gestures",
    summary = "Whether changes animate, and one-off movements that leave the mood as it is."
  ),
  layout = list(
    title = "Size and placement",
    summary = "How big the mascot is, on wide and narrow screens, and whether it sits in the page or floats."
  ),
  colours = list(
    title = "Colours and theme",
    summary = "Recolour any part of the character, follow your app's brand, and choose light or dark."
  ),
  menu = list(
    title = "Popup menu",
    summary = "A small menu on the mascot. Each choice arrives in your server as an ordinary Shiny input."
  ),
  wiring = list(
    title = "Wiring it in Shiny",
    summary = "Where each call goes: mascot() in the UI, updateMascot() in the server, and modules."
  ),
  preview = list(
    title = "Static preview",
    summary = "An offline page that compares moods, colours and sizes without running Shiny."
  ),
  examples = list(
    title = "Bundled examples",
    summary = "Small apps that each teach one scenario. Copy one to start your own."
  )
)

guide_arg <- function(hint, accepts, default, null = NULL, detail = NULL, example = NULL, try = NULL) {
  list(hint = hint, accepts = accepts, default = default, null = null, detail = detail, example = example, try = try)
}

playground_guide <- list(
  mascot_character = list(
    category = "look",
    what = "Chooses a built-in character.",
    returns = "A mascot_character object with the character's id and display name.",
    args = list(
      name = guide_arg(
        "The character's id. Tessa (\"tessa\") is the only built-in character so far.",
        accepts = c("string"),
        default = "\"tessa\"",
        detail = "An unknown name is an error that lists the valid names. When more characters arrive,
          changing the character on a live mascot plays a short swap animation."
      )
    )
  ),
  mascot_mood = list(
    category = "look",
    what = "Sets the face and pose, and the status text when you have not written your own.",
    returns = "A mascot_mood object.",
    args = list(
      name = guide_arg(
        "One of the moods listed by mascot_moods().",
        accepts = c("string"),
        default = "\"idle\"",
        detail = "A mood change plays a short wiggle, then shows the new face. The status line names the
          mood unless you set your own status text, so the mood never carries meaning on its own.",
        example = "updateMascot(\"helper\", mood = \"worried\")"
      )
    )
  ),
  mascot_moods = list(
    category = "look",
    what = "Lists the moods, with a sentence on when to use each one.",
    returns = "A data frame with name and description columns.",
    args = list()
  ),
  mascot_status = list(
    category = "messages",
    what = "The always visible line under the mascot, read out by screen readers.",
    returns = "A mascot_status object.",
    args = list(
      text = guide_arg(
        "Your own words. Leave it empty to hand the line back to the mood.",
        accepts = c("string"),
        default = "NULL",
        null = "follows the mood (\"Happy\", \"Thinking\", ...)",
        detail = "The text is always escaped, so it is safe for text a visitor typed. Use it for a short
          description of the current state, such as \"Checking 120 rows\".",
        example = "updateMascot(\"helper\", status = mascot_status())  # back to the mood"
      )
    )
  ),
  mascot_bubble = list(
    category = "messages",
    what = "A speech bubble for something that just happened.",
    returns = "A mascot_bubble object.",
    args = list(
      text = guide_arg(
        "Plain text, HTML() or htmltools tags. Empty clears the bubble.",
        accepts = c("string", "HTML()", "tags"),
        default = "NULL",
        null = "clears the bubble",
        detail = "Plain text is escaped. HTML() and tags are trusted as they are: use them for your own
          content (bold words, a list, a small table), never for text a visitor typed. Tags that bring their
          own dependencies, such as an htmlwidget, are not supported.",
        example = "mascot_bubble(HTML(\"<strong>Saved.</strong> Your draft is safe.\"))"
      ),
      duration = guide_arg(
        "Seconds before the bubble hides itself. Inf keeps it until closed.",
        accepts = c("number > 0", "Inf"),
        default = "5",
        null = "same as Inf: stays until closed, replaced or cleared",
        detail = "Use a timed bubble for passing news. For a message that needs action, such as an
          invalid form, use Inf: a timed message can vanish before it is read. A hidden mascot pauses the
          timer and resumes it when shown again."
      ),
      closable = guide_arg(
        "Shows a close button on the bubble.",
        accepts = c("TRUE", "FALSE"),
        default = "TRUE",
        detail = "With FALSE the button is hidden; the Escape key still closes the bubble."
      )
    )
  ),
  mascot_motion = list(
    category = "motion",
    what = "Allows or stops animation. The visitor's reduced-motion setting always wins.",
    returns = "A mascot_motion object.",
    args = list(
      animate = guide_arg(
        "Animate mood changes and gestures. FALSE makes every change instant.",
        accepts = c("TRUE", "FALSE"),
        default = "TRUE",
        detail = "A visitor who asked their system for reduced motion sees instant changes even with
          TRUE. Use FALSE for screenshots, reports or a calmer page."
      ),
      swap = guide_arg(
        "Animate character changes. Has no effect when animate is FALSE.",
        accepts = c("TRUE", "FALSE"),
        default = "TRUE",
        detail = "FALSE swaps characters instantly while moods still animate."
      )
    )
  ),
  mascot_gesture = list(
    category = "motion",
    what = "A one-off movement, such as a nod, that leaves the mood unchanged.",
    returns = "A mascot_gesture object.",
    args = list(
      name = guide_arg(
        "One of the gestures listed by mascot_gestures().",
        accepts = c("string"),
        default = "none: required",
        detail = "Send it with updateMascot(\"helper\", gesture = \"nod\"). A gesture sent before the mascot
          appears plays once when it does.",
        example = "updateMascot(\"helper\", gesture = mascot_gesture(\"wave\"))"
      )
    )
  ),
  mascot_gestures = list(
    category = "motion",
    what = "Lists the gestures, with a sentence on when to use each one.",
    returns = "A data frame with name and description columns.",
    args = list()
  ),
  mascot_size = list(
    category = "layout",
    what = "Sets the drawing size, with an optional size for small screens.",
    returns = "A mascot_size object.",
    args = list(
      size = guide_arg(
        "CSS pixels (at least 24) or a percentage such as \"20%\".",
        accepts = c("number >= 24", "\"20%\""),
        default = "160",
        detail = "A percentage follows the width of the mascot's container when inline and the window
          width when floating. The drawing never gets smaller than 24 pixels."
      ),
      small_screen = guide_arg(
        "A different size for screens up to 576 pixels wide (phones).",
        accepts = c("number >= 24", "\"20%\""),
        default = "NULL",
        null = "uses size on every screen",
        detail = "Narrow your browser window below 576 pixels to see it switch."
      )
    )
  ),
  mascot_placement = list(
    category = "layout",
    what = "Keeps the mascot in the page, or floats it in a corner of the window.",
    returns = "A mascot_placement object.",
    args = list(
      position = guide_arg(
        "\"inline\" sits where you put mascot() in the UI; a corner floats it.",
        accepts = c("\"inline\"", "\"top-left\"", "\"top-right\"", "\"bottom-left\"", "\"bottom-right\""),
        default = "\"inline\"",
        detail = "A floating mascot stays in its corner while the page scrolls, above Shiny notifications.
          The shortcut \"floating\" means \"bottom-right\"."
      ),
      minimise = guide_arg(
        "Adds a minimise button to a floating mascot. Needs a corner.",
        accepts = c("TRUE", "FALSE"),
        default = "FALSE",
        detail = "A minimised mascot shrinks to a small restore button. Updates and messages still arrive
          and show when the visitor restores it."
      ),
      drag = guide_arg(
        "Let visitors drag a floating mascot. Pick a corner first.",
        accepts = c("FALSE", "\"snap\"", "\"free\""),
        default = "FALSE",
        detail = "Snap moves to the nearest corner on release. Free stays where dropped. In Shiny,
          input$<id>_position reports the corner for snap, or a list with x and y in CSS pixels for free.",
        example = "mascot_placement(\"bottom-right\", drag = \"snap\")"
      )
    )
  ),
  mascot_colour_roles = list(
    category = "colours",
    what = "Lists every part of a character you can recolour, its own colour and what it follows.",
    returns = "A data frame with role, colour, follows and shade columns.",
    args = list(
      character = guide_arg(
        "The character whose parts to list.",
        accepts = c("string", "mascot_character()"),
        default = "\"tessa\""
      )
    )
  ),
  mascot_theme = list(
    category = "colours",
    what = "Recolours parts of the character for light and dark mode.",
    returns = "A mascot_theme object.",
    args = list(
      light = guide_arg(
        "Colours for light mode, as a named list of parts: list(body = \"#1f6feb\").",
        accepts = c("named list"),
        default = "NULL",
        null = "the character's own colours in light mode",
        detail = "Values can be colour names, hex codes, rgb() output or CSS rgb() strings. Parts you leave
          out follow the parts they are tied to (the table below), or keep their own colour.",
        example = "mascot_theme(light = list(body = \"#1f6feb\", rim = \"#966600\"))"
      ),
      dark = guide_arg(
        "Colours for dark mode, in the same form as light.",
        accepts = c("named list"),
        default = "NULL",
        null = "the character's own colours in dark mode"
      ),
      mode = guide_arg(
        "\"auto\" follows the page's light/dark switch; \"light\" or \"dark\" fixes it.",
        accepts = c("\"auto\"", "\"light\"", "\"dark\""),
        default = "\"auto\"",
        detail = "Auto reads the page's Bootstrap signal (data-bs-theme, as set by bslib's
          input_dark_mode()), then Quarto's dark class. With no signal it uses light."
      ),
      css = guide_arg(
        "Ties parts to CSS variables of your page, such as list(body = \"--team-blue\").",
        accepts = c("named list"),
        default = "NULL",
        null = "no CSS source",
        detail = "Experimental. The browser reads the variable, so R cannot check it. A CSS entry wins
          over light and dark for the same part. A missing variable keeps the character's colour and warns
          in the browser console.",
        example = "mascot_theme(css = list(body = \"--bs-primary\"))"
      )
    )
  ),
  mascot_popup_menu = list(
    category = "menu",
    what = "Adds a small menu to the mascot; each choice becomes a Shiny input.",
    returns = "A mascot_popup_menu object.",
    args = list(
      items = guide_arg(
        "Labels named by item id: c(finish = \"Finish review\").",
        accepts = c("named character vector"),
        default = "NULL",
        null = "removes the menu",
        detail = "Ids are unique and have no spaces; labels are plain text. A choice sets
          input$<id>_menu to the item id, also when the same item is chosen twice. Enter or Space opens the
          menu from the keyboard, Escape closes it.",
        example = "observeEvent(input$helper_menu, {\n  if (input$helper_menu == \"finish\") ...\n})"
      )
    )
  ),
  mascot = list(
    category = "wiring",
    what = "Places a mascot in your UI. Every argument is a starting value.",
    returns = "An htmltools tag with the mascot's scripts and styles attached.",
    args = list(
      character = guide_arg(
        "Who to draw.",
        accepts = c("string", "mascot_character()"),
        default = "\"tessa\"",
        try = "look"
      ),
      id = guide_arg(
        "A unique name on the page. updateMascot() uses it to find this mascot.",
        accepts = c("string without spaces"),
        default = "none: required",
        detail = "In a module, wrap it in ns(): mascot(id = ns(\"helper\")). In that module's server, update
          it with the plain name: updateMascot(\"helper\", ...)."
      ),
      mood = guide_arg(
        "The starting mood.",
        accepts = c("string", "mascot_mood()"),
        default = "\"idle\"",
        try = "look"
      ),
      status = guide_arg(
        "The starting status text.",
        accepts = c("string", "mascot_status()"),
        default = "NULL",
        null = "follows the mood",
        try = "messages"
      ),
      bubble = guide_arg(
        "A bubble shown when the page opens.",
        accepts = c("string", "HTML()", "tags", "mascot_bubble()"),
        default = "NULL",
        null = "no bubble",
        try = "messages"
      ),
      size = guide_arg(
        "The starting size.",
        accepts = c("number", "\"20%\"", "mascot_size()"),
        default = "160",
        try = "layout"
      ),
      placement = guide_arg(
        "Inline or a floating corner.",
        accepts = c("string", "named list", "mascot_placement()"),
        default = "\"inline\"",
        try = "layout"
      ),
      theme = guide_arg(
        "The starting colours.",
        accepts = c("named list", "bslib::bs_theme()", "mascot_theme()"),
        default = "NULL",
        null = "the character's own colours",
        try = "colours"
      ),
      motion = guide_arg(
        "Whether changes animate.",
        accepts = c("TRUE", "FALSE", "mascot_motion()"),
        default = "TRUE",
        try = "motion"
      ),
      popup_menu = guide_arg(
        "A menu on the mascot.",
        accepts = c("named character vector", "mascot_popup_menu()"),
        default = "NULL",
        null = "no menu",
        try = "menu"
      )
    )
  ),
  updateMascot = list(
    category = "wiring",
    what = "Changes a live mascot from your server. Only the arguments you supply change.",
    returns = "Nothing useful (NULL, invisibly). It sends one message to the browser.",
    args = list(
      id = guide_arg(
        "The id you gave mascot(). Inside a module, without ns().",
        accepts = c("string"),
        default = "none: required",
        detail = "updateMascot() adds the module's namespace itself. If nothing happens, check the id: in
          development mode the browser console names the likely slip. Try \"The wrong id\" under Try a
          mistake.",
        try = "wiring"
      ),
      character = guide_arg(
        "Swap to another character.",
        accepts = c("string", "mascot_character()"),
        default = "NULL",
        null = "unchanged",
        try = "look"
      ),
      mood = guide_arg(
        "Change the mood.",
        accepts = c("string", "mascot_mood()"),
        default = "NULL",
        null = "unchanged",
        try = "look"
      ),
      status = guide_arg(
        "Set your own status, or mascot_status() to follow the mood again.",
        accepts = c("string", "mascot_status()"),
        default = "NULL",
        null = "unchanged",
        try = "messages"
      ),
      bubble = guide_arg(
        "Show a bubble, or mascot_bubble() to clear it.",
        accepts = c("string", "HTML()", "tags", "mascot_bubble()"),
        default = "NULL",
        null = "unchanged",
        try = "messages"
      ),
      size = guide_arg(
        "Resize the mascot.",
        accepts = c("number", "\"20%\"", "mascot_size()"),
        default = "NULL",
        null = "unchanged",
        try = "layout"
      ),
      placement = guide_arg(
        "Move it inline or to a corner.",
        accepts = c("string", "named list", "mascot_placement()"),
        default = "NULL",
        null = "unchanged",
        try = "layout"
      ),
      theme = guide_arg(
        "Recolour it, or mascot_theme() for the character's own colours.",
        accepts = c("named list", "bslib::bs_theme()", "mascot_theme()"),
        default = "NULL",
        null = "unchanged",
        try = "colours"
      ),
      motion = guide_arg(
        "Allow or stop animation.",
        accepts = c("TRUE", "FALSE", "mascot_motion()"),
        default = "NULL",
        null = "unchanged",
        try = "motion"
      ),
      popup_menu = guide_arg(
        "Set the menu, or mascot_popup_menu() to remove it.",
        accepts = c("named character vector", "mascot_popup_menu()"),
        default = "NULL",
        null = "unchanged",
        try = "menu"
      ),
      ... = guide_arg(
        "Must be empty: it catches misspelt argument names.",
        accepts = c("nothing"),
        default = "empty",
        detail = "A typo such as moood = \"happy\" is an error instead of being silently ignored. Try it in
          \"Try a mistake\" below."
      ),
      gesture = guide_arg(
        "Play a one-off gesture. Must be named: gesture = \"nod\".",
        accepts = c("string", "mascot_gesture()"),
        default = "NULL",
        null = "no gesture",
        try = "motion"
      ),
      session = guide_arg(
        "The Shiny session. The default works inside any server or module.",
        accepts = c("Shiny session"),
        default = "shiny::getDefaultReactiveDomain()",
        detail = "Supply it when the call runs outside a reactive context, such as a later::later() callback
          or a helper that receives the session. Must be named. The slow-task demo passes it for its second
          step; for real slow work, use shiny::ExtendedTask as in mascot_example(\"long-task\").",
        try = "wiring"
      )
    )
  ),
  mascot_preview = list(
    category = "preview",
    what = "Builds an offline page that compares moods, light and dark colours, and small drawings.",
    returns = "A browsable htmltools page; its contrast attribute lists colours below 3:1.",
    args = list(
      character = guide_arg(
        "The character to preview.",
        accepts = c("string", "mascot_character()"),
        default = "\"tessa\""
      ),
      mood = guide_arg(
        "One mood, or every mood side by side.",
        accepts = c("string", "mascot_mood()"),
        default = "NULL",
        null = "shows every mood"
      ),
      status = guide_arg(
        "Status text for every cell.",
        accepts = c("string", "mascot_status()"),
        default = "NULL",
        null = "follows each mood"
      ),
      bubble = guide_arg(
        "A bubble for every cell.",
        accepts = c("string", "HTML()", "mascot_bubble()"),
        default = "NULL",
        null = "no bubble"
      ),
      size = guide_arg(
        "The drawing size; a percentage follows the cell width.",
        accepts = c("number", "\"20%\"", "mascot_size()"),
        default = "160"
      ),
      placement = guide_arg(
        "Checked as in mascot(); the preview keeps every cell in its grid.",
        accepts = c("string", "named list", "mascot_placement()"),
        default = "\"inline\""
      ),
      theme = guide_arg(
        "Colours to compare in light and dark.",
        accepts = c("named list", "bslib::bs_theme()", "mascot_theme()"),
        default = "NULL",
        null = "the character's own colours"
      ),
      motion = guide_arg(
        "Animate the preview. Off by default so faces hold still for comparison.",
        accepts = c("TRUE", "FALSE", "mascot_motion()"),
        default = "FALSE"
      ),
      popup_menu = guide_arg(
        "Checked as in mascot(); menus stay inactive on a static page.",
        accepts = c("named character vector", "mascot_popup_menu()"),
        default = "NULL",
        null = "no menu"
      )
    )
  ),
  mascot_examples = list(
    category = "examples",
    what = "Lists the bundled example apps in teaching order.",
    returns = "A data frame with name, title and description columns.",
    args = list()
  ),
  mascot_example = list(
    category = "examples",
    what = "Runs a bundled example app, or returns where its code is.",
    returns = "With run = FALSE, the path to the app's app.R file.",
    args = list(
      name = guide_arg(
        "The example's name from mascot_examples().",
        accepts = c("string"),
        default = "none: required"
      ),
      run = guide_arg(
        "Launch the app (TRUE) or just return its path (FALSE).",
        accepts = c("TRUE", "FALSE"),
        default = "TRUE",
        detail = "Running needs an interactive R session. From a script or a test, use run = FALSE and pass
          the folder to shiny::runApp()."
      )
    )
  )
)
