
from pathlib import Path
import pandas as pd

project = Path(__file__).resolve().parents[1]
raw = project / "data" / "raw"

# Load source data
orders = pd.read_csv(
    raw / "olist_orders_dataset.csv",
    usecols=["order_id", "order_status"]
)

items = pd.read_csv(
    raw / "olist_order_items_dataset.csv",
    usecols=[
        "order_id", "order_item_id",
        "price", "freight_value"
    ]
)

payments = pd.read_csv(
    raw / "olist_order_payments_dataset.csv"
)

# Identify payment exceptions
payments["zero_amount"] = payments["payment_value"].eq(0)
payments["zero_installments"] = payments[
    "payment_installments"
].eq(0)
payments["undefined_method"] = payments[
    "payment_type"
].eq("not_defined")

payments["positive_amount"] = payments["payment_value"].gt(0)

flags = [
    "zero_amount",
    "zero_installments",
    "undefined_method"
]

flagged_orders = set(
    payments.loc[
        payments[flags].any(axis=1), "order_id"
    ]
)

missing_payment_orders = (
    set(orders["order_id"]) - set(payments["order_id"])
)

target_orders = flagged_orders | missing_payment_orders

# Aggregate items to ONE row per order
item_totals = items.groupby(
    "order_id", as_index=False
).agg(
    item_rows=("order_item_id", "size"),
    item_value=("price", "sum"),
    freight_value=("freight_value", "sum")
)

# Aggregate payments to ONE row per order
payment_totals = payments.groupby(
    "order_id", as_index=False
).agg(
    payment_rows=("payment_sequential", "size"),
    payment_value=("payment_value", "sum"),
    positive_payment_rows=("positive_amount", "sum"),
    zero_payment_rows=("zero_amount", "sum")
)

# Join only after aggregating
result = orders.loc[
    orders["order_id"].isin(target_orders)
].merge(
    item_totals,
    on="order_id",
    how="left",
    validate="one_to_one"
).merge(
    payment_totals,
    on="order_id",
    how="left",
    validate="one_to_one"
)

# Calculate comparable totals
result["items_plus_freight"] = (
    result["item_value"] + result["freight_value"]
)

result["payment_difference"] = (
    result["payment_value"] - result["items_plus_freight"]
).round(2)

result["missing_payment_record"] = (
    result["payment_rows"].isna()
)

# Display findings
print("\n=== ORDER-LEVEL RECONCILIATION ===")
print("Orders investigated:", len(result))

columns = [
    "order_id",
    "order_status",
    "item_rows",
    "item_value",
    "freight_value",
    "items_plus_freight",
    "payment_rows",
    "positive_payment_rows",
    "zero_payment_rows",
    "payment_value",
    "payment_difference",
    "missing_payment_record"
]

print(
    result[columns]
    .sort_values("order_id")
    .to_string(index=False)
)

# Save detailed results locally
output = (
    project / "data" / "processed" /
    "payment_order_reconciliation.csv"
)

output.parent.mkdir(parents=True, exist_ok=True)
result[columns].to_csv(output, index=False)

print("\nOutput saved to:", output)
print("\n=== RECONCILIATION COMPLETE ===")
