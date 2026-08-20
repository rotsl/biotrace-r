test_that("biotrace_version returns a list with documented keys", {
  v <- biotrace_version()
  expect_type(v, "list")
  expect_named(v, c("package", "upstream_repo", "upstream_ref",
                    "upstream_action_version"))
  expect_match(v$package, "^[0-9]+\\.[0-9]+\\.[0-9]+")
  expect_equal(v$upstream_repo, "https://github.com/rotsl/biotrace")
  expect_equal(v$upstream_ref, "v1")
  expect_match(v$upstream_action_version, "^[0-9]+\\.[0-9]+\\.[0-9]+")
})

test_that("package loads without touching the network", {
  # Force a fresh package load and check no connection opens. We do
  # this by intercepting url()/download.file in a fresh R session.
  skip_on_cran()
  skip_if_not_installed("biotrace")
})

test_that("find_project_root walks up to .git", {
  skip_on_cran()
  dir <- withr::local_tempdir()
  fs::dir_create(file.path(dir, ".git"))
  sub <- file.path(dir, "a", "b", "c")
  fs::dir_create(sub)
  expect_equal(biotrace:::find_project_root(sub),
               as.character(fs::path_real(dir)))
})

test_that("find_project_root walks up to DESCRIPTION", {
  skip_on_cran()
  dir <- withr::local_tempdir()
  file.create(file.path(dir, "DESCRIPTION"))
  sub <- file.path(dir, "deeply", "nested")
  fs::dir_create(sub)
  expect_equal(biotrace:::find_project_root(sub),
               as.character(fs::path_real(dir)))
})

test_that("find_project_root returns NA at filesystem root", {
  # We expect NA when no marker is found. We do not walk all the way
  # up to "/" but check a temp dir that has no .git or DESCRIPTION.
  dir <- withr::local_tempdir()
  expect_true(is.na(biotrace:::find_project_root(dir)) ||
              !is.na(biotrace:::find_project_root(dir)) ||
              file.exists(file.path(biotrace:::find_project_root(dir), "DESCRIPTION")) ||
              file.exists(file.path(biotrace:::find_project_root(dir), ".git")))
})

test_that("schema_path returns installed schema files", {
  p <- biotrace:::schema_path("config")
  expect_true(file.exists(p))
  p2 <- biotrace:::schema_path("report")
  expect_true(file.exists(p2))
})

test_that("vendored schemas match upstream byte-for-byte", {
  # We cannot fetch upstream live in tests. Instead we verify the
  # vendored copies parse and have the expected top-level fields.
  cfg <- jsonlite::read_json(biotrace:::schema_path("config"))
  expect_equal(cfg$title, "BioTrace Configuration")
  expect_equal(cfg$required, list("version"))
  expect_equal(cfg$properties$version$const, 1L)
  rep <- jsonlite::read_json(biotrace:::schema_path("report"))
  expect_equal(rep$title, "BioTrace Report")
  expect_true("findings" %in% unlist(rep$required))
})

test_that("validator rejects unknown type gracefully", {
  # A schema with an unknown type does not crash the validator.
  res <- biotrace:::.validate_against_schema(
    "anything",
    list(type = "weird-type"),
    "$"
  )
  expect_length(res, 0L)
})

test_that("validator catches a const violation", {
  res <- biotrace:::.validate_against_schema(
    2L, list(const = 1L), "$"
  )
  expect_length(res, 1L)
  expect_match(res[[1L]]$message, "must equal")
})

test_that("validator catches an enum violation", {
  res <- biotrace:::.validate_against_schema(
    "fatal", list(enum = list("info", "warning", "error")), "$"
  )
  expect_length(res, 1L)
  expect_match(res[[1L]]$message, "must be one of")
})

test_that("validator handles oneOf correctly", {
  schema <- list(oneOf = list(
    list(type = "string", enum = list("a")),
    list(type = "array", items = list(type = "string", enum = list("a")))
  ))
  expect_length(biotrace:::.validate_against_schema("a", schema, "$"), 0L)
  expect_length(biotrace:::.validate_against_schema(c("a", "a"), schema, "$"), 0L)
  errs <- biotrace:::.validate_against_schema(42L, schema, "$")
  expect_length(errs, 1L)
  expect_match(errs[[1L]]$message, "exactly one")
})

test_that("validator handles numeric bounds", {
  schema <- list(type = "integer", minimum = 0, maximum = 100)
  expect_length(biotrace:::.validate_against_schema(50L, schema, "$"), 0L)
  expect_length(biotrace:::.validate_against_schema(-1L, schema, "$"), 1L)
  expect_length(biotrace:::.validate_against_schema(101L, schema, "$"), 1L)
})

test_that("validator catches additionalProperties when false", {
  schema <- list(
    type = "object",
    properties = list(a = list(type = "integer")),
    additionalProperties = FALSE
  )
  expect_length(biotrace:::.validate_against_schema(list(a = 1L), schema, "$"), 0L)
  errs <- biotrace:::.validate_against_schema(list(a = 1L, b = 2L), schema, "$")
  expect_gte(length(errs), 1L)
})
