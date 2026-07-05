#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Update test files with renamed class names
"""

import os
import sys
from pathlib import Path

# Force UTF-8 output
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

PROJECT_ROOT = Path(r"e:\Godot\GodotProjects\project-juicy-godot")
TESTS_DIR = PROJECT_ROOT / "addons" / "bricks" / "tests" / "conditions"

# Class name replacements
CLASS_REPLACEMENTS = [
    ("ConditionNot", "CheckNot"),
    ("ConditionAll", "CheckAll"),
    ("ConditionAny", "CheckAny"),
    ("ConditionComposite", "CheckComposite"),
    ("ConditionNodeActive", "CheckNodeActive"),
    ("ConditionNodeInGroup", "CheckNodeInGroup"),
    ("ConditionOnFloor", "CheckOnFloor"),
    ("ConditionInAir", "CheckInAir"),
    ("ConditionInputPressed", "CheckInputPressed"),
    ("ConditionInputReleased", "CheckInputReleased"),
    ("ConditionInputHeld", "CheckInputHeld"),
    ("ConditionTimeReached", "CheckTimeReached"),
    ("ConditionDistance", "CheckDistance"),
]

TEST_FILES = [
    "test_composite_conditions.gd",
    "test_node_conditions.gd",
    "test_physics_conditions.gd",
    "test_input_conditions.gd",
    "test_time_conditions.gd",
    "test_distance_conditions.gd",
    "test_phase1_integration.gd",
]


def update_test_file(test_file):
    """Update test file with new class names"""
    test_path = TESTS_DIR / test_file

    if not test_path.exists():
        print(f"  [!] Not found: {test_file}")
        return False

    print(f"  Processing: {test_file}")

    # Read file
    try:
        with open(test_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"  [!] Read failed: {e}")
        return False

    original = content

    # Replace all class names
    for old_class, new_class in CLASS_REPLACEMENTS:
        content = content.replace(old_class, new_class)

    # Check if changed
    if content == original:
        print(f"    [INFO] No changes needed")
        return True

    # Write back
    try:
        with open(test_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"    [OK] Updated")
    except Exception as e:
        print(f"  [!] Write failed: {e}")
        return False

    return True


def main():
    print("=" * 60)
    print("  Update Test Files with Renamed Class Names")
    print("=" * 60)
    print(f"Tests directory: {TESTS_DIR}")
    print(f"Files to update: {len(TEST_FILES)}")
    print("")

    success = 0
    for test_file in TEST_FILES:
        if update_test_file(test_file):
            success += 1

    print("")
    print("=" * 60)
    print(f"  Complete: {success}/{len(TEST_FILES)} files updated")
    print("=" * 60)

    return 0


if __name__ == "__main__":
    exit(main())
