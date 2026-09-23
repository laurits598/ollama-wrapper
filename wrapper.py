#!/usr/bin/env python3
"""
OllamaWrapper - Middleware between user and Ollama agent.

Handles:
- Loading input JSON (verdict data)
- Loading persona (system instructions)
- Sending to Ollama
- Returning structured response
"""

import argparse
import json
import os
import re
import requests
import yaml
import sys
from pathlib import Path
from typing import Dict, Any, Optional

PROJECT_ROOT = Path(__file__).resolve().parent
PERSONA_DIR = PROJECT_ROOT / "personas"
YAML_FILE = "persona_claude.yaml"
DEFAULT_PERSONA_FILE = PERSONA_DIR / YAML_FILE
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "testing" / "results"
REQUIRED_KEYS = {"classification", "severity", "risk_score", "evidence"}

class OllamaWrapper:
    """Wrapper around Ollama for structured analysis."""
    
    def __init__(
        self,
        ollama_url: str = "http://localhost:11434",
        model: str = "llama2",
    ):
        """
        Initialize wrapper.
        
        Args:
            ollama_url: URL where ollama is running
            model: Model name to use (e.g., 'llama2', 'neural-chat', 'mistral')
        """
        self.ollama_url = ollama_url
        self.model = model
        self.persona = {}
        self.input_data = {}
    
    def load_persona(self, persona_file: str) -> None:
        """
        Load persona/instructions from YAML file.
        
        Args:
            persona_file: Path to persona.yaml
        """
        with open(persona_file, 'r') as f:
            self.persona = yaml.safe_load(f)
        print(f"[+] Loaded persona from {persona_file}")
    
    def load_input(self, input_file: str) -> None:
        """
        Load input data from JSON file.

        Args:
            input_file: Path to input.json
        """
        with open(input_file, 'r') as f:
            self.input_data = json.load(f)
        self.input_data = self.filter_noise_paths(self.input_data)
        print(f"[+] Loaded input from {input_file}")

    def filter_noise_paths(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Aggressively filter noise paths - truncate huge sections.

        Args:
            data: The input JSON data

        Returns:
            Filtered data
        """
        # If filesystem_changes is huge, truncate it
        if 'filesystem_changes' in data:
            changes = data['filesystem_changes']
            if isinstance(changes, (list, dict)):
                # Keep only first 20 entries max
                if isinstance(changes, list):
                    data['filesystem_changes'] = changes[:20]
                    print(f"[*] Truncated filesystem_changes to 20 entries")
                elif isinstance(changes, dict):
                    keys = list(changes.keys())[:20]
                    data['filesystem_changes'] = {k: changes[k] for k in keys}
                    print(f"[*] Truncated filesystem_changes to 20 keys")

        # Filter environment section if present
        if 'environment' in data and 'files' in data['environment']:
            files = data['environment']['files']
            if isinstance(files, list) and len(files) > 20:
                data['environment']['files'] = files[:20]
                print(f"[*] Truncated environment.files to 20 entries")

        return data
    
    def build_prompt(self) -> str:
        """
        Build complete prompt from persona and input.
        
        Returns:
            Complete prompt string
        """
        if not self.persona:
            raise ValueError("Persona not loaded. Call load_persona() first.")
        if not self.input_data:
            raise ValueError("Input not loaded. Call load_input() first.")
        
        # Build system instruction
        system = self.persona.get('system', '')
        mission = self.persona.get('mission', '')
        output_format = self.persona.get('output_format', '')
        
        # Build user message from input
        user_msg = (
            "Analyze the following execution data and return only the required JSON object.\n"
            "Do not include markdown, headings, or explanatory text.\n\n"
            f"{json.dumps(self.input_data, indent=2)}"
        )
        
        # Combine into full prompt
        full_prompt = f"""{system}

Mission: {mission}

Output Format: {output_format}

User Input:
{user_msg}"""
        
        return full_prompt

    def _post_chat(self, messages: list[dict[str, str]]) -> str:
        """Send a chat request to Ollama and return message content."""
        url = f"{self.ollama_url}/api/chat"

        payload = {
            "model": self.model,
            "messages": messages,
            "stream": False,
            "options": {
                "temperature": 0,
                "top_p": 0.2,
                "num_predict": 512,
            },
        }

        response = requests.post(url, json=payload, timeout=300)
        response.raise_for_status()

        result = response.json()
        return result.get('message', {}).get('content', '').strip()
    
    def query_ollama(self, prompt: str) -> str:
        """
        Send prompt to Ollama and get response.
        
        Args:
            prompt: The prompt to send
            
        Returns:
            Response from Ollama
        """
        try:
            print(f"[*] Sending to Ollama ({self.model})...")
            messages = [
                {
                    "role": "system",
                    "content": (
                        "You are a malware triage engine. "
                        "Return one valid JSON object only. "
                        "The object must contain exactly these keys: "
                        "classification, severity, risk_score, evidence. "
                        "Do not return an empty object."
                    ),
                },
                {
                    "role": "user",
                    "content": prompt,
                },
            ]

            response = self._post_chat(messages)
            if self.validate_output(response) is not None:
                return response

            print("[*] Model returned invalid JSON shape; retrying with stricter instructions...")
            repair_messages = messages + [
                {
                    "role": "assistant",
                    "content": response or "{}",
                },
                {
                    "role": "user",
                    "content": (
                        "Your previous reply was invalid. "
                        "Return exactly one JSON object with keys "
                        "classification, severity, risk_score, evidence. "
                        "severity must be one of Critical, High, Medium, Low. "
                        "risk_score must be an integer from 0 to 100. "
                        "evidence must be a non-empty array of concrete observed behaviors."
                    ),
                },
            ]
            return self._post_chat(repair_messages)
        
        except requests.exceptions.ConnectionError:
            print(f"[!] Error: Could not connect to Ollama at {self.ollama_url}")
            print("[!] Make sure Ollama is running: docker run -d -p 11434:11434 ollama/ollama")
            sys.exit(1)
        except Exception as e:
            print(f"[!] Error querying Ollama: {e}")
            sys.exit(1)

    def validate_output(self, output: str) -> Optional[str]:
        """
        Validate that model output matches the expected compact JSON structure.
        """
        try:
            parsed = json.loads(output)
        except json.JSONDecodeError:
            print("[!] Model output was not valid JSON")
            return None

        if not isinstance(parsed, dict):
            print("[!] Model output was not a JSON object")
            return None

        if set(parsed.keys()) != REQUIRED_KEYS:
            print(f"[!] Model output keys were unexpected: {list(parsed.keys())}")
            return None

        if not isinstance(parsed["classification"], str) or not parsed["classification"].strip():
            print("[!] Invalid classification value")
            return None

        if parsed["severity"] not in {"Critical", "High", "Medium", "Low"}:
            print(f"[!] Invalid severity value: {parsed['severity']}")
            return None

        if not isinstance(parsed["risk_score"], int) or not 0 <= parsed["risk_score"] <= 100:
            print(f"[!] Invalid risk_score value: {parsed['risk_score']}")
            return None

        if not isinstance(parsed["evidence"], list) or not parsed["evidence"]:
            print("[!] Evidence must be a non-empty list")
            return None

        if not all(isinstance(item, str) and item.strip() for item in parsed["evidence"]):
            print("[!] Evidence items must be non-empty strings")
            return None

        return json.dumps(parsed, indent=2)
    
    def analyze(self) -> str:
        """
        Run complete analysis: load → build prompt → query → return.
        
        Returns:
            Analysis result from Ollama
        """
        prompt = self.build_prompt()
        
        print("[*] Prompt:")
        print("=" * 60)
        print(prompt)
        print("=" * 60)
        
        response = self.query_ollama(prompt)
        validated = self.validate_output(response)
        if validated is None:
            raise ValueError("Model output remained invalid after retry.")
        return validated
    
    def save_output(self, output: str, output_file: str = "output.txt") -> None:
        """
        Save response to file.
        
        Args:
            output: The response text
            output_file: Where to save it
        """
        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with output_path.open('w') as f:
            f.write(output)
        print(f"[+] Output saved to {output_path}")


def make_safe_filename(value: str) -> str:
    """Return a filesystem-safe filename fragment."""
    return re.sub(r'[^A-Za-z0-9._-]+', '_', value).strip('._-') or "output"


def main(argv=None):
    """Run one analysis from a JSON verdict file."""
    parser = argparse.ArgumentParser(description="Analyze a malware verdict with Ollama")
    parser.add_argument(
        "input_file",
        nargs="?",
        default="input.json",
        help="JSON verdict file (default: input.json)",
    )
    parser.add_argument(
        "model",
        nargs="?",
        default="qwen2.5-coder:7b",
        help="Ollama model name (default: qwen2.5-coder:7b)",
    )
    parser.add_argument(
        "--persona",
        default=str(DEFAULT_PERSONA_FILE),
        help=f"Persona YAML file (default: {DEFAULT_PERSONA_FILE})",
    )
    parser.add_argument(
        "--output-dir",
        default=str(DEFAULT_OUTPUT_DIR),
        help=f"Directory for analysis output (default: {DEFAULT_OUTPUT_DIR})",
    )
    parser.add_argument(
        "--ollama-url",
        default="http://localhost:11434",
        help="Ollama server URL (default: http://localhost:11434)",
    )
    args = parser.parse_args(argv)

    input_file = args.input_file
    if not os.path.exists(input_file):
        print(f"[!] Error: File not found: {input_file}")
        print("[?] Usage: python3 wrapper.py <json_file> [model_name] [options]")
        print("[?] Example: python3 wrapper.py test_cryptominer.json llama3:latest")
        sys.exit(1)

    # Initialize wrapper
    wrapper = OllamaWrapper(
        ollama_url=args.ollama_url,
        model=args.model,
    )
    
    # Load persona and input
    print(f"[+] Loading persona from: {args.persona}")
    wrapper.load_persona(args.persona)
    
    print(f"[+] Loading input from: {input_file}")
    wrapper.load_input(input_file)
    
    # Run analysis
    print("[+] Starting analysis...")
    output = wrapper.analyze()
    
    # Display result
    print("\n[+] Analysis Result:")
    print("=" * 60)
    print(output)
    print("=" * 60)
    
    # Save to file
    # Get just the filename, not the full path
    #output_filename = os.path.basename(input_file).replace(".json", "_output.txt")
    safe_model = make_safe_filename(args.model)
    output_filename = os.path.basename(input_file).replace(".json", f"_{safe_model}_output.txt")
    output_path = Path(args.output_dir) / output_filename
    wrapper.save_output(output, str(output_path))
    print(f"[+] Output saved to: {output_filename}")



if __name__ == "__main__":
    main()
       
