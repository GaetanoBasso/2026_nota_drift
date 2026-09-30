# CLAUDE.md

Project: pass-through of energy price shocks (oil, gas, electricity) to negotiated
wages, national accounts wages per hour, compensation per hour and deflator in
euro area countries at quarterly frequency (Stata). See `README.md`.

## Project rules

- **Stata 18** (`version 18.0` in `master.do`). There is no Stata in the Claude cloud
  container, so dofiles cannot be run there. Say this explicitly and ask the user to run
  them and share the log.
- **`master.do` is the only entry point.** It defines all paths and parameters as
  globals and runs every dofile in order. A new dofile must be added to `master.do`
  in the right section (1 = data creation, 2 = analysis), with a one-line comment.
- **Dofiles never define paths or parameters.** They use the globals from `master.do`:
  `${stem} ${home} ${do} ${log} ${data} ${out} ${gph} ${source_na} ${source_contr}`,
  `$countries`, `$hmax`, `$covid_dum`, `$lp_*`.
- **Naming**: `cr_*.do` builds data (writes to `${data}`); `an_*.do` runs analysis
  (writes to `${out}` and `${gph}`). The suffix `_ea` stands for the euro area country set.
- **Each dofile opens its own log**:
  `cap log close` then `log using ${log}/log_<dofile name>.txt, t replace`, and ends
  with `log close`. Logs are committed to git.
- **Git tracks only** `dofiles/`, `logfiles/`, `README.md`, `CLAUDE.md` (`.gitignore`
  ignores everything else). Never commit data, output or graphs.
- Do not commit Stata swap files (`~*.stswp`).
- Raw sources on the shared drive (`${source_*}`, `${home}/rawdata`) are **read-only**.
  Never save into them.
- **Line endings**: dofiles use Windows line endings (CRLF). Keep them when editing, so
  that diffs stay clean.

## Data conventions

- Panel in long format: `geo` (string: DE IT FR ES NL BE EA), `geocode` (encoded),
  `timeq` (`%tq`), `year`, `quarter`. `xtset geocode timeq`.
- Country-specific variables are reshaped from wide names with a country suffix
  (e.g. `wageHTDE`, `ELEEURMWHIT`) using `reshape long ..., j(geo) string`.
- Monthly data are made quarterly with `collapse (mean) ..., by(timeq)`.
- Growth rates are year-on-year % changes, computed in place:
  `gen _v = 100*v/l4.v-100`, `drop v`, `rename _v v`.
- Intermediate files are `tempfile`s. Only final datasets are saved to `${data}`.
- Merges are `merge 1:1 timeq geo ..., nogen`. Check the match table in the log.

## Coding style

- Comments are in **Italian**, short, starting with `*`. Section headers use
  `* --- ... --- *` or blocks framed by `*****`.
- Globals are for paths and parameters; locals and `tempfile`s are for everything else.
- Loops use `foreach v of varlist ...` / `foreach x of global ...` / `forv`.
- Put checks in the code (`assert`, `isid`) instead of assuming data properties.
- Minimal code: no wrappers or programs unless they are used more than once.
- LP conventions (`an_lp_energy_ea.do`): horizon `0/$hmax`; the shock is scaled to
  +10 pp; `$lp_lags` lags of the outcome and the shock; panel = country FE +
  Driscoll–Kraay (`xtscc`, lag h+1), weighted by employment `[aw=occP]`; country time series = `newey`, lag h+1. Results
  go to a `postfile` dataset. The estimation sample is marked explicitly
  (`smp` + `markout`), its period is posted as `tmin`/`tmax` and shown in every graph
  title. State-dependent variants interact all regressors with the state dummy and
  carry the state in the output name (e.g. `lp_energy_growthstate_ea`).

## Karpathy guidelines

The request was to copy these from the CLAUDE.md of the RAI repository, but that
repository was not accessible from the session that wrote this file. The text below is
taken from the public source of these guidelines:
<https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md>.

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
