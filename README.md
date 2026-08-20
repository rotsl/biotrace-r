# biotrace

[![R-universe status](https://rotsl.r-universe.dev/badges/biotrace)](https://rotsl.r-universe.dev/biotrace)
[![R CMD check](https://github.com/rotsl/biotrace-r/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/rotsl/biotrace-r/actions/workflows/R-CMD-check.yaml)
[![Documentation](https://github.com/rotsl/biotrace-r/actions/workflows/pages.yml/badge.svg)](https://rotsl.github.io/biotrace-r/)

`biotrace` is the R integration package for the BioTrace GitHub Action. BioTrace traces biological results from data and code to figures and scientific claims. It runs as a GitHub Action, referenced by `uses: rotsl/biotrace@v1` in a workflow file.

This package does not ship or run the upstream TypeScript engine. The engine runs only through GitHub. The R package contains configuration helpers, a workflow scaffolder, a report reader, and a command line interface.

## Package structure

```
rotsl/biotrace       upstream GitHub Action, unchanged
        |
        v   uses: rotsl/biotrace@v1
        |
rotsl/biotrace-r     R package: R API + CLI + integration helpers
        |
        v
        |
rotsl/rotsl.r-universe.dev    R-universe registry
```

The package is split into four layers:

- Configuration helpers write and validate the BioTrace YAML config file.
- Workflow scaffolding writes the GitHub workflow YAML that calls the upstream Action.
- Report readers parse the JSON report the Action produces.
- A GitHub helper can trigger or inspect an existing BioTrace workflow.

The upstream BioTrace Action is an external dependency. The package does not modify it, vendor its source code, or run it locally.

## Installation

Install the production version from R-universe:

```r
install.packages(
  "biotrace",
  repos = c(
    "https://rotsl.r-universe.dev",
    "https://cloud.r-project.org"
  )
)
```

The tagged source is also available from GitHub:

```r
# install.packages("pak")
pak::pak("rotsl/biotrace-r@v0.1.0")
```

## Quick start

```r
library(biotrace)

# Initialise .github/biotrace.yml and .github/workflows/biotrace.yml
use_biotrace()

# Validate a configuration file
validate_biotrace_config(".github/biotrace.yml")

# Read a BioTrace JSON report
report <- read_biotrace_report(
  system.file("extdata", "example-report.json", package = "biotrace")
)
print(report)
summary(report)
```

## Command line interface

After installation, the `biotrace` command is on `PATH`:

```sh
biotrace --help
biotrace --version
biotrace init
biotrace config validate .github/biotrace.yml
biotrace report biotrace-report.json
biotrace github run --repo rotsl/biotrace-r --action trigger --dry-run
```

The CLI does not provide a `biotrace check` subcommand. There is no local execution of the upstream TypeScript engine in this package, so a `check` command would be misleading. The closest equivalent is `biotrace github run`, which talks to GitHub.

## Scope

- The package does not run the upstream BioTrace TypeScript engine locally.
- The package does not modify `rotsl/biotrace`.
- Generated workflows do not contain GitHub tokens. The default workflow uses `${{ github.token }}`, which GitHub Actions substitutes at run time.
- Package functions do not push commits, open pull requests, or create GitHub repositories.

## Upstream

The upstream BioTrace Action lives at <https://github.com/rotsl/biotrace>.

The R integration package lives at <https://github.com/rotsl/biotrace-r>.

## License

Apache License (>= 2). See `LICENSE` for the full text. The upstream BioTrace Action is also Apache 2.0.
