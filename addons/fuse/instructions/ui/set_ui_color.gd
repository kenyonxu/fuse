@tool
@icon("res://addons/fuse/icons/builtin/ColorRect.svg")
extends BaseInstruction
class_name SetUIColor

## 设置 Control 节点的 modulate / self_modulate 颜色

# =============================================
# 枚举定义
# =============================================
enum ColorTarget {
	MODULATE,       # modulate 颜色
	SELF_MODULATE   # self_modulate 颜色
}

# =============================================
# 属性定义
# =============================================

## 目标 Control 节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 颜色目标类型
var color_target: ColorTarget = ColorTarget.MODULATE:
	set(value):
		color_target = value
		_update_resource_name()

## 目标颜色
var color: Color = Color.WHITE:
	set(value):
		color = value
		_update_resource_name()

## 是否从变量读取颜色
var use_variable: bool = false:
	set(value):
		use_variable = value
		_update_resource_name()
		notify_property_list_changed()

## 颜色变量名
var color_variable: String = "":
	set(value):
		color_variable = value
		_update_resource_name()

# =============================================
# 元数据（必需）
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_UI_COLOR_NAME"
	metadata.category_key = "FUSE_CATEGORY_UI"
	metadata.description_key = "FUSE_INSTRUCTION_SET_UI_COLOR_DESC"
	metadata.keywords = ["UI", "颜色", "color", "modulate", "self_modulate", "控件", "control", "透明度", "色调"]
	metadata.builtin_icon = "ColorRect"
	return metadata

func _setup_metadata():
	pass

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Target 分类
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
		hint_string = "Control",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Color 分类
	properties.append({
		name = "Color Settings",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "color_target",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Modulate,Self Modulate",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "use_variable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if use_variable:
		properties.append({
			name = "color_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "color",
			type = TYPE_COLOR,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

# =============================================
# 条件属性可见性
# =============================================
func _validate_property(property: Dictionary) -> void:
	if use_variable:
		if property.name == "color":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "color_variable":
			property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_UI_COLOR_RESOURCE_NAME", {
		"target": target_str,
		"color": str(color)
	})

# =============================================
# 执行
# =============================================
func execute(context: ExecutionContext):
	_start_execution(context)

	if target_node.is_empty():
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	var node := context.get_node(target_node)
	if not node or not (node is Control):
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
			"node": str(target_node),
			"actual_type": node.get_class() if node else "null"
		})
		finished.emit()
		return

	var ctrl := node as Control
	var final_color: Color = color

	# 从变量读取颜色
	if use_variable and not color_variable.is_empty():
		var var_color = VariableOperations.get_variable(context, color_variable, BaseVariable.VariableScope.LOCAL, null)
		if var_color is Color:
			final_color = var_color

	match color_target:
		ColorTarget.MODULATE:
			ctrl.modulate = final_color
		ColorTarget.SELF_MODULATE:
			ctrl.self_modulate = final_color

	_log_info_localized("FUSE_LOG_UI_COLOR_SET", {
		"node": node.name,
		"color": str(final_color)
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_UI_COLOR_DESCRIPTION", {
		"target": target_str,
		"color": str(color)
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	if use_variable and color_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
	return errors

# =============================================
# 动态属性拦截
# =============================================
func _set(property: StringName, value: Variant) -> bool:
	if property in ["color_target", "color", "use_variable", "color_variable"]:
		set(property, value)
		_update_resource_name()
		if property == "use_variable":
			notify_property_list_changed()
		return true
	return false
