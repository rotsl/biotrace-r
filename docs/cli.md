# Command line interface

The installed package includes a `biotrace` executable. It calls the same R functions exposed by the package API.

```text
biotrace --help
biotrace --version
```

## Configuration and workflow files

```text
biotrace init
biotrace config print
biotrace config validate .github/biotrace.yml
biotrace workflow print
biotrace workflow write .github/workflows/biotrace.yml
```

## Reports

```text
biotrace report biotrace-report.json
```

## GitHub integration

```text
biotrace github run --repo owner/repository --action list-workflows
biotrace github run --repo owner/repository --action list-runs
biotrace github run --repo owner/repository --action trigger --dry-run
```

The CLI validates local configuration and report files. BioTrace itself runs in GitHub Actions, so the CLI does not reproduce the TypeScript engine locally.
