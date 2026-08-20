# biotrace 0.1.0

First production release of the R integration package for the BioTrace GitHub Action.

## R API

The public R API includes:

- `use_biotrace()` writes `.github/biotrace.yml` and `.github/workflows/biotrace.yml` and refuses to overwrite existing files unless `overwrite = TRUE`.
- `write_biotrace_config()`, `read_biotrace_config()`, `validate_biotrace_config()` write, read, and validate the BioTrace YAML configuration against the upstream JSON Schema.
- `write_biotrace_workflow()`, `biotrace_workflow_text()` generate a GitHub Actions workflow that references `rotsl/biotrace@v1`.
- `read_biotrace_report()`, `validate_biotrace_report()`, `summary.biotrace_report()`, `print.biotrace_report()` read and summarise the JSON report produced by the Action.
- `run_biotrace_github()` triggers or inspects a BioTrace workflow through the GitHub REST API. Tokens are read from environment variables only.
- `biotrace_version()` reports the package version and the upstream Action tag the package was designed against.
- `default_biotrace_config()` and `default_biotrace_config_text()` return the smallest valid configuration.

## CLI

The installed `biotrace` executable provides `init`, `config print`, `config validate`, `workflow print`, `workflow write`, `report`, and `github run`. Exit codes are 0 for success, 1 for user errors, and 2 for unexpected internal errors.

## Schemas

Verbatim copies of `biotrace-config.schema.json` and `biotrace-report.schema.json` from `rotsl/biotrace` are stored under `inst/extdata/schemas/`. The local validator implements the subset of JSON Schema draft-7 used by those schemas.

## Testing

The testthat suite covers configuration, workflows, reports, the CLI, path handling, and GitHub request construction. Tests use temporary directories and local HTTP doubles, so they do not require network access or credentials.

## Repository workflow

The `biotrace-r` repository tests the upstream Action against its own source. The `.github/biotrace.yml` file is a minimal valid configuration, and `.github/workflows/biotrace.yml` runs `rotsl/biotrace@v1` on every pull request.
