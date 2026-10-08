
clear
cap log close

* --- Log file --- *
log using ${log}/log_an_lpiv_energy_ea.txt, t replace

*******************************************************************************
* Local Projections con variabili strumentali (LP-IV; Stock e Watson, 2018) degli
* shock ai prezzi di petrolio e gas, su serie storiche (EA e singoli paesi)
*
* Stessa specificazione delle LP OLS su serie storiche (an_lp_energy_ea.do), ma la
* variazione congiunturale del prezzo s(t) è strumentata con shock esterni mensili, comuni ai paesi:
*   petrolio (OilSpotUSDBarrel): shock di offerta di petrolio (news) di Mori e Peersman (oilMP)
*   gas (TTFSpotEURMWH)        : shock di offerta di gas di Alessandri e Gazzani, 2025 (gasAG)
* (coppie prezzo-strumento in $lp_ivshocks / $lp_ivinstr; nessuno strumento per l'elettricità)
*
* Frequenza mista: gli strumenti sono mensili, le LP trimestrali. Nella specificazione di base
* (e in unsm, pre, rf) lo strumento è la media trimestrale dei 3 shock mensili (z); nella variante umid i 3 shock
* mensili del trimestre t (z1, z2, z3: 1°, 2° e 3° mese) sono strumenti separati (U-MIDAS,
* Foroni, Marcellino e Schumacher, 2015)
*   1° stadio: s(t)   = c(h) + g(h)*z(t) + controlli + u(t)
*   2° stadio: y(t+h) = a(h) + b(h)*s_hat(t) + controlli + e(t+h)
* - s: variazione congiunturale logaritmica del prezzo (100*dln P), divisa per 10, quindi b(h)
*   è l'effetto di un aumento del 10% del prezzo (il segno degli strumenti è irrilevante)
* - controlli (in entrambi gli stadi): gli stessi delle LP OLS: $lp_lags ritardi di y, s e
*   $lp_controls (per dur senza ur, collineare con i ritardi di dur); dummy Covid 2020q1-2022q4
*   e i suoi $lp_lags ritardi (se $covid_dum == 1)
* - errori standard Newey-West: ivreg2, robust kernel(bartlett) bw(h+2), cioè h+1 ritardi
*   come newey lag(h+1)
* - Forza del 1° stadio: F efficace di Montiel Olea e Pflueger (2013) (weakivtest, Pflueger e
*   Wang, 2015; robusto a eteroschedasticità e autocorrelazione come gli errori standard),
*   riportato solo nel log (minimo, massimo e valore per ogni orizzonte, con il valore critico);
*   strumenti segnalati come deboli se F efficace < valore critico per una distorsione massima
*   della 2SLS del $lp_ivtau% (livello 5%)
* - Varianti (variabile variant):
*   base = LP-IV smussate (Barnichon e Brownlees, 2019), strumento trimestrale: la risposta
*          b(h) = B(h)'theta è una spline cubica (nodi a ogni orizzonte), stimata su tutti gli
*          orizzonti insieme con una penalità lambda sulle differenze di ordine $lp_slp_r di
*          theta; controlli specifici per orizzonte e non penalizzati (eliminati per
*          Frisch-Waugh nel campione di ogni orizzonte); lambda scelto per validazione
*          incrociata su 5 blocchi temporali contigui. Intervalli di confidenza con
*          undersmoothing: stima e errori standard con lambda/$lp_slp_us (distorsione da
*          penalità trascurabile), bande centrate su questa stima (variabile bc), mentre la
*          linea è la stima con il lambda della validazione incrociata (b); errori standard
*          Newey-West (h+1 ritardi) sui punteggi aggregati per trimestre dello shock
*   unsm = LP-IV non smussate, orizzonte per orizzonte (ivreg2), strumento trimestrale
*   umid = come unsm, 3 shock mensili come strumenti separati
*   pre  = come unsm, solo dati pre-Covid (t e t+h fino al 2019q4), senza dummy Covid
*   rf   = forma ridotta: OLS di y(t+h) sullo strumento trimestrale e sugli stessi controlli
*          (newey lag(h+1)), risposta a uno shock di 1 deviazione standard dello strumento
* - Campione: le date dello shock t richiedono strumenti, prezzo e controlli; l'outcome
*   y(t+h) può andare oltre la fine degli strumenti (nel log: date dello shock e ultimo
*   trimestre dell'outcome usato)
* - Risultati in ${out}/lp_energy_iv_ea.dta; grafici senza titoli, bande al 90%, prefisso
*   lp_iv_ (solo petrolio e gas):
*   lp_iv_og_EA_*   : EA, petrolio (blu) e gas (rosso) nello stesso grafico
*   lp_iv_og_ctry_* : EA e paesi, petrolio e gas, stesso asse y stretto (_sq: versione quadrata)
*   lp_iv_main_*    : singolo prezzo, EA
*   lp_iv_app_*     : singolo prezzo, paesi, stesso asse y stretto
*   lp_iv_rob_*     : base (smussate), non smussate (unsm), strumenti mensili (umid) e
*                     pre-Covid per l'EA
*   lp_rf_og_EA_*, lp_rf_og_ctry_* : come lp_iv_og_*, forma ridotta (appendice)
*   il periodo campionario di lp_iv_main_*, lp_iv_og_EA_* e lp_rf_og_EA_* è scritto in
*   graphs/smp_lp_*.tex
*******************************************************************************

foreach p in ivreg2 ranktest weakivtest avar {
	cap which `p'
	if _rc ssc install `p'
}
which ivreg2

* Asse y stretto: range dai dati (incluso lo 0) ed etichette interne al range, così da lasciare
* il minimo spazio bianco sopra e sotto. Passo delle etichette (se non dato come 3° argomento)
* = massimo valore assoluto del range / 5, arrotondato per eccesso a 1, 2 o 5 x 10^k: es. .1 per
* [-.5,.5], .2 per [-1,1], .5 per [-2,2]. Con un passo dato, se il range non arriva a un passo
* dallo 0 viene allargato fino a un passo (almeno un'etichetta oltre allo 0)
cap program drop lp_yaxis
program lp_yaxis, rclass
	args ymin ymax st
	local ymin = min(`ymin', 0)
	local ymax = max(`ymax', 0)
	if "`st'" == "" {
		local d = max(-(`ymin'), `ymax')/5
		local m = 10^floor(log10(`d') + 1e-9)
		local r = `d'/`m'
		local st = cond(`r' <= 1 + 1e-9, 1, cond(`r' <= 2 + 1e-9, 2, cond(`r' <= 5 + 1e-9, 5, 10)))*`m'
	}
	if max(-(`ymin'), `ymax') < `st' {
		if -(`ymin') > `ymax' local ymin = -`st'
		else local ymax = `st'
	}
	* Prima e ultima etichetta interne al range (tolleranza per gli errori di arrotondamento)
	local y0 = round(ceil(`ymin'/`st' - 1e-9)*`st', 1e-10)
	local y1 = round(floor(`ymax'/`st' + 1e-9)*`st', 1e-10)
	return local opt "yscale(range(`ymin' `ymax')) ylabel(`y0'(`st')`y1', labsize(small))"
	return scalar st = `st'
end

* Assi y dei grafici a più pannelli (un pannello per unità geo in units, stime in if): asse
* comune se l'ampiezza delle bande (max hi90 - min lo90 del pannello) supera quella del
* pannello più stretto al massimo di $lp_ytol punti; altrimenti un asse per pannello, con il
* passo delle etichette dell'asse comune. Restituisce r(<unità>) = opzioni dell'asse y
cap program drop lp_ypanels
program lp_ypanels, rclass
	syntax if, units(string)
	marksample touse, novarlist
	local ok ""
	local wmin = .
	local wmax = .
	local ymin = .
	local ymax = .
	foreach u of local units {
		qui su lo90 if `touse' & geo == "`u'"
		if r(N) == 0 continue
		local lo_`u' = r(min)
		qui su hi90 if `touse' & geo == "`u'"
		local hi_`u' = r(max)
		local ok "`ok' `u'"
		local wmin = min(`wmin', (`hi_`u'') - (`lo_`u''))
		local wmax = max(`wmax', (`hi_`u'') - (`lo_`u''))
		local ymin = min(`ymin', `lo_`u'')
		local ymax = max(`ymax', `hi_`u'')
	}
	if "`ok'" == "" exit
	* Asse comune e suo passo delle etichette
	lp_yaxis `ymin' `ymax'
	local st = r(st)
	local copt "`r(opt)'"
	local common = ((`wmax') - (`wmin') <= $lp_ytol + 1e-9)
	foreach u of local ok {
		local o_`u' "`copt'"
		if !`common' {
			lp_yaxis `lo_`u'' `hi_`u'' `st'
			local o_`u' "`r(opt)'"
		}
	}
	di as txt "  asse y " cond(`common', "comune", "per pannello, passo `st'") ///
		": differenza tra le ampiezze delle bande " %5.2f (`wmax') - (`wmin')
	foreach u of local ok {
		return local `u' "`o_`u''"
	}
end

* LP-IV smussate (Barnichon e Brownlees, 2019). S: una riga per orizzonte e trimestre dello
* shock, colonne y, s, z (già depurati dai controlli nel campione di ogni orizzonte), timeq, h.
* Restituisce per h = 0,...,H: risposta (lambda della validazione incrociata), centro e errore
* standard delle bande (lambda/k, undersmoothing) e lambda scelto (relativo)
cap mata: mata drop lp_slp()
mata:
real matrix lp_slp(real matrix S, real scalar H, real scalar r, real scalar k)
{
	real colvector y, x, z, t, hh, xh, sel, ut, ts, cs, mse, w, e, b, se
	real matrix B, D, P, X, Xh, A, th, g, Om, Gl, V
	real scalar n, K, h, j, sc, i, f, a1, a2, lam, best, m, l

	y = S[., 1]; x = S[., 2]; z = S[., 3]; t = S[., 4]; hh = S[., 5]
	n = rows(y)
	// 1° stadio in ogni orizzonte: proiezione di s su z (dati già depurati dai controlli)
	xh = J(n, 1, .)
	for (h = 0; h <= H; h++) {
		sel = selectindex(hh :== h)
		if (rows(sel)) xh[sel] = z[sel] * (cross(z[sel], x[sel]) / cross(z[sel], z[sel]))
	}
	// Base spline cubica con nodi a ogni orizzonte: valori agli orizzonti interi 1/6, 4/6, 1/6
	K = H + 3
	B = J(H + 1, K, 0)
	for (h = 0; h <= H; h++) B[|h + 1, h + 1 \ h + 1, h + 3|] = (1, 4, 1) / 6
	// Penalità sulle differenze di ordine r dei coefficienti della spline
	D = I(K)
	for (j = 1; j <= r; j++) D = D[|2, 1 \ rows(D), K|] - D[|1, 1 \ rows(D) - 1, K|]
	P = cross(D, D)
	X  = B[hh :+ 1, .] :* x
	Xh = B[hh :+ 1, .] :* xh
	// lambda = c * tr(Xh'X)/tr(P), c scelto per validazione incrociata su 5 blocchi contigui
	// di trimestri dello shock (errore di previsione di y dato lo strumento)
	sc = trace(cross(Xh, X)) / trace(P)
	cs = 10 :^ ((-8::8) / 2)
	ut = uniqrows(t)
	m = rows(ut)
	mse = J(rows(cs), 1, 0)
	for (i = 1; i <= rows(cs); i++) {
		for (f = 1; f <= 5; f++) {
			a1 = ut[floor((f - 1) * m / 5) + 1]
			a2 = ut[floor(f * m / 5)]
			ts = (t :>= a1) :& (t :<= a2)
			th = lusolve(cross(Xh, 1 :- ts, X) + cs[i] * sc * P, cross(Xh, 1 :- ts, y))
			e = select(y - Xh * th, ts)
			mse[i] = mse[i] + cross(e, e)
		}
	}
	w = order(mse, 1)
	best = cs[w[1]]
	lam = best * sc
	b = B * lusolve(cross(Xh, X) + lam * P, cross(Xh, y))
	// Bande con undersmoothing: stima con lambda/k, su cui sono centrate le bande
	A = cross(Xh, X) + (lam / k) * P
	th = lusolve(A, cross(Xh, y))
	// Errori standard: punteggi aggregati per trimestre dello shock, Newey-West con H+1 ritardi
	e = y - X * th
	g = J(m, K, 0)
	for (j = 1; j <= m; j++) {
		sel = selectindex(t :== ut[j])
		g[j, .] = colsum(Xh[sel, .] :* e[sel])
	}
	Om = cross(g, g)
	for (l = 1; l <= min((H + 1, m - 1)); l++) {
		Gl = cross(g[|l + 1, 1 \ m, K|], g[|1, 1 \ m - l, K|])
		Om = Om + (1 - l / (H + 2)) * (Gl + Gl')
	}
	A = luinv(A)
	V = A * Om * A'
	se = sqrt(diagonal(B * V * B'))
	return((b, B * th, se, J(H + 1, 1, best)))
}
end

use ${data}/dataset_ea.dta, clear
xtset geocode timeq

* Shock scalati a un aumento del 10%
foreach s of global lp_ivshocks {
	replace `s' = `s'/10
}

* Ritardi di shock, outcome e controlli (costruiti all'interno del paese)
foreach v in $lp_ivshocks $lp_outcomes $lp_controls {
	forv l = 1/$lp_lags {
		gen L`l'_`v' = L`l'.`v'
	}
}

* Dummy Covid e suoi ritardi
gen byte dcovid = inrange(timeq, tq(2020q1), tq(2022q4))
forv l = 1/$lp_lags {
	gen byte L`l'_dcovid = L`l'.dcovid
}

* Dummy Covid e ritardi (in tutte le specificazioni tranne pre)
local cv ""
if $covid_dum == 1 {
	local cv "dcovid"
	forv l = 1/$lp_lags {
		local cv "`cv' L`l'_dcovid"
	}
}

* Strumenti disponibili (mensili per posizione nel trimestre e media trimestrale);
* deviazione standard dello strumento trimestrale per scalare la forma ridotta
foreach z of global lp_ivinstr {
	su `z'1 `z'2 `z'3 `z' if geo == "EA"
	qui su `z' if geo == "EA"
	local sd_`z' = r(sd)
}

tempname pf
postfile `pf' str5 spec str5 geo str4 variant str20 shock str8 outcome byte h double(b bc se) int(N tmin tmax) using ${out}/lp_energy_iv_ea.dta, replace

local nz : word count $lp_ivshocks

*******************************************************************************
* 1) LP-IV serie storiche, un paese alla volta
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
			foreach vr in unsm umid pre rf base {
				* Strumenti: media trimestrale (base, unsm, pre, rf) o shock mensili separati (umid)
				local zi "`z'"
				if "`vr'" == "umid" local zi "`z'1 `z'2 `z'3"
				local xr "`cv'"
				if "`vr'" == "pre"  local xr ""
				local fmin = .
				local fmax = .
				local weak ""
				local flist ""
				local clist ""
				local s0 = .
				local s1 = .
				local ylast = .
				if "`vr'" == "base" mata: S = J(0, 5, .)
				forv h = 0/$hmax {
					local xc ""
					if "`vr'" == "pre" local xc "& timeq + `h' <= tq(2019q4)"
					cap drop lhs smp
					qui gen lhs = F`h'.`y'
					qui gen byte smp = 1 `xc'
					markout smp lhs `s' `zi' `ctrl' `xr'
					qui su timeq if smp
					local t0 = r(min)
					local t1 = r(max)
					local N = r(N)
					* LP smussate (base): dati dell'orizzonte h depurati dai controlli, stima dopo il ciclo
					if "`vr'" == "base" {
						if `N' == 0 continue
						foreach v in lhs `s' `zi' {
							qui reg `v' `ctrl' `xr' if smp
							cap drop r_`v'
							qui predict double r_`v' if smp, resid
						}
						cap drop hcur
						qui gen hcur = `h'
						mata: S = S \ st_data(., "r_lhs r_`s' r_`zi' timeq hcur", "smp")
						drop r_lhs r_`s' r_`zi' hcur
						local N`h' = `N'
						local t0`h' = `t0'
						local t1`h' = `t1'
						continue
					}
					* Forma ridotta: risposta a uno shock di 1 deviazione standard dello strumento
					if "`vr'" == "rf" {
						cap newey lhs `zi' `ctrl' `xr' if smp, lag(`=`h'+1')
						if _rc {
							di as txt "Salto: `c' `vr' `s' -> `y', h=`h' (rc=" _rc ")"
							continue
						}
						post `pf' ("ts") ("`c'") ("`vr'") ("`s'") ("`y'") (`h') (_b[`zi']*`sd_`z'') (_b[`zi']*`sd_`z'') (_se[`zi']*`sd_`z'') (e(N)) (`t0') (`t1')
						continue
					}
					cap ivreg2 lhs `ctrl' `xr' (`s' = `zi') if smp, robust kernel(bartlett) bw(`=`h'+2') small
					if _rc {
						di as txt "Salto: `c' `vr' `s' -> `y', h=`h' (rc=" _rc ")"
						local flist "`flist' n.a."
						local clist "`clist' n.a."
						continue
					}
					local b = _b[`s']
					local se = _se[`s']
					local N = e(N)
					* F efficace di Montiel Olea e Pflueger e valore critico (tau = $lp_ivtau%)
					local F = .
					local ccrit = .
					cap weakivtest, level(0.05)
					if !_rc {
						local F = r(F_eff)
						local ccrit = r(c_TSLS_$lp_ivtau)
					}
					local flist "`flist' `: di %5.1f `F''"
					local clist "`clist' `: di %5.1f `ccrit''"
					local fmin = min(`fmin', `F')
					local fmax = max(`fmax', `F')
					if !missing(`F', `ccrit') & `F' < `ccrit' local weak "`weak' `h'"
					* Date dello shock (orizzonte 0) e ultimo trimestre dell'outcome usato
					if `h' == 0 {
						local s0 = `t0'
						local s1 = `t1'
					}
					local ylast = max(`ylast', `t1' + `h')
					post `pf' ("ts") ("`c'") ("`vr'") ("`s'") ("`y'") (`h') (`b') (`b') (`se') (`N') (`t0') (`t1')
				}
				if "`vr'" == "base" {
					mata: st_matrix("R", lp_slp(S, $hmax, $lp_slp_r, $lp_slp_us))
					di as txt "LP smussate `c' `s' -> `y': lambda relativo scelto per validazione incrociata = " %9.4g el(R, 1, 4) " (bande con lambda/$lp_slp_us)"
					forv h = 0/$hmax {
						if "`N`h''" == "" continue
						post `pf' ("ts") ("`c'") ("`vr'") ("`s'") ("`y'") (`h') (el(R, `h'+1, 1)) (el(R, `h'+1, 2)) (el(R, `h'+1, 3)) (`N`h'') (`t0`h'') (`t1`h'')
						local N`h' ""
					}
				}
				if inlist("`vr'", "rf", "base") continue
				di as txt "1° stadio `c' `vr' `s' (strumenti `zi') -> `y': F efficace di Montiel Olea-Pflueger min " %6.1f `fmin' ", max " %6.1f `fmax'
				di as txt "  F efficace per h = 0,...,$hmax:`flist'"
				di as txt "  valore critico (tau = $lp_ivtau%):`clist'"
				di as txt "  campione: shock " %tq `s0' "-" %tq `s1' " (h = 0); outcome fino a " %tq `ylast'
				if "`weak'" != "" di as err "  ATTENZIONE: strumenti deboli (F efficace < valore critico) per h =`weak'"
			}
		}
	}
	restore
}

postclose `pf'

*******************************************************************************
* 2) Risultati: intervalli di confidenza, Excel e grafici
*******************************************************************************

use ${out}/lp_energy_iv_ea.dta, clear
* Bande centrate su bc (= b tranne che per le LP smussate: stima con undersmoothing)
gen lo90 = bc - invnormal(0.95)*se
gen hi90 = bc + invnormal(0.95)*se
save ${out}/lp_energy_iv_ea.dta, replace
export excel using ${out}/lp_energy_iv_ea.xlsx, firstrow(var) replace

local lab_base "Baseline (smooth LP)"
local lab_unsm "Unsmoothed"
local lab_umid "Monthly instruments"
local lab_pre  "Pre-Covid"
local sty_base "lcolor(navy) lwidth(medthick)"
local sty_unsm "lcolor(orange) lwidth(medthick) lpattern(longdash_dot)"
local sty_umid "lcolor(maroon) lwidth(medthick) lpattern(shortdash)"
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

		* --- Appendice: paesi, asse y comune se le bande hanno ampiezze simili ($lp_ytol) --- *
		local gl ""
		local units : subinstr global countries "`mg'" "", word
		lp_ypanels if `sel', units(`units')
		foreach g of local units {
			local yax_`g' "`r(`g')'"
		}
		foreach g of global countries {
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
				xtitle("Quarters") ytitle("pp") xlabel(0(2)$hmax) `yax_`g'' ///
				graphregion(color(white) margin(vsmall)) name(g_`g', replace) nodraw
			local gl "`gl' g_`g'"
		}
		if "`gl'" != "" {
			graph combine `gl', imargin(tiny) graphregion(color(white) margin(vsmall)) name(comb, replace)
			graph export ${gph}/lp_iv_app_`s'_`y'.png, replace
		}

		* --- Robustezza: LP non smussate, strumenti mensili e pre-Covid per l'EA --- *
		local rc `"if geo == "`mg'" & shock == "`s'" & outcome == "`y'""'
		local pl `"(rarea lo90 hi90 h `rc' & variant == "base", color(gs13))"'
		local lg ""
		local k = 1
		foreach vr in base unsm umid pre {
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

* --- Petrolio (blu) e gas (rosso) nello stesso grafico, bande al 90%: LP-IV smussate (base,
* prefisso lp_iv_) e forma ridotta (rf, prefisso lp_rf_) --- *
local o : word 1 of $lp_ivshocks
local g : word 2 of $lp_ivshocks
local others : subinstr global countries "EA" "", word
local pfx_base "lp_iv"
local pfx_rf   "lp_rf"
local lo_base  "Oil price"
local lg_base  "Gas price"
local lo_rf    "Oil supply news shock"
local lg_rf    "Gas supply shock"
foreach vr in base rf {
	local px "`pfx_`vr''"
	foreach y of global lp_outcomes {
		qui count if variant == "`vr'" & inlist(shock, "`o'", "`g'") & outcome == "`y'"
		if r(N) == 0 continue
		lp_ypanels if variant == "`vr'" & inlist(shock, "`o'", "`g'") & outcome == "`y'", units(EA `others')
		foreach c in EA `others' {
			local yax_`c' "`r(`c')'"
		}
		local gl ""
		local lco ""
		foreach c in EA `others' {
			local co `"if geo == "`c'" & variant == "`vr'" & shock == "`o'" & outcome == "`y'""'
			local cg `"if geo == "`c'" & variant == "`vr'" & shock == "`g'" & outcome == "`y'""'
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
				file open `fh' using "${gph}/smp_`px'_og_EA_`y'.tex", write replace
				file write `fh' "oil `po0'--`po1'; gas `pg0'--`pg1'"
				file close `fh'
				twoway `pl', yline(0, lcolor(black)) legend(order(3 "`lo_`vr''" 4 "`lg_`vr''") rows(1) position(6)) ///
					xtitle("Quarters") ytitle("pp") xlabel(0(2)$hmax) ///
					graphregion(color(white)) name(gog, replace)
				graph export ${gph}/`px'_og_EA_`y'.png, replace
			}
			twoway `pl', yline(0, lcolor(black)) legend(off) ///
				subtitle("`c'" "Oil `qo0'–`qo1'; gas `qg0'–`qg1'", size(small)) ///
				xtitle("Quarters", size(small)) ytitle("pp") xlabel(0(2)$hmax) `yax_c' ///
				graphregion(color(white) margin(vsmall)) name(g_`c', replace) nodraw
			local gl "`gl' g_`c'"
		}
		if "`gl'" == "" continue
		* Riquadro con la sola legenda: un solo punto per serie, quindi le linee non si vedono
		twoway (line b h `lco', lcolor(navy) lwidth(medthick)) (line b h `lcg', lcolor(cranberry) lp(longdash) lwidth(medthick)), ///
			legend(order(1 "`lo_`vr''" 2 "`lg_`vr''") cols(1) ring(0) position(0) size(large) region(lstyle(none))) ///
			xscale(off) yscale(off) xlabel(none) ylabel(none) xtitle("") ytitle("") ///
			plotregion(style(none)) graphregion(color(white)) name(g_leg, replace) nodraw
		local gl "`gl' g_leg"
		graph combine `gl', imargin(tiny) graphregion(color(white) margin(vsmall)) name(comb, replace)
		graph export ${gph}/`px'_og_ctry_`y'.png, replace
		* Versione quadrata (nota e slide)
		graph combine `gl', imargin(tiny) cols(3) xsize(6) ysize(6) graphregion(color(white) margin(vsmall)) name(combsq, replace)
		graph export ${gph}/`px'_og_ctry_`y'_sq.png, replace
	}
}

log close
