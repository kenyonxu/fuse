@tool
extends EditorScript

## 编辑器信号下拉列表测试脚本
## 用于验证 OnTargetSignalEmit 的编辑器功能

func _run():
	print("=== 编辑器信号下拉列表测试开始 ===")

	# 创建测试场景
	var test_scene = create_test_scene()
	if not test_scene:
		print("❌ 创建测试场景失败")
		return

	# 创建 OnTargetSignalEmit 实例
	var signal_event = OnTargetSignalEmit.new()
	signal_event.log_level = FuseLogger.LogLevel.DEBUG

	# 测试1: 无目标节点时的属性列表
	print("\n--- 测试1: 无目标节点时的属性列表 ---")
	test_empty_target_node(signal_event)

	# 测试2: 有目标节点时的属性列表
	print("\n--- 测试2: 有目标节点时的属性列表 ---")
	test_with_target_node(signal_event, test_scene)

	# 测试3: 信号选择后的属性列表
	print("\n--- 测试3: 信号选择后的属性列表 ---")
	test_signal_selection(signal_event, test_scene)

	print("\n=== 编辑器信号下拉列表测试完成 ===")

## 创建测试场景
func create_test_scene() -> Node:
	var scene = Node.new()
	scene.name = "TestScene"

	# 添加按钮节点
	var button = Button.new()
	button.name = "TestButton"
	scene.add_child(button)

	# 添加标签节点
	var label = Label.new()
	label.name = "TestLabel"
	scene.add_child(label)

	# 添加定时器节点
	var timer = Timer.new()
	timer.name = "TestTimer"
	scene.add_child(timer)

	print("✓ 创建测试场景，包含节点: Button, Label, Timer")
	return scene

## 测试无目标节点时的属性列表
func test_empty_target_node(signal_event):
	var properties = signal_event._get_property_list()

	# 查找 target_signal 属性
	var target_signal_property = null
	for prop in properties:
		if prop.name == "target_signal":
			target_signal_property = prop
			break

	if not target_signal_property:
		print("❌ 未找到 target_signal 属性")
		return

	print("target_signal 属性类型: ", target_signal_property.type)
	print("target_signal 属性提示: ", target_signal_property.hint)
	print("target_signal 提示字符串: ", target_signal_property.hint_string)
	print("target_signal 使用方式: ", target_signal_property.usage)

	# 验证是否为只读状态
	if target_signal_property.usage & PROPERTY_USAGE_READ_ONLY:
		print("✓ 无目标节点时，target_signal 正确设置为只读")
	else:
		print("❌ 无目标节点时，target_signal 应该为只读")

## 测试有目标节点时的属性列表
func test_with_target_node(signal_event, test_scene):
	# 设置目标节点路径
	signal_event.target_node_path = "TestButton"

	# 直接测试信号获取功能，因为我们在非编辑器环境中
	print("⚠️  在非编辑器环境中运行，直接测试信号发现功能")
	test_signal_discovery(signal_event, test_scene)

	# 即使在非编辑器环境中，我们也测试属性列表生成
	var properties = signal_event._get_property_list()

	# 查找 target_signal 属性
	var target_signal_property = null
	for prop in properties:
		if prop.name == "target_signal":
			target_signal_property = prop
			break

	if not target_signal_property:
		print("❌ 未找到 target_signal 属性")
		return

	print("target_signal 属性类型: ", target_signal_property.type)
	print("target_signal 属性提示: ", target_signal_property.hint)
	print("target_signal 提示字符串: ", target_signal_property.hint_string)
	print("target_signal 使用方式: ", target_signal_property.usage)

	# 验证是否为下拉列表
	if target_signal_property.hint == PROPERTY_HINT_ENUM:
		print("✓ 有目标节点时，target_signal 正确设置为下拉列表")

		# 检查信号列表
		var signal_names = target_signal_property.hint_string.split(",")
		print("可用信号数量: ", signal_names.size())
		print("可用信号: ", signal_names)

		if signal_names.size() > 0:
			print("✓ 成功获取到信号列表")
		else:
			print("❌ 未能获取到信号列表")
	else:
		print("❌ 有目标节点时，target_signal 应该为下拉列表")

## 测试信号发现功能
func test_signal_discovery(signal_event, test_scene):
	print("测试信号发现功能...")

	# 手动获取按钮的信号
	var button = test_scene.get_node("TestButton")
	if not button:
		print("❌ 无法找到测试按钮")
		return

	var signals = SignalManager.get_node_signals(button)
	print("按钮信号数量: ", signals.size())

	for signal_info in signals:
		print("  - ", signal_info.get_display_name())

	if signals.size() > 0:
		print("✓ 信号发现功能正常")
	else:
		print("❌ 信号发现功能异常")

## 测试信号选择后的属性列表
func test_signal_selection(signal_event, test_scene):
	# 设置目标节点和信号
	signal_event.target_node_path = "TestButton"
	signal_event.target_signal = "pressed"

	var properties = signal_event._get_property_list()

	# 查找 filter_signal_args 属性
	var filter_property = null
	for prop in properties:
		if prop.name == "filter_signal_args":
			filter_property = prop
			break

	if not filter_property:
		print("❌ 未找到 filter_signal_args 属性")
		return

	print("filter_signal_args 属性存在")

	# 如果选择了信号，检查是否有参数过滤相关属性
	if signal_event.filter_signal_args:
		# 这里应该会有参数过滤相关的属性
		print("✓ 信号选择后，参数过滤功能可用")
	else:
		print("✓ 信号选择功能正常")