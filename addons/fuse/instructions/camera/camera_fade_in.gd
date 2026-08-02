@tool
@icon("res://addons/fuse/icons/builtin/ColorRect.svg")
extends BaseInstruction
class_name CameraFadeIn

## Camera Fade In 指令 - 从全屏颜色渐变到透明（淡入效果）
##
## 创建一个 CanvasLayer + ColorRect 覆盖层，通过 Tween 渐变 alpha 实现淡入。

## 覆盖颜色
var color: Color = Color.BLACK:
	set(value):
		color = value
		_update_resource_name()

## 渐变时长（秒）
var duration: float = 1.0:
	set(value):
		duration = value
		_update_resource_name()

## 缓动类型
enum FadeEasing {
	LINEAR,   ## 线性
	EASE_IN,  ## 缓入
	EASE_OUT, ## 缓出
	EASE_IN_OUT ## 缓入缓出
}

var easing_type: FadeEasing = FadeEasing.EASE_OUT:
	set(value):
		easing_type = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_CAMERA_FADE_IN_NAME"
	metadata.category_key = "FUSE_CATEGORY_CAMERA"
	metadata.description_key = "FUSE_INSTRUCTION_CAMERA_FADE_IN_DESC"
	metadata.keywords = ["camera", "fade", "in", "淡入", "摄像机", "渐变", "过渡", "transition", "screen"]
	metadata.builtin_icon = "ColorRect"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({
		name = "Camera Fade In",
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
		hint_string = "0.1,10,0.1,or_greater",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "easing_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Linear,Ease In,Ease Out,Ease In Out",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []
	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_CAMERA_FADE_IN_NAME"))
	parts.append("(%.2fs)" % duration)
	resource_name = " ".join(parts)

## 获取指令描述
func get_description() -> String:
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_CAMERA_FADE_IN_DESC_FORMAT", {
		"duration": str(duration),
		"color": str(color)
	})

## 执行指令
func execute(context: ExecutionContext) -> void:
	_start_execution(context)

	# 获取场景树
	var tree = context.target.get_tree()
	if tree == null:
		_log_error_localized("FUSE_ERROR_SCENE_TREE_NOT_FOUND", {})
		set_error_localized("FUSE_ERROR_SCENE_TREE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 创建 CanvasLayer
	var canvas = CanvasLayer.new()
	canvas.name = "FuseCameraFadeIn"
	canvas.layer = 128  # 最高层确保覆盖一切

	# 创建 ColorRect
	var rect = ColorRect.new()
	rect.name = "FadeRect"
	rect.color = color
	rect.modulate.a = 1.0  # 完全不透明开始
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(rect)

	# 添加到场景根节点
	tree.root.add_child(canvas)

	# 创建 Tween 渐变 alpha
	var tween = canvas.create_tween()
	_apply_tween_easing(tween)

	tween.tween_property(rect, "modulate:a", 0.0, duration)

	_log_info_localized("FUSE_LOG_CAMERA_FADE_IN", {
		"duration": str(duration),
		"color": str(color)
	})

	# 等待动画完成后清理
	await tween.finished
	if is_instance_valid(canvas):
		canvas.queue_free()

	_on_execution_completed()

## 应用缓动设置
func _apply_tween_easing(tween: Tween) -> void:
	var tween_easing: Tween.EaseType
	var tween_trans: Tween.TransitionType

	match easing_type:
		FadeEasing.LINEAR:
			tween_easing = Tween.EaseType.EASE_IN
			tween_trans = Tween.TransitionType.TRANS_LINEAR
		FadeEasing.EASE_IN:
			tween_easing = Tween.EaseType.EASE_IN
			tween_trans = Tween.TransitionType.TRANS_SINE
		FadeEasing.EASE_OUT:
			tween_easing = Tween.EaseType.EASE_OUT
			tween_trans = Tween.TransitionType.TRANS_SINE
		FadeEasing.EASE_IN_OUT:
			tween_easing = Tween.EaseType.EASE_IN_OUT
			tween_trans = Tween.TransitionType.TRANS_SINE

	tween.set_ease(tween_easing)
	tween.set_trans(tween_trans)

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	if duration <= 0:
		errors.append(FuseLocalization.translate("FUSE_ERROR_DURATION_MUST_BE_POSITIVE"))
	return errors
