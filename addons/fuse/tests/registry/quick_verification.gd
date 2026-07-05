# quick_verification.gd
extends Node

## 快速验证注册系统的基本结构是否正确

func _ready():
	print("\n=== 快速验证注册系统 ===\n")

	# 验证 ComponentRegistry
	verify_component_registry()

	# 验证 EventRegistry
	verify_event_registry()

	# 验证 ConditionRegistry
	verify_condition_registry()

	# 验证 InstructionRegistry
	verify_instruction_registry()

	print("\n=== 验证完成 ===\n")

## 验证 ComponentRegistry
func verify_component_registry():
	print("[验证] ComponentRegistry")

	# 检查类是否存在
	if ClassDB.class_exists("ComponentRegistry"):
		print("  ✓ ComponentRegistry 类存在")
	else:
		print("  ✗ ComponentRegistry 类不存在")
		return

	# 检查方法
	var methods = ["register", "get_all", "get_by_name", "get_count", "clear_all", "search"]
	for method in methods:
		if ClassDB.class_has_method("ComponentRegistry", method):
			print("  ✓ 方法 '%s' 存在" % method)
		else:
			print("  ✗ 方法 '%s' 不存在" % method)

## 验证 EventRegistry
func verify_event_registry():
	print("\n[验证] EventRegistry")

	if not ClassDB.class_exists("EventRegistry"):
		print("  ✗ EventRegistry 类不存在")
		return

	var methods = ["register_event", "get_all_events", "get_event_by_name", "get_event_count", "search_events", "clear_all_events"]
	for method in methods:
		if ClassDB.class_has_method("EventRegistry", method):
			print("  ✓ 方法 '%s' 存在" % method)
		else:
			print("  ✗ 方法 '%s' 不存在" % method)

## 验证 ConditionRegistry
func verify_condition_registry():
	print("\n[验证] ConditionRegistry")

	if not ClassDB.class_exists("ConditionRegistry"):
		print("  ✗ ConditionRegistry 类不存在")
		return

	var methods = ["register_condition", "get_all_conditions", "get_condition_by_name", "get_condition_count", "search_conditions", "clear_all_conditions"]
	for method in methods:
		if ClassDB.class_has_method("ConditionRegistry", method):
			print("  ✓ 方法 '%s' 存在" % method)
		else:
			print("  ✗ 方法 '%s' 不存在" % method)

## 验证 InstructionRegistry
func verify_instruction_registry():
	print("\n[验证] InstructionRegistry（向后兼容）")

	if not ClassDB.class_exists("InstructionRegistry"):
		print("  ✗ InstructionRegistry 类不存在")
		return

	var methods = [
		"register_instruction",
		"get_all_instructions",
		"get_instruction_by_name",
		"get_instruction_count",
		"search_instructions",
		"clear_all"
	]

	for method in methods:
		if ClassDB.class_has_method("InstructionRegistry", method):
			print("  ✓ 方法 '%s' 存在" % method)
		else:
			print("  ✗ 方法 '%s' 不存在" % method)
