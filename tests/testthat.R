# This file is part of the standard setup for testthat, with one addition: a cap on the test workers.
#
# Where should you do additional testing?
# Learn more about the roles of various files in:
# * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
# * https://testthat.r-lib.org/articles/special-files.html

library(testthat)
library(mascot)

# The tests run in parallel (Config/testthat/parallel), and CRAN allows at most two cores. testthat takes its number of
# workers from getOption("Ncpus") first, so a session that has it above two (set for installing packages, say) is
# lowered to two while the tests run, and restored afterwards. R CMD check runs this file with --vanilla, so no profile
# sets the option there; when it is unset, testthat's own choice stands (TESTTHAT_CPUS, else two).
local({
  ncpus <- suppressWarnings(as.integer(getOption("Ncpus")))
  if (length(ncpus) == 1L && !is.na(ncpus) && ncpus > 2L) {
    old <- options(Ncpus = 2L)
    on.exit(options(old))
  }
  test_check("mascot")
})
