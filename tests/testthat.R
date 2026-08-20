# This file is required by testthat edition 3. It loads the package
# source once into a fresh environment and runs the tests under it.
#
# Tests are intentionally hermetic: no network access, no GitHub token,
# no writes outside `withr::local_tempdir()`.

library(testthat)
library(biotrace)

test_check("biotrace")
