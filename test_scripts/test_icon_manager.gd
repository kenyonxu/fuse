# test_icon_manager.gd
## 测试 FuseIconManager 基本功能

extends Node

func _ready():
	print("=== FuseIconManager 功能测试 ===\n")

	# 测试 1: 初始化
	print("[测试 1] 初始化图标管理器")
	FuseIconManager.init()
	print("✓ 初始化完成\n")

	# 等待一帧以确保初始化完成
	await get_tree().process_frame

	# 测试 2: 获取存在的内置图标
	print("[测试 2] 获取存在的内置图标 (Script)")
	var script_icon = FuseIconManager.get_builtin_icon("Script")
	if script_icon != null:
		print("✓ 成功获取 Script 图标")
		print("  图标类型: %s" % script_icon.get_class())
	else:
		print("✗ 获取 Script 图标失败")
	print("")

	# 测试 3: 获取不存在的图标（应该返回占位图标）
	print("[测试 3] 获取不存在的图标 (NonExistentIcon)")
	var placeholder_icon = FuseIconManager.get_builtin_icon("NonExistentIcon")
	if placeholder_icon != null:
		print("✓ 成功返回占位图标")
		print("  图标类型: %s" % placeholder_icon.get_class())
	else:
		print("✗ 未能返回占位图标")
	print("")

	# 测试 4: 缓存验证（第二次获取同一图标应该返回同一对象）
	print("[测试 4] 缓存验证")
	var script_icon_2 = FuseIconManager.get_builtin_icon("Script")
	if script_icon == script_icon_2:
		print("✓ 缓存工作正常，返回同一对象")
	else:
		print("✗ 缓存失效，返回了不同对象")
	print("")

	# 测试 5: 检查图标是否存在
	print("[测试 5] 检查图标是否存在")
	print("  Script 图标存在: %s" % FuseIconManager.has_builtin_icon("Script"))
	print("  NonExistentIcon 图标存在: %s" % FuseIconManager.has_builtin_icon("NonExistentIcon"))
	print("")

	# 测试 6: 智能获取图标（多种输入类型）
	print("[测试 6] 智能获取图标")
	print("  字符串 'Script': %s" % ("成功" if FuseIconManager.get_icon("Script") != null else "失败"))
	print("  Texture2D 直接返回: %s" % ("成功" if FuseIconManager.get_icon(script_icon) == script_icon else "失败"))
	print("  空字符串: %s" % ("成功" if FuseIconManager.get_icon("") == null else "失败"))
	print("  null: %s" % ("成功" if FuseIconManager.get_icon(null) == null else "失败"))
	print("")

	# 测试 7: 清理
	print("[测试 7] 清理缓存")
	FuseIconManager.cleanup()
	print("✓ 清理完成")
	print("")

	print("=== 测试完成 ===")

	# 退出游戏
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
