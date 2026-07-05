#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Extract class names from condition files
"""

import os
import sys
import re
from pathlib import Path

# Force UTF-8 output
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

PROJECT_ROOT = Path(r"e:\Godot\GodotProjects\project-juicy-godot")
CONDITIONS_DIR = PROJECT_ROOT / "addons" / "bricks" / "conditions"

# Extract class_name from file
def extract_class_name(file_path):
    """Extract class_name from .gd file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            # Find class_name declaration
            match = re.search(r'class_name\s+(\S+)', content)
            if match:
                return match.group(1)
    except Exception as e:
        pass
    return None

# Get all check files and extract class names
condition_info = {}
for check_file in sorted(CONDITIONS_DIR.rglob("check_*.gd")):
    class_name = extract_class_name(check_file)
    if class_name:
        relative_path = check_file.relative_to(CONDITIONS_DIR)
        condition_info[str(relative_path).replace("\\", "/")] = class_name

# Print as markdown table
print("\n### 已实现的条件列表\n")
print("| 文件名 | 类名 |")
print("|--------|------|")
for file_path in sorted(condition_info.keys()):
    print(f"| `{file_path}` | `{condition_info[file_path]}` |")
