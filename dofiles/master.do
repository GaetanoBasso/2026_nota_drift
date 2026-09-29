
clear all
set more off
version 18.0

cap log close

*******************************************************************************
* 0) SETUP E PARAMETRI
*******************************************************************************

* --- Cartelle ---
if `"`c(os)'"' == "Windows" 		global   stem   `"//osiride-fs/group/main/892fl"'
if `"`c(os)'"' == "Unix" 		global   stem   `"/home/group/main/892fl"'

global source_contr  "${stem}/dati/ecb/contrattuali/dta"
global source_na  "${stem}/dati/eurostat/conti_naz_europei/CN_Q/dta"
global home    "${stem}/policy/2026/2026_nota_drift"
global out     "${home}/output"
global gph     "${home}/graphs"
global do     "${home}/dofiles"
global log     "${home}/logfiles"
global data     "${home}/data"

capture mkdir "$out"
capture mkdir "$gph"
capture mkdir "$log"
capture mkdir "$data"

* --- Paesi analizzati ---
global countries "DE IT NL ES FR EA"

* --- Parametri dell'esercizio ------------------------------------------------
* hmax      : orizzonte massimo in trimestri rispetto all'ultimo disponibile
* oos_start : primo forecast origin della valutazione ricorsiva
* minobs    : numero minimo di osservazioni per stimare un modello
* covid_dum : 1 = include una dummy per i mesi di lockdown nelle stime in-sample
global hmax      = 12
global oos_start = tm(1995q1)


