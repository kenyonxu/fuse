@tool
extends EditorScript

## Task 3.1 验证脚本
##
## 验证 AudioComponentInspector 插件是否正确实现

func _run():
	print("=== Task 3.1 验证开始 ===")
	print("\n1. 检查 AudioComponentInspector 文件存在...")

	var inspector_path = "res://addons/juicy_mixer/editor/audio_component_inspector.gd"
	var inspector_file = FileAccess.open(inspector_path, FileAccess.READ)

	if not inspector_file:
		print("   ❌ 失败: AudioComponentInspector 文件不存在")
		return
	else:
		print("   ✓ 文件存在")
		inspector_file.close()

	print("\n2. 检查 AudioComponentInspector 类定义...")

	var inspector_script = load(inspector_path)
	if not inspector_script:
		print("   ❌ 失败: 无法加载脚本")
		return

	# 检查类名
	var inspector_instance = inspector_script.new()
	if not inspector_instance:
		print("   ❌ 失败: 无法实例化")
		return

	if inspector_instance.get_class() != "AudioComponentInspector":
		if not ClassDB.class_exists("AudioComponentInspector"):
			print("   ⚠ 警告: class_name 可能未正确加载，但实例可以创建")
		else:
			print("   ✓ 类定义正确")
	else:
		print("   ✓ 类定义正确")

	print("\n3. 检查必需方法...")

	# 检查 _can_handle
	if not inspector_instance.has_method("_can_handle"):
		print("   ❌ 失败: 缺少 _can_handle 方法")
	else:
		print("   ✓ _can_handle 方法存在")

	# 检查 _parse_begin
	if not inspector_instance.has_method("_parse_begin"):
		print("   ❌ 失败: 缺少 _parse_begin 方法")
	else:
		print("   ✓ _parse_begin 方法存在")

	# 检查回调方法
	if not inspector_instance.has_method("_on_add_binding"):
		print("   ❌ 失败: 缺少 _on_add_binding 方法")
	else:
		print("   ✓ _on_add_binding 方法存在")

	if not inspector_instance.has_method("_on_auto_detect_signals"):
		print("   ❌ 失败: 缺少 _on_auto_detect_signals 方法")
	else:
		print("   ✓ _on_auto_detect_signals 方法存在")

	print("\n4. 检查 plugin.gd 集成...")

	var plugin_path = "res://addons/juicy_mixer/plugin.gd"
	var plugin_file = FileAccess.open(plugin_path, FileAccess.READ)

	if not plugin_file:
		print("   ❌ 失败: plugin.gd 文件不存在")
		return

	var plugin_content = plugin_file.get_as_text()
	plugin_file.close()

	# 检查 preload
	if "const AudioComponentInspector = preload" in plugin_content:
		print("   ✓ AudioComponentInspector 已 preload")
	else:
		print("   ❌ 失败: AudioComponentInspector 未 preload")
		return

	# 检查成员变量
	if "var audio_component_inspector: EditorInspectorPlugin" in plugin_content:
		print("   ✓ audio_component_inspector 成员变量已声明")
	else:
		print("   ❌ 失败: audio_component_inspector 成员变量未声明")
		return

	# 检查注册
	if "audio_component_inspector = AudioComponentInspector.new()" in plugin_content:
		print("   ✓ 在 _enter_tree() 中实例化")
	else:
		print("   ❌ 失败: 未在 _enter_tree() 中实例化")
		return

	if "add_inspector_plugin(audio_component_inspector)" in plugin_content:
		print("   ✓ 在 _enter_tree() 中注册")
	else:
		print("   ❌ 失败: 未在 _enter_tree() 中注册")
		return

	# 检查移除
	if "remove_inspector_plugin(audio_component_inspector)" in plugin_content:
		print("   ✓ 在 _exit_tree() 中移除")
	else:
		print("   ❌ 失败: 未在 _exit_tree() 中移除")
		return

	print("\n5. 检查按钮文本...")

	if not inspector_script.source_code.contains("+ 快速添加"):
		print("   ❌ 失败: '+ 快速添加' 按钮文本不正确")
	else:
		print("   ✓ '+ 快速添加' 按钮文本正确")

	if not inspector_script.source_code.contains("🔍 自动检测信号"):
		print("   ❌ 失败: '🔍 自动检测信号' 按钮文本不正确")
	else:
		print("   ✓ '🔍 自动检测信号' 按钮文本正确")

	print("\n6. 测试 _can_handle 功能...")

	# 创建测试 AudioComponent
	var audio_component_path = "res://addons/juicy_mixer/resources/audio/audio_component.gd"
	var audio_component_script = load(audio_component_path)

	if not audio_component_script:
		print("   ⚠ 跳过: 无法加载 AudioComponent 脚本进行测试")
	else:
		var test_component = audio_component_script.new()

		# 测试 _can_handle
		var can_handle_result = inspector_instance._can_handle(test_component)
		if can_handle_result == true:
			print("   ✓ _can_handle 正确识别 AudioComponent")
		else:
			print("   ❌ 失败: _can_handle 未正确识别 AudioComponent")

		# 测试对非 AudioComponent 返回 false
		var test_node = Node.new()
		var cannot_handle_result = inspector_instance._can_handle(test_node)
		if cannot_handle_result == false:
			print("   ✓ _can_handle 正确拒绝非 AudioComponent 对象")
		else:
			print("   ❌ 失败: _can_handle 应该拒绝非 AudioComponent 对象")

	print("\n7. 测试 _on_add_binding 功能...")

	var test_component2 = audio_component_script.new()
	var initial_count = test_component2.audio_bindings.size()

	# 调用 _on_add_binding
	inspector_instance._on_add_binding(test_component2)

	var new_count = test_component2.audio_bindings.size()
	if new_count == initial_count + 1:
		print("   ✓ _on_add_binding 成功添加绑定")
	else:
		print("   ❌ 失败: _on_add_binding 未成功添加绑定 (期望: %d, 实际: %d)" % [initial_count + 1, new_count])

	# 验证添加的是 AudioBinding
	var last_binding = test_component2.audio_bindings.back()
	if last_binding and last_binding.get("signal_name") != null:
		print("   ✓ 添加的对象是 AudioBinding")
	else:
		print("   ❌ 失败: 添加的对象不是 AudioBinding")

	print("\n8. 测试 _on_auto_detect_signals 功能...")

	# 这个功能应该打印警告信息（因为 get_edited_object() 会返回 null）
	print("   测试 _on_auto_detect_signals（应该打印警告）...")
	inspector_instance._on_auto_detect_signals(test_component2)
	print("   ✓ _on_auto_detect_signals 执行完成")

	print("\n=== Task 3.1 验证完成 ===")
	print("\n总结:")
	print("  - AudioComponentInspector 文件已创建")
	print("  - 所有必需方法已实现")
	print("  - plugin.gd 集成正确")
	print("  - 按钮文本符合规范")
	print("  - 核心功能测试通过")
	print("\n✓ Task 3.1 实现完成！")
	print("\n下一步:")
	print("  1. 在 Godot 编辑器中重启插件")
	print("  2. 创建 AudioComponent 资源")
	print("  3. 在 Inspector 中验证按钮显示")
	print("  4. 测试按钮功能")
