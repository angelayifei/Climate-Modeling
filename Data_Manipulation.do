#delimit ;
clear all;

/*****************************************************************************************************************************/
/**************************************  Experiment data from one model and one region  **************************************/ 
/**************************************** (Here we extract China data from GCAM model) ***************************************/

local models 
"DNE21
GCAM
IMACLIM
IMAGE
MESSAGE
POLES
REMIND"
;

local regions
"China
EU
India
USA
World"
;

/* Subset Data for a specific model and region; keep only year between 2010 and 2050*/
foreach md of local models{;
	foreach rg of local regions{;

		use data_550;
		keep if region=="`rg'" & model=="`md'" & (year>=2010 & year<=2050);
		save subset/`md'_`rg'_550.dta, replace;
		clear;

		use data_Base;
		keep if region=="`rg'" & model=="`md'" & (year>=2010 & year<=2050);
		save subset/`md'_`rg'_Base.dta, replace;
		clear;

		/* Create power sector subsets of data */
		do Power_Subset `md' `rg';
		clear;

		do Trans_Subset `md' `rg';
		clear;

		/*do experiment_Bld_Subset;
		clear;

		do experiment_Ind_Subset;
		clear; */

		do Trans_Decompose `md' `rg';
		clear;

		};
};

/* Combine all outputs in the transport sector */
cd "S:\energy\Research\Energy Forecasts Evaluation Project\Climate Policy Modeling\AMPERE\Stata programming\Trans_outputs";
! dir *.dta /a-d /b > filelist.txt;

file open myfile using filelist.txt, read;

file read myfile line;
while r(eof)==0 {; /* while you're not at the end of the file */
	append using `line';
	file read myfile line;
};
file close myfile;
order model region fuel year;
save All_Trans_Outputs_data, replace;
