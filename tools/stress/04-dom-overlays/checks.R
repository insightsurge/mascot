stress_checks <- function(ctx) {
  checkmate::assert_list(ctx, names = "unique")
  app <- ctx$app
  state <- ctx$state
  ctx$check("DOM churn and custom input binding", {
    app$click("chaos")
    app$wait_for_js("window.stressMutationsDone && document.querySelectorAll('#noise span').length === 201")
    app$wait_for_js("Shiny.shinyapp.$inputValues.custom === '200'")
    stopifnot(identical(app$get_value(input = "custom"), "200"))
    app$click("change")
    state("helper", "happy", "Update 1")
    stopifnot(isTRUE(app$get_js(paste0(
      "(() => {const c=document.querySelector('#helper canvas');",
      "return c.width>0 && c.height>0 && ",
      "c.getContext('2d').getImageData(0,0,c.width,c.height).data.some(v=>v>0);})()"
    ))))
  })
  ctx$check("menu reachable above fixed overlay", {
    app$run_js("document.querySelector('#helper .mascot-button').click()")
    app$wait_for_js("window.mascot.host.state(document.getElementById('helper')).menuOpen")
    stopifnot(isTRUE(app$get_js(paste0(
      "(() => {const e=document.querySelector('[role=menuitem]');",
      "if(!e)return false; const r=e.getBoundingClientRect();",
      "return e.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2));})()"
    ))))
  })
  ctx$check("progress and modal updates", {
    app$click("progress")
    state("helper", "thinking", "Progress")
    app$click("modal")
    app$wait_for_js("!!document.querySelector('.modal.show')")
    app$click("change")
    state("helper", "happy", "Update 2")
  })
  app$get_screenshot(file = file.path(ctx$scratch, "overlays.png"))
}
