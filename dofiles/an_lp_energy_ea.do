
clear
cap log close

* --- Log file --- *
log using ${log}/log_an_lp_energy_ea.txt, t replace

*******************************************************************************
* Local Projections (Jordà, 2005) degli shock ai prezzi energetici
*
* Per ogni shock s, outcome y e orizzonte h = 0,...,$hmax:
*   y(i,t+h) = a(i,h) + b(h)*s(i,t)
*              + sum_{l=1..p} [c(l,h)*y(i,t-l) + d(l,h)*s(i,t-l) + f(l,h)'x(i,t-l)]
*              + k(h)*covid(t) + e(i,t+h)
* - y, s: variazioni % tendenziali; s è diviso per 10, quindi b(h) è l'effetto
*   (in pp) di un aumento di 10 pp della variazione tendenziale del prezzo
* - x: controlli macro in $lp_controls (come in Corsello e Foschi, 2026);
*   covid: dummy 2020q1-2022q4 (se $covid_dum == 1)
* - Panel: effetti fissi paese sui paesi in $lp_panel, ponderato con pesi fissi
*   (media degli occupati del paese sul periodo, wP, aweight), errori standard Driscoll-Kraay
*   (xtscc >= 1.4, necessario per aweight con fe) con lag h+1
* - Serie storiche: una regressione per paese in $countries, errori standard
*   Newey-West con lag h+1
* - Varianti (variabile variant): base; pre = solo t+h <= 2019q4 (senza dummy covid);
*   post = solo t >= 2020q1; seas = base con effetti fissi trimestrali
* - Grafici senza titoli (titoli e note nel file TeX):
*   principali  lp_main_*: EA per petrolio e gas, panel per l'elettricità
*   appendice   lp_app_* : panel e paesi restanti, stesso asse y
*   robustezza  lp_rob_* : varianti per l'unità del grafico principale
*   il periodo campionario dei grafici principali è scritto in graphs/smp_*.tex
* - Sezione 4: LP per stato di alta/bassa inflazione di fondo allo shock
*******************************************************************************

cap which xtscc
if _rc ssc install xtscc
which xtscc

use ${data}/dataset_ea.dta, clear
xtset geocode timeq

* Shock scalati a 10 pp
foreach s of global lp_shocks {
	replace `s' = `s'/10
}

* Ritardi di shock, outcome e controlli (costruiti all'interno del paese)
foreach v in $lp_shocks $lp_outcomes $lp_controls {
	forv l = 1/$lp_lags {
		gen L`l'_`v' = L`l'.`v'
	}
}

* Dummy Covid ed effetti fissi trimestrali
gen byte dcovid = inrange(timeq, tq(2020q1), tq(2022q4))
forv q = 2/4 {
	gen byte q`q' = quarter == `q'
}

* Paesi del panel
gen byte inpanel = 0
foreach c of global lp_panel {
	replace inpanel = 1 if geo == "`c'"
}
* Pesi fissi del panel: occupati medi del paese sul periodo
egen wP = mean(occP), by(geocode)
xtset geocode timeq
tempfile lpdata
save `lpdata'

* Ritardi dei controlli macro e dummy Covid (comuni a tutte le specificazioni)
local xctrl ""
foreach v of global lp_controls {
	forv l = 1/$lp_lags {
		local xctrl "`xctrl' L`l'_`v'"
	}
}
local cv ""
if $covid_dum == 1 local cv "dcovid"

tempname pf
postfile `pf' str5 spec str5 geo str4 variant str20 shock str8 outcome byte h double(b se) int(N tmin tmax) using ${out}/lp_energy_ea.dta, replace

*******************************************************************************
* 1) LP panel
*******************************************************************************

foreach s of global lp_shocks {
	foreach y of global lp_outcomes {
		local ctrl ""
		forv l = 1/$lp_lags {
			local ctrl "`ctrl' L`l'_`y' L`l'_`s'"
		}
		local ctrl "`ctrl' `xctrl'"
		foreach vr in base pre post seas {
			local xr "`cv'"
			if "`vr'" == "pre"  local xr ""
			if "`vr'" == "seas" local xr "`cv' q2 q3 q4"
			forv h = 0/$hmax {
				local xc ""
				if "`vr'" == "pre"  local xc "& timeq + `h' <= tq(2019q4)"
				if "`vr'" == "post" local xc "& timeq >= tq(2020q1)"
				cap drop lhs smp
				qui gen lhs = F`h'.`y'
				qui gen byte smp = inpanel `xc'
				markout smp lhs `s' `ctrl' `xr' wP
				qui su timeq if smp
				local t0 = r(min)
				local t1 = r(max)
				cap xtscc lhs `s' `ctrl' `xr' if smp [aw=wP], fe lag(`=`h'+1')
				if _rc {
					di as txt "Salto: PANEL `vr' `s' -> `y', h=`h' (rc=" _rc ")"
					continue
				}
				post `pf' ("panel") ("PANEL") ("`vr'") ("`s'") ("`y'") (`h') (_b[`s']) (_se[`s']) (e(N)) (`t0') (`t1')
			}
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
			local ctrl "`ctrl' `xctrl'"
			foreach vr in base pre post seas {
				local xr "`cv'"
				if "`vr'" == "pre"  local xr ""
				if "`vr'" == "seas" local xr "`cv' q2 q3 q4"
				forv h = 0/$hmax {
					local xc ""
					if "`vr'" == "pre"  local xc "& timeq + `h' <= tq(2019q4)"
					if "`vr'" == "post" local xc "& timeq >= tq(2020q1)"
					cap drop lhs smp
					qui gen lhs = F`h'.`y'
					qui gen byte smp = 1 `xc'
					markout smp lhs `s' `ctrl' `xr'
					qui su timeq if smp
					local t0 = r(min)
					local t1 = r(max)
					* ELEEURMWH non esiste per EA e BE; post-Covid: poche osservazioni. La stima fallisce e si salta
					cap newey lhs `s' `ctrl' `xr' if smp, lag(`=`h'+1') force
					if _rc {
						di as txt "Salto: `c' `vr' `s' -> `y', h=`h' (rc=" _rc ")"
						continue
					}
					post `pf' ("ts") ("`c'") ("`vr'") ("`s'") ("`y'") (`h') (_b[`s']) (_se[`s']) (e(N)) (`t0') (`t1')
				}
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

local lab_base "Base"
local lab_pre  "Pre-Covid"
local lab_post "Post-Covid"
local lab_seas "Eff. fissi trimestrali"
local sty_base "lcolor(navy) lwidth(medthick)"
local sty_pre  "lcolor(forest_green) lwidth(medthick) lpattern(dash)"
local sty_post "lcolor(dkorange) lwidth(medthick) lpattern(shortdash)"
local sty_seas "lcolor(maroon) lwidth(medthick) lpattern(longdash_dot)"

tempname fh
foreach s of global lp_shocks {
	* Unità del grafico principale: EA per petrolio e gas, panel per l'elettricità
	local mg "EA"
	if "`s'" == "ELEEURMWH" local mg "PANEL"
	foreach y of global lp_outcomes {
		local sel `"variant == "base" & shock == "`s'" & outcome == "`y'""'

		* --- Grafico principale --- *
		local cond `"if geo == "`mg'" & `sel'"'
		qui su tmin `cond' & h == 0
		local p0 : di %tq r(min)
		qui su tmax `cond' & h == 0
		local p1 : di %tq r(max)
		file open `fh' using "${gph}/smp_lp_main_`s'_`y'.tex", write replace
		file write `fh' "`p0'--`p1'"
		file close `fh'
		twoway (rarea lo90 hi90 h `cond', color(gs13)) ///
			(rarea lo68 hi68 h `cond', color(gs10)) ///
			(line b h `cond', `sty_base'), ///
			yline(0, lcolor(black)) legend(off) ///
			xtitle("Trimestri") ytitle("pp") xlabel(0(2)$hmax) ///
			graphregion(color(white)) name(gmain, replace)
		graph export ${gph}/lp_main_`s'_`y'.png, replace

		* --- Appendice: panel e paesi restanti, stesso asse y --- *
		local gl ""
		foreach g in PANEL $countries {
			if "`g'" == "`mg'" continue
			qui count if geo == "`g'" & `sel'
			if r(N) == 0 continue
			local cond `"if geo == "`g'" & `sel'"'
			qui su tmin `cond' & h == 0
			local p0 : di %tq r(min)
			qui su tmax `cond' & h == 0
			local p1 : di %tq r(max)
			twoway (rarea lo90 hi90 h `cond', color(gs13)) ///
				(rarea lo68 hi68 h `cond', color(gs10)) ///
				(line b h `cond', `sty_base'), ///
				yline(0, lcolor(black)) legend(off) subtitle("`g' (`p0'-`p1')") ///
				xtitle("Trimestri") ytitle("pp") xlabel(0(2)$hmax) ///
				graphregion(color(white)) name(g_`g', replace) nodraw
			local gl "`gl' g_`g'"
		}
		graph combine `gl', ycommon graphregion(color(white)) name(comb, replace)
		graph export ${gph}/lp_app_`s'_`y'.png, replace

		* --- Robustezza: varianti per l'unità del grafico principale --- *
		local rc `"if geo == "`mg'" & shock == "`s'" & outcome == "`y'""'
		local pl `"(rarea lo90 hi90 h `rc' & variant == "base", color(gs13))"'
		local lg ""
		local k = 1
		foreach vr in base pre post seas {
			qui count `rc' & variant == "`vr'"
			if r(N) == 0 continue
			local ++k
			local pl `"`pl' (line b h `rc' & variant == "`vr'", `sty_`vr'')"'
			local lg `"`lg' `k' "`lab_`vr''""'
		}
		twoway `pl', yline(0, lcolor(black)) legend(order(`lg') rows(1) position(6)) ///
			xtitle("Trimestri") ytitle("pp") xlabel(0(2)$hmax) ///
			graphregion(color(white)) name(grob, replace)
		graph export ${gph}/lp_rob_`s'_`y'.png, replace
	}
}

*******************************************************************************
* 4) LP per stato dell'inflazione di fondo allo shock: alta vs bassa
*
* Trimestre t ad alta inflazione (hinf = 1) se l'inflazione di fondo (HICP esclusi
* energia, alimentari, alcol e tabacchi, var. % a/a) in t-1 supera $infl_thr;
* altrimenti bassa inflazione (hinf = 0); hinf mancante se manca hicpx in t-1.
* Specificazione completamente interagita con lo stato (come Ramey e Zubairy, 2018):
*   y(i,t+h) = a(i,h) + g(h)*hinf(i,t)
*              + hinf(i,t)*[bH(h)*s(i,t) + controlli] + (1-hinf(i,t))*[bL(h)*s(i,t) + controlli] + e(i,t+h)
* pdiff: p-value del test bH(h) = bL(h). NH: osservazioni ad alta inflazione nel campione.
*******************************************************************************

use `lpdata', clear
gen byte hinf = L.hicpx > $infl_thr if !missing(L.hicpx)
tab geo hinf, missing

tempname pf
postfile `pf' str5 spec str5 geo str20 shock str8 outcome byte h double(bH seH bL seL pdiff) int(N NH tmin tmax) using ${out}/lp_energy_inflstate_ea.dta, replace

* --- LP panel --- *
foreach s of global lp_shocks {
	foreach y of global lp_outcomes {
		local ctrl ""
		forv l = 1/$lp_lags {
			local ctrl "`ctrl' L`l'_`y' L`l'_`s'"
		}
		local rhs ""
		foreach v in `s' `ctrl' `xctrl' `cv' {
			qui gen hi_`v' = `v'*hinf
			qui gen lo_`v' = `v'*(1-hinf)
			local rhs "`rhs' hi_`v' lo_`v'"
		}
		forv h = 0/$hmax {
			cap drop lhs smp
			qui gen lhs = F`h'.`y'
			qui gen byte smp = inpanel
			markout smp lhs hinf `rhs' wP
			qui su timeq if smp
			local t0 = r(min)
			local t1 = r(max)
			qui count if smp & hinf == 1
			local nh = r(N)
			qui xtscc lhs hinf `rhs' if smp [aw=wP], fe lag(`=`h'+1')
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
			foreach v in `s' `ctrl' `xctrl' `cv' {
				qui gen hi_`v' = `v'*hinf
				qui gen lo_`v' = `v'*(1-hinf)
				local rhs "`rhs' hi_`v' lo_`v'"
			}
			forv h = 0/$hmax {
				cap drop lhs smp
				qui gen lhs = F`h'.`y'
				qui gen byte smp = 1
				markout smp lhs hinf `rhs'
				qui su timeq if smp
				local t0 = r(min)
				local t1 = r(max)
				qui count if smp & hinf == 1
				local nh = r(N)
				* ELEEURMWH non esiste per EA e BE: la stima fallisce e si salta
				cap newey lhs hinf `rhs' if smp, lag(`=`h'+1') force
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
use ${out}/lp_energy_inflstate_ea.dta, clear
foreach k in H L {
	gen lo90`k' = b`k' - invnormal(0.95)*se`k'
	gen hi90`k' = b`k' + invnormal(0.95)*se`k'
}
save ${out}/lp_energy_inflstate_ea.dta, replace
export excel using ${out}/lp_energy_inflstate_ea.xlsx, firstrow(var) replace

* Rosso = alta inflazione, blu tratteggiato = bassa inflazione
foreach s of global lp_shocks {
	local mg "EA"
	if "`s'" == "ELEEURMWH" local mg "PANEL"
	foreach y of global lp_outcomes {
		local sel `"shock == "`s'" & outcome == "`y'""'

		* --- Grafico principale --- *
		local cond `"if geo == "`mg'" & `sel'"'
		qui su tmin `cond' & h == 0
		local p0 : di %tq r(min)
		qui su tmax `cond' & h == 0
		local p1 : di %tq r(max)
		file open `fh' using "${gph}/smp_lp_inflstate_main_`s'_`y'.tex", write replace
		file write `fh' "`p0'--`p1'"
		file close `fh'
		twoway (rarea lo90H hi90H h `cond', color(cranberry%20) lwidth(none)) ///
			(rarea lo90L hi90L h `cond', color(navy%20) lwidth(none)) ///
			(line bH h `cond', lcolor(cranberry) lwidth(medthick)) ///
			(line bL h `cond', lcolor(navy) lwidth(medthick) lpattern(dash)), ///
			yline(0, lcolor(black)) legend(order(3 "Alta inflazione" 4 "Bassa inflazione") rows(1) position(6)) ///
			xtitle("Trimestri") ytitle("pp") xlabel(0(2)$hmax) ///
			graphregion(color(white)) name(gmain, replace)
		graph export ${gph}/lp_inflstate_main_`s'_`y'.png, replace

		* --- Appendice: panel e paesi restanti, stesso asse y --- *
		local gl ""
		foreach g in PANEL $countries {
			if "`g'" == "`mg'" continue
			qui count if geo == "`g'" & `sel'
			if r(N) == 0 continue
			local cond `"if geo == "`g'" & `sel'"'
			qui su tmin `cond' & h == 0
			local p0 : di %tq r(min)
			qui su tmax `cond' & h == 0
			local p1 : di %tq r(max)
			twoway (rarea lo90H hi90H h `cond', color(cranberry%20) lwidth(none)) ///
				(rarea lo90L hi90L h `cond', color(navy%20) lwidth(none)) ///
				(line bH h `cond', lcolor(cranberry) lwidth(medthick)) ///
				(line bL h `cond', lcolor(navy) lwidth(medthick) lpattern(dash)), ///
				yline(0, lcolor(black)) legend(off) subtitle("`g' (`p0'-`p1')") ///
				xtitle("Trimestri") ytitle("pp") xlabel(0(2)$hmax) ///
				graphregion(color(white)) name(g_`g', replace) nodraw
			local gl "`gl' g_`g'"
		}
		graph combine `gl', ycommon graphregion(color(white)) name(comb, replace)
		graph export ${gph}/lp_inflstate_app_`s'_`y'.png, replace
	}
}

log close
