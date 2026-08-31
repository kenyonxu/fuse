# addons/fuse/tests/topology/test_export_topology.gd
extends Node

const TopologyExport := preload("res://addons/fuse/editor/topology/topology_export.gd")

var _fail := 0

func _check(cond: bool, msg: String) -> void:
	if cond: print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)

func _ready():
	print("=== test_export_topology ===")
	_test_sanitize()
	_test_export_real_scene()
	print("=== 结果: %d 失败 ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _test_sanitize() -> void:
	var dirty := {
		"path": NodePath("../Target"),
		"obj": RefCounted.new(),
		"plain": [1, "a", true],
		"nested": {"x": NodePath("A/B")},
	}
	var clean: Variant = TopologyExport.sanitize_for_json(dirty)
	var s := JSON.stringify(clean)
	var parsed: Variant = JSON.parse_string(s)
	_check(parsed is Dictionary, "sanitized 值可 JSON 往返")
	_check(str(clean["path"]) == "../Target", "NodePath 转字符串")
	_check(clean["obj"] is Dictionary and clean["obj"].has("__object__"), "Object 转浅字典")

func _test_export_real_scene() -> void:
	var scene: PackedScene = load("res://demos/fuse/brickian/game_scene.tscn")
	var inst := scene.instantiate()
	add_child(inst)
	var topology: Dictionary = InstructionAnalyzer.build_topology(inst)
	# 显式 stem（≠ scene_name）证明产物名来自参数而非回退
	var out_path: String = TopologyExport.export_to_json(topology, "user://topology_test", "explicit_stem")
	_check(not out_path.is_empty(), "导出成功返回路径")
	if out_path.is_empty():
		return
	_check(out_path.get_file() == "explicit_stem.json",
		"显式 file_stem 决定文件名（实际 %s）" % out_path.get_file())
	var text := FileAccess.get_file_as_string(out_path)
	var parsed: Variant = JSON.parse_string(text)
	_check(parsed is Dictionary, "导出文件是合法 JSON")
	if parsed is Dictionary:
		_check(parsed.has("triggers") and (parsed["triggers"] as Array).size() >= 1,
			"triggers 非空（实际 %d）" % (parsed["triggers"] as Array).size())
		_check(parsed.has("cross_references") and parsed.has("variable_analysis"), "关联与变量分析键在")
	inst.queue_free()
