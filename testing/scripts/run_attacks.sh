#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="$REPO_ROOT/testing/fixtures/attacks"
RESULTS_DIR="$REPO_ROOT/testing/results"
PERSONA_FILE="$REPO_ROOT/personas/persona_claude.yaml"

models=("llama3.1:latest")

for model in "${models[@]}"; do
    for file in "$TEST_DIR"/*.json; do
        echo "[+] Processing: $file with model: $model"
        python3 "$REPO_ROOT/wrapper.py" "$file" "$model" \
            --persona "$PERSONA_FILE" \
            --output-dir "$RESULTS_DIR"
    done
done

echo
echo "[+] Summary"

python3 - "$TEST_DIR" "$RESULTS_DIR" <<'PY'
import json
import re
import sys
from pathlib import Path

test_dir = Path(sys.argv[1])
output_dir = Path(sys.argv[2])
models = ["llama3.1:latest"]


def make_safe_filename(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9._-]+', '_', value).strip('._-') or "output"


def display_log_name(filename: str) -> str:
    match = re.match(r"^(.*?\.(?:sh|py))", filename)
    return match.group(1) if match else Path(filename).stem


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
            print(f"  {display_name}: {data.get('severity', 'N/A')} ({data.get('risk_score', 'N/A')})")
        except Exception:
            print(f"  {display_name}: Parse error")

    print()
PY
