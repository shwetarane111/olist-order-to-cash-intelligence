
# Dataset Source, Attribution & Usage

## Original Dataset

**Title:** Brazilian E-Commerce Public Dataset by Olist

**Publisher:** Olist

**Source:** https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

**License:** Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)

**License reference:** https://creativecommons.org/licenses/by-nc-sa/4.0/

## Dataset Description

The Olist dataset contains historical Brazilian marketplace data from 2016–2018.

Its source tables represent orders, customers, order items, payments, reviews, products, sellers, geographic reference information, and product-category translations.

The dataset was released publicly by Olist for analysis and learning.

It is historical data, not a current Olist operational feed.

## Source Files

The project uses nine source CSV files:

| File | Subject |
|---|---|
| `olist_orders_dataset.csv` | Order status and timestamps |
| `olist_customers_dataset.csv` | Customer identities and geographic attributes |
| `olist_order_items_dataset.csv` | Order items, products, sellers, price and freight |
| `olist_order_payments_dataset.csv` | Payment entries, methods and installments |
| `olist_order_reviews_dataset.csv` | Review records, scores, comments and dates |
| `olist_products_dataset.csv` | Product reference attributes |
| `olist_sellers_dataset.csv` | Seller reference attributes |
| `olist_geolocation_dataset.csv` | ZIP-prefix geographic references |
| `product_category_name_translation.csv` | Category translations |

## Obtaining the Data

Download the source dataset from:

https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

After downloading, extract the source CSV files into the local `data/raw/` folder.

The public GitHub repository does not redistribute the original CSV files.

## Attribution

The data used in the project originates from:

Olist — Brazilian E-Commerce Public Dataset, available on Kaggle.

Dataset license: CC BY-NC-SA 4.0.

This project is an independent educational and portfolio analysis.

It is not affiliated with, sponsored by, or endorsed by Olist.

## Licensing Boundaries

The Olist dataset remains subject to the terms specified by its original publisher.

This repository does not claim ownership of the original dataset.

Source data, adapted datasets, and derived materials must be evaluated according to the applicable original license.

Any future redistribution of dataset-derived files should be assessed against the Attribution, NonCommercial and ShareAlike conditions.

No permission is implied for uses prohibited by the dataset license.

## Data Handling

Original CSV files are stored locally and excluded from Git.

The published repository contains:

- Original project code and SQL logic
- DAX definitions
- Architecture and methodology documentation
- KPI definitions
- Data-quality and release-validation descriptions
- Screenshots of aggregate historical dashboards

Public files are reviewed to avoid exposing local credentials and account-specific configuration.

The locally maintained PBIX binary is excluded by default because it may contain imported records and connection metadata.

## Limitations

- Publicly released historical data, not live data
- Pseudonymous customer identifiers
- Source-recorded financial amounts, not audited settlement records
- Multiple transaction and review grains
- ZIP-prefix-based geographic reference information
- Data quality and coverage vary by business entity

The project should not be used to infer current Olist business performance.
