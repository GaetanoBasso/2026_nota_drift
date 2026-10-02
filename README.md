# 2026_nota_drift

Note on the pass-through of energy price shocks (oil, gas, electricity) to wages
in the main euro area countries (DE, FR, IT, ES, NL, BE) and the euro area aggregate (EA),
at quarterly frequency.

Three wage/price measures are compared:

- **negotiated wages** (ECB indicator of negotiated wage rates, `contr`);
- **national accounts wages per hour** (`wageH`) and **compensation per hour** (`compH`);
- **HICP inflation** (`hicp`).

The gap between negotiated wages and national accounts wages is the *wage drift*,
which gives the note its name.

## Repository structure

```
dofiles/
  master.do              paths, parameters, runs the whole project
  cr_dataset_ea.do       builds the quarterly country panel  -> data/dataset_ea.dta
  an_lp_energy_ea.do     Local Projections of energy shocks -> output/, graphs/
logfiles/                one text log per dofile (log_<dofile name>.txt)
main_graphs.tex          LaTeX file collecting the graphs (compile in ${home}, next to graphs/)
```

Only `dofiles/`, `logfiles/`, `graphs/`, `README.md`, `CLAUDE.md` and `main_graphs.tex` are tracked
(see `.gitignore`); graphs are committed so that Overleaf can compile `main_graphs.tex`.
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
| `contr` | Indicator of negotiated wage rates (INWR), total economy, annual growth rate (`GY`), quarterly | ECB INW dataset, downloaded with `getTimeSeries ECB_RESTR INW/.......`. For DE and FR the national provider series (`DE2`, `FR2`) are used |
| `hicp` | HICP all items (index 2015=100), year-on-year % change of the quarterly average | Eurostat `prc_hicp_midx`, downloaded with `getTimeSeries`; EA = EA20 |
| `hicpx` | Core HICP: all items excluding energy, food, alcohol and tobacco (index 2015=100), year-on-year % change; defines the inflation state | Eurostat `prc_hicp_midx` (`TOT_X_NRG_FOOD`), `getTimeSeries` |
| `lip` | Log of industrial production (B–D, seasonally and calendar adjusted, 2021=100), quarterly average | Eurostat `sts_inpr_m`, `getTimeSeries` |
| `ur` | Unemployment rate (seasonally adjusted, % of labour force), quarterly average | Eurostat `une_rt_m`, `getTimeSeries` |
| `bund1y` | 1-year Bund yield (Svensson term structure, residual maturity 1 year), quarterly average, common to all countries | Deutsche Bundesbank, series `BBSIS.M.I.ZST.ZI.EUR.S1311.B.A604.R01XX.R.A.A._Z._Z.A` |
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
   over complete quarters; the 1-year Bund yield (monthly, Bundesbank) likewise.
5. Energy prices: the monthly data are averaged to quarterly, turned into year-on-year
   % changes, and reshaped by country. Oil and gas are common to all countries.
   Electricity is country-specific. EA gets an empty electricity column so that oil and
   gas are also available for EA.
6. All sources are merged (the Bund yield by quarter). `wageH compH defl clupH hicpx` are turned into
   year-on-year % changes (`100*x/L4.x - 100`) and `vagh` into a quarter-on-quarter
   % change (`100*x/L.x - 100`); `lip = ln(ip)`.
7. The result is saved to `${data}/dataset_ea.dta`.

## Analysis (`an_lp_energy_ea.do`)

Local Projections (Jordà, 2005). Each energy price is used as a shock on its own, and
each variable in `$lp_outcomes` (`contr hicp wageH compH`) is used as the outcome
on its own, for
horizons h = 0, …, 12 quarters (`$hmax`):

```
y(i,t+h) = a(i,h) + b(h) s(i,t) + Σ_{l=1..p} [ c(l,h) y(i,t-l) + d(l,h) s(i,t-l) + f(l,h)' x(i,t-l) ]
           + k(h) covid(t) + e(i,t+h)
```

- `y` and `s` are year-on-year % changes. `s` is divided by 10, so `b(h)` is the
  response in percentage points of the outcome's year-on-year growth to a
  **+10 pp increase in the year-on-year growth of the energy price**.
- `p = $lp_lags` (default 4 quarters) lags of the outcome, the shock and the macro
  controls `x` = `$lp_controls` (log industrial production, unemployment rate, 1-year
  Bund yield, as in Corsello and Foschi, 2026) are used as controls, plus a COVID dummy
  for 2020q1–2022q4 when `$covid_dum = 1` (default).
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
- **Robustness variants** (`variant`): `base`; `pre` = only observations with
  t+h ≤ 2019q4 (no COVID dummy); `post` = only shocks from 2020q1 (country time series
  are often not estimable: too few observations); `seas` = `base` plus quarter fixed
  effects.
- **Sample period**: stored as `tmin`/`tmax` (first and last shock date t at h = 0).
  It is shown in the panel labels of the appendix figures and written to
  `graphs/smp_<figure>.tex` for the main figures, which `main_graphs.tex` reads.

### High vs low inflation at the time of the shock (section 4)

Following Corsello and Foschi (2026), a quarter t is **high inflation** (`hinf = 1`)
if core HICP inflation (`hicpx`) in t-1 is above `$infl_thr` (default 2%); all other
quarters are **low inflation**. The threshold and timing are an assumption to be
checked against the paper. The LPs are re-estimated with every regressor interacted
with `hinf` and `1-hinf`, plus `hinf` itself (as in Ramey and Zubairy, 2018). This gives
`bH` and `bL`, with a test of their equality (`pdiff`).

Outputs:

- `${out}/lp_energy_ea.dta` / `.xlsx`: one row per `spec` (panel/ts) × `geo` ×
  `variant` × `shock` × `outcome` × `h`, with `b`, `se`, `N`, `tmin`, `tmax` and
  68% / 90% bands.
- `${out}/lp_energy_inflstate_ea.dta` / `.xlsx`: inflation-state results, with
  `bH seH bL seL pdiff N NH tmin tmax` (`NH` = high-inflation observations).
- Graphs (no titles: titles and notes are in `main_graphs.tex`):
  - `lp_main_<shock>_<outcome>.png`: main figure, EA for oil and gas, panel for
    electricity;
  - `lp_app_<shock>_<outcome>.png`: appendix, the panel (oil, gas) and the countries,
    with a common y axis;
  - `lp_rob_<shock>_<outcome>.png`: appendix, robustness variants for the main unit;
  - `lp_inflstate_main_*` / `lp_inflstate_app_*`: the same for the inflation state.

Caveat: the "shocks" are observed energy price changes, conditioned on their own lags
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
- Ramey, V. A. and Zubairy, S. (2018), "Government Spending Multipliers in Good
  Times and in Bad: Evidence from US Historical Data", *Journal of Political Economy*,
  126(2), 850–901. <https://doi.org/10.1086/696277>
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
