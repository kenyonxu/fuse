extends Node
class_name TestExecutionContextCacheLimit

## 测试ExecutionContext缓存大小限制

var _context: ExecutionContext

func _ready():
	print("=== 测试ExecutionContext缓存限制 ===")
	test_cache_limit_enforcement()
	test_lru_eviction()
	test_cleanup_clears_cache()
	print("=== 所有测试通过 ===")

func test_cache_limit_enforcement():
	print("\n测试1: 缓存大小限制")
	_context = ExecutionContext.new()

	# 添加超过限制的变量名（限制为1000）
	for i in range(1500):
		var var_name = "test_var_%d" % i
		_context._get_cached_name_key(var_name)

	var cache_size = _context._variable_name_cache.size()
	print("  缓存大小: ", cache_size)
	assert(cache_size <= 1000, "缓存大小不应超过限制")
	print("✓ 缓存大小限制测试通过")

func test_lru_eviction():
	print("\n测试2: LRU淘汰策略")
	_context = ExecutionContext.new()

	# 添加1000个变量填满缓存
	var first_key = ""
	for i in range(1000):
		var var_name = "test_var_%d" % i
		if i == 0:
			first_key = var_name
		_context._get_cached_name_key(var_name)

	# 添加更多变量触发清理
	for i in range(1000, 1200):
		var var_name = "test_var_%d" % i
		_context._get_cached_name_key(var_name)

	# 最早的变量应该被淘汰
	var first_still_exists = _context._variable_name_cache.has(first_key)
	print("  最早的键是否仍存在: ", first_still_exists)
	assert(not first_still_exists, "最早的变量应该被LRU淘汰")
	print("✓ LRU淘汰策略测试通过")

func test_cleanup_clears_cache():
	print("\n测试3: cleanup清理缓存")
	_context = ExecutionContext.new()

	# 添加一些缓存
	for i in range(100):
		_context._get_cached_name_key("test_var_%d" % i)

	assert(_context._variable_name_cache.size() > 0, "缓存应该非空")

	# 调用cleanup
	_context.cleanup()

	assert(_context._variable_name_cache.is_empty(), "cleanup后缓存应该为空")
	assert(_context._cache_access_order.is_empty(), "cleanup后访问顺序应该为空")
	print("✓ cleanup清理测试通过")
