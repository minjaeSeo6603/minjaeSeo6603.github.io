*************************************************
*								*
*	READ ME FILE					*
*								*
*	Programs for micro and macro estimates 	*
*								*
*************************************************



/* This readme file provides the programs and the variables definitions for: 

	  -  Microestimates on Inherited Trust in the GSS
		Database: AER_MICRO.dta
			  
	  - Macroestimates on Growth and Inherited Trust - 
		Database : AER_MACRO.dta", clear

*/





***************************************************************************************
***************************************************************************************
*
*
*
* 						MICROESTIMATES 
*
*
*
***************************************************************************************
***************************************************************************************

*
*  DATABASE: GSS
* 

use "AER_MICRO.dta"

************************
* WAVES OF IMMIGRATIONS *
************************

/* Grandparents : nativegp (=1 if 4 grandparents are born in the US, =0.75 if 3 out of 4 are born in the US, =0.5 if 2 out of 4, =0.25 if 1 out of 4, = 0 if none are born in the US)
/* Parents : nativep (=1 if 2 parents are born in the US, =0.5 if 1 out of 2 is born in the US, =0 if none are born in the US)
/* Respondent: native (=1 if born in the US, =0 otherwise) 
/* Eth: country of origin of the respondent 


gen gen2=(nativegp==0 & nativep<=0.5 & native==1)  
gen gen3=(nativegp<=0.5 & nativep==1 & native==1 & nativegp!=. & nativep!=.)
gen gen4=(nativegp>0.5 & nativep==1 & native==1 & nativegp!=. & nativep!=.)


gen coh2000=((gen2==1 & naiss>=1910) |  (gen3==1 & naiss>=1935) | (gen4==1 & naiss>=1960))
gen coh1935=((gen2==1 & naiss<1910) |  (gen3==1 & naiss<1935) | (gen4==1 & naiss<1960))



tabstat  age men ageedu incomegood inactive employed unemployed norelig pro catho if coh2000==1 /*
*/ & cty_sample==1, statistics(mean sd)

tabstat  age men ageedu incomegood inactive employed unemployed norelig pro catho if coh1935==1 /*
*/ & cty_sample==1, statistics(mean sd)


* GROUP DUMMIES

foreach x in Afri Aut Bg Cd Czr Dk Fin Fra Ger Hg India Ire Ita Mx Nth Nw Pol Pt Rus Sp Swd Switz Uk Youg {
foreach y in coh1935 coh2000 {
quietly gen `x'_`y' = `x'*`y'

}
}


*TABLE 1

/* Reference group: no religion and inactive*/

reg trust10_large age men ageedu age2 incomegood catho pro employed inactive unemployed /*
*/  Afri_coh2000 Afri_coh1935 Aut_coh2000 Aut_coh1935 Bg_coh2000 Bg_coh1935 Cd_coh2000 Cd_coh1935 Czr_coh2000 Czr_coh1935 Dk_coh2000 Dk_coh1935 Fra_coh2000 Fra_coh1935 /*
*/ Fin_coh2000 Fin_coh1935 Ger_coh2000 Ger_coh1935 Hg_coh2000 Hg_coh1935 India_coh2000 India_coh1935 Ire_coh2000 Ire_coh1935 Ita_coh2000 Ita_coh1935 Mx_coh2000 Mx_coh1935 Nth_coh2000 Nth_coh1935 /*
*/ Nw_coh2000 Nw_coh1935 Pol_coh2000 Pol_coh1935 Pt_coh2000 Pt_coh1935 Rus_coh2000 Rus_coh1935 Sp_coh2000 Sp_coh1935 Swd_coh2000 Switz_coh2000 Switz_coh1935 Uk_coh2000 Uk_coh1935 Youg_coh2000 Youg_coh1935 /*
*/ if (coh2000==1 | coh1935==1) & cty_sample==1 & religionok==1, cluster(eth)


/* SUBSAMPLES 1935 AND 2000
Coefficients to be used for the Macro part: 
Split the estimations for 1935 and 2000
Sweden in 1935 and Sweden in 2000 are the reference country */



*1935
reg trust10_large age men ageedu incomegood catho pro unemployed employed/*
*/ Afri Aut Bg Uk Cd Czr Dk Fin Fra Ger Hg India Ire Ita Mx Nth Nw Pol Pt Rus Sp  Switz Youg /*
*/  if cty_sample==1 & religionok==1 &  coh1935, cluster(eth)

estat summarize
est store coh1935

* 2000
reg trust10_large age men ageedu incomegood catho pro unemployed employed/*
*/ Afri Aut Bg Uk Cd Czr Dk Fin Fra Ger Hg India Ire Ita Mx Nth Nw Pol Pt Rus Sp  Switz Youg /*
*/  if cty_sample==1 & religionok==1 &  coh2000, cluster(eth)

estat summarize
est store coh2000
est table coh1935 coh2000

* ROBUSTNESS CHECKS : OTHER TRUST INDICATOR 

*TRUST 123
reg trust age men ageedu incomegood catho pro unemployed employed/*
*/ Afri Aut Bg Uk Cd Czr Dk Fin Fra Ger Hg India Ire Ita Mx Nth Nw Pol Pt Rus Sp  Switz Youg /*
*/  if cty_sample==1 & religionok==1 &  coh1935==1, cluster(eth)

reg trust age men ageedu incomegood catho pro unemployed employed/*
*/ Afri Aut Bg Uk Cd Czr Dk Fin Fra Ger Hg India Ire Ita Mx Nth Nw Pol Pt Rus Sp  Switz Youg /*
*/  if cty_sample==1 & religionok==1 &  coh2000==1, cluster(eth)

* TRUST no depends
drop trust_nodepends
gen trust_nodepends=.
replace trust_nodepends=1 if trust==1
replace trust_nodepends=0 if trust==2

reg trust_nodepends age men ageedu incomegood catho pro unemployed employed/*
*/ Afri Aut Bg Uk Cd Czr Dk Fin Fra Ger Hg India Ire Ita Mx Nth Nw Pol Pt Rus Sp  Switz Youg /*
*/  if cty_sample==1 & religionok==1 &  coh1935==1, cluster(eth)

reg trust_nodepends  age men ageedu incomegood catho pro unemployed employed/*
*/ Afri Aut Bg Uk Cd Czr Dk Fin Fra Ger Hg India Ire Ita Mx Nth Nw Pol Pt Rus Sp  Switz Youg /*
*/  if cty_sample==1 & religionok==1 & coh2000==1, cluster(eth)


* TRUST alternative
gen trust_alter=.
replace trust_alter=1 if (trust==1 | trust==3)
replace trust_alter=0 if trust==2

reg trust_alter age men ageedu incomegood catho pro unemployed employed/*
*/ Afri Aut Bg Uk Cd Czr Dk Fin Fra Ger Hg India Ire Ita Mx Nth Nw Pol Pt Rus Sp  Switz Youg /*
*/  if cty_sample==1 & religionok==1 &  coh1935==1, cluster(eth)

reg trust_alter age men ageedu incomegood catho pro unemployed employed/*
*/ Afri Aut Bg Uk Cd Czr Dk Fin Fra Ger Hg India Ire Ita Mx Nth Nw Pol Pt Rus Sp  Switz Youg /*
*/  if cty_sample==1 & religionok==1 &  coh2000==1, cluster(eth)


**************************************************************************
* 
*  CORELATION BETWEEN INHERITED TRUST AND TRUST IN THE HOME COUNTRY 
*
* TABLE III 
*
*
 
* COLUMN 1 : correlation between inherited trust in 2000 and trust in home country in 2000 (WVS) 
reg trust10_large trustwvs2000 age men ageedu incomegood unemployed employed catho pro  /*
*/ if cty_sample==1 & coh2000==1 & religionok==1, cluster(eth)

* COLUMN 2 : correlation between inherited trust in 1935 and trust in home country in 2000 (WVS) 
reg trust10_large trustwvs2000 age men ageedu incomegood catho pro unemployed employed/*
*/ if cty_sample==1 & coh1935==1 & religionok==1, cluster(eth)

* COLUMN 3 : correlation between inherited trust in 2000 and trust in home country in 2000: Subsample 4th generation
reg trust10_large trustwvs2000 age men ageedu incomegood unemployed employed catho pro  /*
*/ if cty_sample==1 & (gen4==1 & naiss>=1960) & religionok==1, cluster(eth)


**********************************************
*  CORRELATION BETWEEN INHERITED TRUST OF US-IMMIGRANTS AND TRUST IN A RANDOM SOURCE COUNTRY - COUNTERFACTUAL TEST
*  TABLE IV


* COLUMN 1
reg trust10_large trustwvs_rand  age men ageedu incomegood unemployed employed catho pro  /*
*/ if cty_sample==1 & ((gen2==1 & naiss>=1910) | (gen3==1 & naiss>=1935) |  (gen4==1 & naiss>=1960)) & religionok==1, cluster(eth)

* COLUMN 2
reg trust10_large trustwvs_rand age men ageedu incomegood catho pro unemployed employed/*
*/ if cty_sample==1 & coh1935==1 & religionok==1, cluster(eth)





*************************************
*
* COHORTS 1910 and 2000  
*
*     TABLE VIII
*
*************************************

/* PERIOD 1910 and 2000

To get as many observations as possible for these two periods, 
a) we consider immigrants whose at least one parent is born in the country 
b) we control for gender age and education. 
 */


gen gen2_test=(nativegp==0 & nativep<=0.5 & native==1)
gen gen3_test=(nativegp<=0.5 & nativep>=0.5 & native==1 & nativegp!=. & nativep!=.)
gen gen4_test=(nativegp>0.5 & nativep>=0.5 & native==1 & nativegp!=. & nativep!=.)

gen coh2000r=((gen2_test==1 & naiss>1910) | (gen3_test==1 & naiss>1935) |  (gen4_test==1 & naiss>1960))
gen coh1910r=((gen3_test==1 & naiss<=1910) |  (gen4_test==1 & naiss<=1935))

gen cty_okr=(Afri==1 | Uk==1 | Cd==1 | Czr==1 |  Dk==1 | Fra==1 | Ger==1 | Ire==1 | Ita==1 | Nth==1 | Nw==1 | Pol==1 | Sp==1 | Swd==1 | Switz==1)


foreach x in Afri Cd Czr Dk Fra Ger Ire Ita Nth Nw Pol Sp Swd Switz Uk{
foreach y in coh2000r coh1910r {
quietly gen `x'_`y' = `x'*`y'
}
}


*TABLE VIII
reg trust10_large age men ageedu  /*
*/ Afri_coh2000r Afri_coh1910r Uk_coh2000r Uk_coh1910r  Cd_coh2000r Cd_coh1910r  Czr_coh2000r Czr_coh1910r  Dk_coh2000r Dk_coh1910r  /*
*/ Fra_coh2000r Fra_coh1910r  Ger_coh2000r Ger_coh1910r  Ire_coh2000r Ire_coh1910r  Ita_coh2000r Ita_coh1910r  Nth_coh2000r Nth_coh1910r  /*
*/ Nw_coh2000r Nw_coh1910r  Pol_coh2000r Pol_coh1910r  Sp_coh2000r Sp_coh1910r  Swd_coh2000r Switz_coh2000r Switz_coh1910r  /*
*/ if (coh2000r==1 | coh1910r==1) & cty_okr==1 , cluster(eth)


* Robustness check
reg trust10_large age men ageedu  employed unemployed inactive incomegood catho pro /*
*/ Afri_coh2000r Afri_coh1910r Uk_coh2000r Uk_coh1910r  Cd_coh2000r Cd_coh1910r  Czr_coh2000r Czr_coh1910r  Dk_coh2000r Dk_coh1910r  /*
*/ Fra_coh2000r Fra_coh1910r  Ger_coh2000r Ger_coh1910r  Ire_coh2000r Ire_coh1910r  Ita_coh2000r Ita_coh1910r  Nth_coh2000r Nth_coh1910r  /*
*/ Nw_coh2000r Nw_coh1910r  Pol_coh2000r Pol_coh1910r  Sp_coh2000r Sp_coh1910r  Swd_coh2000r Switz_coh2000r Switz_coh1910r  /*
*/ if (coh2000r==1 | coh1910r==1) & cty_okr==1 & religionok==1, cluster(eth)


/* SUBSAMPLES 1910 and 2000
*1910
reg trust10_large age men ageedu /*
*/ Afri Cd Czr Dk Fra Ger Ire Ita Nth Nw Pol Sp  Switz Uk /*
*/ if cty_okr==1 & coh1910r,cluster(eth)

*2000
reg trust10_large age men ageedu /*
*/ Afri Cd Czr Dk Fra Ger Ire Ita Nth Nw Pol Sp  Switz Uk /*
*/ if cty_okr==1 & coh2000r,cluster(eth)



tabstat  age mta eth if cty_okr==1 & coh1910ren ageedu incomegood inactive employed unemployed norelig pro catho if coh1910r==1 /*
*/ & cty_okr==1, statistics(mean sd)





**********************************************
*
*
*  CORRELATION BETWEEN INHERITED TRUST AND TRUST IN THE HOME COUNTRY 
*
*			SUBSAMPLES
*
*			TABLE XIII


* COLUMN 1: Correlation between inherited trust in 1935 and trust in home country : 2nd-3d generations
reg trust10_large trustwvs2000 age men ageedu incomegood catho pro unemployed employed/*
*/ if religionok==1 &  cty_sample==1 & ((gen2==1 & naiss<1910) | (gen3==1 & naiss<1935)), cluster(eth)


* COLUMN 2: Correlation between inherited trust in 1935 and trust in home country : 4th generation
reg trust10_large trustwvs2000 age men ageedu incomegood catho pro unemployed employed/*
*/ if religionok==1 &    cty_sample==1 & (gen4==1 & naiss<1960), cluster(eth)


* COLUMN 3: Correlation between inherited trust in 2000 and trust in home country : 2nd-3d generations
reg trust10_large trustwvs2000 age men ageedu incomegood unemployed inactive employed catho pro  /*
*/ if religionok==1 &   cty_sample==1 & ((gen2==1 & naiss>=1910) | (gen3==1 & naiss>=1935)), cluster(eth)

* COLUMN 4: Correlation between inherited trust in 2000 and trust in home country : 4th generation
reg trust10_large trustwvs2000 age men ageedu incomegood unemployed  employed catho pro  /*
*/ if religionok==1 & cty_sample==1 & (gen4==1 & naiss>=1960), cluster(eth)





***********************
*
* ROBUSTNESS - 50 YEARS LAG

gen coh2000lag=((gen2_test==1 & (naiss>1885| naiss<=1950)) |  (gen3_test==1 & naiss>1910) | (gen4_test==1 & naiss>1935))
gen coh1935lag=((gen2_test==1 & naiss<=1885) |  (gen3_test==1 & naiss<=1910) | (gen4_test==1 & naiss<=1935))

gen cty_okrm=(Afri==1 | Uk==1 | Cd==1 | Czr==1 |  Dk==1 | Fra==1 | Ger==1 | Ire==1 | Ita==1 | Mx==1 | Nth==1 | Nw==1 | Pol==1 | Sp==1 | Swd==1 | Switz==1)


reg trust10_large age men ageedu /*
*/ Afri Cd Czr Dk Fra Ger Ire Ita Nth Nw Pol Sp Switz Uk /*
*/ if cty_okrm==1 & coh2000lag==1, cluster(eth)

reg trust10_large age men ageedu /*
*/ Afri Cd Czr Dk Fra Ger Ire Ita Nth Nw Pol Sp Switz Uk /*
*/ if cty_okrm==1 & coh1935lag==1, cluster(eth)


***************************************************************************************
***************************************************************************************
*
*
*
* 						MACROESTIMATES 
*
*
*
***************************************************************************************
***************************************************************************************

use "AER_MACRO.dta", clear

* gdpk_diffswd_good : difference in income per capita relative to Sweden 
* trustgss_good : inherited trust relative to Sweden (estimated by OLS from the GSS database / Reference: Microestimates)
* gdpk_diffswd_good_1 : difference in income per capita relative to Sweden Lagged Value
* polity2diff : difference in the quality of political institutions relative to Sweden


**************************
*   
*    PERIODS 1935 - 2000
*
*        TABLE V - VI
*
************************

* FIGURES 1 & 2 
reg trustwvs2000 trustgss    if period==2000
reg trustwvs2000 trustgss    if  period==1935
twoway (scatter trustwvs2000 trustgss if period==2000, ytitle("Trust in the home country in 2000")  xtitle("Inherited trust in 2000") caption( "R²=0.19", ring(0) pos(2)) legend(off) msize (tiny) mlabel(cty) mlabsize(small)) 
twoway (scatter trustwvs2000 trustgss if period==1935, ytitle("Trust in the home country in 2000")  xtitle("Inherited trust in 1935") caption( "R²=0.00", ring(0) pos(2)) legend(off) msize (tiny) mlabel(cty) mlabsize(small)) 

* FIGURE 3
reg gdpk_diffswd_good trustgss    if period==2000 & Afri==0 & India==0
twoway (scatter gdpk_diffswd_good trustgss if Nsample1935==0 & period==2000, ytitle("Income per capita relative to Sweden in 2000")  xtitle("Inherited trust in 2000") caption( "R²=0.54", ring(0) pos(2)) legend(off) msize (tiny) mlabel(cty) mlabsize(small)) 


* Cross-country: TABLE V
xi: reg   gdpk_diffswd_good trustgss if period19352000==1, noconstant
xi: reg   gdpk_diffswd_good trustgss gdpk_diffswd_good_1 if period19352000==1, noconstant
xi: reg   gdpk_diffswd_good trustgss gdpk_diffswd_good_1 polity2diff if period19352000==1, noconstant
xi: reg   gdpk_diffswd_good trustgss gdpk_diffswd_good_1 polity2diff if period19352000==1 & cty!="Afri", noconstant



* Within estimates: TABLE VI
xi: reg   gdpk_diffswd_good trustgss i.cty if period19352000==1 , noconstant
xi: reg   gdpk_diffswd_good trustgss gdpk_diffswd_good_1 i.cty  if period19352000==1 , noconstant
xi: reg   gdpk_diffswd_good trustgss gdpk_diffswd_good_1 i.cty  if period19352000==1 & cty!="Afri" , noconstant
xi: reg   gdpk_diffswd_good trustgss gdpk_diffswd_good_1 polity2diff i.cty  if period19352000==1, noconstant
xi: reg   gdpk_diffswd_goodsmooth trustgss gdpk_diffswd_good_1 polity2diff i.cty  if period19352000==1, noconstant



* FIGURE 4:  Evolution Change in Trust 
sort cty period
gen gdpk_diffswd_good_1=gdpk_diffswd_good[_n-1] if cty==cty[_n-1]
gen trustgss_lag1=trustgss[_n-1] if cty==cty[_n-1]
list cty period gdpk_diffswd_good gdpk_diffswd_good_1 trustgss trustgss_lag1 if period19352000==1
gen change_trust=trustgss -trustgss_lag1 if period==2000
gen change_gdpk=gdpk_diffswd_good - gdpk_diffswd_good_1 if period==2000
reg change_gdpk  change_trust  if period==2000 & Nsample1935==0
twoway (scatter change_gdpk  change_trust if Nsample1935==0 & period==2000, ytitle("Change in Income relative to Sweden: 2000-1935")  xtitle("Change in Inherited trust relative to Sweden: 2000-1935") caption( "R²=0.43", ring(0) pos(2)) legend(off) msize (tiny) mlabel(cty) mlabsize(small)) 



*****************
* COUNTERFACTUALS 

* BASIC REGRESSION
xi: reg   gdpk_diffswd_good trustgss gdpk_diffswd_good_1 polity2diff i.cty  if Nsample1935==0 & period19352000==1, noconstant


* FIGURE 5: Increase in gdp if same inherited trust than in Sweden */

gen gdpk_change_trust0=-28230.15*trustgss if period==2000 & Nsample1935==0 & cty!="India"
gen pgdpk_change_trust0=100*(gdpk_change_trust0)/gdpkmad
list cty period pgdpk_change_trust0  if period==2000
graph hbar (mean) pgdpk_change_trust0  if cty!="Swd" & Nsample1935==0 & cty!="India" & cty!="Afri", nofill xsize(8) ytitle("Variation in GDP per capita if same inherited trust as Sweden (%)") over(cty,sort(pgdpk_change_trust0)descending)


* FIGURE 6: Increase in gdp if same initial income per capita than in Sweden */

gen gdpk_change_gdp0=-2.814842*gdpk_diffswd_good_1  if period==2000 & Nsample1935==0 & cty!="India"
gen pgdpk_change_gdp0=100*(gdpk_change_gdp0)/gdpkmad
list cty period pgdpk_change_gdp0  if period==2000

graph hbar (mean) pgdpk_change_gdp0  if cty!="Swd" & Nsample1935==0 & cty!="India" & cty!="Afri", nofill xsize(8) ytitle("Variation in GDP per capita if same initial economic development as Sweden (%)") over(cty,sort(pgdpk_change_gdp0)descending)

* FIGURE 7: Fixed effects
gen pgdpk_change_fixed=-100*(fixed)/gdpkmad
graph hbar (mean) pgdpk_change_fixed if cty!="Swd" & Nsample1935==0 & cty!="India" & cty!="Afri" & period==2000, nofill xsize(8) ytitle("Variation in GDP per capita if same country fixed effect as Sweden (%)") over(cty,sort(pgdpk_change_fixed)descending)
list cty pgdpk_change_fixed if period==2000



***************************
*
*  PERIODS 1935 - 2000
*   Lag 50 ans 
*
*    TABLE VII 
*
**************************





* FIGURES 8 & 9 
reg gdpk_diffswd_good trustgss50yearslag    if period==1935
twoway (scatter gdpk_diffswd_good trustgss50yearslag if period==1935, ytitle("Income per capita relative to Sweden in 1935")  xtitle("Inherited trust in 1935 - Lag 50 years") caption( "R²=0.25", ring(0) pos(2)) legend(off) msize (tiny) mlabel(cty) mlabsize(small)) 

reg gdpk_diffswd_good trustgss50yearslag    if period==2000
twoway (scatter gdpk_diffswd_good trustgss50yearslag if period==2000, ytitle("Income per capita relative to Sweden in 2000")  xtitle("Inherited trust in 2000 - Lag 50 years") caption( "R²=0.59", ring(0) pos(2)) legend(off) msize (tiny) mlabel(cty) mlabsize(small)) 


* TABLE VII
xi: reg   gdpk_diffswd_good trustgss50yearslag, noconstant 
xi: reg   gdpk_diffswd_good trustgss50yearslag i.cty , noconstant 
xi: reg   gdpk_diffswd_good trustgss50yearslag gdpk_diffswd_good_1 polity2diff i.cty , noconstant 


*************************
*
*  COHORTS  1910 - 2000
*
*   TABLE IX - X
*
*************************

* Nsample1910: = 1 if countries are not relevant in the GSS estimated 
* The countries used in the macro estimates corresponds to the subsample 1910-2000 in the GSS: cty_okr
* cty_okrm=(Afri==1 | Uk==1 | Cd==1 | Czr==1 |  Dk==1 | Fra==1 | Ger==1 | Ire==1  | Ita==1 | Nth==1 | Nw==1 | Pol==1 | Sp==1 | Swd==1 | Switz==1)






* FIGURE 10
reg gdpk_diffswd_good trustgss_1910_2000 if Nsample1910==0 & period==1910
twoway (scatter gdpk_diffswd_good trustgss_1910_2000  if period==1910, ytitle("Income per capita relative to Sweden in 1910")  xtitle("Inherited trust in 1910") caption( "R²=0.33", ring(0) pos(2)) legend(off) msize (tiny) mlabel(cty) mlabsize(small)) 

* TABLES IX & X
xi: reg   gdpk_diffswd_good trustgss_1910_2000 if Nsample1910==0 & period19102000==1 , noconstant
xi: reg   gdpk_diffswd_good trustgss_1910_2000   gdpk_diffswd_good_2   if Nsample1910==0 & period19102000==1 , noconstant
xi: reg   gdpk_diffswd_good trustgss_1910_2000   gdpk_diffswd_good_2  polity2diff19102000 if Nsample1910==0 & period19102000==1, noconstant

xi: reg   gdpk_diffswd_good trustgss_1910_2000  i.cty if Nsample1910==0 & period19102000==1 , noconstant
xi: reg   gdpk_diffswd_good trustgss_1910_2000   gdpk_diffswd_good_2  i.cty if Nsample1910==0 & period19102000==1 , noconstant
xi: reg   gdpk_diffswd_good trustgss_1910_2000   gdpk_diffswd_good_2  polity2diff19102000 i.cty if Nsample1910==0 & period19102000==1, noconstant



***********************************
*
*  ADDITIONAL CONTROLS 
*   
*
*     TABLE XI
*************************************
xi: reg   gdpk_diffswd_good trustgss hardwork  gdpk_diffswd_good_1 polity2diff i.cty if  period19352000==1, noconstant 
xi: reg   gdpk_diffswd_good trustgss confbus  gdpk_diffswd_good_1 polity2diff i.cty if  period19352000==1, noconstant 
xi: reg   gdpk_diffswd_good trustgss gveq gdpk_diffswd_good_1 polity2diff i.cty if  period19352000==1, noconstant 
xi: reg   gdpk_diffswd_good trustgss womanwork gdpk_diffswd_good_1 polity2diff i.cty if period19352000==1, noconstant 
xi: reg   gdpk_diffswd_good trustgss hardwork confbus gveq womanwork gdpk_diffswd_good_1 polity2diff i.cty if period19352000==1, noconstant 




****************************************************
*
*  ROBUSTNESS - DIFFERENT INDICATORS OF TRUST
*
*
*            TABLE XIV
*
****************************************************

xi: reg  gdpk_diffswd_good trust123new gdpk_diffswd_good_1 polity2diff i.cty if period19352000==1, noconstant
xi: reg  gdpk_diffswd_good trust_nodepends gdpk_diffswd_good_1 polity2diff i.cty if Nsample1935==0, noconstant
xi: reg  gdpk_diffswd_good trust_alter gdpk_diffswd_good_1 polity2diff i.cty if Nsample1935==0, noconstant


****************************************************
*
*  ROBUSTNESS - PERIODS 1950 2000
*
*
*            TABLE XV
*
****************************************************


* Estimates

xi: reg   gdpk_diffswd_good trustgss_lag75, noconstant 
xi: reg   gdpk_diffswd_good trustgss_lag75 i.cty , noconstant 
xi: reg   gdpk_diffswd_good trustgss_lag75 gdpk_diffswd_good_1_lag75 polity2diff19502000 i.cty, noconstant 






