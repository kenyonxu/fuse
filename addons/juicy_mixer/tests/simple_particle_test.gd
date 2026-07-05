extends Node

# 简单的粒子测试脚本
# 可以直接在Godot中运行来验证粒子效果

func _ready():
	print("=== 简单粒子测试开始 ===")
	
	# 创建粒子事件处理器
	var particle_handler = JuicyParticleEventHandler.new()
	
	# 创建测试粒子场景
	var particle_scene = _create_test_particle_scene()
	
	# 创建测试UI
	_create_ui(particle_handler, particle_scene)
	
	print("粒子测试准备完成，请在编辑器中运行此场景")

func _create_test_particle_scene() -> PackedScene:
	"""创建测试用的粒子场景"""
	var particles = GPUParticles2D.new()
	particles.amount = 150
	particles.lifetime = 2.5
	particles.one_shot = true
	
	# 设置粒子材质
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3(0, -1, 0)
	material.spread = 60.0  # 更大的扩散角度
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 150.0
	material.angular_velocity_min = -120.0
	material.angular_velocity_max = 120.0
	material.gravity = Vector3(0, 30, 0)  # 较小的重力
	material.scale_min = 1.0  # 更大的粒子
	material.scale_max = 3.0
	
	# 设置颜色变化
	material.color = Color.WHITE
	var color_gradient = Gradient.new()
	color_gradient.add_point(0.0, Color.YELLOW)
	color_gradient.add_point(0.5, Color.ORANGE)
	color_gradient.add_point(1.0, Color.RED)
	material.color_ramp = color_gradient
	
	particles.process_material = material
	
	# 创建纹理 - 更大更明显
	var texture = ImageTexture.new()
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)  # 透明背景
	
	# 创建一个渐变圆形
	for x in range(64):
		for y in range(64):
			var dist = Vector2(x - 32, y - 32).length()
			if dist <= 32:
				var alpha = 1.0 - (dist / 32.0)
				# 中心白色，边缘透明
				var brightness = 1.0
				image.set_pixel(x, y, Color(brightness, brightness, brightness, alpha))
	
	texture.set_image(image)
	particles.texture = texture
	
	# 打包为场景
	var scene = PackedScene.new()
	scene.pack(particles)
	
	return scene

func _create_ui(particle_handler: JuicyParticleEventHandler, particle_scene: PackedScene):
	var control = Control.new()
	add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var vbox = VBoxContainer.new()
	control.add_child(vbox)
	vbox.position = Vector2(50, 50)
	
	# 标题
	var title_label = Label.new()
	title_label.text = "粒子效果测试"
	title_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title_label)
	
	# 分隔线
	var separator1 = HSeparator.new()
	vbox.add_child(separator1)
	
	# 生成粒子按钮
	var spawn_btn = Button.new()
	spawn_btn.text = "生成爆炸粒子效果"
	spawn_btn.pressed.connect(_on_spawn_pressed.bind(particle_handler, particle_scene))
	vbox.add_child(spawn_btn)
	
	# 生成多个粒子按钮
	var multiple_btn = Button.new()
	multiple_btn.text = "生成多个粒子效果"
	multiple_btn.pressed.connect(_on_multiple_spawn_pressed.bind(particle_handler, particle_scene))
	vbox.add_child(multiple_btn)
	
	# 停止粒子按钮
	var stop_btn = Button.new()
	stop_btn.text = "停止所有粒子"
	stop_btn.pressed.connect(_on_stop_pressed.bind(particle_handler))
	vbox.add_child(stop_btn)
	
	# 分隔线
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# 统计按钮
	var stats_btn = Button.new()
	stats_btn.text = "显示统计信息"
	stats_btn.pressed.connect(_on_stats_pressed.bind(particle_handler))
	vbox.add_child(stats_btn)
	
	# 清理按钮
	var cleanup_btn = Button.new()
	cleanup_btn.text = "清理所有粒子"
	cleanup_btn.pressed.connect(_on_cleanup_pressed.bind(particle_handler))
	vbox.add_child(cleanup_btn)
	
	# 分隔线
	var separator3 = HSeparator.new()
	vbox.add_child(separator3)
	
	# 配置说明
	var config_label = Label.new()
	config_label.text = "配置说明:\n- 最大并发粒子系统: 15\n- 最大池大小: 30\n- 自动清理时间: 10秒"
	config_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(config_label)

func _on_spawn_pressed(particle_handler: JuicyParticleEventHandler, particle_scene: PackedScene):
	print("生成粒子效果...")
	
	# 在随机位置生成粒子
	var random_pos = Vector2(
		randf_range(200, 800),
		randf_range(200, 600)
	)
	
	var spawn_event = JuicyEvent.create_particle_spawn_event(
		"Test",
		self, 
		particle_scene,
		80,  # 粒子数量
		random_pos
	)
	spawn_event.context_id = "test_spawn"
	
	var success = particle_handler.handle_event(spawn_event)
	print("粒子生成结果: ", success, " 位置: ", random_pos)

func _on_multiple_spawn_pressed(particle_handler: JuicyParticleEventHandler, particle_scene: PackedScene):
	print("生成多个粒子效果...")
	
	# 生成多个粒子效果
	for i in range(5):
		var random_pos = Vector2(
			randf_range(100, 900),
			randf_range(100, 700)
		)
		
		var spawn_event = JuicyEvent.create_particle_spawn_event(
			"Test",
			self, 
			particle_scene,
			30 + i * 10,  # 递增的粒子数量
			random_pos
		)
		spawn_event.context_id = "multiple_spawn_" + str(i)
		
		var success = particle_handler.handle_event(spawn_event)
		print("粒子生成 ", i, " 结果: ", success, " 位置: ", random_pos)
		
		# 稍微延迟一下
		await get_tree().create_timer(0.1).timeout

func _on_stop_pressed(particle_handler: JuicyParticleEventHandler):
	print("停止所有粒子...")
	
	var stop_event = JuicyEvent.new(JuicyEvent.EventType.PARTICLE_STOP)
	stop_event.context_id = "test_spawn"
	stop_event.target = self
	
	var success = particle_handler.handle_event(stop_event)
	print("停止单个粒子结果: ", success)
	
	# 停止多个粒子
	for i in range(5):
		var multi_stop_event = JuicyEvent.new(JuicyEvent.EventType.PARTICLE_STOP)
		multi_stop_event.context_id = "multiple_spawn_" + str(i)
		multi_stop_event.target = self
		
		var multi_success = particle_handler.handle_event(multi_stop_event)
		print("停止多个粒子 ", i, " 结果: ", multi_success)

func _on_stats_pressed(particle_handler: JuicyParticleEventHandler):
	var stats = particle_handler.get_particle_stats()
	var perf_stats = particle_handler.get_performance_stats()
	
	print("=== 粒子统计 ===")
	print("池大小: ", stats.pool_size)
	print("活跃粒子系统: ", stats.active_particles)
	print("最大池大小: ", stats.max_pool_size)
	print("最大并发粒子系统: ", stats.max_concurrent_systems)
	print("事件处理数: ", perf_stats.events_handled)
	print("事件失败数: ", perf_stats.events_failed)
	print("成功率: ", perf_stats.success_rate)
	print("平均处理时间: ", perf_stats.average_handling_time, "ms")
	print("===============")

func _on_cleanup_pressed(particle_handler: JuicyParticleEventHandler):
	print("清理所有粒子...")
	
	particle_handler.cleanup()
	
	print("清理完成")
	_on_stats_pressed(particle_handler)  # 显示清理后的统计

func _exit_tree():
	print("粒子测试清理")