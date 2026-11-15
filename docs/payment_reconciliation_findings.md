# Payment Exception Reconciliation — Targeted Audit

**Project:** Order-to-Cash Intelligence Platform  
**Dataset:** Olist Brazilian E-Commerce (Historical, 2016–2018)  
**Audit scope:** 11 selected orders  
**Tools:** Python, pandas  
**Status:** Targeted investigation completed; full-dataset reconciliation pending

## 1. Objective

Investigate anomalous payment records and validate financial consistency by comparing recorded payment totals against order-item prices plus freight.

The analysis focuses on zero-value payments, zero-installment records, undefined payment methods, and orders without payment records.

## 2. Methodology

- Identified payment records meeting the defined exception criteria.
- Included orders without matching payment records.
- Aggregated item prices and freight to one row per order.
- Separately aggregated payment values to one row per order.
- Joined the aggregated tables using `order_id`, preventing transaction duplication from one-to-many joins.
- Compared recorded payments against item-plus-freight totals, rounded to two decimal places.
- Preserved missing payment values rather than substituting zero.

## 3. Verified Results

| Metric | Result |
|---|---:|
| Orders investigated | 11 |
| Orders with both item and payment totals | 7 |
| Comparable orders reconciling at cent precision | 7 |
| Total recorded payments across comparable orders | R$1,085.53 |
| Total item-plus-freight value across comparable orders | R$1,085.53 |
| Canceled orders without item records | 3 |
| Delivered orders without payment records | 1 |

### Exception Investigation

**Zero-value vouchers**

Six zero-value voucher records were found across five orders. All five orders contained positive payment records, and their aggregate payments matched item-plus-freight totals.

**Zero-installment credit-card payments**

Two delivered orders contained zero-installment values with positive recorded payments. Both orders reconciled financially. The installment values remain metadata-quality exceptions.

**Undefined payment methods**

Three canceled orders contained zero-value payments with undefined payment methods and no item records. These records are consistent with possible cancellation placeholders; the exact source-system reason is unverified.

**Delivered order missing payment records**

Order `bfbd0f9bdef84302105ad712db648a6c` was marked delivered and contained three item records totaling R$143.46 including freight, but had no matching payment records.

This is a payment-data coverage exception. It does not establish unpaid revenue or financial loss.

## 4. Proposed Data-Quality Treatment Rules

| Rule ID | Condition | Treatment |
|---|---|---|
| PAY-001 | Zero-value voucher | Preserve original record; flag for traceability; evaluate reconciliation at order level |
| PAY-002 | Zero installments | Preserve original value; flag as installment metadata exception |
| PAY-003 | Undefined payment method on canceled order | Preserve record; retain canceled status; investigate source-system semantics |
| PAY-004 | Delivered order without payment record | Flag as missing-payment coverage; preserve null payment values |
| PAY-005 | No item records | Do not perform item-to-payment comparison; investigate order status |
| PAY-006 | Comparable payment and item totals differ | Record discrepancy and investigate before modifying metrics |

Rules are provisional analytical policies, not confirmed accounting procedures.

## 5. Limitations

- This audit covers only 11 selected orders, not the complete dataset.
- Matching recorded payments to item-plus-freight totals does not establish recognized revenue or accounting settlement.
- Canceled orders without items cannot be evaluated through the current item-based reconciliation formula.
- Missing payments must not be interpreted as zero payments or financial losses.
- Currency comparisons in this exploratory script use rounding to two decimal places; production-quality reconciliation should use decimal or integer-cent arithmetic.
- The source data does not independently establish why anomalous payment records were created.

## 6. Next Steps

1. Perform payment-to-item reconciliation across the complete Orders dataset.
2. Classify results by order status and payment-data availability.
3. Investigate mismatches and document their magnitude and frequency.
4. Build reproducible financial reconciliation tests.
5. Integrate validated measures and exception indicators into PostgreSQL and Power BI.

**Conclusion:** Seven of the 11 investigated orders could be financially compared, and all seven reconciled at two-decimal precision. Three canceled orders lacked item records, while one delivered order lacked payment records and remains an unresolved data-coverage exception.