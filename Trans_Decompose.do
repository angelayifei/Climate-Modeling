#delimit ;
clear all;

/******************************************************************************************************************/
/********************************  Decompose Transport sector data under 550 scenario  ****************************/
/******************************************************************************************************************/

/* Merge 550_Transport and Base_Transpor datasets */
use subset/`1'_`2'_550_Trans;

/* If the dataset is empty, save and exit the dataset, read next line*/
count;
if r(N)==0 {;
	clear all;
	};
	
else {;
merge 1:1 model region fuel year using subset/`1'_`2'_Base_Trans;
drop _merge;

save subset/`1'_`2'_Trans_Analysis, replace;

/*************************************************** First step ***************************************************/
/******************************************************************************************************************/
/* Decompose CO2 emissions from Transport at the sectoral level, into demand effect, 
energy intensity effect and carbon intensity effect */
local scenarios "550 Base";
local subsectors "Freight Passenger";

/* Sectoral demand level log2scenario */
foreach x of local subsectors{;
	gen log2scenario_ES_`x' =.;
	replace log2scenario_ES_`x' = ln((ES_Trans_`x'_550)/(ES_Trans_`x'_Base))
		if fuel=="All" & ES_Trans_`x'_Base!=.;
		};

/*Energy intensity (energy consumption/sectoral activity) log2scenario */
foreach s of local scenarios{;
	foreach x of local subsectors{;
		gen EI_`x'_`s' =.;
		replace EI_`x'_`s' = FE_Trans_`x'_`s' / ES_Trans_`x'_`s' 
		if fuel=="All" & FE_Trans_`x'_`s'!=. & ES_Trans_`x'_`s'!=.;
	};
};
foreach x of local subsectors{;
	gen log2scenario_EI_`x' =.;
	replace log2scenario_EI_`x'= ln((EI_`x'_550)/(EI_`x'_Base))
		if fuel=="All" & EI_`x'_550!=. & EI_`x'_Base!=.;
};


/*Allocate emissions to Freight and Passenger subsectors based on shares of subsectoral energy consumption in 
total Transport energy consumption */
foreach s of local scenarios{;
	foreach x of local subsectors{;
		gen weight_`x'_`s' =.;
		replace weight_`x'_`s' = FE_Trans_`x'_`s' / FE_Trans_`s'
			if fuel=="All" & FE_Trans_`x'_`s'!=. & FE_Trans_`s'!=.;
		gen CO2_Trans_`x'_`s' =.;
		replace CO2_Trans_`x'_`s' = CO2e_gen_`s' * weight_`x'_`s'
			if fuel=="All" & weight_`x'_`s'!=.;
};

foreach x of local subsectors{;
	gen log2scenario_Emission_`x' =.;
	replace log2scenario_Emission_`x'=ln((CO2_Trans_`x'_550)/(CO2_Trans_`x'_Base))
	if fuel=="All" & CO2_Trans_`x'_Base!=.;
};

/* Emission factors */
foreach s of local scenarios{;
	foreach x of local subsectors{;
		gen EF_`x'_`s' =.;
		replace EF_`x'_`s' = CO2_Trans_`x'_`s' / FE_Trans_`x'_`s'
			if  fuel=="All" & FE_Trans_`x'_`s'!=.;
};

foreach x of local subsectors{;
	gen log2scenario_EF_`x'=.;
	replace log2scenario_EF_`x'=ln((EF_`x'_550)/(EF_`x'_Base))
		if fuel=="All" & EF_`x'_Base!=.;
};

/* Calculate multiplier phi */
foreach x of local subsectors{;
	gen Phi_`x' = .;
	replace Phi_`x' = (CO2_Trans_`x'_550 - CO2_Trans_`x'_Base) / (log2scenario_Emission_`x')
		if fuel=="All" & CO2_Trans_`x'_Base!=. & log2scenario_Emission_`x'!=.;
};

/* Calculate scale effect, energy intensity effect and carbon intensity effect 
when subsectoral energy consumption data are available*/
foreach x of local subsectors{;
	gen scale_effect_`x' =.;
	replace scale_effect_`x' = log2scenario_ES_`x' * Phi_`x'
		if fuel=="All" & Phi_`x'!=.;

	gen EI_effect_`x' =.;
	replace EI_effect_`x' = log2scenario_EI_`x' * Phi_`x'
		if fuel=="All" & Phi_`x'!=.;

	gen CI_effect_`x' =.;
	replace CI_effect_`x' = log2scenario_EF_`x' * Phi_`x'
		if fuel=="All" & Phi_`x'!=.;
};

local effects "scale_effect EI_effect CI_effect";
foreach eff of local effects{;
	gen `eff'_Trans =.;
	replace `eff'_Trans = `eff'_Freight + `eff'_Passenger
	if fuel=="All" & `eff'_Freight!=. & `eff'_Passenger!=.;
};

/* Calculate scale effect, energy intensity effect and carbon intensity effect when 
subsectoral energy consumption data are not available*/
gen log2scenario_ES_Trans =.;
replace log2scenario_ES_Trans = (log2scenario_ES_Freight + log2scenario_ES_Passenger)/2
	if fuel=="All"; /* Approximate calculation */

gen log2scenario_EI_Trans=.;
replace log2scenario_EI_Trans = ln((FE_Trans_550)/(FE_Trans_Base)) - log2scenario_ES_Trans
	if fuel=="All";

foreach s of local scenarios{;
	gen EF_Trans_`s'=.;
	replace EF_Trans_`s' = CO2e_gen_`s' / FE_Trans_`s' 
		if CO2e_gen_`s'!=. & FE_Trans_`s'!=.;
};
	
gen log2scenario_EF_Trans=.;
replace log2scenario_EF_Trans = ln((EF_Trans_550)/(EF_Trans_Base))
	if fuel=="All" & EF_Trans_Base!=. & EF_Trans_550 !=.;

gen log2scenario_Emission_Trans=.;
replace log2scenario_Emission_Trans = ln((CO2e_gen_550)/(CO2e_gen_Base)) 
	if CO2e_gen_550!=. & CO2e_gen_Base!=.;

gen Phi_Trans =.;
replace Phi_Trans = (CO2e_gen_550 - CO2e_gen_Base) / log2scenario_Emission_Trans
	if log2scenario_Emission_Trans!=0 & log2scenario_Emission_Trans!=.;

replace scale_effect_Trans = log2scenario_ES_Trans * Phi_Trans
	if fuel=="All" & scale_effect_Trans==.;
replace EI_effect_Trans = log2scenario_EI_Trans * Phi_Trans
	if fuel=="All" & EI_effect_Trans==.;
replace CI_effect_Trans = log2scenario_EF_Trans * Phi_Trans
	if fuel=="All" & CI_effect_Trans==.;

order _all, alphabetic;
order  region fuel model year CO2e_gen_550 CO2e_gen_Base Phi_Trans EF_Trans_550 EF_Trans_Base
scale_effect_Trans EI_effect_Trans CI_effect_Trans
scale_effect_Freight scale_effect_Passenger EI_effect_Freight EI_effect_Passenger CI_effect_Freight CI_effect_Passenger;

drop log2scenario* weight*;

save subset/`1'_`2'_Trans_Analysis, replace;

/*************************************************** Second step ***************************************************/
/******************************************************************************************************************/
/* Further decompose carbon intensity effect into fuel emission efficiency improvement and fuel switching */

gen delta_EF =.;
replace delta_EF = EF_Trans_550 - EF_Trans_Base if EF_Trans_550!=. & EF_Trans_Base!=.;

gen avg_EF =.;
replace avg_EF = (EF_Trans_550 + EF_Trans_Base)/2 if EF_Trans_550!=. & EF_Trans_Base!=.;

/*Calculate fuel share */
foreach s of local scenarios {;
gen FS_`s' =.;

	forvalues year_i = 2010(10)2050 {;
		levelsof FE_Trans_`s' if fuel=="All" & year==`year_i', miss local (FE_total_`s');
	
		foreach x of varlist fuel {;
			replace FS_`s' = FE_Trans_`s' / `FE_total_`s'' 
				if fuel==`x' & year==`year_i' & `FE_total_`s''!=.;
			};
	};
};

gen delta_FS=.;
replace delta_FS = FS_550 - FS_Base if FS_550!=. & FS_Base!=.;

gen avg_FS=.;
replace avg_FS = (FS_550 + FS_Base)/2 if FS_550!=. & FS_Base!=.;

/* Calculate CO2 change due to emission factor improvement */
gen EF_effect_share = .;

forvalues year_i = 2010(10)2050 {;
	levelsof delta_EF if fuel=="All" & year==`year_i', miss local (delta_EF_all_`year_i');
	
	foreach x of varlist fuel {;
		replace EF_effect_share = (delta_EF * avg_FS) / `delta_EF_all_`year_i''
			if fuel==`x' & year==`year_i' & `delta_EF_all_`year_i''!=. & delta_EF!=. & avg_FS!=.;
		};
};

replace EF_effect_share=0 if EF_effect_share==.;

forvalues year_i = 2010(10)2050 {;
	foreach x of varlist fuel {;
		levelsof EF_effect_share if fuel=="`x'" & year==`year_i';
			local EFES_`x'_`year_i' = `r(levels)';
	};
	
	replace EF_effect_share = `EFES_Electricity_`year_i'' + `EFES_Gases_`year_i''
		+ `EFES_Liquids_`year_i'' + `EFES_Other_`year_i'' + `EFES_Hydrogen_`year_i''
		if fuel=="All" & year==`year_i';
	};

gen EF_effect =.;

forvalues year_i = 2010(10)2050 {;
	levelsof CI_effect_Trans if fuel=="All" & year==`year_i', miss local (CI_Effect_Total_`year_i');
	replace EF_effect = EF_effect_share * `CI_Effect_Total_`year_i''
		if year==`year_i' & EF_effect_share!=. & `CI_Effect_Total_`year_i''!=.;
};


/* Fuel switching effect */
gen Switch_effect_share =.;
forvalues year_i = 2010(10)2050 {;
	foreach x of varlist fuel {;
		replace Switch_effect_share =  (avg_EF * delta_FS) / `delta_EF_all_`year_i''
			if fuel==`x' & year==`year_i' & `delta_EF_all_`year_i''!=. & avg_EF !=. & delta_FS!=.;
		};
};
replace Switch_effect_share=0 if Switch_effect_share==.;

forvalues year_i = 2010(10)2050 {;
	foreach x of varlist fuel {;
		levelsof Switch_effect_share if fuel=="`x'" & year==`year_i';
			local FSES_`x'_`year_i' = `r(levels)';
	};
	
	replace Switch_effect_share = `FSES_Electricity_`year_i'' + `FSES_Gases_`year_i'' 
		+ `FSES_Liquids_`year_i'' + `FSES_Other_`year_i'' + `FSES_Hydrogen_`year_i''
		if fuel=="All" & year==`year_i';
	};

gen FuelSwitch_Effect=.;

forvalues year_i = 2010(10)2050 {;
	replace FuelSwitch_Effect = Switch_effect_share * `CI_Effect_Total_`year_i''
		if year==`year_i' & Switch_effect_share!=. & `CI_Effect_Total_`year_i''!=.;
};

/*************************************************** Third step ***************************************************/
/******************************************************************************************************************/
/* Further decompose fuel switching effect. Calculate the average emission factor of all fuels with decreasing shares.
Compare this calculated average emission factor with each fuel's emission factor to understand fuel switching effects. */

gen EF_DecSh=0;
replace EF_DecSh = avg_EF if delta_FS<0 
	& fuel!="All" & fuel!="Liquids Biomass" & fuel!="Liquids Oil" & fuel!="Liquids Coal"; /* avoid double counting with Liquids */

gen Delta_FS_DecSh=0;
replace Delta_FS_DecSh = delta_FS if delta_FS<0 
	& fuel!="All" & fuel!="Liquids Biomass" & fuel!="Liquids Oil" & fuel!="Liquids Coal";

gen prod_EF_DeltaFS = EF_DecSh * Delta_FS_DecSh;

forvalues year_i = 2020(10)2050 {;
	summarize Delta_FS_Dec if year==`year_i';
	local SumSh_DecSh_`year_i' = r(sum);
	summarize prod_EF_DeltaFS if year==`year_i';
	local prod_`year_i' = r(sum);
	local avg_EF_DecSh_`year_i' = `prod_`year_i''/`SumSh_DecSh_`year_i'';
	
};

gen FuelSwitch_effect2_share =.;

forvalues year_i = 2020(10)2050 {;
	replace FuelSwitch_effect2_share = (avg_EF - `avg_EF_DecSh_`year_i'') * delta_FS /`delta_EF_all_`year_i''
		if year==`year_i' & `delta_EF_all_`year_i''!=. & avg_EF!=. & `avg_EF_DecSh_`year_i''!=. & delta_FS!=.;
};

replace FuelSwitch_effect2_share=0 if FuelSwitch_effect2_share==.;

forvalues year_i = 2020(10)2050 {;
	foreach x of varlist fuel {;
		levelsof FuelSwitch_effect2_share if fuel=="`x'" & year==`year_i', miss local (FSES2_`x'_`year_i');
	};
	
	replace FuelSwitch_effect2_share = `FSES2_Electricity_`year_i'' + `FSES2_Gases_`year_i''
		+ `FSES2_Liquids_`year_i'' + `FSES2_Other_`year_i'' + `FSES2_Hydrogen_`year_i''
		if fuel=="All" & year==`year_i';
	};
	
gen FuelSwitch_effect2=.;

forvalues year_i = 2020(10)2050 {;
	replace FuelSwitch_effect2 = FuelSwitch_effect2_share * `CI_Effect_Total_`year_i''
		if year==`year_i' & `CI_Effect_Total_`year_i''!=.;
};

save subset/`1'_`2'_Trans_Analysis, replace;

/* Generate output table */
keep model region fuel year scale_effect_Trans EI_effect_Trans CI_effect_Trans EF_Reduce_Effect FuelSwitch_effect2;
rename EF_Reduce_Effect EF_effect_Trans;
rename FuelSwitch_effect2 FS_effect_Trans;

save Trans_outputs/`1'_`2'_Trans, replace;
label variable scale_effect_Trans "Transport sector scale effect";
label variable EI_effect_Trans "Transport sector energy intensity effect";
label variable CI_effect_Trans "Transport sector carbon intensity effect";
label variable EF_effect_Trans "Tansport sector emission rate improvement effect (under carbon effect)";
label variable FS_effect_Trans "Tansport sector fuel switching effect (under carbon effect)";

save Trans_outputs/`1'_`2'_Trans, replace;
clear all;
};
