@tool
@icon("res://addons/fuse/icons/builtin/Script.png")
extends BaseInstruction
class_name SyncInstructionTemplate

## 指令描述（简短说明指令的功能）
##
## 详细描述（可选）：
## - 用途说明
## - 使用场景
## - 注意事项

# =============================================
# 参数定义
# =============================================

# 目标节点路径（如果需要）
var target_node: NodePath = NodePath("")

# 其他参数根据需要添加
# var parameter_name: Variant = 0  # 示例：根据实际类型设置默认值

# =============================================
# 元数据方法
# =============================================

## 获取指令元数据（必需）
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_XXX_NAME"
	metadata.category_key = "FUSE_CATEGORY_XXX"
	metadata.description_key = "FUSE_INSTRUCTION_XXX_DESC"
	metadata.keywords = ["keyword1", "keyword2", "keyword3"]
	metadata.builtin_icon = "Script"  # 选择合适的图标
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# 添加分类（可选）
	properties.append({
		name = "Category",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 添加属性
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Node2D,Node3D",  # 根据需要调整
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 动态属性设置（可选）
func _set(property: StringName, value: Variant) -> bool:
	if property == "some_property":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false

## 属性验证（可选，用于条件性显示属性）
# 示例：根据条件隐藏属性
# var show_optional: bool = false
# func _validate_property(property: Dictionary) -> void:
# 	if property.name == "optional_property" and not show_optional:
# 		property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []

	parts.append("操作名称")

	if not target_node.is_empty():
		parts.append("'%s'" % target_node)
	else:
		parts.append("未指定节点")

	resource_name = " ".join(parts)

## 获取指令描述（必需）
func get_description() -> String:
	return "操作 %s" % str(target_node)

# =============================================
# 执行逻辑
# =============================================

## 执行指令（必需）
func execute(context: ExecutionContext):
	_start_execution(context)

	# ============================================
	# 1. 验证参数
	# ============================================

	if target_node.is_empty():
		_log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
		set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# ============================================
	# 2. 获取节点
	# ============================================

	var node := context.get_node(target_node)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# ============================================
	# 3. 类型检查（如果需要）
	# ============================================

	if not (node is Node2D or node is Node3D):
		var type_str = node.get_class()
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": node.name, "actual_type": type_str})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"node": node.name, "actual_type": type_str})
		finished.emit()
		return

	# ============================================
	# 4. 执行核心逻辑
	# ============================================

	# 在这里实现你的指令逻辑
	# ...

	_log_info("指令执行成功")

	# ============================================
	# 5. 同步完成
	# ============================================

	_on_execution_completed()

# =============================================
# 验证
# =============================================

## 验证指令参数（必需）
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append("目标节点路径不能为空")

	# 添加其他验证...
	# if parameter_name < 0:
	#     errors.append("参数不能为负数")

	return errors

# =============================================
# 辅助方法（根据需要添加）
# =============================================

## 示例：验证数值有效性
func _is_valid_value(value: float) -> bool:
	return not (is_nan(value) or is_inf(value))

## 示例：验证向量有效性
func _is_valid_vector(value: Vector3) -> bool:
	return not (is_nan(value.x) or is_inf(value.x) or
				is_nan(value.y) or is_inf(value.y) or
				is_nan(value.z) or is_inf(value.z))

# =============================================
# 资源清理（如果需要）
# =============================================

## 清理资源（可选）
func _cleanup_resources():
	super._cleanup_resources()
	# 清理定时器、信号连接等
	# if _timer and is_instance_valid(_timer):
	#     if _timer.timeout.is_connected(_on_timer_timeout):
	#         _timer.timeout.disconnect(_on_timer_timeout)
	#     _timer = null
