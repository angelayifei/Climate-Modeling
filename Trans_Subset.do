#delimit ;
clear all;

/****************************************************************************************************************/
/********************************  Subset Transport sector data under 550 scenario  ****************************/
/***************************************************************************************************************/
local scenarios "550 Base";
foreach s of local scenarios {;
use subset/`1'_`2'_`s'.dta;

/* If the dataset is empty, save and exit the dataset, read next line*/
count;
if r(N)==0 {;
	save subset/`1'_`2'_`s'_Trans, replace;
	clear all;
	};
	else {;

keep model fuel year region FE_Transport FE_Transport_Freight FE_Transport_Passenger 
	 ES_Transport_Freight ES_Transport_Passenger Emissions_CO2_FFI_TRAN;

/* keep only secondary energy sources which are relevant in end use sectors*/
keep if fuel=="All" | fuel=="Electricity" | fuel=="Gases" | fuel=="Heat" | fuel=="Liquids" | fuel=="Hydrogen" 
		|fuel=="Liquids Biomass" | fuel=="Liquids Coal" | fuel=="Liquids Oil" | fuel=="Other";
/* Solids fuels also zero values for all countires and all models, so drop here*/

save subset/`1'_`2'_`s'_Trans,replace;
clear;


/***************************** Find emission factors by fuel in transport sector**********************************/
/* Emission factors are calculated from IEA's WEO2013 data. 
(See "IEA Emission Factors.xlsx") document under AMPERE folder */

use Emission_Factors.dta;


/* IEA provides emissions from transport for oil, while not for coal and gas.
Therefore, oil emission factors are derived from dividing transport emissions by oil inputs into transport;
whereas for coal and gas, emission factors are derived from dividing total emissions from TFC by total inputs into TFC. */
forvalues year_i = 2010(10)2030 {;
	levelsof EF_PI_Trans if scenario=="NPS" & region=="`2'" & fuel=="Oil" & year==`year_i';
		local EF_Oil_Trans_`year_i'=`r(levels)';
	levelsof EF_PI_TFC if scenario=="NPS" & region=="`2'" & fuel=="Gas" & year==`year_i';
		local EF_Gas_TFC_`year_i'=`r(levels)';
	levelsof EF_PI_TFC if scenario=="NPS" & region=="`2'" & fuel=="Coal" & year==`year_i';
		local EF_Coal_TFC_`year_i'=`r(levels)';
};

/* Emission factor for biofuels is about 65.9 (MtCO2e/EJ)
Data source: the Climate Registry
http://www.theclimateregistry.org/downloads/2014/04/2014-Climate-Registry-Default-Emissions-Factors.pdf
This factor is calculated based on the assumption that ethanol and biodiesel account for 80% and 20% of total biofuels.  
However, biofuels don't belong to the fossil fuel category. So here we assume the emission factor to be zero*/
local EF_Biofuels = 0;

clear;

/* Find electricity emission factors */
use subset/`1'_`2'_`s'_POWER.dta;
forvalues year_i = 2010(10)2050 {;
	levelsof CO2_Power_`s' if fuel=="All" & year==`year_i';
		local CO2_Power_`year_i'=`r(levels)';
	levelsof SE_Electricity_`s' if fuel=="All" & year==`year_i';
		local PowerGen_`year_i'=`r(levels)';
	local EF_electricity_`year_i' = `CO2_Power_`year_i'' / `PowerGen_`year_i'';
	};

clear;
/****************************** Calculate emissions by fuel in the transport sector ***********************************/
use subset/`1'_`2'_`s'_Trans;

gen CO2e_gen=0;

/* Assume "hydrogen" and "other" fuels have zero emission factors */
forvalues year_i = 2010(10)2030 {;

	replace CO2e_gen = FE_Transport * `EF_Oil_Trans_`year_i'' 
		if (fuel=="Liquids Oil" | fuel=="Liquids Coal") & year==`year_i'; 
		/* assume CTL emission factors are the same as crude oil */
	replace CO2e_gen = FE_Transport * `EF_Biofuels' 
		if fuel=="Liquids Biomass" & year==`year_i';
	replace CO2e_gen = FE_Transport * `EF_Gas_TFC_`year_i'' 
		if fuel=="Gases" & year==`year_i';
	replace CO2e_gen = FE_Transport * `EF_Coal_TFC_`year_i'' 
		if fuel=="Other" & year==`year_i'; 
		/* It is guessed that coal powered transportation is grouped into "other" category" */
	}; 
 forvalues year_i = 2040(10)2050 {;
	replace CO2e_gen = FE_Transport * `EF_Oil_Trans_2030' 
		if (fuel=="Liquids Oil" | fuel=="Liquids Coal") & year==`year_i'; /* assume CTL emission factors are the same as crude oil */
	replace CO2e_gen = FE_Transport * `EF_Biofuels' 
		if fuel=="Liquids Biomass" & year==`year_i';
	replace CO2e_gen = FE_Transport * `EF_Gas_TFC_2030' 
		if fuel=="Gases" & year==`year_i';
	replace CO2e_gen = FE_Transport * `EF_Coal_TFC_2030'
		if fuel=="Other" & year==`year_i'; 
	}; 

replace CO2e_gen = 0 if CO2e_gen==.;

/* Calculate total liquids fuel emissions */
forvalues year_i = 2010(10)2050 {;
	levelsof CO2e_gen if fuel=="Liquids Oil" & year==`year_i';
		local CO2_Oil_`year_i' = `r(levels)';
	levelsof CO2e_gen if fuel=="Liquids Coal" & year==`year_i';
		local CO2_CTL_`year_i' = `r(levels)';
	levelsof CO2e_gen if fuel=="Liquids Biomass" & year==`year_i';
		local CO2_Biofuels_`year_i' = `r(levels)';
	
	replace CO2e_gen = `CO2_Oil_`year_i'' + `CO2_CTL_`year_i'' + `CO2_Biofuels_`year_i''
		if fuel=="Liquids" & year==`year_i';
	};

/* Some models don't produce results for biofuels, CTL and oil, and only produce results for "liquids" category.
In such cases, assume liquids emission factors are the same as crude oil. */
forvalues year_i = 2010(10)2030 {;
	replace CO2e_gen = FE_Transport * `EF_Oil_Trans_`year_i'' 
		if fuel=="Liquids" & year==`year_i' & CO2e_gen==0; 
	};
forvalues year_i = 2040(10)2050 {;
	replace CO2e_gen = FE_Transport * `EF_Oil_Trans_2030' 
		if fuel=="Liquids" & year==`year_i' & CO2e_gen==0; 
	};
	
/* Calculate total emissions in Transport Sector from fossil fuels */
forvalues year_i = 2010(10)2050 {;
	levelsof CO2e_gen if fuel=="Gases" & year==`year_i';
		local CO2_Gases_`year_i' = `r(levels)';
	levelsof CO2e_gen if fuel=="Liquids" & year==`year_i';
		local CO2_Liquids_`year_i' = `r(levels)';
	levelsof CO2e_gen if fuel=="Other" & year==`year_i';
		local CO2_Other_`year_i' = `r(levels)';
	
	if `CO2_Oil_`year_i''==0 {;
		replace CO2e_gen = `CO2_Liquids_`year_i'' + `CO2_Gases_`year_i'' + `CO2_Other_`year_i''
			if fuel=="All" & year==`year_i'; 
			};
		else {;
		/* This step corrects calculation for those models that don't have specific liquids fuel (CTL, biofuels, oil) data */
	replace CO2e_gen = `CO2_Oil_`year_i'' + `CO2_CTL_`year_i'' + `CO2_Gases_`year_i'' + `CO2_Other_`year_i''
		if fuel=="All" & year==`year_i'; 
		};
		/* Note that emissions from biofuels are not counted as fossil fuels emissions */
	
	};

/* Compare calculated total CO2 with the data in the original dataset */
forvalues year_i = 2010(10)2050 {;
	levelsof CO2e_gen if fuel=="All" & year==`year_i';
		local CO2e_gen_`year_i' = `r(levels)';
	levelsof Emissions_CO2_FFI_TRAN if fuel=="All" & year==`year_i';
		local CO2e_org_`year_i' = `r(levels)';
	local scale_factor_`year_i' = `CO2e_org_`year_i'' / `CO2e_gen_`year_i'';
};

/* Adjust CO2 by fuel with scale_factor of each year */
gen CO2e_adj = 0;

forvalues year_i = 2010(10)2050 {;
	replace CO2e_adj = CO2e_gen * `scale_factor_`year_i'' if year==`year_i';
	};

gen scale_factor = 0;
replace scale_factor = CO2e_adj / CO2e_gen if fuel=="All" & CO2e_gen!=0;

/* Calculate electricity emissions by applying emission factors derived from power sector data */
forvalues year_i = 2010(10)2050 {;
	replace CO2e_gen = FE_Transport * `EF_electricity_`year_i''
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

rename FE_Transport FE_Trans_`s';
rename FE_Transport_Freight FE_Trans_Freight_`s';
rename FE_Transport_Passenger FE_Trans_Passenger_`s';
rename ES_Transport_Freight ES_Trans_Freight_`s'; 
rename ES_Transport_Passenger ES_Trans_Passenger_`s';
rename Emissions_CO2_FFI_TRAN CO2_Trans_`s';
rename CO2e_gen CO2e_gen_`s';
rename CO2e_adj CO2e_adj_`s';
rename scale_factor scale_factor_`s';

save subset/`1'_`2'_`s'_Trans,replace;
clear;
};
