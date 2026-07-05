# JuicyPropertyBuffer - 虚拟属性缓冲区
# 集中管理所有属性修改，避免多次Node.set()调用
# 处理属性混合和冲突解决，提供批处理优化
#
# ## 混合过程
# 缓冲区使用三阶段混合过程来组合来自多个来源（轨道、中间件）的属性修改：
#
# ### 阶段1：基础值（OVERRIDE_BASE）
#   - 如果存在 OVERRIDE_BASE 样本，最后一个成为基础值
#   - 否则，使用原始属性值
#
# ### 阶段2：乘法偏移（MULTIPLICATIVE）
#   - 所有 MULTIPLICATIVE 样本按顺序相乘
#   - 结果与基础值相乘
#   - Color 类型支持 alpha 控制模式（alpha_mode: 0=乘法, 1=保留, 2=设置）
#
# ### 阶段3：加法偏移（ADDITIVE）
#   - 所有 ADDITIVE 样本累积
#   - 结果添加到乘法后的值
#
# ## 特殊情况
#   - 纯 OVERRIDE_BASE（无其他模式）：直接返回 OVERRIDE_BASE 值（真正的覆盖）
#   - 纯 ADDITIVE（无其他模式）：累积所有 ADDITIVE 样本
#
# ## Context ID 系统
#   - 每个来源（轨道/中间件）都有唯一的 context_id
#   - ADDITIVE/MULTIPLICATIVE 样本替换具有相同 context_id 的旧样本
#   - 防止同一来源多次更新时重复累积
#
# ## 优先级系统（重要）
#   - ⚠️ 优先级**只适用于每个混合模式内**，不影响跨混合模式交互
#   - 高优先级样本在其模式内首先处理
#   - 例如：OVERRIDE_BASE(priority=10) + ADDITIVE(priority=0)
#     结果是：(OVERRIDE_BASE 作为基础) + (ADDITIVE 被添加)
#     低优先级的 ADDITIVE 仍会影响最终结果
#   - **要真正覆盖所有效果**，在最终中间件中使用 OVERRIDE_BASE
#
# ## 类型支持
#   - float, int：直接算术运算
#   - Vector2, Vector3：逐分量运算
#   - Color：逐通道运算，ADDITIVE 模式下保留 alpha，MULTIPLICATIVE 支持 alpha_mode

class_name JuicyPropertyBuffer
extends RefCounted

# 混合模式枚举
enum BlendMode {
	OVERRIDE_BASE,    # 覆盖基础值
	ADDITIVE,         # 叠加偏移量
	MULTIPLICATIVE    # 乘法混合
}

# 缓冲区数据结构
var _buffer: Dictionary = {}  # target_node_id: { property_name: PropertySamples }
var _original_values: Dictionary = {}  # target_node_id: { property_name: original_value }

# 性能优化
var _dirty_targets: Dictionary = {}  # target_node_id: bool
var _batch_size: int = 50

# 属性采样数据
class PropertySamples:
	var base_samples: Array = []
	var additive_samples: Array = []
	var multiplicative_samples: Array = []
	var final_value: Variant
	var dirty: bool = true

# 单个属性采样
class PropertySample:
	var context_id: String
	var value: Variant
	var weight: float = 1.0
	var priority: int = 0
	var timestamp: float
	## 🔧 修复问题2：Color alpha 控制模式
	## 0 = 乘法 alpha（默认），1 = 保留 alpha，2 = 设置 alpha
	var alpha_mode: int = 0

# 核心接口
func add_sample(target: Node, property: String, value: Variant, mode: BlendMode, context_id: String = "") -> void:
	# 添加 null 检查，防止崩溃
	if not target:
		push_warning("JuicyPropertyBuffer: Target is null, skipping sample for property: " + property)
		return

	var target_id = target.get_instance_id()

	# 初始化缓冲区结构
	_initialize_target_buffer(target_id, property)

	# 保存原始值
	_save_original_value(target, property)

	# 🔥 对于 ADDITIVE 和 MULTIPLICATIVE，先移除该 context_id 的旧样本
	# 防止累积（PropertyTrack 每帧都会调用 add_sample）
	if context_id != "":
		var samples = _buffer[target_id][property]
		match mode:
			BlendMode.ADDITIVE:
				_remove_samples_by_context(samples.additive_samples, context_id)
			BlendMode.MULTIPLICATIVE:
				_remove_samples_by_context(samples.multiplicative_samples, context_id)

	# 创建采样
	var sample = PropertySample.new()
	sample.context_id = context_id
	sample.value = value
	sample.timestamp = Time.get_ticks_msec() / 1000.0

	# 添加到对应混合模式
	var samples = _buffer[target_id][property]
	match mode:
		BlendMode.OVERRIDE_BASE:
			samples.base_samples.append(sample)
		BlendMode.ADDITIVE:
			samples.additive_samples.append(sample)
		BlendMode.MULTIPLICATIVE:
			samples.multiplicative_samples.append(sample)

	samples.dirty = true
	_dirty_targets[target_id] = true

# 中间件专用接口 - 支持中间件属性写入
func add_middleware_sample(target: Node, property: String, value: Variant, mode: BlendMode, middleware_name: String, priority: int = 0) -> void:
	var target_id = target.get_instance_id()
	
	# 初始化缓冲区结构
	_initialize_target_buffer(target_id, property)
	
	# 保存原始值
	_save_original_value(target, property)
	
	# 创建采样
	var sample = PropertySample.new()
	sample.context_id = "middleware_" + middleware_name  # 使用中间件名称作为上下文ID
	sample.value = value
	sample.priority = priority  # 中间件优先级
	sample.timestamp = Time.get_ticks_msec() / 1000.0
	
	# 添加到对应混合模式
	var samples = _buffer[target_id][property]
	match mode:
		BlendMode.OVERRIDE_BASE:
			_insert_sample_with_priority(samples.base_samples, sample)
		BlendMode.ADDITIVE:
			_insert_sample_with_priority(samples.additive_samples, sample)
		BlendMode.MULTIPLICATIVE:
			_insert_sample_with_priority(samples.multiplicative_samples, sample)
	
	samples.dirty = true
	_dirty_targets[target_id] = true

# 移除指定中间件的所有采样
func remove_middleware_samples(middleware_name: String) -> void:
	var context_id = "middleware_" + middleware_name

	for target_id in _buffer.keys():
		for property in _buffer[target_id].keys():
			var samples = _buffer[target_id][property]

			# 移除指定中间件的所有采样
			_remove_samples_by_context(samples.base_samples, context_id)
			_remove_samples_by_context(samples.additive_samples, context_id)
			_remove_samples_by_context(samples.multiplicative_samples, context_id)

			samples.dirty = true

## 🔧 修复问题4：按中间件和混合模式移除样本
## 只移除指定混合模式的样本，保留其他模式的样本
func remove_middleware_samples_by_mode(middleware_name: String, mode: BlendMode) -> void:
	var context_id = "middleware_" + middleware_name

	for target_id in _buffer.keys():
		for property in _buffer[target_id].keys():
			var samples = _buffer[target_id][property]

			# 只移除指定混合模式的样本
			match mode:
				BlendMode.OVERRIDE_BASE:
					_remove_samples_by_context(samples.base_samples, context_id)
				BlendMode.ADDITIVE:
					_remove_samples_by_context(samples.additive_samples, context_id)
				BlendMode.MULTIPLICATIVE:
					_remove_samples_by_context(samples.multiplicative_samples, context_id)

			samples.dirty = true

## 🔧 修复问题4：按中间件和特定属性移除样本
## 只移除指定属性的样本，保留其他属性
func remove_middleware_samples_for_property(middleware_name: String, property: String) -> void:
	var context_id = "middleware_" + middleware_name

	for target_id in _buffer.keys():
		if _buffer[target_id].has(property):
			var samples = _buffer[target_id][property]
			_remove_samples_by_context(samples.base_samples, context_id)
			_remove_samples_by_context(samples.additive_samples, context_id)
			_remove_samples_by_context(samples.multiplicative_samples, context_id)
			samples.dirty = true

func remove_context_samples(context_id: String) -> void:
	for target_id in _buffer.keys():
		for property in _buffer[target_id].keys():
			var samples = _buffer[target_id][property]
			
			# 移除指定上下文的所有采样
			_remove_samples_by_context(samples.base_samples, context_id)
			_remove_samples_by_context(samples.additive_samples, context_id)
			_remove_samples_by_context(samples.multiplicative_samples, context_id)
			
			samples.dirty = true

func clear_target_samples(target: Node) -> void:
	var target_id = target.get_instance_id()
	_buffer.erase(target_id)
	_original_values.erase(target_id)
	_dirty_targets.erase(target_id)

func clear_property_samples(target: Node, property: String) -> void:
	var target_id = target.get_instance_id()
	if _buffer.has(target_id) and _buffer[target_id].has(property):
		_buffer[target_id].erase(property)

# 批处理应用
func flush_all_samples() -> void:
	for target_id in _dirty_targets.keys():
		var target = instance_from_id(target_id)
		if not is_instance_valid(target):
			continue
		
		_flush_target_samples(target)
	
	_dirty_targets.clear()

func flush_target_samples(target: Node) -> void:
	var target_id = target.get_instance_id()
	if not _buffer.has(target_id):
		return
	
	_flush_target_samples(target)
	_dirty_targets.erase(target_id)

# 内部实现
func _initialize_target_buffer(target_id: int, property: String) -> void:
	if not _buffer.has(target_id):
		_buffer[target_id] = {}
	
	if not _buffer[target_id].has(property):
		_buffer[target_id][property] = PropertySamples.new()

func _save_original_value(target: Node, property: String) -> void:
	var target_id = target.get_instance_id()
	
	if not _original_values.has(target_id):
		_original_values[target_id] = {}
	
	if not _original_values[target_id].has(property):
		if property in target:
			_original_values[target_id][property] = target.get(property)

func _flush_target_samples(target: Node) -> void:
	var target_id = target.get_instance_id()
	if not _buffer.has(target_id):
		return
	
	var target_buffer = _buffer[target_id]
	
	for property in target_buffer.keys():
		var samples = target_buffer[property]

		if not samples.dirty:
			continue

		# 计算最终值
		var final_value = _calculate_final_property_value(target, property)

		# 应用到目标
		if property in target:
			target.set(property, final_value)

		samples.final_value = final_value
		samples.dirty = false

func _calculate_final_property_value(target: Node, property: String) -> Variant:
	var target_id = target.get_instance_id()
	var samples = _buffer[target_id][property]

	if samples.base_samples.is_empty() and samples.additive_samples.is_empty() and samples.multiplicative_samples.is_empty():
		return _original_values[target_id].get(property, target.get(property))

	# 🔥 特殊处理1：如果只有 OVERRIDE_BASE 样本（没有加法和乘法），直接使用 OVERRIDE_BASE 值
	# 这样 OVERRIDE_BASE 就是真正的"覆盖"，而不是"原始值 + OVERRIDE_BASE值"
	if not samples.base_samples.is_empty() and samples.additive_samples.is_empty() and samples.multiplicative_samples.is_empty():
		var last_base = samples.base_samples[-1]
		return last_base.value

	# 🔥 特殊处理2：如果只有 ADDITIVE 样本（没有 OVERRIDE_BASE 和乘法），直接累加 ADDITIVE 值
	# 这样就不会重复加上 _original_values，因为 JuicyPropertyTrack 已经计算了 original + offset
	if samples.base_samples.is_empty() and not samples.additive_samples.is_empty() and samples.multiplicative_samples.is_empty():
		# 对于 Color 类型，需要特殊处理（每个通道相加）
		var original = _original_values[target_id].get(property, target.get(property))
		if typeof(original) == TYPE_COLOR:
			var final_color = Color(0, 0, 0, original.a)
			for sample in samples.additive_samples:
				var sample_color = sample.value as Color
				final_color.r += sample_color.r
				final_color.g += sample_color.g
				final_color.b += sample_color.b
				final_color.a = sample_color.a  # 使用最后一个样本的 alpha
			return final_color
		else:
			# 非颜色类型：直接累加
			var final_value = _get_zero_value(original)
			for sample in samples.additive_samples:
				final_value += sample.value
			return final_value

	# 阶段1：获取基础值
	var base_value = _original_values[target_id].get(property, target.get(property))
	if not samples.base_samples.is_empty():
		var last_base = samples.base_samples[-1]  # 后来者优先
		base_value = last_base.value

	# 🔧 修复问题1：处理 null base_value
	if base_value == null:
		# 如果 base_value 为 null，根据属性类型获取默认零值
		if property in target:
			var current_value = target.get(property)
			base_value = _get_zero_value_for_type(typeof(current_value))
		else:
			# 属性不存在，使用默认值
			base_value = 0.0

	# 阶段2：应用乘法偏移（带类型安全）
	var multiplied_value: Variant
	if not samples.multiplicative_samples.is_empty():
		# 🔧 修复问题2：Color 类型的特殊处理（支持 alpha_mode）
		if base_value is Color:
			multiplied_value = base_value.duplicate()
			for sample in samples.multiplicative_samples:
				if sample.value is Color:
					var sample_color = sample.value as Color
					# RGB 通道总是乘法
					multiplied_value.r *= sample_color.r
					multiplied_value.g *= sample_color.g
					multiplied_value.b *= sample_color.b
					# Alpha 通道根据 alpha_mode 处理
					match sample.alpha_mode:
						0: # 乘法 alpha（默认）
							multiplied_value.a *= sample_color.a
						1: # 保留原始 alpha
							pass
						2: # 设置 alpha
							multiplied_value.a = sample_color.a
				else:
					# 非Color值，使用标准乘法
					multiplied_value = _multiply_values(multiplied_value, sample.value)
		else:
			# 非 Color 类型，使用标准乘法
			var multiplicative_offset = _get_identity_value(base_value)
			for sample in samples.multiplicative_samples:
				multiplicative_offset = _multiply_values(multiplicative_offset, sample.value)
			multiplied_value = _multiply_values(base_value, multiplicative_offset)
	else:
		multiplied_value = base_value

	# 阶段3：应用加法偏移
	var additive_offset = _get_zero_value(multiplied_value)
	for sample in samples.additive_samples:
		additive_offset += sample.value
	var final_value = (multiplied_value if multiplied_value != null else _get_zero_value(additive_offset)) + additive_offset

	return final_value

func _remove_samples_by_context(samples: Array, context_id: String) -> void:
	for i in range(samples.size() - 1, -1, -1):
		if samples[i].context_id == context_id:
			samples.remove_at(i)

# 按优先级插入采样
func _insert_sample_with_priority(samples: Array, sample: PropertySample) -> void:
	# 找到合适的插入位置（优先级高的在前面）
	var insert_index = 0
	for i in range(samples.size()):
		if samples[i].priority > sample.priority:
			insert_index = i + 1
		else:
			break
	
	samples.insert(insert_index, sample)

func _get_identity_value(value: Variant) -> Variant:
	if value is float or value is int:
		return 1.0
	elif value is Vector2:
		return Vector2.ONE
	elif value is Vector3:
		return Vector3.ONE
	elif value is Color:
		return Color.WHITE
	else:
		return 1.0

func _get_zero_value(value: Variant) -> Variant:
	if value is float or value is int:
		return 0.0
	elif value is Vector2:
		return Vector2.ZERO
	elif value is Vector3:
		return Vector3.ZERO
	elif value is Color:
		return Color.TRANSPARENT
	else:
		return 0.0

## 🔧 修复问题1：根据属性类型获取零值（而非值）
## 用于处理 null base_value 的情况
func _get_zero_value_for_type(type: int) -> Variant:
	match type:
		TYPE_FLOAT: return 0.0
		TYPE_INT: return 0
		TYPE_VECTOR2: return Vector2.ZERO
		TYPE_VECTOR3: return Vector3.ZERO
		TYPE_COLOR: return Color.TRANSPARENT
		TYPE_NIL: return 0.0
		_: return 0.0

## 🔧 修复问题1：类型安全的乘法，支持 Color、Vector2、Vector3
func _multiply_values(a: Variant, b: Variant) -> Variant:
	# Color 类型乘法（逐通道乘法）
	if a is Color and b is Color:
		return Color(
			a.r * b.r,
			a.g * b.g,
			a.b * b.b,
			a.a * b.a
		)
	# Vector2 乘法（通常是 Vector2 * float）
	elif a is Vector2:
		if b is float or b is int:
			return a * b
		elif b is Vector2:
			# Vector2 逐分量乘法
			return Vector2(a.x * b.x, a.y * b.y)
		else:
			push_warning("Vector2 只能与 float/int/Vector2 相乘，得到类型：%s" % typeof(b))
			return a
	elif b is Vector2:
		if a is float or a is int:
			return b * a
		else:
			push_warning("float/int 只能与 Vector2 相乘，得到类型：%s" % typeof(a))
			return b
	# Vector3 乘法
	elif a is Vector3:
		if b is float or b is int:
			return a * b
		elif b is Vector3:
			# Vector3 逐分量乘法
			return Vector3(a.x * b.x, a.y * b.y, a.z * b.z)
		else:
			push_warning("Vector3 只能与 float/int/Vector3 相乘，得到类型：%s" % typeof(b))
			return a
	elif b is Vector3:
		if a is float or a is int:
			return b * a
		else:
			push_warning("float/int 只能与 Vector3 相乘，得到类型：%s" % typeof(a))
			return b
	# float/int 乘法
	elif a is float or a is int:
		return a * b
	elif b is float or b is int:
		return b * a
	else:
		push_warning("不支持的乘法类型：%s * %s，返回第一个值" % [typeof(a), typeof(b)])
		return a

# =============================================================================
# 缓冲区合并操作（用于组合系统）
# =============================================================================

## 复制缓冲区内容到目标缓冲区，应用权重
## 用于组合系统的 ADDITIVE 和 OVERRIDE 混合模式
## @param source_buffer: 源缓冲区
## @param target: 目标节点
## @param weight: 权重因子（0.0-1.0）
## @param context_id: 上下文ID，用于标识样本来源
func copy_buffer_with_weight(source_buffer: JuicyPropertyBuffer, target: Node, weight: float, context_id: String = "") -> void:
	if not source_buffer or not target:
		return

	# 获取源缓冲区的内部数据（需要访问私有成员）
	# 通过反射获取 _buffer 内容
	var source_data = source_buffer._get_internal_buffer_data()
	if not source_data:
		return

	for source_target_id in source_data.keys():
		var properties = source_data[source_target_id]

		# 获取源节点（如果需要）
		var source_target = instance_from_id(source_target_id)
		if not source_target or not is_instance_valid(source_target):
			continue

		# 遍历所有属性
		for property_name in properties.keys():
			var samples = properties[property_name]
			var target_node = target  # 组合系统的目标节点

			# 处理 base_samples
			for sample in samples.base_samples:
				var weighted_value = _apply_weight_to_value(sample.value, weight)
				add_sample(target_node, property_name, weighted_value, BlendMode.ADDITIVE, context_id)

			# 处理 additive_samples
			for sample in samples.additive_samples:
				var weighted_value = _apply_weight_to_value(sample.value, weight)
				add_sample(target_node, property_name, weighted_value, BlendMode.ADDITIVE, context_id)

			# 处理 multiplicative_samples（转换为加法，乘法在flush阶段处理）
			for sample in samples.multiplicative_samples:
				# 乘法样本需要特殊处理：将权重应用到偏移量
				# 这里简化处理，直接使用加法模式
				var weighted_value = _apply_weight_to_value(sample.value, weight)
				add_sample(target_node, property_name, weighted_value, BlendMode.ADDITIVE, context_id)

## 乘法混合模式：将缓冲区内容乘法应用到目标缓冲区
## 用于组合系统的 MULTIPLICATIVE 混合模式
## @param source_buffer: 源缓冲区
## @param target: 目标节点
## @param weight: 权重因子（0.0-1.0），用于控制影响程度
## @param context_id: 上下文ID，用于标识样本来源
func multiply_buffer_with_weight(source_buffer: JuicyPropertyBuffer, target: Node, weight: float, context_id: String = "") -> void:
	if not source_buffer or not target:
		return

	# 获取源缓冲区的内部数据
	var source_data = source_buffer._get_internal_buffer_data()
	if not source_data:
		return

	for source_target_id in source_data.keys():
		var properties = source_data[source_target_id]

		var source_target = instance_from_id(source_target_id)
		if not source_target or not is_instance_valid(source_target):
			continue

		# 遍历所有属性
		for property_name in properties.keys():
			var samples = properties[property_name]
			var target_node = target

			# 对于乘法混合，我们计算每个样本的加权幂
			# value = base ^ weight
			for sample in samples.base_samples:
				var weighted_value = _power_value(sample.value, weight)
				add_sample(target_node, property_name, weighted_value, BlendMode.MULTIPLICATIVE, context_id)

			for sample in samples.additive_samples:
				var weighted_value = _power_value(sample.value, weight)
				add_sample(target_node, property_name, weighted_value, BlendMode.MULTIPLICATIVE, context_id)

			for sample in samples.multiplicative_samples:
				var weighted_value = _power_value(sample.value, weight)
				add_sample(target_node, property_name, weighted_value, BlendMode.MULTIPLICATIVE, context_id)

## 获取内部缓冲区数据（用于组合系统）
## 返回 _buffer 的引用，允许其他系统读取缓冲区内容
## @return: 内部缓冲区数据字典
func _get_internal_buffer_data() -> Dictionary:
	return _buffer

## 应用权重到值
## @param value: 原始值
## @param weight: 权重因子
## @return: 加权后的值
func _apply_weight_to_value(value: Variant, weight: float) -> Variant:
	if value is float or value is int:
		return float(value) * weight
	elif value is Vector2:
		return value * weight
	elif value is Vector3:
		return value * weight
	elif value is Color:
		# Color 乘法：对 RGB 分量应用权重，保留 alpha
		return Color(value.r * weight, value.g * weight, value.b * weight, value.a)
	else:
		return value

## 计算值的幂（用于乘法混合）
## @param value: 基数值
## @param exponent: 指数（权重）
## @return: 幂运算结果
func _power_value(value: Variant, exponent: float) -> Variant:
	if value is float or value is int:
		return pow(float(value), exponent)
	elif value is Vector2:
		return Vector2(pow(value.x, exponent), pow(value.y, exponent))
	elif value is Vector3:
		return Vector3(pow(value.x, exponent), pow(value.y, exponent), pow(value.z, exponent))
	elif value is Color:
		# Color 幂运算：对 RGB 分量计算幂，保留 alpha
		return Color(pow(value.r, exponent), pow(value.g, exponent), pow(value.b, exponent), value.a)
	else:
		return value

# =============================================================================
# 查询和调试
# =============================================================================

func get_buffer_stats() -> Dictionary:
	var stats = {
		"total_targets": _buffer.size(),
		"total_properties": 0,
		"total_samples": 0,
		"dirty_targets": _dirty_targets.size()
	}
	
	for target_id in _buffer.keys():
		for property in _buffer[target_id].keys():
			stats.total_properties += 1
			var samples = _buffer[target_id][property]
			stats.total_samples += samples.base_samples.size()
			stats.total_samples += samples.additive_samples.size()
			stats.total_samples += samples.multiplicative_samples.size()
	
	return stats