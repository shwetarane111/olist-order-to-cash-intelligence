
from pathlib import Path
import pandas as pd

# 1. Locate the files
project = Path(__file__).resolve().parents[1]
raw = project / "data" / "raw"

reviews = pd.read_csv(
    raw / "olist_order_reviews_dataset.csv",
    dtype={"review_id": "string", "order_id": "string"}
)

orders = pd.read_csv(
    raw / "olist_orders_dataset.csv",
    usecols=["order_id"]
)

# 2. Dataset structure
print("\n=== 1. DATASET SIZE ===")
print("Rows:", len(reviews))
print("Columns:", len(reviews.columns))

print("\n=== 2. COLUMNS AND TYPES ===")
print(reviews.dtypes.to_string())

print("\n=== 3. FIRST FIVE RECORDS ===")
print(
    reviews[
        ["review_id", "order_id", "review_score"]
    ].head().to_string(index=False)
)

# 3. Key uniqueness
print("\n=== 4. IDENTIFIER CHECKS ===")

print("Unique review IDs:", reviews["review_id"].nunique())
print("Unique order IDs:", reviews["order_id"].nunique())

print(
    "Repeated review ID occurrences:",
    reviews["review_id"].duplicated().sum()
)

print(
    "Repeated order ID occurrences:",
    reviews["order_id"].duplicated().sum()
)

print(
    "Duplicate review/order combinations:",
    reviews.duplicated(
        subset=["review_id", "order_id"]
    ).sum()
)

print("Exact duplicate rows:", reviews.duplicated().sum())

# 4. Orders with multiple reviews
reviews_per_order = reviews.groupby("order_id").size()

print("\n=== 5. MULTIPLE REVIEWS ===")
print(
    "Orders with multiple review records:",
    (reviews_per_order > 1).sum()
)

print(
    "Maximum reviews per order:",
    reviews_per_order.max()
)

# 5. Missing values
print("\n=== 6. MISSING VALUES ===")
print(reviews.isna().sum().to_string())

# 6. Customer satisfaction scores
print("\n=== 7. REVIEW SCORE DISTRIBUTION ===")

print(
    reviews["review_score"]
    .value_counts(dropna=False)
    .sort_index()
    .to_string()
)

invalid_scores = (
    reviews["review_score"].isna()
    | ~reviews["review_score"].isin([1, 2, 3, 4, 5])
)

print("Invalid or missing scores:", invalid_scores.sum())
print(
    "Average review score:",
    round(reviews["review_score"].mean(), 2)
)

# 7. Text availability
print("\n=== 8. REVIEW COMMENTS ===")

for col in ["review_comment_title", "review_comment_message"]:
    missing = reviews[col].isna().sum()
    blank = (
        reviews[col].notna()
        & reviews[col].fillna("").str.strip().eq("")
    ).sum()

    print(f"{col}:")
    print("  Missing:", missing)
    print("  Blank but non-null:", blank)

# 8. Date quality
print("\n=== 9. DATE CHECKS ===")

created = pd.to_datetime(
    reviews["review_creation_date"],
    errors="coerce"
)

answered = pd.to_datetime(
    reviews["review_answer_timestamp"],
    errors="coerce"
)

print(
    "Invalid/missing creation dates:",
    created.isna().sum()
)

print(
    "Invalid/missing answer timestamps:",
    answered.isna().sum()
)

print(
    "Answer before survey creation:",
    ((answered < created) & answered.notna() & created.notna()).sum()
)

# 9. Relationship with Orders
print("\n=== 10. RELATIONSHIP CHECK ===")

unknown_orders = ~reviews["order_id"].isin(
    orders["order_id"]
)

orders_without_reviews = ~orders["order_id"].isin(
    reviews["order_id"]
)

print(
    "Review rows without matching orders:",
    unknown_orders.sum()
)

print(
    "Orders without review records:",
    orders_without_reviews.sum()
)

print("\n=== REVIEW PROFILING COMPLETE ===")
