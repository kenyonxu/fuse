extends CharacterBody2D

## deep_tests 物理基底的角色控制器——重力 + 输入移动 + move_and_slide。
## 为物理/移动类事件的观测提供驱动（is_on_floor 等状态需要 move_and_slide 被调用过）。
## 测试工具脚本，同 input_driver 性质，不属于 Fuse 测试内容本身。

const GRAVITY := 980.0
const SPEED := 300.0
const JUMP := -400.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	# 仅在有输入时接管水平速度——否则保留（Fuse SetVelocity/AddVelocity 写入的值不被每帧清零）
	var dir := Input.get_axis("Left", "Right")
	if dir != 0.0:
		velocity.x = dir * SPEED
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP
	var x_before := velocity.x
	move_and_slide()
	# 贴墙保压：滑动碰撞会把 velocity.x 清零，后续帧无压力致 is_on_wall 只在撞击帧为真——
	# 维持小压力让 CheckOnWall/OnCollision 类观测稳定可用（测试基建行为）
	if is_on_wall() and absf(x_before) > 1.0:
		velocity.x = 50.0 * signf(x_before)
