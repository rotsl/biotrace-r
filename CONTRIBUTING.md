# Contributing to biotrace-r

Contributions to the R interface, documentation, and tests are welcome.

## Project scope

The upstream BioTrace Action at <https://github.com/rotsl/biotrace> is an external dependency. Changes in this repository cover the R package and its integration with `rotsl/biotrace@v1`. Changes to the Action belong in its own repository.

The package calls BioTrace through GitHub Actions. It does not contain a local copy of the TypeScript engine, so the CLI has no local `biotrace check` command.

## Contributions

Public R functions use roxygen2 documentation and have tests for successful and invalid input. Functions that write files preserve existing files unless `overwrite = TRUE`. Path arguments return plain character values.

CLI changes use the dispatcher in `R/cli.R` and document their syntax in `.cli_help_text()`. CLI tests call `biotrace:::biotrace_cli()` directly so they do not depend on an installed executable being present on `PATH`.

## Tests

The test suite is self contained. Network requests and GitHub responses use local test doubles. Files created during a test stay inside a temporary directory, and credentials are not required.

The repository check covers package documentation, `R CMD build`, `R CMD check --as-cran`, installation, CLI behavior, fixtures, workflow syntax, secrets, and whitespace.

## Pull requests

Pull requests target `main`. Continuous integration runs R CMD check on Linux, macOS, and Windows. Commit subjects use the imperative mood and remain under 72 characters.

## Code of conduct

This project follows the Contributor Covenant version 2.1. See `CODE_OF_CONDUCT.md`.
