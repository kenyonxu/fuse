# 测试：BaseTweenInstruction.use_physics_process 开关——默认 idle 回归/开关生效/两条执行路径端到端
#
# process mode 验证用行为法：4.7 的 Tween 无 get_process_mode 绑定，
# 故调低 Engine.physics_ticks_per_second 后对比两种 tween 的推进时钟。
extends Node

var _fail: int = 0
var _sig_finished: bool = false

func _ready() -> void:
	print("=== BaseTweenInstruction physics process 开关测试开始 ===")
	await _test_create_tween_modes()
	await _test_move_to_physics_e2e()
	await _test_tween_property_physics_e2e()
	print("=== BaseTweenInstruction physics process 开关测试完成（失败 %d 项）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("✓ " + message)
	else:
		_fail += 1
		push_error("✗ " + message)

func _wait_instruction_finished(instruction: BaseInstruction, max_frames: int) -> void:
	_sig_finished = false
	instruction.finished.connect(func(): _sig_finished = true, CONNECT_ONE_SHOT)
	for i in range(max_frames):
		await get_tree().process_frame
		if _sig_finished:
			break

## _create_tween 按开关选择驱动时钟
#
# 4.7 的 Tween 无 get_process_mode 绑定，且 elapsed 是与墙钟对齐的虚拟时钟，
# 故用步进粒度区分：物理时钟调慢至 5tps + 限帧 120 后采样 30 帧——
# idle tween 每帧推进，physics tween 仅在物理 tick 处跳变。
func _test_create_tween_modes() -> void:
	print("\n--- process mode 设置 ---")
	var idle_host := Node2D.new()
	var physics_host := Node2D.new()
	add_child(idle_host)
	add_child(physics_host)

	var original_tps := Engine.physics_ticks_per_second
	var original_max_fps := Engine.max_fps
	Engine.physics_ticks_per_second = 5
	Engine.max_fps = 120

	var mv_default := TweenMoveTo.new()
	var tween_default: Tween = mv_default._create_tween(idle_host)
	tween_default.tween_property(idle_host, "position:x", 1000.0, 10.0)

	var mv_physics := TweenMoveTo.new()
	mv_physics.use_physics_process = true
	var tween_physics: Tween = mv_physics._create_tween(physics_host)
	tween_physics.tween_property(physics_host, "position:x", 1000.0, 10.0)

	var idle_changes := 0
	var physics_changes := 0
	var prev_idle := 0.0
	var prev_physics := 0.0
	for i in range(30):
		await get_tree().process_frame
		if absf(idle_host.position.x - prev_idle) > 0.0001:
			idle_changes += 1
		if absf(physics_host.position.x - prev_physics) > 0.0001:
			physics_changes += 1
		prev_idle = idle_host.position.x
		prev_physics = physics_host.position.x

	_check(idle_changes >= 25, "默认（开关关闭）每渲染帧推进（30 帧中 %d 帧有位移）" % idle_changes)
	_check(
		physics_changes <= 5,
		"开关开启按物理帧步进（30 帧中 %d 帧有位移）" % physics_changes
	)

	tween_default.kill()
	tween_physics.kill()
	Engine.physics_ticks_per_second = original_tps
	Engine.max_fps = original_max_fps
	idle_host.queue_free()
	physics_host.queue_free()

## TweenMoveTo 直跑路径：开关开启不影响正常完成与位移
func _test_move_to_physics_e2e() -> void:
	print("\n--- TweenMoveTo 物理帧端到端 ---")
	var host := Node2D.new()
	host.name = "PhysicsMoveHost"
	add_child(host)

	var mv := TweenMoveTo.new()
	mv.target_node = NodePath("../PhysicsMoveHost")
	mv.target_position = Vector2(30, 0)
	mv.duration = 0.05
	mv.use_physics_process = true
	mv.execute(ExecutionContext.new(host, host))
	await _wait_instruction_finished(mv, 120)
	_check(_sig_finished, "物理帧模式正常完成")
	_check(absf(host.position.x - 30.0) < 0.5, "物理帧位移到位 x=%.2f" % host.position.x)
	host.queue_free()

## TweenPropertyInstruction 直跑路径：开关经统一 _create_tween 入口生效
func _test_tween_property_physics_e2e() -> void:
	print("\n--- TweenProperty 物理帧端到端 ---")
	var host := Node2D.new()
	host.name = "PhysicsPropertyHost"
	add_child(host)

	var tp := TweenPropertyInstruction.new()
	tp.target_node = NodePath("../PhysicsPropertyHost")
	tp.property_path = "position"
	tp.to_value = Vector2(40, 0)
	tp.duration = 0.05
	tp.use_physics_process = true
	tp.execute(ExecutionContext.new(host, host))
	await _wait_instruction_finished(tp, 120)
	_check(_sig_finished, "物理帧模式正常完成")
	_check(absf(host.position.x - 40.0) < 0.5, "物理帧属性动画到位 x=%.2f" % host.position.x)
	host.queue_free()
