# 测试 JuicyMixerManager 功能
# 验证中间件配置节点的各种功能

extends Node

# 测试用的中间件
var test_middleware_script: Script
var config_node: JuicyMixerManager

func _ready():
	print("=== JuicyMixerManager 测试开始 ===")
	
	# 加载测试用的中间件脚本
	test_middleware_script = load("res://addons/juicy_mixer/middleware/example_middleware.gd")
	if not test_middleware_script:
		push_error("无法加载测试中间件脚本")
		return
	
	# 创建配置节点
	config_node = JuicyMixerManager.new()
	add_child(config_node)
	
	# 运行测试
	_test_basic_functionality()
	_test_middleware_creation()
	_test_configuration_application()
	_test_dynamic_properties()
	
	print("=== JuicyMixerManager 测试完成 ===")

func _test_basic_functionality():
	print("\n--- 基础功能测试 ---")
	
	# 测试空配置
	var stats = config_node.get_config_stats()
	print("初始统计: ", stats)
	assert(stats.total_entries == 0, "初始条目数应该为0")
	
	# 添加一个配置条目
	var entry = MiddlewareEntry.new()
	entry.middleware_script = test_middleware_script
	entry.enabled = true
	entry.priority = 100
	
	config_node.middleware_entries.append(entry)
	
	# 验证添加后的统计
	stats = config_node.get_config_stats()
	print("添加条目后统计: ", stats)
	assert(stats.total_entries == 1, "应该有一个条目")
	assert(stats.enabled_entries == 1, "应该有一个启用条目")
	
	print("✓ 基础功能测试通过")

func _test_middleware_creation():
	print("\n--- 中间件创建测试 ---")
	
	if config_node.middleware_entries.size() == 0:
		push_error("没有配置条目")
		return
	
	var entry = config_node.middleware_entries[0]
	
	# 测试中间件名称获取
	var name = entry.get_middleware_name()
	print("中间件名称: ", name)
	assert(not name.is_empty(), "应该能获取中间件名称")
	
	# 测试中间件实例创建
	var middleware = entry.create_middleware()
	assert(middleware != null, "应该能创建中间件实例")
	assert(middleware is JuicyMiddleware, "创建的实例应该是JuicyMiddleware类型")
	
	# 验证配置应用
	if not entry.config_data.is_empty():
		var applied_config = middleware.get_configuration()
		print("应用后的配置: ", applied_config)
	
	print("✓ 中间件创建测试通过")

func _test_configuration_application():
	print("\n--- 配置应用测试 ---")
	
	# 确保JuicyMixer已初始化
	if not JuicyMixer.instance:
		push_error("JuicyMixer未初始化")
		return
	
	# 应用配置
	config_node._apply_middleware_configs()
	
	# 验证中间件是否被添加到管道
	var pipeline = JuicyMixer.get_middleware_pipeline()
	if pipeline:
		var all_middleware = pipeline.get_all_middleware()
		print("管道中的中间件数量: ", all_middleware.size())
		
		# 检查我们添加的中间件是否存在
		var found = false
		for middleware in all_middleware:
			if middleware and middleware.middleware_name == "ExampleMiddleware":
				found = true
				break
		
		assert(found, "应该能在管道中找到添加的中间件")
	
	print("✓ 配置应用测试通过")

func _test_dynamic_properties():
	print("\n--- 动态属性测试 ---")
	
	if config_node.middleware_entries.size() == 0:
		push_error("没有配置条目")
		return
	
	var entry = config_node.middleware_entries[0]
	
	# 测试动态属性列表生成
	var properties = entry._get_property_list()
	print("动态属性数量: ", properties.size())
	assert(properties.size() > 3, "应该有基础属性加上配置属性")  # 基础3个 + 配置属性
	
	# 测试配置数据访问
	var config_stats = entry.get_config_stats()
	print("配置统计: ", config_stats)
	assert(config_stats.has_script, "应该有脚本")
	assert(config_stats.enabled, "应该启用")
	
	print("✓ 动态属性测试通过")

func _test_priority_sorting():
	print("\n--- 优先级排序测试 ---")
	
	# 清空现有条目
	config_node.middleware_entries.clear()
	
	# 添加不同优先级的条目
	var entry1 = MiddlewareEntry.new()
	entry1.middleware_script = test_middleware_script
	entry1.priority = 200
	
	var entry2 = MiddlewareEntry.new()
	entry2.middleware_script = test_middleware_script
	entry2.priority = 100
	
	var entry3 = MiddlewareEntry.new()
	entry3.middleware_script = test_middleware_script
	entry3.priority = 300
	
	config_node.middleware_entries.append(entry1)
	config_node.middleware_entries.append(entry2)
	config_node.middleware_entries.append(entry3)
	
	# 测试排序
	var sorted = config_node.middleware_entries.duplicate()
	sorted.sort_custom(func(a, b): return a.priority < b.priority)
	
	print("排序前优先级: ", [config_node.middleware_entries[0].priority, 
							 config_node.middleware_entries[1].priority, 
							 config_node.middleware_entries[2].priority])
	print("排序后优先级: ", [sorted[0].priority, sorted[1].priority, sorted[2].priority])
	
	assert(sorted[0].priority == 100, "第一个应该是优先级100")
	assert(sorted[1].priority == 200, "第二个应该是优先级200")
	assert(sorted[2].priority == 300, "第三个应该是优先级300")
	
	print("✓ 优先级排序测试通过")

func _exit_tree():
	# 清理测试节点
	if config_node and is_instance_valid(config_node):
		config_node.queue_free()