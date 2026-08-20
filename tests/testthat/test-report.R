test_that("read_biotrace_report reads the example fixture", {
  path <- system.file("extdata", "example-report.json", package = "biotrace")
  report <- read_biotrace_report(path)
  expect_s3_class(report, "biotrace_report")
  expect_equal(report$status, "warning")
  expect_equal(report$score$reproducibility, 82L)
})

test_that("read_biotrace_report errors on a missing file", {
  expect_error(read_biotrace_report("/no/such.json"),
               class = "biotrace_file_missing")
})

test_that("read_biotrace_report errors on malformed JSON", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "bad.json")
  writeLines(c("{not json}"), path)
  expect_error(read_biotrace_report(path), class = "biotrace_json_parse_error")
})

test_that("read_biotrace_report attaches the source path", {
  path <- .write_example_report()
  report <- read_biotrace_report(path)
  expect_equal(attr(report, "source"), normalizePath(path, mustWork = FALSE))
})

test_that("print.biotrace_report returns the report invisibly and prints a summary", {
  path <- .write_example_report()
  report <- read_biotrace_report(path)
  out <- capture.output(print(report))
  expect_true(any(grepl("BioTrace report", out)))
  expect_true(any(grepl("warning", out)))
  expect_true(any(grepl("Reproducibility score", out)))
  expect_true(any(grepl("Findings", out)))
})

test_that("summary.biotrace_report returns a list with the documented fields", {
  path <- .write_example_report()
  report <- read_biotrace_report(path)
  s <- summary(report)
  expect_type(s, "list")
  expect_equal(s$status, "warning")
  expect_equal(s$score, 82L)
  expect_equal(s$findings_count, 3L)
  expect_equal(s$blocking_findings_count, 0L)
  expect_equal(s$files_checked, 4L)
  expect_equal(s$claims_checked, 2L)
  expect_equal(s$figures_checked, 3L)
  expect_equal(s$findings_by_severity[["warning"]], 2L)
  expect_equal(s$findings_by_severity[["info"]], 1L)
  expect_equal(s$findings_by_severity[["error"]], 0L)
})

test_that("summary.biotrace_report handles a report with no findings", {
  rep <- .example_report_list()
  rep$findings <- list()
  rep$summary$findings <- 0L
  path <- file.path(withr::local_tempdir(), "no-findings.json")
  writeLines(jsonlite::toJSON(rep, auto_unbox = TRUE), path)
  s <- summary(read_biotrace_report(path))
  expect_equal(s$findings_count, 0L)
  expect_equal(s$findings_by_severity[["warning"]], 0L)
})

test_that("validate_biotrace_report returns TRUE for a valid fixture", {
  path <- .write_example_report()
  expect_invisible(validate_biotrace_report(path))
})

test_that("validate_biotrace_report throws on schema-invalid report", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "bad.json")
  bad <- .example_report_list()
  bad$schema_version <- "2.0"  # const 1.0
  writeLines(jsonlite::toJSON(bad, auto_unbox = TRUE), path)
  expect_error(validate_biotrace_report(path),
               class = "biotrace_invalid_report")
})

test_that("validate_biotrace_report returns errors with return_errors=TRUE", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "bad.json")
  bad <- .example_report_list()
  bad$status <- "fatal"
  writeLines(jsonlite::toJSON(bad, auto_unbox = TRUE), path)
  errs <- validate_biotrace_report(path, return_errors = TRUE)
  expect_gt(length(errs), 0L)
  paths <- vapply(errs, function(e) e$path, character(1))
  expect_true(any(grepl("status", paths, fixed = TRUE)))
})

test_that("validate_biotrace_report flags a missing required field", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "missing.json")
  bad <- .example_report_list()
  bad$findings <- NULL  # required field
  writeLines(jsonlite::toJSON(bad, auto_unbox = TRUE), path)
  errs <- validate_biotrace_report(path, return_errors = TRUE)
  paths <- vapply(errs, function(e) e$path, character(1))
  expect_true(any(grepl("findings", paths, fixed = TRUE)))
})

test_that("validate_biotrace_report flags a finding missing required keys", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "bad-finding.json")
  bad <- .example_report_list()
  bad$findings[[1L]] <- list(id = "x", module = "lineage")  # missing severity, title, message, deterministic
  writeLines(jsonlite::toJSON(bad, auto_unbox = TRUE), path)
  errs <- validate_biotrace_report(path, return_errors = TRUE)
  expect_gt(length(errs), 0L)
})

test_that("validate_biotrace_report accepts the shipped example fixture", {
  path <- system.file("extdata", "example-report.json", package = "biotrace")
  expect_invisible(validate_biotrace_report(path))
})
