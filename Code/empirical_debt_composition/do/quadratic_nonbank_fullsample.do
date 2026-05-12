****************************************************
* quadratic_nonbank_fullsample.do
*
* Non-bank second stage only — FULL sample, no constant.
*
*   Q  (main):  dh = beta*d + theta*(delta^q*d) + kappa*d^2 + psi*(delta^q*d^2)
*   Q0:         dh = beta*d + kappa*d^2
*   L:          dh = beta*d + theta*(delta^q*d)
*   T:          dh = beta*d + theta*(delta^q*d) + mu*d_high_c + nu*(delta^q*d_high_c)
*               where d_high_c = highD*(d-100), highD = 1[d>=100]
*
* First stage:  delta^q from baseline non-bank (d<100); CB/PB from centered threshold.
* CB/PB second stage: centered threshold (for implied foreign debt from Spec Q).
****************************************************

capture log close
log using "Code/empirical_debt_composition/results/quadratic_nonbank_results2.txt", text replace

xtset country_id year

****************************************************
* First stage — Non-bank: baseline (d < 100) -> delta_n_q
****************************************************
capture drop below100
gen below100 = d < 100 if !missing(d)

capture drop delta_n_hat delta_n_q
xtreg nonbank_size d i.year if below100==1, fe vce(cluster country_id)
predict double delta_n_hat if e(sample), u
bys country_id: egen double delta_n_q = mean(delta_n_hat)
drop delta_n_hat

****************************************************
* First stage — CB and PB: centered threshold, full sample
****************************************************
capture drop highD d_high_c
gen highD = d >= 100 if !missing(d)
gen double d_high_c = highD * (d - 100)

capture drop delta_cb_hat_q delta_cb_q
xtreg cb_size c.d c.d_high_c i.year, fe vce(cluster country_id)
predict double delta_cb_hat_q if e(sample), u
bys country_id: egen double delta_cb_q = mean(delta_cb_hat_q)
drop delta_cb_hat_q

capture drop delta_pb_hat_q delta_pb_q
xtreg di02 c.d c.d_high_c i.year, fe vce(cluster country_id)
predict double delta_pb_hat_q if e(sample), u
bys country_id: egen double delta_pb_q = mean(delta_pb_hat_q)
drop delta_pb_hat_q

****************************************************
* Report structural sizes (deltas) by country
****************************************************
di _newline(3) "=========================================="
di "  STRUCTURAL SIZES (delta_hat) BY COUNTRY"
di "=========================================="
di "  Country | delta_h (nonbank) | delta_cb | delta_pb"
di "----------------------------------------------------------"

preserve
capture confirm variable country
if _rc == 0 {
    collapse (mean) delta_n_q delta_cb_q delta_pb_q, by(country_id country)
    sort country
    list country delta_n_q delta_cb_q delta_pb_q, noobs clean
}
else {
    collapse (mean) delta_n_q delta_cb_q delta_pb_q, by(country_id)
    sort country_id
    list country_id delta_n_q delta_cb_q delta_pb_q, noobs clean
}
di _newline "Summary statistics:"
summ delta_n_q delta_cb_q delta_pb_q
restore

****************************************************
* TIME TREND CHECK (professor's request)
*
* Does the non-bank sector show a secular increase in size
* over time (controlling for debt)?  If yes, and debt also
* trends up, the weak concavity (kappa) could be an artefact
* of a common trend rather than a true absorption mechanism.
*
* Two approaches per sector:
*   (A) Display every year-FE coefficient from the i.year
*       first stage so you can eyeball the path.
*   (B) Re-run the first stage replacing i.year with a
*       continuous year variable and report its coefficient.
****************************************************

di _newline(3) "=========================================="
di "  YEAR FIXED EFFECTS & TIME TREND CHECK"
di "=========================================="

* ---------- Non-bank ----------
di _newline(2) "--- Non-bank first stage (d < 100) ---"
quietly xtreg nonbank_size d i.year if below100==1, fe vce(cluster country_id)

di _newline "  (A) Year FE coefficients from i.year specification:"
di "       Year | Coefficient"
di "       -----|------------"
levelsof year if e(sample), local(yrs)
foreach y of local yrs {
    capture local coef = _b[`y'.year]
    if _rc == 0 {
        di "       `y' | " %9.3f `coef'
    }
}

di _newline "  (B) Linear trend test — replace i.year with continuous year:"
xtreg nonbank_size d year if below100==1, fe vce(cluster country_id)
local nb_trend_b = _b[year]
local nb_trend_se = _se[year]
local nb_trend_p = 2*ttail(e(df_r), abs(`nb_trend_b'/`nb_trend_se'))
di _newline "  ==> Non-bank linear trend: coeff = " %7.4f `nb_trend_b' ///
   "  (SE " %6.4f `nb_trend_se' ")" ///
   "  p = " %6.4f `nb_trend_p'

* ---------- Central bank ----------
di _newline(2) "--- Central bank first stage (full sample) ---"
quietly xtreg cb_size c.d c.d_high_c i.year, fe vce(cluster country_id)

di _newline "  (A) Year FE coefficients from i.year specification:"
di "       Year | Coefficient"
di "       -----|------------"
levelsof year if e(sample), local(yrs)
foreach y of local yrs {
    capture local coef = _b[`y'.year]
    if _rc == 0 {
        di "       `y' | " %9.3f `coef'
    }
}

di _newline "  (B) Linear trend test:"
xtreg cb_size c.d c.d_high_c year, fe vce(cluster country_id)
local cb_trend_b = _b[year]
local cb_trend_se = _se[year]
local cb_trend_p = 2*ttail(e(df_r), abs(`cb_trend_b'/`cb_trend_se'))
di _newline "  ==> CB linear trend: coeff = " %7.4f `cb_trend_b' ///
   "  (SE " %6.4f `cb_trend_se' ")" ///
   "  p = " %6.4f `cb_trend_p'

* ---------- Private bank ----------
di _newline(2) "--- Private bank first stage (full sample) ---"
quietly xtreg di02 c.d c.d_high_c i.year, fe vce(cluster country_id)

di _newline "  (A) Year FE coefficients from i.year specification:"
di "       Year | Coefficient"
di "       -----|------------"
levelsof year if e(sample), local(yrs)
foreach y of local yrs {
    capture local coef = _b[`y'.year]
    if _rc == 0 {
        di "       `y' | " %9.3f `coef'
    }
}

di _newline "  (B) Linear trend test:"
xtreg di02 c.d c.d_high_c year, fe vce(cluster country_id)
local pb_trend_b = _b[year]
local pb_trend_se = _se[year]
local pb_trend_p = 2*ttail(e(df_r), abs(`pb_trend_b'/`pb_trend_se'))
di _newline "  ==> PB linear trend: coeff = " %7.4f `pb_trend_b' ///
   "  (SE " %6.4f `pb_trend_se' ")" ///
   "  p = " %6.4f `pb_trend_p'

* ---------- Summary ----------
di _newline(2) "=========================================="
di "  SUMMARY: Linear time trends in sector size"
di "  (controlling for debt + country FE)"
di "  Sector       | Trend coeff |   SE    | p-value"
di "  -------------|-------------|---------|--------"
di "  Non-bank     | " %9.4f `nb_trend_b' "   | " %7.4f `nb_trend_se' " | " %6.4f `nb_trend_p'
di "  Central bank | " %9.4f `cb_trend_b' "   | " %7.4f `cb_trend_se' " | " %6.4f `cb_trend_p'
di "  Private bank | " %9.4f `pb_trend_b' "   | " %7.4f `pb_trend_se' " | " %6.4f `pb_trend_p'
di "=========================================="
di _newline "Interpretation:"
di "  If non-bank trend > 0 and significant, the sector is growing"
di "  over time (in % of GDP) after controlling for debt."
di "  Combined with trending debt, this could explain the weak"
di "  concavity (kappa insignificant) in the second stage."
di "  Professor's concern: if both debt and non-bank size trend up,"
di "  setting T_h ~ 0 may be too strong an assumption."

****************************************************
* Interactions
****************************************************
capture drop d_sq delta_n_d delta_n_d_sq delta_n_dhc
gen double d_sq         = d * d
gen double delta_n_d    = delta_n_q * d
gen double delta_n_d_sq = delta_n_q * d_sq
gen double delta_n_dhc  = delta_n_q * d_high_c

capture drop delta_cb_d delta_cb_dhc
gen double delta_cb_d   = delta_cb_q * d
gen double delta_cb_dhc = delta_cb_q * d_high_c

capture drop delta_pb_d delta_pb_dhc
gen double delta_pb_d   = delta_pb_q * d
gen double delta_pb_dhc = delta_pb_q * d_high_c

****************************************************
* Non-bank second stage — full sample, nocons
****************************************************
di _newline(3) "=========================================="
di "  NON-BANK: Q, Q0, L, T (full sample, no constant)"
di "=========================================="

* --- Q (main) ---
di _newline(2) "--- Spec Q ---"
reg dh c.d c.delta_n_d c.d_sq c.delta_n_d_sq, ///
    nocons vce(cluster country_id)
estimates store specQ_n
capture drop dhhat_Q
predict double dhhat_Q if e(sample), xb

* --- Qs (drop psi only: beta*d + theta*(delta*d) + kappa*d^2) ---
di _newline(2) "--- Spec Qs ---"
reg dh c.d c.delta_n_d c.d_sq, ///
    nocons vce(cluster country_id)
estimates store specQs_n
capture drop dhhat_Qs
predict double dhhat_Qs if e(sample), xb

* --- Q0 ---
di _newline(2) "--- Spec Q0 ---"
reg dh c.d c.d_sq, ///
    nocons vce(cluster country_id)
estimates store specQ0_n
capture drop dhhat_Q0
predict double dhhat_Q0 if e(sample), xb

* --- L ---
di _newline(2) "--- Spec L ---"
reg dh c.d c.delta_n_d, ///
    nocons vce(cluster country_id)
estimates store specL_n
capture drop dhhat_L
predict double dhhat_L if e(sample), xb

* --- T (centered threshold) ---
di _newline(2) "--- Spec T ---"
reg dh c.d c.delta_n_d c.d_high_c c.delta_n_dhc, ///
    nocons vce(cluster country_id)
estimates store specT_n
capture drop dhhat_T
predict double dhhat_T if e(sample), xb

****************************************************
* NON-BANK second stage WITH COUNTRY + YEAR FE
* Specs B, C, D only (no psi term)
****************************************************
di _newline(3) "=========================================="
di "  NON-BANK: Specs B, C, D WITH COUNTRY + YEAR FE"
di "=========================================="

* --- B_fe: beta*d + theta*(delta*d) + kappa*d^2 ---
di _newline(2) "--- Spec B_fe ---"
xtreg dh c.d c.delta_n_d c.d_sq i.year, ///
    fe vce(cluster country_id)
estimates store specB_fe

* --- C_fe: beta*d + kappa*d^2 ---
di _newline(2) "--- Spec C_fe ---"
xtreg dh c.d c.d_sq i.year, ///
    fe vce(cluster country_id)
estimates store specC_fe

* --- D_fe: beta*d + theta*(delta*d) ---
di _newline(2) "--- Spec D_fe ---"
xtreg dh c.d c.delta_n_d i.year, ///
    fe vce(cluster country_id)
estimates store specD_fe

di _newline(2) "=========================================="
di "  Comparison: Pooled vs FE (d and d^2 terms only)"
di "=========================================="

di _newline "  Pooled (no FE):"
estimates table specQs_n specQ0_n specL_n, ///
    keep(d delta_n_d d_sq) star(0.10 0.05 0.01) stats(N r2)

di _newline "  With country + year FE:"
estimates table specB_fe specC_fe specD_fe, ///
    keep(d delta_n_d d_sq) star(0.10 0.05 0.01) stats(N r2_w r2_b r2_o)

****************************************************
* FOREIGN DEBT with delta_h interactions
*
* Test: does delta_h affect foreign absorption?
* If countries with small non-bank sectors rely more
* on foreigners, theta should be negative (larger
* delta_h => less foreign debt at any given d).
****************************************************
di _newline(3) "=========================================="
di "  FOREIGN DEBT: df on d with delta_h interactions"
di "=========================================="

* --- Pooled specs ---
di _newline(2) "--- df pooled: beta*d + kappa*d^2 (no delta_h) ---"
reg df c.d c.d_sq, nocons vce(cluster country_id)
estimates store df_Q0

di _newline(2) "--- df pooled: beta*d + theta*(delta_h*d) + kappa*d^2 ---"
reg df c.d c.delta_n_d c.d_sq, nocons vce(cluster country_id)
estimates store df_Qs

di _newline(2) "--- df pooled: beta*d + theta*(delta_h*d) ---"
reg df c.d c.delta_n_d, nocons vce(cluster country_id)
estimates store df_L

* --- FE specs ---
di _newline(2) "--- df FE: beta*d + kappa*d^2 + country FE + year FE ---"
xtreg df c.d c.d_sq i.year, fe vce(cluster country_id)
estimates store df_Q0_fe

di _newline(2) "--- df FE: beta*d + theta*(delta_h*d) + kappa*d^2 + FE ---"
xtreg df c.d c.delta_n_d c.d_sq i.year, fe vce(cluster country_id)
estimates store df_Qs_fe

di _newline(2) "--- df FE: beta*d + theta*(delta_h*d) + FE ---"
xtreg df c.d c.delta_n_d i.year, fe vce(cluster country_id)
estimates store df_L_fe

di _newline(2) "=========================================="
di "  df comparison: Pooled vs FE"
di "=========================================="

di _newline "  Pooled:"
estimates table df_Q0 df_Qs df_L, ///
    keep(d delta_n_d d_sq) star(0.10 0.05 0.01) stats(N r2)

di _newline "  With country + year FE:"
estimates table df_Q0_fe df_Qs_fe df_L_fe, ///
    keep(d delta_n_d d_sq) star(0.10 0.05 0.01) stats(N r2_w r2_b r2_o)

di _newline "Interpretation:"
di "  theta (delta_h * d) in df regression:"
di "    theta < 0 => countries with larger non-bank sectors hold LESS foreign debt"
di "    (they don't need foreigners because domestic capacity is enough)"
di "    theta > 0 => countries with larger non-bank sectors hold MORE foreign debt"
di "  This tests the heterogeneous pecking order hypothesis."

****************************************************
* CB / PB second stage (for implied foreign debt using Spec Q dh)
****************************************************
di _newline(3) "=========================================="
di "  CB and PB (centered threshold, full sample, nocons)"
di "=========================================="

reg dcb c.d c.delta_cb_d c.d_high_c c.delta_cb_dhc, ///
    nocons vce(cluster country_id)
capture drop dcbhat_Q
predict double dcbhat_Q if e(sample), xb

reg dpb c.d c.delta_pb_d c.d_high_c c.delta_pb_dhc, ///
    nocons vce(cluster country_id)
capture drop dpbhat_Q
predict double dpbhat_Q if e(sample), xb

****************************************************
* Implied foreign debt — all five specs
* dfhat_X = d - dhhat_X - dcbhat - dpbhat
****************************************************

foreach spec in Q Qs Q0 L T {
    capture drop dfhat_`spec'
    gen double dfhat_`spec' = d - dhhat_`spec' - dcbhat_Q - dpbhat_Q ///
        if !missing(d, dhhat_`spec', dcbhat_Q, dpbhat_Q)
    capture drop sample_`spec'
    gen sample_`spec' = !missing(df, dfhat_`spec')
}

di _newline(3) "=========================================="
di "  FOREIGN DEBT PREDICTION COMPARISON"
di "=========================================="

foreach spec in Q Qs Q0 L T {
    di _newline(2) "--- Spec `spec' ---"
    corr df dfhat_`spec' if sample_`spec'==1
    reg df dfhat_`spec' if sample_`spec'==1, vce(cluster country_id)
    capture drop df_error_`spec' abs_df_error_`spec'
    gen double df_error_`spec'     = df - dfhat_`spec'     if sample_`spec'==1
    gen double abs_df_error_`spec' = abs(df_error_`spec')  if sample_`spec'==1
    summ df_error_`spec' abs_df_error_`spec' if sample_`spec'==1
}

di _newline(3) "=========================================="
di "  SUMMARY: foreign debt prediction"
di "  Spec | N | Corr | Reg R2 | Mean error | MAE"
di "=========================================="
foreach spec in Q Qs Q0 L T {
    quietly corr df dfhat_`spec' if sample_`spec'==1
    local corr_`spec' = r(rho)
    quietly reg df dfhat_`spec' if sample_`spec'==1, vce(cluster country_id)
    local r2_`spec' = e(r2)
    local n_`spec' = e(N)
    quietly summ df_error_`spec' if sample_`spec'==1
    local me_`spec' = r(mean)
    quietly summ abs_df_error_`spec' if sample_`spec'==1
    local mae_`spec' = r(mean)
    di "  `spec'" _col(8) %5.0f `n_`spec'' _col(16) %6.3f `corr_`spec'' ///
       _col(25) %6.3f `r2_`spec'' _col(34) %7.2f `me_`spec'' _col(44) %6.2f `mae_`spec''
}

****************************************************
* Summary table
****************************************************
di _newline(3) "=========================================="
di "  estimates table: Q | Qs | Q0 | L | T"
di "=========================================="
estimates table specQ_n specQs_n specQ0_n specL_n specT_n, ///
    star(0.10 0.05 0.01) stats(N r2)

****************************************************
* Marginal effects — Spec Q only (full quadratic)
* slope = beta + theta*delta + 2*kappa*d + 2*psi*delta*d
****************************************************
di _newline(3) "=========================================="
di "  MARGINAL EFFECTS: Spec Q"
di "=========================================="
estimates restore specQ_n
local beta  = _b[d]
local theta = _b[delta_n_d]
local kappa = _b[d_sq]
local psi   = _b[delta_n_d_sq]

di _newline "Coefficients: beta theta kappa psi"
di %9.4f `beta' "  " %9.6f `theta' "  " %9.6f `kappa' "  " %9.6f `psi'

di _newline "Slope if delta=0:"
foreach dval in 20 40 60 80 100 120 150 {
    local slope = `beta' + 2*`kappa'*`dval'
    di "  d=`dval': " %7.4f `slope'
}
di _newline "Slope if delta=+100:"
foreach dval in 20 40 60 80 100 120 150 {
    local slope = `beta' + `theta'*100 + 2*`kappa'*`dval' + 2*`psi'*100*`dval'
    di "  d=`dval': " %7.4f `slope'
}
di _newline "Slope if delta=-90:"
foreach dval in 20 40 60 80 100 120 150 {
    local slope = `beta' + `theta'*(-90) + 2*`kappa'*`dval' + 2*`psi'*(-90)*`dval'
    di "  d=`dval': " %7.4f `slope'
}

****************************************************
* Graph: actual vs predicted foreign debt (Spec Q)
****************************************************
twoway ///
    (scatter df dfhat_Q if sample_Q==1, msize(small) mcolor(navy)) ///
    (lfit df dfhat_Q if sample_Q==1, lcolor(red)), ///
    xtitle("Predicted foreign debt (Spec Q)") ///
    ytitle("Actual foreign debt (df)") ///
    title("Actual vs Predicted Foreign Debt")

****************************************************
* SIZE-SCALED SPECIFICATIONS (non-bank only)
*
* Since non-bank size (S_h) trends upward over time,
* testing concavity in levels (dh on d^2) may miss a
* capacity constraint whose ceiling moves with S_h.
*
* Scale the LHS by contemporaneous non-bank size:
*   dh/Sh = portfolio share devoted to gov bonds
*
* Spec R1:  dh/Sh = beta*d + kappa*d^2
* Spec R2:  dh/Sh = beta*d + theta*(delta_hat*d) + kappa*d^2
*
* If kappa < 0 and significant here, the concavity was
* always present but masked by the trending S_h.
****************************************************

di _newline(3) "=========================================="
di "  SIZE-SCALED SPECS: dh/Sh on d, d^2"
di "=========================================="

capture drop dh_over_sh
gen double dh_over_sh = dh / nonbank_size ///
    if !missing(dh, nonbank_size) & nonbank_size > 5

di _newline "  Observations with nonbank_size > 5:"
count if !missing(dh_over_sh)
summ dh_over_sh nonbank_size if !missing(dh_over_sh)

* --- Spec R1: clean ratio, no delta ---
di _newline(2) "--- Spec R1: dh/Sh = beta*d + kappa*d^2 (no delta) ---"
reg dh_over_sh c.d c.d_sq, ///
    nocons vce(cluster country_id)
estimates store specR1

* --- Spec R2: ratio with delta interaction ---
di _newline(2) "--- Spec R2: dh/Sh = beta*d + theta*(delta*d) + kappa*d^2 ---"
reg dh_over_sh c.d c.delta_n_d c.d_sq, ///
    nocons vce(cluster country_id)
estimates store specR2

* --- Comparison table ---
di _newline(2) "=========================================="
di "  Comparison: R1 vs R2  (size-scaled LHS)"
di "=========================================="
estimates table specR1 specR2, ///
    star(0.10 0.05 0.01) stats(N r2)

di _newline "Key question: is kappa (d^2) now significantly negative?"
di "  If yes => concavity was masked by trending S_h."
di "  If no  => no capacity constraint, even relative to size."

di _newline "Secondary question: is theta (delta*d) significant in R2?"
di "  If yes => delta captures something beyond raw size."
di "  If no  => delta was just a proxy for S_h scaling."

****************************************************
* DEBT ALLOCATION ACROSS ALL SECTORS (pecking-order test)
*
* Professor's question: as total debt D rises, how does
* the marginal absorption rate change for each sector?
*
* Pecking-order prediction:
*   - dh slope starts high, then decreases (non-bank fills up)
*   - df slope increases as dh slope falls (switch to foreigners)
*   - db slope increases at high d (banking absorbs residual)
*
* Three specs per sector:
*   (1) Linear:    dj = beta*d
*   (2) Quadratic: dj = beta*d + kappa*d^2
*   (3) Threshold: dj = beta*d + mu*d_high_c
*
* All: no constant, cluster-robust SEs, full sample.
****************************************************

di _newline(3) "=========================================="
di "  DEBT ALLOCATION: ALL SECTORS ON d, d^2"
di "=========================================="

* Create banking sector total: db = dcb + dpb
capture drop db
gen double db = dcb + dpb if !missing(dcb, dpb)

* =============================================
* (1) Linear: dj = beta*d
* =============================================
di _newline(2) "=========================================="
di "  (1) LINEAR: dj = beta*d"
di "=========================================="

di _newline "--- dh (non-bank) ---"
reg dh c.d, nocons vce(cluster country_id)
estimates store alloc_h_lin

di _newline "--- df (foreign) ---"
reg df c.d, nocons vce(cluster country_id)
estimates store alloc_f_lin

di _newline "--- dcb (central bank) ---"
reg dcb c.d, nocons vce(cluster country_id)
estimates store alloc_cb_lin

di _newline "--- dpb (private bank) ---"
reg dpb c.d, nocons vce(cluster country_id)
estimates store alloc_pb_lin

di _newline "--- db (banking total = dcb + dpb) ---"
reg db c.d, nocons vce(cluster country_id)
estimates store alloc_b_lin

di _newline(2) "  Linear absorption shares (beta):"
estimates table alloc_h_lin alloc_f_lin alloc_cb_lin alloc_pb_lin alloc_b_lin, ///
    star(0.10 0.05 0.01) stats(N r2)

* =============================================
* (2) Quadratic: dj = beta*d + kappa*d^2
* =============================================
di _newline(2) "=========================================="
di "  (2) QUADRATIC: dj = beta*d + kappa*d^2"
di "=========================================="

di _newline "--- dh (non-bank) ---"
reg dh c.d c.d_sq, nocons vce(cluster country_id)
estimates store alloc_h_quad

di _newline "--- df (foreign) ---"
reg df c.d c.d_sq, nocons vce(cluster country_id)
estimates store alloc_f_quad

di _newline "--- dcb (central bank) ---"
reg dcb c.d c.d_sq, nocons vce(cluster country_id)
estimates store alloc_cb_quad

di _newline "--- dpb (private bank) ---"
reg dpb c.d c.d_sq, nocons vce(cluster country_id)
estimates store alloc_pb_quad

di _newline "--- db (banking total) ---"
reg db c.d c.d_sq, nocons vce(cluster country_id)
estimates store alloc_b_quad

di _newline(2) "  Quadratic coefficients:"
estimates table alloc_h_quad alloc_f_quad alloc_cb_quad alloc_pb_quad alloc_b_quad, ///
    star(0.10 0.05 0.01) stats(N r2)

* =============================================
* (3) Threshold: dj = beta*d + mu*d_high_c
* =============================================
di _newline(2) "=========================================="
di "  (3) THRESHOLD: dj = beta*d + mu*1[d>=100]*(d-100)"
di "=========================================="

di _newline "--- dh (non-bank) ---"
reg dh c.d c.d_high_c, nocons vce(cluster country_id)
estimates store alloc_h_thr

di _newline "--- df (foreign) ---"
reg df c.d c.d_high_c, nocons vce(cluster country_id)
estimates store alloc_f_thr

di _newline "--- dcb (central bank) ---"
reg dcb c.d c.d_high_c, nocons vce(cluster country_id)
estimates store alloc_cb_thr

di _newline "--- dpb (private bank) ---"
reg dpb c.d c.d_high_c, nocons vce(cluster country_id)
estimates store alloc_pb_thr

di _newline "--- db (banking total) ---"
reg db c.d c.d_high_c, nocons vce(cluster country_id)
estimates store alloc_b_thr

di _newline(2) "  Threshold coefficients:"
estimates table alloc_h_thr alloc_f_thr alloc_cb_thr alloc_pb_thr alloc_b_thr, ///
    star(0.10 0.05 0.01) stats(N r2)

* =============================================
* Marginal absorption rates from quadratic spec
*   slope_j(d) = beta_j + 2*kappa_j * d
* =============================================
di _newline(2) "=========================================="
di "  MARGINAL ABSORPTION RATES (from quadratic)"
di "  slope_j(d) = beta_j + 2*kappa_j * d"
di "=========================================="

foreach sector in h f cb pb b {
    estimates restore alloc_`sector'_quad
    local beta_`sector' = _b[d]
    local kappa_`sector' = _b[d_sq]
}

di _newline "  d   |  dh slope  |  df slope  | dcb slope  | dpb slope  |  db slope  |  Sum"
di "  ----|-----------|------------|------------|------------|------------|-------"
foreach dval in 20 40 60 80 100 120 150 180 {
    local sl_h  = `beta_h'  + 2*`kappa_h' *`dval'
    local sl_f  = `beta_f'  + 2*`kappa_f' *`dval'
    local sl_cb = `beta_cb' + 2*`kappa_cb'*`dval'
    local sl_pb = `beta_pb' + 2*`kappa_pb'*`dval'
    local sl_b  = `beta_b'  + 2*`kappa_b' *`dval'
    local sl_sum = `sl_h' + `sl_f' + `sl_b'
    di "  " %3.0f `dval' " | " %9.4f `sl_h' " | " %10.4f `sl_f' ///
       " | " %10.4f `sl_cb' " | " %10.4f `sl_pb' " | " %10.4f `sl_b' ///
       " | " %6.3f `sl_sum'
}

di _newline "Interpretation:"
di "  If dh slope decreases with d => non-bank absorption slows (capacity fills)"
di "  If df slope decreases with d => foreign absorption slows (default ceiling)"
di "  If db slope increases with d => banking steps in as residual absorber"
di "  Strict pecking order => dh slope starts near 1, then drops; df rises then drops"
di "  Simultaneous allocation => slopes are stable, all sectors absorb in parallel"

****************************************************
* DEBT ALLOCATION WITH COUNTRY + YEAR FIXED EFFECTS
*
* Same regressions as above but with xtreg fe + i.year,
* so we isolate within-country variation over time.
****************************************************

di _newline(3) "=========================================="
di "  DEBT ALLOCATION WITH COUNTRY + YEAR FE"
di "=========================================="

* =============================================
* (4) Quadratic + FE: dj = beta*d + kappa*d^2 + country FE + year FE
* =============================================
di _newline(2) "=========================================="
di "  (4) QUADRATIC + COUNTRY FE + YEAR FE"
di "=========================================="

di _newline "--- dh (non-bank) ---"
xtreg dh c.d c.d_sq i.year, fe vce(cluster country_id)
estimates store alloc_h_quad_fe

di _newline "--- df (foreign) ---"
xtreg df c.d c.d_sq i.year, fe vce(cluster country_id)
estimates store alloc_f_quad_fe

di _newline "--- dcb (central bank) ---"
xtreg dcb c.d c.d_sq i.year, fe vce(cluster country_id)
estimates store alloc_cb_quad_fe

di _newline "--- dpb (private bank) ---"
xtreg dpb c.d c.d_sq i.year, fe vce(cluster country_id)
estimates store alloc_pb_quad_fe

di _newline "--- db (banking total) ---"
xtreg db c.d c.d_sq i.year, fe vce(cluster country_id)
estimates store alloc_b_quad_fe

di _newline(2) "  Quadratic + FE coefficients (d and d^2 only):"
estimates table alloc_h_quad_fe alloc_f_quad_fe alloc_cb_quad_fe alloc_pb_quad_fe alloc_b_quad_fe, ///
    keep(d d_sq) star(0.10 0.05 0.01) stats(N r2_w r2_b r2_o)

* =============================================
* (5) Threshold + FE: dj = beta*d + mu*d_high_c + country FE + year FE
* =============================================
di _newline(2) "=========================================="
di "  (5) THRESHOLD + COUNTRY FE + YEAR FE"
di "=========================================="

di _newline "--- dh (non-bank) ---"
xtreg dh c.d c.d_high_c i.year, fe vce(cluster country_id)
estimates store alloc_h_thr_fe

di _newline "--- df (foreign) ---"
xtreg df c.d c.d_high_c i.year, fe vce(cluster country_id)
estimates store alloc_f_thr_fe

di _newline "--- dcb (central bank) ---"
xtreg dcb c.d c.d_high_c i.year, fe vce(cluster country_id)
estimates store alloc_cb_thr_fe

di _newline "--- dpb (private bank) ---"
xtreg dpb c.d c.d_high_c i.year, fe vce(cluster country_id)
estimates store alloc_pb_thr_fe

di _newline "--- db (banking total) ---"
xtreg db c.d c.d_high_c i.year, fe vce(cluster country_id)
estimates store alloc_b_thr_fe

di _newline(2) "  Threshold + FE coefficients (d and d_high_c only):"
estimates table alloc_h_thr_fe alloc_f_thr_fe alloc_cb_thr_fe alloc_pb_thr_fe alloc_b_thr_fe, ///
    keep(d d_high_c) star(0.10 0.05 0.01) stats(N r2_w r2_b r2_o)

* =============================================
* Marginal absorption rates from quadratic + FE
* =============================================
di _newline(2) "=========================================="
di "  MARGINAL ABSORPTION RATES (quadratic + FE)"
di "  slope_j(d) = beta_j + 2*kappa_j * d"
di "=========================================="

foreach sector in h f cb pb b {
    estimates restore alloc_`sector'_quad_fe
    local beta_`sector'_fe = _b[d]
    local kappa_`sector'_fe = _b[d_sq]
}

di _newline "  d   |  dh slope  |  df slope  | dcb slope  | dpb slope  |  db slope  |  Sum"
di "  ----|-----------|------------|------------|------------|------------|-------"
foreach dval in 20 40 60 80 100 120 150 180 {
    local sl_h  = `beta_h_fe'  + 2*`kappa_h_fe' *`dval'
    local sl_f  = `beta_f_fe'  + 2*`kappa_f_fe' *`dval'
    local sl_cb = `beta_cb_fe' + 2*`kappa_cb_fe'*`dval'
    local sl_pb = `beta_pb_fe' + 2*`kappa_pb_fe'*`dval'
    local sl_b  = `beta_b_fe'  + 2*`kappa_b_fe' *`dval'
    local sl_sum = `sl_h' + `sl_f' + `sl_b'
    di "  " %3.0f `dval' " | " %9.4f `sl_h' " | " %10.4f `sl_f' ///
       " | " %10.4f `sl_cb' " | " %10.4f `sl_pb' " | " %10.4f `sl_b' ///
       " | " %6.3f `sl_sum'
}

di _newline "  Comparison: pooled vs FE"
di "  Pooled captures cross-country + within-country variation"
di "  FE isolates within-country: as a given country's debt rises,"
di "  how does each sector's absorption change?"

log close
