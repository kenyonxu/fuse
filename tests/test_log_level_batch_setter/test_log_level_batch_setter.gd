# 文件：tests/test_log_level_batch_setter/test_log_level_batch_setter.gd
extends Node

## LogLevelBatchSetter.collect_components 收集逻辑测试
##
## 只测 static 纯函数（项目惯例：编辑器工具只测可 headless 判定的部分）：
## - 深嵌套组件全量收集（EventBinding / 复合指令 / 复合条件 / CheckComposite.LogicNode）
## - 实例化子场景与外部 .tres 的跳过归类
## - 重叠 roots 去重、循环引用防护
##
## 场景树为 free-standing 手工组装（不加入 SceneTree），避免触发组件 _ready 运行时逻辑

const EXTERNAL_DIR: String = "user://test_log_level_batch_setter"

var _test_count: int = 0
var _pass_count: int = 0
var _fail_count: int = 0

func _ready() -> void:
	print("=== Running Test: LogLevelBatchSetter.collect_components ===")
	_test_deep_nested_collection()
	_test_overlapping_roots_dedup()
	_test_cyclic_references()
	_cleanup_external_files()
	_print_test_report()
	get_tree().quit(1 if _fail_count > 0 else 0)

## 深嵌套场景：验证所有层级的组件都被收集，实例内/外部资源正确归类
func _test_deep_nested_collection() -> void:
	var tree: Dictionary = _build_deep_tree()
	var root: Node = tree["root"]
	var collected: Dictionary = LogLevelBatchSetter.collect_components([root], root)

	var actual_ids: Dictionary = _collect_target_ids(collected["applicable"])
	_assert_eq(actual_ids.size(), (tree["expected_ids"] as Dictionary).size(), "收集数量（实际: %s）" % str(_diff_names(actual_ids, tree["expected_ids"])))
	for expected_id: int in tree["expected_ids"]:
		_assert_true(actual_ids.has(expected_id), "收集到期望组件: %s" % tree["expected_ids"][expected_id])

	var skipped_external: Array = collected["skipped_external"]
	_assert_eq(skipped_external.size(), 1, "外部资源跳过数")
	if skipped_external.size() == 1:
		_assert_true((skipped_external[0]["path"] as String).begins_with(EXTERNAL_DIR), "外部资源路径记录正确")

	_assert_eq(collected["skipped_nested_count"], 3, "实例内组件跳过数（Trigger 节点 + event + action_runner）")

	root.free()

## 重叠 roots：父节点与子节点同时选中，子树只收集一次
func _test_overlapping_roots_dedup() -> void:
	var tree: Dictionary = _build_deep_tree()
	var root: Node = tree["root"]
	var multi_trigger: Node = root.get_node("MultiEventTrigger")

	var whole: Dictionary = LogLevelBatchSetter.collect_components([root], root)
	var overlapping: Dictionary = LogLevelBatchSetter.collect_components([root, multi_trigger], root)

	_assert_eq(overlapping["applicable"].size(), whole["applicable"].size(), "重叠 roots 收集数量一致")

	root.free()

## 循环引用：条件互指不导致死循环，各对象只计一次
func _test_cyclic_references() -> void:
	var root: Node = Node.new()
	root.name = "Scene"

	var trigger: Trigger = Trigger.new()
	trigger.name = "CyclicTrigger"
	root.add_child(trigger)
	trigger.owner = root

	# CheckAll.conditions 含 CheckNot，CheckNot.inner_condition 指回 CheckAll 自身
	var check_all: CheckAll = CheckAll.new()
	var check_not: CheckNot = CheckNot.new()
	check_not.inner_condition = check_all
	check_all.conditions = [check_not]

	var action_runner: ActionRunner = ActionRunner.new()
	var run_check: RunConditionCheck = RunConditionCheck.new()
	run_check.condition = check_all
	action_runner.instructions = [run_check]
	trigger.action_runner = action_runner

	var collected: Dictionary = LogLevelBatchSetter.collect_components([root], root)
	var actual_ids: Dictionary = _collect_target_ids(collected["applicable"])

	_assert_true(actual_ids.has(check_all.get_instance_id()), "循环引用下仍收集到 CheckAll")
	_assert_true(actual_ids.has(check_not.get_instance_id()), "循环引用下仍收集到 CheckNot")
	_assert_eq(actual_ids.size(), 5, "循环引用收集数量（trigger + action_runner + run_check + check_all + check_not）")

	root.free()

## ==================== 场景构造 ====================

## 构造深嵌套 free-standing 场景树
## 结构（owner=scene_root 的组件全部应被收集）：
## MultiEventTrigger
##   └ event_bindings[0]: EventBinding
##       ├ event: OnInterval（stop_condition: CheckNot(inner: CheckVariable)）
##       └ action_runner: ActionRunner
##           └ instructions[0]: IfElse
##               ├ condition: CheckAll(conditions: [CheckNot(inner: CheckVariable)])
##               └ true_instructions: [Wait, ForLoop(loop: [RunConditionCheck(condition: CheckComposite/LogicNode)])]
## Runner（action_runner: ActionRunner）
## instance_root（模拟实例化子场景，无 owner）
##   └ Trigger（owner=instance_root → 整枝跳过，计 3 个：节点 + event + action_runner）
## ExternalTrigger（event_definition 为外部 .tres → 跳过并记录路径）
func _build_deep_tree() -> Dictionary:
	var root: Node = Node.new()
	root.name = "Scene"

	# ---- MultiEventTrigger 深嵌套分支 ----
	var multi_trigger: MultiEventTrigger = MultiEventTrigger.new()
	multi_trigger.name = "MultiEventTrigger"
	root.add_child(multi_trigger)
	multi_trigger.owner = root

	var interval_event: OnInterval = OnInterval.new()
	var event_stop_not: CheckNot = CheckNot.new()
	var event_stop_cond: CheckVariable = CheckVariable.new()
	event_stop_not.inner_condition = event_stop_cond
	interval_event.stop_condition = event_stop_not

	var if_else: IfElse = IfElse.new()
	var branch_all: CheckAll = CheckAll.new()
	var branch_not: CheckNot = CheckNot.new()
	var branch_cond: CheckVariable = CheckVariable.new()
	branch_not.inner_condition = branch_cond
	branch_all.conditions = [branch_not]
	if_else.condition = branch_all

	var wait_instr: Wait = Wait.new()
	var for_loop: ForLoop = ForLoop.new()
	var run_check: RunConditionCheck = RunConditionCheck.new()
	var composite: CheckComposite = CheckComposite.new()
	var leaf_cond: CheckVariable = CheckVariable.new()
	var logic_root: CheckComposite.LogicNode = CheckComposite.LogicNode.create_logic(
		CheckComposite.LogicOperator.AND,
		[CheckComposite.LogicNode.create_leaf(leaf_cond)]
	)
	composite._root_node = logic_root
	run_check.condition = composite
	for_loop.loop_instructions = [run_check]
	if_else.true_instructions = [wait_instr, for_loop]

	var runner_ar: ActionRunner = ActionRunner.new()
	runner_ar.instructions = [if_else]

	var binding: EventBinding = EventBinding.new()
	binding.event = interval_event
	binding.action_runner = runner_ar
	multi_trigger.event_bindings = [binding]

	# ---- Runner 节点分支 ----
	var runner_node: Runner = Runner.new()
	runner_node.name = "Runner"
	root.add_child(runner_node)
	runner_node.owner = root
	var standalone_ar: ActionRunner = ActionRunner.new()
	runner_node.action_runner = standalone_ar

	# ---- 实例化子场景分支（owner 不属于 scene_root，整枝跳过）----
	var instance_root: Node = Node.new()
	instance_root.name = "InstanceRoot"
	root.add_child(instance_root)
	var nested_trigger: Trigger = Trigger.new()
	nested_trigger.name = "NestedTrigger"
	instance_root.add_child(nested_trigger)
	nested_trigger.owner = instance_root
	var nested_event: OnInterval = OnInterval.new()
	nested_trigger.event_definition = nested_event
	var nested_ar: ActionRunner = ActionRunner.new()
	nested_trigger.action_runner = nested_ar

	# ---- 外部 .tres 分支（跳过并记录路径）----
	var external_trigger: Trigger = Trigger.new()
	external_trigger.name = "ExternalTrigger"
	root.add_child(external_trigger)
	external_trigger.owner = root
	var external_event: OnInterval = _create_external_event()
	if external_event != null:
		external_trigger.event_definition = external_event

	var expected_ids: Dictionary = {
		multi_trigger.get_instance_id(): "MultiEventTrigger",
		interval_event.get_instance_id(): "OnInterval",
		event_stop_not.get_instance_id(): "OnInterval.stop_condition CheckNot",
		event_stop_cond.get_instance_id(): "CheckNot.inner CheckVariable",
		runner_ar.get_instance_id(): "binding.action_runner",
		if_else.get_instance_id(): "IfElse",
		branch_all.get_instance_id(): "IfElse.condition CheckAll",
		branch_not.get_instance_id(): "CheckAll.conditions CheckNot",
		branch_cond.get_instance_id(): "CheckNot.inner CheckVariable",
		wait_instr.get_instance_id(): "Wait",
		for_loop.get_instance_id(): "ForLoop",
		run_check.get_instance_id(): "RunConditionCheck",
		composite.get_instance_id(): "CheckComposite",
		leaf_cond.get_instance_id(): "LogicNode 叶子 CheckVariable",
		runner_node.get_instance_id(): "Runner 节点",
		standalone_ar.get_instance_id(): "Runner.action_runner",
		external_trigger.get_instance_id(): "ExternalTrigger 节点",
	}

	return {"root": root, "expected_ids": expected_ids}

## 在 user:// 下保存并加载一个外部事件资源（resource_path 不含 "::"）
func _create_external_event() -> OnInterval:
	DirAccess.make_dir_recursive_absolute(EXTERNAL_DIR)
	var external_event: OnInterval = OnInterval.new()
	external_event.resource_path = EXTERNAL_DIR + "/external_event.tres"
	var save_error: int = ResourceSaver.save(external_event)
	if save_error != OK:
		push_error("[test_log_level_batch_setter] 保存外部资源失败: %d" % save_error)
		return null
	var loaded: OnInterval = load(external_event.resource_path) as OnInterval
	return loaded

## ==================== 断言与清理 ====================

## 汇总 applicable 目标的 instance_id 集合
func _collect_target_ids(applicable: Array) -> Dictionary:
	var ids: Dictionary = {}
	for item: Dictionary in applicable:
		ids[item["target"].get_instance_id()] = true
	return ids

## 找出实际收集集合中多出的条目名（用于失败信息）
func _diff_names(actual_ids: Dictionary, expected: Dictionary) -> Array:
	var names: Array = []
	for id: int in actual_ids:
		if not expected.has(id):
			names.append(str(id))
	return names

func _cleanup_external_files() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null or not dir.dir_exists("test_log_level_batch_setter"):
		return
	var sub: DirAccess = DirAccess.open(EXTERNAL_DIR)
	if sub != null:
		sub.list_dir_begin()
		var file_name: String = sub.get_next()
		while not file_name.is_empty():
			if not sub.current_is_dir():
				sub.remove(file_name)
			file_name = sub.get_next()
		sub.list_dir_end()
	dir.remove("test_log_level_batch_setter")

func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_test_count += 1
	if actual == expected:
		_pass_count += 1
		print("[PASS] " + label)
	else:
		_fail_count += 1
		push_error("[FAIL] %s: 期望 %s，实际 %s" % [label, str(expected), str(actual)])

func _assert_true(value: bool, label: String) -> void:
	_assert_eq(value, true, label)

func _print_test_report() -> void:
	print("=== Test Complete: %d/%d passed ===" % [_pass_count, _test_count])
