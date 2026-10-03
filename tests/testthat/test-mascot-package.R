describe("the mascot package", {
  it("names Harsh Verma as author, maintainer and copyright holder", {
    # Given the installed package's metadata
    authors <- eval(parse(
      text = utils::packageDescription("mascot")[["Authors@R"]]
    ))

    # When we look for Harsh Verma
    harsh <- authors[authors$given == "Harsh" & authors$family == "Verma"]

    # Then there is exactly one entry, with all three roles
    expect_length(harsh, 1)
    expect_setequal(harsh$role, c("aut", "cre", "cph"))
    expect_identical(harsh$email, "analyticswithharsh@gmail.com")
  })

  it("is MIT licensed", {
    # Given / When
    licence <- utils::packageDescription("mascot")[["License"]]

    # Then
    expect_identical(licence, "MIT + file LICENSE")
  })

  it("carries a release version (x.y.z) or a development version (x.y.z.9000, .9001, ...)", {
    # Given / When
    version <- as.character(utils::packageVersion("mascot"))

    # Then
    expect_match(version, "^[0-9]+\\.[0-9]+\\.[0-9]+(\\.9[0-9]{3})?$")
  })
})
