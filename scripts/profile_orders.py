
from pathlib import Path
import pandas as pd

# 1. Locate our CSV file
project_folder = Path(__file__).resolve().parents[1]
file_path = project_folder / "data" / "raw" / "olist_orders_dataset.csv"

# 2. Read the dataset
orders = pd.read_csv(file_path)

# 3. Check the dataset size
print("\n=== DATASET SIZE ===")
print("Rows:", orders.shape[0])
print("Columns:", orders.shape[1])

# 4. Display column names and data types
print("\n=== COLUMNS AND DATA TYPES ===")
print(orders.dtypes.to_string())

# 5. Preview five records
print("\n=== FIRST FIVE RECORDS ===")
print(
    orders[
        ["order_id", "order_status",
         "order_purchase_timestamp",
         "order_delivered_customer_date"]
    ].head(5).to_string(index=False)
)

# 6. Check primary-key uniqueness
print("\n=== ORDER ID CHECK ===")
print("Unique order IDs:", orders["order_id"].nunique())
print("Duplicate order IDs:", orders["order_id"].duplicated().sum())
print("Missing order IDs:", orders["order_id"].isna().sum())

# 7. Identify missing values
print("\n=== MISSING VALUES PER COLUMN ===")
print(orders.isna().sum().to_string())

# 8. Count orders by status
print("\n=== ORDER STATUS COUNTS ===")
print(orders["order_status"].value_counts(dropna=False).to_string())
