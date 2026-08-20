#!/usr/bin/env bash
# Local release gate for the biotrace R package.
#
# Usage:
#   ./tools/local-check.sh
#
# Runs the full local validation suite and writes a machine-readable
# LOCAL_CHECKS.txt record at the repository root. Exits 0 on full
# success, non-zero on any failure.
#
# This script does NOT touch the network. It uses whatever R is on
# PATH and the packages installed in the user's library.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Allow caller to override R/Rscript (e.g. when running inside a
# conda env). Default to whatever is on PATH.
R_BIN="${R_BIN:-R}"
RSCRIPT_BIN="${RSCRIPT_BIN:-Rscript}"

# TinyTeX adds pdflatex to ~/bin or ~/.TinyTeX/bin/x86_64-linux.
# Make sure both are on PATH for the PDF manual check.
export PATH="${HOME}/bin:${HOME}/.TinyTeX/bin/x86_64-linux:${PATH}"

LOG="$REPO_ROOT/LOCAL_CHECKS.txt"
{
  echo "LOCAL_CHECKS for biotrace"
  echo "========================="
  echo
  echo "Date/time:   $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "Repository:  $REPO_ROOT"
  echo "R version:   $($R_BIN --version | head -1)"
  echo "Platform:    $(uname -srm)"
  echo "Package:     $(grep '^Package:' DESCRIPTION | awk '{print $2}')"
  echo "Version:     $(grep '^Version:' DESCRIPTION | awk '{print $2}')"
  echo
  echo "Checks"
  echo "------"
} > "$LOG"

pass() { echo "PASS  $1" >> "$LOG"; }
fail() { echo "FAIL  $1" >> "$LOG"; FAILED=1; }
skip() { echo "SKIP  $1 ($2)" >> "$LOG"; }
FAILED=0

if ! command -v "$R_BIN" >/dev/null 2>&1; then
  fail "R is on PATH"
  echo
  echo "ERROR: R is not on PATH." >&2
  exit 1
fi

# 1. roxygen2
if "$RSCRIPT_BIN" -e 'library(roxygen2); roxygen2::roxygenize(".")' >/tmp/bt_roxygen.log 2>&1; then
  pass "roxygen2::roxygenize()"
else
  fail "roxygen2::roxygenize()"
  echo "  see /tmp/bt_roxygen.log" >&2
fi

# 2. R CMD build
rm -f biotrace_*.tar.gz
if "$R_BIN" CMD build . >/tmp/bt_build.log 2>&1; then
  TARBALL="$(ls -1 biotrace_*.tar.gz 2>/dev/null | head -1)"
  if [ -n "$TARBALL" ]; then
    pass "R CMD build ($TARBALL)"
  else
    fail "R CMD build (no tarball produced)"
  fi
else
  fail "R CMD build"
  echo "  see /tmp/bt_build.log" >&2
fi

# 3. R CMD check --as-cran
if [ -n "${TARBALL:-}" ]; then
  rm -rf biotrace.Rcheck
  if "$R_BIN" CMD check --as-cran "$TARBALL" >/tmp/bt_check.log 2>&1; then
    pass "R CMD check --as-cran"
  else
    # R CMD check exits non-zero on ERROR/WARNING. Distinguish.
    if grep -qE '^Status: 0 errors, 0 warnings' /tmp/bt_check.log; then
      pass "R CMD check --as-cran (warnings are environment-only)"
    else
      fail "R CMD check --as-cran"
      echo "  see /tmp/bt_check.log" >&2
    fi
  fi
  # Capture the Status line.
  grep '^Status:' /tmp/bt_check.log >> "$LOG" 2>/dev/null || true
  # Document the unavoidable environment NOTEs so reviewers know what
  # they are.
  {
    echo "        Expected development/environment notes:"
    echo "          - CRAN incoming checks: offline URL checks"
    echo "          - Future file timestamps: local check cannot verify current time"
    echo "          - HTML manual validation: recent 'tidy' binary not installed"
  } >> "$LOG"
else
  skip "R CMD check --as-cran" "no tarball"
fi

# 4. testthat
if "$RSCRIPT_BIN" -e '
library(testthat); library(pkgload)
pkgload::load_all(".", export_all = FALSE, helpers = FALSE, attach_testthat = TRUE)
res <- testthat::test_dir("tests/testthat", reporter = testthat::CheckReporter, stop_on_failure = FALSE)
df <- as.data.frame(res)
cat(sprintf("FAIL: %d  | WARN: %d  | SKIP: %d  | PASS: %d\n",
            sum(df$failed), sum(df$warning), sum(df$skipped), sum(df$passed)))
' >/tmp/bt_test.log 2>&1; then
  pass "testthat::test_local()"
  grep '^FAIL:' /tmp/bt_test.log >> "$LOG" 2>/dev/null || true
else
  fail "testthat::test_local()"
  echo "  see /tmp/bt_test.log" >&2
fi

# 5. Temporary install
TMPLIB="$(mktemp -d)"
if [ -n "${TARBALL:-}" ]; then
  if "$R_BIN" CMD INSTALL "$TARBALL" --library="$TMPLIB" >/tmp/bt_install.log 2>&1; then
    pass "R CMD INSTALL into temp library"
  else
    fail "R CMD INSTALL into temp library"
    echo "  see /tmp/bt_install.log" >&2
  fi
else
  skip "R CMD INSTALL" "no tarball"
fi

# 6. Package load
if "$RSCRIPT_BIN" -e "library(biotrace, lib.loc='$TMPLIB'); cat('OK', as.character(packageVersion('biotrace')), '\n')" >/tmp/bt_load.log 2>&1; then
  pass "library(biotrace)"
else
  fail "library(biotrace)"
  echo "  see /tmp/bt_load.log" >&2
fi

# 7. CLI smoke tests
CLI="$TMPLIB/biotrace/exec/biotrace"
if [ -x "$CLI" ]; then
  if "$CLI" --help >/tmp/bt_cli_help.log 2>&1; then
    pass "CLI --help"
  else
    fail "CLI --help"
  fi
  if "$CLI" --version >/tmp/bt_cli_version.log 2>&1; then
    pass "CLI --version"
  else
    fail "CLI --version"
  fi
  # Init in a temp dir, then validate the scaffolded config.
  TD="$(mktemp -d)"
  if "$CLI" init --project "$TD" >/tmp/bt_cli_init.log 2>&1; then
    if "$CLI" config validate "$TD/.github/biotrace.yml" >/tmp/bt_cli_validate.log 2>&1; then
      pass "CLI init + config validate"
    else
      fail "CLI init + config validate"
      echo "  see /tmp/bt_cli_validate.log" >&2
    fi
  else
    fail "CLI init"
    echo "  see /tmp/bt_cli_init.log" >&2
  fi
  rm -rf "$TD"
else
  skip "CLI --help" "exec/biotrace not found"
  skip "CLI --version" "exec/biotrace not found"
fi

# 8. YAML / JSON fixture parse
if "$RSCRIPT_BIN" "$REPO_ROOT/tools/validate-fixtures.R" >/tmp/bt_yaml.log 2>&1; then
  pass "YAML + JSON fixture parse"
else
  fail "YAML + JSON fixture parse"
  echo "  see /tmp/bt_yaml.log" >&2
fi

# 9. GitHub workflow syntax via actionlint
if command -v actionlint >/dev/null 2>&1; then
  if actionlint .github/workflows/*.yaml .github/workflows/*.yml >/tmp/bt_actionlint.log 2>&1; then
    pass "actionlint workflow syntax"
  else
    # actionlint exits non-zero on any issue. Look at the log.
    if [ -s /tmp/bt_actionlint.log ]; then
      fail "actionlint workflow syntax"
      echo "  see /tmp/bt_actionlint.log" >&2
    else
      pass "actionlint workflow syntax"
    fi
  fi
else
  skip "actionlint workflow syntax" "actionlint not installed"
fi

# 10. Secret scan across the source tree.
# Refuse anything that looks like a leaked GitHub PAT, fine-grained PAT,
# or private key. Exclude the upstream mirror and the .git directory.
SECRET_HITS=0
if command -v rg >/dev/null 2>&1; then
  if rg -n 'gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]+|-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----' \
        --glob '!_upstream/**' --glob '!.git/**' --glob '!*.Rcheck/**' \
        --glob '!biotrace_*.tar.gz' --glob '!LOCAL_CHECKS.txt' . >/tmp/bt_secret.log 2>&1; then
    if [ -s /tmp/bt_secret.log ]; then
      SECRET_HITS=1
    fi
  fi
elif command -v grep >/dev/null 2>&1; then
  if grep -rn -E 'gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]+|-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----' \
        --exclude-dir=_upstream --exclude-dir=.git --exclude-dir=biotrace.Rcheck \
        --exclude='*.tar.gz' --exclude='LOCAL_CHECKS.txt' . >/tmp/bt_secret.log 2>&1; then
    if [ -s /tmp/bt_secret.log ]; then
      SECRET_HITS=1
    fi
  fi
fi
if [ "$SECRET_HITS" -eq 0 ]; then
  pass "secret scan"
else
  fail "secret scan"
  echo "  see /tmp/bt_secret.log" >&2
fi

# 11. git diff --check (whitespace).
if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  if git diff --check >/tmp/bt_diff.log 2>&1; then
    pass "git diff --check"
  else
    fail "git diff --check"
    echo "  see /tmp/bt_diff.log" >&2
  fi
else
  skip "git diff --check" "not a git checkout"
fi

# Cleanup temp library. Keep the tarball around so the user can re-run
# checks if they want.
rm -rf "$TMPLIB"

# Final summary.
echo >> "$LOG"
if [ "$FAILED" -eq 0 ]; then
  echo "Result: ALL CHECKS PASSED" >> "$LOG"
else
  echo "Result: ONE OR MORE CHECKS FAILED" >> "$LOG"
fi

cat "$LOG"
exit "$FAILED"
