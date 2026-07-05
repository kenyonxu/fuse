extends SceneTree

## AudioManager 规范合规性修复验证脚本
##
## 验证所有规范问题已修复

func _init():
	print("=== AudioManager 规范合规性验证 ===\n")

	# 验证所有修复
	var all_passed = true

	all_passed = all_passed and test_issue_1_category_registration()
	all_passed = all_passed and test_issue_2_print_output()
	all_passed = all_passed and test_issue_3_ready_print()
	all_passed = all_passed and test_issue_5_extra_features_removed()

	print("\n" + "=".repeat(50))
	if all_passed:
		print("✓ 所有规范问题已修复！")
	else:
		print("✗ 部分验证失败")
	print("=".repeat(50))

	quit()

func test_issue_1_category_registration() -> bool:
	print("[Issue 1] 验证类别注册逻辑实现...")

	# 直接读取源代码验证
	var file = FileAccess.open("res://addons/juicy_mixer/core/audio_manager.gd", FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var has_loop = "for category in default_categories:" in content
	var has_registration = "_audio_handler.register_category(category)" in content
	var has_count_print = 'Registered %d categories' in content

	if has_loop and has_registration and has_count_print:
		print("✓ 类别注册逻辑已实现")
		return true
	else:
		print("✗ 类别注册逻辑未完全实现")
		if not has_loop:
			print("  - 缺少 for 循环")
		if not has_registration:
			print("  - 缺少 register_category 调用")
		if not has_count_print:
			print("  - 缺少类别计数打印")
		return false

func test_issue_2_print_output() -> bool:
	print("[Issue 2] 验证 print 输出符合规格...")

	# 直接读取源代码验证
	var file = FileAccess.open("res://addons/juicy_mixer/core/audio_manager.gd", FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	if "Applied global limit config" in content:
		print("✓ print 输出符合规格")
		return true
	else:
		print("✗ print 输出不符合规格")
		return false

func test_issue_3_ready_print() -> bool:
	print("[Issue 3] 验证 _ready() print 输出符合规格...")

	# 直接读取源代码验证
	var file = FileAccess.open("res://addons/juicy_mixer/core/audio_manager.gd", FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	if "Initialized with scene-level config" in content:
		print("✓ _ready() print 输出符合规格")
		return true
	else:
		print("✗ _ready() print 输出不符合规格")
		return false

func test_issue_5_extra_features_removed() -> bool:
	print("[Issue 5] 验证额外功能已移除...")

	var manager = AudioManager.new()

	# 检查不应该存在的方法
	var methods_to_remove = [
		"get_mixing_config",
		"get_global_limit_config",
		"get_default_categories",
		"add_default_category",
		"remove_default_category",
		"get_debug_info"
	]

	var has_extra_methods = false
	for method in methods_to_remove:
		if manager.has_method(method):
			print("✗ 额外方法仍存在: ", method)
			has_extra_methods = true

	if not has_extra_methods:
		print("✓ 额外功能已移除")
		return true
	else:
		return false
