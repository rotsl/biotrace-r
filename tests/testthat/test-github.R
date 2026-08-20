test_that("run_biotrace_github triggers a workflow_dispatch when dry_run", {
  res <- run_biotrace_github("rotsl/biotrace-r",
                             action = "trigger",
                             token = "fake-token",
                             dry_run = TRUE)
  expect_true(isTRUE(res$dry_run))
  req <- res$request
  expect_equal(req$method, "POST")
  expect_match(req$url, "/actions/workflows/biotrace.yml/dispatches$")
  expect_match(req$headers[["Authorization"]], "^Bearer fake-token$")
  expect_equal(req$body$ref, "main")
})

test_that("run_biotrace_github builds GET URL for list-runs", {
  res <- run_biotrace_github("rotsl/biotrace-r",
                             action = "list-runs",
                             token = "fake-token",
                             dry_run = TRUE)
  expect_equal(res$request$method, "GET")
  expect_match(res$request$url,
               "/repos/rotsl/biotrace-r/actions/workflows/biotrace.yml/runs$")
})

test_that("run_biotrace_github builds GET URL for list-workflows", {
  res <- run_biotrace_github("rotsl/biotrace-r",
                             action = "list-workflows",
                             token = "fake-token",
                             dry_run = TRUE)
  expect_equal(res$request$method, "GET")
  expect_match(res$request$url, "/repos/rotsl/biotrace-r/actions/workflows$")
})

test_that("run_biotrace_github aborts when no token is available", {
  withr::local_envvar(GITHUB_TOKEN = "", GH_TOKEN = "")
  # Use a mock transport so we never reach the network: we want to
  # verify that token resolution aborts before the transport is
  # called. dry_run = FALSE so the token check is enforced.
  mock <- .mock_transport(list())
  expect_error(run_biotrace_github("rotsl/biotrace-r",
                                   action = "trigger",
                                   transport = mock),
               class = "biotrace_token_missing")
})

test_that("run_biotrace_github reads token from a custom env var", {
  withr::local_envvar(GITHUB_TOKEN = "", GH_TOKEN = "",
                      BIOTRACE_TOKEN = "from-env")
  res <- run_biotrace_github("rotsl/biotrace-r",
                             action = "trigger",
                             token_env = "BIOTRACE_TOKEN",
                             dry_run = TRUE)
  expect_match(res$request$headers[["Authorization"]],
               "^Bearer from-env$")
})

test_that("run_biotrace_github falls back to GH_TOKEN", {
  withr::local_envvar(GITHUB_TOKEN = "", GH_TOKEN = "gh-cli-token")
  res <- run_biotrace_github("rotsl/biotrace-r",
                             action = "trigger",
                             dry_run = TRUE)
  expect_match(res$request$headers[["Authorization"]],
               "^Bearer gh-cli-token$")
})

test_that("run_biotrace_github uses the mock transport", {
  mock <- .mock_transport(list(
    trigger = list(status = 204L, headers = character(0), content = raw(0))
  ))
  res <- run_biotrace_github("rotsl/biotrace-r",
                             action = "trigger",
                             token = "fake",
                             transport = mock)
  expect_equal(res$response, NULL) # 204 with empty body
})

test_that("run_biotrace_github surfaces a mock transport failure", {
  mock <- function(req) {
    list(status = 403L, headers = character(0),
         content = charToRaw("{\"message\":\"Forbidden\"}"))
  }
  expect_error(run_biotrace_github("rotsl/biotrace-r",
                                   action = "trigger",
                                   token = "fake",
                                   transport = mock),
               class = "biotrace_github_request_failed")
})

test_that("run_biotrace_github rejects a malformed repo slug", {
  expect_error(run_biotrace_github("not-a-slug",
                                   action = "trigger",
                                   token = "fake",
                                   dry_run = TRUE),
               class = "biotrace_repo_arg")
})

test_that("run_biotrace_github can target a custom workflow_name", {
  res <- run_biotrace_github("rotsl/biotrace-r",
                             action = "trigger",
                             workflow_name = "biotrace-dev.yml",
                             token = "fake",
                             dry_run = TRUE)
  expect_match(res$request$url, "biotrace-dev.yml/dispatches$")
})

test_that("run_biotrace_github uses a custom ref when provided", {
  res <- run_biotrace_github("rotsl/biotrace-r",
                             action = "trigger",
                             ref = "feature/foo",
                             token = "fake",
                             dry_run = TRUE)
  expect_equal(res$request$body$ref, "feature/foo")
})

test_that("run_biotrace_github never writes the token to disk", {
  dir <- withr::local_tempdir()
  withr::local_dir(dir)
  res <- run_biotrace_github("rotsl/biotrace-r",
                             action = "trigger",
                             token = "SECRET-VALUE-DO-NOT-LEAK",
                             dry_run = TRUE)
  files <- list.files(dir, recursive = TRUE, all.files = TRUE)
  for (f in files) {
    txt <- tryCatch(readLines(file.path(dir, f), warn = FALSE),
                    error = function(e) character(0))
    expect_false(any(grepl("SECRET-VALUE-DO-NOT-LEAK", txt, fixed = TRUE)))
  }
})

test_that("run_biotrace_github sets the GitHub API version header", {
  res <- run_biotrace_github("rotsl/biotrace-r",
                             action = "trigger",
                             token = "fake",
                             dry_run = TRUE)
  expect_equal(res$request$headers[["X-GitHub-Api-Version"]], "2022-11-28")
  expect_equal(res$request$headers[["Accept"]], "application/vnd.github+json")
})
