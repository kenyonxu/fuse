@tool
@icon("res://addons/bricks/icons/instruction.svg")
extends BaseInstruction

## 设置 AnimatedSprite2D.speed_scale
## 变量绑定版本 - 值支持直接输入或从变量读取
## 自动生成 - 请勿手动修改

## 目标节点路径
@export var target_node: NodePath = NodePath("")

## speed_scale 来源（VALUE=直接值 / VARIABLE=从变量读取）
enum SpeedScaleSource { VALUE, VARIABLE }
var speed_scale_source: SpeedScaleSource = SpeedScaleSource.VALUE:
	set(v):
		speed_scale_source = v
		notify_property_list_changed()

## speed_scale 直接值
var speed_scale_value: float = 0.0

## speed_scale 变量名
var speed_scale_variable: String = ""
## speed_scale 变量作用域
var speed_scale_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(v):
		speed_scale_scope = v
		notify_property_list_changed()
## speed_scale 作用域来源（仅 SCOPE 时使用）
var speed_scale_scope_source: VariableScopeUtils.ScopeSource = VariableScopeUtils.ScopeSource.NEAREST:
	set(v):
		speed_scale_scope_source = v
		notify_property_list_changed()
## speed_scale 自定义作用域 ID（CUSTOM_ID 模式使用）
var speed_scale_custom_scope_id: String = ""
## speed_scale 目标节点路径（TARGET_NODE 模式使用）
var speed_scale_target_node_path: NodePath = NodePath("")

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	properties.append({
		name = "Speed Scale",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "speed_scale_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "直接值,变量",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if speed_scale_source == SpeedScaleSource.VALUE:
		properties.append({
			name = "speed_scale_value",
			type = 3,
			hint = 0,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "speed_scale_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "speed_scale_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if speed_scale_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "speed_scale_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if speed_scale_scope_source == VariableScopeUtils.ScopeSource.CUSTOM_ID:
				properties.append({
					name = "speed_scale_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif speed_scale_scope_source == VariableScopeUtils.ScopeSource.TARGET_NODE:
				properties.append({
					name = "speed_scale_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties

static func _get_instruction_metadata() -> InstructionMetadata:
	var md = InstructionMetadata.new()
	md.name = "设置 AnimatedSprite2D.speed_scale (变量)"
	md.category = "用户生成"
	md.description = "设置 AnimatedSprite2D 节点的 speed_scale 属性 (变量)"
	md.keywords = ["animatedsprite2d", "speed_scale", "set"]
	return md

func _setup_metadata():
	pass

func _update_resource_name():
	resource_name = "SetAnimatedSprite2DSpeedScale_WithVariable"

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

	# 从变量读取值
	var speed_scale_val: float = speed_scale_value
	if speed_scale_source == SpeedScaleSource.VARIABLE and not speed_scale_variable.is_empty():
		if speed_scale_scope == BaseVariable.VariableScope.SCOPE:
			if speed_scale_scope_source == VariableScopeUtils.ScopeSource.NEAREST:
				speed_scale_val = VariableOperations.get_variable(context, speed_scale_variable, BaseVariable.VariableScope.SCOPE, speed_scale_val)
			else:
				var scope_container = VariableScopeUtils.get_scope_container_by_source(context, speed_scale_scope_source as VariableScopeUtils.ScopeSource, speed_scale_custom_scope_id, speed_scale_target_node_path)
				if scope_container == null:
					set_error("找不到参数 speed_scale 的作用域容器")
					finished.emit()
					return
				speed_scale_val = scope_container.get_variable(speed_scale_variable, speed_scale_val)
		else:
			speed_scale_val = VariableOperations.get_variable(context, speed_scale_variable, speed_scale_scope, speed_scale_val)

	node.speed_scale = speed_scale_val

	_on_execution_completed()

func get_description() -> String:
	return "设置 AnimatedSprite2D.speed_scale on " + str(target_node)

func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append("目标节点路径为空")
	return errors

func _validate_property(property: Dictionary) -> void:
	if speed_scale_source != SpeedScaleSource.VARIABLE:
		if property.name in ["speed_scale_variable", "speed_scale_scope", "speed_scale_scope_source", "speed_scale_custom_scope_id", "speed_scale_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
			return
	if speed_scale_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["speed_scale_scope_source", "speed_scale_custom_scope_id", "speed_scale_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
			return
	if speed_scale_scope == BaseVariable.VariableScope.SCOPE and speed_scale_source == SpeedScaleSource.VARIABLE:
		VariableScopeUtils.validate_scope_source_property(property, speed_scale_scope_source as VariableScopeUtils.ScopeSource)

