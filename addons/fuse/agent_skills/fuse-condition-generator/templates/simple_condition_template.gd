@tool
@icon("res://addons/fuse/icons/builtin/NodePath.png")
extends BaseCondition
class_name CheckSimpleConditionTemplate

## 简单条件描述（简短说明条件的功能）
##
## 简单条件说明：
## - 检查单一条件
## - 返回布尔值
## - 不依赖变量

# =============================================
# 参数定义
# =============================================

## 检查参数
@export_group("Condition Check")
@export var check_parameter: String = "":
	set(value):
		check_parameter = value
		_update_resource_name()

## 期望值（如果需要）
@export var expected_value: Variant:
	set(value):
		expected_value = value
		_update_resource_name()

# =============================================
# 元数据方法
# =============================================

## 获取条件元数据（必需）
static func _get_condition_metadata() -> ConditionMetadata:
	var metadata = ConditionMetadata.new()
	metadata.name_key = "FUSE_CONDITION_XXX_NAME"
	metadata.category_key = "FUSE_CATEGORY_XXX"
	metadata.description_key = "FUSE_CONDITION_XXX_DESC"
	metadata.keywords = ["keyword1", "keyword2", "keyword3"]
	metadata.builtin_icon = "NodePath"
	return metadata

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称（必需）
func _update_resource_name():
	var parts = []

	parts.append("条件检查")

	if not check_parameter.is_empty():
		parts.append("'%s'" % check_parameter)
	else:
		parts.append("(未设置)")

	resource_name = " ".join(parts)

## 获取条件类型
func get_condition_type() -> String:
	return "simple_condition"

## 获取条件分类
func get_condition_category() -> String:
	return "category"

## 获取条件描述
func get_description() -> String:
	if check_parameter.is_empty():
		return "条件检查 (未设置参数)"

	return "条件检查: %s" % check_parameter

# =============================================
# 条件评估
# =============================================

## 评估条件（必需）
func _evaluate_condition(context: ExecutionContext) -> bool:
	# ============================================
	# 1. 验证参数
	# ============================================

	if check_parameter.is_empty():
		_log_error("检查参数不能为空")
		_create_fuse_error_localized("FUSE_ERROR_PARAMETER_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		return false

	# ============================================
	# 2. 执行检查逻辑
	# ============================================

	var result = _perform_check(context)

	# ============================================
	# 3. 记录日志
	# ============================================

	_log_debug("条件检查结果: %s => %s" % [check_parameter, "true" if result else "false"])

	# ============================================
	# 4. 返回布尔值
	# ============================================

	return result

# =============================================
# 检查逻辑实现
# =============================================

## 执行检查逻辑
func _perform_check(context: ExecutionContext) -> bool:
	# ============================================
	# 在这里实现具体的检查逻辑
	# ============================================

	# 示例：检查节点是否存在
	var node = context.get_node(check_parameter)
	var exists = node != null

	return exists

	# 其他示例：
	#
	# # 检查数值范围
	# var value = get_some_value()
	# return value > min_value and value < max_value
	#
	# # 检查字符串包含
	# var text = get_some_text()
	# return text.find(check_parameter) >= 0
	#
	# # 检查布尔值
	# var flag = get_some_flag()
	# return flag == true

# =============================================
# 依赖计算
# =============================================

## 计算依赖（如果不依赖变量，返回空数组）
func _compute_dependencies() -> Array[String]:
	# 如果条件依赖变量，返回变量名列表
	# 例如：return ["variable1", "variable2"]
	return []

# =============================================
# 参数方法
# =============================================

## 获取参数
func get_parameters() -> Dictionary:
	return {
		"check_parameter": check_parameter,
		"expected_value": expected_value
	}

## 设置参数
func set_parameters(parameters: Dictionary):
	if parameters.has("check_parameter"):
		check_parameter = parameters["check_parameter"]
	if parameters.has("expected_value"):
		expected_value = parameters["expected_value"]

# =============================================
# 验证
# =============================================

## 验证条件配置（必需）
func validate() -> Array[String]:
	var errors: Array[String] = super.validate()

	if check_parameter.is_empty():
		errors.append("检查参数不能为空")

	return errors
