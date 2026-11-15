
from pathlib import Path

import pandas as pd
import sqlalchemy
import psycopg

print("Python environment: OK")
print("pandas version:", pd.__version__)
print("SQLAlchemy version:", sqlalchemy.__version__)
print("PostgreSQL driver: OK")

raw_folder = Path("data/raw")
csv_files = sorted(raw_folder.glob("*.csv"))

print("CSV files found:", len(csv_files))

for file in csv_files:
    print(" -", file.name)

if len(csv_files) == 9:
    print("SUCCESS: All nine source CSV files found!")
else:
    print("CHECK: Expected nine CSV files in data/raw.")
