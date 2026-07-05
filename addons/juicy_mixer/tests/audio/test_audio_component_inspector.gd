@tool
extends Node

## AudioComponentInspector 测试场景
##
## 用于手动测试 AudioComponentInspector 插件功能
##
## 使用方法:
## 1. 在编辑器中打开此场景
## 2. 在 FileSystem dock 中创建 AudioComponent 资源
## 3. 选中资源并在 Inspector 中查看
## 4. 验证自定义按钮是否显示

func _ready():
	print("=== AudioComponentInspector 测试场景 ===")
	print("\n此场景用于测试 AudioComponentInspector 插件功能")
	print("\n测试步骤:")
	print("1. 在 FileSystem dock 中右键点击")
	print("2. 选择 '新建资源'")
	print("3. 搜索并选择 'AudioComponent'")
	print("4. 在 Inspector 中查看自定义按钮")
	print("   - '+ 快速添加' 按钮")
	print("   - '🔍 自动检测信号' 按钮")
	print("\n预期结果:")
	print("- 两个按钮应该显示在 Inspector 顶部")
	print("- 点击 '+ 快速添加' 应该添加新的 AudioBinding")
	print("- 点击 '🔍 自动检测信号' 应该显示信息对话框")

	# 自动创建测试资源
	_create_test_component()

	print("\n✓ 测试资源已创建并选中")
	print("  请在 Inspector 中查看自定义控件")


func _create_test_component():
	## 创建测试 AudioComponent 资源

	var test_component := AudioComponent.new()
	test_component.resource_name = "TestAudioComponent"

	# 添加一个示例绑定
	var binding := AudioBinding.new()
	binding.signal_name = "test_signal"
	binding.adv_cooldown = 0.5
	test_component.audio_bindings.append(binding)

	# 保存资源
	var save_path := "res://test_audio_component.tres"
	var error := ResourceSaver.save(test_component, save_path)

	if error != OK:
		print("❌ 保存测试资源失败: ", error)
		return

	print("✓ 测试资源已保存到: ", save_path)

	# 在编辑器中选中和显示资源
	if Engine.is_editor_hint():
		# 延迟一帧以确保资源已保存
		await get_tree().process_frame

		# 在 FileSystem dock 中选中新创建的资源
		if EditorInterface:
			EditorInterface.select_file(save_path)

			# 确保 Inspector 可见
			EditorInterface.inspect_object(test_component)
			print("✓ 测试资源已在 Inspector 中显示")
		else:
			print("⚠ 警告: 无法获取 EditorInterface")
	else:
		print("⚠ 警告: 此场景需要在编辑器中运行才能完整测试")
