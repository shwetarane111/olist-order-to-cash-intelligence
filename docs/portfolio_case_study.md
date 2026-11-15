
# Portfolio Case Study
## Order-to-Cash Intelligence Platform

### End-to-End E-Commerce Analytics Engineering

**Technologies:** PostgreSQL, Python, SQL, Power BI, DAX, Dimensional Modeling, Data Quality

**Dataset:** Historical Brazilian E-Commerce Public Dataset by Olist

---

## 1. Project Summary

Built an end-to-end analytics platform that transforms historical Brazilian marketplace transaction records into a validated PostgreSQL analytical warehouse and a six-page Power BI reporting solution.

The platform connects order fulfillment, recorded financial transactions, customer satisfaction, product and seller activity, and geographic quality through a documented dimensional model.

The project emphasizes metric traceability, record-grain correctness, independent reconciliation, and clear business interpretation.

### Project Scale

- 99,441 historical orders
- 112,650 order-item entries
- 103,886 payment entries
- 99,224 review records
- 12 imported analytical tables
- 20 active Power BI relationships
- 55 documented business KPIs
- 6 Power BI dashboard pages
- 36 headline KPI cards
- 24 analytical charts

---

## 2. Business Problem

E-commerce marketplace reporting requires data from multiple operational sources.

Orders, items, payments, and reviews do not share the same natural grain.

For example:

- One order can contain multiple items.
- One order can contain multiple payment entries.
- An order may have multiple review records.
- Customer identities must be distinguished from individual order records.
- Financial coverage gaps must be distinguished from actual mismatches.
- Delivery and review timestamps represent different business events.

A direct join across transaction tables can multiply records and distort financial, customer, and operational metrics.

The project addresses these issues using a layered warehouse and a grain-aware semantic model.

---

## 3. Solution Approach

### Source Processing

Used the historical Olist CSV dataset as the source.

Implemented source profiling and preparation through Python and PostgreSQL.

### Warehouse Architecture

Organized PostgreSQL into:

- raw
- staging
- analytics

The analytics layer contains eight dimensions and four fact tables.

### Analytical Model

Modeled separate order, item, payment, and review facts.

Created twenty active dimension-to-fact Power BI relationships using single-direction filtering.

Retained distinct purchase, delivery, and review date roles.

### Business Metrics

Documented 55 KPI definitions spanning:

- Order activity
- Delivery performance
- Financial reconciliation
- Customer ordering behavior
- Review satisfaction
- Product and seller contribution
- Geographic reference coverage
- Data-quality exceptions

### Dashboard Design

Built six consistent Power BI pages using common purchase-date and order-status controls.

Each page includes six KPI cards and four analytical charts.

---

## 4. Important Engineering Decisions

### Preserve Transaction Grain

Maintained separate order, item, payment, and review facts.

This prevents incorrect assumptions that a payment or review record represents exactly one marketplace order.

### Avoid Ambiguous Relationships

Used dimension-to-fact relationships rather than fact-to-fact joins or bidirectional model filtering.

### Keep Financial Definitions Explicit

Compared item-and-freight totals with recorded payment amounts only when sufficient records existed.

Classified matched, mismatched, and incomplete orders separately.

### Recalculate Cohort Metrics Dynamically

Computed repeat customer and repeat seller participation within the active purchase-date and order-status filters.

### Preserve Source Data Quality Exceptions

Retained missing geographic references and flagged coordinates rather than excluding them from headline denominators.

### Validate Independently

Used PostgreSQL queries to verify Power BI DAX measures instead of relying exclusively on dashboard outputs.

---

## 5. Selected Results

### Fulfillment

Among 96,470 delivery-evaluable orders, 89,936 were on time and 6,534 were late.

Historical on-time delivery rate:
**93.23%**.

Average purchase-to-delivery duration:
**12.56 days**.

### Financial Reconciliation

Comparable orders:
**98,665**.

Matched:
**98,089**.

Mismatched:
**576**.

Financial match rate:
**99.42%**.

Financial coverage gaps:
**776 orders**.

Net comparable payment difference:
**R$2,870.39**.

Absolute financial discrepancy:
**R$3,271.95**.

These results describe recorded data consistency, not bank settlement or accounting revenue.

### Customer and Reviews

Distinct customer identities with orders:
**96,096**.

Repeat-order customer share:
**3.12%**.

Average review score:
**4.09 / 5**.

Review coverage:
**99.23%**.

### Product and Seller Activity

Recorded item-price value:
**R$13,591,643.70**.

Active products:
**32,951**.

Active sellers:
**3,095**.

Multi-order seller share:
**81.55%**.

Top 10 seller item-price concentration:
**13.15%**.

These are contribution and participation measures, not profit metrics.

### Geographic Coverage

Map-ready orders:
**99,162**.

Map-ready order share:
**99.72%**.

Orders without geographic references:
**278**.

Orders with flagged representative coordinates:
**1**.

All populations retain their geographic quality exceptions.

---

## 6. Validation Strategy

Validated both the complete historical dataset and a selected Q1 2018 delivered-order cohort.

The QA workflow included:

- Warehouse row-count checks
- Grain and population checks
- Independent financial reconciliation
- Delivery population partitioning
- Review-record reconciliation
- Geographic coverage partitioning
- Power BI DAX Query View checks
- PostgreSQL release-audit queries
- Cross-page slicer and interaction tests
- Final six-page visual QA

The final consolidated DAX and SQL release checks passed.

See `validation.md` for detailed evidence.

---

## 7. What the Project Demonstrates

### Data Engineering

- Layered analytical warehouse design
- Source profiling and preparation
- SQL transformations
- Data-quality verification
- Reproducible analytical definitions

### Analytics Engineering

- Grain-aware fact design
- Dimensional relationships
- Reusable KPI specifications
- Denominator and filtering discipline
- Independent metric reconciliation

### Business Intelligence

- Six interactive dashboards
- DAX measure development
- Trend and distribution analysis
- Financial exception reporting
- Fulfillment and seller analytics
- Stakeholder-oriented metric interpretation

---

## 8. Limitations

This is a historical analytical project, not a live marketplace system.

Recorded payment values do not prove bank settlement or revenue recognition.

Recorded item-price contribution does not establish profitability.

Customer identities are pseudonymous source identifiers.

Geographic information is based on ZIP-prefix reference data, not exact addresses.

Business performance observations are descriptive and do not establish causal explanations.

The public repository excludes the raw dataset and PBIX binary.

---

## 9. Potential Future Enhancements

Possible extensions include:

- Automated warehouse build orchestration
- Containerized local reproducibility
- Automated SQL unit and regression tests
- Data lineage documentation
- Incremental ingestion patterns
- Deployment-oriented Power BI project artifacts
- Additional documented and tested cohort comparisons

These are proposed enhancements, not features claimed as already implemented.

---

## 10. Portfolio Artifacts

Main repository:
`README.md`

Architecture:
`architecture.md`

KPI definitions:
`kpi_dictionary.md`

Dashboard guide:
`dashboard_guide.md`

Validation:
`validation.md`

Release QA:
`powerbi_release_qa_7_5.md`

SQL:
`../sql/`

DAX:
`../powerbi/dax/`

Screenshots:
`../assets/screenshots/`

---

## Conclusion

The project demonstrates how historical marketplace records can be transformed into a structured, validated analytical environment that supports operational, financial, customer, seller, and geographic reporting.

The primary outcome is an auditable analytics platform with explicit grain, metric definitions, and cross-system validation—not an unsupported claim of business savings or production impact.
