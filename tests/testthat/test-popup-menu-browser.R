# Skips the whole file on CRAN or without Chrome, before any of its code runs.
skip_without_chrome()

describe("popup menu input contract", {
  it("toggles by pointer and keyboard without clicks and sends each item choice", {
    js <- local_runtime_page(
      tags = list(mascot("helper", placement = "inline", motion = FALSE, click = mascot_popup_menu(c(help = "Help")))),
      shiny_stub = TRUE
    )
    result <- js(
      "(() => {
      const el = document.getElementById('helper'), button = el.querySelector('.mascot-menu-toggle');
      button.click();
      const pointerOpened = mascot.host.state(el).menuOpen;
      button.click();
      const pointerClosed = !mascot.host.state(el).menuOpen;
      const key = (type, repeat = false) => button.dispatchEvent(new KeyboardEvent(type,
        {key: 'Enter', bubbles: true, cancelable: true, repeat}));
      key('keydown'); key('keydown', true); key('keyup');
      const keyboardOpened = mascot.host.state(el).menuOpen;
      el.querySelector('[role=menuitem]').click();
      button.click(); el.querySelector('[role=menuitem]').click();
      key('keydown'); key('keyup'); key('keydown'); key('keyup');
      return {pointerOpened, pointerClosed, keyboardOpened, closed: !mascot.host.state(el).menuOpen,
        clicks: menuEvents.filter(e => e[0] === 'helper_click'),
        choices: menuEvents.filter(e => e[0] === 'helper_menu')};
    })()"
    )
    expect_true(result$pointerOpened)
    expect_true(result$pointerClosed)
    expect_true(result$keyboardOpened)
    expect_true(result$closed)
    expect_identical(result$clicks, list())
    expect_identical(result$choices, rep(list(list("helper_menu", "help", list(priority = "event"))), 2))
  })
})
