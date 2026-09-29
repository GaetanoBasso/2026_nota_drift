	
clear
cap log close

* --- Log file --- *
log using ${log}/log_cr_dataset_ea.txt, t replace

* Dati CNQ Eurostat
use anno trim wageHT* compHT* deflT* clupHT* using ${source_na}/CN_dataset_dest.dta, clear
keep anno trim *DE *IT *FR *ES *NL *EA
gen int year    = round(anno)
gen int quarter    = round(trim)
gen int timeq = yq(year, quarter)
format timeq %tq
drop anno trim
reshape long wageHT compHT deflT clupHT, j(geo) i(timeq year quarter) string
rename *T *
tempfile cnq_ea
save `cnq_ea'

* Dati contrattuali ECB pubblici PNA
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
reshape long ELEEURMWH, i(timeq) j(geo) string
gen year=year(dofq(timeq))
gen quarter=quarter(dofq(timeq))
tempfile prices
save `prices'

* Merge
use `cnq_ea', clear
merge 1:1 timeq geo using `prices', nogen
merge 1:1 timeq geo using `contr_ea', nogen
encode geo, gen(geocode)
xtset geocode timeq
foreach v of varlist wageH compH defl clupH {
	gen _`v' = 100*`v'/l4.`v'-100 if _n>4
	drop `v'
	rename _`v' `v'
}

* Save dataset
order timeq year quarter geo geocode contr
compress
save ${home}/data/dataset_ea.dta, replace

log close


