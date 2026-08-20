# Internal helpers shared across the package.
#
# This file deliberately exports nothing. Public helpers live in their
# own files (paths.R, config.R, ...) so that the exported surface is
# easy to audit.

# Null-coalescing operator. We define our own rather than importing
# rlang::`%||%` so the package keeps working across rlang versions
# that toggle the function's behaviour. Used by report.R and cli.R.
`%||%` <- function(a, b) if (is.null(a)) b else a

# Wrap a multi-line message into a single comma-joined string for
# inclusion in rlang::abort() / warn() / inform() messages.
.format_reasons <- function(reasons) {
  if (length(reasons) == 0L) return(character(0))
  paste(reasons, collapse = "\n")
}

# Read a text file as UTF-8, failing with a useful error when the file
# does not exist. We use base::readLines rather than brio because we want
# to keep the dependency footprint small.
.read_text_utf8 <- function(path) {
  if (!.exists_file(path)) {
    abort_file_missing(path)
  }
  tryCatch(
    readLines(path, encoding = "UTF-8", warn = FALSE),
    error = function(e) {
      abort_read_failed(path, conditionMessage(e))
    }
  )
}

# Write a UTF-8 text file atomically: write to a temp file in the same
# directory, then rename. The rename is the commit point. This means a
# partially written file is never observable to another process.
.write_text_utf8 <- function(path, text) {
  .ensure_parent_dir(path)
  tmp <- paste0(path, ".tmp-", Sys.getpid(), "-", sprintf("%06d", sample.int(1e6, 1) - 1L))
  on.exit(unlink(tmp), add = TRUE)
  tryCatch(
    {
      con <- file(tmp, open = "w", encoding = "UTF-8")
      on.exit(if (isOpen(con)) close(con), add = TRUE)
      writeLines(text, con, sep = "\n", useBytes = FALSE)
      try(close(con), silent = TRUE)
      on.exit(NULL, after = 0)
      file.rename(tmp, path)
    },
    error = function(e) {
      abort_write_failed(path, conditionMessage(e))
    }
  )
  invisible(path)
}

.exists_file <- function(path) {
  nzchar(path) && file.exists(path) && !dir.exists(path)
}

.ensure_parent_dir <- function(path) {
  parent <- dirname(path)
  if (!dir.exists(parent)) {
    dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  }
  invisible(parent)
}

# Convert a vector of strings into a trimmed, de-duplicated, non-empty
# vector. Used to normalise the comma-separated inputs the CLI accepts
# (e.g. `--fail-on error` vs `--fail-on error,warning`).
.split_csv <- function(x) {
  if (is.null(x) || length(x) == 0L) return(character(0))
  x <- unlist(strsplit(as.character(x), ",", fixed = TRUE))
  x <- trimws(x)
  x <- x[nzchar(x)]
  x
}

# A deterministic numeric seed for atomic temp files. We avoid setting
# .Random.seed in the user's session, which is the polite thing to do
# for a library function.
.sample_int <- function(n) {
  if (n <= 0L) return(integer(0))
  sample.int(n, 1L) - 1L
}

# Convert a list-of-errors into a single rlang condition. Each error
# must be a named list with at least a "message" field and a "path"
# field. This is used by the JSON-schema validator to collect all
# schema violations in one shot rather than failing on the first one.
.collect_errors <- function(errors) {
  if (length(errors) == 0L) return(NULL)
  structure(
    list(errors = errors),
    class = "biotrace_validation_errors"
  )
}

# Boolean coercion that matches what yaml.load produces for the literal
# values `true`, `false`, `yes`, `no`. We only treat the unambiguous
# true values as TRUE.
.is_true <- function(x) {
  if (is.null(x)) return(FALSE)
  if (is.logical(x)) return(isTRUE(x))
  if (is.character(x)) {
    return(tolower(x) %in% c("true", "yes", "on", "1"))
  }
  if (is.numeric(x)) return(x != 0)
  FALSE
}

# We want the CLI's stderr to look like the rest of cli's output, so we
# funnel everything through cli_text. But we also want a single
# formatting primitive for messages that include a path. This keeps
# behaviour consistent across the package.
.format_path_msg <- function(msg, path) {
  if (missing(path) || !nzchar(path)) return(msg)
  paste0(msg, ": ", path)
}

# Quote a YAML value when it would otherwise be misparsed. We use this
# for workflow `with:` inputs so values like "false" survive a YAML
# round-trip as the string "false" rather than the boolean FALSE.
# GitHub Actions coerces inputs to strings either way, but quoting
# matches the upstream workflow style verbatim. We keep the rule
# conservative: only the YAML boolean / null keywords and empty
# strings get quoted. Plain scalars like `${{ github.token }}` parse
# fine unquoted, so we leave them alone.
.yaml_quote_if_needed <- function(val) {
  if (!is.character(val) || length(val) != 1L) return(as.character(val))
  if (nchar(val) == 0L) return('""')
  keywords <- c("true", "false", "yes", "no", "on", "off", "null", "~",
                "True", "False", "Yes", "No", "Null",
                "TRUE", "FALSE", "YES", "NO", "NULL")
  if (val %in% keywords) {
    escaped <- gsub('"', '\\\\"', val)
    return(sprintf('"%s"', escaped))
  }
  val
}

# Throw a structured error. rlang errors carry `parent` and `call`
# information; we set the `call` to `NULL` so the message reaches the
# user without a noisy "Error in fn() :" prefix that points at an
# internal frame the user cannot act on.
abort_msg <- function(message, class = "biotrace_error", ..., call = NULL) {
  rlang::abort(message, class = class, ..., call = call)
}

abort_file_missing <- function(path) {
  abort_msg(
    message = paste0("File does not exist: ", path),
    class = c("biotrace_file_missing", "biotrace_error"),
    path = path
  )
}

abort_dir_missing <- function(path) {
  abort_msg(
    message = paste0("Directory does not exist: ", path),
    class = c("biotrace_dir_missing", "biotrace_error"),
    path = path
  )
}

abort_read_failed <- function(path, reason) {
  abort_msg(
    message = paste0("Failed to read ", path, ": ", reason),
    class = c("biotrace_read_failed", "biotrace_error"),
    path = path, reason = reason
  )
}

abort_write_failed <- function(path, reason) {
  abort_msg(
    message = paste0("Failed to write ", path, ": ", reason),
    class = c("biotrace_write_failed", "biotrace_error"),
    path = path, reason = reason
  )
}

abort_yaml_parse <- function(path, reason) {
  abort_msg(
    message = paste0("YAML parse error in ", path, ": ", reason),
    class = c("biotrace_yaml_parse_error", "biotrace_error"),
    path = path, reason = reason
  )
}

abort_json_parse <- function(path, reason) {
  abort_msg(
    message = paste0("JSON parse error in ", path, ": ", reason),
    class = c("biotrace_json_parse_error", "biotrace_error"),
    path = path, reason = reason
  )
}

abort_invalid_config <- function(reasons) {
  abort_msg(
    message = paste0(
      "Invalid BioTrace configuration.\n",
      .format_reasons(reasons)
    ),
    class = c("biotrace_invalid_config", "biotrace_error"),
    reasons = reasons
  )
}

abort_invalid_report <- function(reasons) {
  abort_msg(
    message = paste0(
      "Invalid BioTrace report JSON.\n",
      .format_reasons(reasons)
    ),
    class = c("biotrace_invalid_report", "biotrace_error"),
    reasons = reasons
  )
}

abort_cli_arg <- function(arg, reason) {
  abort_msg(
    message = paste0("Invalid argument ", arg, ": ", reason),
    class = c("biotrace_cli_arg_error", "biotrace_error"),
    arg = arg, reason = reason
  )
}

abort_github_token_missing <- function(env_var) {
  abort_msg(
    message = paste0(
      "GitHub token not found. Set ", env_var,
      " to a token with repo:public_repo or workflow permission, ",
      "or use the `token` argument. biotrace never reads tokens ",
      "from source control."
    ),
    class = c("biotrace_token_missing", "biotrace_error"),
    env_var = env_var
  )
}

abort_github_request <- function(reason) {
  abort_msg(
    message = paste0("GitHub request failed: ", reason),
    class = c("biotrace_github_request_failed", "biotrace_error"),
    reason = reason
  )
}
