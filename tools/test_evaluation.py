#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Event 迁移评估工具测试脚本

验证评估工具的准确性：
1. 已迁移的 Event（OnMouseEnter, OnMouseExit）
2. 无状态 Event（OnReady）
3. 高优先级 Event（OnInputKey）
"""

import sys
import os
from pathlib import Path

# 设置 UTF-8 编码
if sys.platform == 'win32':
    os.system('')

# 添加 tools 目录到路径
tools_dir = Path(__file__).parent
sys.path.insert(0, str(tools_dir))

from evaluate_events_migration import EventEvaluator, EventEvaluation


def test_migrated_events():
    """测试已迁移的 Event"""
    print("\n" + "="*60)
    print("测试 1: 已迁移的 Event")
    print("="*60)

    project_root = Path(__file__).parent.parent

    # 测试已迁移的 Event（使用实际文件名）
    migrated_files = [
        ("OnMouseEnter", "input/on_mouse_enter.gd"),
        ("OnMouseExit", "input/on_mouse_exit.gd")
    ]

    for event_name, relative_path in migrated_files:
        event_path = project_root / "addons" / "bricks" / "events" / relative_path

        if not event_path.exists():
            print(f"X FAIL: {event_name} 文件不存在: {event_path}")
            return False

        # 读取文件内容验证
        with open(event_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # 检查是否包含 RuntimeInstance
        has_runtime_instance = (
            "RuntimeEventInstance" in content and
            "initialize_with_runtime_instance" in content
        )

        if not has_runtime_instance:
            print(f"X FAIL: {event_name} 应该已迁移但未检测到 RuntimeInstance")
            return False

        print(f"OK PASS: {event_name} 已正确迁移")

    return True


def test_no_state_events():
    """测试无状态 Event"""
    print("\n" + "="*60)
    print("测试 2: 无状态 Event")
    print("="*60)

    project_root = Path(__file__).parent.parent
    evaluator = EventEvaluator(str(project_root / "addons" / "bricks"), verbose=False)

    # 测试无状态的 Event（使用实际文件名）
    # 注意：OnReady 有 _timer 状态变量，所以不是无状态 Event
    no_state_files = [
        ("OnNodeInstance", "node/on_node_instance.gd"),
        ("OnAnimationFinished", "animation/on_animation_finished.gd"),
        ("OnSceneLoaded", "scene/on_scene_loaded.gd"),
        ("OnTreeChanged", "scene/on_tree_changed.gd"),
        ("OnCollision", "physics/on_collision.gd"),
    ]

    for event_name, relative_path in no_state_files:
        event_path = project_root / "addons" / "bricks" / "events" / relative_path

        if not event_path.exists():
            print(f"? SKIP: {event_name} 文件未找到")
            continue

        evaluation = evaluator._evaluate_event(event_path)

        if evaluation is None:
            print(f"X FAIL: {event_name} 评估失败")
            return False

        if evaluation.has_state:
            print(f"X FAIL: {event_name} 应该无状态但检测到状态: {evaluation.state_variables}")
            return False

        if evaluation.priority != "none":
            print(f"X FAIL: {event_name} 优先级应该是 'none' 但实际是 '{evaluation.priority}'")
            return False

        if evaluation.should_migrate:
            print(f"X FAIL: {event_name} 不应该需要迁移")
            return False

        print(f"OK PASS: {event_name} 正确识别为无状态 Event")

    return True


def test_high_priority_events():
    """测试高优先级 Event"""
    print("\n" + "="*60)
    print("测试 3: 高优先级 Event")
    print("="*60)

    project_root = Path(__file__).parent.parent
    evaluator = EventEvaluator(str(project_root / "addons" / "bricks"), verbose=False)

    # 测试应该被识别为高优先级的 Event（使用实际文件名）
    high_priority_files = [
        ("OnInputKey", "input/on_input_key.gd"),
        ("OnInterval", "lifecycle/on_interval.gd"),
        ("OnArea2DEnter", "physics/on_area_2d_enter.gd"),
        ("OnArea3DEntered", "physics/on_area_3d_entered.gd"),
        ("OnTimer", "timing/on_timer.gd"),
        ("OnCooldownFinished", "timing/on_cooldown_finished.gd"),
    ]

    for event_name, relative_path in high_priority_files:
        event_path = project_root / "addons" / "bricks" / "events" / relative_path

        if not event_path.exists():
            print(f"? SKIP: {event_name} 文件未找到")
            continue

        evaluation = evaluator._evaluate_event(event_path)

        if evaluation is None:
            print(f"X FAIL: {event_name} 评估失败")
            return False

        if not evaluation.has_state:
            print(f"X FAIL: {event_name} 应该有状态")
            return False

        if evaluation.priority != "high":
            print(f"X FAIL: {event_name} 优先级应该是 'high' 但实际是 '{evaluation.priority}'")
            return False

        if not evaluation.should_migrate:
            print(f"X FAIL: {event_name} 应该需要迁移")
            return False

        if evaluation.sharing_risk != "high":
            print(f"X FAIL: {event_name} 共享风险应该是 'high' 但实际是 '{evaluation.sharing_risk}'")
            return False

        vars_str = ', '.join(evaluation.state_variables[:3])
        print(f"OK PASS: {event_name} 正确识别为高优先级")
        print(f"         状态变量: {vars_str}")

    return True


def test_evaluation_counts():
    """测试评估计数准确性"""
    print("\n" + "="*60)
    print("测试 4: 评估计数准确性")
    print("="*60)

    project_root = Path(__file__).parent.parent
    evaluator = EventEvaluator(str(project_root / "addons" / "bricks"), verbose=False)

    # 运行完整评估
    evaluations = evaluator.evaluate_all()

    # 统计
    total = len(evaluations)
    migrated = sum(1 for e in evaluations if e.is_migrated)
    high_priority = sum(1 for e in evaluations if e.priority == "high")
    medium_priority = sum(1 for e in evaluations if e.priority == "medium")
    should_migrate = sum(1 for e in evaluations if e.should_migrate)

    print(f"总 Event 数: {total}")
    print(f"已迁移: {migrated}")
    print(f"高优先级: {high_priority}")
    print(f"中优先级: {medium_priority}")
    print(f"需要迁移: {should_migrate}")

    # 验证
    errors = []

    if total != 59:
        errors.append(f"总 Event 数应该是 59，实际是 {total}")

    if migrated != 2:
        errors.append(f"已迁移 Event 数应该是 2，实际是 {migrated}")

    if high_priority != 7:
        errors.append(f"高优先级 Event 数应该是 7，实际是 {high_priority}")

    if medium_priority != 3:
        errors.append(f"中优先级 Event 数应该是 3，实际是 {medium_priority}")

    if should_migrate != 10:
        errors.append(f"需要迁移的 Event 数应该是 10，实际是 {should_migrate}")

    if errors:
        for error in errors:
            print(f"X FAIL: {error}")
        return False

    print("OK PASS: 所有计数正确")
    return True


def main():
    """运行所有测试"""
    print("\n" + "="*60)
    print("Event 迁移评估工具测试")
    print("="*60)

    tests = [
        ("已迁移的 Event", test_migrated_events),
        ("无状态 Event", test_no_state_events),
        ("高优先级 Event", test_high_priority_events),
        ("评估计数准确性", test_evaluation_counts),
    ]

    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"\nX EXCEPTION in {test_name}: {e}")
            import traceback
            traceback.print_exc()
            results.append((test_name, False))

    # 总结
    print("\n" + "="*60)
    print("测试总结")
    print("="*60)

    passed = sum(1 for _, result in results if result)
    total = len(results)

    for test_name, result in results:
        status = "OK PASS" if result else "X FAIL"
        print(f"{status}: {test_name}")

    print("\n" + "="*60)
    print(f"通过: {passed}/{total}")
    print("="*60)

    if passed == total:
        print("\nOK 所有测试通过！")
        return 0
    else:
        print(f"\nX {total - passed} 个测试失败")
        return 1


if __name__ == "__main__":
    sys.exit(main())
