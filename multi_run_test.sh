#!/bin/bash

set -euo pipefail

test_dir="Tests2"
runs="${1:-5}"
output_dir="Output"
results_csv="$output_dir/multi_run_results.csv"
results_json="$output_dir/multi_run_results.json"

models=(
    "llama3.1:latest"
)

mkdir -p "$output_dir"

python3 - <<'PY' "$results_csv"
import csv
import sys

with open(sys.argv[1], "w", encoding="utf-8", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["model", "log_name", "source_file", "run", "severity", "risk_score"])
PY

for run in $(seq 1 "$runs"); do
    echo "[+] Starting run $run/$runs"

    for model in "${models[@]}"; do
        for file in "$test_dir"/*.json; do
            echo "[+] Processing: $file with model: $model (run $run/$runs)"
            python3 wrapper.py "$file" "$model"

            python3 - <<'PY' "$file" "$model" "$run" "$results_csv"
import csv
import json
import re
import sys
from pathlib import Path

input_file = Path(sys.argv[1])
model = sys.argv[2]
run = int(sys.argv[3])
results_csv = Path(sys.argv[4])

def make_safe_filename(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9._-]+', '_', value).strip('._-') or "output"

def display_log_name(filename: str) -> str:
    match = re.match(r"^(.*?\.(?:sh|py))", filename)
    if match:
        return match.group(1)
    return Path(filename).stem

safe_model = make_safe_filename(model)
output_file = Path("Output") / f"{input_file.stem}_{safe_model}_output.txt"

with open(output_file, "r", encoding="utf-8") as f:
    data = json.load(f)

with open(results_csv, "a", encoding="utf-8", newline="") as f:
    writer = csv.writer(f)
    writer.writerow([
        model,
        display_log_name(input_file.name),
        input_file.name,
        run,
        data.get("severity", "N/A"),
        data.get("risk_score", "N/A"),
    ])
PY
        done
    done
done

python3 - <<'PY' "$results_csv" "$results_json" "$runs"
import csv
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

results_csv = Path(sys.argv[1])
results_json = Path(sys.argv[2])
runs = int(sys.argv[3])

grouped = defaultdict(list)
with open(results_csv, "r", encoding="utf-8", newline="") as f:
    reader = csv.DictReader(f)
    rows = list(reader)

for row in rows:
    grouped[(row["model"], row["log_name"])].append({
        "run": int(row["run"]),
        "severity": row["severity"],
        "risk_score": int(row["risk_score"]),
        "source_file": row["source_file"],
    })

summary = []
for (model, log_name), entries in sorted(grouped.items()):
    entries.sort(key=lambda item: item["run"])
    severities = [item["severity"] for item in entries]
    scores = [item["risk_score"] for item in entries]
    severity_counts = Counter(severities)
    summary.append({
        "model": model,
        "log_name": log_name,
        "source_file": entries[0]["source_file"],
        "runs": entries,
        "severity_mode": severity_counts.most_common(1)[0][0],
        "severity_counts": dict(severity_counts),
        "avg_risk_score": round(sum(scores) / len(scores), 1),
    })

results_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")

def make_row(columns, widths):
    return " | ".join(str(value).ljust(width) for value, width in zip(columns, widths))

for model in sorted({item["model"] for item in summary}):
    print(f"\n[+] Summary for {model}")

    model_rows = [item for item in summary if item["model"] == model]
    headers = ["Log"] + [f"R{i}" for i in range(1, runs + 1)] + ["Mode", "Avg"]
    table_rows = []

    for item in model_rows:
        run_values = [f'{entry["severity"]} ({entry["risk_score"]})' for entry in item["runs"]]
        table_rows.append([
            item["log_name"],
            *run_values,
            item["severity_mode"],
            item["avg_risk_score"],
        ])

    widths = [len(header) for header in headers]
    for row in table_rows:
        for idx, value in enumerate(row):
            widths[idx] = max(widths[idx], len(str(value)))

    print(make_row(headers, widths))
    print("-+-".join("-" * width for width in widths))
    for row in table_rows:
        print(make_row(row, widths))

print(f"\n[+] Saved detailed results to {results_csv}")
print(f"[+] Saved aggregated summary to {results_json}")
PY
