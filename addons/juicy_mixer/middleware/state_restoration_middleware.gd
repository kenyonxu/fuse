# StateRestorationMiddleware - 状态还原中间件
# 在Director执行流程中自动管理对象属性状态快照和还原
# 职责：在效果执行前后自动创建状态快照，在效果完成或中断时自动还原状态
# 优先级：850（在验证之后，中断之前，通道管理之前，时间缩放之前，LOD优化之后）
# 集成：与PropertyStateManager协作管理对象属性状态

class_name StateRestorationMiddleware
extends JuicyMiddleware

var _state_manager: PropertyStateManager

# =============================================================================
# 生命周期方法
# =============================================================================

func _init():
	middleware_name = "StateRestorationMiddleware"
	priority = 850
	description = "Automatically manages object property state snapshots and restoration during effect execution"
	author = "JuicyMixer Team"
	tags = ["state", "restoration", "snapshot", "property", "backup"]

# =============================================================================
# 中间件接口实现
# =============================================================================

func initialize(config: Dictionary = {}) -> bool:
	"""
	初始化中间件
	
	@param config: 配置字典
	@return: 初始化是否成功
	"""
	var result = super.initialize(config)
	if result:
		_state_manager = PropertyStateManager.new()
		_setup_default_configuration()
	return result

func before_play(context: JuicyContext) -> bool:
	"""
	在播放前创建状态快照
	
	@param context: 上下文
	@return: 是否允许播放
	"""
	if not context or not context.target:
		_log_warning("Context or target is null, skipping state snapshot")
		return true  # 允许播放，让其他中间件处理这个问题
	
	# 获取状态配置
	var config = _get_state_config(context)
	
	if config.auto_snapshot:
		_state_manager.create_snapshot(
			context.target, 
			context.context_id,
			{"phase": "before_play", "resource": context.resource.resource_name if context.resource else "unknown"}
		)
		_log_debug("State snapshot created before play", {
			"context_id": context.context_id,
			"target": context.target.name if context.target else "unknown"
		})
	
	return true

func after_play(context: JuicyContext) -> void:
	"""
	在播放后创建状态快照
	
	@param context: 上下文
	"""
	if not context or not context.target:
		return
	
	# 获取状态配置
	var config = _get_state_config(context)
	
	if config.auto_snapshot:
		_state_manager.create_snapshot(
			context.target, 
			context.context_id,
			{"phase": "after_play", "resource": context.resource.resource_name if context.resource else "unknown"}
		)
		_log_debug("State snapshot created after play", {
			"context_id": context.context_id,
			"target": context.target.name if context.target else "unknown"
		})

func before_stop(context: JuicyContext) -> void:
	"""
	在停止前创建状态快照
	
	@param context: 上下文
	"""
	if not context or not context.target:
		return
	
	# 获取状态配置
	var config = _get_state_config(context)
	
	if config.auto_snapshot:
		_state_manager.create_snapshot(
			context.target, 
			context.context_id,
			{"phase": "before_stop", "resource": context.resource.resource_name if context.resource else "unknown"}
		)
		_log_debug("State snapshot created before stop", {
			"context_id": context.context_id,
			"target": context.target.name if context.target else "unknown"
		})

func after_stop(context: JuicyContext) -> void:
	"""
	在停止后自动还原状态
	
	@param context: 上下文
	"""
	if not context or not context.target:
		_log_warning("Invalid context or target in after_stop", {"context": context})
		return
	
	# 获取状态配置
	var config = _get_state_config(context)
	
	if not config.auto_snapshot:
		# 调试输出已移除以提高性能
		return
	
	# 触发还原前事件
	_trigger_restoration_hooks("before_restoration", context)
	
	# 根据阻塞模式选择还原方式
	if config.blocking_mode:
		# 阻塞模式：等待还原完成
		_perform_blocking_restoration(context, config)
	else:
		# 非阻塞模式：启动后台还原
		_perform_nonblocking_restoration(context, config)

func _perform_blocking_restoration(context: JuicyContext, config: RestorationConfig) -> void:
	"""
	执行阻塞模式的状态还原
	
	@param context: 上下文
	@param config: 状态配置
	"""
	var restoration_result = await _perform_state_restoration_impl(context, config, true)
	
	# 处理还原结果
	_handle_restoration_result(context, restoration_result)
	
	# 触发还原后事件
	_trigger_restoration_hooks("after_restoration", context, restoration_result)

func _perform_nonblocking_restoration(context: JuicyContext, config: RestorationConfig) -> void:
	"""
	执行非阻塞模式的状态还原
	
	@param context: 上下文
	@param config: 状态配置
	"""
	# 使用非阻塞版本的状态还原
	var restoration_result = _perform_state_restoration_nonblocking(context, config)
	
	# 处理还原结果（立即返回的结果）
	_handle_restoration_result(context, restoration_result)
	
	# 触发还原后事件（表示还原已启动）
	_trigger_restoration_hooks("after_restoration", context, restoration_result)

func _start_background_restoration_task(context: JuicyContext, config: RestorationConfig) -> void:
	"""
	启动后台还原任务
	
	@param context: 上下文
	@param config: 状态配置
	"""
	# 创建后台任务
	var background_task = func():
		var restoration_result = await _perform_state_restoration_impl(context, config, false)
		# 还原完成后处理结果
		_handle_restoration_result(context, restoration_result)
		# 触发最终完成事件
		_trigger_restoration_hooks("background_restoration_completed", context, restoration_result)
	
	# 在后台执行任务，使用call_deferred避免阻塞当前帧
	background_task.call_deferred()

func _perform_state_restoration(context: JuicyContext, config: RestorationConfig) -> Dictionary:
	"""
	执行状态还原操作（阻塞版本）
	
	@param context: 上下文
	@param config: 状态配置
	@return: 还原结果字典
	"""
	return await _perform_state_restoration_impl(context, config, true)

func _perform_state_restoration_nonblocking(context: JuicyContext, config: RestorationConfig) -> Dictionary:
	"""
	执行状态还原操作（非阻塞版本）
	
	@param context: 上下文
	@param config: 状态配置
	@return: 还原结果字典（立即返回，后台执行）
	"""
	# 启动后台任务执行实际的还原操作
	var background_task = func():
		var result = await _perform_state_restoration_impl(context, config, false)
		# 还原完成后处理结果
		_handle_restoration_result(context, result)
		_trigger_restoration_hooks("background_restoration_completed", context, result)
	
	# 立即返回初始结果，表示还原已启动
	background_task.call_deferred()
	
	return {
		"success": true,
		"restoration_type": "non_blocking_auto_restore",
		"error": null,
		"warnings": [],
		"validation_passed": true,
		"fallback_used": false,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"non_blocking": true,
		"background_task_started": true
	}

func _perform_state_restoration_impl(context: JuicyContext, config: RestorationConfig, is_blocking: bool) -> Dictionary:
	"""
	执行状态还原操作的具体实现
	
	@param context: 上下文
	@param config: 状态配置
	@param is_blocking: 是否为阻塞模式
	@return: 还原结果字典
	"""
	var result = {
		"success": false,
		"restoration_type": "auto_restore",
		"error": null,
		"warnings": [],
		"validation_passed": true,
		"fallback_used": false,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	# 首先验证当前状态完整性
	if config.validate_restoration and _state_manager:
		var validation = _state_manager.validate_state_integrity(context.target, context.context_id)
		result.validation_passed = validation.is_valid
		if not validation.is_valid:
			result.warnings.append_array(validation.warnings)
	
	# 尝试标准自动还原
	var restored = false
	if _state_manager:
		restored = await _state_manager.auto_restore_state(context.target, context.context_id)
		result.success = restored
	else:
		result.success = false
		result.error = "State manager not available"
	
	if restored:
		result.restoration_type = "auto_restore"
		# 调试输出已移除以提高性能
	else:
		# 标准还原失败，尝试备用策略
		# 调试输出已移除以提高性能
		
		var fallback_result = await _attempt_fallback_restoration(context, config)
		result.success = fallback_result.success
		result.fallback_used = true
		result.restoration_type = fallback_result.strategy
		result.error = fallback_result.error
		# 调试输出已移除以提高性能
	
	return result

func _attempt_fallback_restoration(context: JuicyContext, config: RestorationConfig) -> Dictionary:
	"""
	尝试备用还原策略
	
	@param context: 上下文
	@param config: 状态配置
	@return: 备用还原结果
	"""
	var fallback_strategies = [
		"emergency_restore",
		"selective_restore",
		"graceful_degradation",
		"fail_safe"
	]
	
	for strategy in fallback_strategies:
		var result = await _execute_fallback_strategy(context, strategy)
		if result.success:
			return result
		
		# 调试输出已移除以提高性能
	
	# 所有策略都失败
	return {
		"success": false,
		"strategy": "all_failed",
		"error": "All fallback restoration strategies exhausted"
	}

func _execute_fallback_strategy(context: JuicyContext, strategy: String) -> Dictionary:
	"""
	执行特定的备用还原策略
	
	@param context: 上下文
	@param strategy: 策略名称
	@return: 执行结果
	"""
	var result = {
		"success": false,
		"strategy": strategy,
		"error": null
	}
	
	if not _state_manager:
		result.error = "State manager not available"
		return result
	
	match strategy:
		"emergency_restore":
			# 紧急恢复到最新快照
			var restored = await _state_manager.emergency_restore(context.target)
			result.success = restored
			if not restored:
				result.error = "Emergency restore failed"
				
		"selective_restore":
			# 选择性恢复关键属性
			var dummy_analysis = {"failure_type": "fallback_restore"}
			var restored = _state_manager._perform_selective_restore(context.target, context.context_id, dummy_analysis)
			result.success = restored
			if not restored:
				result.error = "Selective restore failed"
				
		"graceful_degradation":
			# 优雅降级到安全状态
			var restored = _state_manager._perform_graceful_degradation(context.target, context.context_id)
			result.success = restored
			if not restored:
				result.error = "Graceful degradation failed"
				
		"fail_safe":
			# 故障安全恢复
			var restored = _state_manager._perform_fail_safe_restore(context.target, context.context_id)
			result.success = restored
			if not restored:
				result.error = "Fail-safe restore failed"
				
		_:
			result.error = "Unknown fallback strategy: " + strategy
	
	return result

func _handle_restoration_result(context: JuicyContext, result: Dictionary) -> void:
	"""
	处理还原结果
	
	@param context: 上下文
	@param result: 还原结果
	"""
	# 记录详细的还原结果
	var log_data = {
		"context_id": context.context_id,
		"target": context.target.name if context.target else "unknown",
		"success": result.success,
		"restoration_type": result.restoration_type,
		"validation_passed": result.validation_passed,
		"fallback_used": result.fallback_used,
		"warnings": result.warnings.size()
	}
	
	if result.error:
		log_data["error"] = result.error
	
	# 简化日志记录，移除详细调试输出
	if not result.success:
		_log_error("State restoration failed", {"context_id": context.context_id})
	
	# 更新统计信息
	if _state_manager:
		var stats = _state_manager.get_statistics()
		log_data["stats"] = stats
	
	# 触发状态还原事件
	_emit_restoration_event(context, result)

func _trigger_restoration_hooks(hook_type: String, context: JuicyContext, restoration_result: Dictionary = {}) -> void:
	"""
	触发还原钩子
	
	@param hook_type: 钩子类型
	@param context: 上下文
	@param restoration_result: 还原结果（可选）
	"""
	var hook_data = {
		"hook_type": hook_type,
		"context_id": context.context_id,
		"target_id": context.target.get_instance_id() if context.target else -1,
		"target_name": context.target.name if context.target else "unknown",
		"timestamp": Time.get_ticks_msec() / 1000.0
	}
	
	# 添加还原结果信息（如果有）
	if restoration_result:
		hook_data["restoration_result"] = restoration_result
	
	# 调用注册的钩子函数
	_call_registered_hooks(hook_type, context, restoration_result)
	# 调试输出已移除以提高性能

func _call_registered_hooks(hook_type: String, context: JuicyContext, restoration_result: Dictionary = {}) -> void:
	"""
	调用注册的钩子函数
	
	@param hook_type: 钩子类型
	@param context: 上下文
	@param restoration_result: 还原结果
	"""
	# 这里可以实现钩子注册和调用机制
	# 暂时使用事件系统作为替代
	pass

func _emit_restoration_event(context: JuicyContext, result: Dictionary) -> void:
	"""
	发出状态还原事件
	
	@param context: 上下文
	@param result: 还原结果
	"""
	var event_data = {
		"event_type": "state_restoration_completed",
		"context_id": context.context_id,
		"target_id": context.target.get_instance_id() if context.target else -1,
		"success": result.success,
		"restoration_type": result.restoration_type,
		"fallback_used": result.fallback_used,
		"validation_passed": result.validation_passed,
		"timestamp": result.timestamp
	}
	
	# 添加错误信息（如果有）
	if result.error:
		event_data["error"] = result.error
	
	# 添加警告信息
	if result.warnings.size() > 0:
		event_data["warnings"] = result.warnings
	
	# 发出事件 - 调试输出已移除

func process(context: JuicyContext, next: Callable) -> bool:
	"""
	处理阶段，每帧调用
	
	@param context: 上下文
	@param next: 下一个中间件的回调函数
	@return: 执行是否成功
	"""
	# 处理自动快照逻辑
	if _state_manager:
		# 使用实际的时间增量
		var delta = 0.016  # 默认60fps
		if context and context.has_method("get_delta"):
			delta = context.get_delta()
		
		_state_manager.process_auto_snapshots(delta)
		
		# 验证状态完整性（可选，基于配置）
		if context and context.target:
			var config = _get_state_config(context)
			if config.validate_restoration:
				var validation = _state_manager.validate_state_integrity(context.target, context.context_id)
				if not validation.is_valid:
					_log_warning("State integrity validation failed for context: " + context.context_id, {
						"errors": validation.errors,
						"warnings": validation.warnings
					})
	
	# 继续执行下一个中间件
	return next.call()

func cleanup(context: JuicyContext) -> void:
	"""
	清理阶段，在效果结束时调用
	
	@param context: 上下文
	"""
	if context and context.target:
		# 清理特定目标的状态快照
		_state_manager.clear_snapshots_for_target(context.target)
		# 调试输出已移除以提高性能

func destroy() -> void:
	"""
	销毁中间件
	"""
	if _state_manager:
		_state_manager.clear_all_snapshots()
		_state_manager = null
	
	super.destroy()

# =============================================================================
# 配置管理
# =============================================================================

func _setup_default_configuration() -> void:
	"""
	设置默认配置
	"""
	_default_configuration = {
		"enable_auto_snapshot": true,
		"enable_debug_logging": false,
		"enable_state_validation": false,
		"priority": 850,
		"max_snapshots_per_target": 10,
		"snapshot_frequency": 0.1,
		"default_restoration_mode": "ease",
		"default_restoration_duration": 0.2,
		"enable_emergency_restore": true,
		"max_emergency_targets": 50
	}
	
	# 设置配置模式
	set_configuration_schema({
		"enable_auto_snapshot": {"type": "bool"},
		"enable_debug_logging": {"type": "bool"},
		"enable_state_validation": {"type": "bool"},
		"priority": {"type": "int"},
		"max_snapshots_per_target": {"type": "int"},
		"snapshot_frequency": {"type": "float"},
		"default_restoration_mode": {"type": "string"},
		"default_restoration_duration": {"type": "float"},
		"enable_emergency_restore": {"type": "bool"},
		"max_emergency_targets": {"type": "int"}
	})

func _get_state_config(context: JuicyContext) -> RestorationConfig:
	"""
	从资源或通道获取状态配置
	
	@param context: 上下文
	@return: 状态还原配置
	"""
	if not context:
		return _create_default_config()
	
	# 从资源获取状态配置
	if context.resource and context.resource.has_method("get_restoration_config"):
		var config = context.resource.get_restoration_config()
		if config:
			return config
	
	# 从通道获取状态配置
	var channel_name = ""
	if context.resource and context.resource.has_method("get_channel"):
		channel_name = context.resource.get_channel()
	
	var channel_config = _get_channel_config(channel_name)
	if channel_config != null:
		return channel_config
	
	# 使用默认配置
	return _create_default_config()

func _create_default_config() -> RestorationConfig:
	"""
	创建默认配置
	
	@return: 默认状态还原配置
	"""
	var default_config = RestorationConfig.new()
	var config_dict = get_configuration()
	
	default_config.auto_snapshot = config_dict.get("enable_auto_snapshot", true)
	default_config.snapshot_frequency = config_dict.get("snapshot_frequency", 0.1)
	default_config.max_snapshots_per_target = config_dict.get("max_snapshots_per_target", 10)
	default_config.validate_restoration = config_dict.get("enable_state_validation", false)
	
	# 设置默认还原模式
	var mode_name = config_dict.get("default_restoration_mode", "ease")
	default_config.default_restoration_mode = JuicyMixerEnums.get_restoration_mode_from_name(mode_name)
	default_config.default_restoration_duration = config_dict.get("default_restoration_duration", 0.2)
	
	return default_config

func _get_channel_config(channel: String) -> RestorationConfig:
	"""
	获取通道配置
	
	@param channel: 通道名称
	@return: 状态还原配置，如果不存在则返回null
	"""
	# 这里可以实现从全局配置或通道管理器获取配置的逻辑
	# 暂时返回null，使用默认配置
	return null

# =============================================================================
# 上下文生命周期事件处理
# =============================================================================

func on_context_created(context: JuicyContext) -> void:
	"""
	上下文创建时调用
	
	@param context: 新创建的上下文
	"""
	# 调试输出已移除以提高性能

func on_context_destroyed(context: JuicyContext) -> void:
	"""
	上下文销毁时调用
	
	@param context: 即将被销毁的上下文
	"""
	if context and context.target:
		# 清理相关的状态快照
		_state_manager.clear_snapshots_for_target(context.target)
	
	# 调试输出已移除以提高性能

# =============================================================================
# 状态查询
# =============================================================================

func get_state_manager() -> PropertyStateManager:
	"""
	获取状态管理器实例
	
	@return: PropertyStateManager实例
	"""
	return _state_manager

func get_state_statistics() -> Dictionary:
	"""
	获取状态管理统计信息
	
	@return: 统计信息字典
	"""
	if _state_manager:
		return _state_manager.get_statistics()
	return {}

# =============================================================================
# 性能监控
# =============================================================================

func get_performance_stats() -> Dictionary:
	"""
	获取性能统计信息
	
	@return: 性能统计字典
	"""
	var base_stats = super.get_performance_stats()
	var state_stats = get_state_statistics()
	
	# 合并统计信息
	var combined_stats = base_stats.duplicate()
	for key in state_stats.keys():
		combined_stats["state_" + key] = state_stats[key]
	
	# 添加中间件特定的性能指标
	combined_stats["auto_snapshot_enabled"] = _is_auto_snapshot_enabled()
	combined_stats["validation_enabled"] = _is_validation_enabled()
	combined_stats["total_configured_contexts"] = _get_configured_contexts_count()
	
	return combined_stats

func _is_auto_snapshot_enabled() -> bool:
	# 检查是否启用了自动快照
	var config_dict = get_configuration()
	return config_dict.get("enable_auto_snapshot", true)

func _is_validation_enabled() -> bool:
	# 检查是否启用了状态验证
	var config_dict = get_configuration()
	return config_dict.get("enable_state_validation", false)

func _get_configured_contexts_count() -> int:
	# 获取已配置状态的上下文数量
	if _state_manager:
		return _state_manager._restoration_configs.size()
	return 0

func handle_runtime_error(context: JuicyContext, error_type: String, error_message: String) -> bool:
	"""
	处理运行时错误
	
	@param context: 上下文
	@param error_type: 错误类型
	@param error_message: 错误消息
	@return: 是否成功处理
	"""
	if not context or not context.context_id:
		return false
	
	_log_error("Runtime error in state restoration: " + error_message, {
		"context_id": context.context_id,
		"error_type": error_type,
		"target": context.target.name if context.target else "unknown"
	})
	
	# 尝试恢复状态
	if _state_manager:
		return await _state_manager.handle_runtime_failure(context.context_id, error_type)
	
	return false

func validate_context_state(context: JuicyContext) -> Dictionary:
	"""
	验证上下文状态
	
	@param context: 上下文
	@return: 验证结果字典
	"""
	if not context or not context.target:
		return {"is_valid": false, "errors": ["Invalid context or target"]}
	
	if not _state_manager:
		return {"is_valid": false, "errors": ["State manager not available"]}
	
	return _state_manager.validate_state_integrity(context.target, context.context_id)

func get_state_diagnostics(context: JuicyContext) -> Dictionary:
	"""
	获取状态诊断信息
	
	@param context: 上下文
	@return: 诊断信息字典
	"""
	var diagnostics = {
		"context_id": context.context_id if context else "unknown",
		"has_state_manager": _state_manager != null,
		"auto_snapshot_enabled": false,
		"validation_enabled": false,
		"snapshots_available": 0,
		"state_integrity": {"is_valid": true, "errors": [], "warnings": []}
	}
	
	if not context or not context.target:
		return diagnostics
	
	var config = _get_state_config(context)
	diagnostics.auto_snapshot_enabled = config.auto_snapshot_enabled if config else false
	diagnostics.validation_enabled = config.validate_restoration if config else false
	
	if _state_manager:
		var target_id = context.target.get_instance_id()
		var snapshots = _state_manager.get_snapshots_for_target(context.target)
		diagnostics.snapshots_available = snapshots.size()
		
		if config and config.validate_restoration:
			diagnostics.state_integrity = _state_manager.validate_state_integrity(context.target, context.context_id)
	
	return diagnostics
