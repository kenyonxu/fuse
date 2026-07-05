extends SceneTree

## Fuse 本地化性能基准测试
##
## 测试项目：
## 1. CSV加载性能
## 2. CSV解析性能
## 3. 翻译查询性能（单次）
## 4. 翻译查询性能（批量）
## 5. 参数化翻译性能

const ITERATIONS := 10000  ## 测试迭代次数
var FuseLocalization: RefCounted

func _init():
	# 加载FuseLocalization类
	FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
	FuseLocalization.init()

	print("=== Fuse 本地化性能基准测试 ===")
	print("")

	# 1. 测试CSV加载性能
	_benchmark_csv_loading()

	# 2. 测试CSV解析性能
	_benchmark_csv_parsing()

	# 3. 测试翻译查询性能（单次）
	_benchmark_single_translation()

	# 4. 测试翻译查询性能（批量）
	_benchmark_bulk_translation()

	# 5. 测试参数化翻译性能
	_benchmark_parameterized_translation()

	print("")
	print("=== 基准测试完成 ===")
	quit()

## 测试CSV加载性能
func _benchmark_csv_loading() -> void:
	print("📊 测试1: CSV文件加载")

	var start := Time.get_ticks_usec()
	var file := FileAccess.open("res://addons/fuse/localization/translations.csv", FileAccess.READ)
	var content := file.get_as_text()
	file.close()
	var elapsed := Time.get_ticks_usec() - start

	print("  文件大小: %d bytes" % content.length())
	print("  加载时间: %d μs (%.3f ms)" % [elapsed, elapsed / 1000.0])
	print("  性能: %.2f MB/s" % [content.length() / (elapsed / 1000000.0) / (1024 * 1024)])

## 测试CSV解析性能
func _benchmark_csv_parsing() -> void:
	print("")
	print("📊 测试2: CSV解析")

	var file := FileAccess.open("res://addons/fuse/localization/translations.csv", FileAccess.READ)
	var content := file.get_as_text()
	file.close()

	var start := Time.get_ticks_usec()
	var lines := content.split("\n")
	var translations := {}
	for line in lines:
		if line.is_empty():
			continue
		var parts := line.split(",")
		if parts.size() >= 2:
			var key := parts[0].strip_edges()
			if not key.is_empty():
				translations[key] = parts.slice(1)
	var elapsed := Time.get_ticks_usec() - start

	print("  解析键数: %d" % translations.size())
	print("  解析时间: %d μs (%.3f ms)" % [elapsed, elapsed / 1000.0])
	print("  平均: %.2f μs/键" % [elapsed / float(translations.size())])

## 测试单次翻译查询性能
func _benchmark_single_translation() -> void:
	print("")
	print("📊 测试3: 单次翻译查询")

	var start := Time.get_ticks_usec()
	for i in range(ITERATIONS):
		var _result: String = FuseLocalization.translate("FUSE_INSTRUCTION_PRINT_NAME")
	var elapsed := Time.get_ticks_usec() - start

	print("  迭代次数: %d" % ITERATIONS)
	print("  总时间: %d μs (%.3f ms)" % [elapsed, elapsed / 1000.0])
	print("  平均: %.2f μs/次" % [elapsed / float(ITERATIONS)])

	var avg_us := elapsed / float(ITERATIONS)
	if avg_us < 1.0:
		print("  ✓ 性能优秀（<1.0 μs/次）")
	else:
		print("  ⚠ 性能需优化（≥1.0 μs/次）")

## 测试批量翻译查询性能
func _benchmark_bulk_translation() -> void:
	print("")
	print("📊 测试4: 批量翻译查询")

	# 获取所有翻译键
	var all_keys: Array = FuseLocalization._translations.keys()
	var key_count: int = min(100, all_keys.size())  # 限制100个键

	var start := Time.get_ticks_usec()
	for i in range(ITERATIONS):
		for j in range(key_count):
			var _result: String = FuseLocalization.translate(all_keys[j])
	var elapsed := Time.get_ticks_usec() - start

	var total_queries: int = ITERATIONS * key_count
	print("  查询次数: %d" % total_queries)
	print("  总时间: %d μs (%.3f ms)" % [elapsed, elapsed / 1000.0])
	print("  平均: %.2f μs/次" % [elapsed / float(total_queries)])

## 测试参数化翻译性能
func _benchmark_parameterized_translation() -> void:
	print("")
	print("📊 测试5: 参数化翻译查询")

	var args: Dictionary = {"name": "TestInstruction", "value": 42}

	var start := Time.get_ticks_usec()
	for i in range(ITERATIONS):
		var _result: String = FuseLocalization.translate_format("FUSE_ERROR_VAR_NOT_FOUND", args)
	var elapsed := Time.get_ticks_usec() - start

	print("  迭代次数: %d" % ITERATIONS)
	print("  总时间: %d μs (%.3f ms)" % [elapsed, elapsed / 1000.0])
	print("  平均: %.2f μs/次" % [elapsed / float(ITERATIONS)])
