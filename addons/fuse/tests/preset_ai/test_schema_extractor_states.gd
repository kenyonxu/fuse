# addons/fuse/tests/preset_ai/test_schema_extractor_states.gd
extends Node

const SchemaExtractor := preload("res://addons/fuse/editor/preset_ai/schema_extractor.gd")

var _fail := 0

func _check(cond: bool, msg: String) -> void:
	if cond: print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)

func _ready():
	print("=== test_schema_extractor_states ===")
	_test_math_operation_nested_gates()
	_test_wait_time_scope()
	_test_sendevent_unchanged()
	_test_unique_names()
	print("=== 结果: %d 失败 ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _schema_of(type_name: String) -> Dictionary:
	var by_name := {}
	for p in SchemaExtractor.get_parameter_schema(type_name):
		by_name[p["name"]] = p
	return by_name

func _test_math_operation_nested_gates() -> void:
	var s := _schema_of("MathOperation")
	_check(s.has("operand_a_variable"), "operand_a_variable 已收录")
	if s.has("operand_a_variable"):
		_check(s["operand_a_variable"].get("requires", {}) == {"operand_a_source": 1},
			"operand_a_variable.requires == {operand_a_source: 1}")
	_check(s.has("operand_a_custom_scope_id"), "三层深度的 operand_a_custom_scope_id 已收录")
	if s.has("operand_a_custom_scope_id"):
		_check(s["operand_a_custom_scope_id"].get("requires", {}) ==
			{"operand_a_source": 1, "operand_a_scope": 1, "operand_a_scope_source": 1},
			"operand_a_custom_scope_id.requires 为三层最小门控")
	_check(s.has("operand_a_scope_source"), "operand_a_scope_source 已收录")
	_check(not s["operation_type"].has("requires"), "静态参数 operation_type 无 requires 键")
	_check(not s["operand_a_value"].has("requires"), "默认态即注册的 operand_a_value 无 requires 键")

func _test_wait_time_scope() -> void:
	var s := _schema_of("Wait")
	_check(s.has("time_scope"), "Wait.time_scope 已收录")
	if s.has("time_scope"):
		_check(s["time_scope"].get("requires", {}) == {"value_source": 1},
			"time_scope.requires == {value_source: 1}")
	_check(not s["wait_time"].has("requires"), "wait_time 无 requires（默认态注册）")

func _test_sendevent_unchanged() -> void:
	var params := SchemaExtractor.get_parameter_schema("SendEvent")
	_check(params.size() == 3, "SendEvent 仍为 3 参数（旧条目回归护栏，实际 %d）" % params.size())
	for p in params:
		_check(not p.has("requires"), "SendEvent.%s 无 requires" % p["name"])

func _test_unique_names() -> void:
	var names := []
	for p in SchemaExtractor.get_parameter_schema("MathOperation"):
		names.append(p["name"])
	var uniq := {}
	for n in names: uniq[n] = true
	_check(uniq.size() == names.size(), "参数名无重复（BFS 各状态去重）")
