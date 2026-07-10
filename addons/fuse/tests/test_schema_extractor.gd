extends Node
const SchemaExtractor = preload("res://addons/fuse/editor/preset_ai/schema_extractor.gd")

var _fail := 0

func _ready() -> void:
	_test_send_event_schema()
	_test_filters_base_properties()
	_test_nested_instructions_marked()
	print("\n=== 结果: %d 处失败 ===" % _fail)
	if _fail > 0: push_error("schema 提取测试失败: %d 处" % _fail)
	get_tree().quit()

func _check(c: bool, msg: String) -> void:
	if c: print("  PASS: ", msg)
	else: _fail += 1; push_error("  FAIL: ", msg)

func _test_send_event_schema() -> void:
	print("\n--- SendEvent schema 含 event_name/event_args ---")
	var s := SchemaExtractor.get_parameter_schema("SendEvent")
	var names: Array = []
	for p in s: names.append(p.name)
	_check("event_name" in names, "含 event_name")
	_check("event_args" in names, "含 event_args")

func _test_filters_base_properties() -> void:
	print("\n--- 过滤基类属性（log_level/script/resource_name 等）---")
	var s := SchemaExtractor.get_parameter_schema("SendEvent")
	for p in s:
		_check(p.name not in ["log_level","script","resource_name","completion_timing","execution_mode","metadata","resource_local_to_scene"], "无基类: %s" % p.name)
		_check(not p.name.begins_with("_"), "无 _ 前缀: %s" % p.name)

func _test_nested_instructions_marked() -> void:
	print("\n--- 嵌套指令数组标记（ForEach.loop_instructions）---")
	var s := SchemaExtractor.get_parameter_schema("ForEach")
	var loop_param = null
	for p in s:
		if p.name == "loop_instructions": loop_param = p
	_check(loop_param != null, "含 loop_instructions")
	if loop_param:
		_check(loop_param.get("is_nested_instructions") == true, "loop_instructions 标记嵌套")
