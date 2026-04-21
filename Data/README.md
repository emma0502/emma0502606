# `Data/` — data sources for "Who Holds Government Debt?"

This directory will hold the data used by the paper's empirical analysis.
The empirical regressions in `Subfiles/Empirical.tex` use the following
five sources, each to be downloaded or loaded from the canonical vintage
listed below.

## Source inventory

| ID       | Source | Role in paper | Obtain from |
|----------|--------|---------------|-------------|
| EWN      | Lane & Milesi-Ferretti, External Wealth of Nations | Non-bank external debt holdings by country–year | https://www.brookings.edu/articles/the-external-wealth-of-nations-database/ |
| GFDD     | World Bank Global Financial Development Database (indicators `di02`, `di11`, `di13`) | Domestic banking-sector characteristics (size, concentration) | https://www.worldbank.org/en/publication/gfdr/data/global-financial-development-database |
| Chinn–Ito | Chinn, M. D. and Ito, H., Chinn–Ito index of capital-account openness (KAOPEN) | Capital-account openness control | https://web.pdx.edu/~ito/Chinn-Ito_website.htm |
| Quinn cap100 | Quinn, D. P., index of financial openness (cap100) | Alternative capital-account openness | Available on author's data page |
| BOI      | Arslanalp & Tsuda, IMF Sovereign Debt Investor Base database | Total government-debt holdings by creditor type (banks, non-banks, central bank, foreign) | https://www.imf.org/external/pubs/ft/wp/2012/data/wp12284.zip (IMF WP 12/284) |

## Construction

The paper uses a **country–year debt-composition panel** built by merging
the above sources on ISO3 country code and year. The panel columns
used in the regressions are:

- `boi_open`, `cb_size`, `bank_size`, `nonbank_size`, `cap100`, `kaopen`,
  `dcb`, `dpb`, `dhdfselective`, `dhdfcomprehensive`, `dist`.

These are referenced by name from `Subfiles/Empirical.tex` and from
`Subfiles/Model.tex`.

## Status (baseline tier)

This directory currently contains only this README. The data and the
Python pipeline that builds the panel from the raw sources and produces
the regression tables and figures are a **known follow-up**, tracked in
the root `README.md` under "Known follow-ups for baseline-tier REMARK
compliance."

Target layout once the pipeline is committed:

```
Data/
├── README.md                      (this file)
├── raw/                           (committed or downloaded raw sources)
│   ├── ewn_1970_2023.csv
│   ├── gfdd_indicators.csv
│   ├── chinn_ito_kaopen.csv
│   ├── quinn_cap100.csv
│   └── boi_investor_base.csv
└── debt_composition_panel.csv     (built panel used by regressions)
```

The build script will be `Code/empirical_debt_composition/build_panel.py`
and will run as part of `./reproduce.sh --all` without network access
(raw sources committed) or, at the user's option, re-downloadable from
the URLs above.
