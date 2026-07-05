@tool
@icon("res://addons/fuse/icons/builtin/ShaderMaterial.svg")
extends BaseInstruction
class_name SetMaterialProperty

## 设置节点材质的 shader 参数，支持 CanvasItem 和 MeshInstance3D

# =============================================
# 枚举定义
# =============================================
enum ParamType {
	FLOAT,  # 浮点数
	COLOR,  # 颜色
	VEC2,   # Vector2
	VEC3,   # Vector3
	BOOL,   # 布尔值
	INT     # 整数
}

enum MaterialSlot {
	MATERIAL_0,       # CanvasItem 材质 / MeshInstance surface 0
	SURFACE_0,        # MeshInstance surface 0 覆盖材质
	SURFACE_1,        # MeshInstance surface 1 覆盖材质
	MATERIAL_OVERRIDE # MeshInstance material_override
}

# =============================================
# 属性定义
# =============================================

## 目标节点（CanvasItem 或 MeshInstance3D）
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_update_resource_name()

## 材质槽位
var material_slot: MaterialSlot = MaterialSlot.MATERIAL_0:
	set(value):
		material_slot = value
		_update_resource_name()

## shader 参数名
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

## 颜色值
var color_value: Color = Color.WHITE:
	set(value):
		color_value = value
		_update_resource_name()

## Vector2 值
var vec2_value: Vector2 = Vector2.ZERO:
	set(value):
		vec2_value = value
		_update_resource_name()

## Vector3 值
var vec3_value: Vector3 = Vector3.ZERO:
	set(value):
		vec3_value = value
		_update_resource_name()

## 布尔值
var bool_value: bool = false:
	set(value):
		bool_value = value
		_update_resource_name()

## 整数值
var int_value: int = 0:
	set(value):
		int_value = value
		_update_resource_name()

# =============================================
# 元数据（必需）
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_MATERIAL_PROPERTY_NAME"
	metadata.category_key = "FUSE_CATEGORY_RENDERING"
	metadata.description_key = "FUSE_INSTRUCTION_SET_MATERIAL_PROPERTY_DESC"
	metadata.keywords = ["材质", "material", "shader", "着色器", "参数", "parameter", "渲染", "rendering", "uniform"]
	metadata.builtin_icon = "ShaderMaterial"
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
		hint_string = "CanvasItem,MeshInstance3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "material_slot",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Material 0,Surface 0,Surface 1,Material Override",
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
		hint_string = "Float,Color,Vector2,Vector3,Bool,Int",
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
		ParamType.COLOR:
			properties.append({
				name = "color_value",
				type = TYPE_COLOR,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		ParamType.VEC2:
			properties.append({
				name = "vec2_value",
				type = TYPE_VECTOR2,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		ParamType.VEC3:
			properties.append({
				name = "vec3_value",
				type = TYPE_VECTOR3,
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
		ParamType.INT:
			properties.append({
				name = "int_value",
				type = TYPE_INT,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

# =============================================
# 条件属性可见性
# =============================================
func _validate_property(property: Dictionary) -> void:
	match parameter_type:
		ParamType.FLOAT:
			if property.name in ["color_value", "vec2_value", "vec3_value", "bool_value", "int_value"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		ParamType.COLOR:
			if property.name in ["float_value", "vec2_value", "vec3_value", "bool_value", "int_value"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		ParamType.VEC2:
			if property.name in ["float_value", "color_value", "vec3_value", "bool_value", "int_value"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		ParamType.VEC3:
			if property.name in ["float_value", "color_value", "vec2_value", "bool_value", "int_value"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		ParamType.BOOL:
			if property.name in ["float_value", "color_value", "vec2_value", "vec3_value", "int_value"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		ParamType.INT:
			if property.name in ["float_value", "color_value", "vec2_value", "vec3_value", "bool_value"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	var param_str = parameter_name if not parameter_name.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_MATERIAL_PROPERTY_RESOURCE_NAME", {
		"target": target_str,
		"param": param_str,
		"value": _get_value_str()
	})

func _get_value_str() -> String:
	match parameter_type:
		ParamType.FLOAT: return str(float_value)
		ParamType.COLOR: return str(color_value)
		ParamType.VEC2: return str(vec2_value)
		ParamType.VEC3: return str(vec3_value)
		ParamType.BOOL: return str(bool_value)
		ParamType.INT: return str(int_value)
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

	var node := context.get_node(target_node)
	if not node:
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	var material: Material

	if node is CanvasItem:
		var canvas := node as CanvasItem
		material = canvas.material
	elif node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		match material_slot:
			MaterialSlot.SURFACE_0:
				material = mesh.get_surface_override_material(0)
			MaterialSlot.SURFACE_1:
				material = mesh.get_surface_override_material(1)
			_:
				material = mesh.material_override
	else:
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {
			"node": node.name,
			"actual_type": node.get_class()
		})
		finished.emit()
		return

	if not material or not (material is ShaderMaterial):
		set_error_localized("FUSE_ERROR_NO_SHADER_MATERIAL", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var shader_mat := material as ShaderMaterial
	var value: Variant
	match parameter_type:
		ParamType.FLOAT: value = float_value
		ParamType.COLOR: value = color_value
		ParamType.VEC2:  value = vec2_value
		ParamType.VEC3:  value = vec3_value
		ParamType.BOOL:  value = bool_value
		ParamType.INT:   value = int_value

	shader_mat.set_shader_parameter(parameter_name, value)

	_log_info_localized("FUSE_LOG_MATERIAL_PARAM_SET", {
		"param": parameter_name,
		"value": str(value)
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_MATERIAL_PROPERTY_DESCRIPTION", {
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
	if property in ["material_slot", "parameter_name", "parameter_type", "float_value", "color_value", "vec2_value", "vec3_value", "bool_value", "int_value"]:
		set(property, value)
		_update_resource_name()
		if property == "parameter_type":
			notify_property_list_changed()
		return true
	return false
