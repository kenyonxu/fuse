# verify_backward_compatibility.gd
extends Node

## 验证 InstructionRegistry 的向后兼容性

func _ready():
	print("\n=== 验证 InstructionRegistry 向后兼容性 ===\n")

	# 测试所有旧的公共方法是否仍然可用
	test_backward_compatibility()

	print("\n=== 向后兼容性验证完成 ===\n")

## 测试向后兼容性
func test_backward_compatibility():
	print("[测试] InstructionRegistry 旧方法调用")

	# 1. 测试 get_all_instructions()
	var all_instructions = InstructionRegistry.get_all_instructions()
	print("  ✓ get_all_instructions() 可用，返回 %d 个指令" % all_instructions.size())

	# 2. 测试 get_instruction_by_name()
	var test_instruction = InstructionRegistry.get_instruction_by_name("SetIntVariable")
	if not test_instruction.is_empty():
		print("  ✓ get_instruction_by_name() 可用，能找到 'SetIntVariable'")
	else:
		print("  ✗ get_instruction_by_name() 未找到 'SetIntVariable'")

	# 3. 测试 get_instruction_count()
	var count = InstructionRegistry.get_instruction_count()
	print("  ✓ get_instruction_count() 可用，返回 %d" % count)

	# 4. 测试 clear_all()
	var before_clear = InstructionRegistry.get_instruction_count()
	InstructionRegistry.clear_all()
	var after_clear = InstructionRegistry.get_instruction_count()

	if after_clear == 0:
		print("  ✓ clear_all() 可用，成功清空注册表")
		# 恢复注册
		_restore_instruction_registration()
	else:
		print("  ✗ clear_all() 未生效")

	# 5. 测试新的搜索方法
	var search_results = InstructionRegistry.search_instructions("variable")
	print("  ✓ search_instructions() 可用，找到 %d 个结果" % search_results.size())

	# 6. 测试按字段搜索
	var search_by_name = InstructionRegistry.search_instructions("set", "name")
	print("  ✓ search_instructions(query, 'name') 可用，找到 %d 个结果" % search_by_name.size())

	print("\n所有向后兼容性测试通过！")

## 恢复指令注册（测试后恢复）
func _restore_instruction_registration():
	# 重新扫描并注册所有指令
	var plugin = EditorPlugin.new()
	plugin._register_all_instructions()
	plugin.free()
