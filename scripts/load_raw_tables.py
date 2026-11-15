
from pathlib import Path
from getpass import getpass
import argparse
import csv

import psycopg
from psycopg import sql


# ==========================================
# 1. Project configuration
# ==========================================

PROJECT = Path(__file__).resolve().parents[1]
RAW_FOLDER = PROJECT / "data" / "raw"

# Source filename and expected row count
# for each PostgreSQL RAW table.

TABLES = {
    "order_items": {
        "file": "olist_order_items_dataset.csv",
        "expected_rows": 112650
    },
    "order_payments": {
        "file": "olist_order_payments_dataset.csv",
        "expected_rows": 103886
    },
    "customers": {
        "file": "olist_customers_dataset.csv",
        "expected_rows": 99441
    },
    "products": {
        "file": "olist_products_dataset.csv",
        "expected_rows": 32951
    },
    "sellers": {
        "file": "olist_sellers_dataset.csv",
        "expected_rows": 3095
    },
    "order_reviews": {
        "file": "olist_order_reviews_dataset.csv",
        "expected_rows": 99224
    },
    "geolocation": {
        "file": "olist_geolocation_dataset.csv",
        "expected_rows": 1000163
    },
    "category_translation": {
        "file": "product_category_name_translation.csv",
        "expected_rows": 71
    }
}


# ==========================================
# 2. Select ONE table to load
# ==========================================

parser = argparse.ArgumentParser(
    description="Load one Olist CSV into PostgreSQL RAW"
)

parser.add_argument(
    "table",
    choices=TABLES.keys(),
    help="Name of the RAW table to load"
)

args = parser.parse_args()

table_name = args.table
config = TABLES[table_name]

csv_path = RAW_FOLDER / config["file"]

if not csv_path.is_file():
    raise FileNotFoundError(csv_path)


# ==========================================
# 3. Validate source CSV
# ==========================================

print("\n=== SOURCE VALIDATION ===")
print("Selected table:", table_name)
print("Source file:", csv_path.name)

with csv_path.open(
    "r", encoding="utf-8-sig", newline=""
) as file:

    reader = csv.reader(file)
    csv_columns = next(reader, None)

    if not csv_columns:
        raise ValueError("CSV header is missing")

    source_count = 0

    for row in reader:
        if len(row) != len(csv_columns):
            raise ValueError(
                f"Incorrect column count on data row "
                f"{source_count + 1}"
            )
        source_count += 1

print("Source rows:", source_count)
print("Source columns:", len(csv_columns))

if source_count != config["expected_rows"]:
    raise ValueError(
        "Source row count differs from the "
        "verified Olist baseline"
    )


# ==========================================
# 4. Connect to PostgreSQL
# ==========================================

password = getpass("\nPostgreSQL password: ")

with psycopg.connect(
    host="localhost",
    port=5432,
    dbname="olist_analytics",
    user="postgres",
    password=password,
    connect_timeout=10
) as conn:

    with conn.cursor() as cur:

        cur.execute("SELECT current_database()")
        database_name = cur.fetchone()[0]

        if database_name != "olist_analytics":
            raise ValueError("Wrong database connection")

        print("\n=== DATABASE VALIDATION ===")
        print("Connected database:", database_name)

        # Find the actual destination columns.
        cur.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = 'raw'
              AND table_name = %s
            ORDER BY ordinal_position
            """,
            (table_name,)
        )

        db_columns = [
            row[0] for row in cur.fetchall()
        ]

        if csv_columns != db_columns:
            raise ValueError(
                "CSV columns do not match PostgreSQL!\n"
                f"CSV: {csv_columns}\n"
                f"Database: {db_columns}"
            )

        print("Column names and order: MATCH")

        # Use SQL identifiers safely.
        target = sql.Identifier("raw", table_name)

        count_sql = sql.SQL(
            "SELECT COUNT(*) FROM {}"
        ).format(target)

        # Prevent accidental duplicate ingestion.
        cur.execute(count_sql)

        existing_count = cur.fetchone()[0]

        print("Existing rows:", existing_count)

        if existing_count != 0:
            raise ValueError(
                f"STOP: raw.{table_name} already contains "
                f"{existing_count} records. "
                "No additional rows were loaded."
            )

        # ==================================
        # 5. Bulk-load CSV
        # ==================================

        print("\n=== LOADING DATA ===")

        copy_sql = sql.SQL(
            "COPY {} ({}) FROM STDIN "
            "WITH (FORMAT CSV, HEADER TRUE)"
        ).format(
            target,
            sql.SQL(", ").join(
                sql.Identifier(col)
                for col in db_columns
            )
        )

        with csv_path.open("rb") as file:
            with cur.copy(copy_sql) as copy:

                while True:
                    chunk = file.read(1024 * 1024)

                    if not chunk:
                        break

                    copy.write(chunk)

        # ==================================
        # 6. Validate inserted row count
        # ==================================

        cur.execute(count_sql)

        loaded_count = cur.fetchone()[0]

        print("\n=== INGESTION VALIDATION ===")
        print("Source rows:", source_count)
        print("PostgreSQL rows:", loaded_count)

        if loaded_count != source_count:
            raise ValueError(
                "Row-count mismatch! "
                "Transaction will roll back."
            )

# Successful transaction commits on exit.
print(
    f"\nSUCCESS: raw.{table_name} loaded "
    "and committed successfully!"
)
