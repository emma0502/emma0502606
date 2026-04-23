****************************************************
* THRESHOLD VERSION (NO CONSTANT): Equations (1) and (2)
****************************************************

****************************************************
* Step 0: Panel setup
****************************************************
*xtset country_id year

****************************************************
* Step 1: Create threshold dummy and below-100 flag
****************************************************
capture drop highD
gen highD = d > 100 if !missing(d)
capture drop below100
gen below100 = d < 100 if !missing(d)

****************************************************
* Step 2: Equation (1) with threshold effects
* First stage uses FULL sample (all d) with threshold interaction
* s_ijt = delta_ij + delta_jt + a1_j*d_it + a2_j*(highD_it*d_it) + u_ijt
****************************************************

* Non-bank size
xtreg nonbank_size c.d##i.highD i.year, fe vce(cluster country_id)
capture drop delta_n_hat_th delta_n_th
predict double delta_n_hat_th if e(sample), u
bys country_id: egen double delta_n_th = mean(delta_n_hat_th)

* Central bank size
xtreg cb_size c.d##i.highD i.year, fe vce(cluster country_id)
capture drop delta_cb_hat_th delta_cb_th
predict double delta_cb_hat_th if e(sample), u
bys country_id: egen double delta_cb_th = mean(delta_cb_hat_th)

* Private bank size
xtreg di02 c.d##i.highD i.year, fe vce(cluster country_id)
capture drop delta_pb_hat_th delta_pb_th
predict double delta_pb_hat_th if e(sample), u
bys country_id: egen double delta_pb_th = mean(delta_pb_hat_th)

****************************************************
* Step 3: Create interaction terms delta_ij * d_it
****************************************************
capture drop delta_n_th_d delta_cb_th_d delta_pb_th_d
gen double delta_n_th_d  = delta_n_th  * d
gen double delta_cb_th_d = delta_cb_th * d
gen double delta_pb_th_d = delta_pb_th * d

****************************************************
* Step 4: Equation (2) — NO CONSTANT, with threshold
* d_ijt = beta_j*d_it + theta_j*(delta_ij*d_it)
*       + mu_j*(highD_it*d_it)
*       + nu_j*(highD_it*delta_ij*d_it) + e_ijt
*
* Note: highD level shift dropped (no constant, so
* highD on its own is a level; we keep slope interactions)
****************************************************

* --- Non-banks ---
* (A) Baseline: with delta, no constant
reg dh c.d c.delta_n_th_d c.d#i.highD c.delta_n_th_d#i.highD, ///
    noconstant vce(cluster country_id)
capture drop dhhat_th
predict double dhhat_th if e(sample), xb

* (B) With constant (for comparison)
reg dh c.d c.delta_n_th_d i.highD c.d#i.highD c.delta_n_th_d#i.highD, ///
    vce(cluster country_id)

* (C) Without delta, no constant
reg dh c.d c.d#i.highD, ///
    noconstant vce(cluster country_id)

* --- Central bank ---
* (A) Baseline: with delta, no constant
reg dcb c.d c.delta_cb_th_d c.d#i.highD c.delta_cb_th_d#i.highD, ///
    noconstant vce(cluster country_id)
capture drop dcbhat_th
predict double dcbhat_th if e(sample), xb

* (B) With constant (for comparison)
reg dcb c.d c.delta_cb_th_d i.highD c.d#i.highD c.delta_cb_th_d#i.highD, ///
    vce(cluster country_id)

* (C) Without delta, no constant
reg dcb c.d c.d#i.highD, ///
    noconstant vce(cluster country_id)

* --- Private banks ---
* (A) Baseline: with delta, no constant
reg dpb c.d c.delta_pb_th_d c.d#i.highD c.delta_pb_th_d#i.highD, ///
    noconstant vce(cluster country_id)
capture drop dpbhat_th
predict double dpbhat_th if e(sample), xb

* (B) With constant (for comparison)
reg dpb c.d c.delta_pb_th_d i.highD c.d#i.highD c.delta_pb_th_d#i.highD, ///
    vce(cluster country_id)

* (C) Without delta, no constant
reg dpb c.d c.d#i.highD, ///
    noconstant vce(cluster country_id)

****************************************************
* Step 5: Construct implied foreign debt residual
* (using fitted values from specification A)
****************************************************
capture drop dfhat_th
gen double dfhat_th = d - dhhat_th - dcbhat_th - dpbhat_th ///
    if !missing(d, dhhat_th, dcbhat_th, dpbhat_th)

****************************************************
* Step 6: Build common comparison sample
****************************************************
capture drop sample_th
gen sample_th = !missing(df, dfhat_th)

****************************************************
* Step 7: Compare actual and implied foreign debt
****************************************************
summ df dfhat_th if sample_th==1
corr df dfhat_th if sample_th==1

reg df dfhat_th if sample_th==1, vce(cluster country_id)

****************************************************
* Step 8: Prediction error
****************************************************
capture drop df_error_th abs_df_error_th
gen double df_error_th = df - dfhat_th if sample_th==1
gen double abs_df_error_th = abs(df_error_th) if sample_th==1

summ df_error_th if sample_th==1
summ abs_df_error_th if sample_th==1

****************************************************
* Step 9: Graph actual vs predicted foreign debt
****************************************************
twoway ///
    (scatter df dfhat_th if sample_th==1, msize(small)) ///
    (lfit df dfhat_th if sample_th==1), ///
    xtitle("Predicted foreign debt share (threshold, no constant)") ///
    ytitle("Actual foreign debt share (df)") ///
    title("Actual vs Predicted Foreign Debt: Threshold (No Constant)")

****************************************************
* Step 10: Optional country-level fit summary
****************************************************
capture drop tag_country_th mean_abs_df_error_th
bys country_id: egen mean_abs_df_error_th = mean(abs_df_error_th)
bys country_id: gen tag_country_th = _n==1
list country_id mean_abs_df_error_th if tag_country_th==1, sep(0)
drop tag_country_th
