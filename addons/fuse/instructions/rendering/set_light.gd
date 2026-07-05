@tool
@icon("res://addons/fuse/icons/builtin/OmniLight3D.svg")
extends BaseInstruction
class_name SetLight

## Set Light 指令 - 设置 Light2D/Light3D 的属性（能量/颜色/启用）

## 目标节点路径
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()
		notify_property_list_changed()

## 灯光能量
var energy: float = 1.0:
	set(value):
		energy = value
		_update_resource_name()

## 灯光颜色
var light_color: Color = Color.WHITE:
	set(value):
		light_color = value
		_update_resource_name()

## 是否启用
var enabled: bool = true:
	set(value):
		enabled = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_LIGHT_NAME"
	metadata.category_key = "FUSE_CATEGORY_RENDERING"
	metadata.description_key = "FUSE_INSTRUCTION_SET_LIGHT_DESC"
	metadata.keywords = ["灯光", "light", "照明", "能量", "energy", "颜色", "color", "启用", "enable", "2D", "3D"]
	metadata.builtin_icon = "OmniLight3D"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Set Light",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Light2D,Light3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "energy",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,100,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "light_color",
		type = TYPE_COLOR,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "enabled",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_LIGHT_NAME"))

	if not target_node.is_empty():
		parts.append("[%s]" % _get_node_display_name(target_node))
	else:
		parts.append("[%s]" % FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED"))

	var state = FuseLocalization.translate("FUSE_COMMON_ENABLED") if enabled else FuseLocalization.translate("FUSE_COMMON_DISABLED")
	parts.append("[%s]" % state)

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	var target_desc = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_COMMON_NO_NODE_SELECTED")
	var state = FuseLocalization.translate("FUSE_COMMON_ENABLED") if enabled else FuseLocalization.translate("FUSE_COMMON_DISABLED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_LIGHT_DESC_FORMAT", {
		"target": target_desc,
		"energy": str(energy),
		"state": state
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var node = context.get_node(target_node)
	if node == null:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 支持 Light2D 和 Light3D
	if node is Light2D:
		var light := node as Light2D
		light.energy = energy
		light.color = light_color
		light.enabled = enabled
	elif node is Light3D:
		var light := node as Light3D
		light.light_energy = energy
		light.light_color = light_color
		light.light_enabled = enabled  # 在 Godot 4.6 中 Light3D 可能使用 visible 或 enabled
	else:
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": node.name, "expected": "Light2D or Light3D"})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"node": node.name, "expected": "Light2D or Light3D"})
		finished.emit()
		return

	_log_info_localized("FUSE_LOG_LIGHT_SET", {
		"node": node.name,
		"energy": str(energy),
		"color": str(light_color)
	})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	return errors
