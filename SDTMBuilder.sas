/**********************************************************************************
*  Program name     : SDTMbuilder.sas
*  Project          : Template
*  Protocol         : 
*  Written by       : Mark Boliek
*  Date of creation : xx/xx/xxxx
*  Description      : Utility macro to apply variable attributes from the specd
*                     into the SDTM data set
*  Macros called    : 
*  Input file       : an excel file with variable definitions
*  Output file      : SDTM data set with variable attributes from the spec -opptional supplemtal data set
*    
*  
*
*  Revision History :
*
*  Date      Author   Description of the change
**********************************************************************************/

%macro SDTMBuilder(
  domain=    ,  /*SDTM domain name found on specification mapping spreadsheet*/ 
  indata=    ,  /*final data set in program before building SDTM domain (should contain all SDTM and SUPP variables)*/
  outlib=sdtm,  /*out library for sdtm domain - default sdtm. ^^Suggest keep domains in SDTM^^*/
  dmlib=sdtm ,  /*library for dm domain if not sdtm - default sdtm  ^^Suggest keep domains in SDTM^^*/
  scrnfailkp=,  /*Y or N  Y=Keeps Screen failures N=Deletes Screen Failures*/
  supp=      ,  /*Y or N - will create supplemental data set if =Y*/
  prtDupkey= ,  /*Y or N - check if key variables can uniquely identify records*/
  debug=     ,  /*Y or N - will not delete datasets created by the macro in work(interactive) if =Y*/
  idvar=     ,  /*idvar to use for supplemental*/
  qeval=    ,    /*variable name used for QEVAL in supplemtal*/
  define =  &data_sdtm_def , /*setup full pathname for sdtm spec*/
  optimize=N,    /*Optimize variable length*/
  xpt=N         /*Create xpt fil in xpt folder*/   
);

/*Read in the SDTM mapping workbook (Study Specific).*/
libname excellib xlsx "&define.";

%let DM=%sysfunc(upcase(&domain));
%put &DM;

proc datasets lib=work memtype=data nolist;
   modify &indata;
      attrib _all_ format=;
      attrib _all_ informat=;
run;  

data re_name;
 set excellib.&DM;
   format _all_;
   informat _all_;
run;

proc sql noprint;
 select name into:varnam from sashelp.vcolumn
 where memname="RE_NAME" and varnum=1;

 select name into:keepnam separated by ' '
 from sashelp.vcolumn  
 where memname="RE_NAME" and varnum>1;
quit;

DATA _specsheet0(keep=A &keepnam);
   set re_name;
   format _all_;
   informat _all_;
   length A $25;
   A=strip(&varnam);
   if _n_ >=13 and upcase(A) not in ('','CONTENT') and L ne 'Y' then output;
RUN;

%put &keepnam;

%if &DM ne TI %then %do;
proc sql noprint;
 select A into:perm separated by ' ' from _specsheet0
 where upcase(G)="PERM";
 
 select A into:perm2 separated by ',' from _specsheet0
 where upcase(G)="PERM";
 
  select '_'||A into:permA separated by ' ' from _specsheet0
 where upcase(G)="PERM";
quit;

%put &perm;
%put &perm2;
%put &permA;
%end;


****Macro that converts all numeric in excel file data set to character for easier conversion*****;
%macro vars(dsn=,dsn2=);
  %let list=;
  %let type=;
  %let dsid=%sysfunc(open(&dsn));
  %let cnt=%sysfunc(attrn(&dsid,nvars));
   %do i = 1 %to &cnt;
    %let list=&list %sysfunc(varname(&dsid,&i));
    %let type=&type %sysfunc(vartype(&dsid,&i));
   %end;
  %let rc=%sysfunc(close(&dsid));

  data &dsn2(drop=
    %do i = 1 %to &cnt;
     %let temp=%scan(&list,&i);
       _&temp
    %end;);
   set &dsn(rename=(
    %do i = 1 %to &cnt;
     %let temp=%scan(&list,&i);
       &temp=_&temp
    %end;));
    %do j = 1 %to &cnt;
     %let temp=%scan(&list,&j);
     %if %scan(&type,&j) = N %then %do;
      &temp=put(_&temp,best8.);
     %end;
     %else %do;
      &temp=_&temp;
     %end;
    %end;
  run;
%mend vars;
****End macro for converting numerics from excel to character****;
%vars(dsn=_specsheet0, dsn2=_specsheetB);

data _specsheet1;
  length spec_name $10 spec_label $50 spec_type $20 display_format spec_origin $50 spec_core $10 text $100 sdtm_var $15;
  set _specsheetB;
  format _all_;
  informat _all_;
  spec_name      =strip(A);
  spec_label     =strip(B);
  spec_type      =strip(upcase(C));
  spec_length    =input(D,8.);
  spec_origin    =strip(F); 
  spec_core      =strip(G); 
  sdtm_var       =strip(I);
  spec_num       =input(J,8.);
  if spec_label='' and spec_type='' and spec_length=. then delete;
%***check for variable label length;
  if length(spec_label)>40 then do;
    text='WAR'||'NING: '||strip(spec_label)||"'s label has more than 40 characters";
    put text ;
  end;
%***check for variable name length;
  if length(spec_name)>8 then do;
    text='WAR'||'NING: Variable '||strip(spec_name)||"'s name has more than 8 characters";
    put text;
  end;
 %***check for variable type and convert into proper wording;
  if compress(upcase(spec_type)) in ('TEXT') then do;
    text='WAR'||'NING: Variable '||strip(spec_name)||"'s type is " ||strip(spec_type);
    put text ;
    spec_type = 'CHAR';
  end;
  else if compress(upcase(spec_type)) in ('INTEGER' 'FLOAT' 'DATE' 'TIME' 'DATE' 'DATETIME' 'NUMERIC') then do;
    text='WAR'||'NING: Variable '||strip(spec_name)||"'s type is " ||strip(spec_type);
    put text ;
    spec_type = 'NUM';
  end;
  if upcase(spec_type) = 'CHAR' then display_format = '';
  if upcase(spec_type) = 'NUM' then spec_length = 8;
  rank=_n_;
  drop A &keepnam;
run;

%**** Get rid of duplicate record ***;
proc sort data = _specsheet1;
  by spec_name rank;
run;

data _specsheet2;
  set _specsheet1;
  by spec_name rank;
  if first.spec_name;
run;

proc sort data = _specsheet2;
  by rank spec_name;
run;


/*Create each individual data sets that contain SDTM variables and SUPPLEMENTAL variables*/
proc sql noprint;
create table sdtm_&dm as
 select upcase(name) as spec_name length=10,* from sashelp.vcolumn     /* keep all variable names are upcase value*/
 where libname='WORK' and memname=upcase("&indata");
quit;

proc sort data=sdtm_&dm;
 by spec_name;
run;

proc sort data=_specsheet2;
 by spec_name;
run;

data _specsheet2 _suppsheet3;
 set _specsheet2;
 by spec_name;
  output _specsheet2;
 if sdtm_var='SUPP' then output _suppsheet3;
run;

proc sort data=_suppsheet3 out=type_supp(keep=spec_name sdtm_var spec_origin);
 by spec_name;
run;

****drop supp vars in final data set if exist***;
proc sql noprint;
 select spec_name into:dropsupp separated by ' '
  from _suppsheet3;

***get supplemental variable count if exist - this keys code to drop supp variables in parent***;
 select count(spec_name) into: suppcnt from _suppsheet3;
quit;

%if &dm=TS %then %do;
data sdtm_&dm;
 set sdtm_&dm;
 if name='TSSEQ' then type='num';
run;
%end;


*********************;
data sdtm_&dm;
 merge sdtm_&dm(in=a)
       type_supp;
 by spec_name;
 if a;
run;

data _diffsdtm;
  merge _specsheet2   (in=a) 
        sdtm_&dm       (in=b);
  by spec_name;
   if a;
/*  if (spec_label ne '' and label ne '') and spec_label ne label then do;*/
/*    put 'WAR' 'NING: The following variable labels are different ';*/
/*    put 'SPEC: ' spec_label= 'SDTM: ' label=;*/
/*  end;*/
  if (type ne '' and spec_type ne '') and upcase(type) ne spec_type then do;
    put 'WAR' 'NING: The following variable types are different ';
    put 'SPEC: ' spec_type= 'SDTM: ' type=;
  end;
  if (a and not b) and sdtm_var='SDTM' then do;
   put 'WAR' 'NING: Variable in SPEC but not in SDTM ';
   put 'SPEC: ' spec_name=;
  end;
/*  if (b and not a) and sdtm_var='' then do;*/
/*   put 'WAR' 'NING: Variable in SDTM but not in SPEC ';*/
/*   put 'SDTM: ' name=;*/
/*  end;*/
/*  if (spec_num ne . and varnum ne .) and spec_num ne varnum then do;*/
/*    put 'WAR' 'NING: The position number in SPEC is incorrect ';*/
/*    put  'SPEC: ' spec_num=  'SDTM: ' varnum=;*/
/*  end;*/
run;

/***Obtain dataset label, key vars, sort vars from CONTENT sheet***/
DATA _content (keep=A B C D E F G H I J K /*L*/);
   SET excellib.CONTENT;
   length A $25;
   A=strip(SDTM_Domain_Mapping_Specificatio);
   format _all_;
RUN;

%let domain=%upcase(&DM);

%global _SortVar _sSortVar;

data _null_;
  set _content(where=(A in ("&domain", "SUPP&domain")));
  length text $100;
  if A="&domain" then do;
  _Sorting_Var=translate(H, '', ',');
  _Key_Var=translate(G, '', ',');
   call symput('dslabel', strip(B));
   call symput('_SortVar', strip(_Sorting_Var));
   call symput('_keyVar', strip(_Key_Var));
   call symput('_class', strip(E));
   call symput('_dname', strip(A));
  end;
  if A="SUPP&domain" then do;
  _Sorting_Var=translate(H, '', ',');
  _Key_Var=translate(G, '', ',');
   call symput('sdslabel', strip(B));
   call symput('_sSortVar', strip(_Sorting_Var));
   call symput('_skeyVar', strip(_Key_Var));
  end;
   if length(A)>40 then do;
    text='WAR'||'NING: dataset label has more than 40 characters';
    put text ;
  end;
run;

%put &_keyvar;
%put &_SortVar;

/*Define attributes in a shell dataset*/
proc sql noprint;
    select count(distinct spec_name) into: nvar
    from _specsheet2;
quit;

%put &nvar;

proc sort data=_specsheet2;
 by rank;
run;

%do _i=1 %to &nvar;
  %local varName&_i varlabel&_i varFormat&_i varLength&_i varType&_i;
%end;

data _null_;
  set _specsheet2;
  rank = _n_;
  call symput(compress("varName"||put(rank, BEST.)), spec_name);
  call symput(compress("varlabel"||put(rank, BEST.)), spec_label);
  if not missing(display_format) then 
      call symput(compress("varFormat"||put(rank, BEST.)), display_format); 
  else call symput(compress("varFormat"||put(rank, BEST.)), "EMPTY");
  call symput(compress("varLength"||put(rank, BEST.)), put(spec_length, best.)); 
  call symput(compress("varType"||put(rank, BEST.)), spec_type);
run;

proc sql noprint;
  create table _ds   
  ( 
      &varname1. &vartype1. (&varlength1.) label = "%cmpres(&varlabel1.)" 
  
      %do _i = 2 %to &nvar.;
	
      , &&varname&_i &&vartype&_i (&&varlength&_i)
          %if %qupcase(&&varFormat&_i) ne %quote(EMPTY) %then %do;
              format = &&varFormat&_i 
          %end;
          label = "&&varlabel&_i" 
      %end;
    );
quit;

data _ds;
  length 
    %do _i = 1 %to &nvar.;
       %if %qupcase(&&vartype&_i) = %quote(CHAR) %then %do;
           &&varname&_i $&&varlength&_i    
       %end;
       %else %do;
           &&varname&_i &&varlength&_i
       %end;
    %end;
    ;
  set _ds;
  format 
    %do _i = 1 %to &nvar.;
       %if %qupcase(&&varFormat&_i) ne %quote(EMPTY) %then %do;
           &&varname&_i &&varFormat&_i 
       %end;
    %end;
  ;
run;


/*get variables to keep or drop - this only gets rid of extraneous variables such as temp variables, etc
  created in programming code - both SDTM and SUPP variables from specification are kept in this step*/

proc contents data= _ds out=_allVar noprint;
run;

data _allVar;
  set _allVar;
  name=compress(upcase(name));
run;

proc sql noprint;
  select name into: allVar
  separated by ' '
  from _allVar
  ;
quit;
    

proc contents data = &indata out=_allExist noprint;
run;

data _allExist;
  set _allExist;
  name=compress(upcase(name));
run;

proc sort data = _allVar(keep=name);
  by name;
run;

proc sort data = _allExist(keep=name);
  by name;
run;

data _dropvards;
  merge _allExist(in = a) _allvar(in = b);
  by name;
  if a and (not b);
run;

proc sql noprint;
  select count(*) into: __nvarToD
  from _dropvards
  ;
quit;

%if &__nvarToD. > 0 %then %do;
proc sql noprint;
  select name into: allToDrop
  separated by ' '
  from _dropvards
  ;
quit;

data _appendds;
  set &indata;
  drop &allToDrop.;
run;

%end;

%else %do;
data _appendds;
  set &indata;		
run;
%end;


%if &dm=TS %then %do;
data _appendds(drop=TSSEQ_);
 set _appendds(rename=(TSSEQ=TSSEQ_));
TSSEQ=input(TSSEQ_,best.);
run;
%end;


/*add attriburtes to the input data set*/
%let _varlenchk=%sysfunc(getoption(varlenchk));
options varlenchk=nowarn;
data _ds;
  set _ds _appendds;
run;
options varlenchk=&_varlenchk;

********* check to see if permissable variables are completely missing to Drop -- P21 check*******;

%if &DM ne TI %then %do;

%vars(dsn=_ds, dsn2=perm_chk);


data perm_chk2;
  set perm_chk;
  
%if &dm=IE %then %do;
 IEDY=1;
%end;
  
  array vars {*} &perm;
   do i = 1 to dim(vars);
   
   vars{i}=compress(vars{i});
  if vars{i} in ('', '.')   then vars{i}='0';else
      vars{i}='1';
  end;
run;

proc sql;
 create table perm_chk3 as
   select 'A' as bvar, &perm2 from perm_chk2;

select count(name) into:permcnt from sashelp.vcolumn
 where memname='PERM_CHK3' and upcase(name) ne 'BVAR';
 
select name into:pdset separated by ' ' from sashelp.vcolumn
 where memname='PERM_CHK3' and upcase(name) ne 'BVAR'; 
 
 quit;

%put &permcnt;
%put &pdset;

data begperm(drop=&permA);
 set PERM_CHK3 end=last;
 by bvar;

 
 array vars  {*} &perm;
 array varsn {*} &permA;
  do i=1 to dim(vars);
    if first.bvar then varsn{i} = input(vars{i},8.);
                  else varsn{i} + input(vars{i},8.);
                  
     vars{i}=strip(put(varsn{i},8.)); 
     
end;
 if last; 
run;

proc transpose data=begperm out=transperm;
 by bvar;
 var &perm;
run;
 
data dropnullperm;
 set transperm;
  if col1 ne '0' then delete;
 run;
 
 proc sql noprint;
  select count(_name_) into:dropit from dropnullperm;
 quit; 
 
 %if &dropit > 0 %then %do;
 proc sql;
  select _name_ into:dropNp separated by ' ' from dropnullperm;
 quit;
 
  %put &dropNp;
 %end; 
 %end; 

****solve issue 'NOBS not resolved';   
%let nobs=0;                           
********************create supplemental data set**********************;
%if &supp=Y %then %do;
proc sql noprint;
  select name into: suppVar separated by ' '
  from sdtm_&dm 
  where sdtm_var='SUPP';

  select count(name) into:seqno 
  from sashelp.vcolumn  
  where libname='WORK' and memname="_DS" and name=upcase("&idvar"); 

  select count(name) into:eval 
  from sashelp.vcolumn  
  where libname='WORK' and memname="_DS" and name=upcase("&qeval"); 
quit;

%put &suppvar;
%put &seqno;
%put &eval ;

%if &seqno>0 and &eval>0 %then %do;  
 data supp1(keep=studyid rdomain usubjid &idvar &suppvar &qeval);
  set _ds;
%end;%else
%if &seqno>0 and &eval=0 %then %do;  
 data supp1(keep=studyid rdomain usubjid &idvar &suppvar);
  set _ds;
%end;%else
%do;
 data supp1(keep=studyid rdomain usubjid &suppvar);
   set _ds;
%end;
   length RDOMAIN $2;
     RDOMAIN="&domain";
run;

proc sort data= supp1;
 %if &seqno>0 and &eval>0 %then %do;
  by studyid rdomain usubjid &idvar &qeval;
 %end;%else
 %if &seqno>0 and &eval=0 %then %do;
  by studyid rdomain usubjid &idvar;
 %end;%else
 %do;
  by studyid rdomain usubjid;
 %end;
 run;

proc transpose data=supp1 out=trans1(where=(col1 ne ''));
 %if &seqno>0 and &eval>0 %then %do;
  by studyid rdomain usubjid &idvar &qeval;
 %end;%else
 %if &seqno>0 and &eval=0 %then %do;
  by studyid rdomain usubjid &idvar;
 %end;%else
 %do;
  by studyid rdomain usubjid;
 %end;
  var &suppvar;
run;

proc sql noprint;
  create table supp2 as
   select a.*, b.spec_origin from trans1 a left join sdtm_&dm b
   on a._name_= b.spec_name;
 quit;

 proc sort data=supp2;
  by studyid rdomain usubjid;
 run;

 %let idval="&idvar";

 %vars(dsn=supp2, dsn2=supp2B);




 proc sql noprint;
  select count(*) into:nobs from supp2B;
 quit;

 %put &nobs;

 %if &nobs>0 %then %do;
 data supp&dm(keep=STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL);
  set supp2B;
   length IDVAR QNAM $8 IDVARVAL QLABEL QORIG $40 QVAL $200 QEVAL $100;
   QNAM =strip(_name_);
   QLABEL=strip(_label_);
   QVAL=strip(col1);
   if index(spec_origin,'CRF')>0        then QORIG='CRF';else
   if strip(upcase(spec_origin))= 'EDT' then QORIG='eDT';else
                                             QORIG=strip(spec_origin);

   %if &eval>0 %then %do;
    QEVAL=strip(&qeval);

    if QEVAL ne '' then do;
	   length VAR13 $8;
       VAR12=input(compress(QNAM,'','A'),8.);
       VAR13=compress(QNAM,'','D');

         if length(VAR13) = 8 then QNAM=strip(substr(VAR13,1,7))||'1';else
         if VAR12 =  . then QNAM=strip(VAR13)||'1';else
	     if VAR12 ne . then QNAM=strip(VAR13)||strip(put(VAR12+1,3.));   
    end;
   %end;

   %if &eval=0 %then %do;
    QEVAL=' ';
   %end;
   %if &seqno>0 %then %do;
    IDVAR=&idval;
    IDVARVAL=strip(&idvar);
   %end;
   %if &seqno=0 %then %do;
    IDVAR=' ';
    IDVARVAL=' ';
   %end;
run;

data supp&dm;
 retain STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL;
set supp&dm;
label STUDYID='Study Identifier'
      RDOMAIN='Related Domain Abbreviation'
	  USUBJID='Unique Subject Identifier'
	  IDVAR='Identifying Variable'
	  IDVARVAL='Identifying Variable Value'
	  QNAM='Qualifier Variable Name'
	  QLABEL='Qualifier Variable Label'
	  QVAL='Data Value'
	  QORIG='Origin'
	  QEVAL='Evaluator';
	  
	  
if upcase(QORIG)='ASSIGNED' then QEVAL='INVESTIGATOR';	  
run;

 proc sort data=supp&dm;
  by &_sSortVar. ;
 run;
%end;
%end;
***************************end create supplemental***********************;

/*Err0r Checking:Compare before and after applying attribute to check
  possible character value truncation*/

**** Obtain character variable list ***;
proc sql noprint;
  select spec_name into: _varlist separated by ' '
  from _specsheet2 
  where upcase(spec_type)='CHAR'
  ;
  select count(spec_name) into: _varnum
  from _specsheet2 
  where upcase(spec_type)='CHAR'
  ;
quit;

proc compare data=&indata compare=_ds noprint OUTNOEQUAL out=_difreslt;
  var &_varlist;
run;

%let mvar=0;
data _null_;
  set _difreslt end=eof;
  if eof then call symput("mvar",trim(left(put(_n_,8.))));
run;

%if &mvar ne 0 %then %do;
  data _null_;
    set _difreslt end=eof;
	length prnttxt $200;
	retain prnttxt '';
	array charvar{&_varnum} &_varlist.;
	%do _i=1 %to &_varnum.;
	  if index(charvar{&_i},'X')^=0 then do;
 		%let _varnm=%scan(&_varlist,&_i);
        if indexw(prnttxt,"&_varnm",', ')=0 then prnttxt=catx(', ',prnttxt,"&_varnm");
      end; 
	%end;
	if eof then call 
     symput('_errtxt','WAR'||'NING: following variables may be truncated: '||prnttxt);
  run;
  %put &_errtxt;
%end;
%*** End of Err0r Checking ***;

*---screening failure codes - to keep or delete screenfailures for any domain--*;
%if (&dm ne TA) and (&dm ne TE) and (&dm ne TI) and (&dm ne TS) and (&dm ne TV) %then %do;

%if %bquote(%upcase(&dm)) = DM %then %do;

   %if %upcase(&scrnfailkp)= N %then %do;  /****exclude screening ****/
      data _DS;
         set _DS;
         where armnrs ne 'SCREEN FAILURE';
      run;
	   %put ATTN: Screen failure deleted from &domain;
   %end;

   %if %upcase(&scrnfailkp)= Y %then %do;
       data _DS;
         set _DS;
      run;
	  %put ATTN: Screen failure kept in &domain;
   %end;

%end;
%else %do;

   %if  %bquote(%upcase(&dm)) ne DM and %upcase(&scrnfailkp)=N %then %do;

        data __mvnosf;
          set &dmlib..dm(keep = usubjid armcd armnrs);
          where armnrs ne 'SCREEN FAILURE';
          keep usubjid;
        run;
        
        proc sort data = __mvnosf;
          by usubjid;
        run;
         
        proc sort data = _DS;
          by usubjid;
        run;
        
        data _DS;
          merge _DS(in=a) __mvnosf(in=b);
          by usubjid;
          if a and b;
        run;
         
        
        %put ATTN: Screen failure deleted from &domain;
        
        proc datasets library=work nolist;
          delete __mvnosf;
        quit;

   %end;
   %else %if  %bquote(%upcase(&dm)) ne DM and %upcase(&scrnfailkp) = Y %then %do;

        %put ATTN: Screen failure kept in &domain;

        data __mvdm;
          set &dmlib..dm(keep = usubjid);
          keep usubjid;
        run;
        
        proc sort data = __mvdm;
          by usubjid;
        run;
         
        proc sort data = _DS;
          by usubjid;
        run;
        
        data _DS;
          merge _DS(in=a) __mvdm(in=b);
          by usubjid;
          if a and b;
        run;
        
        proc datasets library=work nolist;
          delete __mvdm;
        quit;
   %end;
%end;
%end;

%if &nobs>0 %then %do;
%if &supp=Y %then %do;
 proc sort data=_ds out=scrnfails(keep=usubjid) nodupkey; /*2019-06-28 upated by Js and kill merge more than one log issue*/
   by usubjid;
 run;

 proc sort data=SUPP&dm;
   by usubjid;
 run;

 data SUPP&dm;
  merge SUPP&dm(in=a)
        scrnfails(in=b);
  by usubjid;
  if a and b;
  run;
%end;
%end;
*******************************************************************************;

/******check if key variables can uniquely identify records******/ 

%if %qupcase(&prtDupkey) = %quote(Y) %then %do;
proc sort data=_ds out=_ds2 dupout=_ds_dup nodupkey;
  by &_keyVar;
run;

%put &_keyvar;

%let _ndup=0;
data _ds_dup;
  set _ds_dup end=eof;
  keep &_keyVar;
  if eof then call symput("_ndup",trim(left(put(_n_,8.))));
run;

%put &_ndup;
  
%let _warn=WAR;
%if &_ndup>0 %then %do;
%put &_warn.NING: &domain: Key variables can not uniquely identify record.;
proc printto print="&pgmsdtm.\&domain.0dup.lst" new;
title "Key variables can not uniquely identify record: &domain";
proc print data=_ds_dup;
run;
proc printto;
run;
title;
%end;

%end; %*** %if %qupcase(&prtDupkey) = %quote(Y);


***Set length of variables to spec length***;
data lengthvar;
 set _specsheet2;
 length lengthvar $20;
  if spec_type='CHAR' then lengthvar= spec_name||' $'||strip(put(spec_length,best.));
  if spec_type='NUM' then  lengthvar= spec_name||' 8.';
run;

proc sql noprint;
 select lengthvar into:len separated by ' '  from lengthvar ;
quit;

%put &len;

data _ds;
 length &len;
set _ds;
run;
 
***End set Length***;



*****OPTIMIZE LENGTH***********;
%macro LenReset(dset = , DropTEST = , DropEPOCH = , DROPVARS =);
*--- DropTEST = Y to leave --TEST, --TESTCD lengths to their default lengths ---;
*--- DropEPOCH = Y to leave EPOCH to default length ---;
*--- DROPVARS = space separated list of additional variables to not truncate ---;

%global lnr callm labelize;
 
proc sql noprint;
    create table cvars as
    select name
    from sashelp.vcolumn
    where libname = 'WORK'
      and memname = %upcase("&DSET")
      and type = 'char'
      %if &dropTest = Y %then %do;
          and not prxmatch('/TEST/i', name)
      %end;
      %if &dropEPOCH = Y %then %do;
          and not prxmatch('/EPOCH/i', name)
      %end;
  
      %if %length(&dropVars) > 0 %then %do;
          %let pattern = %sysfunc(prxparse(s/ /|/oi));
          %let dropvar2 = %sysfunc(prxchange(&pattern, -1, &dropvars));
          and not prxmatch("/&dropvar2/i", name)
      %end;
      ;
quit;
 
data _null_;
    set cvars end = eof;
 
    if _n_ = 1 then do;
        call execute('proc sql; create table lentest as ');
    end;
 
    call execute('  select max(length('||strip(name)||')) as len, "'||strip(name)||'" as name from &dset');
    if not eof then do;
        call execute('union all corr ');
    end;
 
    if eof then do;
        call execute('; quit;');
    end;
run;
 
proc sql noprint;
    create table meta as
    select v.name, type, length, len, label
    from sashelp.vcolumn v
    left join
         lentest l
    on v.name = l.name
    where libname = 'WORK'
      and memname = %upcase("&DSET")
 
    order by varnum
    ;
quit;
 
data lengths2;
    set meta;
    length ln callm labl $ 200;
    if len < length and not missing(len) then length = len;
    if type = 'char' then do;
        ln =  'Length '||strip(name)||' $ '||strip(put(length, 8.))||';';
    end;
    else do;
        ln = 'Length '||strip(name)||' '||strip(put(length, 8.))||';';
    end;
    callm = "call missing("||strip(name)||");";
    labl = "label "||strip(name)||"='"||strip(label)||"';";
run;
 
proc sql noprint;
  select ln into :lnr separated by ' '
    from lengths2
    ;
quit;
 
options varlenchk = nowarn;
%mend LenReset;

%if &optimize=Y %then %do;

  %LenReset(dset = _ds, DropTEST = N, DropEPOCH = N, DROPVARS =);
  
 data _ds;  
  &lnr;
 set _ds;
 run;
 
   %if &nobs>0 %then %do;
   %if &supp=Y %then %do;
     %LenReset(dset = supp&dm, DropTEST = N, DropEPOCH = N, DROPVARS =);
  
data supp&dm;  
  &lnr;
 set supp&dm;
 run;
 
   %end;
   %end;

%end;

**************END OPTIMIZE*******************;



/****** output SDTM domain and supplementals(if applicable)******/
proc sort data=_ds;
  by &_SortVar;
run;

%if &dm=TI %then %do;
data sdtm.TI(label="&dslabel.");
  set _ds;
run;
%end;
%else %if &dropit>0 %then %do;
data &outlib..&dm( drop=&dropNp label="&dslabel.");
  set _ds;
  %if &suppcnt>0 %then %do;
  drop &dropsupp;
  %end;
run;
%end;
%else %do;
data &outlib..&dm(label="&dslabel.");
  set _ds;
  %if &suppcnt>0 %then %do;
  drop &dropsupp;
  %end;
run;
%end;

%if &nobs>0 %then %do;
%if &supp=Y %then %do;
data &outlib..supp&dm(label="&sdslabel.");
retain STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL;
  length /*STUDYID $20*/ RDOMAIN $2 /*USUBJID $50*/;
  set supp&dm;
run;
%end;
%end;


******************Write xpt file*********************;
%if &xpt=Y %then %do;

libname _xptout sasv5xpt "&sdtmxptdir\%lowcase(&domain..xpt)" ;
   proc copy in=&outlib out=_xptout;
        select &dm;
   run ;
   
%if &nobs>0 %then %do;
%if &supp=Y %then %do;
libname _xptsupp sasv5xpt "&sdtmxptdir\%lowcase(supp&domain..xpt)" ;
   proc copy in=&outlib out=_xptsupp;
        select supp&dm;
   run ;
%end;
%end;   

%end;
******************end write xpt file******************;


/***used to debug in interactive mode***/
%if %qupcase(&debug)^=%quote(Y) %then %do;
proc datasets library=work memtype=data nolist;
Delete
 SDTM_&domain 
_ALLEXIST
_ALLVAR 
_APPENDDS 
_CONTENT
_DIFFSDTM 
_DIFRESLT
_DROPVARDS 
_DS
_DS2
_DS_DUP
_SPECSHEET0
_SPECSHEET1
_SPECSHEET2
_SPECSHEETB
SCRNFAILS
LENGTHVAR
RE_NAME
%if &nobs>0 %then %do;
%if %qupcase(&supp) = Y %then %do;
 delete SUPP1
        SUPP2
		SUPP2B
        TRANS1
        TYPE_SUPP
		_SUPPSHEET3;
%end;
%end;
%end;
run;
quit;
%mend SDTMBuilder;

**** END SDTM BUILDER ****;



****Example call****;
*%SDTMBuilder(
  domain= eg  ,/*SDTM domain name found on specification*/ 
  indata= eg_ ,/*final data set in program before building SDTM domain (should contain all SDTM, and SUPP variables(if applicable))*/
  outlib= work  ,  /*out library for sdtm domain - default sdtm. ^^Suggest keep domains in SDTM^^*/
  /*dmlib=    ,  /*library for dm domain if not sdtm - default sdtm  ^^Suggest keep domains in SDTM^^*/
  scrnfailkp=Y,/*Y or N  Y=Keeps Screen failures N=Deletes Screen Failures*/
  supp=Y      ,/*Y or N - will create supplemental data set if =Y*/
  prtDupkey=Y ,/*Y or N - check if key variables can uniquely identify records*/
  debug=Y     ,/*Y or N - will not delete datasets created by the macro if =Y*/
  idvar= egseq,/* idvar to use for supplemental*/ 
  qeval=egeval)/*variable name used for QEVAL in supplemtal*/ 
;

 

