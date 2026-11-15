
from pathlib import Path
import pandas as pd

# 1. Locate the source files
project = Path(__file__).resolve().parents[1]
raw = project / "data" / "raw"

products = pd.read_csv(
    raw / "olist_products_dataset.csv"
)

items = pd.read_csv(
    raw / "olist_order_items_dataset.csv",
    usecols=["product_id"]
)

# 2. Dataset structure
print("\n=== 1. DATASET SIZE ===")
print("Rows:", len(products))
print("Columns:", len(products.columns))

print("\n=== 2. COLUMNS AND TYPES ===")
print(products.dtypes.to_string())

print("\n=== 3. FIRST FIVE RECORDS ===")
print(products.head(5).to_string(index=False))

# 3. Key uniqueness
print("\n=== 4. PRODUCT ID CHECK ===")
print("Unique products:", products["product_id"].nunique())
print("Duplicate product IDs:", products["product_id"].duplicated().sum())
print("Missing product IDs:", products["product_id"].isna().sum())

# 4. Missing values
print("\n=== 5. MISSING VALUES ===")
print(products.isna().sum().to_string())

# 5. Product categories
print("\n=== 6. CATEGORY CHECK ===")
print(
    "Distinct non-null categories:",
    products["product_category_name"].nunique()
)

print("\nTop 10 categories by product count:")
print(
    products["product_category_name"]
    .value_counts()
    .head(10)
    .to_string()
)

# 6. Check physical attributes
print("\n=== 7. PHYSICAL ATTRIBUTE CHECKS ===")

physical_columns = [
    "product_weight_g",
    "product_length_cm",
    "product_height_cm",
    "product_width_cm"
]

for column in physical_columns:
    values = pd.to_numeric(products[column], errors="coerce")

    print(f"\n{column}")
    print("Missing or invalid:", values.isna().sum())
    print("Zero values:", (values == 0).sum())
    print("Negative values:", (values < 0).sum())

# 7. Referential integrity
print("\n=== 8. RELATIONSHIP CHECK ===")

unknown_products = ~items["product_id"].isin(
    products["product_id"]
)

unused_products = ~products["product_id"].isin(
    items["product_id"]
)

print(
    "Order item rows without matching products:",
    unknown_products.sum()
)

print(
    "Products without order item records:",
    unused_products.sum()
)

print("\n=== PRODUCT PROFILING COMPLETE ===")
