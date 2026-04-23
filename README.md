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
| Figure: $D_h$ vs $D_f$ (selective default) | `Figures/Fig_dhdfselective.pdf` | Committed PDF (regeneration is a known follow-up) |
| Figure: $D_h$ vs $D_f$ (comprehensive default) | `Figures/Fig_dhdfcomprehensive.pdf` | Committed PDF (regeneration is a known follow-up) |
| Figure: Empirical distribution | `Figures/dist.png` | Committed PNG (regeneration is a known follow-up) |
| Regression tables (6) | Inlined in `Subfiles/Empirical.tex` | Currently hard-coded LaTeX (regeneration is a known follow-up) |

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

Currently this only compiles the paper (the empirical regression
pipeline is a known follow-up; see below). The script is designed
so that once `Code/empirical_debt_composition/` lands, `--all` will
regenerate figures and tables from raw data and then compile.

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
├── Data/                        # data documentation (data itself is a follow-up)
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

## Known follow-ups for baseline-tier REMARK compliance

These items were surfaced by a Claude Opus 4.7 review of this repo
against the [REMARK STANDARD](https://github.com/econ-ark/REMARK/blob/main/STANDARD.md)
and are tracked here so the gap is visible to any reviewer. See the
pull request associated with this commit for the full review and the
accept / edit / reject triage.

1. **Add the empirical regression pipeline.**
   The regressions that produce the six tables currently inlined in
   `Subfiles/Empirical.tex` and the three figures in `Figures/` are
   not yet runnable from this repo. Target: `Code/empirical_debt_composition/`
   with (a) `build_panel.py` that ingests EWN, GFDD, Chinn–Ito, Quinn
   cap100, and IMF BOI into `Data/debt_composition_panel.csv`,
   (b) `run_regressions.py` that writes the six table `.tex` files,
   and (c) `make_figures.py` that writes the three figure files.
   Once present, have `Subfiles/Empirical.tex` `\input{...}` each
   table instead of carrying the body inline, and have `./reproduce.sh --all`
   call the pipeline before compiling the paper.
2. **Commit the data inputs** (or a download script) for the five
   sources listed in `Data/README.md`, with exact vintages / dates.
3. **Audit the `Dockerfile`** for remaining HAFiscal-specific paths
   (e.g. `/workspaces/HAFiscal-Public`) once the reproduction pipeline
   above is in place.

## License

This replication package is released under the Apache-2.0 License.
See [`LICENSE`](LICENSE).

## Citation

See [`CITATION.cff`](CITATION.cff). If you use this software, please
cite the paper and the repository.
