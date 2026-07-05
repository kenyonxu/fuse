# =============================================================================
# EventHandlerEntry 使用示例
# =============================================================================
extends Node

# 事件处理器条目资源
@export var audio_handler_entry: EventHandlerEntry
@export var particle_handler_entry: EventHandlerEntry

# 事件处理器实例
var audio_handler: JuicyEventHandler
var particle_handler: JuicyEventHandler

# 事件管理器
var event_manager: Node

func _ready():
	print("=== EventHandlerEntry 示例开始 ===")
	
	# 初始化事件管理器
	_init_event_manager()
	
	# 初始化事件处理器
	_init_event_handlers()
	
	# 演示事件处理
	_demo_event_handling()
	
	print("=== EventHandlerEntry 示例完成 ===")

func _init_event_manager():
	"""初始化事件管理器"""
	event_manager = Node.new()
	event_manager.name = "EventManager"
	add_child(event_manager)
	print("✓ 事件管理器初始化完成")

func _init_event_handlers():
	"""初始化事件处理器"""
	
	# 方法1：使用编辑器配置的资源
	if audio_handler_entry:
		audio_handler = audio_handler_entry.create_handler()
		if audio_handler:
			print("✓ 音频事件处理器创建成功: ", audio_handler.handler_name)
		else:
			print("✗ 音频事件处理器创建失败")
	
	# 方法2：程序化创建和配置
	if not particle_handler_entry:
		particle_handler_entry = EventHandlerEntry.new()
		particle_handler_entry.handler_class_name = "juicy_particle_event_handler"
		
		# 配置粒子处理器参数
		particle_handler_entry.config_data = {
			"max_pool_size": 25,
			"max_concurrent_systems": 12,
			"auto_cleanup_time": 8.0
		}
	
	# 创建粒子处理器实例
	particle_handler = particle_handler_entry.create_handler()
	if particle_handler:
		print("✓ 粒子事件处理器创建成功: ", particle_handler.handler_name)
	else:
		print("✗ 粒子事件处理器创建失败")

func _demo_event_handling():
	"""演示事件处理"""
	
	print("\n--- 事件处理演示 ---")
	
	# 演示1：音频事件处理
	_demo_audio_events()
	
	# 演示2：粒子事件处理
	_demo_particle_events()
	
	# 演示3：批量事件处理
	_demo_batch_event_processing()
	
	# 演示4：动态配置更新
	_demo_dynamic_configuration()

func _demo_audio_events():
	"""演示音频事件处理"""
	print("\n1. 音频事件处理演示")
	
	if not audio_handler:
		print("  音频处理器不可用，跳过演示")
		return
	
	# 创建测试音频事件
	var test_audio_stream = load("res://addons/juicy_mixer/tests/test_audio.wav") if FileAccess.file_exists("res://addons/juicy_mixer/tests/test_audio.wav") else null
	
	if test_audio_stream:
		var audio_event = JuicyEvent.create_audio_play_event(
			"Test",
			self, 
			test_audio_stream,
			Vector2(100, 200),
			0.8
		)
		
		# 检查处理器是否能处理此事件
		if audio_handler.can_handle(audio_event):
			print("  ✓ 音频处理器可以处理音频播放事件")
			
			# 处理事件
			var success = audio_handler.handle_event(audio_event)
			print("  ✓ 音频事件处理结果: ", "成功" if success else "失败")
		else:
			print("  ✗ 音频处理器无法处理此事件类型")
	else:
		print("  测试音频文件不存在，创建模拟事件")
		
		# 创建模拟事件用于测试
		var mock_event = JuicyEvent.new(JuicyEvent.EventType.AUDIO_PLAY)
		mock_event.target = self
		mock_event.event_data = {
			"audio_stream": null,
			"position": Vector2(100, 200),
			"volume": 0.8
		}
		
		if audio_handler.can_handle(mock_event):
			print("  ✓ 音频处理器可以处理模拟音频事件")
		else:
			print("  ✗ 音频处理器无法处理模拟音频事件")

func _demo_particle_events():
	"""演示粒子事件处理"""
	print("\n2. 粒子事件处理演示")
	
	if not particle_handler:
		print("  粒子处理器不可用，跳过演示")
		return
	
	# 创建测试粒子事件
	var particle_event = JuicyEvent.create_particle_spawn_event(
		"Test",
		self,
		null,  # 粒子场景
		50,    # 数量
		Vector2(300, 400)  # 位置
	)
	
	# 检查处理器是否能处理此事件
	if particle_handler.can_handle(particle_event):
		print("  ✓ 粒子处理器可以处理粒子生成事件")
		
		# 处理事件
		var success = particle_handler.handle_event(particle_event)
		print("  ✓ 粒子事件处理结果: ", "成功" if success else "失败")
	else:
		print("  ✗ 粒子处理器无法处理此事件类型")

func _demo_batch_event_processing():
	"""演示批量事件处理"""
	print("\n3. 批量事件处理演示")
	
	var handlers = []
	if audio_handler:
		handlers.append(audio_handler)
	if particle_handler:
		handlers.append(particle_handler)
	
	if handlers.size() == 0:
		print("  没有可用的事件处理器")
		return
	
	# 创建不同类型的事件
	var events = []
	
	# 音频事件
	var audio_event = JuicyEvent.new(JuicyEvent.EventType.AUDIO_PLAY)
	audio_event.target = self
	events.append(audio_event)
	
	# 粒子事件
	var particle_event = JuicyEvent.new(JuicyEvent.EventType.PARTICLE_SPAWN)
	particle_event.target = self
	events.append(particle_event)
	
	# UI更新事件
	var ui_event = JuicyEvent.create_ui_update_event("Test", self, "text", "Hello World")
	events.append(ui_event)
	
	# 处理所有事件
	var processed_count = 0
	for event in events:
		for handler in handlers:
			if handler.can_handle(event):
				var success = handler.handle_event(event)
				if success:
					processed_count += 1
					print("  ✓ 处理了事件类型: ", event.event_type)
					break
	
	print("  总共处理了 ", processed_count, " 个事件")

func _demo_dynamic_configuration():
	"""演示动态配置更新"""
	print("\n4. 动态配置更新演示")
	
	if not audio_handler_entry:
		print("  音频处理器条目不可用")
		return
	
	# 获取当前配置
	var current_config = audio_handler_entry.config_data
	print("  当前配置: ", current_config)
	
	# 修改配置
	var new_config = current_config.duplicate()
	new_config["master_volume"] = 0.5  # 降低音量
	new_config["max_concurrent_sounds"] = 10  # 减少并发数
	
	# 应用新配置
	audio_handler_entry.config_data = new_config
	
	# 重新创建处理器实例以应用新配置
	var new_handler = audio_handler_entry.create_handler()
	if new_handler:
		var new_handler_config = new_handler.get_configuration()
		print("  新配置: ", new_handler_config)
		print("  ✓ 配置更新成功")
		
		# 清理旧处理器
		if audio_handler:
			audio_handler.cleanup()
		
		audio_handler = new_handler
	else:
		print("  ✗ 配置更新失败")

func _exit_tree():
	"""清理资源"""
	print("\n--- 清理资源 ---")
	
	# 清理事件处理器
	if audio_handler:
		audio_handler.cleanup()
		print("✓ 音频处理器已清理")
	
	if particle_handler:
		particle_handler.cleanup()
		print("✓ 粒子处理器已清理")
	
	# 清理事件管理器
	if event_manager:
		event_manager.queue_free()
		print("✓ 事件管理器已清理")

# 辅助函数：创建事件处理器条目资源
static func create_handler_entry_resource(handler_class_name: String, config: Dictionary, save_path: String) -> EventHandlerEntry:
	"""创建并保存事件处理器条目资源"""
	
	var entry = EventHandlerEntry.new()
	entry.handler_class_name = handler_class_name
	entry.config_data = config
	
	# 保存资源
	var error = ResourceSaver.save(entry, save_path)
	if error == OK:
		print("✓ 事件处理器条目资源已保存: ", save_path)
		return entry
	else:
		print("✗ 保存事件处理器条目资源失败: ", error)
		return null

# 辅助函数：批量创建处理器
static func create_handlers_from_entries(entries: Array) -> Array:
	"""从条目数组创建处理器实例"""
	
	var handlers = []
	for entry in entries:
		if entry is EventHandlerEntry and entry.enabled:
			var handler = entry.create_handler()
			if handler:
				handlers.append(handler)
	
	return handlers

# 辅助函数：处理事件
static func process_event_with_handlers(event: JuicyEvent, handlers: Array) -> bool:
	"""使用处理器数组处理事件"""
	
	if not event or handlers.size() == 0:
		return false
	
	for handler in handlers:
		if handler is JuicyEventHandler and handler.can_handle(event):
			return handler.handle_event(event)
	
	return false