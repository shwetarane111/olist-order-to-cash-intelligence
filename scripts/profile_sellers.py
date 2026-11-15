
from pathlib import Path
import pandas as pd

# 1. Locate our source files
project = Path(__file__).resolve().parents[1]
raw = project / "data" / "raw"

# Postal codes must be strings
sellers = pd.read_csv(
    raw / "olist_sellers_dataset.csv",
    dtype={"seller_zip_code_prefix": "string"}
)

items = pd.read_csv(
    raw / "olist_order_items_dataset.csv",
    usecols=["order_id", "seller_id"]
)

# 2. Dataset size
print("\n=== 1. DATASET SIZE ===")
print("Rows:", len(sellers))
print("Columns:", len(sellers.columns))

# 3. Inspect structure
print("\n=== 2. COLUMNS AND TYPES ===")
print(sellers.dtypes.to_string())

print("\n=== 3. FIRST FIVE RECORDS ===")
print(sellers.head(5).to_string(index=False))

# 4. Primary key validation
print("\n=== 4. SELLER ID CHECK ===")
print("Unique sellers:", sellers["seller_id"].nunique())
print("Duplicate seller IDs:", sellers["seller_id"].duplicated().sum())
print("Missing seller IDs:", sellers["seller_id"].isna().sum())

# 5. Missing values
print("\n=== 5. MISSING VALUES ===")
print(sellers.isna().sum().to_string())

# 6. Geographic distribution
print("\n=== 6. TOP TEN SELLER STATES ===")
print(
    sellers["seller_state"]
    .value_counts()
    .head(10)
    .to_string()
)

print("\n=== 7. GEOGRAPHIC DATA QUALITY ===")

valid_zip = sellers["seller_zip_code_prefix"].str.fullmatch(
    r"\d{5}", na=False
)

valid_state = sellers["seller_state"].str.fullmatch(
    r"[A-Z]{2}", na=False
)

print("Invalid ZIP prefixes:", (~valid_zip).sum())
print("Invalid state code format:", (~valid_state).sum())

# 8. Referential integrity
print("\n=== 8. RELATIONSHIP CHECK ===")

unknown_sellers = ~items["seller_id"].isin(
    sellers["seller_id"]
)

unused_sellers = ~sellers["seller_id"].isin(
    items["seller_id"]
)

print(
    "Item rows without matching sellers:",
    unknown_sellers.sum()
)

print(
    "Sellers without order item records:",
    unused_sellers.sum()
)

# 9. Seller activity
print("\n=== 9. SELLER ACTIVITY ===")

orders_per_seller = (
    items.groupby("seller_id")["order_id"].nunique()
)

print(
    "Sellers with multiple distinct orders:",
    (orders_per_seller > 1).sum()
)

print(
    "Maximum distinct orders for one seller:",
    orders_per_seller.max()
)

print("\n=== SELLER PROFILING COMPLETE ===")
