# Order-to-Cash Intelligence Platform — Source Data Dictionary

**Project:** Olist Brazilian E-Commerce Analytics  
**Phase:** Step 3 — Source discovery and profiling  
**Status:** v1.1 — all nine source files profiled from local terminal outputs shared during the project  
**Source:** Olist Brazilian E-Commerce Public Dataset (historical data, 2016–2018)  
**Dataset URL:** https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

> **Scope and evidence:** All nine table profiles are based on the user's local Python terminal outputs shared during the project, including the Orders output provided on November 10, 2026. These are **source-level profiling checks**, not proof that every business value is correct. `str` and `string` refer to text in pandas; date-like source columns have not yet been converted to datetime. No data cleaning or PostgreSQL load has occurred. An issue register and testing plan are in `docs/data_quality_report.md`.

## Glossary

- **Grain:** What one row of the table represents.
- **Primary key / candidate key:** Column(s) expected or observed to uniquely identify a record.
- **Foreign key:** A column referencing an identifier in another table; relationships are not yet enforced in PostgreSQL.
- **Natural key:** Identifier already supplied by the source system.
- **Composite key:** Multiple columns used together to identify a record.
- **Referential-integrity check:** Test whether a referenced value appears in the parent table.
- **Join fan-out:** A join that multiplies rows because both sides contain repeated matching IDs.
- **Missing:** `isna()` / null values in the source; not necessarily errors.

## Source inventory and grain

| Table (CSV file) | Local rows | Grain | Candidate / expected key | Current observation |
|---|---:|---|---|---|
| Orders (`olist_orders_dataset.csv`) | 99,441 | One order | `order_id` | 0 duplicate/missing IDs; 8 order statuses; timestamp gaps requiring investigation |
| Order Items (`olist_order_items_dataset.csv`) | 112,650 | One purchased item within an order | (`order_id`, `order_item_id`) | 0 duplicate composite keys; 98,666 distinct orders |
| Payments (`olist_order_payments_dataset.csv`) | 103,886 | One payment record within an order | (`order_id`, `payment_sequential`) | 0 duplicate composite keys; 99,440 distinct orders |
| Customers (`olist_customers_dataset.csv`) | 99,441 | One order-associated customer record | `customer_id` | 0 duplicate IDs; 96,096 distinct `customer_unique_id` values |
| Products (`olist_products_dataset.csv`) | 32,951 | One product | `product_id` | 0 duplicate IDs; 73 non-null categories |
| Sellers (`olist_sellers_dataset.csv`) | 3,095 | One seller | `seller_id` | 0 duplicate IDs |
| Reviews (`olist_order_reviews_dataset.csv`) | 99,224 | One review record | (`review_id`, `order_id`) is unique in this extract; assess before making a PK | `review_id` and `order_id` repeat independently |
| Geolocation (`olist_geolocation_dataset.csv`) | 1,000,163 | One geolocation observation | No safe unique ZIP key in raw data | Multiple coordinates per ZIP; 261,831 exact duplicate rows |
| Category Translation (`product_category_name_translation.csv`) | 71 | One Portuguese-to-English category mapping | `product_category_name` | 71 unique Portuguese keys and English labels |

## 1. Orders — `olist_orders_dataset.csv`

**Grain:** One order. **Observed natural key:** `order_id`. **Local rows:** 99,441. **Local profiling output received:** Yes.

| Column | Meaning |
|---|---|
| `order_id` | Order identifier; intended unique key |
| `customer_id` | Links order to the order-associated Customers record |
| `order_status` | Source order state, such as delivered, canceled or shipped |
| `order_purchase_timestamp` | Time order was placed |
| `order_approved_at` | Time order was approved (may be missing) |
| `order_delivered_carrier_date` | Time order was handed to carrier (may be missing) |
| `order_delivered_customer_date` | Recorded final delivery time (may be missing) |
| `order_estimated_delivery_date` | Estimated delivery date |

**Validated findings:** 99,441 distinct `order_id` values, 0 duplicate IDs, 0 missing IDs. Missing timestamp values: `order_approved_at` = 160, `order_delivered_carrier_date` = 1,783, `order_delivered_customer_date` = 2,965; other five columns have 0 missing values. Order-status distribution: delivered = 96,478; shipped = 1,107; canceled = 625; unavailable = 609; invoiced = 314; processing = 301; created = 5; approved = 2. All timestamp columns were read as `str` and require explicit parsing for date calculations.

**Modeling cautions:** Some orders do not have associated item (775), payment (1), or review (768) records. The status of these specific unmatched orders has not yet been examined. Do not equate all orders with completed transactions or assume every missing delivery timestamp is a data error. Calculate delivery performance only after specifying eligible order states and valid delivery dates.

## 2. Order Items — `olist_order_items_dataset.csv`

**Grain:** One ordered item. **Candidate key:** (`order_id`, `order_item_id`). **Local rows:** 112,650.

| Column | Observed pandas type | Meaning |
|---|---|---|
| `order_id` | `str` | References Orders |
| `order_item_id` | `int64` | Item sequence within an order |
| `product_id` | `str` | References Products |
| `seller_id` | `str` | References Sellers |
| `shipping_limit_date` | `str` | Seller shipping deadline; convert to datetime later |
| `price` | `float64` | Item price, BRL |
| `freight_value` | `float64` | Item-level freight charge, BRL |

**Validated findings:** 98,666 distinct order IDs; 9,803 orders have multiple item rows; 21 is the maximum items in one order. There are no nulls, negative prices, negative freight amounts, duplicate composite keys or unmatched Order references. 775 Orders have no matching item records.

## 3. Payments — `olist_order_payments_dataset.csv`

**Grain:** One recorded payment component. **Candidate key:** (`order_id`, `payment_sequential`). **Local rows:** 103,886.

| Column | Observed pandas type | Meaning |
|---|---|---|
| `order_id` | `str` | References Orders |
| `payment_sequential` | `int64` | Payment component sequence within an order |
| `payment_type` | `str` | Recorded method, e.g. credit_card, boleto, voucher, debit_card |
| `payment_installments` | `int64` | Recorded installment count |
| `payment_value` | `float64` | Payment component amount, BRL |

**Validated findings:** 99,440 distinct order IDs; 2,961 orders have multiple payment records; maximum 29 records per order. There are zero duplicate composite keys, nulls, negative payment amounts or unmatched order references. Investigation candidates: 9 zero-value payments, 2 zero-installment records, 3 `not_defined` method records, and 1 Order with no payment record.

**Modeling caution:** Aggregate at `order_id` before comparing payment values to item-plus-freight totals; do not join Payments to item rows and then sum unadjusted payment values.

## 4. Customers — `olist_customers_dataset.csv`

**Grain:** One order-associated customer record. **Candidate key:** `customer_id`. **Local rows:** 99,441.

| Column | Observed pandas type | Meaning |
|---|---|---|
| `customer_id` | `str` | Order-specific customer record identifier |
| `customer_unique_id` | `str` | Identifier used to recognize the same customer across order records |
| `customer_zip_code_prefix` | `string` | First five digits of postal code; retain leading zeros |
| `customer_city` | `str` | Customer city |
| `customer_state` | `str` | Customer state abbreviation |

**Validated findings:** 99,441 distinct `customer_id` values, 96,096 distinct `customer_unique_id` values, 2,997 customers with multiple order-linked records (3.12% of distinct customer identifiers), maximum 17 records for one customer. No nulls, duplicate `customer_id` values, unmatched Orders or unused customer records.

**Modeling caution:** `COUNT(DISTINCT customer_id)` is not the same as `COUNT(DISTINCT customer_unique_id)`. The 3.12% figure is a preliminary repeat-record measure, not a cohort retention KPI.

## 5. Products — `olist_products_dataset.csv`

**Grain:** One product. **Candidate key:** `product_id`. **Local rows:** 32,951.

| Column | Observed pandas type | Meaning |
|---|---|---|
| `product_id` | `str` | Product identifier |
| `product_category_name` | `str` | Portuguese product-category label |
| `product_name_lenght` | `float64` | Length of product name; source misspelling preserved |
| `product_description_lenght` | `float64` | Length of product description; source misspelling preserved |
| `product_photos_qty` | `float64` | Number of product photos |
| `product_weight_g` | `float64` | Product weight in grams |
| `product_length_cm` | `float64` | Product/package length in cm |
| `product_height_cm` | `float64` | Product/package height in cm |
| `product_width_cm` | `float64` | Product/package width in cm |

**Validated findings:** 32,951 distinct IDs; 73 non-null categories; no missing/duplicate product IDs or unmatched Product IDs in Order Items. Missing category, name length, description length and photo count: 610 each (co-occurrence not yet tested). Missing physical attributes: 2 per attribute. Four product records have zero weight; no negative weights or dimensions. Every Products record has at least one Order Item reference.

**Modeling caution:** Number of product records per category is not quantity sold or revenue. Do not invent missing weights or category values.

## 6. Sellers — `olist_sellers_dataset.csv`

**Grain:** One seller. **Candidate key:** `seller_id`. **Local rows:** 3,095.

| Column | Observed pandas type | Meaning |
|---|---|---|
| `seller_id` | `str` | Seller identifier |
| `seller_zip_code_prefix` | `string` | Postal-code prefix; retain leading zeros |
| `seller_city` | `str` | Seller city |
| `seller_state` | `str` | Seller state abbreviation |

**Validated findings:** 3,095 distinct IDs, no nulls/duplicate IDs, 0 invalid five-digit ZIP-format records, 0 invalid two-uppercase-letter state-code formats, 0 unmatched Order Items references, and 0 Sellers without item records. 2,524 sellers appear in multiple distinct orders; the maximum distinct orders for one seller is 1,854. SP contains 1,849 sellers.

**Modeling caution:** Passing ZIP/state format checks does not validate existence or geographic accuracy.

## 7. Reviews — `olist_order_reviews_dataset.csv`

**Grain:** One review record. **Uniqueness observed:** (`review_id`, `order_id`) has zero duplicates, but both IDs individually repeat. **Local rows:** 99,224.

| Column | Observed pandas type | Meaning |
|---|---|---|
| `review_id` | `string` | Review identifier; not unique on its own in this extract |
| `order_id` | `string` | References Orders; not unique on its own |
| `review_score` | `int64` | Rating from 1 to 5 |
| `review_comment_title` | `str` | Optional text title |
| `review_comment_message` | `str` | Optional written feedback |
| `review_creation_date` | `str` | Survey-creation date; not yet parsed to datetime |
| `review_answer_timestamp` | `str` | Customer response timestamp; not yet parsed to datetime |

**Validated findings:** 98,410 distinct review IDs; 98,673 distinct order IDs; 814 repeated review ID occurrences; 551 repeated order ID occurrences; 547 orders with multiple reviews (max 3). Zero exact-row or review/order pair duplicates. Scores all valid (1–5), with mean 4.09 across review *records*. Missing titles: 87,656; missing messages: 58,247. Additionally, 2 non-null titles and 27 non-null messages are blank. No missing/invalid dates, answers before survey creation, or unmatched order references. There are 768 Orders with no review record.

**Modeling caution:** Review-level average and order-level average are different statistics if some orders have several reviews. Document a rule before calculating order-level satisfaction.

## 8. Geolocation — `olist_geolocation_dataset.csv`

**Grain:** One geographic observation; raw ZIP prefixes are not unique. **Local rows:** 1,000,163.

| Column | Observed pandas type | Meaning |
|---|---|---|
| `geolocation_zip_code_prefix` | `string` | Postal-code prefix; repeated across observations |
| `geolocation_lat` | `float64` | Latitude in decimal degrees |
| `geolocation_lng` | `float64` | Longitude in decimal degrees |
| `geolocation_city` | `str` | City label |
| `geolocation_state` | `str` | State abbreviation |

**Validated findings:** 19,015 distinct prefixes; 17,972 prefixes have several observations; maximum 1,146 observations per prefix. Exact duplicate rows: 261,831. No nulls, invalid ZIP formats, invalid uppercase state-code formats, or mathematically invalid latitude/longitude values. 27 distinct state codes. 29 observations fall outside a broad *approximate* Brazil bounding box. Distinct ZIP prefixes missing from geolocation: 157 customer ZIPs and 7 seller ZIPs.

**Modeling caution:** Avoid direct many-to-many ZIP joins. Build and validate one geographic lookup row per prefix; investigate outliers. Missing-prefix counts are *distinct ZIP counts*, not numbers of customer/seller/order records. Approximate straight-line distance is not actual delivery route distance.

## 9. Product Category Translation — `product_category_name_translation.csv`

**Grain:** One translated category. **Candidate key:** `product_category_name`. **Local rows:** 71.

| Column | Observed pandas type | Meaning |
|---|---|---|
| `product_category_name` | `string` | Portuguese category name; connects to Products |
| `product_category_name_english` | `string` | English category label |

**Validated findings:** 71 distinct Portuguese keys, 71 distinct English values, 0 duplicates, 0 nulls, and 0 blank values. All mapped Portuguese categories appear in Products. Of the 73 distinct non-null source categories, two have no translation:

| Untranslated Portuguese category | Products affected |
|---|---:|
| `portateis_cozinha_e_preparadores_de_alimentos` | 10 |
| `pc_gamer` | 3 |
| **Total non-null untranslated category products** | **13** |

Another **610 products have a missing source category name**. These are separate from the 13 products with existing but untranslated labels. Thus **623 product records cannot currently obtain an English label through the source lookup**, or approximately **1.89%** of 32,951 products.

**Modeling caution:** Preserve these products via a LEFT JOIN. For an unmatched non-null category, retain a readable or explicitly mapped Portuguese fallback. For missing categories, use an explicit `Unknown / Unclassified` label. Do not claim a fallback is an official Olist translation.

## Relationships to validate in PostgreSQL

| Parent | Child | Join columns | Expected relationship |
|---|---|---|---|
| Customers | Orders | `customer_id` | One customer record → one order in this extract (validated via coverage; test uniqueness on both sides) |
| Orders | Order Items | `order_id` | One → many (some Orders without items) |
| Orders | Payments | `order_id` | One → many (one Order without payment record) |
| Orders | Reviews | `order_id` | One → potentially many (some Orders without reviews) |
| Products | Order Items | `product_id` | One → many |
| Sellers | Order Items | `seller_id` | One → many |
| Category Translation | Products | `product_category_name` | One category → many products, nullable/unmatched on Products side |
| Cleaned ZIP lookup | Customers | ZIP prefix | One ZIP → many customer records, coverage gaps |
| Cleaned ZIP lookup | Sellers | ZIP prefix | One ZIP → many sellers, coverage gaps |

## Source profiling status and next steps

- [x] All nine source files profiled with shared local terminal output, including Orders.
- [x] Draft `docs/data_quality_report.md` with evidence, affected counts, risk priorities, proposed handling rules and unresolved investigation statuses.
- [ ] Build automated, reproducible profiling / validation outputs rather than relying only on terminal screenshots.
- [ ] Load raw data into PostgreSQL without changing original source files.
- [ ] Design analysis-ready models with explicit grains and reconciliation checks.

**Interpretation note:** Structural checks are not a guarantee of business correctness. Suspected anomalies remain investigation candidates until confirmed.
