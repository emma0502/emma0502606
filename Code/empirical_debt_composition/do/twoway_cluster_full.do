****************************************************
* TWO-WAY CLUSTERED STANDARD ERRORS for Spec A
* Both Stage 1 (sector size) and Stage 2 (debt allocation)
*
* Strategy:
*   - Use xtreg to extract delta_ij (point estimates do not
*     depend on the SE / clustering scheme).
*   - Re-run Stage 1 with ivreg2 to report two-way clustered
*     SEs for Table 6.3.
*   - Run Stage 2 with ivreg2 + nocons + two-way clustering;
*     coefficients match the original `reg ..., nocons`
*     exactly (no instruments = plain OLS).
*
* Required install (one-time):
*   ssc install ivreg2
*   ssc install ranktest
****************************************************

capture log close
log using "Code/empirical_debt_composition/results/twoway_cluster_full.txt", text replace

xtset country_id year

****************************************************
* Threshold level Dbar (percent of GDP)
*   Default here = Hansen 1-threshold estimate for db_total
*   with country FE (see threshold_estimation_default_trim.txt:
*   Order 1 Threshold = 102.74851). Set to 100 to match the
*   round number used in the main paper text.
*   Changing Dbar redefines highD and centered interactions, so
*   delta_ij and Stage 2 coefficients are not comparable across
*   different Dbar values.
****************************************************
local Dbar = 102.74851
* local Dbar = 100

****************************************************
* Step 1: threshold variables
****************************************************
capture drop highD d_high_c
gen highD       = d > `Dbar' if !missing(d)
gen double d_high_c = highD * (d - `Dbar')

****************************************************
* Step 2: First stage (xtreg) --- to extract delta_ij
*   Point estimates of delta_ij do NOT depend on the SE
*   clustering scheme. We use xtreg here only to recover
*   delta_ij. SEs reported here are not used in the paper.
****************************************************

* Non-bank size --- extract delta_n_th
capture drop delta_n_hat_th delta_n_th stage1_n_obs
xtreg nonbank_size c.d c.d_high_c i.year, fe vce(cluster country_id)
predict double delta_n_hat_th if e(sample), u
bys country_id: egen double delta_n_th  = mean(delta_n_hat_th)
bys country_id: egen long   stage1_n_obs = count(delta_n_hat_th)

* Central bank size
capture drop delta_cb_hat_th delta_cb_th stage1_cb_obs
xtreg cb_size c.d c.d_high_c i.year, fe vce(cluster country_id)
predict double delta_cb_hat_th if e(sample), u
bys country_id: egen double delta_cb_th  = mean(delta_cb_hat_th)
bys country_id: egen long   stage1_cb_obs = count(delta_cb_hat_th)

* Private bank size
capture drop delta_pb_hat_th delta_pb_th stage1_pb_obs
xtreg di02 c.d c.d_high_c i.year, fe vce(cluster country_id)
predict double delta_pb_hat_th if e(sample), u
bys country_id: egen double delta_pb_th  = mean(delta_pb_hat_th)
bys country_id: egen long   stage1_pb_obs = count(delta_pb_hat_th)

****************************************************
* Step 3: Stage 2 interactions
****************************************************
capture drop delta_n_th_d delta_cb_th_d delta_pb_th_d
gen double delta_n_th_d  = delta_n_th  * d
gen double delta_cb_th_d = delta_cb_th * d
gen double delta_pb_th_d = delta_pb_th * d

capture drop delta_n_th_dhc delta_cb_th_dhc delta_pb_th_dhc
gen double delta_n_th_dhc  = delta_n_th  * d_high_c
gen double delta_cb_th_dhc = delta_cb_th * d_high_c
gen double delta_pb_th_dhc = delta_pb_th * d_high_c

****************************************************
* Step 4: STAGE 1 with TWO-WAY clustering (for Table 6.3)
*
* ivreg2 with partial(i.country_id) absorbs country fixed
* effects (within transformation, like xtreg ..., fe).
* Year fixed effects are included as regressors via i.year.
* Coefficients on D and on highD*(D-Dbar) match xtreg
* exactly; only the reported SEs change.
****************************************************

di _newline(3) "=========================================="
di "  STAGE 1  --  ivreg2, two-way (country, year)"
di "  with country FE absorbed and year FE as regressors"
di "=========================================="

di _newline(2) "--- Non-bank size (Table 6.3 col 1) ---"
ivreg2 nonbank_size d d_high_c i.year i.country_id, ///
    partial(i.country_id) cluster(country_id year)

di _newline(2) "--- CB size (Table 6.3 col 2) ---"
ivreg2 cb_size d d_high_c i.year i.country_id, ///
    partial(i.country_id) cluster(country_id year)

di _newline(2) "--- Private bank size (Table 6.3 col 3) ---"
ivreg2 di02 d d_high_c i.year i.country_id, ///
    partial(i.country_id) cluster(country_id year)

****************************************************
* Step 5: STAGE 2 HEADLINE Spec A with TWO-WAY clustering
*   Plain OLS, no constant, two-way cluster (country, year)
****************************************************

di _newline(3) "=========================================="
di "  STAGE 2 HEADLINE  --  ivreg2, two-way (country, year)"
di "=========================================="

di _newline(2) "--- Non-bank (dh) -- headline ---"
ivreg2 dh d delta_n_th_d d_high_c delta_n_th_dhc, ///
    nocons cluster(country_id year)

di _newline(2) "--- Central bank (dcb) -- headline ---"
ivreg2 dcb d delta_cb_th_d d_high_c delta_cb_th_dhc, ///
    nocons cluster(country_id year)

di _newline(2) "--- Private bank (dpb) -- headline ---"
ivreg2 dpb d delta_pb_th_d d_high_c delta_pb_th_dhc, ///
    nocons cluster(country_id year)

****************************************************
* Step 6: STAGE 2 MATCHED SAMPLE  +  TWO-WAY clustering
*   Non-bank: 547,  CB: 718,  PB: 732
****************************************************

di _newline(3) "=========================================="
di "  STAGE 2 MATCHED  --  ivreg2, two-way (country, year)"
di "=========================================="

di _newline(2) "--- Non-bank (dh) -- matched ---"
ivreg2 dh d delta_n_th_d d_high_c delta_n_th_dhc ///
    if !missing(delta_n_hat_th), ///
    nocons cluster(country_id year)

di _newline(2) "--- Central bank (dcb) -- matched ---"
ivreg2 dcb d delta_cb_th_d d_high_c delta_cb_th_dhc ///
    if !missing(delta_cb_hat_th), ///
    nocons cluster(country_id year)

di _newline(2) "--- Private bank (dpb) -- matched ---"
ivreg2 dpb d delta_pb_th_d d_high_c delta_pb_th_dhc ///
    if !missing(delta_pb_hat_th), ///
    nocons cluster(country_id year)

****************************************************
* Step 7: STAGE 2 SPARSE-COUNTRY DROP k>=5  +  TWO-WAY
****************************************************

di _newline(3) "=========================================="
di "  STAGE 2 SPARSE k>=5  --  ivreg2, two-way"
di "=========================================="

di _newline(2) "--- Non-bank (dh) -- k>=5 ---"
ivreg2 dh d delta_n_th_d d_high_c delta_n_th_dhc ///
    if stage1_n_obs >= 5, ///
    nocons cluster(country_id year)

di _newline(2) "--- Central bank (dcb) -- k>=5 ---"
ivreg2 dcb d delta_cb_th_d d_high_c delta_cb_th_dhc ///
    if stage1_cb_obs >= 5, ///
    nocons cluster(country_id year)

di _newline(2) "--- Private bank (dpb) -- k>=5 ---"
ivreg2 dpb d delta_pb_th_d d_high_c delta_pb_th_dhc ///
    if stage1_pb_obs >= 5, ///
    nocons cluster(country_id year)

****************************************************
* Step 8: STAGE 2 SPARSE-COUNTRY DROP k>=10  +  TWO-WAY
****************************************************

di _newline(3) "=========================================="
di "  STAGE 2 SPARSE k>=10  --  ivreg2, two-way"
di "=========================================="

di _newline(2) "--- Non-bank (dh) -- k>=10 ---"
ivreg2 dh d delta_n_th_d d_high_c delta_n_th_dhc ///
    if stage1_n_obs >= 10, ///
    nocons cluster(country_id year)

di _newline(2) "--- Central bank (dcb) -- k>=10 ---"
ivreg2 dcb d delta_cb_th_d d_high_c delta_cb_th_dhc ///
    if stage1_cb_obs >= 10, ///
    nocons cluster(country_id year)

di _newline(2) "--- Private bank (dpb) -- k>=10 ---"
ivreg2 dpb d delta_pb_th_d d_high_c delta_pb_th_dhc ///
    if stage1_pb_obs >= 10, ///
    nocons cluster(country_id year)

log close
