# Path helpers shared by config.R / workflow.R / github.R / cli.R.
#
# We deliberately route every file operation through `fs`. fs is a small,
# mature, cross-platform dependency and gives us nicer path joining
# semantics than base::file.path on Windows.

# Locate a BioTrace project root by walking up from `start` until we find
# a directory containing `.git` or a `DESCRIPTION` file. We prefer the
# git root, but fall back to DESCRIPTION so this works for an
# R-package-only project (no git) too.
#
# Returns the absolute path, or NA_character_ if no root was found. We
# never throw here so callers can decide what to do (e.g. fall back to
# the current working directory).
find_project_root <- function(start = ".") {
  start <- fs::path_abs(start)
  if (!fs::dir_exists(start)) {
    start <- fs::path_abs(".")
  }
  if (fs::dir_exists(start)) {
    start <- fs::path_real(start)
  }
  # Walk upward until we hit a git/.github marker or the filesystem root.
  cur <- start
  seen <- character(0)
  repeat {
    if (!nzchar(cur) || cur %in% seen) break
    seen <- c(seen, cur)
    if (fs::dir_exists(fs::path(cur, ".git")) ||
        fs::file_exists(fs::path(cur, "DESCRIPTION"))) {
      return(cur)
    }
    parent <- dirname(cur)
    if (parent == cur) break
    cur <- parent
  }
  NA_character_
}

# Resolve a user-supplied path that may be relative to a project root.
# `path` may be:
# - NULL or NA: return `default` resolved under `root`
# - absolute: returned as-is
# - relative: resolved under `root`
resolve_path <- function(path, root = ".", default = NULL) {
  if (is.null(path) || (length(path) == 1L && is.na(path))) {
    path <- default
  }
  if (is.null(path)) return(NULL)
  path <- fs::as_fs_path(path)
  if (fs::is_absolute_path(path)) return(fs::path_real(path))
  fs::path_abs(path, start = root)
}

# Locate a file shipped under `inst/extdata` of the installed package.
extdata_path <- function(filename) {
  fs::path_package("biotrace", "extdata", filename)
}

# Locate a file shipped under `inst/templates`.
template_path <- function(filename) {
  fs::path_package("biotrace", "templates", filename)
}

# Locate a file shipped under `inst/extdata/schemas`. Used by
# validation.R to load the authoritative JSON Schemas published by
# upstream BioTrace.
schema_path <- function(name) {
  name <- match.arg(name, c("config", "report"))
  extdata_path(fs::path("schemas", paste0("biotrace-", name, ".schema.json")))
}

# Return the path to the installed CLI script. Used by tests to invoke
# the CLI without depending on PATH being set up.
cli_executable_path <- function() {
  fs::path_package("biotrace", "exec", "biotrace")
}

# Coerce a possibly-NULL path to a UTF-8 character vector. Used to
# normalise user input before validation.
as_path_chr <- function(path) {
  if (is.null(path)) return(NA_character_)
  if (length(path) == 0L) return(NA_character_)
  as.character(path)
}
