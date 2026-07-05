#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Bricks Phase 1 Conditions Batch Rename Script

Rename all condition_ prefixed files to check_ prefix to comply with naming conventions.
Reference: condition_creation_guide.md
"""

import os
import sys
import re
import shutil
from pathlib import Path

# Set UTF-8 encoding for Windows console
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

# 项目根目录
PROJECT_ROOT = Path(r"e:\Godot\GodotProjects\project-juicy-godot")

# 条件目录
CONDITIONS_DIR = PROJECT_ROOT / "addons" / "bricks" / "conditions"

# 重命名映射表
RENAMING_MAP = {
    # 复合逻辑类
    "composite/condition_not.gd": {
        "new_file": "composite/check_not.gd",
        "old_class": "ConditionNot",
        "new_class": "CheckNot"
    },
    "composite/condition_all.gd": {
        "new_file": "composite/check_all.gd",
        "old_class": "ConditionAll",
        "new_class": "CheckAll"
    },
    "composite/condition_any.gd": {
        "new_file": "composite/check_any.gd",
        "old_class": "ConditionAny",
        "new_class": "CheckAny"
    },
    "composite/condition_composite.gd": {
        "new_file": "composite/check_composite.gd",
        "old_class": "ConditionComposite",
        "new_class": "CheckComposite"
    },

    # 节点操作类
    "node/condition_node_active.gd": {
        "new_file": "node/check_node_active.gd",
        "old_class": "ConditionNodeActive",
        "new_class": "CheckNodeActive"
    },
    "node/condition_node_in_group.gd": {
        "new_file": "node/check_node_in_group.gd",
        "old_class": "ConditionNodeInGroup",
        "new_class": "CheckNodeInGroup"
    },

    # 物理检测类
    "physics/condition_on_floor.gd": {
        "new_file": "physics/check_on_floor.gd",
        "old_class": "ConditionOnFloor",
        "new_class": "CheckOnFloor"
    },
    "physics/condition_in_air.gd": {
        "new_file": "physics/check_in_air.gd",
        "old_class": "ConditionInAir",
        "new_class": "CheckInAir"
    },

    # 输入检测类
    "input/condition_input_pressed.gd": {
        "new_file": "input/check_input_pressed.gd",
        "old_class": "ConditionInputPressed",
        "new_class": "CheckInputPressed"
    },
    "input/condition_input_released.gd": {
        "new_file": "input/check_input_released.gd",
        "old_class": "ConditionInputReleased",
        "new_class": "CheckInputReleased"
    },
    "input/condition_input_held.gd": {
        "new_file": "input/check_input_held.gd",
        "old_class": "ConditionInputHeld",
        "new_class": "CheckInputHeld"
    },

    # 时间检测类
    "time/condition_time_reached.gd": {
        "new_file": "time/check_time_reached.gd",
        "old_class": "ConditionTimeReached",
        "new_class": "CheckTimeReached"
    },

    # 距离检测类
    "distance/condition_distance.gd": {
        "new_file": "distance/check_distance.gd",
        "old_class": "ConditionDistance",
        "new_class": "CheckDistance"
    },
}

# 测试文件映射表（需要更新类名引用）
TEST_FILES = [
    "tests/test_composite_conditions.gd",
    "tests/test_node_conditions.gd",
    "tests/test_physics_conditions.gd",
    "tests/test_input_conditions.gd",
    "tests/test_time_conditions.gd",
    "tests/test_distance_conditions.gd",
    "tests/test_phase1_integration.gd",
]


def print_section(title):
    """打印分节标题"""
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


def log_rename(old_path, new_path, old_class, new_class):
    """记录重命名操作"""
    print(f"  文件: {old_path}")
    print(f"    → {new_path}")
    print(f"  类名: {old_class} → {new_class}")


def update_class_names(content, old_class, new_class):
    """
    更新文件内容中的类名引用

    Args:
        content: 文件内容字符串
        old_class: 旧类名
        new_class: 新类名

    Returns:
        更新后的文件内容
    """
    # 替换 class_name 声明
    content = re.sub(
        rf'class_name\s+{re.escape(old_class)}',
        f'class_name {new_class}',
        content
    )

    # 替换类型注解
    content = re.sub(
        rf':\s*{re.escape(old_class)}',
        f': {new_class}',
        content
    )

    # 替换字符串中的类名引用
    content = re.sub(
        rf'"{re.escape(old_class)}"',
        f'"{new_class}"',
        content
    )

    # 替换注释中的类名引用
    content = re.sub(
        rf"'{re.escape(old_class)}'",
        f"'{new_class}'",
        content
    )

    return content


def rename_condition_file(old_file_path, mapping):
    """
    重命名单个条件文件

    Args:
        old_file_path: 旧文件路径（相对路径）
        mapping: 映射字典，包含 new_file, old_class, new_class
    """
    old_full_path = CONDITIONS_DIR / old_file_path
    new_full_path = CONDITIONS_DIR / mapping["new_file"]

    # 检查旧文件是否存在
    if not old_full_path.exists():
        print(f"  [!] File not found, skipping: {old_file_path}")
        return False

    # 检查新文件是否已存在
    if new_full_path.exists():
        print(f"  [!] Target file already exists, skipping: {mapping['new_file']}")
        return False

    # 读取原文件
    print(f"\n  处理: {old_file_path}")
    try:
        with open(old_full_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"  ❌ 读取文件失败: {e}")
        return False

    # 更新类名
    content = update_class_names(content, mapping["old_class"], mapping["new_class"])

    # 写入新文件
    try:
        # 确保目录存在
        new_full_path.parent.mkdir(parents=True, exist_ok=True)

        with open(new_full_path, 'w', encoding='utf-8') as f:
            f.write(content)
    except Exception as e:
        print(f"  ❌ 写入文件失败: {e}")
        return False

    # 删除旧文件
    try:
        old_full_path.unlink()
    except Exception as e:
        print(f"  ⚠️  删除旧文件失败: {e}")
        # 不返回 False，继续处理

    # 重命名 .uid 文件
    old_uid_path = old_full_path.with_suffix('.gd.uid')
    new_uid_path = new_full_path.with_suffix('.gd.uid')

    if old_uid_path.exists():
        try:
            shutil.move(str(old_uid_path), str(new_uid_path))
            print(f"  ✓ .uid 文件已重命名")
        except Exception as e:
            print(f"  ⚠️  重命名 .uid 文件失败: {e}")

    print(f"  ✅ 重命名成功")
    return True


def update_test_file(test_file_path):
    """
    更新测试文件中的所有类名引用

    Args:
        test_file_path: 测试文件路径
    """
    full_path = CONDITIONS_DIR / test_file_path

    if not full_path.exists():
        print(f"  ⚠️  测试文件不存在，跳过: {test_file_path}")
        return False

    print(f"\n  更新测试文件: {test_file_path}")

    try:
        with open(full_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"  ❌ 读取测试文件失败: {e}")
        return False

    # 更新所有类名引用
    original_content = content
    for old_file, mapping in RENAMING_MAP.items():
        content = update_class_names(content, mapping["old_class"], mapping["new_class"])

    # 检查是否有变化
    if content == original_content:
        print(f"  ℹ️  无需更新")
        return True

    # 写回文件
    try:
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  ✓ 测试文件已更新")
    except Exception as e:
        print(f"  ❌ 写入测试文件失败: {e}")
        return False

    return True


def main():
    """主函数"""
    print_section("Bricks Phase 1 Conditions 批量重命名")

    print(f"\n项目根目录: {PROJECT_ROOT}")
    print(f"条件目录: {CONDITIONS_DIR}")

    # 检查目录是否存在
    if not CONDITIONS_DIR.exists():
        print(f"\n❌ 错误: 条件目录不存在")
        print(f"   请确认项目路径是否正确")
        return 1

    print(f"\n📋 将要重命名 {len(RENAMING_MAP)} 个条件文件")
    print(f"📋 将要更新 {len(TEST_FILES)} 个测试文件")

    # 确认操作
    print(f"\n⚠️  警告: 此操作将:")
    print(f"  - 重命名 {len(RENAMING_MAP)} 个条件文件")
    print(f"  - 更新所有类名")
    print(f"  - 更新测试文件中的引用")
    print(f"  - 重命名 .uid 文件")

    response = input("\n是否继续? (yes/no): ").strip().lower()
    if response not in ['yes', 'y']:
        print("操作已取消")
        return 0

    # 执行重命名
    print_section("Step 1: 重命名条件文件")

    success_count = 0
    for old_file, mapping in RENAMING_MAP.items():
        if rename_condition_file(old_file, mapping):
            success_count += 1

    print(f"\n✅ 成功重命名 {success_count}/{len(RENAMING_MAP)} 个条件文件")

    # 更新测试文件
    print_section("Step 2: 更新测试文件引用")

    test_success_count = 0
    for test_file in TEST_FILES:
        if update_test_file(test_file):
            test_success_count += 1

    print(f"\n✅ 成功更新 {test_success_count}/{len(TEST_FILES)} 个测试文件")

    # 总结
    print_section("重命名完成")

    print(f"\n📊 统计:")
    print(f"  重命名的条件文件: {success_count}/{len(RENAMING_MAP)}")
    print(f"  更新的测试文件: {test_success_count}/{len(TEST_FILES)}")

    print(f"\n📝 下一步:")
    print(f"  1. 检查 Git 状态: git status")
    print(f"  2. 运行语法检查: godot --headless --check-only --quit")
    print(f"  3. 运行测试验证功能")
    print(f"  4. 提交更改: git add -A && git commit -m '...' ")

    return 0


if __name__ == "__main__":
    exit(main())
