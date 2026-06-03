****************************************************
* THRESHOLD ESTIMATION (Hansen 2000) -- DEFAULT TRIM
*
* Same as threshold_estimation.do but with NO `trim()'
* option. Stata's `threshold' command then uses its
* default trimming (10% per tail of the threshold
* variable), which is also what Jeanne (2025) Tab_thresreg.do
* uses (no trim() specified there either).
*
* Why default trim?
*   - Default = standard convention in Hansen (2000).
*   - Matches Jeanne's pooled specification exactly.
*   - Less aggressive than trim(5); more stable Dbar
*     when the criterion function is flat near the tails.
*
* Variables expected in memory (same as twoway_cluster_full.do):
*   country_id, year, d, dh, dcb, dpb
****************************************************

capture log close
log using "Code/empirical_debt_composition/results/threshold_estimation_default_trim.txt", text replace

xtset country_id year

capture drop db_total
gen double db_total = dcb + dpb

xtset, clear

****************************************************
* (1) BANKING TOTAL (dcb + dpb) -- HEADLINE
****************************************************
di _newline(3) "=========================================="
di "  THRESHOLD 1/4: db_total = dcb + dpb (banking)"
di "=========================================="

di _newline(1) "--- (1a) NO threshold (linear baseline, regress) ---"
regress db_total d i.country_id if !missing(db_total, d)
estat ic
matrix ic_db_0 = r(S)
scalar bic_db_0 = ic_db_0[1, 6]

di _newline(1) "--- (1b) ONE threshold ---"
threshold db_total i.country_id if !missing(db_total, d), ///
    threshvar(d) regionvars(d) nthresholds(1)
scalar bic_db_1 = e(bic)

di _newline(1) "--- (1c) TWO thresholds ---"
cap noi threshold db_total i.country_id if !missing(db_total, d), ///
    threshvar(d) regionvars(d) nthresholds(2)
if _rc == 0  scalar bic_db_2 = e(bic)
else         scalar bic_db_2 = .

di _newline(1) "--- BIC comparison for db_total (lower = better) ---"
di "  0 thr : BIC = " bic_db_0
di "  1 thr : BIC = " bic_db_1
di "  2 thr : BIC = " bic_db_2

****************************************************
* (2) CENTRAL BANK ONLY (dcb)
****************************************************
di _newline(3) "=========================================="
di "  THRESHOLD 2/4: dcb (central bank)"
di "=========================================="

di _newline(1) "--- (2a) NO threshold ---"
regress dcb d i.country_id if !missing(dcb, d)
estat ic
matrix ic_cb_0 = r(S)
scalar bic_cb_0 = ic_cb_0[1, 6]

di _newline(1) "--- (2b) ONE threshold ---"
threshold dcb i.country_id if !missing(dcb, d), ///
    threshvar(d) regionvars(d) nthresholds(1)
scalar bic_cb_1 = e(bic)

di _newline(1) "--- (2c) TWO thresholds ---"
cap noi threshold dcb i.country_id if !missing(dcb, d), ///
    threshvar(d) regionvars(d) nthresholds(2)
if _rc == 0  scalar bic_cb_2 = e(bic)
else         scalar bic_cb_2 = .

di _newline(1) "--- BIC comparison for dcb ---"
di "  0 thr : BIC = " bic_cb_0
di "  1 thr : BIC = " bic_cb_1
di "  2 thr : BIC = " bic_cb_2

****************************************************
* (3) PRIVATE BANK ONLY (dpb)
****************************************************
di _newline(3) "=========================================="
di "  THRESHOLD 3/4: dpb (private bank)"
di "=========================================="

di _newline(1) "--- (3a) NO threshold ---"
regress dpb d i.country_id if !missing(dpb, d)
estat ic
matrix ic_pb_0 = r(S)
scalar bic_pb_0 = ic_pb_0[1, 6]

di _newline(1) "--- (3b) ONE threshold ---"
threshold dpb i.country_id if !missing(dpb, d), ///
    threshvar(d) regionvars(d) nthresholds(1)
scalar bic_pb_1 = e(bic)

di _newline(1) "--- (3c) TWO thresholds ---"
cap noi threshold dpb i.country_id if !missing(dpb, d), ///
    threshvar(d) regionvars(d) nthresholds(2)
if _rc == 0  scalar bic_pb_2 = e(bic)
else         scalar bic_pb_2 = .

di _newline(1) "--- BIC comparison for dpb ---"
di "  0 thr : BIC = " bic_pb_0
di "  1 thr : BIC = " bic_pb_1
di "  2 thr : BIC = " bic_pb_2

****************************************************
* (4) NON-BANK (dh) -- PLACEBO
*     Theory says non-banks have a *cap*, not a kink.
****************************************************
di _newline(3) "=========================================="
di "  THRESHOLD 4/4: dh (non-bank, placebo)"
di "=========================================="

di _newline(1) "--- (4a) NO threshold ---"
regress dh d i.country_id if !missing(dh, d)
estat ic
matrix ic_h_0 = r(S)
scalar bic_h_0 = ic_h_0[1, 6]

di _newline(1) "--- (4b) ONE threshold ---"
threshold dh i.country_id if !missing(dh, d), ///
    threshvar(d) regionvars(d) nthresholds(1)
scalar bic_h_1 = e(bic)

di _newline(1) "--- BIC comparison for dh ---"
di "  0 thr : BIC = " bic_h_0
di "  1 thr : BIC = " bic_h_1

****************************************************
* SUMMARY
****************************************************
di _newline(3) "=========================================="
di "  SUMMARY OF BIC (lower = better)"
di "=========================================="
di "  Outcome      0 thr            1 thr            2 thr"
di "  db_total  " bic_db_0 "   " bic_db_1 "   " bic_db_2
di "  dcb       " bic_cb_0 "   " bic_cb_1 "   " bic_cb_2
di "  dpb       " bic_pb_0 "   " bic_pb_1 "   " bic_pb_2
di "  dh        " bic_h_0  "   " bic_h_1  "   ."

xtset country_id year

log close
