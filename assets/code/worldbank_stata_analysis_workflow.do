/*==============================================================================
  eMBeD STATA Test – Q1-Q4
  Author: Minjae Seo
  AI Usage description:
  - Tool: ChatGPT-5.
  - Use: formatting structure, syntax checks, and graph-format suggestions.
  - Independent work: variable construction, model choices, estimation, and interpretation.
==============================================================================*/

clear all
set more off
cap log close
log using "stata_test_log.smcl", replace
cd "/Users/seominjae/Desktop/DECDI/package for applicants"
cap mkdir table
cap mkdir figure

** Install required packages, uncomment the code below **

/* cap which esttab
if _rc ssc install estout, replace
cap which coefplot
if _rc ssc install coefplot, replace */

********************************************************************************
* QUESTION 1
********************************************************************************

*** Q1A: Import & Verify ***
import delimited "test dataset.csv", clear varnames(1)
desc
isid respondent_id
tab1 c1 c2 c5 c9 c7 c8 e9 statement h4 h5_1 h5_2 h5_3 h5_4 h5_5 h5_98 h7
sum c3, d

/* Q1A ANSWER:
   - Data import checks pass: N=1,000, 20 variables, respondent_id unique.
   - Key diagnostics: missing in c5=184, e9=4; treatment arms balanced (242-257). */


********************************************************************************
* QUESTION 2 
********************************************************************************

*** Q2A: Missing values ***
* Count missing values by variable type
ds, has(type string)
foreach v of varlist `r(varlist)' {
    qui count if `v' == ""
    if r(N) > 0 di "`v': `r(N)' missing"
}
ds, has(type numeric)
foreach v of varlist `r(varlist)' {
    qui count if missing(`v')
    if r(N) > 0 di "`v': `r(N)' missing"
}

/* Q2A ANSWER:
   - Variables with missing values: c5 (184), e9 (4). */

*** Q2B: Recode special codes -> missing ***
* 97/98 non-substantive responses -> missing
replace c5 = "" if strmatch(lower(c5), "don*know")
replace c7 = "" if c7 == "Refused"
replace c8 = "" if c8 == "Refused" | strmatch(lower(c8), "don*know")
replace e9 = "" if strmatch(lower(e9), "don*know")

/* Q2B ANSWER:
   - Recode to missing: c5 "Don't Know", c7 "Refused", c8 "Refused/Don't know", e9 "Don't Know". */

*** Q2C: Combined outcome ***
gen byte female = (c2 == "Female")

foreach v in h5_1 h5_2 h5_3 h5_4 h5_5 h5_98 h7 {
    gen byte `v'_b = (`v' == "Yes")
    drop `v'
    rename `v'_b `v'
}

// h5_1-h5_4 = 4 waste actions; h5_5(None) & h5_98(DK) excluded
egen byte actions = rowtotal(h5_1 h5_2 h5_3 h5_4)
replace actions = . if h5_98 == 1

/* Q2C ANSWER:
   - Combined outcome: actions = h5_1+h5_2+h5_3+h5_4 (0-4), excluding h5_5 and h5_98.
   - Set actions missing when h5_98=1. */

*** Q2D: Median ***
sum actions, d
di "Median: " r(p50)

/* Q2D ANSWER:
   - Median(actions)=1 (Mean=1.6, SD=1.03, N=945). */

*** Q2E: Standardize at municipality level ***
encode municipality, gen(muni)

bys muni: egen a_m = mean(actions)
bys muni: egen a_s = sd(actions)
gen actions_z = (actions - a_m) / a_s
drop a_m a_s

/* Q2E ANSWER:
   - Standardization is within municipality: actions_z=(actions-mean_muni)/sd_muni.
   - This is a within-municipality metric, not overall-sample standardization. */

*** Q2F: Labels ***
lab var actions   "Intended waste actions (0-4)"
lab var actions_z "Standardized actions (muni z-score)"
lab var female    "Female"

/* Q2F ANSWER:
   - New variables were labeled (female, actions, actions_z). */


********************************************************************************
* QUESTION 3 
********************************************************************************

*** Q3A: Distribution tables***
gen byte age_grp = irecode(c3, 29, 44, 59, 200)
lab define agl 0 "18-29" 1 "30-44" 2 "45-59" 3 "60+"
lab val age_grp agl
lab var age_grp "Age group"

// Excel tables
preserve
contract c2, freq(n) percent(pct)
export excel using "table/q3a_distribution.xlsx", sheet("Gender") firstrow(var) replace
restore

preserve
decode age_grp, gen(age_str)
contract age_str, freq(n) percent(pct)
export excel using "table/q3a_distribution.xlsx", sheet("Age") firstrow(var) sheetreplace
restore

preserve
drop if missing(c8)
contract c8, freq(n) percent(pct)
export excel using "table/q3a_distribution.xlsx", sheet("Education") firstrow(var) sheetreplace
restore

/* Q3A ANSWER:
   - Exported Excel distributions for gender, age groups, and education(Please refer to each different excel sheet).
   - Exported three regional bar graphs (gender, age group, education). */

* Regional variation graphs

* Table for gender
graph bar (count), over(c2) by(region, cols(2) ///
    note("Region code legend: R1 = M01-M06, R2 = M07-M10.") ///
    title("Gender by Region")) legend(off) ytitle("Frequency")
graph export "figure/q3a_gender_region.png", replace width(1800)

* Table for age group
graph bar (count), over(age_grp) by(region, cols(2) ///
    note("Region code legend: R1 = M01-M06, R2 = M07-M10.") ///
    title("Age Group by Region")) legend(off) ytitle("Frequency")
graph export "figure/q3a_age_region.png", replace width(1800)

graph hbar (count) if !missing(c8), ///
    over(c8, sort(1) descending label(labsize(vsmall))) ///
    by(region, cols(2) note("Region code legend: R1 = M01-M06, R2 = M07-M10.") ///
        title("Education by Region")) ///
    legend(off)
graph export "figure/q3a_education_region.png", replace width(2200)

// strings to numeric
foreach v of varlist c1 c2 c5 c9 c7 c8 e9 statement h4 {
    encode `v', gen(`v'_n)
    drop `v'
    ren `v'_n `v'
}
drop municipality region

*** Q3B: Environmental concern by municipality ***
* Single descriptive figure for municipality patterns
graph hbar (percent), ///
    over(e9, sort(1) descending label(labsize(small))) ///
    by(muni, cols(2) compact ///
        note("Region code legend: R1 = M01-M06, R2 = M07-M10.") ///
        title("Environmental Concern by Municipality")) ///
    blabel(bar, format(%4.1f) size(vsmall)) ///
    legend(off)
graph export "figure/q3b_env_concern.png", replace width(2200)

/* Q3B ANSWER:
   - Environmental concern is high across municipalities; "Definitely Worried" is dominant. */

*** Q3C: Balance table ***
eststo clear
foreach v in female c3 c8 c7 c5 e9 {
    eststo bal_`v': qui reg `v' ib1.statement, r
    qui testparm i.statement
    estadd scalar F_p = r(p)
}

esttab bal_* using "table/q3c_balance.xlsx", replace ///
    cells("b(star fmt(3)) se(par fmt(3))") ///
    mtitles("Female" "Age" "Educ" "Marital" "Housing" "EnvConcern") ///
    coeflabels(_cons "Control Mean") label ///
    stats(N F_p, fmt(0 3) labels("N" "Joint F p-val"))

/* Q3C ANSWER:
   - All joint balance p-values > 0.05; baseline covariates are balanced across treatment arms. */


********************************************************************************
* QUESTION 4 
********************************************************************************
/* Outcomes: h5_1 h5_2 h5_3 h5_4 h5_5 actions actions_z
   Controls: demographic vars | FE: municipality
   Encode order: 1=Control 2=Health 3=Individual 4=Natural Resource */

*** Q4A: Treatment effect on reliability (H4) ***
// Recode h4 to ordinal 
// 1=Neither, 2=Somewhat unreliable, 3=Very unreliable, 4=Somewhat reliable, 5=Very reliable
recode h4 (1=3) (2=2) (3=1) (4=4) (5=5), gen(h4_ord)
lab var h4_ord "Reliability (1=very unreliable to 5=very reliable)"

reg h4_ord ib1.statement, r

/* Q4A ANSWER:
   - All treatment framings increased perceived reliability vs control:
     Health = +0.540, Individual = +0.499, Natural Resource = +0.465.
   - All three effects are statistically significant (p<0.001). */

*** Q4B: Simple regressions (no tables) ***
foreach y in h5_1 h5_2 h5_3 h5_4 h5_5 actions actions_z {
    reg `y' ib1.statement, r
}

*** Q4C: Controls + fixed effects ***
/* Controls: female, age (c3), education (i.c8).
   c5 is excluded due to many missing values; c7 is excluded for limited relevance.
   Fixed effects: i.muni to absorb local unobserved heterogeneity. */
local ctrls "female c3 i.c8"

eststo clear
foreach y in h5_1 h5_2 h5_3 h5_4 h5_5 actions actions_z {
    eststo f_`y': reg `y' ib1.statement `ctrls' i.muni, r
}

/* Q4C ANSWER:
   - Re-estimated treatment effects with demographic controls and municipality fixed effects. */

*** Q4D: Final results — Excel + coefficient plot ***
esttab f_* using "table/q4d_results.xlsx", replace ///
    cells("b(star fmt(3)) se(par fmt(3))") ///
    keep(2.statement 3.statement 4.statement) label ///
    mtitles("Segregate" "Legal Dump" "No Plastic" "Reuse" "None" "Actions" "Actions(z)") ///
    stats(N r2, fmt(0 3) labels("N" "R-squared"))

coefplot (f_h5_1, label("Segregate")) (f_h5_2, label("Legal Dump")) ///
    (f_h5_3, label("No Plastics")) (f_h5_4, label("Reuse")) ///
    (f_h5_5, label("None")) ///
    (f_actions, label("Actions")), ///
    keep(2.statement 3.statement 4.statement) xline(0) ///
    coeflabels(2.statement="Health" 3.statement="Individual" ///
        4.statement="Natural Resource") ///
    title("Treatment Effects on Waste Actions")
graph export "figure/q4d_coefplot.png", replace

/* Q4D ANSWER:
   - Main results (all H5 outcomes + actions + actions_z) exported to Excel
     with controls and municipality fixed effects.
   - Coefficient plot summarizes treatment effects and 95% confidence intervals.
   - Effects are interpreted as ITT estimates. */

*** Q4E: Alternative outcome — PCA index ***
pca h5_1 h5_2 h5_3 h5_4
predict actions_pca, score
replace actions_pca = . if h5_98 == 1
lab var actions_pca "PCA action index (1st component)"

/* Q4E ANSWER:
   - Built an alternative outcome using PCA (first component of h5_1-h5_4).
   - Estimated treatment effects on the PCA index with the same controls + FE. */

eststo f_pca: qui reg actions_pca ib1.statement `ctrls' i.muni, r
esttab f_pca, cells("b(star fmt(3)) se(par fmt(3))") ///
    keep(2.statement 3.statement 4.statement) label

*** Q4F: Randomization Inference ***
// Regression p-value for comparison
reg h5_1 ib1.statement, r
test 3.statement
local reg_p = r(p)
di "Regression p-value (statement=3 vs control): `reg_p'"

// Part 1: RI for all treatment arms on h5_1
set seed 12345
permute statement _b[2.statement] _b[3.statement] _b[4.statement], ///
    reps(1000): reg h5_1 ib1.statement

// Part 2: RI for statement=3 vs control on h5_1
preserve
keep if statement == 1 | statement == 3
gen byte treat3 = (statement == 3)
permute treat3 _b[treat3], reps(1000) seed(12345): reg h5_1 treat3
restore

/* Q4F ANSWER:
   - Regression p-value for statement=3 vs control on h5_1: 0.1563.
   - RI two-sided p-values (1,000 reps): statement=2 -> 0.036,
     statement=3 -> 0.172, statement=4 -> 0.240.
   - RI two-sided p-value for statement=3 vs control: 0.182.
   - Conclusion: statement=3 effect is not statistically significant in both
     regression and RI; RI is slightly more conservative. */

log close
