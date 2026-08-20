# Support

## Where to ask

- Bug reports and feature requests: <https://github.com/rotsl/biotrace-r/issues>
- Security reports: see `SECURITY.md` (do not use GitHub issues)
- Questions about the upstream BioTrace Action: <https://github.com/rotsl/biotrace/issues>

## Issue details

CLI reports are easier to reproduce with:

```sh
biotrace --version
biotrace --help
```

R API reports are easier to reproduce with:

```r
library(biotrace)
biotrace_version()
sessionInfo()
```

GitHub tokens do not belong in issue reports. Any output containing a token should be handled under the security policy.

## What is in scope

- The R package and its CLI
- The vendored JSON Schemas
- The integration workflow under `.github/workflows/biotrace.yml`
- Package builds published by R-universe

## What is not in scope

- The upstream BioTrace TypeScript engine. Report upstream issues to <https://github.com/rotsl/biotrace>.
- The `rotsl.r-universe.dev` registry itself. Report registry issues to <https://github.com/rotsl/rotsl.r-universe.dev>.
- Generic R, GitHub Actions, or git questions. Use the appropriate community support channels for those.
