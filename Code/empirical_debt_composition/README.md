# `Code/empirical_debt_composition/` — empirical pipeline (Stata)

This directory reproduces every regression reported in
`Subfiles/Empirical.tex`. It is invoked by `./reproduce.sh --all` from the
repository root.

## Requirements

- **Stata 17+** (tested with Stata/MP 17.0; any flavour — MP, SE, IC — works).
- No additional Stata packages are required. Everything uses base Stata
  (`xtreg`, `reg`, `predict`, `estimates table`, `twoway`, `log`).
- The pipeline is **not reproducible inside the Binder / conda environment**
  declared in `binder/environment.yml`, because Stata is proprietary and
  cannot be conda-installed.
- **Work in progress:** the author is currently porting these `.do`
  files to Python (`pandas` + `linearmodels.PanelOLS` for the
  fixed-effects first stage, clustered-SE OLS for the second stage).
  Once the port lands, the Stata sources will remain here as a
  canonical reference and the Python pipeline will become the default
  entry point, making the paper reproducible inside Binder without a
  Stata license. See the root `README.md` for details.

## Data

- Input: `Data/gfdd_with_de_facto1.dta` (committed, ~870 KB).
- A country–year panel built offline from GFDD, EWN, Chinn-Ito, Quinn, and
  the IMF BOI sovereign-debt investor database. Provenance for each source
  is documented in `Data/README.md`; a scripted rebuild is a follow-up.

## How to run

From the repository root:

```bash
./reproduce.sh --all            # full reproduction (docs + empirics)
./reproduce.sh --empirical      # empirical pipeline only
```

Or directly:

```bash
cd /path/to/emma0502606
stata -b do Code/empirical_debt_composition/run_all.do
```

Both routes call `run_all.do`, which:

1. Loads `Data/gfdd_with_de_facto1.dta`.
2. Runs the five stages described below in order.
3. Writes a master log to `results/run_all.log`.

## Files

| Path | Role | Paper section |
|------|------|---------------|
| `run_all.do` | Master driver (load data, open log, `do` each stage in order) | — |
| `do/threshold_estimation.do` | Two-stage estimator with a `highD = d > 100` threshold dummy; produces `delta_n_th`, `delta_cb_th`, `delta_pb_th`, `highD` that the integration stage consumes | Section 3, baseline threshold |
| `do/threshold_integration_estimation.do` | Adds `de_facto * d` and `cap100 * d` interactions to the second stage; **depends on state left in memory by `threshold_estimation.do`** | Section 3, integration robustness |
| `do/threshold_estimation_centered.do` | Centered-threshold variant (`d_high_c = highD*(d-100)`); self-contained; logs to `results/threshold_centered_results.txt` | Section 3, centered specification |
| `do/threshold_estimation_noconstant.do` | `noconstant` variant of the second stage; self-contained | Section 3, no-intercept check |
| `do/quadratic_nonbank_fullsample.do` | Convexity + pecking-order specifications (linear, quadratic, threshold) across non-banks / CB / private banks; self-contained; logs to `results/quadratic_nonbank_results2.txt` | Section 3, convexity and pecking order |

`run_all.do` runs the first two in a single session (for the state
dependency) and the remaining three in separate fresh sessions.

## Committed outputs

For reviewers without a Stata license, the two key log outputs are
committed under `results/`:

- `results/threshold_centered_results.txt` — produced by
  `threshold_estimation_centered.do`.
- `results/quadratic_nonbank_results2.txt` — produced by
  `quadratic_nonbank_fullsample.do`.

Regression numbers quoted in `Subfiles/Empirical.tex` are sourced from
these two files. Re-running `run_all.do` on a machine with Stata 17+
regenerates them; content should match up to log-preamble metadata
(date, Stata build, user).

## Known limitations

1. **Tables are not auto-emitted as LaTeX.** The numbers in
   `Subfiles/Empirical.tex` are currently transcribed by hand from
   `results/*.txt`. Emitting them via `estout` / `esttab` is a named
   follow-up.
2. **Figures are not auto-emitted from Stata.** The figures in
   `Figures/` were produced manually. Wiring `graph export` into
   `run_all.do` is a named follow-up.
3. **Data build is manual.** `gfdd_with_de_facto1.dta` was assembled
   offline; a scripted rebuild from raw sources is a follow-up. See
   `Data/README.md`.
