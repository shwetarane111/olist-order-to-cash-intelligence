
from pathlib import Path
import pandas as pd

# 1. Locate the project and source data
project = Path(__file__).resolve().parents[1]
raw = project / "data" / "raw"

payments = pd.read_csv(
    raw / "olist_order_payments_dataset.csv",
    dtype={"order_id": "string"}
)

orders = pd.read_csv(
    raw / "olist_orders_dataset.csv",
    usecols=["order_id", "order_status"],
    dtype={"order_id": "string"}
)

# 2. Combine payments with their order statuses
# validate ensures each payment matches at most one order
data = payments.merge(
    orders,
    on="order_id",
    how="left",
    validate="many_to_one"
)

# 3. Flag unusual payment records
data["zero_amount"] = data["payment_value"].eq(0)

data["zero_installments"] = (
    data["payment_installments"].eq(0)
)

data["undefined_method"] = (
    data["payment_type"].eq("not_defined")
)

flags = [
    "zero_amount",
    "zero_installments",
    "undefined_method"
]

# 4. Select records triggering at least one flag
exceptions = data.loc[
    data[flags].any(axis=1)
].copy()

print("\n=== 1. EXCEPTION COUNTS ===")

for flag in flags:
    print(flag, ":", int(data[flag].sum()))

print(
    "Distinct flagged payment records:",
    len(exceptions)
)

print(
    "Distinct orders with flagged payments:",
    exceptions["order_id"].nunique()
)

print(
    "Payment records with multiple flags:",
    int((exceptions[flags].sum(axis=1) > 1).sum())
)

# 5. Examine each exception type
summary = []

for flag in flags:
    subset = data.loc[data[flag]]

    print(f"\n=== 2. {flag.upper()} ===")

    print(
        subset[
            [
                "order_id",
                "payment_sequential",
                "payment_type",
                "payment_installments",
                "payment_value",
                "order_status"
            ]
        ].to_string(index=False)
    )

    status_counts = subset["order_status"].value_counts(
        dropna=False
    )

    status_text = "; ".join(
        f"{status}: {count}"
        for status, count in status_counts.items()
    )

    summary.append({
        "issue": flag,
        "affected_payment_records": len(subset),
        "distinct_orders": subset["order_id"].nunique(),
        "order_status_breakdown": status_text
    })

# 6. Investigate orders without payment records
print("\n=== 3. ORDERS WITHOUT PAYMENTS ===")

missing_payment_orders = orders.loc[
    ~orders["order_id"].isin(payments["order_id"])
]

print(missing_payment_orders.to_string(index=False))

# 7. Export aggregate findings for documentation
summary.append({
    "issue": "order_without_payment",
    "affected_payment_records": 0,
    "distinct_orders": len(missing_payment_orders),
    "order_status_breakdown": (
        "; ".join(
            f"{status}: {count}"
            for status, count in
            missing_payment_orders["order_status"]
            .value_counts().items()
        )
    )
})

summary_file = (
    project / "docs" / "payment_exception_summary.csv"
)

pd.DataFrame(summary).to_csv(
    summary_file,
    index=False
)

# 8. Save row-level evidence locally
# data/processed is excluded from Git
details_file = (
    project / "data" / "processed" /
    "payment_exception_details.csv"
)

details_file.parent.mkdir(
    parents=True,
    exist_ok=True
)

exceptions.to_csv(details_file, index=False)

print("\n=== 4. EXPORT RESULTS ===")
print("Summary:", summary_file)
print("Local exception details:", details_file)

print("\n=== PAYMENT INVESTIGATION COMPLETE ===")
