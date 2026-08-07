@tool
@icon("res://addons/fuse/icons/builtin/Viewport.png")
extends BaseInstruction
class_name SetWindowSize

## Set Window Size 指令 - 设置游戏窗口尺寸（像素）
##
## 通过 DisplayServer.window_set_size 修改主窗口尺寸。
## 注意：仅在运行时生效，不影响 project.godot 中的初始窗口配置。

## 窗口宽度（像素）
var width: int = 1280:
	set(value):
		width = value
		_update_resource_name()

## 窗口高度（像素）
var height: int = 720:
	set(value):
		height = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_WINDOW_SIZE_NAME"
	metadata.category_key = "FUSE_CATEGORY_SYSTEM"
	metadata.description_key = "FUSE_INSTRUCTION_SET_WINDOW_SIZE_DESC"
	metadata.keywords = ["窗口", "window", "尺寸", "size", "屏幕", "screen", "分辨率", "resolution", "宽度", "width", "高度", "height", "DisplayServer"]
	metadata.builtin_icon = "Viewport"
	return metadata

func _setup_metadata():
	pass

## 声明变量读写模式（本指令无变量属性）
func get_variable_modes() -> Array[Dictionary]:
	return []

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Window Size",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "width",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "1,7680,1",  # 1px ~ 8K，防止 0 或负数
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "height",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "1,4320,1",  # 1px ~ 8K，防止 0 或负数
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_WINDOW_SIZE_NAME"))
	parts.append("%dx%d" % [width, height])
	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_WINDOW_SIZE_DESC_FORMAT", {
		"width": str(width),
		"height": str(height)
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# 验证尺寸
	if width <= 0 or height <= 0:
		_log_error_localized("FUSE_ERROR_WINDOW_SIZE_INVALID", {
			"width": str(width),
			"height": str(height)
		})
		set_error_localized("FUSE_ERROR_WINDOW_SIZE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {
			"width": str(width),
			"height": str(height)
		})
		finished.emit()
		return

	# 设置窗口尺寸（DisplayServer.window_set_size(Vector2i, WindowID = MAIN_WINDOW_ID)）
	DisplayServer.window_set_size(Vector2i(width, height))

	_log_info_localized("FUSE_LOG_WINDOW_SIZE_SET", {
		"width": str(width),
		"height": str(height)
	})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if width <= 0 or height <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_WINDOW_SIZE_INVALID"))
	return errors
