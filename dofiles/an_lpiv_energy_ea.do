
clear
cap log close

* --- Log file --- *
log using ${log}/log_an_lpiv_energy_ea.txt, t replace

*******************************************************************************
* Local Projections con variabili strumentali (LP-IV; Stock e Watson, 2018) degli
* shock ai prezzi di petrolio e gas
*
* Stessa specificazione delle LP OLS (an_lp_energy_ea.do), ma la variazione tendenziale
* del prezzo s(i,t) è strumentata con uno shock esterno z(t), comune ai paesi:
*   petrolio (OilSpotUSDBarrel): shock di offerta di petrolio (news) di Mori e Peersman (oilMP)
*   gas (TTFSpotEURMWH)        : shock di offerta di gas di Alessandri e Gazzani, 2025 (gasAG)
* (coppie prezzo-strumento in $lp_ivshocks / $lp_ivinstr; nessuno strumento per l'elettricità)
*   1° stadio: s(i,t)   = c(i,h) + g(h)*z(t)      + controlli + u(i,t)
*   2° stadio: y(i,t+h) = a(i,h) + b(h)*s_hat(i,t) + controlli + e(i,t+h)
* - s: variazione % tendenziale, divisa per 10, quindi b(h) è l'effetto di un aumento
*   di 10 pp della variazione tendenziale del prezzo (il segno dello strumento è irrilevante)
* - controlli: gli stessi delle LP OLS: $lp_lags ritardi di y, s e $lp_controls (per dur
*   senza ur, collineare con i ritardi di dur); dummy Covid 2020q1-2022q4 (se $covid_dum == 1)
* - Panel: paesi in $lp_panel, effetti fissi paese (dummy), pesi fissi wP (aweight),
*   errori standard Driscoll-Kraay: ivreg2, dkraay(h+2), cioè h+1 ritardi come xtscc lag(h+1)
* - Serie storiche: una regressione per paese in $countries, errori standard Newey-West:
*   ivreg2, robust kernel(bartlett) bw(h+2), cioè h+1 ritardi come newey lag(h+1)
* - Forza del 1° stadio: F di Kleibergen-Paap (e(widstat)), riportato solo nel log
*   (minimo e massimo sugli orizzonti); strumento segnalato come debole se F < $lp_ivweakF
* - Varianti (variabile variant): base; pre = solo dati pre-Covid (t e t+h fino al 2019q4),
*   senza dummy Covid
* - Il campione è limitato al periodo coperto dagli strumenti
* - Risultati in ${out}/lp_energy_iv_ea.dta; grafici senza titoli, bande al 90%, con la
*   stessa struttura dei grafici OLS ma prefisso lp_iv_ (solo petrolio e gas):
*   lp_iv_og_EA_*   : EA, petrolio (blu) e gas (rosso) nello stesso grafico
*   lp_iv_og_ctry_* : EA e paesi, petrolio e gas, stesso asse y stretto (_sq: versione quadrata)
*   lp_iv_main_*    : singolo prezzo, EA
*   lp_iv_app_*     : singolo prezzo, panel e paesi, stesso asse y stretto
*   lp_iv_rob_*     : base e pre-Covid per l'EA
*   il periodo campionario di lp_iv_main_* e lp_iv_og_EA_* è scritto in graphs/smp_lp_iv_*.tex
*******************************************************************************

foreach p in ivreg2 ranktest {
	cap which `p'
	if _rc ssc install `p'
}
which ivreg2

* Asse y comune e stretto per i grafici combinati: range dai dati (incluso lo 0) ed etichette
* interne al range, così da lasciare il minimo spazio bianco sopra e sotto
cap program drop lp_yaxis
program lp_yaxis, rclass
	args ymin ymax
	local ymin = min(`ymin', 0)
	local ymax = max(`ymax', 0)
	local d = (`ymax' - `ymin')/4
	local m = 10^floor(log10(`d'))
	local r = `d'/`m'
	local st = cond(`r' <= 1, 1, cond(`r' <= 2, 2, cond(`r' <= 5, 5, 10)))*`m'
	local y0 = ceil(`ymin'/`st')*`st'
	local y1 = floor(`ymax'/`st')*`st'
	return local opt "yscale(range(`ymin' `ymax')) ylabel(`y0'(`st')`y1')"
end

use ${data}/dataset_ea.dta, clear
xtset geocode timeq

* Shock scalati a 10 pp
foreach s of global lp_ivshocks {
	replace `s' = `s'/10
}

* Ritardi di shock, outcome e controlli (costruiti all'interno del paese)
foreach v in $lp_ivshocks $lp_outcomes $lp_controls {
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
* Effetti fissi paese del panel (dummy; il primo paese di $lp_panel è la base)
local fe ""
foreach c of global lp_panel {
	if "`c'" == word("$lp_panel", 1) continue
	gen byte fe_`c' = geo == "`c'"
	local fe "`fe' fe_`c'"
}
xtset geocode timeq

* Dummy Covid (in tutte le specificazioni tranne pre)
local cv ""
if $covid_dum == 1 local cv "dcovid"

* Strumenti disponibili
foreach z of global lp_ivinstr {
	su `z'
}

tempname pf
postfile `pf' str5 spec str5 geo str4 variant str20 shock str8 outcome byte h double(b se) int(N tmin tmax) using ${out}/lp_energy_iv_ea.dta, replace

local nz : word count $lp_ivshocks

*******************************************************************************
* 1) LP-IV panel
*******************************************************************************

forv j = 1/`nz' {
	local s : word `j' of $lp_ivshocks
	local z : word `j' of $lp_ivinstr
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
			local fmin = .
			local fmax = .
			local weak ""
			local flist ""
			forv h = 0/$hmax {
				local xc ""
				if "`vr'" == "pre" local xc "& timeq + `h' <= tq(2019q4)"
				cap drop lhs smp
				qui gen lhs = F`h'.`y'
				qui gen byte smp = inpanel `xc'
				markout smp lhs `s' `z' `ctrl' `xr' wP
				qui su timeq if smp
				local t0 = r(min)
				local t1 = r(max)
				cap ivreg2 lhs `ctrl' `xr' `fe' (`s' = `z') if smp [aw=wP], dkraay(`=`h'+2') small
				if _rc {
					di as txt "Salto: PANEL `vr' `s' -> `y', h=`h' (rc=" _rc ")"
					local flist "`flist' n.a."
					continue
				}
				local F = e(widstat)
				local flist "`flist' `: di %5.1f `F''"
				local fmin = min(`fmin', `F')
				local fmax = max(`fmax', `F')
				if `F' < $lp_ivweakF local weak "`weak' `h'"
				post `pf' ("panel") ("PANEL") ("`vr'") ("`s'") ("`y'") (`h') (_b[`s']) (_se[`s']) (e(N)) (`t0') (`t1')
			}
			di as txt "1° stadio PANEL `vr' `s' (strumento `z') -> `y': F di Kleibergen-Paap min " %6.1f `fmin' ", max " %6.1f `fmax'
			di as txt "  F per h = 0,...,$hmax:`flist'"
			if "`weak'" != "" di as err "  ATTENZIONE: possibile strumento debole (F < $lp_ivweakF) per h =`weak'"
		}
	}
}

*******************************************************************************
* 2) LP-IV serie storiche, un paese alla volta
*******************************************************************************

foreach c of global countries {
	preserve
	keep if geo == "`c'"
	tsset timeq
	forv j = 1/`nz' {
		local s : word `j' of $lp_ivshocks
		local z : word `j' of $lp_ivinstr
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
				local fmin = .
				local fmax = .
				local weak ""
				local flist ""
				forv h = 0/$hmax {
					local xc ""
					if "`vr'" == "pre" local xc "& timeq + `h' <= tq(2019q4)"
					cap drop lhs smp
					qui gen lhs = F`h'.`y'
					qui gen byte smp = 1 `xc'
					markout smp lhs `s' `z' `ctrl' `xr'
					qui su timeq if smp
					local t0 = r(min)
					local t1 = r(max)
					cap ivreg2 lhs `ctrl' `xr' (`s' = `z') if smp, robust kernel(bartlett) bw(`=`h'+2') small
					if _rc {
						di as txt "Salto: `c' `vr' `s' -> `y', h=`h' (rc=" _rc ")"
						local flist "`flist' n.a."
						continue
					}
					local F = e(widstat)
					local flist "`flist' `: di %5.1f `F''"
					local fmin = min(`fmin', `F')
					local fmax = max(`fmax', `F')
					if `F' < $lp_ivweakF local weak "`weak' `h'"
					post `pf' ("ts") ("`c'") ("`vr'") ("`s'") ("`y'") (`h') (_b[`s']) (_se[`s']) (e(N)) (`t0') (`t1')
				}
				di as txt "1° stadio `c' `vr' `s' (strumento `z') -> `y': F di Kleibergen-Paap min " %6.1f `fmin' ", max " %6.1f `fmax'
				di as txt "  F per h = 0,...,$hmax:`flist'"
				if "`weak'" != "" di as err "  ATTENZIONE: possibile strumento debole (F < $lp_ivweakF) per h =`weak'"
			}
		}
	}
	restore
}

postclose `pf'

*******************************************************************************
* 3) Risultati: intervalli di confidenza, Excel e grafici
*******************************************************************************

use ${out}/lp_energy_iv_ea.dta, clear
gen lo90 = b - invnormal(0.95)*se
gen hi90 = b + invnormal(0.95)*se
save ${out}/lp_energy_iv_ea.dta, replace
export excel using ${out}/lp_energy_iv_ea.xlsx, firstrow(var) replace

local lab_base "Baseline"
local lab_pre  "Pre-Covid"
local sty_base "lcolor(navy) lwidth(medthick)"
local sty_pre  "lcolor(forest_green) lwidth(medthick) lpattern(dash)"

tempname fh
foreach s of global lp_ivshocks {
	* Unità del grafico principale: EA (petrolio e gas)
	local mg "EA"
	foreach y of global lp_outcomes {
		local sel `"variant == "base" & shock == "`s'" & outcome == "`y'""'
		qui count if geo == "`mg'" & `sel'
		if r(N) == 0 {
			di as txt "Nessun grafico: nessuna stima `mg' per `s' -> `y'"
			continue
		}

		* --- Grafico principale --- *
		local cond `"if geo == "`mg'" & `sel'"'
		qui su tmin `cond' & h == 0
		local p0 : di %tq r(min)
		qui su tmax `cond' & h == 0
		local p1 : di %tq r(max)
		file open `fh' using "${gph}/smp_lp_iv_main_`s'_`y'.tex", write replace
		file write `fh' "`p0'--`p1'"
		file close `fh'
		twoway (rarea lo90 hi90 h `cond', color(gs13)) ///
			(line b h `cond', `sty_base'), ///
			yline(0, lcolor(black)) legend(off) ///
			xtitle("Quarters") ytitle("pp") xlabel(0(2)$hmax) ///
			graphregion(color(white)) name(gmain, replace)
		graph export ${gph}/lp_iv_main_`s'_`y'.png, replace

		* --- Appendice: panel e paesi restanti, stesso asse y (stretto) --- *
		local gl ""
		qui count if geo != "`mg'" & `sel'
		if r(N) > 0 {
			qui su lo90 if geo != "`mg'" & `sel'
			local a = r(min)
			qui su hi90 if geo != "`mg'" & `sel'
			lp_yaxis `a' `r(max)'
			local yax `"`r(opt)'"'
		}
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
				xtitle("Quarters") ytitle("pp") xlabel(0(2)$hmax) `yax' ///
				graphregion(color(white) margin(vsmall)) name(g_`g', replace) nodraw
			local gl "`gl' g_`g'"
		}
		if "`gl'" != "" {
			graph combine `gl', imargin(tiny) graphregion(color(white) margin(vsmall)) name(comb, replace)
			graph export ${gph}/lp_iv_app_`s'_`y'.png, replace
		}

		* --- Robustezza: pre-Covid per l'EA --- *
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
		graph export ${gph}/lp_iv_rob_`s'_`y'.png, replace
	}
}

* --- Petrolio (blu) e gas (rosso) nello stesso grafico, bande al 90% --- *
local o : word 1 of $lp_ivshocks
local g : word 2 of $lp_ivshocks
local others : subinstr global countries "EA" "", word
foreach y of global lp_outcomes {
	qui count if spec == "ts" & variant == "base" & inlist(shock, "`o'", "`g'") & outcome == "`y'"
	if r(N) == 0 continue
	qui su lo90 if spec == "ts" & variant == "base" & inlist(shock, "`o'", "`g'") & outcome == "`y'"
	local a = r(min)
	qui su hi90 if spec == "ts" & variant == "base" & inlist(shock, "`o'", "`g'") & outcome == "`y'"
	lp_yaxis `a' `r(max)'
	local yax `"`r(opt)'"'
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
		* Campioni: formato lungo per i file smp_*.tex, breve (es. 01q1) per i grafici
		qui su tmin `co' & h == 0
		local po0 : di %tq r(min)
		local qo0 : di %tqYY!qq r(min)
		qui su tmax `co' & h == 0
		local po1 : di %tq r(max)
		local qo1 : di %tqYY!qq r(max)
		qui su tmin `cg' & h == 0
		local pg0 : di %tq r(min)
		local qg0 : di %tqYY!qq r(min)
		qui su tmax `cg' & h == 0
		local pg1 : di %tq r(max)
		local qg1 : di %tqYY!qq r(max)
		local pl `"(rarea lo90 hi90 h `co', color(navy%25) lwidth(none)) (rarea lo90 hi90 h `cg', color(cranberry%25) lwidth(none)) (line b h `co', lcolor(navy) lwidth(medthick)) (line b h `cg', lcolor(cranberry) lp(longdash) lwidth(medthick))"'
		* Grafico EA a sé stante, con legenda
		if "`c'" == "EA" {
			file open `fh' using "${gph}/smp_lp_iv_og_EA_`y'.tex", write replace
			file write `fh' "oil `po0'--`po1'; gas `pg0'--`pg1'"
			file close `fh'
			twoway `pl', yline(0, lcolor(black)) legend(order(3 "Oil price" 4 "Gas price") rows(1) position(6)) ///
				xtitle("Quarters") ytitle("pp") xlabel(0(2)$hmax) ///
				graphregion(color(white)) name(gog, replace)
			graph export ${gph}/lp_iv_og_EA_`y'.png, replace
		}
		twoway `pl', yline(0, lcolor(black)) legend(off) ///
			subtitle("`c'" "Oil `qo0'–`qo1'; gas `qg0'–`qg1'", size(small)) ///
			xtitle("Quarters", size(small)) ytitle("pp") xlabel(0(2)$hmax) `yax' ///
			graphregion(color(white) margin(vsmall)) name(g_`c', replace) nodraw
		local gl "`gl' g_`c'"
	}
	if "`gl'" == "" continue
	* Riquadro con la sola legenda: un solo punto per serie, quindi le linee non si vedono
	twoway (line b h `lco', lcolor(navy) lwidth(medthick)) (line b h `lcg', lcolor(cranberry) lp(longdash) lwidth(medthick)), ///
		legend(order(1 "Oil price" 2 "Gas price") cols(1) ring(0) position(0) size(large) region(lstyle(none))) ///
		xscale(off) yscale(off) xlabel(none) ylabel(none) xtitle("") ytitle("") ///
		plotregion(style(none)) graphregion(color(white)) name(g_leg, replace) nodraw
	local gl "`gl' g_leg"
	graph combine `gl', imargin(tiny) graphregion(color(white) margin(vsmall)) name(comb, replace)
	graph export ${gph}/lp_iv_og_ctry_`y'.png, replace
	* Versione quadrata (nota e slide)
	graph combine `gl', imargin(tiny) cols(3) xsize(6) ysize(6) graphregion(color(white) margin(vsmall)) name(combsq, replace)
	graph export ${gph}/lp_iv_og_ctry_`y'_sq.png, replace
}

log close
