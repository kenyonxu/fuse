# 测试：AddVelocity 指令——叠加语义/变量源/非物理体/round-trip
extends Node

var _fail: int = 0

func _ready() -> void:
	print("=== AddVelocity 测试开始 ===")
	_test_additive_semantics()
	_test_variable_source()
	_test_non_physics_error()
	_test_roundtrip()
	_test_replace_modes()
	print("=== AddVelocity 测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 叠加语义：现有速度 + 冲量（非覆盖）
func _test_additive_semantics() -> void:
	print("\n--- 叠加语义 ---")
	var body := CharacterBody2D.new()
	body.name = "Body1"
	add_child(body)
	body.velocity = Vector2(50, -20)

	var inst := AddVelocity.new()
	inst.target_node = NodePath("../Body1")
	inst.impulse = Vector2(-300, 0)
	var context := ExecutionContext.new(body, body)
	inst.execute(context)

	_check(body.velocity == Vector2(-250, -20), "叠加（50-300=-250，-20 保留，实际 %s）" % str(body.velocity))
	_check(inst.is_completed(), "同步完成")
	body.queue_free()

## 冲量从变量读（Vector2）
func _test_variable_source() -> void:
	print("\n--- 变量源冲量 ---")
	var body := CharacterBody2D.new()
	body.name = "Body2"
	add_child(body)
	body.velocity = Vector2.ZERO

	var context := ExecutionContext.new(body, body)
	context.set_variable("kb_vec", Vector2(-400, -150))

	var inst := AddVelocity.new()
	inst.target_node = NodePath("../Body2")
	inst.impulse_source = AddVelocity.ImpulseSource.VARIABLE
	inst.impulse_variable = "kb_vec"
	inst.execute(context)

	_check(body.velocity == Vector2(-400, -150), "变量冲量生效（实际 %s）" % str(body.velocity))

	# 非 Vector2 变量报错
	context.set_variable("kb_bad", 123)
	var inst2 := AddVelocity.new()
	inst2.target_node = NodePath("../Body2")
	inst2.impulse_source = AddVelocity.ImpulseSource.VARIABLE
	inst2.impulse_variable = "kb_bad"
	inst2.execute(context)
	_check(inst2.has_error(), "非 Vector2 变量报错")
	body.queue_free()

## 非物理体报错
func _test_non_physics_error() -> void:
	print("\n--- 非物理体 ---")
	var plain := Node.new()
	plain.name = "PlainNode"
	add_child(plain)

	var inst := AddVelocity.new()
	inst.target_node = NodePath("../PlainNode")
	inst.impulse = Vector2(10, 0)
	var context := ExecutionContext.new(plain, plain)
	inst.execute(context)
	_check(inst.has_error(), "无 velocity 属性报错")
	plain.queue_free()

## round-trip
func _test_roundtrip() -> void:
	print("\n--- round-trip ---")
	var inst := AddVelocity.new()
	inst.target_node = NodePath("../SomeBody")
	inst.impulse = Vector2(-300, 0)
	inst.impulse_source = AddVelocity.ImpulseSource.VARIABLE
	inst.impulse_variable = "kb_vec"
	var data := PresetValueCodec.serialize_instruction(inst)
	_check(data.has("impulse") and data.has("impulse_source") and data.has("impulse_variable"), "序列化含全部新键")
	var restored := PresetValueCodec.deserialize_instruction(data)
	_check(restored is AddVelocity and restored.impulse_variable == "kb_vec", "还原正确")


## 半覆盖模式：REPLACE_X 覆盖 x 保留 y / REPLACE_Y 反之
func _test_replace_modes() -> void:
	print("\n--- 半覆盖模式 ---")
	var body := CharacterBody2D.new()
	body.name = "BodyR"
	add_child(body)

	# REPLACE_X：移动中受击 (+200, 下落 +150) → x 覆盖为 -300，y 保留
	body.velocity = Vector2(200, 150)
	var inst := AddVelocity.new()
	inst.target_node = NodePath("../BodyR")
	inst.impulse = Vector2(-300, 0)
	inst.replace_mode = AddVelocity.ReplaceMode.REPLACE_X
	var context := ExecutionContext.new(body, body)
	inst.execute(context)
	_check(body.velocity == Vector2(-300, 150), "REPLACE_X：x 覆盖 -300，y 保留 150（实际 %s）" % str(body.velocity))

	# REPLACE_Y：弹板场景 (水平 +100, 下落 +200) → y 覆盖为 -400，x 保留
	body.velocity = Vector2(100, 200)
	var inst2 := AddVelocity.new()
	inst2.target_node = NodePath("../BodyR")
	inst2.impulse = Vector2(0, -400)
	inst2.replace_mode = AddVelocity.ReplaceMode.REPLACE_Y
	inst2.execute(context)
	_check(body.velocity == Vector2(100, -400), "REPLACE_Y：y 覆盖 -400，x 保留 100（实际 %s）" % str(body.velocity))

	# round-trip 含 replace_mode
	var inst3 := AddVelocity.new()
	inst3.target_node = NodePath("../BodyR")
	inst3.impulse = Vector2(-300, 0)
	inst3.replace_mode = AddVelocity.ReplaceMode.REPLACE_X
	var data := PresetValueCodec.serialize_instruction(inst3)
	_check(data.has("replace_mode") and data.get("replace_mode") == 1, "序列化含 replace_mode")
	var restored := PresetValueCodec.deserialize_instruction(data)
	_check(restored is AddVelocity and restored.replace_mode == AddVelocity.ReplaceMode.REPLACE_X, "还原 replace_mode")
	body.queue_free()
