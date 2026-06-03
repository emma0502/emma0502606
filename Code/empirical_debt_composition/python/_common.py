"""Shared utilities for the Python port of the empirical pipeline.

Loaders, regression helpers, and writers used by the three stage
modules and by ``run_all.py``.

Targets are the committed Stata logs under
``Code/empirical_debt_composition/results/``; this module exposes the
machinery used to reproduce those numbers from
``Data/gfdd_with_de_facto1.dta``.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

import numpy as np
import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[3]
DATA_PATH = REPO_ROOT / "Data" / "gfdd_with_de_facto1.dta"
RESULTS_DIR = REPO_ROOT / "Code" / "empirical_debt_composition" / "results"
PYTHON_RESULTS_DIR = RESULTS_DIR / "python"


def load_panel() -> pd.DataFrame:
    """Read ``Data/gfdd_with_de_facto1.dta`` and return a fresh DataFrame.

    Reloads from disk every call so that callers can mutate freely
    without affecting other stages, mirroring the ``use ... , clear``
    convention in the .do files.
    """
    df = pd.read_stata(DATA_PATH, convert_categoricals=False)
    df["country_id"] = df["country_id"].astype(int)
    df["year"] = df["year"].astype(int)
    return df


def ensure_results_dir() -> Path:
    PYTHON_RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    return PYTHON_RESULTS_DIR


@dataclass
class OLSResult:
    """Plain OLS estimate with optional clustered covariance."""

    coef: pd.Series
    se: pd.Series
    nobs: int
    ssr: float
    centered_r2: float
    uncentered_r2: float
    cov: np.ndarray
    cluster_groups: tuple[str, ...] = ()

    def t_stats(self) -> pd.Series:
        return self.coef / self.se

    def to_string(self, label: str = "") -> str:
        lines: list[str] = []
        if label:
            lines.append(label)
        lines.append("-" * 78)
        lines.append(f"{'variable':<24} {'coef':>14} {'se':>14} {'t/z':>10}")
        lines.append("-" * 78)
        for name in self.coef.index:
            b = self.coef[name]
            s = self.se[name]
            t = b / s if s > 0 else float("nan")
            lines.append(f"{name:<24} {b:>14.7f} {s:>14.7f} {t:>10.3f}")
        lines.append(f"N = {self.nobs}, SSR = {self.ssr:.6g}")
        lines.append(
            f"centered R2 = {self.centered_r2:.6f}, "
            f"uncentered R2 = {self.uncentered_r2:.6f}"
        )
        if self.cluster_groups:
            lines.append(f"clusters: {' x '.join(self.cluster_groups)}")
        return "\n".join(lines)


def _make_X(
    frame: pd.DataFrame,
    regressors: Sequence[str],
    add_constant: bool,
) -> tuple[np.ndarray, list[str]]:
    cols = list(regressors)
    X = frame.loc[:, cols].to_numpy(dtype=float)
    if add_constant:
        X = np.column_stack([X, np.ones(X.shape[0])])
        cols = cols + ["_cons"]
    return X, cols


def _cluster_meat(
    X: np.ndarray,
    u: np.ndarray,
    groups: np.ndarray,
) -> np.ndarray:
    """Compute the cluster sum sum_g (X_g' u_g)(X_g' u_g)'.

    ``groups`` is a 1-D array of integer cluster ids of length n.
    """
    meat = np.zeros((X.shape[1], X.shape[1]))
    for g in np.unique(groups):
        idx = groups == g
        Xg = X[idx]
        ug = u[idx]
        s = Xg.T @ ug
        meat += np.outer(s, s)
    return meat


def ols_twoway_cluster(
    frame: pd.DataFrame,
    y_col: str,
    regressors: Sequence[str],
    cluster_cols: Sequence[str] = ("country_id", "year"),
    add_constant: bool = False,
    sample_mask: pd.Series | None = None,
) -> OLSResult:
    """OLS with optional two-way Cameron-Gelbach-Miller clustered SE.

    Replicates Stata's ``ivreg2 ..., cluster(g h)`` output (no instruments
    means OLS).  When ``cluster_cols`` has one entry, falls back to the
    standard one-way cluster formula and matches ``regress ..., vce(cluster g)``
    /  ``ivreg2 ..., cluster(g)`` exactly.

    Standard errors use ``ivreg2``'s small-sample correction:
        c_g = G_g / (G_g - 1) * (N - 1) / (N - K)
    for each cluster dimension and the intersection cluster
    (the common piece is subtracted with the same correction
    rule based on the *minimum* cluster count, matching ivreg2's
    default ``small`` behaviour).
    """
    if sample_mask is not None:
        frame = frame.loc[sample_mask].copy()
    needed = list(regressors) + [y_col] + list(cluster_cols)
    sub = frame.dropna(subset=needed).copy()

    X, cols = _make_X(sub, regressors, add_constant)
    y = sub[y_col].to_numpy(dtype=float)
    n, k = X.shape

    XtX = X.T @ X
    XtX_inv = np.linalg.inv(XtX)
    beta = XtX_inv @ X.T @ y
    u = y - X @ beta
    ssr = float(u @ u)

    y_demean = y - y.mean()
    centered_r2 = 1 - ssr / float(y_demean @ y_demean)
    uncentered_r2 = 1 - ssr / float(y @ y)

    # Two-way clustering (Cameron-Gelbach-Miller).  When only one cluster
    # dimension is supplied the "intersection" piece collapses to the
    # one-way meat and the formula matches ``cluster(g)`` exactly.
    cluster_arrays = [sub[c].to_numpy() for c in cluster_cols]
    G = [len(np.unique(g)) for g in cluster_arrays]
    G_min = min(G) if G else n

    def _ssadj(Ng: int) -> float:
        return (Ng / (Ng - 1)) * ((n - 1) / (n - k))

    if len(cluster_arrays) == 1:
        meat = _ssadj(G[0]) * _cluster_meat(X, u, cluster_arrays[0])
    else:
        # Build the intersection cluster id from the tuple of cluster
        # values so we can sum X_gh' u_gh u_gh' X_gh.
        inter = pd.MultiIndex.from_arrays(cluster_arrays).codes
        # codes is a tuple of arrays; encode by combining
        inter_id = np.zeros(n, dtype=np.int64)
        mult = 1
        for codes in inter:
            inter_id += codes * mult
            mult *= max(2, codes.max() + 1)
        meat_g = _cluster_meat(X, u, cluster_arrays[0])
        meat_h = _cluster_meat(X, u, cluster_arrays[1])
        meat_gh = _cluster_meat(X, u, inter_id)
        meat = (
            _ssadj(G[0]) * meat_g
            + _ssadj(G[1]) * meat_h
            - _ssadj(G_min) * meat_gh
        )

    cov = XtX_inv @ meat @ XtX_inv
    se = np.sqrt(np.diag(cov))

    return OLSResult(
        coef=pd.Series(beta, index=cols),
        se=pd.Series(se, index=cols),
        nobs=n,
        ssr=ssr,
        centered_r2=centered_r2,
        uncentered_r2=uncentered_r2,
        cov=cov,
        cluster_groups=tuple(cluster_cols),
    )


def xtreg_fe_with_country_fe(
    frame: pd.DataFrame,
    y_col: str,
    regressors: Sequence[str],
    entity_col: str = "country_id",
    cluster_cols: Sequence[str] = ("country_id",),
    sample_mask: pd.Series | None = None,
) -> tuple[OLSResult, dict[int, float]]:
    """Within-country FE regression matching ``xtreg, fe``.

    ``regressors`` should already contain any year dummies the user
    wants treated as exogenous variables.  Returns the OLS result on
    the within-transformed variables AND the country-level fixed
    effect estimates ``alpha_i`` (matching Stata's ``predict u``,
    centred so that sum_i alpha_i = 0 over included observations,
    which is what ``predict u`` reports).
    """
    if sample_mask is not None:
        frame = frame.loc[sample_mask].copy()
    needed = list(regressors) + [y_col, entity_col] + list(cluster_cols)
    sub = frame.dropna(subset=needed).copy()

    # Within-transform: y_it - mean_i(y), X_it - mean_i(X).
    grp = sub.groupby(entity_col)
    y = sub[y_col].to_numpy(dtype=float)
    X_raw = sub[list(regressors)].to_numpy(dtype=float)

    y_bar = grp[y_col].transform("mean").to_numpy(dtype=float)
    X_bar = (
        sub[list(regressors)]
        .groupby(sub[entity_col])
        .transform("mean")
        .to_numpy(dtype=float)
    )

    y_w = y - y_bar
    X_w = X_raw - X_bar

    XtX = X_w.T @ X_w
    XtX_inv = np.linalg.inv(XtX)
    beta = XtX_inv @ X_w.T @ y_w

    # Fitted values and residuals on the original (un-transformed) data.
    fitted_no_fe = X_raw @ beta
    resid_no_fe = y - fitted_no_fe

    # Country FE estimates: alpha_i = mean_i(resid_no_fe).
    sub = sub.assign(_resid=resid_no_fe)
    alpha_per_country = sub.groupby(entity_col)["_resid"].mean()

    # Stata's ``predict u`` reports u_i centred so the overall constant
    # absorbs the mean: u_i = mean_i(resid) - mean(resid).
    overall_mean = float(resid_no_fe.mean())
    alpha_centred = alpha_per_country - overall_mean

    # Final residuals after subtracting country FE.
    sub["_alpha"] = sub[entity_col].map(alpha_per_country)
    full_resid = resid_no_fe - sub["_alpha"].to_numpy(dtype=float)
    ssr = float(full_resid @ full_resid)

    n = len(sub)
    n_entities = sub[entity_col].nunique()
    k_within = X_w.shape[1]
    # Effective parameters: k slopes + (n_entities - 1) entity dummies + 1
    # constant.  Use the same ddof Stata does for ``xtreg, fe``:
    # df_resid = N - K - (G_within - G_dropped).  We use n - k_within - n_entities.
    ddof = n - k_within - n_entities

    # Cluster meat on within-transformed data, but with the small-sample
    # correction Stata uses for xtreg fe:
    #   c = G/(G-1) * (N-1)/(N-K)
    # where K excludes the (G-1) absorbed entity dummies.
    cluster_arrays = [sub[c].to_numpy() for c in cluster_cols]
    G = [len(np.unique(g)) for g in cluster_arrays]
    if len(cluster_arrays) == 1:
        c0 = (G[0] / (G[0] - 1)) * ((n - 1) / max(ddof, 1))
        meat = c0 * _cluster_meat(X_w, full_resid, cluster_arrays[0])
    else:
        G_min = min(G)
        c_factors = [(g / (g - 1)) * ((n - 1) / max(ddof, 1)) for g in G]
        c_min = (G_min / (G_min - 1)) * ((n - 1) / max(ddof, 1))
        inter = pd.MultiIndex.from_arrays(cluster_arrays).codes
        inter_id = np.zeros(n, dtype=np.int64)
        mult = 1
        for codes in inter:
            inter_id += codes * mult
            mult *= max(2, codes.max() + 1)
        meat_g = _cluster_meat(X_w, full_resid, cluster_arrays[0])
        meat_h = _cluster_meat(X_w, full_resid, cluster_arrays[1])
        meat_gh = _cluster_meat(X_w, full_resid, inter_id)
        meat = c_factors[0] * meat_g + c_factors[1] * meat_h - c_min * meat_gh

    cov = XtX_inv @ meat @ XtX_inv
    se = np.sqrt(np.diag(cov))

    y_demean = y - y.mean()
    centered_r2 = 1 - ssr / float(y_demean @ y_demean)
    uncentered_r2 = 1 - ssr / float(y @ y)

    res = OLSResult(
        coef=pd.Series(beta, index=list(regressors)),
        se=pd.Series(se, index=list(regressors)),
        nobs=n,
        ssr=ssr,
        centered_r2=centered_r2,
        uncentered_r2=uncentered_r2,
        cov=cov,
        cluster_groups=tuple(cluster_cols),
    )
    fe_dict = {int(k): float(v) for k, v in alpha_centred.items()}
    return res, fe_dict


def write_textlog(path: Path, sections: Iterable[tuple[str, str]]) -> None:
    """Write a dictionary of (header, body) pairs to a text log file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as f:
        for header, body in sections:
            f.write("=" * 78 + "\n")
            f.write(header + "\n")
            f.write("=" * 78 + "\n\n")
            f.write(body)
            f.write("\n\n")
