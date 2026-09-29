clear
set more off

local a="/home/group/main/892fl/dati/ecb/contrattuali/dta"
local b="/home/group/main/892fl/dati/ecb/contrattuali/excel"
local c="/home/group/main/892fl/segnalazioni/segnalazione_area_euro/output/eps"



getTimeSeries ECB STS_PUB/Q.I10+IT+DE+ES+NL.N.INWR.000000.3+4+5+1+2.000 "" "" 0 0

rename *, low replace

gen anno=real(substr(date,1,4))

gen trim=real(substr(date,7,1))
drop if anno<1995

gen name=subinstr(tsname, "ECB_STS1.Q.", "", .)
drop tsname

gen l=length(name)

gen country=substr(name,`l'-22,2) 


gen cod=substr(name,`l'-17,4) 
drop  date l name name 

*keep if anno>=2005
gen time=yq(anno, trim)
format time %tqCY,q

replace country="EA" if country=="I10"

drop cod
reshape wide value, i(anno trim time) j(country) string
rename value* *
save `a'/ECB_sts1m_q_inwr.dta,replace
clear

* per la Francia prendo la serie con codice 2 altrimenti si blocca per i dati duplicati


getTimeSeries ECB STS_PUB/Q.FR.N.INWR.000000.2.000 "" "" 0 0
rename *, low replace

gen anno=real(substr(date,1,4))

gen trim=real(substr(date,7,1))
drop if anno<1995

gen name=subinstr(tsname, "ECB_STS1.Q.", "", .)
drop tsname

gen l=length(name)

gen country=substr(name,`l'-22,2) 


gen cod=substr(name,`l'-17,4) 
drop  date l name name 

*keep if anno>=2005
gen time=yq(anno, trim)
format time %tqCY,q
drop cod
reshape wide value, i(anno trim time) j(country) string
rename value* *
save `a'/ECB_sts1m_q_inwr_FR.dta,replace
merge 1:1 anno trim using `a'/ECB_sts1m_q_inwr.dta
drop _merge
order anno trim 
save `a'/ECB_sts1m_q_inwr.dta,replace

export excel using "`b'/ECB_sts_q.xlsx", sheetreplace firstrow(var) sheet("inwr")


clear
getTimeSeries ECB_STS_PUB/Q.DE+I10+NL.N.INWX.000000.1+2+3+4+5.ANR "" "" 0 0


rename *, low replace

gen anno=real(substr(date,1,4))

gen trim=real(substr(date,7,1))
drop if anno<1995

gen name=subinstr(tsname, "ECB_STS1.Q.", "", .)
drop tsname

gen l=length(name)

gen country=substr(name,`l'-22,2) 


gen cod=substr(name,`l'-17,4) 
drop  date l name name 


*keep if anno>=2010
gen time=yq(anno, trim)
format time %tqCY,q

replace country="EA" if country=="I10"
 
drop cod
reshape wide value, i(anno trim time) j(country) string
rename value* *

save `a'/ECB_sts1m_q_inwx.dta,replace
order anno trim time 
export excel using "`b'/ECB_sts_q.xlsx", sheetreplace firstrow(var) sheet("inwx")













/*
clear

use `r'/datim.dta
keep anno trim vrehcge vrehcpri 
rename trim month
rename vrehcge IT
keep if anno>=2011
gen time=ym(anno, month)
format time %tmCY,m

save `a'/retr_IT.dta, replace
merge 1:m anno month time using `a'/ECB_sts1m.dta
drop _merge
sort time
save `a'/ECB_sts1m.dta,replace

order anno month time 
export excel using "`b'/ECB_sts1m.xlsx", sheetreplace firstrow(var) sheet("retribuzioni")

rename time date
keep if anno>=2018
drop if ES==.
/*Produrre la figura*/
egen aa=max(date)
egen bb=min(date)
local start=bb
local end=aa-1

#delimit;
line EA date, c(l) lcolor(black) lpattern(solid)         lwidth(thick) ||
line FR date, c(l) lcolor(blue)  lpattern(shortdash)     lwidth(thick) ||
line DE date, c(l) lcolor(black) lpattern(shortdash)     lwidth(thick) ||
line IT date, c(l) lcolor(red)   lpattern(solid)      lwidth(thick) ||
line NL date, c(l) lcolor(blue)  lpattern(solid)         lwidth(thick) yaxis(2) xaxis(2) ||
line ES date, c(l) lcolor(green) lpattern(solid)         lwidth(thick) 
legend(on)legend(symxsize(6) symysize(6) size(*1.5) order(1 2 3 4 6 5) rows(2) cols(6) region(c(white))
lab(1 "Area dell'euro") lab(2 "Francia") lab(3 "Germania") lab(4 "Italia") lab(5 "Spagna") lab(6 "Paesi Bassi"))
legend(ring(2) col(1)) 
/*title("Dinamica delle retribuzioni contrattuali")
subtitle("(variazioni tendenziali)")*/
ylabel(0(1)4, format(%2.0fc) labsi(*1.5) angle(0)axis(1)) 
ylabel(0(1)4, format(%2.0fc) labsi(*1.5) angle(0)axis(2)) 
tlabel(`start'(12)`end',labsi(*1.5)  format(%tmCY) noticks angle(horizontal) axis(1 2)) tmtick(##12, tp(i))
xli(696(12)744, lc(ltblue) lw(vthin))
xlabel("", axis(2)) 
graphregion(c(white)) yti("") yti("",axis(2)) xti("") xti("",axis(2)) ysize(3.5) xsize(6.5);
graph export `c'/graf_retrib.png, replace;
graph export `c'/graf_retrib.pdf, replace;
