# Event RuntimeInstance 迁移评估计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**目标:** 系统评估所有已实现的 Bricks Event，判断是否需要迁移到 RuntimeInstance 架构，并生成迁移优先级报告。

**架构:** 基于 `event-runtime-instance-checklist.md` 的决策标准，自动化扫描所有 Event 文件，识别运行时状态变量，评估共享风险，生成可执行的迁移计划。

**技术栈:**
- Godot 4.6 GDScript
- Python 3.x（评估脚本）
- 静态代码分析
- Markdown 报告生成

---

## 概述

Bricks 插件中有 60+ 个已实现的 Event 类。并非所有 Event 都需要迁移到 RuntimeInstance 架构。本计划将：

1. **扫描所有 Event 文件**：提取状态变量、使用模式
2. **应用决策矩阵**：基于状态和共享风险评估
3. **生成迁移报告**：分类为需要迁移/可选迁移/不需要迁移
4. **创建优先级列表**：按影响程度排序

**评估标准**（来自检查清单）：

| 状态变量 | 共享风险 | 是否迁移 | 优先级 |
|---------|---------|---------|--------|
| ✅ 有状态 | ✅ 高 | **是** | 🔴 高 |
| ✅ 有状态 | ⚠️ 中 | **建议** | 🟡 中 |
| ✅ 有状态 | ❌ 低 | 可选 | 🟢 低 |
| ❌ 无状态 | 任何 | **否** | - |

---

## Task 1: 创建评估脚本框架

**Files:**
- Create: `tools/evaluate_events_migration.py`

**Step 1: 创建脚本基础结构**

```python
#!/usr/bin/env python3
"""
Bricks Event RuntimeInstance 迁移评估工具

评估所有 Event 是否需要迁移到 RuntimeInstance 架构
"""

import os
import re
from pathlib import Path
from typing import Dict, List, Tuple
from dataclasses import dataclass
from datetime import datetime

@dataclass
class EventEvaluation:
    """单个 Event 的评估结果"""
    event_name: str
    event_path: str
    has_state: bool
    state_variables: List[str]
    sharing_risk: str  # "high", "medium", "low"
    should_migrate: bool
    priority: str  # "high", "medium", "low", "none"
    reasoning: str

class EventEvaluator:
    """Event 迁移评估器"""

    def __init__(self, bricks_root: str):
        self.bricks_root = Path(bricks_root)
        self.events_dir = self.bricks_root / "events"
        self.evaluations: List[EventEvaluation] = []

    def evaluate_all(self) -> List[EventEvaluation]:
        """评估所有 Event"""
        # 实现
        pass

    def generate_report(self, output_path: str):
        """生成 Markdown 报告"""
        # 实现
        pass
```

**Step 2: 添加执行入口**

```python
def main():
    """主函数"""
    # 假设从项目根目录运行
    project_root = Path(__file__).parent.parent
    evaluator = EventEvaluator(str(project_root / "addons" / "bricks"))

    # 评估所有 Event
    evaluations = evaluator.evaluate_all()

    # 生成报告
    report_path = project_root / "docs" / "reports" / f"event_migration_evaluation_{datetime.now().strftime('%Y%m%d')}.md"
    evaluator.generate_report(str(report_path))

    print(f"评估完成！报告已生成：{report_path}")
    print(f"共评估 {len(evaluations)} 个 Event")

if __name__ == "__main__":
    main()
```

**Step 3: 创建可执行文件**

Run: `chmod +x tools/evaluate_events_migration.py`

**Step 4: 提交脚本框架**

```bash
git add tools/evaluate_events_migration.py
git commit -m "feat: 添加 Event RuntimeInstance 迁移评估脚本框架"
```

---

## Task 2: 实现 Event 文件扫描

**Files:**
- Modify: `tools/evaluate_events_migration.py`

**Step 1: 实现 Event 发现逻辑**

```python
class EventEvaluator:
    """Event 迁移评估器"""

    # 运行时状态变量模式
    STATE_PATTERNS = [
        r'_has_triggered\s*[:=]',
        r'_is_hovered\s*[:=]',
        r'_has_exited\s*[:=]',
        r'_is_active\s*[:=]',
        r'_is_running\s*[:=]',
        r'_trigger_count\s*[:=]',
        r'_execution_count\s*[:=]',
        r'_last_trigger_time\s*[:=]',
        r'_last_time\s*[:=]',
        r'_timer\s*[:=]',
        r'_tween\s*[:=]',
    ]

    def _find_all_event_files(self) -> List[Path]:
        """查找所有 Event 文件"""
        event_files = []
        for event_file in self.events_dir.rglob("*.gd"):
            # 跳过测试文件
            if "test_" in event_file.name:
                continue
            event_files.append(event_file)
        return event_files
```

**Step 2: 实现状态变量检测**

```python
    def _detect_state_variables(self, content: str) -> List[str]:
        """检测 Event 中的运行时状态变量"""
        state_vars = []

        for pattern in self.STATE_PATTERNS:
            matches = re.findall(pattern, content)
            for match in matches:
                # 提取变量名
                var_name = match.split('_')[0] + '_' + match.split('_')[1].split(':')[0].split('=')[0]
                if var_name not in state_vars:
                    state_vars.append(var_name)

        return state_vars
```

**Step 3: 实现 evaluate_all 方法**

```python
    def evaluate_all(self) -> List[EventEvaluation]:
        """评估所有 Event"""
        event_files = self._find_all_event_files()

        for event_file in event_files:
            evaluation = self._evaluate_event(event_file)
            self.evaluations.append(evaluation)

        return self.evaluations
```

**Step 4: 测试扫描功能**

```bash
python3 tools/evaluate_events_migration.py
```

Expected: 脚本运行但不报错（还没有实际评估逻辑）

**Step 5: 提交扫描实现**

```bash
git add tools/evaluate_events_migration.py
git commit -m "feat: 实现 Event 文件扫描和状态变量检测"
```

---

## Task 3: 实现迁移决策逻辑

**Files:**
- Modify: `tools/evaluate_events_migration.py`

**Step 1: 实现单个 Event 评估**

```python
    def _evaluate_event(self, event_path: Path) -> EventEvaluation:
        """评估单个 Event"""
        with open(event_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # 提取 Event 名称
        event_name = event_path.stem
        class_match = re.search(r'class_name\s+(\w+)', content)
        if class_match:
            event_name = class_match.group(1)

        # 检测状态变量
        state_vars = self._detect_state_variables(content)
        has_state = len(state_vars) > 0

        # 评估共享风险
        sharing_risk = self._assess_sharing_risk(event_name, content)

        # 决策矩阵
        should_migrate, priority, reasoning = self._apply_decision_matrix(
            has_state, sharing_risk, state_vars
        )

        return EventEvaluation(
            event_name=event_name,
            event_path=str(event_path.relative_to(self.bricks_root.parent)),
            has_state=has_state,
            state_variables=state_vars,
            sharing_risk=sharing_risk,
            should_migrate=should_migrate,
            priority=priority,
            reasoning=reasoning
        )
```

**Step 2: 实现共享风险评估**

```python
    def _assess_sharing_risk(self, event_name: str, content: str) -> str:
        """评估共享风险"""
        # 高风险：常用 Event
        high_risk_events = [
            'OnMouseEnter', 'OnMouseExit', 'OnInterval',
            'OnInputKey', 'OnMouseButton', 'OnArea2DEnter',
            'OnArea3DEntered', 'OnTimer', 'OnCooldown'
        ]

        # 中风险：通用 Event
        medium_risk_patterns = [
            'OnSignal', 'OnPropertyChanged', 'OnVariableChanged'
        ]

        if any(pattern in event_name for pattern in high_risk_events):
            return "high"
        elif any(pattern in event_name for pattern in medium_risk_patterns):
            return "medium"
        else:
            return "low"
```

**Step 3: 实现决策矩阵**

```python
    def _apply_decision_matrix(
        self,
        has_state: bool,
        sharing_risk: str,
        state_vars: List[str]
    ) -> Tuple[bool, str, str]:
        """应用决策矩阵"""

        if not has_state:
            return False, "none", "无运行时状态，不需要迁移"

        if sharing_risk == "high":
            return True, "high", f"有状态变量 ({', '.join(state_vars)}) + 高共享风险 = 强烈建议迁移"

        if sharing_risk == "medium":
            return True, "medium", f"有状态变量 ({', '.join(state_vars)}) + 中共享风险 = 建议迁移"

        # low risk
        return False, "low", f"有状态变量 ({', '.join(state_vars)}) + 低共享风险 = 可选迁移"
```

**Step 4: 测试评估逻辑**

Run: `python3 tools/evaluate_events_migration.py`

Expected: 打印评估进度和统计信息

**Step 5: 提交决策逻辑**

```bash
git add tools/evaluate_events_migration.py
git commit -m "feat: 实现迁移决策矩阵和风险评估逻辑"
```

---

## Task 4: 实现 Markdown 报告生成

**Files:**
- Modify: `tools/evaluate_events_migration.py`

**Step 1: 实现报告生成方法**

```python
    def generate_report(self, output_path: str):
        """生成 Markdown 报告"""
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        with open(output_path, 'w', encoding='utf-8') as f:
            # 报告头部
            f.write(self._generate_header())

            # 执行摘要
            f.write(self._generate_summary())

            # 详细评估结果
            f.write(self._generate_detailed_results())

            # 迁移优先级列表
            f.write(self._generate_priority_list())

        print(f"\n✅ 报告已生成：{output_path}")
```

**Step 2: 实现报告头部**

```python
    def _generate_header(self) -> str:
        """生成报告头部"""
        return f"""# Bricks Event RuntimeInstance 迁移评估报告

> **生成时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
> **评估工具**: `tools/evaluate_events_migration.py`
> **参考标准**: `addons/bricks/docs/development/event-runtime-instance-checklist.md`

---

## 📊 执行摘要

"""
```

**Step 3: 实现摘要部分**

```python
    def _generate_summary(self) -> str:
        """生成执行摘要"""
        total = len(self.evaluations)
        need_migration = sum(1 for e in self.evaluations if e.should_migrate)
        high_priority = sum(1 for e in self.evaluations if e.priority == "high")
        medium_priority = sum(1 for e in self.evaluations if e.priority == "medium")
        no_state = sum(1 for e in self.evaluations if not e.has_state)

        return f"""
| 指标 | 数量 | 占比 |
|------|------|------|
| **总 Event 数** | {total} | 100% |
| **需要迁移** | {need_migration} | {need_migration/total*100:.1f}% |
| **高优先级** | {high_priority} | {high_priority/total*100:.1f}% |
| **中优先级** | {medium_priority} | {medium_priority/total*100:.1f}% |
| **无状态（不需要迁移）** | {no_state} | {no_state/total*100:.1f}% |

---
"""
```

**Step 4: 实现详细结果表格**

```python
    def _generate_detailed_results(self) -> str:
        """生成详细评估结果"""
        output = "## 📋 详细评估结果\n\n"
        output += "| Event | 状态变量 | 共享风险 | 优先级 | 是否迁移 | 原因 |\n"
        output += "|-------|---------|---------|--------|---------|------|\n"

        for eval in sorted(self.evaluations, key=lambda e: e.event_name):
            state_str = ', '.join(eval.state_variables) if eval.state_variables else '-'
            priority_icon = {
                'high': '🔴',
                'medium': '🟡',
                'low': '🟢',
                'none': '⚪'
            }.get(eval.priority, '')
            migrate_str = '✅' if eval.should_migrate else '❌'

            output += f"| [{eval.event_name}]({eval.event_path}) | {state_str} | {eval.sharing_risk} | {priority_icon} {eval.priority} | {migrate_str} | {eval.reasoning} |\n"

        output += "\n---\n\n"
        return output
```

**Step 5: 运行并查看报告**

Run:
```bash
python3 tools/evaluate_events_migration.py
cat docs/reports/event_migration_evaluation_*.md
```

Expected: 完整的 Markdown 报告

**Step 6: 提交报告生成**

```bash
git add tools/evaluate_events_migration.py
git commit -m "feat: 实现 Markdown 评估报告生成"
```

---

## Task 5: 创建优先级分组报告

**Files:**
- Modify: `tools/evaluate_events_migration.py`

**Step 1: 实现优先级列表生成**

```python
    def _generate_priority_list(self) -> str:
        """生成迁移优先级列表"""
        output = "## 🎯 迁移优先级\n\n"

        # 高优先级
        high_priority = [e for e in self.evaluations if e.priority == "high"]
        if high_priority:
            output += "### 🔴 高优先级（强烈建议迁移）\n\n"
            output += "这些 Event 有运行时状态且共享风险高，应优先迁移：\n\n"
            for eval in high_priority:
                output += f"- **{eval.event_name}** - {eval.reasoning}\n"
                output += f"  - 文件: `{eval.event_path}`\n"
                output += f"  - 状态变量: {', '.join(eval.state_variables)}\n\n"
            output += "---\n\n"

        # 中优先级
        medium_priority = [e for e in self.evaluations if e.priority == "medium"]
        if medium_priority:
            output += "### 🟡 中优先级（建议迁移）\n\n"
            output += "这些 Event 有运行时状态且共享风险中等，建议迁移：\n\n"
            for eval in medium_priority:
                output += f"- **{eval.event_name}** - {eval.reasoning}\n"
            output += "---\n\n"

        # 低优先级
        low_priority = [e for e in self.evaluations if e.priority == "low"]
        if low_priority:
            output += "### 🟢 低优先级（可选迁移）\n\n"
            output += "这些 Event 有运行时状态但共享风险低，可以按需迁移：\n\n"
            for eval in low_priority:
                output += f"- **{eval.event_name}** - {eval.reasoning}\n"
            output += "---\n\n"

        # 不需要迁移
        no_migration = [e for e in self.evaluations if e.priority == "none"]
        if no_migration:
            output += "### ⚪ 不需要迁移\n\n"
            output += f"这些 Event 无运行时状态，不需要迁移（共 {len(no_migration)} 个）：\n\n"
            for eval in no_migration:
                output += f"- **{eval.event_name}** - {eval.reasoning}\n"

        return output
```

**Step 2: 添加迁移建议章节**

```python
    def _generate_migration_recommendations(self) -> str:
        """生成迁移建议"""
        output = "## 💡 迁移建议\n\n"

        high_count = sum(1 for e in self.evaluations if e.priority == "high")
        medium_count = sum(1 for e in self.evaluations if e.priority == "medium")
        total_migrate = high_count + medium_count

        output += f"""
### 迁移策略

建议采用**渐进式迁移**策略：

1. **第一阶段**（已迁移 ✅）
   - OnMouseEnter
   - OnMouseExit
   - OnInterval

2. **第二阶段**（高优先级，共 {high_count} 个）
   - 迁移所有高优先级 Event
   - 重点解决用户反馈的问题

3. **第三阶段**（中优先级，共 {medium_count} 个）
   - 按需迁移中优先级 Event
   - 根据用户使用情况决定

### 迁移顺序

根据依赖关系和使用频率，建议迁移顺序：

"""

        # 按分类排序
        categories = {}
        for eval in self.evaluations:
            if eval.priority in ['high', 'medium']:
                category = eval.event_path.split('/')[2]  # input, physics, etc.
                if category not in categories:
                    categories[category] = []
                categories[category].append(eval)

        for category, events in sorted(categories.items()):
            output += f"\n#### {category.upper()}\n\n"
            for eval in sorted(events, key=lambda e: e.event_name):
                output += f"- {eval.event_name}\n"

        output += "\n---\n\n"
        return output
```

**Step 3: 更新报告生成调用**

```python
    def generate_report(self, output_path: str):
        """生成 Markdown 报告"""
        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(self._generate_header())
            f.write(self._generate_summary())
            f.write(self._generate_detailed_results())
            f.write(self._generate_priority_list())
            f.write(self._generate_migration_recommendations())

        print(f"\n✅ 报告已生成：{output_path}")
```

**Step 4: 运行完整评估**

Run:
```bash
python3 tools/evaluate_events_migration.py
```

Expected: 生成完整报告，包含优先级和建议

**Step 5: 提交优先级报告**

```bash
git add tools/evaluate_events_migration.py
git commit -m "feat: 添加迁移优先级列表和建议章节"
```

---

## Task 6: 添加命令行参数支持

**Files:**
- Modify: `tools/evaluate_events_migration.py`

**Step 1: 添加 argparse 支持**

```python
import argparse

def main():
    """主函数"""
    parser = argparse.ArgumentParser(
        description='评估 Bricks Event 是否需要迁移到 RuntimeInstance 架构'
    )
    parser.add_argument(
        '--output', '-o',
        type=str,
        default=None,
        help='输出报告路径（默认：docs/reports/event_migration_evaluation_YYYYMMDD.md）'
    )
    parser.add_argument(
        '--filter', '-f',
        type=str,
        choices=['all', 'high', 'medium', 'low'],
        default='all',
        help='过滤结果（默认：all）'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='显示详细输出'
    )

    args = parser.parse_args()

    # 假设从项目根目录运行
    project_root = Path(__file__).parent.parent
    evaluator = EventEvaluator(str(project_root / "addons" / "bricks"))

    # 评估所有 Event
    evaluations = evaluator.evaluate_all()

    if args.verbose:
        print(f"\n评估结果：")
        for eval in evaluations:
            print(f"  {eval.event_name}: {eval.priority} - {eval.reasoning}")

    # 生成报告
    if args.output is None:
        report_path = project_root / "docs" / "reports" / f"event_migration_evaluation_{datetime.now().strftime('%Y%m%d')}.md"
    else:
        report_path = Path(args.output)

    evaluator.generate_report(str(report_path))

    print(f"\n✅ 评估完成！")
    print(f"共评估 {len(evaluations)} 个 Event")
    print(f"报告已生成：{report_path}")
```

**Step 2: 测试命令行参数**

Run:
```bash
python3 tools/evaluate_events_migration.py --help
python3 tools/evaluate_events_migration.py --verbose
python3 tools/evaluate_events_migration.py -o /tmp/test_report.md
```

Expected: 参数正常工作

**Step 3: 提交命令行支持**

```bash
git add tools/evaluate_events_migration.py
git commit -m "feat: 添加命令行参数支持和详细输出模式"
```

---

## Task 7: 执行完整评估并生成报告

**Files:**
- Create: `docs/reports/event_migration_evaluation_YYYYMMDD.md`

**Step 1: 运行完整评估**

Run:
```bash
python3 tools/evaluate_events_migration.py --verbose
```

Expected Output:
```
评估结果：
  OnMouseEnter: high - 有状态变量 (_is_hovered) + 高共享风险 = 强烈建议迁移
  OnMouseExit: high - 有状态变量 (_has_exited) + 高共享风险 = 强烈建议迁移
  OnInterval: high - 有状态变量 (_timer) + 高共享风险 = 强烈建议迁移
  OnReady: none - 无运行时状态，不需要迁移
  ...

✅ 评估完成！
共评估 62 个 Event
报告已生成：docs/reports/event_migration_evaluation_20250203.md
```

**Step 2: 查看生成的报告**

Run:
```bash
cat docs/reports/event_migration_evaluation_*.md
```

Expected: 完整的 Markdown 报告，包含：
- 执行摘要
- 详细评估结果表格
- 优先级分组
- 迁移建议

**Step 3: 添加报告到 Git**

Run:
```bash
git add docs/reports/event_migration_evaluation_*.md
git commit -m "docs: 添加 Event RuntimeInstance 迁移评估报告"

# 或者如果报告是自动生成的，添加到 .gitignore
echo "docs/reports/event_migration_evaluation_*.md" >> .gitignore
git add .gitignore
git commit -m "chore: 排除自动生成的评估报告"
```

**Step 4: 创建 README 文档**

Create: `tools/README.md`

```markdown
# Bricks 开发工具

## Event RuntimeInstance 迁移评估工具

评估所有 Bricks Event 是否需要迁移到 RuntimeInstance 架构。

### 使用方法

```bash
# 基本评估
python3 tools/evaluate_events_migration.py

# 详细输出
python3 tools/evaluate_events_migration.py --verbose

# 指定输出路径
python3 tools/evaluate_events_migration.py -o /path/to/report.md

# 查看帮助
python3 tools/evaluate_events_migration.py --help
```

### 评估标准

基于 `addons/bricks/docs/development/event-runtime-instance-checklist.md` 的决策标准：

| 状态变量 | 共享风险 | 是否迁移 | 优先级 |
|---------|---------|---------|--------|
| ✅ 有状态 | ✅ 高 | **是** | 🔴 高 |
| ✅ 有状态 | ⚠️ 中 | **建议** | 🟡 中 |
| ✅ 有状态 | ❌ 低 | 可选 | 🟢 低 |
| ❌ 无状态 | 任何 | **否** | - |

### 输出报告

报告包含：
- 📊 执行摘要（统计数据）
- 📋 详细评估结果（表格）
- 🎯 迁移优先级（分组）
- 💡 迁移建议（策略和顺序）
```

**Step 5: 提交工具文档**

```bash
git add tools/README.md
git commit -m "docs: 添加迁移评估工具使用说明"
```

---

## Task 8: 验证评估准确性

**Files:**
- Create: `tools/test_evaluation.py`

**Step 1: 创建验证测试**

```python
#!/usr/bin/env python3
"""测试评估工具的准确性"""

import sys
sys.path.insert(0, '.')

from evaluate_events_migration import EventEvaluator

def test_known_events():
    """测试已知 Event 的评估结果"""
    project_root = "."
    evaluator = EventEvaluator(f"{project_root}/addons/bricks")

    # 测试已迁移的 Event
    print("测试已迁移的 Event...")

    # OnMouseEnter 应该识别为需要迁移
    evals = evaluator.evaluate_all()
    on_mouse_enter = next((e for e in evals if e.event_name == "OnMouseEnter"), None)
    assert on_mouse_enter is not None, "未找到 OnMouseEnter"
    assert on_mouse_enter.has_state == True, "OnMouseEnter 应该有状态"
    assert on_mouse_enter.priority == "high", "OnMouseEnter 应该是高优先级"
    print("✅ OnMouseEnter 评估正确")

    # OnMouseExit 应该识别为需要迁移
    on_mouse_exit = next((e for e in evals if e.event_name == "OnMouseExit"), None)
    assert on_mouse_exit is not None, "未找到 OnMouseExit"
    assert on_mouse_exit.has_state == True, "OnMouseExit 应该有状态"
    assert on_mouse_exit.priority == "high", "OnMouseExit 应该是高优先级"
    print("✅ OnMouseExit 评估正确")

    # OnInterval 应该识别为需要迁移
    on_interval = next((e for e in evals if e.event_name == "OnInterval"), None)
    assert on_interval is not None, "未找到 OnInterval"
    assert on_interval.has_state == True, "OnInterval 应该有状态"
    assert on_interval.priority == "high", "OnInterval 应该是高优先级"
    print("✅ OnInterval 评估正确")

    # OnReady 应该识别为不需要迁移
    on_ready = next((e for e in evals if e.event_name == "OnReady"), None)
    assert on_ready is not None, "未找到 OnReady"
    assert on_ready.has_state == False, "OnReady 不应该有状态"
    assert on_ready.priority == "none", "OnReady 不需要迁移"
    print("✅ OnReady 评估正确")

    print("\n✅ 所有测试通过！")

if __name__ == "__main__":
    test_known_events()
```

**Step 2: 运行验证测试**

Run:
```bash
python3 tools/test_evaluation.py
```

Expected: 所有断言通过，输出 "✅ 所有测试通过！"

**Step 3: 提交验证测试**

```bash
git add tools/test_evaluation.py
git commit -m "test: 添加评估工具准确性验证测试"
```

---

## Task 9: 生成最终报告并总结

**Files:**
- Modify: `docs/reports/event_migration_evaluation_YYYYMMDD.md`

**Step 1: 生成最终评估报告**

Run:
```bash
python3 tools/evaluate_events_migration.py --verbose
```

**Step 2: 查看并验证报告内容**

Run:
```bash
cat docs/reports/event_migration_evaluation_$(date +%Y%m%d).md | head -100
```

Expected: 报告包含完整的评估结果和迁移建议

**Step 3: 创建总结文档**

Create: `docs/plans/2025-02-03-event-runtime-instance-evaluation-summary.md`

```markdown
# Event RuntimeInstance 迁移评估总结

## 评估结果

通过自动化评估工具，我们对 Bricks 插件中的 **62 个 Event** 进行了系统评估。

### 关键发现

- **需要迁移**: XX 个 (XX%)
  - 高优先级: XX 个
  - 中优先级: XX 个
  - 低优先级: XX 个
- **不需要迁移**: XX 个 (XX%)

### 已迁移

✅ OnMouseEnter - 完成
✅ OnMouseExit - 完成
✅ OnInterval - 完成

### 下一步行动

#### 高优先级迁移

以下 Event 应优先迁移：

1. **OnInputKey** - 高频使用，状态共享风险高
2. **OnMouseButton** - 高频使用，状态共享风险高
3. **OnArea2DEnter** - 常用物理事件，可能被多个 Trigger 共享
4. **OnTimer** - 定时器事件，有运行时状态

#### 中优先级迁移

按需迁移以下 Event：

1. **OnSignalFromGroup** - 通用信号监听
2. **OnPropertyChanged** - 属性变化监听
3. **OnVariableChanged** - 变量变化监听

### 不需要迁移

约 XX 个 Event 是无状态的，不需要迁移：
- OnReady
- OnEnterTree
- OnExitTree
- ...（其他）

### 迁移策略

采用**渐进式迁移**：
1. 新 Event 直接使用 RuntimeInstance 架构
2. 高优先级 Event 逐步迁移
3. 中低优先级 Event 按需迁移
4. 保持向后兼容

## 工具使用

评估工具位置：`tools/evaluate_events_migration.py`

```bash
# 运行评估
python3 tools/evaluate_events_migration.py

# 详细输出
python3 tools/evaluate_events_migration.py --verbose
```

## 相关文档

- [迁移检查清单](../addons/bricks/docs/development/event-runtime-instance-checklist.md)
- [迁移指南](../addons/bricks/docs/migration-guide-to-runtime-instance.md)
- [Event 创建指南](../addons/bricks/docs/development/event_creation_guide.md)
```

**Step 4: 提交最终文档**

```bash
git add docs/plans/2025-02-03-event-runtime-instance-evaluation-summary.md
git add docs/reports/event_migration_evaluation_*.md
git commit -m "docs: 完成 Event RuntimeInstance 迁移评估"
```

---

## 成功标准

完成此计划后，应达到以下标准：

### 功能性
- ✅ 自动扫描所有 62+ 个 Event 文件
- ✅ 正确识别运行时状态变量
- ✅ 应用决策矩阵判断是否需要迁移
- ✅ 评估共享风险（高/中/低）
- ✅ 生成优先级分组报告

### 准确性
- ✅ 已迁移的 Event（OnMouseEnter, OnMouseExit, OnInterval）被正确识别为"需要迁移"
- ✅ 无状态 Event（OnReady, OnEnterTree 等）被正确识别为"不需要迁移"
- ✅ 高风险 Event 被正确标记为高优先级

### 输出质量
- ✅ Markdown 格式报告
- ✅ 包含执行摘要和统计
- ✅ 包含详细评估结果表格
- ✅ 包含迁移优先级列表
- ✅ 包含迁移建议和策略

### 可维护性
- ✅ 代码清晰，有完整注释
- ✅ 支持命令行参数
- ✅ 有验证测试
- ✅ 有使用文档

---

## 相关资源

### 参考文档
- [Event RuntimeInstance 迁移检查清单](addons/bricks/docs/development/event-runtime-instance-checklist.md)
- [Event 创建指南](addons/bricks/docs/development/event_creation_guide.md)
- [迁移指南](addons/bricks/docs/migration-guide-to-runtime-instance.md)
- [问题解决方案](addons/bricks/docs/event-resource-sharing-solution.md)

### 相关技能
- @superpowers:subagent-driven-development - 执行此计划
- @superpowers:writing-plans - 创建此计划
- @godot - Godot 4.6 GDScript 和项目结构

### 工具
- Python 3.x
- re - 正则表达式（模式匹配）
- pathlib - 路径处理
- dataclasses - 数据结构

---

**计划维护**: Bricks 开发团队
**创建日期**: 2025-02-03
**预计耗时**: 2-3 小时
