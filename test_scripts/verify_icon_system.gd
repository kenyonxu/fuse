@tool
extends EditorScript

## 快速验证图标管理系统

# 预加载测试事件
const IconTestEvent = preload("res://addons/fuse/tests/test_helper_events/icon_test_event.gd")
##
## 使用方法:
## 1. 在 Godot 编辑器中，点击 Project > Tools > Execute Script (或在编辑器中按 Ctrl+Shift+X)
## 2. 选择此脚本 (verify_icon_system.gd)
## 3. 点击运行
## 4. 观察控制台输出

func _run():
	print("\n" + "=".repeat(60))
	print("Fuse 图标管理系统 - 快速验证")
	print("=".repeat(60) + "\n")

	# 验证 1: 检查 FuseIconManager 静态方法
	print("1. 检查 FuseIconManager 静态方法...")
	var test_icon = FuseIconManager.get_builtin_icon("Play")
	if test_icon:
		print("   ✓ FuseIconManager 静态方法正常")
	else:
		print("   ✗ FuseIconManager 静态方法测试失败")
		return

	# 验证 2: 测试内置图标加载
	print("\n2. 测试内置图标加载...")
	var test_icons = ["Play", "Stop", "New", "Print", "Edit", "Delete"]
	var loaded_count = 0

	for icon_name in test_icons:
		var icon = FuseIconManager.get_builtin_icon(icon_name)
		if icon:
			loaded_count += 1
			print("   ✓ '%s' 图标加载成功" % icon_name)
		else:
			print("   ✗ '%s' 图标加载失败" % icon_name)

	print("   加载成功率: %d/%d" % [loaded_count, test_icons.size()])

	# 验证 3: 测试占位图标
	print("\n3. 测试占位图标...")
	# 使用不存在的图标名称会自动生成占位图标
	var placeholder = FuseIconManager.get_builtin_icon("NonExistentIconForVerification")
	if placeholder:
		print("   ✓ 占位图标生成成功")
	else:
		print("   ✗ 占位图标生成失败")

	# 验证 4: 测试 BaseEvent 图标
	print("\n4. 测试 BaseEvent 图标系统...")
	var test_event = IconTestEvent.new()
	if test_event:
		var event_icon = test_event.get_event_icon()
		if event_icon:
			print("   ✓ IconTestEvent 图标获取成功")
			print("   ✓ 事件使用 icon_name = 'Play'")
		else:
			print("   ✗ IconTestEvent 图标获取失败")
	else:
		print("   ✗ IconTestEvent 创建失败")

	# 验证 5: 测试指令元数据图标
	print("\n5. 测试指令元数据图标...")
	var create_var_metadata = CreateVariable._get_instruction_metadata()
	if create_var_metadata.icon_name == "New":
		print("   ✓ CreateVariable 图标: %s" % create_var_metadata.icon_name)
	else:
		print("   ✗ CreateVariable 图标配置错误")

	var print_metadata = Print._get_instruction_metadata()
	if print_metadata.icon_name == "Print":
		print("   ✓ Print 图标: %s" % print_metadata.icon_name)
	else:
		print("   ✗ Print 图标配置错误")

	# 验证 6: 性能测试
	print("\n6. 性能测试（100 次图标加载）...")
	var start_time = Time.get_ticks_msec()

	for i in range(100):
		var icon = FuseIconManager.get_builtin_icon("Play")

	var elapsed = Time.get_ticks_msec() - start_time
	print("   ✓ 耗时: %d ms (平均: %.2f ms/次)" % [elapsed, elapsed / 100.0])

	if elapsed < 100:
		print("   ✓ 性能优秀 (< 100ms)")
	elif elapsed < 500:
		print("   ⚠ 性能可接受 (< 500ms)")
	else:
		print("   ✗ 性能需要优化 (>= 500ms)")

	# 总结
	print("\n" + "=".repeat(60))
	print("验证完成！")
	print("=".repeat(60) + "\n")

	print("下一步:")
	print("1. 运行 test_icon_system.tscn 进行完整测试")
	print("2. 运行 test_backward_compat.tscn 进行兼容性测试")
	print("3. 在编辑器中创建 Trigger 节点测试图标显示")
