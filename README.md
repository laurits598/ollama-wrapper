# OllamaWrapper - Quick Start

A minimal wrapper around Ollama for analyzing malware verdicts.

## Files

- **Dockerfile.ollama** - Container image (ollama + model)
- **wrapper.py** - Middleware: loads inputs, sends to ollama, returns output
- **input.json** - Sample verdict data (with "msg" field)
- **persona.yaml** - LLM instructions (system prompt, mission, format)

## How It Works

```
input.json (verdict data)
    ↓
persona.yaml (instructions)
    ↓
wrapper.py (combines them)
    ↓
Ollama/LLM (analyzes)
    ↓
output.txt (human-readable analysis)
```

## Quick Start

### 1. Start Ollama Container

```bash
# Pull and run ollama
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
python3 wrapper.py
```

Output will be in `output.txt`.

## Files Explained

### Dockerfile
Runs ollama and exposes port 11434.

### wrapper.py
- Loads `persona.yaml` (instructions)
- Loads `input.json` (verdict data)
- Combines them into a prompt
- Sends to Ollama
- Returns analysis
- Saves to `output.txt`

### input.json
Your verdict data. Can be:
- Simple: just `"msg"` field
- Complex: full structure from malware detector

### persona.yaml
Defines what the LLM does:
- `system` - Background/expertise
- `mission` - What to analyze
- `output_format` - How to structure response

## Customization

### Change Model
Edit `wrapper.py`, line in `main()`:
```python
wrapper = OllamaWrapper(model="mistral")  # or "neural-chat"
```

### Change Input/Output Files
Edit `wrapper.py`, in `main()`:
```python
wrapper.load_persona("my_persona.yaml")
wrapper.load_input("my_input.json")
wrapper.save_output(output, "my_output.txt")
```

### Change Persona
Edit `persona.yaml` to change:
- What the LLM is an expert in
- What it should analyze
- How it should format output

## Testing

Test without a full malware detector:

```bash
# 1. Make sure ollama is running
docker ps  # should see ollama container

# 2. Run wrapper
python3 wrapper.py

# 3. Check output
cat output.txt
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

1. Test with sample input.json
2. Customize persona.yaml for your needs
3. Integrate with malware detector (later)
4. Add more input fields as needed

## Integration (Later)

Once working, integrate into malware detector:
```
malware_detector → verdict.json → wrapper.py → LLM analysis → report
```
