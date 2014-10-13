#delimit ;
clear all;

/*****************************************************************************************************************/
/********************************  Subset Building sector data under 550 and Base scenario  ******************************/
/***************************************************************************************************************/
local scenarios "550 Base";
foreach s of local scenarios {;

use subset/`md'_`rg'_`s'.dta;
keep model fuel year region FE_Building Emissions_CO2_FFI_BLD;
/* Floor space data are missing; otherwise the variable should be kept */  

/* keep only secondary energy sources which are relevant in end use sectors*/
keep if fuel=="All" | fuel=="Electricity" | fuel=="Gases" | fuel=="Heat" | fuel=="Liquids" | fuel=="Hydrogen" 
		|fuel=="Solids" | fuel=="Solids Biomass" | fuel=="Solids Biomass (Traditional)" | 
		|fuel=="Solids Coal" | fuel=="Space Heating" | fuel=="Other";
/* Liquids biomass, liquids oil and liquids coal are irrelevant, so drop here*/

save subset/`md'_`rg'_`s'_Bld,replace;
clear;


/***************************** Find emission factors by fuel in Building sector**********************************/
/* Emission factors are calculated from IEA's WEO2013 data. 
(See "IEA Emission Factors.xlsx") document under AMPERE folder */

use Emission_Factors.dta;

/* The emissions factors used here are derived from dividing emissions from TFC by total fuel inputs into TFC */
local fuels "Coal Oil Gas";
forvalues year_i = 2010(10)2030 {;
	foreach x of local fuels {;
		levelsof EF_PI_TFC if scenario=="`s'" & region=="`rg'" & fuel=="`x'" & year==`year_i';
			local EF_`x'_TFC_`year_i'=`r(levels)';
		};
	};

clear;

/* Find electricity emission factors */
use subset/`md'_`rg'_`s'_POWER.dta;
forvalues year_i = 2010(10)2050 {;
	levelsof CO2_Power_`s' if fuel=="All" & year==`year_i';
		local CO2_Power_`year_i'=`r(levels)';
	levelsof SE_Electricity_`s' if fuel=="All" & year==`year_i';
		local PowerGen_`year_i'=`r(levels)';
	local EF_electricity_`year_i' = `CO2_Power_`year_i'' / `PowerGen_`year_i'';
	};

clear;

/****************************** Calculate emissions by fuel in the building sector ***********************************/
use subset/`md'_`rg'_`s'_Bld;

gen CO2e_gen=0;

/* Assume "hydrogen" and "other" fuels have zero emission factors */


forvalues year_i = 2010(10)2030 {;
	replace CO2e_gen = FE_Building * `EF_Oil_TFC_`year_i'' 
		if fuel=="Liquids" & year==`year_i'; 
	replace CO2e_gen = FE_Building * `EF_Gas_TFC_`year_i'' 
		if fuel=="Gases" & year==`year_i'; 
	replace CO2e_gen = FE_Building * `EF_Coal_TFC_`year_i'' 
		if fuel=="Solids Coal" & year==`year_i'; 
	};
 forvalues year_i = 2040(10)2050 {;
	replace CO2e_gen = FE_Building * `EF_Oil_TFC_2030' 
		if fuel=="Liquids" & year==`year_i'; 
	replace CO2e_gen = FE_Building * `EF_Gas_TFC_2030' 
		if fuel=="Gases" & year==`year_i'; 
	replace CO2e_gen = FE_Building * `EF_Coal_TFC_2030' 
		if fuel=="Solids Coal" & year==`year_i'; 
	};
replace CO2e_gen = 0 if CO2e_gen==.;

/* Calculate total emissions in Building Sector from fossil fuels */

forvalues year_i = 2010(10)2050 {;
	levelsof CO2e_gen if fuel=="Gases" & year==`year_i';
		local CO2_Gases_`year_i' = `r(levels)';
	levelsof CO2e_gen if fuel=="Liquids" & year==`year_i';
		local CO2_Liquids_`year_i' = `r(levels)';
	levelsof CO2e_gen if fuel=="Solids Coal" & year==`year_i';
		local CO2_Coal_`year_i' = `r(levels)';
	replace CO2e_gen = `CO2_Gases_`year_i'' + `CO2_Liquids_`year_i'' + `CO2_Coal_`year_i''
		if fuel=="All" & year==`year_i'; 
	};
	
/* Compare calculated total CO2 with the data in the original dataset */
forvalues year_i = 2010(10)2050 {;
	levelsof CO2e_gen if fuel=="All" & year==`year_i';
		local CO2e_gen_`year_i' = `r(levels)';
	levelsof Emissions_CO2_FFI_BLD if fuel=="All" & year==`year_i';
		local CO2e_org_`year_i' = `r(levels)';
	local scale_factor_`year_i' = `CO2e_org_`year_i'' / `CO2e_gen_`year_i'';
};

/* Adjust CO2 by fuel with scale_factor of each year */
gen CO2e_adj = 0;

forvalues year_i = 2010(10)2050 {;
	replace CO2e_adj = CO2e_gen * `scale_factor_`year_i'' if year==`year_i';
	};

gen scale_factor = 0;
replace scale_factor = CO2e_adj / CO2e_gen if CO2e_gen!=0;

/* Calculate electricity emissions by applying emission factors derived from power sector data */
forvalues year_i = 2010(10)2050 {;
	replace CO2e_gen = FE_Building * `EF_electricity_`year_i''
		if fuel=="Electricity" & year==`year_i';
	};
replace CO2e_adj = CO2e_gen if fuel=="Electricity";

/* Use integrated counting method, add electricity emissions to total fial cosumption emissions */
forvalues year_i = 2010(10)2050 {;
	levelsof CO2e_gen if fuel=="All" & year==`year_i';
		local CO2_TFC_`year_i'=`r(levels)';
	levelsof CO2e_gen if fuel=="Electricity" & year==`year_i';
		local CO2_Electricity_`year_i'=`r(levels)';
	replace CO2e_gen = `CO2_TFC_`year_i'' + `CO2_Electricity_`year_i''
		if fuel=="All" & year==`year_i';
		
	levelsof CO2e_adj if fuel=="All" & year==`year_i';
		local CO2_TFC_adj_`year_i'=`r(levels)';
	replace CO2e_adj=`CO2_TFC_adj_`year_i'' + `CO2_Electricity_`year_i''
		if fuel=="All" & year==`year_i';
		};

rename FE_Building FE_Building_`s';
rename Emissions_CO2_FFI_BLD CO2_Bld_`s';
rename CO2e_gen CO2e_gen_`s';
rename CO2e_adj CO2e_adj_`s';
rename scale_factor scale_factor_`s';

save subset/`md'_`rg'_`s'_Bld,replace;
clear;

};
