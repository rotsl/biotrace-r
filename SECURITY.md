# Security policy

## Reporting a vulnerability

Email `phonics-tiffs1i@icloud.com` with a description of the issue and, if possible, a minimal reproduction. Do not open a public GitHub issue for security reports.

Security reports receive an acknowledgement within 72 hours. High severity issues have a target response time of 30 days. Other issues follow the regular release schedule.

## Scope

This policy covers the `biotrace` R package and the `biotrace-r` repository. It does not cover the upstream BioTrace Action at <https://github.com/rotsl/biotrace>; report upstream issues through that repository's own security policy.

## Token handling

The package never writes GitHub tokens to disk. Generated workflows use `${{ github.token }}`, which GitHub Actions substitutes at run time. The `run_biotrace_github()` R function and the `biotrace github run` CLI command read tokens from environment variables only (`GITHUB_TOKEN` by default, with a fallback to `GH_TOKEN`). Tokens are never printed, never embedded into generated files, and never written to logs.

Suspected token exposure is treated as a security report. Repository checks scan the source tree for common credential formats.

## Supported versions

Security fixes apply to the latest release line.
