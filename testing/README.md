# Testing workspace

This directory contains the captured verdict fixtures, evaluation scripts, and model outputs for `ollama-wrapper`.

The active persona configuration is stored separately in `../personas/persona_claude.yaml`.

## Directories

- `fixtures/baseline/` — five small baseline verdicts.
- `fixtures/attacks/` — ten attack-oriented verdicts.
- `fixtures/filtered/` — sixteen filtered or normalized verdicts.
- `scripts/` — shell runners and output validation.
- `results/` — checked-in outputs plus generated summaries.

The fixtures are input data only. The evaluation scripts send them to the Ollama server; they do not execute the referenced malware or shell scripts.

Run scripts from the repository root or any other working directory:

```bash
bash testing/scripts/run_attacks.sh
bash testing/scripts/run_filtered_qwen.sh
bash testing/scripts/run_baseline_models.sh
bash testing/scripts/repeated_attacks.sh 5
python3 testing/scripts/check_outputs.py
```
