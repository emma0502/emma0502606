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
#   ./reproduce.sh              # full reproduction: empirics + paper PDF
#   ./reproduce.sh --all        # alias for full reproduction
#   ./reproduce.sh --empirical  # Stata empirical pipeline only
#   ./reproduce.sh --docs       # compile the paper PDF only
#   ./reproduce.sh --help
#
# Scope of --all
# --------------
# "Full" here means: (a) the empirical pipeline under
# Code/empirical_debt_composition/ and (b) the paper compile.
#
# Part (a) requires Stata 17+ (proprietary). If Stata is not on PATH the
# empirical step is SKIPPED with a clear message, and the committed
# results/*.txt logs under Code/empirical_debt_composition/results/ are
# used as the authoritative record of the regressions. The paper compile
# does not consume those logs programmatically (numbers are transcribed
# into Subfiles/Empirical.tex), so --all still produces emma0502606.pdf
# identical to the committed copy when Stata is absent.
#
# This Stata dependency is the reason emma0502606 cannot be reproduced
# end-to-end inside the conda env declared in binder/environment.yml.
# Porting the regressions to Python (linearmodels) or R (fixest) is
# tracked as a follow-up in README.md under "Known limitations".

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

show_help() {
    cat <<'EOF'
./reproduce.sh — reproduction driver for "Who Holds Government Debt?"

Usage:
    ./reproduce.sh [--all]        Full reproduction: empirics + paper.
    ./reproduce.sh --empirical    Run only the Stata empirical pipeline
                                  (Code/empirical_debt_composition/run_all.do).
                                  Skipped with a clear message if Stata
                                  is not on PATH.
    ./reproduce.sh --docs         Compile the paper PDF only.
    ./reproduce.sh --help         Show this help.

Outputs:
    emma0502606.pdf                                  Main paper.
    Code/empirical_debt_composition/results/         Regression logs.

Environment:
    Stata:    17+ on PATH as stata-mp | stata-se | stata (for --empirical).
              If absent, the committed results/*.txt logs are used.
    Python:   declared in pyproject.toml (installed via `uv sync`)
              or binder/environment.yml (for Binder / conda).
    LaTeX:    TeX Live 2023+ with packages listed in
              reproduce/required_latex_packages.txt.
EOF
}

log_info()    { echo "[reproduce] $*"; }
log_success() { echo "[reproduce] OK  $*"; }
log_warn()    { echo "[reproduce] WARN $*"; }
log_error()   { echo "[reproduce] ERR $*" >&2; }

find_stata() {
    # Print the first available Stata binary on PATH, else empty.
    for b in stata-mp stata-se stata; do
        if command -v "$b" >/dev/null 2>&1; then
            echo "$b"
            return 0
        fi
    done
    return 1
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
        # -b = batch mode; Stata writes <script>.log next to the driver.
        "$stata_bin" -b do "$driver"
        log_success "Empirical pipeline finished."
        log_info "See Code/empirical_debt_composition/results/ for logs."
    else
        log_warn "Stata not on PATH (looked for stata-mp / stata-se / stata)."
        log_warn "Skipping empirical pipeline."
        log_info "Using committed logs in Code/empirical_debt_composition/results/"
        log_info "  * threshold_centered_results.txt"
        log_info "  * quadratic_nonbank_results2.txt"
        log_info "These are the authoritative regression output for this paper."
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
    log_info "Running full reproduction (empirics + paper)."
    run_empirical
    run_docs
    log_success "Full reproduction finished."
}

MODE="all"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)    show_help; exit 0 ;;
        --docs)       MODE="docs";      shift ;;
        --empirical)  MODE="empirical"; shift ;;
        --all)        MODE="all";       shift ;;
        *)            log_error "Unknown option: $1"; show_help; exit 2 ;;
    esac
done

case "$MODE" in
    docs)       run_docs ;;
    empirical)  run_empirical ;;
    all)        run_all ;;
esac
