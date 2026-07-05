# 位置类型测试 - 区分本地位置和全局位置震动
# 帮助理解震动效果对本地位置和全局位置的影响

extends Node2D

# 测试节点
@onready var local_test_sprite: Sprite2D = $LocalTestSprite
@onready var global_test_sprite: Sprite2D = $GlobalTestSprite
@onready var label: Label = $Label

# 震动驱动器
var local_context: JuicyContext
var global_context: JuicyContext
var driver: JuicyShakeDriver
var buffer: JuicyPropertyBuffer

# 测试状态
var test_local_position = true  # 当前测试本地位置
var is_shaking = false
var original_local_pos: Vector2
var original_global_pos: Vector2

func _ready():
	# 设置两个精灵的初始位置
	local_test_sprite.position = Vector2(-100, 0)
	global_test_sprite.position = Vector2(100, 0)
	
	# 保存原始位置
	original_local_pos = local_test_sprite.position
	original_global_pos = global_test_sprite.position
	
	# 更新标签
	update_label()
	
	# 创建驱动器
	driver = JuicyShakeDriver.new()
	buffer = JuicyPropertyBuffer.new()

func _process(delta):
	if is_shaking:
		# 更新上下文时间
		var current_time = Time.get_time_dict_from_system()["unix"]
		
		if local_context:
			local_context.current_time = current_time
			driver.process(local_context, delta, buffer)
		
		if global_context:
			global_context.current_time = current_time
			driver.process(global_context, delta, buffer)
		
		buffer.flush_all_samples()
		
		# 检查是否完成
		if local_context and driver.is_shake_complete(local_context, "position"):
			stop_shake()
		elif global_context and driver.is_shake_complete(global_context, "global_position"):
			stop_shake()

func _input(event):
	if event.is_action_pressed("ui_accept"):  # 空格键
		if not is_shaking:
			start_shake()
		else:
			stop_shake()

func start_shake():
	print("开始震动测试")
	is_shaking = true
	
	# 重置位置到原始状态
	local_test_sprite.position = original_local_pos
	global_test_sprite.position = original_global_pos
	
	if test_local_position:
		# 测试本地位置震动
		var local_shake_data = [{
			"property": "position",
			"amplitude": 30.0,
			"frequency": 5.0,
			"duration": 2.0,
			"falloff": JuicyShakeDriver.ShakeFalloff.LINEAR,
			"octaves": 1,
			"noise_seed": 12345
		}]
		
		var resource = JuicyShakeResource.new()
		local_context = JuicyContext.create(resource, local_test_sprite)
		local_context.set_driver_data("shake_data", local_shake_data)
		driver.prepare(local_context, 0.0, buffer)
		
		label.text = "本地位置震动中... 按空格键停止"
	else:
		# 测试全局位置震动
		var global_shake_data = [{
			"property": "global_position",
			"amplitude": 30.0,
			"frequency": 5.0,
			"duration": 2.0,
			"falloff": JuicyShakeDriver.ShakeFalloff.LINEAR,
			"octaves": 1,
			"noise_seed": 12345
		}]
		
		var resource = JuicyShakeResource.new()
		global_context = JuicyContext.create(resource, global_test_sprite)
		global_context.set_driver_data("shake_data", global_shake_data)
		driver.prepare(global_context, 0.0, buffer)
		
		label.text = "全局位置震动中... 按空格键停止"

func stop_shake():
	print("停止震动测试")
	is_shaking = false
	
	# 清理上下文
	if local_context:
		local_context.free()
		local_context = null
	if global_context:
		global_context.free()
		global_context = null
	
	# 切换测试类型
	test_local_position = not test_local_position
	update_label()

func update_label():
	if test_local_position:
		label.text = "按空格键测试本地位置震动\n当前：本地位置"
	else:
		label.text = "按空格键测试全局位置震动\n当前：全局位置"

func _exit_tree():
	if local_context:
		local_context.free()
	if global_context:
		global_context.free()
	driver = null
	buffer = null