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

## 是否锁物理型位置变化
@export var lock_movement: bool = false

## 受击锁移动期间的水平冲量摩擦衰减（px/s²，越大停得越快）
@export var knockback_friction: float = 600.0

@onready var _sprite: AnimatedSprite2D = $PlayerSprites
@onready var _anim_tree: AnimationTree = $AnimationTree

# 由 fuse trigger 注入的输入意图：
#   OnInputCompositeAction 每帧把 input_vector 写入 move_input
#   OnInputAction(Jump) 按下时把 jump_requested 置 true（_physics_process 消费后复位）
# @export_storage：进入 get_property_list 供 fuse SetPropertyValue 枚举/写入，但不在 Inspector 显示
@export_storage var move_input: Vector2 = Vector2.ZERO
@export_storage var jump_requested: bool = false

var _jump_count: int = 0
var _was_on_floor: bool = false
var _was_falling: bool = false

# 待触发的一次性动画条件标志（本帧设置、下一帧清除，确保 AnimationTree 能读到）
var _pending_jump: bool = false
var _pending_double_jump: bool = false




func _ready() -> void:
	_anim_tree.active = true


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	if not lock_movement:
		_handle_movement()
		_handle_jump()
	else:
		# 锁定移动 = 禁止输入，不冻结物理：冲量（击退）按摩擦自然衰减，
		# 而非清零——受击滑行/空中受击轨迹由物理驱动
		velocity.x = move_toward(velocity.x, 0.0, knockback_friction * delta)
	move_and_slide()

	_update_animation()
	_update_facing()

	_was_on_floor = is_on_floor()
	if _was_on_floor:
		_was_falling = false


## 应用重力，限制最大下落速度
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * gravity_scale * delta
		velocity.y = minf(velocity.y, max_fall_velocity)


## 处理左右移动输入（输入由 fuse trigger 注入到 move_input）
func _handle_movement() -> void:
	velocity.x = move_input.x * speed


## 处理跳跃与二段跳（跳跃请求由 fuse trigger 注入到 jump_requested）
func _handle_jump() -> void:
	if is_on_floor():
		_jump_count = 0

	if jump_requested:
		jump_requested = false  # 消费请求
		if is_on_floor():
			velocity.y = jump_force
			_jump_count = 1
			_pending_jump = true
		elif enable_double_jump and _jump_count == 1:
			velocity.y = jump_force
			_jump_count = 2
			_pending_double_jump = true


## 根据状态更新 AnimationTree 条件参数
func _update_animation() -> void:
	var on_floor_now := is_on_floor()

	# 先清除上一帧的一次性条件
	_set_anim_condition("jump", false)
	_set_anim_condition("do_double_jump", false)
	_set_anim_condition("fall", false)
	_set_anim_condition("land", false)

	# 触发本帧的一次性条件
	if _pending_jump:
		_set_anim_condition("jump", true)
		_pending_jump = false
	elif _pending_double_jump:
		_set_anim_condition("do_double_jump", true)
		_pending_double_jump = false

	# 进入下落阶段：在空中且非上升（velocity.y >= 0）
	# 含跳跃顶点 velocity.y==0，以及平台边缘走出首帧（此时重力尚未累积，velocity.y 仍为 0）
	if not on_floor_now and velocity.y >= 0.0 and not _was_falling:
		_set_anim_condition("fall", true)
		_was_falling = true

	if not _was_on_floor and on_floor_now:
		_set_anim_condition("land", true)


## 根据移动方向翻转精灵
func _update_facing() -> void:
	# 锁移动（受击）期间保持面向：击退冲量反向不代表转身
	if lock_movement:
		return
	if velocity.x > 0.0:
		_sprite.flip_h = false
	elif velocity.x < 0.0:
		_sprite.flip_h = true


## 设置 PlayerNormal 状态机条件
func _set_anim_condition(condition_name: StringName, value: bool) -> void:
	_anim_tree.set("parameters/PlayerNormal/conditions/" + condition_name, value)
