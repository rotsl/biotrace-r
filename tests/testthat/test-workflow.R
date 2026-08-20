test_that("biotrace_workflow_text references rotsl/biotrace@v1", {
  txt <- biotrace_workflow_text()
  expect_true(any(grepl("uses: rotsl/biotrace@v1", txt, fixed = TRUE)))
  expect_false(any(grepl("uses: ./", txt, fixed = TRUE)))
})

test_that("biotrace_workflow_text produces valid YAML", {
  txt <- biotrace_workflow_text()
  parsed <- yaml::yaml.load(paste(txt, collapse = "\n"))
  expect_type(parsed, "list")
  expect_equal(parsed$jobs$biotrace$steps[[2L]]$uses, "rotsl/biotrace@v1")
})

test_that("write_biotrace_workflow writes a parseable workflow", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, ".github", "workflows", "biotrace.yml")
  out <- write_biotrace_workflow(path)
  expect_true(file.exists(path))
  parsed <- yaml::read_yaml(path)
  expect_equal(parsed$name, "BioTrace")
  expect_equal(parsed$jobs$biotrace$steps[[2L]]$uses, "rotsl/biotrace@v1")
  expect_equal(parsed$jobs$biotrace$steps[[2L]]$with$config,
               ".github/biotrace.yml")
  expect_equal(parsed$jobs$biotrace$steps[[2L]]$with$`fail-on`, "error")
  expect_equal(parsed$jobs$biotrace$steps[[2L]]$with$`ai-enabled`, "false")
})

test_that("write_biotrace_workflow can add workflow_dispatch", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "wf.yml")
  write_biotrace_workflow(path, include_workflow_dispatch = TRUE)
  txt <- paste(readLines(path), collapse = "\n")
  parsed <- yaml::yaml.load(txt)
  # The yaml package interprets the unquoted `on:` key as the YAML 1.1
  # boolean TRUE. GitHub Actions itself parses `on:` correctly, so we
  # keep the unquoted form to match upstream style. Here we look up the
  # event map by the parsed key (which is the literal "TRUE") rather
  # than by position, since name comes first.
  on_map <- parsed[["TRUE"]] %||% parsed[["on"]]
  expect_true("workflow_dispatch" %in% names(on_map))
  # And the raw text must contain the trigger literal, regardless of
  # how a downstream YAML parser chooses to spell the key.
  expect_true(grepl("workflow_dispatch:", txt, fixed = TRUE))
})

test_that("write_biotrace_workflow passes extra inputs through", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "wf.yml")
  write_biotrace_workflow(path,
                          extra_inputs = list(`create-labels` = "false",
                                              `comment-mode` = "create-new"))
  parsed <- yaml::read_yaml(path)
  with_inputs <- parsed$jobs$biotrace$steps[[2L]]$with
  expect_equal(with_inputs$`create-labels`, "false")
  expect_equal(with_inputs$`comment-mode`, "create-new")
})

test_that("write_biotrace_workflow refuses to overwrite by default", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "wf.yml")
  write_biotrace_workflow(path)
  expect_error(write_biotrace_workflow(path), class = "biotrace_refuse_overwrite")
})

test_that("write_biotrace_workflow rejects invalid fail_on", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "wf.yml")
  expect_error(write_biotrace_workflow(path, fail_on = "fatal"),
               class = "biotrace_error")
})

test_that("use_biotrace writes both files", {
  dir <- withr::local_tempdir()
  result <- use_biotrace(project = dir)
  expect_true(file.exists(result$config))
  expect_true(file.exists(result$workflow))
  cfg <- yaml::read_yaml(result$config)
  expect_equal(cfg$version, 1L)
  wf <- yaml::read_yaml(result$workflow)
  expect_equal(wf$jobs$biotrace$steps[[2L]]$uses, "rotsl/biotrace@v1")
  expect_equal(wf$jobs$biotrace$steps[[2L]]$with$config,
               ".github/biotrace.yml")
})

test_that("use_biotrace refuses to overwrite without overwrite = TRUE", {
  dir <- withr::local_tempdir()
  use_biotrace(project = dir)
  expect_error(use_biotrace(project = dir), class = "biotrace_refuse_overwrite")
  use_biotrace(project = dir, overwrite = TRUE)
})

test_that("use_biotrace errors when project dir does not exist", {
  expect_error(use_biotrace(project = "/no/such/dir"),
               class = "biotrace_dir_missing")
})

test_that("workflow text is deterministic for the same arguments", {
  a <- biotrace_workflow_text()
  b <- biotrace_workflow_text()
  expect_identical(a, b)
})

test_that("workflow text does not include hardcoded secrets", {
  txt <- biotrace_workflow_text()
  expect_false(any(grepl("ghp_", txt)))
  expect_false(any(grepl("github_pat_", txt)))
  expect_true(any(grepl("github.token", txt, fixed = TRUE)))
})

test_that("workflow includes required permissions", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "wf.yml")
  write_biotrace_workflow(path)
  parsed <- yaml::read_yaml(path)
  perms <- parsed$permissions
  expect_equal(perms$contents, "read")
  expect_equal(perms$`pull-requests`, "write")
  expect_equal(perms$issues, "write")
  expect_equal(perms$checks, "write")
})

test_that("workflow upload-artifact step uses the report-path output", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "wf.yml")
  write_biotrace_workflow(path)
  txt <- paste(readLines(path), collapse = "\n")
  expect_true(grepl("steps.biotrace.outputs.report-path", txt, fixed = TRUE))
})

test_that("workflow can disable report upload", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "wf.yml")
  write_biotrace_workflow(path, upload_report = FALSE)
  parsed <- yaml::read_yaml(path)
  # Two steps only: checkout + biotrace (no upload step).
  expect_length(parsed$jobs$biotrace$steps, 2L)
})
