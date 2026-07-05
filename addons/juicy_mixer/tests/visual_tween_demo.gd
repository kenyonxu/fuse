# 可视化Tween效果演示
# 让您能够实际看到各种Tween补间动画效果
# 支持多种缓动曲线、多属性并行、相对值等高级功能

extends Node2D

# 场景中的精灵节点
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var path_indicator: Line2D = $PathIndicator
@onready var demo_objects: Node2D = $DemoObjects

# Tween驱动器相关
var context: JuicyContext
var driver: JuicyTweenDriver
var buffer: JuicyPropertyBuffer

# 演示状态
var is_tweening = false
var tween_timer = 0.0
var original_position: Vector2
var original_rotation: float
var original_scale: Vector2
var original_color: Color

# 当前演示场景
var current_demo = 1
var demo_names = {
	1: "基础位置Tween - 缓动对比",
	2: "多属性并行Tween",
	3: "颜色渐变Tween",
	4: "相对值Tween",
	5: "复杂组合效果",
	6: "缓动曲线对比",
	7: "延迟效果演示"
}

# 路径记录
var position_trail: Array[Vector2] = []
var max_trail_points = 100

# 对比演示相关
var comparison_contexts: Array = []
var comparison_drivers: Array = []
var comparison_buffers: Array = []
var comparison_sprites: Array = []

func _ready():
	# 初始化UI
	update_label()
	
	# 保存原始值
	original_position = sprite.position
	original_rotation = sprite.rotation
	original_scale = sprite.scale
	original_color = sprite.modulate
	
	# 创建Tween驱动器
	driver = JuicyTweenDriver.new()
	buffer = JuicyPropertyBuffer.new()
	
	# 设置路径指示器
	path_indicator.width = 2.0
	path_indicator.default_color = Color(1, 1, 1, 0.6)

func update_label():
	if is_tweening:
		var demo_name = demo_names.get(current_demo, "未知演示")
		var progress_info = ""
		if context and driver:
			# 显示第一个属性的进度
			var properties = driver.tween_properties.keys()
			if properties.size() > 0:
				var progress = driver.get_tween_progress(context, properties[0])
				progress_info = "\n进度: %.1f%%" % (progress * 100)
		label.text = demo_name + " 进行中..." + progress_info + "\n数字键1-7：选择演示，空格键：重置，R键：重新开始"
	else:
		var demo_name = demo_names.get(current_demo, "未知演示")
		label.text = "当前：" + demo_name + "\n数字键1-7：选择演示，空格键：重置，R键：重新开始"

func _process(delta):
	if is_tweening:
		tween_timer += delta
		
		# 更新上下文时间
		context.current_time = tween_timer
		
		# 处理主Tween
		driver.process(context, delta, buffer)
		buffer.flush_all_samples()
		
		# 处理对比演示的Tween
		if current_demo == 6 and comparison_drivers.size() > 0:
			for i in range(comparison_drivers.size()):
				if comparison_contexts[i] and comparison_drivers[i]:
					comparison_contexts[i].current_time = tween_timer
					comparison_drivers[i].process(comparison_contexts[i], delta, comparison_buffers[i])
					comparison_buffers[i].flush_all_samples()
		
		# 记录位置轨迹
		if sprite.position != original_position:
			position_trail.append(sprite.position)
			if position_trail.size() > max_trail_points:
				position_trail.pop_front()
			_update_path_indicator()
		
		# 检查是否完成
		var all_complete = true
		for property in driver.tween_properties.keys():
			if not driver.is_tween_complete(context, property):
				all_complete = false
				break
		
		if all_complete:
			stop_tween()

func _input(event):
	if event is InputEventKey and event.pressed:
		# 数字键选择演示场景
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			var new_demo = event.keycode - KEY_1 + 1
			if new_demo != current_demo:
				current_demo = new_demo
				if is_tweening:
					stop_tween()
				reset_to_original()
				update_label()
		
		# 空格键重置到原始状态
		elif event.keycode == KEY_SPACE:
			if is_tweening:
				stop_tween()
			reset_to_original()
		
		# R键重新开始当前演示
		elif event.keycode == KEY_R:
			if is_tweening:
				stop_tween()
			reset_to_original()
			start_tween()

func reset_to_original():
	# 重置所有属性到原始值
	sprite.position = original_position
	sprite.rotation = original_rotation
	sprite.scale = original_scale
	sprite.modulate = original_color
	
	# 清空轨迹
	position_trail.clear()
	_update_path_indicator()

func start_tween():
	print("开始Tween演示 - 场景: " + str(current_demo))
	
	# 重置计时器
	tween_timer = 0.0
	
	# 根据当前场景创建不同的Tween数据
	var tween_data = _create_tween_data_for_demo(current_demo)
	
	# 将字典数组转换为TweenData对象数组
	var tween_data_objects = []
	for tween_dict in tween_data:
		var tween_obj = TweenData.new()
		tween_obj.property = tween_dict["property"]
		tween_obj.from_value = tween_dict["from_value"]
		tween_obj.to_value = tween_dict["to_value"]
		tween_obj.duration = tween_dict["duration"]
		tween_obj.trans_type = tween_dict.get("trans_type", Tween.TRANS_LINEAR)
		tween_obj.ease_type = tween_dict.get("ease_type", Tween.EASE_IN_OUT)
		tween_obj.delay = tween_dict.get("delay", 0.0)
		tween_obj.relative = tween_dict.get("relative", false)
		tween_data_objects.append(tween_obj)
	
	# 创建上下文
	var resource = JuicyTweenResource.new()
	# 使用add_tween_data方法添加每个TweenData对象
	for tween_obj in tween_data_objects:
		resource.add_tween_data(
			tween_obj.property,
			tween_obj.from_value,
			tween_obj.to_value,
			tween_obj.duration,
			tween_obj.delay,
			tween_obj.ease_type,
			tween_obj.trans_type,
			tween_obj.relative
		)
	
	context = JuicyContext.create(resource, sprite)
	
	# 准备驱动器
	driver.prepare(context, 0.0, buffer)
	
	# 开始Tween
	is_tweening = true
	
	update_label()

func stop_tween():
	print("停止Tween演示")
	is_tweening = false
	
	# 清理主上下文
	context = null
	
	# 清理对比演示资源
	if current_demo == 6:
		_cleanup_comparison()
	
	update_label()

func _exit_tree():
	# 清理引用
	context = null
	driver = null
	buffer = null
	
	# 清理对比演示资源
	_cleanup_comparison()

func _create_tween_data_for_demo(demo_num: int) -> Array:
	match demo_num:
		1:  # 基础位置Tween - 缓动对比
			return [{
				"property": "position",
				"from_value": original_position,
				"to_value": original_position + Vector2(200, -100),
				"duration": 2.0,
				"trans_type": Tween.TRANS_QUAD,
				"ease_type": Tween.EASE_IN_OUT
			}]
		
		2:  # 多属性并行Tween
			return [
				{
					"property": "position",
					"from_value": original_position,
					"to_value": original_position + Vector2(150, -80),
					"duration": 2.0,
					"trans_type": Tween.TRANS_SINE,
					"ease_type": Tween.EASE_OUT
				},
				{
					"property": "rotation",
					"from_value": 0.0,
					"to_value": PI * 2,  # 360度旋转
					"duration": 2.0,
					"trans_type": Tween.TRANS_LINEAR,
					"ease_type": Tween.EASE_IN_OUT
				},
				{
					"property": "scale",
					"from_value": Vector2(1, 1),
					"to_value": Vector2(1.5, 1.5),
					"duration": 1.5,
					"trans_type": Tween.TRANS_BACK,
					"ease_type": Tween.EASE_OUT
				}
			]
		
		3:  # 颜色渐变Tween
			return [{
				"property": "modulate",
				"from_value": Color.RED,
				"to_value": Color.BLUE,
				"duration": 3.0,
				"trans_type": Tween.TRANS_LINEAR,
				"ease_type": Tween.EASE_IN_OUT
			}]
		
		4:  # 相对值Tween
			return [{
				"property": "position",
				"from_value": Vector2.ZERO,  # 相对值模式下的偏移
				"to_value": Vector2(100, -50),
				"duration": 2.0,
				"relative": true,  # 启用相对值模式
				"trans_type": Tween.TRANS_BOUNCE,
				"ease_type": Tween.EASE_OUT
			}]
		
		5:  # 复杂组合效果
			return [
				{
					"property": "position",
					"from_value": original_position,
					"to_value": original_position + Vector2(100, -50),
					"duration": 1.5,
					"delay": 0.5,  # 延迟0.5秒开始
					"trans_type": Tween.TRANS_ELASTIC,
					"ease_type": Tween.EASE_OUT
				},
				{
					"property": "scale",
					"from_value": Vector2(1, 1),
					"to_value": Vector2(2, 0.5),  # 压扁效果
					"duration": 1.0,
					"trans_type": Tween.TRANS_QUAD,
					"ease_type": Tween.EASE_IN_OUT
				},
				{
					"property": "rotation",
					"from_value": 0.0,
					"to_value": PI / 4,  # 45度旋转
					"duration": 1.2,
					"delay": 0.3,
					"trans_type": Tween.TRANS_CIRC,
					"ease_type": Tween.EASE_IN
				}
			]
		
		6:  # 缓动曲线对比
			_setup_comparison_demo()
			return [{
				"property": "position",
				"from_value": original_position,
				"to_value": original_position + Vector2(300, 0),
				"duration": 2.0,
				"trans_type": Tween.TRANS_QUAD,
				"ease_type": Tween.EASE_IN_OUT
			}]
		
		7:  # 延迟效果演示
			return [
				{
					"property": "position",
					"from_value": original_position,
					"to_value": original_position + Vector2(0, -100),
					"duration": 1.0,
					"delay": 0.0,
					"trans_type": Tween.TRANS_LINEAR,
					"ease_type": Tween.EASE_IN_OUT
				},
				{
					"property": "scale",
					"from_value": Vector2(1, 1),
					"to_value": Vector2(1.5, 1.5),
					"duration": 1.0,
					"delay": 0.5,  # 延迟0.5秒
					"trans_type": Tween.TRANS_BOUNCE,
					"ease_type": Tween.EASE_OUT
				},
				{
					"property": "rotation",
					"from_value": 0.0,
					"to_value": PI,
					"duration": 1.0,
					"delay": 1.0,  # 延迟1秒
					"trans_type": Tween.TRANS_ELASTIC,
					"ease_type": Tween.EASE_OUT
				}
			]
		
		_:
			return []

func _setup_comparison_demo():
	# 设置对比演示 - 多个精灵使用不同的缓动曲线
	demo_objects.visible = true
	
	# 清理之前的对比数据
	_cleanup_comparison()
	
	# 获取对比精灵
	comparison_sprites = []
	for i in range(demo_objects.get_child_count()):
		var child = demo_objects.get_child(i)
		if child is Sprite2D:
			comparison_sprites.append(child)
	
	# 为每个对比精灵创建不同的Tween配置
	var transitions = [
		Tween.TRANS_LINEAR,
		Tween.TRANS_SINE,
		Tween.TRANS_QUAD,
		Tween.TRANS_BOUNCE,
		Tween.TRANS_ELASTIC
	]
	
	var ease_types = [
		Tween.EASE_IN,
		Tween.EASE_OUT,
		Tween.EASE_IN_OUT,
		Tween.EASE_IN,
		Tween.EASE_OUT
	]
	
	for i in range(min(comparison_sprites.size(), transitions.size())):
		var sprite = comparison_sprites[i]
		var trans_type = transitions[i]
		var ease_type = ease_types[i]
		
		# 重置精灵位置
		sprite.position = Vector2(100, 150 + i * 80)
		
		# 创建Tween数据对象
		var tween_obj = TweenData.new()
		tween_obj.property = "position"
		tween_obj.from_value = sprite.position
		tween_obj.to_value = sprite.position + Vector2(400, 0)
		tween_obj.duration = 2.0
		tween_obj.trans_type = trans_type
		tween_obj.ease_type = ease_type
		
		var tween_data = [tween_obj]
		
		# 创建独立的上下文和驱动器
		var resource = JuicyTweenResource.new()
		# 使用add_tween_data方法添加数据
		resource.add_tween_data(
			"position",
			sprite.position,
			sprite.position + Vector2(400, 0),
			2.0,
			0.0,
			ease_type,
			trans_type,
			false
		)
		var comp_context = JuicyContext.create(resource, sprite)
		
		var comp_driver = JuicyTweenDriver.new()
		var comp_buffer = JuicyPropertyBuffer.new()
		
		comp_driver.prepare(comp_context, 0.0, comp_buffer)
		
		# 保存引用
		comparison_contexts.append(comp_context)
		comparison_drivers.append(comp_driver)
		comparison_buffers.append(comp_buffer)

func _cleanup_comparison():
	# 清理对比演示的资源
	for i in range(comparison_contexts.size()):
		comparison_contexts[i] = null
		comparison_drivers[i] = null
		comparison_buffers[i] = null
	
	comparison_contexts.clear()
	comparison_drivers.clear()
	comparison_buffers.clear()
	
	if demo_objects:
		demo_objects.visible = false

func _update_path_indicator():
	# 更新路径指示器
	path_indicator.clear_points()
	for pos in position_trail:
		path_indicator.add_point(pos)
	