****************************************************
* FULL VERSION: Threshold + de facto integration
* Uses threshold-version deltas from equation (1)
****************************************************

****************************************************
* Step 0: Clean old variables
****************************************************
capture drop phi_def_th_d dhhat_def_th dcbhat_def_th dpbhat_def_th
capture drop dfhat_def_th sample_def_th df_error_def_th abs_df_error_def_th

****************************************************
* Step 1: Make sure threshold-version interaction terms exist
****************************************************
capture drop delta_n_th_d delta_cb_th_d delta_pb_th_d
gen double delta_n_th_d  = delta_n_th  * d
gen double delta_cb_th_d = delta_cb_th * d
gen double delta_pb_th_d = delta_pb_th * d

****************************************************
* Step 2: Create de facto interaction term
****************************************************
gen double phi_def_th_d = de_facto * d if !missing(de_facto,d)

****************************************************
* Step 3: Full equation (2) with threshold + de facto
****************************************************

* Domestic non-banks
reg dh  c.d c.delta_n_th_d c.phi_def_th_d ///
    i.highD c.d#i.highD c.delta_n_th_d#i.highD c.phi_def_th_d#i.highD, ///
    vce(cluster country_id)
predict double dhhat_def_th if e(sample), xb

* Domestic central bank
reg dcb c.d c.delta_cb_th_d c.phi_def_th_d ///
    i.highD c.d#i.highD c.delta_cb_th_d#i.highD c.phi_def_th_d#i.highD, ///
    vce(cluster country_id)
predict double dcbhat_def_th if e(sample), xb

* Domestic private banks
reg dpb c.d c.delta_pb_th_d c.phi_def_th_d ///
    i.highD c.d#i.highD c.delta_pb_th_d#i.highD c.phi_def_th_d#i.highD, ///
    vce(cluster country_id)
predict double dpbhat_def_th if e(sample), xb

****************************************************
* Step 4: Construct implied foreign residual
****************************************************
gen double dfhat_def_th = d - dhhat_def_th - dcbhat_def_th - dpbhat_def_th ///
    if !missing(d,dhhat_def_th,dcbhat_def_th,dpbhat_def_th)

****************************************************
* Step 5: Common comparison sample
****************************************************
gen sample_def_th = !missing(df,dfhat_def_th)

****************************************************
* Step 6: Compare actual and implied foreign debt
****************************************************
summ df dfhat_def_th if sample_def_th==1
corr df dfhat_def_th if sample_def_th==1
reg df dfhat_def_th if sample_def_th==1, vce(cluster country_id)

****************************************************
* Step 7: Prediction error
****************************************************
gen double df_error_def_th = df - dfhat_def_th if sample_def_th==1
gen double abs_df_error_def_th = abs(df_error_def_th) if sample_def_th==1

summ df_error_def_th if sample_def_th==1
summ abs_df_error_def_th if sample_def_th==1

****************************************************
* Step 8: Optional graph
****************************************************
twoway ///
    (scatter df dfhat_def_th if sample_def_th==1, msize(small)) ///
    (lfit df dfhat_def_th if sample_def_th==1), ///
    xtitle("Predicted foreign debt share (threshold + de facto)") ///
    ytitle("Actual foreign debt share (df)") ///
    title("Actual vs Predicted Foreign Debt Share: Threshold + De Facto")
	****************************************************
* FULL VERSION: Threshold + CAP100
* Uses threshold-version deltas from equation (1)
****************************************************

****************************************************
* Step 0: Clean old variables
****************************************************
capture drop phi_cap_th_d dhhat_cap_th dcbhat_cap_th dpbhat_cap_th
capture drop dfhat_cap_th sample_cap_th df_error_cap_th abs_df_error_cap_th

****************************************************
* Step 1: Make sure threshold-version interaction terms exist
****************************************************
capture drop delta_n_th_d delta_cb_th_d delta_pb_th_d
gen double delta_n_th_d  = delta_n_th  * d
gen double delta_cb_th_d = delta_cb_th * d
gen double delta_pb_th_d = delta_pb_th * d

****************************************************
* Step 2: Create CAP100 interaction term
****************************************************
gen double phi_cap_th_d = cap100 * d if !missing(cap100,d)

****************************************************
* Step 3: Full equation (2) with threshold + CAP100
****************************************************

* Domestic non-banks
reg dh  c.d c.delta_n_th_d c.phi_cap_th_d ///
    i.highD c.d#i.highD c.delta_n_th_d#i.highD c.phi_cap_th_d#i.highD, ///
    vce(cluster country_id)
predict double dhhat_cap_th if e(sample), xb

* Domestic central bank
reg dcb c.d c.delta_cb_th_d c.phi_cap_th_d ///
    i.highD c.d#i.highD c.delta_cb_th_d#i.highD c.phi_cap_th_d#i.highD, ///
    vce(cluster country_id)
predict double dcbhat_cap_th if e(sample), xb

* Domestic private banks
reg dpb c.d c.delta_pb_th_d c.phi_cap_th_d ///
    i.highD c.d#i.highD c.delta_pb_th_d#i.highD c.phi_cap_th_d#i.highD, ///
    vce(cluster country_id)
predict double dpbhat_cap_th if e(sample), xb

****************************************************
* Step 4: Construct implied foreign residual
****************************************************
gen double dfhat_cap_th = d - dhhat_cap_th - dcbhat_cap_th - dpbhat_cap_th ///
    if !missing(d,dhhat_cap_th,dcbhat_cap_th,dpbhat_cap_th)

****************************************************
* Step 5: Common comparison sample
****************************************************
gen sample_cap_th = !missing(df,dfhat_cap_th)

****************************************************
* Step 6: Compare actual and implied foreign debt
****************************************************
summ df dfhat_cap_th if sample_cap_th==1
corr df dfhat_cap_th if sample_cap_th==1
reg df dfhat_cap_th if sample_cap_th==1, vce(cluster country_id)

****************************************************
* Step 7: Prediction error
****************************************************
gen double df_error_cap_th = df - dfhat_cap_th if sample_cap_th==1
gen double abs_df_error_cap_th = abs(df_error_cap_th) if sample_cap_th==1

summ df_error_cap_th if sample_cap_th==1
summ abs_df_error_cap_th if sample_cap_th==1

****************************************************
* Step 8: Optional graph
****************************************************
twoway ///
    (scatter df dfhat_cap_th if sample_cap_th==1, msize(small)) ///
    (lfit df dfhat_cap_th if sample_cap_th==1), ///
    xtitle("Predicted foreign debt share (threshold + CAP100)") ///
    ytitle("Actual foreign debt share (df)") ///
    title("Actual vs Predicted Foreign Debt Share: Threshold + CAP100")