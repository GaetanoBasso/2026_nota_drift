
clear
cap log close

* --- Log file --- *
log using ${log}/log_an_lp_energy_ea.txt, t replace

*******************************************************************************
* Local Projections (Jordà, 2005) degli shock ai prezzi energetici
*
* Per ogni shock s, outcome y e orizzonte h = 0,...,$hmax:
*   y(i,t+h) = a(i,h) + b(h)*s(i,t) + sum_{l=1..p} [c(l,h)*y(i,t-l) + d(l,h)*s(i,t-l)] + e(i,t+h)
* - y, s: variazioni % tendenziali; s è diviso per 10, quindi b(h) è l'effetto
*   (in pp) di un aumento di 10 pp della variazione tendenziale del prezzo
* - Panel: effetti fissi paese sui paesi in $lp_panel, errori standard
*   Driscoll-Kraay (xtscc) con lag h+1
* - Serie storiche: una regressione per paese in $countries, errori standard
*   Newey-West con lag h+1
* - Se $covid_dum == 1 si escludono le osservazioni con t+h in 2020q1-2021q4
* - Il periodo campionario (date dello shock t nella stima a h=0) è riportato
*   nel titolo di ogni riquadro dei grafici
* - Sezione 4: LP separate per trimestri di alta e bassa crescita allo shock
*******************************************************************************

cap which xtscc
if _rc ssc install xtscc

use ${data}/dataset_ea.dta, clear
xtset geocode timeq

* Shock scalati a 10 pp
foreach s of global lp_shocks {
	replace `s' = `s'/10
}

* Ritardi di shock e outcome (costruiti all'interno del paese)
foreach v in $lp_shocks $lp_outcomes {
	forv l = 1/$lp_lags {
		gen L`l'_`v' = L`l'.`v'
	}
}

* Paesi del panel
gen byte inpanel = 0
foreach c of global lp_panel {
	replace inpanel = 1 if geo == "`c'"
}
tempfile lpdata
save `lpdata'

tempname pf
postfile `pf' str5 spec str5 geo str20 shock str8 outcome byte h double(b se) int(N tmin tmax) using ${out}/lp_energy_ea.dta, replace

*******************************************************************************
* 1) LP panel
*******************************************************************************

foreach s of global lp_shocks {
	foreach y of global lp_outcomes {
		local ctrl ""
		forv l = 1/$lp_lags {
			local ctrl "`ctrl' L`l'_`y' L`l'_`s'"
		}
		forv h = 0/$hmax {
			local cov ""
			if $covid_dum == 1 local cov "& !inrange(timeq+`h', tq(2020q1), tq(2021q4))"
			cap drop lhs smp
			qui gen lhs = F`h'.`y'
			qui gen byte smp = inpanel `cov'
			markout smp lhs `s' `ctrl'
			qui su timeq if smp
			local t0 = r(min)
			local t1 = r(max)
			qui xtscc lhs `s' `ctrl' if smp, fe lag(`=`h'+1')
			post `pf' ("panel") ("PANEL") ("`s'") ("`y'") (`h') (_b[`s']) (_se[`s']) (e(N)) (`t0') (`t1')
		}
		di as txt "Panel LP: `s' -> `y' fatto"
	}
}

*******************************************************************************
* 2) LP serie storiche, un paese alla volta
*******************************************************************************

foreach c of global countries {
	preserve
	keep if geo == "`c'"
	tsset timeq
	foreach s of global lp_shocks {
		foreach y of global lp_outcomes {
			local ctrl ""
			forv l = 1/$lp_lags {
				local ctrl "`ctrl' L`l'_`y' L`l'_`s'"
			}
			forv h = 0/$hmax {
				local cov ""
				if $covid_dum == 1 local cov "& !inrange(timeq+`h', tq(2020q1), tq(2021q4))"
				cap drop lhs smp
				qui gen lhs = F`h'.`y'
				qui gen byte smp = 1 `cov'
				markout smp lhs `s' `ctrl'
				qui su timeq if smp
				local t0 = r(min)
				local t1 = r(max)
				* ELEEURMWH non esiste per EA: la stima fallisce e si salta
				cap newey lhs `s' `ctrl' if smp, lag(`=`h'+1') force
				if _rc {
					di as txt "Salto: `c' `s' -> `y', h=`h' (rc=" _rc ")"
					continue
				}
				post `pf' ("ts") ("`c'") ("`s'") ("`y'") (`h') (_b[`s']) (_se[`s']) (e(N)) (`t0') (`t1')
			}
		}
	}
	restore
}

postclose `pf'

*******************************************************************************
* 3) Risultati: intervalli di confidenza, Excel e grafici
*******************************************************************************

use ${out}/lp_energy_ea.dta, clear
gen lo90 = b - invnormal(0.95)*se
gen hi90 = b + invnormal(0.95)*se
gen lo68 = b - se
gen hi68 = b + se
save ${out}/lp_energy_ea.dta, replace
export excel using ${out}/lp_energy_ea.xlsx, firstrow(var) replace

local lab_OilSpotUSDBarrel "Petrolio (USD)"
local lab_TTFSpotEURMWH    "Gas TTF"
local lab_ELEEURMWH        "Elettricità"
local lab_defl             "deflatore PIL"
local lab_wageH            "retribuzione oraria (CN)"
local lab_compH            "redditi da lavoro dip. per ora (CN)"
local lab_contr            "retribuzioni contrattuali"
local lab_hicp             "HICP"

* Un grafico per coppia shock-outcome: panel + un riquadro per paese
foreach s of global lp_shocks {
	foreach y of global lp_outcomes {
		local gl ""
		foreach g in PANEL $countries {
			qui count if geo == "`g'" & shock == "`s'" & outcome == "`y'"
			if r(N) == 0 continue
			local cond `"if geo == "`g'" & shock == "`s'" & outcome == "`y'""'
			qui su tmin `cond' & h == 0
			local p0 : di %tq r(min)
			qui su tmax `cond' & h == 0
			local p1 : di %tq r(max)
			twoway (rarea lo90 hi90 h `cond', color(gs13)) ///
				(rarea lo68 hi68 h `cond', color(gs10)) ///
				(line b h `cond', lcolor(navy) lwidth(medthick)), ///
				yline(0, lcolor(black)) legend(off) title("`g' (`p0'-`p1')") ///
				xtitle("Trimestri") ytitle("pp") xlabel(0(2)$hmax) ///
				graphregion(color(white)) name(g_`g', replace) nodraw
			local gl "`gl' g_`g'"
		}
		graph combine `gl', title("`lab_`s'' -> `lab_`y''") ///
			note("Risposta a +10 pp della var. tendenziale del prezzo; bande 68% e 90%") ///
			graphregion(color(white)) name(comb, replace)
		graph export ${gph}/lp_`s'_`y'.png, replace
	}
}

*******************************************************************************
* 4) LP per stato del ciclo allo shock: alta vs bassa crescita
*
* Trimestre t ad alta crescita (hg = 1) se:
*   vagh(t) > media storica di vagh del paese  e  vagh(t+1) > 0  e  vagh(t+2) > 0
* altrimenti bassa crescita (hg = 0); hg mancante se manca vagh in t, t+1 o t+2.
* vagh: var. % congiunturale del valore aggiunto del totale economia.
* Specificazione completamente interagita con lo stato (come Ramey e Zubairy, 2018):
*   y(i,t+h) = a(i,h) + g(h)*hg(i,t)
*              + hg(i,t)*[bH(h)*s(i,t) + controlli] + (1-hg(i,t))*[bL(h)*s(i,t) + controlli] + e(i,t+h)
* Nota: lo stato usa vagh(t+1) e vagh(t+2), cioè informazione successiva allo shock.
* pdiff: p-value del test bH(h) = bL(h). NH: osservazioni ad alta crescita nel campione.
*******************************************************************************

use `lpdata', clear
egen vagh_mean = mean(vagh), by(geocode)
xtset geocode timeq
gen byte hg = vagh > vagh_mean & F1.vagh > 0 & F2.vagh > 0 if !missing(vagh, F1.vagh, F2.vagh)
tab geo hg, missing

tempname pf
postfile `pf' str5 spec str5 geo str20 shock str8 outcome byte h double(bH seH bL seL pdiff) int(N NH tmin tmax) using ${out}/lp_energy_growthstate_ea.dta, replace

* --- LP panel --- *
foreach s of global lp_shocks {
	foreach y of global lp_outcomes {
		local ctrl ""
		forv l = 1/$lp_lags {
			local ctrl "`ctrl' L`l'_`y' L`l'_`s'"
		}
		local rhs ""
		foreach v in `s' `ctrl' {
			qui gen hi_`v' = `v'*hg
			qui gen lo_`v' = `v'*(1-hg)
			local rhs "`rhs' hi_`v' lo_`v'"
		}
		forv h = 0/$hmax {
			local cov ""
			if $covid_dum == 1 local cov "& !inrange(timeq+`h', tq(2020q1), tq(2021q4))"
			cap drop lhs smp
			qui gen lhs = F`h'.`y'
			qui gen byte smp = inpanel `cov'
			markout smp lhs hg `rhs'
			qui su timeq if smp
			local t0 = r(min)
			local t1 = r(max)
			qui count if smp & hg == 1
			local nh = r(N)
			qui xtscc lhs hg `rhs' if smp, fe lag(`=`h'+1')
			qui test hi_`s' = lo_`s'
			post `pf' ("panel") ("PANEL") ("`s'") ("`y'") (`h') (_b[hi_`s']) (_se[hi_`s']) (_b[lo_`s']) (_se[lo_`s']) (r(p)) (e(N)) (`nh') (`t0') (`t1')
		}
		drop hi_* lo_*
		di as txt "Panel LP per stato: `s' -> `y' fatto"
	}
}

* --- LP serie storiche, un paese alla volta --- *
foreach c of global countries {
	preserve
	keep if geo == "`c'"
	tsset timeq
	foreach s of global lp_shocks {
		foreach y of global lp_outcomes {
			local ctrl ""
			forv l = 1/$lp_lags {
				local ctrl "`ctrl' L`l'_`y' L`l'_`s'"
			}
			local rhs ""
			foreach v in `s' `ctrl' {
				qui gen hi_`v' = `v'*hg
				qui gen lo_`v' = `v'*(1-hg)
				local rhs "`rhs' hi_`v' lo_`v'"
			}
			forv h = 0/$hmax {
				local cov ""
				if $covid_dum == 1 local cov "& !inrange(timeq+`h', tq(2020q1), tq(2021q4))"
				cap drop lhs smp
				qui gen lhs = F`h'.`y'
				qui gen byte smp = 1 `cov'
				markout smp lhs hg `rhs'
				qui su timeq if smp
				local t0 = r(min)
				local t1 = r(max)
				qui count if smp & hg == 1
				local nh = r(N)
				* ELEEURMWH non esiste per EA: la stima fallisce e si salta
				cap newey lhs hg `rhs' if smp, lag(`=`h'+1') force
				if _rc {
					di as txt "Salto: `c' `s' -> `y', h=`h' (rc=" _rc ")"
					continue
				}
				qui test hi_`s' = lo_`s'
				* Coefficiente omesso (nessuna osservazione nello stato): risposta mancante
				post `pf' ("ts") ("`c'") ("`s'") ("`y'") (`h') (cond(_se[hi_`s'] > 0, _b[hi_`s'], .)) (_se[hi_`s']) (cond(_se[lo_`s'] > 0, _b[lo_`s'], .)) (_se[lo_`s']) (r(p)) (e(N)) (`nh') (`t0') (`t1')
			}
			drop hi_* lo_*
		}
	}
	restore
}

postclose `pf'

* --- Risultati: intervalli, Excel e grafici --- *
use ${out}/lp_energy_growthstate_ea.dta, clear
foreach k in H L {
	gen lo90`k' = b`k' - invnormal(0.95)*se`k'
	gen hi90`k' = b`k' + invnormal(0.95)*se`k'
}
save ${out}/lp_energy_growthstate_ea.dta, replace
export excel using ${out}/lp_energy_growthstate_ea.xlsx, firstrow(var) replace

* Un grafico per coppia shock-outcome: rosso = alta crescita, blu = bassa crescita
foreach s of global lp_shocks {
	foreach y of global lp_outcomes {
		local gl ""
		foreach g in PANEL $countries {
			qui count if geo == "`g'" & shock == "`s'" & outcome == "`y'"
			if r(N) == 0 continue
			local cond `"if geo == "`g'" & shock == "`s'" & outcome == "`y'""'
			qui su tmin `cond' & h == 0
			local p0 : di %tq r(min)
			qui su tmax `cond' & h == 0
			local p1 : di %tq r(max)
			twoway (rarea lo90H hi90H h `cond', color(cranberry%20) lwidth(none)) ///
				(rarea lo90L hi90L h `cond', color(navy%20) lwidth(none)) ///
				(line bH h `cond', lcolor(cranberry) lwidth(medthick)) ///
				(line bL h `cond', lcolor(navy) lwidth(medthick) lpattern(dash)), ///
				yline(0, lcolor(black)) legend(off) title("`g' (`p0'-`p1')") ///
				xtitle("Trimestri") ytitle("pp") xlabel(0(2)$hmax) ///
				graphregion(color(white)) name(g_`g', replace) nodraw
			local gl "`gl' g_`g'"
		}
		graph combine `gl', title("`lab_`s'' -> `lab_`y''") ///
			note("Risposta a +10 pp della var. tendenziale del prezzo; rosso = alta crescita, blu tratteggiato = bassa crescita; bande 90%") ///
			graphregion(color(white)) name(comb, replace)
		graph export ${gph}/lp_growthstate_`s'_`y'.png, replace
	}
}

log close
