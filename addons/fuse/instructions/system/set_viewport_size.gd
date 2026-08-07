@tool
@icon("res://addons/fuse/icons/builtin/Viewport.png")
extends BaseInstruction
class_name SetViewportSize

## Set Viewport Size 指令 - 设置项目主视口的逻辑分辨率
##
## 通过修改 root Window 的 content_scale_size 实现，等价于运行时更改
## 项目设置 display/window/size/viewport_width 与 viewport_height。
## 影响 2D 摄像机（Camera2D）的可视范围。
##
## 前提：项目 stretch/mode 不为 "disabled"（默认 "canvas_items"），
## 否则 content_scale_size 不参与视口计算（见 Window::_update_viewport_size）。

## 视口宽度（逻辑像素）
var width: int = 1280:
	set(value):
		width = value
		_update_resource_name()

## 视口高度（逻辑像素）
var height: int = 720:
	set(value):
		height = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_VIEWPORT_SIZE_NAME"
	metadata.category_key = "FUSE_CATEGORY_SYSTEM"
	metadata.description_key = "FUSE_INSTRUCTION_SET_VIEWPORT_SIZE_DESC"
	metadata.keywords = ["视口", "viewport", "尺寸", "size", "分辨率", "resolution", "逻辑", "logical", "摄像机", "camera", "content_scale", "宽度", "width", "高度", "height"]
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
		name = "Viewport Size",
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
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_VIEWPORT_SIZE_NAME"))
	parts.append("%dx%d" % [width, height])
	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_VIEWPORT_SIZE_DESC_FORMAT", {
		"width": str(width),
		"height": str(height)
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# 验证尺寸
	if width <= 0 or height <= 0:
		_log_error_localized("FUSE_ERROR_VIEWPORT_SIZE_INVALID", {
			"width": str(width),
			"height": str(height)
		})
		set_error_localized("FUSE_ERROR_VIEWPORT_SIZE_INVALID", FuseError.ErrorType.VALIDATION_ERROR, {
			"width": str(width),
			"height": str(height)
		})
		finished.emit()
		return

	# 获取 root Window（项目主窗口）
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_log_error_localized("FUSE_ERROR_VIEWPORT_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_VIEWPORT_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var root: Window = tree.get_root()
	if root == null:
		_log_error_localized("FUSE_ERROR_VIEWPORT_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_VIEWPORT_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 设置逻辑视口分辨率（Window.content_scale_size，setter 要求 >= 0）
	# 等价运行时更改 display/window/size/viewport_width/height，实时触发 _update_viewport_size()
	root.content_scale_size = Vector2i(width, height)

	_log_info_localized("FUSE_LOG_VIEWPORT_SIZE", {
		"width": str(width),
		"height": str(height)
	})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if width <= 0 or height <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_VIEWPORT_SIZE_INVALID"))
	return errors
