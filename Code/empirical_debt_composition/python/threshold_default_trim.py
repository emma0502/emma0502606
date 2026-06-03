"""Python port of ``threshold_estimation_default_trim.do``.

Replicates the Hansen 1- and 2-threshold regressions reported in
Section 6.3 of the paper.  For each outcome (db_total = dcb+dpb,
dcb, dpb, dh) we fit:

    y_it = alpha_r * I_r(d_it; tau) + beta_r * d_it * I_r(d_it; tau)
                                    + gamma_i + e_it

via grid search over tau in the interior 80% (10% trim each side) of
the empirical d distribution.  Country FE gamma_i are absorbed by
within-transformation; one country (the lowest country_id, matching
Stata's behaviour of dropping ``Australia`` as the base level) is
omitted from the country dummy block.

The four banking/non-bank tables in the .txt log are reproduced and
compared to the Stata results in
``Code/empirical_debt_composition/results/threshold_estimation_default_trim.txt``.

Run from the repo root:

    python -m Code.empirical_debt_composition.python.threshold_default_trim
"""

from __future__ import annotations

import io
import sys
from pathlib import Path
from typing import Sequence

import numpy as np
import pandas as pd

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
    from Code.empirical_debt_composition.python._common import (
        ensure_results_dir,
        load_panel,
    )
else:
    from ._common import ensure_results_dir, load_panel


def _country_dummies(country_id: np.ndarray, base: int) -> tuple[np.ndarray, list[int]]:
    countries = np.sort(np.unique(country_id))
    others = [int(c) for c in countries if int(c) != int(base)]
    D = np.column_stack(
        [(country_id == c).astype(float) for c in others]
    )
    return D, others


def _fit_one_threshold(
    y: np.ndarray,
    d: np.ndarray,
    country_id: np.ndarray,
    tau: float,
    base_country: int,
) -> dict:
    """OLS fit of the kink model at a fixed threshold ``tau``.

    Parameterisation:
        y = alpha1 * I1 + beta1 * d*I1 + alpha2 * I2 + beta2 * d*I2
              + sum_{c != base} gamma_c * 1{country=c} + eps
    """
    n = len(y)
    I1 = (d <= tau).astype(float)
    I2 = (d > tau).astype(float)
    D, others = _country_dummies(country_id, base_country)
    X = np.column_stack([I1, d * I1, I2, d * I2, D])
    names = ["alpha1", "beta1", "alpha2", "beta2"] + [
        f"country_{c}" for c in others
    ]
    XtX = X.T @ X
    XtX_inv = np.linalg.inv(XtX)
    beta = XtX_inv @ X.T @ y
    u = y - X @ beta
    ssr = float(u @ u)
    k = X.shape[1]
    sigma2 = ssr / (n - k)
    cov = sigma2 * XtX_inv
    se = np.sqrt(np.diag(cov))
    return {
        "tau": float(tau),
        "beta": beta,
        "se": se,
        "names": names,
        "ssr": ssr,
        "n": n,
        "k": k,
        "sigma2": sigma2,
    }


def _fit_no_threshold(
    y: np.ndarray,
    d: np.ndarray,
    country_id: np.ndarray,
    base_country: int,
) -> dict:
    n = len(y)
    D, others = _country_dummies(country_id, base_country)
    cons = np.ones(n)
    X = np.column_stack([d, D, cons])
    names = ["d"] + [f"country_{c}" for c in others] + ["_cons"]
    XtX = X.T @ X
    XtX_inv = np.linalg.inv(XtX)
    beta = XtX_inv @ X.T @ y
    u = y - X @ beta
    ssr = float(u @ u)
    k = X.shape[1]
    sigma2 = ssr / (n - k)
    cov = sigma2 * XtX_inv
    se = np.sqrt(np.diag(cov))
    return {
        "beta": beta,
        "se": se,
        "names": names,
        "ssr": ssr,
        "n": n,
        "k": k,
        "sigma2": sigma2,
    }


def _stata_threshold_bic(n: int, ssr: float, k: int) -> float:
    """Approximate Stata's ``threshold`` BIC.

    Stata reports ``-2*ll + (k+1)*ln(N)`` with ll evaluated at the OLS
    MLE.  The "+1" accounts for the residual variance.
    """
    ll = -n / 2.0 * (1.0 + np.log(2.0 * np.pi) + np.log(ssr / n))
    return float(-2.0 * ll + (k + 1) * np.log(n))


def hansen_one_threshold(
    y: np.ndarray,
    d: np.ndarray,
    country_id: np.ndarray,
    trim: float = 0.10,
) -> dict:
    """Grid-search Hansen 1-threshold estimator.

    Search range is ``sorted(d)[lo:hi]`` with ``lo = floor(trim*n)``
    and ``hi = n - floor(trim*n)`` (the ``trim(0.10)`` default of
    Stata's ``threshold`` command, which yields 625 candidate
    regressions for n = 780).
    """
    n = len(y)
    sorted_d = np.sort(d)
    lo = int(np.floor(trim * n))
    hi = n - lo
    grid_positions = sorted_d[lo:hi]
    candidates = np.unique(grid_positions)

    base_country = int(np.min(country_id))
    best: dict | None = None
    for tau in candidates:
        fit = _fit_one_threshold(y, d, country_id, float(tau), base_country)
        if best is None or fit["ssr"] < best["ssr"]:
            best = fit
    assert best is not None
    best["bic"] = _stata_threshold_bic(best["n"], best["ssr"], best["k"])
    best["base_country"] = base_country
    return best


def hansen_two_thresholds(
    y: np.ndarray,
    d: np.ndarray,
    country_id: np.ndarray,
    trim: float = 0.10,
) -> dict:
    """Bai (1997) sequential 2-threshold estimator.

    Stage 1: 1-threshold tau1 via :func:`hansen_one_threshold`.
    Stage 2: holding tau1 fixed, search the larger of the two regions
    for tau2.
    """
    first = hansen_one_threshold(y, d, country_id, trim=trim)
    tau1 = first["tau"]
    n = len(y)
    base_country = int(np.min(country_id))

    # In which region is each obs?
    in_low = d <= tau1
    in_high = d > tau1
    larger = in_low if in_low.sum() >= in_high.sum() else in_high
    candidates = np.unique(np.sort(d[larger]))
    # Stata trims within the conditional sub-sample.
    n_sub = larger.sum()
    lo = int(np.floor(trim * n_sub))
    hi = n_sub - lo
    candidates = np.unique(np.sort(d[larger])[lo:hi])

    best: dict | None = None
    for tau2 in candidates:
        if tau2 == tau1:
            continue
        lo_tau, hi_tau = sorted([tau1, float(tau2)])
        I1 = (d <= lo_tau).astype(float)
        I2 = ((d > lo_tau) & (d <= hi_tau)).astype(float)
        I3 = (d > hi_tau).astype(float)
        D, others = _country_dummies(country_id, base_country)
        X = np.column_stack(
            [I1, d * I1, I2, d * I2, I3, d * I3, D]
        )
        names = (
            ["alpha1", "beta1", "alpha2", "beta2", "alpha3", "beta3"]
            + [f"country_{c}" for c in others]
        )
        XtX = X.T @ X
        try:
            XtX_inv = np.linalg.inv(XtX)
        except np.linalg.LinAlgError:
            continue
        beta = XtX_inv @ X.T @ y
        u = y - X @ beta
        ssr = float(u @ u)
        if best is None or ssr < best["ssr"]:
            sigma2 = ssr / (n - X.shape[1])
            cov = sigma2 * XtX_inv
            se = np.sqrt(np.diag(cov))
            best = {
                "tau1": lo_tau,
                "tau2": hi_tau,
                "beta": beta,
                "se": se,
                "names": names,
                "ssr": ssr,
                "n": n,
                "k": X.shape[1],
                "sigma2": sigma2,
            }
    if best is None:
        return {"failed": True, "tau1": tau1}
    best["bic"] = _stata_threshold_bic(best["n"], best["ssr"], best["k"])
    best["base_country"] = base_country
    return best


def _format_one_threshold(label: str, fit: dict) -> str:
    out = io.StringIO()
    out.write(f"--- {label}: 1-threshold (Hansen, trim=0.10) ---\n")
    out.write(f"  tau            = {fit['tau']:.7f}\n")
    out.write(f"  N              = {fit['n']}\n")
    out.write(f"  k (params)     = {fit['k']}\n")
    out.write(f"  SSR            = {fit['ssr']:.4f}\n")
    out.write(f"  BIC (Stata-ish)= {fit['bic']:.4f}\n")
    out.write("  Region 1 (d <= tau):\n")
    a1 = fit["beta"][0]
    b1 = fit["beta"][1]
    a1_se = fit["se"][0]
    b1_se = fit["se"][1]
    out.write(
        f"    _cons = {a1:>10.6f}  (SE {a1_se:.6f}, z = {a1/a1_se:>6.2f})\n"
    )
    out.write(
        f"    d     = {b1:>10.7f}  (SE {b1_se:.7f}, z = {b1/b1_se:>6.2f})\n"
    )
    out.write("  Region 2 (d > tau):\n")
    a2 = fit["beta"][2]
    b2 = fit["beta"][3]
    a2_se = fit["se"][2]
    b2_se = fit["se"][3]
    out.write(
        f"    _cons = {a2:>10.6f}  (SE {a2_se:.6f}, z = {a2/a2_se:>6.2f})\n"
    )
    out.write(
        f"    d     = {b2:>10.7f}  (SE {b2_se:.7f}, z = {b2/b2_se:>6.2f})\n"
    )
    return out.getvalue()


def _format_two_thresholds(label: str, fit: dict) -> str:
    out = io.StringIO()
    out.write(f"--- {label}: 2-thresholds (Bai sequential, trim=0.10) ---\n")
    if fit.get("failed"):
        out.write("  search failed (no improvement over 1-threshold)\n")
        return out.getvalue()
    out.write(f"  tau1           = {fit['tau1']:.7f}\n")
    out.write(f"  tau2           = {fit['tau2']:.7f}\n")
    out.write(f"  N              = {fit['n']}\n")
    out.write(f"  k (params)     = {fit['k']}\n")
    out.write(f"  SSR            = {fit['ssr']:.4f}\n")
    out.write(f"  BIC (Stata-ish)= {fit['bic']:.4f}\n")
    for r, (a_idx, b_idx, lab) in enumerate(
        [(0, 1, "Region1 (d<=tau1)"), (2, 3, "Region2"), (4, 5, "Region3 (d>tau2)")]
    ):
        a = fit["beta"][a_idx]
        b = fit["beta"][b_idx]
        a_se = fit["se"][a_idx]
        b_se = fit["se"][b_idx]
        out.write(f"  {lab}:\n")
        out.write(
            f"    _cons = {a:>10.6f}  (SE {a_se:.6f}, z = {a/a_se:>6.2f})\n"
        )
        out.write(
            f"    d     = {b:>10.7f}  (SE {b_se:.7f}, z = {b/b_se:>6.2f})\n"
        )
    return out.getvalue()


def _format_no_threshold(label: str, fit: dict) -> str:
    out = io.StringIO()
    out.write(f"--- {label}: 0-threshold (linear with country FE) ---\n")
    out.write(f"  N              = {fit['n']}\n")
    out.write(f"  k (params)     = {fit['k']}\n")
    out.write(f"  SSR            = {fit['ssr']:.4f}\n")
    out.write(f"  BIC (Stata-ish)= {_stata_threshold_bic(fit['n'], fit['ssr'], fit['k']):.4f}\n")
    b = fit["beta"][0]
    s = fit["se"][0]
    out.write(f"  d coefficient = {b:.7f}  (SE {s:.7f}, t = {b/s:.2f})\n")
    return out.getvalue()


# Targets we expect from the Stata log (committed under
# Code/empirical_debt_composition/results/threshold_estimation_default_trim.txt).
STATA_TARGETS_1THR: dict[str, dict[str, float]] = {
    "db_total": {
        "tau": 102.74851,
        "region1_d": 0.2735618,
        "region1_d_se": 0.0148598,
        "region2_d": 0.9638326,
        "region2_d_se": 0.0317138,
    },
    "dcb": {
        "tau": 109.026,
        "region1_d": 0.1617667,
        "region1_d_se": 0.0147613,
        "region2_d": 0.794868,
        "region2_d_se": 0.0379451,
    },
    "dpb": {
        "tau": 109.026,
        "region1_d": 0.0940137,
        "region1_d_se": 0.0136957,
        "region2_d": 0.1537806,
        "region2_d_se": 0.0352059,
    },
    "dh": {
        "tau": 108.755,
        "region1_d": 0.1124473,
        "region1_d_se": 0.0148277,
        "region2_d": -0.289633,
        "region2_d_se": 0.0376075,
    },
}


def _diff_against_target(label: str, fit: dict) -> str:
    tgt = STATA_TARGETS_1THR.get(label)
    if tgt is None:
        return ""
    out = io.StringIO()
    out.write(f"  vs Stata target for {label}:\n")

    def _row(name: str, py: float, st: float) -> None:
        diff = py - st
        rel = abs(diff) / max(abs(st), 1e-9)
        ok = "OK " if rel < 1e-3 else "!! "
        out.write(
            f"    {ok}{name:<14} python={py:>14.7f} stata={st:>14.7f} "
            f"diff={diff:>+12.7f}  rel={rel:.2e}\n"
        )

    _row("tau",          fit["tau"],     tgt["tau"])
    _row("region1_d",    fit["beta"][1], tgt["region1_d"])
    _row("region1_d_se", fit["se"][1],   tgt["region1_d_se"])
    _row("region2_d",    fit["beta"][3], tgt["region2_d"])
    _row("region2_d_se", fit["se"][3],   tgt["region2_d_se"])
    return out.getvalue()


def main() -> None:
    df = load_panel()
    df = df.copy()
    df["db_total"] = df["dcb"] + df["dpb"]

    out_dir = ensure_results_dir()
    out_path = out_dir / "threshold_default_trim.py.txt"

    sections: list[str] = []
    sections.append(
        "Python port of threshold_estimation_default_trim.do\n"
        f"Source data: Data/gfdd_with_de_facto1.dta (N={len(df)} rows)\n"
    )

    bic_summary: dict[str, dict[str, float]] = {}

    for label in ("db_total", "dcb", "dpb", "dh"):
        sub = df.dropna(subset=[label, "d", "country_id", "year"]).copy()
        y = sub[label].to_numpy(dtype=float)
        d = sub["d"].to_numpy(dtype=float)
        c = sub["country_id"].to_numpy(dtype=int)

        sections.append("=" * 78)
        sections.append(f"OUTCOME = {label}  (N = {len(y)})")
        sections.append("=" * 78)

        no_thr = _fit_no_threshold(y, d, c, base_country=int(c.min()))
        sections.append(_format_no_threshold(label, no_thr))

        one_thr = hansen_one_threshold(y, d, c)
        sections.append(_format_one_threshold(label, one_thr))
        sections.append(_diff_against_target(label, one_thr))

        if label != "dh":
            two_thr = hansen_two_thresholds(y, d, c)
            sections.append(_format_two_thresholds(label, two_thr))
            two_bic = two_thr.get("bic", float("nan"))
        else:
            two_bic = float("nan")

        bic_summary[label] = {
            "0_thr": _stata_threshold_bic(no_thr["n"], no_thr["ssr"], no_thr["k"]),
            "1_thr": one_thr["bic"],
            "2_thr": two_bic,
        }

    sections.append("=" * 78)
    sections.append("SUMMARY OF BIC (lower = better)")
    sections.append("=" * 78)
    sections.append(f"{'Outcome':<12} {'0 thr':>12} {'1 thr':>12} {'2 thr':>12}")
    for label, b in bic_summary.items():
        sections.append(
            f"{label:<12} {b['0_thr']:>12.4f} {b['1_thr']:>12.4f} "
            f"{b['2_thr']:>12.4f}"
        )

    out_path.write_text("\n".join(sections))
    print(f"wrote {out_path}")
    for label in ("db_total", "dcb", "dpb", "dh"):
        sub = df.dropna(subset=[label, "d", "country_id", "year"])
        y = sub[label].to_numpy(dtype=float)
        d = sub["d"].to_numpy(dtype=float)
        c = sub["country_id"].to_numpy(dtype=int)
        fit = hansen_one_threshold(y, d, c)
        tgt = STATA_TARGETS_1THR[label]
        ok = abs(fit["tau"] - tgt["tau"]) < 1e-3
        print(
            f"  {label:<10} tau_py={fit['tau']:.5f} "
            f"tau_stata={tgt['tau']:.5f} {'OK' if ok else 'MISMATCH'}"
        )


if __name__ == "__main__":
    main()
