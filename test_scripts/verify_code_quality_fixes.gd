extends SceneTree

## 验证代码质量改进
##
## 测试以下改进：
## 1. register_category() 参数验证
## 2. update_mixing_config() 参数验证
## 3. update_global_config() 参数验证

func _init():
	print("=== AudioManager 代码质量改进验证 ===\n")

	# 测试参数验证
	test_parameter_validation()

	print("\n==================================================")
	print("✓ 代码质量改进验证完成！")
	print("==================================================")

	quit()

func test_parameter_validation():
	print("[测试 1] 验证 update_mixing_config() 参数验证...")

	# 创建 AudioManager
	var manager = AudioManager.new()

	# 测试传入 null
	manager.update_mixing_config(null)
	# 预期：会打印警告消息，但不会崩溃
	print("✓ null 参数不会导致崩溃")

	# 测试传入有效配置
	var config = AudioMixingConfig.new()
	manager.update_mixing_config(config)
	assert(manager.instance_mixing_config == config, "配置应该被正确设置")
	print("✓ 有效配置被正确设置\n")

	# 重新创建管理器以测试下一个功能
	manager.free()

	print("[测试 2] 验证 update_global_config() 参数验证...")

	manager = AudioManager.new()
	manager._ready()  # 初始化

	# 测试传入 null
	manager.update_global_config(null)
	# 预期：会打印警告消息，但不会崩溃
	print("✓ null 参数不会导致崩溃")

	# 测试传入有效配置
	var global_config = GlobalAudioLimitConfig.new()
	manager.update_global_config(global_config)
	assert(manager.global_limit_config == global_config, "配置应该被正确设置")
	print("✓ 有效配置被正确设置\n")

	manager.free()

	print("[测试 3] 验证 register_category() 参数验证...")

	var handler = JuicyAudioEventHandler.new()

	# 测试传入 null
	handler.register_category(null)
	# 预期：会打印警告消息，但不会崩溃
	print("✓ null 参数不会导致崩溃")

	# 测试传入有效类别
	var category = AudioCategory.new()
	category.category_name = "TestCategory"
	handler.register_category(category)
	# 预期：不会崩溃，虽然逻辑还未实现
	print("✓ 有效类别不会导致崩溃")

	# handler 是 RefCounted，不需要手动释放

	print("\n[测试 4] 验证文档注释完整性...")

	# 读取源文件并检查文档注释
	var file = FileAccess.open("res://addons/juicy_mixer/core/audio_manager.gd", FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	# 检查关键文档是否存在
	var checks = {
		"enable_inheritance": content.contains("## 是否启用配置继承（未来功能）"),
		"enable_debug_view": content.contains("## 是否启用调试视图（未来功能）"),
		"update_mixing_config": content.contains("## 运行时更新混音配置"),
		"update_global_config": content.contains("## 运行时更新全局限额配置"),
	}

	for check_name in checks:
		if checks[check_name]:
			print("✓ %s 文档存在" % check_name)
		else:
			print("✗ %s 文档缺失" % check_name)

	# 读取 handler 文件并检查文档
	file = FileAccess.open("res://addons/juicy_mixer/events/juicy_audio_event_handler.gd", FileAccess.READ)
	content = file.get_as_text()
	file.close()

	if content.contains("## 此方法为 AudioManager 提供类别注册接口"):
		print("✓ register_category() 详细文档存在")
	else:
		print("✗ register_category() 详细文档缺失")

	print()
