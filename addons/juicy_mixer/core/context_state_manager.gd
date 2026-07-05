# ContextStateManager - Context状态协调管理器
# 协调ChannelMiddleware和InterruptionMiddleware的状态管理
# 职责：提供统一的状态视图，避免重复跟踪，确保状态一致性
# 设计原则：不替代原有逻辑，只提供协调和同步
#
# 使用示例：
# var state_manager = ContextStateManager.get_instance()
# state_manager.sync_context_state(context, channel_middleware, interruption_middleware)
# var info = state_manager.get_unified_context_info(context_id)

class_name ContextStateManager
extends RefCounted

# 全局单例实例
static var _instance: ContextStateManager = null

# 统一的状态索引（只读缓存，不替代原有管理）
var _context_index: Dictionary = {}  # context_id -> UnifiedContextInfo
var _target_index: Dictionary = {}   # target_id -> Array[context_id]
var _channel_index: Dictionary = {}  # channel_name -> Array[context_id]

# 性能统计
var _query_count: int = 0
var _last_sync_time: float = 0.0

# 统一的Context信息结构（只读视图）
class UnifiedContextInfo:
	var context_id: String
	var target_id: int
	var channel_name: String
	var status: String  # "pending", "active", "queued", "paused", "completed"
	var is_channel_active: bool
	var is_interruption_active: bool
	var priority: int
	var created_time: float
	var last_update: float
	
	func _init(context_id: String):
		self.context_id = context_id
		self.created_time = Time.get_ticks_msec() / 1000.0
		self.last_update = self.created_time
		self.status = "pending"
		self.is_channel_active = false
		self.is_interruption_active = false
		self.priority = 0

# =============================================================================
# 单例模式
# =============================================================================

static func get_instance() -> ContextStateManager:
	if _instance == null:
		_instance = ContextStateManager.new()
	return _instance

static func reset_instance() -> void:
	if _instance:
		_instance.cleanup_all()
		_instance = null

# =============================================================================
# 核心协调接口 - 由中间件调用
# =============================================================================

func sync_context_state(context: JuicyContext, channel_middleware: ChannelMiddleware, interruption_middleware: InterruptionMiddleware) -> void:
	"""
	同步Context状态 - 由中间件调用，更新统一状态视图
	不替代原有管理，只提供协调和同步
	
	@param context: Context实例
	@param channel_middleware: 通道中间件实例
	@param interruption_middleware: 中断中间件实例
	"""
	if not context or not context.context_id:
		return
	
	var context_id = context.context_id
	
	# 获取或创建统一信息
	var unified_info = _context_index.get(context_id)
	if not unified_info:
		unified_info = UnifiedContextInfo.new(context_id)
		_context_index[context_id] = unified_info
	
	# 确保Context的活跃状态正确设置
	if context.is_active and unified_info.status != "active":
		unified_info.status = "active"
		unified_info.is_channel_active = true
	
	# 从ChannelMiddleware获取通道状态
	_sync_channel_state(context, unified_info, channel_middleware)
	
	# 从InterruptionMiddleware获取中断状态
	_sync_interruption_state(context, unified_info, interruption_middleware)
	
	# 更新索引
	_update_indices(context_id, unified_info)
	
	unified_info.last_update = Time.get_ticks_msec() / 1000.0
	_last_sync_time = unified_info.last_update
	_query_count += 1

func remove_context_sync(context_id: String) -> void:
	"""
	移除Context同步信息
	
	@param context_id: Context ID
	"""
	if not _context_index.has(context_id):
		return
	
	var unified_info = _context_index[context_id]
	
	# 从索引中移除
	_remove_from_indices(context_id, unified_info)
	
	# 从主索引中移除
	_context_index.erase(context_id)
	
	_query_count += 1

# =============================================================================
# 状态查询接口 - 提供统一视图
# =============================================================================

func get_unified_context_info(context_id: String) -> UnifiedContextInfo:
	"""
	获取统一的Context信息
	
	@param context_id: Context ID
	@return: 统一Context信息，不存在返回null
	"""
	_query_count += 1
	return _context_index.get(context_id, null)

func get_active_contexts_for_target(target: Node) -> Array[String]:
	"""
	获取目标的所有活跃Context
	
	@param target: 目标节点
	@return: 活跃Context ID数组
	"""
	if not target:
		return []
	
	var target_id = target.get_instance_id()
	var context_ids = _target_index.get(target_id, [])
	var active_contexts: Array[String] = []
	
	for context_id in context_ids:
		var info = _context_index.get(context_id)
		if info and (info.status == "active" or info.is_channel_active):
			active_contexts.append(context_id)
	
	_query_count += 1
	return active_contexts

func get_contexts_by_channel(channel_name: String) -> Array:
	"""
	获取通道的所有Context
	
	@param channel_name: 通道名称
	@return: Context ID数组
	"""
	_query_count += 1
	return _channel_index.get(channel_name, []).duplicate()

func get_channel_overview(channel_name: String) -> Dictionary:
	"""
	获取通道概览信息
	
	@param channel_name: 通道名称
	@return: 通道概览字典
	"""
	var context_ids = get_contexts_by_channel(channel_name)
	var overview = {
		"total": context_ids.size(),
		"active": 0,
		"queued": 0,
		"pending": 0,
		"completed": 0,
		"contexts": {}
	}
	
	
	for context_id in context_ids:
		var info = _context_index.get(context_id)
		if info:
			overview["contexts"][context_id] = {
				"status": info.status,
				"priority": info.priority,
				"target_id": info.target_id
			}
			
			match info.status:
				"active":
					overview["active"] += 1
				"queued":
					overview["queued"] += 1
				"pending":
					overview["pending"] += 1
				"completed":
					overview["completed"] += 1
	_query_count += 1
	return overview

func get_target_overview(target: Node) -> Dictionary:
	"""
	获取目标概览信息
	
	@param target: 目标节点
	@return: 目标概览字典
	"""
	if not target:
		return {}
	
	var target_id = target.get_instance_id()
	var context_ids = _target_index.get(target_id, [])
	var overview = {
		"target_id": target_id,
		"total": context_ids.size(),
		"active": 0,
		"queued": 0,
		"pending": 0,
		"channels": {},
		"contexts": {}
	}
	
	for context_id in context_ids:
		var info = _context_index.get(context_id)
		if info:
			overview["contexts"][context_id] = {
				"status": info.status,
				"channel": info.channel_name,
				"priority": info.priority
			}
			
			# 统计状态
			match info.status:
				"active":
					overview["active"] += 1
				"queued":
					overview["queued"] += 1
				"pending":
					overview["pending"] += 1
			
			# 按通道分组
			if not overview["channels"].has(info.channel_name):
				overview["channels"][info.channel_name] = []
			overview["channels"][info.channel_name].append(context_id)
	
	_query_count += 1
	return overview

# =============================================================================
# 状态一致性检查
# =============================================================================

func validate_state_consistency(channel_middleware: ChannelMiddleware, interruption_middleware: InterruptionMiddleware) -> Dictionary:
	"""
	验证状态一致性 - 检查ChannelMiddleware和InterruptionMiddleware之间的状态差异
	
	@param channel_middleware: 通道中间件实例
	@param interruption_middleware: 中断中间件实例
	@return: 验证结果字典
	"""
	var result = {
		"consistent": true,
		"issues": [],
		"warnings": [],
		"stats": {
			"total_contexts": _context_index.size(),
			"checked_contexts": 0,
			"inconsistent_contexts": 0
		}
	}
	
	# 检查所有已同步的Context
	for context_id in _context_index.keys():
		var info = _context_index[context_id]
		if not info:
			continue
		
		result["stats"]["checked_contexts"] += 1
		
		# 检查状态一致性
		var issues = _check_context_consistency(info, channel_middleware, interruption_middleware)
		if issues.size() > 0:
			result["consistent"] = false
			result["stats"]["inconsistent_contexts"] += 1
			result["issues"].append_array(issues)
	
	_query_count += 1
	return result

# =============================================================================
# 内部同步方法
# =============================================================================

func _sync_channel_state(context: JuicyContext, unified_info: UnifiedContextInfo, channel_middleware: ChannelMiddleware) -> void:
	"""同步通道状态"""
	# 获取Context的通道信息
	var channel_name = "default"
	if context.resource:
		# 检查是否有get_channel方法，如果没有则直接访问channel属性
		if context.resource.has_method("get_channel"):
			channel_name = context.resource.get_channel()
		else:
			# 直接尝试访问channel属性（对于导出变量）
			channel_name = context.resource.channel
	if channel_name.is_empty():
		channel_name = "default"
	
	unified_info.channel_name = channel_name
	
	# 设置目标ID
	if context.target:
		unified_info.target_id = context.target.get_instance_id()
	
	# 从ChannelMiddleware获取状态信息
	if channel_middleware:
		var channel_state = channel_middleware.get_channel_state(channel_name)
		if channel_state:
			# 检查Context在通道中的状态
			unified_info.is_channel_active = channel_state.active_contexts.has(context.context_id)
			if unified_info.is_channel_active:
				unified_info.status = "active"
			elif channel_state.queued_contexts.has(context.context_id):
				unified_info.status = "queued"
		else:
			# 如果没有通道状态，使用Context的活跃状态
			if context.is_active:
				unified_info.status = "active"
				unified_info.is_channel_active = true
	else:
		# 如果没有通道中间件，使用Context的活跃状态
		if context.is_active:
			unified_info.status = "active"
			unified_info.is_channel_active = true
	
	# 获取优先级
	if context.resource:
		if context.resource.has_method("get_priority"):
			unified_info.priority = context.resource.get_priority()
		else:
			# 直接尝试访问priority属性（对于导出变量）
			unified_info.priority = context.resource.priority

func _sync_interruption_state(context: JuicyContext, unified_info: UnifiedContextInfo, interruption_middleware: InterruptionMiddleware) -> void:
	"""同步中断状态"""
	if not context.target:
		return
	
	# 从InterruptionMiddleware获取状态信息
	if interruption_middleware:
		var interruption_state = interruption_middleware.get_interruption_state(context.target)
		if interruption_state:
			# 检查Context在中断状态中的情况
			if interruption_state.has_method("has_active_context"):
				unified_info.is_interruption_active = interruption_state.has_active_context(context.context_id)
			
			# 如果中断状态显示不同信息，以中断状态为准（中断优先级更高）
			if interruption_state.has_method("has_queued_context") and interruption_state.has_queued_context(context.context_id):
				if unified_info.status != "active":  # 不覆盖活跃状态
					unified_info.status = "queued"
			
			# 获取当前策略
			if interruption_state.has_method("get_target_id"):
				unified_info.target_id = interruption_state.get_target_id()
	else:
		# 如果没有中断中间件，使用Context的活跃状态
		if context.is_active and unified_info.status != "active":
			unified_info.status = "active"

func _update_indices(context_id: String, unified_info: UnifiedContextInfo) -> void:
	"""更新索引"""
	
	# 更新目标索引
	var target_id = unified_info.target_id
	if target_id > 0:
		if not _target_index.has(target_id):
			_target_index[target_id] = []
		# 确保不重复添加
		if context_id not in _target_index[target_id]:
			_target_index[target_id].append(context_id)
	
	# 更新通道索引
	var channel_name = unified_info.channel_name
	if not channel_name.is_empty():
		if not _channel_index.has(channel_name):
			_channel_index[channel_name] = []
		# 确保不重复添加
		if context_id not in _channel_index[channel_name]:
			_channel_index[channel_name].append(context_id)

func _remove_from_indices(context_id: String, unified_info: UnifiedContextInfo) -> void:
	"""从索引中移除"""
	# 从目标索引中移除
	var target_id = unified_info.target_id
	if target_id > 0 and _target_index.has(target_id):
		_target_index[target_id].erase(context_id)
		if _target_index[target_id].is_empty():
			_target_index.erase(target_id)
	
	# 从通道索引中移除
	var channel_name = unified_info.channel_name
	if not channel_name.is_empty() and _channel_index.has(channel_name):
		_channel_index[channel_name].erase(context_id)
		if _channel_index[channel_name].is_empty():
			_channel_index.erase(channel_name)

func _check_context_consistency(info: UnifiedContextInfo, channel_middleware: ChannelMiddleware, interruption_middleware: InterruptionMiddleware) -> Array:
	"""检查Context状态一致性"""
	var issues = []
	
	# 检查基本信息完整性
	if not info.context_id or info.context_id.is_empty():
		issues.append("Context ID is missing or empty")
	
	if info.target_id <= 0:
		issues.append("Target ID is invalid")
	
	if info.channel_name.is_empty():
		issues.append("Channel name is empty")
	
	# 检查状态一致性
	if info.status == "active" and not info.is_channel_active:
		issues.append("Status is active but channel is not active")
	
	# 检查通道状态一致性
	if channel_middleware and info.status == "active":
		var channel_state = channel_middleware.get_channel_state(info.channel_name)
		if channel_state:
			if not channel_state.active_contexts.has(info.context_id):
				issues.append("Status is active but not found in channel active contexts")
	
	# 检查中断状态一致性 - 由于无法直接从target_id获取Node，我们检查逻辑一致性
	if interruption_middleware and info.is_interruption_active:
		if info.status != "active" and info.is_interruption_active:
			issues.append("Interruption shows active but context status is not active")
	
	return issues

# =============================================================================
# 统计和调试
# =============================================================================

func get_statistics() -> Dictionary:
	"""
	获取统计信息
	
	@return: 统计字典
	"""
	return {
		"total_contexts": _context_index.size(),
		"total_targets": _target_index.size(),
		"total_channels": _channel_index.size(),
		"query_count": _query_count,
		"last_sync_time": _last_sync_time
	}

func get_contexts_summary() -> Dictionary:
	"""
	获取Context摘要信息
	
	@return: 摘要字典
	"""
	var summary = {
		"total": _context_index.size(),
		"active": 0,
		"queued": 0,
		"pending": 0,
		"completed": 0,
		"targets": _target_index.size()
	}
	
	# 统计各种状态的Context数量
	for context_id in _context_index.keys():
		var info = _context_index[context_id]
		if info:
			match info.status:
				"active":
					summary["active"] += 1
				"queued":
					summary["queued"] += 1
				"pending":
					summary["pending"] += 1
				"completed":
					summary["completed"] += 1
	
	return summary

func get_active_contexts_count() -> int:
	"""
	获取活跃Context数量
	
	@return: 活跃Context数量
	"""
	var count = 0
	for context_id in _context_index.keys():
		var info = _context_index[context_id]
		if info and (info.status == "active" or info.is_channel_active):
			count += 1
	return count

func get_queued_contexts_count() -> int:
	"""
	获取排队Context数量
	
	@return: 排队Context数量
	"""
	var count = 0
	for context_id in _context_index.keys():
		var info = _context_index[context_id]
		if info and info.status == "queued":
			count += 1
	return count

func has_active_contexts() -> bool:
	"""
	检查是否有活跃Context
	
	@return: 是否有活跃Context
	"""
	for context_id in _context_index.keys():
		var info = _context_index[context_id]
		if info and (info.status == "active" or info.is_channel_active):
			return true
	return false

func debug_print_overview() -> void:
	"""打印状态概览"""
	print("=== Context State Manager Overview ===")
	print("Total Contexts: ", _context_index.size())
	print("Total Targets: ", _target_index.size())
	print("Total Channels: ", _channel_index.size())
	print("Query Count: ", _query_count)
	
	if _channel_index.size() > 0:
		print("\nChannel Overview:")
		for channel_name in _channel_index.keys():
			var overview = get_channel_overview(channel_name)
			print("  ", channel_name, ": ", overview["active"], "/", overview["total"], " active")

# =============================================================================
# 清理
# =============================================================================

func cleanup_all() -> void:
	"""清理所有数据"""
	var before_contexts = _context_index.size()
	var before_targets = _target_index.size()
	var before_channels = _channel_index.size()
	
	_context_index.clear()
	_target_index.clear()
	_channel_index.clear()
	_query_count = 0
	_last_sync_time = 0.0
	
	var after_contexts = _context_index.size()
	var after_targets = _target_index.size()
	var after_channels = _channel_index.size()
	
	print("ContextStateManager: Cleanup completed - Contexts: ", before_contexts, "->", after_contexts,
		  ", Targets: ", before_targets, "->", after_targets,
		  ", Channels: ", before_channels, "->", after_channels)
