# Package metadata

| Field | Value |
| --- | --- |
| Package | `biotrace` |
| Version | `0.1.0` |
| Author and maintainer | Rohan R |
| ORCID | [0009-0005-9225-1775](https://orcid.org/0009-0005-9225-1775) |
| License | Apache License 2.0 or later |
| R version | R 3.6 or later |
| Upstream Action | `rotsl/biotrace@v1` |

## Runtime dependencies

- `fs` handles paths and file operations.
- `jsonlite` reads reports and GitHub responses.
- `rlang` provides structured conditions.
- `yaml` reads and writes configuration and workflow files.

The installed command line interface requires `Rscript` on `PATH`. Node.js and TypeScript are not package system requirements.

## Included reference files

The package includes verbatim copies of the upstream configuration and report JSON Schemas under `inst/extdata/schemas/`. They are distributed under the same Apache 2.0 license as the upstream BioTrace Action.
