
from pathlib import Path
from decimal import Decimal
import pandas as pd

# 1. Locate the project files
project = Path(__file__).resolve().parents[1]
raw = project / "data" / "raw"
processed = project / "data" / "processed"

# 2. Load our previously identified top 10 mismatches
top_ten = pd.read_csv(
    processed / "top_10_payment_mismatches.csv",
    dtype={"order_id": "string"}
)

# Select the three largest absolute discrepancies
top_three = top_ten.nlargest(
    3, "absolute_difference_cents"
)

# 3. Load source item records
items = pd.read_csv(
    raw / "olist_order_items_dataset.csv",
    usecols=[
        "order_id",
        "order_item_id",
        "price",
        "freight_value"
    ],
    dtype={
        "order_id": "string",
        "price": "string",
        "freight_value": "string"
    }
)

# 4. Load source payment records
payments = pd.read_csv(
    raw / "olist_order_payments_dataset.csv",
    usecols=[
        "order_id",
        "payment_sequential",
        "payment_type",
        "payment_installments",
        "payment_value"
    ],
    dtype={
        "order_id": "string",
        "payment_value": "string"
    }
)

# Helper: sum monetary values using Decimal
def money_sum(values):
    return sum(
        (Decimal(str(value)) for value in values),
        Decimal("0.00")
    )

# 5. Inspect each of the three largest discrepancies
for index, (_, row) in enumerate(top_three.iterrows(), start=1):
    order_id = row["order_id"]

    order_items = items.loc[
        items["order_id"] == order_id
    ]

    order_payments = payments.loc[
        payments["order_id"] == order_id
    ]

    if (
        order_items[["price", "freight_value"]].isna().any().any()
        or order_payments["payment_value"].isna().any()
    ):
        raise ValueError(f"Missing monetary data: {order_id}")

    print(f"\n=== CASE {index} ===")
    print("Order ID:", order_id)
    print("Order status:", row["order_status"])

    print("\nITEM RECORDS:")
    print(
        order_items[
            ["order_item_id", "price", "freight_value"]
        ].to_string(index=False)
    )

    print("\nPAYMENT RECORDS:")
    print(
        order_payments[
            [
                "payment_sequential",
                "payment_type",
                "payment_installments",
                "payment_value"
            ]
        ].sort_values("payment_sequential").to_string(index=False)
    )

    # Calculate source totals independently
    item_total = (
        money_sum(order_items["price"])
        + money_sum(order_items["freight_value"])
    )

    payment_total = money_sum(
        order_payments["payment_value"]
    )

    difference = payment_total - item_total

    print("\nFINANCIAL SUMMARY:")
    print("Number of item rows:", len(order_items))
    print("Number of payment rows:", len(order_payments))
    print(f"Item + freight total: R${item_total:.2f}")
    print(f"Payment total: R${payment_total:.2f}")
    print(f"Difference: R${difference:.2f}")

    expected_cents = int(row["difference_cents"])

    if int(difference * 100) != expected_cents:
        raise ValueError(
            f"Source totals disagree with reconciliation: {order_id}"
        )

    print("Reconciliation cross-check: PASS")

print("\n=== TOP THREE INVESTIGATION COMPLETE ===")
