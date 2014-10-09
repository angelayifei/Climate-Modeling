#delimit ;

do process_data AMPERE_Data Data_Temp 1 1 31 None None;

collapse (firstnm)
Population
GDP_MER
GDP_PPP
PE
PE_Electricity
SE
SE_Electricity
SE_Liquids
SE_Gases
SE_Solids
SE_Heat
SE_Hydrogen
FE
FE_Industry
FE_Building
FE_Other
FE_Transport
FE_Transport_Freight
FE_Transport_Passenger
ES_Transport_Freight
ES_Transport_Passenger
Emissions_CO2
Emissions_CO2_FFI
Emissions_CO2_FFI_ES
Emissions_CO2_FFI_POWER
Emissions_CO2_FFI_ED
Emissions_CO2_FFI_IND
Emissions_CO2_FFI_BLD
Emissions_CO2_FFI_TRAN
Emissions_CO2_FFI_OTHER
Emissions_CO2_CCS
,
by (model_scenario model project climate_scenario tech_scenario tech_diffusion region fuel year);

order model_scenario model project climate_scenario tech_scenario tech_diffusion region fuel year, first;

save data_Imported.dta, replace;
clear;


