********************************************************************
* run_all.do — master driver for the empirical pipeline of
*              "Who Holds Government Debt?"
*
* This driver reproduces every regression reported in Subfiles/Empirical.tex
* from a single entry point. It must be run from the repository root so
* that the relative paths below resolve correctly, e.g.
*
*     cd /path/to/emma0502606
*     stata -b do Code/empirical_debt_composition/run_all.do
*
* It is also what reproduce.sh invokes when Stata is on PATH.
*
* Sequencing rationale
* --------------------
* The five ingredient .do files under do/ were written to be run
* interactively, one after another, on top of a panel already in memory.
* They therefore fall into two groups:
*
*   (A) State-chained pair (must share one session):
*         1. do/threshold_estimation.do
*              - builds delta_n_th / delta_cb_th / delta_pb_th and highD
*         2. do/threshold_integration_estimation.do
*              - consumes those deltas and highD to add de-facto /
*                cap100 interactions (paper Section 3 robustness)
*
*   (B) Self-contained scripts (each reloads a fresh panel):
*         3. do/threshold_estimation_centered.do
*              - centered-threshold variant; writes
*                results/threshold_centered_results.txt
*         4. do/threshold_estimation_noconstant.do
*              - noconstant variant; output goes to run_all.log
*         5. do/quadratic_nonbank_fullsample.do
*              - convexity + pecking-order; writes
*                results/quadratic_nonbank_results2.txt
*
* Reviewers without Stata: the two committed results/*.txt files are
* the exact outputs of stages (3) and (5). Running this driver on a
* machine with Stata 17+ reproduces them (modulo the log preamble).
********************************************************************

version 17
clear all
set more off
capture log close _all

local DATA   "Data/gfdd_with_de_facto1.dta"
local RESDIR "Code/empirical_debt_composition/results"

capture confirm file "`DATA'"
if _rc {
    display as error "run_all.do: cannot find `DATA'. Run from repo root."
    exit 601
}

capture mkdir "`RESDIR'"

log using "`RESDIR'/run_all.log", text replace

********************************************************************
* (A) Threshold two-stage + de-facto integration
*     These two scripts share session state and must run together.
********************************************************************
use "`DATA'", clear
xtset country_id year

display _newline(2) "=== Stage 1: threshold_estimation.do ==="
do "Code/empirical_debt_composition/do/threshold_estimation.do"

display _newline(2) "=== Stage 2: threshold_integration_estimation.do ==="
do "Code/empirical_debt_composition/do/threshold_integration_estimation.do"

********************************************************************
* (B) Self-contained variants. Each reloads a fresh panel so that it
*     does not inherit state from the stages above.
********************************************************************
use "`DATA'", clear
xtset country_id year

display _newline(2) "=== Stage 3: threshold_estimation_centered.do ==="
do "Code/empirical_debt_composition/do/threshold_estimation_centered.do"

use "`DATA'", clear
xtset country_id year

display _newline(2) "=== Stage 4: threshold_estimation_noconstant.do ==="
do "Code/empirical_debt_composition/do/threshold_estimation_noconstant.do"

use "`DATA'", clear
xtset country_id year

display _newline(2) "=== Stage 5: quadratic_nonbank_fullsample.do ==="
do "Code/empirical_debt_composition/do/quadratic_nonbank_fullsample.do"

capture log close _all

display _newline(2) "run_all.do: finished. See `RESDIR'/ for log and committed results."
