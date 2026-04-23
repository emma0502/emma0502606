# Who Holds Government Debt? — Replication package

[![Powered by Econ-ARK](./@resources/econ-ark/PoweredByEconARK.svg)](https://econ-ark.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.10%2B-blue.svg)](pyproject.toml)

**Paper:** *Who Holds Government Debt?*
**Author:** Yiran Emma Ma (Johns Hopkins University)
**Type:** REMARK-in-progress, targeting the **baseline (standard) tier** of
[econ-ark/REMARK](https://github.com/econ-ark/REMARK).

---

## What the paper asks

The paper develops a model in which the composition of public debt across
**domestic banks, domestic non-banks, and foreign investors** is determined by
endogenous borrowing limits. The government faces default constraints on
non-bank creditors and convex costs of financial repression on bank-held
debt. These constraints generate threshold effects: when total debt
exceeds a critical level, the government exhausts non-bank borrowing
capacity and allocates marginal debt to banks.

The paper structurally estimates the model using panel data on debt
composition across countries and over time. The estimation identifies
distinct borrowing limits across creditor types and provides a tractable
framework for interpreting variation in who holds government debt.

## What this REMARK reproduces

| Paper artifact | File in repo | How it is produced today |
|---|---|---|
| Main paper PDF | `emma0502606.pdf` | `./reproduce.sh --docs` (compiles `emma0502606.tex` via LaTeX) |
| Regression logs (threshold, centered) | `Code/empirical_debt_composition/results/threshold_centered_results.txt` | `./reproduce.sh --empirical` (re-runs `threshold_estimation_centered.do` in Stata); committed copy is used when Stata is absent |
| Regression logs (convexity + pecking order) | `Code/empirical_debt_composition/results/quadratic_nonbank_results2.txt` | `./reproduce.sh --empirical` (re-runs `quadratic_nonbank_fullsample.do` in Stata); committed copy is used when Stata is absent |
| Panel dataset | `Data/gfdd_with_de_facto1.dta` | Committed (SHA-256 in `Data/README.md`); scripted rebuild from raw sources is a follow-up |
| Figures | `Figures/*.pdf`, `Figures/*.png` | Committed; regeneration from Stata `graph export` is a follow-up |
| Regression tables (6) | Inlined in `Subfiles/Empirical.tex` | Numbers transcribed from the two results logs above; auto-emit via `esttab` is a follow-up |

## Quick start

### Compile the paper PDF

```bash
./reproduce.sh --docs
```

Output: `emma0502606.pdf`. Requires TeX Live 2023+ with the packages
listed in `reproduce/required_latex_packages.txt`.

### Full reproduction

```bash
./reproduce.sh --all        # equivalent to ./reproduce.sh
```

This runs the Stata empirical pipeline under
`Code/empirical_debt_composition/` and then compiles the paper. If Stata
is not installed, the empirical step is **skipped with a clear message**
and the committed `results/*.txt` logs are used as the authoritative
record of the regressions. The paper compile succeeds either way because
the regression numbers are currently transcribed into
`Subfiles/Empirical.tex` (auto-emit via `esttab` is a named follow-up).

### Empirical pipeline only

```bash
./reproduce.sh --empirical
```

Invokes `stata -b do Code/empirical_debt_composition/run_all.do`. See
[`Code/empirical_debt_composition/README.md`](Code/empirical_debt_composition/README.md)
for per-stage details.

### Software requirements

| Component | Version | Used for | Required for `--all`? |
|---|---|---|---|
| LaTeX | TeX Live 2023+ | Paper compile | Yes |
| Stata | 17+ (MP / SE / IC) | `--empirical` stage | No — falls back to committed logs |
| Python | 3.10+ | `uv sync` / helper scripts in `reproduce/` | Yes |

### Environment setup

```bash
uv sync                           # recommended (uses pyproject.toml)
# or
conda env create -f environment.yml && conda activate who-holds-government-debt
```

Python 3.10+ is required.

## Repository layout

```
emma0502606/
├── emma0502606.tex              # main paper source
├── emma0502606.pdf              # compiled paper (committed)
├── Subfiles/                    # paper subfiles (Intro, Model, Empirical, Conclusion)
├── Figures/                     # figures used by the paper
├── Data/                        # panel dataset (gfdd_with_de_facto1.dta) + provenance
├── Code/empirical_debt_composition/  # Stata empirical pipeline (run_all.do + do/ + results/)
├── Equations/                   # shared equation snippets
├── Subfiles.ltx                 # subfile driver
├── references.bib               # bibliography
├── @local/, @resources/         # econark LaTeX template scaffolding
├── pyproject.toml               # Python dependency manifest
├── environment.yml              # conda environment (mirrors pyproject.toml)
├── binder/                      # Binder-compatible environment
├── reproduce.sh                 # reproduction driver
├── reproduce/                   # LaTeX build helpers (reproduce_documents.sh etc.)
├── Dockerfile, .devcontainer/   # optional containerised environment
└── legacy-hafiscal/             # inherited scaffolding, not used (see its README)
```

## How this REMARK relates to HAFiscal

This repository was originally scaffolded from the
[HAFiscal REMARK](https://github.com/econ-ark/HAFiscal) template. All of
the HAFiscal-specific content — the structural HANK pipeline, the
Voila dashboard, the HANK-and-SAM tutorial, every HAFiscal table and
figure, HAFiscal's detailed READMEs — now lives under
[`legacy-hafiscal/`](legacy-hafiscal/README.md) and is **not used by
this paper**. `./reproduce.sh` does not enter that directory.

## Known limitations and follow-ups

These items were surfaced by a Claude Opus 4.7 review of this repo
against the [REMARK STANDARD](https://github.com/econ-ark/REMARK/blob/main/STANDARD.md).
They are tracked here so any gap remaining after this commit is visible
to a reviewer.

### Limitations (intentional, documented)

1. **Binder / conda cannot execute the empirical stage today.** The
   regressions currently live in Stata
   (`Code/empirical_debt_composition/do/`). Stata is proprietary and
   not conda-installable, so the environment declared in
   `binder/environment.yml` does **not** reproduce Section 3
   end-to-end in-browser. As mitigation, the two authoritative
   regression logs (`threshold_centered_results.txt`,
   `quadratic_nonbank_results2.txt`) are committed under
   `Code/empirical_debt_composition/results/`, and `./reproduce.sh --all`
   runs cleanly in Binder by falling back to those committed logs.

   **Work in progress:** the author is currently porting the five Stata
   `.do` files to Python (using [`pandas`](https://pandas.pydata.org/)
   and [`linearmodels`](https://bashtage.github.io/linearmodels/) —
   specifically `PanelOLS` for the fixed-effects first stage and
   clustered-SE OLS for the second stage). Once the port lands, the
   `Code/empirical_debt_composition/do/` Stata sources will remain in
   the repo as a canonical reference and the Python pipeline will become
   the default entry point for `./reproduce.sh --empirical`, making the
   whole paper reproducible inside `binder/environment.yml` without a
   Stata license.

### Follow-ups

1. **Auto-emit regression tables** from the (forthcoming) Python
   pipeline so that `Subfiles/Empirical.tex` `\input{...}`s them
   instead of carrying transcribed numbers inline.
2. **Auto-emit figures** from the pipeline instead of relying on the
   currently committed PDFs/PNGs under `Figures/`.
3. **Scripted data build.** Replace the offline Excel/Stata merge that
   produced `Data/gfdd_with_de_facto1.dta` with a `build_panel.py`
   that starts from the raw GFDD, EWN, Chinn–Ito, Quinn, and IMF BOI
   sources. See `Data/README.md` for the source inventory and current
   provenance.
4. **Audit the `Dockerfile`** for remaining HAFiscal-specific paths
   (e.g. `/workspaces/HAFiscal-Public`).

## License

This replication package is released under the Apache-2.0 License.
See [`LICENSE`](LICENSE).

## Citation

See [`CITATION.cff`](CITATION.cff). If you use this software, please
cite the paper and the repository.
