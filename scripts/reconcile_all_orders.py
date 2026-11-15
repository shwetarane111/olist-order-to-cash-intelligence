
from pathlib import Path
from decimal import Decimal, InvalidOperation
import pandas as pd

# ==========================================
# 1. Project paths
# ==========================================

project = Path(__file__).resolve().parents[1]
raw = project / "data" / "raw"

details_path = (
    project / "data" / "processed" /
    "full_order_reconciliation.csv"
)

summary_path = (
    project / "docs" /
    "full_payment_reconciliation_summary.csv"
)

# ==========================================
# 2. Load source datasets
# ==========================================

orders = pd.read_csv(
    raw / "olist_orders_dataset.csv",
    usecols=["order_id", "order_status"]
)

items = pd.read_csv(
    raw / "olist_order_items_dataset.csv",
    usecols=["order_id", "price", "freight_value"],
    dtype={
        "price": "string",
        "freight_value": "string"
    }
)

payments = pd.read_csv(
    raw / "olist_order_payments_dataset.csv",
    usecols=["order_id", "payment_value"],
    dtype={"payment_value": "string"}
)

print("\n=== 1. SOURCE RECORDS ===")
print("Orders:", len(orders))
print("Order Items:", len(items))
print("Payments:", len(payments))

# ==========================================
# 3. Convert BRL amounts to integer cents
# ==========================================

def to_cents(value):
    if pd.isna(value):
        raise ValueError("Missing monetary value")

    try:
        amount = Decimal(str(value))
    except InvalidOperation as exc:
        raise ValueError(
            f"Invalid monetary value: {value}"
        ) from exc

    if not amount.is_finite():
        raise ValueError("Non-finite monetary value")

    if amount != amount.quantize(Decimal("0.01")):
        raise ValueError(
            f"Amount has more than 2 decimal places: {value}"
        )

    return int(amount * 100)


items["price_cents"] = items["price"].map(to_cents)

items["freight_cents"] = (
    items["freight_value"].map(to_cents)
)

payments["payment_cents"] = (
    payments["payment_value"].map(to_cents)
)

# ==========================================
# 4. Aggregate to one row per order
# ==========================================

item_totals = items.groupby(
    "order_id", as_index=False
).agg(
    item_rows=("order_id", "size"),
    price_cents=("price_cents", "sum"),
    freight_cents=("freight_cents", "sum")
)

payment_totals = payments.groupby(
    "order_id", as_index=False
).agg(
    payment_rows=("order_id", "size"),
    payment_cents=("payment_cents", "sum")
)

# ==========================================
# 5. Join aggregated totals to Orders
# ==========================================

result = orders.merge(
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

# Protect against accidentally losing orders
if len(result) != len(orders):
    raise ValueError("Order count changed during joining!")

# Preserve missing monetary values
for col in [
    "item_rows", "price_cents", "freight_cents",
    "payment_rows", "payment_cents"
]:
    result[col] = result[col].astype("Int64")

result["item_total_cents"] = (
    result["price_cents"] + result["freight_cents"]
)

result["difference_cents"] = (
    result["payment_cents"] -
    result["item_total_cents"]
)

# ==========================================
# 6. Classify reconciliation outcomes
# ==========================================

has_items = result["item_rows"].notna()
has_payments = result["payment_rows"].notna()

result["reconciliation_status"] = "UNCLASSIFIED"

result.loc[
    ~has_items & ~has_payments,
    "reconciliation_status"
] = "MISSING_BOTH"

result.loc[
    ~has_items & has_payments,
    "reconciliation_status"
] = "MISSING_ITEMS"

result.loc[
    has_items & ~has_payments,
    "reconciliation_status"
] = "MISSING_PAYMENTS"

comparable = has_items & has_payments

result.loc[
    comparable &
    result["difference_cents"].eq(0).fillna(False),
    "reconciliation_status"
] = "MATCH"

result.loc[
    comparable &
    result["difference_cents"].ne(0).fillna(False),
    "reconciliation_status"
] = "MISMATCH"

if (result["reconciliation_status"] == "UNCLASSIFIED").any():
    raise ValueError("Some orders were not classified")

# ==========================================
# 7. Print overall reconciliation results
# ==========================================

print("\n=== 2. RECONCILIATION RESULTS ===")

print(
    result["reconciliation_status"]
    .value_counts()
    .to_string()
)

comparable_orders = result.loc[comparable]

matched = (
    result["reconciliation_status"] == "MATCH"
).sum()

mismatched = (
    result["reconciliation_status"] == "MISMATCH"
).sum()

print("\nComparable orders:", len(comparable_orders))
print("Matched orders:", matched)
print("Mismatched orders:", mismatched)

if len(comparable_orders) > 0:
    match_rate = matched / len(comparable_orders) * 100
    print(f"Match rate: {match_rate:.2f}%")

# ==========================================
# 8. Calculate financial totals
# ==========================================

total_items_cents = int(
    comparable_orders["item_total_cents"].sum()
)

total_payments_cents = int(
    comparable_orders["payment_cents"].sum()
)

absolute_difference_cents = int(
    comparable_orders["difference_cents"].abs().sum()
)

print("\n=== 3. FINANCIAL TOTALS ===")

print(
    f"Item + freight total: R${total_items_cents / 100:,.2f}"
)

print(
    f"Recorded payments: R${total_payments_cents / 100:,.2f}"
)

print(
    "Sum of absolute order-level differences: "
    f"R${absolute_difference_cents / 100:,.2f}"
)

# ==========================================
# 9. Analyze results by order status
# ==========================================

print("\n=== 4. RESULTS BY ORDER STATUS ===")

status_summary = (
    result.groupby(
        ["order_status", "reconciliation_status"],
        dropna=False
    )
    .size()
    .reset_index(name="orders")
)

print(status_summary.to_string(index=False))

# ==========================================
# 10. Export reproducible results
# ==========================================

details_path.parent.mkdir(
    parents=True, exist_ok=True
)

summary_path.parent.mkdir(
    parents=True, exist_ok=True
)

result.to_csv(details_path, index=False)

status_summary.to_csv(
    summary_path, index=False
)

print("\n=== 5. OUTPUT FILES ===")
print("Detailed results:", details_path)
print("Summary:", summary_path)

print("\n=== FULL RECONCILIATION COMPLETE ===")
