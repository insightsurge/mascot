stress_checks <- function(ctx) {
  checkmate::assert_list(ctx, names = "unique")
  app <- ctx$app
  mode <- function(id) {
    checkmate::assert_string(id)
    sprintf("window.mascot.host.state(document.getElementById('%s')).mode", id)
  }
  body <- function(id) {
    checkmate::assert_string(id)
    app$get_js(sprintf("window.mascot.host.state(document.getElementById('%s')).colours.body", id))
  }
  ctx$check("auto theme follows the page into dark and back", {
    app$wait_for_js(paste(mode("follows"), "=== 'light'"))
    stopifnot(identical(toupper(body("follows")), "#F2C14E"))
    app$click("dark")
    app$wait_for_js("document.documentElement.getAttribute('data-bs-theme') === 'dark'")
    app$wait_for_js(paste(mode("follows"), "=== 'dark'"))
    stopifnot(identical(toupper(body("follows")), "#3A6EA5"))
    app$click("light")
    app$wait_for_js(paste(mode("follows"), "=== 'light'"))
    stopifnot(identical(toupper(body("follows")), "#F2C14E"))
  })
  ctx$check("a fixed light theme ignores the page", {
    app$click("dark")
    app$wait_for_js(paste(mode("follows"), "=== 'dark'"))
    stopifnot(identical(app$get_js(mode("fixed")), "light"))
  })
  ctx$check("updates apply in dark mode", {
    app$click("change")
    ctx$state("follows", "happy", "Update 1")
    stopifnot(identical(app$get_js(mode("follows")), "dark"))
  })
}
