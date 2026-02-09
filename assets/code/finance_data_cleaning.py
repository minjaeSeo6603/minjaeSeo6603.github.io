"""
================================================================================
SCF Data Cleaning and Preparation Script
================================================================================
Author: Seo, Minjae
Date: January 2025
Purpose: Clean and prepare Survey of Consumer Finances data for analysis

This script performs the following:
1. Load and validate raw data from 2010, 2016, 2022 SCF waves
2. Check data quality (missing values, variable ranges, duplicates)
3. Apply inflation adjustment to monetary variables
4. Handle outliers via winsorization
5. Create derived variables and categorical encodings
6. Merge with supplementary opinion data
7. Construct proper survey weights
8. Export cleaned dataset

Usage:
    python data_cleaning.py

Output:
    - cleaned_scf_data.csv: Main analysis dataset
    - output/reports/data_quality_report.txt: Data quality diagnostics
================================================================================
"""

import pandas as pd
import numpy as np
from datetime import datetime
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# =============================================================================
# CONFIGURATION
# =============================================================================

# Paths (portable project-relative defaults)
PROJECT_ROOT = Path(__file__).resolve().parents[2]
RAW_DATA_CANDIDATES = [
    PROJECT_ROOT / "data" / "raw",
    PROJECT_ROOT / "dataset",  # backward compatibility for older layout
]
PROCESSED_DATA_DIR = PROJECT_ROOT / "data" / "clean"
REPORTS_DIR = PROJECT_ROOT / "output" / "reports"


def resolve_data_dir():
    """Locate raw input directory for SCF files."""
    for candidate in RAW_DATA_CANDIDATES:
        if (candidate / "SCFP2010.csv").exists():
            return candidate
    raise FileNotFoundError(
        "Could not locate SCF raw data. Expected SCFP2010.csv in one of: "
        + ", ".join(str(p) for p in RAW_DATA_CANDIDATES)
    )


DATA_DIR = resolve_data_dir()

# Survey years
YEARS = [2010, 2016, 2022]

# CPI-U Annual Averages (Bureau of Labor Statistics)
# Source: https://www.bls.gov/cpi/
CPI = {
    2010: 218.1,
    2016: 240.0,
    2022: 292.7
}
BASE_YEAR = 2022  # Reference year for inflation adjustment

# Monetary variables to adjust for inflation
MONETARY_VARS = [
    'INCOME', 'WAGEINC', 'BUSSEFARMINC', 'INTDIVINC', 'KGINC',
    'SSRETINC', 'TRANSFOTHINC', 'NORMINC',
    'NETWORTH', 'ASSET', 'FIN', 'NFIN',
    'DEBT', 'MRTHEL', 'RESDBT', 'OTHLOC', 'CCBAL', 'INSTALL',
    'ODEBT', 'HOUSES', 'VEHIC'
]

# Variables to winsorize (handle outliers)
VARS_TO_WINSORIZE = ['INCOME', 'NETWORTH', 'DEBT', 'ASSET']
WINSOR_PERCENTILES = (1, 99)

# Expected variable ranges based on SCF codebook
EXPECTED_RANGES = {
    'AGE': (18, 95),
    'EDUC': (-1, 17),
    'EDCL': (1, 4),
    'RACE': (1, 5),
    'MARRIED': (1, 5),
    'HHSEX': (1, 2),
    'KIDS': (0, 20),
    'WGT': (0, np.inf),
    'YESFINRISK': (0, 1),
    'X401': (1, 5),
    'X402': (1, 5),
    'X403': (1, 5),
    'X405': (1, 5),
}

# =============================================================================
# DATA LOADING FUNCTIONS
# =============================================================================

def load_scfp_data(data_dir, years):
    """
    Load Summary Extract Public Data for specified years.

    Parameters:
    -----------
    data_dir : str
        Path to data directory
    years : list
        List of survey years to load

    Returns:
    --------
    dict : Dictionary of DataFrames keyed by year
    """
    datasets = {}

    for year in years:
        filepath = data_dir / f'SCFP{year}.csv'
        print(f"Loading SCFP{year}.csv...")

        df = pd.read_csv(filepath)
        df['YEAR'] = year
        datasets[year] = df

        print(f"  → {len(df):,} observations, {len(df.columns)} variables")

    return datasets


def load_supplementary_data(data_dir, years):
    """
    Load supplementary data containing opinion variables (X401, X402, X403, X405).

    Parameters:
    -----------
    data_dir : str
        Path to data directory
    years : list
        List of survey years to load

    Returns:
    --------
    dict : Dictionary of DataFrames keyed by year
    """
    datasets = {}

    for year in years:
        filepath = data_dir / f'scf_sup_{year}.csv'
        print(f"Loading scf_sup_{year}.csv...")

        df = pd.read_csv(filepath)
        df.columns = df.columns.str.upper()
        df['YEAR'] = year
        datasets[year] = df

        print(f"  → {len(df):,} observations")

    return datasets


# =============================================================================
# DATA VALIDATION FUNCTIONS
# =============================================================================

def validate_schema_consistency(datasets):
    """
    Check that all datasets have consistent column structure.

    Parameters:
    -----------
    datasets : dict
        Dictionary of DataFrames keyed by year

    Returns:
    --------
    dict : Validation results
    """
    years = list(datasets.keys())
    column_sets = {year: set(df.columns) for year, df in datasets.items()}

    # Find common columns
    common = set.intersection(*column_sets.values())

    # Find year-specific columns
    differences = {}
    for year in years:
        only_this_year = column_sets[year] - common
        if only_this_year:
            differences[year] = only_this_year

    return {
        'common_columns': len(common),
        'all_identical': len(differences) == 0,
        'differences': differences
    }


def validate_imputation_structure(df, year):
    """
    Validate that each household (YY1) has exactly 5 implicates (Y1).

    The SCF uses multiple imputation with 5 implicates per household.

    Parameters:
    -----------
    df : DataFrame
        Survey data
    year : int
        Survey year

    Returns:
    --------
    dict : Validation results
    """
    implicate_counts = df.groupby('YY1')['Y1'].nunique()

    return {
        'year': year,
        'n_households': df['YY1'].nunique(),
        'n_observations': len(df),
        'expected_observations': df['YY1'].nunique() * 5,
        'all_have_5_implicates': (implicate_counts == 5).all(),
        'min_implicates': implicate_counts.min(),
        'max_implicates': implicate_counts.max()
    }


def validate_variable_ranges(df, expected_ranges, year):
    """
    Check that variables are within expected ranges.

    Parameters:
    -----------
    df : DataFrame
        Survey data
    expected_ranges : dict
        Dictionary of {variable: (min, max)}
    year : int
        Survey year

    Returns:
    --------
    list : List of validation issues
    """
    issues = []

    for var, (min_val, max_val) in expected_ranges.items():
        if var not in df.columns:
            continue

        below_min = (df[var] < min_val).sum()
        above_max = (df[var] > max_val).sum() if max_val != np.inf else 0

        if below_min > 0 or above_max > 0:
            issues.append({
                'year': year,
                'variable': var,
                'below_min': below_min,
                'above_max': above_max,
                'expected_range': f"[{min_val}, {max_val}]"
            })

    return issues


def analyze_missing_values(df, key_vars):
    """
    Analyze missing values in key variables.

    Parameters:
    -----------
    df : DataFrame
        Survey data
    key_vars : list
        List of variable names to check

    Returns:
    --------
    DataFrame : Missing value statistics
    """
    results = []

    for var in key_vars:
        if var not in df.columns:
            continue

        results.append({
            'Variable': var,
            'N_Missing': df[var].isna().sum(),
            'Pct_Missing': df[var].isna().mean() * 100,
            'N_Zero': (df[var] == 0).sum(),
            'N_Negative': (df[var] < 0).sum(),
            'Min': df[var].min(),
            'Max': df[var].max()
        })

    return pd.DataFrame(results)


# =============================================================================
# DATA TRANSFORMATION FUNCTIONS
# =============================================================================

def apply_inflation_adjustment(df, monetary_vars, cpi, base_year):
    """
    Adjust monetary variables to base year dollars using CPI.

    Parameters:
    -----------
    df : DataFrame
        Survey data
    monetary_vars : list
        List of monetary variable names
    cpi : dict
        Dictionary of {year: cpi_value}
    base_year : int
        Base year for adjustment

    Returns:
    --------
    DataFrame : Data with adjusted variables (suffix '_ADJ')
    """
    df = df.copy()

    # Calculate adjustment factors
    factors = {year: cpi[base_year] / cpi[year] for year in cpi}

    factor_series = df['YEAR'].map(factors)
    for var in monetary_vars:
        if var in df.columns:
            adj_var = f'{var}_ADJ'
            df[adj_var] = df[var] * factor_series

    return df


def winsorize_by_year(df, var, lower_pct=1, upper_pct=99):
    """
    Winsorize variable by year to handle outliers.

    Parameters:
    -----------
    df : DataFrame
        Survey data
    var : str
        Variable name to winsorize
    lower_pct : float
        Lower percentile cutoff
    upper_pct : float
        Upper percentile cutoff

    Returns:
    --------
    DataFrame : Data with winsorized variable (suffix '_WIN')
    """
    df = df.copy()
    win_var = f'{var}_WIN'
    df[win_var] = df[var].copy()

    for year in df['YEAR'].unique():
        mask = df['YEAR'] == year
        year_data = df.loc[mask, var]

        lower_bound = np.percentile(year_data, lower_pct)
        upper_bound = np.percentile(year_data, upper_pct)

        df.loc[mask, win_var] = year_data.clip(lower=lower_bound, upper=upper_bound)

    return df


def create_log_transforms(df, vars_to_transform):
    """
    Create log transformations for skewed variables.

    Parameters:
    -----------
    df : DataFrame
        Survey data
    vars_to_transform : list
        List of variable names to transform

    Returns:
    --------
    DataFrame : Data with log-transformed variables (prefix 'LOG_')
    """
    df = df.copy()

    for var in vars_to_transform:
        if var not in df.columns:
            continue

        log_var = f'LOG_{var}'

        # Use inverse hyperbolic sine for variables that can be negative
        if df[var].min() < 0:
            df[log_var] = np.arcsinh(df[var])
        else:
            # Standard log(1+x) for non-negative variables
            df[log_var] = np.log1p(df[var].clip(lower=0))

    return df


def create_categorical_variables(df):
    """
    Create categorical and binary variables for analysis.

    Parameters:
    -----------
    df : DataFrame
        Survey data

    Returns:
    --------
    DataFrame : Data with new categorical variables
    """
    df = df.copy()

    # Education categories (from EDCL)
    educ_map = {1: 'No High School', 2: 'High School', 3: 'Some College', 4: 'College+'}
    if 'EDCL' in df.columns:
        df['EDUC_CAT'] = df['EDCL'].map(educ_map)

    # Age groups
    if 'AGE' in df.columns:
        df['AGE_GROUP'] = pd.cut(
            df['AGE'],
            bins=[0, 35, 50, 65, 100],
            labels=['Under 35', '35-50', '51-65', '65+']
        )

    # Binary indicators
    if 'EDCL' in df.columns:
        df['COLLEGE'] = (df['EDCL'] >= 4).astype(int)

    if 'AGE' in df.columns:
        df['YOUNG'] = (df['AGE'] < 40).astype(int)

    if 'DEBT' in df.columns:
        df['HAS_DEBT'] = (df['DEBT'] > 0).astype(int)

    # Income quintiles by year
    if 'INCOME_ADJ' in df.columns:
        df['INCOME_QUINTILE'] = df.groupby('YEAR')['INCOME_ADJ'].transform(
            lambda x: pd.qcut(x, q=5, labels=['Q1', 'Q2', 'Q3', 'Q4', 'Q5'], duplicates='drop')
        )

    return df


def create_weight_variables(df):
    """
    Create normalized and scaled weight variables.

    Parameters:
    -----------
    df : DataFrame
        Survey data with WGT variable

    Returns:
    --------
    DataFrame : Data with additional weight variables
    """
    df = df.copy()

    # Normalized weights (sum to 1 within each year)
    df['WGT_NORM'] = df.groupby('YEAR')['WGT'].transform(lambda x: x / x.sum())

    # Scaled weights (mean = 1 within each year, sum = sample size)
    df['WGT_SCALED'] = df.groupby('YEAR')['WGT'].transform(lambda x: x / x.mean())

    return df


# =============================================================================
# DATA MERGING FUNCTIONS
# =============================================================================

def validate_merge_keys(df1, df2, keys):
    """
    Validate merge key consistency between two datasets.

    Parameters:
    -----------
    df1 : DataFrame
        First dataset
    df2 : DataFrame
        Second dataset
    keys : list
        List of merge key column names

    Returns:
    --------
    dict : Validation results
    """
    keys1 = set(zip(*[df1[k] for k in keys]))
    keys2 = set(zip(*[df2[k] for k in keys]))

    return {
        'only_in_df1': len(keys1 - keys2),
        'only_in_df2': len(keys2 - keys1),
        'common': len(keys1 & keys2),
        'perfect_match': len(keys1 - keys2) == 0 and len(keys2 - keys1) == 0
    }


def merge_datasets(scfp_df, sup_df, keys):
    """
    Merge SCFP data with supplementary opinion data.

    Parameters:
    -----------
    scfp_df : DataFrame
        Summary Extract Public Data
    sup_df : DataFrame
        Supplementary data with opinion variables
    keys : list
        List of merge key column names

    Returns:
    --------
    DataFrame : Merged dataset
    """
    # Select only necessary columns from supplementary data
    sup_cols = keys + ['X401', 'X402', 'X403', 'X405']
    sup_subset = sup_df[sup_cols]

    # Perform inner join
    merged = pd.merge(
        scfp_df,
        sup_subset,
        on=keys,
        how='inner',
        validate='one_to_one'
    )

    return merged


# =============================================================================
# REPORTING FUNCTIONS
# =============================================================================

def generate_quality_report(scfp_data, sup_data, merged_data, output_path):
    """
    Generate comprehensive data quality report.

    Parameters:
    -----------
    scfp_data : dict
        Dictionary of SCFP DataFrames by year
    sup_data : dict
        Dictionary of supplementary DataFrames by year
    merged_data : DataFrame
        Final merged dataset
    output_path : str
        Path for output report
    """
    with open(output_path, 'w') as f:
        f.write("="*70 + "\n")
        f.write("SCF DATA QUALITY REPORT\n")
        f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("="*70 + "\n\n")

        # Section 1: Raw Data Summary
        f.write("1. RAW DATA SUMMARY\n")
        f.write("-"*70 + "\n")
        for year, df in scfp_data.items():
            f.write(f"  SCFP {year}: {len(df):,} obs, {len(df.columns)} vars\n")
        f.write("\n")

        # Section 2: Schema Validation
        f.write("2. SCHEMA CONSISTENCY\n")
        f.write("-"*70 + "\n")
        schema_result = validate_schema_consistency(scfp_data)
        f.write(f"  Common columns: {schema_result['common_columns']}\n")
        f.write(f"  All identical: {schema_result['all_identical']}\n")
        f.write("\n")

        # Section 3: Imputation Structure
        f.write("3. MULTIPLE IMPUTATION STRUCTURE\n")
        f.write("-"*70 + "\n")
        for year, df in scfp_data.items():
            imp_result = validate_imputation_structure(df, year)
            f.write(f"  {year}: {imp_result['n_households']:,} households × 5 implicates = "
                   f"{imp_result['n_observations']:,} obs\n")
        f.write("\n")

        # Section 4: Merged Data Summary
        f.write("4. MERGED DATA SUMMARY\n")
        f.write("-"*70 + "\n")
        f.write(f"  Total observations: {len(merged_data):,}\n")
        f.write(f"  Unique households: {merged_data['YY1'].nunique():,}\n")
        f.write(f"  Variables: {len(merged_data.columns)}\n")
        f.write("\n")

        # Section 5: Key Variable Statistics
        f.write("5. KEY VARIABLE STATISTICS\n")
        f.write("-"*70 + "\n")
        key_vars = ['AGE', 'INCOME_ADJ', 'NETWORTH', 'DEBT', 'EDUC']
        stats = merged_data[key_vars].describe().T[['count', 'mean', 'std', 'min', '50%', 'max']]
        f.write(stats.round(2).to_string())
        f.write("\n\n")

        # Section 6: Opinion Variable Distributions
        f.write("6. OPINION VARIABLE DISTRIBUTIONS\n")
        f.write("-"*70 + "\n")
        for var in ['X401', 'X402', 'X403', 'X405']:
            dist = merged_data[var].value_counts(normalize=True).sort_index() * 100
            f.write(f"  {var}: {dist.round(1).to_dict()}\n")
        f.write("\n")

        f.write("="*70 + "\n")
        f.write("END OF REPORT\n")
        f.write("="*70 + "\n")

    print(f"Quality report saved to: {output_path}")


# =============================================================================
# MAIN EXECUTION
# =============================================================================

def main():
    """Main data cleaning pipeline."""

    print("\n" + "="*70)
    print("SCF DATA CLEANING PIPELINE")
    print("="*70 + "\n")

    # Step 1: Load raw data
    print("STEP 1: Loading raw data...")
    print("-"*70)
    scfp_data = load_scfp_data(DATA_DIR, YEARS)
    sup_data = load_supplementary_data(DATA_DIR, YEARS)

    # Step 2: Validate raw data
    print("\nSTEP 2: Validating raw data...")
    print("-"*70)

    # Schema consistency
    schema_result = validate_schema_consistency(scfp_data)
    print(f"Schema consistency: {'PASS' if schema_result['all_identical'] else 'FAIL'}")

    # Imputation structure
    for year, df in scfp_data.items():
        imp_result = validate_imputation_structure(df, year)
        status = 'PASS' if imp_result['all_have_5_implicates'] else 'FAIL'
        print(f"Imputation structure {year}: {status}")

    # Step 3: Combine waves
    print("\nSTEP 3: Combining survey waves...")
    print("-"*70)
    scfp_combined = pd.concat(scfp_data.values(), ignore_index=True)
    sup_combined = pd.concat(sup_data.values(), ignore_index=True)
    print(f"Combined SCFP: {len(scfp_combined):,} observations")
    print(f"Combined supplementary: {len(sup_combined):,} observations")

    # Step 4: Apply inflation adjustment
    print("\nSTEP 4: Applying inflation adjustment...")
    print("-"*70)
    scfp_combined = apply_inflation_adjustment(scfp_combined, MONETARY_VARS, CPI, BASE_YEAR)
    adjusted_count = sum(1 for v in MONETARY_VARS if f'{v}_ADJ' in scfp_combined.columns)
    print(f"Adjusted {adjusted_count} monetary variables to {BASE_YEAR} dollars")

    # Step 5: Handle outliers
    print("\nSTEP 5: Handling outliers (winsorization)...")
    print("-"*70)
    for var in VARS_TO_WINSORIZE:
        if var in scfp_combined.columns:
            scfp_combined = winsorize_by_year(
                scfp_combined, var,
                lower_pct=WINSOR_PERCENTILES[0],
                upper_pct=WINSOR_PERCENTILES[1]
            )
            print(f"  Winsorized {var} at {WINSOR_PERCENTILES}th percentiles")

    # Step 6: Create log transformations
    print("\nSTEP 6: Creating log transformations...")
    print("-"*70)
    vars_for_log = ['INCOME_ADJ', 'NETWORTH', 'DEBT', 'ASSET']
    scfp_combined = create_log_transforms(scfp_combined, vars_for_log)
    print(f"Created log transforms for: {vars_for_log}")

    # Step 7: Create categorical variables
    print("\nSTEP 7: Creating categorical variables...")
    print("-"*70)
    scfp_combined = create_categorical_variables(scfp_combined)
    print("Created: EDUC_CAT, AGE_GROUP, COLLEGE, YOUNG, HAS_DEBT, INCOME_QUINTILE")

    # Step 8: Merge with opinion data
    print("\nSTEP 8: Merging with opinion data...")
    print("-"*70)
    merge_keys = ['YEAR', 'YY1', 'Y1']
    merge_validation = validate_merge_keys(scfp_combined, sup_combined, merge_keys)
    print(f"Merge key validation: {'PASS' if merge_validation['perfect_match'] else 'FAIL'}")

    merged_data = merge_datasets(scfp_combined, sup_combined, merge_keys)
    print(f"Merged dataset: {len(merged_data):,} observations")

    # Step 9: Create weight variables
    print("\nSTEP 9: Creating weight variables...")
    print("-"*70)
    merged_data = create_weight_variables(merged_data)
    print("Created: WGT_NORM (normalized), WGT_SCALED (scaled)")

    # Step 10: Final validation
    print("\nSTEP 10: Final validation...")
    print("-"*70)
    for var in ['X401', 'X402', 'X403', 'X405']:
        if var in merged_data.columns:
            issues = validate_variable_ranges(merged_data, {var: EXPECTED_RANGES[var]}, 'ALL')
            status = 'PASS' if not issues else 'FAIL'
            print(f"  {var} range validation: {status}")

    # Step 11: Export cleaned data
    print("\nSTEP 11: Exporting cleaned data...")
    print("-"*70)
    PROCESSED_DATA_DIR.mkdir(parents=True, exist_ok=True)
    output_data_path = PROCESSED_DATA_DIR / 'cleaned_scf_data.csv'
    merged_data.to_csv(output_data_path, index=False)
    print(f"Cleaned data saved to: {output_data_path}")

    # Step 12: Generate quality report
    print("\nSTEP 12: Generating quality report...")
    print("-"*70)
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    report_path = REPORTS_DIR / 'data_quality_report.txt'
    generate_quality_report(scfp_data, sup_data, merged_data, report_path)

    # Final summary
    print("\n" + "="*70)
    print("DATA CLEANING COMPLETE")
    print("="*70)
    print(f"Final dataset: {len(merged_data):,} observations")
    print(f"Variables: {len(merged_data.columns)}")
    print(f"Output: {output_data_path}")
    print(f"Report: {report_path}")
    print("="*70 + "\n")

    return merged_data


if __name__ == "__main__":
    cleaned_data = main()
