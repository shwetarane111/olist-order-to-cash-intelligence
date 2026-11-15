
from pathlib import Path
import csv
import re

source = Path("docs/kpi_dictionary.md")
destination = Path("docs/powerbi_kpi_coverage.csv")

if not source.exists():
    raise SystemExit(
        "KPI dictionary not found. Run this script "
        "from the project root folder."
    )

content = source.read_text(encoding="utf-8")

kpi_ids = sorted(
    set(re.findall(r"\bKPI-\d{3}\b", content)),
    key=lambda item: int(item.split("-")[1])
)

print(f"Unique KPI IDs found: {len(kpi_ids)}")

if len(kpi_ids) != 55:
    raise SystemExit(
        "Expected 55 KPI IDs. Review the dictionary "
        "before generating the coverage register."
    )

columns = [
    "KPI_ID",
    "Dictionary_Name",
    "Business_Definition",
    "Grain",
    "Date_Role",
    "DAX_Measure_or_Calculation",
    "SQL_Validation_File",
    "Filtered_Test",
    "Implementation_Status",
    "Notes"
]

with destination.open(
    "w", newline="", encoding="utf-8-sig"
) as handle:
    writer = csv.DictWriter(
        handle, fieldnames=columns
    )
    writer.writeheader()

    for kpi_id in kpi_ids:
        writer.writerow({
            "KPI_ID": kpi_id,
            "Dictionary_Name": "",
            "Business_Definition": "",
            "Grain": "",
            "Date_Role": "",
            "DAX_Measure_or_Calculation": "",
            "SQL_Validation_File": "",
            "Filtered_Test": "",
            "Implementation_Status": "NOT_REVIEWED",
            "Notes": ""
        })

print(f"Created: {destination}")
