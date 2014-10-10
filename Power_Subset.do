#delimit ;
clear all;


/********************************************************************************************************************/
/********************************  Subset Power sector data under 550 & Base scenario  ******************************/
/********************************************************************************************************************/
local scenarios "550 Base";

use subset/`1'_`2'_`s'.dta;

/* If the dataset is empty, save and exit the dataset, read next line*/
count;
if r(N)==0 {;
	save subset/`1'_`2'_`s'_Power.dta, replace;
	clear all;
	};

else {;

keep model fuel year region PE_Electricity SE_Electricity Emissions_CO2_FFI_POWER;

/* drop secondary energy sources because they are irrelevant in power generation */
drop if fuel=="Electricity" | fuel=="Gases" | fuel=="Heat" | fuel=="Liquids" 
		|fuel=="Liquids Biomass" | fuel=="Liquids Coal" | fuel=="Liquids Oil" | fuel=="Hydrogen" 
		|fuel=="Solids" | fuel=="Solids Biomass" | fuel=="Solids Biomass (Traditional)" | 
		|fuel=="Solids Coal" | fuel=="Space Heating";

save subset/`1'_`2'_`s'_Power,replace;
clear;


/***************************** Find emission factors by fuel for power sector**********************************/
/* Emission factors are calculated from IEA's WEO2013 data. 
(See "IEA Emission Factors.xlsx") document under AMPERE folder */

use Emission_Factors.dta;

/* If primary inputs data are available, use emission factors that applicable to primary inputs;
If not, use emission factors applicable for electricity generated */

local fuels "Coal Oil Gas";
forvalues year_i = 2010(10)2030 {;
	foreach x of local fuels {;
		levelsof EF_PI_PowGen if scenario=="NPS" & region=="`2'" & fuel=="`x'" & year==`year_i';
			local EF_`x'_PI_`year_i'=`r(levels)';
		levelsof EF_PowGen if scenario=="NPS" & region=="`2'" & fuel=="`x'" & year==`year_i';
			local EF_`x'_PowGen_`year_i'=`r(levels)';
		};
	};

clear;


/****************************** Calculate emissions by fuel in the power sector ***********************************/
use subset/`1'_`2'_`s'_Power;

gen CO2e_gen=0;

/* Apply emission factors to corresponding fuels. Coal and Gas have primary input data, while oil doesn't.
 Assume CCS captures 85% of CO2 generated. */
local CCS_Factor = 0.15;

local fuel2 "Coal Gas";
forvalues year_i = 2010(10)2050 {;
	foreach x of local fuel2{;
		levelsof SE_Electricity if fuel=="`x'" & year==`year_i', miss local (ElecGen_`x'_`year_i');
		levelsof SE_Electricity if fuel=="`x' w/ CCS" & year==`year_i', miss local (ElecGen_`x'_wCCS_`year_i');
		levelsof SE_Electricity if fuel=="`x' w/o CCS" & year==`year_i', miss local (ElecGen_`x'_woCCS_`year_i');
		
		if `ElecGen_`x'_`year_i'' !=. {;
				local Share_`x'_wCCS_`year_i' = `ElecGen_`x'_wCCS_`year_i'' / `ElecGen_`x'_`year_i'';
				local Share_`x'_woCCS_`year_i' = `ElecGen_`x'_woCCS_`year_i'' / `ElecGen_`x'_`year_i'';
				};
			else {;
				local Share_`x'_wCCS_`year_i' = . ;
				local Share_`x'_woCCS_`year_i' = . ;
			};
		};
	};
		

forvalues year_i = 2010(10)2030 {;
	foreach x of local fuel2 {;
		levelsof PE_Electricity if fuel=="`x'" & year==`year_i', miss local (PI_`x'_`year_i');
		replace CO2e_gen = `PI_`x'_`year_i'' * `Share_`x'_wCCS_`year_i'' * `EF_`x'_PI_`year_i'' * `CCS_Factor'
			if fuel=="`x' w/ CCS" & year==`year_i';
		replace CO2e_gen = `PI_`x'_`year_i'' * `Share_`x'_woCCS_`year_i'' * `EF_`x'_PI_`year_i''
			if fuel=="`x' w/o CCS" & year==`year_i';
	};
	
	replace CO2e_gen = SE_Electricity * `EF_Oil_PowGen_`year_i'' * `CCS_Factor'
		if fuel=="Oil w/ CCS" & year==`year_i';
	replace CO2e_gen = SE_Electricity * `EF_Oil_PowGen_`year_i''
		if fuel=="Oil w/o CCS" & year==`year_i';
};

save subset/`1'_`2'_`s'_Power.dta, replace;

/* for year>2030, assume the emission factors are the same as 2030 */
forvalues year_i = 2040(10)2050 {;
	foreach x of local fuel2 {;
		levelsof PE_Electricity if fuel=="`x'" & year==`year_i', miss local (PI_`x'_`year_i');
		replace CO2e_gen = `PI_`x'_`year_i'' * `Share_`x'_wCCS_`year_i'' * `EF_`x'_PI_2030' * `CCS_Factor'
			if fuel=="`x' w/ CCS" & year==`year_i';
		replace CO2e_gen = `PI_`x'_`year_i'' * `Share_`x'_woCCS_`year_i'' * `EF_`x'_PI_2030'
			if fuel=="`x' w/o CCS" & year==`year_i';
	};
	
	replace CO2e_gen = SE_Electricity * `EF_Oil_PowGen_2030' * `CCS_Factor'
		if fuel=="Oil w/ CCS" & year==`year_i';
	replace CO2e_gen = SE_Electricity * `EF_Oil_PowGen_2030'
		if fuel=="Oil w/o CCS" & year==`year_i';
};

save subset/`1'_`2'_`s'_Power,replace;

/* Calculate total emissions for coal, oil and gas */
forvalues year_i = 2010(10)2050 {;
	foreach x of local fuels {;
		levelsof CO2e_gen if fuel=="`x' w/ CCS" & year==`year_i', miss local (CO2_`x'_wCCS_`year_i');
		levelsof CO2e_gen if fuel=="`x' w/o CCS" & year==`year_i', miss local (CO2_`x'_woCCS_`year_i');
		
		local CO2_`x'_`year_i' = `CO2_`x'_wCCS_`year_i'' + `CO2_`x'_woCCS_`year_i'';
		replace CO2e_gen = `CO2_`x'_`year_i'' if fuel=="`x'" & year==`year_i';
		};
	};

forvalues year_i = 2010(10)2050 {;
	replace CO2e_gen = `CO2_Coal_`year_i'' + `CO2_Gas_`year_i'' + `CO2_Oil_`year_i''
		if fuel=="All" & year==`year_i';
	};
	
save subset/`1'_`2'_`s'_Power,replace;

/* Adjust emission based on calculated total results with original results */
gen CO2e_adj =.;

forvalues year_i = 2010(10)2050 {;
	levelsof CO2e_gen if fuel=="All" & year==`year_i', miss local (CO2gen_`year_i');
	levelsof Emissions_CO2_FFI_POWER if fuel=="All" & year==`year_i', miss local (CO2org_`year_i');
	
	if `CO2gen_`year_i''!=. & `CO2gen_`year_i''!=0 {;
		local scale_factor_`year_i' = `CO2org_`year_i'' / `CO2gen_`year_i'';
		};
		else {;
			local scale_factor_`year_i'=0;
			};
	
	replace CO2e_adj = CO2e_gen * `scale_factor_`year_i'' if year==`year_i';
};

gen scale_factor =.;
replace scale_factor = CO2e_adj / CO2e_gen if CO2e_gen!=. & fuel=="All";
	
rename PE_Electricity PE_Electricity_`s';
rename SE_Electricity SE_Electricity_`s';
rename Emissions_CO2_FFI_POWER CO2_Power_`s';
rename CO2e_gen CO2e_gen_`s';
rename CO2e_adj CO2e_adj_`s';
rename scale_factor scale_factor_`s';

save subset/`1'_`2'_`s'_Power,replace;
clear;


};
