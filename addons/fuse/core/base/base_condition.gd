@tool
@icon("res://addons/fuse/icons/condition.svg")
@abstract
class_name BaseCondition extends Resource

# 预加载本地化工具类
const FuseLocalization = preload("res://addons/fuse/localization/fuse_localization.gd")

# 预加载变量工具类（统一变量访问 API）
const VariableOperations = preload("res://addons/fuse/core/utils/variable_operations.gd")
const VariableScopeUtils = preload("res://addons/fuse/core/utils/variable_scope_utils.gd")
const FuseNodeUtils = preload("res://addons/fuse/utils/fuse_node_utils.gd")

## 条件配置
@export_group("Condition Configuration")
@export var enabled: bool = true:
	set(value):
		enabled = value
		_log_debug("Condition %s" % ("enabled" if value else "disabled"))

@export var log_level: FuseLogger.LogLevel = FuseLogger.LogLevel.INFO  ## 日志输出级别

@export var negate_result: bool = false:
	set(value):
		negate_result = value
		_log_debug("Negate result %s" % ("enabled" if value else "disabled"))

## 条件状态
var last_check_time: float = 0.0
var check_count: int = 0
var last_result: bool = false
var _fuse_error: FuseError = null	 ## FuseError 实例，用于统一错误处理
## 性能优化：缓存 FuseLocalization 类引用
static var _fuse_localization_class: RefCounted = null

## 缓存配置
@export_group("Cache Configuration")
@export var enable_cache: bool = false:
	set(value):
		enable_cache = value
		_log_debug("Condition cache %s" % ("enabled" if value else "disabled"))

@export var cache_duration: float = 1.0:
	set(value):
		cache_duration = max(0.1, value)
		_log_debug("Cache duration set to: %.2f seconds" % value)

@export var cache_context_changes: bool = true  ## 是否在上下文变化时失效缓存
@export var hash_all_variables: bool = false   ## 是否包含所有变量在哈希中

## 缓存状态
var _cached_result: bool = false
var _cache_timestamp: float = 0.0
var _cache_context_hash: int = 0
var _cached_dependencies: Array[String] = []

## 线程安全配置
## 标记为 true 的条件可以在工作线程中并行评估
## 子类应该根据实现重写此属性
var is_thread_safe: bool:
	get:
		return _compute_thread_safety()

## 缓存线程安全评估结果
var _thread_safety_cached: bool = false
var _thread_safety_computed: bool = false

## 常量
const DEFAULT_CHECK_INTERVAL: float = 0.1

## 条件描述
var _description: String

# 更新条件在列表中的名称
# 需要子类重写此方法
@abstract
func _update_resource_name()

## 获取 target_node 的可读显示名称
##
## 将相对路径（如 "..", "../NodeName"）转换为可读的节点名称。
## 用于 _update_resource_name() 和 get_description() 中显示目标节点。
##
## 解析策略：
## - 路径末尾有明确节点名（非纯相对引用）→ 直接提取
## - 编辑器模式通过 FuseNodeUtils 解析纯相对引用（.. / .）
## - 多层 .. 无法解析时 → 智能回退（如 ../../.. → [3层上级]）
## - 重启后的刷新由 EditorPlugin.scene_changed 信号处理
##
## 参数：
## - path: NodePath - 要解析的节点路径
##
## 返回：
## - String - 可读的节点名称
func _get_node_display_name(path: NodePath) -> String:
	if path.is_empty():
		return ""
	var path_str = str(path)
	# 快速路径：路径末尾有明确节点名（非纯相对引用）
	var file_name = path_str.get_file()
	if not file_name.is_empty() and file_name != ".." and file_name != ".":
		return file_name
	# 编辑器模式下通过 FuseNodeUtils 解析纯相对引用（.. / .）
	if Engine.is_editor_hint():
		var resolved = FuseNodeUtils.resolve_node_name_for_display(self, path)
		if resolved != path_str:
			return resolved
		# 解析失败，使用智能回退显示
		return _get_parent_level_display(path_str)
	return path_str

## 将纯 .. 路径转换为可读的层级描述
static func _get_parent_level_display(path_str: String) -> String:
	var segments = path_str.split("/")
	var parent_count = 0
	for seg in segments:
		if seg == "..":
			parent_count += 1
		elif seg == ".":
			continue
		else:
			break
	if parent_count <= 0:
		return path_str
	if parent_count == 1:
		return "[上级]"
	return "[%d层上级]" % parent_count

## 记录上次更新 resource_name 时使用的语言
## 用于检测编辑器语言是否发生变化，以便自动刷新资源名称
var _last_locale: String = ""

## 拦截属性设置，处理 resource_name 的语言自动更新
##
## 当 resource_name 被设置时（包括从文件反序列化时），
## 检查当前语言是否与上次更新时的语言不同。
## 如果不同，则重新调用 _update_resource_name() 来使用新语言翻译。
##
## 参数：
## - property: StringName - 属性名称
## - value: Variant - 属性值
##
## 返回：
## - bool - 如果属性被处理返回 true，否则返回 false
func _set(property: StringName, value: Variant) -> bool:
	if property == "resource_name":
		# 确保本地化系统已初始化，并检查语言是否变化
		FuseLocalization.init()

		# 检查当前语言是否与上次更新时不同
		var current_locale = FuseLocalization.get_locale_code()
		if _last_locale.is_empty() or current_locale != _last_locale:
			# 语言已变化或首次设置，重新生成翻译
			_last_locale = current_locale
			_update_resource_name()
			# 返回 false 让 Godot 使用我们更新的 resource_name
			return false

		# 语言未变化，记录当前语言
		_last_locale = current_locale

	# 返回 false 让 Godot 继续默认处理
	return false

## 条件检查接口
## context: ExecutionContext - 执行上下文
## returns: bool - 条件是否满足
func check(context: ExecutionContext) -> bool:
	# 防御性编程：检查 context 是否为空
	if context == null:
		_log_error("ExecutionContext is null, cannot check condition")
		_create_fuse_error_localized("FUSE_ERROR_CONTEXT_NULL_CHECK_CONDITION", FuseError.ErrorType.VALIDATION_ERROR)
		return false
	
	if not enabled:
		_log_debug("Condition is disabled, returning false")
		return false
	
	# 检查缓存是否有效
	if enable_cache and _is_cache_valid(context):
		_log_debug("Using cached result: %s" % ("true" if _cached_result else "false"))
		last_result = _cached_result
		return _cached_result
	
	check_count += 1
	last_check_time = Time.get_ticks_msec() / 1000.0
	
	# 执行实际的条件检查
	var result = _evaluate_condition(context)
	
	# 应用结果取反
	if negate_result:
		result = not result
	
	last_result = result
	
	# 更新缓存
	if enable_cache:
		_update_cache(result, context)
	
	_log_debug("Condition check #%d: %s" % [check_count, "true" if result else "false"])
	return result

## 评估条件（子类实现）
## context: ExecutionContext - 执行上下文
## returns: bool - 条件评估结果
@abstract
func _evaluate_condition(context: ExecutionContext) -> bool

## 条件验证接口
## returns: Array[String] - 验证错误列表，空数组表示验证通过
func validate() -> Array[String]:
	var errors: Array[String] = []
	
	if not enabled:
		errors.append("Condition is disabled")
		_create_fuse_error_localized("FUSE_ERROR_CONDITION_DISABLED", FuseError.ErrorType.VALIDATION_ERROR)
	
	return errors

## 条件描述信息
## returns: String - 条件的描述文本
func get_description() -> String:
	return "Base Condition"

## 条件详细信息
## returns: Dictionary - 包含条件详细信息的字典
func get_detailed_info() -> Dictionary:
	var detailed_info = {
		"type": get_condition_type(),
		"description": get_description(),
		"enabled": enabled,
		"negate_result": negate_result,
		"check_count": check_count,
		"last_check_time": last_check_time,
		"last_result": last_result
	}
	
	# 如果有 FuseError，添加错误信息
	if _fuse_error:
		detailed_info["fuse_error"] = _fuse_error.get_error_details()
	
	return detailed_info

## 获取条件状态信息
## returns: Dictionary - 包含条件状态信息的字典
func get_status_info() -> Dictionary:
	return {
		"enabled": enabled,
		"check_count": check_count,
		"last_check_time": last_check_time,
		"last_result": last_result,
		"needs_recheck": needs_recheck(null),
		"is_valid": is_valid(null)
	}

## 获取条件类型
## returns: String - 条件类型名称
func get_condition_type() -> String:
	return "base"

## 获取条件分类
## returns: String - 条件分类名称
func get_condition_category() -> String:
	return "general"

## 获取条件图标
##
## 优先级与 BaseInstruction.get_icon() 一致：
##   1. metadata.builtin_icon → FuseIconManager.get_builtin_icon()
##   2. metadata.custom_icon → FuseIconManager.get_custom_icon()
##   3. metadata.icon_name → FuseIconManager
##   4. metadata.icon → 直接返回 Texture2D
##   5. 回退到默认 condition.svg
##
## returns: Texture2D - 条件图标
func get_condition_icon() -> Texture2D:
	# 尝试从子类静态 metadata 获取图标
	var script = get_script()
	if script and script.has_method("_get_condition_metadata"):
		var meta = script._get_condition_metadata()
		if meta:
			# 使用 Object.get() 安全访问属性，与 FuseMetadata.get_icon_texture() 一致
			var builtin = meta.get("builtin_icon")
			if builtin is String and not builtin.is_empty():
				return FuseIconManager.get_builtin_icon(builtin)
			var custom = meta.get("custom_icon")
			if custom is String and not custom.is_empty():
				return FuseIconManager.get_custom_icon(custom)
			var icon_name_val = meta.get("icon_name")
			if icon_name_val is String and not icon_name_val.is_empty():
				if FuseIconManager.has_custom_icon(icon_name_val):
					return FuseIconManager.get_custom_icon(icon_name_val)
				return FuseIconManager.get_builtin_icon(icon_name_val)
			var icon_val = meta.get("icon")
			if icon_val is Texture2D:
				return icon_val

	# 回退到默认条件图标（向后兼容）
	var icon_path = "res://addons/fuse/icons/condition.svg"
	if ResourceLoader.exists(icon_path):
		return load(icon_path)
	else:
		_log_warning("Condition icon not found at path: %s" % icon_path)
		return null

## 获取图标（兼容性方法）
## returns: Texture2D - 条件图标
func get_icon() -> Texture2D:
	return get_condition_icon()

## 获取条件参数
## returns: Dictionary - 条件参数字典
func get_parameters() -> Dictionary:
	return {}

## 设置条件参数
## parameters: Dictionary - 参数字典
func set_parameters(parameters: Dictionary):
	# 防御性编程：检查参数是否为空
	if parameters == null:
		_log_error("Parameters dictionary is null, cannot set parameters")
		return
	
	for key in parameters:
		# 使用 get(key) 方法检查属性是否存在
		# 如果属性不存在，get 返回 null
		var current_value = get(key)
		var property_exists = current_value != null
		
		if property_exists:
			_log_debug("Setting property: %s = %s" % [key, str(parameters[key])])
			# 使用 Godot 4.x 兼容的设置方法
			if has_method("set_" + key):
				call("set_" + key, parameters[key])
			else:
				# 直接赋值
				set(key, parameters[key])
		else:
			_log_warning("Property '%s' does not exist on condition" % key)

## 检查条件是否需要重新评估
## context: ExecutionContext - 执行上下文
## returns: bool - 是否需要重新评估
func needs_recheck(context: ExecutionContext) -> bool:
	# 防御性编程：检查 context 是否为空
	if context == null:
		_log_warning("ExecutionContext is null, defaulting to recheck")
		return true
	
	# 默认情况下，每次都重新检查
	# 子类可以重写此方法来实现更智能的检查策略
	return true

## 获取条件依赖的变量
## returns: Array[String] - 依赖的变量名列表
func get_dependencies() -> Array[String]:
	# 使用缓存避免重复计算
	if _cached_dependencies.is_empty():
		_cached_dependencies = _compute_dependencies()
	return _cached_dependencies

## 计算条件依赖的变量（子类实现）
## returns: Array[String] - 依赖的变量名列表
@abstract
func _compute_dependencies() -> Array[String]

## 计算条件是否线程安全
## 默认实现返回 false，子类需要重写
## 线程安全的条件应该：
## 1. 不访问节点属性（使用快照数据）
## 2. 不调用需要在主线程的 API
## 3. 只进行纯数学计算或变量比较
func _compute_thread_safety() -> bool:
	if _thread_safety_computed:
		return _thread_safety_cached

	# 默认不安全，子类需要显式标记
	_thread_safety_cached = false
	_thread_safety_computed = true
	return false

## 重置线程安全缓存
## 当条件配置改变时调用
func reset_thread_safety_cache() -> void:
	_thread_safety_computed = false
	_thread_safety_cached = false

## 获取条件影响的变量
## returns: Array[String] - 影响的变量名列表
func get_affected_variables() -> Array[String]:
	# 子类可以重写此方法来声明影响的变量
	return []

## 重置条件状态
func reset():
	check_count = 0
	last_check_time = 0.0
	last_result = false
	_fuse_error = null
	clear_cache()
	clear_dependencies_cache()
	reset_thread_safety_cache()
	_log_debug("Condition reset")

## 清除依赖缓存
func clear_dependencies_cache():
	_cached_dependencies.clear()
	_log_debug("Dependencies cache cleared")

## 启用/禁用条件
func set_enabled(value: bool):
	enabled = value
	_log_debug("Condition %s" % ("enabled" if value else "disabled"))

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("BaseCondition", log_level, message)

func _log_info(message: String):
	FuseLogger.log_info("BaseCondition", log_level, message)

func _log_warning(message: String):
	FuseLogger.log_warning("BaseCondition", log_level, message)

func _log_error(message: String):
	FuseLogger.log_error("BaseCondition", log_level, message)

## 获取条件优先级
## returns: int - 条件优先级，数值越小优先级越高
func get_priority() -> int:
	return 0

## 条件序列化
## returns: Dictionary - 序列化后的条件数据
func serialize() -> Dictionary:
	return {
		"type": get_condition_type(),
		"enabled": enabled,
		"negate_result": negate_result,
		"parameters": get_parameters()
	}

## 条件反序列化
## data: Dictionary - 序列化的条件数据
func deserialize(data: Dictionary):
	if data.has("enabled"):
		enabled = data["enabled"]
	
	if data.has("negate_result"):
		negate_result = data["negate_result"]
	
	if data.has("parameters"):
		set_parameters(data["parameters"])

## 克隆条件
## returns: BaseCondition - 克隆的新条件
func clone() -> BaseCondition:
	# 使用 Godot 4.x 兼容的复制方法
	var new_condition = duplicate()
	
	# 确保新条件重置状态
	if new_condition.has_method("reset"):
		new_condition.reset()
	else:
		_log_warning("Clone does not have reset method")
	
	return new_condition

## 检查条件是否有效
## context: ExecutionContext - 执行上下文
## returns: bool - 条件是否有效
func is_valid(context: ExecutionContext) -> bool:
	# 防御性编程：检查 context 是否为空
	if context == null:
		_log_warning("ExecutionContext is null, checking basic validity only")
		_create_fuse_error_localized("FUSE_ERROR_CONTEXT_NULL_BASIC_VALIDATION", FuseError.ErrorType.VALIDATION_ERROR)
	
	var validation_errors = validate()
	for error in validation_errors:
		_log_error("Validation error: %s" % error)
	
	return validation_errors.is_empty()

## 获取条件的历史记录
## returns: Array[Dictionary] - 条件检查历史记录
func get_history() -> Array[Dictionary]:
	# 子类可以实现历史记录功能
	return []

## 清理历史记录
func clear_history():
	# 子类可以实现历史记录清理功能
	pass

## 当条件满足时调用
func on_condition_met(context: ExecutionContext):
	# 防御性编程：检查 context 是否为空
	if context == null:
		_log_warning("ExecutionContext is null in on_condition_met")
	
	_log_debug("Condition met: %s" % get_description())
	# 子类可以重写此方法来响应条件满足事件

## 当条件不满足时调用
func on_condition_failed(context: ExecutionContext):
	# 防御性编程：检查 context 是否为空
	if context == null:
		_log_warning("ExecutionContext is null in on_condition_failed")
	
	_log_debug("Condition failed: %s" % get_description())
	# 子类可以重写此方法来响应条件不满足事件

## 获取条件的性能指标
## returns: Dictionary - 性能指标字典
func get_performance_metrics() -> Dictionary:
	return {
		"check_count": check_count,
		"last_check_time": last_check_time,
		"average_check_time": 0.0  # 需要在子类中实现
	}

## 优化条件检查
## context: ExecutionContext - 执行上下文
## returns: bool - 优化后的检查结果
func optimized_check(context: ExecutionContext) -> bool:
	# 防御性编程：检查 context 是否为空
	if context == null:
		_log_error("ExecutionContext is null, cannot perform optimized check")
		return false
	
	# 默认使用标准检查
	# 子类可以重写此方法来实现优化检查
	return check(context)

## 获取条件的调试信息
## returns: String - 调试信息字符串
func get_debug_info() -> String:
	return "Condition: %s | Enabled: %s | Checks: %d | Last: %s" % [
		get_description(),
		str(enabled),
		check_count,
		str(last_result)
	]

## 批量操作方法

## 批量检查条件
## contexts: Array[ExecutionContext] - 执行上下文数组
## returns: Array[bool] - 条件检查结果数组
func check_batch(contexts: Array[ExecutionContext]) -> Array[bool]:
	var results: Array[bool] = []
	var start_time = Time.get_ticks_msec() / 1000.0
	
	for context in contexts:
		var result = check(context)
		results.append(result)
	
	var end_time = Time.get_ticks_msec() / 1000.0
	var total_time = end_time - start_time
	var avg_time = total_time / contexts.size() if contexts.size() > 0 else 0.0
	
	_log_debug("批量条件检查完成: 检查了 %d 个上下文, 平均时间: %.4f 秒" % [contexts.size(), avg_time])
	return results

## 批量优化检查条件
## contexts: Array[ExecutionContext] - 执行上下文数组
## returns: Array[bool] - 条件检查结果数组
func optimized_check_batch(contexts: Array[ExecutionContext]) -> Array[bool]:
	var results: Array[bool] = []
	var start_time = Time.get_ticks_msec() / 1000.0
	
	for context in contexts:
		var result = optimized_check(context)
		results.append(result)
	
	var end_time = Time.get_ticks_msec() / 1000.0
	var total_time = end_time - start_time
	var avg_time = total_time / contexts.size() if contexts.size() > 0 else 0.0
	
	_log_debug("批量优化条件检查完成: 检查了 %d 个上下文, 平均时间: %.4f 秒" % [contexts.size(), avg_time])
	return results

## 批量验证条件
## contexts: Array[ExecutionContext] - 执行上下文数组
## returns: Array[bool] - 条件验证结果数组
func validate_batch(contexts: Array[ExecutionContext]) -> Array[bool]:
	var results: Array[bool] = []
	
	for context in contexts:
		var result = is_valid(context)
		results.append(result)
	
	_log_debug("批量条件验证完成: 验证了 %d 个上下文" % contexts.size())
	return results

## 批量获取条件状态信息
## contexts: Array[ExecutionContext] - 执行上下文数组
## returns: Array[Dictionary] - 条件状态信息数组
func get_status_info_batch(contexts: Array[ExecutionContext]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	
	for context in contexts:
		var status_info = get_status_info()
		results.append(status_info)
	
	_log_debug("批量获取条件状态信息完成: 获取了 %d 个上下文的状态" % contexts.size())
	return results

## 缓存管理方法

## 检查缓存是否有效
## context: ExecutionContext - 执行上下文
## returns: bool - 缓存是否有效
func _is_cache_valid(context: ExecutionContext) -> bool:
	if _cache_timestamp == 0.0:
		return false
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var cache_age = current_time - _cache_timestamp
	
	# 检查缓存是否过期
	if cache_age > cache_duration:
		_log_debug("Cache expired (age: %.2f > duration: %.2f)" % [cache_age, cache_duration])
		return false
	
	# 检查上下文是否发生变化
	var current_context_hash = _generate_context_hash(context)
	if current_context_hash != _cache_context_hash:
		_log_debug("Context changed, cache invalidated")
		return false
	
	return true

## 更新缓存
## result: bool - 条件检查结果
## context: ExecutionContext - 执行上下文
func _update_cache(result: bool, context: ExecutionContext):
	_cached_result = result
	_cache_timestamp = Time.get_ticks_msec() / 1000.0
	_cache_context_hash = _generate_context_hash(context)
	_log_debug("Cache updated: %s (context hash: %d)" % ["true" if result else "false", _cache_context_hash])

## 生成上下文哈希
## context: ExecutionContext - 执行上下文
## returns: int - 上下文哈希值
func _generate_context_hash(context: ExecutionContext) -> int:
	if context == null:
		return 0

	var hash_value = context.execution_id.hash()

	if cache_context_changes:
		# 包含所有依赖变量
		for dep_var in get_dependencies():
			var var_value = context.get_variable(dep_var)
			hash_value ^= (hash_value << 5) + str(var_value).hash()

		# 如果启用，包含所有上下文变量
		if hash_all_variables:
			for var_name in context.local_variables:
				var var_value = context.local_variables[var_name]
				hash_value ^= (hash_value << 3) + str(var_value).hash()

	return hash_value

## 手动清除结果缓存
func clear_result_cache():
	_cached_result = false
	_cache_timestamp = 0.0
	_cache_context_hash = 0
	var condition_name = get_description()
	_log_debug("[%s] 结果缓存已清除" % condition_name)

## 清除特定上下文的缓存
func clear_context_cache(context: ExecutionContext):
	if context:
		var hash = _generate_context_hash(context)
		var condition_name = get_description()
		# 如果哈希匹配，清除缓存
		if hash == _cache_context_hash:
			_cached_result = false
			_cache_timestamp = 0.0
			_cache_context_hash = 0
			_log_debug("[%s] 上下文缓存已清除 (hash: %d)" % [condition_name, hash])

## 清除缓存
func clear_cache():
	_cached_result = false
	_cache_timestamp = 0.0
	_cache_context_hash = 0
	var condition_name = get_description()
	_log_debug("[%s] 所有缓存已清除" % condition_name)

## 获取缓存信息
## returns: Dictionary - 缓存信息字典
func get_cache_info() -> Dictionary:
	var current_time = Time.get_ticks_msec() / 1000.0
	var cache_age = current_time - _cache_timestamp if _cache_timestamp > 0 else 0.0
	var is_valid = _cache_timestamp > 0 and cache_age <= cache_duration
	
	return {
		"enabled": enable_cache,
		"duration": cache_duration,
		"cached_result": _cached_result,
		"cache_timestamp": _cache_timestamp,
		"cache_age": cache_age,
		"context_hash": _cache_context_hash,
		"is_valid": is_valid
	}

## 依赖关系管理方法

## 添加条件依赖关系
## @param depends_on: 依赖的变量名数组
func add_dependencies(depends_on: Array[String]) -> void:
	# 子类可以重写此方法来添加特定的依赖关系
	_log_debug("添加条件依赖关系: %s" % str(depends_on))

## 移除条件依赖关系
## @param depends_on: 要移除的依赖变量名数组
func remove_dependencies(depends_on: Array[String]) -> void:
	# 子类可以重写此方法来移除特定的依赖关系
	_log_debug("移除条件依赖关系: %s" % str(depends_on))

## 获取条件依赖关系图
## @return: 依赖关系图数据结构
func get_dependency_graph() -> Dictionary:
	var dependencies = get_dependencies()
	var affected_variables = get_affected_variables()
	
	var graph = {
		"nodes": [],
		"edges": [],
		"condition_info": {
			"type": get_condition_type(),
			"description": get_description(),
			"enabled": enabled,
			"priority": get_priority()
		}
	}
	
	# 添加条件节点
	graph["nodes"].append({
		"id": "condition_" + str(get_instance_id()),
		"label": get_description(),
		"type": "condition"
	})
	
	# 添加依赖变量节点和边
	for dep_var in dependencies:
		graph["nodes"].append({
			"id": dep_var,
			"label": dep_var,
			"type": "dependency"
		})
		graph["edges"].append({
			"from": dep_var,
			"to": "condition_" + str(get_instance_id()),
			"type": "dependency"
		})
	
	# 添加影响变量节点和边
	for affected_var in affected_variables:
		graph["nodes"].append({
			"id": affected_var,
			"label": affected_var,
			"type": "affected"
		})
		graph["edges"].append({
			"from": "condition_" + str(get_instance_id()),
			"to": affected_var,
			"type": "affects"
		})
	
	return graph

## 检查条件依赖关系是否满足
## @param context: ExecutionContext - 执行上下文
## @return: bool - 依赖关系是否满足
func check_dependencies(context: ExecutionContext) -> bool:
	if context == null:
		_log_error("ExecutionContext is null, cannot check dependencies")
		return false
	
	var dependencies = get_dependencies()
	for dep_var in dependencies:
		if not context.has_variable(dep_var):
			_log_debug("依赖变量不存在: %s" % dep_var)
			return false
	
	_log_debug("所有依赖关系满足: %s" % str(dependencies))
	return true

## 获取条件依赖关系状态
## @param context: ExecutionContext - 执行上下文
## @return: Dictionary - 依赖关系状态字典
func get_dependency_status(context: ExecutionContext) -> Dictionary:
	var dependencies = get_dependencies()
	var status = {
		"total_dependencies": dependencies.size(),
		"satisfied_dependencies": 0,
		"missing_dependencies": [],
		"dependency_details": {}
	}
	
	for dep_var in dependencies:
		var exists = context.has_variable(dep_var) if context else false
		var value = context.get_variable(dep_var) if context else null
		
		status["dependency_details"][dep_var] = {
			"exists": exists,
			"value": value,
			"type": typeof(value) if value != null else TYPE_NIL
		}
		
		if exists:
			status["satisfied_dependencies"] += 1
		else:
			status["missing_dependencies"].append(dep_var)
	
	return status

## 批量检查条件依赖关系
## @param contexts: Array[ExecutionContext] - 执行上下文数组
## @return: Array[bool] - 依赖关系检查结果数组
func check_dependencies_batch(contexts: Array[ExecutionContext]) -> Array[bool]:
	var results: Array[bool] = []
	
	for context in contexts:
		var result = check_dependencies(context)
		results.append(result)
	
	_log_debug("批量检查条件依赖关系完成: 检查了 %d 个上下文" % contexts.size())
	return results

## 批量获取条件依赖关系状态
## @param contexts: Array[ExecutionContext] - 执行上下文数组
## @return: Array[Dictionary] - 依赖关系状态数组
func get_dependency_status_batch(contexts: Array[ExecutionContext]) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	
	for context in contexts:
		var status = get_dependency_status(context)
		results.append(status)
	
	_log_debug("批量获取条件依赖关系状态完成: 获取了 %d 个上下文的状态" % contexts.size())
	return results

## 获取条件依赖关系可视化数据
## @return: Dictionary - 可视化数据
func get_dependency_visualization_data() -> Dictionary:
	var dependencies = get_dependencies()
	var affected_variables = get_affected_variables()
	
	var visualization_data = {
		"condition": {
			"id": "condition_" + str(get_instance_id()),
			"name": get_description(),
			"type": get_condition_type(),
			"enabled": enabled,
			"priority": get_priority()
		},
		"dependencies": dependencies,
		"affected_variables": affected_variables,
		"dependency_graph": get_dependency_graph()
	}
	
	# 如果有 FuseError，添加错误信息
	if _fuse_error:
		visualization_data["fuse_error"] = _fuse_error.get_error_details()
	
	return visualization_data

## 创建 FuseError 实例
## message: String - 错误消息
## error_type: FuseError.ErrorType - 错误类型
## context: Dictionary - 错误上下文
func _create_fuse_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR, context: Dictionary = {}):
	var error_context = context.duplicate()
	error_context["condition_type"] = get_condition_type()
	error_context["condition_description"] = get_description()
	
	_fuse_error = FuseError.create_with_context(error_type, "BaseCondition", message, error_context)

## 创建本地化 FuseError 实例
##
## 参数：
## - message_key: String - 翻译键
## - error_type: FuseError.ErrorType - 错误类型
## - args: Dictionary - 翻译参数（可选）
## - context: Dictionary - 错误上下文（可选）
func _create_fuse_error_localized(
	message_key: String,
	error_type: FuseError.ErrorType = FuseError.ErrorType.RUNTIME_ERROR,
	args: Dictionary = {},
	context: Dictionary = {}
) -> void:
	# 尝试本地化错误消息
	var localized_message = message_key
	if _fuse_localization_class == null:
		_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 确保翻译系统已初始化
	if _fuse_localization_class and _fuse_localization_class.has_method("init"):
		_fuse_localization_class.init()

	if _fuse_localization_class and _fuse_localization_class.has_method("translate_format"):
		if args.is_empty():
			localized_message = _fuse_localization_class.translate(message_key)
		else:
			localized_message = _fuse_localization_class.translate_format(message_key, args)
	else:
		# 回退：手动替换参数
		for key in args:
			localized_message = localized_message.replace("{%s}" % key, str(args[key]))

	# 创建 FuseError 实例
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	error_context["condition_type"] = get_condition_type()
	error_context["condition_description"] = get_description()

	_fuse_error = FuseError.create_with_context(error_type, "BaseCondition", localized_message, error_context)

## 获取 FuseError 实例
## returns: FuseError - FuseError 实例，如果没有错误则返回 null
func get_fuse_error() -> FuseError:
	return _fuse_error

## 检查是否有 FuseError
## returns: bool - 是否有 FuseError
func has_fuse_error() -> bool:
	return _fuse_error != null

## 获取条件元数据
##
## 子类应实现此方法以提供条件的元数据信息
## returns: ConditionMetadata - 条件元数据对象
static func _get_condition_metadata() -> ConditionMetadata:
	return null
