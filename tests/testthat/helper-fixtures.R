# Test fixtures: shared paths and helpers used by every test file.

# A small valid report object that exercises every required field plus a
# few optional ones. Mirrors inst/extdata/example-report.json so tests
# that exercise file reading and tests that exercise list reading agree
# on the shape.
.example_report_list <- function() {
  list(
    schema_version = "1.0",
    generated_at = "2026-08-20T10:30:00Z",
    status = "warning",
    repository = list(owner = "rotsl", name = "example"),
    score = list(
      reproducibility = 82L,
      components = list(
        list(name = "environment_definition", weight = 15, result = "passed"),
        list(name = "random_seed", weight = 10, result = "failed",
             reason = "no set.seed")
      )
    ),
    summary = list(
      files_checked = 4L,
      claims_checked = 2L,
      figures_checked = 3L,
      findings = 3L,
      blocking_findings = 0L
    ),
    findings = list(
      list(id = "stale-output", module = "lineage", severity = "warning",
           title = "Possible stale output",
           message = "input changed but output did not",
           path = "results/de_results.csv",
           label = "results:changed",
           deterministic = TRUE),
      list(id = "figure-stale", module = "figure", severity = "warning",
           title = "Figure may be stale",
           message = "upstream dependency changed",
           path = "figures/figure_2.png",
           label = "figure:stale",
           deterministic = TRUE),
      list(id = "metadata-ok", module = "files", severity = "info",
           title = "Metadata valid",
           message = "6 rows, 3 columns",
           path = "data/sample_metadata.csv",
           label = "metadata:valid",
           deterministic = TRUE)
    ),
    claims = list(list(id = "il6-treatment-effect", status = "verified",
                       assertions = list())),
    lineage = list(list(id = "differential-expression", status = "warning")),
    ai = list(enabled = FALSE, status = "disabled", provider = "",
              advisory_only = TRUE, observations = list())
  )
}

# Write the example report JSON to a temp file. Returns the path.
.write_example_report <- function(dir = tempfile()) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(dir, "biotrace-report.json")
  json <- jsonlite::toJSON(.example_report_list(), auto_unbox = TRUE,
                           pretty = TRUE)
  writeLines(json, path)
  path
}

# Write a minimal valid config to a temp file. Returns the path.
.write_minimal_config <- function(dir = tempfile()) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(dir, "biotrace.yml")
  writeLines(c("version: 1"), path)
  path
}

# Mock transport for run_biotrace_github. Returns a closure that
# records the calls made to it and serves a pre-baked response based
# on the action in the request.
.mock_transport <- function(responses = list()) {
  calls <- list()
  function(req) {
    calls[[length(calls) + 1L]] <<- req
    if (!is.null(responses[[req$action]])) return(responses[[req$action]])
    list(status = 200L, headers = character(0),
         content = charToRaw("{}"))
  }
}
