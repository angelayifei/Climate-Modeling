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
/* Decompose CO2 emissions from transport at the sectoral level, into demand effect, 
energy intensity effect and carbon intensity effect */

/* Sectoral demand level log2scenario */
gen log2scenario_Df =.;
replace log2scenario_Df = ln((ES_Trans_Freight_550)/(ES_Trans_Freight_Base))
	if fuel=="All" & ES_Trans_Freight_Base!=.;

gen log2scenario_Dp =.;
replace log2scenario_Dp = ln((ES_Trans_Passenger_550)/(ES_Trans_Passenger_Base))
	if fuel=="All" & ES_Trans_Passenger_Base!=.;

/*Energy intensity (energy consumption/sectoral activity) log2scenario */
gen EI_Freight_550 =.;
replace EI_Freight_550 = FE_Trans_Freight_550 / ES_Trans_Freight_550 
	if fuel=="All" & FE_Trans_Freight_550!=. & ES_Trans_Freight_550!=.;
gen EI_Freight_Base =.;
replace EI_Freight_Base = FE_Trans_Freight_Base / ES_Trans_Freight_Base 
	if fuel=="All" & FE_Trans_Freight_Base!=. & ES_Trans_Freight_Base!=.;
gen log2scenario_EIf =.;
replace log2scenario_EIf = ln((EI_Freight_550)/(EI_Freight_Base))
	if fuel=="All" & EI_Freight_550!=. & EI_Freight_Base!=.;

gen EI_Passenger_550 =.;
replace EI_Passenger_550 = FE_Trans_Passenger_550 / ES_Trans_Passenger_550 
	if fuel=="All" & FE_Trans_Passenger_550!=. & ES_Trans_Passenger_550!=.;
gen EI_Passenger_Base =.;
replace EI_Passenger_Base = FE_Trans_Passenger_Base / ES_Trans_Passenger_Base 
	if fuel=="All" & FE_Trans_Passenger_Base!=. & ES_Trans_Passenger_Base!=.;
gen log2scenario_EIp =.;
replace log2scenario_EIp = ln((EI_Passenger_550)/(EI_Passenger_Base))
	if fuel=="All" & EI_Passenger_550!=. & EI_Passenger_Base!=.;

/*Allocate emissions to Freight and Passenger subsectors based on shares of subsectoral energy consumption in 
total transport energy consumption */
gen weight_Freight_550 =.;
replace weight_Freight_550 = FE_Trans_Freight_550 / FE_Trans_550
	if fuel=="All" & FE_Trans_Freight_550!=. & FE_Trans_550!=.;
gen CO2_Trans_Freight_550 =.;
replace CO2_Trans_Freight_550 = CO2e_adj_550 * weight_Freight_550
	if fuel=="All" & weight_Freight_550!=.;

gen weight_Freight_Base =.;
replace weight_Freight_Base = FE_Trans_Freight_Base / FE_Trans_Base
	if fuel=="All" & FE_Trans_Freight_Base!=. & FE_Trans_Base!=.;
gen CO2_Trans_Freight_Base =.;
replace CO2_Trans_Freight_Base = CO2e_adj_Base * weight_Freight_Base
	if fuel=="All" & weight_Freight_Base!=.;

gen weight_Passenger_550 =.;
replace weight_Passenger_550 = FE_Trans_Passenger_550 / FE_Trans_550
	if fuel=="All" & FE_Trans_Passenger_550!=. & FE_Trans_550!=.;
gen CO2_Trans_Passenger_550 =.;
replace CO2_Trans_Passenger_550 = CO2e_adj_550 * weight_Passenger_550
	if fuel=="All" & weight_Passenger_550!=.;

gen weight_Passenger_Base =.;
replace weight_Passenger_Base = FE_Trans_Passenger_Base / FE_Trans_Base
	if fuel=="All" & FE_Trans_Passenger_Base!=. & FE_Trans_Base!=.;
gen CO2_Trans_Passenger_Base =.;
replace CO2_Trans_Passenger_Base = CO2e_adj_Base * weight_Passenger_Base
	if fuel=="All" & weight_Passenger_Base!=.;
	
gen log2scenario_Emissionf =.;
replace log2scenario_Emissionf=ln((CO2_Trans_Freight_550)/(CO2_Trans_Freight_Base))
	if fuel=="All" & CO2_Trans_Freight_Base!=.;

gen log2scenario_Emissionp =.;
replace log2scenario_Emissionp=ln((CO2_Trans_Passenger_550)/(CO2_Trans_Passenger_Base))
	if fuel=="All" & CO2_Trans_Passenger_Base!=.;

/* Emission factors */
gen EF_Freight_550 =.;
replace EF_Freight_550 = CO2_Trans_Freight_550 / FE_Trans_Freight_550
	if  fuel=="All" & FE_Trans_Freight_550!=.;
gen EF_Freight_Base =.;
replace EF_Freight_Base = CO2_Trans_Freight_Base / FE_Trans_Freight_Base
	if  fuel=="All" & FE_Trans_Freight_Base!=.;

gen EF_Passenger_550 =.;
replace EF_Passenger_550 = CO2_Trans_Passenger_550 / FE_Trans_Passenger_550
	if  fuel=="All" & FE_Trans_Passenger_550!=.;
gen EF_Passenger_Base =.;
replace EF_Passenger_Base = CO2_Trans_Passenger_Base / FE_Trans_Passenger_Base
	if  fuel=="All" & FE_Trans_Passenger_Base!=.;

gen log2scenario_EFf =.;
replace log2scenario_EFf=ln((EF_Freight_550)/(EF_Freight_Base))
	if fuel=="All" & EF_Freight_Base!=.;

gen log2scenario_EFp =.;
replace log2scenario_EFp=ln((EF_Passenger_550)/(EF_Passenger_Base))
	if fuel=="All" & EF_Passenger_Base!=.;

gen Phi_Freight = .;
replace Phi_Freight = (CO2_Trans_Freight_550 - CO2_Trans_Freight_Base) / (log2scenario_Emissionf)
	if fuel=="All" & CO2_Trans_Freight_Base!=. & log2scenario_Emissionf !=.;

gen Phi_Passenger = .;
replace Phi_Passenger = (CO2_Trans_Passenger_550 - CO2_Trans_Passenger_Base) / (log2scenario_Emissionp)
	if fuel=="All" & CO2_Trans_Passenger_Base!=. & log2scenario_Emissionp !=.;

/* Calculate scale effect, energy intensity effect and carbon intensity effect 
when subsectoral energy consumption data are available*/
gen scale_effect_Freight =.;
replace scale_effect_Freight = log2scenario_Df * Phi_Freight
	if fuel=="All" & Phi_Freight!=.;
gen scale_effect_Passenger =.;
replace scale_effect_Passenger = log2scenario_Dp * Phi_Passenger
	if fuel=="All" & Phi_Passenger!=.;

gen EI_effect_Freight =.;
replace EI_effect_Freight = log2scenario_EIf * Phi_Freight
	if fuel=="All" & Phi_Freight!=.;
gen EI_effect_Passenger =.;
replace EI_effect_Passenger = log2scenario_EIp * Phi_Passenger
	if fuel=="All" & Phi_Passenger!=.;

gen CI_effect_Freight =.;
replace CI_effect_Freight = log2scenario_EFf * Phi_Freight
	if fuel=="All" & Phi_Freight!=.;
gen CI_effect_Passenger =.;
replace CI_effect_Passenger = log2scenario_EFp * Phi_Passenger
	if fuel=="All" & Phi_Passenger!=.;

gen scale_effect_trans =.;
replace scale_effect_trans = scale_effect_Freight + scale_effect_Passenger
	if fuel=="All" & scale_effect_Freight!=. & scale_effect_Passenger!=.;

gen EI_effect_trans =.;
replace EI_effect_trans = EI_effect_Freight + EI_effect_Passenger
	if fuel=="All" & EI_effect_Freight!=. & EI_effect_Passenger!=.;

gen CI_effect_trans =.;
replace CI_effect_trans = CI_effect_Freight + CI_effect_Passenger
	if fuel=="All" & CI_effect_Freight!=. & CI_effect_Passenger!=.;

/* Calculate scale effect, energy intensity effect and carbon intensity effect when 
subsectoral energy consumption data are not available*/
gen log2scenario_Dt =.;
replace log2scenario_Dt = (log2scenario_Dp + log2scenario_Df)/2
	if fuel=="All"; /* Approximate calculation */

gen log2scenario_It=.;
replace log2scenario_It = ln((FE_Trans_550)/(FE_Trans_Base)) - log2scenario_Dt
	if fuel=="All";

gen EF_trans_550=.;
replace EF_trans_550 = CO2e_adj_550 / FE_Trans_550 
	if CO2e_adj_550!=. & FE_Trans_550!=.;
gen EF_trans_Base=.;
replace EF_trans_Base = CO2e_adj_Base / FE_Trans_Base
	if CO2e_adj_Base!=. & FE_Trans_Base!=.;
	
gen log2scenario_EFt=.;
replace log2scenario_EFt = ln((EF_trans_550)/(EF_trans_Base))
	if fuel=="All" & EF_trans_Base!=. & EF_trans_550 !=.;

gen log2scenario_CO2trans=.;
replace log2scenario_CO2trans = ln((CO2e_adj_550)/(CO2e_adj_Base)) 
	if CO2e_adj_550!=. & CO2e_adj_Base!=.;

gen Phi_trans =.;
replace Phi_trans = (CO2e_adj_550 - CO2e_adj_Base) / log2scenario_CO2trans
	if log2scenario_CO2trans!=0 & log2scenario_CO2trans!=.;

replace scale_effect_trans = log2scenario_Dt * Phi_trans
	if fuel=="All" & scale_effect_trans==.;

replace EI_effect_trans = log2scenario_It * Phi_trans
	if fuel=="All" & EI_effect_trans==.;

replace CI_effect_trans = log2scenario_EFt * Phi_trans
	if fuel=="All" & CI_effect_trans==.;

order _all, alphabetic;
order region fuel model year CO2e_adj_550 CO2e_adj_Base Phi_trans EF_trans_550 EF_trans_Base
scale_effect_trans EI_effect_trans CI_effect_trans
scale_effect_Freight scale_effect_Passenger EI_effect_Freight EI_effect_Passenger CI_effect_Freight CI_effect_Passenger;

drop log2scenario* weight* scale_factor*;

save subset/`1'_`2'_Trans_Analysis, replace;

/*************************************************** Second step ***************************************************/
/******************************************************************************************************************/
/* Further decompose carbon intensity effect into fuel emission efficiency improvement and fuel switching */

gen delta_EF =.;
replace delta_EF = EF_trans_550 - EF_trans_Base if EF_trans_550!=. & EF_trans_Base!=.;

gen avg_EF =.;
replace avg_EF = (EF_trans_550 + EF_trans_Base)/2 if EF_trans_550!=. & EF_trans_Base!=.;

/* Emission efficiency improvement effect */
gen FS_550 =.;

forvalues year_i = 2010(10)2050 {;
	levelsof FE_Trans_550 if fuel=="All" & year==`year_i', miss local (FE_total_550);
	
	foreach x of varlist fuel {;
		replace FS_550 = FE_Trans_550 / `FE_total_550' 
			if fuel==`x' & year==`year_i' & `FE_total_550'!=.;
		};
};

gen FS_Base =.;

forvalues year_i = 2010(10)2050 {;
	levelsof FE_Trans_Base if fuel=="All" & year==`year_i', miss local (FE_total_Base);
	
	foreach x of varlist fuel {;
		replace FS_Base = FE_Trans_Base / `FE_total_Base' 
			if fuel==`x' & year==`year_i' & `FE_total_Base'!=.;
		};
};

gen delta_FS=.;
replace delta_FS = FS_550 - FS_Base if FS_550!=. & FS_Base!=.;

gen avg_FS=.;
replace avg_FS = (FS_550 + FS_Base)/2 if FS_550!=. & FS_Base!=.;

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
	levelsof EF_effect_share if fuel=="Electricity" & year==`year_i';
		local EFES_Electricity_`year_i' = `r(levels)';
	levelsof EF_effect_share if fuel=="Gases" & year==`year_i';
		local EFES_Gases_`year_i' = `r(levels)';
	levelsof EF_effect_share if fuel=="Liquids" & year==`year_i';
		local EFES_Liquids_`year_i' = `r(levels)';
	levelsof EF_effect_share if fuel=="Other" & year==`year_i';
		local EFES_Other_`year_i' = `r(levels)';
	levelsof EF_effect_share if fuel=="Hydrogen" & year==`year_i';
		local EFES_Hydrogen_`year_i' = `r(levels)';
	
	replace EF_effect_share = `EFES_Electricity_`year_i'' + `EFES_Gases_`year_i''
		+ `EFES_Liquids_`year_i'' + `EFES_Other_`year_i'' + `EFES_Hydrogen_`year_i''
		if fuel=="All" & year==`year_i';
	};

gen EF_Reduce_Effect =.;

forvalues year_i = 2010(10)2050 {;
	levelsof CI_effect_trans if fuel=="All" & year==`year_i', miss local (CI_Effect_Total_`year_i');
	replace EF_Reduce_Effect = EF_effect_share * `CI_Effect_Total_`year_i''
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
	levelsof Switch_effect_share if fuel=="Electricity" & year==`year_i';
		local FSES_Electricity_`year_i' = `r(levels)';
	levelsof Switch_effect_share if fuel=="Gases" & year==`year_i';
		local FSES_Gases_`year_i' = `r(levels)';
	levelsof Switch_effect_share if fuel=="Liquids" & year==`year_i';
		local FSES_Liquids_`year_i' = `r(levels)';
	levelsof Switch_effect_share if fuel=="Other" & year==`year_i';
		local FSES_Other_`year_i' = `r(levels)';
	levelsof Switch_effect_share if fuel=="Hydrogen" & year==`year_i';
		local FSES_Hydrogen_`year_i' = `r(levels)';
	
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
	levelsof FuelSwitch_effect2_share if fuel=="Electricity" & year==`year_i', miss local (FSES2_Electricity_`year_i');
	levelsof FuelSwitch_effect2_share if fuel=="Gases" & year==`year_i', miss local (FSES2_Gases_`year_i');
	levelsof FuelSwitch_effect2_share if fuel=="Liquids" & year==`year_i', miss local (FSES2_Liquids_`year_i');
	levelsof FuelSwitch_effect2_share if fuel=="Other" & year==`year_i', miss local (FSES2_Other_`year_i');
	levelsof FuelSwitch_effect2_share if fuel=="Hydrogen" & year==`year_i', miss local (FSES2_Hydrogen_`year_i');
	
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
keep model region fuel year scale_effect_trans EI_effect_trans CI_effect_trans EF_Reduce_Effect FuelSwitch_effect2;
rename EF_Reduce_Effect EF_effect_trans;
rename FuelSwitch_effect2 FS_effect_trans;

save Trans_outputs/`1'_`2'_Trans, replace;
label variable scale_effect_trans "Transport sector scale effect";
label variable EI_effect_trans "Transport sector energy intensity effect";
label variable CI_effect_trans "Transport sector carbon intensity effect";
label variable EF_effect_trans "Tansport sector emission rate improvement effect (under carbon effect)";
label variable FS_effect_trans "Tansport sector fuel switching effect (under carbon effect)";

save Trans_outputs/`1'_`2'_Trans, replace;
clear all;
};
