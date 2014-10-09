// This do-file takes seven arguments as shown below:
//
//    do Data_Processing SourceData
//                       VariablesFile
//                       YearStart
//                       YearIncrement
//                       UniqueVariables
//                       RegionOverride
//                       VariableNameOverride
//
// For example, with "EIA_Intl_Liquids.dta" as the source data (the .dta
// extension is added automatically), "EIA_Data_Variables.csv" as the variables
// file (the .csv extension is added automatically), a starting date of 2009, a
// year increment of 1, 9 unique variables (this includes any variables
// that are "BLANK"), and no overrides (use "None"), then the command would be:
//
//    do Process_Data EIA_Oil Data_EIA_Variables 2009 1 9 None None
//
// Note: if the starting date is given as "1", then the years are taken from
// the first row in the source data file; this first row is then deleted before
// the rest of the data are processed.
//
// Note: the region and variable name overrides allow whatever is in those
// respective columns to be overridden with the given arguments; this is
// useful where one variables file suits multiple source data tables except
// for variations in region and/or variable name (each source data file must
// have only a single unique variable name with no blank rows).

// Read in the source data file; this file contains the actual data values
use `1'.dta

// Record the total number of year for later processing (it is assumed that
// the input dataset is structured so that years are columns); describe must
// be called before r(k) has the correct value
describe
local totalYears = `r(k)'

// If the year-start argument (the third argument passed to this do-file) is
// equal to 1, then the years are contained in the first row of data; write
// these years to a .txt file for use in later processing, then remove the
// row from the data
if `3' == 1 {
	// Open a .txt file
	file open yearsFile using "`1'_Years.txt", write replace text

	// Loop through the years, writing each one to the .txt file
	forvalues currentYear = 1/`totalYears' {
		file write yearsFile "`=var`currentYear'[1]'" _n
	}
	
	// Close the file
	file close yearsFile
	
	// Delete the first row of data
	drop if _n == 1
}

// Declare a file handle
tempname myFile

// Open a temporary .csv file to store the matrix of data as a single column
file open myFile using "Temp_Data.csv", write replace text

// Record the total number of observations for later processing
local totalObs = _N

// Loop through all of the values in the data, writing each column below the
// previous one in the output .csv file
forvalues col = 1/`totalYears' {
	forvalues row = 1/`totalObs' {
		// Write the value
		file write myFile "`=var`col'[`row']'"
		
		// Output a newline character only if this isn't the last line
		if !(`col' == `totalYears' & `row' == `totalObs') {
			file write myFile _n
		}
	}
}

// Close the .csv output file
file close myFile

// Clear the current data from memory
clear

// Read in the .csv file that was just created above
insheet using Temp_Data.csv

// This .csv file has one column (variable) of data with the variable name
// "v1"; rename it to "values" for clarity
rename v1 values

// Save the data in .dta format, replacing any previous file if present
save Temp_Data.dta, replace

// Clear this data from memory
clear

// Read in the .csv file containing the source, table, vintage, scenario,
// region, energy type, units, and variable name information
insheet using `2'.csv, names


// If a region override was provided, replace all observations for "region"
// with the given argument
if "`6'" != "None" replace region = "`6'"

// If a variable name override was provided, replace all observations for
// "variable_name" with the given argument
if "`7'" != "None" replace variable_name = "`7'"

// Tabulate the unique values in the "variable_name"; create a new column for
// each one using the naming convention "var_holder*"
tabulate variable_name, generate(var_holder)

// Save this data with the tabulated columns into a new .csv file
save `2'_Tabulate.csv, replace

// Clear this data from memory
clear

// Consecutively call -append- to make copies of the variable names for each
// year in the dataset (note: didn't use -expand- here because original
// ordering is not preserved; using append ensures consistent ordering within
// each set of years)
forvalues i = 1/`totalYears' {
	append using `2'_Tabulate.csv
}

// These commands fill out the "year" variable with the appropriate year
// values
if `3' == 1 file open yearsFile using "`1'_Years.txt", read text
forvalues i = 1/`totalYears' {
	// If the year-start argument is equal to 1, use the years written
	// previously to the years .txt file
	if `3' == 1 {
		file read yearsFile yearValue 
	}
	// Otherwise, generate the years based on the year start and year increment
	// arguments
	else {
		local yearValue = `3' + ((`i' - 1) * `4')
	}
	local startRange = 1 + `totalObs'*(`i'-1)
	local endRange = `totalObs'*`i'
	replace year = `yearValue' in `startRange'/`endRange'
}
if `3' == 1 file close yearsFile

// Merge the values into the current dataset using the observation number as
// the key; because the data values are in a single column organized by sets
// of years, they should match the current dataset without any manipulation
merge 1:1 _n using Temp_Data.dta

// Drop the "_merge" variable created by the call to -merge-; the assumption
// is that there was a perfect match based on an equal number of observations
// in each dataset
drop _merge

// Copy the data values from the "values" column to the correct variables
// indicated by the numbers (either 1 or 0) in the "var_holder*" columns; at
// the same time, rename the "var_holder*" columns with their real names
forvalues i = 1/`5' {
	replace var_holder`i' = . if var_holder`i' == 0
	replace var_holder`i' = values if var_holder`i' == 1
	
	// These commands extract the correct variable name from the variable
	// label and then rename the variable using the correct name; more
	// specifically, -tabulate- will create variables var_holder1, var_holder2,
	// and so on, with labels that look like this:
	//
	//     variable_name==Consumption
	//     variable_name==Production
	//
	// These commands extract the text after "==" and use it to replace the
	// temporary var_holder* name
	local nameLoc = strpos("`:var lab var_holder`i''","==") + 2
	local strLength = length("`:var lab var_holder`i''")
	local nameLength = `strLength' - `nameLoc' + 1
	local variableName = substr("`:var lab var_holder`i''", `nameLoc', `nameLength')
	rename var_holder`i' `variableName'
	label variable `variableName' "`variableName'"
}
//

// Drop the "values" variable because it is no longer needed
drop values 

// Remove all observations where the variable name is "BLANK"
drop if variable_name == "BLANK"

// Remove the "variable_name" column
drop variable_name

// Remove the "BLANK" column; capture any error if there is no "BLANK" column
capture drop BLANK

// Delete these files because they are no longer needed
capture erase "`1'_Years.txt"
erase "Temp_Data.csv"
erase "Temp_Data.dta"
erase "`2'_Tabulate.csv"
