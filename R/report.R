#' BioTrace report readers
#'
#' `read_biotrace_report()` reads the machine-readable JSON report
#' produced by the BioTrace GitHub Action. The result is an S3 object
#' of class `biotrace_report` with `print()` and `summary()` methods.
#'
#' `validate_biotrace_report()` validates a report file against the
#' upstream BioTrace report JSON Schema.
#'
#' `summary.biotrace_report()` returns a compact summary of the
#' report: status, score, finding counts.
#'
#' @section Report shape:
#' The report JSON follows the upstream
#' `biotrace-report.schema.json` (shipped under
#' `inst/extdata/schemas/`). Required fields are `schema_version`,
#' `generated_at`, `status`, `score`, `summary`, `findings`.
#'
#' @param file `[character(1)]` Path to a BioTrace report JSON file.
#' @param return_errors `[logical(1)]` Return a list of validation
#'   errors instead of throwing? Used by
#'   [validate_biotrace_report()] only.
#' @param x `[biotrace_report]` A report object.
#' @param object `[biotrace_report]` A report object.
#' @param ... Unused. Present so the S3 methods match the generic
#'   signature.
#'
#' @return
#'   - `read_biotrace_report()`: an object of class `biotrace_report`
#'     (a list with extra attributes holding the source path).
#'   - `validate_biotrace_report()`: `TRUE` (invisible) or a list of
#'     error objects.
#'   - `summary.biotrace_report()`: a list with elements
#'     `status`, `score`, `findings_count`, `blocking_findings_count`,
#'     `files_checked`, `claims_checked`, `figures_checked`,
#'     `generated_at`, `source`.
#'
#' @examples
#' report_path <- system.file("extdata", "example-report.json",
#'                            package = "biotrace")
#' report <- read_biotrace_report(report_path)
#' print(report)
#' summary(report)
#'
#' @name biotrace_report
NULL

# Severity ordering used by the print/summary helpers.
.SEVERITY_ORDER <- c(info = 1L, warning = 2L, error = 3L)

.severity_label <- function(sev) {
  if (is.null(sev) || length(sev) == 0L) return(character(0))
  tolower(as.character(sev))
}

# Convenience accessor that survives a missing field. We always return
# NULL for missing fields so callers can branch without tryCatch.
.field <- function(report, name) {
  if (is.null(report)) return(NULL)
  report[[name]]
}

# Summarise findings by severity. Returns a named integer vector
# c(info = , warning = , error = ) with zero-filled entries.
.findings_by_severity <- function(findings) {
  counts <- c(info = 0L, warning = 0L, error = 0L)
  if (is.null(findings) || length(findings) == 0L) return(counts)
  sev <- vapply(findings, function(f) {
    s <- .severity_label(f[["severity"]])
    if (!s %in% names(counts)) NA_character_ else s
  }, character(1))
  for (s in sev[!is.na(sev)]) counts[[s]] <- counts[[s]] + 1L
  counts
}

#' @rdname biotrace_report
#' @export
read_biotrace_report <- function(file) {
  if (!is.character(file) || length(file) != 1L || !nzchar(file)) {
    abort_msg(
      "`file` must be a non-empty single string.",
      class = c("biotrace_path_arg", "biotrace_error")
    )
  }
  if (!.exists_file(file)) abort_file_missing(file)
  text <- .read_text_utf8(file)

  # First, validate JSON parses. jsonlite::validate returns FALSE on
  # failure rather than throwing.
  if (!jsonlite::validate(text)) {
    abort_json_parse(file, "not valid JSON")
  }
  obj <- tryCatch(
    jsonlite::fromJSON(text, simplifyVector = FALSE),
    error = function(e) abort_json_parse(file, conditionMessage(e))
  )
  if (is.null(obj)) obj <- list()

  structure(
    obj,
    class = "biotrace_report",
    source = normalizePath(file, mustWork = TRUE)
  )
}

#' @rdname biotrace_report
#' @export
validate_biotrace_report <- function(file, return_errors = FALSE) {
  if (!is.character(file) || length(file) != 1L || !nzchar(file)) {
    abort_msg(
      "`file` must be a non-empty single string.",
      class = c("biotrace_path_arg", "biotrace_error")
    )
  }
  .biotrace_validate_file(file, "report", return_errors = return_errors)
}

#' @rdname biotrace_report
#' @export
summary.biotrace_report <- function(object, ...) {
  report <- object
  if (!inherits(report, "biotrace_report")) {
    abort_msg(
      "`object` must inherit from class biotrace_report.",
      class = c("biotrace_report_arg", "biotrace_error")
    )
  }
  score <- .field(report, "score")
  repro <- if (is.list(score)) score[["reproducibility"]] else NA_integer_
  summ <- .field(report, "summary")
  findings <- .field(report, "findings")
  by_sev <- .findings_by_severity(findings)

  structure(
    list(
      status = .field(report, "status"),
      score = repro,
      findings_count = if (is.list(summ)) summ[["findings"]] else length(findings),
      blocking_findings_count = if (is.list(summ)) summ[["blocking_findings"]] else NA_integer_,
      files_checked = if (is.list(summ)) summ[["files_checked"]] else NA_integer_,
      claims_checked = if (is.list(summ)) summ[["claims_checked"]] else NA_integer_,
      figures_checked = if (is.list(summ)) summ[["figures_checked"]] else NA_integer_,
      generated_at = .field(report, "generated_at"),
      findings_by_severity = by_sev,
      source = attr(report, "source")
    ),
    class = "biotrace_report_summary"
  )
}

# Friendly human-readable rendering used by both print() and the CLI
# `biotrace report` command.
.render_report_summary <- function(report) {
  s <- summary.biotrace_report(report)
  lines <- character(0)
  add <- function(...) lines <<- c(lines, c(...))

  add(sprintf("BioTrace report: %s", s$status %||% "(unknown status)"))
  if (!is.null(s$score) && !is.na(s$score)) {
    add(sprintf("Reproducibility score: %d/100", as.integer(s$score)))
  }
  if (!is.null(s$generated_at)) {
    add(sprintf("Generated at: %s", s$generated_at))
  }
  add(sprintf("Findings: %d total, %d blocking",
              s$findings_count %||% 0L,
              s$blocking_findings_count %||% 0L))
  if (!is.null(s$findings_by_severity) && any(s$findings_by_severity > 0L)) {
    add(sprintf("  by severity: info=%d, warning=%d, error=%d",
                s$findings_by_severity[["info"]],
                s$findings_by_severity[["warning"]],
                s$findings_by_severity[["error"]]))
  }
  if (!is.null(s$files_checked) && !is.na(s$files_checked)) {
    add(sprintf("Files checked: %d", as.integer(s$files_checked)))
  }
  if (!is.null(s$claims_checked) && !is.na(s$claims_checked)) {
    add(sprintf("Claims checked: %d", as.integer(s$claims_checked)))
  }
  if (!is.null(s$figures_checked) && !is.na(s$figures_checked)) {
    add(sprintf("Figures checked: %d", as.integer(s$figures_checked)))
  }
  src <- attr(report, "source")
  if (!is.null(src)) add(sprintf("Source: %s", src))
  lines
}

#' @rdname biotrace_report
#' @export
print.biotrace_report <- function(x, ...) {
  report <- x
  if (!inherits(report, "biotrace_report")) {
    abort_msg(
      "`x` must inherit from class biotrace_report.",
      class = c("biotrace_report_arg", "biotrace_error")
    )
  }
  cat(.render_report_summary(report), sep = "\n")
  invisible(report)
}
