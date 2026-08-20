#' biotrace: R integration for the BioTrace GitHub Action
#'
#' BioTrace (<https://github.com/rotsl/biotrace>) is a GitHub Action that
#' traces biological results from data and code to figures and scientific
#' claims. The `biotrace` R package is the R-facing integration layer for
#' that Action. It does not ship or run the upstream TypeScript engine.
#'
#' The package provides four kinds of helpers:
#'
#' - Configuration helpers: [write_biotrace_config()],
#'   [read_biotrace_config()], [validate_biotrace_config()].
#' - Workflow scaffolding: [use_biotrace()], [write_biotrace_workflow()],
#'   [biotrace_workflow_text()].
#' - Report readers: [read_biotrace_report()],
#'   [validate_biotrace_report()], [summary.biotrace_report()].
#' - GitHub integration: [run_biotrace_github()].
#'
#' The installed CLI (`biotrace`) wraps the same R API. Run
#' `biotrace --help` after installation for usage.
#'
#' BioTrace runs only through the published GitHub Action, which the
#' scaffolded workflow references as `uses: rotsl/biotrace@v1`. The
#' package does not provide a local replica of the upstream engine.
#'
#' @keywords internal
#' @aliases biotrace-package
"_PACKAGE"

#' Report the package version and the upstream BioTrace reference
#'
#' `biotrace_version()` returns a list with the package version and the
#' upstream BioTrace Action tag this package was designed against. The
#' upstream tag is informational: this package works with the upstream
#' Action at the `uses: rotsl/biotrace@v1` ref, which is the tag this
#' package targets.
#'
#' @return A list with elements `package` (character version string),
#'   `upstream_repo` (URL), `upstream_ref` (Action tag), and
#'   `upstream_action_version` (the `package.json` version of upstream
#'   BioTrace at the time this package was authored).
#' @export
#' @examples
#' biotrace_version()
biotrace_version <- function() {
  list(
    package = .biotrace_pkg_version(),
    upstream_repo = .biotrace_upstream_repo(),
    upstream_ref = .biotrace_upstream_ref(),
    upstream_action_version = .biotrace_upstream_action_version()
  )
}

# Authoritative identity constants used across the package. Keeping them
# in one place means the CLI, the workflow templates and the
# documentation all agree on which upstream tag they target.
.biotrace_upstream_repo <- function() {
  "https://github.com/rotsl/biotrace"
}

.biotrace_upstream_ref <- function() {
  # The upstream version this package was designed against.
  # Source: action.yml + schemas/* fetched from the main branch on the
  # date recorded in DESCRIPTION. The upstream action reports its own
  # version in package.json; we record it here for diagnostics only.
  "v1"
}

.biotrace_upstream_action_version <- function() {
  # BioTrace package.json version at the time of authoring. Used only for
  # documentation; biotrace does not assert this at runtime, because the
  # upstream release tag is the contract that matters to consumers.
  "1.1.0"
}

# The installed version of this R package. Kept in sync with
# DESCRIPTION so we have one source of truth callable from R.
.biotrace_pkg_version <- function() {
  as.character(utils::packageVersion("biotrace"))
}

# CRAN-style empty package environment hook. Required so that
# `R CMD check --as-cran` sees a top-level package doc page.
NULL
