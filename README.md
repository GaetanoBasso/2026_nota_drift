# 2026_nota_drift

Note on the pass-through of energy price shocks (oil, gas, electricity) to wages
in the main euro area countries (DE, FR, IT, ES, NL) and the euro area aggregate (EA),
at quarterly frequency.

Three wage/price measures are compared:

- **negotiated wages** (ECB indicator of negotiated wage rates, `contr`);
- **national accounts wages per hour** (`wageH`) and **compensation per hour** (`compH`);
- the **deflator** (`defl`).

The gap between negotiated wages and national accounts wages is the *wage drift*,
which gives the note its name.

## Repository structure

```
dofiles/
  master.do              paths, parameters, runs the whole project
  cr_dataset_ea.do       builds the quarterly country panel  -> data/dataset_ea.dta
  an_lp_energy_ea.do     Local Projections of energy shocks -> output/, graphs/
  EA_retribuzioni_q .do  stand-alone ECB download script (NOT part of the project)
logfiles/                one text log per dofile (log_<dofile name>.txt)
```

Only `dofiles/`, `logfiles/`, `README.md` and `CLAUDE.md` are tracked (see `.gitignore`).
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
| `wageH`, `compH`, `defl`, `clupH` | National accounts: wages per hour, compensation of employees per hour, deflator, unit labour cost per hour | Eurostat quarterly national accounts, from the internal file `${source_na}/CN_dataset_dest.dta` (variables `*HT*`, `deflT*`) |
| `contr` | Indicator of negotiated wage rates (INWR), quarterly | ECB, STS dataset. Downloaded with `getTimeSeries`: `STS_PUB/Q.{I10,IT,DE,ES,NL}.N.INWR.000000.{1..5}.000`, and `Q.FR.N.INWR.000000.2.000` for France |
| `OilSpotUSDBarrel` | Oil spot price, USD per barrel | `rawdata/Data_OIL_ELE_GAS.xlsx` (monthly) |
| `TTFSpotEURMWH` | Dutch TTF natural gas spot price, EUR/MWh | same file |
| `ELEEURMWH` | Wholesale electricity price, EUR/MWh, country-specific (not available for EA) | same file |

Steps:

1. National accounts series are reshaped into a long panel (`geo` × `timeq`).
2. Negotiated wages: the ECB quarterly INWR series are downloaded directly. The
   earlier block that averaged the monthly file `dati_retr_pubblici_1.dta` to quarterly
   frequency is kept but commented out. EA and four countries come in one query; France
   is downloaded separately with institution code 2, because otherwise the series is
   duplicated. The raw download is saved to `${data}/ecb_inwr_q.dta`.
3. Energy prices: the monthly data are averaged to quarterly, turned into year-on-year
   % changes, and reshaped by country. Oil and gas are common to all countries.
   Electricity is country-specific. EA gets an empty electricity column so that oil and
   gas are also available for EA.
4. The three sources are merged. `wageH compH defl clupH contr` are turned into
   year-on-year % changes: `100*x/L4.x - 100`.
5. The result is saved to `${data}/dataset_ea.dta`.

> **Check:** the INWR series are downloaded with suffix `000`. The code treats this as an
> index level and computes year-on-year growth rates. If the series is already an annual
> rate of change (the ECB suffix for that is `ANR`), remove `contr` from the growth-rate
> loop in `cr_dataset_ea.do`.

## Analysis (`an_lp_energy_ea.do`)

Local Projections (Jordà, 2005). Each energy price is used as a shock on its own, and
the deflator, `wageH` and `compH` are each used as the outcome on their own, for
horizons h = 0, …, 12 quarters (`$hmax`):

```
y(i,t+h) = a(i,h) + b(h) s(i,t) + Σ_{l=1..p} [ c(l,h) y(i,t-l) + d(l,h) s(i,t-l) ] + e(i,t+h)
```

- `y` and `s` are year-on-year % changes. `s` is divided by 10, so `b(h)` is the
  response in percentage points of the outcome's year-on-year growth to a
  **+10 pp increase in the year-on-year growth of the energy price**.
- `p = $lp_lags` (default 4 quarters) lags of both the outcome and the shock are used
  as controls.
- **Panel LP**: pooled over `$lp_panel` (DE IT NL ES FR). EA is left out because it
  is the aggregate of the other countries. The regression includes country fixed
  effects and uses Driscoll–Kraay standard errors (Driscoll and Kraay, 1998) with h+1
  lags, via `xtscc`. Oil and gas are common to all countries, so time fixed effects
  cannot be included.
- **Time-series LP**: one regression per country in `$countries` (including EA), with
  Newey–West standard errors (Newey and West, 1987) and h+1 lags. Electricity is
  skipped for EA because there is no series for it.
- **Covid**: with `$covid_dum = 1`, observations whose outcome date t+h falls in
  2020q1–2021q4 are dropped.

Outputs:

- `${out}/lp_energy_ea.dta` and `${out}/lp_energy_ea.xlsx`: one row per
  `spec` (panel/ts) × `geo` × `shock` × `outcome` × `h`, with `b`, `se`, `N` and
  68% / 90% bands.
- `${gph}/lp_<shock>_<outcome>.png`: 9 figures, one per shock–outcome pair. Each
  figure shows the panel response and one panel per country.

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
- Newey, W. K. and West, K. D. (1987), "A Simple, Positive Semi-Definite,
  Heteroskedasticity and Autocorrelation Consistent Covariance Matrix",
  *Econometrica*, 55(3), 703–708. <https://doi.org/10.2307/1913610>
- ECB Data Portal, Negotiated wages:
  <https://data.ecb.europa.eu/data/data-categories/prices-macroeconomic-and-sectoral-statistics/other-prices-and-costs/labour-costs/negotiated-wages>
- ECB Data Portal, INWR series (example, euro area annual rate):
  <https://data.ecb.europa.eu/data/datasets/STS/STS.Q.I9.N.INWR.000000.3.ANR>
- ECB Data Portal, Indicator of negotiated wage rates (INW) dataset:
  <https://data.ecb.europa.eu/data/datasets/inw/data-information>
- Eurostat, quarterly national accounts: GDP and main components
  (`namq_10_gdp`): <https://ec.europa.eu/eurostat/databrowser/product/view/namq_10_gdp>;
  employment and hours by industry (`namq_10_a10_e`), available e.g. via DBnomics:
  <https://db.nomics.world/Eurostat/namq_10_a10_e>
