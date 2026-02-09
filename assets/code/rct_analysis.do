/*********************************************************************
**    - Import & clean demographics (household size, gender)
**    - Clean & process assets (median imputation, total asset values)
**    - Construct Kessler-10 score and depression categories
**    - Merge datasets into individual-wave level panel
*********************************************************************/

clear all
set more off

/****************************
* Set globals
****************************/

* Set file paths 
* Change to your working directory and file path

if "`c(username)'" == "seominjae"{
	global root "/Users/seominjae/Desktop/RCT"
	global figures "${root}/figures"
	global data_raw "${root}/data/raw"
	global data_clean "${root}/data/clean"
	global data_merge "${root}/data/merge"
}

*** Demographics: Import and Cleaning ***
use "${data_raw}/demographics.dta", clear

* Inspect the first few rows and variable names
list in 1/10  
describe  

* Ensure unique identifiers: Household ID, Household member ID, villageid, and wave are uniquely identifies observations
isid hhid hhmid villageid wave

* Convert gender and treat_hh to Dummy variables
decode gender, gen(gender_str)  // Convert labeled values to string
gen gender_num = .
replace gender_num = 1 if gender_str == "Female"
replace gender_num = 0 if gender_str == "Male"

* Drop the original gender variable
drop gender gender_str

* Rename the new numeric gender variable back to gender
rename gender_num gender

* Label the numeric gender variable for clarity
label variable gender "Gender"
label define gender_label 1 "Female" 0 "Male"
label values gender gender_label

* Verify that the conversion worked
desc gender
tab gender

* Define and apply treatment label
label define treat_label 0 "Control" 1 "Treatment"
label values treat_hh treat_label

* save data in the clean folders
save "${data_clean}/demographics_clean.dta", replace


*Q2*
/*
   Instructions: "Calculate a proxy variable for household size based on the
   number of members surveyed in each household in Wave 1. Assume the
   household size for Wave 2 remains the same."
*/

* Compute household size based on the number of members surveyed per household in Wave 1
egen hh_size_wave = count(hhmid) if wave == 1, by(hhid)

* Fill in the household size for Wave 2 using the same values from Wave 1
bysort hhid (wave): replace hh_size_wave = hh_size_wave[_n-1] if missing(hh_size_wave)

* Label the variable
label variable hh_size_wave "Household size (from Wave 1, assumed constant for Wave 2)"

* Verify results
list wave hhid hhmid hh_size_wave in 1/20
tabstat hh_size_wave, by(wave) statistics(n mean sd min max)

sort wave hhid hhmid

* Re-save demographics with hh_size_wave included
save "${data_clean}/demographics_clean.dta", replace

* Calculate the monetary value of all assets*
/*
   Instructions specify: "use the median of currentvalue for each TYPE of asset
   (by type we mean, for example, 'chickens', 'Cutlass', 'Room Furniture', etc.)"

   This means we should impute by SPECIFIC asset name (e.g., "chickens", "Radio"),
   NOT by broad Asset_Type category (Animals, Tools, Durables).

   DATA STRUCTURE:
   - Asset_Type = 1 (Animals): specific type in 'animaltype' variable
   - Asset_Type = 2 (Tools): specific type in 'toolcode' variable
   - Asset_Type = 3 (Durables): specific type in 'durablegood_code' variable
*/

* import assets data
use "${data_raw}/assets.dta", clear

* Remove leading zeros from `hhid`
* Convert `hhid` to numeric (ensuring no scientific notation)
destring hhid, replace force

* Ensure Stata displays the full number (fix scientific notation)
format hhid %12.0f  // Displays hhid as a full number

* Verify the data structure
describe
list in 1/10

* Check specific asset type variables
tab animaltype, missing
tab toolcode, missing
tab durablegood_code, missing

* Count missing values before imputation
count if missing(currentvalue)
display "Missing currentvalue observations before imputation: " r(N)

/*
   IMPUTATION STRATEGY:
   Per Instructions, impute missing currentvalue using median for each SPECIFIC asset type:
   - For animals: impute by animaltype (e.g., code for chickens, goats, etc.)
   - For tools: impute by toolcode (e.g., code for cutlass, hoe, etc.)
   - For durables: impute by durablegood_code (e.g., code for radio, furniture, etc.)
*/

* Create a unified asset code variable for imputation
* Combine the three code variables into one (they are mutually exclusive by Asset_Type)
gen asset_code = .
replace asset_code = animaltype if Asset_Type == 1
replace asset_code = 100 + toolcode if Asset_Type == 2  // Add 100 to avoid overlap
replace asset_code = 200 + durablegood_code if Asset_Type == 3  // Add 200 to avoid overlap
label variable asset_code "Combined asset type code (for imputation)"

* Impute missing current values using median by SPECIFIC asset code
bysort asset_code: egen med_val = median(currentvalue)
replace currentvalue = med_val if missing(currentvalue)

* Verify imputation results
count if missing(currentvalue)
display "Missing currentvalue observations after imputation: " r(N)

* Clean up temporary variables
drop med_val asset_code

*Q4: Create a variable that contains the total monetary value for each observation, by multiplying quantity and the imputed current value.*
* Calculate total value for each asset record (quantity * currentvalue)
gen totalvalue = quantity * currentvalue
list hhid wave quantity currentvalue totalvalue in 1/20

*Q5: Produce a dataset at the household-wave level (for each household, there should be at most two observations, one for each wave) which contains the following variables:*

* Create category-wise total values based on asset_type
gen total_animals  = totalvalue if Asset_Type == 1
replace total_animals = 0 if missing(total_animals)

gen total_tools = totalvalue if Asset_Type == 2
replace total_tools = 0 if missing(total_tools)

gen total_durables = totalvalue if Asset_Type == 3
replace total_durables = 0 if missing(total_durables)

collapse (sum) total_animals total_tools total_durables, by(hhid wave)

* Compute total asset value for each household-wave
gen total_assets = total_animals + total_tools + total_durables

* Label variables
label variable total_animals "Total value of animals (household, wave)"
label variable total_tools "Total value of tools (household, wave)"
label variable total_durables "Total value of durable goods (household, wave)"
label variable total_assets "Total asset value (household, wave)"

* save data
sort wave hhid
save "${data_clean}/assets_clean.dta", replace

*Q6: construct the kessler score (name it kessler score) and a categorical variable named kessler categories with 4 categories: no significant depression, mild depression, moderate depression, and severe depression*
/*
   Kessler-10 Scale:
   - 10 questions, each scored 1-5 (1=none of the time, 5=all of the time)
   - Total score range: 10-50
   - Higher scores indicate greater psychological distress

   Categories (based on standard K10 cut-offs):
   - 10-19: No significant depression (likely to be well)
   - 20-24: Mild depression (likely to have mild disorder)
   - 25-29: Moderate depression (likely to have moderate disorder)
   - 30-50: Severe depression (likely to have severe disorder)
*/

*import depression data*
use "${data_raw}/depression.dta", clear

* Check variable names for the 10 questions
describe

* Kessler-10 question variables
local k10_vars "tired nervous sonervous hopeless restless sorestless depressed everythingeffort nothingcheerup worthless"

* Count missing responses in Kessler-10 questions
egen missing_kessler = rowmiss(`k10_vars')
label variable missing_kessler "Number of Missing Kessler Questions"
tab missing_kessler, missing

/*
   HANDLING MISSING VALUES - Justification:

   Strategy: Mean imputation for respondents with 1-2 missing responses

   Rationale:
   - If only 1-2 of 10 questions are missing, we have 80-90% of the information
   - Mean imputation assumes missing values are similar to observed values
   - This preserves sample size while maintaining reasonable accuracy

   - If 3+ questions are missing (30%+), imputation becomes unreliable
   - These observations are set to missing (listwise deletion for analysis)

   Alternative approaches considered:
   - Complete case analysis: Would lose too many observations
   - Multiple imputation: More complex, may be overkill for 1-2 missing items
*/

* Calculate mean of non-missing Kessler items for each respondent
egen mean_kessler = rowmean(`k10_vars')

* Count number of non-missing responses
egen nonmiss_kessler = rownonmiss(`k10_vars')

* Generate total Kessler-10 score (sum of all 10 items)
gen kessler_score = tired + nervous + sonervous + hopeless + restless + sorestless + depressed + everythingeffort + nothingcheerup + worthless

* For respondents with 1-2 missing responses: impute using scaled mean
* (mean of available items * 10 to approximate total score)
replace kessler_score = round(mean_kessler * 10) if missing_kessler > 0 & missing_kessler <= 2

* Set score to missing for respondents with 3+ missing responses (unreliable imputation)
replace kessler_score = . if missing_kessler >= 3

* Remove temporary imputation variables
drop mean_kessler nonmiss_kessler

* Label the Kessler-10 score
label variable kessler_score "Kessler-10 Total Score (10-50, higher = more distress)"

* Verify score range
summarize kessler_score
assert kessler_score >= 10 & kessler_score <= 50 if !missing(kessler_score)

* Create categorical variable for distress levels (standard K10 cut-offs)
gen kessler_categories = .
replace kessler_categories = 0 if kessler_score >= 10 & kessler_score <= 19
replace kessler_categories = 1 if kessler_score >= 20 & kessler_score <= 24
replace kessler_categories = 2 if kessler_score >= 25 & kessler_score <= 29
replace kessler_categories = 3 if kessler_score >= 30 & kessler_score <= 50
replace kessler_categories = 4 if missing(kessler_score)  // Mark missing values

* Label the categories for interpretation
label define kessler_labels 0 "no significant depression" 1 "mild depression" 2 "moderate depression" 3 "severe depression" 4 "Missing"
label values kessler_categories kessler_labels
label variable kessler_categories "Kessler Categories"

* Justify Missingness
tabulate wave if missing_kessler > 0
* 313 missing Kessler-10 responses are entirely from Wave 1 (100%)
* We should not use strict listwise deletion, as it may distort comparisons.
* Use mean Imputations, which assumes that missing values are similar to observed values, but if 3+ responses are missing, this assumption is weaker
* Therefore, threshold for missing questions <2 for mean imputations

* Verify final results
tabulate kessler_categories, missing
summarize kessler_score

sort wave hhid hhmid

* save data
save "${data_clean}/depression_clean.dta", replace


*Q7:Constructing a single dataset*

* Load the demographics dataset (base dataset)
use "${data_clean}/demographics_clean.dta", clear

* Merge with the depression data
merge 1:1 wave hhid hhmid using "${data_clean}/depression_clean.dta"
sort wave hhid hhmid

* Check merge results
tab _merge

* Drop unmatched records (if necessary)
* _merge == 1: in demographics only (not in depression)
* _merge == 2: in depression only (not in demographics)
drop if _merge == 2   // Remove individuals in depression but not in demographics
drop _merge  // Remove merge indicator

* Merge with assets data
merge m:1 wave hhid using "${data_clean}/assets_clean.dta"
sort wave hhid 

* Drop unmatched household records from assets if they are not useful
drop if _merge == 2  // Remove extra households from assets that don't exist in demographics + depression

* Drop the merge indicator variable
drop _merge

* Save the final dataset
save "${data_merge}/merged.dta", replace

/*********************************************************************
** PART 2: EXPLORATORY ANALYSIS
** - Depression vs Household Wealth (Total Assets)
** - Depression vs Gender(Binary Indicator), age(Continuous),age_group (Demographic Characteristic)
*********************************************************************/

clear all
set more off
set scheme s2color  // Improved visualization theme

/****************************
* 1. Set Global Paths
****************************/

* Change file paths based on your system
if "`c(username)'" == "seominjae"{
    global root "/Users/seominjae/Desktop/RCT"
    global figures "${root}/figures"
    global tables "${root}/figures"
    global data_merge "${root}/data/merge"
    global data_clean "${root}/data/clean"
}

* Load merged dataset
use "${data_merge}/merged.dta", clear

* Keep only Wave 1 (Baseline Data)
keep if wave == 1

/****************************
* 2. Depression vs Household Wealth (Total Assets)
****************************/

*** Summary Statistics ***
summarize kessler_score total_assets

*** Scatter Plot: Depression vs Total Assets ***
graph twoway (scatter kessler_score total_assets, msize(vsmall) mcolor(blue)) ///
             (lfit kessler_score total_assets, lcolor(red)), ///
             title("Depression vs Household Wealth", size(large)) ///
             xtitle("Total Asset Value", size(medium)) ytitle("Kessler Score (Depression)", size(medium)) ///
             legend(label(1 "Individuals") label(2 "Linear Fit") size(small)) ///
             graphregion(color(white)) bgcolor(white)

graph export "${figures}/plot/depression_wealth.png", replace

*** Box Plot: Depression by Wealth Quartiles ***

* Divide total assets into 4 quartiles
xtile asset_quartile = total_assets, nq(4) 
* Define meaningful labels for quartiles
label define asset_labels 1 "Lowest Wealth" 2 "Low-Middle Wealth" 3 "Upper-Middle Wealth" 4 "Highest Wealth"
label values asset_quartile asset_labels

* Box Plot: Depression by Wealth Quartiles
graph box kessler_score, over(asset_quartile, label(labsize(small))) ///
    title("Depression by Household Wealth Quartiles", size(large)) ///
    ylabel(, angle(0) grid) ytitle("Kessler Score", size(medium)) ///
    graphregion(color(white)) bgcolor(white)

* Export the Box Plot as PNG
graph export "${figures}/plot/depression_quartiles.png", replace

*** Correlation Analysis ***
correlate kessler_score total_assets

*** Regression: Does Wealth Predict Depression? ***
regress kessler_score total_assets


/****************************
* 3. Depression vs Gender
****************************/

*** Summary Statistics by Gender ***
tabstat kessler_score, by(gender) statistics(mean sd min max)

* Define Gender Labels (0 = Male, 1 = Female)
capture label drop gender_labels
label define gender_labels 1 "Female" 0 "Male"
label values gender gender_labels

*** Box Plot: Depression by Gender ***
graph box kessler_score, over(gender, label(labsize(medium))) ///
    title("Depression by Gender", size(large)) ///
    ylabel(, angle(0) grid) ytitle("Kessler Score", size(medium)) ///
    graphregion(color(white)) bgcolor(white)

graph export "${figures}/plot/depression_gender.png", replace

*** Regression: Does Gender Predict Depression? ***
regress kessler_score i.gender

/****************************
* 4. Depression vs age
****************************/

*** Summary Statistics ***
summarize age total_assets

* Visualize Depression by Age
gen age_group = .
replace age_group = 1 if age >= 4 & age < 18
replace age_group = 2 if age >= 18 & age < 30
replace age_group = 3 if age >= 30 & age < 50
replace age_group = 4 if age >= 50
replace age_group = 5 if age == -999  // Keep missing age separate
capture label drop age_lbl
label define age_lbl 1 "Age(4-17)" 2 "Age(18-29)" 3 "Age(30-49)" 4 "Age(50+)" 5 "Missing Age"
label values age_group age_lbl

graph box kessler_score, over(age_group) ///
    title("Depression by Age Category (Wave 1)") ///
    ylabel(, grid) ytitle("Kessler Score")

graph export "${figures}/plot/depression_age_group.png", replace

	

** Likewise deletion**
gen age_scatter = age
drop if age_scatter == -999

** Correlation Analysis
corr kessler_score age_scatter

*** Scatter Plot: Depression vs Age ***

** summary statistics with likewise deletion
summarize age_scatter kessler_score

graph twoway (scatter age_scatter kessler_score, msize(vsmall) mcolor(blue)) ///
             (lfit kessler_score age_scatter, lcolor(red)), ///
             title("Depression vs Age(with likewise deletion)", size(large)) ///
             xtitle("Age", size(medium)) ytitle("Kessler Score (Depression)", size(medium)) ///
             legend(label(1 "Individuals") label(2 "Linear Fit") size(small)) ///
             graphregion(color(white)) bgcolor(white)
			 
graph export "${figures}/plot/depression_age.png", replace

*** Regression: Does age Predict Depression? ***
regress kessler_score age_scatter


/****************************
* 5. Additional: Wealth Grouping (Above/Below Median)
****************************/

* Create a wealth grouping (above/below median total assets)
quietly summarize total_assets, detail
scalar median_w1_wealth = r(p50)
display "Median wealth (Wave 1): " median_w1_wealth
gen byte wealth_group = .
replace wealth_group = 0 if total_assets < median_w1_wealth
replace wealth_group = 1 if total_assets >= median_w1_wealth
capture label drop wealth_lbl
label define wealth_lbl 0 "Below Median Wealth" 1 "Above Median Wealth"
label values wealth_group wealth_lbl
label var wealth_group "Wealth group (baseline median split)"

* Compare mean depression (K10) by wealth group
tabulate wealth_group, summarize(kessler_score)
ttest kessler_score, by(wealth_group)

* save data 
save "${data_merge}/merged_wave1.dta", replace


* Save it as log ouputs
capture log close
log using "${figures}/table/table_part2_1.log", replace
summarize kessler_score total_assets
correlate kessler_score total_assets
regress kessler_score total_assets
tabstat kessler_score, by(gender) statistics(mean sd min max)
regress kessler_score i.gender
summarize age_scatter kessler_score
corr kessler_score age_scatter
regress kessler_score age_scatter
ttest kessler_score, by(wealth_group)
log close

/*********************************************************************
** EVALUATING THE RCT (Wave 2)
**  
** - Were GT sessions effective at reducing depression?
** - Did the effect of GT sessions differ by gender?
**
** Notes:
** - Uses Wave 2 data
** - Analyzes the impact of GT sessions on depression (Kessler Score)
** - Performs regression analysis with interaction terms
** - Exports well-formatted tables and visualizations
**
*********************************************************************/

clear all
set more off
set scheme s2color  // Improved visualization theme

/****************************
* 1. Set Global Paths
****************************/

* Change file paths based on your system
if "`c(username)'" == "seominjae"{
    global root "/Users/seominjae/Desktop/RCT"
    global figures "${root}/figures"
    global tables "${root}/figures"
    global data_merge "${root}/data/merge"
    global data_clean "${root}/data/clean"
}

* Load merged dataset
use "${data_merge}/merged.dta", clear

/****************************
* 1.5 Balance Check (Baseline Randomization Verification)
****************************/
/*
   RCT Best Practice: Before analyzing treatment effects, verify that
   randomization created comparable treatment and control groups at baseline.

   We check if observable characteristics are balanced between groups at Wave 1.
   If randomization was successful, differences should be small and not significant.
*/

preserve
keep if wave == 1  // Use baseline data for balance check

* Balance table: Compare means by treatment status
display _n "=============================================="
display "BALANCE CHECK: Baseline (Wave 1) Characteristics"
display "=============================================="

* Demographics
ttest age, by(treat_hh)
ttest gender, by(treat_hh)

* Wealth (assets)
ttest total_assets, by(treat_hh)

* Baseline depression (Kessler score)
ttest kessler_score, by(treat_hh)

* Summary statistics by treatment group
tabstat age gender total_assets kessler_score, by(treat_hh) statistics(n mean sd) columns(statistics)

display _n "Note: If p-values > 0.05, groups are balanced on these characteristics"
display "Large differences would suggest potential issues with randomization"

restore

* Keep only Wave 2 observations for post-treatment analysis
keep if wave == 2

* Remove age=-999
list age if age == -999
drop if age  == -999 // remove one entry 
summarize age kessler_score

* create age categories
gen age_group = .
replace age_group = 1 if age >= 2 & age < 18
replace age_group = 2 if age >= 18 & age < 30
replace age_group = 3 if age >= 30 & age < 50
replace age_group = 4 if age >= 50
capture label drop age_lbl
label define age_lbl 1 "Age(2-17)" 2 "Age(18-29)" 3 "Age(30-49)" 4 "Age(50+)"
label values age_group age_lbl


/****************************
* 2. GT Sessions & Depression: Were They Effective? (Q2)
****************************/
/*
   RCT Design Notes:
   - Treatment was randomly assigned at the HOUSEHOLD level
   - Therefore, standard errors should be clustered at household level (hhid)
   - This accounts for within-household correlation of outcomes
*/

*** Summary Statistics ***
summarize kessler_score treat_hh

* Summary by treatment group
tabstat kessler_score, by(treat_hh) statistics(n mean sd min max)

*** Box Plot: Depression by Treatment Group ***
* Redefine labels for Wave 2 analysis (use replace option to avoid error if already defined)
capture label drop treatment_labels
label define treatment_labels 0 "Control" 1 "Treated"
label values treat_hh treatment_labels

graph box kessler_score, over(treat_hh, label(labsize(medium))) ///
    title("Depression by GT Treatment Group (Wave 2)", size(large)) ///
    ylabel(, angle(0) grid) ytitle("Kessler Score (Depression)", size(medium)) ///
    graphregion(color(white)) bgcolor(white)

graph export "${figures}/plot/depression_treatment.png", replace

*** Regression: Did GT Sessions Reduce Depression? (Q2) ***
/*
   Model: kessler_score = β0 + β1*treat_hh + ε

   Interpretation:
   - β0 (Constant): Mean Kessler score for Control group (treat_hh=0)
   - β1 (treat_hh): Average Treatment Effect (ATE) - difference in mean Kessler
                    score between Treated and Control groups
   - If β1 < 0 and significant: GT sessions reduced depression
   - If β1 > 0 and significant: GT sessions increased depression

   Note: Using clustered standard errors at household level because
   treatment was assigned at household level
*/

* Simple OLS (for comparison)
regress kessler_score treat_hh

* OLS with clustered standard errors (PREFERRED - accounts for household-level treatment assignment)
regress kessler_score treat_hh, vce(cluster hhid)
estimates store model_q2


/****************************
* 3. GT Sessions & Gender Interaction Effect (Q3)
****************************/
/*
   Q3 requires:
   - Woman (binary): 1 = Female, 0 = Male
   - Treated Household (binary): treat_hh
   - Interaction term: Treated Household * Woman

   Instructions: "explain and interpret ALL coefficients in your specification,
   keeping in mind units and reference groups"
*/

*** Define Woman (Binary Variable) ***
gen woman = gender  // woman=1 if Female, woman=0 if Male (per earlier coding)
label variable woman "Woman (1=Female, 0=Male)"

*** Interaction Term: Treatment x Woman ***
gen treat_woman = treat_hh * woman  // Interaction: Treated * Woman
label variable treat_woman "Treatment x Woman Interaction"

*** Regression: Does Gender Modify the Treatment Effect? (Q3) ***
/*
   Model: kessler_score = β0 + β1*treat_hh + β2*woman + β3*(treat_hh*woman) + ε

   COEFFICIENT INTERPRETATION (Reference group: Untreated Men):

   β0 (Constant):
      - Mean Kessler score for UNTREATED MEN (treat_hh=0, woman=0)
      - This is the baseline/reference group

   β1 (treat_hh):
      - Effect of treatment FOR MEN ONLY
      - Difference in mean Kessler score between Treated Men and Untreated Men
      - If negative: GT sessions reduced depression among men

   β2 (woman):
      - Gender difference in Kessler score among UNTREATED individuals
      - Difference between Untreated Women and Untreated Men
      - If positive: women have higher depression than men in control group

   β3 (treat_woman - INTERACTION TERM):
      - DIFFERENTIAL treatment effect by gender
      - How much MORE (or less) the treatment effect is for women compared to men
      - If negative: treatment is more effective for women than men
      - If positive: treatment is less effective for women than men

   Treatment Effect for Women = β1 + β3
   Treatment Effect for Men = β1

   Units: Kessler-10 score (10-50 scale, higher = more psychological distress)
*/

* OLS with clustered standard errors (household-level clustering)
regress kessler_score treat_hh woman treat_woman, vce(cluster hhid)
estimates store model_q3

* Calculate treatment effect for women (β1 + β3)
lincom treat_hh + treat_woman
display "Treatment effect for WOMEN: " r(estimate) " (SE: " r(se) ")"

* Display treatment effect for men (β1)
display "Treatment effect for MEN: coefficient on treat_hh above"


/****************************
* 4. Presentation: Box Plots & Interpretation
****************************/

*** Box Plot: Depression by Treatment & Gender ***
graph box kessler_score, over(treat_hh, label(labsize(medium))) by(gender, title("Depression by Treatment & Gender (Wave 2)", size(large))) ///
    ylabel(, angle(0) grid) ytitle("Kessler Score (Depression)", size(medium)) ///
    graphregion(color(white)) bgcolor(white)

graph export "${figures}/plot/depression_treatment_gender.png", replace

*** Box Plot: Depression by Treatment & Age Group ***
graph box kessler_score, over(treat_hh, label(labsize(medium))) by(age_group, title("Depression by Treatment & Age group (Wave 2)", size(large))) ///
    ylabel(, angle(0) grid) ytitle("Kessler Score (Depression)", size(medium)) ///
    graphregion(color(white)) bgcolor(white)

graph export "${figures}/plot/depression_treatment_age.png", replace

* save data for part2-2
save "${data_merge}/merged_wave2.dta", replace


* Save it as log outputs
capture log close
log using "${figures}/table/table_part2_2.log", replace

display _n "=============================================="
display "PART 3: RCT ANALYSIS RESULTS"
display "=============================================="

display _n "--- Q2: Treatment Effect on Depression ---"
summarize kessler_score treat_hh
tabstat kessler_score, by(treat_hh) statistics(n mean sd)

display _n "Simple OLS:"
regress kessler_score treat_hh

display _n "OLS with Clustered SE (PREFERRED):"
regress kessler_score treat_hh, vce(cluster hhid)

display _n "--- Q3: Gender Interaction Analysis ---"
display _n "OLS with Clustered SE:"
regress kessler_score treat_hh woman treat_woman, vce(cluster hhid)

display _n "Treatment effect for WOMEN (β_treat + β_interaction):"
lincom treat_hh + treat_woman

display _n "=============================================="
display "COEFFICIENT INTERPRETATION SUMMARY"
display "=============================================="
display "Reference Group: Untreated Men"
display "treat_hh: Treatment effect for MEN"
display "woman: Gender gap among untreated (Women - Men)"
display "treat_woman: DIFFERENTIAL treatment effect (Women vs Men)"
display "Treatment Effect for Women = treat_hh + treat_woman"
display "=============================================="

log close
