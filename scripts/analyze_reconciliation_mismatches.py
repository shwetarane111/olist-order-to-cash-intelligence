
from pathlib import Path
import pandas as pd

# 1. Locate our existing reconciliation output
project = Path(__file__).resolve().parents[1]

source = (
    project / "data" / "processed" /
    "full_order_reconciliation.csv"
)

df = pd.read_csv(source)

# 2. Confirm one record per order
if df["order_id"].isna().any() or not df["order_id"].is_unique:
    raise ValueError("Order IDs must be present and unique")

# 3. Select only mismatched orders
mismatches = df.loc[
    df["reconciliation_status"] == "MISMATCH"
].copy()

mismatches["difference_cents"] = pd.to_numeric(
    mismatches["difference_cents"],
    errors="raise"
)

if mismatches["difference_cents"].isna().any():
    raise ValueError("Mismatch amounts cannot be missing")

if (mismatches["difference_cents"] % 1 != 0).any():
    raise ValueError("Expected integer-cent differences")

mismatches["difference_cents"] = (
    mismatches["difference_cents"].astype("int64")
)

mismatches["absolute_difference_cents"] = (
    mismatches["difference_cents"].abs()
)

# 4. Positive and negative differences
positive = mismatches.loc[
    mismatches["difference_cents"] > 0
]

negative = mismatches.loc[
    mismatches["difference_cents"] < 0
]

print("\n=== 1. MISMATCH OVERVIEW ===")
print("Orders investigated:", len(mismatches))
print("Payments higher than items:", len(positive))
print("Payments lower than items:", len(negative))

print(
    "Total positive difference: R$"
    f"{positive['difference_cents'].sum() / 100:,.2f}"
)

print(
    "Total negative difference: R$"
    f"{negative['difference_cents'].sum() / 100:,.2f}"
)

print(
    "Net difference: R$"
    f"{mismatches['difference_cents'].sum() / 100:,.2f}"
)

print(
    "Total absolute difference: R$"
    f"{mismatches['absolute_difference_cents'].sum() / 100:,.2f}"
)

# 5. Categorize discrepancies by magnitude
print("\n=== 2. DIFFERENCE SIZE DISTRIBUTION ===")

bins = [0, 1, 10, 100, 1000, float("inf")]

labels = [
    "Exactly R$0.01",
    "R$0.02 to R$0.10",
    "R$0.11 to R$1.00",
    "R$1.01 to R$10.00",
    "Above R$10.00"
]

mismatches["difference_band"] = pd.cut(
    mismatches["absolute_difference_cents"],
    bins=bins,
    labels=labels
)

print(
    mismatches["difference_band"]
    .value_counts(sort=False)
    .to_string()
)

# 6. Calculate mismatch rates by order status
print("\n=== 3. MISMATCH RATES BY ORDER STATUS ===")

comparable = df.loc[
    df["reconciliation_status"].isin(["MATCH", "MISMATCH"])
]

status_totals = (
    comparable.groupby("order_status")
    .size()
    .rename("comparable_orders")
)

status_mismatches = (
    mismatches.groupby("order_status")
    .size()
    .rename("mismatched_orders")
)

status_summary = pd.concat(
    [status_totals, status_mismatches],
    axis=1
).fillna(0)

status_summary["mismatched_orders"] = (
    status_summary["mismatched_orders"].astype(int)
)

status_summary["mismatch_rate_pct"] = (
    status_summary["mismatched_orders"]
    / status_summary["comparable_orders"] * 100
).round(3)

status_summary = (
    status_summary.sort_values(
        "mismatched_orders", ascending=False
    )
)

print(status_summary.to_string())

# 7. Identify the ten largest discrepancies
print("\n=== 4. TOP TEN ABSOLUTE DIFFERENCES ===")

top_ten = mismatches.nlargest(
    10, "absolute_difference_cents"
)

columns = [
    "order_id",
    "order_status",
    "item_total_cents",
    "payment_cents",
    "difference_cents",
    "absolute_difference_cents"
]

print(top_ten[columns].to_string(index=False))

# 8. Export results
summary_path = (
    project / "docs" /
    "mismatch_status_summary.csv"
)

details_path = (
    project / "data" / "processed" /
    "top_10_payment_mismatches.csv"
)

status_summary.to_csv(summary_path)
top_ten[columns].to_csv(details_path, index=False)

print("\n=== OUTPUT FILES ===")
print("Status summary:", summary_path)
print("Top ten mismatches:", details_path)

print("\n=== MISMATCH ANALYSIS COMPLETE ===")
