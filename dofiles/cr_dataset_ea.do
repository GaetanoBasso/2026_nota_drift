	
clear
cap log close

* --- Log file --- *
log using ${log}/log_cr_dataset_ea.txt, t replace

* Dati CNQ Eurostat
use anno trim wageHT* compHT* deflT* clupHT* vaghT* occPT* occHT* using ${source_na}/CN_dataset_dest.dta, clear
keep anno trim *DE *IT *FR *ES *NL *BE *EA
gen int year    = round(anno)
gen int quarter    = round(trim)
gen int timeq = yq(year, quarter)
format timeq %tq
drop anno trim
reshape long wageHT compHT deflT clupHT vaghT occPT occHT, j(geo) i(timeq year quarter) string
rename *T *
tempfile cnq_ea
save `cnq_ea'

/*
* Dati contrattuali ECB ristretti Totale economia - versione mensile (sostituita dal download trimestrale sotto)
use anno month EA_INWR ES IT FR NL DE_INWR using ${source_contr}/dati_retr_pubblici_1.dta, clear
gen int year    = round(anno)
gen int quarter = ceil(month / 3)
gen int timeq = yq(year, quarter)
format timeq %tq
foreach v in EA_INWR ES IT FR NL DE_INWR {
	rename `v' contr`v'
}
rename *_INWR *
reshape long contr, j(geo) i(timeq year quarter anno month) string
collapse (mean) contr, by(year quarter timeq geo*)
tempfile contr_ea
save `contr_ea'
*/

* Dati contrattuali ECB (INWR, trimestrali) scaricati con getTimeSeries; tassi di crescita annuali
* EA IT ES NL BE: senza restrizioni particolari (isid sotto verifica una sola serie per paese); DE e FR: prediligo le fonti nazionali a ECB
clear
getTimeSeries ECB_RESTR INW/....... "" "" 0 0
rename *,l
split tsname, p(".")
rename tsname2 freq
rename tsname5 withwithoutoneoff
rename tsname6 sector
rename tsname7 provider
rename tsname8 measure
keep if freq=="Q"
drop tsname
rename tsname3 geo 
replace geo="EA" if geo=="I10"
keep if inlist(geo, "EA", "DE", "IT", "ES", "NL", "FR", "BE")
assert inlist(geo, "EA", "DE", "IT", "ES", "NL", "FR", "BE")
replace date=subinstr(date,"-"," ",.)
gen year=real(word(date,1))
replace date=subinstr(date,"Q","",.)
gen quarter=real(word(date,2))
drop date
gen int timeq = yq(year, quarter)
format timeq %tq
rename value contr
keep if withwithoutoneoff=="INWR"
keep if sector=="000000"
keep if measure=="GY"
drop if provider!="FR2"&geo=="FR"
drop if provider!="DE2"&geo=="DE"
keep timeq year quarter geo contr
isid geo timeq
save ${data}/ecb_inwr_q.dta, replace
tempfile contr_ea
save `contr_ea'

* Dati IPCA vari paesi
clear
getTimeSeries EUROSTAT PRC_HICP_MIDX/.I15.CP00.DE+FR+NL+IT+ES+BE+EA20 "" "" 0 0
rename *, low replace
replace tsname=subinstr(tsname,"."," ",.)
gen country=word(tsname,5)
replace date=subinstr(date,"-"," ",.)
gen anno=real(word(date,1))
gen mese=real(word(date,2))
drop date tsname
reshape wide value, i(anno mese) j(country) string
rename value* hicp_*
gen mdate=ym(anno, mese)
format mdate %tm 
gen dd=dofm(mdate)
format dd %td
gen trim=quarter(dd)
egen ctrlm=max(mese), by(anno trim)
drop if ((trim==1 & ctrlm!=3) | (trim==2& ctrlm!=6) | (trim==3 & ctrlm!=9) | (trim==4 & ctrlm!=12))
sort anno 
rename hicp_EA20 hicp_EA
collapse (mean) hicp_DE hicp_EA hicp_ES hicp_FR hicp_IT hicp_NL hicp_BE, by (anno trim)
reshape long hicp_, i(anno trim) j(geo) string
rename hicp_ hicp
rename anno year
rename trim quarter
gen int timeq = yq(year, quarter)
format timeq %tq
encode geo, gen(x)
xtset x timeq
gen _hicp = 100*hicp/l4.hicp-100 if _n>4
drop hicp
rename _hicp hicp
xtset, clear
drop x 
save ${data}/eurostat_hicp_ea_q.dta, replace
tempfile hicp_ea
save `hicp_ea'

* Dati mensili Eurostat aggiuntivi: HICP core, produzione industriale, tasso di disoccupazione
* hicpx: HICP esclusi energia, alimentari, alcol e tabacchi (indice 2015=100, non destagionalizzato, come hicp)
* ip   : produzione industriale B-D, dest. e corretta per i giorni lavorativi (indice 2021=100)
* ur   : tasso di disoccupazione, destagionalizzato, % forze di lavoro
local k_hicpx "PRC_HICP_MIDX/M.I15.TOT_X_NRG_FOOD"
local k_ip    "STS_INPR_M/M.PRD.B-D.SCA.I21"
foreach v in hicpx ip {
	clear
	getTimeSeries EUROSTAT `k_`v''.DE+FR+NL+IT+ES+BE+EA20 "" "" 0 0
	rename *, low replace
	gen geo = word(subinstr(tsname, ".", " ", .), -1)
	replace geo = "EA" if geo == "EA20"
	replace date = subinstr(date, "-", " ", .)
	gen year = real(word(date, 1))
	gen quarter = ceil(real(word(date, 2))/3)
	* solo trimestri completi (3 mesi disponibili)
	egen nm = count(value), by(geo year quarter)
	keep if nm == 3
	collapse (mean) value, by(geo year quarter)
	gen int timeq = yq(year, quarter)
	format timeq %tq
	rename value `v'
	keep timeq geo `v'
	isid geo timeq
	tempfile `v'_ea
	save ``v'_ea'
}

local v ur
clear
getTimeSeries EUROSTAT UNE_RT_M/M.SA.TOTAL.PC_ACT.T. "" "" 0 0
rename *, low replace
gen geo = word(subinstr(tsname, ".", " ", .), -1)
replace geo = "EA" if geo == "EA21"
keep if inlist(geo, "EA", "DE", "IT", "ES", "NL", "FR", "BE")
replace date = subinstr(date, "-", " ", .)
gen year = real(word(date, 1))
gen quarter = ceil(real(word(date, 2))/3)
* solo trimestri completi (3 mesi disponibili)
egen nm = count(value), by(geo year quarter)
keep if nm == 3
collapse (mean) value, by(geo year quarter)
gen int timeq = yq(year, quarter)
format timeq %tq
rename value `v'
keep timeq geo `v'
isid geo timeq
tempfile `v'_ea
save ``v'_ea'

* Rendimento del Bund a 1 anno (Bundesbank: struttura per scadenza dei titoli federali,
* metodo Svensson, vita residua 1 anno, dati mensili), comune a tutti i paesi
* Serie BBSIS.M.I.ZST.ZI.EUR.S1311.B.A604.R01XX.R.A.A._Z._Z.A; se il download diretto è
* bloccato, scaricarla da https://www.bundesbank.de/en/statistics/money-and-capital-markets/interest-rates-and-yields
import delimited using "https://api.statistiken.bundesbank.de/rest/download/BBSIS/M.I.ZST.ZI.EUR.S1311.B.A604.R01XX.R.A.A._Z._Z.A?format=csv&lang=en", varnames(nonames) delimiters(",") stringcols(_all) clear
keep if ustrregexm(v1, "^[0-9]{4}-[0-9]{2}$")
gen year = real(substr(v1, 1, 4))
gen quarter = ceil(real(substr(v1, 6, 2))/3)
gen bund1y = real(v2)
egen nm = count(bund1y), by(year quarter)
keep if nm == 3
collapse (mean) bund1y, by(year quarter)
gen int timeq = yq(year, quarter)
format timeq %tq
keep timeq bund1y
isid timeq
tempfile bund
save `bund'

* Shock di offerta di gas (Alessandri e Gazzani, 2025, Journal of Monetary Economics 151, 103749),
* foglio "2025update" del file GasSupplyShocks.xlsx (Dropbox, dl=1 per il download diretto);
* serie mensile, comune a tutti i paesi: prima colonna data, seconda colonna shock
tempfile agf
local agf "`agf'.xlsx"
copy "https://www.dropbox.com/scl/fi/60tlgoqhahodhfpgxr096/GasSupplyShocks.xlsx?rlkey=lsxpghuwbyd7sn8mia59a2uaf&dl=1" "`agf'", replace
import excel using "`agf'", sheet("2025update") firstrow clear
describe
qui ds
tokenize `r(varlist)'
rename `1' date
rename `2' gasAG
cap confirm numeric variable date
if !_rc gen timem = mofd(date)
else gen timem = monthly(date, "YM")
keep if !missing(gasAG)
assert !missing(timem)
gen timeq = qofd(dofm(timem))
collapse (mean) gasAG, by(timeq)
format timeq %tq
isid timeq
tempfile gasag
save `gasag'

* Shock di offerta di petrolio (Mori e Peersman), colonna "Updated sample 2025m12" del foglio Google
* (esportato in csv); serie mensile, comune a tutti i paesi: prima colonna data
tempfile mpf
local mpf "`mpf'.csv"
copy "https://docs.google.com/spreadsheets/d/10tkAw-C5LOBr6MHTQITpTcXIryXb12Ul/export?format=csv&gid=207083778" "`mpf'", replace
import delimited using "`mpf'", varnames(1) clear
describe
local mp ""
foreach v of varlist _all {
	local lab : variable label `v'
	if strtrim("`lab'") == "Updated sample 2025m12" | lower("`v'") == "updatedsample2025m12" local mp "`v'"
}
assert "`mp'" != ""
qui ds
tokenize `r(varlist)'
rename `1' date
rename `mp' oilMP
cap confirm numeric variable oilMP
if _rc destring oilMP, replace force
cap confirm numeric variable date
if !_rc gen timem = mofd(date)
else gen timem = monthly(date, "YM")
keep if !missing(oilMP)
assert !missing(timem)
gen timeq = qofd(dofm(timem))
collapse (mean) oilMP, by(timeq)
format timeq %tq
isid timeq
tempfile oilmp
save `oilmp'

* Dati shock prezzi energetici
import excel ${home}/rawdata/Data_OIL_ELE_GAS.xlsx, clear first
destring _all, replace
gen timem=monthly(Date,"YM")
drop if timem==.
format timem %tm
drop Date
gen timeq=qofd(dofm(timem))
collapse (mean) Oil* TTF* ELE*, by(timeq)
format timeq %tq
tsset timeq
foreach v of varlist Oil* TTF* ELE* {
	gen _`v' = 100*`v'/l4.`v'-100 if _n>4
	drop `v'
	rename _`v' `v'
}
rename ELE_GermanyEURMWH ELEEURMWHDE
rename ELE_FranceEURMWH ELEEURMWHFR
rename ELE_ItalyEURMWH ELEEURMWHIT
rename ELE_SpainEURMWH ELEEURMWHES
rename ELE_NetherlandsEURMWH ELEEURMWHNL
* BE: prezzo elettrico non presente nel file Excel (colonna attesa: ELE_BelgiumEURMWH)
cap confirm var ELE_BelgiumEURMWH
if !_rc rename ELE_BelgiumEURMWH ELEEURMWHBE
else gen ELEEURMWHBE = .
gen ELEEURMWHEA = .	// EA senza prezzo elettrico: serve per avere Oil e TTF anche per EA
reshape long ELEEURMWH, i(timeq) j(geo) string
gen year=year(dofq(timeq))
gen quarter=quarter(dofq(timeq))
tempfile prices
save `prices'

* Merge
use `cnq_ea', clear
merge 1:1 timeq geo using `prices', nogen
merge 1:1 timeq geo using `contr_ea', nogen
merge 1:1 timeq geo using `hicp_ea', nogen
foreach v in hicpx ip ur {
	merge 1:1 timeq geo using ``v'_ea', nogen
}
merge m:1 timeq using `bund', nogen keep(master match)
merge m:1 timeq using `gasag', nogen keep(master match)
merge m:1 timeq using `oilmp', nogen keep(master match)
* Anno e trimestre anche per le righe aggiunte dai merge
replace year = year(dofq(timeq))
replace quarter = quarter(dofq(timeq))
encode geo, gen(geocode)
xtset geocode timeq
foreach v of varlist wageH compH defl clupH hicpx { 
	gen _`v' = 100*`v'/l4.`v'-100 if _n>4
	drop `v'
	rename _`v' `v'
}
xtset
gen _vagh = 100*vagh/l.vagh-100 if _n>1
drop vagh
rename _vagh vagh
* Ore lavorate, totale economia: var. % congiunturale
gen _occH = 100*occH/l.occH-100 if _n>1
drop occH
rename _occH occH
* Tasso di disoccupazione: differenza congiunturale (il livello ur resta tra i controlli)
gen dur = ur - l.ur
* Logaritmo della produzione industriale
gen lip = ln(ip)
drop ip


* Save dataset
order timeq year quarter geo geocode contr
compress
save ${home}/data/dataset_ea.dta, replace

log close


