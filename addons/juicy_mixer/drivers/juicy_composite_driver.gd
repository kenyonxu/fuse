# JuicyCompositeDriver - 组合效果驱动器
# 实现多效果组合的混音台功能，支持参数映射和实时更新
# 管理多个JuicyFeedbackResource的组合执行，提供多种混合模式

class_name JuicyCompositeDriver
extends JuicyDriver

# =============================================================================
# 组合状态管理
# =============================================================================

## 组合状态内部类
class CompositeState:
	var active_contexts: Array[String] = []  # 活跃的子上下文ID列表
	var item_weights: Dictionary = {}        # 上下文ID -> 权重映射
	var blend_progress: float = 0.0          # 混合进度（0.0-1.0）
	var parameter_values: Dictionary = {}    # 参数值存储（联觉系统）

# =============================================================================
# 核心属性
# =============================================================================

## 组合资源配置
var composite_resource: JuicyCompositeResource

## 组合状态存储：context_id -> CompositeState
var _composite_states: Dictionary = {}

# =============================================================================
# 生命周期管理
# =============================================================================

func _init():
	"""
	初始化驱动器
	设置驱动器名称和支持的属性
	"""
	driver_name = "JuicyCompositeDriver"
	supported_properties = []  # 组合驱动器通过子Driver处理属性
	required_context_data = []  # 不需要特殊的上下文数据

func prepare(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	准备阶段，在效果开始前调用一次
	用于初始化组合状态和创建子上下文
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于存储属性采样
	"""
	var start_time = _start_execution_timer()
	
	# 创建新的组合状态
	var state = CompositeState.new()
	
	# 检查是否有有效的组合资源
	if not composite_resource:
		_log_error("Composite resource is null", context)
		_end_execution_timer(start_time)
		return
	
	# 计算总权重
	var total_weight = 0.0
	for item in composite_resource.composite_items:
		if item and item.enabled and item.resource:
			total_weight += item.weight
	
	# 创建子上下文并启动子效果
	for item in composite_resource.composite_items:
		if not item or not item.enabled or not item.resource:
			continue
		
		# 检查条件
		if item.condition and not _evaluate_condition(item.condition, context):
			continue
		
		# 创建子项上下文
		var item_context = _create_item_context(context, item)
		
		# 通过JuicyMixer播放子效果
		var context_id = ""
		if item.resource.has_method("create_drivers"):
			# 使用资源的驱动器创建方法
			var drivers = item.resource.create_drivers()
			if drivers.size() > 0:
				# 这里需要与JuicyMixer集成来正确启动子效果
				# 临时使用简化的方式
				context_id = _play_sub_effect(item.resource, context.target)
			else:
				_log_warning("No drivers created for item resource", context)
				continue
		else:
			_log_warning("Resource does not support driver creation", context)
			continue
		
		# 添加到活跃上下文列表
		state.active_contexts.append(context_id)
		
		# 计算标准化权重
		var normalized_weight = item.weight / total_weight if total_weight > 0 else 0.0
		if composite_resource.normalize_weights and total_weight > 0:
			state.item_weights[context_id] = normalized_weight
		else:
			state.item_weights[context_id] = item.weight
		
		_log_debug("Created sub-context: " + context_id + " with weight: " + str(state.item_weights[context_id]), context)
	
	# 存储组合状态
	_composite_states[context.context_id] = state
	
	# 初始化参数映射（从Resource配置到Context执行）
	if composite_resource.enable_parameter_mapping:
		_setup_parameter_mappings_from_resource(context, state)
	
	_log_debug("Composite prepare completed with " + str(state.active_contexts.size()) + " active contexts", context)
	
	_end_execution_timer(start_time)

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
	"""
	处理阶段，每帧调用
	实现组合效果的核心逻辑，计算属性值并写入缓冲区
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	@param delta: 时间增量（秒）
	@param buffer: JuicyPropertyBuffer实例，用于存储属性采样
	"""
	var start_time = _start_execution_timer()
	
	var state = _composite_states.get(context.context_id)
	if not state:
		_log_warning("No composite state found for context: " + context.context_id, context)
		_end_execution_timer(start_time)
		return
	
	# 更新混合进度
	state.blend_progress = min(state.blend_progress + delta, 1.0)
	
	# 联觉系统：实时更新参数映射
	if composite_resource.enable_parameter_mapping and composite_resource.auto_update_parameters:
		_update_parameter_mappings(context, state, delta)
	
	# 应用混合模式到属性缓冲区
	_apply_blend_mode(context, state, buffer)
	
	# 检查是否所有子效果都已完成
	_check_completion(context, state)
	
	_end_execution_timer(start_time)

func cleanup(context: JuicyContext) -> void:
	"""
	清理阶段，在效果结束时调用
	用于清理组合状态和停止子效果
	
	@param context: JuicyContext实例，包含效果运行所需的所有数据
	"""
	var state = _composite_states.get(context.context_id)
	if not state:
		return
	
	_log_debug("Cleaning up composite with " + str(state.active_contexts.size()) + " active contexts", context)
	
	# 停止所有活跃的子上下文
	for context_id in state.active_contexts:
		_stop_sub_effect(context_id)
	
	# 清理Context中的参数映射
	context.clear_parameter_mappings()
	
	# 清理状态
	_composite_states.erase(context.context_id)

# =============================================================================
# 联觉系统 - 参数映射
# =============================================================================

func set_parameter(context_id: String, parameter_name: String, value: float) -> void:
	"""
	设置参数值（混音台核心功能）
	用于实时更新组合效果的参数
	
	@param context_id: 上下文ID
	@param parameter_name: 参数名称
	@param value: 参数值
	"""
	var context = JuicyMixer.get_context(context_id)
	if not context:
		return
	
	# 更新Context中的参数值
	context.set_parameter(parameter_name, value)
	
	# 立即应用参数映射到所有子上下文
	_apply_parameter_mappings(context, parameter_name, value)

# 从Resource配置设置参数映射到Context
func _setup_parameter_mappings_from_resource(context: JuicyContext, state: CompositeState) -> void:
	"""
	从Resource配置设置参数映射到Context
	遍历composite_resource.parameter_mappings并为每个映射创建MappingTarget
	
	@param context: 上下文实例
	@param state: 组合状态
	"""
	for mapping in composite_resource.parameter_mappings:
		if not mapping.enabled:
			continue
		
		if mapping.target_item_index >= composite_resource.composite_items.size():
			_log_warning("Target item index out of bounds: " + str(mapping.target_item_index), context)
			continue
		
		var item = composite_resource.composite_items[mapping.target_item_index]
		if not item or not item.resource:
			_log_warning("Target item or resource is null at index: " + str(mapping.target_item_index), context)
			continue
		
		# 获取对应的子上下文ID
		var target_context_id = ""
		if mapping.target_item_index < state.active_contexts.size():
			target_context_id = state.active_contexts[mapping.target_item_index]
		
		if target_context_id.is_empty():
			_log_warning("No active context found for target item index: " + str(mapping.target_item_index), context)
			continue
		
		# 为每个参数映射创建目标并添加到Context
		context.add_parameter_mapping(
			mapping.input_parameter,
			target_context_id,
			mapping.target_property,
			mapping.curve
		)
		
		_log_debug("Added parameter mapping: " + mapping.input_parameter + " -> " + target_context_id + "." + mapping.target_property, context)

# 应用参数映射到所有目标
func _apply_parameter_mappings(context: JuicyContext, parameter_name: String, value: float) -> void:
	"""
	应用参数映射到所有目标
	获取Context中的参数映射，遍历所有映射目标并应用值
	
	@param context: 上下文实例
	@param parameter_name: 参数名称
	@param value: 参数值
	"""
	var mappings = context.get_parameter_mapping_targets(parameter_name)
	for target in mappings:
		if not target or not target.enabled:
			continue
		
		var target_context = JuicyMixer.get_context(target.context_id)
		if not target_context or not target_context.has_method("get_property_buffer"):
			continue
		
		# 使用曲线映射值（如果有曲线）
		var mapped_value = value
		if target.curve:
			mapped_value = target.curve.sample(clampf(value, 0.0, 1.0))
		
		# 通过PropertyBuffer设置属性
		var property_buffer = target_context.get_property_buffer()
		if property_buffer:
			property_buffer.add_middleware_sample(
				target_context.target,
				target.property_path,
				mapped_value,
				JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE,
				"parameter_mapping",
				100  # 高优先级确保参数映射生效
			)

func _update_parameter_mappings(context: JuicyContext, state: CompositeState, delta: float) -> void:
	"""
	实时更新参数映射
	获取所有参数值并应用映射
	
	@param context: 上下文实例
	@param state: 组合状态
	@param delta: 时间增量
	"""
	# 动态检查条件变化
	_update_active_items_based_on_conditions(context, state)
	
	# 获取所有参数值并应用映射
	for parameter_name in context.get_parameter_names():
		var value = context.get_parameter(parameter_name)
		_apply_parameter_mappings(context, parameter_name, value)

# 动态更新基于条件的活跃项
func _update_active_items_based_on_conditions(context: JuicyContext, state: CompositeState) -> void:
	"""
	根据条件变化动态更新活跃的组合项
	
	@param context: 上下文实例
	@param state: 组合状态
	"""
	for i in range(composite_resource.composite_items.size()):
		var item = composite_resource.composite_items[i]
		if not item or not item.enabled or not item.resource:
			continue
		
		var should_be_active = true
		# 检查条件（如果存在且有效）- 使用安全的属性访问
		if item.has_method("get_condition"):
			var condition = item.get_condition()
			if condition and condition.has_method("evaluate"):
				should_be_active = condition.evaluate(context)
		else:
			# 尝试直接访问condition属性（如果存在）
			var condition = null
			if "condition" in item:
				condition = item.condition
			if condition and condition.has_method("evaluate"):
				should_be_active = condition.evaluate(context)
		
		# 检查当前状态并更新
		var context_id = state.active_contexts[i] if i < state.active_contexts.size() else ""
		var is_currently_active = not context_id.is_empty()
		
		if should_be_active and not is_currently_active:
			# 需要激活该项
			var item_context = _create_item_context(context, item)
			var new_context_id = _play_sub_effect(item.resource, context.target)
			if not new_context_id.is_empty():
				if i < state.active_contexts.size():
					state.active_contexts[i] = new_context_id
				else:
					state.active_contexts.append(new_context_id)
		elif not should_be_active and is_currently_active:
			# 需要停用该项
			_stop_sub_effect(context_id)
			if i < state.active_contexts.size():
				state.active_contexts[i] = ""


# =============================================================================
# 混合模式实现
# =============================================================================

func _apply_blend_mode(context: JuicyContext, state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
	"""
	应用混合模式
	根据配置的混合模式将子效果的结果合并到缓冲区
	
	@param context: 上下文实例
	@param state: 组合状态
	@param buffer: 属性缓冲区
	"""
	match composite_resource.blend_mode:
		JuicyCompositeResource.CompositeBlendMode.ADDITIVE:
			_apply_additive_blend(state, buffer)
		JuicyCompositeResource.CompositeBlendMode.MULTIPLICATIVE:
			_apply_multiplicative_blend(state, buffer)
		JuicyCompositeResource.CompositeBlendMode.OVERRIDE:
			_apply_override_blend(state, buffer)
		JuicyCompositeResource.CompositeBlendMode.WEIGHTED_AVERAGE:
			_apply_weighted_average_blend(state, buffer)
		_:
			_log_warning("Unknown blend mode: " + str(composite_resource.blend_mode), context)

func _apply_additive_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
	"""
	叠加混合模式
	将所有子效果的属性值按权重叠加

	@param state: 组合状态
	@param buffer: 属性缓冲区
	"""
	for context_id in state.active_contexts:
		var weight = state.item_weights.get(context_id, 1.0)
		var item_context = _get_context(context_id)
		if item_context and item_context.has_method("get_property_buffer"):
			var item_buffer = item_context.get_property_buffer()
			if item_buffer and item_context.target:
				_copy_buffer_properties(item_buffer, buffer, item_context.target, weight, context_id)

func _apply_multiplicative_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
	"""
	乘法混合模式
	将所有子效果的属性值按权重相乘

	@param state: 组合状态
	@param buffer: 属性缓冲区
	"""
	for context_id in state.active_contexts:
		var weight = state.item_weights.get(context_id, 1.0)
		var item_context = _get_context(context_id)
		if item_context and item_context.has_method("get_property_buffer"):
			var item_buffer = item_context.get_property_buffer()
			if item_buffer and item_context.target:
				_multiply_buffer_properties(item_buffer, buffer, item_context.target, weight, context_id)

func _apply_override_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
	"""
	覆盖混合模式
	使用第一个有效的子效果完全覆盖缓冲区

	@param state: 组合状态
	@param buffer: 属性缓冲区
	"""
	for context_id in state.active_contexts:
		var item_context = _get_context(context_id)
		if item_context and item_context.has_method("get_property_buffer"):
			var item_buffer = item_context.get_property_buffer()
			if item_buffer and item_context.target:
				_copy_buffer_properties(item_buffer, buffer, item_context.target, 1.0, context_id)
				break  # 只使用第一个有效项

func _apply_weighted_average_blend(state: CompositeState, buffer: JuicyPropertyBuffer) -> void:
	"""
	加权平均混合模式
	按权重计算所有子效果属性值的加权平均

	@param state: 组合状态
	@param buffer: 属性缓冲区
	"""
	var total_weight = 0.0
	for context_id in state.active_contexts:
		total_weight += state.item_weights.get(context_id, 1.0)

	if total_weight <= 0.0:
		return

	for context_id in state.active_contexts:
		var weight = state.item_weights.get(context_id, 1.0) / total_weight
		var item_context = _get_context(context_id)
		if item_context and item_context.has_method("get_property_buffer"):
			var item_buffer = item_context.get_property_buffer()
			if item_buffer and item_context.target:
				_copy_buffer_properties(item_buffer, buffer, item_context.target, weight, context_id)

# =============================================================================
# 辅助方法
# =============================================================================

func _create_item_context(parent_context: JuicyContext, item: JuicyCompositeItem) -> JuicyContext:
	"""
	创建子项上下文
	为组合中的每个子效果创建独立的上下文
	
	@param parent_context: 父上下文
	@param item: 组合项
	@return: 子项上下文
	"""
	var item_context = JuicyContext.create(item.resource, parent_context.target, parent_context.owner)
	item_context.time_scale = parent_context.time_scale
	item_context.duration = item.resource.get_duration() if item.resource.has_method("get_duration") else 0.0
	return item_context

func _check_completion(context: JuicyContext, state: CompositeState) -> void:
	"""
	检查完成状态
	如果所有子效果都已完成，则完成当前组合效果
	
	@param context: 上下文实例
	@param state: 组合状态
	"""
	var all_completed = true
	for context_id in state.active_contexts:
		var item_context = _get_context(context_id)
		if not item_context or not item_context.is_completed:
			all_completed = false
			break
	
	if all_completed and state.active_contexts.size() > 0:
		context.complete()

# =============================================================================
# 临时辅助方法（需要与JuicyMixer系统集成）
# =============================================================================

func _play_sub_effect(resource: JuicyFeedbackResource, target: Node) -> String:
	"""
	播放子效果
	通过JuicyMixer系统集成播放子效果

	@param resource: 子效果资源
	@param target: 目标节点
	@return: 上下文ID
	"""
	return JuicyMixer.play(resource, target)

func _stop_sub_effect(context_id: String) -> void:
	"""
	停止子效果
	通过JuicyMixer系统集成停止子效果

	@param context_id: 子效果上下文ID
	"""
	JuicyMixer.stop(context_id)

func _get_context(context_id: String) -> JuicyContext:
	"""
	获取上下文
	通过JuicyMixer系统集成获取上下文实例

	@param context_id: 上下文ID
	@return: 上下文实例
	"""
	return JuicyMixer.get_context(context_id)

# =============================================================================
# 缓冲区操作（与JuicyPropertyBuffer集成）
# =============================================================================

func _copy_buffer_properties(source_buffer: JuicyPropertyBuffer, target_buffer: JuicyPropertyBuffer, target_node: Node, weight: float, context_id: String = "") -> void:
	"""
	复制缓冲区属性
	将源缓冲区的所有属性样本按权重复制到目标缓冲区

	@param source_buffer: 源缓冲区
	@param target_buffer: 目标缓冲区
	@param target_node: 目标节点
	@param weight: 权重
	@param context_id: 上下文ID
	"""
	if weight <= 0:
		return

	# 使用 JuicyPropertyBuffer 的合并方法
	target_buffer.copy_buffer_with_weight(source_buffer, target_node, weight, context_id)

func _multiply_buffer_properties(source_buffer: JuicyPropertyBuffer, target_buffer: JuicyPropertyBuffer, target_node: Node, weight: float, context_id: String = "") -> void:
	"""
	乘法缓冲区属性
	将源缓冲区的所有属性样本按权重乘法应用到目标缓冲区

	@param source_buffer: 源缓冲区
	@param target_buffer: 目标缓冲区
	@param target_node: 目标节点
	@param weight: 权重
	@param context_id: 上下文ID
	"""
	if weight <= 0:
		return

	# 使用 JuicyPropertyBuffer 的乘法合并方法
	target_buffer.multiply_buffer_with_weight(source_buffer, target_node, weight, context_id)

# =============================================================================
# 日志和调试
# =============================================================================

func _log_debug(message: String, context: JuicyContext) -> void:
	"""
	调试日志
	仅在调试模式下输出
	
	@param message: 日志消息
	@param context: 上下文实例
	"""
	if OS.is_debug_build():
		print("[JuicyCompositeDriver:", context.context_id, "] ", message)

func _log_warning(message: String, context: JuicyContext) -> void:
	"""
	警告日志
	
	@param message: 日志消息
	@param context: 上下文实例
	"""
	print("[WARNING][JuicyCompositeDriver:", context.context_id, "] ", message)

func _log_error(message: String, context: JuicyContext) -> void:
	"""
	错误日志
	
	@param message: 日志消息
	@param context: 上下文实例
	"""
	print("[ERROR][JuicyCompositeDriver:", context.context_id, "] ", message)

# =============================================================================
# 条件评估
# =============================================================================

func _evaluate_condition(condition: JuicyCondition, context: JuicyContext) -> bool:
	"""
	评估条件是否满足
	
	@param condition: 要评估的条件
	@param context: 上下文实例
	@return: 条件是否满足
	"""
	if not condition or not condition.enabled:
		return true
	
	# 使用条件的evaluate方法进行评估
	return condition.evaluate(context)
