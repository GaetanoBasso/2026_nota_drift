# 2026_nota_drift

Note on the pass-through of energy price shocks (oil, gas, electricity) to wages
in the main euro area countries (DE, FR, IT, ES, NL, BE) and the euro area aggregate (EA),
at quarterly frequency.

Outcomes:

- **negotiated wages** (ECB indicator of negotiated wage rates, `contr`);
- **national accounts gross wages per hour** (`wageH`);
- **HICP inflation** (`hicp`);
- in the appendix: **hours worked** (`occH`, quarter-on-quarter % change) and the
  **unemployment rate** (`dur`, quarter-on-quarter change in pp).

The gap between negotiated wages and national accounts wages is the *wage drift*,
which gives the note its name.

## Repository structure

```
dofiles/
  master.do              paths, parameters, runs the whole project
  cr_dataset_ea.do       builds the quarterly country panel  -> data/dataset_ea.dta
  an_lp_energy_ea.do     OLS Local Projections of energy shocks -> output/, graphs/ (switched off in master.do)
  an_lpiv_energy_ea.do   IV Local Projections, oil and gas, time series -> output/, graphs/lp_iv_*
logfiles/                one text log per dofile (log_<dofile name>.txt)
main_graphs.tex          LaTeX file collecting the graphs (compile in ${home}, next to graphs/)
nota_drift.tex           2-page policy note (English): results (placeholders), methodology, discussion
slides_drift.pptx        2-slide PowerPoint deck (English) with the oil+gas wage graphs
make_slides_drift.js     builds slides_drift.pptx from graphs/ (node + npm package pptxgenjs)
```

Only `dofiles/`, `logfiles/`, `graphs/`, `README.md`, `CLAUDE.md`, the two `.tex` files and the
slides (`slides_drift.pptx`, `make_slides_drift.js`) are tracked (see `.gitignore`); graphs are
committed so that Overleaf can compile the `.tex` files.
Data and output live on the shared drive under `${home}`
(`/home/group/main/892fl/policy/2026/2026_nota_drift` on Unix,
`//osiride-fs/group/main/892fl/...` on Windows).

## How to run

Run `dofiles/master.do` in Stata 18. It sets the paths and parameters and then runs,
in order:

1. `cr_dataset_ea.do`: builds the dataset;
2. `an_lp_energy_ea.do`: estimates the Local Projections.

Requirements:

- `getTimeSeries`, used to download the ECB and Eurostat series. It is not an official Stata or SSC
  command, so it has to be available in the environment where the code runs.
- `xtscc` (Hoechle, 2007), from SSC. `an_lp_energy_ea.do` installs it if it is missing.
- Internet access from Stata to the Bundesbank SDMX API (1-year Bund yield, downloaded
  with `import delimited`).
- Read access to the shared folders `${source_na}` and `${source_contr}`, and to
  `${home}/rawdata/Data_OIL_ELE_GAS.xlsx`.

## Data (`cr_dataset_ea.do`)

| Variable | Description | Source |
|---|---|---|
| `wageH`, `compH`, `defl`, `clupH` | National accounts: wages per hour, compensation of employees per hour, GDP deflator, unit labour cost per hour (year-on-year % change) | Eurostat quarterly national accounts, from the internal file `${source_na}/CN_dataset_dest.dta` (variables `*HT*`, `deflT*`) |
| `vagh` | Total economy value added, quarter-on-quarter % change | same file (variables `vaghT*`) |
| `occP` | Employment (persons), level; weight of the panel LPs | same file (variables `occPT*`) |
| `occH` | Hours worked, total economy, quarter-on-quarter % change | same file (variables `occHT*`) |
| `contr` | Indicator of negotiated wage rates (INWR), total economy, annual growth rate (`GY`), quarterly | ECB INW dataset, downloaded with `getTimeSeries ECB_RESTR INW/.......`. For DE and FR the national provider series (`DE2`, `FR2`) are used |
| `hicp` | HICP all items (index 2015=100), year-on-year % change of the quarterly average | Eurostat `prc_hicp_midx`, downloaded with `getTimeSeries`; EA = EA20 |
| `hicpx` | Core HICP: all items excluding energy, food, alcohol and tobacco (index 2015=100), year-on-year % change. Kept in the dataset, not used in the estimates | Eurostat `prc_hicp_midx` (`TOT_X_NRG_FOOD`), `getTimeSeries` |
| `lip` | Log of industrial production (B–D, seasonally and calendar adjusted, 2021=100), quarterly average | Eurostat `sts_inpr_m`, `getTimeSeries` |
| `ur` | Unemployment rate (seasonally adjusted, % of labour force), quarterly average | Eurostat `une_rt_m`, `getTimeSeries` |
| `dur` | Quarter-on-quarter change of `ur` (pp) | computed from `ur` |
| `bund1y` | 1-year Bund yield (Svensson term structure, residual maturity 1 year), quarterly average, common to all countries | Deutsche Bundesbank, series `BBSIS.M.I.ZST.ZI.EUR.S1311.B.A604.R01XX.R.A.A._Z._Z.A` |
| `gasAG` | Gas supply shock of Alessandri and Gazzani (2025, *Journal of Monetary Economics* 151, 103749), quarterly average of the monthly series; `gasAG1`–`gasAG3`: shock in the 1st, 2nd and 3rd month of the quarter; common to all countries; instrument for the gas price in the IV LPs | `GasSupplyShocks.xlsx`, sheet `2025update` (authors' Dropbox), downloaded by `cr_dataset_ea.do` |
| `oilMP` | Oil supply news shock of Mori and Peersman, column "Updated sample 2025m12", quarterly average of the monthly series; `oilMP1`–`oilMP3`: shock in the 1st, 2nd and 3rd month of the quarter; common to all countries; instrument for the oil price in the IV LPs | authors' Google spreadsheet (exported as csv), downloaded by `cr_dataset_ea.do` |
| `OilSpotUSDBarrel` | Oil spot price, USD per barrel | `rawdata/Data_OIL_ELE_GAS.xlsx` (monthly) |
| `TTFSpotEURMWH` | Dutch TTF natural gas spot price, EUR/MWh | same file |
| `ELEEURMWH` | Wholesale electricity price, EUR/MWh, country-specific (not available for EA; for BE only if the file has a column `ELE_BelgiumEURMWH`) | same file |

Steps:

1. National accounts series are reshaped into a long panel (`geo` × `timeq`).
2. Negotiated wages: the ECB quarterly INWR annual growth rates are downloaded
   directly and saved to `${data}/ecb_inwr_q.dta`. The earlier block that averaged
   the monthly file `dati_retr_pubblici_1.dta` to quarterly frequency is kept but
   commented out.
3. HICP: monthly indices are averaged over complete quarters, turned into
   year-on-year % changes and saved to `${data}/eurostat_hicp_ea_q.dta`.
4. Core HICP, industrial production and unemployment (monthly, Eurostat) are averaged
   over complete quarters; the 1-year Bund yield (monthly, Bundesbank) likewise. The
   Alessandri–Gazzani gas supply shock and the Mori–Peersman oil supply news shock are
   downloaded directly from the authors' files (Stata `copy`) and averaged by quarter.
5. Energy prices: the monthly data are averaged to quarterly, turned into year-on-year
   % changes, and reshaped by country. Oil and gas are common to all countries.
   Electricity is country-specific. EA gets an empty electricity column so that oil and
   gas are also available for EA.
6. All sources are merged (the Bund yield by quarter). `wageH compH defl clupH hicpx` are turned into
   year-on-year % changes (`100*x/L4.x - 100`) and `vagh` into a quarter-on-quarter
   % change (`100*x/L.x - 100`), as are hours worked `occH`; `dur = ur - L.ur`;
   `lip = ln(ip)`.
7. The result is saved to `${data}/dataset_ea.dta`.

## Analysis (`an_lp_energy_ea.do`)

Local Projections (Jordà, 2005). Each energy price is used as a shock on its own, and
each variable in `$lp_outcomes` (`contr hicp wageH occH dur`) is used as the outcome
on its own, for
horizons h = 0, …, 12 quarters (`$hmax`):

```
y(i,t+h) = a(i,h) + b(h) s(i,t) + Σ_{l=1..p} [ c(l,h) y(i,t-l) + d(l,h) s(i,t-l) + f(l,h)' x(i,t-l) ]
           + k(h) covid(t) + e(i,t+h)
```

- `s` is the year-on-year % change of the energy price, divided by 10, so `b(h)` is the
  response (in pp) to a **+10 pp increase in the year-on-year growth of the energy
  price**. `y` is a year-on-year % change (`contr hicp wageH`), a quarter-on-quarter
  % change (`occH`) or a quarter-on-quarter difference (`dur`).
- `p = $lp_lags` (default 4 quarters) lags of the outcome, the shock and the macro
  controls `x` = `$lp_controls` (log industrial production, unemployment rate, 1-year
  Bund yield, as in Corsello and Foschi, 2026) are used as controls, plus a COVID dummy
  for 2020q1–2022q4 when `$covid_dum = 1` (default). For `dur` the lags of `ur` are left
  out, because they are collinear with the lags of the outcome.
- **Panel LP**: pooled over `$lp_panel` (DE IT NL ES FR BE). EA is left out because it
  is the aggregate of the other countries. The regression is weighted by fixed
  country weights, equal to each country's average employment over the whole period
  (`wP`, the country mean of `occP`; analytic weights), includes country
  fixed effects and uses Driscoll–Kraay standard errors (Driscoll and Kraay, 1998) with h+1
  lags, via `xtscc` (version 1.4 or later is needed for weights with fixed effects;
  `which xtscc` prints the installed version in the log). Oil and gas are common to all countries, so time fixed effects
  cannot be included.
- **Time-series LP**: one regression per country in `$countries` (including EA), with
  Newey–West standard errors (Newey and West, 1987) and h+1 lags. Electricity is
  skipped for EA because there is no series for it.
- **Robustness variant** (`variant`): `base`; `pre` = pre-Covid data only (t and t+h up
  to 2019q4), without the COVID dummy.
- **Sample period**: stored as `tmin`/`tmax` (first and last shock date t at h = 0).
  It is shown in the panel labels of the appendix figures and written to
  `graphs/smp_<figure>.tex` for `lp_main_*` and `lp_og_EA_*`, which the `.tex` files read.

Outputs:

- `${out}/lp_energy_ea.dta` / `.xlsx`: one row per `spec` (panel/ts) × `geo` ×
  `variant` × `shock` × `outcome` × `h`, with `b`, `se`, `N`, `tmin`, `tmax` and
  90% bands.
- Graphs (no titles: titles and notes are in the `.tex` files; 90% bands only):
  - `lp_og_EA_<outcome>.png`: EA, oil (blue) and gas (red) in the same graph, with a
    legend — main text of `main_graphs.tex` for `contr hicp wageH`, appendix for `occH dur`;
  - `lp_og_ctry_<outcome>.png`: EA and the six countries, oil and gas, common y axis,
    legend in a cell of its own (`_sq`: square version, used in the note and the slides);
  - `lp_main_<shock>_<outcome>.png`: appendix, one energy price, EA for oil and gas,
    panel for electricity;
  - `lp_app_<shock>_<outcome>.png`: appendix, one energy price, the panel (oil, gas)
    and the countries, with a common y axis;
  - `lp_rob_<shock>_<outcome>.png`: appendix, baseline vs pre-Covid sample for the
    unit of `lp_main_*`.

Graph labels, the `.tex` files and the slides are in English (dofile comments stay in
Italian). `nota_drift.tex` (2-page policy note) and `slides_drift.pptx` (2 slides) use the
oil+gas graphs for negotiated wages and hourly wages. The note leaves placeholders
(`\tbc{...}`, shown in red) where the results have to be described. The slides are built
by `node make_slides_drift.js` from the repository root: missing graphs become placeholder
boxes and the EA sample periods are read from `graphs/smp_lp_og_EA_*.tex`, so the deck has
to be rebuilt after each Stata run.

## IV Local Projections (`an_lpiv_energy_ea.do`)

Run by `master.do` instead of the OLS file (the OLS call is in a block comment). Same
time-series specification, controls and horizons as the OLS LPs, for EA and each country
(no panel), but the year-on-year change of the oil price is instrumented with the
Mori–Peersman oil supply news shock and that of the gas price with the Alessandri–Gazzani
gas supply shock (`$lp_ivshocks`, `$lp_ivinstr`); electricity has no instrument. 2SLS with
`ivreg2`, Newey–West standard errors with h+1 lags.

- **Mixed frequency.** The instruments are monthly, the LPs quarterly. Baseline: the three
  monthly shocks of quarter t enter as three separate instruments (unrestricted MIDAS,
  Foroni, Marcellino and Schumacher, 2015), so the first stage estimates how much each
  month moves the quarterly average price (a shock early in the quarter affects all three
  months of the average, a late one only one), conditional on all quarterly controls
  including the lags of the outcome. Variant `qsum`: one instrument, the quarterly average
  of the monthly shocks (equal weights). Variant `pre`: baseline on pre-Covid data only.
- **Sample.** Shock dates t need the instruments, the price and the controls; the outcome
  at t+h can extend beyond the end of the instruments. The log reports, for each series,
  the shock dates and the last outcome quarter used.
- **Controls.** Both stages include the lags of the outcome, of the price change and of
  the macro controls, as in the OLS LPs.
- **First stage.** Effective F of Montiel Olea and Pflueger (2013), computed with
  `weakivtest` (Pflueger and Wang, 2015; SSC, needs `avar`) after each `ivreg2`, robust to
  heteroskedasticity and autocorrelation. Reported only in the log (minimum, maximum and
  value at each horizon, with the critical value); a warning is printed when it is below
  the critical value for a maximum 2SLS bias of `$lp_ivtau`% (default 10%).
- **Outputs.** `${out}/lp_energy_iv_ea.dta` / `.xlsx`; graphs with prefix `lp_iv_`
  (`og_EA`, `og_ctry` and `_sq`, `main`, `app`, `rob` with baseline, pre-Covid and
  quarterly-average instrument). The `.tex` files and the slides use the IV graphs; the
  OLS graphs of the last OLS run are shown in an appendix of `main_graphs.tex` for
  comparison (including electricity, which has no instrument).

Caveat (OLS): the "shocks" are observed energy price changes, conditioned on their own lags
and on lags of the outcome. They are not identified structural shocks, so the
responses should be read as conditional reduced-form pass-through.

## References

- Jordà, Ò. (2005), "Estimation and Inference of Impulse Responses by Local
  Projections", *American Economic Review*, 95(1), 161–182.
  <https://doi.org/10.1257/0002828053828518>
- Driscoll, J. C. and Kraay, A. C. (1998), "Consistent Covariance Matrix Estimation
  with Spatially Dependent Panel Data", *Review of Economics and Statistics*, 80(4),
  549–560. <https://doi.org/10.1162/003465398557825>
- Hoechle, D. (2007), "Robust standard errors for panel regressions with
  cross-sectional dependence", *Stata Journal*, 7(3), 281–312.
  <https://doi.org/10.1177/1536867X0700700301>
- Corsello, F. and Foschi, A. (2026), "The different effects of oil and gas supply
  shocks on euro-area inflation", Banca d'Italia, *Questioni di Economia e Finanza
  (Occasional Papers)*, No. 1024.
- Foroni, C., Marcellino, M. and Schumacher, C. (2015), "Unrestricted mixed data sampling
  (MIDAS): MIDAS regressions with unrestricted lag polynomials", *Journal of the Royal
  Statistical Society: Series A*, 178(1), 57–82. <https://doi.org/10.1111/rssa.12043>
- Stock, J. H. and Watson, M. W. (2018), "Identification and Estimation of Dynamic Causal
  Effects in Macroeconomics Using External Instruments", *Economic Journal*, 128(610),
  917–948. <https://doi.org/10.1111/ecoj.12593>
- Montiel Olea, J. L. and Pflueger, C. (2013), "A Robust Test for Weak Instruments",
  *Journal of Business and Economic Statistics*, 31(3), 358–369.
- Pflueger, C. and Wang, S. (2015), "A Robust Test for Weak Instruments in Stata",
  *Stata Journal*, 15(1), 216–225. <https://doi.org/10.1177/1536867X1501500113>
- Newey, W. K. and West, K. D. (1987), "A Simple, Positive Semi-Definite,
  Heteroskedasticity and Autocorrelation Consistent Covariance Matrix",
  *Econometrica*, 55(3), 703–708. <https://doi.org/10.2307/1913610>
- ECB Data Portal, Negotiated wages:
  <https://data.ecb.europa.eu/data/data-categories/prices-macroeconomic-and-sectoral-statistics/other-prices-and-costs/labour-costs/negotiated-wages>
- Eurostat, HICP monthly data (index) (`prc_hicp_midx`):
  <https://ec.europa.eu/eurostat/databrowser/view/prc_hicp_midx/default/table>
- ECB Data Portal, INWR series (example, euro area annual rate):
  <https://data.ecb.europa.eu/data/datasets/STS/STS.Q.I9.N.INWR.000000.3.ANR>
- ECB Data Portal, Indicator of negotiated wage rates (INW) dataset:
  <https://data.ecb.europa.eu/data/datasets/inw/data-information>
- Eurostat, quarterly national accounts: GDP and main components
  (`namq_10_gdp`): <https://ec.europa.eu/eurostat/databrowser/product/view/namq_10_gdp>;
  employment and hours by industry (`namq_10_a10_e`), available e.g. via DBnomics:
  <https://db.nomics.world/Eurostat/namq_10_a10_e>
