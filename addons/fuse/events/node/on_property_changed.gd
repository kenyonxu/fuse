@tool
@icon("res://addons/fuse/icons/builtin/MemberProperty.png")
extends BaseEvent
class_name OnPropertyChanged

## 属性变化监听事件
##
## 监听节点属性的变化，支持任意节点和属性
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _check_timer: float - 检查计时器
## - _last_value: Variant - 上次的值
## - _is_monitoring: bool - 是否正在监听
##
## 相关文档: addons/fuse/docs/migration-guide-to-runtime-instance.md

## 目标节点路径
@export var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 属性名
@export var property_name: String = "":
	set(value):
		property_name = value
		_update_resource_name()

## 检查间隔（秒），默认 0.1 秒
@export var check_interval: float = 0.1:
	set(value):
		check_interval = value
		_update_resource_name()

## 是否发出旧值和新值
@export var emit_old_and_new: bool = true

## 🔧 缓存节点引用，用于访问节点
var _target_node_ref: Node = null
var _owner_node_ref: Node = null

## 更新资源名称（必需）
func _update_resource_name():
	var node_text = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_PROPERTY_CHANGED_NO_NODE")
	var prop_text = property_name if not property_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_PROPERTY_CHANGED_NO_PROPERTY")

	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_PROPERTY_CHANGED_RESOURCE_NAME", {
		"node": node_text,
		"property": prop_text
	})

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
	# 验证 target_node
	if target_node.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证 property_name
	if property_name.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_PROPERTY_NAME_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证 check_interval
	if check_interval <= 0:
		_create_fuse_error_localized("FUSE_ERROR_CHECK_INTERVAL_INVALID", FuseError.ErrorType.CONFIGURATION_ERROR, {"interval": check_interval})
		return

	# 获取目标节点
	_target_node_ref = owner_node.get_node_or_null(target_node)
	if not _target_node_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	# 验证属性是否存在
	if not _target_node_ref.has_method("get") or not _property_exists():
		_create_fuse_error_localized("FUSE_ERROR_PROPERTY_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(target_node),
			"property": property_name
		})
		return

	# 设置监控状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", true)
		_runtime_instance_ref.set_runtime_state("check_timer", 0.0)
		_runtime_instance_ref.set_runtime_state("last_value", _get_property_value())

	_log_debug_localized("FUSE_LOG_EVENT_PROPERTY_MONITORING_STARTED", {
		"node": str(target_node),
		"property": property_name,
		"interval": check_interval
	})

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化运行时事件实例（必需）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 设置 Trigger 引用（从父类继承）
	set_trigger_ref(owner_node)

	# 获取目标节点
	_target_node_ref = owner_node.get_node_or_null(target_node)
	if not _target_node_ref:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
		return

	# 验证属性是否存在
	if not _target_node_ref.has_method("get") or not _property_exists():
		_create_fuse_error_localized("FUSE_ERROR_PROPERTY_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {
			"node_path": str(target_node),
			"property": property_name
		})
		return

	# 初始化运行时状态
	_initialize_runtime_state(runtime_instance)

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 初始化运行时状态（重写父类方法）
func _initialize_runtime_state(runtime_instance: RuntimeEventInstance) -> void:
	# 设置监控状态
	runtime_instance.set_runtime_state("is_monitoring", true)
	runtime_instance.set_runtime_state("check_timer", 0.0)
	runtime_instance.set_runtime_state("last_value", _get_property_value())

	_log_debug_localized("FUSE_LOG_EVENT_PROPERTY_MONITORING_STARTED", {
		"node": str(target_node),
		"property": property_name,
		"interval": check_interval
	})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 🔧 清理 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		_runtime_instance_ref.set_runtime_state("check_timer", 0.0)
		_runtime_instance_ref.set_runtime_state("last_value", null)

	_target_node_ref = null
	_owner_node_ref = null

	# 清理运行时实例引用
	_runtime_instance_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 每帧处理（由 Trigger 调用）
func on_process(delta: float, event_instance: RuntimeEventInstance = null) -> void:
	# 🔧 使用 RuntimeEventInstance 的状态
	var is_monitoring = false
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("is_monitoring"):
		is_monitoring = _runtime_instance_ref.get_runtime_state("is_monitoring")

	if not is_monitoring:
		return

	# 每帧写回累计值——历史上只在到点时写回，未到点时累计结果丢失，永不触发
	var check_timer = 0.0
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("check_timer"):
		check_timer = _runtime_instance_ref.get_runtime_state("check_timer")

	check_timer += delta

	if check_timer >= check_interval:
		check_timer -= check_interval
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("check_timer", check_timer)
		_check_property()
	elif _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("check_timer", check_timer)

## 检查属性变化
func _check_property():
	# 检查目标节点是否仍然有效
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		_log_warning("目标节点已失效，停止监听属性")
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("is_monitoring", false)
		return

	# 🔧 使用 RuntimeEventInstance 的状态
	var last_value = null
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("last_value"):
		last_value = _runtime_instance_ref.get_runtime_state("last_value")

	var current_value = _get_property_value()

	# 比较值是否变化
	if not _are_values_equal(current_value, last_value):
		var old_val = last_value
		if _runtime_instance_ref:
			_runtime_instance_ref.set_runtime_state("last_value", current_value)

		# 安全地获取节点名称
		var node_name = "Unknown"
		if _target_node_ref and is_instance_valid(_target_node_ref):
			node_name = _target_node_ref.name if _target_node_ref.name else "Unknown"

		_log_info_localized("FUSE_LOG_EVENT_PROPERTY_CHANGED", {
			"node": node_name,
			"property": property_name,
			"old_value": str(old_val) if emit_old_and_new else "(未发出)",
			"new_value": str(current_value) if emit_old_and_new else "(未发出)"
		})

		# 创建上下文节点传递值
		var context_node = Node.new()
		context_node.name = "PropertyChangedContext"
		if emit_old_and_new:
			context_node.set_meta("old_value", old_val)
			context_node.set_meta("new_value", current_value)
		context_node.set_meta("property_name", property_name)
		context_node.set_meta("target_node", _target_node_ref)
		context_node.set_meta("trigger", _owner_node_ref)

		# 桥接 last_event_args（宿主 Trigger 同步为 event_<参数名> 局部变量）
		if _runtime_instance_ref:
			var event_args: Dictionary = {"property_name": property_name}
			if emit_old_and_new:
				event_args["old_value"] = old_val
				event_args["new_value"] = current_value
			_runtime_instance_ref.set_runtime_state("last_event_args", event_args)

		if _runtime_instance_ref:
			_runtime_instance_ref.update_trigger_stats()

		triggered.emit(context_node)

		# 清理上下文节点
		context_node.queue_free()

## 获取属性值
func _get_property_value() -> Variant:
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return null

	# 使用 get() 方法获取属性值
	if _target_node_ref.has_method("get"):
		return _target_node_ref.call("get", property_name)

	return null

## 检查属性是否存在
func _property_exists() -> bool:
	if not _target_node_ref or not is_instance_valid(_target_node_ref):
		return false

	# 尝试获取属性列表
	var property_list = _target_node_ref.get_property_list()
	for prop in property_list:
		if prop.has("name") and prop.name == property_name:
			return true

	return false

## 比较两个值是否相等
func _are_values_equal(a: Variant, b: Variant) -> bool:
	# 处理 null 值
	if a == null and b == null:
		return true
	if a == null or b == null:
		return false

	# 检查类型是否相同
	if typeof(a) != typeof(b):
		return false

	# 比较值
	return a == b

## 获取事件描述
func get_description() -> String:
	var node_text = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_PROPERTY_CHANGED_NO_NODE")
	var prop_text = property_name if not property_name.is_empty() else FuseLocalization.translate("FUSE_EVENT_ON_PROPERTY_CHANGED_NO_PROPERTY")

	var value_text_key = "FUSE_EVENT_ON_PROPERTY_CHANGED_EMIT_VALUES" if emit_old_and_new else "FUSE_EVENT_ON_PROPERTY_CHANGED_EMIT_SIGNAL_ONLY"
	var value_text = FuseLocalization.translate(value_text_key)

	return FuseLocalization.translate_format("FUSE_EVENT_ON_PROPERTY_CHANGED_DESC", {
		"node": node_text,
		"property": prop_text,
		"interval": str(check_interval),
		"value": value_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "property_changed"

## 获取事件分类
func get_event_category() -> String:
	return "state"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if property_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_PROPERTY_NAME_EMPTY"))

	if check_interval <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_CHECK_INTERVAL_INVALID"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()

	# 🔧 重置 RuntimeEventInstance 的状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("check_timer", 0.0)
		if _target_node_ref and is_instance_valid(_target_node_ref):
			_runtime_instance_ref.set_runtime_state("last_value", _get_property_value())
		else:
			_runtime_instance_ref.set_runtime_state("last_value", null)

	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["check_timer"] = 0.0
	base["last_value"] = null
	base["is_monitoring"] = false
	return base

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_PROPERTY_CHANGED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_STATE"
	metadata.description_key = "FUSE_EVENT_ON_PROPERTY_CHANGED_DESC"
	metadata.keywords = ["property", "属性", "change", "变化", "monitor", "监听", "watch", "观察", "node", "节点"]
	metadata.builtin_icon = "MemberProperty"
	return metadata
