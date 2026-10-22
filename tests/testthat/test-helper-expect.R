describe("expect_near()", {
  it("passes within the absolute distance and fails beyond it, naming both values", {
    expect_success(expect_near(9, 8, 1))
    expect_success(expect_near(c(7.5, 8.5), c(8, 8), 0.5))
    # A relative tolerance of 1 would accept 15 for 8; this check does not.
    expect_failure(expect_near(15, 8, 1), "is 15, not within 1 of 8")
    expect_failure(expect_near(-8, 8, 1))
  })
  it("checks its arguments", {
    expect_error(expect_near("8", 8, 1), "object")
    expect_error(expect_near(8, c(8, 9), 1), "expected")
    expect_error(expect_near(8, 8, -1), "within")
  })
})
