@tool
@icon("res://addons/fuse/icons/builtin/ColorRect.svg")
extends BaseInstruction
class_name ScreenFlash

## Screen Flash 指令 - 全屏闪烁效果
##
## 创建 CanvasLayer + ColorRect，通过 Tween 实现 alpha 脉冲。
## 异步执行，Tween 完成后触发 finished。

## 闪烁颜色
var color: Color = Color.WHITE:
	set(value):
		color = value
		_update_resource_name()

## 闪烁时长（秒）
var duration: float = 0.15:
	set(value):
		duration = max(value, 0.01)
		_update_resource_name()

## 闪烁次数
var flash_count: int = 1:
	set(value):
		flash_count = max(value, 1)
		_update_resource_name()

# =============================================
# 运行时状态
# =============================================
var _canvas_layer: CanvasLayer = null
var _color_rect: ColorRect = null
var _tween: Tween = null
var _current_flash: int = 0

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SCREEN_FLASH_NAME"
	metadata.category_key = "FUSE_CATEGORY_RENDERING"
	metadata.description_key = "FUSE_INSTRUCTION_SCREEN_FLASH_DESC"
	metadata.keywords = ["屏幕", "screen", "闪烁", "flash", "全屏", "fullscreen", "特效", "effect", "闪白", "hit", "伤害", "damage"]
	metadata.builtin_icon = "ColorRect"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Screen Flash",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "color",
		type = TYPE_COLOR,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "duration",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.01,2.0,0.01",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "flash_count",
		type = TYPE_INT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "1,10,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_SCREEN_FLASH_RESOURCE_NAME", {
		"color": "#%s" % color.to_html(false),
		"duration": duration,
		"count": flash_count
	})

## 获取指令描述
func get_description() -> String:
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SCREEN_FLASH_DESCRIPTION", {
		"color": "#%s" % color.to_html(false),
		"duration": duration,
		"count": flash_count
	})

## 执行指令（异步）
func execute(context: ExecutionContext) -> void:
	_start_execution(context)
	_is_synchronous_hint = false

	var scene_tree = context.target.get_tree()
	if not scene_tree:
		set_error_localized("FUSE_ERROR_SCENE_TREE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 创建 CanvasLayer
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "FuseScreenFlash"
	_canvas_layer.layer = 128
	scene_tree.root.add_child(_canvas_layer)

	# 创建 ColorRect
	_color_rect = ColorRect.new()
	_color_rect.name = "FlashRect"
	_color_rect.color = color
	_color_rect.color.a = 0.0
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_color_rect)

	# 执行闪烁
	_current_flash = 0
	_perform_flash()

func _perform_flash() -> void:
	if _current_flash >= flash_count:
		_cleanup()
		return

	# 创建 Tween
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	_tween = _color_rect.create_tween()
	_tween.set_trans(Tween.TRANS_SINE)

	# 单次闪烁的时长
	var single_duration = duration / float(flash_count)
	var half_duration = single_duration / 2.0

	# alpha: 0 → 1 → 0
	_tween.tween_property(_color_rect, "color:a", 1.0, half_duration)
	_tween.tween_property(_color_rect, "color:a", 0.0, half_duration)

	_tween.finished.connect(_on_flash_finished, CONNECT_ONE_SHOT)

func _on_flash_finished() -> void:
	_current_flash += 1
	_perform_flash()

func _cleanup() -> void:
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	_tween = null

	if _color_rect and is_instance_valid(_color_rect):
		_color_rect.queue_free()
	_color_rect = null

	if _canvas_layer and is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	_canvas_layer = null

	_log_info_localized("FUSE_LOG_SCREEN_FLASH", {
		"color": "#%s" % color.to_html(false),
		"count": flash_count
	})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if duration <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_DURATION_INVALID"))
	if flash_count <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_FLASH_COUNT_INVALID"))
	return errors
