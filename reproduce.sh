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
#   ./reproduce.sh            # full reproduction (currently: docs only)
#   ./reproduce.sh --docs     # compile the paper PDF only
#   ./reproduce.sh --all      # alias for full reproduction
#   ./reproduce.sh --help
#
# Status: the empirical regression pipeline that produces the tables and
# figures in Subfiles/Empirical.tex is being migrated into this repo under
# Code/empirical_debt_composition/ and is not yet driven from this script.
# Until then --all only compiles the paper from its committed tables and
# committed figure PDFs. See "Known follow-ups" in README.md.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

show_help() {
    cat <<'EOF'
./reproduce.sh — reproduction driver for "Who Holds Government Debt?"

Usage:
    ./reproduce.sh [--all]        Run the full reproduction.
                                  (Currently: compile the paper only.
                                  Empirical regression pipeline is a
                                  known follow-up; see README.md.)
    ./reproduce.sh --docs         Compile the paper PDF only.
    ./reproduce.sh --help         Show this help.

Outputs:
    emma0502606.pdf               Main paper.

Environment:
    Python:   declared in pyproject.toml (installed via `uv sync`)
              or binder/environment.yml (for Binder / conda).
    LaTeX:    TeX Live 2023+ with packages listed in
              reproduce/required_latex_packages.txt.
EOF
}

log_info()    { echo "[reproduce] $*"; }
log_success() { echo "[reproduce] OK  $*"; }
log_error()   { echo "[reproduce] ERR $*" >&2; }

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
    # Future: run_empirical (Code/empirical_debt_composition/) then run_docs.
    # For now the only step is run_docs, because the empirical pipeline is
    # not yet committed. This is tracked as a known follow-up in README.md.
    log_info "Running full reproduction."
    log_info "NOTE: empirical regression pipeline is a known follow-up."
    log_info "      This run compiles the paper from its committed tables."
    run_docs
    log_success "Full reproduction finished."
}

MODE="all"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)  show_help; exit 0 ;;
        --docs)     MODE="docs"; shift ;;
        --all)      MODE="all";  shift ;;
        *)          log_error "Unknown option: $1"; show_help; exit 2 ;;
    esac
done

case "$MODE" in
    docs) run_docs ;;
    all)  run_all ;;
esac
