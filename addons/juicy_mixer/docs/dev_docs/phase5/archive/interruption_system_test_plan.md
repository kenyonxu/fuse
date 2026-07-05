# 中断策略系统测试计划

## 1. 测试策略概述

### 1.1 测试目标
- 验证中断策略系统的正确性和可靠性
- 确保与现有系统的兼容性
- 验证性能指标满足要求
- 确保在各种边界条件下的稳定性

### 1.2 测试层次
1. **单元测试** - 测试各个组件的独立功能
2. **集成测试** - 测试组件间的交互
3. **性能测试** - 验证系统性能指标
4. **端到端测试** - 验证完整的使用场景

## 2. 单元测试计划

### 2.1 JuicyMixerEnums测试

#### 测试文件：`test_juicy_mixer_enums.gd`

```gdscript
# 测试中断策略枚举转换
func test_interruption_policy_name_conversion():
    # 测试所有策略的名称转换
    for policy in JuicyMixerEnms.InterruptionPolicy.values():
        var name = JuicyMixerEnms.get_interruption_policy_name(policy)
        var converted_policy = JuicyMixerEnms.get_interruption_policy_from_name(name)
        assert_eq(policy, converted_policy, "Policy conversion should be bidirectional")

func test_interruption_policy_descriptions():
    # 测试策略描述获取
    for policy in JuicyMixerEnms.InterruptionPolicy.values():
        var description = JuicyMixerEnms.get_interruption_policy_description(policy)
        assert_not_null(description, "Description should not be null")
        assert_false(description.is_empty(), "Description should not be empty")

func test_invalid_policy_handling():
    # 测试无效策略处理
    var invalid_policy = JuicyMixerEnms.get_interruption_policy_from_name("invalid_policy")
    assert_eq(JuicyMixerEnms.InterruptionPolicy.STACK, invalid_policy, "Should return default policy")
```

### 2.2 InterruptionState测试

#### 测试文件：`test_interruption_state.gd`

```gdscript
func test_active_context_management():
    var state = InterruptionState.new()
    var context_id = "test_context_1"
    
    # 测试添加活跃上下文
    state.add_active_context(context_id)
    assert_true(state.has_active_context(context_id), "Should have active context")
    assert_eq(1, state.get_active_context_count(), "Should have 1 active context")
    
    # 测试移除活跃上下文
    state.remove_active_context(context_id)
    assert_false(state.has_active_context(context_id), "Should not have active context")
    assert_eq(0, state.get_active_context_count(), "Should have 0 active contexts")

func test_queued_context_management():
    var state = InterruptionState.new()
    var context_id = "test_context_1"
    
    # 测试添加队列上下文
    state.add_queued_context(context_id)
    assert_true(state.has_queued_context(context_id), "Should have queued context")
    assert_eq(1, state.get_queued_context_count(), "Should have 1 queued context")
    
    # 测试获取下一个队列上下文
    var next_context = state.get_next_queued_context()
    assert_eq(context_id, next_context, "Should return correct context")
    
    # 测试弹出队列上下文
    var popped_context = state.pop_next_queued_context()
    assert_eq(context_id, popped_context, "Should pop correct context")
    assert_eq(0, state.get_queued_context_count(), "Should have 0 queued contexts")

func test_priority_queue_management():
    var state = InterruptionState.new()
    
    # 添加不同优先级的项目
    state.add_priority_queue_item("context_1", 5)
    state.add_priority_queue_item("context_2", 10)
    state.add_priority_queue_item("context_3", 7)
    
    # 验证优先级排序
    var first_item = state.get_next_priority_item()
    assert_eq("context_2", first_item.context_id, "Highest priority should be first")
    
    var second_item = state.get_next_priority_item()
    assert_eq("context_3", second_item.context_id, "Second highest priority should be second")

func test_transition_state_management():
    var state = InterruptionState.new()
    var context_id = "transition_context"
    
    # 测试设置过渡状态
    state.set_transition(context_id)
    assert_true(state.is_transitioning(), "Should be transitioning")
    assert_eq(context_id, state.transition_context, "Should have correct transition context")
    assert_eq(0.0, state.transition_progress, "Progress should start at 0")
    
    # 测试更新过渡进度
    state.update_transition_progress(0.5)
    assert_eq(0.5, state.transition_progress, "Progress should update correctly")
    
    # 测试过渡完成
    state.update_transition_progress(0.6)
    assert_true(state.is_transition_complete(), "Should be complete")
    
    # 测试清除过渡状态
    state.clear_transition()
    assert_false(state.is_transitioning(), "Should not be transitioning")
    assert_eq("", state.transition_context, "Transition context should be cleared")

func test_interruption_history_management():
    var state = InterruptionState.new()
    var record = {
        "timestamp": Time.get_ticks_msec() / 1000.0,
        "new_context": "new_context",
        "existing_context": "existing_context",
        "policy": JuicyMixerEnms.InterruptionPolicy.STACK,
        "target_id": 12345
    }
    
    # 测试添加中断记录
    state.add_interruption_record(record)
    var history = state.get_interruption_history()
    assert_eq(1, history.size(), "Should have 1 history record")
    assert_eq(record, history[0], "History record should match")
    
    # 测试清空历史记录
    state.clear_interruption_history()
    history = state.get_interruption_history()
    assert_eq(0, history.size(), "Should have 0 history records")
```

### 2.3 ChannelInterruptionConfig测试

#### 测试文件：`test_channel_interruption_config.gd`

```gdscript
func test_configuration_validation():
    var config = ChannelInterruptionConfig.new()
    
    # 测试有效配置
    config.channel_name = "test_channel"
    config.max_queue_size = 10
    config.transition_duration = 0.5
    config.max_history_size = 100
    
    var result = config.validate_config()
    assert_true(result.valid, "Valid configuration should pass validation")
    assert_eq(0, result.issues.size(), "Should have no issues")
    
    # 测试无效配置
    config.channel_name = ""
    config.max_queue_size = 0
    config.transition_duration = -1.0
    config.max_history_size = 5
    
    result = config.validate_config()
    assert_false(result.valid, "Invalid configuration should fail validation")
    assert_gt(result.issues.size(), 0, "Should have issues")

func test_policy_management():
    var config = ChannelInterruptionConfig.new()
    
    # 测试设置和获取策略
    config.set_policy(JuicyMixerEnms.InterruptionPolicy.RESTART)
    assert_eq(JuicyMixerEnms.InterruptionPolicy.RESTART, config.get_policy(), "Policy should match")
    
    # 测试设置和获取优先级
    config.set_channel_priority(10)
    assert_eq(10, config.get_channel_priority(), "Priority should match")
    
    # 测试设置和获取队列大小
    config.set_max_queue_size(20)
    assert_eq(20, config.get_max_queue_size(), "Max queue size should match")
    
    # 测试设置和获取过渡持续时间
    config.set_transition_duration(0.3)
    assert_eq(0.3, config.get_transition_duration(), "Transition duration should match")

func test_feature_management():
    var config = ChannelInterruptionConfig.new()
    
    # 测试启用/禁用功能
    config.enable_feature("priority_queue", false)
    assert_false(config.is_feature_enabled("priority_queue"), "Priority queue should be disabled")
    
    config.enable_feature("priority_queue", true)
    assert_true(config.is_feature_enabled("priority_queue"), "Priority queue should be enabled")
    
    config.enable_feature("interruption_history", true)
    assert_true(config.is_feature_enabled("interruption_history"), "Interruption history should be enabled")
    
    config.enable_feature("auto_cleanup", true)
    assert_true(config.is_feature_enabled("auto_cleanup"), "Auto cleanup should be enabled")

func test_configuration_serialization():
    var config = ChannelInterruptionConfig.new()
    config.channel_name = "test_channel"
    config.set_policy(JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE)
    config.set_channel_priority(15)
    config.set_max_queue_size(25)
    config.set_transition_duration(0.4)
    
    # 测试序列化
    var config_dict = config.get_config_dict()
    assert_eq("test_channel", config_dict["channel_name"], "Channel name should match")
    assert_eq("priority_override", config_dict["default_policy"], "Policy should match")
    assert_eq(15, config_dict["priority"], "Priority should match")
    
    # 测试反序列化
    var new_config = ChannelInterruptionConfig.new()
    var success = new_config.load_from_dict(config_dict)
    assert_true(success, "Should load successfully")
    assert_eq(config.channel_name, new_config.channel_name, "Channel name should match")
    assert_eq(config.get_policy(), new_config.get_policy(), "Policy should match")
```

### 2.4 JuicyInterruptionManager测试

#### 测试文件：`test_juicy_interruption_manager.gd`

```gdscript
func test_stack_interruption():
    var manager = JuicyInterruptionManager.new()
    var mock_context1 = _create_mock_context("context1")
    var mock_context2 = _create_mock_context("context2")
    
    # 测试堆叠中断
    var result = manager.handle_interruption(
        mock_context2.context_id, 
        mock_context1.context_id, 
        JuicyMixerEnms.InterruptionPolicy.STACK
    )
    
    assert_true(result, "Stack interruption should succeed")
    
    # 验证状态
    var state = manager.get_interruption_state(mock_context1.target)
    assert_true(state.has_active_context(mock_context2.context_id), "New context should be active")
    assert_true(state.has_queued_context(mock_context1.context_id), "Old context should be queued")

func test_restart_interruption():
    var manager = JuicyInterruptionManager.new()
    var mock_context1 = _create_mock_context("context1")
    var mock_context2 = _create_mock_context("context2")
    
    # 测试重启中断
    var result = manager.handle_interruption(
        mock_context2.context_id, 
        mock_context1.context_id, 
        JuicyMixerEnms.InterruptionPolicy.RESTART
    )
    
    assert_true(result, "Restart interruption should succeed")
    
    # 验证状态
    var state = manager.get_interruption_state(mock_context1.target)
    assert_true(state.has_active_context(mock_context2.context_id), "New context should be active")
    assert_eq(0, state.get_queued_context_count(), "Queue should be empty")

func test_ignore_interruption():
    var manager = JuicyInterruptionManager.new()
    var mock_context1 = _create_mock_context("context1")
    var mock_context2 = _create_mock_context("context2")
    
    # 测试忽略中断
    var result = manager.handle_interruption(
        mock_context2.context_id, 
        mock_context1.context_id, 
        JuicyMixerEnms.InterruptionPolicy.IGNORE
    )
    
    assert_true(result, "Ignore interruption should succeed")

func test_priority_override_interruption():
    var manager = JuicyInterruptionManager.new()
    var mock_context1 = _create_mock_context("context1")
    var mock_context2 = _create_mock_context("context2")
    
    # 设置全局优先级
    manager.set_global_priority("TestResource", 10)
    
    # 测试优先级覆盖中断
    var result = manager.handle_interruption(
        mock_context2.context_id, 
        mock_context1.context_id, 
        JuicyMixerEnms.InterruptionPolicy.PRIORITY_OVERRIDE
    )
    
    assert_true(result, "Priority override interruption should succeed")

func test_smooth_transition_interruption():
    var manager = JuicyInterruptionManager.new()
    var mock_context1 = _create_mock_context("context1")
    var mock_context2 = _create_mock_context("context2")
    
    # 测试平滑过渡中断
    var result = manager.handle_interruption(
        mock_context2.context_id, 
        mock_context1.context_id, 
        JuicyMixerEnms.InterruptionPolicy.SMOOTH_TRANSITION
    )
    
    assert_true(result, "Smooth transition interruption should succeed")
    
    # 验证过渡状态
    var state = manager.get_interruption_state(mock_context1.target)
    assert_true(state.is_transitioning(), "Should be transitioning")

func test_performance_stats():
    var manager = JuicyInterruptionManager.new()
    var mock_context1 = _create_mock_context("context1")
    var mock_context2 = _create_mock_context("context2")
    
    # 执行一些中断操作
    manager.handle_interruption(mock_context2.context_id, mock_context1.context_id, JuicyMixerEnms.InterruptionPolicy.STACK)
    
    # 验证性能统计
    var stats = manager.get_performance_stats()
    assert_gt(stats["interruption_count"], 0, "Should have interruption count")
    assert_gt(stats["total_interruption_time"], 0.0, "Should have total time")
    assert_gt(stats["average_interruption_time"], 0.0, "Should have average time")

func _create_mock_context(context_id: String) -> Dictionary:
    var mock_target = Node2D.new()
    var mock_resource = MockResource.new()
    
    return {
        "context_id": context_id,
        "target": mock_target,
        "resource": mock_resource
    }

class MockResource extends Resource:
    func get_class():
        return "TestResource"
```

### 2.5 InterruptionMiddleware测试

#### 测试文件：`test_interruption_middleware.gd`

```gdscript
func test_middleware_initialization():
    var middleware = InterruptionMiddleware.new()
    
    # 测试初始化
    var result = middleware.initialize()
    assert_true(result, "Middleware should initialize successfully")
    assert_not_null(middleware._interruption_manager, "Interruption manager should be created")
    assert_eq("InterruptionMiddleware", middleware.middleware_name, "Name should match")
    assert_eq(100, middleware.priority, "Priority should be 100")

func test_before_play_interruption_check():
    var middleware = InterruptionMiddleware.new()
    middleware.initialize()
    
    var mock_context = _create_mock_context("test_context")
    
    # 测试无中断情况
    var result = middleware.before_play(mock_context)
    assert_true(result, "Should allow play when no interruption needed")
    
    # 测试需要中断的情况
    # 这里需要模拟现有活跃上下文
    var result2 = middleware.before_play(mock_context)
    # 根据具体中断策略验证结果

func test_process_transition():
    var middleware = InterruptionMiddleware.new()
    middleware.initialize()
    
    var mock_context = _create_mock_context("test_context")
    var next_func = func(): return true
    
    # 测试处理阶段
    var result = middleware.process(mock_context, next_func)
    assert_true(result, "Process should succeed")

func test_context_lifecycle_events():
    var middleware = InterruptionMiddleware.new()
    middleware.initialize()
    
    var mock_context = _create_mock_context("test_context")
    
    # 测试上下文创建事件
    middleware.on_context_created(mock_context)
    
    # 测试上下文销毁事件
    middleware.on_context_destroyed(mock_context)
    
    # 测试上下文暂停事件
    middleware.on_context_paused(mock_context)
    
    # 测试上下文恢复事件
    middleware.on_context_resumed(mock_context)

func test_configuration_management():
    var middleware = InterruptionMiddleware.new()
    middleware.initialize()
    
    # 测试设置通道配置
    var config = ChannelInterruptionConfig.new()
    middleware.set_channel_config("test_channel", config)
    
    # 测试设置全局优先级
    middleware.set_global_priority("TestResource", 10)
    
    # 测试设置默认策略
    middleware.set_default_policy(JuicyMixerEnms.InterruptionPolicy.RESTART)

func _create_mock_context(context_id: String) -> Dictionary:
    var mock_target = Node2D.new()
    var mock_resource = MockResource.new()
    
    return {
        "context_id": context_id,
        "target": mock_target,
        "resource": mock_resource
    }

class MockResource extends Resource:
    func get_class():
        return "TestResource"
```

## 3. 集成测试计划

### 3.1 Director系统集成测试

#### 测试文件：`test_director_integration.gd`

```gdscript
func test_director_interruption_integration():
    # 创建Director实例
    var property_buffer = JuicyPropertyBuffer.new()
    var driver_registry = JuicyDriverRegistry.new()
    var middleware_pipeline = JuicyMiddlewarePipeline.new()
    var director = JuicyDirector.new(property_buffer, driver_registry, middleware_pipeline)
    
    # 初始化中间件管道
    middleware_pipeline.initialize()
    
    # 添加中断中间件
    var interruption_middleware = InterruptionMiddleware.new()
    middleware_pipeline.add_middleware(interruption_middleware)
    
    # 创建测试资源
    var resource1 = TestResource.new()
    var resource2 = TestResource.new()
    resource1.interruption_policy = "stack"
    resource2.interruption_policy = "stack"
    
    # 创建测试目标
    var target = Node2D.new()
    
    # 测试播放第一个效果
    var context_id1 = director.play(resource1, target)
    assert_false(context_id1.is_empty(), "First play should succeed")
    
    # 测试播放第二个效果（应该触发中断）
    var context_id2 = director.play(resource2, target)
    assert_false(context_id2.is_empty(), "Second play should succeed with interruption")
    
    # 验证中断状态
    var state = interruption_middleware.get_interruption_state(target)
    assert_not_null(state, "Should have interruption state")
    assert_true(state.has_active_context(context_id2), "Second context should be active")
    assert_true(state.has_queued_context(context_id1), "First context should be queued")

func test_director_middleware_hooks():
    # 测试中间件钩子触发
    var property_buffer = JuicyPropertyBuffer.new()
    var driver_registry = JuicyDriverRegistry.new()
    var middleware_pipeline = JuicyMiddlewarePipeline.new()
    var director = JuicyDirector.new(property_buffer, driver_registry, middleware_pipeline)
    
    # 初始化和添加中间件
    middleware_pipeline.initialize()
    var interruption_middleware = InterruptionMiddleware.new()
    middleware_pipeline.add_middleware(interruption_middleware)
    
    # 创建测试数据
    var resource = TestResource.new()
    var target = Node2D.new()
    
    # 测试播放和停止
    var context_id = director.play(resource, target)
    assert_false(context_id.is_empty(), "Play should succeed")
    
    var stop_result = director.stop(context_id)
    assert_true(stop_result, "Stop should succeed")
    
    # 测试暂停和恢复
    var context_id2 = director.play(resource, target)
    assert_false(context_id2.is_empty(), "Play should succeed")
    
    var pause_result = director.pause(context_id2)
    assert_true(pause_result, "Pause should succeed")
    
    var resume_result = director.resume(context_id2)
    assert_true(resume_result, "Resume should succeed")

class TestResource extends JuicyFeedbackResource:
    @export var interruption_policy: String = "stack"
    
    func create_drivers() -> Array:
        return []
    
    func get_interruption_policy() -> String:
        return interruption_policy
```

### 3.2 中间件管道集成测试

#### 测试文件：`test_middleware_pipeline_integration.gd`

```gdscript
func test_interruption_middleware_registration():
    var pipeline = JuicyMiddlewarePipeline.new()
    pipeline.initialize()
    
    # 测试注册中断中间件
    var middleware = InterruptionMiddleware.new()
    var result = pipeline.add_middleware(middleware)
    assert_true(result, "Should register interruption middleware successfully")
    
    # 验证中间件存在
    var retrieved_middleware = pipeline.get_middleware("InterruptionMiddleware")
    assert_not_null(retrieved_middleware, "Should retrieve middleware")
    assert_eq(middleware, retrieved_middleware, "Should be the same instance")
    
    # 验证中间件数量
    assert_eq(1, pipeline.get_middleware_count(), "Should have 1 middleware")
    
    # 验证中间件激活状态
    assert_true(pipeline.is_middleware_active("InterruptionMiddleware"), "Should be active")

func test_middleware_execution_order():
    var pipeline = JuicyMiddlewarePipeline.new()
    pipeline.initialize()
    
    # 添加多个中间件
    var validation_middleware = ValidationMiddleware.new()
    var interruption_middleware = InterruptionMiddleware.new()
    var logging_middleware = LoggingMiddleware.new()
    
    pipeline.add_middleware(validation_middleware)
    pipeline.add_middleware(interruption_middleware)
    pipeline.add_middleware(logging_middleware)
    
    # 验证执行顺序（按优先级）
    var middleware_list = pipeline.get_all_middleware()
    assert_eq(interruption_middleware, middleware_list[0], "Interruption middleware should execute first")

func test_middleware_pipeline_with_interruption():
    var pipeline = JuicyMiddlewarePipeline.new()
    pipeline.initialize()
    
    # 添加中断中间件
    var interruption_middleware = InterruptionMiddleware.new()
    pipeline.add_middleware(interruption_middleware)
    
    # 创建测试上下文
    var context = _create_test_context()
    
    # 测试管道执行
    var result = pipeline.execute(context)
    assert_true(result, "Pipeline execution should succeed")

func _create_test_context() -> Dictionary:
    var mock_target = Node2D.new()
    var mock_resource = TestResource.new()
    
    return {
        "context_id": "test_context",
        "resource": mock_resource,
        "target": mock_target,
        "owner": mock_target
    }

class TestResource extends JuicyFeedbackResource:
    func create_drivers() -> Array:
        return []
```

### 3.3 事件系统集成测试

#### 测试文件：`test_event_system_integration.gd`

```gdscript
func test_interruption_event_creation():
    # 测试中断事件创建
    var event = JuicyEvent.create_custom_event(null, {
        "type": "interruption_occurred",
        "new_context": "context_2",
        "existing_context": "context_1",
        "policy": "stack"
    })
    
    assert_not_null(event, "Event should be created")
    assert_eq(JuicyEvent.EventType.CUSTOM_EVENT, event.event_type, "Event type should match")
    assert_eq("interruption_occurred", event.event_data["type"], "Event data should match")

func test_interruption_event_handling():
    # 创建事件处理器
    var handler = InterruptionEventHandler.new()
    handler.supported_events = [JuicyEvent.EventType.CUSTOM_EVENT]
    
    # 创建中断事件
    var event = JuicyEvent.create_custom_event(null, {
        "type": "interruption_occurred",
        "new_context": "context_2",
        "existing_context": "context_1",
        "policy": "stack"
    })
    
    # 测试事件处理
    var result = handler.handle_event(event)
    assert_true(result, "Event should be handled successfully")

class InterruptionEventHandler extends JuicyEventHandler:
    func _init():
        handler_name = "InterruptionEventHandler"
        supported_events = [JuicyEvent.EventType.CUSTOM_EVENT]
    
    func handle_event(event) -> bool:
        if not can_handle(event):
            return false
        
        # 处理中断事件
        if event.event_data.has("type") and event.event_data["type"] == "interruption_occurred":
            print("Interruption occurred: ", event.event_data)
            return true
        
        return false
```

## 4. 性能测试计划

### 4.1 中断处理性能测试

#### 测试文件：`test_interruption_performance.gd`

```gdscript
func test_interruption_decision_performance():
    var manager = JuicyInterruptionManager.new()
    var iterations = 1000
    
    # 创建测试上下文
    var contexts = []
    for i in range(iterations):
        contexts.append(_create_mock_context("context_" + str(i)))
    
    # 测量中断决策时间
    var start_time = Time.get_ticks_usec()
    
    for i in range(iterations - 1):
        manager.handle_interruption(
            contexts[i + 1].context_id,
            contexts[i].context_id,
            JuicyMixerEnms.InterruptionPolicy.STACK
        )
    
    var end_time = Time.get_ticks_usec()
    var total_time = (end_time - start_time) / 1000.0  # 转换为毫秒
    var average_time = total_time / iterations
    
    print("Total interruption time: ", total_time, "ms")
    print("Average interruption time: ", average_time, "ms")
    
    # 验证性能要求
    assert_lt(average_time, 1.0, "Average interruption time should be less than 1ms")

func test_memory_usage():
    var manager = JuicyInterruptionManager.new()
    var initial_memory = OS.get_static_memory_usage_by_type()[typeof(manager)]
    
    # 创建大量中断状态
    var targets = []
    for i in range(100):
        var target = Node2D.new()
        targets.append(target)
        manager.get_interruption_state(target)
    
    var peak_memory = OS.get_static_memory_usage_by_type()[typeof(manager)]
    
    # 清理
    for target in targets:
        manager.clear_interruption_state(target)
    
    var final_memory = OS.get_static_memory_usage_by_type()[typeof(manager)]
    
    print("Initial memory: ", initial_memory, " bytes")
    print("Peak memory: ", peak_memory, " bytes")
    print("Final memory: ", final_memory, " bytes")
    
    # 验证内存使用合理
    var memory_increase = peak_memory - initial_memory
    assert_lt(memory_increase, 1024 * 100, "Memory increase should be less than 100KB")

func test_concurrent_interruptions():
    var manager = JuicyInterruptionManager.new()
    var target_count = 50
    var interruptions_per_target = 20
    
    # 创建多个目标
    var targets = []
    for i in range(target_count):
        targets.append(Node2D.new())
    
    # 并发中断测试
    var start_time = Time.get_ticks_usec()
    
    for target in targets:
        for i in range(interruptions_per_target):
            var context1 = _create_mock_context("context_" + str(i))
            var context2 = _create_mock_context("context_" + str(i + 1))
            context1.target = target
            context2.target = target
            
            manager.handle_interruption(
                context2.context_id,
                context1.context_id,
                JuicyMixerEnms.InterruptionPolicy.STACK
            )
    
    var end_time = Time.get_ticks_usec()
    var total_time = (end_time - start_time) / 1000.0
    
    print("Concurrent interruptions time: ", total_time, "ms")
    
    # 验证并发性能
    var total_interruptions = target_count * interruptions_per_target
    var average_time = total_time / total_interruptions
    assert_lt(average_time, 0.5, "Average concurrent interruption time should be less than 0.5ms")
```

### 4.2 系统性能基准测试

#### 测试文件：`test_system_performance_benchmark.gd`

```gdscript
func test_full_system_performance():
    # 初始化完整系统
    var juicy_mixer = JuicyMixer.instance
    
    # 创建测试资源
    var resources = []
    for i in range(100):
        var resource = TestResource.new()
        resource.interruption_policy = "stack"
        resources.append(resource)
    
    # 创建测试目标
    var targets = []
    for i in range(10):
        targets.append(Node2D.new())
    
    # 测量系统性能
    var start_time = Time.get_ticks_usec()
    
    # 执行大量播放操作
    var context_ids = []
    for i in range(100):
        var target = targets[i % targets.size()]
        var context_id = juicy_mixer.play(resources[i], target)
        context_ids.append(context_id)
    
    var end_time = Time.get_ticks_usec()
    var total_time = (end_time - start_time) / 1000.0
    var average_time = total_time / 100
    
    print("Full system play time: ", total_time, "ms")
    print("Average play time: ", average_time, "ms")
    
    # 验证系统性能
    assert_lt(average_time, 5.0, "Average play time should be less than 5ms")
    
    # 清理
    for context_id in context_ids:
        juicy_mixer.stop(context_id)

func test_interruption_overhead():
    # 比较有无中断系统的性能差异
    var juicy_mixer = JuicyMixer.instance
    
    # 创建测试资源
    var resource1 = TestResource.new()
    var resource2 = TestResource.new()
    resource1.interruption_policy = "ignore"  # 最小中断开销
    resource2.interruption_policy = "ignore"
    
    var target = Node2D.new()
    
    # 测试无中断开销
    var start_time = Time.get_ticks_usec()
    for i in range(1000):
        var context_id = juicy_mixer.play(resource1, target)
        juicy_mixer.stop(context_id)
    var time_without_interruption = (Time.get_ticks_usec() - start_time) / 1000.0
    
    # 测试有中断开销
    start_time = Time.get_ticks_usec()
    for i in range(1000):
        var context_id1 = juicy_mixer.play(resource1, target)
        var context_id2 = juicy_mixer.play(resource2, target)
        juicy_mixer.stop(context_id1)
        juicy_mixer.stop(context_id2)
    var time_with_interruption = (Time.get_ticks_usec() - start_time) / 1000.0
    
    var overhead = time_with_interruption - time_without_interruption
    var overhead_percentage = (overhead / time_without_interruption) * 100
    
    print("Time without interruption: ", time_without_interruption, "ms")
    print("Time with interruption: ", time_with_interruption, "ms")
    print("Interruption overhead: ", overhead, "ms (", overhead_percentage, "%)")
    
    # 验证中断开销可接受
    assert_lt(overhead_percentage, 20.0, "Interruption overhead should be less than 20%")

class TestResource extends JuicyFeedbackResource:
    @export var interruption_policy: String = "stack"
    
    func create_drivers() -> Array:
        return []
    
    func get_interruption_policy() -> String:
        return interruption_policy
```

## 5. 端到端测试计划

### 5.1 完整中断流程测试

#### 测试文件：`test_end_to_end_interruption.gd`

```gdscript
func test_stack_interruption_flow():
    # 初始化系统
    var juicy_mixer = JuicyMixer.instance
    
    # 创建测试资源
    var resource1 = TestResource.new()
    var resource2 = TestResource.new()
    resource1.interruption_policy = "stack"
    resource2.interruption_policy = "stack"
    
    # 创建测试目标
    var target = Node2D.new()
    
    # 测试堆叠中断流程
    var context_id1 = juicy_mixer.play(resource1, target)
    assert_false(context_id1.is_empty(), "First play should succeed")
    
    var context_id2 = juicy_mixer.play(resource2, target)
    assert_false(context_id2.is_empty(), "Second play should succeed with stack interruption")
    
    # 验证中断状态
    var middleware = juicy_mixer.get_middleware("InterruptionMiddleware")
    var state = middleware.get_interruption_state(target)
    assert_not_null(state, "Should have interruption state")
    assert_true(state.has_active_context(context_id2), "Second context should be active")
    assert_true(state.has_queued_context(context_id1), "First context should be queued")
    
    # 停止第二个效果，验证第一个效果恢复
    juicy_mixer.stop(context_id2)
    # 这里需要等待一帧让系统处理
    await get_tree().process_frame
    
    # 验证第一个效果是否恢复
    var context1 = juicy_mixer.get_context(context_id1)
    assert_not_null(context1, "First context should still exist")
    # 根据具体实现验证恢复逻辑

func test_priority_override_flow():
    # 初始化系统
    var juicy_mixer = JuicyMixer.instance
    
    # 创建不同优先级的测试资源
    var low_priority_resource = TestResource.new()
    var high_priority_resource = TestResource.new()
    low_priority_resource.interruption_policy = "priority_override"
    high_priority_resource.interruption_policy = "priority_override"
    low_priority_resource.priority = 1
    high_priority_resource.priority = 10
    
    # 创建测试目标
    var target = Node2D.new()
    
    # 测试优先级覆盖流程
    var context_id1 = juicy_mixer.play(low_priority_resource, target)
    assert_false(context_id1.is_empty(), "Low priority play should succeed")
    
    var context_id2 = juicy_mixer.play(high_priority_resource, target)
    assert_false(context_id2.is_empty(), "High priority play should succeed with override")
    
    # 验证中断状态
    var middleware = juicy_mixer.get_middleware("InterruptionMiddleware")
    var state = middleware.get_interruption_state(target)
    assert_not_null(state, "Should have interruption state")
    assert_true(state.has_active_context(context_id2), "High priority context should be active")
    # 低优先级上下文应该被停止或排队

func test_smooth_transition_flow():
    # 初始化系统
    var juicy_mixer = JuicyMixer.instance
    
    # 创建测试资源
    var resource1 = TestResource.new()
    var resource2 = TestResource.new()
    resource1.interruption_policy = "smooth_transition"
    resource2.interruption_policy = "smooth_transition"
    
    # 创建测试目标
    var target = Node2D.new()
    
    # 测试平滑过渡流程
    var context_id1 = juicy_mixer.play(resource1, target)
    assert_false(context_id1.is_empty(), "First play should succeed")
    
    var context_id2 = juicy_mixer.play(resource2, target)
    assert_false(context_id2.is_empty(), "Second play should succeed with smooth transition")
    
    # 验证过渡状态
    var middleware = juicy_mixer.get_middleware("InterruptionMiddleware")
    var state = middleware.get_interruption_state(target)
    assert_not_null(state, "Should have interruption state")
    assert_true(state.is_transitioning(), "Should be transitioning")
    
    # 等待过渡完成
    await get_tree().create_timer(0.5).timeout
    
    # 验证过渡完成后的状态
    assert_false(state.is_transitioning(), "Transition should be complete")
    assert_true(state.has_active_context(context_id2), "New context should be active")

func test_complex_interruption_scenario():
    # 初始化系统
    var juicy_mixer = JuicyMixer.instance
    
    # 创建多个测试资源
    var resources = []
    for i in range(5):
        var resource = TestResource.new()
        resource.interruption_policy = ["stack", "restart", "ignore", "priority_override", "smooth_transition"][i]
        resource.priority = i + 1
        resources.append(resource)
    
    # 创建多个测试目标
    var targets = []
    for i in range(3):
        targets.append(Node2D.new())
    
    # 执行复杂的中断场景
    var context_ids = []
    
    # 在不同目标上播放效果
    for i in range(3):
        var context_id = juicy_mixer.play(resources[i], targets[i])
        context_ids.append(context_id)
    
    # 在同一目标上播放不同策略的效果
    for i in range(2):
        var context_id = juicy_mixer.play(resources[i + 3], targets[0])
        context_ids.append(context_id)
    
    # 验证系统状态
    var middleware = juicy_mixer.get_middleware("InterruptionMiddleware")
    for target in targets:
        var state = middleware.get_interruption_state(target)
        if state:
            print("Target ", target.get_instance_id(), " state: ", state.get_state_summary())
    
    # 清理
    for context_id in context_ids:
        juicy_mixer.stop(context_id)

class TestResource extends JuicyFeedbackResource:
    @export var interruption_policy: String = "stack"
    @export var priority: int = 0
    
    func create_drivers() -> Array:
        return []
    
    func get_interruption_policy() -> String:
        return interruption_policy
    
    func get_priority() -> int:
        return priority
```

## 6. 测试执行计划

### 6.1 测试环境准备
1. **测试框架设置** - 配置Godot测试环境
2. **测试数据准备** - 创建测试资源和场景
3. **性能基准建立** - 建立性能基准线
4. **测试工具开发** - 开发测试辅助工具

### 6.2 测试执行顺序
1. **单元测试** - 验证各组件独立功能
2. **集成测试** - 验证组件间交互
3. **性能测试** - 验证性能指标
4. **端到端测试** - 验证完整场景

### 6.3 测试报告
1. **测试覆盖率报告** - 统计测试覆盖范围
2. **性能测试报告** - 分析性能数据
3. **缺陷报告** - 记录发现的问题
4. **测试总结报告** - 综合评估测试结果

## 7. 测试验收标准

### 7.1 功能验收标准
- 所有中断策略正确执行
- 中断状态管理准确
- 事件系统正常工作
- 配置系统功能完整

### 7.2 性能验收标准
- 中断决策时间 < 1ms
- 内存增长 < 100KB（100个并发中断）
- 系统开销 < 20%
- 并发处理能力 > 50个目标

### 7.3 稳定性验收标准
- 连续运行24小时无崩溃
- 内存泄漏检测通过
- 边界条件处理正确
- 错误恢复机制有效

## 8. 测试时间安排

### 第1天：单元测试开发
- JuicyMixerEnums测试
- InterruptionState测试
- ChannelInterruptionConfig测试

### 第2天：单元测试开发（续）
- JuicyInterruptionManager测试
- InterruptionMiddleware测试

### 第3天：集成测试开发
- Director系统集成测试
- 中间件管道集成测试
- 事件系统集成测试

### 第4天：性能测试开发
- 中断处理性能测试
- 系统性能基准测试
- 并发性能测试

### 第5天：端到端测试和报告
- 完整中断流程测试
- 复杂场景测试
- 测试报告生成

**总计：5天**