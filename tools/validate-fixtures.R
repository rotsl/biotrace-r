#!/usr/bin/env Rscript
# Validate every YAML and JSON fixture in the biotrace package source.
#
# Run from the repository root. Exits 0 if every file parses, non-zero
# otherwise. Used by tools/local-check.sh.
#
# We do not depend on the biotrace package here; this is a pure
# infrastructure check that runs even before the package is installed.

library(yaml)
library(jsonlite)

ok <- TRUE
report <- function(f, kind) {
  cat(sprintf("  parsed (%s): %s\n", kind, f))
}

cat("YAML + JSON fixture validation\n")
cat("==============================\n")

# Schema fixtures
for (f in list.files("inst/extdata/schemas", pattern = "\\.json$",
                     full.names = TRUE)) {
  res <- tryCatch({ jsonlite::read_json(f); TRUE },
                  error = function(e) { message(e$message); FALSE })
  if (!isTRUE(res)) ok <- FALSE
  if (res) report(f, "json-schema")
}

# JSON example fixtures
for (f in list.files("inst/extdata", pattern = "\\.json$",
                     full.names = TRUE, recursive = TRUE)) {
  res <- tryCatch({ jsonlite::read_json(f); TRUE },
                  error = function(e) { message(e$message); FALSE })
  if (!isTRUE(res)) ok <- FALSE
  if (res) report(f, "json")
}

# YAML fixtures and templates
yaml_files <- c(
  list.files("inst/extdata", pattern = "\\.yml$", full.names = TRUE,
             recursive = TRUE),
  list.files("inst/templates", pattern = "\\.yml$", full.names = TRUE,
             recursive = TRUE),
  ".github/biotrace.yml",
  ".github/workflows/biotrace.yml",
  ".github/workflows/R-CMD-check.yaml"
)
for (f in yaml_files) {
  if (!file.exists(f)) {
    message("file not found: ", f)
    ok <- FALSE
    next
  }
  res <- tryCatch({ yaml::read_yaml(f); TRUE },
                  error = function(e) { message(e$message); FALSE })
  if (!isTRUE(res)) ok <- FALSE
  if (res) report(f, "yaml")
}

cat("\n")
if (ok) {
  cat("RESULT: ALL FIXTURES PARSED\n")
  quit(status = 0)
} else {
  cat("RESULT: ONE OR MORE FIXTURES FAILED TO PARSE\n")
  quit(status = 1)
}
