#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Bricks Event RuntimeInstance 迁移评估工具

评估所有 Event 是否需要迁移到 RuntimeInstance 架构
"""

import os
import re
import sys
import argparse
from pathlib import Path
from typing import Dict, List, Tuple
from dataclasses import dataclass
from datetime import datetime

# 修复 Windows 编码问题
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')


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
	is_migrated: bool  # 是否已迁移到 RuntimeInstance


class EventEvaluator:
	"""Event 迁移评估器"""

	# 运行时状态变量模式
	# 注意：排除 _runtime_instance_ref 和 _signal_connections，这些是迁移后的基础设施
	STATE_PATTERNS = [
		r'_has_triggered\s*[:=]',
		r'_is_hovered\s*[:=]',
		r'_has_exited\s*[:=]',
		r'_is_active\s*[:=]',
		r'_is_running\s*[:=]',
		r'_is_completed\s*[:=]',
		r'_trigger_count\s*[:=]',
		r'_execution_count\s*[:=]',
		r'_current_repeat_count\s*[:=]',
		r'_last_trigger_time\s*[:=]',
		r'_last_time\s*[:=]',
		r'_last_input_time\s*[:=]',
		r'_remaining_time\s*[:=]',
		r'_timer\s*[:=]',
		r'_tween\s*[:=]',
		r'_main_timer\s*[:=]',
		r'_progress_timer\s*[:=]',
		r'_triggered_bodies\s*[:=]',
		r'_owner_node_ref\s*[:=]',
	]

	def __init__(self, bricks_root: str, verbose: bool = False):
		self.bricks_root = Path(bricks_root)
		self.events_dir = self.bricks_root / "events"
		self.evaluations: List[EventEvaluation] = []
		self.verbose = verbose

	def _log(self, message: str):
		"""输出日志（仅在 verbose 模式下）"""
		if self.verbose:
			print(f"[DEBUG] {message}")

	def _find_all_event_files(self) -> List[Path]:
		"""查找所有 Event 文件"""
		event_files = []
		for event_file in self.events_dir.rglob("*.gd"):
			# 跳过测试文件
			if "test_" in event_file.name:
				continue
			event_files.append(event_file)
		return event_files

	def _detect_state_variables(self, content: str) -> List[str]:
		"""检测 Event 中的运行时状态变量"""
		state_vars = []

		for pattern in self.STATE_PATTERNS:
			matches = re.findall(pattern, content)
			# 从匹配中提取变量名
			for match in matches:
				# 提取变量名（去掉 : 或 = 后面的部分）
				var_name = match.split(':')[0].split('=')[0].strip()
				if var_name and var_name not in state_vars:
					state_vars.append(var_name)

		return state_vars

	def _assess_sharing_risk(self, event_name: str, content: str) -> str:
		"""评估共享风险

		Args:
			event_name: Event 类名
			content: Event 文件内容

		Returns:
			"high", "medium", 或 "low"
		"""
		# 高风险：常用 Event，容易在多个场景中被同时使用
		high_risk_events = [
			'OnMouseEnter', 'OnMouseExit', 'OnInterval',
			'OnInputKey', 'OnMouseButton', 'OnArea2DEnter',
			'OnArea3DEntered', 'OnTimer', 'OnCooldown'
		]

		# 中风险：通用 Event，有一定共享可能
		medium_risk_patterns = [
			'OnSignal', 'OnPropertyChanged', 'OnVariableChanged'
		]

		# 检查高风险
		if any(pattern in event_name for pattern in high_risk_events):
			return "high"

		# 检查中风险
		if any(pattern in event_name for pattern in medium_risk_patterns):
			return "medium"

		# 默认低风险
		return "low"

	def _apply_decision_matrix(
		self,
		has_state: bool,
		sharing_risk: str,
		state_vars: List[str]
	) -> Tuple[bool, str, str]:
		"""应用决策矩阵

		Args:
			has_state: 是否有状态变量
			sharing_risk: 共享风险等级 ("high", "medium", "low")
			state_vars: 状态变量列表

		Returns:
			(should_migrate, priority, reasoning) 元组
		"""
		# 如果没有状态变量，不需要迁移
		if not has_state:
			return False, "none", "无运行时状态，不需要迁移"

		# 高风险 + 有状态 = 强烈建议迁移
		if sharing_risk == "high":
			return True, "high", f"有状态变量 ({', '.join(state_vars)}) + 高共享风险 = 强烈建议迁移"

		# 中风险 + 有状态 = 建议迁移
		if sharing_risk == "medium":
			return True, "medium", f"有状态变量 ({', '.join(state_vars)}) + 中共享风险 = 建议迁移"

		# 低风险 + 有状态 = 可选迁移
		return False, "low", f"有状态变量 ({', '.join(state_vars)}) + 低共享风险 = 可选迁移"

	def _evaluate_event(self, event_path: Path) -> EventEvaluation:
		"""评估单个 Event"""
		# 读取文件内容
		try:
			with open(event_path, 'r', encoding='utf-8') as f:
				content = f.read()

		except Exception as e:
			print(f"警告: 无法读取文件 {event_path}: {e}")
			return None

		# 提取 Event 名称
		event_name = event_path.stem
		class_match = re.search(r'class_name\s+(\w+)', content)
		if class_match:
			event_name = class_match.group(1)

		self._log(f"评估事件: {event_name}")

		# 检查是否已经迁移（使用 RuntimeEventInstance）
		has_runtime_instance = (
			"RuntimeEventInstance" in content and
			"initialize_with_runtime_instance" in content
		)

		# 检测状态变量（只在未迁移时检测）
		state_vars = []
		if not has_runtime_instance:
			state_vars = self._detect_state_variables(content)
			self._log(f"  状态变量: {state_vars}")

		has_state = len(state_vars) > 0

		# 评估共享风险
		sharing_risk = self._assess_sharing_risk(event_name, content)
		self._log(f"  共享风险: {sharing_risk}")

		# 应用决策矩阵
		should_migrate, priority, reasoning = self._apply_decision_matrix(
			has_state, sharing_risk, state_vars
		)

		# 如果已迁移，更新决策结果
		if has_runtime_instance:
			should_migrate = False
			priority = "none"
			reasoning = "已迁移到 RuntimeInstance 架构"
			self._log(f"  已迁移到 RuntimeInstance")

		return EventEvaluation(
			event_name=event_name,
			event_path=str(event_path.relative_to(self.bricks_root.parent)),
			has_state=has_state,
			state_variables=state_vars,
			sharing_risk=sharing_risk,
			should_migrate=should_migrate,
			priority=priority,
			reasoning=reasoning,
			is_migrated=has_runtime_instance
		)

	def evaluate_all(self, filter_priority: str = None) -> List[EventEvaluation]:
		"""评估所有 Event

		Args:
			filter_priority: 可选，按优先级过滤 ("high", "medium", "low", "none")
		"""
		event_files = self._find_all_event_files()

		for event_file in event_files:
			evaluation = self._evaluate_event(event_file)
			if evaluation:  # 确保评估结果有效
				# 如果指定了过滤条件
				if filter_priority is None or evaluation.priority == filter_priority:
					self.evaluations.append(evaluation)

		return self.evaluations

	def _generate_priority_list(self) -> List[str]:
		"""生成按优先级分组的 Event 列表"""
		lines = [
			"## 优先级分组",
			"",
			"### 高优先级迁移（强烈建议）",
			"",
			"这些 Event 有运行时状态且共享风险高，强烈建议尽快迁移。",
			"",
		]

		high_priority = [e for e in self.evaluations if e.priority == "high"]
		if high_priority:
			lines.append("| Event Name | State Variables | Sharing Risk | Reasoning |")
			lines.append("|------------|-----------------|--------------|-----------|")
			for eval_result in high_priority:
				vars_str = ", ".join(eval_result.state_variables[:3])
				if len(eval_result.state_variables) > 3:
					vars_str += f" (+{len(eval_result.state_variables) - 3})"
				lines.append(f"| {eval_result.event_name} | {vars_str} | {eval_result.sharing_risk} | {eval_result.reasoning} |")
		else:
			lines.append("*无高优先级 Event*")

		lines.extend(["", "### 中优先级迁移（建议）", "", "这些 Event 有运行时状态且有一定共享风险，建议迁移。", ""])

		medium_priority = [e for e in self.evaluations if e.priority == "medium"]
		if medium_priority:
			lines.append("| Event Name | State Variables | Sharing Risk | Reasoning |")
			lines.append("|------------|-----------------|--------------|-----------|")
			for eval_result in medium_priority:
				vars_str = ", ".join(eval_result.state_variables[:3])
				if len(eval_result.state_variables) > 3:
					vars_str += f" (+{len(eval_result.state_variables) - 3})"
				lines.append(f"| {eval_result.event_name} | {vars_str} | {eval_result.sharing_risk} | {eval_result.reasoning} |")
		else:
			lines.append("*无中优先级 Event*")

		lines.extend(["", "### 低优先级迁移（可选）", "", "这些 Event 有运行时状态但共享风险低，可以稍后迁移。", ""])

		low_priority = [e for e in self.evaluations if e.priority == "low"]
		if low_priority:
			lines.append("| Event Name | State Variables | Sharing Risk | Reasoning |")
			lines.append("|------------|-----------------|--------------|-----------|")
			for eval_result in low_priority:
				vars_str = ", ".join(eval_result.state_variables[:3])
				if len(eval_result.state_variables) > 3:
					vars_str += f" (+{len(eval_result.state_variables) - 3})"
				lines.append(f"| {eval_result.event_name} | {vars_str} | {eval_result.sharing_risk} | {eval_result.reasoning} |")
		else:
			lines.append("*无低优先级 Event*")

		lines.extend(["", "### 无需迁移", "", "这些 Event 无运行时状态或已迁移，不需要迁移。", ""])

		no_migration = [e for e in self.evaluations if e.priority == "none"]
		if no_migration:
			migrated = [e for e in no_migration if e.is_migrated]
			no_state = [e for e in no_migration if not e.has_state]

			if migrated:
				lines.append(f"**已迁移 ({len(migrated)} 个)**:")
				for eval_result in migrated:
					lines.append(f"- {eval_result.event_name} - 已使用 RuntimeInstance")
				lines.append("")

			if no_state:
				lines.append(f"**无状态 ({len(no_state)} 个)**:")
				for eval_result in no_state:
					lines.append(f"- {eval_result.event_name} - 无运行时状态")
				lines.append("")
		else:
			lines.append("*所有 Event 都需要迁移*")

		return lines

	def _generate_migration_recommendations(self) -> List[str]:
		"""生成迁移建议"""
		lines = [
			"## 迁移建议",
			"",
			"### 迁移优先级",
			"",
			"1. **第一阶段（高优先级）**: 首先迁移高共享风险的 Event",
			"   - 这些 Event 最容易在多个场景中同时使用",
			"   - 迁移后收益最大",
			"   - 包括: OnMouseEnter, OnMouseExit, OnInterval, OnInputKey, OnMouseButton 等",
			"",
			"2. **第二阶段（中优先级）**: 迁移中等共享风险的 Event",
			"   - 这些 Event 有一定共享可能",
			"   - 迁移后可以提高系统稳定性",
			"   - 包括: OnTargetSignalEmit, OnPropertyChanged, OnVariableChanged 等",
			"",
			"3. **第三阶段（低优先级）**: 最后迁移低共享风险的 Event",
			"   - 这些 Event 很少被共享",
			"   - 迁移的收益较小",
			"   - 可以在有时间时逐步迁移",
			"",
			"### 迁移步骤",
			"",
			"参考文档: `addons/bricks/docs/development/runtime-instance-migration-guide.md`",
			"",
			"基本步骤：",
			"",
			"1. **创建 RuntimeInstance 类**",
			"   ```gdscript",
			"   # addons/bricks/events/[category]/runtime/[event_name]_runtime.gd",
			"   extends RuntimeEventInstance",
			"   ",
			"   var _has_triggered: bool = false",
			"   ",
			"   func _on_event_triggered():",
			"       _has_triggered = true",
			"   ```",
			"",
			"2. **修改 Event 类**",
			"   ```gdscript",
			"   # 在 Event 类中添加",
			"   func _get_runtime_instance_class() -> String:",
			"       return \"[EventName]Runtime\"",
			"   ",
			"   func initialize_with_runtime_instance(runtime: RuntimeEventInstance) -> void:",
			"       super.initialize_with_runtime_instance(runtime)",
			"       # 初始化自定义逻辑",
			"   ```",
			"",
			"3. **测试迁移结果**",
			"   - 确保事件功能正常",
			"   - 验证状态隔离",
			"   - 检查内存泄漏",
			"",
			"4. **更新文档**",
			"   - 在 Event 文件顶部添加注释",
			"   - 标记迁移日期",
			"   - 记录重要变更",
			"",
		]

		return lines

	def generate_report(self, output_path: str):
		"""生成 Markdown 报告"""
		report_path = Path(output_path)

		# 确保目录存在
		report_path.parent.mkdir(parents=True, exist_ok=True)

		# 统计数据（修正统计逻辑）
		total = len(self.evaluations)
		with_state = sum(1 for e in self.evaluations if e.has_state)
		should_migrate = sum(1 for e in self.evaluations if e.should_migrate)
		migrated = sum(1 for e in self.evaluations if e.is_migrated)
		optional = sum(1 for e in self.evaluations if e.priority == "low")
		no_migration_needed = sum(1 for e in self.evaluations if e.priority == "none")

		# 按优先级统计
		high_priority = sum(1 for e in self.evaluations if e.priority == "high")
		medium_priority = sum(1 for e in self.evaluations if e.priority == "medium")
		low_priority_count = sum(1 for e in self.evaluations if e.priority == "low")

		# 生成 Markdown 内容
		lines = [
			f"# Bricks Event RuntimeInstance 迁移评估报告",
			f"",
			f"**生成时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
			f"**项目路径**: {self.bricks_root.parent}",
			f"",
			f"## 执行摘要",
			f"",
			f"### 总体统计",
			f"",
			f"| 指标 | 数量 | 占比 |",
			f"|------|------|------|",
			f"| **总 Event 数** | {total} | 100% |",
			f"| **有状态变量的 Event** | {with_state} | {with_state*100//total if total > 0 else 0}% |",
			f"| **需要迁移的 Event** | {should_migrate} | {should_migrate*100//total if total > 0 else 0}% |",
			f"| **已迁移的 Event** | {migrated} | {migrated*100//total if total > 0 else 0}% |",
			f"| **可选迁移的 Event** | {optional} | {optional*100//total if total > 0 else 0}% |",
			f"| **无需迁移的 Event** | {no_migration_needed} | {no_migration_needed*100//total if total > 0 else 0}% |",
			f"",
			f"### 迁移优先级分布",
			f"",
			f"| 优先级 | 数量 | 说明 |",
			f"|--------|------|------|",
			f"| **高优先级** | {high_priority} | 有状态 + 高共享风险，强烈建议迁移 |",
			f"| **中优先级** | {medium_priority} | 有状态 + 中共享风险，建议迁移 |",
			f"| **低优先级** | {low_priority_count} | 有状态 + 低共享风险，可选迁移 |",
			f"| **无需迁移** | {no_migration_needed} | 无状态或已迁移 |",
			f"",
		]

		# 添加关键发现
		lines.extend([
			f"### 关键发现",
			f"",
		])

		if migrated > 0:
			lines.append(f"- ✓ 已有 **{migrated}** 个 Event 迁移到 RuntimeInstance 架构")
		else:
			lines.append("- ⚠️ 目前还没有 Event 迁移到 RuntimeInstance 架构")

		if should_migrate > 0:
			lines.append(f"- ⚠️ 有 **{should_migrate}** 个 Event 需要迁移（高+中优先级）")
		else:
			lines.append("- ✓ 所有需要迁移的 Event 已完成迁移")

		if high_priority > 0:
			lines.append(f"- 🚨 有 **{high_priority}** 个高优先级 Event 需要立即处理")

		lines.extend(["", ""])

		# 添加优先级分组
		lines.extend(self._generate_priority_list())
		lines.extend(["", ""])

		# 添加迁移建议
		lines.extend(self._generate_migration_recommendations())
		lines.extend(["", ""])

		# 添加详细结果表格
		lines.extend([
			f"## 详细评估结果",
			f"",
			f"以下按分类列出所有 Event 的评估结果：",
			f"",
		])

		# 按分类分组
		categories = {}
		for eval_result in self.evaluations:
			# 从路径中提取分类
			path_parts = Path(eval_result.event_path).parts
			if len(path_parts) >= 3:
				category = path_parts[2]  # addons/bricks/events/<category>/...
			else:
				category = "other"

			if category not in categories:
				categories[category] = []
			categories[category].append(eval_result)

		# 输出每个分类的 Event
		for category, events in sorted(categories.items()):
			lines.append(f"### {category.capitalize()}")
			lines.append("")
			lines.append(f"| Event Name | Has State | State Variables | Priority | Status |")
			lines.append(f"|------------|-----------|-----------------|----------|--------|")

			for eval_result in events:
				has_state_str = "✓" if eval_result.has_state else "✗"

				if eval_result.state_variables:
					vars_str = ", ".join(eval_result.state_variables[:2])
					if len(eval_result.state_variables) > 2:
						vars_str += f" (+{len(eval_result.state_variables) - 2})"
				else:
					vars_str = "-"

				# 状态标记
				if eval_result.is_migrated:
					status = "✓ 已迁移"
				elif eval_result.should_migrate:
					status = "✗ 需要迁移"
				elif eval_result.priority == "low":
					status = "○ 可选迁移"
				else:
					status = "- 无需迁移"

				# 优先级标记
				priority_str = eval_result.priority.upper()

				lines.append(f"| {eval_result.event_name} | {has_state_str} | {vars_str} | {priority_str} | {status} |")

			lines.append("")

		# 写入文件
		with open(report_path, 'w', encoding='utf-8') as f:
			f.write('\n'.join(lines))

		print(f"\n报告已生成: {report_path}")


def main():
	"""主函数"""
	parser = argparse.ArgumentParser(
		description='Bricks Event RuntimeInstance 迁移评估工具',
		formatter_class=argparse.RawDescriptionHelpFormatter,
		epilog="""
示例:
  %(prog)s                      # 运行评估并生成报告
  %(prog)s --verbose            # 显示详细输出
  %(prog)s --output report.md   # 指定输出文件
  %(prog)s --filter high        # 只显示高优先级 Event
  %(prog)s --help               # 显示帮助信息
		"""
	)

	parser.add_argument(
		'-v', '--verbose',
		action='store_true',
		help='显示详细输出（调试信息）'
	)

	parser.add_argument(
		'-o', '--output',
		type=str,
		default=None,
		help='指定输出报告路径（默认: docs/reports/event_migration_evaluation_YYYYMMDD.md）'
	)

	parser.add_argument(
		'-f', '--filter',
		type=str,
		choices=['high', 'medium', 'low', 'none'],
		help='按优先级过滤结果（只显示指定优先级的 Event）'
	)

	args = parser.parse_args()

	# 假设从项目根目录运行
	project_root = Path(__file__).parent.parent
	evaluator = EventEvaluator(
		str(project_root / "addons" / "bricks"),
		verbose=args.verbose
	)

	# 评估所有 Event
	print(f"\n{'='*60}")
	print(f"开始评估 Bricks Event 迁移需求...")
	print(f"{'='*60}\n")

	evaluations = evaluator.evaluate_all(filter_priority=args.filter)

	# 统计结果
	total_events = len(evaluations)
	events_with_state = sum(1 for e in evaluations if e.has_state)
	events_should_migrate = sum(1 for e in evaluations if e.should_migrate)
	migrated_count = sum(1 for e in evaluations if e.is_migrated)
	optional_count = sum(1 for e in evaluations if e.priority == "low")

	# 按优先级统计
	high_priority = sum(1 for e in evaluations if e.priority == "high")
	medium_priority = sum(1 for e in evaluations if e.priority == "medium")
	low_priority = sum(1 for e in evaluations if e.priority == "low")

	print(f"{'='*60}")
	print(f"Event 迁移评估结果")
	print(f"{'='*60}")
	print(f"总 Event 数: {total_events}")
	print(f"有状态变量的 Event: {events_with_state}")
	print(f"需要迁移的 Event: {events_should_migrate}")
	print(f"已迁移的 Event: {migrated_count}")
	print(f"可选迁移的 Event: {optional_count}")
	print(f"")
	print(f"优先级分布:")
	print(f"  - 高优先级: {high_priority}")
	print(f"  - 中优先级: {medium_priority}")
	print(f"  - 低优先级: {low_priority}")
	print(f"{'='*60}\n")

	# 显示已迁移的 Event
	migrated_events = [e for e in evaluations if e.is_migrated]
	if migrated_events:
		print("已迁移的 Event (使用 RuntimeEventInstance):")
		for eval_result in migrated_events:
			print(f"  ✓ {eval_result.event_name}")
		print()

	# 显示高优先级的 Event
	high_priority_events = [e for e in evaluations if e.priority == "high"]
	if high_priority_events:
		print("高优先级 Event (强烈建议迁移):")
		for eval_result in high_priority_events:
			print(f"  🚨 {eval_result.event_name}")
			if eval_result.state_variables:
				vars_str = ", ".join(eval_result.state_variables[:3])
				print(f"      状态变量: {vars_str}")
			print(f"      推理: {eval_result.reasoning}")
		print()

	# 显示中优先级的 Event
	medium_priority_events = [e for e in evaluations if e.priority == "medium"]
	if medium_priority_events:
		print("中优先级 Event (建议迁移):")
		for eval_result in medium_priority_events:
			print(f"  ⚠️  {eval_result.event_name}")
			if eval_result.state_variables:
				vars_str = ", ".join(eval_result.state_variables[:3])
				print(f"      状态变量: {vars_str}")
			print(f"      推理: {eval_result.reasoning}")
		print()

	# 生成报告
	if args.output:
		report_path = Path(args.output)
	else:
		report_dir = project_root / "docs" / "reports"
		report_dir.mkdir(parents=True, exist_ok=True)
		report_path = report_dir / f"event_migration_evaluation_{datetime.now().strftime('%Y%m%d')}.md"

	evaluator.generate_report(str(report_path))

	print(f"\n✓ 评估完成！共评估 {len(evaluations)} 个 Event")
	if args.filter:
		print(f"  (已过滤: 只显示 {args.filter} 优先级的 Event)")


if __name__ == "__main__":
	main()
