*******************************************************************************************************************
********************************************BEGIN  HEADER******************************************************

/*Name of do-file: generate_ffx_labelled_dictionary.do*/

/*Purpose: 	
	(1) Generates a 'tidy' dictionary from 'untidy' csv files by 
		(a) Importing raw xls data files
		(b) Renaming variables for consistency with datasets
		(c) Generating new variables from the Multi-Select question types
	(2) Creates do file for labelling variables and values 
	*/
	
/*	input : xls data dictionaries
		
*/

/*	output : cleaned and labelled dictionary
			
*/

/*Authors: 	Hellen Awuoche
			Daniel Kwaro
			
*/

/*Contact Email: hawuoche@kemricdc.org*/

/*first version: 8th December 2017*/

/*last review/version: 29th December 2017*/

******************************************END HEADER**********************************************************
******************************************************************************************************************
set more off

//global macros
global workspace  "C:\HISS\Fisherfolk_workspace" //workspace
cd $workspace

global raw_metadata   "Fisherfolk_cleaning_project\Data\Raw_data\metadata" //input <--- raw datasets
global raw_data   "Fisherfolk_cleaning_project\Data\Raw_data\data" //input <--- raw datasets
global scripts          "Fisherfolk_cleaning_project\Data\code\stata\scripts" //input <-scripts for labelling datasets
global temp_data   "Fisherfolk_cleaning_project\Data\temp_data" //output--> cleaned datasets
global clean_data   "Fisherfolk_cleaning_project\Data\clean_data\metadata" //output--> cleaned datasets
global reports        "Fisherfolk_cleaning_project\Data\output" //output-->data quality report


******************************************************************************************************************
****************************************BEGIN SET UP************************************************************

// save log file
cap log using "LBBS_cleaning_project\output\logs\generate_labelled_dataset log.smcl", replace

//create handle for managing quality report
tempname fhandle

******************************************************************************************************************
****************************************END SET UP************************************************************

//CONVERSION OF VARIABLE NAMES
*=============================

//Append all dictionaries 
/*
import excel "${raw_data}\dictionary_ffx.xlsx", sheet("Households - Register Household") firstrow allstring clear
*save in temporary file
tempfile dict
sa "`dict'"

local extrasheets `""Households - Update Household" "Fisherfolk - Update Participant" "herfolk - Interview Participant" "dren Fisherfolk - Children Form" "Referrals - Followup Form""'

foreach sheet in `extrasheets'{

import excel "${raw_data}\dictionary_ffx.xlsx", sheet("`sheet'") firstrow allstring clear
append using "`dict'"
					
sa "`dict'" , replace
}
*
*save the raw dataset before any edits
sa "$raw_data\metadata\raw_ffx_dictionary", replace
*/


//Append all dictionaries 
**
import excel "${raw_metadata}\dictionary_ffx.xlsx", sheet("Households - Register Household") firstrow allstring clear
	generate source ="RegisterHousehold"
*save in temporary file
tempfile dict
sa "`dict'"

import excel "${raw_metadata}\dictionary_ffx.xlsx", sheet("Households - Update Household") firstrow allstring clear
append using "`dict'"
	replace source ="UpdateHousehold" if source == ""
*save  file
sa "`dict'", replace

import excel "${raw_metadata}\dictionary_ffx.xlsx", sheet("Fisherfolk - Update Participant") firstrow allstring clear
append using "`dict'"
	replace source ="UpdateParticipant" if source == ""
*save  file
sa "`dict'", replace


import excel "${raw_metadata}\dictionary_ffx.xlsx", sheet("herfolk - Interview Participant") firstrow allstring clear
append using "`dict'"
	replace source ="InterviewParticipant" if source == ""
*save  file
sa "`dict'", replace


import excel "${raw_metadata}\dictionary_ffx.xlsx", sheet("dren Fisherfolk - Children Form") firstrow allstring clear
append using "`dict'"
	replace source ="ChildrenForm" if source == ""
*save  file
sa "`dict'", replace


import excel "${raw_metadata}\dictionary_ffx.xlsx", sheet("Referrals - Followup Form") firstrow allstring clear
append using "`dict'"
	replace source ="FollowupForm" if source == ""
*save  file
sa "`dict'", replace

*save the raw dataset before any edits
sa "$raw_metadata\raw_ffx_dictionary", replace

//Convert prefix to the word "form."
replace question_id=regexr( question_id,"^/[a-z|0-9|_]*/","form.")
//Convert remaining "/" to "."
replace question_id=regexr( question_id,"/",".")

//rename variable names (question_id) where not sensible to stata
*replace question_id = subinstr(question_id, "form.child_summary_details_first_name_child_first_name__middle_name_child_middle","form.child_summary_details", .)

//check for duplicates i.e variables that have been assigned the same names
*duplicates report question_id
gen id = _n
so question_id
duplicates tag question_id, gen(dups)
br id question_id label source if dups

//rename variables that have the same names
replace question_id=regexr( question_id,"^form.","form.ch") if source == "ChildrenForm"
replace question_id = subinstr(question_id, "form.","form.update_", .) if inlist(id, 501, 517, 518, 519, 520, 521)
replace question_id = subinstr(question_id, "form.","form.fup_", .) if inlist(id, 1, 12)

drop id dups

//if type=MSelect, generate new variables by prefixing each option with current variable name followed by "|"
	*save in temporary file
		tempfile original  /*save original file*/
		save "`original'"

		keep if type=="MSelect" /*keep if multiple select question*/
		*keep question_id options /*keep only question id and options*/
		keep question_id label options type /*keep only question id, label options and type*/
		
//remove tabs in the options variable 
clonevar options1 = options 
	
// remove tab from question id and options1
replace question_id = subinstr(question_id, "`=char(10)'", " ", .)
replace options1 = subinstr(options1, "`=char(10)'", " ", .)

		
		split options1, p(-) gen(optionname) /*split option into multiple columns using "-" as a separator*/
		foreach var of varlist optionname*{
		replace `var'=regexr( `var',"[0-9]+","") /*remove number-prefixes  from option labels*/
		}
		*
		
		split options1, p(-) gen(optionvalue)
		foreach var of varlist optionvalue* {
		replace `var'=regexs(1) if regexm( `var',"(([0-9]+)[a-zA-Z]*)") /*remove string-suffixes  from option values*/
		}
		*

		//reshape dataset
		gen id=_n
		reshape long optionname optionvalue , i( id)
		bysort id (_j): replace optionvalue= optionvalue[_n+1] /*replace option value with successive value*/
		gen question_id2= question_id + "|" + optionvalue if !missing( optionvalue) /*create new variable name for multi-select questions*/
 
		 *drop unnecessary rows
		 drop if missing(question_id2)
		 
		 *drop uneccesary columns 
		 drop id _j
replace question_id=question_id2
drop question_id2

replace type="MSelect" 
 
merge  m:m question_id using "`original'", nogenerate
drop if type=="MSelect" & missing(optionvalue) //dropped original multiselect question

//Remove text between "|" and "-", as well as the "-"

// to fit with stata, replace ".", "" , "/" and "|" with empty string
replace question_id=regexr(question_id,"[(\|)(\.)]","")
replace question_id=regexr(question_id,"[(\|)(\.)]","")
replace question_id=regexr(question_id,"[(\|)(\.)]","")
replace question_id=regexr(question_id,"[(\/)(\.)]","")
replace question_id=regexr(question_id,"[(\/)(\.)]","")


// to fit with stata, convert to lower case
replace question_id=lower(question_id) //to fit with stata, convert to lower case

//duplicate the multiselect questions inorder to have two values for each option (0=no,1==yes)
expand 2 if type=="MSelect", gen(multiselectoptionvalues)

//save old values into a new variable
clonevar optionvalue_original=optionvalue

//replace option values with 0=no and 1=yes for multiselect questions
tostring multiselectoptionvalues, replace
replace optionvalue=multiselectoptionvalues if type=="MSelect"
drop multiselectoptionvalues

// save old values of optionname into a new variable for label definition

clonevar optionname_original = optionname

// create a copy of the label variable
clonevar var_label = label

//define values for multi-select variables
 replace var_label = optionname if type=="MSelect"
 
 replace  optionname = "yes" if type=="MSelect" & optionvalue == "1"
 replace  optionname = "no" if type=="MSelect" & optionvalue == "0"

//replace source in the new Mselect variables
replace source ="ChildrenForm" if regexm( question_id,"^formch") & source == ""
replace source ="InterviewParticipant" if source == ""


//define values for single select variables

**if type=Select, generate new variables by spliting each option 
		tempfile main  /*save main file*/
		save "`main'"
		
//keep only single select
 
keep if type=="Select"

//remove tabs in the options variable 
clonevar options2 = options 

*replace options2 = subinstr(options2, "`=char(10)'", " ", .)

local s `= char(10)'
split options2, p(`s') gen(selectoptionname) //use tab as a separator


//reshape dataset
gen id=_n
reshape long selectoptionname  , i( id) 

drop if missing(selectoptionname)

bysort id (_j): replace optionvalue= optionvalue[_n+1] /*replace option value with successive value*/
gen question_id2= question_id + "|" + optionvalue if !missing( optionvalue) /*create new variable name for multi-select questions*/

//extract the values from selectoptionname
replace selectoptionname=trim(selectoptionname)
gen selectoptionvalue=regexs(1) if regexm(selectoptionname, "-.([A-Z]?[0-9]+)$") 

//remove the suffix==optionname from the selectoptionname
replace selectoptionname=regexr(selectoptionname, "-.([A-Z]?[0-9]+)$","") 

replace selectoptionname=trim(selectoptionname)

//rename variables that have dulicate names from the register household and update household files to enable correct merging
*replace question_id = regexr(question_id, "formphysical_addressbeach","formupdate_physical_addressbeach") if source == "UpdateHousehold"
*replace question_id = regexr(question_id, "formhhd_consent","formupdatehhd_consent") if source == "UpdateHousehold"
replace question_id = subinstr(question_id, "form","formupdate_", .) if source == "UpdateHousehold"


//keep only relevant variables
keep question_id selectoptionname selectoptionvalue

//merge with the dictionary		
merge  m:m question_id using "`main'", nogenerate

//revert replaced variable names to original names
*replace question_id = regexr(question_id, "^formupdate_physical","formphysical")
replace question_id = subinstr(question_id, "update_","", .) if source == "UpdateHousehold"

//combine the optionnames and optionvalues
replace optionname= selectoptionname if missing( optionname)
replace optionvalue= selectoptionvalue if missing( optionvalue)
drop selectoptionname selectoptionvalue		

*gen labelvar="label variable" + question_id + " "

	replace optionname = subinstr(optionname, "  [____ ] ","", .)
	replace optionname = subinstr(optionname, " ……………………. ","", .)
	replace optionname = subinstr(optionname, " ……….. ","", .)
	replace optionname = subinstr(optionname, " ………………. ","", .)
	replace optionname = subinstr(optionname, "…………………..…… ","", .)
	replace optionname = subinstr(optionname, " …………………","", .)
	replace optionname = subinstr(optionname, "…………… ","", .)
	replace optionname = subinstr(optionname, "…………………………....... ","", .)
	replace optionname = subinstr(optionname, " ……… ","", .)
	replace optionname = subinstr(optionname, "……………………. ","", .)
	replace optionname = subinstr(optionname, ": ","", .)
	replace optionname = subinstr(optionname, ".. ","", .)
	replace optionname = subinstr(optionname, "() ","", .)
	replace optionname = subinstr(optionname, "(1) ","", .)
	replace optionname = subinstr(optionname, "(2) ","", .)
	replace optionname = subinstr(optionname, "(3) ","", .)
	replace optionname = subinstr(optionname, "(4) ","", .)
	replace optionname = subinstr(optionname, "D.","", .)
	replace optionname = subinstr(optionname, "A. ","", .)
	replace optionname = subinstr(optionname, "B.","", .)
	replace optionname = subinstr(optionname, "C","", .)
	replace optionname = subinstr(optionname, "E","", .)
	replace optionname = subinstr(optionname, "………...….","", .)
	
	replace var_label = subinstr(var_label, "[____]","", .)
	replace var_label = subinstr(var_label, "…………………….","", .)
	replace var_label = subinstr(var_label, "………..","", .)
	replace var_label = subinstr(var_label, "……………….","", .)
	replace var_label = subinstr(var_label, "………………","", .)
	replace var_label = subinstr(var_label, "……","", .)
	replace var_label = subinstr(var_label, "…","", .)
	replace var_label = subinstr(var_label, "......","", .)
	replace var_label = subinstr(var_label, ":","", .)
	replace var_label = subinstr(var_label, "..","", .)
	replace var_label = subinstr(var_label, "e.g.statusofmothernotknown,motherispositiveorchildisorphanedbydeathofmotheretc)","", .)

//drop variables that are instructions or prompts to the interveiwer
drop if  type=="Trigger" | type == "Repeat" 

drop if type=="FieldList" & missing(optionvalue) //dropp question if is type = fieldlist and missing option value

drop if type=="Group" & missing(optionvalue) //dropp question if is type = group and missing option value

drop if question_id == "formcalculate_welcome_msg"

// remove tabs from label
	replace label = subinstr(label, "`=char(10)'", " ", .) //remove tabs in label variable

//define values for single select variables

	replace var_label=trim(var_label)	//remove leading and trailing blanks in variable labels
	replace var_label = subinstr(var_label, "`=char(10)'", " ", .) //remove tab in variable labels
	replace var_label=regexr(var_label, "([A-Z]([0-9]+)[a-z]).","") /*remove the prefix for question no (A1a. etc) from the label*/
	replace var_label=regexr(var_label, "([A-Z][0-9]+).","") /*remove the prefix for question no (A1. etc) from the label*/
	replace var_label = subinstr(var_label, "`=char(063)'", " ", .)/*remove character "?"  from variable label*/
	
	/*remove unnecessary text from the variable label*/
	replace var_label = subinstr(var_label, "What is the", " ", .)
	replace var_label = subinstr(var_label, "   name of the beach/village where you came from ","where from", .)
	replace var_label = subinstr(var_label, "Did your","", .)
	replace var_label = subinstr(var_label, "Did you", " ", .)
	replace var_label = subinstr(var_label, "(____) to earn livelihood through fishing activities (or serving people engaged in fishing related activities) in the last 12 months (since this time last year)", " ", .)
	replace var_label = subinstr(var_label, "   move or travel from location   ", "moved from location", .)
	replace var_label = subinstr(var_label, "(____) to earn livelihood through fishing activities in the last 12 months", " ", .)
	replace var_label = subinstr(var_label, "How many", " ", .)
	replace var_label = subinstr(var_label, "   times did you move from location   ", "no of times moved from location", .)
	replace var_label = subinstr(var_label, "did your","", .)
	replace var_label = subinstr(var_label, "did you","", .)
	replace var_label = subinstr(var_label, "What is your", " ", .)
	replace var_label = subinstr(var_label, "   current relationship status ", "current relationship status ", .)
	replace var_label = subinstr(var_label, " Other (current) relationship status", "other relationship status ", .)
	replace var_label = subinstr(var_label, "Have you", " ", .)
	replace var_label = subinstr(var_label, "That is, did a spouse ever pass away while you were still married or living with them", " ", .)
	replace var_label = "inherited" if question_id == "forma16"
	replace var_label = subinstr(var_label, "had a change in your relationship status within the last 12 months ", "change in relationship status", .)
	replace var_label = subinstr(var_label, "have you had in the last 12 months", " ", .)
	replace var_label = subinstr(var_label, " Specify the change in relationship that you had ", "specify change in relationship status", .)
	replace var_label = subinstr(var_label, "   highest level of education you have attained ", "education level", .)
	replace var_label = "sex" if question_id == "forma1_sex"
	replace var_label = "age" if question_id == "forma2_age"
	replace var_label = subinstr(var_label, "How old were you at your last birthday", "age at last birthday", .)
	replace var_label = subinstr(var_label, " Specify those others (Bar owners, shopkeepers,hotel owners, charcoal dealers E.T.C)","specify other occupation", .)
	replace var_label = subinstr(var_label, " Where are you currently living ","current residence", .)
	replace var_label = subinstr(var_label, " How long have you been living in ____ ","length of stay in location", .)
	replace var_label = subinstr(var_label, " Duration of stay in months ____  ","length stay in months", .)
	replace var_label = subinstr(var_label, " Where  live before coming to ____ (your current residence) ","where lived before", .)
	replace var_label = subinstr(var_label, "How old is ____","participant age", .)
	replace var_label = subinstr(var_label, "Is age of ____ recorded in Months (for minors below two years) ","age in months", .)
	replace var_label = "age in years" if question_id == "formage_years"
	replace var_label = subinstr(var_label, "Is ____ allergic to AL","child allergic to AL", .)
	replace var_label = subinstr(var_label, "Are you allergic to AL ","allergic to AL", .)
	replace var_label = subinstr(var_label, "Last visit ____  was ____  ; Is ____ now at home","member now at home", .)
	replace var_label = "at home" if question_id == "format_home"
	replace var_label = "at home value" if question_id == "format_home_value"
	replace var_label = subinstr(var_label, "   sleep under a mosquito net last night","used net last night ", .)
	replace var_label = subinstr(var_label, "In many places, some people use bednets for other things than sleeping, such as curtains or fishing nets. Are nets being used for alternative uses in this community","nets used for alternative uses", .)
	replace var_label = subinstr(var_label, "What types of nets are being used for alternative uses: nets 2 years old or newer, nets 3 years old or older, or both types of nets","types of nets used for alternative uses", .)
	replace var_label = subinstr(var_label, "  household receive any mosquito nets at a 2017 distribution point","received nets", .)
	replace var_label = subinstr(var_label, " If yes, how many nets  household receive ","no of nets received", .)
	replace var_label = subinstr(var_label, "Why  not receive any mosquito nets at a 2017 campaign distribution point ","why not receive nets", .)
	replace var_label = subinstr(var_label, " Did (____) sleep under a mosquito net last night ","child sleep under net last night", .)
	replace var_label = subinstr(var_label, " Has ( ____ ) been ill with a fever at any time in the last 2 weeks ","child had fever last 2 weeks", .)
	replace var_label = subinstr(var_label, "   been ill with a fever at any time in the last 2 weeks ","fever last 2 weeks", .)
	replace var_label = subinstr(var_label, " Did (____ )  seek advice or treatment for the fever from any source ","child seek treatment for fever", .)
	replace var_label = subinstr(var_label, " Has (____ )  taken CoArtem (AL), DuoCotecxin (DP), Quinine, or Cotrimoxazole in the last 2 weeks ","child take antimalaria last 2 weeks", .)
	replace var_label = subinstr(var_label, " Specify which drug did (____ ) take ","specify drug child took", .)
	replace var_label = subinstr(var_label, " Has (____ ) had a fever in the last 24 hours ","child had fever last 24 hrs", .)
	replace var_label = subinstr(var_label, "   seek advice or treatment for the fever from any source ","seek treatment for fever", .)
	replace var_label = subinstr(var_label, "   taken CoArtem (AL), DuoCotecxin (DP), Quinine, or Cotrimoxazole in the last 2 weeks ","take antimalaria last 2 weeks", .)
	replace var_label = subinstr(var_label, "  (CHOOSE ALL THAT APPLY)","", .)
	replace var_label = subinstr(var_label, "   had a fever in the last 24 hours ","fever last 24 hrs", .)
	replace var_label = subinstr(var_label, " Does your household have any mosquito nets that can be used while sleeping ","household has nets", .)
	replace var_label = subinstr(var_label, " Is this person(____) responding to the children’s matrix questions  (Ask to mothers/fathers or designated guardian to children in a household)","responding to children questions", .)
	replace var_label = subinstr(var_label, "   mosquito nets does your household have ","no of nets in household", .)
	replace var_label = subinstr(var_label, "num nets hhd (N.B. This number determines, the number of times the matrix questions will REPEAT themselves, it will be asked once more in the next question for confirmation)","repeat no of nets in household", .)
	replace var_label = subinstr(var_label, " In the past 12 months, has a healthcare worker pierced or cut you with a needle or other medical instrument ","pierced with a needle by healthcare worker last 12 mnths", .)
	replace var_label = subinstr(var_label, " How often do you have six or more drinks on one occasion ","no of times had six or more drinks per occasion", .)
	replace var_label = subinstr(var_label, " How often during the last year have you ","", .)
	replace var_label = subinstr(var_label, "found that you were not able to stop drinking once you had started ","no fo times unable stop drinking once started", .)
	replace var_label = subinstr(var_label, "failed to do what was normally expected from you because of drinking ","no of times failed to do as expected because of drinking", .)
	replace var_label = subinstr(var_label, "needed a first drink in the morning to get yourself going after a heavy drinking session ","no of times needed first drink in the morning to get going", .)
	replace var_label = subinstr(var_label, "had a feeling of guilt or remorse after drinking ","no of times feeling guilty after drinking", .)
	replace var_label = subinstr(var_label, "been unable to remember what happened the night before because you had been drinking ","no of times memory lose after drinking", .)
	replace var_label = subinstr(var_label, "   or someone else been injured as a result of your drinking ","injury post drinking", .)
	replace var_label = subinstr(var_label, " Has a relative or friend, or a doctor or other health worker been concerned about your drinking or suggested you cut down ","others concerned about drinking", .)
	replace var_label = subinstr(var_label, "   ever heard of an illness called tuberculosis or TB ","ever heard of TB", .)
	replace var_label = subinstr(var_label, " In the past 12 months, has any non-medical person deliberately pierced your skin, including tattooing and scarification ","non-medical person deliberately pierced skin last 12 mnths", .)
	replace var_label = subinstr(var_label, "   had history of close contact with confirmed TB or chronic cough "," close contact with confirmed TB", .)
	replace var_label = subinstr(var_label, "   ever been told by a doctor or other health professional that you had tuberculosis ","ever been told had TB", .)
	replace var_label = subinstr(var_label, "   ever been treated for your tuberculosis","ever been treated for TB", .)
	replace var_label = subinstr(var_label, " Are you currently taking treatment for your tuberculosis ","currently on TB treatment", .)
	replace var_label = subinstr(var_label, " When  begin treatment for TB ","when begin TB treatment", .)
	replace var_label = subinstr(var_label, "   complete the treatment ","completed TB treatment", .)
	replace var_label = subinstr(var_label, " How long was/is the treatment for tuberculosis  (# of months) [Don't know = 97, Refuse to Answer = 98 ]","length of TB treatment", .)
	replace var_label = subinstr(var_label, " Were you ever offered an HIV test at the TB clinic ","HIV test TB clin", .)
	replace var_label = subinstr(var_label, " In the past 12-months, have you used any mind-altering substances or recreational substances (Khat/Miraa/Bhangi, etc.) ","used mind-altering substances past 12 mnths", .)
	replace var_label = subinstr(var_label, " Other (Specify below)","specify other drug", .)
	replace var_label = subinstr(var_label, " Some people inject drugs with a needle and syringe for pleasure.   ever injected drugs for pleasure ","ever injected drugs for pleasure", .)
	replace var_label = subinstr(var_label, "   injected drugs with a needle in the last 12-months ","injected drugs with a needle last 12 months", .)
	replace var_label = subinstr(var_label, " When you have injected drugs, have you ever shared the syringe or needle with another people ","ever shared needle", .)
	replace var_label = subinstr(var_label, " How often do you have a drink containing alcohol ","no of times having alcoholic drink", .)
	replace var_label = subinstr(var_label, "   drinks containing alcohol do you have on a typical day when you are drinking ","no of alcoholic drinks per day", .)
	replace var_label = subinstr(var_label, "Is the Camera for the tablet or barcode reader working properly ","camera working", .)
	replace var_label = "change age" if question_id == "formchange_details1"
	replace var_label = "change gender" if question_id == "formchange_details2"
	replace var_label = "change name" if question_id == "formchange_details3"
	replace var_label = "child age" if question_id == "formchild_age"
	replace var_label = "child first name" if question_id == "formchild_f_name"
	replace var_label = "child first name" if question_id == "formchild_first_name"
	replace var_label = "child gender" if question_id == "formchild_gender"
	replace var_label = "child middle name" if question_id == "formchild_m_name"
	replace var_label = "child middle name" if question_id == "formchild_middle_name"
	replace var_label = "child pid" if question_id == "formchild_pid"
	replace var_label = "close followup condition" if question_id == "formclose_followup_condition"
	replace var_label = subinstr(var_label, "Comment Box","comment", .)
	replace var_label = subinstr(var_label, "HIV Confirmatory test","HIV confirmatory result", .)
	replace var_label = subinstr(var_label, "   ever had sexual intercourse ","ever had sex", .)
	replace var_label = subinstr(var_label, "   visit a health facility or see a health care provider because of these problems ","visit health for facility problem", .)
	replace var_label = subinstr(var_label, " Did the healthcare provider tell you that you had a sexually transmitted infection ","told you had STI", .)
	replace var_label = subinstr(var_label, "   get treatment for this sexually transmitted infection ","get treatment for STI", .)
	replace var_label = subinstr(var_label, " Do you think that your chances of getting HIV infection are none, low, moderate or great ","HIV risk perception", .)
	replace var_label = subinstr(var_label, " Other specify","specify other low risk", .)
	replace var_label = subinstr(var_label, " Specify why do you think you have moderate or greater risk of getting HIV infection","specify other high risk", .)
	replace var_label = subinstr(var_label, " You indicated that you lived in____   for  ____  months. During that time,  have any sexual partners in that location ","have sexual partner in location1", .)
	replace var_label = subinstr(var_label, "   sexual partners  have during your time in this location ","no of sexual partners in location1", .)
	replace var_label = subinstr(var_label, " You indicated that you lived in [location (2)] for [x] months. During that time,  have any sexual partners in that location ","have sexual partner in location2", .)
	replace var_label = "no of sexual partners in location2" if question_id == "formd19"
	replace var_label = subinstr(var_label, " How old were you when you had sexual intercourse for the very first time  (years)","age at first sex", .)
	replace var_label = subinstr(var_label, " You indicated that you lived in [location (3)] for [x] months. During that time,  have any sexual partners in that location ","have sexual partner in location3", .)
	replace var_label = "no of sexual partners in location3" if question_id == "formd21"
	replace var_label = subinstr(var_label, " Would you prefer to be circumcised or remain uncircumcised ","prefer to be circumcised", .)
	replace var_label = subinstr(var_label, "   get circumcised during the last five years ","get circumcised last 5 years", .)
	replace var_label = subinstr(var_label, " Where were you circumcised ","where circumcised", .)
	replace var_label = subinstr(var_label, " Specify where  you were circumcised","specify where circumcised", .)
	replace var_label = subinstr(var_label, " Who perfomed the circumcision on you ","who circumcised", .)
	replace var_label = subinstr(var_label, "other. Specify who performed the circumcision on you","specify who circumcised", .)
	replace var_label = subinstr(var_label, "   sex partners have you had in your life  (Don't Know 9997, Refuse to Answer 9998)","no of lifetime sexual partners", .)
	replace var_label = subinstr(var_label, "   sex partners have you had in the past 12 months   (If never had sex in the last 12 months key in zero (0))","no of sexual partners last 12 mnths", .)
	replace var_label = subinstr(var_label, "   or your partner use a condom the last time you had sex ","condom use last sex", .)
	replace var_label = subinstr(var_label, " During the last 12 months have you had an abnormal discharge from your Penis  This may include an unusual smell colour, or texture   MALES ONLY","have discharge penis last 12 mnths", .)
	replace var_label = subinstr(var_label, " During the last 12 months have you had an ulcer or sore on near your Penis    MALES ONLY","have ulcer or sore on near penis last 12 mnths", .)
	replace var_label = subinstr(var_label, " During the last 12 months have you had an abnormal discharge from your Vagina  This may include an unusual smell colour, or texture   FEMALES ONLY","have discharge from vagina last 12 mnths", .)
	replace var_label = subinstr(var_label, " During the last 12 months have you had an ulcer or sore on near your Vagina    FEMALES ONLY","have ulcer or sore on near vagina last 12 mnths", .)
	replace var_label = "interview date" if question_id == "formdateoftoday"
	replace var_label = "DBS barcode" if question_id == "formdbs_barcode"
	replace var_label = subinstr(var_label, "Enter the DBS Barcode Number (If DBS was not collected just enter the random barcode number on participants consent)","DBS barcode type", .)
	replace var_label = subinstr(var_label, "Take the DBS Random ID / Barcode ID/Assent Random ID for ____","DBS barcode scan", .)
	replace var_label = subinstr(var_label, "  DBS spots have been collected from ____ ","no of DBS spots", .)
	replace var_label = "Date of birth" if question_id == "formdob"
	replace var_label = subinstr(var_label, "Number of DBS spots collected from  ____ i.e child","no of child DBS spots", .)
	replace var_label = subinstr(var_label, "   ever had a HIV test ","ever had HIV test", .)
	replace var_label = subinstr(var_label, "   ever gone to a health facility for HIV care and treatment ","ever seek HIV care", .)
	replace var_label = subinstr(var_label, " Why haven’t you gone to a health facility for HIV care and treatment   ","why not seek HIV care", .)
	replace var_label = subinstr(var_label, " Specify why you haven't gone to a health facility for HIV care and treatment","specify why not seek care other", .)
	replace var_label = subinstr(var_label, " When  first enroll for HIV care  (dd/mm/yyy)","when first enroll for HIV care", .)
	replace var_label = subinstr(var_label, " When was the last time you attended the Health centre for HIV care and treatment ","last time attended HIV care clinic", .)
	replace var_label = subinstr(var_label, " Specify why  not attended the health facility for in the last six months or more","specify why not attend clinic other", .)
	replace var_label = subinstr(var_label, " Are you currently taking ARVs","currently taking ARVs", .)
	replace var_label = subinstr(var_label, " How often do you take ARVs ","freq of taking ARVs", .)
	replace var_label = subinstr(var_label, " Specify other reasons why you do not take ARVs currently all of the time (as directed every day) ","specify why not take ARVs always other", .)
	replace var_label = subinstr(var_label, "   gone to more than one health facility for HIV care and treatment  For example, have you changed facilities entirely or do you ever just seek care in a different place ","gone to more than one health facility for HIV care", .)
	replace var_label = subinstr(var_label, "   inform the old facility that you were moving ","inform the old facility of move", .)
	replace var_label = subinstr(var_label, "   get a transfer letter/ inform the previous health facility when moving to the next ","get tranfer letter", .)
	replace var_label = subinstr(var_label, " Why did/do you change the health facility ","why change clin", .)
	replace var_label = subinstr(var_label, " Would you prefer to receive your HIV Care & Treatment at a singular or multiple locations ","prefer singule or multiple locations for HIV care", .)
	replace var_label = "specify service received at HIV clinic other" if question_id == "formf24_other"
	replace var_label = subinstr(var_label, " What was the date when you first learned [____ ] was HIV+ ","date learnt child is HIV+", .)
	replace var_label = subinstr(var_label, " Is ____  HIV positive ","is child HIV+", .)
	replace var_label = subinstr(var_label, " Has [____ ] ever gone to a health facility for HIV care and treatment ","child ever seek HIV care", .)
	replace var_label = subinstr(var_label, " Specify why hasn’t [____ ] gone to a health facility for HIV care and treatment  ","specify why not child seek care other", .)
	replace var_label = subinstr(var_label, " When did [____ ] first enroll for HIV care ","when child first enroll HIV care", .)
	replace var_label = subinstr(var_label, " When was the last time [____ ] attended the Health centre for HIV care and treatment ","last time child attend HIV care clinic", .)
	replace var_label = subinstr(var_label, "Main reason why never had an HIV test ","main reason never had HIV test", .)
	replace var_label = subinstr(var_label, " What would you say is the main reason why you have never had an HIV test ","why never had HIV test", .)
	replace var_label = subinstr(var_label, " Specify the other reason why you have never had an HIV test","specify why never had HIV test", .)
	replace var_label = subinstr(var_label, "   times have you tested for HIV (in the last 12 months) ","no of times tested for HIV last 12 mnths", .)
	replace var_label = subinstr(var_label, " Specify why did [____ ] not attend the health facility in the last six month or more ","specify why not child attend clinic other", .)
	replace var_label = subinstr(var_label, " Has [____ ]","child", .)
	replace var_label = subinstr(var_label, "Is [____ ]","child", .)
	replace var_label = subinstr(var_label, " How often does [____ ]","freq of child", .)
	replace var_label = subinstr(var_label, "Other services (specify)","specify service child received at HIV clinic other", .)
	replace var_label = subinstr(var_label, " When was your most recent HIV test done ","when most recent HIV test done", .)
	replace var_label = subinstr(var_label, " Where was the last test done ","where last test done", .)
	replace var_label = subinstr(var_label, "where last test done (Specify)","specify where last test done", .)
	replace var_label = subinstr(var_label, " What was your most recent HIV test result ","most recent HIV result", .)
	replace var_label = subinstr(var_label, " What was the date when you first learned you were HIV+ ","date leant was HIV+", .)
	replace var_label = subinstr(var_label, "   ever participated in programs for people living with HIV ","ever participated in programs for PLWA", .)
	replace var_label = subinstr(var_label, " If yes, what type of program  Specify","specify program for PLWA other", .)
	replace var_label = "specify program for PLWA" if question_id == "formf9b"
	replace var_label = subinstr(var_label, "HIV Final test Result","HIV final result", .)
	replace var_label = subinstr(var_label, "   make a budget/ plan on how to use or save the money you have in the past two months ","budget last 2 mnths", .)
	replace var_label = subinstr(var_label, " Do you have money saved in the banks, MPESA, at home, in ‘chamas’ or elsewhere ","have savings", .)
	replace var_label = subinstr(var_label, " If yes to above question, do you consider your savings as being safe and under your own control","savings safe", .)
	replace var_label = "fisherfolk counter" if question_id == "formfisherfolk_counter"
	replace var_label = "followup counter" if question_id == "formfollowup_counter"
	replace var_label = subinstr(var_label, " Were you tested for HIV during pregnancy (ANC/Maternity) when you were pregnant with ( ____ )","tested for HIV during pregnancy", .)
	replace var_label = subinstr(var_label, "   receive the result of your HIV test during your pregnancy/Delivery of ____  ","rec HIV ANC result", .)
	replace var_label = subinstr(var_label, " What was the result of your HIV test during your pregnancy/maternity with ____ ","receive HIV test result during pregnancy", .)
	replace var_label = subinstr(var_label, " Can you tell me the main reason why you were not tested for HIV during ANC and maternity services with ( ____ ) ","main reason why not tested for HIV during ANC", .)
	replace var_label = subinstr(var_label, " Since you knew you were HIV positive, were you already taking HIV medication for your own health while you were pregnant with ____ ","take ARVs while pg", .)
	replace var_label = subinstr(var_label, " During any of your ANC visits, were you told of a place where you could receive care and treatment services to prevent ( ____ ) from getting HIV infection ","ANC informed about PMTCT", .)
	replace var_label = subinstr(var_label, "   take any medication to prevent ( ____ ) from getting HIV infection ","take any medication to prevent MTCT", .)
	replace var_label = subinstr(var_label, "   take this HIV medication during your pregnancy (before birth) with ( ____ ) ","take HIV medication during your pregnancy", .)
	replace var_label = subinstr(var_label, "   months pregnant were you with ( ____ ) when you started taking this HIV medication ","no of months take HIV medication while pregnat", .)
	replace var_label = subinstr(var_label, "   take HIV medication during labour and/or delivery with ( ____ ) ","take HIV medication during labour", .)
	replace var_label = subinstr(var_label, " Initials of the last born child  ( If the child was still born, key in the initials: STB)","initials of last child", .)
	replace var_label = subinstr(var_label, " Did ( ____ ) take any medications to prevent him/her from getting HIV infection ","child take meds to prevent HIV infection", .)
	replace var_label = subinstr(var_label, " Is ____ a boy or a girl ","child gender", .)
	replace var_label = subinstr(var_label, " When  give birth to ____  ","child date of birth", .)
	replace var_label = subinstr(var_label, " Is ____ still alive ","child alive", .)
	replace var_label = subinstr(var_label, " When did ____ die ","child date of death", .)
	replace var_label = subinstr(var_label, " When you were pregnant with ____  go to the clinic for antenatal care ","attend ANC when pregnant with child", .)
	replace var_label = subinstr(var_label, "   times  visit the ANC clinic during your pregnancy with ____ ","no of times attended ANC when pregnant with child", .)
	replace var_label = subinstr(var_label, " During any of your visits to the ANC when you were pregnant with ( ____ ) were you offered an HIV test ","offered HIV test ANC when pregnant with child", .)
	replace var_label = "gender display" if question_id == "formgender_display"
	replace var_label = "gender value" if question_id == "formgender_value"
	replace var_label = subinstr(var_label, "Has the household head consented to participation in this study ","household head given individual consent", .)
	replace var_label = subinstr(var_label, "Has the household head consented to overall participation of household members in this study ","household head given overall consent", .)
	replace var_label = "consent date" if question_id == "formhhd_consent_date"
	replace var_label = subinstr(var_label, "Questions to head of the household","questions to the household head", .)
	replace var_label = "fishefolk member count" if question_id == "formhhd_detailsfisherfolk_member_counter"
	replace var_label = "household eligible" if question_id == "formhhd_detailshhd_eligible"
	replace var_label = "age" if question_id == "formhhd_detailshhd_member/age"
	replace var_label = "member age" if question_id == "formhhd_detailshhd_member/age/age"
	replace var_label = subinstr(var_label, "Is age of ____  recorded in Months (for minors below two years) ","age in months", .)
	replace var_label = "age in years" if question_id == "formhhd_detailshhd_member/age/age_years"
	replace var_label = subinstr(var_label, "Is ____ now at home ","member now at home", .)
	replace var_label = subinstr(var_label, "First Name of household ____","household fname", .)
	replace var_label = subinstr(var_label, "Is ____  male or female ","member gender", .)
	replace var_label = subinstr(var_label, "Does ____   earn his/her livelihood through the fishing industry ","member is fisherfolk", .)
	replace var_label = "eligible adult display" if question_id =="formhhd_detailshhd_member/illegible_adult_display"
	replace var_label = "mamber is child" if question_id == "formhhd_detailshhd_member/is_child"
	replace var_label = "member is eligible adult" if question_id == "formhhd_detailshhd_member/is_eligible_adult"
	replace var_label = "member is fisherfolk" if question_id == "formhhd_detailshhd_member/is_fisherfolk"
	replace var_label = "member is household head" if question_id == "formhhd_detailshhd_member/is_household_head"
	replace var_label = subinstr(var_label, "When is the last time ____  slept in the house (in weeks)","last time member slept in the house", .)
	replace var_label = subinstr(var_label, "Last Name of ____","member lname", .)
	replace var_label = "member loop position" if question_id == "formhhd_detailshhd_member/loop_position"
	replace var_label = subinstr(var_label, "Mature minor determination","mature minor detertmination", .)
	replace var_label = "mature minor" if question_id == "formhhd_detailshhd_member/mature_minor_determination/mature_minor"
	replace var_label = "member reference" if question_id == "formhhd_detailshhd_member/member_reference"
	replace var_label = subinstr(var_label, "Middle Name of  ____","member's middle name", .)
	replace var_label = "participant id" if question_id == "formhhd_detailshhd_member/participant_id"
	replace var_label = subinstr(var_label, "Place and time details of where and when to get ____","contact details", .)
	replace var_label = subinstr(var_label, "Where is the best place to contact ____  ","contact place", .)
	replace var_label = subinstr(var_label, "When is the best day and time to contact ____ ","contact time", .)
	replace var_label = subinstr(var_label, "Enter the member running number for this household member:","member running number", .)
	replace var_label = subinstr(var_label, "Confirm the running number for this household member:","repeat member running number", .)
	replace var_label = "register household" if question_id ==  "formhhd_detailsregister_household"
	replace var_label = subinstr(var_label, "No member of this household depends on the fishing industry for their livelihood. Therefore, this household will not be registered in this study. Would you like to register the members anyway ","register ineligible household", .)
	replace var_label = subinstr(var_label, "The questions that follow are directed to the head of the household:     people usually reside in this household , including yourself and any guests who stayed here overnight ","no of household members", .)
	replace var_label = "eligible household" if question_id == "formhhd_eligible"
	replace var_label = "first name" if question_id == "formhhd_first_name"
	replace var_label = "last name" if question_id == "formhhd_last_name"
	replace var_label = subinstr(var_label, "Does any member of your household, or long-stay guest earn their livelihood through the fishing industry ","any household member is a fisherfolk", .)
	replace var_label = "member age" if question_id == "formhhd_memberage"
	replace var_label = subinstr(var_label, "Is age of ____  recorded in MONTHS or YEARS ","age units", .)
	replace var_label = subinstr(var_label, "Is (____) now at home ","member now at home", .)
	replace var_label = subinstr(var_label, "You have indicated that  ____ is____   years old, please confirm if s/he  meets any of the following criteria:","mature minor eligibility criteria", .)
	replace var_label = subinstr(var_label, "SEX Is ____  Male or Female ","gender", .)
	replace var_label = subinstr(var_label, "Does  (____) earn his/her livelihood through the fishing industry ","member is a fisherfolk", .)
	replace var_label = subinstr(var_label, "When is the last time the person slept in the house (in weeks)","last time member slept in the house", .)
	replace var_label = "member is a mature minor" if question_id =="formhhd_membermature_minor"
	replace var_label = subinstr(var_label, "place and time","contact details", .)
	replace var_label = subinstr(var_label, "where is the best place to contact (____)  ","contact place", .)
	replace var_label = subinstr(var_label, "when is the best time to contact (____)  ","contact time", .)
	replace var_label = subinstr(var_label, "  members of your household , including yourself , or long stay guests earn their livelihood through the fishing industry ","no of fisherfolk household members", .)
	replace var_label = "middle name" if question_id == "formhhd_middle_name"
	replace var_label = subinstr(var_label, "Please enter the names of the head of the household","household head's names", .)
	replace var_label = subinstr(var_label, "Are you employed in fishing industry ","househead is a fisherfolk", .)
	replace var_label = "visit date" if question_id == "formhhd_visit_date"
	replace var_label = subinstr(var_label, "Enter the household number for this household, e.g V03/001/A","household id", .)
	replace var_label = subinstr(var_label, "Enter the household number for this household, e.g V03/01/A","household id", .)
	replace var_label = "child is eligible for  HIV screening" if question_id == "formhiv_child_eligibility"
	replace var_label = "household id" if question_id == "formhousehold_id"
	replace var_label = subinstr(var_label, "Is the person giving consent the biological mother of  ____  ","is biological mother", .)
	replace var_label = "kibuogi choice facility" if question_id == "formkibuogi_cluster"
	replace var_label = "kisumu choice facility" if question_id == "formkisumu_cluster"
	replace var_label = "kiumba choice facility" if question_id == "formkiumba_cluster"
	replace var_label = subinstr(var_label, "Comments (if any)","comments", .)
	replace var_label = subinstr(var_label, "Has ____ /  ____ been linked to a specific facility for HIV care and treatment  ","linked to HIV care", .)
	replace var_label = "lmp in weeks" if question_id == "formlmp_weeks"
	replace var_label = "luanda choice facility" if question_id == "formluanda_rombo_cluster"
	replace var_label = subinstr(var_label, " Are you ","", .)
	replace var_label = subinstr(var_label, " If ever used or participated in the intervention: ","", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(Families Matter )","aware of Families Matter", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Families Matter)","participated in Families Matter", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Families Matter )","satisfaction with Families Matter", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program( Healthy Choices I or Healthy Choices for Better Future )","aware of Healthy Choices for Better Future", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Healthy Choices I or Healthy Choices for Better Future )","participated in Healthy Choices for Better Future", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention ( Healthy Choices I or Healthy Choices for Better Future )","satisfaction with Healthy Choices for Better Future", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program( Healthy choices II or My Health My Choice)","aware of My Health My Choice", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Healthy choices II or My Health My Choic)","participated in My Health My Choice", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Healthy choices II or My Health My Choic )","satisfaction with My Health My Choice", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program( Health talks in school)","aware of Health talks in school", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Health talks in school )","participated in Health talks in school", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention ( Health talks in school)","satsfaction with Health talks in school", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(A club or group with peers )","aware of club or group with peers", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( A club or group with peers )","participated in club or group with peers", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention ( A club or group with peers )","satisfaction with club or group with peers", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(Making Life’s Responsible Choices )","aware of Making Life’s Responsible Choices", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Making Life’s Responsible Choices )","participated in Making Life’s Responsible Choices", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention ( Making Life’s Responsible Choices )","satisfaction with Making Life’s Responsible Choices", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program( Violence prevention education )","aware of Violence prevention education", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Violence prevention education )","participated in Violence prevention education", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Violence prevention education )","satsfaction with Violence prevention education", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(shuga )","aware of shuga", .)
	replace var_label = subinstr(var_label, "   participate in the intervention(shuga )","participated in shuga", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (shuga)","satisfaction with shuga", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(jipange )","aware of jipange", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( jipange)","participated in jipange", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (jipange)","satisfaction with jipange", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program( Chill club )","aware of Chill club", .)
	replace var_label = subinstr(var_label, "   participate in the intervention (Chill club )","participated in Chill club", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Chill club )","satisfaction with Chill club", .)
	replace var_label = subinstr(var_label, "aware of this intervention(home based HIV testing)","aware of home based HIV testing", .)
	replace var_label = subinstr(var_label, "   participate in the intervention(homebased HIV testing)","participated in home based HIV testing", .)
	replace var_label = "satisfaction with home based HIV testing" if question_id == "formm1c"
	replace var_label = subinstr(var_label, "aware of the following intervention program( Life Skills Program)","aware of Life Skills", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Life Skills Program)","participated in Life Skills", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Life Skills Program)","satisfaction with Life Skills", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program( Sister to sister )","aware of Sister to sister", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Sister to sister )","participated in Sister to sister", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention,Sister to sister - Kenya","satisfaction with Sister to sister", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(Stepping Stones )","aware of Step Stones", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Stepping Stones )","participated in Step Stones", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Stepping Stones )","satisfaction with Step Stones", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(The DREAMS program )","aware of DREAMS", .)
	replace var_label = subinstr(var_label, "   participate in the intervention(The DREAMS program )","participated in DREAMS", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention ( The DREAMS program )","satisfaction with DREAMS", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program (Cash transfer to families of girls and young women )","aware of Cash transfer to families of girls and young women", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Cash transfer to families of girls and young women )","icipated in Cash transfer to families of girls and young women", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention ( Cash transfer to families of girls and young women )","satisfaction with Cash transfer to families of girls and young women", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program ( Cash transfer to girls and young women for them to use or save)","aware of Cash transfer to girls and young women for them to use or save", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Cash transfer to girls and young women for them to use or save)","participated in Cash transfer to girls and young women for them to use or save", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention ( Cash transfer to girls and young women for them to use or save)","satisfaction with Cash transfer to girls and young women for them to use or save", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(Educational subsidies for girls and young women )","aware of Educational subsidies for girls and young women", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Educational subsidies for girls and young women)","participated in Educational subsidies for girls and young women", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Educational subsidies for girls and young women )","satisfaction with Educational subsidies for girls and young women", .)
	replace var_label = subinstr(var_label, " Safe Spaces” for girls/young women (Specify such a place(s))","specify Safe Spaces", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program( Safe Spaces” for girls/young women:)","aware of Safe Spaces for girls and young women", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Safe Spaces” for girls/young women:)","participated in Safe Spaces for girls and young women", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention ( Safe Spaces” for girls/young women:)","satisfied with Safe Spaces for girls and young women", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(Gender norms )","aware of Gender norms", .)
	replace var_label = subinstr(var_label, "   participate in the intervention(Gender norms )","participated in Gender norms", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Gender norms )","satisfaction with Gender norms", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(facility based HIV testing)","aware of facility based HIV testing", .)
	replace var_label = subinstr(var_label, "   participate in the intervention(facility based HIV testing)","participated in facility based HIV testing", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (facility based)","satisfaction with facility based HIV testing", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(Financial literacy)","aware of Financial literacy", .)
	replace var_label = subinstr(var_label, "   participate in the intervention(Financial literacy) ","participated in Financial literacy", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Financial literacy)","satisfaction with Financial literacy", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program('Social asset building' ) ","aware of Social asset building", .)
	replace var_label = subinstr(var_label, "   participate in the intervention ('Social asset building' ) ","participated in Social asset building", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention  ('Social asset building' ) ","satisfaction with Social asset building", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program (Economic empowerment or microfinance program)","aware of Economic empowerment or microfinance", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Economic empowerment or microfinance program ) ","participated in Economic empowerment or microfinance", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Economic empowerment or microfinance program) ","satisfaction with Economic empowerment or microfinance", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(Enrolment into a self-help group, merry-go round/table banking) ","aware of Enrolment into a self-help group, merry-go round or table banking", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Enrolment into a self-help group, merry-go round/table banking) ","participated in Enrolment into a self-help group, merry-go round or table banking", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Enrolment into a self-help group, merry-go round/table banking) ","satisfaction with Enrolment into a self-help group, merry-go round or table banking", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(Peer to Peer Model/Peer education and outreach ) ","aware of Peer to Peer Model", .)
	replace var_label = subinstr(var_label, "   participate in the intervention(Peer to Peer Model/Peer education and outreach ) ","participated in Peer to Peer Model", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Peer to Peer Model/Peer education and outreach ) ","satisfaction with Peer to Peer Model", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(any other program) (Probe for:) • Respect-K A risk reduction Counseling intervention • Condom distribution • Modern contraceptives • STI Screening • STI Treatment • TB Screening • TB Treatment • ANC/PMTCT • Linkage to CCC","aware of other program", .)
	replace var_label = subinstr(var_label, "   participate in the intervention(any other program) ","participated in other program", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (any other program)","satisfaction with other program", .)
	replace var_label = subinstr(var_label, " Are there community health workers in your community (CHWs/CHEWS)","aware of community health workers", .)
	replace var_label = subinstr(var_label, "   ever been contacted by a CHWs/CHEWS","contacted by community health workers", .)
	replace var_label = "satisfied with community health workers" if question_id == "formm36c"
	replace var_label = subinstr(var_label, " Are there community health workers in your community (peer educators)","aware of peer educators", .)
	replace var_label = subinstr(var_label, "   ever been contacted by a peer educator","contacted by peer educators", .)
	replace var_label = subinstr(var_label, "   satisfaction with CHWs in your community ","satisfcation with peer educators", .)
	replace var_label = subinstr(var_label, "   ever heard of “drop-in” centers for medical services in your community ","aware of drop-in centers", .)
	replace var_label = subinstr(var_label, "   ever attended a “drop-in” center ","attended drop-in centers", .)
	replace var_label = subinstr(var_label, "   satisfaction with drop-in centers ","satisfaction with drop-in centers", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(Mobile-clinic HIV testing)","aware of Mobile-clinic HIV testing", .)
	replace var_label = subinstr(var_label, "   participate in the intervention(mobile clinic HIV testing)","participate in Mobile-clinic HIV testing", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (mobile testing)","satisfaction with Mobile-clinic HIV testing", .)
	replace var_label = subinstr(var_label, " If yes to any (A, B, C) above,  seek any post-violence services or care ","seek post violence services", .)
	replace var_label = subinstr(var_label, "What kind of post-violence services or care  seek (Specify)","specify post violence service other", .)
	replace var_label = subinstr(var_label, " If you have used post-violence care, how satisfied were you with the service ","satisfaction with post violence service", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(Family testing )","aware of Family testing", .)
	replace var_label = subinstr(var_label, "   participate in the intervention(family testing)","participate in Family testing", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (family testing)","satisfaction with Family testing", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(Integrated HIV Testing Service (HTS/VCT)","aware of Integrated HIV Testing Service", .)
	replace var_label = subinstr(var_label, "   participate in the intervention(Integrated HIV Testing Service (HTS/VCT)","participated in Integrated HIV Testing Service", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Integrated HIV Testing Service (HTS/VCT)","satisfaction with Integrated HIV Testing Service", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program( Pre-exposure prophylaxis (PrEP)","aware of PrEP", .)
	replace var_label = subinstr(var_label, " Did participate in the intervention(Pre-exposure prophylaxis (PrEP):)","participate in PrEP", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention ( Pre-exposure prophylaxis (PrEP):)","satisfaction with PrEP", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(Post-exposure prophylaxis (PEP): )","aware of PEP", .)
	replace var_label = subinstr(var_label, "   participate in the intervention(Post-exposure prophylaxis (PEP): )","participate in PEP", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention ( Post-exposure prophylaxis)","satisfaction with PEP", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program(Emergency Contraceptive Pills )","aware of ePill", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( Emergency Contraceptive Pills )","participate in ePill", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention (Emergency Contraceptive Pills )","satisfaction with ePill", .)
	replace var_label = subinstr(var_label, "aware of the following intervention program( EBAN-K)","aware of EBAN-K", .)
	replace var_label = subinstr(var_label, "   participate in the intervention( EBAN-K )","participate in EBAN-K", .)
	replace var_label = subinstr(var_label, "How satisfied are you with the intervention ( EBAN-K)","satisfaction with EBAN-K", .)
	replace var_label = "mahanga choice facility" if question_id == "formmahanga_cluster"
	replace var_label = "malaria treatment given" if question_id == "formmalaria_treatment"
	replace var_label = "mfangano choice facility" if question_id == "formmfangano_cluster"
	replace var_label = "migrations counter" if question_id == "formmigrations_counter"
	replace var_label = subinstr(var_label, "End date ____","migration end date", .)
	replace var_label = subinstr(var_label, "Location name ____","migration location name", .)
	replace var_label = subinstr(var_label, "Start Date ____","migration start date", .)
	replace var_label = "not at home counter" if question_id == "formnot_at_home_counter"
	replace var_label = subinstr(var_label, "Other Contact means(Specify)","other contact means", .)
	replace var_label = subinstr(var_label, "Other facility:","other facility", .)
	replace var_label = subinstr(var_label, "Other malaria drug","other malaria drug", .)
	replace var_label = "oyamo choice facility" if question_id == "formoyamo_cluster"
	replace var_label = "participant age" if question_id == "formparticipant_age"
	replace var_label = subinstr(var_label, "Take the Consent Barcode for the participant","barcode scan", .)
	replace var_label = subinstr(var_label, "Take the Consent Barcode for the child (____ )","child barcode scan", .)
	replace var_label = subinstr(var_label, "Enter the Barcode/Random ID Number for the child","child barcode type", .)
	replace var_label = subinstr(var_label, "Enter the Barcode Number","random id type", .)
	replace var_label = "participant first name" if question_id == "formparticipant_first_name"
	replace var_label = "participant gender" if question_id == "formparticipant_gender"
	replace var_label = "participant id" if question_id == "formparticipant_id"
	replace var_label = "participant last name" if question_id == "formparticipant_last_name"
	replace var_label = "participant middle name" if question_id == "formparticipant_middle_name"
	replace var_label = subinstr(var_label, "Take the Consent Barcode for the child's biological mother or designated guardian","mother or guardian barcode scan", .)
	replace var_label = subinstr(var_label, "Enter the Barcode/Random ID Number for the mother or designated guardian","mother or guardian barcode type", .)
	replace var_label = subinstr(var_label, "   relationship with this partner ____ ","relatioship with partner", .)
	replace var_label = subinstr(var_label, "   use a condom the last time you had sex with this partner  (Partner  ____)","condom use last sex with partner", .)
	replace var_label = subinstr(var_label, "   ever been tested with this partner  (Partner  ____)","tested with partner", .)
	replace var_label = subinstr(var_label, " What is this partner’s HIV status  (Partner  ____)","partner's HIV status", .)
	replace var_label = subinstr(var_label, "   disclosed your most recent test result to your partner  (Partner  ____)","disclose test result to partner", .)
	replace var_label = subinstr(var_label, " Is the partner older than you, younger than you, or about the same age  (Partner  ____)","age difference with partner", .)
	replace var_label = subinstr(var_label, " Would you say (Partner  ____) is ten or more years older than you, or less than ten years older than you ","partner older", .)
	replace var_label = subinstr(var_label, " Would you say (Partner  ____) is ten or more years younger than you, or less than ten years younger than you","partner younger", .)
	replace var_label = subinstr(var_label, " In the last 12-months did partner ever give you money, gifts or other favors for having sex with him/her  (Partner  ____)","partner give you gifts for favors last 12 months", .)
	replace var_label = subinstr(var_label, " List other gifts","specify gift received other", .)
	replace var_label = subinstr(var_label, " In the last 12-months have you ever given money, gifts, or other favors for having sex with him/her (Partner  ____) ","give gifts for favour last 12 months", .)
	replace var_label = subinstr(var_label, " When was the first time you had sexual intercourse with partner ____ ","first time sex with partner", .)
	replace var_label = subinstr(var_label, " What other gifts or other favors  give (specify) (Partner  ____)","specify gift give other", .)
	replace var_label = subinstr(var_label, "   times in the last 12 months  have sex with this partner  (Partner  ____)","no of times had sex with partner last 12 mnths", .)
	replace var_label = subinstr(var_label, "and this partner currently doing something or using any method to delay or avoid getting pregnant  (Partner  ____)","using family planning", .)
	replace var_label = subinstr(var_label, " Which method(s) are you (your partner) using  (Partner  ____)","family planning methods being used", .)
	replace var_label = subinstr(var_label, " In the last 12 months did this partner force you to have sex  (Partner  ____)","partner force sex", .)
	replace var_label = subinstr(var_label, "Other Specify (Partner  ____)","specify other partner", .)
	replace var_label = subinstr(var_label, " When was the last time you had sexual intercourse with ____ ","last time sex with partner", .)
	replace var_label = subinstr(var_label, " Does this partner ____  work in the fishing industry ","partner is fisherfolk", .)
	replace var_label = subinstr(var_label, " Other type of occupation in the fisherfolk industry (Partner  ____) ","specify partner occupation other", .)
	replace var_label = subinstr(var_label, "   BMU Membership of this (Partner  ____) ","partner is BMU member", .)
	replace var_label = subinstr(var_label, " What is/was the marital status of this (Partner  ____) ","partner marital status", .)
	replace var_label = subinstr(var_label, " Is this sexual relationship ongoing   (Partner  ____)","ongoing relationship", .)
	replace var_label = subinstr(var_label, " Was a condom used every time you had sex with this partner in the last 3 months   (Partner  ____)","condom used every time sex with patner", .)
	replace var_label = "last sexual encounter duration" if question_id == "formpartner_matrixlast_sexual_encounter_duration"
	replace var_label = subinstr(var_label, "Enter the nearest fishing beach:","beach", .)
	replace var_label = subinstr(var_label, "Enter the county:","county", .)
	replace var_label = "registration attempts" if question_id == "formphysical_addresshhd_registration_attempts"
	replace var_label = subinstr(var_label, "where is the best place to contact (____ )  ","contact place", .)
	replace var_label = subinstr(var_label, "when is the best time to contact ____  ","contact time", .)
	replace var_label = subinstr(var_label, "Ask the person if she is pregnant (Probe)","pregnancy status", .)
	replace var_label = subinstr(var_label, "Was RDT done ","RDT done", .)
	replace var_label = "remba choice facility" if question_id == "formremba_cluster"
	replace var_label = "repeat net counter" if question_id == "formrepeat_net_count"
	replace var_label = subinstr(var_label, " Why didn’t someone sleep under the net last night   (Net ____)","why not use net last night", .)
	replace var_label = subinstr(var_label, "Other (Specify why someone didn't sleep under the net) (Net ____)","other why not use net last night", .)
	replace var_label = subinstr(var_label, " Did anyone sleep under this net last night  (Net ____)","use this net last night", .)
	replace var_label = "ringiti choice facility" if question_id == "formringiti_cluster"
	replace var_label = subinstr(var_label, " Do you know of areas within the community that are not safe for you because you could be in danger of being attacked ","unsafe places in community", .)
	replace var_label = subinstr(var_label, " If yes to above question, can you avoid such risky areas in the community ","avoid unsafe places in community", .)
	replace var_label = subinstr(var_label, " Do you believe that you have the ability to avoid the dangerous places you have mentioned above ","able to avoid unsafe places in community", .)
	replace var_label = subinstr(var_label, " Do you have a specific plan to manage risky situations such as imminent sexual violence ","plan to manage risky situations", .)
	replace var_label = subinstr(var_label, ".....................  Check all that apply","", .)
	replace var_label = "sex" if question_id == "formsex"
	replace var_label = "sexual matrix labels" if question_id == "formsexual_matrix_labels"
	replace var_label = "sexual partners count" if question_id == "formsexual_partners_counter"
	replace var_label = subinstr(var_label, " Is there someone in the community, other than your mother or guardian, from whom you can borrow money in case of an emergency e.g. medical illness involving you or a close family member ","have an emergency contact", .)
	replace var_label = subinstr(var_label, " Is there a private place in your community, other than home or school, where you can meet or hang out with your peers of the same gender ","private place in community", .)
	replace var_label = subinstr(var_label, " Do you have a trusted female friend, other than your mother or guardian, whom you could turn to if you had a serious problem ","have a confidant", .)
	replace var_label = subinstr(var_label, "Sources of income","source of income", .)
	replace var_label = subinstr(var_label, " Explain your [other] sources of income(cash )","spefciy other source of income other", .)
	replace var_label = subinstr(var_label, "Staff Code:","Staff Code", .)
	replace var_label = "time now" if question_id == "formtimeofnow"
	replace var_label = subinstr(var_label, "Type barcode for the child DBS/Assent Random ID/Barcode","child DBS barcode type", .)
	replace var_label = "HIV test done" if question_id == "formx_hiv_test_done"
	replace var_label = "confirm no of sexual partners" if question_id == "formxd4"

	
// Remove leading and trailing blanks, blanks within the var label and change case to lower	
	replace var_label = trim(var_label) //remove leading and trailing blanks
	replace var_label=lower(var_label) // to fit with stata, convert to lower case
    replace var_label = subinstr(var_label," ","",.) // remove blanks from var_label
	
//rename variables with very long or similar names to match the dataset	

replace question_id = subinstr(question_id, "hhd_details","", .)
replace question_id = subinstr(question_id, "physical_address","", .)
replace question_id = subinstr(question_id, "place_and_time","", .)

*drop if question_id == "update_at_home_value"

gen id = _n

replace question_id = subinstr(question_id, "form","formupdate_", .) if source == "UpdateHousehold"
replace question_id = subinstr(question_id, "determination","det", .)
replace question_id = subinstr(question_id, "mature_","", .)
replace question_id = "formhhd_memberminor_detcrit1" if inlist(id, 1853, 1854)
replace question_id = "formhhd_memberminor_detcrit2" if inlist(id, 1855, 1856)
replace question_id = "formhhd_memberminor_detcrit3" if inlist(id, 1857, 1858)
replace question_id = "formhhd_memberminor_detcrit4" if inlist(id, 1859, 1860)
replace question_id = "formhhd_memberminor_determination" if id == 1861

replace question_id = subinstr(question_id, "update_timeofnow","timeofnow", .)

drop id

//create variable module
gen module = "Module A" if regexm( label,"^[A][0-9]+")
replace module = "Module B" if regexm( label,"^[B][0-9]+") & missing(module) 
replace module = "Module C" if regexm( label,"^[C][0-9]+") & missing(module) 
replace module = "Module D" if regexm( label,"^[D][0-9]+") & missing(module) 
replace module = "Module E" if regexm( label,"^[E][0-9]+") & missing(module) 
replace module = "Module F" if regexm( label,"^[F][0-9]+") & missing(module) 
replace module = "Module G" if regexm( label,"^[G][0-9]+") & missing(module) 
replace module = "Module M" if regexm( label,"^[M][0-9]+") & missing(module) 
replace module = "Module N" if regexm( label,"^[N][0-9]+") & missing(module)

replace module = "Module A" if ///
( regexm( question_id,"^forma[0-9]+") ///
| regexm( question_id,"^formbeach") ///
| regexm( question_id,"^formage") ///
| regexm( question_id,"^formchange") ///
| regexm( question_id,"^format") ///
| regexm( question_id,"^formchild") ///
| regexm( question_id,"^formcontact") ///
| regexm( question_id,"^formdob") ///
| regexm( question_id,"^formgender") ///
| regexm( question_id,"^formhhd") ///
| regexm( question_id,"^formidentifier") ///
| regexm( question_id,"^formis") ///
| regexm( question_id,"^formmigrations") ///
| regexm( question_id,"^formparticipant") ///
| regexm( question_id,"^formphone") ///
| regexm( question_id,"^formphysical") ///
| regexm( question_id,"^formplace") ///
| regexm( question_id,"^formsex") ) & missing(module)

replace module = "Module B" if ///
( regexm( question_id,"^formallergic") ///
| regexm( question_id,"^formmalaria") ///
| regexm( question_id,"^formlmp") ///
| regexm( question_id,"^formpreg") ///
| regexm( question_id,"^formrdt") ) & missing(module)

replace module = "Module F" if ///
( regexm( question_id,"^formconfirmatory") ///
| regexm( question_id,"^formdbs") ///
| regexm( question_id,"^formf[0-9]+") ///
| regexm( question_id,"^formfinal") ///
| regexm( question_id,"^formhiv") ///
| regexm( question_id,"^formlinkage") ///
| regexm( question_id,"^formlinked") ///
| regexm( question_id,"^formscreening") ///
| regexm( question_id,"^formtype") ///
| regexm( question_id,"^formx_hiv") ) & missing(module)

replace module = "Module E" if ///
( regexm( question_id,"^formpartner") ///
| regexm( question_id,"^formsexual") ///
| regexm( question_id,"^formxd4") ) & missing(module)

replace module = "Module A" if question_id == "formhousehold_id"
replace module = "Module A" if question_id == "formnot_at_home_counter"
replace module = "Module B" if question_id == "formrepeat_net_count"
replace module = "Module B" if question_id == "formrepeat_netb10_other"
replace module = "Module B" if question_id == "formother_malaria_drug"

replace module = "Module Other" if  missing(module)

replace question_id = subinstr(question_id, "form","", .)
replace question_id=substr(question_id,1,30)

// create module_description
gen module_description = ""
replace module_description = "INDIVIDUAL DEMOGRAPHIC INFORMATION" if  module == "Module A"
replace module_description = "MALARIA" if  module == "Module B"
replace module_description = "GENERAL HIV RISK" if  module == "Module C"
replace module_description = "SEXUAL BEHAVIOUR AND HIV RISK" if  module == "Module D"
replace module_description = "SEXUAL PARTNER MATRIX" if  module == "Module E"
replace module_description = "HIV DIAGNOSIS, CARE AND TREATMENT" if  module == "Module F"
replace module_description = "REPRODUCTIVE HISTORY" if  module == "Module G"
replace module_description = "HIV PREVENTION, CARE AND TREATMENT INTERVENTION AWARENESS, UTILIZATION AND SATISFACTION WITH SERVICE" if  module == "Module M"
replace module_description = "SOCIAL ASSETS SAFETY AND FINANCIAL LITERACY" if  module == "Module N"
replace module_description = "OTHER" if  module == "Module Other"


***generate command for labelling question_id**
gen labelvar="label variable" + question_id + " "

/*create commands for defining labels*/
replace optionname =" "+char(34)+ optionname +char(34)+" " if !missing(optionname) 
bysort question_id (optionvalue):gen position=_n if !missing( optionvalue)
bysort question_id (optionvalue):egen minposition=min(position)
bysort question_id (optionvalue):egen maxposition=max(position)

gen value_label= optionvalue + "" + optionname+"" if !missing( optionvalue)

***generate command for labelling question_id**
gen var_label_cmd="label "+ "variable "+question_id+" "+char(34)+var_label+char(34)


gen label_defn_cmd= "label define "+ question_id+" "+value_label + "///" if position==minposition & position!=.
replace label_defn_cmd= "label define "+ question_id+" "+value_label  if position==minposition & position!=. & minposition==maxposition
replace label_defn_cmd=  " "+value_label  if position!=. & position==maxposition & missing(label_defn_cmd)
replace label_defn_cmd= value_label +"///" if !missing( optionvalue ) & missing(label_defn_cmd)


//create commands for labelling values
gen label_values_cmd="label values "+ question_id+" "+ question_id if !missing(optionvalue)


// complete unknown values in the variable label with values from var_label

br if label == "[unknown]"

replace label = var_label if label == "[unknown]"

//save updated dictionary in both stata and csv formats
local ffx_dictionary = "${temp_data}\\`ffx_dictionary'_ffx_dictionary_labelled"
save `ffx_dictionary',replace
export delimited using `ffx_dictionary', replace


//Create do file automatically add labels to variables

/*create the do files for labelling variables and values*/

/*create the do file for labelling*/

tempname fhandle

file open `fhandle' using "${scripts}\var_label_cmd_ffx.do", write text replace

* create header of do-file 

file write `fhandle' " ******************************************************** " _n _n
file write `fhandle' " ** name: var_label_cmd_ffx.do	" _n
file write `fhandle' " ** description: code to label variables /values of variables for Fisherfolk surveys" _n
file write `fhandle' " ** inputs: Data sets for Fisherfolk" _n					
file write `fhandle' " ** author: Hellen Awuoche" _n												
file write `fhandle' " ** survey: Fisherfolk" _n															
file write `fhandle' " ** output: labeling do file" _n											
file write `fhandle' " ** created: 2oDEC2017" _n 
file write `fhandle' " ** last revised/reviewed:"  (c(current_date))  _n _n													
file write `fhandle' " ******************************************************** " _n _n

file write `fhandle'  "set varabbrev off" _n

file write `fhandle'  "capture log close" _n

file write `fhandle'  "set more off" _n _n

file write `fhandle'  " **************************** " _n
file write `fhandle'  " ** set up working folders ** " _n
file write `fhandle'  " **************************** " _n _n

file write `fhandle' "// global macros" _n
file write `fhandle' "global workspace " (char(34)) "$workspace"  (char(34))  _n
file write `fhandle' "cd $workspace" _n _n

file write `fhandle' "global raw_data" (char(34)) "Fisherfolk_cleaning_project\Data\Raw_data\data" (char(34)) _n
file write `fhandle' "global clean_data" (char(34)) "Fisherfolk_cleaning_project\Data\clean_data\data"  (char(34)) _n
file write `fhandle' "global scripts" (char(34)) "Fisherfolk_cleaning_project\Data\code\stata\scripts" (char(34))  _n _n

file write `fhandle' "// save log file" _n
file write `fhandle' "log using" (char(34))  "Fisherfolk_cleaning_project\Data\output\logs\var_label_cmd_ffx.smcl" (char(34)) ", replace"_n _n

file write `fhandle' "// read dataset" _n
*file write `fhandle' "use" (char(34))  "${raw_data}\adult_ffx_interview.dta" (char(34)) ", replace"_n _n
file write `fhandle' "use" (char(34))  "${raw_data}\adult_ffx_interview.dta" (char(34)) ", replace"_n _n


file write `fhandle' "/*!!!!!!!!!!!!!!!" _n
file write `fhandle' "replace null values with missing values to facilitate destringing of encoded categorical variables"_n
file write `fhandle' "this is because- missing values in database recorded as null which is different format from stata" _n
file write `fhandle' "*/" _n _n

file write `fhandle'  "foreach var of varlist _all {" _n
file write `fhandle' 	  _tab _tab _tab "cap replace " "\`var'" "=" (char(34))  (char(34)) " if "  "\`var'" "==" (char(34)) "---" (char(34)) _n
file write `fhandle'     _tab "}"_n
file write `fhandle' "*"_n _n

file close `fhandle'

// write  do file for labelling variables and values 

keep question_id module module_description label var_label ///
																					optionvalue ///
																				var_label_cmd ///
																				label_defn_cmd ///
																	         label_values_cmd ///
																			 position ///
																			 maxposition

bysort module (question_id optionvalue) : gen index=_n /*an index for each item within a module*/
sort module question_id optionvalue
bysort  question_id (optionvalue) : gen index2=_n /*an index for each item within a variable i.e. options*/
sort  question_id index index2


file open `fhandle' using "${scripts}\var_label_cmd_ffx.do", write text append
local lines = _N
forval i=1/`lines'{
	if (index[`i'])==1{
	    file write `fhandle' " " _n _n
		file write `fhandle'  " ************************************************************************************* " _n
		file write `fhandle' "*" (module[`i']) " : " (module_description[`i']) _newline
		file write `fhandle'  " ************************************************************************************* " _n _n
		}
	
	if (index2[`i'])==1{
		file write `fhandle' " " _n 
		file write `fhandle' " * "  (label[`i']) _n 
		file write `fhandle' "capture  " (var_label_cmd[`i']) _n
		}
	if (!missing(label_defn_cmd[`i']))& (index2[`i'])==1 {	
				file write `fhandle'  _tab _tab "capture  destring " (question_id[`i']) ", replace force " _n
			}
	if (!missing(label_defn_cmd[`i'])){	
				file write `fhandle'  _tab _tab (label_defn_cmd[`i']) _n
			}
	if (!missing(label_values_cmd[`i'])) & ((position[`i'])==(maxposition[`i'])){	
				file write `fhandle'  _tab _tab "capture  "  (label_values_cmd[`i']) _n
			}
}
file write `fhandle' "// save labbelled dataset" _n
file write `fhandle' "save" (char(34))  "Fisherfolk_cleaning_project\Data\labelled_data\data\adult_ffx_interview_labelled.dta" (char(34)) ", replace"_n _n

file write `fhandle' " " _n _n
file write `fhandle'  " ************************************************************************************* " _n
file write `fhandle' "*" "CLEAN-UP CODE"  _newline
file write `fhandle'  " ************************************************************************************* " _n _n
*file write `fhandle'  "capture macro drop _all" _n
file write `fhandle'  "capture log close" _n

file close `fhandle'
drop index*
clear all

*****END CODE TO CREATE DO FILES FOR LABELLING VARIABLES, LABELS AND ATTACHING NOTES **********
******************************************************************************************************************


//keep only relevant variables
use "${temp_data}\_ffx_dictionary_labelled"

drop options1 source optionvalue_original optionname_original labelvar position minposition maxposition value_label var_label_cmd ///
label_defn_cmd label_values_cmd

*save the clean and labelled dictionary both stata and csv formats
save "${clean_data}\ffx_dictionary_final", replace
export delimited using "${clean_data}\ffx_dictionary_final", replace

//just a comment
