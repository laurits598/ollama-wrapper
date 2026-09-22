
import subprocess
import os
# Loop through files in Output directory
for filename in os.listdir("Output"):
    if filename.endswith(".txt"):
        print(f"[+] Checking output file: {filename}")
        with open(os.path.join("Output", filename), 'r') as f:
            content = f.read()
            if "## Risk Level" not in content:
                print(f"[!] Warning: Output file {filename} does not contain '## Risk Level' section. Check the response format.")
            else:
                print(f"[+] {filename} ")
                subprocess.run(f"cat {os.path.join('Output', filename)} | grep \"Risk Level\" -A1", shell=True) 
                print("-" * 60)
                #subprocess.run(f"cat Output/listen.sh_20260612_195044_942013_llama3.1:latest_output.txt | grep 'Risk' -A1", shell=True) 
