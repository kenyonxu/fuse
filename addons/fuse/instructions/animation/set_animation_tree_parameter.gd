@tool
@icon("res://addons/fuse/icons/builtin/AnimationTree.png")
extends BaseInstruction
class_name SetAnimationTreeParameter

## 设置 AnimationTree 节点的参数值，支持多种参数类型

# =============================================
# 枚举定义
# =============================================
enum ParamType {
	FLOAT,   # 浮点数
	INT,     # 整数
	BOOL,    # 布尔值
	STRING   # 字符串（条件参数）
}

# =============================================
# 属性定义
# =============================================

## 目标 AnimationTree 节点
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## AnimationTree 参数名
var parameter_name: String = "":
	set(value):
		parameter_name = value
		_update_resource_name()

## 参数类型
var parameter_type: ParamType = ParamType.FLOAT:
	set(value):
		parameter_type = value
		_update_resource_name()
		notify_property_list_changed()

## 浮点值
var float_value: float = 0.0:
	set(value):
		float_value = value
		_update_resource_name()

## 整数值
var int_value: int = 0:
	set(value):
		int_value = value
		_update_resource_name()

## 布尔值
var bool_value: bool = false:
	set(value):
		bool_value = value
		_update_resource_name()

## 字符串值
var string_value: String = "":
	set(value):
		string_value = value
		_update_resource_name()

# =============================================
# 元数据（必需）
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_ANIM_TREE_PARAM_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_INSTRUCTION_SET_ANIM_TREE_PARAM_DESC"
	metadata.keywords = ["动画树", "animation", "tree", "animtree", "参数", "parameter", "blend", "混合"]
	metadata.builtin_icon = "AnimationTree"
	return metadata

func _setup_metadata():
	pass

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties := []

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
		hint_string = "AnimationTree",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Parameter 分类
	properties.append({
		name = "Parameter",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "parameter_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "parameter_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Float,Int,Bool,String",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Value 分类（根据参数类型动态显示）
	properties.append({
		name = "Value",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	match parameter_type:
		ParamType.FLOAT:
			properties.append({
				name = "float_value",
				type = TYPE_FLOAT,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		ParamType.INT:
			properties.append({
				name = "int_value",
				type = TYPE_INT,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		ParamType.BOOL:
			properties.append({
				name = "bool_value",
				type = TYPE_BOOL,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		ParamType.STRING:
			properties.append({
				name = "string_value",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

# =============================================
# 条件属性可见性
# =============================================
func _validate_property(property: Dictionary) -> void:
	# 根据 parameter_type 隐藏不需要的值属性
	match parameter_type:
		ParamType.FLOAT:
			if property.name in ["int_value", "bool_value", "string_value"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		ParamType.INT:
			if property.name in ["float_value", "bool_value", "string_value"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		ParamType.BOOL:
			if property.name in ["float_value", "int_value", "string_value"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		ParamType.STRING:
			if property.name in ["float_value", "int_value", "bool_value"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var param_str = parameter_name if not parameter_name.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var value_str = _get_value_str()
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_ANIM_TREE_PARAM_RESOURCE_NAME", {
		"param": param_str,
		"value": value_str
	})

func _get_value_str() -> String:
	match parameter_type:
		ParamType.FLOAT: return str(float_value)
		ParamType.INT: return str(int_value)
		ParamType.BOOL: return str(bool_value)
		ParamType.STRING: return string_value
		_: return ""

# =============================================
# 执行
# =============================================
func execute(context: ExecutionContext):
	_start_execution(context)

	if target_node.is_empty() or parameter_name.is_empty():
		set_error_localized("FUSE_ERROR_MISSING_PARAMETER", FuseError.ErrorType.VALIDATION_ERROR, {"parameter": "target_node/parameter_name"})
		finished.emit()
		return

	var anim_tree := context.get_node(target_node)
	if not anim_tree or not (anim_tree is AnimationTree):
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
			"node": str(target_node),
			"actual_type": anim_tree.get_class() if anim_tree else "null"
		})
		finished.emit()
		return

	var tree := anim_tree as AnimationTree
	var param_path = "parameters/%s" % parameter_name

	match parameter_type:
		ParamType.FLOAT:
			tree.set(param_path, float_value)
		ParamType.INT:
			tree.set(param_path, int_value)
		ParamType.BOOL:
			tree.set(param_path, bool_value)
		ParamType.STRING:
			tree.set(param_path, string_value)

	_log_info_localized("FUSE_LOG_ANIM_TREE_PARAM_SET", {
		"param": parameter_name,
		"value": _get_value_str()
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_ANIM_TREE_PARAM_DESCRIPTION", {
		"target": target_str,
		"param": parameter_name,
		"value": _get_value_str()
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))
	if parameter_name.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_MISSING_PARAMETER"))
	return errors

# =============================================
# 动态属性拦截
# =============================================
func _set(property: StringName, value: Variant) -> bool:
	if property in ["parameter_type", "parameter_name", "float_value", "int_value", "bool_value", "string_value"]:
		set(property, value)
		_update_resource_name()
		if property == "parameter_type":
			notify_property_list_changed()
		return true
	return false
