# 测试：GetAnimationLength 指令——库前缀/裸名/错误路径/变量保存
extends Node

var _fail: int = 0

func _ready() -> void:
	print("=== GetAnimationLength 测试开始 ===")
	_test_builtin_library_length()
	_test_prefixed_library_length()
	_test_animation_not_found()
	_test_node_not_found()
	_test_save_to_global()
	print("=== GetAnimationLength 测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

## 构造带动画库的 AnimationPlayer：内置库 "hit"(0.5s) + 具名库 "player" 的 "player/hit"(0.233s)
func _build_player() -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = "TestAP"
	add_child(player)
	var builtin_lib := AnimationLibrary.new()
	var hit := Animation.new()
	hit.length = 0.5
	builtin_lib.add_animation("hit", hit)
	player.add_animation_library("", builtin_lib)
	var named_lib := AnimationLibrary.new()
	var named_hit := Animation.new()
	named_hit.length = 0.233
	named_lib.add_animation("hit", named_hit)
	player.add_animation_library("player", named_lib)
	return player

func _make_instruction(ap_path: String, anim: String, save_var: String) -> GetAnimationLength:
	var inst := GetAnimationLength.new()
	inst.target_node = NodePath(ap_path)
	inst.animation_name = anim
	inst.save_to_variable = save_var
	return inst

## 内置库裸名：hit → 0.5
func _test_builtin_library_length() -> void:
	print("\n--- 内置库裸名 ---")
	var ap := _build_player()
	var trigger := Node.new()
	trigger.name = "T1"
	add_child(trigger)
	var context := ExecutionContext.new(ap, trigger)
	var inst := _make_instruction("../TestAP", "hit", "anim_len")
	inst.execute(context)
	_check(context.get_variable("anim_len") == 0.5, "内置库 hit 时长 0.5（实际 %s）" % str(context.get_variable("anim_len")))
	ap.queue_free()
	trigger.queue_free()

## 具名库前缀：player/hit → 0.233
func _test_prefixed_library_length() -> void:
	print("\n--- 具名库前缀 ---")
	var ap := _build_player()
	var trigger := Node.new()
	trigger.name = "T2"
	add_child(trigger)
	var context := ExecutionContext.new(ap, trigger)
	var inst := _make_instruction("../TestAP", "player/hit", "anim_len2")
	inst.execute(context)
	_check(context.get_variable("anim_len2") == 0.233, "player/hit 时长 0.233（实际 %s）" % str(context.get_variable("anim_len2")))
	ap.queue_free()
	trigger.queue_free()

## 动画不存在：错误路径
func _test_animation_not_found() -> void:
	print("\n--- 动画不存在 ---")
	var ap := _build_player()
	var trigger := Node.new()
	trigger.name = "T3"
	add_child(trigger)
	var context := ExecutionContext.new(ap, trigger)
	var inst := _make_instruction("../TestAP", "no_such", "anim_len3")
	inst.execute(context)
	_check(inst.has_error(), "不存在的动画报错")
	_check(context.get_variable("anim_len3") == null, "失败时不写变量")
	ap.queue_free()
	trigger.queue_free()

## 节点不存在：错误路径
func _test_node_not_found() -> void:
	print("\n--- 节点不存在 ---")
	var trigger := Node.new()
	trigger.name = "T4"
	add_child(trigger)
	var context := ExecutionContext.new(trigger, trigger)
	var inst := _make_instruction("../NoAP", "hit", "anim_len4")
	inst.execute(context)
	_check(inst.has_error(), "不存在的节点报错")
	trigger.queue_free()

## GLOBAL 作用域保存
func _test_save_to_global() -> void:
	print("\n--- GLOBAL 保存 ---")
	var ap := _build_player()
	var trigger := Node.new()
	trigger.name = "T5"
	add_child(trigger)
	var context := ExecutionContext.new(ap, trigger)
	var inst := _make_instruction("../TestAP", "player/hit", "gal_anim_len")
	inst.save_to_scope = BaseVariable.VariableScope.GLOBAL
	inst.execute(context)
	_check(VariableOperations.get_variable(context, "gal_anim_len", BaseVariable.VariableScope.GLOBAL, -1.0) == 0.233,
		"GLOBAL 作用域变量正确写入")
	ap.queue_free()
	trigger.queue_free()
