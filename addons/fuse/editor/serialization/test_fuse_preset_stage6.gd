# addons/fuse/editor/serialization/test_fuse_preset_stage6.gd
@tool
class_name TestFusePresetStage6
extends RefCounted

## Stage 6 集成验证脚本
## 运行方式：在 Godot 编辑器中通过工具脚本调用 TestFusePresetStage6.run_all()


static func run_all() -> Dictionary:
	var results := {
		"passed": 0,
		"failed": 0,
		"tests": []
	}

	# 1-4. 各层级 roundtrip
	_run_test(results, "L1_roundtrip", _test_l1_roundtrip)
	_run_test(results, "L2_roundtrip", _test_l2_roundtrip)
	_run_test(results, "L3_roundtrip", _test_l3_roundtrip)
	_run_test(results, "L4_roundtrip", _test_l4_roundtrip)

	# 5-6. 边界
	_run_test(results, "empty_preset", _test_empty_preset)
	_run_test(results, "unknown_level", _test_unknown_level)

	# 注意: L2/L3/L4 校验测试依赖 fuse_inspector_plugin.gd 中的 _validate_before_export
	# 实例方法，静态测试无法直接调用。校验逻辑通过编辑器手动测试验证。

	print("\n=== Stage 6 验证结果 ===")
	print("通过: %d / 失败: %d" % [results["passed"], results["failed"]])
	for t in results["tests"]:
		var status := "PASS" if t["passed"] else "FAIL"
		print("%s %s: %s" % [status, t["name"], t["message"]])

	return results


static func _run_test(results: Dictionary, name: String, test_fn: Callable) -> void:
	var entry := {"name": name, "passed": false, "message": ""}
	results["tests"].append(entry)

	var outcome = test_fn.call()
	if outcome is Dictionary and outcome.get("ok", false):
		entry["passed"] = true
		entry["message"] = outcome.get("msg", "OK")
		results["passed"] += 1
	else:
		var msg: String = ""
		if outcome is String:
			msg = outcome
		elif outcome is Dictionary:
			msg = outcome.get("msg", "失败")
		entry["message"] = msg
		results["failed"] += 1


# ---- L1: ActionRunner ----

static func _test_l1_roundtrip() -> Dictionary:
	var preset := FusePreset.new()
	preset.level = "L1"
	preset.display_name = "Test L1"
	preset.category = "test"
	preset.description = "L1 test preset"
	preset.version = "2.0"

	var json_data := preset.to_json()
	var ok := true
	var msg := ""

	if json_data["level"] != "L1":
		ok = false; msg = "L1 to_json level mismatch: " + json_data["level"]
	elif not json_data.has("action_runner"):
		ok = false; msg = "L1 to_json missing action_runner"
	elif not json_data["action_runner"].has("instructions"):
		ok = false; msg = "L1 to_json missing instructions"
	else:
		var restored := FusePreset.from_json(json_data)
		if restored.level != "L1":
			ok = false; msg = "L1 from_json level mismatch"
		elif restored.display_name != "Test L1":
			ok = false; msg = "L1 from_json name mismatch"
		else:
			msg = "L1 roundtrip OK"

	return {"ok": ok, "msg": msg}


# ---- L2: Trigger ----

static func _test_l2_roundtrip() -> Dictionary:
	var preset := FusePreset.new()
	preset.level = "L2"
	preset.display_name = "Test L2"
	preset.event_json = {"type": "EventOnKeyPressed", "key": "Space"}
	preset.trigger_config = {"trigger_once": true, "cooldown_mode": 1, "cooldown_time": 2.0}
	preset.instructions = []

	var json_data := preset.to_json()
	var ok := true
	var msg := ""

	if json_data["level"] != "L2":
		ok = false; msg = "L2 to_json level mismatch"
	elif not json_data.has("event"):
		ok = false; msg = "L2 to_json missing event"
	elif not json_data.has("trigger_config"):
		ok = false; msg = "L2 to_json missing trigger_config"
	elif not json_data.has("action_runner"):
		ok = false; msg = "L2 to_json missing action_runner"
	else:
		var restored := FusePreset.from_json(json_data)
		if restored.level != "L2":
			ok = false; msg = "L2 from_json level mismatch"
		elif restored.event_json.get("type") != "EventOnKeyPressed":
			ok = false; msg = "L2 event type mismatch"
		elif restored.trigger_config.get("trigger_once") != true:
			ok = false; msg = "L2 trigger_once mismatch"
		else:
			msg = "L2 roundtrip OK"

	return {"ok": ok, "msg": msg}


# ---- L3: Runner ----

static func _test_l3_roundtrip() -> Dictionary:
	var preset := FusePreset.new()
	preset.level = "L3"
	preset.display_name = "Test L3"
	preset.signal_binding = {"signal_name": "body_entered"}
	preset.instructions = []

	var json_data := preset.to_json()
	var ok := true
	var msg := ""

	if json_data["level"] != "L3":
		ok = false; msg = "L3 to_json level mismatch"
	elif not json_data.has("signal_binding"):
		ok = false; msg = "L3 to_json missing signal_binding"
	elif json_data["signal_binding"].get("signal_name") != "body_entered":
		ok = false; msg = "L3 signal_name mismatch"
	else:
		var restored := FusePreset.from_json(json_data)
		if restored.level != "L3":
			ok = false; msg = "L3 from_json level mismatch"
		elif restored.signal_binding.get("signal_name") != "body_entered":
			ok = false; msg = "L3 restored signal_name mismatch"
		else:
			msg = "L3 roundtrip OK"

	return {"ok": ok, "msg": msg}


# ---- L4: MultiEventTrigger ----

static func _test_l4_roundtrip() -> Dictionary:
	var preset := FusePreset.new()
	preset.level = "L4"
	preset.display_name = "Test L4"
	preset.trigger_config = {"use_parallel_condition_evaluation": false}
	preset.event_bindings_json = [
		{
			"binding_config": {"enabled": true, "trigger_once": false},
			"event": {"type": "EventOnAreaEnter"},
			"action_runner": {"execution_mode": 0, "instructions": []},
			"conditions": [{"type": "ConditionIsPlayer", "target_node": "../Player"}]
		}
	]

	var json_data := preset.to_json()
	var ok := true
	var msg := ""

	if json_data["level"] != "L4":
		ok = false; msg = "L4 to_json level mismatch"
	elif not json_data.has("event_bindings"):
		ok = false; msg = "L4 to_json missing event_bindings"
	elif not json_data.has("trigger_config"):
		ok = false; msg = "L4 to_json missing trigger_config"
	elif json_data.has("action_runner"):
		ok = false; msg = "L4 to_json should NOT have top-level action_runner"
	else:
		var restored := FusePreset.from_json(json_data)
		if restored.level != "L4":
			ok = false; msg = "L4 from_json level mismatch"
		elif restored.event_bindings_json.size() != 1:
			ok = false; msg = "L4 binding count mismatch: " + str(restored.event_bindings_json.size())
		elif restored.trigger_config.get("use_parallel_condition_evaluation") != false:
			ok = false; msg = "L4 parallel eval mismatch"
		else:
			msg = "L4 roundtrip OK"

	return {"ok": ok, "msg": msg}


# ---- 边界测试 ----

static func _test_empty_preset() -> Dictionary:
	var preset := FusePreset.new()
	var json_data := preset.to_json()
	var ok := true
	var msg := "Empty preset OK"

	if json_data["level"] != "L1":
		ok = false; msg = "Empty preset should default to L1"
	elif not json_data.has("action_runner"):
		ok = false; msg = "Empty L1 should have action_runner"

	return {"ok": ok, "msg": msg}


static func _test_unknown_level() -> Dictionary:
	var preset := FusePreset.new()
	preset.level = "L99"
	var json_data := preset.to_json()
	var ok := true
	var msg := "Unknown level OK"

	if json_data["level"] != "L99":
		ok = false; msg = "Unknown level not preserved"
	elif json_data.has("action_runner"):
		ok = false; msg = "Unknown level should not have action_runner"

	return {"ok": ok, "msg": msg}
