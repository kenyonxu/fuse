@tool
@icon("res://addons/fuse/icons/builtin/Mouse.png")
extends BaseInstruction
class_name MouseWorldPosition

## 获取鼠标在 2D 世界中的位置并保存到变量

# =============================================
# 属性定义
# =============================================

## Camera2D 节点（空 = 使用当前 viewport 默认变换）
var camera_node: NodePath = NodePath(""):
	set(value):
		camera_node = value
		_update_resource_name()

## 保存鼠标世界坐标到变量
var save_to_variable: String = "":
	set(value):
		save_to_variable = value
		_update_resource_name()

# =============================================
# 元数据（必需）
# =============================================
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_MOUSE_WORLD_POS_NAME"
	metadata.category_key = "FUSE_CATEGORY_SYSTEM"
	metadata.description_key = "FUSE_INSTRUCTION_MOUSE_WORLD_POS_DESC"
	metadata.keywords = ["鼠标", "mouse", "世界坐标", "world", "position", "坐标", "位置", "2D", "变量", "variable"]
	metadata.builtin_icon = "Mouse"
	return metadata

func _setup_metadata():
	pass

## 声明变量读写模式（save_to=write）
func get_variable_modes() -> Array[Dictionary]:
	return [{"name": "save_to_variable", "mode": "write"}]

# =============================================
# 动态属性列表
# =============================================
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Camera 分类
	properties.append({
		name = "Camera",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "camera_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Camera2D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Output 分类
	properties.append({
		name = "Output",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "save_to_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

# =============================================
# 资源名称
# =============================================
func _update_resource_name():
	var var_str = save_to_variable if not save_to_variable.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_MOUSE_WORLD_POS_RESOURCE_NAME", {
		"var": var_str
	})

# =============================================
# 执行
# =============================================
func execute(context: ExecutionContext):
	_start_execution(context)

	if save_to_variable.is_empty():
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取 viewport
	var viewport: Viewport = null
	if context.has_node("."):
		var root = context.get_node(".")
		if root:
			viewport = root.get_viewport()

	if not viewport:
		set_error_localized("FUSE_ERROR_VIEWPORT_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 获取鼠标屏幕坐标
	var mouse_pos = viewport.get_mouse_position()
	var world_pos: Vector2 = mouse_pos

	# 如果有指定 camera，使用 camera 变换
	if not camera_node.is_empty():
		var camera = context.get_node(camera_node) as Camera2D
		if camera:
			var canvas_transform = camera.get_canvas_transform()
			world_pos = canvas_transform.affine_inverse() * mouse_pos
		else:
			# camera 节点不存在，使用默认 canvas_transform
			var canvas_transform = viewport.canvas_transform
			world_pos = canvas_transform.affine_inverse() * mouse_pos
	else:
		var canvas_transform = viewport.canvas_transform
		world_pos = canvas_transform.affine_inverse() * mouse_pos

	# 保存到变量
	VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, world_pos)

	_log_info_localized("FUSE_LOG_MOUSE_WORLD_POS", {
		"pos": str(world_pos),
		"var": save_to_variable
	})
	_on_execution_completed()

# =============================================
# 描述
# =============================================
func get_description() -> String:
	var var_str = save_to_variable if not save_to_variable.is_empty() else FuseLocalization.translate("FUSE_TEXT_UNSPECIFIED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_MOUSE_WORLD_POS_DESCRIPTION", {
		"var": var_str
	})

# =============================================
# 验证
# =============================================
func validate() -> Array[String]:
	var errors = super.validate()
	if save_to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))
	return errors

# =============================================
# 动态属性拦截
# =============================================
func _set(property: StringName, value: Variant) -> bool:
	if property == "save_to_variable":
		set(property, value)
		_update_resource_name()
		return true
	return false
