# addons/fuse/tests/preset_ai/test_codec_inline_export.gd
extends Node

const PresetValueCodec := preload("res://addons/fuse/core/serialization/preset_value_codec.gd")
const OnInterval := preload("res://addons/fuse/events/lifecycle/on_interval.gd")
const CheckScopeVariable := preload("res://addons/fuse/conditions/scope/check_scope_variable.gd")

var _fail := 0

func _ready():
	# 1) 场景内嵌 condition（resource_path 含 ::）必须序列化为 inline dict
	var event := OnInterval.new()
	event.interval_seconds = 1.0
	var cond := CheckScopeVariable.new()
	cond.variable_name = "stopped"
	# 模拟场景内嵌 sub-resource：resource_path 含 ::
	cond.resource_path = "res://demos/fuse/brickian/title_scene.tscn::Resource_fknqa"
	event.stop_condition = cond
	var data := PresetValueCodec.serialize_event(event)
	var ok: bool = data.get("stop_condition", null) is Dictionary and data["stop_condition"].get("type", "") == "CheckScopeVariable"
	if ok:
		print("✓ 场景内嵌 condition 序列化为 inline dict")
	else:
		_fail += 1
		push_error("✗ 期望 inline dict，实际: %s" % str(data.get("stop_condition")))

	# 2) 无 :: 的外部资源仍走路径引用（顶层恒为 dict，路径引用仅出现在嵌套字段）
	var ext := CheckScopeVariable.new()
	ext.resource_path = "res://addons/fuse/presets/conditions/my_cond.tres"
	var data2 := PresetValueCodec.serialize_condition(ext)
	var ok2: bool = data2 is Dictionary and data2.get("type", "") == "CheckScopeVariable"
	if ok2:
		print("✓ 外部 .tres condition 仍为完整 dict")
	else:
		_fail += 1
		push_error("✗ 外部 .tres condition 顶层应为 dict，实际: %s" % str(data2))

	# 3) 非 Base* 的场景内嵌引擎资源（嵌在组件字段里）必须 inline dict，而非 :: 私有引用字符串
	var curve := Curve.new()
	curve.resource_path = "res://demos/fuse/brickian/title_scene.tscn::Resource_curv9"
	var holder := CheckScopeVariable.new()
	holder.variable_name = "speed"
	holder.expected_value = curve
	var data3 := PresetValueCodec.serialize_condition(holder)
	var ev: Variant = data3.get("expected_value", null)
	var ok3: bool = ev is Dictionary and (ev as Dictionary).get("type", "") == "Curve"
	if ok3:
		print("✓ 场景内嵌引擎资源（Curve）序列化为 inline dict")
	else:
		_fail += 1
		push_error("✗ 期望 inline dict，实际: %s" % str(ev))

	# 4) 无 :: 的外部引擎资源嵌套时仍为路径引用字符串（防过度修复）
	var curve_ext := Curve.new()
	curve_ext.resource_path = "res://addons/fuse/presets/my_curve.tres"
	var holder2 := CheckScopeVariable.new()
	holder2.variable_name = "speed"
	holder2.expected_value = curve_ext
	var data4 := PresetValueCodec.serialize_condition(holder2)
	var ev4: Variant = data4.get("expected_value", null)
	var ok4: bool = ev4 is String and (ev4 as String) == "res://addons/fuse/presets/my_curve.tres"
	if ok4:
		print("✓ 外部 .tres 引擎资源嵌套时仍为路径字符串")
	else:
		_fail += 1
		push_error("✗ 期望路径字符串，实际: %s" % str(ev4))

	print("=== 结果: %d 失败 ===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
