****************************************************
* THRESHOLD VERSION — CENTERED at d_bar = 100
* Two second-stage specifications:
*   Spec A (centered, no level shift)
*   Spec B (original uncentered + free highD level shift)
****************************************************

****************************************************
* Step 0: Panel setup & log output
****************************************************
capture log close
log using "Code/empirical_debt_composition/results/threshold_centered_results.txt", text replace

xtset country_id year

****************************************************
* Step 1: Create threshold dummy & centered variable
****************************************************
capture drop highD d_high_c
gen highD = d > 100 if !missing(d)
gen double d_high_c = highD * (d - 100)

****************************************************
* Step 2: First stage with CENTERED threshold
* s_ijt = delta_ij + delta_jt + a1_j*d_it
*       + a2_j*[highD*(d_it - 100)] + u_ijt
****************************************************

* Non-bank size
capture drop delta_n_hat_th delta_n_th
xtreg nonbank_size c.d c.d_high_c i.year, fe vce(cluster country_id)
predict double delta_n_hat_th if e(sample), u
bys country_id: egen double delta_n_th = mean(delta_n_hat_th)

* Central bank size
capture drop delta_cb_hat_th delta_cb_th
xtreg cb_size c.d c.d_high_c i.year, fe vce(cluster country_id)
predict double delta_cb_hat_th if e(sample), u
bys country_id: egen double delta_cb_th = mean(delta_cb_hat_th)

* Private bank size
capture drop delta_pb_hat_th delta_pb_th
xtreg di02 c.d c.d_high_c i.year, fe vce(cluster country_id)
predict double delta_pb_hat_th if e(sample), u
bys country_id: egen double delta_pb_th = mean(delta_pb_hat_th)

****************************************************
* Step 2B: Report country-level structural sizes
****************************************************
di _newline(3) "=========================================="
di "  STRUCTURAL SIZES (delta_ij) by country"
di "=========================================="

capture drop _tag_country
bys country_id: gen _tag_country = _n == 1
list country_id delta_n_th delta_cb_th delta_pb_th if _tag_country == 1, sep(0) noobs
drop _tag_country

****************************************************
* Step 3: Create interaction terms
****************************************************
capture drop delta_n_th_d delta_cb_th_d delta_pb_th_d
gen double delta_n_th_d  = delta_n_th  * d
gen double delta_cb_th_d = delta_cb_th * d
gen double delta_pb_th_d = delta_pb_th * d

* Centered highD interactions (for Spec A)
capture drop delta_n_th_dhc delta_cb_th_dhc delta_pb_th_dhc
gen double delta_n_th_dhc  = delta_n_th  * d_high_c
gen double delta_cb_th_dhc = delta_cb_th * d_high_c
gen double delta_pb_th_dhc = delta_pb_th * d_high_c

* Uncentered highD interactions (for Spec B and C)
capture drop highD_d highD_delta_n highD_delta_cb highD_delta_pb
gen double highD_d         = highD * d
gen double highD_delta_n   = delta_n_th  * highD_d
gen double highD_delta_cb  = delta_cb_th * highD_d
gen double highD_delta_pb  = delta_pb_th * highD_d


****************************************************
* Step 4A: SPEC A — Centered, no constant, no level shift
*
* d^j = beta_j * d
*     + theta_j * (delta_ij * d)
*     + mu_j * [highD * (d - 100)]
*     + nu_j * [highD * delta_ij * (d - 100)]
****************************************************
di _newline(3) "=========================================="
di "  SPEC A: Centered, no constant"
di "=========================================="

* Non-bank
di _newline(2) "--- Non-bank (dh) — Spec A ---"
reg dh c.d c.delta_n_th_d c.d_high_c c.delta_n_th_dhc, nocons vce(cluster country_id)
capture drop dhhat_A
predict double dhhat_A if e(sample), xb

* Central bank
di _newline(2) "--- Central bank (dcb) — Spec A ---"
reg dcb c.d c.delta_cb_th_d c.d_high_c c.delta_cb_th_dhc, nocons vce(cluster country_id)
capture drop dcbhat_A
predict double dcbhat_A if e(sample), xb

* Private bank
di _newline(2) "--- Private bank (dpb) — Spec A ---"
reg dpb c.d c.delta_pb_th_d c.d_high_c c.delta_pb_th_dhc, nocons vce(cluster country_id)
capture drop dpbhat_A
predict double dpbhat_A if e(sample), xb

****************************************************
* Step 4B: SPEC B — Original uncentered + free highD
*   (Professor's approach 2: keep highD*d, add highD)
*
* d^j = beta_j * d
*     + theta_j * (delta_ij * d)
*     + lambda_j * highD
*     + mu_j * (highD * d)
*     + nu_j * (highD * delta_ij * d)
****************************************************
di _newline(3) "=========================================="
di "  SPEC B: Original uncentered + free highD (professor's approach 2)"
di "=========================================="

* Non-bank
di _newline(2) "--- Non-bank (dh) — Spec B ---"
reg dh c.d c.delta_n_th_d i.highD c.highD_d c.highD_delta_n, nocons vce(cluster country_id)
capture drop dhhat_B
predict double dhhat_B if e(sample), xb
estimates store specB_n

* Central bank
di _newline(2) "--- Central bank (dcb) — Spec B ---"
reg dcb c.d c.delta_cb_th_d i.highD c.highD_d c.highD_delta_cb, nocons vce(cluster country_id)
capture drop dcbhat_B
predict double dcbhat_B if e(sample), xb
estimates store specB_cb

* Private bank
di _newline(2) "--- Private bank (dpb) — Spec B ---"
reg dpb c.d c.delta_pb_th_d i.highD c.highD_d c.highD_delta_pb, nocons vce(cluster country_id)
capture drop dpbhat_B
predict double dpbhat_B if e(sample), xb
estimates store specB_pb

****************************************************
* Step 4C: SPEC C — No structural size (no delta)
*   Centered threshold, but without delta interactions
*
* d^j = beta_j * d
*     + mu_j * [highD * (d - 100)]
****************************************************
di _newline(3) "=========================================="
di "  SPEC C: No structural size (no delta interactions)"
di "=========================================="

* Non-bank
di _newline(2) "--- Non-bank (dh) — Spec C (no delta) ---"
reg dh c.d c.d_high_c, nocons vce(cluster country_id)
capture drop dhhat_C
predict double dhhat_C if e(sample), xb

* Central bank
di _newline(2) "--- Central bank (dcb) — Spec C (no delta) ---"
reg dcb c.d c.d_high_c, nocons vce(cluster country_id)
capture drop dcbhat_C
predict double dcbhat_C if e(sample), xb

* Private bank
di _newline(2) "--- Private bank (dpb) — Spec C (no delta) ---"
reg dpb c.d c.d_high_c, nocons vce(cluster country_id)
capture drop dpbhat_C
predict double dpbhat_C if e(sample), xb

****************************************************
* Step 6: Implied foreign debt residual (Spec A)
****************************************************
capture drop dfhat_A
gen double dfhat_A = d - dhhat_A - dcbhat_A - dpbhat_A ///
    if !missing(d, dhhat_A, dcbhat_A, dpbhat_A)

capture drop sample_A
gen sample_A = !missing(df, dfhat_A)

di _newline(3) "=========================================="
di "  FOREIGN DEBT FIT — Spec A (centered)"
di "=========================================="
summ df dfhat_A if sample_A==1
corr df dfhat_A if sample_A==1
reg df dfhat_A if sample_A==1, vce(cluster country_id)

capture drop df_error_A abs_df_error_A
gen double df_error_A     = df - dfhat_A     if sample_A==1
gen double abs_df_error_A = abs(df_error_A)  if sample_A==1
di _newline "Mean error and MAE (Spec A):"
summ df_error_A     if sample_A==1
summ abs_df_error_A if sample_A==1

****************************************************
* Step 7: Implied foreign debt residual (Spec B)
****************************************************
capture drop dfhat_B
gen double dfhat_B = d - dhhat_B - dcbhat_B - dpbhat_B ///
    if !missing(d, dhhat_B, dcbhat_B, dpbhat_B)

capture drop sample_B
gen sample_B = !missing(df, dfhat_B)

di _newline(3) "=========================================="
di "  FOREIGN DEBT FIT — Spec B (original + highD)"
di "=========================================="
summ df dfhat_B if sample_B==1
corr df dfhat_B if sample_B==1
reg df dfhat_B if sample_B==1, vce(cluster country_id)

capture drop df_error_B abs_df_error_B
gen double df_error_B     = df - dfhat_B     if sample_B==1
gen double abs_df_error_B = abs(df_error_B)  if sample_B==1
di _newline "Mean error and MAE (Spec B):"
summ df_error_B     if sample_B==1
summ abs_df_error_B if sample_B==1

****************************************************
* Step 7C: Implied foreign debt residual (Spec C)
****************************************************
capture drop dfhat_C
gen double dfhat_C = d - dhhat_C - dcbhat_C - dpbhat_C ///
    if !missing(d, dhhat_C, dcbhat_C, dpbhat_C)

capture drop sample_C
gen sample_C = !missing(df, dfhat_C)

di _newline(3) "=========================================="
di "  FOREIGN DEBT FIT — Spec C (no delta)"
di "=========================================="
summ df dfhat_C if sample_C==1
corr df dfhat_C if sample_C==1
reg df dfhat_C if sample_C==1, vce(cluster country_id)

capture drop df_error_C abs_df_error_C
gen double df_error_C     = df - dfhat_C     if sample_C==1
gen double abs_df_error_C = abs(df_error_C)  if sample_C==1
di _newline "Mean error and MAE (Spec C):"
summ df_error_C     if sample_C==1
summ abs_df_error_C if sample_C==1

****************************************************
* Step 8: Graph — Spec A
****************************************************
twoway ///
    (scatter df dfhat_A if sample_A==1, msize(small)) ///
    (lfit df dfhat_A if sample_A==1), ///
    xtitle("Predicted foreign debt (Spec A: centered, no level shift)") ///
    ytitle("Actual foreign debt share (df)") ///
    title("Actual vs Predicted Foreign Debt: Spec A (centered)")

log close
