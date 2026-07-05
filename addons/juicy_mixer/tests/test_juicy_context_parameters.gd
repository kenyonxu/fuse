# 测试JuicyContext的参数管理功能
# 验证参数存储、映射和清理功能

extends Node

# 测试用的模拟资源
var mock_resource: JuicyShakeResource
var mock_target: Node
var mock_owner: Node

func _ready():
	print("=== JuicyContext参数管理测试开始 ===")
	
	# 创建测试用的节点
	mock_target = Node.new()
	mock_owner = Node.new()
	
	# 创建模拟资源 - 使用JuicyShakeResource
	mock_resource = JuicyShakeResource.new()
	
	# 运行测试
	test_parameter_storage()
	test_parameter_mappings()
	test_parameter_cleanup()
	test_error_handling()
	
	print("=== JuicyContext参数管理测试完成 ===")
	
	# 清理
	mock_target.queue_free()
	mock_owner.queue_free()

func test_parameter_storage():
	print("\n--- 测试参数存储 ---")
	
	# 创建上下文
	var context = JuicyContext.create(mock_resource, mock_target, mock_owner)
	
	# 测试设置和获取参数
	context.set_parameter("intensity", 0.5)
	var value = context.get_parameter("intensity")
	assert(value == 0.5, "参数值应该为0.5，实际为: " + str(value))
	print("✓ 基本参数设置/获取成功")
	
	# 测试默认值
	var default_value = context.get_parameter("non_existent", 1.0)
	assert(default_value == 1.0, "默认值应该为1.0，实际为: " + str(default_value))
	print("✓ 默认值处理成功")
	
	# 测试参数存在检查
	assert(context.has_parameter("intensity"), "应该存在intensity参数")
	assert(not context.has_parameter("non_existent"), "不应该存在non_existent参数")
	print("✓ 参数存在检查成功")
	
	# 测试获取所有参数名称
	var param_names = context.get_parameter_names()
	assert(param_names.size() == 1, "应该有一个参数，实际为: " + str(param_names.size()))
	assert(param_names.has("intensity"), "应该包含intensity参数")
	print("✓ 参数名称列表成功")
	
	# 测试移除参数
	context.remove_parameter("intensity")
	assert(not context.has_parameter("intensity"), "intensity参数应该被移除")
	print("✓ 参数移除成功")
	
	# 清理
	context.reset()

func test_parameter_mappings():
	print("\n--- 测试参数映射 ---")
	
	# 创建上下文
	var context = JuicyContext.create(mock_resource, mock_target, mock_owner)
	
	# 创建测试曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(1, 2))  # 2倍映射
	
	# 添加参数映射
	context.add_parameter_mapping("intensity", "sub_context_1", "amplitude", curve)
	context.add_parameter_mapping("intensity", "sub_context_2", "volume_db")
	context.add_parameter_mapping("speed", "sub_context_1", "frequency")
	
	# 验证映射添加成功
	var mappings = context.get_parameter_mappings()
	assert(mappings.size() == 2, "应该有两个参数映射，实际为: " + str(mappings.size()))
	print("✓ 参数映射添加成功")
	
	# 验证具体映射目标
	var intensity_targets = context.get_parameter_mapping_targets("intensity")
	assert(intensity_targets.size() == 2, "intensity应该有2个映射目标，实际为: " + str(intensity_targets.size()))
	
	# 检查第一个映射目标
	var first_target = intensity_targets[0]
	assert(first_target is JuicyContext.MappingTarget, "应该是MappingTarget类型")
	assert(first_target.context_id == "sub_context_1", "上下文ID应该为sub_context_1")
	assert(first_target.property_path == "amplitude", "属性路径应该为amplitude")
	assert(first_target.curve != null, "应该有曲线")
	assert(first_target.enabled == true, "应该启用")
	print("✓ 映射目标属性验证成功")
	
	# 验证无效映射处理
	context.add_parameter_mapping("", "invalid", "test")  # 空参数名
	context.add_parameter_mapping("test", "", "test")     # 空上下文ID
	context.add_parameter_mapping("test", "valid", "")    # 空属性路径
	
	# 这些无效映射不应该被添加
	var mappings_after_invalid = context.get_parameter_mappings()
	assert(mappings_after_invalid.size() == 2, "无效映射不应该被添加，实际为: " + str(mappings_after_invalid.size()))
	print("✓ 无效映射处理成功")
	
	# 清理
	context.reset()

func test_parameter_cleanup():
	print("\n--- 测试参数清理 ---")
	
	# 创建上下文
	var context = JuicyContext.create(mock_resource, mock_target, mock_owner)
	
	# 添加一些参数和映射
	context.set_parameter("test_param", 0.8)
	context.add_parameter_mapping("test_param", "ctx1", "prop1")
	context.add_parameter_mapping("test_param", "ctx2", "prop2")
	
	# 验证数据存在
	assert(context.has_parameter("test_param"), "应该存在test_param参数")
	assert(context.get_parameter_mappings().size() == 1, "应该有一个参数映射")
	
	# 执行重置
	context.reset()
	
	# 验证数据被清理
	assert(not context.has_parameter("test_param"), "重置后不应该存在test_param参数")
	assert(context.get_parameter_mappings().size() == 0, "重置后不应该有参数映射")
	print("✓ 重置清理成功")
	
	# 测试手动清理映射
	context.set_parameter("new_param", 1.0)
	context.add_parameter_mapping("new_param", "ctx1", "prop1")
	
	context.clear_parameter_mappings()
	assert(context.get_parameter_mappings().size() == 0, "手动清理后不应该有参数映射")
	# 参数本身应该还存在
	assert(context.has_parameter("new_param"), "参数本身不应该被清理")
	print("✓ 手动清理映射成功")

func test_error_handling():
	print("\n--- 测试错误处理 ---")
	
	# 创建上下文
	var context = JuicyContext.create(mock_resource, mock_target, mock_owner)
	
	# 测试空参数名
	context.set_parameter("", 0.5)  # 不应该崩溃
	var empty_value = context.get_parameter("")
	assert(empty_value == 0.0, "空参数名应该返回默认值0.0")
	
	# 测试空映射
	context.add_parameter_mapping("", "test", "prop")  # 不应该崩溃
	context.add_parameter_mapping("test", "", "prop")  # 不应该崩溃
	context.add_parameter_mapping("test", "ctx", "")   # 不应该崩溃
	
	print("✓ 错误处理成功")
	
	# 清理
	context.reset()
