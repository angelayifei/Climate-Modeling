#delimit ;

//Import downloaded data and transform into manipulatable format
do Import_data;

//Save two subsets of the imported data: 550 Scenario and Base Scenario
use data_Imported.dta;
keep if climate_scenario=="550";
save data_550.dta, replace;

use data_Imported.dta;
keep if climate_scenario=="Base";
save data_Base.dta, replace;

clear all;

