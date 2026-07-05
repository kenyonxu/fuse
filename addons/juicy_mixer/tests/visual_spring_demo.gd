# 可视化弹簧效果演示
# 让您能够实际看到弹簧物理效果

extends Node2D

# 场景中的精灵节点
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var stiffness_label: Label = $StiffnessLabel
@onready var damping_label: Label = $DampingLabel

# 弹簧驱动器相关
var context: JuicyContext
var driver: JuicySpringDriver
var buffer: JuicyPropertyBuffer

# 演示状态
var is_springing = false
var spring_timer = 0.0
var original_position: Vector2

# 弹簧参数
var stiffness = 50.0
var damping = 5.0
var mass = 1.0

func _ready():
	# 初始化UI
	update_labels()
	
	# 保存原始位置
	original_position = sprite.position
	
	# 创建弹簧驱动器
	driver = JuicySpringDriver.new()
	buffer = JuicyPropertyBuffer.new()

func update_labels():
	if is_springing:
		label.text = "弹簧效果演示中...\n空格键：开始弹簧效果，↑↓键：调整刚度，←→键：调整阻尼"
	else:
		label.text = "当前：弹簧效果演示\n空格键：开始弹簧效果，↑↓键：调整刚度，←→键：调整阻尼"
	
	stiffness_label.text = "刚度 (K): " + str(stiffness)
	damping_label.text = "阻尼 (C): " + str(damping)

func _process(delta):
	if is_springing:
		spring_timer += delta
		
		# 更新上下文时间
		context.current_time = spring_timer
		
		# 处理弹簧效果
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		
		# 每30帧打印一次位置信息（约0.5秒）
		if int(spring_timer * 60) % 30 == 0:
			print("当前位置: " + str(sprite.position) + ", 速度: " + str(driver.get_spring_offset(context, "position")))
		
		var is_stable: bool = false
		# 检查是否稳定
		if driver.is_spring_stable(context, "position"):
			if not is_stable:
				print("弹簧已稳定！")
				is_stable = true
				

			# 可以继续运行，让用户观察稳定状态

func _input(event):
	print("收到输入事件: " + str(event))
	
	# 检查是否是按键事件
	if event is InputEventKey and event.pressed:
		print("按键事件 - 按键码: " + str(event.keycode) + ", 物理按键: " + str(event.physical_keycode))
		
		# 空格键 - 开始弹簧效果
		if event.keycode == KEY_SPACE:
			print("空格键按下，当前弹簧状态: " + str(is_springing))
			if is_springing:
				stop_spring()
			else:
				start_spring()
		
		# 上箭头 - 增加刚度
		elif event.keycode == KEY_UP:
			stiffness = min(stiffness + 10.0, 200.0)
			update_labels()
			print("刚度增加到: " + str(stiffness))
		
		# 下箭头 - 减少刚度
		elif event.keycode == KEY_DOWN:
			stiffness = max(stiffness - 10.0, 1.0)
			update_labels()
			print("刚度减少到: " + str(stiffness))
		
		# 右箭头 - 增加阻尼
		elif event.keycode == KEY_RIGHT:
			damping = min(damping + 2.0, 50.0)
			update_labels()
			print("阻尼增加到: " + str(damping))
		
		# 左箭头 - 减少阻尼
		elif event.keycode == KEY_LEFT:
			damping = max(damping - 2.0, 0.0)
			update_labels()
			print("阻尼减少到: " + str(damping))

func start_spring():
	print("开始弹簧演示")
	print("原始位置: " + str(original_position))
	
	# 重置精灵位置
	sprite.position = original_position
	
	# 创建弹簧配置 - 目标位置在右侧100像素处
	var target_position = original_position + Vector2(100, 0)
	
	var spring_data_obj = SpringData.new()
	spring_data_obj.property = "position"
	spring_data_obj.target_value = target_position
	spring_data_obj.stiffness = stiffness
	spring_data_obj.damping = damping
	spring_data_obj.mass = mass
	spring_data_obj.threshold = 0.1
	spring_data_obj.initial_velocity = Vector2.ZERO
	
	var spring_data = [spring_data_obj]
	
	print("弹簧数据: " + str(spring_data_obj))
	print("目标位置: " + str(target_position))
	
	# 创建上下文
	var resource = JuicySpringResource.new()
	# 使用add_spring_data方法添加数据
	var added_data = resource.add_spring_data(
		"position",
		target_position,
		stiffness,
		damping,
		mass,
		Vector2.ZERO,
		0.1
	)
	
	context = JuicyContext.create(resource, sprite)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 开始弹簧效果
	is_springing = true
	spring_timer = 0.0
	
	update_labels()

func stop_spring():
	print("停止弹簧演示")
	print("停止时位置: " + str(sprite.position))
	is_springing = false
	
	# 重置引用让垃圾回收器处理
	context = null
	
	update_labels()

func _exit_tree():
	# 重置引用让垃圾回收器处理
	context = null
	driver = null
	buffer = null