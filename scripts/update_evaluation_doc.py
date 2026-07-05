#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Update condition evaluation result document with file names and class names
"""

import sys
import re
from pathlib import Path

# Force UTF-8 output
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

# Document and conditions mapping
DOC_FILE = Path(r"e:\Godot\GodotProjects\project-juicy-godot\addons\bricks\docs\roadmap\2026-01-30-condition-evaluation-result.md")

# Condition info (name → filename, classname, status)
CONDITION_INFO = {
    # P0
    "非": ("composite/check_not.gd", "CheckNot", "✅ 已实现"),
    "节点激活": ("node/check_node_active.gd", "CheckNodeActive", "✅ 已实现"),

    # P1
    "所有条件满足": ("composite/check_all.gd", "CheckAll", "✅ 已实现"),
    "任意条件满足": ("composite/check_any.gd", "CheckAny", "✅ 已实现"),
    "对象距离": ("distance/check_distance.gd", "CheckDistance", "✅ 已实现"),
    "在地面上": ("physics/check_on_floor.gd", "CheckOnFloor", "✅ 已实现"),
    "在空中": ("physics/check_in_air.gd", "CheckInAir", "✅ 已实现"),
    "时间到达": ("time/check_time_reached.gd", "CheckTimeReached", "✅ 已实现"),
    "按键按下": ("input/check_input_pressed.gd", "CheckInputPressed", "✅ 已实现"),
    "按键释放": ("input/check_input_released.gd", "CheckInputReleased", "✅ 已实现"),
    "按键持续按住": ("input/check_input_held.gd", "CheckInputHeld", "✅ 已实现"),
    "节点组检测": ("node/check_node_in_group.gd", "CheckNodeInGroup", "✅ 已实现"),
    "条件组合": ("composite/check_composite.gd", "CheckComposite", "✅ 已实现"),

    # P2
    "正在下落": ("physics/check_is_falling.gd", "CheckIsFalling", "⚠️ 未实现"),
    "动画播放中": ("animation/check_is_playing.gd", "CheckIsPlaying", "⚠️ 未实现"),
    "指定动画": ("animation/check_is_animation.gd", "CheckIsAnimation", "⚠️ 未实现"),
    "倒计时结束": ("time/check_countdown_finished.gd", "CheckCountdownFinished", "⚠️ 未实现"),
    "游戏时间": ("time/check_game_time.gd", "CheckGameTime", "⚠️ 未实现"),
    "节点层次关系": ("node/check_is_child_of.gd", "CheckIsChildOf", "⚠️ 未实现"),
    "生命值检测": ("variable/check_health_value.gd", "CheckHealthValue", "⚠️ 未实现"),
    "动画完成": ("animation/check_animation_finished.gd", "CheckAnimationFinished", "⚠️ 未实现"),
    "速度检测": ("physics/check_velocity.gd", "CheckVelocity", "⚠️ 未实现"),
    "方位检测": ("node/check_direction.gd", "CheckDirection", "⚠️ 未实现"),
    "时间段内": ("time/check_time_range.gd", "CheckTimeRange", "⚠️ 未实现"),
    "生命值低于/高于": ("variable/compare_health_threshold.gd", "CompareHealthThreshold", "⚠️ 未实现"),
    "在墙壁上": ("physics/check_on_wall.gd", "CheckOnWall", "⚠️ 未实现"),
    "方向检测": ("node/check_facing_direction.gd", "CheckFacingDirection", "⚠️ 未实现"),

    # P3
    "正在跳跃": ("physics/check_is_jumping.gd", "CheckIsJumping", "⚠️ 未实现"),
    "冷却完成": ("time/check_cooldown_ready.gd", "CheckCooldownReady", "⚠️ 未实现"),
    "碰撞检测": ("physics/check_is_colliding.gd", "CheckIsColliding", "⚠️ 未实现"),
    "在区域内": ("physics/check_in_area.gd", "CheckInArea", "⚠️ 未实现"),

    # P4
    "animationtree状态机状态": ("animation/check_animationtree_state.gd", "CheckAnimationTreeState", "⚠️ 未实现"),
    "动画帧": ("animation/check_animation_frame.gd", "CheckAnimationFrame", "⚠️ 未实现"),
    "相机视野内": ("camera/check_in_view.gd", "CheckInView", "⚠️ 未实现"),
    "相机模式检测": ("camera/check_camera_mode.gd", "CheckCameraMode", "⚠️ 未实现"),
}

def update_document():
    """Update the evaluation result document"""

    # Read document
    print("读取文档...")
    try:
        with open(DOC_FILE, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"错误: 无法读取文档 - {e}")
        return False

    original_content = content
    updates = 0

    # Update each condition entry
    for condition_name, (filename, classname, status) in CONDITION_INFO.items():
        # Find the condition section (starts with "### [number]. [condition name]")
        # Pattern: "### 1. 非 (Not Condition)"
        pattern = rf"(### \d+\. {re.escape(condition_name)}[^\n]*)"
        replacement = rf"\1\n\n**文件名:** `{filename}`\n**类名:** `{classname}`\n**状态:** {status}"

        new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

        if new_content != content:
            content = new_content
            updates += 1
            print(f"  ✓ 更新: {condition_name} → {filename}")

    # Check if any updates were made
    if content == original_content:
        print("\n无需更新")
        return False

    # Write back
    print(f"\n写入文档...")
    try:
        with open(DOC_FILE, 'w', encoding='utf-8') as f:
            f.write(content)
    except Exception as e:
        print(f"错误: 无法写入文档 - {e}")
        return False

    print(f"\n✅ 成功更新 {updates} 个条件")
    return True


def main():
    print("=" * 60)
    print("  更新条件评估结果文档")
    print("=" * 60)
    print(f"文档: {DOC_FILE}")
    print(f"条件数量: {len(CONDITION_INFO)}")
    print("")

    if update_document():
        print("\n✅ 文档更新完成")
        return 0
    else:
        print("\n没有需要更新的内容")
        return 0


if __name__ == "__main__":
    exit(main())
