#!/usr/bin/env python3
import sys, os

# Add current directory to path to find extract_files
sys.path.insert(0, os.path.dirname(__file__))
from extract_files import detokenize_applesoft

# Use relative path
EXTRACTED = os.path.join(os.path.dirname(os.path.dirname(__file__)), "extracted")

# Create detokenized directory
DETOKENIZED = os.path.join(os.path.dirname(os.path.dirname(__file__)), "detokenized")
os.makedirs(DETOKENIZED, exist_ok=True)

for name in sys.argv[1:]:
    path = os.path.join(EXTRACTED, name)
    with open(path, 'rb') as f:
        data = f.read()
    print(f"========== {name} ==========")
    detokenized = detokenize_applesoft(data)
    print(detokenized[:500] + "..." if len(detokenized) > 500 else detokenized)
    print()
    
    # Save to file
    output_path = os.path.join(DETOKENIZED, name)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(detokenized)
