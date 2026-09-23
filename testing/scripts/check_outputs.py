
#!/usr/bin/env python3

import json
from pathlib import Path


RESULTS_DIR = Path(__file__).resolve().parents[1] / "results"
REQUIRED_KEYS = {"classification", "severity", "risk_score", "evidence"}


def main() -> int:
    failures = 0
    for output_file in sorted(RESULTS_DIR.glob("*.txt")):
        print(f"[+] Checking {output_file.name}")
        try:
            data = json.loads(output_file.read_text(encoding="utf-8"))
            missing = REQUIRED_KEYS - set(data)
            valid_score = isinstance(data.get("risk_score"), int) and 0 <= data["risk_score"] <= 100
            valid_severity = data.get("severity") in {"Critical", "High", "Medium", "Low"}
            valid_evidence = isinstance(data.get("evidence"), list) and bool(data["evidence"])
            if missing or not valid_score or not valid_severity or not valid_evidence:
                print(f"[!] Invalid result: missing={sorted(missing)}")
                failures += 1
            else:
                print(f"[+] {data['severity']} ({data['risk_score']})")
        except (OSError, json.JSONDecodeError, TypeError):
            print("[!] Could not parse output as a result JSON object")
            failures += 1

    if failures:
        print(f"[!] {failures} invalid output file(s)")
        return 1

    print("[+] All output files are valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
