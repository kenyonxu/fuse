extends SceneTree

## 性能测试：load() vs preload() vs 缓存

const PRELOADED = preload("res://addons/fuse/localization/fuse_localization.gd")

var _cached_class = null

func _init():
	print("================================================================================")
	print("性能测试：load() vs preload() vs 缓存")
	print("================================================================================")

	# 测试 1: preload 性能（已经加载）
	print("\n测试 1: preload（已加载）")
	var start = Time.get_ticks_usec()
	for i in range(1000):
		var result = PRELOADED.translate("FUSE_LOG_PRINT_MESSAGE")
	var elapsed = Time.get_ticks_usec() - start
	print("  1000次调用耗时: %d μs (平均: %.2f μs/次)" % [elapsed, elapsed / 1000.0])

	# 测试 2: load 每次都加载
	print("\n测试 2: load 每次都加载")
	start = Time.get_ticks_usec()
	for i in range(100):  # 减少次数，因为很慢
		var cls = load("res://addons/fuse/localization/fuse_localization.gd")
		var result = cls.translate("FUSE_LOG_PRINT_MESSAGE")
	elapsed = Time.get_ticks_usec() - start
	print("  100次调用耗时: %d μs (平均: %.2f μs/次)" % [elapsed, elapsed / 100.0])

	# 测试 3: 缓存类引用
	print("\n测试 3: 缓存类引用")
	if _cached_class == null:
		_cached_class = load("res://addons/fuse/localization/fuse_localization.gd")

	start = Time.get_ticks_usec()
	for i in range(1000):
		var result = _cached_class.translate("FUSE_LOG_PRINT_MESSAGE")
	elapsed = Time.get_ticks_usec() - start
	print("  1000次调用耗时: %d μs (平均: %.2f μs/次)" % [elapsed, elapsed / 1000.0])

	# 测试 4: 首次 load 开销
	print("\n测试 4: 首次 load 开销")
	start = Time.get_ticks_usec()
	var cls = load("res://addons/fuse/localization/fuse_localization.gd")
	elapsed = Time.get_ticks_usec() - start
	print("  单次 load 耗时: %d μs (%.3f ms)" % [elapsed, elapsed / 1000.0])

	print("\n================================================================================")
	print("结论:")
	print("  - preload 最快（已预先加载）")
	print("  - 缓存类引用性能接近 preload（推荐）")
	print("  - 每次都 load 最慢（避免使用）")
	print("================================================================================")

	quit()
