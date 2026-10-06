
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
global countries "DE IT NL ES FR BE EA"

* --- Parametri dell'esercizio ------------------------------------------------
* hmax      : orizzonte massimo in trimestri rispetto all'ultimo disponibile
* oos_start : primo forecast origin della valutazione ricorsiva
* minobs    : numero minimo di osservazioni per stimare un modello
* covid_dum : 1 = include tra i controlli delle LP una dummy per 2020q1-2022q4
global hmax      = 12
global oos_start = tq(1995q1)
global covid_dum = 1

* --- Parametri delle Local Projections (an_lp_energy_ea.do) ------------------
* lp_lags     : numero di ritardi di outcome e shock inclusi come controlli
* lp_shocks   : prezzi energetici (var. % tendenziali); lo shock è scalato a 10 pp
* lp_outcomes : variabili di risposta (var. % tendenziali)
* lp_controls : controlli macro come in Corsello e Foschi (2026), inclusi con $lp_lags ritardi:
*               log produzione industriale, tasso di disoccupazione, rendimento Bund 1 anno
* lp_panel    : paesi del panel (EA esclusa: è l'aggregato degli altri);
*               le stime panel sono ponderate per gli occupati medi del paese (occP)
global lp_lags     = 4
global lp_shocks   "OilSpotUSDBarrel TTFSpotEURMWH ELEEURMWH"
global lp_outcomes "contr hicp wageH compH"
global lp_controls "lip ur bund1y"
global lp_panel    "DE IT NL ES FR BE"

*******************************************************************************
* 1) CREAZIONE DATASET
*******************************************************************************

* Dataset panel trimestrale: CN Eurostat, retribuzioni contrattuali BCE, HICP, controlli macro, prezzi energetici
do ${do}/cr_dataset_ea.do

*******************************************************************************
* 2) ANALISI
*******************************************************************************

* Local Projections (Jordà, 2005): shock dei prezzi energetici su retribuzioni e prezzi; robustezza
do ${do}/an_lp_energy_ea.do
