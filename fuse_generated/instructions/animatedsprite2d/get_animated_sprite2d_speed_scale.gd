@tool
@icon("res://addons/bricks/icons/instruction.svg")
extends BaseInstruction

## 获取 AnimatedSprite2D.speed_scale
## 自动生成 - 请勿手动修改

## 目标节点路径
var target_node: NodePath = NodePath("")

## 保存到的变量名
var save_to_variable: String = ""

## 保存到的变量作用域
var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		save_to_scope = value
		notify_property_list_changed()

## 作用域来源枚举
enum ScopeSource { NEAREST, CUSTOM_ID, TRIGGER_SCOPE, TARGET_NODE }

## 保存作用域来源（仅当 save_to_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		notify_property_list_changed()

## 保存自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = ""

## 保存目标节点路径（TARGET_NODE 模式使用）
var save_target_node_path: NodePath = NodePath("")

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	# Target 分类
	properties.append({
		name = "Target",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "AnimatedSprite2D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Save To 分类
	properties.append({
		name = "Save To",
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

	properties.append({
		name = "save_to_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 仅当 save_to_scope == SCOPE 时显示作用域来源属性
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 根据 scope_source 添加额外属性
		if scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "save_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

static func _get_instruction_metadata() -> InstructionMetadata:
	var md = InstructionMetadata.new()
	md.name = "获取 AnimatedSprite2D.speed_scale"
	md.category = "用户生成"
	md.description = "获取 AnimatedSprite2D 节点的 speed_scale 属性值并保存到变量"
	md.keywords = ["animatedsprite2d", "speed_scale", "get"]
	return md

func _setup_metadata():
	pass

func _update_resource_name():
	resource_name = "GetAnimatedSprite2DSpeedScale"

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

	# 读取属性值
	var value = node.speed_scale

	# 保存到变量
	if save_to_variable.is_empty():
		set_error("保存变量名不能为空")
		finished.emit()
		return

	match save_to_scope:
		BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
			VariableOperations.set_variable(context, save_to_variable, save_to_scope, value)
		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, value)
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(context, utils_scope_source, custom_scope_id, save_target_node_path)
				if scope_container == null:
					set_error("找不到作用域容器")
					finished.emit()
					return
				scope_container.set_variable(save_to_variable, value)

	_on_execution_completed()

func get_description() -> String:
	return "获取 AnimatedSprite2D.speed_scale on " + str(target_node)

func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append("目标节点路径为空")
	if save_to_variable.is_empty():
		errors.append("保存变量名不能为空")
	return errors

func _validate_property(property: Dictionary) -> void:
	# 非 SCOPE 作用域时隐藏作用域来源属性
	if save_to_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["scope_source", "custom_scope_id", "save_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
			return

	# SCOPE 作用域下使用 VariableScopeUtils 控制属性显隐
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)

