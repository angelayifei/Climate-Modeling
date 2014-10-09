#delimit ;
clear all;


/*****************************************************************************************************************/
/********************************  Subset Power sector data under 550 scenario  ******************************/
/***************************************************************************************************************/
use subset/`1'_`2'_550.dta;

/* If the dataset is empty, save and exit the dataset, read next line*/
count;
if r(N)==0 {;
	save subset/`1'_`2'_550_Power.dta, replace;
	clear all;
	};
	else {;

keep model fuel year region PE_Electricity SE_Electricity Emissions_CO2_FFI_POWER;

/* drop secondary energy sources because they are irrelevant in power generation */
drop if fuel=="Electricity" | fuel=="Gases" | fuel=="Heat" | fuel=="Liquids" 
		|fuel=="Liquids Biomass" | fuel=="Liquids Coal" | fuel=="Liquids Oil" | fuel=="Hydrogen" 
		|fuel=="Solids" | fuel=="Solids Biomass" | fuel=="Solids Biomass (Traditional)" | 
		|fuel=="Solids Coal" | fuel=="Space Heating";

save subset/`1'_`2'_550_Power,replace;
clear;


/***************************** Find emission factors by fuel for power sector**********************************/
/* Emission factors are calculated from IEA's WEO2013 data. 
(See "IEA Emission Factors.xlsx") document under AMPERE folder */

use Emission_Factors.dta;

/* If primary inputs data are available, use emission factors for primary inputs;
If not, use emission factors for each unit of electricity generated */

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
use subset/`1'_`2'_550_Power;

gen CO2e_gen=0;

/* Apply emission factors to corresponding fuels. Assume CCS captures 85% of CO2 generated. */

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
		
/* Coal and Gas have primary input data, while oil doesn't. */
forvalues year_i = 2010(10)2030 {;
	levelsof PE_Electricity if fuel=="Coal" & year==`year_i', miss local (PI_Coal_`year_i');
	levelsof PE_Electricity if fuel=="Gas" & year==`year_i', miss local (PI_Gas_`year_i');
	
	replace CO2e_gen = `PI_Coal_`year_i'' * `Share_Coal_wCCS_`year_i'' * `EF_Coal_PI_`year_i'' * 0.15
		if fuel=="Coal w/ CCS" & year==`year_i';
	replace CO2e_gen = `PI_Coal_`year_i'' * `Share_Coal_woCCS_`year_i'' * `EF_Coal_PI_`year_i''
		if fuel=="Coal w/o CCS" & year==`year_i';
	
	if `Share_Gas_wCCS_`year_i'' != . {;
	replace CO2e_gen = `PI_Gas_`year_i'' * `Share_Gas_wCCS_`year_i'' * `EF_Gas_PI_`year_i'' * 0.15
		if fuel=="Gas w/ CCS" & year==`year_i';
	replace CO2e_gen = `PI_Gas_`year_i'' * `Share_Gas_woCCS_`year_i'' * `EF_Gas_PI_`year_i''
		if fuel=="Gas w/o CCS" & year==`year_i';
		};
	
	replace CO2e_gen = SE_Electricity * `EF_Oil_PowGen_`year_i'' * 0.15
		if fuel=="Oil w/ CCS" & year==`year_i';
	replace CO2e_gen = SE_Electricity * `EF_Oil_PowGen_`year_i''
		if fuel=="Oil w/o CCS" & year==`year_i';
};

save subset/`1'_`2'_550_Power.dta, replace;

/* for year>2030, assume the emission factors are the same as 2030 */
forvalues year_i = 2040(10)2050 {;
	levelsof PE_Electricity if fuel=="Coal" & year==`year_i', miss local (PI_Coal_`year_i');
	levelsof PE_Electricity if fuel=="Gas" & year==`year_i', miss local (PI_Gas_`year_i');
	
	replace CO2e_gen = `PI_Coal_`year_i'' * `Share_Coal_wCCS_`year_i'' * `EF_Coal_PI_2030' * 0.15
		if fuel=="Coal w/ CCS" & year==`year_i';
	replace CO2e_gen = `PI_Coal_`year_i'' * `Share_Coal_woCCS_`year_i'' * `EF_Coal_PI_2030'
		if fuel=="Coal w/o CCS" & year==`year_i';
	
	if `Share_Gas_wCCS_`year_i'' != . {;
	replace CO2e_gen = `PI_Gas_`year_i'' * `Share_Gas_wCCS_`year_i'' * `EF_Gas_PI_2030' * 0.15
		if fuel=="Gas w/ CCS" & year==`year_i';
	replace CO2e_gen = `PI_Gas_`year_i'' * `Share_Gas_woCCS_`year_i'' * `EF_Gas_PI_2030'
		if fuel=="Gas w/o CCS" & year==`year_i';
		};
	
	replace CO2e_gen = SE_Electricity * `EF_Oil_PowGen_2030' * 0.15
		if fuel=="Oil w/ CCS" & year==`year_i';
	replace CO2e_gen = SE_Electricity * `EF_Oil_PowGen_2030'
		if fuel=="Oil w/o CCS" & year==`year_i';
};

save subset/`1'_`2'_550_Power,replace;

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
save subset/`1'_`2'_550_Power,replace;	
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
	
rename PE_Electricity PE_Electricity_550;
rename SE_Electricity SE_Electricity_550;
rename Emissions_CO2_FFI_POWER CO2_Power_550;
rename CO2e_gen CO2e_gen_550;
rename CO2e_adj CO2e_adj_550;
rename scale_factor scale_factor_550;

save subset/`1'_`2'_550_Power,replace;
clear;

/*****************************************************************************************************************/
/********************************  Subset Power sector data under Base scenario  ******************************/
/***************************************************************************************************************/
use subset/`1'_`2'_Base.dta;

keep model fuel year region PE_Electricity SE_Electricity Emissions_CO2_FFI_POWER;

/* drop secondary energy sources because they are irrelevant in power generation */
drop if fuel=="Electricity" | fuel=="Gases" | fuel=="Heat" | fuel=="Liquids" 
		|fuel=="Liquids Biomass" | fuel=="Liquids Coal" | fuel=="Liquids Oil" | fuel=="Hydrogen" 
		|fuel=="Solids" | fuel=="Solids Biomass" | fuel=="Solids Biomass (Traditional)" | 
		|fuel=="Solids Coal" | fuel=="Space Heating";

save subset/`1'_`2'_Base_Power,replace;
clear;


/***************************** Find emission factors by fuel for power sector**********************************/
/* Emission factors are calculated from IEA's WEO2013 data. 
(See "IEA Emission Factors.xlsx") document under AMPERE folder */

use Emission_Factors.dta;

/* If primary inputs data are available, use emission factors for primary inputs;
If not, use emission factors for each unit of electricity generated */

local fuels "Coal Oil Gas";
forvalues year_i = 2010(10)2030 {;
	foreach x of local fuels {;
		levelsof EF_PI_PowGen if scenario=="CPS" & region=="`2'" & fuel=="`x'" & year==`year_i';
			local EF_`x'_PI_`year_i'=`r(levels)';
		levelsof EF_PowGen if scenario=="CPS" & region=="`2'" & fuel=="`x'" & year==`year_i';
			local EF_`x'_PowGen_`year_i'=`r(levels)';
		};
	};

clear;


/****************************** Calculate emissions by fuel in the power sector ***********************************/
use subset/`1'_`2'_Base_Power;

gen CO2e_gen=0;

/* Apply emission factors to corresponding fuels. Assume CCS captures 85% of CO2 generated. */

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
		
/* Coal and Gas have primary input data, while oil doesn't. */
forvalues year_i = 2010(10)2030 {;
	levelsof PE_Electricity if fuel=="Coal" & year==`year_i', miss local (PI_Coal_`year_i');
	levelsof PE_Electricity if fuel=="Gas" & year==`year_i', miss local (PI_Gas_`year_i');
	
	replace CO2e_gen = `PI_Coal_`year_i'' * `Share_Coal_wCCS_`year_i'' * `EF_Coal_PI_`year_i'' * 0.15
		if fuel=="Coal w/ CCS" & year==`year_i';
	replace CO2e_gen = `PI_Coal_`year_i'' * `Share_Coal_woCCS_`year_i'' * `EF_Coal_PI_`year_i''
		if fuel=="Coal w/o CCS" & year==`year_i';
	
	if `Share_Gas_wCCS_`year_i'' != . {;
	replace CO2e_gen = `PI_Gas_`year_i'' * `Share_Gas_wCCS_`year_i'' * `EF_Gas_PI_`year_i'' * 0.15
		if fuel=="Gas w/ CCS" & year==`year_i';
	replace CO2e_gen = `PI_Gas_`year_i'' * `Share_Gas_woCCS_`year_i'' * `EF_Gas_PI_`year_i''
		if fuel=="Gas w/o CCS" & year==`year_i';
		};
	
	replace CO2e_gen = SE_Electricity * `EF_Oil_PowGen_`year_i'' * 0.15
		if fuel=="Oil w/ CCS" & year==`year_i';
	replace CO2e_gen = SE_Electricity * `EF_Oil_PowGen_`year_i''
		if fuel=="Oil w/o CCS" & year==`year_i';
};

save subset/`1'_`2'_Base_Power.dta, replace;

/* for year>2030, assume the emission factors are the same as 2030 */
forvalues year_i = 2040(10)2050 {;
	levelsof PE_Electricity if fuel=="Coal" & year==`year_i', miss local (PI_Coal_`year_i');
	levelsof PE_Electricity if fuel=="Gas" & year==`year_i', miss local (PI_Gas_`year_i');
	
	replace CO2e_gen = `PI_Coal_`year_i'' * `Share_Coal_wCCS_`year_i'' * `EF_Coal_PI_2030' * 0.15
		if fuel=="Coal w/ CCS" & year==`year_i';
	replace CO2e_gen = `PI_Coal_`year_i'' * `Share_Coal_woCCS_`year_i'' * `EF_Coal_PI_2030'
		if fuel=="Coal w/o CCS" & year==`year_i';
	
	if `Share_Gas_wCCS_`year_i'' != . {;
	replace CO2e_gen = `PI_Gas_`year_i'' * `Share_Gas_wCCS_`year_i'' * `EF_Gas_PI_2030' * 0.15
		if fuel=="Gas w/ CCS" & year==`year_i';
	replace CO2e_gen = `PI_Gas_`year_i'' * `Share_Gas_woCCS_`year_i'' * `EF_Gas_PI_2030'
		if fuel=="Gas w/o CCS" & year==`year_i';
		};
	
	replace CO2e_gen = SE_Electricity * `EF_Oil_PowGen_2030' * 0.15
		if fuel=="Oil w/ CCS" & year==`year_i';
	replace CO2e_gen = SE_Electricity * `EF_Oil_PowGen_2030'
		if fuel=="Oil w/o CCS" & year==`year_i';
};

save subset/`1'_`2'_Base_Power,replace;

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
save subset/`1'_`2'_Base_Power,replace;	
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
	
rename PE_Electricity PE_Electricity_Base;
rename SE_Electricity SE_Electricity_Base;
rename Emissions_CO2_FFI_POWER CO2_Power_Base;
rename CO2e_gen CO2e_gen_Base;
rename CO2e_adj CO2e_adj_Base;
rename scale_factor scale_factor_Base;

save subset/`1'_`2'_Base_Power,replace;
clear;


};

