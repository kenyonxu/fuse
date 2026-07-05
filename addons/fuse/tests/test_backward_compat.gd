extends Node

## 向后兼容性测试
## 测试旧的 icon 字段仍然可以正常工作

# 预加载测试事件
const IconTestEvent = preload("res://addons/fuse/tests/test_helper_events/icon_test_event.gd")

func _ready():
	print("=== 向后兼容性测试开始 ===\n")
	test_old_icon_field()
	test_mixed_usage()
	test_instruction_metadata()
	print("\n=== 向后兼容性测试完成 ===")

## 测试旧的 icon 字段
func test_old_icon_field():
	print("1. 测试旧 icon 字段")

	# 创建测试事件
	var test_event = IconTestEvent.new()
	assert(test_event != null, "应该能创建 IconTestEvent")

	# 设置旧字段（使用一个不存在的图标名称会自动生成占位图标）
	var placeholder = FuseIconManager.get_builtin_icon("NonExistentIcon12345")
	assert(placeholder != null, "应该能获取占位图标")
	test_event.icon = placeholder

	# 验证可以获取
	var retrieved_icon = test_event.get_event_icon()
	assert(retrieved_icon != null, "旧 icon 字段应该仍然工作")
	print("   ✓ 旧 icon 字段正常工作")

	print("   ✓ 旧字段测试通过\n")

## 测试混合使用
func test_mixed_usage():
	print("2. 测试混合使用（新旧字段）")

	var test_event = IconTestEvent.new()

	# 优先使用新字段
	test_event.icon_name = "Play"
	var icon = test_event.get_event_icon()
	assert(icon != null, "icon_name 应该优先")
	print("   ✓ icon_name 优先级正确")

	# 新字段为空时使用旧字段
	test_event.icon_name = ""
	# 使用不存在的图标名称获取占位图标
	test_event.icon = FuseIconManager.get_builtin_icon("NonExistentIcon67890")
	icon = test_event.get_event_icon()
	assert(icon != null, "icon 字段应该作为后备")
	print("   ✓ icon 字段作为后备正常")

	print("   ✓ 混合使用测试通过\n")

## 测试指令元数据中的图标
func test_instruction_metadata():
	print("3. 测试指令元数据图标")

	# 测试 CreateVariable 指令
	var create_var_metadata = CreateVariable._get_instruction_metadata()
	assert(create_var_metadata.icon_name == "New", "CreateVariable 应该使用 'New' 图标")
	print("   ✓ CreateVariable 图标: %s" % create_var_metadata.icon_name)

	# 测试 Print 指令
	var print_metadata = Print._get_instruction_metadata()
	assert(print_metadata.icon_name == "Print", "Print 应该使用 'Print' 图标")
	print("   ✓ Print 图标: %s" % print_metadata.icon_name)

	print("   ✓ 指令元数据测试通过\n")
