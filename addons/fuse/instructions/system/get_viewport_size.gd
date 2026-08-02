@tool
@icon("res://addons/fuse/icons/builtin/Viewport.png")
extends BaseInstruction
class_name GetViewportSize

## Get Viewport Size 指令 - 获取当前视口尺寸并保存到变量

## 宽度保存到的变量名
var save_to_variable_x: String = "":
	set(value):
		save_to_variable_x = value
		_update_resource_name()

## 高度保存到的变量名
var save_to_variable_y: String = "":
	set(value):
		save_to_variable_y = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_GET_VIEWPORT_SIZE_NAME"
	metadata.category_key = "FUSE_CATEGORY_SYSTEM"
	metadata.description_key = "FUSE_INSTRUCTION_GET_VIEWPORT_SIZE_DESC"
	metadata.keywords = ["视口", "viewport", "尺寸", "size", "屏幕", "screen", "分辨率", "resolution", "宽度", "width", "高度", "height"]
	metadata.builtin_icon = "Viewport"
	return metadata

func _setup_metadata():
	pass

## 声明变量读写模式（save_to_x/y=write）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "save_to_variable_x", "mode": "write"},
		{"name": "save_to_variable_y", "mode": "write"},
	]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Viewport Size",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "save_to_variable_x",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "save_to_variable_y",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_VIEWPORT_SIZE_NAME"))

	var vars = []
	if not save_to_variable_x.is_empty():
		vars.append(save_to_variable_x)
	if not save_to_variable_y.is_empty():
		vars.append(save_to_variable_y)

	if not vars.is_empty():
		parts.append("→ %s" % ", ".join(vars))

	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_VIEWPORT_SIZE_DESC_FORMAT", {
		"var_x": save_to_variable_x if not save_to_variable_x.is_empty() else "-",
		"var_y": save_to_variable_y if not save_to_variable_y.is_empty() else "-"
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# 获取视口
	var viewport = context.target.get_viewport()
	if viewport == null:
		_log_error_localized("FUSE_ERROR_VIEWPORT_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_VIEWPORT_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var size = viewport.get_visible_rect().size

	# 保存到变量
	if not save_to_variable_x.is_empty():
		context.set_local(save_to_variable_x, size.x)

	if not save_to_variable_y.is_empty():
		context.set_local(save_to_variable_y, size.y)

	_log_info_localized("FUSE_LOG_VIEWPORT_SIZE", {
		"width": str(size.x),
		"height": str(size.y)
	})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if save_to_variable_x.is_empty() and save_to_variable_y.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VIEWPORT_VAR_EMPTY"))
	return errors
