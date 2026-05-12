********************************************************************
* run_all.do — master Stata driver for the empirical pipeline of
*              "Who Holds Government Debt?"
*
* Reproduces the four results tables in Subfiles/Empirical.tex
* (paper sections 6.3, 6.4, 6.5, 6.6) from the committed dataset
* Data/gfdd_with_de_facto1.dta. Run from the repository root:
*
*     stata -b do Code/empirical_debt_composition/run_all.do
*
* Stage map
* ---------
*   (1) threshold_estimation_default_trim.do
*         Hansen 1- and 2-threshold regressions for db_total / dcb /
*         dpb / dh on d with country FE.  Produces Section 6.3.
*         Self-contained; reloads the panel.
*
*   (2) twoway_cluster_full.do
*         Stage 1 (xtreg fe) extracts country-level structural sizes
*         delta_n_th, delta_cb_th, delta_pb_th using Dbar = 102.74851
*         from stage (1).  Stage 1 is also re-run with ivreg2 for
*         two-way clustered SEs (Section 6.4).  Stage 2 is a no-cons
*         OLS with two-way clustering (Section 6.5).  MUST share a
*         Stata session with stage (3) is NOT required: each stage
*         re-loads the panel.
*
*   (3) quadratic_nonbank_fullsample.do
*         Concavity / pecking-order specs for dh and df, plus the
*         all-sectors quadratic / threshold debt-allocation block.
*         Produces Section 6.6 and the appendix material.
*         Self-contained.
*
* Reviewers without Stata: see Code/empirical_debt_composition/python/
* for the equivalent Python pipeline (`run_all.py`); both write to
* Code/empirical_debt_composition/results/.
********************************************************************

version 17
clear all
set more off
capture log close _all

local DATA   "Data/gfdd_with_de_facto1.dta"
local DODIR  "Code/empirical_debt_composition/do"
local RESDIR "Code/empirical_debt_composition/results"

capture confirm file "`DATA'"
if _rc {
    display as error "run_all.do: cannot find `DATA'. Run from repo root."
    exit 601
}

capture mkdir "`RESDIR'"

log using "`RESDIR'/run_all.log", text replace

********************************************************************
* (1) Hansen threshold — Section 6.3
********************************************************************
use "`DATA'", clear
xtset country_id year
display _newline(2) "=== Stage 1/3: threshold_estimation_default_trim.do ==="
do "`DODIR'/threshold_estimation_default_trim.do"

********************************************************************
* (2) Two-way clustered two-stage estimator — Sections 6.4 + 6.5
********************************************************************
use "`DATA'", clear
xtset country_id year
display _newline(2) "=== Stage 2/3: twoway_cluster_full.do ==="
do "`DODIR'/twoway_cluster_full.do"

********************************************************************
* (3) Concavity + pecking order — Section 6.6
********************************************************************
use "`DATA'", clear
xtset country_id year
display _newline(2) "=== Stage 3/3: quadratic_nonbank_fullsample.do ==="
do "`DODIR'/quadratic_nonbank_fullsample.do"

capture log close _all

display _newline(2) "run_all.do: finished. See `RESDIR'/ for committed Stata logs."
