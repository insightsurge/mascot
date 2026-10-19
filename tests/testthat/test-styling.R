describe("public CSS styling hooks", {
  it("documents every public property used by the engine, leaving defaults private", {
    rd <- unlist(local_help_page("mascot_styling"))
    public <- unique(unlist(regmatches(rd, gregexpr("--mascot-[[:alnum:]_-]+", rd))))
    files <- list.files(system.file("www", package = "mascot"), full.names = TRUE)
    source <- unlist(lapply(files, readLines))
    used <- unique(unlist(regmatches(source, gregexpr("--mascot-[[:alnum:]_-]+", source))))
    # Dynamic source copies must also name only documented properties.
    host <- readLines(file.path(system.file("www", package = "mascot"), "mascot-host.js"))
    start <- which(grepl("const stylingHooks =", host, fixed = TRUE))
    end <- start + which(grepl("];", host[(start + 1L):length(host)], fixed = TRUE))[[1]]
    hooks <- paste(host[start:end], collapse = "\n")
    dynamic <- regmatches(hooks, gregexpr("'[a-z-]+'", hooks))[[1]]
    used <- unique(c(used, paste0("--mascot-", gsub("'", "", dynamic, fixed = TRUE))))
    expect_setequal(paste0("--mascot-", gsub("'", "", dynamic, fixed = TRUE)), public)
    expect_setequal(used, public)
    expect_length(public, 7L)
    expect_false(any(grepl("--mascot-[[:alnum:]_-]+\\s*:", source)))
    expect_true(all(vapply(
      c("mascot", "mascot-status", "mascot-bubble", "mascot-menu", "mascot-tooltip"),
      function(class) any(grepl(paste0(".", class), rd, fixed = TRUE)),
      logical(1)
    )))
  })

  it("keeps inherited and per-mascot colours above page copies through floating and updates", {
    skip_without_chrome()
    skip_if_not_installed("shinytest2")
    js <- local_host_page(
      bubble = mascot_bubble("Ready", duration = Inf),
      click = mascot_popup_menu(c(about = "About"), label = "Help"),
      shiny_menu = TRUE
    )
    js(
      "const el=document.getElementById('a'),box=document.createElement('div');
      el.before(box);box.append(el);box.dataset.bsTheme='dark';
      box.style.cssText='--bs-body-bg:#123456;--bs-body-color:#abcdef;--bs-border-color:#654321;';
      window.readPanels=()=>['bubble','menu','tooltip'].map(name=>{
        const panel=el.querySelector('.mascot-'+name),s=getComputedStyle(panel);
        return [s.backgroundColor,s.color,s.borderTopColor];});"
    )
    expect_identical(js("readPanels()[0]"), list("rgb(18, 52, 86)", "rgb(171, 205, 239)", "rgb(101, 67, 33)"))
    js(
      "box.style.cssText+='--mascot-panel-bg:#153448;--mascot-panel-color:#ffffff;--mascot-panel-border:#8fc7e8;'+
      '--mascot-restore-bg:#153448;--mascot-restore-fg:#ffffff;--mascot-restore-glow:#8fc7e8;';
      mascot.host.receive({id:'a',patch:{placement:{floating:true,position:'bottom-right',minimise:true,drag:false}}});"
    )
    result <- host_layout(js, "return readPanels();")
    expected <- list("rgb(21, 52, 72)", "rgb(255, 255, 255)", "rgb(143, 199, 232)")
    for (panel in result) {
      expect_identical(panel, expected)
    }
    expect_identical(
      js("getComputedStyle(el.querySelector('.mascot-bubble'),'::after').backgroundColor"),
      expected[[1]]
    )
    expect_identical(js("getComputedStyle(el.querySelector('.mascot-bubble-close')).borderTopColor"), expected[[3]])
    js(
      "const sheet=document.createElement('style');sheet.textContent='#a {--mascot-restore-bg:#204060;}';
      document.head.append(sheet);el.querySelector('.mascot-minimise').click();
      mascot.host.receive({id:'a',patch:{theme:{light:{body:'#abcdef'},dark:{body:'#123456'},mode:'auto',css:null,brand:null}}});
      el.querySelector('.mascot-restore').focus();"
    )
    result <- host_layout(
      js,
      "const s=getComputedStyle(el.querySelector('.mascot-restore'));
      return {bg:s.backgroundColor,fg:s.color,border:s.borderTopColor,outline:s.outlineColor,glow:s.boxShadow};"
    )
    expect_identical(result$bg, "rgb(32, 64, 96)")
    expect_identical(result$fg, expected[[2]])
    expect_identical(result$border, expected[[2]])
    expect_identical(result$outline, expected[[2]])
    expect_match(result$glow, expected[[3]], fixed = TRUE)
    js(
      "sheet.remove();box.style.cssText='--bs-body-bg:#ffffff;--bs-body-color:#212529;--bs-border-color:#dee2e6;';
      box.dataset.bsTheme='light';"
    )
    expect_identical(
      host_layout(js, "return readPanels()[0];"),
      list("rgb(255, 255, 255)", "rgb(33, 37, 41)", "rgb(222, 226, 230)")
    )
  })

  it("uses 1031 by default and applies a supplied floating stacking order", {
    skip_without_chrome()
    skip_if_not_installed("shinytest2")
    js <- local_host_page(placement = "bottom-right")
    expect_identical(js("getComputedStyle(document.getElementById('a')).zIndex"), "1031")
    js(
      "const style=document.createElement('style');style.textContent=':root {--mascot-z-index:1056;}';document.head.append(style);"
    )
    expect_identical(js("getComputedStyle(document.getElementById('a')).zIndex"), "1056")
    js(
      "style.remove();const el=document.getElementById('a');
      mascot.host.receive({id:'a',patch:{placement:{floating:false,position:'inline',minimise:false,drag:false}}});
      const container=document.createElement('div');el.before(container);container.append(el);
      container.style.setProperty('--mascot-z-index','1040');
      mascot.host.receive({id:'a',patch:{placement:{floating:true,position:'bottom-right',minimise:false,drag:false}}});"
    )
    expect_identical(host_layout(js, "return getComputedStyle(el).zIndex;"), "1040")
    js("el.style.setProperty('--mascot-z-index','1050');")
    expect_identical(js("getComputedStyle(el).zIndex"), "1050")
    js("el.style.removeProperty('--mascot-z-index');container.style.removeProperty('--mascot-z-index');")
    expect_identical(host_layout(js, "return getComputedStyle(el).zIndex;"), "1031")
  })

  it("lets root colours win in a real bslib app in light and dark mode", {
    local_shiny_browser()
    skip_if_not_installed("bslib")
    app <- app_driver(
      function() {
        library(mascot)
        shiny::shinyApp(
          bslib::page_fluid(
            theme = bslib::bs_theme(version = 5),
            mascot("styled", bubble = mascot_bubble("Ready", duration = Inf), motion = FALSE)
          ),
          function(input, output, session) {}
        )
      },
      name = "styling"
    )
    withr::defer(app$stop())
    app$wait_for_js("!!window.mascot?.host?.state(document.getElementById('styled'))")
    expect_true(app$get_js("getComputedStyle(document.body).getPropertyValue('--bs-body-bg').trim().length > 0"))
    app$run_js(
      "const css=document.createElement('style');css.textContent=':root {--mascot-panel-bg:#153448;--mascot-panel-color:#ffffff;--mascot-panel-border:#8fc7e8;}';document.head.append(css);"
    )
    for (mode in c("light", "dark")) {
      app$run_js(sprintf("document.documentElement.dataset.bsTheme='%s'", mode))
      app$wait_for_js(sprintf("mascot.host.state(document.getElementById('styled')).mode === '%s'", mode))
      expect_identical(
        app$get_js("getComputedStyle(document.querySelector('.mascot-bubble')).backgroundColor"),
        "rgb(21, 52, 72)"
      )
      expect_identical(
        app$get_js("getComputedStyle(document.querySelector('.mascot-bubble')).color"),
        "rgb(255, 255, 255)"
      )
      expect_identical(
        app$get_js("getComputedStyle(document.querySelector('.mascot-bubble')).borderTopColor"),
        "rgb(143, 199, 232)"
      )
    }
  })

  it("shows the styling help and honours panel colours in the studio in both modes", {
    local_shiny_browser()
    studio_frame <- "document.getElementById('live_frame').contentWindow"
    studio_live <- paste0(studio_frame, ".document.getElementById('helper')")
    skip_if_not_installed("bslib")
    app <- app_driver(
      function() {
        library(mascot)
        shiny::shinyAppDir(system.file("examples", "studio", package = "mascot"))
      },
      name = "studio-styling",
      width = 1400,
      height = 900
    )
    withr::defer(app$stop())
    app$wait_for_js(sprintf("!!%s?.mascot?.host?.state(%s)", studio_frame, studio_live))
    app$click(selector = "#all_functions")
    app$click(selector = '.pg-index-link[data-value="mascot_theme"]')
    app$wait_for_js("!document.querySelector('#studio_inspector [data-function=mascot_theme]').hidden")
    app$run_js(
      "const help=[...document.querySelectorAll('#studio_inspector details')].find(el=>
        el.querySelector('summary')?.textContent==='Styling panels and the restore button with CSS');
      help.open=true;window.stylingHelp=help;
      const css=document.createElement('style');css.textContent='#helper {--mascot-panel-bg:#153448;--mascot-panel-color:#ffffff;--mascot-panel-border:#8fc7e8;}';document.getElementById('live_frame').contentDocument.head.append(css);"
    )
    app$wait_for_js("stylingHelp.getClientRects().length > 0")
    expect_true(app$get_js(
      "document.querySelector('#studio_inspector [data-function=mascot_theme]').contains(stylingHelp)"
    ))
    expect_true(app$get_js(
      "stylingHelp.textContent.includes('--mascot-z-index') && stylingHelp.textContent.includes('.mascot-tooltip')"
    ))
    for (mode in c("light", "dark")) {
      app$run_js(sprintf("document.documentElement.dataset.bsTheme='%s'", mode))
      app$wait_for_js(sprintf("%s.mascot.host.state(%s).mode === '%s'", studio_frame, studio_live, mode))
      expect_identical(
        app$get_js(
          "(() => {const f=document.getElementById('live_frame').contentWindow;const s=f.getComputedStyle(f.document.querySelector('#helper .mascot-bubble'));return [s.backgroundColor,s.color,s.borderTopColor];})()"
        ),
        list("rgb(21, 52, 72)", "rgb(255, 255, 255)", "rgb(143, 199, 232)")
      )
    }
  })
})
