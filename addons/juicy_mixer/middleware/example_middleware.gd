# ExampleMiddleware - 示例中间件
# 演示如何使用JuicyMiddleware基类创建自定义中间件

class_name ExampleMiddleware
extends JuicyMiddleware

# =============================================================================
# 中间件元信息
# =============================================================================

func _init():
	# 设置中间件基本信息
	middleware_name = "ExampleMiddleware"
	middleware_version = "1.0.0"
	priority = 500  # 中等优先级
	description = "这是一个示例中间件，演示如何使用JuicyMiddleware基类"
	author = "JuicyMixer Team"
	tags = ["example", "demo", "tutorial"]

# =============================================================================
# 核心接口实现
# =============================================================================

## 实现处理逻辑
func process(context: JuicyContext, next: Callable) -> bool:
	_log_debug("开始处理Context", {"context_id": context.context_id, "progress": context.progress})
	
	# 示例：在处理前修改Context的某些属性
	if context.target:
		# 示例：添加一个简单的偏移效果
		var offset = Vector2(10, 10) * context.progress
		context.target.position += offset
		
		_log_debug("应用偏移效果", {"offset": offset, "new_position": context.target.position})
	
	# 调用下一个中间件
	var result = next.call()
	
	if result:
		_log_debug("处理完成", {"context_id": context.context_id})
	else:
		_log_warning("处理被中断", {"context_id": context.context_id})
	
	return result

## 实现清理逻辑
func cleanup(context: JuicyContext) -> void:
	_log_debug("清理中间件资源", {"context_id": context.context_id})
	
	# 示例：清理特定的上下文数据
	if context.target:
		# 恢复原始位置（在实际应用中，这可能需要更复杂的逻辑）
		var original_pos = Vector2.ZERO  # 这里应该从缓存中获取原始值
		context.target.position = original_pos

## 实现Context创建钩子
func on_context_created(context: JuicyContext) -> void:
	_log_debug("Context创建，初始化中间件数据", {"context_id": context.context_id})
	
	# 示例：初始化中间件特定的上下文数据
	context.set_middleware_data(middleware_name, "initialized", true)
	context.set_middleware_data(middleware_name, "creation_time", Time.get_ticks_msec())

## 实现Context销毁钩子
func on_context_destroyed(context: JuicyContext) -> void:
	_log_debug("Context销毁，清理中间件数据", {"context_id": context.context_id})
	
	# 示例：清理中间件特定的上下文数据
	context.set_middleware_data(middleware_name, "initialized", null)
	context.set_middleware_data(middleware_name, "creation_time", null)

## 实现Context暂停钩子
func on_context_paused(context: JuicyContext) -> void:
	_log_debug("Context暂停，暂停中间件逻辑", {"context_id": context.context_id})
	
	# 示例：暂停特定的处理逻辑
	context.set_middleware_data(middleware_name, "paused", true)

## 实现Context恢复钩子
func on_context_resumed(context: JuicyContext) -> void:
	_log_debug("Context恢复，恢复中间件逻辑", {"context_id": context.context_id})
	
	# 示例：恢复特定的处理逻辑
	context.set_middleware_data(middleware_name, "paused", false)

# =============================================================================
# 验证接口实现
# =============================================================================

## 实现Context数据验证
func _validate_required_context_data(context: JuicyContext) -> bool:
	# 示例：验证Context是否包含必需的数据
	if not context.resource:
		_log_error("Context缺少resource数据", {"context_id": context.context_id})
		return false
	
	if not context.target:
		_log_error("Context缺少target数据", {"context_id": context.context_id})
		return false
	
	return true

## 实现目标节点验证
func _validate_target_node(context: JuicyContext) -> bool:
	# 示例：验证目标节点是否支持position属性
	if not context.target:
		return false
	
	if not "position" in context.target:
		_log_warning("目标节点不支持position属性", {
			"context_id": context.context_id,
			"target_type": context.target.get_class()
		})
		return false
	
	return true

# =============================================================================
# 配置管理
# =============================================================================

## 设置默认配置
func _setup_default_configuration() -> void:
	# 调用父类的默认配置设置
	super._setup_default_configuration()
	
	# 添加中间件特定的默认配置
	_default_configuration["enable_offset_effect"] = true
	_default_configuration["offset_multiplier"] = 1.0
	_default_configuration["log_details"] = false
	
	# 更新配置模式
	set_configuration_schema({
		"enable_performance_monitoring": {"type": "bool"},
		"enable_debug_logging": {"type": "bool"},
		"priority": {"type": "int"},
		"max_log_entries": {"type": "int"},
		"enable_offset_effect": {"type": "bool"},
		"offset_multiplier": {"type": "float"},
		"log_details": {"type": "bool"}
	})

# =============================================================================
# 工具方法
# =============================================================================

## 获取中间件特定的配置值
func get_offset_multiplier() -> float:
	return _configuration.get("offset_multiplier", 1.0)

## 检查是否启用偏移效果
func is_offset_effect_enabled() -> bool:
	return _configuration.get("enable_offset_effect", true)

## 设置偏移乘数
func set_offset_multiplier(multiplier: float) -> void:
	_configuration["offset_multiplier"] = multiplier
	_log_debug("偏移乘数已更新", {"multiplier": multiplier})