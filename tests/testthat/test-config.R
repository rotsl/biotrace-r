test_that("default_biotrace_config returns a valid minimal config", {
  cfg <- default_biotrace_config()
  expect_type(cfg, "list")
  expect_equal(cfg$version, 1L)
  errs <- biotrace:::.biotrace_validate(cfg, "config", "$", return_errors = TRUE)
  expect_length(errs, 0L)
})

test_that("default_biotrace_config_text is a YAML string with version: 1", {
  txt <- default_biotrace_config_text()
  expect_type(txt, "character")
  expect_match(txt, "version: 1", fixed = TRUE)
  parsed <- yaml::yaml.load(txt)
  expect_equal(parsed$version, 1L)
})

test_that("write_biotrace_config creates the parent dir and writes valid YAML", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "nested", "biotrace.yml")
  out <- write_biotrace_config(path)
  expect_true(file.exists(path))
  expect_equal(out, normalizePath(path, mustWork = FALSE))
  parsed <- yaml::read_yaml(path)
  expect_equal(parsed$version, 1L)
  expect_length(biotrace:::.biotrace_validate(parsed, "config", "$",
                                              return_errors = TRUE), 0L)
})

test_that("write_biotrace_config refuses to overwrite by default", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "biotrace.yml")
  write_biotrace_config(path)
  expect_error(write_biotrace_config(path), class = "biotrace_refuse_overwrite")
  # overwrite = TRUE works.
  write_biotrace_config(path, overwrite = TRUE)
  expect_true(file.exists(path))
})

test_that("write_biotrace_config rejects an invalid config", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "biotrace.yml")
  bad <- list(version = 2L)  # const 1
  expect_error(write_biotrace_config(path, config = bad),
               class = "biotrace_invalid_config")
  expect_false(file.exists(path))
})

test_that("write_biotrace_config accepts the example fixture shape", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "biotrace.yml")
  example <- read_biotrace_config(
    system.file("extdata", "example-biotrace.yml", package = "biotrace")
  )
  write_biotrace_config(path, config = example)
  expect_true(file.exists(path))
})

test_that("read_biotrace_config reads a minimal config", {
  path <- .write_minimal_config()
  cfg <- read_biotrace_config(path)
  expect_equal(cfg$version, 1L)
})

test_that("read_biotrace_config errors on a missing file", {
  expect_error(read_biotrace_config("/no/such/file.yml"),
               class = "biotrace_file_missing")
})

test_that("read_biotrace_config errors on broken YAML", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "broken.yml")
  writeLines(c("version: 1", "  - bad: indent: here"), path)
  expect_error(read_biotrace_config(path), class = "biotrace_yaml_parse_error")
})

test_that("validate_biotrace_config returns TRUE for a valid file", {
  path <- .write_minimal_config()
  expect_invisible(validate_biotrace_config(path))
})

test_that("validate_biotrace_config returns errors with return_errors=TRUE", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "bad.yml")
  writeLines(c("version: 2"), path)
  errs <- validate_biotrace_config(path, return_errors = TRUE)
  expect_gt(length(errs), 0L)
  expect_true(any(grepl("version", vapply(errs, function(e) e$path, character(1)),
                        fixed = TRUE)))
})

test_that("validate_biotrace_config throws on invalid file by default", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "bad.yml")
  writeLines(c("version: 2"), path)
  expect_error(validate_biotrace_config(path), class = "biotrace_invalid_config")
})

test_that("validate_biotrace_config flags missing required version", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "noversion.yml")
  writeLines(c("repository:", "  languages: [R]"), path)
  errs <- validate_biotrace_config(path, return_errors = TRUE)
  paths <- vapply(errs, function(e) e$path, character(1))
  expect_true(any(grepl("version", paths, fixed = TRUE)))
})

test_that("validate_biotrace_config flags unknown severity enum", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "bad-sev.yml")
  yaml::write_yaml(list(
    version = 1L,
    lineage = list(list(
      id = "x", inputs = list("a"), code = list("b"), outputs = list("c"),
      stale_output_severity = "fatal"
    ))
  ), path)
  errs <- validate_biotrace_config(path, return_errors = TRUE)
  expect_gt(length(errs), 0L)
  paths <- vapply(errs, function(e) e$path, character(1))
  expect_true(any(grepl("stale_output_severity", paths, fixed = TRUE)))
})

test_that("validate_biotrace_config accepts the example fixture", {
  path <- system.file("extdata", "example-biotrace.yml", package = "biotrace")
  expect_invisible(validate_biotrace_config(path))
})
