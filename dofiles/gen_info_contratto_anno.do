***************************************************************************
* ESTRAI INFO SULLA CONTRATTAZIONE COLLETIVA A LIVELLO DI CONTRATTOxMESE
* - Archivio dei minimi BdI 
* - Archivio dei rinnovi BdI 
* - Indice delle retribuzioni contrattuali e LOIC Istat
* - Dataset da unire alle 24 date 
***************************************************************************

clear all 
set more off 
cap log close




 

global pgm  "/home/group/main/892fl/policy/2024/2024_QEF_contrattazione/dofiles"
do "${pgm}/AA_set_seeds_define_paths.do"

global contratti_bdi eme ems alim tec pec conc cal leg cct gra pet ch got vet cer lat cem lap mtm fiat ele gas cos ///
                     co dmo far fs frc auc trm atr tma pts rec szz sfs sca nol por alb pue quo gio rtv cte cre ass stp vp pul ipl ipr ssl ssu lav
global anno_inizio 2000
global anno_fine   2025 		     
		   
* archivio dei minimi - estrai medie annuali per (contratto,anno)
use "${data}/dataset_archivio_minimi.dta", clear 
drop if inlist(ccnl,"ind","ser")
keep if inrange(anno,${anno_inizio},${anno_fine})
gen primo_anno_archivio_minimi=year(dofm(first_ccnl))
preserve 
	collapse (mean) minmin mintot maxmin maxtot,  by(anno ccnl) 
	rename ccnl sigla_bdi 
	save   "${data}/minimi_euro_by_ccnl_anno.dta", replace  
restore
        collapse (first) primo_anno_archivio_minimi, by(ccnl)
	rename ccnl sigla_bdi
save    "${data}/minimi_primo_anno_by_ccnl_anno.dta", replace 	
 
* archivio dei rinnovi - estrai importo complessivo annuale unatantum 
use "${data}/dataset_unatantum.dta", clear 
keep contratto anno_unatantum_p importo_unatantum_p 
keep if !mi(anno_unatantum_p) & inrange(anno_unatantum_p,${anno_inizio},${anno_fine})
rename (contratto anno_unatantum_p importo_unatantum_p) (sigla_bdi anno importo_unatantum)
collapse (sum) importo_unatantum, by(sigla_bdi anno)
save    "${data}/unatantum_by_ccnl_anno.dta", replace

*archivio dei rinnovi - classifica ogni anno del ciclo di vita del contratto 
use  "${data}/dataset_rinnovi.dta", clear
keep if inrange(anno_stipula,${anno_inizio},${anno_fine}) 
keep contratto data_stipula data_al  
gen exp = data_al-data_stipula+1
expand exp 
drop exp 
bys contratto data_stipula data_al: gen data=data_stipula+(_n-1)
format data %tm 
gen stipula  = (data == data_stipula)
gen scadenza = (data == data_al)
gen mesi_dal_rinnovo=data-data_stipula
gen mesi_alla_scadenza=data_al-data

collapse (max) stipula scadenza (first) data_stipula data_al mesi_dal_rinnovo mesi_alla_scadenza, by(contratto data)
gen contratto_in_vigore = 1

preserve
  bys contratto: egen min_data_stipula=min(data_stipula)
  keep if data_stipula==min_data_stipula 
  duplicates drop contratto, force 
  keep contratto data_stipula 
  gen exp = ym(2024,12)-data_stipula+1
  expand exp 
  drop exp  
  bys contratto data_stipula: gen data=data_stipula+(_n-1)
  format data %tm
  keep contratto data 
tempfile tofill 
save    `tofill', replace 
restore

merge 1:1 contratto data using `tofill'
replace contratto_in_vigore=0 if _merge == 2
replace stipula            =0 if _merge == 2
replace scadenza           =0 if _merge == 2 
drop _merge 

bys contratto (data): carryforward data_al, gen(temp)
gen mesi_dalla_scadenza=data-temp if contratto_in_vigore == 0

gen     status_contratto = 0 if contratto_in_vigore == 1 & mesi_dal_rinnovo <  mesi_alla_scadenza & !mi(mesi_dal_rinnovo) & !mi(mesi_alla_scadenza)
replace status_contratto = 1 if contratto_in_vigore == 1 & mesi_dal_rinnovo >= mesi_alla_scadenza & !mi(mesi_dal_rinnovo) & !mi(mesi_alla_scadenza)
replace status_contratto = 2 if contratto_in_vigore == 0 & mesi_dalla_scadenza < 12
replace status_contratto = 3 if contratto_in_vigore == 0 & inrange(mesi_dalla_scadenza,12,24)
replace status_contratto = 4 if contratto_in_vigore == 0 & mesi_dalla_scadenza > 24 & !mi(mesi_dalla_scadenza)

gen anno=year(dofm(data))
bys contratto anno: egen mode_status_contratto=mode(status_contratto), minmode 

collapse (max) stipula scadenza (mean) status_contratto=mode_status_contratto (sum) mesi_in_vigore=contratto_in_vigore, by(contratto anno)
label define status_contratto 0 "In vigore e lontano dalla scadenza" 1 "In vigore e vicino alla scadenza" 2 "Scaduto da meno di un anno" 3 "Scaduto da almeno un anno e non più di due anni" 4 "Scaduto da più di due anni"
label values status_contratto status_contratto

rename contratto sigla_bdi
keep if inrange(anno,${anno_inizio},${anno_fine})
save "${data}/rinnovi_info_contratto_by_ccnl_anno.dta", replace

* archivio rinnovi - primo anno nell'archivio 
use  "${data}/dataset_rinnovi.dta", clear
keep if inrange(anno_stipula,${anno_inizio},${anno_fine}) 
bys contratto: egen primo_anno_archivio_rinnovi = min(anno_stipula)
keep contratto primo_anno_archivio_rinnovi 
duplicates drop contratto, force 
rename contratto sigla_bdi

save "${data}/rinnovi_primo_anno_by_ccnl_anno.dta", replace

** archivio del loic e del roic - estrai medie annuali 
use "${data}/loic_roic_contratti.dta", clear
keep if inrange(anno,${anno_inizio},${anno_fine}) 
keep contratto anno loic roic
drop if mi(loic)
collapse (mean) loic roic, by(contratto anno)
rename contratto sigla_bdi
save  "${data}/roic_loic_by_ccnl_anno.dta", replace 


* crosswalk sigla bdi - ccnl cnel
* nel caso di un codice cnel associato a più sigle bdi, tenere la sigla bdi associata al peso in base 2021 maggiore
use "/home/group/main/892fl/dati/contrattazione/dati/dta/crosswalk/contratti_istat_base2021_codice_istat_bdi_cnel.dta", clear
*drop contratti che abbiamo deciso di non seguire  
drop if ccnl_cnel == "K531" // rifiuti privati 
drop if ccnl_cnel == "K541" // rifiuti municipalizzati 
drop if inlist(ccnl_cnel,"00476680582","13029381004","02500880121","01058580687","15907661001") // trasporto aereo-vettori 
drop if ccnl_cnel == "I810" // servizi a terra aeroporti 
drop if ccnl_cnel == "T011" // case di cura private 

replace sigla_bdi = "SSL" if sigla_bdi == "SSA" & ccnl_cnel == "T151"
replace sigla_bdi = "SSU" if sigla_bdi == "SSA" & ccnl_cnel == "T141"

keep if !mi(ccnl_cnel)  
bys ccnl_cnel (dc21): gen n=_n 
bys ccnl_cnel (dc21): gen N=_N  
keep if n==N 
keep sigla_bdi ccnl_cnel 
replace sigla_bdi=strlower(sigla_bdi)
keep sigla_bdi ccnl_cnel  

save "${data}/crosswalk_by_ccnl_anno.dta", replace







 
