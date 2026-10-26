# This file is part of the standard setup for testthat, with one addition: a cap on the test workers.
#
# Where should you do additional testing?
# Learn more about the roles of various files in:
# * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
# * https://testthat.r-lib.org/articles/special-files.html

library(testthat)
library(mascot)

# The tests run in parallel (Config/testthat/parallel), and CRAN allows at most two cores. testthat takes its number of
# workers from getOption("Ncpus") first, which a machine's profile may set higher for installing packages, so the
# option is capped at two (a setting of 1 is kept) while the tests run, and restored afterwards.
local({
  ncpus <- suppressWarnings(as.integer(getOption("Ncpus", 2L)))
  old <- options(Ncpus = if (length(ncpus) == 1L && !is.na(ncpus) && ncpus >= 1L) min(ncpus, 2L) else 2L)
  on.exit(options(old))
  test_check("mascot")
})
