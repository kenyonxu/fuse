# =============================================================================
# EventHandlerEntry 测试脚本
# =============================================================================
extends Node

# 测试事件处理器条目
var test_entry: EventHandlerEntry

func _ready():
	print("=== EventHandlerEntry 测试开始 ===")
	
	# 测试1: 创建事件处理器条目
	test_create_entry()
	
	# 测试2: 扫描可用的事件处理器
	test_scan_handlers()
	
	# 测试3: 选择事件处理器
	test_select_handler()
	
	# 测试4: 配置事件处理器
	test_configure_handler()
	
	# 测试5: 创建事件处理器实例
	test_create_handler_instance()
	
	# 测试6: 测试配置模式
	test_configuration_schema()
	
	# 测试7: 测试资源名称更新
	test_resource_name()
	
	# 测试8: 测试调试功能
	test_debug_features()
	
	print("=== EventHandlerEntry 测试完成 ===")

func test_create_entry():
	print("\n--- 测试1: 创建事件处理器条目 ---")
	test_entry = EventHandlerEntry.new()
	assert(test_entry != null, "事件处理器条目创建失败")
	assert(test_entry.handler_class_name == "", "默认类名应该为空")
	assert(test_entry.enabled == true, "默认应该启用")
	assert(test_entry.priority == 0, "默认优先级应该为0")
	print("✓ 事件处理器条目创建成功")

func test_scan_handlers():
	print("\n--- 测试2: 扫描可用的事件处理器 ---")
	
	# 清除扫描缓存
	EventHandlerEntry.clear_scan_cache()
	
	# 创建新条目触发扫描
	var entry = EventHandlerEntry.new()
	
	# 等待扫描完成
	await get_tree().create_timer(0.1).timeout
	
	# 调试输出可用处理器
	entry.debug_print_available_handlers()
	
	# 检查是否发现了已知的事件处理器
	var available_handlers = []
	for key in EventHandlerEntry._available_handlers.keys():
		available_handlers.append(key)
	
	print("发现的事件处理器: ", available_handlers)
	
	# 验证是否发现了音频和粒子处理器
	var has_audio_handler = "juicy_audio_event_handler" in available_handlers
	var has_particle_handler = "juicy_particle_event_handler" in available_handlers
	
	assert(has_audio_handler, "应该发现音频事件处理器")
	assert(has_particle_handler, "应该发现粒子事件处理器")
	
	print("✓ 事件处理器扫描成功")
	print("  - 音频处理器: ", "✓" if has_audio_handler else "✗")
	print("  - 粒子处理器: ", "✓" if has_particle_handler else "✗")

func test_select_handler():
	print("\n--- 测试3: 选择事件处理器 ---")
	
	# 选择音频事件处理器
	test_entry.handler_class_name = "juicy_audio_event_handler"
	
	# 验证选择
	assert(test_entry.handler_class_name == "juicy_audio_event_handler", "类名设置失败")
	assert(test_entry.handler_script != null, "脚本应该被加载")
	
	# 获取处理器名称
	var handler_name = test_entry.get_handler_name()
	print("选择的事件处理器: ", handler_name)
	
	assert(handler_name == "AudioEventHandler", "处理器名称应该为 AudioEventHandler")
	
	print("✓ 事件处理器选择成功")

func test_configure_handler():
	print("\n--- 测试4: 配置事件处理器 ---")
	
	# 设置配置数据
	var test_config = {
		"max_pool_size": 25,
		"max_concurrent_sounds": 15,
		"master_volume": 0.7,
		"audio_bus": "SFX",
		"spatial_audio_enabled": true
	}
	
	test_entry.config_data = test_config
	
	# 验证配置
	var config_stats = test_entry.get_config_stats()
	print("配置统计: ", config_stats)
	
	assert(config_stats.has_script == true, "应该有脚本")
	assert(config_stats.enabled == true, "应该启用")
	assert(config_stats.config_keys.size() == 5, "应该有5个配置项")
	
	print("✓ 事件处理器配置成功")

func test_create_handler_instance():
	print("\n--- 测试5: 创建事件处理器实例 ---")
	
	# 创建事件处理器实例
	var handler = test_entry.create_handler()
	
	assert(handler != null, "事件处理器实例创建失败")
	assert(handler is JuicyEventHandler, "实例应该是 JuicyEventHandler 类型")
	
	# 验证配置已应用
	var handler_config = handler.get_configuration()
	print("处理器配置: ", handler_config)
	
	assert(handler_config.has("max_pool_size"), "配置应该包含 max_pool_size")
	assert(handler_config.max_pool_size == 25, "max_pool_size 应该为 25")
	assert(handler_config.master_volume == 0.7, "master_volume 应该为 0.7")
	
	# 测试事件处理能力
	var test_event = JuicyEvent.create_audio_play_event("Test", self, null)
	var can_handle = handler.can_handle(test_event)
	print("可以处理音频事件: ", can_handle)
	assert(can_handle == true, "音频处理器应该能处理音频事件")
	
	# 清理
	handler.cleanup()
	
	print("✓ 事件处理器实例创建和配置成功")

func test_configuration_schema():
	print("\n--- 测试6: 测试配置模式 ---")
	
	# 创建新的条目用于测试粒子处理器
	var particle_entry = EventHandlerEntry.new()
	particle_entry.handler_class_name = "juicy_particle_event_handler"
	
	# 等待配置更新
	await get_tree().create_timer(0.1).timeout
	
	# 获取配置统计
	var config_stats = particle_entry.get_config_stats()
	print("粒子处理器配置统计: ", config_stats)
	
	# 创建实例测试配置
	var particle_handler = particle_entry.create_handler()
	var particle_config = particle_handler.get_configuration()
	print("粒子处理器配置: ", particle_config)
	
	assert(particle_config.has("max_pool_size"), "粒子配置应该包含 max_pool_size")
	assert(particle_config.has("max_concurrent_systems"), "粒子配置应该包含 max_concurrent_systems")
	assert(particle_config.has("auto_cleanup_time"), "粒子配置应该包含 auto_cleanup_time")
	
	# 清理
	particle_handler.cleanup()
	
	print("✓ 配置模式测试成功")

func test_resource_name():
	print("\n--- 测试7: 测试资源名称更新 ---")
	
	# 测试资源名称
	var resource_name = str(test_entry)
	print("资源名称: ", resource_name)
	
	assert(resource_name.contains("AudioEventHandler"), "资源名称应该包含处理器名称")
	assert(resource_name.contains("Priority: 0"), "资源名称应该包含优先级")
	assert(resource_name.contains("✓"), "资源名称应该包含启用状态图标")
	
	# 测试禁用状态
	test_entry.enabled = false
	var disabled_name = str(test_entry)
	print("禁用状态名称: ", disabled_name)
	assert(disabled_name.contains("✗"), "禁用状态应该显示 ✗")
	
	# 恢复启用状态
	test_entry.enabled = true
	
	print("✓ 资源名称更新测试成功")

func test_debug_features():
	print("\n--- 测试8: 测试调试功能 ---")
	
	# 测试配置统计
	var config_stats = test_entry.get_config_stats()
	print("配置统计信息: ", config_stats)
	
	assert(config_stats.has("has_script"), "配置统计应该包含 has_script")
	assert(config_stats.has("enabled"), "配置统计应该包含 enabled")
	assert(config_stats.has("priority"), "配置统计应该包含 priority")
	assert(config_stats.has("config_keys"), "配置统计应该包含 config_keys")
	assert(config_stats.has("default_keys"), "配置统计应该包含 default_keys")
	
	# 测试强制刷新
	test_entry.force_refresh_property_list()
	print("✓ 强制刷新属性列表成功")
	
	# 测试重新扫描
	EventHandlerEntry.rescan_handlers()
	print("✓ 重新扫描事件处理器成功")
	
	print("✓ 调试功能测试成功")

# 辅助函数：等待指定时间
func wait_seconds(seconds: float):
	await get_tree().create_timer(seconds).timeout