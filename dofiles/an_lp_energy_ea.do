
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
* - s: variazione % tendenziale, divisa per 10, quindi b(h) è l'effetto di un aumento
*   di 10 pp della variazione tendenziale del prezzo; y: variazione % tendenziale
*   (contr, hicp, wageH), var. % congiunturale (occH) o differenza congiunturale (dur)
* - x: controlli macro in $lp_controls (come in Corsello e Foschi, 2026); per dur senza
*   ur (collineare con i ritardi di dur); covid: dummy 2020q1-2022q4 (se $covid_dum == 1)
* - Panel: effetti fissi paese sui paesi in $lp_panel, ponderato con pesi fissi
*   (media degli occupati del paese sul periodo, wP, aweight), errori standard Driscoll-Kraay
*   (xtscc >= 1.4, necessario per aweight con fe) con lag h+1
* - Serie storiche: una regressione per paese in $countries, errori standard
*   Newey-West con lag h+1
* - Varianti (variabile variant): base; pre = solo dati pre-Covid (t e t+h fino al 2019q4),
*   senza dummy Covid
* - Grafici senza titoli (titoli e note nel file TeX), bande al 90%:
*   lp_og_EA_*      : EA, petrolio (blu) e gas (rosso) nello stesso grafico
*   lp_og_ctry_*    : EA e paesi, petrolio e gas, stesso asse y (_sq: versione quadrata)
*   lp_main_*       : singolo prezzo, EA per petrolio e gas, panel per l'elettricità
*   lp_app_*        : singolo prezzo, panel e paesi restanti, stesso asse y
*   lp_rob_*        : base e pre-Covid per l'unità di lp_main_*
*   il periodo campionario di lp_main_* e lp_og_EA_* è scritto in graphs/smp_*.tex
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

* Dummy Covid
gen byte dcovid = inrange(timeq, tq(2020q1), tq(2022q4))

* Paesi del panel
gen byte inpanel = 0
foreach c of global lp_panel {
	replace inpanel = 1 if geo == "`c'"
}
* Pesi fissi del panel: occupati medi del paese sul periodo
egen wP = mean(occP), by(geocode)
xtset geocode timeq

* Dummy Covid (in tutte le specificazioni tranne pre)
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
		foreach v of global lp_controls {
			* dur: il livello ur è collineare con i ritardi di dur
			if "`y'" == "dur" & "`v'" == "ur" continue
			forv l = 1/$lp_lags {
				local ctrl "`ctrl' L`l'_`v'"
			}
		}
		foreach vr in base pre {
			local xr "`cv'"
			if "`vr'" == "pre"  local xr ""
			forv h = 0/$hmax {
				local xc ""
				if "`vr'" == "pre" local xc "& timeq + `h' <= tq(2019q4)"
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
			foreach v of global lp_controls {
				* dur: il livello ur è collineare con i ritardi di dur
				if "`y'" == "dur" & "`v'" == "ur" continue
				forv l = 1/$lp_lags {
					local ctrl "`ctrl' L`l'_`v'"
				}
			}
			foreach vr in base pre {
				local xr "`cv'"
				if "`vr'" == "pre"  local xr ""
				forv h = 0/$hmax {
					local xc ""
					if "`vr'" == "pre" local xc "& timeq + `h' <= tq(2019q4)"
					cap drop lhs smp
					qui gen lhs = F`h'.`y'
					qui gen byte smp = 1 `xc'
					markout smp lhs `s' `ctrl' `xr'
					qui su timeq if smp
					local t0 = r(min)
					local t1 = r(max)
					* ELEEURMWH non esiste per EA e BE: la stima fallisce e si salta
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
save ${out}/lp_energy_ea.dta, replace
export excel using ${out}/lp_energy_ea.xlsx, firstrow(var) replace

local lab_base "Baseline"
local lab_pre  "Pre-Covid"
local sty_base "lcolor(navy) lwidth(medthick)"
local sty_pre  "lcolor(forest_green) lwidth(medthick) lpattern(dash)"

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
			(line b h `cond', `sty_base'), ///
			yline(0, lcolor(black)) legend(off) ///
			xtitle("Quarters") ytitle("pp") xlabel(0(2)$hmax) ///
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
				(line b h `cond', `sty_base'), ///
				yline(0, lcolor(black)) legend(off) subtitle("`g' (`p0'-`p1')") ///
				xtitle("Quarters") ytitle("pp") xlabel(0(2)$hmax) ///
				graphregion(color(white)) name(g_`g', replace) nodraw
			local gl "`gl' g_`g'"
		}
		graph combine `gl', ycommon graphregion(color(white)) name(comb, replace)
		graph export ${gph}/lp_app_`s'_`y'.png, replace

		* --- Robustezza: pre-Covid per l'unità del grafico principale --- *
		local rc `"if geo == "`mg'" & shock == "`s'" & outcome == "`y'""'
		local pl `"(rarea lo90 hi90 h `rc' & variant == "base", color(gs13))"'
		local lg ""
		local k = 1
		foreach vr in base pre {
			qui count `rc' & variant == "`vr'"
			if r(N) == 0 continue
			local ++k
			local pl `"`pl' (line b h `rc' & variant == "`vr'", `sty_`vr'')"'
			local lg `"`lg' `k' "`lab_`vr''""'
		}
		twoway `pl', yline(0, lcolor(black)) legend(order(`lg') rows(1) position(6)) ///
			xtitle("Quarters") ytitle("pp") xlabel(0(2)$hmax) ///
			graphregion(color(white)) name(grob, replace)
		graph export ${gph}/lp_rob_`s'_`y'.png, replace
	}
}

* --- Petrolio (blu) e gas (rosso) nello stesso grafico, bande al 90% --- *
local o "OilSpotUSDBarrel"
local g "TTFSpotEURMWH"
local others : subinstr global countries "EA" "", word
foreach y of global lp_outcomes {
	local gl ""
	local lco ""
	foreach c in EA `others' {
		local co `"if geo == "`c'" & variant == "base" & shock == "`o'" & outcome == "`y'""'
		local cg `"if geo == "`c'" & variant == "base" & shock == "`g'" & outcome == "`y'""'
		* Serve la stima per entrambi gli shock
		qui count `co'
		local no = r(N)
		qui count `cg'
		if `no' == 0 | r(N) == 0 continue
		* Condizioni per il riquadro della legenda (primo paese disponibile, solo h = 0)
		if "`lco'" == "" {
			local lco `"`co' & h == 0"'
			local lcg `"`cg' & h == 0"'
		}
		qui su tmin `co' & h == 0
		local po0 : di %tq r(min)
		qui su tmax `co' & h == 0
		local po1 : di %tq r(max)
		qui su tmin `cg' & h == 0
		local pg0 : di %tq r(min)
		qui su tmax `cg' & h == 0
		local pg1 : di %tq r(max)
		local pl `"(rarea lo90 hi90 h `co', color(navy%25) lwidth(none)) (rarea lo90 hi90 h `cg', color(cranberry%25) lwidth(none)) (line b h `co', lcolor(navy) lwidth(medthick)) (line b h `cg', lcolor(cranberry) lp(longdash) lwidth(medthick))"'
		* Grafico EA a sé stante, con legenda
		if "`c'" == "EA" {
			file open `fh' using "${gph}/smp_lp_og_EA_`y'.tex", write replace
			file write `fh' "oil `po0'--`po1'; gas `pg0'--`pg1'"
			file close `fh'
			twoway `pl', yline(0, lcolor(black)) legend(order(3 "Oil price" 4 "Gas price") rows(1) position(6)) ///
				xtitle("Quarters") ytitle("pp") xlabel(0(2)$hmax) ///
				graphregion(color(white)) name(gog, replace)
			graph export ${gph}/lp_og_EA_`y'.png, replace
		}
		twoway `pl', yline(0, lcolor(black)) legend(off) ///
			subtitle("`c'" "Oil `po0'-`po1'; gas `pg0'-`pg1'", size(small)) ///
			xtitle("Quarters", size(small)) ytitle("pp") xlabel(0(2)$hmax) ///
			graphregion(color(white)) name(g_`c', replace) nodraw
		local gl "`gl' g_`c'"
	}
	* Riquadro con la sola legenda: un solo punto per serie, quindi le linee non si vedono
	twoway (line b h `lco', lcolor(navy) lwidth(medthick)) (line b h `lcg', lcolor(cranberry) lp(longdash) lwidth(medthick)), ///
		legend(order(1 "Oil price" 2 "Gas price") cols(1) ring(0) position(0) size(large) region(lstyle(none))) ///
		xscale(off) yscale(off) xlabel(none) ylabel(none) xtitle("") ytitle("") ///
		plotregion(style(none)) graphregion(color(white)) name(g_leg, replace) nodraw
	local gl "`gl' g_leg"
	graph combine `gl', ycommon graphregion(color(white)) name(comb, replace)
	graph export ${gph}/lp_og_ctry_`y'.png, replace
	* Versione quadrata (nota e slide)
	graph combine `gl', ycommon cols(3) xsize(6) ysize(6) graphregion(color(white)) name(combsq, replace)
	graph export ${gph}/lp_og_ctry_`y'_sq.png, replace
}

log close
