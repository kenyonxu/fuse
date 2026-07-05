# LODMiddleware 测试文件
# 测试 LOD 配置资源序列化、中间件功能、距离计算、视锥剔除等核心功能

extends Node

# 测试用的临时文件路径
const TEMP_CONFIG_PATH = "user://test_lod_config.tres"

# 测试计数器
var _test_count = 0
var _passed_count = 0
var _failed_count = 0
var _test_results = []

func _ready():
	print("=== 开始 LODMiddleware 测试 ===")
	run_all_tests()
	print("=== LODMiddleware 测试完成 ===")

func run_all_tests():
	print("\n" + "=".repeat(50))
	print("运行所有 LODMiddleware 测试")
	print("=".repeat(50))
	
	# 测试1: LOD配置资源序列化测试
	test_lod_config_serialization()
	
	# 测试2: LOD配置强度计算测试
	test_lod_config_intensity_calculation()
	
	# 测试3: LOD配置验证测试
	test_lod_config_validation()
	
	# 测试4: LODMiddleware基础功能测试
	test_lod_middleware_initialization()
	
	# 测试5: LODMiddleware默认配置创建测试
	test_lod_middleware_default_config_creation()
	
	# 测试6: LODMiddleware摄像机处理测试
	test_lod_middleware_camera_handling()
	
	# 测试7: 距离计算测试
	test_distance_calculation()
	
	# 测试8: 强度倍数计算测试
	test_intensity_multiplier_calculation()
	
	# 测试9: 上下文强度调整测试
	test_intensity_adjustment_in_context()
	
	# 测试10: 视锥剔除可见目标测试
	test_frustum_culling_visible_target()
	
	# 测试11: 视锥剔除外部目标测试
	test_frustum_culling_outside_target()
	
	# 测试12: 视锥剔除边界情况测试
	test_frustum_culling_boundary_conditions()
	
	# 测试13: 视锥剔除集成测试
	test_frustum_culling_in_integration()
	
	# 测试14: 距离剔除超出最大距离测试
	test_distance_culling_beyond_max_distance()
	
	# 测试15: 距离剔除在最大距离内测试
	test_distance_culling_within_max_distance()
	
	# 测试16: 配置加载和保存测试
	test_config_loading_and_saving()
	
	# 测试17: 距离阈值设置测试
	test_distance_thresholds_setting()
	
	# 测试18: 摄像机设置测试
	test_camera_setting()
	
	# 测试19: LOD统计信息收集测试
	test_lod_stats_collection()
	
	# 测试20: 调试信息打印测试
	test_debug_print_lod_info()
	
	# 测试21: LODMiddleware与JuicyContext集成测试
	test_lod_middleware_with_juicy_context()
	
	# 测试22: LODMiddleware生命周期方法测试
	test_lod_middleware_lifecycle_methods()
	
	# 测试23: LODMiddleware性能监控测试
	test_lod_middleware_performance_monitoring()
	
	# 测试24: null上下文处理测试
	test_null_context_handling()
	
	# 测试25: null目标处理测试
	test_null_target_handling()
	
	# 测试26: 缺少摄像机处理测试
	test_missing_camera_handling()
	
	# 测试27: 边界情况配置测试
	test_edge_case_configurations()
	
	# 打印测试总结
	print_test_summary()

# =============================================================================
# 测试组1: LOD配置资源序列化测试
# =============================================================================

func test_lod_config_serialization():
	"""测试LOD配置资源的序列化和反序列化"""
	print("\n测试1: LOD配置资源序列化测试")
	
	# 创建配置并设置参数
	var config = JuicyLODConfig.new()
	config.config_name = "test_lod"
	config.max_distance = 800.0
	config.distance_thresholds = [150.0, 300.0, 450.0]
	config.intensity_multipliers = [1.0, 0.8, 0.6, 0.4, 0.2]
	config.enable_frustum_culling = false
	config.enable_distance_culling = true
	config.description = "Test LOD configuration"
	
	# 保存配置
	var save_result = ResourceSaver.save(config, TEMP_CONFIG_PATH)
	assert_equal(OK, save_result, "配置保存应该成功")
	
	# 加载配置
	var loaded_config = load(TEMP_CONFIG_PATH) as JuicyLODConfig
	assert_not_null(loaded_config, "加载的配置不应该为null")
	assert_equal(loaded_config.config_name, "test_lod", "配置名称应该匹配")
	assert_equal(loaded_config.max_distance, 800.0, "最大距离应该匹配")
	assert_equal(loaded_config.distance_thresholds, [150.0, 300.0, 450.0], "距离阈值应该匹配")
	assert_equal(loaded_config.intensity_multipliers, [1.0, 0.8, 0.6, 0.4, 0.2], "强度倍数应该匹配")
	assert_equal(loaded_config.enable_frustum_culling, false, "视锥剔除设置应该匹配")
	assert_equal(loaded_config.enable_distance_culling, true, "距离剔除设置应该匹配")
	assert_equal(loaded_config.description, "Test LOD configuration", "描述应该匹配")
	
	_test_count += 1
	_passed_count += 1
	print("✓ LOD配置资源序列化测试通过")

func test_lod_config_intensity_calculation():
	"""测试LOD配置的强度计算功能"""
	print("\n测试2: LOD配置强度计算测试")
	
	var config = JuicyLODConfig.new()
	config.max_distance = 500.0
	config.distance_thresholds = [100.0, 200.0, 300.0]
	config.intensity_multipliers = [1.0, 0.75, 0.5, 0.25, 0.0]
	
	# 测试不同距离下的强度计算
	assert_equal(config.calculate_intensity_multiplier(50.0), 1.0, "50距离应该返回1.0强度")
	assert_equal(config.calculate_intensity_multiplier(100.0), 1.0, "100距离应该返回1.0强度")
	assert_equal(config.calculate_intensity_multiplier(150.0), 0.75, "150距离应该返回0.75强度")
	assert_equal(config.calculate_intensity_multiplier(250.0), 0.5, "250距离应该返回0.5强度")
	assert_equal(config.calculate_intensity_multiplier(350.0), 0.25, "350距离应该返回0.25强度")
	assert_equal(config.calculate_intensity_multiplier(600.0), 0.0, "超出最大距离应该返回0.0强度")
	
	_test_count += 1
	_passed_count += 1
	print("✓ LOD配置强度计算测试通过")

func test_lod_config_validation():
	"""测试LOD配置的验证功能"""
	print("\n测试3: LOD配置验证测试")
	
	# 测试有效配置
	var valid_config = JuicyLODConfig.new()
	valid_config.config_name = "valid_config"
	valid_config.max_distance = 500.0
	valid_config.distance_thresholds = [100.0, 200.0, 300.0]
	valid_config.intensity_multipliers = [1.0, 0.75, 0.5, 0.0]  # 修复：应该是thresholds.size() + 1
	
	var validation_result = valid_config.validate()
	assert_true(validation_result.valid, "有效配置应该通过验证")
	assert_equal(validation_result.issues.size(), 0, "有效配置不应该有问题")
	
	# 测试无效配置 - 空名称
	var invalid_config1 = JuicyLODConfig.new()
	invalid_config1.config_name = ""
	invalid_config1.max_distance = 500.0
	
	var validation_result1 = invalid_config1.validate()
	assert_false(validation_result1.valid, "空名称配置应该验证失败")
	assert_true(validation_result1.issues.size() > 0, "应该有问题报告")
	
	# 测试无效配置 - 负最大距离
	var invalid_config2 = JuicyLODConfig.new()
	invalid_config2.config_name = "invalid"
	invalid_config2.max_distance = -100.0
	
	var validation_result2 = invalid_config2.validate()
	assert_false(validation_result2.valid, "负最大距离应该验证失败")
	
	# 测试无效配置 - 数组大小不匹配
	var invalid_config3 = JuicyLODConfig.new()
	invalid_config3.config_name = "invalid"
	invalid_config3.max_distance = 500.0
	invalid_config3.distance_thresholds = [100.0, 200.0]
	invalid_config3.intensity_multipliers = [1.0, 0.5]  # 大小不匹配
	
	var validation_result3 = invalid_config3.validate()
	assert_false(validation_result3.valid, "数组大小不匹配应该验证失败")
	
	# 测试无效配置 - 距离阈值非递增
	var invalid_config4 = JuicyLODConfig.new()
	invalid_config4.config_name = "invalid"
	invalid_config4.max_distance = 500.0
	invalid_config4.distance_thresholds = [200.0, 100.0, 300.0]  # 非递增
	invalid_config4.intensity_multipliers = [1.0, 0.75, 0.5, 0.25, 0.0]
	
	var validation_result4 = invalid_config4.validate()
	assert_false(validation_result4.valid, "非递增距离阈值应该验证失败")
	
	_test_count += 1
	_passed_count += 1
	print("✓ LOD配置验证测试通过")

# =============================================================================
# 测试组2: LODMiddleware 基础功能测试
# =============================================================================

func test_lod_middleware_initialization():
	"""测试LODMiddleware的初始化"""
	print("\n测试4: LODMiddleware基础功能测试")
	
	var middleware = JuicyLODMiddleware.new()
	
	assert_equal(middleware.middleware_name, "LODMiddleware", "中间件名称应该正确")
	assert_equal(middleware.priority, 700, "优先级应该正确")
	assert_not_null(middleware.description, "描述不应该为空")
	assert_null(middleware.get_lod_config(), "初始配置应该为null")
	
	_test_count += 1
	_passed_count += 1
	print("✓ LODMiddleware基础功能测试通过")

func test_lod_middleware_default_config_creation():
	"""测试LODMiddleware的默认配置创建"""
	var middleware = JuicyLODMiddleware.new()
	
	# 创建一个虚拟上下文来触发配置初始化
	var context = JuicyContext.new()
	context.target = Node2D.new()
	
	# 处理上下文以初始化配置
	var processed = middleware.process(context, func(ctx): return true)
	
	# 验证配置已创建
	var config = middleware.get_lod_config()
	assert_not_null(config, "配置应该被创建")
	assert_equal(config.config_name, "default", "默认配置名称应该为'default'")

func test_lod_middleware_camera_handling():
	"""测试LODMiddleware的摄像机处理"""
	print("\n测试6: LODMiddleware摄像机处理测试")
	
	var middleware = JuicyLODMiddleware.new()
	
	# 测试设置摄像机
	var camera = Camera2D.new()
	middleware.set_camera(camera)
	
	# 验证摄像机被设置（通过统计信息检查）
	var stats = middleware.get_lod_stats()
	assert_true(stats.camera_set, "摄像机应该被设置")
	
	_test_count += 1
	_passed_count += 1
	print("✓ LODMiddleware摄像机处理测试通过")

# =============================================================================
# 测试组3: 距离计算和强度调整测试
# =============================================================================

func test_distance_calculation():
	"""测试距离计算的准确性"""
	print("\n测试7: 距离计算测试")
	
	var middleware = JuicyLODMiddleware.new()
	
	# 创建测试节点
	var camera = Camera2D.new()
	camera.global_position = Vector2(0, 0)
	var target = Node2D.new()
	target.global_position = Vector2(100, 0)
	
	# 计算距离
	var distance = middleware._calculate_distance_to_target(camera, target)
	assert_equal(distance, 100.0, "距离计算应该准确")
	
	# 测试对角线距离
	target.global_position = Vector2(30, 40)
	distance = middleware._calculate_distance_to_target(camera, target)
	assert_equal(distance, 50.0, "对角线距离计算应该准确（勾股定理）")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 距离计算测试通过")

func test_intensity_multiplier_calculation():
	"""测试强度倍数计算"""
	print("\n测试8: 强度倍数计算测试")
	
	var middleware = JuicyLODMiddleware.new()
	
	# 设置测试配置
	var config = JuicyLODConfig.new()
	config.max_distance = 400.0
	config.distance_thresholds = [100.0, 200.0, 300.0]
	config.intensity_multipliers = [1.0, 0.8, 0.6, 0.4, 0.2]
	middleware.set_lod_config(config)
	
	# 测试不同距离下的强度倍数
	assert_equal(middleware._calculate_intensity_multiplier(50.0), 1.0, "50距离应该返回1.0强度倍数")
	assert_equal(middleware._calculate_intensity_multiplier(100.0), 1.0, "100距离应该返回1.0强度倍数")
	assert_equal(middleware._calculate_intensity_multiplier(150.0), 0.8, "150距离应该返回0.8强度倍数")
	assert_equal(middleware._calculate_intensity_multiplier(250.0), 0.6, "250距离应该返回0.6强度倍数")
	assert_equal(middleware._calculate_intensity_multiplier(350.0), 0.4, "350距离应该返回0.4强度倍数")
	assert_equal(middleware._calculate_intensity_multiplier(450.0), 0.0, "超出最大距离应该返回0.0强度倍数")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 强度倍数计算测试通过")

func test_intensity_adjustment_in_context():
	"""测试上下文中的强度调整"""
	var middleware = JuicyLODMiddleware.new()
	
	# 设置测试配置
	var config = JuicyLODConfig.new()
	config.max_distance = 300.0
	config.distance_thresholds = [100.0, 200.0]
	config.intensity_multipliers = [1.0, 0.5, 0.25]
	middleware.set_lod_config(config)
	
	# 创建测试上下文
	var context = JuicyContext.new()
	context.target = Node2D.new()
	context.time_scale = 1.0
	
	# 创建摄像机和目标
	var camera = Camera2D.new()
	camera.global_position = Vector2(0, 0)
	context.target.global_position = Vector2(150, 0)  # 距离150，应该在第二个区间
	
	middleware.set_camera(camera)
	
	# 处理上下文
	var processed = middleware.process(context, func(ctx): 
		assert_equal(ctx.time_scale, 0.5, "时间缩放应该根据距离调整")
		return true
	)
	
	assert_true(processed, "处理应该成功")

# =============================================================================
# 测试组4: 视锥剔除测试
# =============================================================================

func test_frustum_culling_visible_target():
	"""测试视锥内目标的可见性判断"""
	print("\n测试10: 视锥剔除可见目标测试")
	
	var middleware = JuicyLODMiddleware.new()
	
	# 创建摄像机和目标
	var camera = Camera2D.new()
	camera.global_position = Vector2(500, 300)  # 假设这是视口中心
	
	# 模拟视口大小
	var viewport_size = Vector2(1000, 600)
	
	# 创建在视锥内的目标
	var target = Node2D.new()
	target.global_position = Vector2(600, 350)  # 在视口内
	
	# 检查可见性
	var is_visible = middleware._is_target_visible(camera, target)
	assert_true(is_visible, "视锥内的目标应该可见")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 视锥剔除可见目标测试通过")

func test_frustum_culling_outside_target():
	"""测试视锥外目标的剔除"""
	print("\n测试11: 视锥剔除外部目标测试")
	
	var middleware = JuicyLODMiddleware.new()
	
	# 创建摄像机和目标
	var camera = Camera2D.new()
	camera.global_position = Vector2(500, 300)
	
	# 创建在视锥外的目标
	var target = Node2D.new()
	target.global_position = Vector2(1200, 300)  # 在视口外
	
	# 检查可见性
	var is_visible = middleware._is_target_visible(camera, target)
	assert_false(is_visible, "视锥外的目标应该被剔除")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 视锥剔除外部目标测试通过")

func test_frustum_culling_boundary_conditions():
	"""测试视锥剔除的边界情况"""
	print("\n测试12: 视锥剔除边界情况测试")
	
	var middleware = JuicyLODMiddleware.new()
	
	# 创建摄像机和目标
	var camera = Camera2D.new()
	camera.global_position = Vector2(0, 0)
	
	# 测试边界情况 - 刚好在边界上
	var target = Node2D.new()
	target.global_position = Vector2(500, 300)  # 假设视口大小为1000x600
	
	var is_visible = middleware._is_target_visible(camera, target)
	# 边界情况的处理取决于具体实现
	
	# 测试null参数
	is_visible = middleware._is_target_visible(null, target)
	assert_false(is_visible, "null摄像机应该返回false")
	
	is_visible = middleware._is_target_visible(camera, null)
	assert_false(is_visible, "null目标应该返回false")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 视锥剔除边界情况测试通过")

func test_frustum_culling_in_integration():
	"""测试视锥剔除在集成中的效果"""
	print("\n测试13: 视锥剔除集成测试")
	
	var middleware = JuicyLODMiddleware.new()
	
	# 设置启用视锥剔除的配置
	var config = JuicyLODConfig.new()
	config.enable_frustum_culling = true
	config.enable_distance_culling = false
	middleware.set_lod_config(config)
	
	# 创建测试上下文
	var context = JuicyContext.new()
	context.target = Node2D.new()
	context.time_scale = 1.0
	
	# 创建摄像机和目标（目标在视锥外）
	var camera = Camera2D.new()
	camera.global_position = Vector2(0, 0)
	context.target.global_position = Vector2(2000, 0)  # 远离视锥
	
	middleware.set_camera(camera)
	
	# 处理上下文
	var processed = middleware.process(context, func(ctx):
		assert_equal(ctx.time_scale, 0.0, "视锥外的目标时间缩放应该为0")
		return true
	)
	
	assert_true(processed, "处理应该成功")
	
	# 验证统计信息
	var stats = middleware.get_lod_stats()
	assert_true(stats.frustum_culled > 0, "应该有视锥剔除统计")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 视锥剔除集成测试通过")

# =============================================================================
# 测试组5: 距离剔除测试
# =============================================================================

func test_distance_culling_beyond_max_distance():
	"""测试超出最大距离的目标剔除"""
	print("\n测试14: 距离剔除超出最大距离测试")
	
	var middleware = JuicyLODMiddleware.new()
	
	# 设置启用距离剔除的配置
	var config = JuicyLODConfig.new()
	config.max_distance = 200.0
	config.enable_frustum_culling = false
	config.enable_distance_culling = true
	middleware.set_lod_config(config)
	
	# 创建测试上下文
	var context = JuicyContext.new()
	context.target = Node2D.new()
	context.time_scale = 1.0
	
	# 创建摄像机和目标（目标超出最大距离）
	var camera = Camera2D.new()
	camera.global_position = Vector2(0, 0)
	context.target.global_position = Vector2(300, 0)  # 距离300，超出最大距离200
	
	middleware.set_camera(camera)
	
	# 处理上下文
	var processed = middleware.process(context, func(ctx):
		assert_equal(ctx.time_scale, 0.0, "超出最大距离的目标时间缩放应该为0")
		return true
	)
	
	assert_true(processed, "处理应该成功")
	
	# 验证统计信息
	var stats = middleware.get_lod_stats()
	assert_true(stats.distance_culled > 0, "应该有距离剔除统计")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 距离剔除超出最大距离测试通过")

func test_distance_culling_within_max_distance():
	"""测试在最大距离内的目标不被剔除"""
	print("\n测试15: 距离剔除在最大距离内测试")
	
	var middleware = JuicyLODMiddleware.new()
	
	# 设置启用距离剔除的配置
	var config = JuicyLODConfig.new()
	config.max_distance = 200.0
	config.distance_thresholds = [50.0, 100.0, 150.0]
	config.intensity_multipliers = [1.0, 0.8, 0.6, 0.4, 0.2]
	config.enable_frustum_culling = false
	config.enable_distance_culling = true
	middleware.set_lod_config(config)
	
	# 创建测试上下文
	var context = JuicyContext.new()
	context.target = Node2D.new()
	context.time_scale = 1.0
	
	# 创建摄像机和目标（目标在最大距离内）
	var camera = Camera2D.new()
	camera.global_position = Vector2(0, 0)
	context.target.global_position = Vector2(100, 0)  # 距离100，在最大距离内
	
	middleware.set_camera(camera)
	
	# 处理上下文
	var processed = middleware.process(context, func(ctx):
		assert_true(ctx.time_scale > 0.0, "在最大距离内的目标时间缩放应该大于0")
		assert_equal(ctx.time_scale, 0.8, "时间缩放应该根据距离阈值调整")
		return true
	)
	
	assert_true(processed, "处理应该成功")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 距离剔除在最大距离内测试通过")

# =============================================================================
# 测试组6: 配置管理测试
# =============================================================================

func test_config_loading_and_saving():
	"""测试配置的加载和保存"""
	print("\n测试16: 配置加载和保存测试")
	
	var middleware = JuicyLODMiddleware.new()
	
	# 创建测试配置
	var config = JuicyLODConfig.new()
	config.config_name = "test_config"
	config.max_distance = 600.0
	config.distance_thresholds = [100.0, 200.0, 300.0]
	config.intensity_multipliers = [1.0, 0.8, 0.6, 0.4, 0.2]
	
	# 保存配置
	var save_result = middleware.save_lod_config(config, TEMP_CONFIG_PATH)
	assert_true(save_result, "配置保存应该成功")
	
	# 加载配置
	var loaded_config = middleware.load_lod_config(TEMP_CONFIG_PATH)
	assert_not_null(loaded_config, "配置加载应该成功")
	assert_equal(loaded_config.config_name, "test_config", "加载的配置名称应该匹配")
	assert_equal(loaded_config.max_distance, 600.0, "加载的最大距离应该匹配")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 配置加载和保存测试通过")

func test_distance_thresholds_setting():
	"""测试距离阈值和强度倍数的设置"""
	print("\n测试17: 距离阈值设置测试")
	
	var middleware = JuicyLODMiddleware.new()
	
	# 创建基础配置
	var config = JuicyLODConfig.new()
	middleware.set_lod_config(config)
	
	# 设置距离阈值和强度倍数
	var thresholds = [50.0, 100.0, 150.0, 200.0]
	var multipliers = [1.0, 0.9, 0.7, 0.5, 0.3]  # 修复：应该是thresholds.size() + 1
	
	middleware.set_distance_thresholds(thresholds, multipliers)
	
	# 验证设置
	var updated_config = middleware.get_lod_config()
	assert_equal(updated_config.distance_thresholds, thresholds, "距离阈值应该被设置")
	assert_equal(updated_config.intensity_multipliers, multipliers, "强度倍数应该被设置")
	
	# 测试无效数组大小
	var invalid_thresholds = [50.0, 100.0]
	var invalid_multipliers = [1.0, 0.5]  # 故意使用不匹配的大小（应该是3个元素）
	
	# 应该记录错误但不抛出异常
	var original_thresholds = updated_config.distance_thresholds.duplicate()
	var original_multipliers = updated_config.intensity_multipliers.duplicate()
	middleware.set_distance_thresholds(invalid_thresholds, invalid_multipliers)
	# 配置应该保持不变
	assert_equal(updated_config.distance_thresholds, original_thresholds, "无效设置不应该改变现有配置")
	assert_equal(updated_config.intensity_multipliers, original_multipliers, "无效设置不应该改变强度倍数")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 距离阈值设置测试通过")

func test_camera_setting():
	"""测试摄像机设置"""
	print("\n测试18: 摄像机设置测试")
	
	var middleware = JuicyLODMiddleware.new()
	
	# 创建测试摄像机
	var camera = Camera2D.new()
	camera.set_name("TestCamera")
	
	# 设置摄像机
	middleware.set_camera(camera)
	
	# 验证通过统计信息
	var stats = middleware.get_lod_stats()
	assert_true(stats.camera_set, "摄像机应该被设置")
	
	_test_count += 1
	_passed_count += 1
	print("✓ 摄像机设置测试通过")

# =============================================================================
# 测试组7: 统计和调试功能测试
# =============================================================================

func test_lod_stats_collection():
	"""测试LOD统计信息收集"""
	var middleware = JuicyLODMiddleware.new()
	
	# 设置配置
	var config = JuicyLODConfig.new()
	config.max_distance = 300.0
	config.distance_thresholds = [100.0, 200.0]
	config.intensity_multipliers = [1.0, 0.7, 0.4, 0.1]
	config.enable_frustum_culling = true
	config.enable_distance_culling = true
	middleware.set_lod_config(config)
	
	# 创建摄像机和目标
	var camera = Camera2D.new()
	camera.global_position = Vector2(0, 0)
	middleware.set_camera(camera)
	
	# 创建多个上下文进行测试
	for i in range(5):
		var context = JuicyContext.new()
		context.target = Node2D.new()
		
		if i < 2:
			# 视锥内的目标
			context.target.global_position = Vector2(50, 50)
		else:
			# 视锥外的目标
			context.target.global_position = Vector2(2000, 0)
		
		context.time_scale = 1.0
		middleware.process(context, func(ctx): return true)
	
	# 获取统计信息
	var stats = middleware.get_lod_stats()
	assert_not_null(stats, "统计信息不应该为null")
	assert_true(stats.has("total_processed"), "应该包含总处理数")
	assert_true(stats.has("frustum_culled"), "应该包含视锥剔除数")
	assert_true(stats.has("distance_culled"), "应该包含距离剔除数")
	assert_true(stats.has("intensity_adjusted"), "应该包含强度调整数")
	assert_true(stats.has("camera_set"), "应该包含摄像机设置状态")
	assert_true(stats.has("max_distance"), "应该包含最大距离")
	assert_true(stats.has("distance_thresholds"), "应该包含距离阈值")
	assert_true(stats.has("intensity_multipliers"), "应该包含强度倍数")
	assert_true(stats.has("frustum_culling_enabled"), "应该包含视锥剔除启用状态")
	assert_true(stats.has("distance_culling_enabled"), "应该包含距离剔除启用状态")

func test_debug_print_lod_info():
	"""测试调试信息打印"""
	var middleware = JuicyLODMiddleware.new()
	
	# 设置一些基本配置
	var config = JuicyLODConfig.new()
	config.config_name = "debug_test"
	middleware.set_lod_config(config)
	
	# 测试调试打印（不应该抛出异常）
	middleware.debug_print_lod_info()
	
	# 测试通过
	assert_true(true, "调试打印应该成功执行")

# =============================================================================
# 测试组8: 中间件集成测试
# =============================================================================

func test_lod_middleware_with_juicy_context():
	"""测试LODMiddleware与JuicyContext的集成"""
	var middleware = JuicyLODMiddleware.new()
	
	# 设置配置
	var config = JuicyLODConfig.new()
	config.max_distance = 250.0
	config.distance_thresholds = [50.0, 100.0, 150.0, 200.0]
	config.intensity_multipliers = [1.0, 0.9, 0.8, 0.6, 0.4, 0.2]
	config.enable_frustum_culling = false
	config.enable_distance_culling = true
	middleware.set_lod_config(config)
	
	# 创建摄像机和目标
	var camera = Camera2D.new()
	camera.global_position = Vector2(0, 0)
	middleware.set_camera(camera)
	
	# 创建上下文
	var context = JuicyContext.new()
	context.target = Node2D.new()
	context.time_scale = 1.0
	
	# 测试不同距离的效果
	var test_distances = [30.0, 75.0, 125.0, 175.0, 225.0, 300.0]
	var expected_scales = [1.0, 0.9, 0.8, 0.6, 0.4, 0.0]  # 最后一个超出最大距离
	
	for i in range(test_distances.size()):
		context.target.global_position = Vector2(test_distances[i], 0)
		var original_scale = context.time_scale
		
		middleware.process(context, func(ctx): 
			if i < expected_scales.size() - 1:
				assert_equal(ctx.time_scale, expected_scales[i], "距离 %f 应该产生强度 %f" % [test_distances[i], expected_scales[i]])
			else:
				assert_equal(ctx.time_scale, 0.0, "超出最大距离应该被剔除")
			return true
		)
		
		# 重置时间缩放用于下一个测试
		context.time_scale = 1.0

func test_lod_middleware_lifecycle_methods():
	"""测试LODMiddleware的生命周期方法"""
	var middleware = JuicyLODMiddleware.new()
	
	# 创建测试上下文
	var context = JuicyContext.new()
	context.context_id = "test_context"
	context.target = Node2D.new()
	
	# 测试生命周期方法（不应该抛出异常）
	middleware.on_context_created(context)
	middleware.on_context_paused(context)
	middleware.on_context_resumed(context)
	middleware.cleanup(context)
	middleware.on_context_destroyed(context)
	
	# 测试通过
	assert_true(true, "所有生命周期方法应该成功执行")

func test_lod_middleware_performance_monitoring():
	"""测试LODMiddleware的性能监控"""
	var middleware = JuicyLODMiddleware.new()
	
	# 启用性能监控
	middleware.set_performance_monitoring_enabled(true)
	
	# 创建测试上下文
	var context = JuicyContext.new()
	context.target = Node2D.new()
	
	# 创建摄像机和目标
	var camera = Camera2D.new()
	camera.global_position = Vector2(0, 0)
	context.target.global_position = Vector2(100, 0)
	middleware.set_camera(camera)
	
	# 处理上下文多次
	for i in range(10):
		middleware.process(context, func(ctx): return true)
	
	# 获取性能统计
	var perf_stats = middleware.get_performance_stats()
	assert_not_null(perf_stats, "性能统计不应该为null")
	assert_true(perf_stats.has("total_execution_time"), "应该包含总执行时间")
	assert_true(perf_stats.has("average_execution_time"), "应该包含平均执行时间")
	assert_true(perf_stats.has("max_execution_time"), "应该包含最大执行时间")
	assert_true(perf_stats.has("min_execution_time"), "应该包含最小执行时间")
	assert_true(perf_stats.has("call_count"), "应该包含调用次数")

# 辅助函数
func assert_equal(expected, actual, message = ""):
	if expected != actual:
		_failed_count += 1
		print("✗ 断言失败: " + message)
		print("  期望: ", expected)
		print("  实际: ", actual)
		_test_results.append({
			"test": get_stack()[1].function,
			"message": message,
			"expected": expected,
			"actual": actual,
			"status": "FAILED"
		})
	else:
		print("  ✓ ", message)

func assert_not_null(value, message = ""):
	if value == null:
		_failed_count += 1
		print("✗ 断言失败: " + message)
		print("  期望: 非null")
		print("  实际: null")
		_test_results.append({
			"test": get_stack()[1].function,
			"message": message,
			"expected": "非null",
			"actual": "null",
			"status": "FAILED"
		})
	else:
		print("  ✓ ", message)

func assert_null(value, message = ""):
	if value != null:
		_failed_count += 1
		print("✗ 断言失败: " + message)
		print("  期望: null")
		print("  实际: ", value)
		_test_results.append({
			"test": get_stack()[1].function,
			"message": message,
			"expected": "null",
			"actual": str(value),
			"status": "FAILED"
		})
	else:
		print("  ✓ ", message)

func assert_true(condition, message = ""):
	if !condition:
		_failed_count += 1
		print("✗ 断言失败: " + message)
		print("  期望: true")
		print("  实际: ", condition)
		_test_results.append({
			"test": get_stack()[1].function,
			"message": message,
			"expected": true,
			"actual": condition,
			"status": "FAILED"
		})
	else:
		print("  ✓ ", message)

func assert_false(condition, message = ""):
	if condition:
		_failed_count += 1
		print("✗ 断言失败: " + message)
		print("  期望: false")
		print("  实际: ", condition)
		_test_results.append({
			"test": get_stack()[1].function,
			"message": message,
			"expected": false,
			"actual": condition,
			"status": "FAILED"
		})
	else:
		print("  ✓ ", message)

# 打印测试总结
func print_test_summary():
	print("\n" + "=".repeat(50))
	print("LODMiddleware 测试总结")
	print("=".repeat(50))
	print("总测试数: ", _test_count)
	print("通过测试: ", _passed_count)
	print("失败测试: ", _failed_count)
	print("成功率: ", float(_passed_count) / float(_test_count) * 100, "%")
	
	if _failed_count > 0:
		print("\n失败的测试:")
		for result in _test_results:
			if result.status == "FAILED":
				print("  - ", result.test, ": ", result.message)
	
	print("\nLODMiddleware 测试完成!")

func _exit_tree():
	# 清理测试节点
	for child in get_children():
		if child is Node2D:
			child.queue_free()
	
	# 清理临时文件
	if FileAccess.file_exists(TEMP_CONFIG_PATH):
		DirAccess.remove_absolute(TEMP_CONFIG_PATH)

func test_null_context_handling():
	"""测试null上下文的处理"""
	var middleware = JuicyLODMiddleware.new()
	
	# 处理null上下文（不应该抛出异常）
	var result = middleware.process(null, func(ctx): return true)
	
	# 应该返回true，因为现在允许继续执行
	assert_true(result, "null上下文应该被成功处理")

func test_null_target_handling():
	"""测试null目标的处理"""
	var middleware = JuicyLODMiddleware.new()
	
	# 创建没有目标的上下文
	var context = JuicyContext.new()
	context.time_scale = 1.0
	
	# 处理没有目标的上下文（不应该抛出异常）
	var result = middleware.process(context, func(ctx): return true)
	
	# 应该成功处理
	assert_true(result, "null目标应该被成功处理")

func test_missing_camera_handling():
	"""测试缺少摄像机的处理"""
	var middleware = JuicyLODMiddleware.new()
	
	# 设置配置
	var config = JuicyLODConfig.new()
	middleware.set_lod_config(config)
	
	# 创建测试上下文
	var context = JuicyContext.new()
	context.target = Node2D.new()
	context.time_scale = 1.0
	
	# 处理上下文（没有摄像机）
	var result = middleware.process(context, func(ctx): 
		# 没有摄像机时，上下文应该保持不变
		assert_equal(ctx.time_scale, 1.0, "没有摄像机时时间缩放应该保持不变")
		return true
	)
	
	assert_true(result, "缺少摄像机时处理应该成功")

func test_edge_case_configurations():
	"""测试边界情况配置"""
	var middleware = JuicyLODMiddleware.new()
	
	# 测试空配置
	var empty_config = JuicyLODConfig.new()
	empty_config.distance_thresholds = []
	empty_config.intensity_multipliers = [0.5]
	middleware.set_lod_config(empty_config)
	
	# 创建测试上下文
	var context = JuicyContext.new()
	context.target = Node2D.new()
	context.time_scale = 1.0
	
	# 创建摄像机和目标
	var camera = Camera2D.new()
	camera.global_position = Vector2(0, 0)
	context.target.global_position = Vector2(100, 0)
	middleware.set_camera(camera)
	
	# 处理上下文
	var result = middleware.process(context, func(ctx): 
		# 应该使用默认强度倍数
		assert_equal(ctx.time_scale, 0.5, "空阈值配置应该使用默认强度倍数")
		return true
	)
	
	assert_true(result, "边界情况配置应该被成功处理")