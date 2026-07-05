# debug_search.gd
@tool
extends Node

func _ready():
	# 注册所有 Events
	EventRegistry.register_event(OnReady)
	EventRegistry.register_event(OnInputAction)
	EventRegistry.register_event(OnInputKey)

	print("已注册的 Events 数量: %d" % EventRegistry.get_event_count())

	# 测试搜索
	var input_events = EventRegistry.search_events("input")
	print("\n搜索 'input' 的结果:")
	for event_info in input_events:
		var metadata = event_info.metadata
		print("  - %s" % metadata.get_localized_name())

	print("\n搜索的关键词匹配:")
	for event_info in EventRegistry.get_all_events():
		var metadata = event_info.metadata
		var name = metadata.get_localized_name()

		# 手动检查关键词
		var keywords = metadata.get("keywords") if metadata.has_method("get") else []
		var has_input_in_keywords = false
		for kw in keywords:
			if "input" in str(kw).to_lower():
				has_input_in_keywords = true
				break

		print("  - %s: keywords=%s, has_input=%s" % [name, str(keywords), has_input_in_keywords])
