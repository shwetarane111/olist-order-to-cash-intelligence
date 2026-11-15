
from pathlib import Path
import pandas as pd

# 1. Locate the source datasets
project = Path(__file__).resolve().parents[1]
raw = project / "data" / "raw"

translations = pd.read_csv(
    raw / "product_category_name_translation.csv",
    dtype="string"
)

products = pd.read_csv(
    raw / "olist_products_dataset.csv",
    usecols=["product_id", "product_category_name"],
    dtype="string"
)

# 2. Dataset structure
print("\n=== 1. DATASET SIZE ===")
print("Rows:", len(translations))
print("Columns:", len(translations.columns))

print("\n=== 2. COLUMNS AND TYPES ===")
print(translations.dtypes.to_string())

print("\n=== 3. FIRST FIVE RECORDS ===")
print(translations.head(5).to_string(index=False))

# 3. Key validation
print("\n=== 4. TRANSLATION KEY CHECK ===")

print(
    "Unique Portuguese categories:",
    translations["product_category_name"].nunique()
)

print(
    "Duplicate Portuguese category keys:",
    translations["product_category_name"].duplicated().sum()
)

print(
    "Unique English labels:",
    translations["product_category_name_english"].nunique()
)

print(
    "Exact duplicate rows:",
    translations.duplicated().sum()
)

# 4. Completeness
print("\n=== 5. MISSING VALUES ===")
print(translations.isna().sum().to_string())

print("\n=== 6. BLANK VALUES ===")

for col in translations.columns:
    blank = (
        translations[col]
        .str.strip()
        .eq("")
        .fillna(False)
        .sum()
    )
    print(f"{col}: {blank}")

# 5. Relationship with Products
print("\n=== 7. CATEGORY COVERAGE ===")

product_categories = set(
    products["product_category_name"].dropna()
)

translated_categories = set(
    translations["product_category_name"].dropna()
)

missing_translations = sorted(
    product_categories - translated_categories
)

unused_translations = sorted(
    translated_categories - product_categories
)

print("Distinct product categories:", len(product_categories))
print("Translated categories:", len(translated_categories))

print(
    "Product categories without English translation:",
    len(missing_translations)
)

print("Untranslated categories:", missing_translations)

print(
    "Translations not used by Products:",
    len(unused_translations)
)

# 6. Business impact
print("\n=== 8. PRODUCTS AFFECTED ===")

untranslated_products = products[
    products["product_category_name"].isin(
        missing_translations
    )
]

print(
    "Products with untranslated categories:",
    len(untranslated_products)
)

print(
    "Products with missing category names:",
    products["product_category_name"].isna().sum()
)

print("\nUntranslated product counts by category:")
print(
    untranslated_products["product_category_name"]
    .value_counts()
    .to_string()
)

print("\n=== TRANSLATION PROFILING COMPLETE ===")
