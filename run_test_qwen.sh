#!/bin/bash

test_dir="Tests2_filtered"

models=(
    "qwen2.5-coder:1.5b"
    "qwen2.5-coder:3b"
    "qwen2.5-coder:7b"
    #"qwen2.5-coder:14b"
)


for model in "${models[@]}"; do
    for file in "$test_dir"/*.json; do
        echo "[+] Processing: $file with model: $model"
        python3 wrapper.py "$file" "$model"
    done
done

echo "[+] Building markdown summary table in Output/model_comparison.md"

python3 - <<'PY'
import glob
import json
import os
import re
from pathlib import Path

test_dir = Path("Tests2_filtered")
models = [
    "qwen2.5-coder:1.5b",
    "qwen2.5-coder:3b",
    "qwen2.5-coder:7b"
    #"qwen2.5-coder:14b"
]

def make_safe_filename(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9._-]+', '_', value).strip('._-') or "output"

tests = sorted(test_dir.glob("*.json"))
output_dir = Path("Output")
summary_path = output_dir / "model_comparison.md"

lines = []
lines.append("# Model Comparison")
lines.append("")
lines.append("| Test case | " + " | ".join(models) + " |")
lines.append("| --- | " + " | ".join(["---"] * len(models)) + " |")

for test_path in tests:
    test_name = test_path.stem
    row = [test_name]

    for model in models:
        safe_model = make_safe_filename(model)
        output_file = output_dir / f"{test_name}_{safe_model}_output.txt"
        if not output_file.exists():
            row.append("Missing")
            continue

        try:
            with open(output_file, "r", encoding="utf-8") as f:
                data = json.load(f)
            severity = data.get("severity", "N/A")
            risk_score = data.get("risk_score", "N/A")
            row.append(f"{severity} ({risk_score})")
        except Exception:
            row.append("Parse error")

    lines.append("| " + " | ".join(row) + " |")

summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"[+] Wrote {summary_path}")
PY
