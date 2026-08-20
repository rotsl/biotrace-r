# CLI tests. We invoke the dispatcher (biotrace:::biotrace_cli) directly
# rather than spawning Rscript, so we can capture output and exit codes
# deterministically. The test-installed-CLI behaviour is covered by a
# separate integration test that uses Rscript against the installed
# package (see test-cli-installed.R).

test_that("--help prints usage and exits 0", {
  out <- capture.output(code <- biotrace:::biotrace_cli("--help"))
  expect_equal(code, 0L)
  expect_true(any(grepl("biotrace", out, fixed = TRUE)))
  expect_true(any(grepl("init", out, fixed = TRUE)))
  expect_true(any(grepl("config", out, fixed = TRUE)))
  expect_true(any(grepl("report", out, fixed = TRUE)))
  expect_true(any(grepl("github", out, fixed = TRUE)))
})

test_that("--version prints the package version", {
  out <- capture.output(code <- biotrace:::biotrace_cli("--version"))
  expect_equal(code, 0L)
  expect_true(any(grepl("^biotrace ", out)))
  expect_true(any(grepl("upstream BioTrace action", out)))
})

test_that("init writes both files in a temp project", {
  dir <- withr::local_tempdir()
  code <- biotrace:::biotrace_cli(c("init", "--project", dir))
  expect_equal(code, 0L)
  expect_true(file.exists(file.path(dir, ".github", "biotrace.yml")))
  expect_true(file.exists(file.path(dir, ".github", "workflows", "biotrace.yml")))
})

test_that("init refuses to overwrite without --force", {
  dir <- withr::local_tempdir()
  biotrace:::biotrace_cli(c("init", "--project", dir))
  code <- biotrace:::biotrace_cli(c("init", "--project", dir))
  expect_equal(code, 1L)
  # With --force it succeeds.
  code <- biotrace:::biotrace_cli(c("init", "--project", dir, "--force"))
  expect_equal(code, 0L)
})

test_that("config print outputs version: 1", {
  out <- capture.output(code <- biotrace:::biotrace_cli(c("config", "print")))
  expect_equal(code, 0L)
  expect_true(any(grepl("version: 1", out, fixed = TRUE)))
})

test_that("config validate accepts a valid file", {
  path <- .write_minimal_config()
  out <- capture.output(code <- biotrace:::biotrace_cli(c("config", "validate", path)))
  expect_equal(code, 0L)
  expect_true(any(grepl("valid", out)))
})

test_that("config validate reports failure on an invalid file", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "bad.yml")
  writeLines(c("version: 2"), path)
  out <- capture.output(code <- biotrace:::biotrace_cli(c("config", "validate", path)))
  expect_equal(code, 1L)
  expect_true(any(grepl("invalid", out)))
})

test_that("workflow print outputs rotsl/biotrace@v1", {
  out <- capture.output(code <- biotrace:::biotrace_cli(c("workflow", "print")))
  expect_equal(code, 0L)
  expect_true(any(grepl("rotsl/biotrace@v1", out, fixed = TRUE)))
})

test_that("workflow write writes a valid file", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "wf.yml")
  out <- capture.output(
    code <- biotrace:::biotrace_cli(c("workflow", "write", "--path", path))
  )
  expect_equal(code, 0L)
  expect_true(file.exists(path))
  parsed <- yaml::read_yaml(path)
  expect_equal(parsed$jobs$biotrace$steps[[2L]]$uses, "rotsl/biotrace@v1")
})

test_that("report prints a summary for a valid fixture", {
  path <- .write_example_report()
  out <- capture.output(code <- biotrace:::biotrace_cli(c("report", path)))
  expect_equal(code, 0L)
  expect_true(any(grepl("BioTrace report", out)))
  expect_true(any(grepl("Reproducibility score", out)))
})

test_that("report errors when the file does not exist", {
  out <- capture.output(code <- biotrace:::biotrace_cli(c("report", "/no/such.json")))
  expect_equal(code, 1L)
})

test_that("report errors when the report is schema-invalid", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "bad.json")
  bad <- .example_report_list()
  bad$status <- "fatal"
  writeLines(jsonlite::toJSON(bad, auto_unbox = TRUE), path)
  out <- capture.output(code <- biotrace:::biotrace_cli(c("report", path)))
  expect_equal(code, 1L)
})

test_that("github run --dry-run prints the request", {
  withr::local_envvar(GITHUB_TOKEN = "fake")
  out <- capture.output(
    code <- biotrace:::biotrace_cli(c("github", "run",
                                      "--repo", "rotsl/biotrace-r",
                                      "--action", "trigger",
                                      "--dry-run"))
  )
  expect_equal(code, 0L)
  txt <- paste(out, collapse = "\n")
  expect_true(grepl("dispatches", txt, fixed = TRUE))
  expect_true(grepl("rotsl/biotrace-r", txt, fixed = TRUE))
})

test_that("github run errors without --repo", {
  out <- capture.output(
    code <- biotrace:::biotrace_cli(c("github", "run", "--dry-run"))
  )
  expect_equal(code, 1L)
})

test_that("github run --dry-run does not require a token", {
  withr::local_envvar(GITHUB_TOKEN = "", GH_TOKEN = "")
  out <- capture.output(
    code <- biotrace:::biotrace_cli(c("github", "run",
                                      "--repo", "rotsl/biotrace-r",
                                      "--action", "list-runs",
                                      "--dry-run"))
  )
  expect_equal(code, 0L)
})

test_that("an unknown subcommand exits with code 1", {
  out <- capture.output(code <- biotrace:::biotrace_cli(c("nope")))
  expect_equal(code, 1L)
})

test_that("no arguments prints help and exits 0", {
  out <- capture.output(code <- biotrace:::biotrace_cli(character(0)))
  expect_equal(code, 0L)
  expect_true(any(grepl("Usage", out)))
})
