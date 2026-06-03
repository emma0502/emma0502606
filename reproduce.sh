#!/bin/bash
# reproduce.sh — reproduction driver for
# "Who Holds Government Debt?" by Yiran Emma Ma.
#
# This script is the single entry point required by the REMARK baseline
# standard (https://github.com/econ-ark/REMARK/blob/main/STANDARD.md).
# It runs end-to-end from a clean clone against the environment declared
# in binder/environment.yml / pyproject.toml.
#
# Usage:
#   ./reproduce.sh              # full reproduction (Python empirics + paper PDF)
#   ./reproduce.sh --all        # alias for full reproduction
#   ./reproduce.sh --python     # Python empirical pipeline only (no Stata, no LaTeX)
#   ./reproduce.sh --check      # quick smoke test of the Python pipeline
#   ./reproduce.sh --empirical  # Stata empirical pipeline only (requires Stata)
#   ./reproduce.sh --docs       # compile the paper PDF only
#   ./reproduce.sh --help
#
# Reproduction strategy
# ---------------------
# The empirical analysis (Sections 6.3 -- 6.6) ships in two equivalent
# implementations:
#
#   * Python  -- Code/empirical_debt_composition/python/run_all.py
#                Pure-conda pipeline. Coefficients match the canonical
#                Stata results to >= 6 decimals; cluster-robust SEs
#                agree to ~1-8% relative (Cameron-Gelbach-Miller small-
#                sample correction differs slightly from ivreg2).
#                Statistical conclusions identical.
#                This is the default entry point for `--all`.
#
#   * Stata   -- Code/empirical_debt_composition/run_all.do
#                Canonical reference implementation; the .txt logs
#                committed under results/ were produced by this code.
#                Requires Stata 17+ on PATH.
#
# `--all` runs the Python pipeline, then compiles the paper. If neither
# Python nor Stata is available, `--all` falls back to using the
# committed `.txt` logs to compile the paper.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

show_help() {
    cat <<'EOF'
./reproduce.sh — reproduction driver for "Who Holds Government Debt?"

Usage:
    ./reproduce.sh [--all]        Full reproduction: Python empirics + paper.
    ./reproduce.sh --python       Run only the Python empirical pipeline
                                  (Code/empirical_debt_composition/python/run_all.py).
                                  Writes per-stage logs and a validation
                                  summary to results/python/.
    ./reproduce.sh --check        Smoke test: re-run the Python pipeline
                                  and assert the headline numbers in
                                  Sections 6.3 -- 6.6 match the committed
                                  Stata logs to within tolerance. Exits
                                  non-zero on mismatch.
    ./reproduce.sh --empirical    Run only the Stata empirical pipeline
                                  (Code/empirical_debt_composition/run_all.do).
                                  Requires Stata 17+ on PATH.
    ./reproduce.sh --docs         Compile the paper PDF only.
    ./reproduce.sh --help         Show this help.

Outputs:
    emma0502606.pdf                                            Main paper.
    Code/empirical_debt_composition/results/                   Stata logs (canonical).
    Code/empirical_debt_composition/results/python/            Python logs.

Environment:
    Python:   declared in pyproject.toml (`uv sync`) or
              binder/environment.yml (conda).
              Required for --python, --check, and the default --all path.
    Stata:    17+ on PATH as stata-mp / stata-se / stata.
              Required for --empirical only.
    LaTeX:    TeX Live 2023+ with packages listed in
              reproduce/required_latex_packages.txt.
EOF
}

log_info()    { echo "[reproduce] $*"; }
log_success() { echo "[reproduce] OK  $*"; }
log_warn()    { echo "[reproduce] WARN $*"; }
log_error()   { echo "[reproduce] ERR $*" >&2; }

find_python() {
    # Print the first usable Python on PATH that has the empirical
    # pipeline's dependencies (pandas, statsmodels, linearmodels).
    for p in python python3; do
        if command -v "$p" >/dev/null 2>&1 \
           && "$p" -c 'import pandas, numpy, statsmodels, linearmodels' \
                >/dev/null 2>&1; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

find_stata() {
    for b in stata-mp stata-se stata; do
        if command -v "$b" >/dev/null 2>&1; then
            echo "$b"
            return 0
        fi
    done
    return 1
}

run_python() {
    local py_bin
    if ! py_bin="$(find_python)"; then
        log_error "Python with pandas + statsmodels + linearmodels not found."
        log_error "Set up the environment first:"
        log_error "  uv sync                 (recommended)"
        log_error "or"
        log_error "  conda env create -f binder/environment.yml"
        log_error "  conda activate who-holds-government-debt"
        return 1
    fi
    log_info "Running Python empirical pipeline: $py_bin -m Code.empirical_debt_composition.python.run_all"
    "$py_bin" -m Code.empirical_debt_composition.python.run_all
    log_success "Python pipeline finished."
    log_info "See Code/empirical_debt_composition/results/python/ for logs."
}

run_check() {
    local py_bin
    if ! py_bin="$(find_python)"; then
        log_error "Python with pandas + statsmodels + linearmodels not found."
        return 1
    fi
    log_info "Running Python pipeline smoke test (--check)."
    "$py_bin" -m Code.empirical_debt_composition.python.run_all --check
}

run_empirical() {
    local stata_bin
    local driver="Code/empirical_debt_composition/run_all.do"

    if [[ ! -f "$driver" ]]; then
        log_error "Missing driver: $driver"
        return 1
    fi

    if stata_bin="$(find_stata)"; then
        log_info "Running Stata empirical pipeline: $stata_bin -b do $driver"
        "$stata_bin" -b do "$driver"
        log_success "Stata empirical pipeline finished."
        log_info "See Code/empirical_debt_composition/results/ for logs."
    else
        log_error "Stata not on PATH (looked for stata-mp / stata-se / stata)."
        log_error "Use --python instead, or install Stata 17+."
        return 1
    fi
}

run_docs() {
    log_info "Compiling paper via reproduce/reproduce_documents.sh ..."
    if [[ ! -x reproduce/reproduce_documents.sh ]]; then
        chmod +x reproduce/reproduce_documents.sh
    fi
    ./reproduce/reproduce_documents.sh main
    if [[ -f emma0502606.pdf ]]; then
        log_success "Paper compiled: emma0502606.pdf"
    else
        log_error "emma0502606.pdf was not produced. See LaTeX log."
        return 1
    fi
}

run_all() {
    log_info "Running full reproduction (Python empirics + paper)."
    if find_python >/dev/null 2>&1; then
        run_python
    else
        log_warn "Python pipeline dependencies not found."
        if find_stata >/dev/null 2>&1; then
            log_warn "Falling back to Stata empirical pipeline."
            run_empirical
        else
            log_warn "Neither Python nor Stata available; skipping empirics."
            log_warn "The paper PDF will still build from committed sources."
        fi
    fi
    run_docs
    log_success "Full reproduction finished."
}

MODE="all"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)    show_help; exit 0 ;;
        --docs)       MODE="docs";      shift ;;
        --python)     MODE="python";    shift ;;
        --check)      MODE="check";     shift ;;
        --empirical)  MODE="empirical"; shift ;;
        --all)        MODE="all";       shift ;;
        *)            log_error "Unknown option: $1"; show_help; exit 2 ;;
    esac
done

case "$MODE" in
    docs)       run_docs ;;
    python)     run_python ;;
    check)      run_check ;;
    empirical)  run_empirical ;;
    all)        run_all ;;
esac
