# addons/fuse/tests/test_stage65_extract.gd
extends SceneTree

## Stage 6.5 验证：InstructionAnalyzer 反射 + 命名启发式提取
## 运行：godot --headless --path <project> -s addons/fuse/tests/test_stage65_extract.gd

func _initialize() -> void:
	_test_variables_export()
	_test_nodepath_dynamic()
	_test_condition_node_extraction()
	_test_condition_variable_extraction()
	_test_event_node_extraction()
	print("\n[Stage 6.5] 测试完成")
	quit()


## 变量提取（SetIntVariable，@export var 模式）—— 验证修 bug
func _test_variables_export() -> void:
	print("\n=== 变量提取（SetIntVariable, @export var）===")
	var si = load("res://addons/fuse/instructions/variables/set_int_variable.gd").new()
	si.target_variable = "health"
	si.from_variable = "max_health"
	var report := {"variables": {"local": [], "scope": [], "global": []}, "nodes": []}
	InstructionAnalyzer._extract_variables(si, report)
	var local: Array = report["variables"]["local"]
	print("  local 变量: ", local)
	# 期望: health + max_health 两个（修复前: 0 个，因硬编码 variable_name 失效）
	var names := []
	for e in local:
		names.append(e["name"])
	assert(names.has("health"), "应提取 target_variable=health（修复前漏）")
	assert(names.has("max_health"), "应提取 from_variable=max_health")
	print("  ✓ 变量提取修复生效（health + max_health）")


## NodePath 提取（find_node，动态属性模式）—— 验证覆盖动态属性
func _test_nodepath_dynamic() -> void:
	print("\n=== NodePath 提取（find_node, 动态属性）===")
	var fn = load("res://addons/fuse/instructions/node_operations/find_node.gd").new()
	fn.target_node_path = NodePath("Player")
	var report := {"nodes": []}
	InstructionAnalyzer._extract_nodepaths(fn, report)
	print("  nodes: ", report["nodes"])
	# 期望: 含 "Player"（动态属性 target_node_path，命名启发式 *_node_path 命中）
	assert(report["nodes"].has("Player"), "应提取动态属性 target_node_path=Player")
	print("  ✓ 动态属性 NodePath 提取生效（Player）")


## Condition 节点提取（CheckNodeExists, check_node_path）
func _test_condition_node_extraction() -> void:
	print("\n=== Condition 节点提取（CheckNodeExists, check_node_path）===")
	var cond = load("res://addons/fuse/conditions/node/check_node_exists.gd").new()
	cond.check_node_path = NodePath("Player")
	var report := {"nodes": []}
	InstructionAnalyzer._extract_nodepaths(cond, report)
	print("  nodes: ", report["nodes"])
	assert(report["nodes"].has("Player"), "应提取 check_node_path=Player")
	print("  \u2713 Condition节点提取生效（Player）")


## Condition 变量提取（CheckVariable, variable_name）
func _test_condition_variable_extraction() -> void:
	print("\n=== Condition 变量提取（CheckVariable, variable_name）===")
	var cond = load("res://addons/fuse/conditions/variable/check_variable.gd").new()
	cond.variable_name = "health"
	var report := {"variables": {"local": [], "scope": [], "global": []}}
	InstructionAnalyzer._extract_variables(cond, report)
	var local: Array = report["variables"]["local"]
	print("  local 变量: ", local)
	assert(local.size() > 0, "应提取到至少一个变量")
	assert(local[0]["name"] == "health", "应提取 variable_name=health")
	print("  \u2713 Condition变量提取生效（health）")


## Event 节点提取（OnNavigationTargetReached, agent_node）
func _test_event_node_extraction() -> void:
	print("\n=== Event 节点提取（OnNavigationTargetReached, agent_node）===")
	var event = load("res://addons/fuse/events/navigation/on_navigation_target_reached.gd").new()
	event.agent_node = NodePath("Agent")
	var report := {"nodes": []}
	InstructionAnalyzer._extract_nodepaths(event, report)
	print("  nodes: ", report["nodes"])
	assert(report["nodes"].has("Agent"), "应提取 agent_node=Agent")
	print("  \u2713 Event节点提取生效（Agent）")
