# 测试中间件自动扫描功能
extends Node

func _ready():
	print("=== 测试中间件自动扫描功能 ===")
	
	# 清除缓存重新扫描
	MiddlewareEntry.clear_scan_cache()
	
	# 创建一个中间件条目来触发扫描
	var entry = MiddlewareEntry.new()
	
	# 手动触发扫描
	print("手动触发扫描...")
	MiddlewareEntry.rescan_middlewares()
	
	# 检查扫描结果
	var stats = entry.get_config_stats()
	print("扫描结果统计: ", stats)
	
	print("=== 测试完成 ===")