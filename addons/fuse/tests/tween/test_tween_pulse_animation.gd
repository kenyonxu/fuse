extends Node2D

## Tween Pulse Animation 指令测试

## 测试目标节点
@onready var test_sprite = $TestSprite

## 测试标签
@onready var label = $Label

## 当前测试状态
var _current_test: int = 0
var _test_active: bool = false

func _ready():
	# 设置初始状态
	test_sprite.scale = Vector2.ONE
	label.text = "Tween Pulse Animation Test\nPress SPACE: Test finite loop (3 times)\nPress ENTER: Test infinite loop\nPress ESC: Cancel animation"

func _input(event):
	if not event.is_pressed():
		return

	if event.is_action("ui_accept") and not _test_active:
		_test_finite_pulse()
	elif event.is_action("ui_text_newline") and not _test_active:
		_test_infinite_pulse()
	elif event.is_action("ui_cancel"):
		_cancel_animation()

## 测试有限循环脉冲动画
func _test_finite_pulse():
	print("=== 测试 TweenPulseAnimation 指令（有限循环）===")

	_current_test = 1
	_test_active = true

	# 重置状态
	test_sprite.scale = Vector2.ONE
	label.text = "Testing finite pulse animation (3 loops)..."

	var context = ExecutionContext.new()
	var instruction = TweenPulseAnimation.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.min_scale = Vector2(0.8, 0.8)
	instruction.max_scale = Vector2(1.2, 1.2)
	instruction.duration = 2.0
	instruction.loop_count = 3

	# 连接完成信号
	instruction.finished.connect(_on_finite_pulse_completed)

	# 执行指令
	add_child(instruction)
	instruction.execute(context)

	print("✓ TweenPulseAnimation 指令已启动（有限循环3次）")

## 测试无限循环脉冲动画
func _test_infinite_pulse():
	print("=== 测试 TweenPulseAnimation 指令（无限循环）===")

	_current_test = 2
	_test_active = true

	# 重置状态
	test_sprite.scale = Vector2.ONE
	label.text = "Testing infinite pulse animation...\nPress ESC to cancel"

	var context = ExecutionContext.new()
	var instruction = TweenPulseAnimation.new()

	# 配置参数
	instruction.target_node = ^"TestSprite"
	instruction.min_scale = Vector2(0.9, 0.9)
	instruction.max_scale = Vector2(1.1, 1.1)
	instruction.duration = 1.0
	instruction.loop_count = 0  # 无限循环

	# 保存引用以便取消
	_current_instruction = instruction

	# 执行指令
	add_child(instruction)
	instruction.execute(context)

	print("✓ TweenPulseAnimation 指令已启动（无限循环）")
	print("  按 ESC 键取消动画")

var _current_instruction: TweenPulseAnimation = null

## 有限循环完成回调
func _on_finite_pulse_completed():
	print("✓ TweenPulseAnimation 指令已完成（有限循环）")
	print("  最终缩放: %s" % str(test_sprite.scale))
	print("测试通过！")

	_test_active = false
	label.text = "Finite pulse test PASSED!\nFinal scale: %s\n\nPress SPACE: Test finite loop\nPress ENTER: Test infinite loop" % str(test_sprite.scale)

## 取消动画
func _cancel_animation():
	if _current_instruction != null and is_instance_valid(_current_instruction):
		print("=== 取消 TweenPulseAnimation 指令 ===")
		_current_instruction.cancel()
		_current_instruction.queue_free()
		_current_instruction = null

		print("✓ 动画已取消")
		print("  最终缩放: %s" % str(test_sprite.scale))

		_test_active = false
		label.text = "Infinite pulse test CANCELLED!\nFinal scale: %s\n\nPress SPACE: Test finite loop\nPress ENTER: Test infinite loop" % str(test_sprite.scale)

## 验证测试结果
func _verify_test_result():
	match _current_test:
		1:
			# 有限循环测试
			assert(test_sprite.scale != Vector2.ZERO, "缩放不应为零")
			print("✓ 有限循环测试验证通过")
		2:
			# 无限循环测试（取消）
			assert(test_sprite.scale != Vector2.ZERO, "缩放不应为零")
			print("✓ 无限循环测试验证通过")
