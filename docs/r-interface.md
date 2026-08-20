# R interface

## Project files

`use_biotrace()` creates `.github/biotrace.yml` and `.github/workflows/biotrace.yml`. Existing files are preserved unless `overwrite = TRUE`.

```r
library(biotrace)
use_biotrace()
```

Configuration can also be handled directly:

```r
config <- default_biotrace_config()
write_biotrace_config(".github/biotrace.yml", config)
read_biotrace_config(".github/biotrace.yml")
validate_biotrace_config(".github/biotrace.yml")
```

## Workflows

`biotrace_workflow_text()` returns workflow YAML without writing a file. `write_biotrace_workflow()` writes the same content to disk.

```r
cat(biotrace_workflow_text(), sep = "\n")
write_biotrace_workflow(".github/workflows/biotrace.yml")
```

## Reports

BioTrace reports are represented by the `biotrace_report` S3 class. Print and summary methods provide a compact view of status, score, and findings.

```r
report <- read_biotrace_report("biotrace-report.json")
print(report)
summary(report)
validate_biotrace_report("biotrace-report.json")
```

## GitHub workflows

`run_biotrace_github()` can list workflows, list recent runs, or dispatch an existing workflow. Dry-run mode returns the request without sending it.

```r
request <- run_biotrace_github(
  "owner/repository",
  action = "trigger",
  dry_run = TRUE
)
```

Live requests read credentials from `GITHUB_TOKEN`, `GH_TOKEN`, or an environment variable named by `token_env`. Tokens are not stored in generated files.
