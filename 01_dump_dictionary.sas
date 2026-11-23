/* ===========================================================================
   01_dump_dictionary.sas

   Ticket 01, mechanical half. Reads SAS's own metadata and emits one flat,
   pipe-delimited file of every column of every table in the libraries you name.
   Output is formatted here; the per-table Markdown files are assembled from it
   afterwards, so nobody hand-types a column list.

   METADATA ONLY. This reads DICTIONARY.COLUMNS and DICTIONARY.TABLES. It reads
   no observations, returns no values, and prints no customer data.

   HOW TO RUN
     1. Open a SAS session where the libraries you want to document are already
        assigned (LIBNAME statements already run, or auto-assigned).
     2. Edit LIBREFS and OUTDIR below. LIBREFS must be UPPERCASE, comma-separated,
        each in single quotes.
     3. Submit. Then send dictionary/_raw/metadata.txt onward.

   NOTES
     - Only librefs in the list are included; WORK and SASHELP are excluded
       unless you ask for them.
     - A table that exists in two librefs appears twice, once per libref. That is
       deliberate: two copies that disagree is a finding.
     - Put the list of tables you actually want in PILOT-TABLES.md BEFORE running
       this. Extracting the whole warehouse is cheap but useless.
   =========================================================================== */

/* --- edit these two lines ------------------------------------------------- */
%let librefs = 'DWH','CUST','MKT';
%let outdir  = C:\Users\hwyun\Documents\deepseek-harness\scb-ra-campaign\dictionary\_raw;

%let outfile = &outdir.\metadata.txt;

%put NOTE: [01] librefs requested: &librefs.;
%put NOTE: [01] writing to: &outfile.;

/* Create the output directory if it is missing. */
options dlcreatedir;

proc sql;
  create table work.dd_metadata as
  select  c.libname,
          c.memname,
          t.memlabel,
          t.nobs,
          c.varnum,
          c.name,
          c.type,
          c.length,
          c.format,
          c.informat,
          c.label
  from    dictionary.columns as c
  left join dictionary.tables as t
    on    c.libname = t.libname
    and   c.memname = t.memname
    and   t.memtype = 'DATA'
  where   c.libname in (&librefs.)
    and   c.memtype = 'DATA'
  order by c.libname, c.memname, c.varnum;
quit;

/* Header, written by itself so the data rows below control their own quoting. */
data _null_;
  file "&outfile.";
  put 'libname|memname|memlabel|nobs|varnum|name|type|length|format|informat|label';
run;

/* Data rows. DSD quotes any value containing the delimiter. */
data _null_;
  length libname memname $32 memlabel $256 name $32 type $1 format informat $32 label $256;
  set work.dd_metadata;
  file "&outfile." dsd dlm='|' mod;
  put libname memname memlabel nobs varnum name type length format informat label;
run;

/* What did we actually get? If these counts look wrong, the librefs are wrong. */
proc sql noprint;
  select count(distinct catx('.', libname, memname)),
         count(*)
    into :n_tab trimmed,
         :n_col trimmed
  from work.dd_metadata;
quit;

%put NOTE: [01] extracted &n_tab. tables and &n_col. columns.;

/* Sanity check: tables found in the requested libraries. */
proc sql;
  select libname, count(distinct memname) as tables
  from work.dd_metadata
  group by libname;
quit;
