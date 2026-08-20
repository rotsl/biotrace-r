# Command-line interface for the biotrace R package.
#
# The installed script lives at inst/exec/biotrace. It is a thin R
# shim that calls biotrace:::biotrace_cli(). This file implements the
# dispatch logic.
#
# Subcommands:
#   biotrace --help
#   biotrace --version
#   biotrace init [--project <path>] [--force]
#   biotrace config print
#   biotrace config validate [path]
#   biotrace workflow print
#   biotrace workflow write [--path <path>] [--force]
#   biotrace report [path]
#   biotrace github run --repo owner/name [--action trigger|list-runs|list-workflows] [--dry-run]
#
# Exit codes:
#   0  success
#   1  user error (bad args, file not found, validation failure)
#   2  unexpected internal error
#
# We deliberately avoid any "biotrace check" subcommand. There is no
# local execution of the upstream BioTrace TypeScript engine in this
# package, so offering a `check` command would be misleading. The
# closest concept is `biotrace github run`, which talks to GitHub.

# Main entry point. Accepts argv (a character vector). Returns an
# integer exit code. Never throws; every error is caught and turned
# into a non-zero exit code so the CLI behaves like a normal Unix
# program.
biotrace_cli <- function(argv = commandArgs(trailingOnly = TRUE)) {
  tryCatch(
    .cli_run(argv),
    biotrace_error = function(e) {
      # Use base message() rather than cli::cli_text because the
      # cli glue engine interprets `{...}` and we want to print the
      # raw error message verbatim.
      message("Error: ", conditionMessage(e))
      1L
    },
    error = function(e) {
      msg <- conditionMessage(e)
      if (!nzchar(msg)) msg <- "unexpected error"
      message("Error: ", msg)
      2L
    }
  )
}

# The actual dispatcher. Throws biotrace_error on user-facing
# failures; the wrapper above converts those into exit code 1.
.cli_run <- function(argv) {
  if (length(argv) == 0L) {
    .cli_print_help()
    return(invisible(0L))
  }

  # Handle global flags first.
  first <- argv[[1L]]
  if (first %in% c("-h", "--help", "help")) {
    .cli_print_help()
    return(invisible(0L))
  }
  if (first %in% c("-V", "--version", "version")) {
    .cli_print_version()
    return(invisible(0L))
  }

  # Subcommands.
  sub <- first
  rest <- if (length(argv) > 1L) argv[-1L] else character(0)
  switch(
    sub,
    "init" = .cli_init(rest),
    "config" = .cli_config(rest),
    "workflow" = .cli_workflow(rest),
    "report" = .cli_report(rest),
    "github" = .cli_github(rest),
    abort_cli_arg(sub, "unknown subcommand. Run `biotrace --help`.")
  )
}

.cli_print_help <- function() {
  cat(.cli_help_text(), sep = "\n")
  invisible(0L)
}

.cli_help_text <- function() {
  c(
    "biotrace - R integration for the BioTrace GitHub Action",
    "",
    "Usage:",
    "  biotrace --help",
    "  biotrace --version",
    "  biotrace init [--project <path>] [--config <path>] [--workflow <path>] [--force]",
    "  biotrace config print",
    "  biotrace config validate [<path>]",
    "  biotrace workflow print",
    "  biotrace workflow write [--path <path>] [--force]",
    "  biotrace report [<path>]",
    "  biotrace github run --repo <owner/name> [--action <action>] [--dry-run]",
    "",
    "Subcommands:",
    "  init             Write .github/biotrace.yml and the BioTrace workflow.",
    "  config print     Print a minimal valid BioTrace configuration.",
    "  config validate  Validate a BioTrace configuration file.",
    "  workflow print   Print the BioTrace workflow YAML.",
    "  workflow write   Write the BioTrace workflow YAML.",
    "  report           Print a summary of a BioTrace JSON report.",
    "  github run       Trigger or inspect the BioTrace workflow on GitHub.",
    "",
    "Notes:",
    "  The actual BioTrace engine runs through the upstream GitHub",
    "  Action (uses: rotsl/biotrace@v1). This CLI does not execute",
    "  BioTrace locally.",
    "",
    "Exit codes:",
    "  0  success",
    "  1  user error",
    "  2  unexpected internal error"
  )
}

.cli_print_version <- function() {
  cat(sprintf("biotrace %s", .biotrace_pkg_version()), sep = "\n")
  cat(sprintf("upstream BioTrace action: %s",
              .biotrace_upstream_ref()), sep = "\n")
  invisible(0L)
}

# Parse a simple `--flag value` / `--flag` / positional list. Returns a
# list with `flags` (named list) and `positionals` (character vector).
# Unknown long options are kept verbatim under "unknown" so the
# caller can decide whether to reject them. `known_flags` must list
# every flag we accept; bool flags (which take no value) must also
# appear in `known_flags`.
.parse_cli_args <- function(argv, known_flags = character(0),
                            bool_flags = character(0)) {
  # bool_flags is a subset of known_flags. We union them so the
  # parser recognises both forms.
  known_flags <- union(known_flags, bool_flags)
  out <- list(flags = list(), positionals = character(0), unknown = character(0))
  i <- 1L
  while (i <= length(argv)) {
    tok <- argv[[i]]
    if (tok == "--") {
      if (i < length(argv)) out$positionals <- c(out$positionals, argv[(i+1L):length(argv)])
      break
    }
    if (startsWith(tok, "--") && tok %in% known_flags) {
      if (tok %in% bool_flags) {
        out$flags[[sub("^--", "", tok)]] <- TRUE
        i <- i + 1L
      } else {
        if (i == length(argv)) abort_cli_arg(tok, "missing value")
        out$flags[[sub("^--", "", tok)]] <- argv[[i + 1L]]
        i <- i + 2L
      }
    } else if (startsWith(tok, "--")) {
      out$unknown <- c(out$unknown, tok)
      i <- i + 1L
    } else {
      out$positionals <- c(out$positionals, tok)
      i <- i + 1L
    }
  }
  out
}

# --- subcommands ---------------------------------------------------------

.cli_init <- function(argv) {
  parsed <- .parse_cli_args(
    argv,
    known_flags = c("--project", "--config", "--workflow"),
    bool_flags = c("--force")
  )
  if (length(parsed$unknown) > 0L) {
    abort_cli_arg(parsed$unknown[[1L]], "unknown flag")
  }
  project <- parsed$flags$project %||% NULL
  cfg <- parsed$flags$config %||% ".github/biotrace.yml"
  wf <- parsed$flags$workflow %||% ".github/workflows/biotrace.yml"
  overwrite <- isTRUE(parsed$flags$force)

  result <- use_biotrace(
    project = project,
    config_path = cfg,
    workflow_path = wf,
    overwrite = overwrite
  )
  cat(sprintf("Wrote %s\n", result$config))
  cat(sprintf("Wrote %s\n", result$workflow))
  cat("Generated workflow uses rotsl/biotrace@v1.\n")
  invisible(0L)
}

.cli_config <- function(argv) {
  if (length(argv) == 0L) {
    abort_cli_arg("config", "expected a subcommand: print, validate")
  }
  sub <- argv[[1L]]
  rest <- if (length(argv) > 1L) argv[-1L] else character(0)
  switch(
    sub,
    "print" = .cli_config_print(rest),
    "validate" = .cli_config_validate(rest),
    abort_cli_arg(sub, "unknown `config` subcommand. Try print or validate.")
  )
}

.cli_config_print <- function(argv) {
  cat(default_biotrace_config_text(), sep = "\n")
  invisible(0L)
}

.cli_config_validate <- function(argv) {
  parsed <- .parse_cli_args(argv, known_flags = character(0), bool_flags = character(0))
  path <- if (length(parsed$positionals) >= 1L) parsed$positionals[[1L]] else ".github/biotrace.yml"
  errs <- validate_biotrace_config(path, return_errors = TRUE)
  if (length(errs) == 0L) {
    cat(sprintf("%s is a valid BioTrace configuration.\n", path))
    return(invisible(0L))
  }
  cat(sprintf("%s is invalid:\n", path))
  for (e in errs) {
    cat(sprintf("  - %s: %s\n", e$path, e$message))
  }
  1L
}

.cli_workflow <- function(argv) {
  if (length(argv) == 0L) {
    abort_cli_arg("workflow", "expected a subcommand: print, write")
  }
  sub <- argv[[1L]]
  rest <- if (length(argv) > 1L) argv[-1L] else character(0)
  switch(
    sub,
    "print" = .cli_workflow_print(rest),
    "write" = .cli_workflow_write(rest),
    abort_cli_arg(sub, "unknown `workflow` subcommand. Try print or write.")
  )
}

.cli_workflow_print <- function(argv) {
  cat(biotrace_workflow_text(), sep = "\n")
  invisible(0L)
}

.cli_workflow_write <- function(argv) {
  parsed <- .parse_cli_args(
    argv,
    known_flags = c("--path", "--config", "--fail-on", "--ai-enabled"),
    bool_flags = c("--force", "--workflow-dispatch")
  )
  if (length(parsed$unknown) > 0L) {
    abort_cli_arg(parsed$unknown[[1L]], "unknown flag")
  }
  path <- parsed$flags$path %||% ".github/workflows/biotrace.yml"
  cfg <- parsed$flags$config %||% ".github/biotrace.yml"
  fail_on <- parsed$flags$`fail-on` %||% "error"
  ai <- parsed$flags$`ai-enabled` %||% "false"
  overwrite <- isTRUE(parsed$flags$force)
  incl_disp <- isTRUE(parsed$flags$`workflow-dispatch`)
  written <- write_biotrace_workflow(
    path = path,
    config_path = cfg,
    fail_on = fail_on,
    ai_enabled = ai,
    include_workflow_dispatch = incl_disp,
    overwrite = overwrite
  )
  cat(sprintf("Wrote %s\n", written))
  invisible(0L)
}

.cli_report <- function(argv) {
  parsed <- .parse_cli_args(argv, known_flags = character(0), bool_flags = character(0))
  path <- if (length(parsed$positionals) >= 1L) parsed$positionals[[1L]] else "biotrace-report.json"

  if (!.exists_file(path)) {
    cat(sprintf("File not found: %s\n", path))
    return(1L)
  }

  errs <- validate_biotrace_report(path, return_errors = TRUE)
  if (length(errs) > 0L) {
    cat(sprintf("%s is not a valid BioTrace report:\n", path))
    for (e in errs) {
      cat(sprintf("  - %s: %s\n", e$path, e$message))
    }
    return(1L)
  }

  report <- read_biotrace_report(path)
  print(report)
  invisible(0L)
}

.cli_github <- function(argv) {
  if (length(argv) == 0L) {
    abort_cli_arg("github", "expected a subcommand: run")
  }
  sub <- argv[[1L]]
  rest <- if (length(argv) > 1L) argv[-1L] else character(0)
  switch(
    sub,
    "run" = .cli_github_run(rest),
    abort_cli_arg(sub, "unknown `github` subcommand. Try run.")
  )
}

.cli_github_run <- function(argv) {
  parsed <- .parse_cli_args(
    argv,
    known_flags = c("--repo", "--action", "--workflow", "--ref", "--token-env", "--api-url"),
    bool_flags = c("--dry-run")
  )
  if (length(parsed$unknown) > 0L) {
    abort_cli_arg(parsed$unknown[[1L]], "unknown flag")
  }
  repo <- parsed$flags$repo
  if (is.null(repo) || !nzchar(repo)) {
    abort_cli_arg("--repo", "required. Pass `--repo owner/name`.")
  }
  action <- parsed$flags$action %||% "trigger"
  workflow_name <- parsed$flags$workflow %||% "biotrace.yml"
  ref <- parsed$flags$ref %||% NULL
  token_env <- parsed$flags$`token-env` %||% "GITHUB_TOKEN"
  api_url <- parsed$flags$`api-url` %||% "https://api.github.com"
  dry_run <- isTRUE(parsed$flags$`dry-run`)

  result <- run_biotrace_github(
    repo = repo,
    action = action,
    workflow_name = workflow_name,
    ref = ref,
    token_env = token_env,
    api_url = api_url,
    dry_run = dry_run
  )
  cat(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE), sep = "\n")
  invisible(0L)
}
