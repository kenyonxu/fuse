extends Node2D

## Camera Follow 指令测试

@onready var player := $Player as Node2D
@onready var camera := $Camera2D as Camera2D

func _ready():
	print("=== 开始测试 Camera Follow 指令 ===")
	await test_lock_follow()
	await test_smooth_follow()
	await test_damped_follow()
	await test_disable_follow()
	print("=== Camera Follow 指令测试完成 ===")

func test_lock_follow():
	print("\n[Test 1] 测试锁定跟随")

	var instruction := CameraFollow.new()
	var context := ExecutionContext.new()

	# 移动玩家
	player.global_position = Vector2(100, 100)

	instruction.target_node = NodePath("../Player")
	instruction.camera_node = NodePath("../Camera2D")
	instruction.follow_mode = CameraFollow.FollowMode.LOCK
	instruction.enabled = true

	instruction.execute(context)
	await context.finished

	# 验证相机位置
	assert(camera.global_position.is_equal_approx(player.global_position), "相机应该在锁定模式下跟随玩家")
	assert(camera.position_smoothing_enabled == false, "锁定模式应该禁用平滑")
	print("✓ 锁定跟随测试通过")

func test_smooth_follow():
	print("\n[Test 2] 测试平滑跟随")

	var instruction := CameraFollow.new()
	var context := ExecutionContext.new()

	instruction.target_node = NodePath("../Player")
	instruction.camera_node = NodePath("../Camera2D")
	instruction.follow_mode = CameraFollow.FollowMode.SMOOTH
	instruction.smooth_speed = 10.0
	instruction.enabled = true

	instruction.execute(context)
	await context.finished

	# 验证平滑速度设置
	assert(camera.position_smoothing_enabled == true, "应该启用平滑跟随")
	assert(is_equal_approx(camera.position_smoothing_speed, 10.0), "平滑速度应该是 10.0")
	print("✓ 平滑跟随测试通过")

func test_damped_follow():
	print("\n[Test 3] 测试阻尼跟随")

	var instruction := CameraFollow.new()
	var context := ExecutionContext.new()

	instruction.target_node = NodePath("../Player")
	instruction.camera_node = NodePath("../Camera2D")
	instruction.follow_mode = CameraFollow.FollowMode.DAMPED
	instruction.damping = true
	instruction.enabled = true

	instruction.execute(context)
	await context.finished

	assert(camera.position_smoothing_enabled == true, "应该启用位置平滑")
	print("✓ 阻尼跟随测试通过")

func test_disable_follow():
	print("\n[Test 4] 测试禁用跟随")

	var instruction := CameraFollow.new()
	var context := ExecutionContext.new()

	instruction.target_node = NodePath("../Player")
	instruction.camera_node = NodePath("../Camera2D")
	instruction.enabled = false

	instruction.execute(context)
	await context.finished

	assert(camera.enabled == false, "相机应该被禁用")
	print("✓ 禁用跟随测试通过")

## 辅助函数：浮点数比较
func is_equal_approx(a: float, b: float, epsilon: float = 0.0001) -> bool:
	return abs(a - b) < epsilon
