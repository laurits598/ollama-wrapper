#!/bin/bash

test_dir="Tests2"

models=(
    "llama3.1:latest"
)

for model in "${models[@]}"; do
    for file in "$test_dir"/*.json; do
        echo "[+] Processing: $file with model: $model"
        python3 wrapper.py "$file" "$model"
    done
done

echo
echo "[+] Summary"

python3 - <<'PY'
import json
import re
from pathlib import Path

test_dir = Path("Tests2")
output_dir = Path("Output")
models = [
    "llama3.1:latest"
]

def make_safe_filename(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9._-]+', '_', value).strip('._-') or "output"

def display_log_name(filename: str) -> str:
    match = re.match(r"^(.*?\.(?:sh|py))", filename)
    if match:
        return match.group(1)
    return Path(filename).stem

for model in models:
    print(f"Model: {model}")
    safe_model = make_safe_filename(model)

    for test_path in sorted(test_dir.glob("*.json")):
        display_name = display_log_name(test_path.name)
        output_file = output_dir / f"{test_path.stem}_{safe_model}_output.txt"

        if not output_file.exists():
            print(f"  {display_name}: Missing")
            continue

        try:
            data = json.loads(output_file.read_text(encoding="utf-8"))
            severity = data.get("severity", "N/A")
            risk_score = data.get("risk_score", "N/A")
            print(f"  {display_name}: {severity} ({risk_score})")
        except Exception:
            print(f"  {display_name}: Parse error")

    print()
PY
