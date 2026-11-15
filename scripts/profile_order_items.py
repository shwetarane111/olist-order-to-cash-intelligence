
from pathlib import Path
import pandas as pd

# STEP 1: Locate our source files
project = Path(__file__).resolve().parents[1]
raw = project / "data" / "raw"

items = pd.read_csv(raw / "olist_order_items_dataset.csv")
orders = pd.read_csv(
    raw / "olist_orders_dataset.csv",
    usecols=["order_id"]
)

# STEP 2: Understand the table
print("\n=== 1. DATASET SIZE ===")
print("Rows:", len(items))
print("Columns:", len(items.columns))

print("\n=== 2. COLUMNS AND DATA TYPES ===")
print(items.dtypes.to_string())

print("\n=== 3. FIRST FIVE ROWS ===")
print(items.head(5).to_string(index=False))

# STEP 3: Examine identifiers
print("\n=== 4. KEY UNIQUENESS ===")
print("Unique orders:", items["order_id"].nunique())

print(
    "Repeated order_id occurrences:",
    items["order_id"].duplicated().sum()
)

print(
    "Duplicate composite keys:",
    items.duplicated(
        subset=["order_id", "order_item_id"]
    ).sum()
)

# STEP 4: Find orders containing multiple items
items_per_order = items.groupby("order_id").size()

print("\n=== 5. ORDER ITEM DISTRIBUTION ===")
print("Orders with multiple items:", (items_per_order > 1).sum())
print("Maximum items in one order:", items_per_order.max())

# STEP 5: Check missing values
print("\n=== 6. MISSING VALUES ===")
print(items.isna().sum().to_string())

# STEP 6: Check financial values
price = pd.to_numeric(items["price"], errors="coerce")
freight = pd.to_numeric(items["freight_value"], errors="coerce")

print("\n=== 7. FINANCIAL DATA CHECKS ===")
print("Invalid or missing prices:", price.isna().sum())
print("Negative prices:", (price < 0).sum())
print("Invalid or missing freight:", freight.isna().sum())
print("Negative freight:", (freight < 0).sum())

# STEP 7: Check relationships with Orders
print("\n=== 8. RELATIONSHIP CHECK ===")

unknown_orders = ~items["order_id"].isin(orders["order_id"])
orders_without_items = ~orders["order_id"].isin(items["order_id"])

print("Item rows without a matching order:", unknown_orders.sum())
print("Orders without item records:", orders_without_items.sum())

print("\n=== PROFILING COMPLETE ===")
