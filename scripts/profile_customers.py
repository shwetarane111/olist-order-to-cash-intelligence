
from pathlib import Path
import pandas as pd

# 1. Locate our data files
project = Path(__file__).resolve().parents[1]
raw = project / "data" / "raw"

# Keep postal codes as strings to preserve leading zeros
customers = pd.read_csv(
    raw / "olist_customers_dataset.csv",
    dtype={"customer_zip_code_prefix": "string"}
)

orders = pd.read_csv(
    raw / "olist_orders_dataset.csv",
    usecols=["order_id", "customer_id"]
)

# 2. Dataset size
print("\n=== 1. DATASET SIZE ===")
print("Rows:", len(customers))
print("Columns:", len(customers.columns))

# 3. Inspect columns and sample records
print("\n=== 2. COLUMNS AND TYPES ===")
print(customers.dtypes.to_string())

print("\n=== 3. FIRST FIVE ROWS ===")
print(customers.head(5).to_string(index=False))

# 4. Identifier validation
print("\n=== 4. CUSTOMER IDENTIFIERS ===")
print(
    "Unique customer_id values:",
    customers["customer_id"].nunique()
)
print(
    "Unique customer_unique_id values:",
    customers["customer_unique_id"].nunique()
)
print(
    "Duplicate customer_id values:",
    customers["customer_id"].duplicated().sum()
)

# 5. Repeat customer analysis
purchases_per_customer = (
    customers.groupby("customer_unique_id")
    ["customer_id"].nunique()
)

repeat_customers = (purchases_per_customer > 1).sum()
total_customers = len(purchases_per_customer)

print("\n=== 5. REPEAT CUSTOMERS ===")
print("Distinct customers:", total_customers)
print("Customers with multiple order records:", repeat_customers)
print(
    "Repeat customer percentage:",
    round(repeat_customers / total_customers * 100, 2)
)
print(
    "Maximum order records for one customer:",
    purchases_per_customer.max()
)

# 6. Missing values
print("\n=== 6. MISSING VALUES ===")
print(customers.isna().sum().to_string())

# 7. Check Orders-to-Customers relationship
print("\n=== 7. RELATIONSHIP CHECK ===")

unknown_customer = ~orders["customer_id"].isin(
    customers["customer_id"]
)

unused_customer = ~customers["customer_id"].isin(
    orders["customer_id"]
)

print(
    "Orders without matching customer records:",
    unknown_customer.sum()
)

print(
    "Customer records without matching orders:",
    unused_customer.sum()
)

# 8. Geographic distribution
print("\n=== 8. TOP TEN CUSTOMER STATES ===")
print(
    customers["customer_state"]
    .value_counts()
    .head(10)
    .to_string()
)

print("\n=== CUSTOMER PROFILING COMPLETE ===")
