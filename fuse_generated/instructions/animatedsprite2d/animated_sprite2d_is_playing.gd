@tool
@icon("res://addons/bricks/icons/instruction.svg")
extends BaseInstruction

## 调用 AnimatedSprite2D.is_playing 方法
## 自动生成 - 请勿手动修改

## 目标节点路径
@export var target_node: NodePath = NodePath("")

## 返回值存储变量名（可选）
@export var result_variable: String = ""
## 返回值存储作用域
@export var result_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		result_variable_scope = value
		notify_property_list_changed()
## 作用域来源（仅 SCOPE 作用域时生效）
enum ScopeSource { NEAREST, CUSTOM_ID, TRIGGER_SCOPE, TARGET_NODE }
@export var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		notify_property_list_changed()
## 自定义作用域 ID（仅 CUSTOM_ID 模式时生效）
@export var custom_scope_id: String = ""

static func _get_instruction_metadata() -> InstructionMetadata:
	var md = InstructionMetadata.new()
	md.name = "调用 AnimatedSprite2D.is_playing"
	md.category = "用户生成"
	md.description = "调用 AnimatedSprite2D 节点的 is_playing 方法"
	md.keywords = ["animatedsprite2d", "is_playing", "call"]
	return md

func _setup_metadata():
	pass

func _update_resource_name():
	resource_name = "CallAnimatedSprite2DIsPlaying"

func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点
	if target_node.is_empty():
		set_error("目标节点路径为空")
		finished.emit()
		return

	# 获取目标节点
	var node := context.get_node(target_node)
	if node == null:
		set_error("找不到目标节点: %s" % str(target_node))
		finished.emit()
		return

	# 类型检查
	if not node is AnimatedSprite2D:
		set_error("目标节点不是 AnimatedSprite2D 类型")
		finished.emit()
		return

	# 调用方法
	var result = node.is_playing()

	# 存储返回值
	if not result_variable.is_empty():
		match result_variable_scope:
			BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
				VariableOperations.set_variable(context, result_variable, result_variable_scope, result)
			BaseVariable.VariableScope.SCOPE:
				if scope_source == ScopeSource.NEAREST:
					VariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.SCOPE, result)
				else:
					var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(context, utils_scope_source, custom_scope_id, target_node)
					if scope_container == null:
						set_error("找不到作用域容器")
						finished.emit()
						return
					scope_container.set_variable(result_variable, result)

	_on_execution_completed()

func get_description() -> String:
	return "调用 AnimatedSprite2D.is_playing on " + str(target_node)

func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append("目标节点路径为空")
	return errors

func _validate_property(property: Dictionary) -> void:
	if result_variable_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["scope_source", "custom_scope_id"]:
			property.usage = PROPERTY_USAGE_NONE
			return
	if scope_source != ScopeSource.CUSTOM_ID and property.name == "custom_scope_id":
		property.usage = PROPERTY_USAGE_NONE

