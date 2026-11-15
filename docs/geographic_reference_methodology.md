# ZIP-Level Geographic Reference Methodology

**Project:** Order-to-Cash Intelligence Platform  
**Source:** Olist Geolocation Dataset  
**Database model:** `staging.ref_zip_geolocation`  
**Target grain:** One record per ZIP-code prefix

## Purpose

Create a reproducible ZIP-level geographic reference for joining Customer and Seller records without multiplying rows.

## Source Characteristics

- 1,000,163 geolocation source records.
- 19,015 distinct ZIP prefixes.
- Multiple coordinates and duplicate source records occur within ZIP prefixes.
- Source records are preserved in `raw.geolocation` and `staging.stg_geolocation`.

## Coordinate Selection

1. Retain source rows passing required ZIP, city/state format, and global coordinate-validity checks.
2. Identify the most frequent city/state combination within each ZIP prefix.
3. If multiple combinations share the highest frequency, break ties using state and city alphabetical order.
4. Calculate median latitude and longitude among records with the selected city/state combination.
5. Select an actual observed coordinate closest to those medians using an approximate distance expression with longitude adjustment.
6. Prefer coordinates within the broad screening rectangle of latitude −34° to +6° and longitude −74° to −28°, when available within the selected city/state group.
7. Break coordinate ties by latitude and longitude.
8. Return exactly one representative record per ZIP prefix.

## Geographic Screening

The broad Brazil bounding rectangle is a heuristic for detecting candidate outliers, not an authoritative country boundary.

A coordinate outside the rectangle is not automatically considered incorrect.

The selected coordinate is a source-observed representative point, not an authoritative ZIP centroid or precise customer/seller location.

## Quality and Lineage

The reference retains source-row counts, selected-label counts, the number of distinct city/state combinations, and flags for location-label conflicts and points outside the screening rectangle.

A unique index enforces one row per ZIP prefix.

The materialized view is refreshed deliberately when its underlying staging data changes.

## Analytical Use

The reference may be LEFT JOINed to Customers and Sellers using their five-character ZIP prefixes.

Missing geographic matches remain NULL. Customer and Seller records must not be dropped.

## Limitations

- Frequent labels are not guaranteed to be geographically authoritative.
- Exact duplicate source rows can influence the preferred-label frequency.
- The distance calculation is an approximation, not geodesic distance.
- ZIP-prefix-level coordinates are approximations and cannot identify individual addresses.
- Multiple source points may represent a broad geographic area.
- Unmatched ZIP prefixes and geography conflicts must remain visible in quality reporting.
- Representative points should not be interpreted as verified locations for individual transactions.

## Validation Requirements

- Exactly 19,015 reference records.
- Exactly 19,015 unique ZIP prefixes.
- Source-row metadata sums to 1,000,163.
- No missing representative coordinates.
- Customer and Seller LEFT JOIN row counts remain unchanged.
- Unmatched distinct ZIP-prefix coverage is documented separately.

**Status:** Method defined. Final observed diagnostic counts and audit sign-off are recorded after PostgreSQL validation.

### Observed Validation Results

- Eligible source records: 1,000,163.
- Distinct ZIP prefixes: 19,015.
- Source coordinates outside the broad Brazil screening rectangle: 31.
- ZIP prefixes with conflicting city/state combinations: 8,558.
- Selected representative coordinates outside the screening rectangle: 4.
- Missing representative coordinates: 0.
- ZIP prefixes with multiple source records: 17,972.
- Maximum source records for one ZIP prefix: 1,146.
- Customer and Seller LEFT JOIN row counts: Preserved.
- Unmatched distinct customer ZIP prefixes: 157.
- Unmatched distinct seller ZIP prefixes: 7.

**Disposition:** The geographic reference is suitable for downstream ZIP-level joins. Conflicting location labels and selected coordinate outliers remain documented quality considerations. Coordinates outside the screening rectangle require further validation before use in published maps.

--------------------------------------------------------------------------------------------

## Seller Dimension Geographic Validation

Source model: `staging.stg_sellers`
Analytical model: `analytics.dim_seller`

- Total sellers: 3,095
- Sellers without a geographic reference: 7
- Unmatched distinct seller ZIP prefixes: 7
- Sellers associated with conflicting ZIP reference labels: 1,566
- Seller/reference city-state disagreements: 147
- Sellers associated with flagged coordinate outliers: 0
- Sellers with map-ready representative coordinates: 3,088
- Map-ready seller coverage: approximately 99.77%
- Inconsistent map fields: 0

All seller records were retained. Geographic label
disagreements are review candidates, not confirmed
source errors. Map coordinates represent ZIP-level
approximations, not precise seller locations.

--------------------------------------------------------------------------------------------

## Customer Geography Dimension Validation

Model: analytics.dim_customer_geography

- Distinct customer location combinations: 15,034
- Unique location keys: 15,034
- Hash-key collisions: 0
- Missing customer city records: 0
- Customer records without geographic reference: 278
- Unmatched distinct customer ZIP prefixes: 157
- Customer records linked to flagged coordinates: 1
- Customer records with conflicting reference labels: 46,889
- Customer/reference label disagreements: 192
- Location combinations with conflicting labels: 7,428
- Location combinations with label disagreements: 92
- Locations with flagged coordinates: 1
- Map-ready location combinations: 14,876
- Orders with map-ready customer locations: 99,162
- Map-ready order coverage: 99.72%

All 99,441 order-associated customer records remain
represented. Coordinates are approximate ZIP-level
representative locations, not precise customer addresses.

--------------------------------------------------------------------------------------------
## Final ANALYTICS Fact-Level Geographic Coverage

| Fact | Records | Unmatched ZIP reference | Flagged coordinates | Map-ready | Coverage |
|---|---:|---:|---:|---:|---:|
| Orders | 99,441 | 278 | 1 | 99,162 | 99.72% |
| Order Items | 112,650 | 302 | 1 | 112,347 | 99.73% |
| Payments | 103,886 | 287 | 1 | 103,598 | 99.72% |
| Reviews | 99,224 | 279 | 1 | 98,944 | 99.72% |

All facts passed geographic integrity validation.
No fact records were removed because of unmatched
ZIP references or flagged representative coordinates.

These counts are measured at different fact grains
and must not be summed as unique customers.