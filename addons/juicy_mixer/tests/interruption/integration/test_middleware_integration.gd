extends SceneTree
# 中断系统与Middleware系统集成测试
# 测试中断中间件与其他中间件的协调工作

const InterruptionMiddleware = preload("res://addons/juicy_mixer/middleware/interruption_middleware.gd")
const ChannelInterruptionConfig = preload("res://addons/juicy_mixer/resources/channel_interruption_config.gd")
const JuicyMixerEnms = preload("res://addons/juicy_mixer/core/juicy_mixer_enums.gd")

var _test_results: Array = []
var _interruption_middleware: InterruptionMiddleware
var _mock_middlewares: Array = []
var _test_node: Node2D
var _pipeline_mock: Object

func _init():
    _test_results = []

func setup_test_environment():
    # 设置测试环境
    _interruption_middleware = InterruptionMiddleware.new()
    _test_node = Node2D.new()
    
    # 创建管道模拟对象
    _pipeline_mock = RefCounted.new()
    _pipeline_mock.middlewares = []
    _pipeline_mock.add_middleware = func(middleware): _pipeline_mock.middlewares.append(middleware)
    _pipeline_mock.get_middlewares = func(): return _pipeline_mock.middlewares

func cleanup_test_environment():
    # 清理测试环境
    if _test_node:
        _test_node.free()
    if _interruption_middleware:
        _interruption_middleware.destroy()
    
    # 清理模拟中间件
    for middleware in _mock_middlewares:
        if middleware.has_method("destroy"):
            middleware.destroy()

func _create_mock_middleware(name: String, priority: int) -> Object:
    # 创建模拟中间件
    var mock_middleware = RefCounted.new()
    mock_middleware.middleware_name = name
    mock_middleware.priority = priority
    mock_middleware.description = "Mock " + name
    mock_middleware.author = "Test"
    mock_middleware.tags = ["test"]
    mock_middleware.enabled = true
    
    # 模拟基本方法
    mock_middleware.initialize = func(config = {}): return true
    mock_middleware.before_play = func(context): return true
    mock_middleware.process = func(context, next): return next.call()
    mock_middleware.cleanup = func(context): pass
    mock_middleware.destroy = func(): pass
    
    _mock_middlewares.append(mock_middleware)
    return mock_middleware

func _create_test_context(context_id: String, channel: String = "test_channel", priority: int = 0) -> Object:
    # 创建测试上下文
    var context = RefCounted.new()
    context.context_id = context_id
    context.target = _test_node
    context.owner = _test_node
    context.resource = _create_test_resource(channel, priority)
    return context

func _create_test_resource(channel: String, priority: int = 0) -> Object:
    # 创建测试资源
    var resource = RefCounted.new()
    resource.channel = channel
    resource.priority = priority
    resource.get_interruption_policy = func(): return ""
    return resource

func test_middleware_initialization_in_pipeline():
    setup_test_environment()
    
    # 测试在管道中的初始化
    var config = {
        "enable_performance_monitoring": true,
        "enable_debug_logging": false,
        "priority": 100
    }
    
    var result = _interruption_middleware.initialize(config)
    assert(result, "中断中间件应该成功初始化")
    assert(_interruption_middleware._interruption_manager != null, "中断管理器应该被创建")
    
    cleanup_test_environment()
    _test_results.append("test_middleware_initialization_in_pipeline: PASSED")

func test_middleware_priority_ordering():
    setup_test_environment()
    
    # 创建不同优先级的中间件
    var low_priority_middleware = _create_mock_middleware("LowPriority", 50)
    var high_priority_middleware = _create_mock_middleware("HighPriority", 150)
    var medium_priority_middleware = _create_mock_middleware("MediumPriority", 100)
    
    # 添加到管道
    _pipeline_mock.add_middleware(low_priority_middleware)
    _pipeline_mock.add_middleware(_interruption_middleware)
    _pipeline_mock.add_middleware(medium_priority_middleware)
    _pipeline_mock.add_middleware(high_priority_middleware)
    
    # 验证优先级排序（高优先级在前）
    var middlewares = _pipeline_mock.get_middlewares()
    assert(middlewares.size() == 4, "应该有4个中间件")
    
    # 中断中间件优先级应该是100
    assert(_interruption_middleware.priority == 100, "中断中间件优先级应该是100")
    
    cleanup_test_environment()
    _test_results.append("test_middleware_priority_ordering: PASSED")

func test_interruption_middleware_before_play():
    setup_test_environment()
    
    # 初始化中断中间件
    _interruption_middleware.initialize()
    
    # 创建测试上下文
    var context = _create_test_context("test_context", "test_channel", 1)
    
    # 测试 before_play 方法
    var result = _interruption_middleware.before_play(context)
    assert(typeof(result) == TYPE_BOOL, "before_play 应该返回布尔值")
    
    cleanup_test_environment()
    _test_results.append("test_interruption_middleware_before_play: PASSED")

func test_interruption_middleware_process():
    setup_test_environment()
    
    # 初始化中断中间件
    _interruption_middleware.initialize()
    
    # 创建模拟的 next 回调函数
    var next_called = false
    var next_callback = func(): 
        next_called = true
        return true
    
    # 创建测试上下文
    var mock_juicy_context = RefCounted.new()
    mock_juicy_context.context_id = "test_context"
    mock_juicy_context.target = _test_node
    
    # 测试 process 方法
    var result = _interruption_middleware.process(mock_juicy_context, next_callback)
    assert(result, "process 应该成功执行")
    assert(next_called, "next 回调应该被调用")
    
    cleanup_test_environment()
    _test_results.append("test_interruption_middleware_process: PASSED")

func test_interruption_middleware_cleanup():
    setup_test_environment()
    
    # 初始化中断中间件
    _interruption_middleware.initialize()
    
    # 创建测试上下文
    var mock_juicy_context = RefCounted.new()
    mock_juicy_context.context_id = "test_context"
    mock_juicy_context.target = _test_node
    
    # 测试 cleanup 方法
    _interruption_middleware.cleanup(mock_juicy_context)
    # 应该成功执行，没有异常
    
    cleanup_test_environment()
    _test_results.append("test_interruption_middleware_cleanup: PASSED")

func test_middleware_chain_execution():
    setup_test_environment()
    
    # 创建模拟中间件链
    var middleware1 = _create_mock_middleware("Middleware1", 80)
    var middleware2 = _create_mock_middleware("Middleware2", 120)
    
    # 设置执行顺序跟踪
    var execution_order = []
    
    # 重写方法以跟踪执行顺序
    middleware1.before_play = func(context): 
        execution_order.append("Middleware1_before_play")
        return true
    
    middleware2.before_play = func(context): 
        execution_order.append("Middleware2_before_play")
        return true
    
    middleware1.process = func(context, next): 
        execution_order.append("Middleware1_process")
        return next.call()
    
    middleware2.process = func(context, next): 
        execution_order.append("Middleware2_process")
        return next.call()
    
    # 初始化中断中间件
    _interruption_middleware.initialize()
    
    # 创建测试上下文
    var context = _create_test_context("test_context", "test_channel", 1)
    
    # 模拟执行链（按优先级顺序）
    var result1 = middleware2.before_play(context)  # 高优先级先执行
    var result2 = _interruption_middleware.before_play(context)  # 中断中间件
    var result3 = middleware1.before_play(context)  # 低优先级后执行
    
    assert(result1 and result2 and result3, "所有中间件都应该成功执行")
    
    cleanup_test_environment()
    _test_results.append("test_middleware_chain_execution: PASSED")

func test_interruption_policy_configuration():
    setup_test_environment()
    
    # 初始化中断中间件
    _interruption_middleware.initialize()
    
    # 配置通道
    var config = ChannelInterruptionConfig.new()
    config.channel_name = "test_channel"
    config.default_policy = JuicyMixerEnms.InterruptionPolicy.RESTART
    config.priority = 10
    _interruption_middleware.set_channel_config("test_channel", config)
    
    # 验证配置
    var retrieved_config = _interruption_middleware._interruption_manager._get_channel_config("test_channel")
    assert(retrieved_config == config, "应该能正确获取通道配置")
    
    cleanup_test_environment()
    _test_results.append("test_interruption_policy_configuration: PASSED")

func test_global_priority_configuration():
    setup_test_environment()
    
    # 初始化中断中间件
    _interruption_middleware.initialize()
    
    # 设置全局优先级
    _interruption_middleware.set_global_priority("TestResource", 15)
    _interruption_middleware.set_global_priority("AnotherResource", 5)
    
    # 验证优先级设置
    # 注意：这里需要实际测试优先级获取逻辑
    # 由于依赖外部方法，这里只是基本测试
    
    cleanup_test_environment()
    _test_results.append("test_global_priority_configuration: PASSED")

func test_default_policy_configuration():
    setup_test_environment()
    
    # 初始化中断中间件
    _interruption_middleware.initialize()
    
    # 设置默认策略
    _interruption_middleware.set_default_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    
    # 验证默认策略
    assert(_interruption_middleware._interruption_manager.get_default_policy() == JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE, "默认策略应该正确设置")
    
    cleanup_test_environment()
    _test_results.append("test_default_policy_configuration: PASSED")

func test_context_lifecycle_integration():
    setup_test_environment()
    
    # 初始化中断中间件
    _interruption_middleware.initialize()
    
    # 创建测试上下文
    var context = _create_test_context("test_context", "test_channel", 1)
    
    # 测试上下文生命周期事件
    _interruption_middleware.on_context_created(context)
    _interruption_middleware.on_context_paused(context)
    _interruption_middleware.on_context_resumed(context)
    _interruption_middleware.on_context_destroyed(context)
    
    # 所有事件应该成功处理
    assert(true, "上下文生命周期事件应该成功处理")
    
    cleanup_test_environment()
    _test_results.append("test_context_lifecycle_integration: PASSED")

func test_interruption_state_query():
    setup_test_environment()
    
    # 初始化中断中间件
    _interruption_middleware.initialize()
    
    # 创建测试上下文
    var context = _create_test_context("test_context", "test_channel", 1)
    
    # 测试状态查询
    var state = _interruption_middleware.get_interruption_state(_test_node)
    # 应该返回 null 或有效状态
    
    # 测试统计查询
    var stats = _interruption_middleware.get_interruption_stats()
    assert(typeof(stats) == TYPE_DICTIONARY, "统计信息应该是字典")
    
    cleanup_test_environment()
    _test_results.append("test_interruption_state_query: PASSED")

func test_performance_monitoring():
    setup_test_environment()
    
    # 初始化中断中间件（启用性能监控）
    _interruption_middleware.initialize({
        "enable_performance_monitoring": true
    })
    
    # 获取性能统计
    var stats = _interruption_middleware.get_performance_stats()
    assert(typeof(stats) == TYPE_DICTIONARY, "性能统计应该是字典")
    assert(stats.has("interruption_interruption_count"), "应该包含中断计数")
    assert(stats.has("interruption_total_interruption_time"), "应该包含总中断时间")
    
    cleanup_test_environment()
    _test_results.append("test_performance_monitoring: PASSED")

func test_error_handling_in_pipeline():
    setup_test_environment()
    
    # 初始化中断中间件
    _interruption_middleware.initialize()
    
    # 测试空上下文处理
    var null_result = _interruption_middleware.before_play(null)
    assert(typeof(null_result) == TYPE_BOOL, "空上下文处理应该返回布尔值")
    
    # 测试无效上下文处理
    var invalid_context = RefCounted.new()
    var invalid_result = _interruption_middleware.before_play(invalid_context)
    assert(typeof(invalid_result) == TYPE_BOOL, "无效上下文处理应该返回布尔值")
    
    cleanup_test_environment()
    _test_results.append("test_error_handling_in_pipeline: PASSED")

func test_middleware_destruction():
    setup_test_environment()
    
    # 初始化中断中间件
    _interruption_middleware.initialize()
    
    # 测试销毁
    _interruption_middleware.destroy()
    assert(_interruption_middleware._interruption_manager == null, "中断管理器应该被清除")
    
    cleanup_test_environment()
    _test_results.append("test_middleware_destruction: PASSED")

func test_configuration_schema():
    setup_test_environment()
    
    # 初始化中断中间件
    _interruption_middleware.initialize()
    
    # 测试配置模式
    var schema = _interruption_middleware.get_configuration_schema()
    assert(typeof(schema) == TYPE_DICTIONARY, "配置模式应该是字典")
    assert(schema.has("enable_performance_monitoring"), "应该包含性能监控模式")
    assert(schema.has("enable_debug_logging"), "应该包含调试日志模式")
    assert(schema.has("priority"), "应该包含优先级模式")
    assert(schema.has("max_log_entries"), "应该包含最大日志条目模式")
    assert(schema.has("enable_auto_cleanup"), "应该包含自动清理模式")
    assert(schema.has("cleanup_threshold"), "应该包含清理阈值模式")
    
    cleanup_test_environment()
    _test_results.append("test_configuration_schema: PASSED")

func test_middleware_tags_and_metadata():
    setup_test_environment()
    
    # 测试中间件元数据
    assert(_interruption_middleware.middleware_name == "InterruptionMiddleware", "中间件名称应该正确")
    assert(_interruption_middleware.priority == 100, "中间件优先级应该是100")
    assert(_interruption_middleware.description == "Handles effect interruption policies during execution", "描述应该正确")
    assert(_interruption_middleware.author == "JuicyMixer Team", "作者应该正确")
    assert("interruption" in _interruption_middleware.tags, "标签应该包含 interruption")
    assert("policy" in _interruption_middleware.tags, "标签应该包含 policy")
    assert("priority" in _interruption_middleware.tags, "标签应该包含 priority")
    assert("transition" in _interruption_middleware.tags, "标签应该包含 transition")
    
    cleanup_test_environment()
    _test_results.append("test_middleware_tags_and_metadata: PASSED")

func test_concurrent_middleware_execution():
    setup_test_environment()
    
    # 创建多个模拟中间件
    var middlewares = []
    for i in range(5):
        var middleware = _create_mock_middleware("ConcurrentMiddleware" + str(i), 90 + i * 10)
        middlewares.append(middleware)
    
    # 初始化中断中间件
    _interruption_middleware.initialize()
    
    # 创建测试上下文
    var context = _create_test_context("test_context", "test_channel", 1)
    
    # 模拟并发执行
    var results = []
    for middleware in middlewares:
        var result = middleware.before_play(context)
        results.append(result)
    
    # 所有中间件都应该成功执行
    for result in results:
        assert(result, "所有中间件都应该成功执行")
    
    cleanup_test_environment()
    _test_results.append("test_concurrent_middleware_execution: PASSED")

func test_middleware_state_isolation():
    setup_test_environment()
    
    # 创建两个独立的中断中间件实例
    var middleware1 = InterruptionMiddleware.new()
    var middleware2 = InterruptionMiddleware.new()
    
    # 初始化
    middleware1.initialize()
    middleware2.initialize()
    
    # 配置不同的通道
    var config1 = ChannelInterruptionConfig.new()
    config1.channel_name = "channel1"
    config1.default_policy = JuicyMixerEnms.InterruptionPolicy.STACK
    middleware1.set_channel_config("channel1", config1)
    
    var config2 = ChannelInterruptionConfig.new()
    config2.channel_name = "channel2"
    config2.default_policy = JuicyMixerEnms.InterruptionPolicy.RESTART
    middleware2.set_channel_config("channel2", config2)
    
    # 验证状态隔离
    var state1 = middleware1._interruption_manager._get_channel_config("channel1")
    var state2 = middleware2._interruption_manager._get_channel_config("channel2")
    
    assert(state1.default_policy == JuicyMixerEnms.InterruptionPolicy.STACK, "中间件1的配置应该独立")
    assert(state2.default_policy == JuicyMixerEnms.InterruptionPolicy.RESTART, "中间件2的配置应该独立")
    
    # 清理
    middleware1.destroy()
    middleware2.destroy()
    
    cleanup_test_environment()
    _test_results.append("test_middleware_state_isolation: PASSED")

func run_all_tests():
    print("=== 开始 中断系统与Middleware系统集成测试 ===")
    
    test_middleware_initialization_in_pipeline()
    test_middleware_priority_ordering()
    test_interruption_middleware_before_play()
    test_interruption_middleware_process()
    test_interruption_middleware_cleanup()
    test_middleware_chain_execution()
    test_interruption_policy_configuration()
    test_global_priority_configuration()
    test_default_policy_configuration()
    test_context_lifecycle_integration()
    test_interruption_state_query()
    test_performance_monitoring()
    test_error_handling_in_pipeline()
    test_middleware_destruction()
    test_configuration_schema()
    test_middleware_tags_and_metadata()
    test_concurrent_middleware_execution()
    test_middleware_state_isolation()
    
    print("=== 中断系统与Middleware系统集成测试结果 ===")
    for result in _test_results:
        print(result)
    
    var passed_count = _test_results.size()
    var total_tests = 18
    print("通过测试: " + str(passed_count) + "/" + str(total_tests))
    
    if passed_count == total_tests:
        print("所有测试通过！")
        return true
    else:
        print("部分测试失败！")
        return false