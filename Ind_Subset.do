#delimit ;
clear all;

/*****************************************************************************************************************/
/********************************  Subset Industry sector data under 550 scenario  ******************************/
/***************************************************************************************************************/

use subset/`md’_`rg’_550.dta;
keep model fuel year region FE_Industry Emissions_CO2_FFI_IND GDP_MER GDP_PPP;
/* GDP as service demand indicator */

/* keep only secondary energy sources which are relevant in end use sectors*/
keep if fuel=="All" | fuel=="Electricity" | fuel=="Gases" | fuel=="Heat" | fuel=="Liquids" | fuel=="Hydrogen" 
		|fuel=="Solids" | fuel=="Solids Biomass" | fuel=="Solids Biomass (Traditional)" | 
		|fuel=="Solids Coal" | fuel=="Space Heating" | fuel=="Other";
/* Liquids biomass, liquids oil and liquids coal are irrelevant, so drop here*/

save subset/`md’_`rg’_550_Ind,replace;
clear;

/***************************** Find emission factors by fuel in Industry sector**********************************/
/* Emission factors are calculated from IEA's WEO2013 data. 
(See "IEA Emission Factors.xlsx") document under AMPERE folder */

use Emission_Factors.dta;

/* The emissions factors used here are derived from dividing emissions from TFC by total fuel inputs into TFC */
local fuels "Coal Oil Gas";
forvalues year_i = 2010(10)2030 {;
	foreach x of local fuels {;
		levelsof EF_PI_TFC if scenario=="NPS" & region=="`rg’" & fuel=="`x'" & year==`year_i';
			local EF_`x'_TFC_`year_i'=`r(levels)';
		};
	};

clear;

/* Find electricity emission factors */
use subset/`md’_`rg’_550_POWER.dta;
forvalues year_i = 2010(10)2050 {;
	levelsof CO2_Power_550 if fuel=="All" & year==`year_i';
		local CO2_Power_`year_i'=`r(levels)';
	levelsof SE_Electricity_550 if fuel=="All" & year==`year_i';
		local PowerGen_`year_i'=`r(levels)';
	local EF_electricity_`year_i' = `CO2_Power_`year_i'' / `PowerGen_`year_i'';
	};

clear;

/****************************** Calculate emissions by fuel in the industry sector ***********************************/
use subset/`md’_`rg’_550_Ind;

gen CO2e_gen=0;

/* Assume "hydrogen" and "other" fuels have zero emission factors */


forvalues year_i = 2010(10)2030 {;
	replace CO2e_gen = FE_Industry * `EF_Oil_TFC_`year_i'' 
		if fuel=="Liquids" & year==`year_i'; 
	replace CO2e_gen = FE_Industry * `EF_Gas_TFC_`year_i'' 
		if fuel=="Gases" & year==`year_i'; 
	replace CO2e_gen = FE_Industry * `EF_Coal_TFC_`year_i'' 
		if fuel=="Solids" & year==`year_i'; 
	/*No Solids Coal data are available. Assume Solids only contain coal */
	};
 forvalues year_i = 2040(10)2050 {;
 replace CO2e_gen = FE_Industry * `EF_Oil_TFC_2030' 
		if fuel=="Liquids" & year==`year_i'; 
	replace CO2e_gen = FE_Industry * `EF_Gas_TFC_2030' 
		if fuel=="Gases" & year==`year_i'; 
	replace CO2e_gen = FE_Industry * `EF_Coal_TFC_2030' 
		if fuel=="Solids" & year==`year_i'; 
	};
replace CO2e_gen = 0 if CO2e_gen==.;

/* Calculate total emissions in Industry Sector from fossil fuels */
forvalues year_i = 2010(10)2050 {;
	levelsof CO2e_gen if fuel=="Gases" & year==`year_i';
		local CO2_Gases_`year_i' = `r(levels)';
	levelsof CO2e_gen if fuel=="Liquids" & year==`year_i';
		local CO2_Liquids_`year_i' = `r(levels)';
	levelsof CO2e_gen if fuel=="Solids" & year==`year_i';
		local CO2_Coal_`year_i' = `r(levels)';
	replace CO2e_gen = `CO2_Gases_`year_i'' + `CO2_Liquids_`year_i'' + `CO2_Coal_`year_i''
		if fuel=="All" & year==`year_i'; 
	};
	
/* Compare calculated total CO2 with the data in the original dataset */
forvalues year_i = 2010(10)2050 {;
	levelsof CO2e_gen if fuel=="All" & year==`year_i';
		local CO2e_gen_`year_i' = `r(levels)';
	levelsof Emissions_CO2_FFI_IND if fuel=="All" & year==`year_i';
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
	replace CO2e_gen = FE_Industry * `EF_electricity_`year_i''
		if fuel=="Electricity" & year==`year_i';
	};
replace CO2e_adj = CO2e_gen if fuel=="Electricity";

/* Use integrated counting method, add electricity emissions to total emissions */
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

rename FE_Industry FE_Industry_550;
rename GDP_MER GDP_MER_550; 
rename GDP_PPP GDP_PPP_550;
rename Emissions_CO2_FFI_IND CO2_Ind_550;
rename CO2e_gen CO2e_gen_550;
rename CO2e_adj CO2e_adj_550;
rename scale_factor scale_factor_550;

save subset/`md’_`rg’_550_Ind,replace;
clear;

#delimit ;
clear all;

/*****************************************************************************************************************/
/********************************  Subset Industry sector data under Base scenario  ******************************/
/***************************************************************************************************************/

use subset/`md’_`rg’_Base.dta;
keep model fuel year region FE_Industry Emissions_CO2_FFI_IND GDP_MER GDP_PPP;
/* GDP as service demand indicator */

/* keep only secondary energy sources which are relevant in end use sectors*/
keep if fuel=="All" | fuel=="Electricity" | fuel=="Gases" | fuel=="Heat" | fuel=="Liquids" | fuel=="Hydrogen" 
		|fuel=="Solids" | fuel=="Solids Biomass" | fuel=="Solids Biomass (Traditional)" | 
		|fuel=="Solids Coal" | fuel=="Space Heating" | fuel=="Other";
/* Liquids biomass, liquids oil and liquids coal are irrelevant, so drop here*/

save subset/`md’_`rg’_Base_Ind,replace;
clear;

/***************************** Find emission factors by fuel in Industry sector**********************************/
/* Emission factors are calculated from IEA's WEO2013 data. 
(See "IEA Emission Factors.xlsx") document under AMPERE folder */

use Emission_Factors.dta;

/* The emissions factors used here are derived from dividing emissions from TFC by total fuel inputs into TFC */
local fuels "Coal Oil Gas";
forvalues year_i = 2010(10)2030 {;
	foreach x of local fuels {;
		levelsof EF_PI_TFC if scenario=="NPS" & region=="`rg’" & fuel=="`x'" & year==`year_i';
			local EF_`x'_TFC_`year_i'=`r(levels)';
		};
	};

clear;

/* Find electricity emission factors */
use subset/`md’_`rg’_Base_POWER.dta;
forvalues year_i = 2010(10)2050 {;
	levelsof CO2_Power_Base if fuel=="All" & year==`year_i';
		local CO2_Power_`year_i'=`r(levels)';
	levelsof SE_Electricity_Base if fuel=="All" & year==`year_i';
		local PowerGen_`year_i'=`r(levels)';
	local EF_electricity_`year_i' = `CO2_Power_`year_i'' / `PowerGen_`year_i'';
	};

clear;

/****************************** Calculate emissions by fuel in the industry sector ***********************************/
use subset/`md’_`rg’_Base_Ind;

gen CO2e_gen=0;

/* Assume "hydrogen" and "other" fuels have zero emission factors */


forvalues year_i = 2010(10)2030 {;
	replace CO2e_gen = FE_Industry * `EF_Oil_TFC_`year_i'' 
		if fuel=="Liquids" & year==`year_i'; 
	replace CO2e_gen = FE_Industry * `EF_Gas_TFC_`year_i'' 
		if fuel=="Gases" & year==`year_i'; 
	replace CO2e_gen = FE_Industry * `EF_Coal_TFC_`year_i'' 
		if fuel=="Solids" & year==`year_i'; 
	/*No Solids Coal data are available. Assume Solids only contain coal */
	};
 forvalues year_i = 2040(10)2050 {;
 replace CO2e_gen = FE_Industry * `EF_Oil_TFC_2030' 
		if fuel=="Liquids" & year==`year_i'; 
	replace CO2e_gen = FE_Industry * `EF_Gas_TFC_2030' 
		if fuel=="Gases" & year==`year_i'; 
	replace CO2e_gen = FE_Industry * `EF_Coal_TFC_2030' 
		if fuel=="Solids" & year==`year_i'; 
	};
replace CO2e_gen = 0 if CO2e_gen==.;

/* Calculate total emissions in Industry Sector from fossil fuels */
forvalues year_i = 2010(10)2050 {;
	levelsof CO2e_gen if fuel=="Gases" & year==`year_i';
		local CO2_Gases_`year_i' = `r(levels)';
	levelsof CO2e_gen if fuel=="Liquids" & year==`year_i';
		local CO2_Liquids_`year_i' = `r(levels)';
	levelsof CO2e_gen if fuel=="Solids" & year==`year_i';
		local CO2_Coal_`year_i' = `r(levels)';
	replace CO2e_gen = `CO2_Gases_`year_i'' + `CO2_Liquids_`year_i'' + `CO2_Coal_`year_i''
		if fuel=="All" & year==`year_i'; 
	};
	
/* Compare calculated total CO2 with the data in the original dataset */
forvalues year_i = 2010(10)2050 {;
	levelsof CO2e_gen if fuel=="All" & year==`year_i';
		local CO2e_gen_`year_i' = `r(levels)';
	levelsof Emissions_CO2_FFI_IND if fuel=="All" & year==`year_i';
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
	replace CO2e_gen = FE_Industry * `EF_electricity_`year_i''
		if fuel=="Electricity" & year==`year_i';
	};
replace CO2e_adj = CO2e_gen if fuel=="Electricity";

/* Use integrated counting method, add electricity emissions to total emissions */
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

rename FE_Industry FE_Industry_Base;
rename GDP_MER GDP_MER_Base; 
rename GDP_PPP GDP_PPP_Base;
rename Emissions_CO2_FFI_IND CO2_Ind_Base;
rename CO2e_gen CO2e_gen_Base;
rename CO2e_adj CO2e_adj_Base;
rename scale_factor scale_factor_Base;

save subset/`md’_`rg’_Base_Ind,replace;
clear;
