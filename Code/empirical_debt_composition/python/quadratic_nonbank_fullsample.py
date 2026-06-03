"""Python port of ``quadratic_nonbank_fullsample.do``.

Reproduces Section 6.6 (concavity of non-bank absorption) and the
auxiliary debt-allocation tables that feed the appendix.

The .do file uses one-way clustering ``vce(cluster country_id)`` for
all OLS specs and ``xtreg ..., fe vce(cluster country_id)`` for the
panel-FE specs.  Country FE are absorbed via within transformation
where applicable.  The Hansen threshold for the centred ``d_high_c``
variable is fixed at 100 (round number) in this file, matching
``gen highD = d >= 100``.

Sample design
-------------
- First stage non-bank: ``below100 = (d < 100)``; xtreg of
  ``nonbank_size`` on ``d, i.year`` with country FE; recover
  ``delta_n_q`` (country-level FE).
- First stage CB / PB: full sample, kink at d=100 via centred
  ``d_high_c``; recover ``delta_cb_q``, ``delta_pb_q`` per country.
- Second stage non-bank (Specs Q, Qs, Q0, L, T, B_fe, C_fe, D_fe).
- Foreign-debt regressions (df).
- Sector-by-sector linear / quadratic / threshold absorption.

The committed Stata log we validate against is
``Code/empirical_debt_composition/results/quadratic_nonbank_results2.txt``
when present; until then we only produce the Python output.
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


def _add_year_dummies(df: pd.DataFrame, mask: pd.Series) -> tuple[pd.DataFrame, list[str]]:
    sub = df.loc[mask].copy()
    years = sorted(sub["year"].unique())
    keep = years[1:]
    cols: list[str] = []
    for y in keep:
        col = f"y{int(y)}"
        sub[col] = (sub["year"] == y).astype(float)
        cols.append(col)
    return sub, cols


def _format_reg(label: str, coef: pd.Series, se: pd.Series, n: int, r2: float) -> str:
    out = io.StringIO()
    out.write(f"--- {label} (N={n}, R2={r2:.4f}) ---\n")
    for k in coef.index:
        b = coef[k]
        s = se[k]
        z = b / s if s and not np.isnan(s) else float("nan")
        out.write(f"  {k:<24} = {b:>14.7f}  (SE {s:.7f}, z = {z:>6.2f})\n")
    return out.getvalue()


def _cluster_country_only(df: pd.DataFrame, y: str, regressors: list[str], mask: pd.Series | None = None) -> tuple[pd.Series, pd.Series, int, float]:
    res = ols_twoway_cluster(
        df,
        y_col=y,
        regressors=regressors,
        cluster_cols=("country_id",),
        add_constant=False,
        sample_mask=mask,
    )
    return res.coef, res.se, res.nobs, res.centered_r2


def main() -> None:
    df = load_panel()
    # Highly fragmented frame — defragment up front.
    df = df.copy()

    # Threshold variables (Stata uses Dbar = 100 here, matching the
    # "round number" referenced in the paper text for §6.6).
    df["highD"] = (df["d"] >= 100).astype(float)
    df["d_high_c"] = df["highD"] * (df["d"] - 100)
    df["d_sq"] = df["d"] * df["d"]

    sections: list[str] = []
    sections.append("Python port of quadratic_nonbank_fullsample.do (Section 6.6)")
    sections.append("Dbar = 100\n")

    # ------------------------------------------------------------------
    # First stage extractions
    # ------------------------------------------------------------------
    # delta_n_q: xtreg nonbank_size d i.year if d<100, fe vce(cluster country_id)
    nb_mask = (df["d"] < 100) & df["nonbank_size"].notna() & df["d"].notna()
    sub_nb, year_cols_nb = _add_year_dummies(df, nb_mask)
    res_nb, fe_n = xtreg_fe_with_country_fe(
        sub_nb,
        y_col="nonbank_size",
        regressors=["d"] + year_cols_nb,
        entity_col="country_id",
        cluster_cols=("country_id",),
    )
    df["delta_n_q"] = df["country_id"].map(fe_n)
    sections.append("--- First stage non-bank (d<100, country FE) ---")
    sections.append(f"  N={res_nb.nobs}, d coef = {res_nb.coef['d']:.7f} (SE {res_nb.se['d']:.7f})")

    # delta_cb_q: xtreg cb_size c.d c.d_high_c i.year, fe vce(cluster country_id)
    cb_mask = df["cb_size"].notna() & df["d"].notna()
    sub_cb, year_cols_cb = _add_year_dummies(df, cb_mask)
    res_cb, fe_cb = xtreg_fe_with_country_fe(
        sub_cb,
        y_col="cb_size",
        regressors=["d", "d_high_c"] + year_cols_cb,
        entity_col="country_id",
        cluster_cols=("country_id",),
    )
    df["delta_cb_q"] = df["country_id"].map(fe_cb)
    sections.append("--- First stage CB (full sample, country FE, kink at 100) ---")
    sections.append(f"  N={res_cb.nobs}, d coef = {res_cb.coef['d']:.7f}, d_high_c coef = {res_cb.coef['d_high_c']:.7f}")

    # delta_pb_q: xtreg di02 c.d c.d_high_c i.year, fe vce(cluster country_id)
    pb_mask = df["di02"].notna() & df["d"].notna()
    sub_pb, year_cols_pb = _add_year_dummies(df, pb_mask)
    res_pb, fe_pb = xtreg_fe_with_country_fe(
        sub_pb,
        y_col="di02",
        regressors=["d", "d_high_c"] + year_cols_pb,
        entity_col="country_id",
        cluster_cols=("country_id",),
    )
    df["delta_pb_q"] = df["country_id"].map(fe_pb)
    sections.append("--- First stage PB (full sample, country FE, kink at 100) ---")
    sections.append(f"  N={res_pb.nobs}, d coef = {res_pb.coef['d']:.7f}, d_high_c coef = {res_pb.coef['d_high_c']:.7f}\n")

    # Interactions used by Stage 2.
    df["delta_n_d"] = df["delta_n_q"] * df["d"]
    df["delta_n_d_sq"] = df["delta_n_q"] * df["d_sq"]
    df["delta_n_dhc"] = df["delta_n_q"] * df["d_high_c"]
    df["delta_cb_d"] = df["delta_cb_q"] * df["d"]
    df["delta_cb_dhc"] = df["delta_cb_q"] * df["d_high_c"]
    df["delta_pb_d"] = df["delta_pb_q"] * df["d"]
    df["delta_pb_dhc"] = df["delta_pb_q"] * df["d_high_c"]

    # ------------------------------------------------------------------
    # Non-bank Stage 2 specs (pooled, no constant, cluster country)
    # ------------------------------------------------------------------
    sections.append("=" * 78)
    sections.append("NON-BANK Stage 2 (full sample, nocons, cluster country)")
    sections.append("=" * 78)
    spec_defs = [
        ("Q",  ["d", "delta_n_d", "d_sq", "delta_n_d_sq"]),
        ("Qs", ["d", "delta_n_d", "d_sq"]),
        ("Q0", ["d", "d_sq"]),
        ("L",  ["d", "delta_n_d"]),
        ("T",  ["d", "delta_n_d", "d_high_c", "delta_n_dhc"]),
    ]
    for name, regs in spec_defs:
        coef, se, n, r2 = _cluster_country_only(df, "dh", regs)
        sections.append(_format_reg(f"Spec {name} (dh)", coef, se, n, r2))

    # ------------------------------------------------------------------
    # Non-bank Stage 2 with country + year FE (Specs B, C, D)
    # ------------------------------------------------------------------
    sections.append("=" * 78)
    sections.append("NON-BANK Stage 2 with country + year FE (Specs B, C, D)")
    sections.append("=" * 78)
    fe_specs = [
        ("B_fe", ["d", "delta_n_d", "d_sq"]),
        ("C_fe", ["d", "d_sq"]),
        ("D_fe", ["d", "delta_n_d"]),
    ]
    for name, base_regs in fe_specs:
        sub_mask = df["dh"].notna() & df[base_regs].notna().all(axis=1)
        sub, year_cols = _add_year_dummies(df, sub_mask)
        regs = base_regs + year_cols
        res, _ = xtreg_fe_with_country_fe(
            sub, y_col="dh", regressors=regs, cluster_cols=("country_id",)
        )
        # Trim to the variables of interest for the printout.
        keep = base_regs
        coef = res.coef.loc[keep]
        se = res.se.loc[keep]
        sections.append(_format_reg(f"Spec {name} (dh + FE)", coef, se, res.nobs, res.centered_r2))

    # ------------------------------------------------------------------
    # Foreign debt regressions
    # ------------------------------------------------------------------
    sections.append("=" * 78)
    sections.append("FOREIGN DEBT (df) regressions")
    sections.append("=" * 78)
    df_specs = [
        ("df Q0",  ["d", "d_sq"]),
        ("df Qs",  ["d", "delta_n_d", "d_sq"]),
        ("df L",   ["d", "delta_n_d"]),
    ]
    for name, regs in df_specs:
        coef, se, n, r2 = _cluster_country_only(df, "df", regs)
        sections.append(_format_reg(name + " (pooled)", coef, se, n, r2))

    # FE versions.
    for name, base_regs in df_specs:
        sub_mask = df["df"].notna() & df[base_regs].notna().all(axis=1)
        sub, year_cols = _add_year_dummies(df, sub_mask)
        regs = base_regs + year_cols
        res, _ = xtreg_fe_with_country_fe(
            sub, y_col="df", regressors=regs, cluster_cols=("country_id",)
        )
        coef = res.coef.loc[base_regs]
        se = res.se.loc[base_regs]
        sections.append(_format_reg(name + " (FE)", coef, se, res.nobs, res.centered_r2))

    # ------------------------------------------------------------------
    # Debt allocation across all sectors (Section appendix)
    # ------------------------------------------------------------------
    sections.append("=" * 78)
    sections.append("DEBT ALLOCATION across sectors (linear / quadratic / threshold)")
    sections.append("=" * 78)
    df["db"] = df["dcb"] + df["dpb"]
    sectors = ["dh", "df", "dcb", "dpb", "db"]

    # Linear
    sections.append("\n  (1) LINEAR: y = beta * d")
    for s in sectors:
        coef, se, n, r2 = _cluster_country_only(df, s, ["d"])
        sections.append(_format_reg(f"linear {s}", coef, se, n, r2))

    # Quadratic
    sections.append("\n  (2) QUADRATIC: y = beta*d + kappa*d_sq")
    for s in sectors:
        coef, se, n, r2 = _cluster_country_only(df, s, ["d", "d_sq"])
        sections.append(_format_reg(f"quadratic {s}", coef, se, n, r2))

    # Threshold
    sections.append("\n  (3) THRESHOLD: y = beta*d + mu*d_high_c (kink at d=100)")
    for s in sectors:
        coef, se, n, r2 = _cluster_country_only(df, s, ["d", "d_high_c"])
        sections.append(_format_reg(f"threshold {s}", coef, se, n, r2))

    # ------------------------------------------------------------------
    # Size-scaled spec
    # ------------------------------------------------------------------
    sections.append("=" * 78)
    sections.append("SIZE-SCALED SPECS (dh / nonbank_size, conditional on size > 5)")
    sections.append("=" * 78)
    df_scale = df.copy()
    df_scale["dh_over_sh"] = np.where(
        (df_scale["dh"].notna()) & (df_scale["nonbank_size"] > 5),
        df_scale["dh"] / df_scale["nonbank_size"],
        np.nan,
    )
    for name, regs in [("R1", ["d", "d_sq"]), ("R2", ["d", "delta_n_d", "d_sq"])]:
        coef, se, n, r2 = _cluster_country_only(df_scale, "dh_over_sh", regs)
        sections.append(_format_reg(f"Spec {name}", coef, se, n, r2))

    # ------------------------------------------------------------------
    # Write log
    # ------------------------------------------------------------------
    out_dir = ensure_results_dir()
    out_path = out_dir / "quadratic_nonbank_fullsample.py.txt"
    out_path.write_text("\n".join(sections))
    print(f"wrote {out_path}")

    # Headline §6.6 numbers we want to compare verbally.
    print("\nHeadline §6.6 numbers (pooled non-bank, no FE):")
    coef_C, se_C, n_C, r2_C = _cluster_country_only(df, "dh", ["d", "d_sq"])
    print(f"  Spec Q0 (dh ~ d + d_sq): N={n_C}")
    for k in coef_C.index:
        print(f"    {k:<14} = {coef_C[k]:>+12.7f}  (SE {se_C[k]:.7f})")

    coef_B, se_B, n_B, r2_B = _cluster_country_only(df, "dh", ["d", "delta_n_d", "d_sq"])
    print(f"  Spec Qs (dh ~ d + delta*d + d_sq): N={n_B}")
    for k in coef_B.index:
        print(f"    {k:<14} = {coef_B[k]:>+12.7f}  (SE {se_B[k]:.7f})")


if __name__ == "__main__":
    main()
