@tool
@icon("res://addons/fuse/icons/builtin/MemberMethod.png")
extends BaseInstruction
class_name RunTargetNodeFunction

## 修复记录:
## - 2026-02-05: 使用 FuseNodeUtils 替代自定义节点查找逻辑
##            添加场景加载顺序保护
##            统一运行时节点解析为 context.get_node()
##            移除不再需要的辅助方法 (_find_node_by_name, _get_target_node)
## - 2026-02-11: 为 result_variable_scope 添加三层变量系统支持
##            添加 ScopeSource 枚举和相关属性
##            参考: addons/fuse/docs/zh_CN/system_docs/architecture/variable_system_design.md

## 性能监控变量
var _performance_stats: Dictionary = {
	"method_cache_refresh_count": 0,
	"node_lookup_count": 0,
	"function_info_creation_count": 0,
	"property_list_update_count": 0,
	"total_execution_time": 0.0,
	"method_cache_refresh_time": 0.0,
	"node_lookup_time": 0.0,
	"function_info_creation_time": 0.0
}

## 作用域来源（仅当 result_variable_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_RUN_TARGET_NODE_FUNCTION_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_RUN_TARGET_NODE_FUNCTION_DESC"
	metadata.keywords = ["函数", "方法", "调用", "节点", "动态", "参数", "function", "method", "call", "node", "dynamic", "parameter"]
	# 设置指令选择器图标
	metadata.builtin_icon = "MemberMethod"
	return metadata

## 类型名称常量（用于高效的类型名称查找）
const TYPE_NAMES = {
	TYPE_NIL: "null",
	TYPE_BOOL: "bool",
	TYPE_INT: "int",
	TYPE_FLOAT: "float",
	TYPE_STRING: "String",
	TYPE_VECTOR2: "Vector2",
	TYPE_VECTOR2I: "Vector2i",
	TYPE_VECTOR3: "Vector3",
	TYPE_VECTOR3I: "Vector3i",
	TYPE_COLOR: "Color",
	TYPE_ARRAY: "Array",
	TYPE_DICTIONARY: "Dictionary",
	TYPE_NODE_PATH: "NodePath",
	TYPE_OBJECT: "Object",
	TYPE_PACKED_BYTE_ARRAY: "PackedByteArray",
	TYPE_PACKED_INT32_ARRAY: "PackedInt32Array",
	TYPE_PACKED_FLOAT32_ARRAY: "PackedFloat32Array",
	TYPE_PACKED_STRING_ARRAY: "PackedStringArray",
	TYPE_PACKED_VECTOR2_ARRAY: "PackedVector2Array",
	TYPE_PACKED_VECTOR3_ARRAY: "PackedVector3Array",
	TYPE_PACKED_COLOR_ARRAY: "PackedColorArray"
}

## 节点配置
var target_node: NodePath = "":
	set(value):
		target_node = value
		_update_target_node_info()
		_update_resource_name()
		_performance_stats.property_list_update_count += 1
		notify_property_list_changed()

## 方法配置
var target_function: String = "":
	set(value):
		var old_function = target_function
		target_function = value
		_update_function_info()
		_update_resource_name()
		_performance_stats.property_list_update_count += 1
		notify_property_list_changed()
		_on_function_changed(old_function, value)

## 方法过滤配置
var method_inheritance_levels: int = 1:  # 默认为仅当前类
	set(value):
		# 防止循环触发
		if _is_updating_properties:
			return
		# 直接存储枚举值，不需要转换
		method_inheritance_levels = value
		_cache_valid = false
		# 触发延迟刷新（在编辑器中）
		if Engine.is_editor_hint():
			_request_method_refresh()
	get:
		return method_inheritance_levels

var exclude_getter_methods: bool = true:
	set(value):
		# 防止循环触发
		if _is_updating_properties:
			return
		exclude_getter_methods = value
		_cache_valid = false
		# 触发延迟刷新（在编辑器中）
		if Engine.is_editor_hint():
			_request_method_refresh()

## 调试模式（启用后会输出详细的方法过滤信息）
var debug_filtering: bool = false:
	set(value):
		debug_filtering = value
		# 调试模式改变时也触发刷新
		if Engine.is_editor_hint():
			_request_method_refresh()

## 将枚举值转换为继承级别位掩码
## 0 = 所有级别 (0xFFFFFFFF)
## 1 = 仅当前类 (1 << 0 = 1)
## 2 = 仅父类 (1 << 1 = 2)
## 3 = 当前类+父类 (1 | 2 = 3)
## 4 = 当前类+前两级父类 (1 | 2 | 4 = 7)
func _enum_to_inheritance_bitmask(enum_value: int) -> int:
	match enum_value:
		0: return 0xFFFFFFFF  # 所有级别
		1: return 1 << 0      # 仅当前类
		2: return 1 << 1      # 仅父类
		3: return (1 << 0) | (1 << 1)  # 当前类+父类
		4: return (1 << 0) | (1 << 1) | (1 << 2)  # 当前类+前两级父类
		_: return 0xFFFFFFFF  # 默认所有级别

## 生成继承级别过滤选项的提示字符串（动态包含类名）
func _get_inheritance_filter_hint_string() -> String:
	# 初始化静态缓存
	_init_inheritance_base_cache()

	# 使用缓存的继承链，避免在 Inspector 回调中访问节点
	if not _node_cache_valid or _cached_inheritance_chain.is_empty():
		# 缓存无效时，使用缓存的通用文本
		return ",".join(_cached_inheritance_base_options)

	var inheritance_chain = _cached_inheritance_chain

	# 构建带有实际类名的选项文本
	var options = []

	# 选项 0: 所有级别
	options.append(_cached_inheritance_base_options[0])

	# 选项 1: 仅当前类
	var current_class_name = inheritance_chain[0].class_name
	var current_only = _cached_inheritance_base_options[1]
	options.append("%s (%s)" % [current_only, current_class_name])

	# 选项 2: 仅父类
	if inheritance_chain.size() > 1:
		var parent_class_name = inheritance_chain[1].class_name
		var parent_only = _cached_inheritance_base_options[2]
		options.append("%s (%s)" % [parent_only, parent_class_name])
	else:
		options.append(_cached_inheritance_base_options[2])

	# 选项 3: 当前类+父类
	if inheritance_chain.size() > 1:
		var current_parent = _cached_inheritance_base_options[3]
		options.append("%s (%s + %s)" % [current_parent, current_class_name, inheritance_chain[1].class_name])
	else:
		options.append(_cached_inheritance_base_options[3])

	# 选项 4: 当前类+前两级父类
	if inheritance_chain.size() > 2:
		var two_parents = _cached_inheritance_base_options[4]
		options.append("%s (%s + %s + %s)" % [
			two_parents,
			current_class_name,
			inheritance_chain[1].class_name,
			inheritance_chain[2].class_name
		])
	else:
		options.append(_cached_inheritance_base_options[4])

	return ",".join(options)

## 参数绑定管理器（替代手动参数管理）
var _binding_manager: ParameterBinding.ParameterBindingManager = ParameterBinding.ParameterBindingManager.new()

## 兼容性属性：获取/设置参数值数组
var function_args: Array:
	get:
		return _binding_manager.get_runtime_args()
	set(value):
		_apply_function_args(value)

## 从数组同步参数值到绑定管理器（兼容旧代码直接赋值）
func _apply_function_args(args: Array) -> void:
	if _is_updating_properties:
		return
	for i in range(args.size()):
		if i < _binding_manager.get_param_count():
			_binding_manager.parameters[i].current_value = args[i]
		else:
			var bp = ParameterBinding.BoundParameter.new()
			bp.index = i
			bp.current_value = args[i]
			_binding_manager.parameters.append(bp)
	_update_resource_name()

## 添加自定义属性设置处理
func _set(property: StringName, value: Variant) -> bool:
	if _binding_manager.handle_set(property, value):
		_update_resource_name()
		return true
	return false

## 添加自定义属性获取处理
func _get(property: StringName) -> Variant:
	return _binding_manager.handle_get(property)

## 返回值处理
var store_result: bool = false:
	set(value):
		store_result = value
		_update_resource_name()
		_performance_stats.property_list_update_count += 1
		notify_property_list_changed()

var result_variable_name: String = "":
	set(value):
		result_variable_name = value
		_update_resource_name()

## 结果变量作用域（三层变量系统）
var result_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		result_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 结果变量作用域来源（仅当 result_variable_scope == SCOPE 时使用）
var result_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		result_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 结果变量自定义作用域 ID（CUSTOM_ID 模式使用）
var result_custom_scope_id: String = "":
	set(value):
		result_custom_scope_id = value
		_update_resource_name()

## 结果变量目标节点路径（TARGET_NODE 模式使用）
var result_target_node_path: NodePath = NodePath(""):
	set(value):
		result_target_node_path = value
		_update_resource_name()

## 运行时状态
var _target_node_instance: Node = null
var _available_functions: Array[Dictionary] = []
var _current_function_info: FunctionInfo = null
var _function_call_result: Variant = null
var _method_cache: Dictionary = {}
var _cache_valid: bool = false

## 线程安全缓存
## 缓存目标节点实例和继承链信息，避免在 Inspector 回调中访问节点
var _cached_target_node_instance: Node = null
var _cached_inheritance_chain: Array[Dictionary] = []
var _node_cache_valid: bool = false

## 性能优化：缓存机制
var _target_node_path_hash: int = 0  # 缓存节点路径的哈希值
var _last_node_lookup_time: int = 0   # 上次节点查找的时间戳
var _node_lookup_cache_duration: int = 1000  # 节点查找缓存有效期（毫秒）
var _cached_method_signatures: Dictionary = {}  # 缓存方法签名，避免重复获取

## 序列化的方法缓存（用于编辑器到运行时的传递）
@export_storage var serialized_method_cache: Array[Dictionary] = []:
	set(value):
		serialized_method_cache = value
		# 运行时反序列化缓存
		_deserialize_method_cache()

## 序列化的参数元数据（用于参数属性的持久化）
@export_storage var serialized_parameter_metadata: Array[Dictionary] = []

## 防止无限循环的标志
var _is_updating_properties: bool = false

## 临时变量实例（避免重复创建）
static var _temp_function_info_instance: FunctionInfo = null

## 静态缓存：变量作用域枚举
static var _cached_variable_scopes: Array[String] = []
static var _variable_scopes_cached: bool = false

## 静态缓存：继承级别过滤选项（基础文本，不含类名）
static var _cached_inheritance_base_options: Array[String] = []
static var _inheritance_base_cached: bool = false

## 静态缓存：提示文本
static var _cached_hint_texts: Dictionary = {}
static var _hint_texts_cached: bool = false

## 初始化变量作用域缓存
static func _init_variable_scopes_cache() -> void:
	if _variable_scopes_cached:
		return

	_cached_variable_scopes = [
		FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL"),
		FuseLocalization.translate("FUSE_VARIABLE_SCOPE_SCOPE"),
		FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL")
	]

	_variable_scopes_cached = true

## 初始化继承级别基础选项缓存
static func _init_inheritance_base_cache() -> void:
	if _inheritance_base_cached:
		return

	_cached_inheritance_base_options = [
		FuseLocalization.translate("FUSE_METHOD_INHERITANCE_ALL_LEVELS"),
		FuseLocalization.translate("FUSE_METHOD_INHERITANCE_CURRENT_CLASS_ONLY"),
		FuseLocalization.translate("FUSE_METHOD_INHERITANCE_PARENT_CLASS_ONLY"),
		FuseLocalization.translate("FUSE_METHOD_INHERITANCE_CURRENT_AND_PARENT"),
		FuseLocalization.translate("FUSE_METHOD_INHERITANCE_CURRENT_AND_TWO_PARENTS")
	]

	_inheritance_base_cached = true

## 初始化提示文本缓存
static func _init_hint_texts_cache() -> void:
	if _hint_texts_cached:
		return

	_cached_hint_texts = {
		"no_methods": FuseLocalization.translate("FUSE_METHOD_FILTER_NO_METHODS"),
		"select_node_first": FuseLocalization.translate("FUSE_METHOD_FILTER_SELECT_NODE_FIRST")
	}

	_hint_texts_cached = true

## 设置指令元数据
func _setup_metadata():
	pass

## 标记是否已初始化（防止重复初始化）
var _resource_initialized: bool = false

## 同步恢复参数状态（不依赖节点访问，可在 _get_property_list 中安全调用）
func _restore_parameter_state():
	if target_function.is_empty():
		return

	# 先反序列化方法缓存（_recreate_function_info_from_metadata 优先从中获取完整信息）
	if not serialized_method_cache.is_empty() and _method_cache.is_empty():
		_deserialize_method_cache()

	# 如果 _set 已从 .tres 的动态属性恢复了参数值，只需重建 _current_function_info
	# 不要调用 _deserialize_parameter_metadata()，它会用过时的 null 值覆盖 _set 恢复的正确值
	if _binding_manager.get_param_count() > 0:
		if not _current_function_info:
			_recreate_function_info_from_metadata()
		return

	# 仅当 _set 没有恢复任何参数时，才从 serialized_parameter_metadata 恢复
	if not serialized_parameter_metadata.is_empty() and not _current_function_info:
		_deserialize_parameter_metadata()

## 延迟初始化（仅包含需要节点访问的操作，通过 call_deferred 调用）
func _initialize_after_load():
	# 如果有目标节点和函数，执行需要节点访问的初始化
	if target_node.is_empty() or target_function.is_empty():
		return

	# 同步恢复已完成，这里只做需要节点实例的操作
	if not _current_function_info:
		_update_target_node_info()
		if _target_node_instance:
			if _method_cache.has(target_function):
				var method_info = _method_cache[target_function]
				_current_function_info = FunctionInfo.new(method_info)
				_update_parameter_defaults()
				_serialize_parameter_metadata()
			else:
				_create_lightweight_function_info()
				_serialize_parameter_metadata()
			notify_property_list_changed()
	elif _target_node_instance == null:
		# _current_function_info 已通过同步恢复得到，但仍需刷新方法缓存
		_update_target_node_info()
		if _target_node_instance and _method_cache.is_empty():
			_refresh_method_cache()

## 更新目标节点信息
func _update_target_node_info():
	# 性能优化：检查节点路径是否真的改变了
	var current_path_hash = target_node.hash()
	if current_path_hash == _target_node_path_hash and _target_node_instance != null:
		# 性能优化：减少不必要的日志输出
		if log_level >= FuseLogger.LogLevel.DEBUG:
			_log_debug("目标节点路径未改变，跳过更新")
		return

	_target_node_instance = null
	_cache_valid = false
	_current_function_info = null
	_target_node_path_hash = current_path_hash
	_cached_method_signatures.clear()  # 清除方法签名缓存
	_node_cache_valid = false  # 使线程安全缓存失效

	if target_node.is_empty():
		return

	# 获取目标节点实例
	if Engine.is_editor_hint():
		_target_node_instance = _get_target_node_in_editor()
		# 更新线程安全缓存
		if _target_node_instance:
			_cached_target_node_instance = _target_node_instance
			_cached_inheritance_chain = FunctionManager.get_inheritance_chain(_target_node_instance)
			_node_cache_valid = true
	else:
		var root = Engine.get_main_loop().current_scene
		if root:
			_target_node_instance = root.get_node_or_null(target_node)

	if _target_node_instance:
		# 编辑器时预缓存方法信息，运行时直接使用
		_refresh_method_cache()
		if log_level >= FuseLogger.LogLevel.DEBUG:
			_log_debug("目标节点已更新: %s (%s)" % [_target_node_instance.name, _target_node_instance.get_class()])

## 更新函数信息
func _update_function_info():
	if target_function.is_empty():
		return

	# 优先从缓存中获取函数信息（不需要节点实例）
	if _method_cache.has(target_function):
		var start_time = Time.get_ticks_msec()
		var method_info = _method_cache[target_function]
		_current_function_info = FunctionInfo.new(method_info)
		var end_time = Time.get_ticks_msec()
		_performance_stats.function_info_creation_count += 1
		_performance_stats.function_info_creation_time += (end_time - start_time)

		# 构建参数绑定管理器（首次构建时不保留，函数变化时由 _on_function_changed 处理）
		_binding_manager.build_from_function_info(_current_function_info, _binding_manager.get_param_count() > 0)
		# 序列化参数元数据以便持久化
		if Engine.is_editor_hint():
			_serialize_parameter_metadata()
			notify_property_list_changed()

		if log_level >= FuseLogger.LogLevel.DEBUG:
			_log_debug("函数信息已更新: %s，耗时 %d ms" % [target_function, end_time - start_time])
	else:
		# 缓存中没有，尝试使用节点实例获取
		if not _target_node_instance:
			return

		# 运行时缓存为空，使用轻量级函数信息创建
		_create_lightweight_function_info()

## 轻量级函数信息创建（避免获取所有方法的开销）
func _create_lightweight_function_info():
	if not _target_node_instance or target_function.is_empty():
		return

	# 直接检查方法是否存在，避免获取所有方法
	if not _target_node_instance.has_method(target_function):
		_log_debug("目标节点没有方法: %s" % target_function)
		return

	# _log_debug("轻量级函数信息创建开始")

	# 尝试获取方法的真实签名信息
	var method_signature = _get_method_signature(target_function)

	# 创建最小化的函数信息，只包含必要信息
	var lightweight_method_info = {
		"name": target_function,
		"args": [],  # 将根据用户提供的参数创建
		"return_val": TYPE_NIL,
		"flags": METHOD_FLAG_NORMAL
	}

	# 根据用户提供的参数数量和实际类型创建参数信息
	var args = _binding_manager.get_runtime_args()
	var param_count = args.size()
	lightweight_method_info.args = []
	for i in range(param_count):
		var actual_value = args[i] if i < args.size() else null
		var actual_type = typeof(actual_value) if actual_value != null else TYPE_NIL

		# 如果用户值为null，尝试从方法签名中获取正确的类型
		if actual_type == TYPE_NIL and method_signature and i < method_signature.args.size():
			actual_type = method_signature.args[i].type

		var param_info = {
			"name": "arg_%d" % i,
			"type": actual_type,  # 使用实际值的类型或方法签名中的类型
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"usage": PROPERTY_USAGE_DEFAULT
		}

		# 只有当用户值不为null时才设置默认值，否则让系统使用类型默认值
		if actual_value != null:
			param_info["default_value"] = actual_value

		lightweight_method_info.args.append(param_info)

	_current_function_info = FunctionInfo.new(lightweight_method_info)
	# _log_debug("轻量级函数信息创建完成")

	# 保留用户已设置的值，仅更新元数据和 null 参数的默认值
	_binding_manager.build_from_function_info(_current_function_info, true)

	_log_debug("  调用后 function_args: %s" % str(_binding_manager.get_runtime_args()))
	_log_debug("轻量级函数信息创建成功: %s (参数数量: %d)" % [target_function, param_count])

## 获取方法签名信息（用于轻量级创建）
func _get_method_signature(method_name: String) -> Dictionary:
	if not _target_node_instance:
		return {}

	# 性能优化：使用缓存避免重复获取方法签名
	var cache_key = str(_target_node_instance.get_instance_id()) + ":" + method_name
	if _cached_method_signatures.has(cache_key):
		_log_debug("从缓存获取方法签名: %s" % method_name)
		return _cached_method_signatures[cache_key]

	# 使用Godot的反射机制获取方法信息
	var method_list = _target_node_instance.get_method_list()
	for method in method_list:
		if method.name == method_name:
			_log_debug("找到方法签名: %s，参数数量: %d" % [method_name, method.args.size()])
			# 缓存方法签名
			_cached_method_signatures[cache_key] = method
			return method

	_log_debug("未找到方法签名: %s" % method_name)
	return {}

## 反序列化方法缓存
func _deserialize_method_cache():
	if serialized_method_cache.is_empty():
		return

	_method_cache.clear()
	for method_data in serialized_method_cache:
		var method_name = method_data.get("name", "")
		if not method_name.is_empty():
			_method_cache[method_name] = method_data

	_cache_valid = true
	_log_debug("反序列化方法缓存完成，加载 %d 个方法" % _method_cache.size())

## 序列化方法缓存
func _serialize_method_cache():
	if _method_cache.is_empty():
		return

	serialized_method_cache.clear()
	for method_name in _method_cache.keys():
		serialized_method_cache.append(_method_cache[method_name])

	_log_debug("序列化方法缓存完成，保存 %d 个方法" % serialized_method_cache.size())

## 反序列化参数元数据
func _deserialize_parameter_metadata():
	if serialized_parameter_metadata.is_empty():
		return

	# 从序列化元数据恢复绑定管理器
	_binding_manager.deserialize(serialized_parameter_metadata)

	# 如果当前没有函数信息，尝试从参数元数据重建
	if not _current_function_info and not target_function.is_empty():
		_recreate_function_info_from_metadata()

## 从参数元数据或方法缓存重建函数信息
func _recreate_function_info_from_metadata():
	# 优先从方法缓存中获取函数信息（更完整）
	if _method_cache.has(target_function):
		var method_info = _method_cache[target_function]
		_current_function_info = FunctionInfo.new(method_info)
		# 保留资源加载时通过 _set 已存储的参数值
		_binding_manager.build_from_function_info(_current_function_info, true)
		return

	# 备选：从绑定管理器已有的参数重建
	if _binding_manager.get_param_count() == 0:
		return

	var method_info = {
		"name": target_function,
		"args": [],
		"return_val": TYPE_NIL,
		"flags": METHOD_FLAG_NORMAL
	}

	for i in range(_binding_manager.get_param_count()):
		var param = _binding_manager.get_parameter(i)
		method_info.args.append({
			"name": param.name,
			"type": param.type,
			"hint": param.hint as int,
			"hint_string": param.hint_string,
			"default_value": param.default_value,
			"usage": PROPERTY_USAGE_DEFAULT
		})

	_current_function_info = FunctionInfo.new(method_info)

## 序列化参数元数据
func _serialize_parameter_metadata():
	serialized_parameter_metadata = _binding_manager.serialize()
	# 触发资源保存（标记为已更改）
	if Engine.is_editor_hint():
		emit_changed()

## 请求方法缓存刷新（延迟调用，避免线程问题）
func _request_method_refresh():
	# 使用 call_deferred 避免在属性 setter 中直接访问节点
	call_deferred("_refresh_method_cache_deferred")

## 延迟刷新方法缓存
func _refresh_method_cache_deferred():
	# 确保有目标节点
	if target_node.is_empty():
		_node_cache_valid = false
		return

	# 获取目标节点实例
	var target_instance = _get_target_node_in_editor()

	if not target_instance:
		_log_debug("无法获取目标节点实例进行方法刷新")
		_node_cache_valid = false
		return

	# 更新线程安全缓存
	_cached_target_node_instance = target_instance
	_cached_inheritance_chain = FunctionManager.get_inheritance_chain(target_instance)
	_node_cache_valid = true

	# 刷新方法缓存
	_refresh_method_cache()
	# 通知属性列表已更改
	notify_property_list_changed()

## 刷新方法缓存
func _refresh_method_cache():
	var start_time = Time.get_ticks_msec()
	_performance_stats.method_cache_refresh_count += 1

	# 避免在后台线程中调用 _has_valid_target_node，直接检查路径
	if target_node.is_empty():
		return

	# 在编辑器中获取目标节点
	var target_instance = _target_node_instance
	if not target_instance:
		if Engine.is_editor_hint():
			target_instance = _get_target_node_in_editor()
		else:
			var root = Engine.get_main_loop().current_scene
			if root:
				target_instance = root.get_node_or_null(target_node)

	if not target_instance:
		_log_debug("无法获取目标节点实例")
		return

	# 性能优化：检查是否真的需要刷新缓存
	var instance_id = target_instance.get_instance_id()
	var cache_key = str(instance_id) + "_method_cache"

	# 如果已经有缓存且实例未变，跳过刷新
	if _method_cache.size() > 0 and _cache_valid:
		var end_time = Time.get_ticks_msec()
		_performance_stats.method_cache_refresh_time += (end_time - start_time)
		_log_debug("方法缓存仍然有效，跳过刷新，耗时 %d ms" % (end_time - start_time))
		return

	_method_cache.clear()

	# 使用配置的过滤参数获取方法列表
	# 必须使用 FunctionManager 以支持继承级别过滤和 getter 过滤
	var bitmask = _enum_to_inheritance_bitmask(method_inheritance_levels)

	var methods = FunctionManager.get_callable_methods(target_instance, bitmask, exclude_getter_methods, debug_filtering)

	# 性能优化：预创建字典
	_method_cache = {}

	for method in methods:
		var method_name = method.get("name", "")
		if not method_name.is_empty():
			# 只存储必要的信息，减少内存占用
			# 保留继承级别信息以便后续使用
			var lightweight_method = {
				"name": method.name,
				"args": method.get("args", []),
				"return_val": method.get("return_val", TYPE_NIL),
				"flags": method.get("flags", METHOD_FLAG_NORMAL),
				"defined_in_class": method.get("defined_in_class", ""),
				"inheritance_level": method.get("inheritance_level", 0)
			}
			_method_cache[method_name] = lightweight_method

	_cache_valid = true

	# 批量缓存 Callable，后续调用时跳过字符串查找
	var method_names: Array[String] = []
	for method_name in _method_cache.keys():
		method_names.append(method_name)
	FunctionManager.cache_callables_for_node(target_instance, method_names)

	var end_time = Time.get_ticks_msec()
	_performance_stats.method_cache_refresh_time += (end_time - start_time)

	# 编辑器时序列化缓存到资源属性
	if Engine.is_editor_hint():
		_serialize_method_cache()

## 更新参数默认值
func _update_parameter_defaults():
	if not _current_function_info or _is_updating_properties:
		return
	_binding_manager.build_from_function_info(_current_function_info)

## 获取类型名称（用于显示）
func _get_type_name(type: int) -> String:
	return TYPE_NAMES.get(type, "Unknown")

## 函数变化时的处理
func _on_function_changed(old_function: String, new_function: String):
	if old_function == new_function:
		return

	_log_debug_localized("FUSE_LOG_FUNCTION_CHANGED", {"old_function": old_function, "new_function": new_function})

	if _current_function_info:
		_binding_manager.build_from_function_info(_current_function_info)
	else:
		_binding_manager.clear()

## 更新资源名称
func _update_resource_name():
	# 性能优化：减少字符串操作，只在必要时更新
	var new_name = _build_resource_name()
	if new_name != resource_name:
		resource_name = new_name

## 构建资源名称（分离逻辑以便优化）
func _build_resource_name() -> String:
	var parts = []

	# 基础信息
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RUN_FUNCTION_BASE"))

	# 目标节点信息
	if not target_node.is_empty():
		parts.append(FuseLocalization.translate_format(
			"FUSE_INSTRUCTION_RUN_FUNCTION_TARGET_NODE",
			{"node": _get_node_display_name(target_node)}
		))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RUN_FUNCTION_NO_NODE"))

	# 函数信息
	if not target_function.is_empty():
		parts.append(FuseLocalization.translate_format(
			"FUSE_INSTRUCTION_RUN_FUNCTION_CALL",
			{"function": target_function}
		))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RUN_FUNCTION_NO_FUNCTION"))

	# 参数信息
	if _binding_manager.get_param_count() > 0:
		parts.append(FuseLocalization.translate_format(
			"FUSE_INSTRUCTION_RUN_FUNCTION_PARAMS",
			{"count": str(_binding_manager.get_param_count())}
		))

	# 返回值处理
	if store_result:
		if not result_variable_name.is_empty():
			var scope_name: String
			match result_variable_scope:
				BaseVariable.VariableScope.LOCAL:
					scope_name = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL")
				BaseVariable.VariableScope.SCOPE:
					scope_name = VariableScopeUtils.get_scope_source_string(
						result_scope_source as VariableScopeUtils.ScopeSource,
						result_custom_scope_id,
						result_target_node_path
					)
				BaseVariable.VariableScope.GLOBAL:
					scope_name = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL")
				_:
					scope_name = FuseLocalization.translate("FUSE_SCOPE_UNKNOWN_STR")

			parts.append(FuseLocalization.translate_format(
				"FUSE_INSTRUCTION_RUN_FUNCTION_STORE_TO",
				{"scope": scope_name, "name": result_variable_name}
			))
		else:
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RUN_FUNCTION_STORE_UNNAMED"))

	# 组合最终名称
	return " ".join(parts)

## 获取方法名称列表（用于下拉选择）
func _get_method_names() -> Array[String]:
	var names: Array[String] = []

	# 移除自动刷新逻辑。
    # 理由：在编辑器启动/资源加载阶段，_method_cache 应该通过 _deserialize_method_cache
    # 从磁盘数据中恢复，而不需要实时去场景树里抓取。
    # 如果此时强制刷新，会导致 "Caller thread can't call" 错误。
	# if not _cache_valid:
	# 	_refresh_method_cache()

	for method_name in _method_cache.keys():
		names.append(method_name)

	# 按字母顺序排序
	names.sort()

	return names

## 检查是否有有效的目标节点
func _has_valid_target_node() -> bool:
	if target_node.is_empty():
		return false

	# 在编辑器中，检查是否可以获取到目标节点
	if Engine.is_editor_hint():
		var target_node = _get_target_node_in_editor()
		return target_node != null

	# 在运行时，只要有路径就认为有效（实际验证在执行时进行）
	return true

## 在编辑器中获取目标节点
func _get_target_node_in_editor() -> Node:
	if target_node.is_empty():
		return null

	# 使用 FuseNodeUtils 替代自定义逻辑
	var editor_interface = Engine.get_singleton("EditorInterface")
	if editor_interface:
		var edited_root = editor_interface.get_edited_scene_root()
		if edited_root:
			# 使用 find_node_from_resource_context 方法支持 Resource 上下文中的相对路径
			return FuseNodeUtils.find_node_from_resource_context(edited_root, self, target_node)

	return null

## 获取动态属性列表
func _get_property_list() -> Array[Dictionary]:
	# 惰性初始化 - 如果节点实例为 null 且在编辑器模式，尝试重新获取
	if Engine.is_editor_hint() and _target_node_instance == null and not target_node.is_empty():
		_update_target_node_info()

	# 首次调用时触发初始化（Resource 不会调用 _ready()）
	if not _resource_initialized and Engine.is_editor_hint():
		_resource_initialized = true
		# 同步恢复参数状态（不依赖节点访问，在属性列表生成前完成）
		_restore_parameter_state()
		# 延迟执行需要节点访问的初始化（方法缓存刷新等）
		call_deferred("_initialize_after_load")

	# 初始化所有静态缓存
	_init_variable_scopes_cache()
	_init_hint_texts_cache()

	if _is_updating_properties:
		return []

	var properties: Array[Dictionary] = []

	# 目标节点选择
	properties.append({
		"name": "target_node",
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		"hint_string": "Node",
		"usage": PROPERTY_USAGE_DEFAULT
	})

	# 方法选择（动态生成）
	   # 仅检查路径字符串，防止后台线程调用 get_node 崩溃
	if not target_node.is_empty():
		var method_names = _get_method_names()
		if method_names.size() > 0:
			properties.append({
				"name": "target_function",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": ",".join(method_names),
				"usage": PROPERTY_USAGE_DEFAULT
			})
		else:
			# 如果方法缓存为空但已有target_function值，仍然显示为可编辑
			if not target_function.is_empty():
				properties.append({
					"name": "target_function",
					"type": TYPE_STRING,
					"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
					"hint_string": target_function,
					"usage": PROPERTY_USAGE_DEFAULT
				})
			else:
				properties.append({
					"name": "target_function",
					"type": TYPE_STRING,
					"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
					"hint_string": _cached_hint_texts["no_methods"],
					"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_READ_ONLY
				})
	else:
		properties.append({
			"name": "target_function",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
			"hint_string": _cached_hint_texts["select_node_first"],
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_READ_ONLY
		})

	# 方法过滤选项（仅在编辑器中显示）
	if Engine.is_editor_hint():
		# 继承级别过滤选项 - 动态生成包含类名的提示字符串
		properties.append({
			"name": "method_inheritance_levels",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": _get_inheritance_filter_hint_string(),
			"usage": PROPERTY_USAGE_DEFAULT
		})

		# Getter 方法过滤选项
		properties.append({
			"name": "exclude_getter_methods",
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		})

		# 调试模式选项
		properties.append({
			"name": "debug_filtering",
			"type": TYPE_BOOL,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		})

	# 动态参数配置
	# 只要有 target_function 和函数信息，就生成参数属性
	if target_function and _current_function_info:
		var param_properties = _get_parameter_properties()
		properties.append_array(param_properties)
	elif target_function and _binding_manager.get_param_count() > 0:
		# 备用方案：如果函数信息为空但绑定管理器有参数数据
		properties.append_array(_binding_manager.get_inspector_properties())


	# 返回值处理配置
	properties.append({
		"name": "store_result",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_DEFAULT
	})

	if store_result:
		properties.append({
			"name": "result_variable_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT
		})

		properties.append({
			"name": "result_variable_scope",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(_cached_variable_scopes),
			"usage": PROPERTY_USAGE_DEFAULT
		})

		# 只在 result_variable_scope == SCOPE 时显示 ScopeSource 配置
		if result_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				"name": "result_scope_source",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Nearest,Custom ID,Trigger Scope,Target Node",
				"usage": PROPERTY_USAGE_DEFAULT
			})

			# 根据作用域来源添加额外属性
			if result_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					"name": "result_custom_scope_id",
					"type": TYPE_STRING,
					"hint": PROPERTY_HINT_NONE,
					"usage": PROPERTY_USAGE_DEFAULT
				})
			elif result_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					"name": "result_target_node_path",
					"type": TYPE_NODE_PATH,
					"hint": PROPERTY_HINT_NONE,
					"usage": PROPERTY_USAGE_DEFAULT
				})

	return properties

## 条件化属性显示
func _validate_property(property: Dictionary) -> void:
	# 只有选择方法后才显示参数配置
	if target_function.is_empty() and property.name.begins_with("param_"):
		property.usage = PROPERTY_USAGE_NONE

	# 只有启用存储结果时才显示结果变量配置
	if not store_result and property.name in ["result_variable_name", "result_variable_scope"]:
		property.usage = PROPERTY_USAGE_READ_ONLY

	# 控制结果变量 ScopeSource 属性可见性（仅在 result_variable_scope == SCOPE 时显示）
	if result_variable_scope == BaseVariable.VariableScope.SCOPE:
		# 将本地枚举转换为 VariableScopeUtils 枚举
		var utils_scope_source = _convert_to_utils_scope_source(result_scope_source)
		VariableScopeUtils.validate_scope_source_property(property, utils_scope_source)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["result_scope_source", "result_custom_scope_id", "result_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 如果没有选择目标节点（只检查路径是否设置，不检查实例，避免线程报错），禁用函数选择
	if target_node.is_empty() and property.name == "target_function":
		property.usage = PROPERTY_USAGE_READ_ONLY

## 转换本地 ScopeSource 枚举到 VariableScopeUtils.ScopeSource
func _convert_to_utils_scope_source(local_scope: ScopeSource) -> VariableScopeUtils.ScopeSource:
	match local_scope:
		ScopeSource.NEAREST:
			return VariableScopeUtils.ScopeSource.NEAREST
		ScopeSource.CUSTOM_ID:
			return VariableScopeUtils.ScopeSource.CUSTOM_ID
		ScopeSource.TRIGGER_SCOPE:
			return VariableScopeUtils.ScopeSource.TRIGGER_SCOPE
		ScopeSource.TARGET_NODE:
			return VariableScopeUtils.ScopeSource.TARGET_NODE
		_:
			return VariableScopeUtils.ScopeSource.NEAREST

## 获取参数属性列表
func _get_parameter_properties() -> Array[Dictionary]:
	if _is_updating_properties:
		return []

	if _binding_manager.get_param_count() > 0:
		return _binding_manager.get_inspector_properties()

	return []

## 执行指令
func execute(context: ExecutionContext):
	var execution_start_time = Time.get_ticks_msec()
	_start_execution(context)

	# 确保方法缓存被加载（运行时可能 setter 没被触发）
	if _method_cache.is_empty() and not serialized_method_cache.is_empty():
		_deserialize_method_cache()

	# 如果函数信息被清除了（上次执行后），从元数据重建
	if not _current_function_info and not target_function.is_empty():
		# 确保参数也恢复
		if _binding_manager.get_param_count() == 0 and not serialized_parameter_metadata.is_empty():
			_deserialize_parameter_metadata()
		_recreate_function_info_from_metadata()

	# 验证参数
	# var errors = _validate_parameters()
	# if not errors.is_empty():
	# 	_log_error_localized("FUSE_ERROR_VALIDATION_FAILED", {"errors": ", ".join(errors)})
	#	set_error_localized("FUSE_ERROR_VALIDATION_FAILED", FuseError.ErrorType.VALIDATION_ERROR, {"errors": ", ".join(errors)})
	#	finished.emit()
	#		return

	# ✅ 使用 context.get_node() 获取目标节点
	var target = context.get_node(target_node)
	if not target:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 调用方法
	var call_result = _call_target_function(target)
	if call_result.has("error") and not call_result.error.is_empty():
		_log_error_localized("FUSE_ERROR_FUNCTION_CALL_FAILED", {"function": target_function, "error": call_result.error})
		set_error_localized("FUSE_ERROR_FUNCTION_CALL_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"function": target_function, "error": call_result.error})
		finished.emit()
		return

	# 处理返回值
	if store_result:
		_store_result_value(context, call_result.result)

	var execution_end_time = Time.get_ticks_msec()
	_performance_stats.total_execution_time += (execution_end_time - execution_start_time)

	# 频繁调用的指令用 DEBUG 级别，避免日志刷屏
	_log_debug_localized("FUSE_LOG_FUNCTION_CALL_SUCCESS", {
		"node": target.name,
		"function": target_function,
		"time": str(execution_end_time - execution_start_time)
	})
	if log_level >= FuseLogger.LogLevel.DEBUG:
		_log_performance_stats()
	_on_execution_completed()

## 验证参数
func _validate_parameters() -> Array[String]:
	var errors: Array[String] = []

	# 验证目标节点
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY"))

	# 验证目标函数
	if target_function.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_FUNCTION_NAME_EMPTY"))
	elif _target_node_instance and not FunctionManager.is_method_callable(_target_node_instance, target_function):
		errors.append(FuseLocalization.translate_format(
			"FUSE_ERROR_FUNCTION_NOT_CALLABLE",
			{"function": target_function}
		))

	# 验证参数
	if _current_function_info and not _validate_function_arguments():
		errors.append(FuseLocalization.translate("FUSE_ERROR_FUNCTION_PARAMS_VALIDATION_FAILED"))

	# 验证返回值处理
	if store_result:
		if result_variable_name.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_RESULT_VARIABLE_NAME_EMPTY"))

	return errors

## 调用目标函数
## 优先使用缓存的 Callable 跳过字符串查找，fallback 到安全调用
func _call_target_function(target: Node) -> Dictionary:
	if not target or target_function.is_empty():
		return {"error": FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_OR_FUNCTION_EMPTY"), "result": null}

	var args = _binding_manager.get_runtime_args()

	# 优先使用缓存的 Callable（跳过字符串查找和可调用性验证）
	var cached = FunctionManager.get_cached_callable(target, target_function)
	if cached.is_valid():
		var call_result = cached.callv(args)
		return {"success": true, "result": call_result}

	# Fallback：使用安全调用（含完整验证）
	return FunctionManager.call_method_safe(target, target_function, args)

	# Fallback：使用安全调用（含完整验证）
	return FunctionManager.call_method_safe(target, target_function, args)

## 验证函数参数
func _validate_function_arguments() -> bool:
	if not _current_function_info:
		_log_info("函数信息为空，参数验证失败")
		return false

	# 输出关键验证信息
	var expected_param_count = _current_function_info.get_parameter_count()
	_log_info("参数验证: 期望 %d 个参数, 实际 %d 个参数" % [expected_param_count, _binding_manager.get_param_count()])

	# 性能优化：减少详细日志输出，只在调试模式下输出
	if log_level >= FuseLogger.LogLevel.DEBUG:
		var args = _binding_manager.get_runtime_args()
		_log_debug("开始参数验证:")
		_log_debug("  函数名: %s" % target_function)
		_log_debug("  用户参数数量: %d" % args.size())
		_log_debug("  用户参数值: %s" % str(args))

		for i in range(args.size()):
			var actual_value = args[i]
			var actual_type = typeof(actual_value)
			_log_debug("  function_args[%d] = %s (类型: %d)" % [i, str(actual_value), actual_type])

		_log_debug("  期望参数数量: %d" % expected_param_count)

		for i in range(expected_param_count):
			var param_name = _current_function_info.get_parameter_name(i)
			var param_type = _current_function_info.get_parameter_type(i)
			var actual_value = args[i] if i < args.size() else null
			var actual_type = typeof(actual_value) if actual_value != null else TYPE_NIL

			_log_debug("  参数 %d (%s): 期望类型=%d, 实际类型=%d, 实际值=%s" % [
				i, param_name, param_type, actual_type, str(actual_value)
			])

	var result = _current_function_info.validate_arguments(_binding_manager.get_runtime_args())
	_log_debug("  参数验证结果: %s" % ("通过" if result else "失败"))
	return result

## 存储结果值
func _store_result_value(context: ExecutionContext, result: Variant):
	if result_variable_name.is_empty():
		_log_warning_localized("FUSE_ERROR_MISSING_PARAMETER", {"parameter": "result_variable_name"})
		return

	# 添加到上下文
	match result_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			if context.has_method("add_variable"):
				context.add_variable(result_variable_name, result)
				_log_info_localized("FUSE_LOG_CALLING_FUNCTION", {
					"function": "存储到局部变量",
					"variable": result_variable_name
				})
			else:
				_log_warning_localized("FUSE_ERROR_CONTEXT_NO_VARIABLE_SUPPORT", {})

		BaseVariable.VariableScope.SCOPE:
			# 保存到 SCOPE 变量
			if result_scope_source == ScopeSource.NEAREST:
				# NEAREST 模式：使用 VariableOperations
				var success = VariableOperations.set_variable(context, result_variable_name, BaseVariable.VariableScope.SCOPE, result)
				if success:
					_log_info_localized("FUSE_LOG_CALLING_FUNCTION", {
						"function": "存储到作用域变量",
						"variable": result_variable_name
					})
				else:
					_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": result_variable_name})
			else:
				# 其他模式：获取指定作用域容器并设置变量
				var utils_scope_source = result_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					result_custom_scope_id,
					result_target_node_path
				)

				if scope_container:
					var success = scope_container.set_variable(result_variable_name, result)
					if success:
						_log_info_localized("FUSE_LOG_CALLING_FUNCTION", {
							"function": "存储到作用域变量",
							"variable": result_variable_name
						})
					else:
						_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": result_variable_name})
				else:
					_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})

		BaseVariable.VariableScope.GLOBAL:
			var success = VariableOperations.set_variable(context, result_variable_name, BaseVariable.VariableScope.GLOBAL, result)
			if success:
				_log_info_localized("FUSE_LOG_CALLING_FUNCTION", {
					"function": "存储到全局变量",
					"variable": result_variable_name
				})
			else:
				_log_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", {"name": result_variable_name})

## 获取指令描述
func get_description() -> String:
	var desc_parts = []

	# 基础描述
	if not target_node.is_empty():
		desc_parts.append(FuseLocalization.translate_format(
			"FUSE_INSTRUCTION_RUN_FUNCTION_DESC_IN_NODE",
			{"node": _get_node_display_name(target_node)}
		))
	else:
		desc_parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RUN_FUNCTION_DESC_NO_NODE"))

	# 函数信息
	if not target_function.is_empty():
		desc_parts.append(FuseLocalization.translate_format(
			"FUSE_INSTRUCTION_RUN_FUNCTION_DESC_CALL",
			{"function": target_function}
		))
	else:
		desc_parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RUN_FUNCTION_DESC_NO_FUNCTION"))

	# 参数信息
	if _binding_manager.get_param_count() > 0:
		desc_parts.append(FuseLocalization.translate_format(
			"FUSE_INSTRUCTION_RUN_FUNCTION_DESC_USING_PARAMS",
			{"count": str(_binding_manager.get_param_count())}
		))

	# 返回值处理
	if store_result:
		if not result_variable_name.is_empty():
			var scope_name: String
			match result_variable_scope:
				BaseVariable.VariableScope.LOCAL:
					scope_name = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL")
				BaseVariable.VariableScope.SCOPE:
					scope_name = VariableScopeUtils.get_scope_source_string(
						result_scope_source as VariableScopeUtils.ScopeSource,
						result_custom_scope_id,
						result_target_node_path
					)
				BaseVariable.VariableScope.GLOBAL:
					scope_name = FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL")
				_:
					scope_name = FuseLocalization.translate("FUSE_SCOPE_UNKNOWN_STR")

			desc_parts.append(FuseLocalization.translate_format(
				"FUSE_INSTRUCTION_RUN_FUNCTION_DESC_STORE_TO",
				{"scope": scope_name, "name": result_variable_name}
			))
		else:
			desc_parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RUN_FUNCTION_DESC_STORE_RESULT"))

	return ", ".join(desc_parts)

## 取消指令执行
func cancel():
	if is_running():
		_log_debug("取消运行节点函数指令")
		super.cancel()

## 资源清理
func _cleanup_resources():
	super._cleanup_resources()
	# 清理 Callable 缓存（如果目标节点存在）
	if _target_node_instance and is_instance_valid(_target_node_instance):
		FunctionManager.clear_callable_cache(_target_node_instance)
	_target_node_instance = null
	_available_functions.clear()
	_current_function_info = null
	_function_call_result = null
	_method_cache.clear()
	_cache_valid = false
	_cached_target_node_instance = null
	_cached_inheritance_chain.clear()
	_node_cache_valid = false
	_log_debug("RunTargetNodeFunction 资源清理完成")

## 重置指令状态
func reset():
	super.reset()
	_target_node_instance = null
	_available_functions.clear()
	_current_function_info = null
	_function_call_result = null
	_method_cache.clear()
	_cache_valid = false
	_cached_target_node_instance = null
	_cached_inheritance_chain.clear()
	_node_cache_valid = false

	# 重置性能优化相关的缓存
	_target_node_path_hash = 0
	_last_node_lookup_time = 0
	_cached_method_signatures.clear()

	# 清除序列化的参数元数据
	serialized_parameter_metadata.clear()

	# 重置性能统计
	reset_performance_stats()

	_log_debug("RunTargetNodeFunction 状态已重置")

## 获取创建的变量（如果有）
func get_created_variable() -> BaseVariable:
	if store_result and not result_variable_name.is_empty():
		# 这里应该返回实际创建的变量，但需要在执行后才能获取
		# 暂时返回 null，实际使用时应该从上下文获取
		return null
	return null

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("RunTargetNodeFunction", log_level, message, target_function)

func _log_info(message: String):
	FuseLogger.log_info("RunTargetNodeFunction", log_level, message, target_function)

func _log_warning(message: String):
	FuseLogger.log_warning("RunTargetNodeFunction", log_level, message, target_function)

func _log_error(message: String):
	FuseLogger.log_error("RunTargetNodeFunction", log_level, message, target_function)

## 性能统计日志
func _log_performance_stats():
	if _performance_stats.total_execution_time > 0:
		_log_info("=== 性能统计 ===")
		_log_info("总执行时间: %d ms" % _performance_stats.total_execution_time)
		_log_info("方法缓存刷新次数: %d，总耗时: %d ms" % [_performance_stats.method_cache_refresh_count, _performance_stats.method_cache_refresh_time])
		_log_info("节点查找次数: %d，总耗时: %d ms" % [_performance_stats.node_lookup_count, _performance_stats.node_lookup_time])
		_log_info("函数信息创建次数: %d，总耗时: %d ms" % [_performance_stats.function_info_creation_count, _performance_stats.function_info_creation_time])
		_log_info("属性列表更新次数: %d" % _performance_stats.property_list_update_count)

		# 计算平均时间
		if _performance_stats.method_cache_refresh_count > 0:
			var avg_cache_time = _performance_stats.method_cache_refresh_time / _performance_stats.method_cache_refresh_count
			_log_info("平均方法缓存刷新时间: %.2f ms" % avg_cache_time)

		if _performance_stats.node_lookup_count > 0:
			var avg_lookup_time = _performance_stats.node_lookup_time / _performance_stats.node_lookup_count
			_log_info("平均节点查找时间: %.2f ms" % avg_lookup_time)

		if _performance_stats.function_info_creation_count > 0:
			var avg_creation_time = _performance_stats.function_info_creation_time / _performance_stats.function_info_creation_count
			_log_info("平均函数信息创建时间: %.2f ms" % avg_creation_time)

## 重置性能统计
func reset_performance_stats():
	_performance_stats = {
		"method_cache_refresh_count": 0,
		"node_lookup_count": 0,
		"function_info_creation_count": 0,
		"property_list_update_count": 0,
		"total_execution_time": 0.0,
		"method_cache_refresh_time": 0.0,
		"node_lookup_time": 0.0,
		"function_info_creation_time": 0.0
	}