
from pathlib import Path
from getpass import getpass
import csv
import psycopg

# ==========================================
# 1. Locate the source dataset
# ==========================================

project = Path(__file__).resolve().parents[1]

csv_file = (
    project / "data" / "raw" /
    "olist_orders_dataset.csv"
)

expected_columns = [
    "order_id",
    "customer_id",
    "order_status",
    "order_purchase_timestamp",
    "order_approved_at",
    "order_delivered_carrier_date",
    "order_delivered_customer_date",
    "order_estimated_delivery_date"
]

if not csv_file.exists():
    raise FileNotFoundError(
        f"CSV file not found: {csv_file}"
    )

# ==========================================
# 2. Validate source CSV
# ==========================================

with csv_file.open(
    "r", encoding="utf-8-sig", newline=""
) as file:

    reader = csv.reader(file)
    actual_columns = next(reader, None)

    if actual_columns != expected_columns:
        raise ValueError(
            "CSV columns do not match the expected "
            "Orders table structure.\n"
            f"Found: {actual_columns}"
        )

    source_count = sum(1 for row in reader)

print("\n=== SOURCE VALIDATION ===")
print("Source file:", csv_file.name)
print("CSV rows:", source_count)
print("CSV columns:", len(actual_columns))

if source_count != 99441:
    raise ValueError(
        "Unexpected Orders row count. "
        "Investigate the source file before loading."
    )

# ==========================================
# 3. Connect to PostgreSQL
# ==========================================

print("\n=== DATABASE CONNECTION ===")

# Password is entered securely at runtime.
# It is NOT saved in the Python script.
password = getpass("Enter PostgreSQL password: ")

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
            raise ValueError(
                "Connected to the wrong database!"
            )

        print("Connected database:", database_name)

        # ==================================
        # 4. Prevent duplicate ingestion
        # ==================================

        cur.execute(
            "SELECT COUNT(*) FROM raw.orders"
        )

        existing_count = cur.fetchone()[0]

        print("Existing database rows:", existing_count)

        if existing_count != 0:
            raise ValueError(
                "STOP: raw.orders already contains "
                f"{existing_count} rows. "
                "No additional data was loaded."
            )

        # ==================================
        # 5. Bulk-load the original CSV
        # ==================================

        print("\n=== LOADING DATA ===")

        copy_sql = """
            COPY raw.orders (
                order_id,
                customer_id,
                order_status,
                order_purchase_timestamp,
                order_approved_at,
                order_delivered_carrier_date,
                order_delivered_customer_date,
                order_estimated_delivery_date
            )
            FROM STDIN
            WITH (FORMAT CSV, HEADER TRUE)
        """

        with csv_file.open("rb") as file:
            with cur.copy(copy_sql) as copy:

                while True:
                    chunk = file.read(1024 * 1024)

                    if not chunk:
                        break

                    copy.write(chunk)

        # ==================================
        # 6. Validate loaded records
        # ==================================

        cur.execute("""
            SELECT
                COUNT(*) AS total_rows,
                COUNT(DISTINCT order_id) AS unique_orders,
                COUNT(*) FILTER (
                    WHERE order_id IS NULL
                       OR TRIM(order_id) = ''
                ) AS missing_ids
            FROM raw.orders
        """)

        total_rows, unique_orders, missing_ids = (
            cur.fetchone()
        )

        print("\n=== INGESTION VALIDATION ===")
        print("PostgreSQL rows:", total_rows)
        print("Unique order IDs:", unique_orders)
        print("Missing order IDs:", missing_ids)

        if (
            total_rows != source_count
            or unique_orders != source_count
            or missing_ids != 0
        ):
            raise ValueError(
                "Validation failed. "
                "The database transaction will roll back."
            )

# Successful exit from the connection context
# commits the validated data.
print("\nSUCCESS: Orders data loaded and validated!")
