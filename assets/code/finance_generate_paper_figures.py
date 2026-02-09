#!/usr/bin/env python3
"""
Generate publication-style figures for the SCF debt-attitude paper.
"""

import argparse
import os
from pathlib import Path

import numpy as np
import pandas as pd


if not os.environ.get("MPLCONFIGDIR"):
    os.environ["MPLCONFIGDIR"] = "/tmp/mpl"

import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PROCESSED = ROOT / "data" / "clean" / "cleaned_scf_data.csv"
DEFAULT_TABLES = ROOT / "output" / "tables"
DEFAULT_FIGURES = ROOT / "output" / "figures"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate publication figures from processed SCF outputs."
    )
    parser.add_argument(
        "--processed",
        type=Path,
        default=DEFAULT_PROCESSED,
        help="Path to cleaned_scf_data.csv",
    )
    parser.add_argument(
        "--tables-dir",
        type=Path,
        default=DEFAULT_TABLES,
        help="Directory containing output table CSVs",
    )
    parser.add_argument(
        "--figures-dir",
        type=Path,
        default=DEFAULT_FIGURES,
        help="Directory where PNG figures are saved",
    )
    return parser.parse_args()


def require_file(path: Path, label: str) -> None:
    if not path.exists():
        raise FileNotFoundError(f"Required {label} not found: {path}")


def require_columns(df: pd.DataFrame, columns: list[str], source_label: str) -> None:
    missing = [col for col in columns if col not in df.columns]
    if missing:
        raise ValueError(
            f"Missing required columns in {source_label}: {missing}"
        )


def weighted_mean(x: pd.Series, w: pd.Series) -> float:
    return float(np.average(x, weights=w))


def weighted_share(mask: pd.Series, w: pd.Series) -> float:
    return float(np.average(mask.astype(float), weights=w))


def setup_matplotlib() -> None:
    plt.style.use("seaborn-v0_8-whitegrid")
    plt.rcParams.update(
        {
            "font.size": 10,
            "axes.titlesize": 14,
            "axes.labelsize": 12,
            "legend.fontsize": 10,
            "figure.dpi": 120,
            "savefig.dpi": 300,
        }
    )


def plot_purpose_acceptance(tables_dir: Path, figures_dir: Path, years: list[int]) -> Path:
    path = tables_dir / "purpose_acceptance_by_year.csv"
    require_file(path, "purpose acceptance table")
    df = pd.read_csv(path)
    require_columns(df, ["YEAR", "label", "acceptance_rate"], str(path))

    available_years = sorted(df["YEAR"].dropna().astype(int).unique().tolist())
    plot_years = [year for year in years if year in available_years] or available_years

    fig, ax = plt.subplots(figsize=(9.5, 5.2))
    colors = {
        "Vacation (Luxury)": "#F18F01",
        "Living expenses (Necessity)": "#A23B72",
        "Car purchase (Durable/necessary)": "#2E86AB",
    }
    markers = {
        "Vacation (Luxury)": "o",
        "Living expenses (Necessity)": "s",
        "Car purchase (Durable/necessary)": "^",
    }

    for label in [
        "Car purchase (Durable/necessary)",
        "Living expenses (Necessity)",
        "Vacation (Luxury)",
    ]:
        g = df[df["label"] == label].sort_values("YEAR")
        if g.empty:
            continue
        ax.plot(
            g["YEAR"],
            g["acceptance_rate"] * 100,
            marker=markers[label],
            linewidth=2.8,
            markersize=7,
            color=colors[label],
            label=label,
        )

    ax.set_title("Acceptance Rates by Debt Purpose (Weighted SCF)")
    ax.set_xlabel("Year")
    ax.set_ylabel("Acceptance Rate (%)")
    ax.set_ylim(0, 85)
    ax.set_xticks(plot_years)
    ax.legend(title="Purpose", loc="center right", frameon=True)
    fig.tight_layout()
    output = figures_dir / "purpose_acceptance_trends.png"
    fig.savefig(output, bbox_inches="tight")
    plt.close(fig)
    return output


def plot_debt_levels_by_attitude_year(
    df: pd.DataFrame, figures_dir: Path, years: list[int]
) -> Path:
    require_columns(df, ["YEAR", "X401", "DEBT_ADJ", "WGT"], "processed dataset")
    d = df[df["X401"].between(1, 5)].copy()
    d["att_group"] = np.where(
        d["X401"] <= 2, "Good idea", np.where(d["X401"] == 3, "Mixed", "Bad idea")
    )

    rows = []
    for (year, group), gg in d.groupby(["YEAR", "att_group"]):
        rows.append(
            {
                "YEAR": int(year),
                "att_group": group,
                "debt_mean": weighted_mean(gg["DEBT_ADJ"], gg["WGT"]),
            }
        )
    out = pd.DataFrame(rows)

    order_group = ["Good idea", "Mixed", "Bad idea"]
    colors = {"Good idea": "#2E86AB", "Mixed": "#A23B72", "Bad idea": "#F18F01"}
    pivot = out.pivot_table(index="att_group", columns="YEAR", values="debt_mean")
    pivot = pivot.reindex(index=order_group, columns=years)

    missing_pairs = []
    for group in order_group:
        for year in years:
            if pd.isna(pivot.loc[group, year]):
                missing_pairs.append((group, year))
    if missing_pairs:
        raise ValueError(
            "Missing debt-level combinations for attitude/year: "
            + ", ".join(f"{group}-{year}" for group, year in missing_pairs)
        )

    x = np.arange(len(years))
    width = 0.24

    fig, ax = plt.subplots(figsize=(10.5, 5.6))
    for i, group in enumerate(order_group):
        vals = pivot.loc[group, years].to_list()
        ax.bar(x + (i - 1) * width, vals, width=width, color=colors[group], label=group)

    ax.set_title("Mean Debt Levels by General Debt Attitude and Year")
    ax.set_xlabel("Year")
    ax.set_ylabel("Debt (2022 dollars)")
    ax.set_xticks(x)
    ax.set_xticklabels(years)
    ax.legend(title="X401 Group", loc="upper right")
    ax.ticklabel_format(axis="y", style="plain")
    fig.tight_layout()
    output = figures_dir / "debt_levels_by_attitude_year.png"
    fig.savefig(output, bbox_inches="tight")
    plt.close(fig)
    return output


def plot_good_share_age_groups(
    df: pd.DataFrame, figures_dir: Path, years: list[int]
) -> Path:
    require_columns(df, ["YEAR", "X401", "AGE", "WGT"], "processed dataset")
    d = df[df["X401"].between(1, 5)].copy()
    d["is_good"] = (d["X401"] <= 2).astype(int)
    d["age_group"] = np.where(d["AGE"] < 40, "Age < 40", "Age >= 40")

    rows = []
    for (year, age_group), g in d.groupby(["YEAR", "age_group"]):
        rows.append(
            {
                "YEAR": int(year),
                "age_group": age_group,
                "good_share": weighted_share(g["is_good"] == 1, g["WGT"]),
            }
        )
    out = pd.DataFrame(rows).sort_values(["age_group", "YEAR"])

    colors = {"Age < 40": "#2E86AB", "Age >= 40": "#A23B72"}
    markers = {"Age < 40": "o", "Age >= 40": "s"}

    fig, ax = plt.subplots(figsize=(9.5, 5.2))
    for age_group in ["Age < 40", "Age >= 40"]:
        g = out[out["age_group"] == age_group]
        if g.empty:
            continue
        ax.plot(
            g["YEAR"],
            g["good_share"] * 100,
            linewidth=2.8,
            marker=markers[age_group],
            markersize=7,
            color=colors[age_group],
            label=age_group,
        )

    y = out["good_share"] * 100
    y_min = max(0.0, float(y.min()) - 2.0)
    y_max = min(100.0, float(y.max()) + 2.0)

    ax.set_title("Rise in Debt-Favorable Attitudes by Age Group")
    ax.set_xlabel("Year")
    ax.set_ylabel("Share with X401 <= 2 (%)")
    ax.set_xticks(years)
    ax.set_ylim(y_min, y_max)
    ax.legend(title="Age Group", loc="upper left")
    fig.tight_layout()
    output = figures_dir / "good_share_age_groups.png"
    fig.savefig(output, bbox_inches="tight")
    plt.close(fig)
    return output


def plot_main_coefficients(tables_dir: Path, figures_dir: Path) -> Path:
    path = tables_dir / "regression_main_models.csv"
    require_file(path, "main regression table")
    df = pd.read_csv(path)
    require_columns(df, ["model", "term", "coef", "std_err"], str(path))

    d = df[df["model"] == "X401_main"].copy()
    if d.empty:
        raise ValueError("No rows with model == 'X401_main' in regression_main_models.csv")

    keep = [
        "C(YEAR)[T.2016]",
        "C(YEAR)[T.2022]",
        "LOG_INCOME_ADJ",
        "AGE",
        "EDUC",
        "LOG_NETWORTH",
        "DEBT2INC",
    ]
    labels = {
        "C(YEAR)[T.2016]": "Year 2016 (vs 2010)",
        "C(YEAR)[T.2022]": "Year 2022 (vs 2010)",
        "LOG_INCOME_ADJ": "Log income",
        "AGE": "Age",
        "EDUC": "Education",
        "LOG_NETWORTH": "Log net worth",
        "DEBT2INC": "Debt-to-income",
    }

    d = d[d["term"].isin(keep)].copy()
    if d.empty:
        raise ValueError("No expected terms found in regression_main_models.csv for X401_main")

    missing_terms = sorted(set(keep) - set(d["term"]))
    if missing_terms:
        print(f"Warning: missing terms in coefficient plot: {missing_terms}")

    d["label"] = d["term"].map(labels)
    d["ci_low"] = d["coef"] - 1.96 * d["std_err"]
    d["ci_high"] = d["coef"] + 1.96 * d["std_err"]
    d = d.sort_values("coef")

    fig, ax = plt.subplots(figsize=(9.8, 6.0))
    y = np.arange(len(d))
    ax.hlines(y, d["ci_low"], d["ci_high"], color="#9AA0A6", linewidth=2.0)
    ax.plot(d["coef"], y, "o", color="#2E86AB", markersize=7)
    ax.axvline(0, color="black", linestyle="--", linewidth=1.0)
    ax.set_yticks(y)
    ax.set_yticklabels(d["label"])
    ax.set_xlabel("Coefficient (X401 model)")
    ax.set_title("Baseline Attitude Regression: Coefficients with 95% CIs")
    fig.tight_layout()
    output = figures_dir / "regression_coefficients_main.png"
    fig.savefig(output, bbox_inches="tight")
    plt.close(fig)
    return output


def plot_good_share_income_quintile(
    df: pd.DataFrame, figures_dir: Path, years: list[int]
) -> Path:
    require_columns(
        df,
        ["YEAR", "X401", "INCOME_QUINTILE", "WGT"],
        "processed dataset",
    )
    d = df[df["X401"].between(1, 5)].copy()
    d["is_good"] = (d["X401"] <= 2).astype(int)

    rows = []
    for (year, quintile), g in d.groupby(["YEAR", "INCOME_QUINTILE"]):
        rows.append(
            {
                "YEAR": int(year),
                "quintile": str(quintile),
                "good_share": weighted_share(g["is_good"] == 1, g["WGT"]),
            }
        )
    out = pd.DataFrame(rows)

    order = ["Q1", "Q2", "Q3", "Q4", "Q5"]
    palette = {
        "Q1": "#2E86AB",
        "Q2": "#4DAA57",
        "Q3": "#F6AE2D",
        "Q4": "#A23B72",
        "Q5": "#3B3B3B",
    }

    fig, ax = plt.subplots(figsize=(10.0, 5.4))
    for quintile in order:
        g = out[out["quintile"] == quintile].sort_values("YEAR")
        if g.empty:
            continue
        ax.plot(
            g["YEAR"],
            g["good_share"] * 100,
            linewidth=2.5,
            marker="o",
            markersize=6,
            color=palette[quintile],
            label=quintile,
        )

    y = out["good_share"] * 100
    y_min = max(0.0, float(y.min()) - 2.0)
    y_max = min(100.0, float(y.max()) + 2.0)

    ax.set_title("Debt-Favorable Attitudes by Income Quintile")
    ax.set_xlabel("Year")
    ax.set_ylabel("Share with X401 <= 2 (%)")
    ax.set_xticks(years)
    ax.set_ylim(y_min, y_max)
    ax.legend(title="Income quintile", ncol=5, loc="upper center")
    fig.tight_layout()
    output = figures_dir / "good_share_income_quintile.png"
    fig.savefig(output, bbox_inches="tight")
    plt.close(fig)
    return output


def main() -> None:
    args = parse_args()
    setup_matplotlib()

    require_file(args.processed, "processed dataset")
    if not args.tables_dir.exists():
        raise FileNotFoundError(f"Required tables directory not found: {args.tables_dir}")

    args.figures_dir.mkdir(parents=True, exist_ok=True)

    df = pd.read_csv(args.processed)
    require_columns(df, ["YEAR"], str(args.processed))
    years = sorted(df["YEAR"].dropna().astype(int).unique().tolist())
    if not years:
        raise ValueError("No valid YEAR values found in processed dataset.")

    saved_paths = [
        plot_purpose_acceptance(args.tables_dir, args.figures_dir, years),
        plot_debt_levels_by_attitude_year(df, args.figures_dir, years),
        plot_good_share_age_groups(df, args.figures_dir, years),
        plot_main_coefficients(args.tables_dir, args.figures_dir),
        plot_good_share_income_quintile(df, args.figures_dir, years),
    ]

    print("Saved figures:")
    for path in saved_paths:
        print(f" - {path}")


if __name__ == "__main__":
    main()
