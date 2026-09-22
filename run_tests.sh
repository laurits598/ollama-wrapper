#!/bin/bash

test_dir="Tests"
timing_file="Output/model_timings.jsonl"

models=(
    "llama3.1:latest"
    "llama3:8b"
    "mistral:latest"
    "qwen2.5-coder:7b"
    "mistral-nemo:12b"
)

mkdir -p Output
: > "$timing_file"

for model in "${models[@]}"; do
    model_start=$(date +%s)
    test_count=0

    for file in "$test_dir"/*.json; do
        echo "[+] Processing: $file with model: $model"
        python3 wrapper.py "$file" "$model"
        test_count=$((test_count + 1))
    done

    model_end=$(date +%s)
    elapsed_seconds=$((model_end - model_start))
    printf '{"model": "%s", "tests": %d, "elapsed_seconds": %d}\n' \
        "$model" "$test_count" "$elapsed_seconds" >> "$timing_file"
    echo "[+] Model timing: $model took ${elapsed_seconds}s across ${test_count} tests"
done

echo "[+] Building markdown summary table in Output/model_comparison.md"

python3 - <<'PY'
import json
import re
from pathlib import Path

test_dir = Path("Tests")
models = [
    "llama3.1:latest",
    "llama3:8b",
    "mistral:latest",
    "qwen2.5-coder:7b",
    "mistral-nemo:12b"
]

def make_safe_filename(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9._-]+', '_', value).strip('._-') or "output"

tests = sorted(test_dir.glob("*.json"))
output_dir = Path("Output")
summary_path = output_dir / "model_comparison.md"
timing_path = output_dir / "model_timings.jsonl"

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

lines.append("")
lines.append("## Model Timings")
lines.append("")
lines.append("| Model | Total time (s) | Avg/test (s) | Tests |")
lines.append("| --- | --- | --- | --- |")

timings = {}
if timing_path.exists():
    for line in timing_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        data = json.loads(line)
        timings[data["model"]] = data

for model in models:
    timing = timings.get(model)
    if not timing:
        lines.append(f"| {model} | Missing | Missing | Missing |")
        continue

    elapsed = timing["elapsed_seconds"]
    test_count = timing["tests"]
    avg = elapsed / test_count if test_count else 0
    lines.append(f"| {model} | {elapsed} | {avg:.1f} | {test_count} |")

summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"[+] Wrote {summary_path}")
PY
