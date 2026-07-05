# 可视化震动效果演示
# 让您能够实际看到震动效果

extends Node2D

# 场景中的精灵节点
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

# 震动驱动器相关
var context: JuicyContext
var driver: JuicyShakeDriver
var buffer: JuicyPropertyBuffer

# 演示状态
var is_shaking = false
var shake_timer = 0.0
var original_position: Vector2
var use_global_position = true  # 默认使用全局位置

func _ready():
	# 初始化UI
	update_label()
	
	# 保存原始位置
	original_position = sprite.position
	
	# 创建震动驱动器
	driver = JuicyShakeDriver.new()
	buffer = JuicyPropertyBuffer.new()

func update_label():
	if is_shaking:
		var pos_type = "全局位置" if use_global_position else "本地位置"
		label.text = pos_type + "震动中...\n空格键：全局位置，回车键：本地位置"
	else:
		var pos_type = "全局位置" if use_global_position else "本地位置"
		label.text = "当前：" + pos_type + "震动\n空格键：全局位置，回车键：本地位置"

func _process(delta):
	if is_shaking:
		shake_timer += delta
		
		# 更新上下文时间
		context.current_time = shake_timer
		
		# 处理震动
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		
		# 每30帧打印一次位置信息（约0.5秒）
		if int(shake_timer * 60) % 30 == 0:
			print("当前位置: " + str(sprite.position))
		
		# 检查是否完成
		var property_name = "global_position" if use_global_position else "position"
		if driver.is_shake_complete(context, property_name):
			stop_shake()

func _input(event):
	print("收到输入事件: " + str(event))
	
	# 检查是否是按键事件
	if event is InputEventKey and event.pressed:
		print("按键事件 - 按键码: " + str(event.keycode) + ", 物理按键: " + str(event.physical_keycode))
		
		# 检查具体的按键码
		if event.keycode == KEY_SPACE:  # 空格键 - 全局位置震动
			print("空格键按下，当前震动状态: " + str(is_shaking) + ", 使用全局位置: " + str(use_global_position))
			if is_shaking:
				stop_shake()
			else:
				use_global_position = true
				print("设置使用全局位置")
				start_shake()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:  # 回车键 - 本地位置震动
			print("回车键按下，当前震动状态: " + str(is_shaking) + ", 使用全局位置: " + str(use_global_position))
			if is_shaking:
				stop_shake()
			else:
				use_global_position = false
				print("设置使用本地位置")
				start_shake()

func start_shake():
	var property_name = "global_position" if use_global_position else "position"
	print("开始震动演示 - 使用属性: " + property_name)
	print("原始位置: " + str(original_position))
	
	# 重置精灵位置
	sprite.position = original_position
	
	# 创建震动配置
	var shake_data_obj = ShakeData.new()
	shake_data_obj.property = property_name
	shake_data_obj.amplitude = 20.0  # 较大的振幅以便观察
	shake_data_obj.frequency = 8.0   # 适中的频率
	shake_data_obj.duration = 2.0    # 2秒持续时间
	shake_data_obj.falloff = 0  # LINEAR
	shake_data_obj.octaves = 1       # 单八度音，效果更明显
	shake_data_obj.noise_seed = 12345  # 固定种子，可重复效果
	
	var shake_data = [shake_data_obj]
	
	print("震动数据: " + str(shake_data_obj))
	
	# 创建上下文
	var resource = JuicyShakeResource.new()
	# 使用add_shake_data方法添加数据
	var added_data = resource.add_shake_data(
		property_name,
		20.0,  # 较大的振幅以便观察
		8.0,   # 适中的频率
		2.0,    # 2秒持续时间
		0,      # LINEAR
		12345,  # 固定种子，可重复效果
		1,      # 单八度音，效果更明显
		0.5,    # 持久性
		2.0     # 间隙度
	)
	
	context = JuicyContext.create(resource, sprite)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 开始震动
	is_shaking = true
	shake_timer = 0.0
	
	update_label()

func stop_shake():
	print("停止震动演示")
	print("停止时位置: " + str(sprite.position))
	is_shaking = false
	
	# 注意：RefCounted对象不应该手动free，它们由引用计数管理
	# 只需要重置引用即可
	context = null
	
	update_label()

func _exit_tree():
	# 注意：RefCounted对象不应该手动free
	# 重置引用让垃圾回收器处理
	context = null
	driver = null
	buffer = null