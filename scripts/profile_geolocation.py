
from pathlib import Path
import pandas as pd

# 1. Locate the datasets
project = Path(__file__).resolve().parents[1]
raw = project / "data" / "raw"

geo = pd.read_csv(
    raw / "olist_geolocation_dataset.csv",
    dtype={"geolocation_zip_code_prefix": "string"}
)

customers = pd.read_csv(
    raw / "olist_customers_dataset.csv",
    usecols=["customer_zip_code_prefix"],
    dtype={"customer_zip_code_prefix": "string"}
)

sellers = pd.read_csv(
    raw / "olist_sellers_dataset.csv",
    usecols=["seller_zip_code_prefix"],
    dtype={"seller_zip_code_prefix": "string"}
)

# 2. Dataset structure
print("\n=== 1. DATASET SIZE ===")
print("Rows:", len(geo))
print("Columns:", len(geo.columns))

print("\n=== 2. COLUMNS AND TYPES ===")
print(geo.dtypes.to_string())

print("\n=== 3. FIRST FIVE RECORDS ===")
print(geo.head(5).to_string(index=False))

# 3. ZIP prefix uniqueness
print("\n=== 4. ZIP PREFIX CHECK ===")

zip_col = geo["geolocation_zip_code_prefix"]

zip_counts = zip_col.value_counts()

print("Unique ZIP prefixes:", zip_col.nunique())
print("ZIP prefixes with multiple records:", (zip_counts > 1).sum())
print("Maximum records for one ZIP:", zip_counts.max())

# 4. Exact duplicates
print("\n=== 5. DUPLICATE RECORDS ===")
print("Exact duplicate rows:", geo.duplicated().sum())

# 5. Missing values
print("\n=== 6. MISSING VALUES ===")
print(geo.isna().sum().to_string())

# 6. Geographic format checks
print("\n=== 7. FORMAT CHECKS ===")

valid_zip = zip_col.str.fullmatch(r"\d{5}", na=False)

valid_state = geo["geolocation_state"].str.fullmatch(
    r"[A-Z]{2}", na=False
)

print("Invalid ZIP formats:", (~valid_zip).sum())
print("Invalid state formats:", (~valid_state).sum())
print(
    "Unique state codes:",
    geo["geolocation_state"].nunique()
)

# 7. Coordinate checks
print("\n=== 8. COORDINATE CHECKS ===")

lat = pd.to_numeric(
    geo["geolocation_lat"], errors="coerce"
)

lng = pd.to_numeric(
    geo["geolocation_lng"], errors="coerce"
)

invalid_lat = lat.isna() | ~lat.between(-90, 90)
invalid_lng = lng.isna() | ~lng.between(-180, 180)

print("Invalid latitudes:", invalid_lat.sum())
print("Invalid longitudes:", invalid_lng.sum())

print("Latitude range:", lat.min(), "to", lat.max())
print("Longitude range:", lng.min(), "to", lng.max())

# Broad approximate Brazil bounding box.
# This is only a screening heuristic, NOT a country-border test.
outside_box = ~(
    lat.between(-35, 6) &
    lng.between(-75, -32)
)

print(
    "Coordinates outside approximate Brazil bounding box:",
    outside_box.sum()
)

# 8. ZIP prefix coverage
print("\n=== 9. ZIP COVERAGE CHECK ===")

geo_zips = set(zip_col.dropna())

customer_zips = set(
    customers["customer_zip_code_prefix"].dropna()
)

seller_zips = set(
    sellers["seller_zip_code_prefix"].dropna()
)

print(
    "Distinct customer ZIP prefixes:",
    len(customer_zips)
)

print(
    "Customer ZIP prefixes absent from geolocation:",
    len(customer_zips - geo_zips)
)

print(
    "Distinct seller ZIP prefixes:",
    len(seller_zips)
)

print(
    "Seller ZIP prefixes absent from geolocation:",
    len(seller_zips - geo_zips)
)

print("\n=== GEOLOCATION PROFILING COMPLETE ===")
