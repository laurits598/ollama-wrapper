# OllamaWrapper

A small local wrapper around Ollama for turning malware-sandbox verdict data into a compact, structured malware assessment.

## File tree

```text
.
├── Dockerfile.ollama
├── MODELS.md
├── NOTES.md
├── README.md
├── wrapper.py
├── personas/
│   ├── persona.yaml
│   ├── persona_brief.yaml
│   └── persona_claude.yaml
└── testing/
    ├── README.md
    ├── fixtures/
    │   ├── baseline/*.json
    │   ├── attacks/*.json
    │   └── filtered/*.json
    ├── scripts/
    │   ├── check_outputs.py
    │   ├── repeated_attacks.sh
    │   ├── run_attacks.sh
    │   ├── run_baseline_models.sh
    │   └── run_filtered_qwen.sh
    └── results/
        ├── *.txt
        ├── *.csv
        ├── *.json
        └── *.md
```

## Files

- **Dockerfile.ollama** - Ollama server image definition
- **wrapper.py** - Main CLI and Ollama integration
- **personas/** - LLM instruction and scoring profiles
- **testing/** - Fixtures, evaluation scripts, and result artifacts

Testing data and scripts are organized as follows:

```text
testing/
  fixtures/baseline/       Small baseline verdicts
  fixtures/attacks/        Attack-oriented verdicts
  fixtures/filtered/       Filtered/normalized verdicts
  scripts/                 Evaluation and result-checking scripts
  results/                 Checked-in outputs and generated summaries

personas/
  persona_claude.yaml      Active JSON-oriented persona
  persona_brief.yaml       Alternative concise persona
  persona.yaml             Legacy human-readable persona
```

## How It Works

```
verdict.json (verdict data)
    ↓
personas/persona_claude.yaml (instructions)
    ↓
wrapper.py (combines them)
    ↓
Ollama/LLM (analyzes)
    ↓
testing/results/* (validated JSON analysis)
```

## Quick Start

### 1. Start Ollama Container

```bash
# Pull and run Ollama
docker run -d -p 11434:11434 --name ollama ollama/ollama

# Pull a model (pick one):
docker exec ollama ollama pull llama2           # ~4GB, good default
docker exec ollama ollama pull neural-chat      # ~5GB, faster
docker exec ollama ollama pull mistral          # ~4GB, powerful
```

### 2. Install Python Dependencies

```bash
pip install requests pyyaml
```

### 3. Run Analysis

```bash
python3 wrapper.py testing/fixtures/baseline/agent_test.json llama3.1:latest
```

Output is written to `testing/results/` by default.

The complete CLI is:

```bash
python3 wrapper.py <json_file> [model] \
  --persona path/to/persona.yaml \
  --output-dir path/to/results \
  --ollama-url http://localhost:11434
```

## Files Explained

### Dockerfile.ollama
Provides the Ollama server base image and exposes port 11434. It does not preload a model.

### wrapper.py
- Loads `personas/persona_claude.yaml` by default (instructions)
- Loads the JSON verdict passed on the command line
- Combines them into a prompt
- Sends to Ollama
- Returns analysis
- Validates and saves JSON to `testing/results/` by default

### Verdict JSON
Your verdict data. It can be:
- Simple: just `"msg"` field
- Complex: full structure from malware detector

### Persona YAML
Defines what the LLM does:
- `system` - Background/expertise
- `mission` - What to analyze
- `output_format` - How to structure response

## Customization

### Change Model
Pass a model name on the command line:
```bash
python3 wrapper.py testing/fixtures/baseline/agent_test.json mistral:latest
```

### Change Input/Output Files
Pass the input and output paths on the command line:
```bash
python3 wrapper.py my_input.json mistral:latest \
  --persona my_persona.yaml \
  --output-dir my_results
```

### Change Persona
Edit a file under `personas/` to change:
- What the LLM is an expert in
- What it should analyze
- How it should format output

## Testing

Test without a full malware detector:

```bash
# 1. Make sure Ollama is running
docker ps  # should see ollama container

# 2. Run the wrapper
python3 wrapper.py testing/fixtures/baseline/agent_test.json llama3.1:latest

# 3. Check output
cat testing/results/agent_test_llama3.1_latest_output.txt
```

Evaluation scripts live under `testing/scripts/` and resolve repository paths themselves:

```bash
bash testing/scripts/run_attacks.sh
bash testing/scripts/run_filtered_qwen.sh
bash testing/scripts/run_baseline_models.sh
bash testing/scripts/repeated_attacks.sh 5
python3 testing/scripts/check_outputs.py
```

## Common Issues

**Q: "Could not connect to Ollama"**
```
Make sure container is running:
docker run -d -p 11434:11434 ollama/ollama
```

**Q: "Model not found"**
```
Pull the model:
docker exec ollama ollama pull llama2
```

**Q: Response is slow**
```
- Smaller model: neural-chat instead of llama2
- More RAM: give docker more memory
- GPU: enable GPU support in docker
```

## Next Steps

1. Test with a fixture under `testing/fixtures/`
2. Customize a persona file under `personas/`
3. Integrate with malware detector (later)
4. Add more input fields as needed

## Integration (Later)

Once working, integrate into malware detector:
```
malware_detector → verdict.json → wrapper.py → LLM analysis → report
```
