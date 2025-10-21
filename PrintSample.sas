/* Selection options are FIRST (first rows) or RANDOM (random sample) */
%let selection=Random;

/* GET TOTAL ROW COUNT FROM TABLE */
	
	proc sql noprint;
	    select count(*) format=comma15. into :N from sashelp.heart;
	quit;

/* SELECT FIRST 20 ROWS */
%if &selection=FIRST %then %do;
	title1 color="#545B66" "Sample from SASHELP.heart";
	title2 height=3 "First 20 of &N Rows";
	data sample;
	    set sashelp.heart(obs=20);
	run;
%end;

/* SELECT RANDOM SAMPLE OF 20 ROWS */

%else %do;
	title1 color="#545B66" "Sample from SASHELP.heart";
	title2 height=3 "Random Sample 20 of &N Rows";
	
	proc surveyselect data=sashelp.heart
	                  method=srs n=20
	                  out=sample noprint;
	run;  
%end; 

/* PRINT SAMPLE */

	footnote height=3 "Created %sysfunc(today(),nldatew.) at %sysfunc(time(), nltime.)";
	proc print data=sample noobs;
	run;
	title;
	footnote;

/* END */
