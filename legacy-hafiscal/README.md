# `legacy-hafiscal/` — inherited HAFiscal scaffolding

This directory holds files inherited from the
[HAFiscal REMARK](https://github.com/econ-ark/HAFiscal) template from which
this repository was originally scaffolded. **None of the files in this
directory are used by the current paper's reproduction.**

The paper in this repository is **"Who Holds Government Debt?"** by Yiran
Emma Ma (Johns Hopkins University), an empirical paper on sovereign-debt
composition. HAFiscal is a structural HANK paper on fiscal stimulus
(Carroll, Crawley, Du, Frankovic, Tretvoll, 2025). They share no code
or results.

The scaffolding is kept (rather than deleted outright) so that the
provenance of the build system, LaTeX `econark` template configuration,
and various `@local`/`@resources` conventions remains inspectable.

## What is here

| Path | Original role |
|------|---------------|
| `Code/HA-Models/` | Full HAFiscal structural estimation pipeline (`do_all.py` and all downstream modules). |
| `Code/Empirical/` | HAFiscal empirical calibration code using SCF 2004. |
| `Code/README.md` | HAFiscal's description of the original `Code/` tree (runtime estimates, pipeline steps). |
| `dashboard/` | Voila dashboard for the HAFiscal HANK model. |
| `HANK-and-SAM-tutorial.ipynb` | HANK + search-and-matching tutorial notebook. |
| `HANK_and_SAM_tutorial_utils.py` | Support utilities for the HANK-and-SAM tutorial. |
| `Tables/` | All table `.tex`/`.pdf` files from the HAFiscal paper. The current paper's tables are inlined in `Subfiles/Empirical.tex`. |
| `Figures/` | HAFiscal figures (splurge estimation, HANK IRFs, multiplier decompositions, untargeted moments, Lorenz-points robustness, etc.). Current paper's figures (`Fig_dhdfselective`, `Fig_dhdfcomprehensive`, `dist.png`) remain in `../Figures/`. |
| `README/` | HAFiscal's detailed README (GETTING-STARTED, REPLICATION, DOCKER, TROUBLESHOOTING, etc.). |
| `README_IF_YOU_ARE_AN_AI/` | HAFiscal's AI-quickstart / workflow docs. |
| `NOTEBOOK-CONSOLIDATION.md` | HAFiscal notebook-consolidation notes. |
| `ARCHITECTURE.md` | HAFiscal architecture doc. |
| `reproduce/reproduce_data_moments/` | HAFiscal SCF-2004 data-moment reproduction scripts and notes. |
| `reproduce/benchmarks/` | HAFiscal computational benchmarks. |
| `history/` | HAFiscal development history logs. |

## Why not delete?

If this REMARK is eventually submitted to the econ-ark catalog, a
reviewer may want to see exactly what was and was not used from the
HAFiscal template. Moving rather than deleting makes the provenance
auditable at zero clutter cost to the main paper.

This directory can be deleted wholesale at any time without affecting
the current paper's build or reproduction. `./reproduce.sh` never
enters this directory.
