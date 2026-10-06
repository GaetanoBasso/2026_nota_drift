
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
* lp_outcomes : variabili di risposta (var. % tendenziali; occH: var. % congiunturale delle ore
*               lavorate; dur: differenza congiunturale del tasso di disoccupazione)
* lp_controls : controlli macro come in Corsello e Foschi (2026), inclusi con $lp_lags ritardi:
*               log produzione industriale, tasso di disoccupazione, rendimento Bund 1 anno
* lp_panel    : paesi del panel (EA esclusa: è l'aggregato degli altri);
*               le stime panel sono ponderate per gli occupati medi del paese (occP)
* lp_ivshocks : prezzi strumentati nelle LP-IV su serie storiche (an_lpiv_energy_ea.do)
* lp_ivinstr  : strumenti, nello stesso ordine di lp_ivshocks: shock di offerta di petrolio
*               di Mori e Peersman (oilMP), shock di offerta di gas di Alessandri e Gazzani (gasAG);
*               nella specificazione di base si usano i 3 shock mensili del trimestre come
*               strumenti separati (oilMP1-oilMP3, gasAG1-gasAG3), nella variante qsum la
*               loro media trimestrale
* lp_ivweakF  : soglia del F di 1° stadio (Kleibergen-Paap) sotto cui lo strumento è segnalato
*               come debole nel log
global lp_lags     = 4
global lp_shocks   "OilSpotUSDBarrel TTFSpotEURMWH ELEEURMWH"
global lp_outcomes "contr hicp wageH occH dur"
global lp_controls "lip ur bund1y"
global lp_panel    "DE IT NL ES FR BE"
global lp_ivshocks "OilSpotUSDBarrel TTFSpotEURMWH"
global lp_ivinstr  "oilMP gasAG"
global lp_ivweakF  = 10

*******************************************************************************
* 1) CREAZIONE DATASET
*******************************************************************************

* Dataset panel trimestrale: CN Eurostat, retribuzioni contrattuali BCE, HICP, controlli macro, prezzi energetici
do ${do}/cr_dataset_ea.do

*******************************************************************************
* 2) ANALISI
*******************************************************************************

* Local Projections (Jordà, 2005) OLS: shock dei prezzi energetici su retribuzioni e prezzi; robustezza
* (disattivate: per rieseguirle togliere i delimitatori di commento qui sotto)
/*
do ${do}/an_lp_energy_ea.do
*/

* Local Projections con variabili strumentali (serie storiche): petrolio strumentato con Mori-Peersman, gas con Alessandri-Gazzani
do ${do}/an_lpiv_energy_ea.do
