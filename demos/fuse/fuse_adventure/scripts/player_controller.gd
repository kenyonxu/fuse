extends CharacterBody2D

## 玩家水平移动速度（像素/秒）
@export var speed: float = 200.0

## 跳跃初速度（Y 轴向上为负）
@export var jump_force: float = -350.0

## 重力倍率
@export var gravity_scale: float = 1.0

## 最大下落速度
@export var max_fall_velocity: float = 800.0

## 是否启用二段跳
@export var enable_double_jump: bool = true

@onready var _sprite: AnimatedSprite2D = $PlayerSprites
@onready var _anim_tree: AnimationTree = $AnimationTree

var _jump_count: int = 0
var _was_on_floor: bool = false


func _ready() -> void:
	_anim_tree.active = true


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_movement()
	_handle_jump()

	move_and_slide()

	_update_animation()
	_update_facing()

	_was_on_floor = is_on_floor()


## 应用重力，限制最大下落速度
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * gravity_scale * delta
		velocity.y = minf(velocity.y, max_fall_velocity)


## 处理左右移动输入
func _handle_movement() -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed


## 处理跳跃与二段跳
func _handle_jump() -> void:
	if is_on_floor():
		_jump_count = 0

	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			velocity.y = jump_force
			_jump_count = 1
			_set_anim_condition("jump", true)
		elif enable_double_jump and _jump_count == 1:
			velocity.y = jump_force
			_jump_count = 2
			_set_anim_condition("do_double_jump", true)


## 根据状态更新 AnimationTree 条件参数
func _update_animation() -> void:
	var on_floor_now := is_on_floor()

	# 离开地面 → 进入下落
	if _was_on_floor and not on_floor_now and velocity.y > 0.0:
		_set_anim_condition("fall", true)

	# 着陆
	if not _was_on_floor and on_floor_now:
		_set_anim_condition("land", true)

	# 清除一次性条件，避免下一帧继续触发
	_set_anim_condition("jump", false)
	_set_anim_condition("do_double_jump", false)
	_set_anim_condition("fall", false)
	_set_anim_condition("land", false)


## 根据移动方向翻转精灵
func _update_facing() -> void:
	if velocity.x > 0.0:
		_sprite.flip_h = false
	elif velocity.x < 0.0:
		_sprite.flip_h = true


## 设置 PlayerNormal 状态机条件
func _set_anim_condition(condition_name: StringName, value: bool) -> void:
	_anim_tree.set("parameters/PlayerNormal/conditions/" + condition_name, value)
