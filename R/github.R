#' Trigger or inspect BioTrace via GitHub
#'
#' `run_biotrace_github()` provides an R-facing way to interact with a
#' GitHub repository that already uses the BioTrace workflow. It does
#' not embed the upstream BioTrace engine, and it does not modify
#' `rotsl/biotrace`.
#'
#' The function uses the GitHub REST API via `utils::download.file` for
#' the read-only parts (workflow listing, workflow runs, run
#' artifacts). For triggering (`workflow_dispatch`) it requires a token
#' with `repo` scope (or `public_repo` for public repositories).
#'
#' This helper is intentionally narrow: it does not attempt to
#' re-implement GitHub Actions, and it does not claim to execute
#' BioTrace locally. It is a convenience wrapper around the GitHub
#' REST API for the same workflow that `use_biotrace()` writes.
#'
#' @section Authentication:
#' Tokens are read from environment variables only. They are never
#' written to disk, never embedded into generated workflows, and
#' never printed. The lookup order is:
#'
#' 1. The `token` argument.
#' 2. The environment variable named by the `token_env` argument
#'    (default: `GITHUB_TOKEN`).
#' 3. The environment variable `GH_TOKEN` (a GitHub CLI convention).
#'
#' If none of those is set, the function aborts with a clear error
#' message. It does not silently degrade to unauthenticated access.
#'
#' @section Network behaviour:
#' All network access is opt-in. The function never touches the
#' network during package load, during `R CMD check`, or during any
#' of the local helpers. The unit tests use a mock transport (the
#' `transport` argument) so they run completely offline.
#'
#' @section Skip-on-CRAN:
#' Tests that exercise the live network path are tagged with
#' `skip_on_cran()`. The default behaviour when `transport` is `NULL`
#' and no token is present is to abort cleanly.
#'
#' @param repo `[character(1)]` Repository slug, in `owner/name` form
#'   (e.g. `"rotsl/biotrace-r"`).
#' @param action `[character(1)]` What to do. One of:
#'   - `"list-workflows"`: list workflow files in the repo.
#'   - `"list-runs"`: list recent runs of the BioTrace workflow.
#'   - `"trigger"`: dispatch the BioTrace workflow
#'     (`workflow_dispatch`). Requires `repo` scope.
#' @param workflow_name `[character(1)]` Workflow file name
#'   (e.g. `"biotrace.yml"`). Used for `list-runs` and `trigger`.
#' @param ref `[character(1)]` Git ref to dispatch the workflow on.
#'   Defaults to the repository's default branch when `NULL`.
#' @param token `[character(1)]` GitHub token. Leave NULL to read
#'   from environment variables (see "Authentication").
#' @param token_env `[character(1)]` Name of the environment variable
#'   holding the token. Defaults to `"GITHUB_TOKEN"`.
#' @param api_url `[character(1)]` GitHub API root. Defaults to
#'   `https://api.github.com`. Override for GitHub Enterprise.
#' @param transport `[function]` Custom HTTP transport for testing.
#'   Takes `(url, method, headers, body)` and returns a list with
#'   `status`, `headers`, `content` (raw). The default uses
#'   `utils::download.file` for GETs and `httr::POST`-equivalent logic
#'   for POSTs, but we do not require `httr` as a dependency.
#' @param dry_run `[logical(1)]` If `TRUE`, return the request that
#'   *would* be issued without sending it. Useful for the CLI's
#'   `--dry-run` flag and for tests.
#'
#' @return
#'   A list (the parsed JSON response, or the request that would have
#'   been issued when `dry_run = TRUE`). The list always contains a
#'   `request` element describing what was sent.
#'
#' @examples
#' \dontrun{
#' # Requires GITHUB_TOKEN set.
#' run_biotrace_github("rotsl/biotrace-r", action = "list-runs")
#' }
#'
#' # Safe, offline: see the request that would be issued.
#' run_biotrace_github(
#'   "rotsl/biotrace-r",
#'   action = "trigger",
#'   dry_run = TRUE
#' )
#'
#' @export
run_biotrace_github <- function(repo,
                                action = c("list-workflows", "list-runs",
                                           "trigger"),
                                workflow_name = "biotrace.yml",
                                ref = NULL,
                                token = NULL,
                                token_env = "GITHUB_TOKEN",
                                api_url = "https://api.github.com",
                                transport = NULL,
                                dry_run = FALSE) {
  action <- match.arg(action)
  if (!is.character(repo) || length(repo) != 1L ||
      !grepl("^[^/]+/[^/]+$", repo)) {
    abort_msg(
      paste0("`repo` must be a single string in owner/name form, ",
             "got: ", deparse(repo)),
      class = c("biotrace_repo_arg", "biotrace_error")
    )
  }
  if (!is.character(workflow_name) || length(workflow_name) != 1L ||
      !nzchar(workflow_name)) {
    abort_msg(
      "`workflow_name` must be a non-empty single string.",
      class = c("biotrace_workflow_name_arg", "biotrace_error")
    )
  }

  token <- .resolve_github_token(token, token_env, allow_missing = isTRUE(dry_run))

  req <- .build_github_request(
    repo = repo,
    action = action,
    workflow_name = workflow_name,
    ref = ref,
    api_url = api_url,
    token = token
  )

  if (isTRUE(dry_run)) {
    return(list(request = req, response = NULL, dry_run = TRUE))
  }

  if (is.null(transport)) {
    transport <- .default_github_transport
  }

  resp <- transport(req)
  .check_github_response(resp, req)
  parsed <- .parse_github_response(resp)

  list(request = req, response = parsed, dry_run = FALSE)
}

# Read a token from the user-supplied value or the environment. We
# look at GITHUB_TOKEN and then GH_TOKEN (a GitHub CLI convention).
# When `allow_missing = TRUE` (used by dry-run mode), we return an
# empty string instead of throwing, so the user can preview the
# request without setting up credentials.
.resolve_github_token <- function(token, token_env, allow_missing = FALSE) {
  if (!is.null(token) && nzchar(token)) {
    if (!is.character(token) || length(token) != 1L) {
      abort_msg(
        "`token` must be a single string.",
        class = c("biotrace_token_arg", "biotrace_error")
      )
    }
    return(token)
  }
  if (!is.character(token_env) || length(token_env) != 1L ||
      !nzchar(token_env)) {
    abort_msg(
      "`token_env` must be a non-empty single string.",
      class = c("biotrace_token_env_arg", "biotrace_error")
    )
  }
  for (env in c(token_env, "GH_TOKEN")) {
    val <- Sys.getenv(env, "")
    if (nzchar(val)) return(val)
  }
  if (isTRUE(allow_missing)) return("")
  abort_github_token_missing(token_env)
}

# Build the request structure. This is a pure function that never
# touches the network. Returns a list with: url, method, headers,
# body, action, repo.
.build_github_request <- function(repo, action, workflow_name, ref,
                                  api_url, token) {
  owner <- sub("/.*$", "", repo)
  name <- sub("^[^/]+/", "", repo)

  headers <- c(
    "Accept" = "application/vnd.github+json",
    "X-GitHub-Api-Version" = "2022-11-28"
  )
  if (!is.null(token) && nzchar(token)) {
    headers <- c(headers, c("Authorization" = paste("Bearer", token)))
  }

  switch(
    action,
    "list-workflows" = list(
      url = paste0(api_url, "/repos/", owner, "/", name, "/actions/workflows"),
      method = "GET",
      headers = headers,
      body = NULL,
      action = action,
      repo = repo
    ),
    "list-runs" = list(
      url = paste0(api_url, "/repos/", owner, "/", name,
                   "/actions/workflows/", workflow_name, "/runs"),
      method = "GET",
      headers = headers,
      body = NULL,
      action = action,
      repo = repo
    ),
    "trigger" = list(
      url = paste0(api_url, "/repos/", owner, "/", name,
                   "/actions/workflows/", workflow_name, "/dispatches"),
      method = "POST",
      headers = headers,
      body = list(ref = ref %||% "main"),
      action = action,
      repo = repo
    )
  )
}

# Default HTTP transport. Uses base R so we do not add a dependency on
# httr / curl. We deliberately keep this simple: GETs use
# download.file, POSTs use an HTTP POST via url() with custom request
# headers (R 4.x supports this through `httr`-free base facilities
# when `libcurl` is available).
.default_github_transport <- function(req) {
  if (!capabilities("libcurl")) {
    abort_github_request(
      "This R installation lacks libcurl support; pass `transport` explicitly."
    )
  }
  method <- toupper(req$method)
  if (method == "GET") {
    tmp <- tempfile(fileext = ".json")
    on.exit(unlink(tmp), add = TRUE)
    tryCatch({
      utils::download.file(
        url = req$url,
        destfile = tmp,
        method = "libcurl",
        quiet = TRUE,
        headers = unlist(req$headers)
      )
    }, error = function(e) {
      abort_github_request(conditionMessage(e))
    })
    raw <- readBin(tmp, "raw", file.info(tmp)$size)
    list(status = 200L, headers = character(0), content = raw)
  } else if (method == "POST") {
    body_json <- if (!is.null(req$body)) {
      jsonlite::toJSON(req$body, auto_unbox = TRUE)
    } else ""
    con <- tryCatch(
      url(req$url, headers = c(unlist(req$headers),
                               `Content-Type` = "application/json")),
      error = function(e) NULL
    )
    if (is.null(con)) {
      abort_github_request("Failed to open URL for POST (libcurl required).")
    }
    tryCatch({
      open(con, "wb")
      writeBin(charToRaw(body_json), con)
      close(con)
      list(status = 204L, headers = character(0), content = raw(0))
    }, error = function(e) {
      try(close(con), silent = TRUE)
      abort_github_request(conditionMessage(e))
    })
  } else {
    abort_github_request(paste("Unsupported HTTP method:", req$method))
  }
}

# Verify the response. We treat 4xx/5xx as errors with the message from
# the GitHub API response body when available.
.check_github_response <- function(resp, req) {
  if (!is.list(resp) || is.null(resp$status)) {
    abort_github_request("Transport returned a malformed response.")
  }
  if (resp$status >= 200L && resp$status < 300L) return(invisible(NULL))
  msg <- sprintf("HTTP %d for %s %s",
                 resp$status, req$method, req$url)
  body <- NULL
  if (!is.null(resp$content) && length(resp$content) > 0L) {
    body <- tryCatch(
      rawToChar(resp$content),
      error = function(e) NULL
    )
  }
  if (!is.null(body) && nzchar(body)) {
    parsed <- tryCatch(
      jsonlite::fromJSON(body, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (is.list(parsed) && !is.null(parsed[["message"]])) {
      msg <- paste0(msg, ": ", parsed[["message"]])
    }
  }
  abort_github_request(msg)
}

.parse_github_response <- function(resp) {
  if (is.null(resp$content) || length(resp$content) == 0L) {
    return(NULL)
  }
  txt <- tryCatch(rawToChar(resp$content), error = function(e) "")
  if (!nzchar(txt)) return(NULL)
  tryCatch(
    jsonlite::fromJSON(txt, simplifyVector = FALSE),
    error = function(e) list(raw = txt)
  )
}
