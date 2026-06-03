# Binder Configuration

This directory contains configuration files for [MyBinder.org](https://mybinder.org), which allows users to launch interactive Jupyter notebooks in the cloud.

## Files

- **`environment.yml`** — conda environment for the "Who Holds Government Debt?" REMARK. Kept in sync by hand with the repo-root `../environment.yml` (which is the file editors and developers use locally).
- **`apt.txt`** — system packages installed by Binder (`latexmk` + minimal TeX Live).
- **`postBuild`** — post-installation script (warms the matplotlib font cache).
- **`requirements.txt`** — additional pip requirements layered on top of `environment.yml`.

## Testing locally

To recreate the same environment Binder uses, from the repo root:

```bash
conda env create -f environment.yml
conda activate who-holds-government-debt
```

Or, with `uv` (recommended for development):

```bash
uv sync
```

## Launching on MyBinder

Click the Binder badge in the main `README.md` to launch the repository
on [mybinder.org](https://mybinder.org). Once the kernel is up,
`./reproduce.sh --docs` compiles the paper and `./reproduce.sh --all`
runs the full pipeline (the Stata empirical step is skipped — see the
top-level `README.md`'s "Known limitations" section for the rationale
and the documented fall-back to committed Stata result logs).
