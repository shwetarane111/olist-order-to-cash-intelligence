
from pathlib import Path
import pandas as pd

# 1. Locate the datasets
project = Path(__file__).resolve().parents[1]
raw = project / "data" / "raw"

payments = pd.read_csv(
    raw / "olist_order_payments_dataset.csv"
)

orders = pd.read_csv(
    raw / "olist_orders_dataset.csv",
    usecols=["order_id"]
)

# 2. Dataset structure
print("\n=== 1. DATASET SIZE ===")
print("Rows:", len(payments))
print("Columns:", len(payments.columns))

print("\n=== 2. COLUMNS AND TYPES ===")
print(payments.dtypes.to_string())

print("\n=== 3. FIRST FIVE ROWS ===")
print(payments.head().to_string(index=False))

# 3. Uniqueness checks
print("\n=== 4. KEY UNIQUENESS ===")
print(
    "Unique orders:",
    payments["order_id"].nunique()
)

print(
    "Duplicate composite keys:",
    payments.duplicated(
        subset=["order_id", "payment_sequential"]
    ).sum()
)

# 4. Multiple payment records
payments_per_order = payments.groupby("order_id").size()

print("\n=== 5. MULTIPLE PAYMENTS ===")
print(
    "Orders with multiple payment records:",
    (payments_per_order > 1).sum()
)
print(
    "Maximum payment records per order:",
    payments_per_order.max()
)

# 5. Missing values
print("\n=== 6. MISSING VALUES ===")
print(payments.isna().sum().to_string())

# 6. Payment methods
print("\n=== 7. PAYMENT TYPES ===")
print(
    payments["payment_type"]
    .value_counts(dropna=False)
    .to_string()
)

# 7. Financial validity
amounts = pd.to_numeric(
    payments["payment_value"],
    errors="coerce"
)

installments = pd.to_numeric(
    payments["payment_installments"],
    errors="coerce"
)

print("\n=== 8. FINANCIAL CHECKS ===")
print("Invalid/missing amounts:", amounts.isna().sum())
print("Negative amounts:", (amounts < 0).sum())
print("Zero-value payments:", (amounts == 0).sum())
print("Invalid/missing installments:", installments.isna().sum())
print("Zero installments:", (installments == 0).sum())
print("Negative installments:", (installments < 0).sum())

# 8. Relationship validation
print("\n=== 9. RELATIONSHIP CHECK ===")

unknown_orders = ~payments["order_id"].isin(
    orders["order_id"]
)

orders_without_payments = ~orders["order_id"].isin(
    payments["order_id"]
)

print(
    "Payment rows without matching orders:",
    unknown_orders.sum()
)

print(
    "Orders without payment records:",
    orders_without_payments.sum()
)

print("\n=== PAYMENT PROFILING COMPLETE ===")
