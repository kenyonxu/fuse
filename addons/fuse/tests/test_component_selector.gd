@tool
extends EditorScript

## 测试 ComponentSelector 基本功能
##
## 使用方法：
## 1. 在 Godot 编辑器中，选择 "项目 > 工具 > 运行编辑器脚本"
## 2. 选择此脚本运行

func _run():
	print("=== 测试 ComponentSelector ===")

	# 测试 1: 检查 ComponentSelector 类是否可以加载
	print("\n[测试 1] 加载 ComponentSelector 类...")
	var ComponentSelector_class = load("res://addons/fuse/editor/component_selector/component_selector.gd")
	if ComponentSelector_class:
		print("✓ ComponentSelector 类加载成功")
	else:
		print("✗ ComponentSelector 类加载失败")
		return

	# 测试 2: 检查 ComponentRegistry 是否正常工作
	print("\n[测试 2] 测试 ComponentRegistry...")
	var event_count = EventRegistry.get_event_count()
	print("  已注册事件数量: %d" % event_count)

	var condition_count = ConditionRegistry.get_condition_count()
	print("  已注册条件数量: %d" % condition_count)

	var instruction_count = InstructionRegistry.get_instruction_count()
	print("  已注册指令数量: %d" % instruction_count)

	# 测试 3: 测试搜索功能
	print("\n[测试 3] 测试 Event 搜索功能...")
	var search_results = EventRegistry.search_events("input")
	print("  搜索 'input' 找到 %d 个事件" % search_results.size())

	for result in search_results:
		if result.has("metadata"):
			var metadata = result.metadata
			if metadata and metadata.has_method("get_localized_name"):
				print("    - %s" % metadata.get_localized_name())

	# 测试 4: 测试 Condition 搜索功能
	print("\n[测试 4] 测试 Condition 搜索功能...")
	search_results = ConditionRegistry.search_conditions("")
	print("  搜索所有条件找到 %d 个" % search_results.size())

	# 测试 5: 检查本地化
	print("\n[测试 5] 检查本地化系统...")
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")
	if FuseLocalization_class and FuseLocalization_class.has_method("init"):
		FuseLocalization_class.init()

		if FuseLocalization_class.has_method("translate"):
			var title = FuseLocalization_class.translate("FUSE_UI_EVENT_SELECTOR_TITLE")
			print("  本地化测试: %s" % title)
			print("  ✓ 本地化系统正常")
		else:
			print("  ✗ translate 方法不存在")
	else:
		print("  ✗ FuseLocalization 类加载失败")

	# 测试 6: 创建测试 Resource
	print("\n[测试 6] 创建测试 Resource...")
	var test_resource = ComponentSelectorTestResource.new()
	print("  创建测试 Resource 成功")
	print("  事件属性类型: %s" % str(test_resource.event))
	print("  条件属性类型: %s" % str(test_resource.condition))

	print("\n=== 测试完成 ===")

# 定义一个测试 Resource 类型（内部类）
class ComponentSelectorTestResource extends Resource:
	@export var event: BaseEvent = null
	@export var condition: BaseCondition = null
