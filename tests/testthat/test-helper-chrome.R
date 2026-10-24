describe("app_driver()", {
  it("checks its arguments", {
    expect_error(app_driver(env = "x"), "env")
  })
})

describe("local_chrome_session()", {
  it("checks its arguments", {
    expect_error(local_chrome_session(env = "x"), "env")
  })
})

describe("chrome_close()", {
  it("checks its argument", {
    expect_error(chrome_close("x"), "browser")
  })
})

describe("wait_studio_js()", {
  it("checks its arguments", {
    expect_error(wait_studio_js("x", "true"), "app")
    app <- structure(new.env(), class = c("AppDriver", "R6"))
    expect_error(wait_studio_js(app, ""), "condition")
  })
})

describe("click_now()", {
  it("checks its arguments", {
    expect_error(click_now("x", "#go"), "app")
    app <- structure(new.env(), class = c("AppDriver", "R6"))
    expect_error(click_now(app, ""), "selector")
  })
})
