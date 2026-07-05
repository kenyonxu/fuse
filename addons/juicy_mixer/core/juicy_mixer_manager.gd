# JuicyMixerManager - 中间件配置节点
# 允许用户在检视器中通过拖拽脚本文件来配置中间件
# 提供类型安全的中间件配置和动态属性生成

@tool
class_name JuicyMixerManager
extends Node

# =============================================================================
# 配置属性
# =============================================================================

## 中间件配置条目列表
@export_group("Configure Middleware Pipeline")
@export var middleware_entries: Array[MiddlewareEntry] = []

@export_group("Configure Event Handlers")
@export var event_handler_entries: Array[EventHandlerEntry] = []

# =============================================================================
# 生命周期方法
# =============================================================================

func _ready():
	if Engine.is_editor_hint():
		# 编辑器模式下不执行配置应用
		return
	
	# 运行时应用中间件配置
	_apply_middleware_configs()

	call_deferred("_register_event_handlers")
	
	# 注册事件处理器
	#_register_event_handlers()

func _process(delta: float):
	# 驱动JuicyDirector的process方法
	var director = JuicyMixer.get_director()
	if director:
		director.process(delta)

# =============================================================================
# 配置应用逻辑
# =============================================================================

## 应用中间件配置到全局管道
func _apply_middleware_configs() -> void:
	var pipeline = JuicyMixer.get_middleware_pipeline()
	if not pipeline:
		push_error("JuicyMixer middleware pipeline not available")
		return
	
	# print("[JuicyMixerManager] Applying middleware configurations...")
	
	# 按优先级排序
	var sorted_entries = middleware_entries.duplicate()
	sorted_entries.sort_custom(_sort_by_priority)
	
	# 应用每个启用的中间件
	for entry in sorted_entries:
		if not entry.enabled:
			continue
		
		var middleware = entry.create_middleware()
		if middleware:
			middleware.priority = entry.priority
			if JuicyMixer.add_middleware(middleware):
				var middleware_name = middleware.middleware_name if middleware else "Unknown"
				if middleware_name.is_empty():
					middleware_name = "Unknown"
				# print("[JuicyMixerManager] Added middleware: ", middleware_name)
			else:
				push_error("Failed to add middleware: " + entry.get_middleware_name())

## 按优先级排序的回调函数
func _sort_by_priority(a: MiddlewareEntry, b: MiddlewareEntry) -> bool:
	if not a or not b:
		return false
	return a.priority < b.priority

# =============================================================================
# 工具方法
# =============================================================================

## 获取所有启用的中间件名称
func get_enabled_middleware_names() -> Array[String]:
	var names: Array[String] = []
	for entry in middleware_entries:
		if entry.enabled and entry.middleware_script:
			names.append(entry.get_middleware_name())
	return names

## 获取中间件配置统计
func get_config_stats() -> Dictionary:
	var stats = {
		"total_entries": middleware_entries.size(),
		"enabled_entries": 0,
		"valid_entries": 0,
		"middleware_names": []
	}
	
	for entry in middleware_entries:
		if entry.enabled:
			stats.enabled_entries += 1
		if entry.middleware_script:
			stats.valid_entries += 1
			stats.middleware_names.append(entry.get_middleware_name())
	
	return stats

# =============================================================================
# 事件处理器注册逻辑
# =============================================================================

## 注册事件处理器到事件处理中间件
func _register_event_handlers() -> void:
	# print("[JuicyMixerManager] Registering event handlers...")
	
	# 获取事件处理中间件
	var event_middleware = _get_event_handling_middleware()
	if not event_middleware:
		push_warning("EventHandlingMiddleware not found, skipping event handler registration")
		return
	
	# 检查事件系统是否启用
	if not event_middleware.is_event_system_enabled():
		push_warning("Event system is not enabled, skipping event handler registration")
		return
	
	# 检查事件处理器条目
	if event_handler_entries.size() == 0:
		# print("[JuicyMixerManager] No event handler entries found")
		return
	
	# 注册每个启用的事件处理器
	var registered_count = 0
	for i in range(event_handler_entries.size()):
		var entry = event_handler_entries[i]
		if not entry:
			push_error("Event handler entry at index " + str(i) + " is null")
			continue
			
		if not entry.enabled:
			# print("[JuicyMixerManager] Skipping disabled event handler entry at index ", i)
			continue
		
		# 检查条目有效性
		if not entry.handler_script:
			push_error("Event handler entry at index " + str(i) + " has no script assigned")
			continue
			
		var handler_name = entry.get_handler_name()
		# print("[JuicyMixerManager] Processing event handler entry: ", handler_name)
		
		# 创建处理器实例
		var handler = entry.create_handler()
		if handler:
			# print("[JuicyMixerManager] Created handler instance: ", handler.handler_name if handler.handler_name else "Unknown")
			
			# 检查处理器是否有效
			if not handler.handler_name or handler.handler_name.is_empty():
				push_warning("Handler has no name, using default name")
				handler.handler_name = "UnnamedHandler_" + str(handler.get_instance_id())
			
			# print("[JuicyMixerManager] Attempting to register handler with name: '", handler.handler_name, "'")
			
			# 注册事件处理器，使用默认优先级0
			var register_success = event_middleware.register_event_handler(handler, 0)
			if register_success:
				# print("[JuicyMixerManager] Successfully registered event handler: ", handler.handler_name)
				registered_count += 1
			else:
				push_error("Failed to register event handler: '" + handler.handler_name +
						  "'. Possible reasons: handler already registered, invalid handler, or scheduler not initialized.")
				
				# 尝试获取更多信息
				if not event_middleware._event_scheduler:
					push_error("Event scheduler is not initialized in EventHandlingMiddleware")
				else:
					push_error("Event scheduler is available, handler registration failed for unknown reason")
		else:
			push_error("Failed to create event handler from entry: " + handler_name +
					  ". Check if the script is a valid JuicyEventHandler subclass.")
	
	# print("[JuicyMixerManager] Registered ", registered_count, " event handlers out of ", event_handler_entries.size(), " entries")

## 获取事件处理中间件
func _get_event_handling_middleware() -> EventHandlingMiddleware:
	"""获取事件处理中间件实例"""
	var pipeline = JuicyMixer.get_middleware_pipeline()
	if not pipeline:
		# print("[JuicyMixerManager] Middleware pipeline not available")
		return null
	
	# 检查管道是否有 get_middleware 方法
	if not pipeline.has_method("get_middleware"):
		# print("[JuicyMixerManager] Pipeline does not have get_middleware method")
		return null
	
	# 从管道中获取事件处理中间件
	var middleware = pipeline.get_middleware("EventHandlingMiddleware")
	if middleware:
		if middleware is EventHandlingMiddleware:
			# print("[JuicyMixerManager] Found EventHandlingMiddleware")
			return middleware
		else:
			# print("[JuicyMixerManager] Found middleware but it's not EventHandlingMiddleware type: ", middleware.get_class())
			pass
	else:
		# print("[JuicyMixerManager] EventHandlingMiddleware not found in pipeline")
		pass
		# 列出所有可用的中间件（可选，用于调试）
		# if pipeline.has_method("get_all_middleware"):
		# 	var all_middleware = pipeline.get_all_middleware()
		# 	print("[JuicyMixerManager] Available middleware: ")
		# 	for m in all_middleware:
		# 		if m:
		# 			print("  - ", m.get_class() if m.has_method("get_class") else "Unknown")
	
	return null

## 获取事件处理器统计信息
func get_event_handler_stats() -> Dictionary:
	"""获取事件处理器配置统计"""
	var stats = {
		"total_entries": event_handler_entries.size(),
		"enabled_entries": 0,
		"valid_entries": 0,
		"handler_names": []
	}
	
	for entry in event_handler_entries:
		if entry.enabled:
			stats.enabled_entries += 1
		if entry.handler_script:
			stats.valid_entries += 1
			stats.handler_names.append(entry.get_handler_name())
	
	# 获取事件系统统计
	var event_middleware = _get_event_handling_middleware()
	if event_middleware:
		stats.event_system_stats = event_middleware.get_event_system_stats()
	
	return stats
