# biotrace

`biotrace` is an R interface for the [BioTrace GitHub Action](https://github.com/rotsl/biotrace). It creates BioTrace configuration and workflow files, validates configuration, reads JSON reports, and works with existing GitHub workflows through the GitHub REST API.

The package uses the published Action at `rotsl/biotrace@v1`. The TypeScript engine remains in the upstream Action and does not run inside the R package.

## Installation

The production package is available from R-universe:

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

## Package components

- Configuration functions read, write, and validate BioTrace YAML.
- Workflow functions create GitHub Actions files that call `rotsl/biotrace@v1`.
- Report functions parse and summarize BioTrace JSON output.
- GitHub functions build requests for workflow discovery, inspection, and dispatch.
- The installed `biotrace` executable exposes the same operations from a shell.

## Package links

- [R-universe package page](https://rotsl.r-universe.dev/biotrace)
- [Source repository](https://github.com/rotsl/biotrace-r)
- [Issue tracker](https://github.com/rotsl/biotrace-r/issues)
- [Upstream BioTrace Action](https://github.com/rotsl/biotrace)
