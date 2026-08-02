@tool
@icon("res://addons/fuse/icons/builtin/KeyInvalid.png")
extends BaseInstruction
class_name BreakLoop

## 跳出循环
##
## 在循环体内使用，立即退出当前循环。
## 只能在 For Loop 或 While Loop 中使用.

# 静态缓存变量
static var _cached_desc: String = ""
static var _desc_cached: bool = false

## 初始化翻译缓存
static func _init_translation_cache() -> void:
	if _desc_cached:
		return
	_cached_desc = FuseLocalization.translate("FUSE_INSTRUCTION_BREAK_LOOP_DESC")
	_desc_cached = true

## 获取指令元数据（用于指令选择器）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_BREAK_LOOP_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_BREAK_LOOP_DESC"
	metadata.keywords = ["break", "loop", "exit", "跳出", "循环", "退出"]
	metadata.builtin_icon = "KeyInvalid"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# 初始化翻译缓存
	_init_translation_cache()

	# Info 分类
	properties.append({
		name = "Info",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "description",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_PLACEHOLDER_TEXT,
		hint_string = _cached_desc,  # 使用缓存
		usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
	})

	return properties

## 更新资源名称
func _update_resource_name():
	resource_name = FuseLocalization.translate("FUSE_INSTRUCTION_BREAK_LOOP_NAME")

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 检查是否在循环中
	if not context.is_in_loop():
		_log_error_localized("FUSE_ERROR_BREAK_NOT_IN_LOOP", {})
		set_error_localized("FUSE_ERROR_BREAK_NOT_IN_LOOP", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 设置 break 标志
	context.set_break_loop_flag()
	_log_info_localized("FUSE_LOG_BREAK_DETECTED", {"index": str(context.get_current_loop_index() if context.has_method("get_current_loop_index") else "?")})
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()
	# Break Loop 没有需要验证的参数
	return errors

## 获取指令描述
func get_description() -> String:
	return FuseLocalization.translate("FUSE_INSTRUCTION_BREAK_LOOP_DESC")
