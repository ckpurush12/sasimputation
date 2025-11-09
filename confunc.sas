/*--------------------------------------------------------------------------------**
** PROGRAM   : confunc.sas	
** PURPOSE   : Import the xlsx file to sas and create a report and output into pdf
**              
** PROGRAMMER:	Purushotaman kumar
** CREATED   :	22 Oct 2025
**
** INPUT     : example.sas
** OUTPUT    : example.sas	
** Description: FCMP function is used for creating and storing unique
                user define function and use in data step, Example shows
                how concatinate is used and created mysentences function
                which can be later called at any datastep with in sas session
                
**
**
** MODIFIED  :	n/a
** 
**--------------------------------------------------------------------------------**
** PROGRAMMED USING SAS VERSION 9.4
**--------------------------------------------------------------------------------***/

options cmplib=(work.functions);

PROC FCMP OUTLIB = work.functions.func;
function mySentence(legalName $, preferredName $, age, occupation $) $;
length sentence $200;
sentence = legalName || " is a " || age || "-year-old " || trim(occupation) ||
". ";
if legalName~=preferredName then sentence = trim(sentence) || ' ' || legalName
|| "prefers to be called '" || trim(preferredName) || ".'";
return (sentence);
ENDSUB;

data example;
input legalName : $10. preferredName : $10. age occupation $15.;
description=mySentence(legalName, preferredName, age, occupation);
datalines;
Jacob Jake 27 teacher
Jessica Jess 24 violinist
Michael Mike 26 scientist
Ross Ross 31 paleontologist
Rachel Rachel 29 waitress
Phoebe Phoebe 29 masseuse
Joey Joey 31 actor
Monica Monica 30 chef
;
run; proc print data=example;run;