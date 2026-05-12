"""Python port of ``twoway_cluster_full.do``.

Reproduces Sections 6.4 and 6.5 of "Who Holds Government Debt?".

Stage 1 (Section 6.4)
---------------------
For each of ``nonbank_size``, ``cb_size`` (CB), ``di02`` (private bank)
fit

    s_jit = beta * d_it + gamma * d_high_c_it + year_FE + country_FE + e

where ``d_high_c = max(d - Dbar, 0)`` and Dbar = 102.74851 (Hansen
threshold from Stage (1) of the pipeline).  Country FE absorbed by
within-transformation; year FE included as dummy regressors with the
earliest year in the estimation sample dropped.  Two-way clustered SE
on (country_id, year) match ivreg2's output.

Country-level fixed-effect estimates ``delta_*_th`` are recovered as
weighted-centred entity effects (matching Stata's ``predict u`` after
``xtreg, fe``).

Stage 2 (Section 6.5)
---------------------
For each of ``dh``, ``dcb``, ``dpb`` fit (no constant, two-way clustered):

    d_jit = beta_j * d_it + theta_j * delta_jt_d_it
                          + mu_j * d_high_c_it + nu_j * delta_jt_dhc_it + e

with ``delta_jt`` the country-level structural sector size from Stage 1.

The script writes a text log under
``Code/empirical_debt_composition/results/python/`` and prints a
column-by-column comparison against the committed Stata log
``Code/empirical_debt_composition/results/twoway_cluster_full.txt``.
"""

from __future__ import annotations

import io
import sys
from pathlib import Path

import numpy as np
import pandas as pd

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
    from Code.empirical_debt_composition.python._common import (
        ensure_results_dir,
        load_panel,
        ols_twoway_cluster,
        xtreg_fe_with_country_fe,
    )
else:
    from ._common import (
        ensure_results_dir,
        load_panel,
        ols_twoway_cluster,
        xtreg_fe_with_country_fe,
    )


DBAR = 102.74851  # Hansen threshold from Section 6.3 (db_total).


def _add_year_dummies(
    frame: pd.DataFrame,
    year_col: str = "year",
    drop_first: bool = True,
) -> tuple[pd.DataFrame, list[str]]:
    """Append integer year dummies; drop the earliest year (Stata default)."""
    years = sorted(frame[year_col].unique())
    if drop_first:
        keep = years[1:]
    else:
        keep = years
    cols: list[str] = []
    out = frame.copy()
    for y in keep:
        col = f"y{int(y)}"
        out[col] = (out[year_col] == y).astype(float)
        cols.append(col)
    return out, cols


def _fit_stage1(
    df: pd.DataFrame,
    sector_col: str,
) -> tuple[pd.Series, pd.Series, dict[int, float], int]:
    """Stage-1 fit for a sector size; returns (coef, se, country_FE, N)."""
    sub = df.dropna(subset=[sector_col, "d", "d_high_c", "country_id", "year"]).copy()
    sub_y, year_cols = _add_year_dummies(sub)
    regressors = ["d", "d_high_c"] + year_cols
    res, fe = xtreg_fe_with_country_fe(
        sub_y,
        y_col=sector_col,
        regressors=regressors,
        entity_col="country_id",
        cluster_cols=("country_id", "year"),
    )
    return res.coef, res.se, fe, res.nobs


def _format_stage1(label: str, coef, se, n: int) -> str:
    out = io.StringIO()
    out.write(f"--- {label} (Section 6.4 column) ---\n")
    out.write(f"  N = {n}\n")
    for k in ["d", "d_high_c"]:
        b = coef[k]
        s = se[k]
        out.write(f"  {k:<10} = {b:>14.7f}  (SE {s:.7f}, z = {b/s:>6.2f})\n")
    return out.getvalue()


def _fit_stage2(
    df: pd.DataFrame,
    y_col: str,
    delta_col: str,
    extra_mask: pd.Series | None = None,
) -> tuple[pd.Series, pd.Series, int]:
    """Stage 2: dh = beta*d + theta*(delta*d) + mu*d_high_c + nu*(delta*d_high_c)."""
    work = df.copy()
    work[f"{delta_col}_d"] = work[delta_col] * work["d"]
    work[f"{delta_col}_dhc"] = work[delta_col] * work["d_high_c"]
    needed = [y_col, "d", f"{delta_col}_d", "d_high_c", f"{delta_col}_dhc"]
    work = work.dropna(subset=needed + ["country_id", "year"])
    if extra_mask is not None:
        work = work.loc[extra_mask.reindex(work.index, fill_value=False)]
    res = ols_twoway_cluster(
        work,
        y_col=y_col,
        regressors=["d", f"{delta_col}_d", "d_high_c", f"{delta_col}_dhc"],
        cluster_cols=("country_id", "year"),
        add_constant=False,
    )
    return res.coef, res.se, res.nobs


def _format_stage2(label: str, coef, se, n: int) -> str:
    out = io.StringIO()
    out.write(f"--- {label} ---\n")
    out.write(f"  N = {n}\n")
    for k in coef.index:
        b = coef[k]
        s = se[k]
        out.write(f"  {k:<24} = {b:>14.7f}  (SE {s:.7f}, z = {b/s:>6.2f})\n")
    return out.getvalue()


# ---------------------------------------------------------------------------
# Stata targets from the committed log
# Code/empirical_debt_composition/results/twoway_cluster_full.txt
# ---------------------------------------------------------------------------
STAGE1_TARGETS: dict[str, dict[str, float]] = {
    "nonbank_size": {
        "n": 547,
        "d": -0.1978076,
        "d_se": 0.2170597,
        "d_high_c": -0.2191246,
        "d_high_c_se": 0.1833025,
    },
    "cb_size": {
        "n": 718,
        "d": 0.0227601,
        "d_se": 0.0399629,
        "d_high_c": 0.5417426,
        "d_high_c_se": 0.1582924,
    },
    "di02": {
        "n": 732,
        "d": -0.3085846,
        "d_se": 0.2579003,
        "d_high_c": 0.8820057,
        "d_high_c_se": 0.401901,
    },
}

STAGE2_HEADLINE_TARGETS: dict[str, dict[str, float]] = {
    "dh": {
        "n": 753,
        "d": 0.3153371, "d_se": 0.039407,
        "delta_n_th_d": 0.0018219, "delta_n_th_d_se": 0.0004912,
        "d_high_c": -0.0367219, "d_high_c_se": 0.1648912,
        "delta_n_th_dhc": -0.0033172, "delta_n_th_dhc_se": 0.0031548,
    },
    "dcb": {
        "n": 780,
        "d": 0.0574604, "d_se": 0.0135715,
        "delta_cb_th_d": 0.0126816, "delta_cb_th_d_se": 0.0043309,
        "d_high_c": 0.2813412, "d_high_c_se": 0.1589916,
        "delta_cb_th_dhc": -0.0633393, "delta_cb_th_dhc_se": 0.0215141,
    },
    "dpb": {
        "n": 780,
        "d": 0.1935454, "d_se": 0.019293,
        "delta_pb_th_d": -0.0001746, "delta_pb_th_d_se": 0.0007186,
        "d_high_c": 0.5371138, "d_high_c_se": 0.2431145,
        "delta_pb_th_dhc": -0.01207, "delta_pb_th_dhc_se": 0.0089072,
    },
}


def _diff_table(label: str, py: dict, st: dict) -> str:
    out = io.StringIO()
    out.write(f"  vs Stata target for {label}:\n")

    def _row(name: str, py_v: float, st_v: float) -> None:
        diff = py_v - st_v
        rel = abs(diff) / max(abs(st_v), 1e-9)
        ok = "OK " if rel < 5e-3 else "!! "
        out.write(
            f"    {ok}{name:<24} python={py_v:>14.7f} stata={st_v:>14.7f} "
            f"diff={diff:>+12.7f}  rel={rel:.2e}\n"
        )

    for k in ("d", "d_se", "d_high_c", "d_high_c_se",
              "delta_n_th_d", "delta_n_th_d_se",
              "delta_n_th_dhc", "delta_n_th_dhc_se",
              "delta_cb_th_d", "delta_cb_th_d_se",
              "delta_cb_th_dhc", "delta_cb_th_dhc_se",
              "delta_pb_th_d", "delta_pb_th_d_se",
              "delta_pb_th_dhc", "delta_pb_th_dhc_se",
              "n"):
        if k in py and k in st:
            _row(k, py[k], st[k])
    return out.getvalue()


def main() -> None:
    df = load_panel()
    df["highD"] = (df["d"] > DBAR).astype(float)
    df["d_high_c"] = df["highD"] * (df["d"] - DBAR)

    sections: list[str] = []
    sections.append("Python port of twoway_cluster_full.do")
    sections.append(f"Dbar = {DBAR}\n")

    # ----------- Stage 1 ------------
    sections.append("=" * 78)
    sections.append("STAGE 1 (Section 6.4) -- ivreg2-equivalent two-way clustered SE")
    sections.append("=" * 78)

    stage1: dict[str, dict[str, float]] = {}
    fe_by_sector: dict[str, dict[int, float]] = {}
    n_by_sector: dict[str, int] = {}
    for sector in ("nonbank_size", "cb_size", "di02"):
        coef, se, fe_dict, n = _fit_stage1(df, sector)
        sections.append(_format_stage1(sector, coef, se, n))
        stage1[sector] = {
            "n": n,
            "d": float(coef["d"]),
            "d_se": float(se["d"]),
            "d_high_c": float(coef["d_high_c"]),
            "d_high_c_se": float(se["d_high_c"]),
        }
        fe_by_sector[sector] = fe_dict
        n_by_sector[sector] = n
        sections.append(_diff_table(sector, stage1[sector], STAGE1_TARGETS[sector]))

    # Attach delta_*_th to the panel as country-level constants.
    df["delta_n_th"] = df["country_id"].map(fe_by_sector["nonbank_size"])
    df["delta_cb_th"] = df["country_id"].map(fe_by_sector["cb_size"])
    df["delta_pb_th"] = df["country_id"].map(fe_by_sector["di02"])

    # Per-country observation counts in the Stage-1 estimating samples.
    s1_samples = {}
    for sector, raw in (
        ("nonbank_size", "stage1_n_obs"),
        ("cb_size", "stage1_cb_obs"),
        ("di02", "stage1_pb_obs"),
    ):
        sub = df.dropna(subset=[sector, "d", "d_high_c", "country_id", "year"])
        s1_samples[raw] = sub.groupby("country_id").size()
    for k, s in s1_samples.items():
        df[k] = df["country_id"].map(s).fillna(0).astype(int)

    # ----------- Stage 2 headline ------------
    sections.append("=" * 78)
    sections.append("STAGE 2 HEADLINE (Section 6.5) -- ivreg2 nocons cluster(country, year)")
    sections.append("=" * 78)

    stage2_results: dict[str, tuple[pd.Series, pd.Series, int]] = {}
    for y_col, delta_col in (("dh", "delta_n_th"), ("dcb", "delta_cb_th"), ("dpb", "delta_pb_th")):
        coef, se, n = _fit_stage2(df, y_col, delta_col)
        stage2_results[y_col] = (coef, se, n)
        sections.append(_format_stage2(f"{y_col} headline", coef, se, n))
        py = {"n": n}
        for col in coef.index:
            py[col] = float(coef[col])
            py[f"{col}_se"] = float(se[col])
        sections.append(_diff_table(y_col, py, STAGE2_HEADLINE_TARGETS[y_col]))

    # ----------- Stage 2 matched (drop obs missing delta_hat) ------------
    sections.append("=" * 78)
    sections.append("STAGE 2 MATCHED -- restrict to Stage-1 estimating sample")
    sections.append("=" * 78)
    matched_masks = {
        "dh": df["country_id"].isin(set(fe_by_sector["nonbank_size"].keys()))
              & df.dropna(subset=["nonbank_size", "d", "d_high_c"]).index.to_series().reindex(df.index, fill_value=pd.NA).notna(),
        "dcb": df["country_id"].isin(set(fe_by_sector["cb_size"].keys()))
              & df.dropna(subset=["cb_size", "d", "d_high_c"]).index.to_series().reindex(df.index, fill_value=pd.NA).notna(),
        "dpb": df["country_id"].isin(set(fe_by_sector["di02"].keys()))
              & df.dropna(subset=["di02", "d", "d_high_c"]).index.to_series().reindex(df.index, fill_value=pd.NA).notna(),
    }
    for y_col, delta_col, mask_key in (
        ("dh", "delta_n_th", "dh"),
        ("dcb", "delta_cb_th", "dcb"),
        ("dpb", "delta_pb_th", "dpb"),
    ):
        coef, se, n = _fit_stage2(df, y_col, delta_col, extra_mask=matched_masks[mask_key])
        sections.append(_format_stage2(f"{y_col} matched", coef, se, n))

    # ----------- Stage 2 sparse-country drop ------------
    for k in (5, 10):
        sections.append("=" * 78)
        sections.append(f"STAGE 2 SPARSE-COUNTRY DROP k>={k}")
        sections.append("=" * 78)
        for y_col, delta_col, count_col in (
            ("dh", "delta_n_th", "stage1_n_obs"),
            ("dcb", "delta_cb_th", "stage1_cb_obs"),
            ("dpb", "delta_pb_th", "stage1_pb_obs"),
        ):
            mask = df[count_col] >= k
            coef, se, n = _fit_stage2(df, y_col, delta_col, extra_mask=mask)
            sections.append(_format_stage2(f"{y_col} k>={k}", coef, se, n))

    out_dir = ensure_results_dir()
    out_path = out_dir / "twoway_cluster_full.py.txt"
    out_path.write_text("\n".join(sections))
    print(f"wrote {out_path}")

    # Concise console diff vs Stata for the headline numbers.
    print("\nHEADLINE diffs vs Stata log:")
    for y_col in ("dh", "dcb", "dpb"):
        coef, se, n = stage2_results[y_col]
        tgt = STAGE2_HEADLINE_TARGETS[y_col]
        print(f"  {y_col} (N python={n} stata={tgt['n']}):")
        for col in coef.index:
            py_b = float(coef[col])
            py_s = float(se[col])
            st_b = tgt[col]
            st_s = tgt[f"{col}_se"]
            db = py_b - st_b
            ds = py_s - st_s
            ok_b = "OK " if abs(db) / max(abs(st_b), 1e-6) < 5e-3 else "!! "
            ok_s = "OK " if abs(ds) / max(abs(st_s), 1e-6) < 5e-2 else "!! "
            print(
                f"    {col:<22} {ok_b}coef diff {db:+.6f}    {ok_s}SE diff {ds:+.6f}"
            )


if __name__ == "__main__":
    main()
