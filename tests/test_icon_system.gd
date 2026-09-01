extends Node

## 图标系统功能测试
## 测试 FuseIconManager 的核心功能

func _ready():
	print("=== 图标系统测试开始 ===\n")
	test_icon_manager()
	test_builtin_icons()
	test_placeholder_icons()
	test_performance()
	print("\n=== 图标系统测试完成 ===")

## 测试图标管理器初始化
func test_icon_manager():
	print("1. 测试图标管理器初始化")

	# FuseIconManager 是静态工具类，不需要实例化
	# 只需测试静态方法是否可用
	var test_icon = FuseIconManager.get_builtin_icon("Play")
	assert(test_icon != null, "FuseIconManager 静态方法应该正常工作")
	print("   ✓ 静态工具类正常")

	print("   ✓ 初始化测试通过\n")

## 测试内置图标加载
func test_builtin_icons():
	print("2. 测试内置图标加载")

	var test_icons = ["Play", "Stop", "New", "Print", "Edit", "Delete"]

	for icon_name in test_icons:
		var icon = FuseIconManager.get_builtin_icon(icon_name)
		if icon:
			print("   ✓ '%s' 图标加载成功" % icon_name)
		else:
			print("   ✗ '%s' 图标加载失败" % icon_name)

	print("   ✓ 内置图标测试完成\n")

## 测试占位图标
func test_placeholder_icons():
	print("3. 测试占位图标")

	# 当图标名称不存在时，get_builtin_icon 会自动生成占位图标
	var placeholder = FuseIconManager.get_builtin_icon("NonExistentIconPlaceholder")
	assert(placeholder != null, "占位图标不应为空")
	print("   ✓ 占位图标获取成功")

	# 测试不同的占位图标会生成（使用不同的名称）
	var placeholder2 = FuseIconManager.get_builtin_icon("AnotherNonExistentIcon")
	assert(placeholder2 != null, "第二个占位图标不应为空")
	print("   ✓ 多个占位图标生成成功")

	print("   ✓ 占位图标测试完成\n")

## 测试性能
func test_performance():
	print("4. 测试缓存性能")

	var start_time = Time.get_ticks_msec()

	# 加载 100 次相同图标
	for i in range(100):
		var icon = FuseIconManager.get_builtin_icon("Play")

	var elapsed = Time.get_ticks_msec() - start_time
	print("   ✓ 100 次加载耗时: %d ms (平均: %.2f ms)" % [elapsed, elapsed / 100.0])

	assert(elapsed < 100, "缓存加载应该很快 (<100ms)")
	print("   ✓ 缓存性能测试通过\n")
