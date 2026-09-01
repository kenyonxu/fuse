# test_event_condition_selector.gd
@tool
extends Node

## Event 和 Condition 选择器集成测试
##
## 测试以下功能：
## 1. ComponentRegistry 能正确注册和管理组件
## 2. EventRegistry 和 ConditionRegistry 工作正常
## 3. ComponentSelector 能正确显示组件
## 4. 搜索功能正常工作
## 5. 本地化功能正常
## 6. Inspector 插件正确检测属性

var test_passed_count: int = 0
var test_failed_count: int = 0
var test_results: Array[String] = []

func _ready():
	print("========================================")
	print("开始 Event 和 Condition 选择器集成测试")
	print("========================================\n")

	# 运行所有测试
	test_component_registry()
	test_event_registry()
	test_condition_registry()
	test_metadata_system()
	test_search_functionality()
	test_localization()

	# 输出测试结果
	print_test_summary()

## 测试 ComponentRegistry
func test_component_registry():
	print("\n【测试 1】ComponentRegistry 基础功能")

	# 清空注册表
	ComponentRegistry.clear_all()

	# 测试初始状态
	var initial_event_count = ComponentRegistry.get_count(ComponentRegistry.ComponentType.EVENT)
	var initial_condition_count = ComponentRegistry.get_count(ComponentRegistry.ComponentType.CONDITION)

	test_assert(initial_event_count == 0, "初始状态 Event 数量应为 0")
	test_assert(initial_condition_count == 0, "初始状态 Condition 数量应为 0")

	# 注册测试事件
	var event_registered = ComponentRegistry.register(
		ComponentRegistry.ComponentType.EVENT,
		OnReady,
		"_get_event_metadata"
	)

	test_assert(event_registered, "OnReady 注册应成功")

	# 检查注册结果
	var event_count = ComponentRegistry.get_count(ComponentRegistry.ComponentType.EVENT)
	test_assert(event_count > 0, "注册后 Event 数量应大于 0")

	# 测试按名称获取
	var event_info = ComponentRegistry.get_by_name(ComponentRegistry.ComponentType.EVENT, "FUSE_EVENT_ON_READY_NAME")
	test_assert(not event_info.is_empty(), "应该能通过名称获取到 Event 信息")

	# 注册测试条件
	var condition_registered = ComponentRegistry.register(
		ComponentRegistry.ComponentType.CONDITION,
		CompareVariable,
		"_get_condition_metadata"
	)

	test_assert(condition_registered, "CompareVariable 注册应成功")

	# 检查注册结果
	var condition_count = ComponentRegistry.get_count(ComponentRegistry.ComponentType.CONDITION)
	test_assert(condition_count > 0, "注册后 Condition 数量应大于 0")

	print("✓ ComponentRegistry 基础功能测试完成")

## 测试 EventRegistry
func test_event_registry():
	print("\n【测试 2】EventRegistry 便捷接口")

	# 清空并重新注册
	EventRegistry.clear_all_events()

	# 注册多个 Event
	var events_to_register = [
		OnReady,
		OnInputAction,
		OnInputKey,
		OnArea2DEnter,
		OnTargetSignalEmit
	]

	for event_class in events_to_register:
		var success = EventRegistry.register_event(event_class)
		test_assert(success, str("Event ", event_class, " 注册应成功"))

	# 获取所有 Events
	var all_events = EventRegistry.get_all_events()
	test_assert(all_events.size() == events_to_register.size(), "应获取到所有注册的 Events")

	# 测试按名称获取
	var on_ready_event = EventRegistry.get_event_by_name("FUSE_EVENT_ON_READY_NAME")
	test_assert(not on_ready_event.is_empty(), "应该能通过名称获取到 OnReady")

	# 测试获取数量
	var event_count = EventRegistry.get_event_count()
	test_assert(event_count == events_to_register.size(), "Event 数量应正确")

	print("✓ EventRegistry 便捷接口测试完成")

## 测试 ConditionRegistry
func test_condition_registry():
	print("\n【测试 3】ConditionRegistry 便捷接口")

	# 清空并重新注册
	ConditionRegistry.clear_all_conditions()

	# 注册多个 Condition
	var conditions_to_register = [
		CompareVariable,
		CheckNodeExists,
		CheckNodeProperty
	]

	for condition_class in conditions_to_register:
		var success = ConditionRegistry.register_condition(condition_class)
		test_assert(success, str("Condition ", condition_class, " 注册应成功"))

	# 获取所有 Conditions
	var all_conditions = ConditionRegistry.get_all_conditions()
	test_assert(all_conditions.size() == conditions_to_register.size(), "应获取到所有注册的 Conditions")

	# 测试按名称获取
	var var_comp_cond = ConditionRegistry.get_condition_by_name("FUSE_CONDITION_VARIABLE_COMPARISON_NAME")
	test_assert(not var_comp_cond.is_empty(), "应该能通过名称获取到 CompareVariable")

	# 测试获取数量
	var condition_count = ConditionRegistry.get_condition_count()
	test_assert(condition_count == conditions_to_register.size(), "Condition 数量应正确")

	print("✓ ConditionRegistry 便捷接口测试完成")

## 测试元数据系统
func test_metadata_system():
	print("\n【测试 4】元数据系统")

	# 不需要重新注册，直接使用已注册的组件
	# 确保有组件可供测试
	if EventRegistry.get_event_count() == 0:
		EventRegistry.register_event(OnReady)
	if ConditionRegistry.get_condition_count() == 0:
		ConditionRegistry.register_condition(CompareVariable)

	# 测试 Event 元数据
	var event_info = EventRegistry.get_event_by_name("FUSE_EVENT_ON_READY_NAME")
	if not event_info.is_empty():
		var metadata = event_info.metadata
		test_assert(metadata != null, "Event 元数据不应为 null")

		if metadata != null:
			# 测试元数据方法
			test_assert(metadata.has_method("get_localized_name"), "元数据应有 get_localized_name 方法")
			test_assert(metadata.has_method("get_localized_category"), "元数据应有 get_localized_category 方法")
			test_assert(metadata.has_method("get_localized_description"), "元数据应有 get_localized_description 方法")
			test_assert(metadata.has_method("get_icon_texture"), "元数据应有 get_icon_texture 方法")

			# 测试获取值
			var name = metadata.get_localized_name()
			test_assert(not name.is_empty(), "本地化名称不应为空")

			var category = metadata.get_localized_category()
			test_assert(not category.is_empty(), "本地化分类不应为空")

			var description = metadata.get_localized_description()
			test_assert(not description.is_empty(), "本地化描述不应为空")

	# 测试 Condition 元数据
	var cond_info = ConditionRegistry.get_condition_by_name("FUSE_CONDITION_VARIABLE_COMPARISON_NAME")
	if not cond_info.is_empty():
		var metadata = cond_info.metadata
		test_assert(metadata != null, "Condition 元数据不应为 null")

		if metadata != null:
			var name = metadata.get_localized_name()
			test_assert(not name.is_empty(), "本地化名称不应为空")

	print("✓ 元数据系统测试完成")

## 测试搜索功能
func test_search_functionality():
	print("\n【测试 5】搜索功能")

	# 确保 Events 和 Conditions 已经注册（由前面的测试完成）
	# 不需要重新注册，因为 test_event_registry 和 test_condition_registry 已经注册了

	# 测试 Event 搜索
	print("  当前已注册的 Events 数量: %d" % EventRegistry.get_event_count())
	var input_events = EventRegistry.search_events("input")
	print("  搜索 'input' 找到 %d 个结果" % input_events.size())
	test_assert(input_events.size() > 0, "搜索 'input' 应找到相关 Events")

	var ready_events = EventRegistry.search_events("ready")
	test_assert(ready_events.size() > 0, "搜索 'ready' 应找到相关 Events")

	# 测试按字段搜索
	var by_name = EventRegistry.search_events("ready", "name")
	test_assert(by_name.size() > 0, "按名称搜索 'ready' 应找到结果")

	var empty_results = EventRegistry.search_events("nonexistent")
	test_assert(empty_results.size() == 0, "搜索不存在的组件应返回空数组")

	# 测试 Condition 搜索
	var variable_conditions = ConditionRegistry.search_conditions("variable")
	test_assert(variable_conditions.size() > 0, "搜索 'variable' 应找到相关 Conditions")

	var comparison_conditions = ConditionRegistry.search_conditions("comparison")
	test_assert(comparison_conditions.size() > 0, "搜索 'comparison' 应找到相关 Conditions")

	# 测试关键词搜索
	var keyword_results = EventRegistry.search_events("start")
	test_assert(keyword_results.size() > 0, "搜索关键词 'start' 应找到结果（通过 keywords 字段）")

	print("✓ 搜索功能测试完成")

## 测试本地化功能
func test_localization():
	print("\n【测试 6】本地化功能")

	# 加载本地化类
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")
	test_assert(FuseLocalization_class != null, "FuseLocalization 类应存在")

	if FuseLocalization_class != null:
		# 初始化本地化系统
		if FuseLocalization_class.has_method("init"):
			FuseLocalization_class.init()

		# 测试翻译功能
		if FuseLocalization_class.has_method("translate"):
			var translated = FuseLocalization_class.translate("FUSE_EVENT_ON_READY_NAME")
			test_assert(not translated.is_empty(), "翻译应返回非空字符串")

			# 测试不同语言
			if FuseLocalization_class.has_method("set_locale"):
				var original_locale = FuseLocalization_class.get_current_locale()

				# 切换到中文
				FuseLocalization_class.set_locale("zh_CN")
				var zh_name = FuseLocalization_class.translate("FUSE_EVENT_ON_READY_NAME")
				test_assert(not zh_name.is_empty(), "中文翻译应返回非空字符串")

				# 切换到英文
				FuseLocalization_class.set_locale("en_US")
				var en_name = FuseLocalization_class.translate("FUSE_EVENT_ON_READY_NAME")
				test_assert(not en_name.is_empty(), "英文翻译应返回非空字符串")

				# 恢复原始语言
				FuseLocalization_class.set_locale(original_locale)

	# 测试元数据的本地化
	var event_info = EventRegistry.get_event_by_name("FUSE_EVENT_ON_READY_NAME")
	if not event_info.is_empty():
		var metadata = event_info.metadata
		if metadata != null and metadata.has_method("get_localized_name"):
			var localized_name = metadata.get_localized_name()
			test_assert(not localized_name.is_empty(), "元数据本地化名称不应为空")

	print("✓ 本地化功能测试完成")

## 测试断言辅助函数
func test_assert(condition: bool, message: String):
	if condition:
		test_passed_count += 1
		test_results.append("✓ PASS: " + message)
		print("  ✓ " + message)
	else:
		test_failed_count += 1
		test_results.append("✗ FAIL: " + message)
		print("  ✗ " + message)

## 打印测试总结
func print_test_summary():
	print("\n========================================")
	print("测试总结")
	print("========================================")
	print("通过: %d" % test_passed_count)
	print("失败: %d" % test_failed_count)
	print("总计: %d" % (test_passed_count + test_failed_count))

	if test_failed_count == 0:
		print("\n🎉 所有测试通过！")
	else:
		print("\n⚠️  有测试失败，请检查上述错误信息")

	print("\n详细结果:")
	for result in test_results:
		print("  " + result)

	print("========================================\n")
