# JuicyMethodTrack - 方法轨道
# 在特定时间点调用目标节点方法
# 支持参数传递和条件触发

@tool
class_name JuicyMethodTrack
extends JuicyTrack

# 基础配置
@export var trigger_time: float = 0.0            # 触发时间
var method_name: String = "":
	set(value):
		method_name = value
		_update_current_method_info()
		notify_property_list_changed()

@export var args: Array = []                     # 方法参数

# 高级属性
@export var trigger_once: bool = true            # 是否只触发一次
@export var delay: float = 0.0                  # 触发后的延迟
@export var repeat_interval: float = -1.0        # 重复间隔，-1表示不重复
@export var max_repeats: int = -1               # 最大重复次数，-1表示无限

# 参数映射系统
@export var use_parameter_mapping: bool = false    # 参数映射开关，默认关闭
@export var parameter_mappings: Array[JuicyParameterMapping] = []

# 继承级别过滤系统
var included_inheritance_levels: int = 0xFFFFFFFF:  # 包含的继承级别（位掩码）
	set(value):
		if included_inheritance_levels != value:
			included_inheritance_levels = value
			_cache_valid = false  # 需要重新刷新缓存
			notify_property_list_changed()
			# 使用 call_deferred 避免线程安全问题
			if Engine.is_editor_hint():
				call_deferred("_refresh_cache_and_notify")

# Getter 方法过滤系统
var exclude_getter_methods: bool = true:  # 是否排除 getter 方法（get/is/has 开头）
	set(value):
		if exclude_getter_methods != value:
			exclude_getter_methods = value
			_cache_valid = false
			notify_property_list_changed()
			# 使用 call_deferred 避免线程安全问题
			if Engine.is_editor_hint():
				call_deferred("_refresh_cache_and_notify")

# 方法缓存系统
@export_storage var serialized_method_cache: Array[Dictionary] = []  # 序列化的方法缓存
@export_storage var _inheritance_chain_cache: Array[String] = []  # 继承链缓存
var _method_cache: Dictionary = {}                  # 运行时方法缓存
var _current_method_info: JuicyMethodInfo = null  # 当前方法信息
var _cache_valid: bool = false                     # 缓存有效性标志
var _is_updating_properties: bool = false          # 防止属性更新循环
var _pending_refresh: bool = false                 # 待刷新标志
var _last_known_target: NodePath = NodePath()      # 用于检测 target 变化

# 运行时状态
var _triggered: bool = false                    # 是否已触发
var _trigger_count: int = 0                     # 触发次数
var _last_trigger_time: float = -1.0           # 上次触发时间
var _pending_calls: Array = []                  # 待处理的调用

func get_track_type() -> String:
	return "Method"

func validate_track() -> String:
	if method_name.is_empty():
		return "Method name cannot be empty"
	
	if trigger_time < 0.0:
		return "Trigger time cannot be negative"
	
	if delay < 0.0:
		return "Delay cannot be negative"
	
	if repeat_interval < -1.0:
		return "Repeat interval cannot be less than -1"
	
	if max_repeats < -1:
		return "Max repeats cannot be less than -1"
	
	# 验证参数映射
	if use_parameter_mapping:
		for i in range(parameter_mappings.size()):
			var mapping = parameter_mappings[i]
			if not mapping:
				return "Parameter mapping at index " + str(i) + " cannot be null"
			
			var mapping_error = mapping.validate_mapping() if mapping.has_method("validate_mapping") else ""
			if not mapping_error.is_empty():
				return "Parameter mapping error at index " + str(i) + ": " + mapping_error
	
	return ""

# 检查是否应该触发
func should_trigger(time: float, context: JuicyContext) -> bool:
	"""
	检查是否应该触发方法调用
	
	@param time: 当前时间
	@param context: JuicyContext实例
	@return: 是否应该触发
	"""
	# 检查基础条件
	if not enabled or muted:
		return false
	
	# 检查触发条件
	if condition and not condition.evaluate(context):
		return false
	
	# 检查是否已经触发过
	if trigger_once and _triggered:
		return false
	
	# 检查是否达到最大重复次数
	if max_repeats >= 0 and _trigger_count >= max_repeats:
		return false
	
	# 检查触发时间
	if time < trigger_time:
		return false
	
	# 检查重复间隔
	if repeat_interval > 0.0 and _last_trigger_time >= 0.0:
		if time - _last_trigger_time < repeat_interval:
			return false
	
	return true

# 触发方法调用
func trigger_method(context: JuicyContext) -> void:
	"""
	触发方法调用
	
	@param context: JuicyContext实例
	"""
	var method_target = get_target_node()
	trigger_method_with_target(method_target, context)

# 使用指定目标节点触发方法调用
func trigger_method_with_target(target_node: Node, context: JuicyContext) -> void:
	"""
	使用指定目标节点触发方法调用
	
	@param target_node: 目标节点
	@param context: JuicyContext实例
	"""
	if not target_node:
		return
	
	# 检查方法是否存在
	if not target_node.has_method(method_name):
		print("Warning: Method '", method_name, "' not found on target: ", target_node.get_path())
		return
	
	# 应用参数映射
	var processed_args = _process_parameter_mappings(context)
	
	# 如果有延迟，创建延迟调用
	if delay > 0.0:
		_schedule_delayed_call(target_node, processed_args, context)
	else:
		# 立即调用
		_execute_method_call(target_node, processed_args)
	
	# 更新状态
	_triggered = true
	_trigger_count += 1
	_last_trigger_time = context.current_time

# 处理参数映射
func _process_parameter_mappings(context: JuicyContext) -> Array:
	"""
	处理参数映射
	
	@param context: JuicyContext实例
	@return: 处理后的参数数组
	"""
	if not use_parameter_mapping:
		return args.duplicate()
	
	var processed_args = args.duplicate()
	
	for i in range(processed_args.size()):
		var arg = processed_args[i]
		
		# 检查是否是参数映射占位符
		if arg is String and (arg as String).begins_with("$"):
			var param_name = (arg as String).substr(1)  # 移除"$"前缀
			var param_value = context.get_parameter(param_name, 0.0)
			
			# 应用参数映射
			for mapping in parameter_mappings:
				if not mapping.enabled:
					continue
				
				# 根据映射类型处理
				match mapping.mapping_type:
					JuicyParameterMapping.MappingType.METHOD_ARGUMENT:
						# 方法参数映射
						if mapping.target_argument_index == i or mapping.target_property == "arg_" + str(i) or mapping.target_property == param_name:
							var mapped_value = mapping.apply_mapping(param_value)
							processed_args[i] = mapped_value
							break
					
					JuicyParameterMapping.MappingType.TRACK_PROPERTY, JuicyParameterMapping.MappingType.TRACK_VALUE:
						# 轨道属性映射
						if mapping.target_property == "arg_" + str(i) or mapping.target_property == param_name:
							var mapped_value = mapping.apply_mapping(param_value)
							processed_args[i] = mapped_value
							break
					
					JuicyParameterMapping.MappingType.CUSTOM:
						# 自定义映射
						if mapping.target_property == "arg_" + str(i) or mapping.target_property == param_name:
							var mapped_value = mapping.apply_custom_mapping(param_value, self)
							processed_args[i] = mapped_value
							break
	
	return processed_args

# 调度延迟调用
func _schedule_delayed_call(target: Node, processed_args: Array, context: JuicyContext) -> void:
	"""
	调度延迟调用
	
	@param target: 目标节点
	@param processed_args: 处理后的参数
	@param context: JuicyContext实例
	"""
	var call_data = {
		"target": target,
		"args": processed_args,
		"trigger_time": context.current_time + delay,
		"context_id": context.context_id
	}
	
	_pending_calls.append(call_data)

# 执行方法调用
func _execute_method_call(target: Node, processed_args: Array) -> void:
	"""
	执行方法调用
	
	@param target: 目标节点
	@param processed_args: 处理后的参数
	"""
	if target.has_method(method_name):
		target.callv(method_name, processed_args)
	else:
		print("Warning: Method '", method_name, "' not found on target: ", target.get_path())

# 处理待处理的调用
func process_pending_calls(context: JuicyContext) -> void:
	"""
	处理待处理的延迟调用
	
	@param context: JuicyContext实例
	"""
	var calls_to_remove = []
	
	for i in range(_pending_calls.size()):
		var call_data = _pending_calls[i]
		
		# 检查是否到了执行时间
		if context.current_time >= call_data.trigger_time:
			_execute_method_call(call_data.target, call_data.args)
			calls_to_remove.append(i)
	
	# 移除已执行的调用
	for i in range(calls_to_remove.size() - 1, -1, -1):
		_pending_calls.remove_at(calls_to_remove[i])

# 获取轨道的开始时间
func get_start_time() -> float:
	return trigger_time

# 获取轨道的结束时间
func get_end_time() -> float:
	if repeat_interval > 0.0 and max_repeats > 0:
		return trigger_time + repeat_interval * max_repeats
	else:
		return trigger_time

# 初始化轨道
func initialize_track(context: JuicyContext) -> void:
	super.initialize_track(context)
	_triggered = false
	_trigger_count = 0
	_last_trigger_time = -1.0
	_pending_calls.clear()

# 清理轨道
func cleanup_track(context: JuicyContext) -> void:
	super.cleanup_track(context)
	_pending_calls.clear()

# 获取轨道的编辑器图标
func get_editor_icon() -> String:
	return "Method"

# 获取轨道的编辑器颜色
func get_editor_color() -> Color:
	return track_color

# 克隆轨道
func clone() -> JuicyTrack:
	var cloned_track = super.clone() as JuicyMethodTrack
	
	# 复制方法轨道特有属性
	cloned_track.trigger_time = trigger_time
	cloned_track.method_name = method_name
	cloned_track.args = args.duplicate()
	cloned_track.target = target
	cloned_track.trigger_once = trigger_once
	cloned_track.delay = delay
	cloned_track.repeat_interval = repeat_interval
	cloned_track.max_repeats = max_repeats
	cloned_track.use_parameter_mapping = use_parameter_mapping
	
	# 复制参数映射
	cloned_track.parameter_mappings.clear()
	for mapping in parameter_mappings:
		if mapping:
			cloned_track.parameter_mappings.append(mapping.duplicate(true))
	
	return cloned_track

# 序列化支持
func get_config_dict() -> Dictionary:
	var config = super.get_config_dict()

	# 添加方法轨道特有配置
	config["trigger_time"] = trigger_time
	config["method_name"] = method_name
	config["args"] = args
	config["target"] = target
	config["trigger_once"] = trigger_once
	config["delay"] = delay
	config["repeat_interval"] = repeat_interval
	config["max_repeats"] = max_repeats
	config["use_parameter_mapping"] = use_parameter_mapping
	config["included_inheritance_levels"] = included_inheritance_levels
	config["exclude_getter_methods"] = exclude_getter_methods

	return config

# 从配置字典加载
func load_from_dict(config_dict: Dictionary) -> bool:
	if not super.load_from_dict(config_dict):
		return false

	# 加载方法轨道特有配置
	if config_dict.has("trigger_time"):
		trigger_time = config_dict["trigger_time"]
	if config_dict.has("method_name"):
		method_name = config_dict["method_name"]
	if config_dict.has("args"):
		args = config_dict["args"]
	if config_dict.has("target"):
		target = config_dict["target"]
	if config_dict.has("trigger_once"):
		trigger_once = config_dict["trigger_once"]
	if config_dict.has("delay"):
		delay = config_dict["delay"]
	if config_dict.has("repeat_interval"):
		repeat_interval = config_dict["repeat_interval"]
	if config_dict.has("max_repeats"):
		max_repeats = config_dict["max_repeats"]
	if config_dict.has("use_parameter_mapping"):
		use_parameter_mapping = config_dict["use_parameter_mapping"]

	# 加载继承级别过滤配置（向后兼容：默认为所有级别）
	if config_dict.has("included_inheritance_levels"):
		included_inheritance_levels = config_dict["included_inheritance_levels"]
	else:
		included_inheritance_levels = 0xFFFFFFFF  # 默认包含所有级别

	# 加载 getter 方法过滤配置（向后兼容：默认过滤）
	if config_dict.has("exclude_getter_methods"):
		exclude_getter_methods = config_dict["exclude_getter_methods"]
	else:
		exclude_getter_methods = true  # 默认过滤 getter 方法

	return true

## ============================================
## 动态属性生成（基于新的辅助类）
## ============================================

## 获取动态属性列表
func _get_property_list() -> Array[Dictionary]:
	if _is_updating_properties:
		return []

	# 检测 target 是否变化
	if target != _last_known_target:
		_last_known_target = target
		_inheritance_chain_cache.clear()
		_method_cache.clear()
		_cache_valid = false
		_pending_refresh = true

	# 检查待刷新标志，如果设置则触发延迟刷新
	if _pending_refresh and Engine.is_editor_hint():
		_pending_refresh = false
		call_deferred("_refresh_cache_and_notify")

	var properties: Array[Dictionary] = []

	# 只在编辑器中生成动态属性
	if not Engine.is_editor_hint():
		return properties

	# 添加目标节点路径（使用基类的 target）
	properties.append({
		"name": "target",
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		"hint_string": "Node",
		"default": NodePath(""),
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	# 不在这里访问节点，避免线程安全问题
	# 始终添加继承级别过滤器（即使缓存为空）
	properties.append({
		"name": "included_inheritance_levels",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_FLAGS,
		"hint_string": _get_inheritance_level_hint_string(),
		"default": 0xFFFFFFFF,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	# 始终添加 getter 方法过滤器
	properties.append({
		"name": "exclude_getter_methods",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"default": true,
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_EDITOR
	})

	# 添加方法选择器
	if not _method_cache.is_empty():
		var method_names = _get_method_names()
		properties.append({
			"name": "method_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(method_names),
			"usage": PROPERTY_USAGE_DEFAULT
		})
	else:
		# 如果缓存为空，仍然显示方法名输入
		var hint_text = "请先选择目标轨道" if _inheritance_chain_cache.is_empty() else "加载中..."
		properties.append({
			"name": "method_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
			"hint_string": hint_text,
			"usage": PROPERTY_USAGE_DEFAULT
		})

	# 如果有当前方法信息，生成参数属性
	if _current_method_info and not method_name.is_empty():
		var param_properties = JuicyParameterEditor.create_parameter_properties(_current_method_info, args)
		properties.append_array(param_properties)

	return properties

## 自定义属性设置处理
func _set(property: StringName, value: Variant) -> bool:
	# 处理动态参数属性
	if str(property).begins_with("param_"):
		return JuicyParameterEditor.handle_parameter_set(str(property), value, args)

	return false

## 自定义属性获取处理
func _get(property: StringName) -> Variant:
	# 处理动态参数属性
	if str(property).begins_with("param_"):
		return JuicyParameterEditor.handle_parameter_get(str(property), args, _current_method_info)

	return null

## 属性变化通知
func _property_can_revert(property: StringName) -> bool:
	return str(property).begins_with("param_")

func _property_get_revert(property: StringName) -> Variant:
	if str(property).begins_with("param_") and _current_method_info:
		# 提取参数索引（支持两种格式：param_0 或 param_0___label）
		var index_str = str(property).substr(6)  # 移除 "param_" 前缀
		if index_str.contains("___"):
			index_str = index_str.split("___")[0]  # 提取 "___" 前的部分

		if index_str.is_valid_int():
			var index = index_str.to_int()
			if index < _current_method_info.get_parameter_count():
				return _current_method_info.get_parameter_default(index)
	return null

## 在编辑器中获取目标节点
func _get_target_node_in_editor_with_timeline() -> Node:
	if not Engine.is_editor_hint():
		return null

	# 从编辑器获取当前场景
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	if not edited_scene_root:
		return null

	# 使用父类的方法获取目标节点（已处理相对路径）
	return super._get_target_node_in_editor(edited_scene_root)

## 延迟刷新方法缓存（线程安全）
## 用于在 setter 和 _get_property_list 中延迟调用，避免线程安全问题
func _refresh_cache_and_notify() -> void:
	var target_node = _get_target_node_in_editor_with_timeline()

	if target_node:
		# 先更新继承链缓存
		_update_inheritance_chain_cache(target_node)
		# 然后刷新方法缓存
		_refresh_method_cache(target_node)
		# 最后刷新属性列表以显示更新后的 UI
		notify_property_list_changed()

## 刷新方法缓存
func _refresh_method_cache(target_node: Node) -> void:
	if not target_node:
		return

	_is_updating_properties = true

	# 使用反射工具获取可调用方法（应用继承级别过滤和 getter 过滤）
	var callable_methods = JuicyMethodReflection.get_callable_methods(
		target_node,
		included_inheritance_levels,
		exclude_getter_methods
	)

	# 创建轻量级缓存
	_method_cache.clear()
	for method in callable_methods:
		var lightweight = JuicyMethodReflection.create_lightweight_method_info(method)
		var method_name_str = lightweight.get("name", "")
		if not method_name_str.is_empty():
			# 附加继承级别信息
			lightweight["defined_in_class"] = method.get("defined_in_class", "")
			lightweight["inheritance_level"] = method.get("inheritance_level", 0)
			_method_cache[method_name_str] = lightweight

	# 序列化缓存
	serialized_method_cache.clear()
	for method_name in _method_cache.keys():
		serialized_method_cache.append(_method_cache[method_name])

	_cache_valid = true
	_is_updating_properties = false

	# 如果当前有选中的方法，恢复方法信息
	if not method_name.is_empty() and _method_cache.has(method_name):
		_update_current_method_info()

## 获取方法名称列表
func _get_method_names() -> Array[String]:
	var names: Array[String] = []

	for method_name in _method_cache.keys():
		names.append(method_name)

	# 按字母顺序排序
	names.sort()

	return names

## 更新当前方法信息
func _update_current_method_info() -> void:
	if method_name.is_empty():
		_current_method_info = null
		return

	# 如果缓存为空或方法不在缓存中，延迟刷新缓存
	if _method_cache.is_empty() or not _method_cache.has(method_name):
		if Engine.is_editor_hint():
			# 使用 call_deferred 避免线程安全问题
			call_deferred("_refresh_cache_and_update_method_info")
		else:
			_current_method_info = null
		return

	# 从缓存中获取方法信息
	var method_info_dict = _method_cache[method_name]
	_current_method_info = JuicyMethodInfo.new(method_info_dict)

	# 调整参数数组大小
	var expected_count = _current_method_info.get_parameter_count()
	if args.size() != expected_count:
		args.resize(expected_count)
		notify_property_list_changed()

## 延迟刷新缓存并更新方法信息
func _refresh_cache_and_update_method_info() -> void:
	var target_node = _get_target_node_in_editor_with_timeline()

	if target_node:
		# 刷新继承链和方法缓存
		_update_inheritance_chain_cache(target_node)
		_refresh_method_cache(target_node)

		# 再次尝试更新方法信息
		if _method_cache.has(method_name):
			var method_info_dict = _method_cache[method_name]
			_current_method_info = JuicyMethodInfo.new(method_info_dict)

			# 调整参数数组大小
			var expected_count = _current_method_info.get_parameter_count()
			if args.size() != expected_count:
				args.resize(expected_count)

			# 通知属性列表更新
			notify_property_list_changed()
		else:
			_current_method_info = null
	else:
		_current_method_info = null

## 从序列化缓存恢复
func _deserialize_method_cache() -> void:
	if serialized_method_cache.is_empty():
		return

	_method_cache.clear()
	for method_data in serialized_method_cache:
		var method_name = method_data.get("name", "")
		if not method_name.is_empty():
			_method_cache[method_name] = method_data

	_cache_valid = true

## 资源准备就绪时的初始化
func _editor_init() -> void:
	"""在编辑器中初始化方法缓存"""
	if not Engine.is_editor_hint():
		return

	# 从序列化缓存恢复
	_deserialize_method_cache()

	# 恢复当前方法信息
	if not method_name.is_empty():
		_update_current_method_info()

	# 如果继承链缓存为空，延迟刷新缓存
	if _inheritance_chain_cache.is_empty():
		call_deferred("_refresh_cache_and_notify")

## ============================================
## 继承级别过滤辅助方法
## ============================================

## 生成继承级别的位掩码提示字符串
func _get_inheritance_level_hint_string() -> String:
	if _inheritance_chain_cache.is_empty():
		return "All Classes"

	var level_strings: Array[String] = []

	for i in range(_inheritance_chain_cache.size()):
		var cls_name = _inheritance_chain_cache[i]
		if i == 0:
			level_strings.append("%s (Current)" % cls_name)
		else:
			level_strings.append("%s (Level %d)" % [cls_name, i])

	return ",".join(level_strings)

## 更新继承链缓存
func _update_inheritance_chain_cache(target_node: Node) -> void:
	if not target_node:
		return

	_inheritance_chain_cache.clear()
	var inheritance_chain = JuicyMethodReflection.get_inheritance_chain(target_node)

	for level_info in inheritance_chain:
		_inheritance_chain_cache.append(level_info.class_name)