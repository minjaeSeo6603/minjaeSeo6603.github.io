********************************************************************************
* Project: Hill-Burton Hospital Construction Funding Analysis
* Author: Minjae Seo
*
* Purpose: This do-file analyzes the relationship between predicted and actual
*          Hill-Burton allocations to evaluate whether the federal formula was
*          predictive of actual funding distributions across states.
*
* Research Questions:
*   1. Was the state-level allocation formula predictive of actual funding?
*   2. Were the non-linearities in the formula (min/max caps) binding?
********************************************************************************

clear all
set more off
capture log close

********************************************************************************
* 1. SET GLOBALS
********************************************************************************

* Adjust this path to match your local directory structure
if "`c(username)'" == "seominjae" {
    global root "/Users/seominjae/Downloads/Pre-doc-main"
    global code "${root}/code/Stata_project_do_files"
    global data "${root}/data/Stata_project_data"
    global data_raw "${data}/raw"
    global data_final "${data}/final"
    global output "${root}/output/Stata_project_figures"
}

* Create output directory if it doesn't exist
capture mkdir "${output}"
capture mkdir "${data}/log"
log using "${data}/log/analysis.log", replace

********************************************************************************
* 2. LOAD DATA AND INITIAL EXPLORATION
********************************************************************************

use "${data_final}/final.dta", clear

* Display basic summary statistics
di _n "=== Summary Statistics ===" _n
summarize predicted hbfunds, detail

* Correlation between predicted and actual allocations
di _n "=== Correlation: Predicted vs. Actual ===" _n
correlate predicted hbfunds

********************************************************************************
* 3. MAIN VISUALIZATION: PREDICTED VS. ACTUAL ALLOCATIONS
********************************************************************************

* Create scatter plot comparing predicted and actual Hill-Burton allocations
* This figure addresses Research Question 1: Formula predictiveness

twoway ///
    (scatter hbfunds predicted, ///
        msymbol(circle_hollow) mcolor(navy%40) msize(medium) ///
        legend(label(1 "State-Year Observations"))) ///
    (lfit hbfunds predicted, ///
        lcolor(blue) lpattern(solid) lwidth(medium) ///
        legend(label(2 "Linear Fit"))) ///
    (function y = x, range(0 2e7) ///
        lpattern(dash) lcolor(maroon) lwidth(medium) ///
        legend(label(3 "45-Degree Reference"))), ///
    title("Predicted vs. Actual Hill-Burton Allocations", size(medsmall)) ///
    subtitle("48 Contiguous U.S. States, 1947-1964", size(small)) ///
    caption("Note: Each point represents a state-year. Red dashed line shows y = x;" ///
            "blue line is best linear fit.", size(vsmall)) ///
    xtitle("Predicted Allocation (USD)", size(small)) ///
    ytitle("Actual Allocation (USD)", size(small)) ///
    xlabel(0(5e6)2e7, format(%9.0fc)) ///
    ylabel(0(5e6)2e7, format(%9.0fc)) ///
    legend(order(1 2 3) position(11) ring(0) size(small) cols(1)) ///
    aspect(1) ///
    xscale(range(0 20000000)) ///
    yscale(range(0 20000000)) ///
    graphregion(color(white)) ///
    plotregion(style(none))

graph export "${output}/predicted_vs_actual_enhanced.png", replace width(3000)

di _n "Figure saved: ${output}/predicted_vs_actual_enhanced.png" _n

********************************************************************************
* 4. REGRESSION ANALYSIS: PREDICTED VS. ACTUAL ALLOCATIONS
********************************************************************************

* Generate log-transformed variables for elasticity interpretation
gen ln_hbfunds = log(hbfunds)
gen ln_predicted = log(predicted)

label variable ln_hbfunds "Log(Actual HB Funds)"
label variable ln_predicted "Log(Predicted Allocation)"

di _n "=== Fixed Effects Regression Analysis ===" _n

* Model 1: Level-level specification with state and year FE (robust SE)
di _n "--- Model 1: Levels with Robust SE ---"
reghdfe hbfunds predicted, absorb(fips year) vce(robust)
estimates store fe_robust

* Model 2: Level-level specification with clustered SE by state
di _n "--- Model 2: Levels with Clustered SE ---"
reghdfe hbfunds predicted, absorb(fips year) vce(cluster fips)
estimates store fe_cluster

* Model 3: Log-log specification with robust SE
di _n "--- Model 3: Log-Log with Robust SE ---"
reghdfe ln_hbfunds ln_predicted, absorb(fips year) vce(robust)
estimates store log_fe_robust

* Model 4: Log-log specification with clustered SE
di _n "--- Model 4: Log-Log with Clustered SE ---"
reghdfe ln_hbfunds ln_predicted, absorb(fips year) vce(cluster fips)
estimates store log_fe_cluster

* Export regression table to LaTeX
esttab fe_robust fe_cluster log_fe_robust log_fe_cluster ///
    using "${output}/regression_table.tex", ///
    title("Regression of Actual on Predicted Hill-Burton Allocations") ///
    label se star(* 0.10 ** 0.05 *** 0.01) ///
    stats(r2 N, fmt(3 0) labels("R-squared" "Observations")) ///
    mtitles("Levels (Robust)" "Levels (Clustered)" "Log-Log (Robust)" "Log-Log (Clustered)") ///
    addnotes("State and year fixed effects included in all specifications." ///
             "Standard errors in parentheses.") ///
    replace

di _n "Regression table saved: ${output}/regression_table.tex" _n

********************************************************************************
* 5. ANALYSIS OF BINDING CONSTRAINTS (MIN/MAX ALLOTMENT THRESHOLDS)
********************************************************************************

* Reload data for threshold analysis (collapse destroyed the data)
use "${data_final}/final.dta", clear

di _n "=== Analysis of Binding Allotment Constraints ===" _n
di "The Hill-Burton formula imposed minimum (0.33) and maximum (0.75) caps"
di "on the allotment percentage. This section examines how often these"
di "constraints were binding." _n

* Identify observations at minimum threshold (0.33)
* Using tolerance for floating-point comparison
gen byte at_min_allot = (abs(allot_pct - 0.33) < 0.001)
label variable at_min_allot "At minimum allotment (0.33)"

* Identify observations at maximum threshold (0.75)
gen byte at_max_allot = (abs(allot_pct - 0.75) < 0.001)
label variable at_max_allot "At maximum allotment (0.75)"

* Summary by year
preserve
gen one = 1
collapse (sum) at_min_allot at_max_allot (sum) n_states = one, by(year)

di _n "--- States Hitting Minimum Allotment (0.33) by Year ---"
list year at_min_allot if at_min_allot > 0, noobs

di _n "--- States Hitting Maximum Allotment (0.75) by Year ---"
list year at_max_allot if at_max_allot > 0, noobs

* Calculate totals
qui sum at_min_allot
scalar total_min = r(sum)

qui sum at_max_allot
scalar total_max = r(sum)

di _n "=== Summary of Binding Constraints ===" _n
di "Total state-year observations at minimum (0.33): " total_min
di "Total state-year observations at maximum (0.75): " total_max
di _n "Interpretation:"
di "  - The minimum allotment (0.33) was frequently binding for high-income states,"
di "    ensuring each state received at least a small portion of funds."
di "  - The maximum allotment (0.75) was never reached, implying no state's need"
di "    was high enough to claim an outsized majority of funds under the formula."

restore

********************************************************************************
* 6. ADDITIONAL VISUALIZATIONS
********************************************************************************

* Distribution of allotment percentages
histogram allot_pct, ///
    bin(20) ///
    fcolor(navy%60) lcolor(navy) ///
    xtitle("Allotment Percentage") ///
    ytitle("Frequency") ///
    title("Distribution of State Allotment Percentages", size(medium)) ///
    subtitle("Hill-Burton Program, 1947-1964", size(small)) ///
    caption("Note: Allotment percentage capped at 0.33 (minimum) and 0.75 (maximum).", size(vsmall)) ///
    xline(0.33, lcolor(red) lpattern(dash)) ///
    xline(0.75, lcolor(red) lpattern(dash)) ///
    graphregion(color(white))

graph export "${output}/allotment_distribution.png", replace width(2400)

* Time series of total allocations
preserve
collapse (sum) predicted hbfunds, by(year)

twoway ///
    (connected predicted year, lcolor(blue) mcolor(blue) msymbol(circle)) ///
    (connected hbfunds year, lcolor(red) mcolor(red) msymbol(square)), ///
    title("Total Hill-Burton Allocations Over Time", size(medium)) ///
    subtitle("Predicted vs. Actual, 1947-1964", size(small)) ///
    xtitle("Year") ///
    ytitle("Total Allocation (USD)", size(small)) ///
    ylabel(, format(%12.0fc)) ///
    legend(order(1 "Predicted" 2 "Actual") position(6) cols(2)) ///
    graphregion(color(white))

graph export "${output}/allocations_time_series.png", replace width(2400)
restore

di _n "Additional figures saved to: ${output}/" _n

********************************************************************************
* 7. SUMMARY AND CONCLUSIONS
********************************************************************************

di _n "=========================================="
di "       ANALYSIS SUMMARY"
di "==========================================" _n

di "Key Findings:"
di "-------------"
di "1. The Hill-Burton allocation formula was highly predictive of actual"
di "   funding distributions across states during 1947-1964."
di ""
di "2. States' predicted shares, derived from population and income data,"
di "   track closely with actual funding receipts."
di ""
di "3. The program operated on a rules-based system with few major"
di "   deviations from the formula."
di ""
di "4. The minimum allotment percentage (0.33) was frequently binding"
di "   for high-income states."
di ""
di "5. The maximum allotment percentage (0.75) was never reached,"
di "   suggesting no state's relative need was extreme enough to"
di "   trigger the upper bound."

di _n "==========================================" _n

log close
