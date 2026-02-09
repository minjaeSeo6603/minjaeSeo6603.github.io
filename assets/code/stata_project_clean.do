********************************************************************************
* Stata Data Task: Data Cleaning
* Project: Hill-Burton Hospital Construction Funding Analysis
* Author: Minjae Seo
* Date: May 15, 2025
*
* Purpose: This do-file imports and cleans raw data on state population and
*          per-capita income, then computes predicted Hill-Burton allocations
*          using the federal formula specified in the Federal Register (1946).
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

* Create log directory if it doesn't exist
capture mkdir "${data}/log"
log using "${data}/log/clean.log", replace

********************************************************************************
* 2. IMPORT AND CLEAN PER-CAPITA INCOME DATA
********************************************************************************

* Import per-capita personal income data (1943-1962) from Bureau of Economic Analysis
import delimited using "${data_raw}/pcinc.csv", varnames(1) case(lower) clear

* Drop aggregate rows (US total, regions, DC, Alaska, Hawaii) and footnote rows
drop if areaname == "United States"
drop if areaname == "District of Columbia"
drop if areaname == "Alaska" | areaname == "Hawaii 3/"
drop if inlist(areaname, "New England", "Mideast", "Great Lakes", ///
               "Plains", "Southeast", "Southwest", "Rocky Mountain", "Far West 3/")
drop if _n > _N - 5

* Rename year columns (v4 = 1943, v5 = 1944, ..., v23 = 1962)
forvalues i = 4/23 {
    local year = 1939 + `i'
    rename v`i' inc`year'
}

* Convert string income values to numeric
destring inc1943-inc1949, replace

* Reshape from wide to long format (one observation per state-year)
reshape long inc, i(areaname) j(year)
rename inc pcinc
rename areaname state

* Label variables
label variable state "State name"
label variable year "Year"
label variable pcinc "Per-capita personal income (current $)"

* Keep only necessary variables
keep state fips year pcinc
order state fips year pcinc

* Save cleaned income data
save "${data_raw}/pcinc_clean.dta", replace

********************************************************************************
* 3. IMPORT AND CLEAN POPULATION DATA
********************************************************************************

* Import population data (1947-1964) from Bureau of Economic Analysis
import delimited using "${data_raw}/pop.csv", varnames(1) case(lower) clear

* Drop aggregate rows and non-contiguous states
drop if areaname == "United States"
drop if areaname == "District of Columbia"
drop if areaname == "Alaska" | areaname == "Hawaii 3/"
drop if inlist(areaname, "New England", "Mideast", "Great Lakes", ///
               "Plains", "Southeast", "Southwest", "Rocky Mountain", "Far West 3/")
drop if _n > _N - 5

* Rename year columns (v4 = 1947, v5 = 1948, ..., v21 = 1964)
forvalues i = 4/21 {
    local year = 1943 + `i'
    rename v`i' inc`year'
}

* Convert string population values to numeric
destring inc1947-inc1964, replace

* Reshape from wide to long format
reshape long inc, i(areaname) j(year)
rename inc pop
rename areaname state

* Label variables
label variable state "State name"
label variable year "Year"
label variable pop "Population"

* Keep only necessary variables
keep state fips year pop
order state fips year pop

* Save cleaned population data
save "${data_raw}/pop_clean.dta", replace

********************************************************************************
* 4. EXTEND INCOME DATA TO 1963-1964 (FOR LAGGED CALCULATIONS)
********************************************************************************

use "${data_raw}/pcinc_clean.dta", clear

* Create template with state names
preserve
keep state
duplicates drop
tempfile states
save `states'
restore

* Generate placeholder observations for 1963-1964
clear
input year
1963
1964
end
cross using `states'
gen pcinc = .

* Append to income data
append using "${data_raw}/pcinc_clean.dta"
duplicates drop state year, force
sort state year
save "${data_raw}/pcinc_clean.dta", replace

********************************************************************************
* 5. EXTEND POPULATION DATA TO 1943-1946 (FOR LAGGED CALCULATIONS)
********************************************************************************

use "${data_raw}/pop_clean.dta", clear

* Create template with state names
preserve
keep state
duplicates drop
tempfile states
save `states'
restore

* Generate placeholder observations for 1943-1946
clear
input year
1943
1944
1945
1946
end
cross using `states'
gen pop = .

* Append to population data
append using "${data_raw}/pop_clean.dta"
duplicates drop state year, force
sort state year
save "${data_raw}/pop_clean.dta", replace

********************************************************************************
* 6. MERGE INCOME AND POPULATION DATA
********************************************************************************

use "${data_raw}/pcinc_clean.dta", clear
merge 1:1 state year using "${data_raw}/pop_clean.dta", keep(match) nogenerate

* Organize variables
order state fips year pop pcinc
label variable state "State"
label variable year "Year"
label variable pcinc "Per-capita income (current $)"
label variable pop "Population"

* Create state-year identifier
gen str stateyear = state + string(year)
label variable stateyear "State-Year ID"

********************************************************************************
* 7. CALCULATE PREDICTED ALLOCATIONS USING HILL-BURTON FORMULA
********************************************************************************

* The allotment formula is specified in the Federal Register (31 Aug 1946):
*   (1) Calculate 3-year moving average of state per-capita income (lagged 2-4 years)
*   (2) Compute national average of smoothed income
*   (3) Create index = state smoothed income / national smoothed income
*   (4) Allotment percentage = 1 - 0.5 * index (capped at 0.33-0.75)
*   (5) Weighted population = (allotment percentage)^2 * population
*   (6) State share = weighted population / total weighted population
*   (7) Predicted allocation = state share * federal appropriation

* Ensure panel is properly sorted
destring fips, replace
sort state year

* Step 1: Create lagged income variables
by state: gen lag2 = pcinc[_n-2]   // 2 years prior
by state: gen lag3 = pcinc[_n-3]   // 3 years prior
by state: gen lag4 = pcinc[_n-4]   // 4 years prior

* Step 2: Calculate smoothed per-capita income (3-year moving average)
gen sm_pcinc = (lag4 + lag3 + lag2) / 3 if year >= 1947
label variable sm_pcinc "Smoothed PC income (avg of t-2, t-3, t-4)"

* Step 3: Calculate national average of smoothed income for each year
sort year
by year: egen nat_sm_pcinc = mean(sm_pcinc)
label variable nat_sm_pcinc "National avg smoothed PC income"

* Step 4: Create income index (state relative to national)
gen index = sm_pcinc / nat_sm_pcinc
label variable index "Income index (state/national)"

* Step 5: Calculate allotment percentage with floor and ceiling
gen allot_pct = 1 - 0.5 * index
replace allot_pct = 0.33 if allot_pct < 0.33  // Minimum allotment
replace allot_pct = 0.75 if allot_pct > 0.75  // Maximum allotment
label variable allot_pct "Allotment percentage (capped 0.33-0.75)"

* Step 6: Calculate weighted population
gen weighted_pop = allot_pct^2 * pop
label variable weighted_pop "Weighted population (allotment^2 * pop)"

* Step 7: Calculate state allocation share
by year: egen total_wpop = total(weighted_pop)
gen alloc_share = weighted_pop / total_wpop
label variable alloc_share "State share of total allocation"

* Keep only program years (1947-1964)
drop if year < 1947
save "${data_raw}/pop_pcinc_first.dta", replace

********************************************************************************
* 8. MERGE FEDERAL APPROPRIATIONS DATA
********************************************************************************

* Federal appropriations by year (in current dollars)
* Source: Annual Congressional appropriations for Hill-Burton program
clear
input int(year) double(appr)
1947   75000000
1948   75000000
1949   75000000
1950   150000000
1951   85000000
1952   82500000
1953   75000000
1954   65000000
1955   96000000
1956   109800000
1957   123800000
1958   120000000
1959   147502832
1960   168589438
1961   160494355
1962   195741119
1963   195930360
1964   180166150
end
format %15.0fc appr
tempfile apprdata
save `apprdata', replace

* Merge appropriations into panel
use "${data_raw}/pop_pcinc_first.dta", clear
merge m:1 year using `apprdata', keep(match master) nogenerate
label variable appr "Federal HB appropriation ($)"

* Step 8: Calculate predicted dollar allocation
gen predicted = alloc_share * appr
label variable predicted "Predicted allocation ($)"

* Step 9: Apply minimum dollar allotments
* $100,000 minimum in 1948; $200,000 minimum in 1949 and later
replace predicted = 100000 if year == 1948 & predicted < 100000
replace predicted = 200000 if year >= 1949 & predicted < 200000

* Format predicted values
format %14.2fc predicted

save "${data_raw}/pop_pcinc.dta", replace

********************************************************************************
* 9. IMPORT AND AGGREGATE ACTUAL HILL-BURTON ALLOCATIONS
********************************************************************************

* Import Hill-Burton Project Register data
clear
import delimited using "${data_raw}/hbpr.txt", delim("\t") varnames(1) encoding("UTF-8")

* Keep relevant variables
keep state year hillburtonfunds
rename hillburtonfunds hbfunds

* Convert funds to numeric (remove commas)
destring hbfunds, replace ignore(",")
label variable hbfunds "Actual Hill-Burton funds ($)"

* Convert 2-digit year to 4-digit year
replace year = 1900 + year

* Filter for 48 contiguous states and program years (1947-1964)
drop if year < 1947 | year > 1964
drop if inlist(state, "Alaska", "Dist of Col", "Guam", "Hawaii", "Puerto Rico", "Virgin Islands")

* Collapse project-level data to state-year totals
collapse (sum) hbfunds, by(state year)
format %14.2fc hbfunds

* Save actual allocations
save "${data_raw}/actual.dta", replace

********************************************************************************
* 10. CREATE FINAL ANALYSIS DATASET
********************************************************************************

* Merge predicted and actual allocations
use "${data_raw}/pop_pcinc.dta", clear
merge 1:1 state year using "${data_raw}/actual.dta", keep(match master) nogenerate

* Organize variables
order state year predicted hbfunds pcinc pop

* Set missing actual funds to zero (no funding that year)
replace hbfunds = 0 if missing(hbfunds)
label variable hbfunds "Actual HB funds ($)"

* Save full analysis dataset
save "${data_final}/final.dta", replace

* Create balanced panel with key variables for Question 1
preserve
keep stateyear predicted hbfunds
order stateyear predicted hbfunds
save "${data_final}/balanced.dta", replace
restore

********************************************************************************
* 11. SUMMARY STATISTICS
********************************************************************************

* Display summary of key variables
summarize predicted hbfunds pop pcinc allot_pct, detail

* Correlation between predicted and actual allocations
correlate predicted hbfunds

di _n "=== Data Cleaning Complete ===" _n
di "Final dataset saved to: ${data_final}/final.dta"
di "Balanced dataset saved to: ${data_final}/balanced.dta"
di "Observations: " _N " state-years (48 states x 18 years)"

log close
