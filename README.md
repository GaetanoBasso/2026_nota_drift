# 2026_nota_drift

Note on the pass-through of energy price shocks (oil, gas, electricity) to wages
in the main euro area countries (DE, FR, IT, ES, NL, BE) and the euro area aggregate (EA),
at quarterly frequency.

Three wage/price measures are compared:

- **negotiated wages** (ECB indicator of negotiated wage rates, `contr`);
- **national accounts wages per hour** (`wageH`) and **compensation per hour** (`compH`);
- the **GDP deflator** (`defl`) and **HICP inflation** (`hicp`).

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

Only `dofiles/`, `logfiles/`, `README.md`, `CLAUDE.md` and `main_graphs.tex` are tracked (see `.gitignore`).
Data, output and graphs live on the shared drive under `${home}`
(`/home/group/main/892fl/policy/2026/2026_nota_drift` on Unix,
`//osiride-fs/group/main/892fl/...` on Windows).

## How to run

Run `dofiles/master.do` in Stata 18. It sets the paths and parameters and then runs,
in order:

1. `cr_dataset_ea.do`: builds the dataset;
2. `an_lp_energy_ea.do`: estimates the Local Projections.

Requirements:

- `getTimeSeries`, used to download the ECB series. It is not an official Stata or SSC
  command, so it has to be available in the environment where the code runs.
- `xtscc` (Hoechle, 2007), from SSC. `an_lp_energy_ea.do` installs it if it is missing.
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
4. Energy prices: the monthly data are averaged to quarterly, turned into year-on-year
   % changes, and reshaped by country. Oil and gas are common to all countries.
   Electricity is country-specific. EA gets an empty electricity column so that oil and
   gas are also available for EA.
5. The four sources are merged. `wageH compH defl clupH` are turned into
   year-on-year % changes (`100*x/L4.x - 100`) and `vagh` into a quarter-on-quarter
   % change (`100*x/L.x - 100`).
6. The result is saved to `${data}/dataset_ea.dta`.

## Analysis (`an_lp_energy_ea.do`)

Local Projections (Jordà, 2005). Each energy price is used as a shock on its own, and
each variable in `$lp_outcomes` (`contr hicp defl wageH compH`) is used as the outcome
on its own, for
horizons h = 0, …, 12 quarters (`$hmax`):

```
y(i,t+h) = a(i,h) + b(h) s(i,t) + Σ_{l=1..p} [ c(l,h) y(i,t-l) + d(l,h) s(i,t-l) ] + e(i,t+h)
```

- `y` and `s` are year-on-year % changes. `s` is divided by 10, so `b(h)` is the
  response in percentage points of the outcome's year-on-year growth to a
  **+10 pp increase in the year-on-year growth of the energy price**.
- `p = $lp_lags` (default 4 quarters) lags of both the outcome and the shock are used
  as controls.
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
- **Covid**: with `$covid_dum = 1`, observations whose outcome date t+h falls in
  2020q1–2021q4 are dropped (currently `$covid_dum = 0`).
- **Sample period**: every panel of every figure shows in its title the first and
  last shock date t used in the h = 0 regression (stored as `tmin`/`tmax`).

### High vs low growth at the time of the shock (section 4)

A quarter t is **high growth** (`hg = 1`) if `vagh(t)` is above the country's
historical average of `vagh` **and** `vagh(t+1) > 0` **and** `vagh(t+2) > 0`. All other
quarters are **low growth** (`hg = 0`). `hg` is missing when `vagh` is missing in t,
t+1 or t+2. The LPs above are re-estimated with every regressor (shock and lags)
interacted with `hg` and `1-hg`, plus `hg` itself, as in Ramey and Zubairy (2018).
This gives one response for shocks that hit in high-growth quarters (`bH`) and one for
low-growth quarters (`bL`), with a test of their equality (`pdiff`).

Note that the state uses `vagh(t+1)` and `vagh(t+2)`, i.e. information from after the
shock, as requested for this first pass.

Outputs:

- `${out}/lp_energy_ea.dta` and `${out}/lp_energy_ea.xlsx`: one row per
  `spec` (panel/ts) × `geo` × `shock` × `outcome` × `h`, with `b`, `se`, `N` and
  68% / 90% bands.
- `${gph}/lp_<shock>_<outcome>.png`: one figure per shock–outcome pair. Each
  figure shows the panel response and one panel per country.
- `${out}/lp_energy_growthstate_ea.dta` / `.xlsx`: state-dependent results, with
  `bH seH bL seL pdiff N NH tmin tmax` (`NH` = high-growth observations in the sample)
  and 90% bands.
- `${gph}/lp_growthstate_<shock>_<outcome>.png`: high-growth (red) and low-growth
  (blue, dashed) responses with 90% bands, panel plus one panel per country.

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
