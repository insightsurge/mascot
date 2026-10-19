describe("the internal Your character studio panel in Chrome", {
  it("loads the example, renders every mood, shows a broken file diagnostic and previews a selected mood", {
    local_shiny_browser()
    app <- app_driver(function() {
      library(mascot)
      options(mascot.internal.character_panel = TRUE)
      mascot_studio(run = FALSE)
    })
    withr::defer(app$stop())
    app$click(selector = "#open_inspector")
    app$run_js("document.querySelector('details:has(#your_character_example)').open = true")
    app$click("your_character_example")
    app$wait_for_js("document.getElementById('your_character_check').textContent === 'Checked: Study Bot'")
    app$wait_for_js("document.querySelectorAll('#your_character_grid .mascot').length === 40")
    expect_identical(
      app$get_js(
        "Array.from(new Set(Array.from(document.querySelectorAll('#your_character_grid .mascot')).map(x=>x.dataset.mood)))"
      ),
      list("idle", "thinking", "happy", "worried", "celebrating")
    )
    expect_match(
      app$get_js("document.getElementById('your_character_code').textContent"),
      'mascot_read_character("study_bot.json")',
      fixed = TRUE
    )
    expect_match(
      app$get_js("document.getElementById('your_character_code').textContent"),
      "mascot_check_character(jsonlite::read_json(",
      fixed = TRUE
    )
    expect_match(
      app$get_js("document.getElementById('your_character_code').textContent"),
      "mascot_check_character(paste(readLines(",
      fixed = TRUE
    )
    app$set_inputs(your_character_mood = "worried", your_character_size = 96, your_character_mode = "dark")
    app$wait_for_js("document.querySelectorAll('#your_character_grid .mascot').length === 8")
    expect_identical(app$get_js("document.querySelector('#your_character_grid .mascot').dataset.mood"), "worried")
    expect_identical(
      app$get_js("getComputedStyle(document.querySelector('#your_character_grid [data-bs-theme=light]')).display"),
      "none"
    )
    app$click(selector = 'details:has(#your_character_example) [data-event=select_function][data-value=mascot_preview]')
    app$wait_for_js(
      "document.querySelector('#preview_frame iframe')?.contentDocument?.querySelector('h1')?.textContent.includes('Study Bot')"
    )
    expect_identical(
      app$get_js("document.querySelector('#preview_frame iframe').contentDocument.querySelectorAll('.mascot').length"),
      40L
    )
    app$set_inputs(preview_mood = "happy", preview_size = 96)
    app$wait_for_js(
      "document.querySelector('#preview_frame iframe')?.contentDocument?.querySelector('.mascot')?.dataset.mood === 'happy'"
    )
    expect_match(
      app$get_js("document.getElementById('code_preview').textContent"),
      'mascot_read_character("study_bot.json")',
      fixed = TRUE
    )
    app$set_inputs(your_character_gesture = "greet")
    app$click("your_character_play")
    file <- file.path(withr::local_tempdir(), "broken.json")
    writeLines('{"format_version":99}', file)
    app$upload_file(your_character_file = file)
    app$wait_for_js("document.getElementById('your_character_check').textContent.includes('$.format_version')")
    expect_match(
      app$get_js("document.getElementById('your_character_check').textContent"),
      "supported character-format version",
      fixed = TRUE
    )
    expect_length(app$get_js("Array.from(document.querySelectorAll('#your_character_grid .mascot'))"), 0)
  })
})
