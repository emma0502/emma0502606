# `Data/` — data for "Who Holds Government Debt?"

This directory holds the country–year panel consumed by the empirical
pipeline in `Code/empirical_debt_composition/`. Everything the paper's
regressions need is in one committed Stata file.

## Committed panel

- **File:** `gfdd_with_de_facto1.dta`
- **Size:** ~870 KB (fits comfortably inside the repo)
- **SHA-256:** `ed70704258b8ff2cde39a428497aa78358606943ce84319bcb8b387116fd1d01`
- **Format:** Stata 17 (`.dta`); loaded in `Code/empirical_debt_composition/run_all.do`
  with `use "Data/gfdd_with_de_facto1.dta", clear`.

Key variables used by the regressions:

| Variable | Role |
|---|---|
| `country_id`, `year` | Panel identifiers (`xtset country_id year`) |
| `d` | Total government debt / GDP (%) — the RHS driver |
| `nonbank_size`, `cb_size`, `di02` | Structural sizes of non-bank, central-bank, and private-bank sectors (first-stage LHS) |
| `dh`, `dcb`, `dpb`, `df` | Shares of government debt held by domestic non-banks, central bank, private banks, and foreign investors (second-stage LHS) |
| `de_facto`, `cap100` | Financial-openness measures used in integration interactions |

The panel is balanced enough that clustered-SE panel FE regressions
(`xtreg ... , fe vce(cluster country_id)`) identify.

## Provenance

`gfdd_with_de_facto1.dta` was assembled **offline**, outside this repo,
by merging five public sources on ISO3 country code and year:

| ID | Source | Contributes | Vintage used |
|----|--------|-------------|--------------|
| GFDD | World Bank Global Financial Development Database (indicators `di02`, `di11`, `di13`) | `nonbank_size`, `cb_size`, `di02` (bank size / concentration) | GFDD 2022 release |
| EWN | Lane & Milesi-Ferretti, External Wealth of Nations | Non-bank external debt holdings | 2024 update (`EWN-dataset-year-end-2024`) |
| Chinn–Ito | Chinn, M. D. and Ito, H., KAOPEN index | Capital-account openness (`kaopen`) | 2023 release |
| Quinn cap100 | Quinn, D. P., capital-account openness index | `cap100`, `de_facto` | 2021 update |
| BOI | Arslanalp & Tsuda, IMF Sovereign Debt Investor Base | Creditor-composition shares `dh`, `dcb`, `dpb`, `df` | IMF WP 12/284 + 2024 refresh |

The merge was done in Excel / Stata interactively and is **not yet
scripted**. See "Known follow-ups" below.

## Status vs. REMARK baseline tier

Committing `gfdd_with_de_facto1.dta` + a documented SHA-256 satisfies the
baseline-tier expectation that raw data used by the paper be available
to a reviewer. It does not yet satisfy the stronger expectation of a
scripted, re-runnable build from public sources.

## Known follow-ups

1. **Scripted data build.** Replace the offline Excel/Stata merge with a
   `build_panel.do` (or `build_panel.py`) that starts from the raw GFDD,
   EWN, Chinn-Ito, Quinn, and BOI downloads and emits
   `gfdd_with_de_facto1.dta`. Tracked against `Code/empirical_debt_composition/`.
2. **Vintage-pinning.** Record exact download URLs and retrieval dates
   for each of the five sources and commit the raw source files (or
   their checksums) under `Data/raw/`.
3. **Provenance note per variable.** Extend the table above so each
   constructed variable in the panel is traceable to the exact source
   column and transformation step.

## Historical / unused sources

Earlier drafts of the paper also consulted the following. They are
documented here so that a reviewer rebuilding the panel from scratch
knows they are not currently wired in:

- `GFDD_filtered.xlsx` — an intermediate Excel workbook; superseded by
  the Stata merge that produced `gfdd_with_de_facto1.dta`.
- `Debt_GFDD_with_Quinn_KAOPEN_FRS.xlsx` — exploratory merge with
  additional Quinn / KAOPEN / financial-repression variables.
- `2021-FKRSU-Update-12-08-2021(DATASET).csv` — Fernández, Klein,
  Rebucci, Schindler, Uribe capital-controls dataset; considered for an
  alternative openness control.

None of these are loaded by `run_all.do`. Dropping them in the scripted
build (follow-up 1) would be fine.
