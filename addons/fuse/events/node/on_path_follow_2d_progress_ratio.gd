@tool
@icon("res://addons/fuse/icons/builtin/PathFollow3D.png")
extends BaseEvent
class_name OnPathFollow2DProgressRatio

## PathFollow2D progress_ratio 到达指定值时触发的事件
##
## 轮询监听 PathFollow2D 节点的 progress_ratio 属性，
## 当当前值与目标值的差值在容差范围内时触发事件。
## 支持直接从属性输入目标值或从变量读取。

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 目标 PathFollow2D 节点路径
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 目标 progress_ratio 值（0.0 - 1.0）
var target_ratio: float = 0.5:
	set(value):
		target_ratio = value
		_update_resource_name()

## 是否从变量获取目标 ratio
var use_variable_for_ratio: bool = false:
	set(value):
		use_variable_for_ratio = value
		_update_resource_name()
		notify_property_list_changed()

## 目标 ratio 变量名
var ratio_variable: String = "":
	set(value):
		ratio_variable = value
		_update_resource_name()

## 目标 ratio 变量作用域
var ratio_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		ratio_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 目标 ratio 作用域来源（仅当 ratio_scope == SCOPE 时使用）
var ratio_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		ratio_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 目标 ratio 自定义作用域 ID（CUSTOM_ID 模式使用）
var ratio_custom_scope_id: String = "":
	set(value):
		ratio_custom_scope_id = value
		_update_resource_name()

## 目标 ratio 目标节点路径（TARGET_NODE 模式使用）
var ratio_target_node_path: NodePath = NodePath(""):
	set(value):
		ratio_target_node_path = value
		_update_resource_name()

## 容差（触发判定范围）
var tolerance: float = 0.01:
	set(value):
		tolerance = value
		_update_resource_name()

## 检查间隔（秒）
var check_interval: float = 0.05:
	set(value):
		check_interval = value
		_update_resource_name()

## 是否仅触发一次
var trigger_once: bool = true:
	set(value):
		trigger_once = value
		_update_resource_name()

## 缓存目标节点引用
var _target_node_ref: Node = null

## 缓存 owner 节点引用，用于创建临时 ExecutionContext
var _owner_node_ref: Node = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["is_monitoring"] = false
	base["check_timer"] = 0.0
	base["has_triggered"] = false
	return base

## 更新资源名称
func _update_resource_name():
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")

	var ratio_str := ""
	if use_variable_for_ratio:
		if ratio_variable.is_empty():
			ratio_str = FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
		else:
			ratio_str = ratio_variable
	else:
		ratio_str = str(snapped(target_ratio, 0.001))

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_PATH_FOLLOW_2D_PROGRESS_RATIO_RESOURCE_NAME", {
		"node": node_str,
		"ratio": ratio_str,
		"tolerance": str(tolerance)
	})

## 初始化事件监听（向后兼容）
func initialize(owner_node: Node) -> void:
	if Engine.is_editor_hint():
		return

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_runtime_instance_ref = RuntimeEventInstance.new(self, owner_node)
	_initialize(owner_node, _runtime_instance_ref)

## 使用 RuntimeInstance 初始化事件
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_initialize(owner_node, runtime_instance)

## 内部初始化逻辑
func _initialize(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	_runtime_instance_ref = runtime_instance
	_owner_node_ref = owner_node
	set_trigger_ref(owner_node)

	_target_node_ref = owner_node.get_node_or_null(target_node)
	if not _target_node_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	if not _target_node_ref is PathFollow2D:
		_create_fuse_error_localized("FUSE_ERROR_NOT_PATH_FOLLOW_2D", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node": _target_node_ref.name,
			"actual_type": _target_node_ref.get_class()
		})
		return

	runtime_instance.set_runtime_state("is_monitoring", true)
	runtime_instance.set_runtime_state("check_timer", 0.0)
	runtime_instance.set_runtime_state("has_triggered", false)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听
func terminate(owner_node: Node) -> void:
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("check_timer", 0.0)
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	_target_node_ref = null
	_owner_node_ref = null
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 重置事件状态
func reset() -> void:
	super.reset()

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("check_timer", 0.0)
		_runtime_instance_ref.set_runtime_state("has_triggered", false)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 每帧处理（由 Trigger 调用）
func on_process(delta: float) -> void:
	if not _runtime_instance_ref:
		return

	var is_monitoring = false
	if _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")
	if not is_monitoring:
		return

	var check_timer = 0.0
	if _runtime_instance_ref.has_runtime_state("check_timer"):
		check_timer = _runtime_instance_ref.get_runtime_state("check_timer")
	check_timer += delta
	_runtime_instance_ref.set_runtime_state("check_timer", check_timer)

	if check_timer >= check_interval:
		check_timer -= check_interval
		_runtime_instance_ref.set_runtime_state("check_timer", check_timer)
		_check_progress_ratio()

## 检查 progress_ratio 是否到达目标值
func _check_progress_ratio() -> void:
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		_log_warning_localized("FUSE_WARNING_TARGET_NODE_INVALID", {})
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		return

	var path_follow := _target_node_ref as PathFollow2D
	var current_ratio := path_follow.progress_ratio

	var target_value := _resolve_target_ratio()
	if target_value == null:
		return

	var target_ratio_value: float = target_value

	var has_triggered = false
	if _runtime_instance_ref.has_runtime_state("has_triggered"):
		has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")
	if trigger_once and has_triggered:
		return

	var diff := absf(current_ratio - target_ratio_value)
	if diff <= tolerance:
		_runtime_instance_ref.set_runtime_state("has_triggered", true)
		if trigger_once:
			_runtime_instance_ref.set_runtime_state("is_monitoring", false)

		_log_info_localized("FUSE_LOG_EVENT_PATH_FOLLOW_2D_PROGRESS_RATIO_REACHED", {
			"node": path_follow.name,
			"current": str(snapped(current_ratio, 0.001)),
			"target": str(snapped(target_ratio_value, 0.001))
		})

		var context_node = Node.new()
		context_node.name = "PathFollow2DProgressRatioContext"
		context_node.set_meta("current_ratio", current_ratio)
		context_node.set_meta("target_ratio", target_ratio_value)
		context_node.set_meta("tolerance", tolerance)
		context_node.set_meta("target_node", path_follow)

		_runtime_instance_ref.update_trigger_stats()
		_emit_triggered(context_node, _owner_node_ref)

		context_node.queue_free()

## 解析目标 ratio
func _resolve_target_ratio() -> Variant:
	if not use_variable_for_ratio:
		return clampf(target_ratio, 0.0, 1.0)

	if ratio_variable.is_empty():
		_log_error_localized("FUSE_ERROR_RATIO_VARIABLE_EMPTY", {})
		return null

	var context := _create_temp_context()
	var value: Variant = null

	match ratio_scope:
		BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
			if not VariableOperations.has_variable(context, ratio_variable, ratio_scope):
				_log_error_localized("FUSE_ERROR_RATIO_VAR_NOT_FOUND", {"variable": ratio_variable})
				return null
			value = VariableOperations.get_variable(context, ratio_variable, ratio_scope, null)
		BaseVariable.VariableScope.SCOPE:
			if ratio_scope_source == ScopeSource.NEAREST:
				if not VariableOperations.has_variable(context, ratio_variable, ratio_scope):
					_log_error_localized("FUSE_ERROR_RATIO_VAR_NOT_FOUND", {"variable": ratio_variable})
					return null
				value = VariableOperations.get_variable(context, ratio_variable, ratio_scope, null)
			else:
				var utils_scope_source = ratio_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(context, utils_scope_source, ratio_custom_scope_id, ratio_target_node_path)
				if scope_container == null:
					_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					return null
				value = scope_container.get_variable(ratio_variable, null)

	if value == null:
		_log_error_localized("FUSE_ERROR_RATIO_VAR_NOT_FOUND", {"variable": ratio_variable})
		return null

	return clampf(float(value), 0.0, 1.0)

## 创建临时 ExecutionContext（用于变量解析）
func _create_temp_context() -> ExecutionContext:
	var temp_context = ExecutionContext.new()
	if _owner_node_ref and is_instance_valid(_owner_node_ref):
		temp_context.trigger = _owner_node_ref
	return temp_context

## 获取动态属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	properties.append({
		name = "Target",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "PathFollow2D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "use_variable_for_ratio",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_ratio:
		properties.append({
			name = "target_ratio",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0,1.0,0.001",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "ratio_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "ratio_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if ratio_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "ratio_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if ratio_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "ratio_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif ratio_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "ratio_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	properties.append({
		name = "Settings",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "tolerance",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.0,0.5,0.001,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "check_interval",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.001,1.0,0.001,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "trigger_once",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 属性验证
func _validate_property(property: Dictionary) -> void:
	if not use_variable_for_ratio:
		if property.name in ["ratio_variable", "ratio_scope", "ratio_scope_source", "ratio_custom_scope_id", "ratio_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "target_ratio":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		if ratio_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["ratio_scope_source", "ratio_custom_scope_id", "ratio_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var ratio_utils_scope_source = ratio_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, ratio_utils_scope_source)

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_ratio", "ratio_scope", "ratio_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		return true
	return false

## 获取事件描述
func get_description() -> String:
	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")

	var ratio_str := ""
	if use_variable_for_ratio:
		ratio_str = ratio_variable if not ratio_variable.is_empty() else FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
	else:
		ratio_str = str(snapped(target_ratio, 0.001))

	return FuseLocalization.translate_format("FUSE_EVENT_PATH_FOLLOW_2D_PROGRESS_RATIO_DESC", {
		"node": node_str,
		"ratio": ratio_str,
		"tolerance": str(tolerance)
	})

## 获取事件类型
func get_event_type() -> String:
	return "path_follow_2d_progress_ratio"

## 获取事件分类
func get_event_category() -> String:
	return "node"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if use_variable_for_ratio:
		if ratio_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_RATIO_VARIABLE_EMPTY"))
		if ratio_scope == BaseVariable.VariableScope.SCOPE:
			var ratio_utils_scope_source = ratio_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				ratio_utils_scope_source,
				ratio_custom_scope_id,
				ratio_target_node_path
			))

	if tolerance < 0.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_TOLERANCE_INVALID"))

	if check_interval <= 0.0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_CHECK_INTERVAL_INVALID"))

	return errors

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_PATH_FOLLOW_2D_PROGRESS_RATIO_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_NODE"
	metadata.description_key = "FUSE_EVENT_PATH_FOLLOW_2D_PROGRESS_RATIO_DESC"
	metadata.keywords = ["pathfollow2d", "progress", "ratio", "path", "progress_ratio", "路径", "进度", "比例"]
	metadata.builtin_icon = "PathFollow3D"
	return metadata
