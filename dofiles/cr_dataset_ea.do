	
clear
cap log close

* --- Log file --- *
log using ${log}/log_cr_dataset_ea.txt, t replace

* Dati CNQ Eurostat
use anno trim wageHT* compHT* deflT* clupHT* vaghT* occP* using ${source_na}/CN_dataset_dest.dta, clear
keep anno trim *DE *IT *FR *ES *NL *BE *EA
gen int year    = round(anno)
gen int quarter    = round(trim)
gen int timeq = yq(year, quarter)
format timeq %tq
drop anno trim
reshape long wageHT compHT deflT clupHT vaghT occP, j(geo) i(timeq year quarter) string
rename *T *
tempfile cnq_ea
save `cnq_ea'

/*
* Dati contrattuali ECB pubblici PNA - versione mensile (sostituita dal download trimestrale sotto)
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
encode geo, gen(geocode)
xtset geocode timeq
foreach v of varlist wageH compH defl clupH { 
	gen _`v' = 100*`v'/l4.`v'-100 if _n>4
	drop `v'
	rename _`v' `v'
}
xtset
gen _vagh = 100*vagh/l.vagh-100 if _n>1
drop vagh
rename _vagh vagh


* Save dataset
order timeq year quarter geo geocode contr
compress
save ${home}/data/dataset_ea.dta, replace

log close


