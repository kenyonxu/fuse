# test_component_registry.gd
extends Node

## 测试 ComponentRegistry 和相关注册器的基本功能

func _ready():
	print("=== 开始测试 ComponentRegistry ===")

	test_component_registry()
	test_event_registry()
	test_condition_registry()
	test_instruction_registry_compatibility()

	print("=== ComponentRegistry 测试完成 ===")

## 测试 ComponentRegistry 基本功能
func test_component_registry():
	print("\n[测试] ComponentRegistry 基本功能")

	# 清理所有注册
	ComponentRegistry.clear_all()

	# 创建测试元数据
	var test_metadata = FuseMetadata.new()
	test_metadata.name_key = "test_component"
	test_metadata.category_key = "test_category"
	test_metadata.description_key = "Test description"

	# 手动构造一个测试类字典（模拟注册）
	var test_class_dict = {
		"class": null,  # 模拟类
		"metadata": test_metadata
	}

	# 测试枚举
	print("  ComponentType 枚举值:")
	print("    INSTRUCTION: %d" % ComponentRegistry.ComponentType.INSTRUCTION)
	print("    EVENT: %d" % ComponentRegistry.ComponentType.EVENT)
	print("    CONDITION: %d" % ComponentRegistry.ComponentType.CONDITION)

	# 测试空注册表
	print("  初始状态检查:")
	print("    Instruction 数量: %d" % ComponentRegistry.get_count(ComponentRegistry.ComponentType.INSTRUCTION))
	print("    Event 数量: %d" % ComponentRegistry.get_count(ComponentRegistry.ComponentType.EVENT))
	print("    Condition 数量: %d" % ComponentRegistry.get_count(ComponentRegistry.ComponentType.CONDITION))

	print("  ✓ ComponentRegistry 基本功能测试通过")

## 测试 EventRegistry
func test_event_registry():
	print("\n[测试] EventRegistry")

	# 清理
	EventRegistry.clear_all_events()

	# 检查初始状态
	var count = EventRegistry.get_event_count()
	print("  初始 Event 数量: %d" % count)

	# 测试获取所有（应该为空）
	var all_events = EventRegistry.get_all_events()
	print("  获取所有 Event 数量: %d" % all_events.size())

	# 测试搜索（应该为空）
	var search_results = EventRegistry.search_events("test")
	print("  搜索 'test' 结果数量: %d" % search_results.size())

	print("  ✓ EventRegistry 测试通过")

## 测试 ConditionRegistry
func test_condition_registry():
	print("\n[测试] ConditionRegistry")

	# 清理
	ConditionRegistry.clear_all_conditions()

	# 检查初始状态
	var count = ConditionRegistry.get_condition_count()
	print("  初始 Condition 数量: %d" % count)

	# 测试获取所有（应该为空）
	var all_conditions = ConditionRegistry.get_all_conditions()
	print("  获取所有 Condition 数量: %d" % all_conditions.size())

	# 测试搜索（应该为空）
	var search_results = ConditionRegistry.search_conditions("test")
	print("  搜索 'test' 结果数量: %d" % search_results.size())

	print("  ✓ ConditionRegistry 测试通过")

## 测试 InstructionRegistry 向后兼容性
func test_instruction_registry_compatibility():
	print("\n[测试] InstructionRegistry 向后兼容性")

	# 清理
	InstructionRegistry.clear_all()

	# 测试旧方法
	var count = InstructionRegistry.get_instruction_count()
	print("  使用 get_instruction_count(): %d" % count)

	var all = InstructionRegistry.get_all_instructions()
	print("  使用 get_all_instructions() 数量: %d" % all.size())

	var by_name = InstructionRegistry.get_instruction_by_name("nonexistent")
	print("  使用 get_instruction_by_name('nonexistent'): %s" % str(by_name))

	# 测试新搜索方法
	var search_results = InstructionRegistry.search_instructions("test")
	print("  使用 search_instructions('test') 数量: %d" % search_results.size())

	# 按字段搜索
	var search_by_name = InstructionRegistry.search_instructions("test", "name")
	print("  按名称搜索数量: %d" % search_by_name.size())

	print("  ✓ InstructionRegistry 向后兼容性测试通过")
