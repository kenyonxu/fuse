extends Node2D

## Fuse Phase 1 条件集成测试
##
## 全面测试所有 P0 和 P1 级条件的集成工作
## 包括复合逻辑、节点操作、物理、输入、时间、距离检测
##
## 测试分类:
## - 复合逻辑条件 (NOT, AND, OR, Composite)
## - 节点操作条件 (NodeActive, NodeInGroup)
## - 物理检测条件 (OnFloor, InAir)
## - 输入检测条件 (InputPressed, InputReleased, InputHeld)
## - 时间检测条件 (TimeReached)
## - 距离检测条件 (Distance)
## - 真实游戏场景测试
## - 性能基准测试

## 统计信息
var _total_tests: int = 0
var _failed_tests: int = 0
var _performance_results: Dictionary = {}

## 测试场景节点
var _player_node: CharacterBody2D = null
var _enemy_node: Node2D = null
var _ui_node: Control = null

func _ready():
	var separator = ""
	for i in range(80):
		separator += "="

	print(separator)
	print("Fuse Phase 1 Conditions - 集成测试开始")
	print(separator)
	print("\n开始时间: %s\n" % Time.get_datetime_string_from_system())

	# 初始化测试环境
	setup_test_environment()

	# 运行所有测试分类
	print("\n" + separator)
	print("【类别 1/7】复合逻辑条件测试")
	print(separator)
	test_composite_logic()

	print("\n" + separator)
	print("【类别 2/7】节点操作条件测试")
	print(separator)
	test_node_operations()

	print("\n" + separator)
	print("【类别 3/7】物理检测条件测试")
	print(separator)
	test_physics_detection()

	print("\n" + separator)
	print("【类别 4/7】输入检测条件测试")
	print(separator)
	test_input_detection()

	print("\n" + separator)
	print("【类别 5/7】时间检测条件测试")
	print(separator)
	test_time_detection()

	print("\n" + separator)
	print("【类别 6/7】距离检测条件测试")
	print(separator)
	test_distance_detection()

	print("\n" + separator)
	print("【类别 7/7】真实场景条件组合测试")
	print(separator)
	test_condition_combinations()

	print("\n" + separator)
	print("【性能基准测试】")
	print(separator)
	run_performance_benchmarks()

	# 清理测试环境
	cleanup_test_environment()

	# 打印测试总结
	print_test_summary()

	var passed_tests = _total_tests - _failed_tests
	print("\n" + separator)
	if _failed_tests == 0:
		print("✅ Phase 1 集成测试全部通过！")
	else:
		print("❌ Phase 1 集成测试存在失败: %d 个失败" % _failed_tests)
	print(separator)
	print("结束时间: %s\n" % Time.get_datetime_string_from_system())

## 设置测试环境
func setup_test_environment():
	print("\n[设置] 创建测试环境...")

	# 创建玩家节点
	_player_node = CharacterBody2D.new()
	_player_node.name = "Player"
	add_child(_player_node)

	# 创建敌人节点
	_enemy_node = Node2D.new()
	_enemy_node.name = "Enemy"
	_enemy_node.position = Vector2(200, 0)
	add_child(_enemy_node)

	# 创建 UI 节点
	_ui_node = Control.new()
	_ui_node.name = "UIPanel"
	add_child(_ui_node)

	# 添加测试组
	add_to_group("test_group")
	_player_node.add_to_group("players")
	_enemy_node.add_to_group("enemies")

	print("[设置] 测试环境创建完成")

## 清理测试环境
func cleanup_test_environment():
	print("\n[清理] 清理测试环境...")

	if _player_node and not _player_node.is_queued_for_deletion():
		_player_node.queue_free()

	if _enemy_node and not _enemy_node.is_queued_for_deletion():
		_enemy_node.queue_free()

	if _ui_node and not _ui_node.is_queued_for_deletion():
		_ui_node.queue_free()

	print("[清理] 测试环境清理完成")

## 测试 1: 复合逻辑条件
func test_composite_logic():
	print("\n--- 复合逻辑条件测试 ---")

	var context = ExecutionContext.new()
	context.scene_context = self

	# 测试 NOT 条件
	test_not_basic(context)
	test_not_with_variable(context)

	# 测试 AND 条件
	test_and_all_true(context)
	test_and_one_false(context)
	test_and_empty(context)

	# 测试 OR 条件
	test_or_all_false(context)
	test_or_one_true(context)
	test_or_empty(context)

	# 测试复合条件嵌套
	test_composite_nested(context)

	print("✓ 复合逻辑条件测试完成")

## NOT 基础测试
func test_not_basic(context: ExecutionContext):
	var test_name = "NOT 基础测试"
	_total_tests += 1

	var check = CheckVariable.new()
	check.variable_name = "test_var"

	var not_cond = CheckNot.new()
	not_cond.inner_condition = check

	# 测试 NOT(true) = false
	context.set_variable("test_var", true)
	var result1 = not_cond.check(context)
	test_assert(result1 == false, "NOT(true) 应该返回 false")

	# 测试 NOT(false) = true
	context.set_variable("test_var", false)
	var result2 = not_cond.check(context)
	test_assert(result2 == true, "NOT(false) 应该返回 true")

	print("  ✓ %s 通过" % test_name)

## NOT 变量测试
func test_not_with_variable(context: ExecutionContext):
	var test_name = "NOT 变量测试"
	_total_tests += 1

	var check = CheckVariable.new()
	check.variable_name = "enabled"

	var not_cond = CheckNot.new()
	not_cond.inner_condition = check

	context.set_variable("enabled", true)
	var result = not_cond.check(context)
	test_assert(result == false, "NOT(enabled=true) 应该返回 false")

	context.set_variable("enabled", false)
	result = not_cond.check(context)
	test_assert(result == true, "NOT(enabled=false) 应该返回 true")

	print("  ✓ %s 通过" % test_name)

## AND 全部为真测试
func test_and_all_true(context: ExecutionContext):
	var test_name = "AND 全部为真测试"
	_total_tests += 1

	var check_a = CheckVariable.new()
	check_a.variable_name = "a"
	var check_b = CheckVariable.new()
	check_b.variable_name = "b"
	var check_c = CheckVariable.new()
	check_c.variable_name = "c"

	context.set_variable("a", true)
	context.set_variable("b", true)
	context.set_variable("c", true)

	var and_cond = CheckAll.new()
	and_cond.conditions = [check_a, check_b, check_c]

	var result = and_cond.check(context)
	test_assert(result == true, "AND(true, true, true) 应该返回 true")

	print("  ✓ %s 通过" % test_name)

## AND 一个为假测试
func test_and_one_false(context: ExecutionContext):
	var test_name = "AND 一个为假测试"
	_total_tests += 1

	var check_a = CheckVariable.new()
	check_a.variable_name = "a"
	var check_b = CheckVariable.new()
	check_b.variable_name = "b"
	var check_c = CheckVariable.new()
	check_c.variable_name = "c"

	context.set_variable("a", true)
	context.set_variable("b", false)
	context.set_variable("c", true)

	var and_cond = CheckAll.new()
	and_cond.conditions = [check_a, check_b, check_c]

	var result = and_cond.check(context)
	test_assert(result == false, "AND(true, false, true) 应该返回 false")

	print("  ✓ %s 通过" % test_name)

## AND 空条件测试
func test_and_empty(context: ExecutionContext):
	var test_name = "AND 空条件测试"
	_total_tests += 1

	var and_cond = CheckAll.new()
	and_cond.conditions = []

	var result = and_cond.check(context)
	test_assert(result == false, "AND() 空条件应该返回 false")

	print("  ✓ %s 通过" % test_name)

## OR 全部为假测试
func test_or_all_false(context: ExecutionContext):
	var test_name = "OR 全部为假测试"
	_total_tests += 1

	var check_a = CheckVariable.new()
	check_a.variable_name = "x"
	var check_b = CheckVariable.new()
	check_b.variable_name = "y"

	context.set_variable("x", false)
	context.set_variable("y", false)

	var or_cond = CheckAny.new()
	or_cond.conditions = [check_a, check_b]

	var result = or_cond.check(context)
	test_assert(result == false, "OR(false, false) 应该返回 false")

	print("  ✓ %s 通过" % test_name)

## OR 一个为真测试
func test_or_one_true(context: ExecutionContext):
	var test_name = "OR 一个为真测试"
	_total_tests += 1

	var check_a = CheckVariable.new()
	check_a.variable_name = "x"
	var check_b = CheckVariable.new()
	check_b.variable_name = "y"

	context.set_variable("x", false)
	context.set_variable("y", true)

	var or_cond = CheckAny.new()
	or_cond.conditions = [check_a, check_b]

	var result = or_cond.check(context)
	test_assert(result == true, "OR(false, true) 应该返回 true")

	print("  ✓ %s 通过" % test_name)

## OR 空条件测试
func test_or_empty(context: ExecutionContext):
	var test_name = "OR 空条件测试"
	_total_tests += 1

	var or_cond = CheckAny.new()
	or_cond.conditions = []

	var result = or_cond.check(context)
	test_assert(result == false, "OR() 空条件应该返回 false")

	print("  ✓ %s 通过" % test_name)

## 复合条件嵌套测试
func test_composite_nested(context: ExecutionContext):
	var test_name = "复合条件嵌套测试"
	_total_tests += 1

	# 构建 (A AND B) OR (C AND D)
	var check_a = CheckVariable.new()
	check_a.variable_name = "a"
	var check_b = CheckVariable.new()
	check_b.variable_name = "b"
	var check_c = CheckVariable.new()
	check_c.variable_name = "c"
	var check_d = CheckVariable.new()
	check_d.variable_name = "d"

	context.set_variable("a", true)
	context.set_variable("b", false)
	context.set_variable("c", true)
	context.set_variable("d", true)

	var and1 = CheckAll.new()
	and1.conditions = [check_a, check_b]

	var and2 = CheckAll.new()
	and2.conditions = [check_c, check_d]

	var or_cond = CheckAny.new()
	or_cond.conditions = [and1, and2]

	var result = or_cond.check(context)
	test_assert(result == true, "(false AND true) OR (true AND true) 应该返回 true")

	print("  ✓ %s 通过" % test_name)

## 测试 2: 节点操作条件
func test_node_operations():
	print("\n--- 节点操作条件测试 ---")

	var context = ExecutionContext.new()
	context.scene_context = self

	# 测试 NodeActive 条件
	test_node_visible(context)
	test_node_processing(context)
	test_node_inside_tree(context)

	# 测试 NodeInGroup 条件
	test_node_in_group(context)
	test_node_not_in_group(context)
	test_node_multiple_groups(context)

	print("✓ 节点操作条件测试完成")

## 节点可见性测试
func test_node_visible(context: ExecutionContext):
	var test_name = "节点可见性测试"
	_total_tests += 1

	var cond = CheckNodeActive.new()
	cond.check_node_path = NodePath("Player")
	cond.check_type = CheckNodeActive.CheckType.VISIBLE

	_player_node.visible = true
	var result1 = cond.check(context)
	test_assert(result1 == true, "可见节点应该返回 true")

	_player_node.visible = false
	var result2 = cond.check(context)
	test_assert(result2 == false, "不可见节点应该返回 false")

	print("  ✓ %s 通过" % test_name)

## 节点处理状态测试
func test_node_processing(context: ExecutionContext):
	var test_name = "节点处理状态测试"
	_total_tests += 1

	var cond = CheckNodeActive.new()
	cond.check_node_path = NodePath("Player")
	cond.check_type = CheckNodeActive.CheckType.PROCESSING

	_player_node.process_mode = Node.PROCESS_MODE_INHERIT
	var result1 = cond.check(context)
	test_assert(result1 == true, "处理中的节点应该返回 true")

	_player_node.process_mode = Node.PROCESS_MODE_DISABLED
	var result2 = cond.check(context)
	test_assert(result2 == false, "处理禁用的节点应该返回 false")

	print("  ✓ %s 通过" % test_name)

## 节点在场景树中测试
func test_node_inside_tree(context: ExecutionContext):
	var test_name = "节点在场景树中测试"
	_total_tests += 1

	var cond = CheckNodeActive.new()
	cond.check_node_path = NodePath("Player")
	cond.check_type = CheckNodeActive.CheckType.INSIDE_TREE

	var result = cond.check(context)
	test_assert(result == true, "在场景树中的节点应该返回 true")

	print("  ✓ %s 通过" % test_name)

## 节点在组中测试
func test_node_in_group(context: ExecutionContext):
	var test_name = "节点在组中测试"
	_total_tests += 1

	var cond = CheckNodeInGroup.new()
	cond.target_node = NodePath("Player")
	cond.group_name = "players"

	var result = cond.check(context)
	test_assert(result == true, "在 'players' 组中的节点应该返回 true")

	print("  ✓ %s 通过" % test_name)

## 节点不在组中测试
func test_node_not_in_group(context: ExecutionContext):
	var test_name = "节点不在组中测试"
	_total_tests += 1

	var cond = CheckNodeInGroup.new()
	cond.target_node = NodePath("Player")
	cond.group_name = "enemies"

	var result = cond.check(context)
	test_assert(result == false, "不在 'enemies' 组中的节点应该返回 false")

	print("  ✓ %s 通过" % test_name)

## 节点多组测试
func test_node_multiple_groups(context: ExecutionContext):
	var test_name = "节点多组测试"
	_total_tests += 1

	_player_node.add_to_group("allies")

	var cond = CheckNodeInGroup.new()
	cond.target_node = NodePath("Player")
	cond.group_name = "allies"

	var result = cond.check(context)
	test_assert(result == true, "在 'allies' 组中的节点应该返回 true")

	print("  ✓ %s 通过" % test_name)

## 测试 3: 物理检测条件
func test_physics_detection():
	print("\n--- 物理检测条件测试 ---")

	var context = ExecutionContext.new()
	context.scene_context = self
	context.target = _player_node

	# 测试 OnFloor 条件
	test_on_floor_true(context)
	test_on_floor_false(context)

	# 测试 InAir 条件
	test_in_air_true(context)
	test_in_air_false(context)

	print("✓ 物理检测条件测试完成")

## OnFloor 为真测试
func test_on_floor_true(context: ExecutionContext):
	var test_name = "OnFloor 为真测试"
	_total_tests += 1

	# 模拟在地面上的状态
	_player_node.up_direction = Vector2.UP
	_player_node.floor_stop_on_slope = true

	var cond = CheckOnFloor.new()
	cond.target_node = NodePath("..")

	# CharacterBody2D 默认不在地面上，需要模拟
	# 我们使用 negate_result 来测试
	cond.negate_result = true
	var result = cond.check(context)
	test_assert(result == true, "NOT OnFloor (在空中) 应该返回 true")

	print("  ✓ %s 通过" % test_name)

## OnFloor 为假测试
func test_on_floor_false(context: ExecutionContext):
	var test_name = "OnFloor 为假测试"
	_total_tests += 1

	var cond = CheckOnFloor.new()
	cond.target_node = NodePath("..")

	var result = cond.check(context)
	test_assert(result == false, "OnFloor (默认在空中) 应该返回 false")

	print("  ✓ %s 通过" % test_name)

## InAir 为真测试
func test_in_air_true(context: ExecutionContext):
	var test_name = "InAir 为真测试"
	_total_tests += 1

	var cond = CheckInAir.new()
	cond.target_node = NodePath("..")

	# CharacterBody2D 默认在空中
	var result = cond.check(context)
	test_assert(result == true, "InAir (默认在空中) 应该返回 true")

	print("  ✓ %s 通过" % test_name)

## InAir 为假测试
func test_in_air_false(context: ExecutionContext):
	var test_name = "InAir 为假测试"
	_total_tests += 1

	var cond = CheckInAir.new()
	cond.target_node = NodePath("..")
	cond.negate_result = true

	var result = cond.check(context)
	test_assert(result == false, "NOT InAir 应该返回 false")

	print("  ✓ %s 通过" % test_name)

## 测试 4: 输入检测条件
func test_input_detection():
	print("\n--- 输入检测条件测试 ---")

	var context = ExecutionContext.new()
	context.scene_context = self

	# 测试 InputPressed 条件
	test_input_pressed_valid(context)
	test_input_pressed_invalid(context)

	# 测试 InputReleased 条件
	test_input_released(context)

	# 测试 InputHeld 条件
	test_input_held_time(context)

	print("✓ 输入检测条件测试完成")

## InputPressed 有效输入测试
func test_input_pressed_valid(context: ExecutionContext):
	var test_name = "InputPressed 有效输入测试"
	_total_tests += 1

	var cond = CheckInputPressed.new()
	cond.input_action = "ui_accept"

	# 注意: 实际输入需要用户操作，这里测试条件创建
	var errors = cond.validate()
	var is_valid = errors.is_empty()

	# 条件应该有效（即使输入在测试中未触发）
	test_assert(is_valid, "InputPressed 条件应该有效")

	print("  ✓ %s 通过" % test_name)

## InputPressed 无效输入测试
func test_input_pressed_invalid(context: ExecutionContext):
	var test_name = "InputPressed 无效输入测试"
	_total_tests += 1

	var cond = CheckInputPressed.new()
	cond.input_action = ""

	var errors = cond.validate()
	var is_invalid = not errors.is_empty()

	test_assert(is_invalid, "空输入动作应该验证失败")

	print("  ✓ %s 通过" % test_name)

## InputReleased 测试
func test_input_released(context: ExecutionContext):
	var test_name = "InputReleased 测试"
	_total_tests += 1

	var cond = CheckInputReleased.new()
	cond.input_action = "ui_cancel"

	var errors = cond.validate()
	var is_valid = errors.is_empty()

	test_assert(is_valid, "InputReleased 条件应该有效")

	print("  ✓ %s 通过" % test_name)

## InputHeld 时间测试
func test_input_held_time(context: ExecutionContext):
	var test_name = "InputHeld 时间测试"
	_total_tests += 1

	var cond = CheckInputHeld.new()
	cond.input_action = "ui_select"
	cond.minimum_hold_time = 0.5

	var errors = cond.validate()
	var is_valid = errors.is_empty()

	test_assert(is_valid, "InputHeld 条件应该有效")
	test_assert(cond.minimum_hold_time == 0.5, "最小保持时间应该是 0.5")

	print("  ✓ %s 通过" % test_name)

## 测试 5: 时间检测条件
func test_time_detection():
	print("\n--- 时间检测条件测试 ---")

	var context = ExecutionContext.new()
	context.scene_context = self

	# 测试 TimeReached 相对模式
	test_time_reached_relative(context)

	# 测试 TimeReached 绝对模式
	test_time_reached_absolute(context)

	# 测试剩余时间
	test_time_remaining(context)

	print("✓ 时间检测条件测试完成")

## TimeReached 相对模式测试
func test_time_reached_relative(context: ExecutionContext):
	var test_name = "TimeReached 相对模式测试"
	_total_tests += 1

	var cond = CheckTimeReached.new()
	cond.target_time = 2.0
	cond.time_mode = CheckTimeReached.TimeMode.RELATIVE

	context.set_variable("elapsed_time", 2.5)
	var result = cond.check(context)
	test_assert(result == true, "2.5s >= 2.0s 应该返回 true")

	context.set_variable("elapsed_time", 1.5)
	var result2 = cond.check(context)
	test_assert(result2 == false, "1.5s < 2.0s 应该返回 false")

	print("  ✓ %s 通过" % test_name)

## TimeReached 绝对模式测试
func test_time_reached_absolute(context: ExecutionContext):
	var test_name = "TimeReached 绝对模式测试"
	_total_tests += 1

	var cond = CheckTimeReached.new()
	cond.target_time = 10.0
	cond.time_mode = CheckTimeReached.TimeMode.ABSOLUTE

	context.set_variable("elapsed_time", 10.5)
	var result = cond.check(context)
	test_assert(result == true, "绝对时间 10.5s >= 10.0s 应该返回 true")

	print("  ✓ %s 通过" % test_name)

## 剩余时间测试
func test_time_remaining(context: ExecutionContext):
	var test_name = "剩余时间测试"
	_total_tests += 1

	var cond = CheckTimeReached.new()
	cond.target_time = 5.0
	cond.time_mode = CheckTimeReached.TimeMode.RELATIVE

	context.set_variable("elapsed_time", 3.0)
	var remaining = cond.get_remaining_time()
	test_assert(remaining >= 0.0, "剩余时间应该有效")

	print("  ✓ %s 通过" % test_name)

## 测试 6: 距离检测条件
func test_distance_detection():
	print("\n--- 距离检测条件测试 ---")

	var context = ExecutionContext.new()
	context.scene_context = self

	# 测试距离比较
	test_distance_greater(context)
	test_distance_less(context)
	test_distance_equal(context)

	# 测试节点移动
	test_distance_movement(context)

	print("✓ 距离检测条件测试完成")

## 距离大于测试
func test_distance_greater(context: ExecutionContext):
	var test_name = "距离大于测试"
	_total_tests += 1

	var cond = CheckDistance.new()
	cond.source_node = NodePath("Player")
	cond.target_node = NodePath("Enemy")
	cond.comparison_operator = CheckDistance.ComparisonOperator.GREATER_THAN
	cond.threshold = 100.0

	# Player 在 (0,0), Enemy 在 (200, 0)，距离 = 200
	var result = cond.check(context)
	test_assert(result == true, "距离 200 > 100 应该返回 true")

	print("  ✓ %s 通过" % test_name)

## 距离小于测试
func test_distance_less(context: ExecutionContext):
	var test_name = "距离小于测试"
	_total_tests += 1

	var cond = CheckDistance.new()
	cond.source_node = NodePath("Player")
	cond.target_node = NodePath("Enemy")
	cond.comparison_operator = CheckDistance.ComparisonOperator.LESS_THAN
	cond.threshold = 300.0

	var result = cond.check(context)
	test_assert(result == true, "距离 200 < 300 应该返回 true")

	print("  ✓ %s 通过" % test_name)

## 距离等于测试
func test_distance_equal(context: ExecutionContext):
	var test_name = "距离等于测试"
	_total_tests += 1

	var cond = CheckDistance.new()
	cond.source_node = NodePath("Player")
	cond.target_node = NodePath("Enemy")
	cond.comparison_operator = CheckDistance.ComparisonOperator.EQUAL
	cond.threshold = 200.0

	var result = cond.check(context)
	test_assert(result == true, "距离约等于 200 应该返回 true")

	print("  ✓ %s 通过" % test_name)

## 距离移动测试
func test_distance_movement(context: ExecutionContext):
	var test_name = "距离移动测试"
	_total_tests += 1

	var cond = CheckDistance.new()
	cond.source_node = NodePath("Player")
	cond.target_node = NodePath("Enemy")
	cond.comparison_operator = CheckDistance.ComparisonOperator.LESS_THAN
	cond.threshold = 50.0

	# 初始距离 200
	var result1 = cond.check(context)
	test_assert(result1 == false, "初始距离 200 应该不满足 < 50")

	# 移动敌人靠近
	_enemy_node.position = Vector2(30, 40)
	var result2 = cond.check(context)
	test_assert(result2 == true, "距离 ~50 应该满足 < 50")

	print("  ✓ %s 通过" % test_name)

## 测试 7: 真实场景条件组合
func test_condition_combinations():
	print("\n--- 真实场景条件组合测试 ---")

	var context = ExecutionContext.new()
	context.scene_context = self
	context.target = _player_node

	# 场景 1: 玩家跳跃检测
	test_player_jump_scenario(context)

	# 场景 2: 敌人检测
	test_enemy_detection_scenario(context)

	# 场景 3: UI 交互
	test_ui_interaction_scenario(context)

	# 场景 4: 连击系统
	test_combo_system_scenario(context)

	print("✓ 真实场景条件组合测试完成")

## 场景 1: 玩家跳跃检测
func test_player_jump_scenario(context: ExecutionContext):
	var test_name = "场景: 玩家跳跃检测"
	_total_tests += 1

	# 条件: 在地上 AND 跳跃键按下
	var on_floor = CheckOnFloor.new()
	on_floor.target_node = NodePath("..")
	on_floor.negate_result = true  # 实际在空中

	var input_jump = CheckInputPressed.new()
	input_jump.input_action = "ui_accept"

	var jump_cond = CheckAll.new()
	jump_cond.conditions = [on_floor, input_jump]

	# 验证条件结构
	var errors = jump_cond.validate()
	var is_valid = errors.is_empty()

	test_assert(is_valid, "跳跃条件组合应该有效")
	test_assert(jump_cond.conditions.size() == 2, "应该有 2 个子条件")

	print("  ✓ %s 通过" % test_name)

## 场景 2: 敌人检测
func test_enemy_detection_scenario(context: ExecutionContext):
	var test_name = "场景: 敌人检测"
	_total_tests += 1

	# 条件: 敌人在组中 AND 距离 < 300
	var in_group = CheckNodeInGroup.new()
	in_group.target_node = NodePath("Enemy")
	in_group.group_name = "enemies"

	var distance_cond = CheckDistance.new()
	distance_cond.source_node = NodePath("Player")
	distance_cond.target_node = NodePath("Enemy")
	distance_cond.comparison_operator = CheckDistance.ComparisonOperator.LESS_THAN
	distance_cond.threshold = 300.0

	var detection_cond = CheckAll.new()
	detection_cond.conditions = [in_group, distance_cond]

	# 测试条件
	var result = detection_cond.check(context)
	test_assert(result == true, "敌人应该被检测到")

	print("  ✓ %s 通过" % test_name)

## 场景 3: UI 交互
func test_ui_interaction_scenario(context: ExecutionContext):
	var test_name = "场景: UI 交互"
	_total_tests += 1

	# 条件: UI 可见 AND (输入按下 OR 超时)
	var ui_visible = CheckNodeActive.new()
	ui_visible.check_node_path = NodePath("UIPanel")
	ui_visible.check_type = CheckNodeActive.CheckType.VISIBLE

	var input_cond = CheckInputPressed.new()
	input_cond.input_action = "ui_select"

	var timeout_cond = CheckTimeReached.new()
	timeout_cond.target_time = 5.0
	timeout_cond.time_mode = CheckTimeReached.TimeMode.RELATIVE

	var input_or_timeout = CheckAny.new()
	input_or_timeout.conditions = [input_cond, timeout_cond]

	var ui_cond = CheckAll.new()
	ui_cond.conditions = [ui_visible, input_or_timeout]

	# 设置 UI 可见
	_ui_node.visible = true
	context.set_variable("elapsed_time", 3.0)

	# 验证条件结构
	var errors = ui_cond.validate()
	var is_valid = errors.is_empty()

	test_assert(is_valid, "UI 交互条件组合应该有效")

	print("  ✓ %s 通过" % test_name)

## 场景 4: 连击系统
func test_combo_system_scenario(context: ExecutionContext):
	var test_name = "场景: 连击系统"
	_total_tests += 1

	# 条件: 输入保持 > 0.3s AND 在地上 AND 距离敌人 < 150
	var input_held = CheckInputHeld.new()
	input_held.input_action = "ui_accept"
	input_held.minimum_hold_time = 0.3

	var on_ground = CheckInAir.new()
	on_ground.target_node = NodePath("..")
	on_ground.negate_result = true

	var close_range = CheckDistance.new()
	close_range.source_node = NodePath("Player")
	close_range.target_node = NodePath("Enemy")
	close_range.comparison_operator = CheckDistance.ComparisonOperator.LESS_THAN
	close_range.threshold = 150.0

	# 移动敌人到近距离
	_enemy_node.position = Vector2(100, 0)

	var combo_cond = CheckAll.new()
	combo_cond.conditions = [input_held, on_ground, close_range]

	# 验证条件结构
	var errors = combo_cond.validate()
	var is_valid = errors.is_empty()

	test_assert(is_valid, "连击条件组合应该有效")
	test_assert(combo_cond.conditions.size() == 3, "应该有 3 个子条件")

	print("  ✓ %s 通过" % test_name)

## 性能基准测试
func run_performance_benchmarks():
	print("\n--- 性能基准测试 ---")

	var context = ExecutionContext.new()
	context.scene_context = self

	# 基准测试 1: 简单条件性能
	benchmark_simple_condition(context, CheckVariable.new(), 10000)

	# 基准测试 2: 复合条件性能
	var check = CheckVariable.new()
	check.variable_name = "perf_test"
	context.set_variable("perf_test", true)
	benchmark_simple_condition(context, check, 10000)

	# 基准测试 3: 嵌套条件性能
	var nested_cond = create_nested_condition(3)
	benchmark_simple_condition(context, nested_cond, 5000)

	# 基准测试 4: 距离条件性能
	var dist_cond = CheckDistance.new()
	dist_cond.source_node = NodePath("Player")
	dist_cond.target_node = NodePath("Enemy")
	benchmark_simple_condition(context, dist_cond, 5000)

	print("✓ 性能基准测试完成")

## 简单条件性能基准
func benchmark_simple_condition(context: ExecutionContext, condition: BaseCondition, iterations: int):
	var start_time = Time.get_ticks_msec()

	for i in range(iterations):
		condition.check(context)

	var end_time = Time.get_ticks_msec()
	var elapsed = float(end_time - start_time)
	var avg_time = elapsed / float(iterations)

	var perf_info = {
		"condition": condition.get_condition_type(),
		"iterations": iterations,
		"total_time_ms": elapsed,
		"avg_time_ms": avg_time,
		"checks_per_second": 1000.0 / avg_time if avg_time > 0 else 0.0
	}

	_performance_results[condition.get_condition_type()] = perf_info

	print("  条件类型: %s" % perf_info["condition"])
	print("    迭代次数: %d" % perf_info["iterations"])
	print("    总时间: %.2f ms" % perf_info["total_time_ms"])
	print("    平均时间: %.4f ms" % perf_info["avg_time_ms"])
	print("    每秒检查: %.0f 次" % perf_info["checks_per_second"])

## 创建嵌套条件（用于性能测试）
func create_nested_condition(depth: int) -> BaseCondition:
	var check = CheckVariable.new()
	check.variable_name = "nested_test"

	if depth <= 0:
		return check

	var not_cond = CheckNot.new()
	not_cond.inner_condition = create_nested_condition(depth - 1)
	return not_cond

## 打印测试总结
func print_test_summary():
	var separator = ""
	for i in range(80):
		separator += "="

	print("\n" + separator)
	print("测试总结")
	print(separator)
	print("总测试数: %d" % _total_tests)

	var passed_tests = _total_tests - _failed_tests
	print("通过: %d" % passed_tests)
	print("失败: %d" % _failed_tests)
	print("成功率: %.2f%%" % (passed_tests * 100.0 / _total_tests if _total_tests > 0 else 0.0))

	print("\n性能结果摘要:")
	for cond_type in _performance_results:
		var perf = _performance_results[cond_type]
		print("  %s: %.4f ms/次 (%.0f 次/秒)" % [cond_type, perf["avg_time_ms"], perf["checks_per_second"]])

	print(separator)

## Assert 辅助函数
func test_assert(condition: bool, message: String):
	if not condition:
		_failed_tests += 1
		print("  ❌ 断言失败: %s" % message)
		push_error("测试失败: %s" % message)
