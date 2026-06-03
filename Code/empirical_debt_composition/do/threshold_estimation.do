****************************************************
* THRESHOLD VERSION: Equations (1) and (2)
****************************************************

****************************************************
* Step 0: Panel setup
****************************************************
*xtset country_id year

****************************************************
* Step 1: Create threshold dummy
****************************************************
capture drop highD
gen highD = d > 100 if !missing(d)

****************************************************
* Step 2: Equation (1) with threshold effects
* s_ijt = delta_ij + delta_jt + a1_j*d_it + a2_j*(highD_it*d_it) + u_ijt
****************************************************

* Non-bank size
xtreg nonbank_size c.d##i.highD i.year, fe vce(cluster country_id)
predict double delta_n_hat_th if e(sample), u
bys country_id: egen double delta_n_th = mean(delta_n_hat_th)

* Central bank size
xtreg cb_size c.d##i.highD i.year, fe vce(cluster country_id)
predict double delta_cb_hat_th if e(sample), u
bys country_id: egen double delta_cb_th = mean(delta_cb_hat_th)

* Private bank size
xtreg di02 c.d##i.highD i.year, fe vce(cluster country_id)
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
* Step 4: Equation (2) with threshold effects
* d_ijt = beta_j*d_it + gamma_j*(delta_ij*d_it)
*       + lambda_j*highD_it + mu_j*(highD_it*d_it)
*       + nu_j*(highD_it*delta_ij*d_it) + e_ijt
****************************************************

* Domestic non-banks
reg dh c.d c.delta_n_th_d i.highD c.d#i.highD c.delta_n_th_d#i.highD, vce(cluster country_id)
predict double dhhat_th if e(sample), xb

* Domestic central bank
reg dcb c.d c.delta_cb_th_d i.highD c.d#i.highD c.delta_cb_th_d#i.highD, vce(cluster country_id)
predict double dcbhat_th if e(sample), xb

* Domestic private banks
reg dpb c.d c.delta_pb_th_d i.highD c.d#i.highD c.delta_pb_th_d#i.highD, vce(cluster country_id)
predict double dpbhat_th if e(sample), xb

****************************************************
* Step 5: Construct implied foreign debt residual
****************************************************
capture drop dfhat_th
gen double dfhat_th = d - dhhat_th - dcbhat_th - dpbhat_th if !missing(d,dhhat_th,dcbhat_th,dpbhat_th)

****************************************************
* Step 6: Build common comparison sample
****************************************************
capture drop sample_th
gen sample_th = !missing(df,dfhat_th)

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
    xtitle("Predicted foreign debt share (threshold version)") ///
    ytitle("Actual foreign debt share (df)") ///
    title("Actual vs Predicted Foreign Debt Share: Threshold Version")

****************************************************
* Step 10: Optional country-level fit summary
****************************************************
capture drop tag_country_th mean_abs_df_error_th
bys country_id: egen mean_abs_df_error_th = mean(abs_df_error_th)
bys country_id: gen tag_country_th = _n==1
list country_id mean_abs_df_error_th if tag_country_th==1, sep(0)
drop tag_country_th