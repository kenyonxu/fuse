#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Bricks Phase 1 Conditions Batch Rename Script (Simplified)
"""

import os
import sys
import shutil
from pathlib import Path

# Force UTF-8 output
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

PROJECT_ROOT = Path(r"e:\Godot\GodotProjects\project-juicy-godot")
CONDITIONS_DIR = PROJECT_ROOT / "addons" / "bricks" / "conditions"

# Renaming map
RENAMING_MAP = [
    # Composite
    ("composite/condition_not.gd", "composite/check_not.gd", "ConditionNot", "CheckNot"),
    ("composite/condition_all.gd", "composite/check_all.gd", "ConditionAll", "CheckAll"),
    ("composite/condition_any.gd", "composite/check_any.gd", "ConditionAny", "CheckAny"),
    ("composite/condition_composite.gd", "composite/check_composite.gd", "ConditionComposite", "CheckComposite"),
    # Node
    ("node/condition_node_active.gd", "node/check_node_active.gd", "ConditionNodeActive", "CheckNodeActive"),
    ("node/condition_node_in_group.gd", "node/check_node_in_group.gd", "ConditionNodeInGroup", "CheckNodeInGroup"),
    # Physics
    ("physics/condition_on_floor.gd", "physics/check_on_floor.gd", "ConditionOnFloor", "CheckOnFloor"),
    ("physics/condition_in_air.gd", "physics/check_in_air.gd", "ConditionInAir", "CheckInAir"),
    # Input
    ("input/condition_input_pressed.gd", "input/check_input_pressed.gd", "ConditionInputPressed", "CheckInputPressed"),
    ("input/condition_input_released.gd", "input/check_input_released.gd", "ConditionInputReleased", "CheckInputReleased"),
    ("input/condition_input_held.gd", "input/check_input_held.gd", "ConditionInputHeld", "CheckInputHeld"),
    # Time
    ("time/condition_time_reached.gd", "time/check_time_reached.gd", "ConditionTimeReached", "CheckTimeReached"),
    # Distance
    ("distance/condition_distance.gd", "distance/check_distance.gd", "ConditionDistance", "CheckDistance"),
]

TEST_FILES = [
    "tests/test_composite_conditions.gd",
    "tests/test_node_conditions.gd",
    "tests/test_physics_conditions.gd",
    "tests/test_input_conditions.gd",
    "tests/test_time_conditions.gd",
    "tests/test_distance_conditions.gd",
    "tests/test_phase1_integration.gd",
]


def rename_condition_file(old_file, new_file, old_class, new_class):
    """Rename single condition file"""
    old_path = CONDITIONS_DIR / old_file
    new_path = CONDITIONS_DIR / new_file

    if not old_path.exists():
        print(f"  [!] File not found: {old_file}")
        return False

    if new_path.exists():
        print(f"  [!] Target exists: {new_file}")
        return False

    # Read and replace
    with open(old_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace class names
    content = content.replace(f"class_name {old_class}", f"class_name {new_class}")
    content = content.replace(f": {old_class}", f": {new_class}")
    content = content.replace(f'"{old_class}"', f'"{new_class}"')
    content = content.replace(f"'{old_class}'", f"'{new_class}'")

    # Write new file
    new_path.parent.mkdir(parents=True, exist_ok=True)
    with open(new_path, 'w', encoding='utf-8') as f:
        f.write(content)

    # Remove old file
    old_path.unlink()

    # Rename .uid file
    old_uid = old_path.with_suffix('.gd.uid')
    new_uid = new_path.with_suffix('.gd.uid')
    if old_uid.exists():
        shutil.move(str(old_uid), str(new_uid))

    print(f"  [OK] {old_file} -> {new_file}")
    print(f"       {old_class} -> {new_class}")
    return True


def update_test_file(test_file):
    """Update test file"""
    test_path = CONDITIONS_DIR / test_file

    if not test_path.exists():
        print(f"  [!] Test file not found: {test_file}")
        return False

    with open(test_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    # Replace all class names
    for old_file, new_file, old_class, new_class in RENAMING_MAP:
        content = content.replace(old_class, new_class)

    if content == original:
        print(f"  [INFO] No changes needed: {test_file}")
        return True

    with open(test_path, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"  [OK] Updated: {test_file}")
    return True


def main():
    print("=" * 60)
    print("  Bricks Phase 1 Conditions Batch Rename")
    print("=" * 60)
    print(f"Project: {PROJECT_ROOT}")
    print(f"Conditions: {CONDITIONS_DIR}")
    print(f"")
    print(f"Will rename {len(RENAMING_MAP)} condition files")
    print(f"Will update {len(TEST_FILES)} test files")
    print("")

    # Execute renaming
    print("=" * 60)
    print("  Step 1: Rename Condition Files")
    print("=" * 60)

    success = 0
    for old_file, new_file, old_class, new_class in RENAMING_MAP:
        if rename_condition_file(old_file, new_file, old_class, new_class):
            success += 1

    print("")
    print(f"Renamed: {success}/{len(RENAMING_MAP)} files")

    # Update tests
    print("")
    print("=" * 60)
    print("  Step 2: Update Test Files")
    print("=" * 60)

    test_success = 0
    for test_file in TEST_FILES:
        if update_test_file(test_file):
            test_success += 1

    print("")
    print(f"Updated: {test_success}/{len(TEST_FILES)} test files")

    # Summary
    print("")
    print("=" * 60)
    print("  Rename Complete")
    print("=" * 60)
    print("")
    print("Next steps:")
    print("  1. Check Git status: git status")
    print("  2. Run syntax check: godot --headless --check-only --quit")
    print("  3. Run tests")
    print("  4. Commit changes")

    return 0


if __name__ == "__main__":
    exit(main())
