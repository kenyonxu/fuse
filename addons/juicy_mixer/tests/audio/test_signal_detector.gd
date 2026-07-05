extends Node

## 预加载 SignalDetector
const SignalDetector = preload("res://addons/juicy_mixer/editor/utils/signal_detector.gd")

## 测试节点
class TestNode extends Node:
	signal custom_signal_1
	signal custom_signal_2(value: int)
	signal _internal_signal

func test_detect_custom_signals():
	var test_node = TestNode.new()
	add_child(test_node)

	var signals = SignalDetector.detect_custom_signals(test_node)

	assert(signals.size() == 2, "应该检测到 2 个自定义信号")
	assert(signals[0].name == "custom_signal_1", "第一个信号应该是 custom_signal_1")
	assert(signals[1].name == "custom_signal_2", "第二个信号应该是 custom_signal_2")

	print("[PASS] test_detect_custom_signals 通过")
	test_node.queue_free()

func test_group_signals_by_class():
	var test_node = TestNode.new()
	add_child(test_node)
	var signals = SignalDetector.detect_custom_signals(test_node)
	var grouped = SignalDetector.group_signals_by_class(signals)

	# 调试输出
	print("信号数量: ", signals.size())
	if signals.size() > 0:
		print("第一个信号的键: ", signals[0].keys())
		print("第一个信号内容: ", signals[0])

	# 检查分组结果
	assert(grouped.size() > 0, "应该至少有一个分组")
	var class_keys = grouped.keys()
	print("分组键: ", class_keys)

	# 验证信号数量总和
	var total_signals = 0
	for cls in grouped:
		total_signals += grouped[cls].size()
	assert(total_signals == 2, "分组后应该有 2 个信号")

	print("[PASS] test_group_signals_by_class 通过")
	test_node.queue_free()

func test_format_signal_text():
	var test_node = TestNode.new()
	var signals = SignalDetector.detect_custom_signals(test_node)

	# 无参数信号
	var text1 = SignalDetector.format_signal_text(signals[0])
	assert(text1 == "custom_signal_1", "无参数信号格式应该正确")

	# 有参数信号
	var text2 = SignalDetector.format_signal_text(signals[1])
	assert(text2 == "custom_signal_2(value: int)", "有参数信号格式应该正确")

	print("[PASS] test_format_signal_text 通过")
	test_node.queue_free()

func test_apply_search_filter():
	var test_node = TestNode.new()
	add_child(test_node)
	var signals = SignalDetector.detect_custom_signals(test_node)
	var grouped = SignalDetector.group_signals_by_class(signals)

	# 测试无过滤（返回原字典）
	var unfiltered = SignalDetector.apply_search_filter(grouped, "")
	assert(unfiltered.size() == grouped.size(), "空搜索应该返回所有分组")

	# 测试搜索 "signal_1"（应该只匹配 custom_signal_1）
	var filtered = SignalDetector.apply_search_filter(grouped, "signal_1")
	assert(filtered.size() > 0, "搜索应该返回结果")
	# 使用动态键访问
	var first_key = filtered.keys()[0]
	assert(filtered[first_key].size() == 1, "应该只匹配 1 个信号")

	# 测试大小写不敏感
	var filtered_lower = SignalDetector.apply_search_filter(grouped, "SIGNAL_2")
	assert(filtered_lower.size() > 0, "大小写不敏感搜索应该返回结果")
	var test_key = filtered_lower.keys()[0]
	assert(filtered_lower[test_key].size() == 1, "大小写不敏感搜索应该工作")

	# 测试不存在的搜索词
	var empty_result = SignalDetector.apply_search_filter(grouped, "nonexistent")
	assert(empty_result.is_empty(), "不存在的搜索应该返回空字典")

	print("[PASS] test_apply_search_filter 通过")
	test_node.queue_free()

func _ready():
	test_detect_custom_signals()
	test_group_signals_by_class()
	test_format_signal_text()
	test_apply_search_filter()
	print("\n[SUCCESS] 所有 SignalDetector 测试通过！")
	get_tree().quit()
