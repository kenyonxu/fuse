# 简单的编辑器测试
@tool
extends EditorScript

func _run():
	print("=== 简单编辑器测试 ===")
	
	# 清除缓存重新扫描
	MiddlewareEntry.clear_scan_cache()
	
	# 创建一个中间件条目
	var entry = MiddlewareEntry.new()
	
	# 调试可用中间件
	entry.debug_print_available_middlewares()
	
	# 测试属性列表生成
	var properties = entry._get_property_list()
	print("生成的属性数量: ", properties.size())
	
	for i in range(properties.size()):
		var prop = properties[i]
		print("属性 ", i, ": ", prop.name, " (", prop.type, ")")
		if prop.has("hint_string") and not prop.hint_string.is_empty():
			print("  提示字符串: ", prop.hint_string)
	
	print("=== 测试完成 ===")