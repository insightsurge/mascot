# Skips the whole file on CRAN and in R CMD check, unless the extended tests are on (helper-extended.R): four full
# checks take seconds, which is what storing them saves.
skip_unless_extended()

describe("the checked built-in characters in R/sysdata.rda", {
  it("match a fresh check of each shipped file (run tools/build-sysdata.R after editing one)", {
    for (id in builtin_characters()$id) {
      path <- system.file("format", "characters", paste0(id, ".json"), package = "mascot", mustWork = TRUE)
      stored <- character_catalogue_builtin(id)
      fresh <- character_format_check(path, from = "file", builtin = TRUE)
      without_manifest <- function(x) structure(x, mascot_manifest = NULL)
      expect_identical(without_manifest(stored), without_manifest(fresh), info = id)
      manifest <- attr(stored, "mascot_manifest")
      expected <- attr(fresh, "mascot_manifest")
      expect_setequal(names(manifest), names(expected))
      exact <- setdiff(names(expected), c("fit", "contrast"))
      expect_identical(manifest[exact], expected[exact], info = id)
      # Fit bounds and contrast ratios come from sin(), cos() and powers, whose last bit can differ between
      # platforms; they are only compared against limits with far wider margins.
      expect_equal(manifest[c("fit", "contrast")], expected[c("fit", "contrast")], tolerance = 1e-12, info = id)
    }
  })
})
