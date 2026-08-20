#' BioTrace configuration helpers
#'
#' `write_biotrace_config()` writes a BioTrace YAML configuration file.
#' `read_biotrace_config()` reads one back as an R list.
#' `validate_biotrace_config()` validates a file against the upstream
#' JSON Schema.
#'
#' @section Stability:
#' Configuration follows `version: 1` of the BioTrace configuration
#' schema. The schema reference copy shipped in this package is a
#' verbatim copy of the JSON Schema published by `rotsl/biotrace`.
#'
#' @param path `[character(1)]` Path to write or read.
#' @param config `[list]` Configuration object. Must be a list whose
#'   `version` field equals `1L`. Use [default_biotrace_config()] to
#'   get a sensible starting point.
#' @param overwrite `[logical(1)]` If `FALSE` (the default), refuse to
#'   overwrite an existing file. Set to `TRUE` to overwrite.
#' @param file `[character(1)]` Path to a BioTrace configuration file
#'   (alias for `path`, for [read_biotrace_config()]).
#' @param return_errors `[logical(1)]` If `TRUE`, return a list of
#'   validation errors instead of throwing. If `FALSE` (the default),
#'   throw on the first validation failure.
#'
#' @return
#'   - `write_biotrace_config()`: the absolute path to the written
#'     file, invisibly.
#'   - `read_biotrace_config()`: a list representing the parsed YAML.
#'   - `validate_biotrace_config()`: `TRUE` (invisible) when valid
#'     and `return_errors = FALSE`; otherwise a list of error objects
#'     (possibly empty).
#'
#' @examples
#' tmp <- tempfile()
#' write_biotrace_config(tmp, default_biotrace_config())
#' validate_biotrace_config(tmp)
#' read_biotrace_config(tmp)
#'
#' @name biotrace_config
NULL

#' @return A list representing the smallest valid BioTrace config.
#' @rdname biotrace_config
#' @export
default_biotrace_config <- function() {
  list(version = 1L)
}

#' @return The default BioTrace configuration as a YAML string.
#' @rdname biotrace_config
#' @export
default_biotrace_config_text <- function() {
  yaml::as.yaml(list(version = 1L), indent.mapping.sequence = TRUE)
}

# Resolve a `config` argument that might be a path, NULL, or a list.
# Returns a list. Throws a friendly error when the input is unusable.
# Uses the yaml seq handler so single-element arrays stay as lists
# rather than collapsing to atomic scalars. This keeps the round-trip
# write -> read -> write stable and matches the JSON Schema's `type:
# array` expectation.
.normalize_config_arg <- function(config) {
  if (is.null(config)) return(default_biotrace_config())
  if (is.character(config) && length(config) == 1L) {
    # Path: read and parse.
    if (!.exists_file(config)) abort_file_missing(config)
    text <- .read_text_utf8(config)
    obj <- tryCatch(
      yaml::yaml.load(text, handlers = list(seq = function(x) as.list(x))),
      error = function(e) abort_yaml_parse(config, conditionMessage(e))
    )
    if (is.null(obj)) obj <- list()
    return(obj)
  }
  if (is.list(config)) return(config)
  abort_msg(
    paste0("`config` must be a list or a path to an existing YAML file, ",
           "got an object of class ", paste(class(config), collapse = "/")),
    class = c("biotrace_config_arg", "biotrace_error")
  )
}

#' @rdname biotrace_config
#' @export
write_biotrace_config <- function(path, config = default_biotrace_config(),
                                  overwrite = FALSE) {
  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    abort_msg(
      "`path` must be a non-empty single string.",
      class = c("biotrace_path_arg", "biotrace_error")
    )
  }
  if (!is.logical(overwrite) || length(overwrite) != 1L || is.na(overwrite)) {
    abort_msg(
      "`overwrite` must be TRUE or FALSE.",
      class = c("biotrace_overwrite_arg", "biotrace_error")
    )
  }

  if (!overwrite && .exists_file(path)) {
    abort_msg(
      paste0("Refusing to overwrite existing file: ", path,
             ". Pass overwrite = TRUE to replace it."),
      class = c("biotrace_refuse_overwrite", "biotrace_error"),
      path = path
    )
  }

  obj <- .normalize_config_arg(config)

  # Validate before writing. A write that produced an invalid config
  # would be a footgun for callers scaffolding a fresh project.
  errs <- .biotrace_validate(obj, "config", path, return_errors = TRUE)
  if (length(errs) > 0L) abort_invalid_config(vapply(errs, function(e) {
    paste0(e$path, ": ", e$message)
  }, character(1)))

  text <- yaml::as.yaml(obj, indent.mapping.sequence = TRUE)
  .write_text_utf8(path, text)
  invisible(normalizePath(path, mustWork = TRUE))
}

#' @rdname biotrace_config
#' @export
read_biotrace_config <- function(file) {
  if (!is.character(file) || length(file) != 1L || !nzchar(file)) {
    abort_msg(
      "`file` must be a non-empty single string.",
      class = c("biotrace_path_arg", "biotrace_error")
    )
  }
  if (!.exists_file(file)) abort_file_missing(file)
  text <- .read_text_utf8(file)
  obj <- tryCatch(
    yaml::yaml.load(text, handlers = list(seq = function(x) as.list(x))),
    error = function(e) abort_yaml_parse(file, conditionMessage(e))
  )
  if (is.null(obj)) obj <- list()
  obj
}

#' @rdname biotrace_config
#' @export
validate_biotrace_config <- function(file, return_errors = FALSE) {
  if (!is.character(file) || length(file) != 1L || !nzchar(file)) {
    abort_msg(
      "`file` must be a non-empty single string.",
      class = c("biotrace_path_arg", "biotrace_error")
    )
  }
  .biotrace_validate_file(file, "config", return_errors = return_errors)
}
