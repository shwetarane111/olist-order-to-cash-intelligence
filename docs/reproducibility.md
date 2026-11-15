
# Reproducibility Guide

## 1. Purpose

This document explains how to prepare a local environment for the Order-to-Cash Intelligence Platform and reproduce its documented analytical outputs.

The public repository contains project source code, SQL, DAX, validation scripts, screenshots, and methodology documentation.

Raw Olist data and the full PBIX binary are intentionally excluded.

As a result, cloning the repository alone is not a one-command end-to-end rebuild.

## 2. Required Tools

- Git
- Python 3
- PostgreSQL
- pgAdmin or another PostgreSQL SQL client
- Visual Studio Code
- Power BI Desktop for Windows

The original development environment was Windows-based.

Check installed versions before reproducing the analysis.

```powershell
python --version
git --version
psql --version
```

Record the versions used in your own environment.

Python package dependencies should be established from the actual imports and environment used by the existing project scripts. Do not assume that an arbitrary installed-package list represents the project's minimal dependencies.


### Python Environment

Create a virtual environment and install
the project's direct Python dependencies.

```powershell
python -m venv .venv

.\.venv\Scripts\Activate.ps1

python -m pip install --upgrade pip

python -m pip install -r requirements.txt
```

The dependency file lists observed direct packages,
not an exact tested environment lockfile.

The analytical warehouse also requires a local
PostgreSQL installation and the original Olist
CSV files obtained separately from Kaggle.

The pipeline is not claimed to be a one-command
fully automated rebuild.

## 3. Obtain the Source Data

Dataset:

https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

License:
CC BY-NC-SA 4.0.

Download the original dataset from Kaggle.

Extract the nine CSV files into:

`data/raw/`

Preserve the filenames expected by the existing ingestion scripts.

The raw dataset is ignored by Git and is not included in this repository.

## 4. PostgreSQL Database

Local development database:

`olist_analytics`

The warehouse uses these schemas:

- raw
- staging
- analytics

Use the project's existing SQL/ingestion workflow to create and populate these schemas.

Before running scripts, inspect the existing SQL files for:

- Prerequisite schemas
- Table dependencies
- Data-loading paths
- Whether a script creates or drops objects
- Whether a script is intended to be run more than once
- Required transaction boundaries

Do not blindly execute all SQL files alphabetically.

A filename prefix may help identify a workflow stage, but execution order must be based on the actual script dependencies.

## 5. Source Profiling

The `scripts/` folder contains the project's Python source-processing and profiling scripts.

Inspect those scripts to identify:

- Python library dependencies
- Expected local input paths
- Database connection methods
- Output file locations
- Required command-line arguments

Run the source-profiling scripts using their documented inputs.

Review row-count, missing-value, duplicate, key-uniqueness, and field-quality outputs before continuing.

## 6. Build the Warehouse

Follow the existing pipeline implementation in its validated order:

1. Load original files into the raw schema.
2. Apply staging transformations.
3. Build analytical dimension tables.
4. Build analytical fact tables.
5. Run population and relationship-key checks.
6. Reconcile the resulting analytics layer with known baselines.

The final imported analytical layer contains twelve tables.

### Expected Analytical Populations

| Table | Expected Rows |
|---|---:|
| analytics.fact_orders | 99,441 |
| analytics.fact_order_items | 112,650 |
| analytics.fact_payments | 103,886 |
| analytics.fact_order_reviews | 99,224 |
| analytics.dim_order_status | 8 |
| analytics.dim_product | 32,951 |
| analytics.dim_seller | 3,095 |
| analytics.dim_customer | 96,096 |
| analytics.dim_customer_geography | 15,034 |
| analytics.dim_purchase_date | 774 |
| analytics.dim_delivery_date | 737 |
| analytics.dim_review_date | 699 |

## 7. Warehouse Smoke Test

After the analytical layer has been built, execute:

```sql
SELECT 'fact_orders' AS table_name,
       COUNT(*) AS row_count
FROM analytics.fact_orders

UNION ALL
SELECT 'fact_order_items', COUNT(*)
FROM analytics.fact_order_items

UNION ALL
SELECT 'fact_payments', COUNT(*)
FROM analytics.fact_payments

UNION ALL
SELECT 'fact_order_reviews', COUNT(*)
FROM analytics.fact_order_reviews

UNION ALL
SELECT 'dim_order_status', COUNT(*)
FROM analytics.dim_order_status

UNION ALL
SELECT 'dim_product', COUNT(*)
FROM analytics.dim_product

UNION ALL
SELECT 'dim_seller', COUNT(*)
FROM analytics.dim_seller

UNION ALL
SELECT 'dim_customer', COUNT(*)
FROM analytics.dim_customer

UNION ALL
SELECT 'dim_customer_geography', COUNT(*)
FROM analytics.dim_customer_geography

UNION ALL
SELECT 'dim_purchase_date', COUNT(*)
FROM analytics.dim_purchase_date

UNION ALL
SELECT 'dim_delivery_date', COUNT(*)
FROM analytics.dim_delivery_date

UNION ALL
SELECT 'dim_review_date', COUNT(*)
FROM analytics.dim_review_date

ORDER BY table_name;
```

All twelve counts should match the validated historical population table above.

These population checks are necessary but are not sufficient to prove data correctness.

## 8. Power BI Semantic Model

The local Power BI report imports the twelve analytical tables.

The validated semantic model uses:

- Twenty active one-to-many relationships
- Single-direction dimension-to-fact filtering
- Three separate date-role dimensions
- A central measure home table
- A disconnected four-row Geo Fact Type display table

Auto date/time is disabled.

The report uses Purchase Date and Order Status as its main dashboard slicers.

DAX reference definitions are available in `powerbi/dax/`.

For the full measure specifications, consult `docs/kpi_dictionary.md`.

## 9. Recreating Dashboard Pages

The six report pages are:

1. Executive Overview
2. Order Fulfillment
3. Financial Reconciliation
4. Customer & Satisfaction
5. Product & Seller Performance
6. Geographic Coverage & Data Quality

The screenshots and `docs/dashboard_guide.md` document the report structure.

The original local PBIX is not included in the public repository. A clone therefore does not directly open the finished report.

Recreating the visual layout requires Power BI Desktop and the approved data model and measures.

## 10. Validation

Run the read-only dashboard-level SQL audit scripts in `sql/`.

The consolidated warehouse release audit is:

`sql/48_powerbi_cross_page_release_validation.sql`

The consolidated Power BI DAX audit is:

`powerbi/dax/16_cross_page_release_checks.dax`

Use two standard cohorts:

### Full History

Purchase Date: Entire available period

Order Status: All

### Q1 2018 Delivered

Purchase Date:
2018-01-01 through 2018-03-31 inclusive

Order Status:
delivered

DAX and SQL outputs must match the expected values recorded in `docs/powerbi_release_qa_7_5.md`.

## 11. Connection Security

Do not commit:

- Local database passwords
- Connection strings containing secrets
- Personal-access tokens
- University account credentials
- Environment-specific authentication files
- Raw data extracts
- Database backup files

Use local configuration and secure credentials for database access.

Connection configuration may need to be updated when the project is reproduced on another computer.

## 12. Reproducibility Scope

### Available Publicly

- Source-processing code
- SQL transformations and quality checks
- DAX definitions and validation queries
- KPI documentation
- Architecture documentation
- Six dashboard screenshots
- Consolidated release QA documentation

### Not Included Publicly

- Raw Olist CSV files
- Local database installation
- Database credentials
- Local PBIX report binary
- University Power BI account or workspace access

### Not Yet Claimed

The repository does not claim to provide a fully containerized or one-command rebuild unless that functionality is independently implemented and tested.

The reproducibility goal is to make the analytical logic, model architecture, metric definitions, and validation process transparent and inspectable.

## 13. Successful Reproduction

A successful reconstructed analytics environment should:

- Match all twelve analytical population baselines
- Preserve the documented table grains
- Reconcile comparable-order financial results
- Reproduce the full-data and Q1 delivery metrics
- Match customer and review populations
- Reproduce seller concentration statistics
- Match geographic exception partitions
- Pass the independent SQL QA queries
- Return the expected DAX measures when configured in Power BI

See `docs/validation.md` for the detailed release checks.
