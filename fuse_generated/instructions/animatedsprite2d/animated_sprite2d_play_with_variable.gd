@tool
@icon("res://addons/bricks/icons/instruction.svg")
extends BaseInstruction

## 调用 AnimatedSprite2D.play 方法
## 变量绑定版本 - 每个参数支持直接值或变量读取
## 自动生成 - 请勿手动修改

## 目标节点路径
@export var target_node: NodePath = NodePath("")

## name 来源（VALUE=直接值 / VARIABLE=从变量读取）
enum NameSource { VALUE, VARIABLE }
var name_source: NameSource = NameSource.VALUE:
	set(v):
		name_source = v
		notify_property_list_changed()

## name 直接值
var name_value: StringName = &""

## name 变量名
var name_variable: String = ""
## name 变量作用域
var name_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(v):
		name_scope = v
		notify_property_list_changed()
## name 作用域来源（仅 SCOPE 时使用）
var name_scope_source: VariableScopeUtils.ScopeSource = VariableScopeUtils.ScopeSource.NEAREST:
	set(v):
		name_scope_source = v
		notify_property_list_changed()
## name 自定义作用域 ID（CUSTOM_ID 模式使用）
var name_custom_scope_id: String = ""
## name 目标节点路径（TARGET_NODE 模式使用）
var name_target_node_path: NodePath = NodePath("")

## custom_speed 来源（VALUE=直接值 / VARIABLE=从变量读取）
enum CustomSpeedSource { VALUE, VARIABLE }
var custom_speed_source: CustomSpeedSource = CustomSpeedSource.VALUE:
	set(v):
		custom_speed_source = v
		notify_property_list_changed()

## custom_speed 直接值
var custom_speed_value: float = 0.0

## custom_speed 变量名
var custom_speed_variable: String = ""
## custom_speed 变量作用域
var custom_speed_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(v):
		custom_speed_scope = v
		notify_property_list_changed()
## custom_speed 作用域来源（仅 SCOPE 时使用）
var custom_speed_scope_source: VariableScopeUtils.ScopeSource = VariableScopeUtils.ScopeSource.NEAREST:
	set(v):
		custom_speed_scope_source = v
		notify_property_list_changed()
## custom_speed 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_speed_custom_scope_id: String = ""
## custom_speed 目标节点路径（TARGET_NODE 模式使用）
var custom_speed_target_node_path: NodePath = NodePath("")

## from_end 来源（VALUE=直接值 / VARIABLE=从变量读取）
enum FromEndSource { VALUE, VARIABLE }
var from_end_source: FromEndSource = FromEndSource.VALUE:
	set(v):
		from_end_source = v
		notify_property_list_changed()

## from_end 直接值
var from_end_value: bool = false

## from_end 变量名
var from_end_variable: String = ""
## from_end 变量作用域
var from_end_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(v):
		from_end_scope = v
		notify_property_list_changed()
## from_end 作用域来源（仅 SCOPE 时使用）
var from_end_scope_source: VariableScopeUtils.ScopeSource = VariableScopeUtils.ScopeSource.NEAREST:
	set(v):
		from_end_scope_source = v
		notify_property_list_changed()
## from_end 自定义作用域 ID（CUSTOM_ID 模式使用）
var from_end_custom_scope_id: String = ""
## from_end 目标节点路径（TARGET_NODE 模式使用）
var from_end_target_node_path: NodePath = NodePath("")

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []

	properties.append({
		name = "Name",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "name_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "直接值,变量",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if name_source == NameSource.VALUE:
		properties.append({
			name = "name_value",
			type = 4,
			hint = 0,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "name_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "name_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if name_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "name_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if name_scope_source == VariableScopeUtils.ScopeSource.CUSTOM_ID:
				properties.append({
					name = "name_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif name_scope_source == VariableScopeUtils.ScopeSource.TARGET_NODE:
				properties.append({
					name = "name_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	properties.append({
		name = "Custom Speed",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "custom_speed_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "直接值,变量",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if custom_speed_source == CustomSpeedSource.VALUE:
		properties.append({
			name = "custom_speed_value",
			type = 3,
			hint = 0,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "custom_speed_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "custom_speed_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if custom_speed_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "custom_speed_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if custom_speed_scope_source == VariableScopeUtils.ScopeSource.CUSTOM_ID:
				properties.append({
					name = "custom_speed_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif custom_speed_scope_source == VariableScopeUtils.ScopeSource.TARGET_NODE:
				properties.append({
					name = "custom_speed_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	properties.append({
		name = "From End",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "from_end_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "直接值,变量",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if from_end_source == FromEndSource.VALUE:
		properties.append({
			name = "from_end_value",
			type = 1,
			hint = 0,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "from_end_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "from_end_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if from_end_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "from_end_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if from_end_scope_source == VariableScopeUtils.ScopeSource.CUSTOM_ID:
				properties.append({
					name = "from_end_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif from_end_scope_source == VariableScopeUtils.ScopeSource.TARGET_NODE:
				properties.append({
					name = "from_end_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties

static func _get_instruction_metadata() -> InstructionMetadata:
	var md = InstructionMetadata.new()
	md.name = "调用 AnimatedSprite2D.play (变量)"
	md.category = "用户生成"
	md.description = "调用 AnimatedSprite2D 节点的 play 方法 (变量)"
	md.keywords = ["animatedsprite2d", "play", "call"]
	return md

func _setup_metadata():
	pass

func _update_resource_name():
	resource_name = "CallAnimatedSprite2DPlay_WithVariable"

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

	# 从变量读取参数值
	var name_val: StringName = name_value
	if name_source == NameSource.VARIABLE and not name_variable.is_empty():
		if name_scope == BaseVariable.VariableScope.SCOPE:
			if name_scope_source == VariableScopeUtils.ScopeSource.NEAREST:
				name_val = VariableOperations.get_variable(context, name_variable, BaseVariable.VariableScope.SCOPE, name_val)
			else:
				var scope_container = VariableScopeUtils.get_scope_container_by_source(context, name_scope_source as VariableScopeUtils.ScopeSource, name_custom_scope_id, name_target_node_path)
				if scope_container == null:
					set_error("找不到参数 name 的作用域容器")
					finished.emit()
					return
				name_val = scope_container.get_variable(name_variable, name_val)
		else:
			name_val = VariableOperations.get_variable(context, name_variable, name_scope, name_val)

	var custom_speed_val: float = custom_speed_value
	if custom_speed_source == CustomSpeedSource.VARIABLE and not custom_speed_variable.is_empty():
		if custom_speed_scope == BaseVariable.VariableScope.SCOPE:
			if custom_speed_scope_source == VariableScopeUtils.ScopeSource.NEAREST:
				custom_speed_val = VariableOperations.get_variable(context, custom_speed_variable, BaseVariable.VariableScope.SCOPE, custom_speed_val)
			else:
				var scope_container = VariableScopeUtils.get_scope_container_by_source(context, custom_speed_scope_source as VariableScopeUtils.ScopeSource, custom_speed_custom_scope_id, custom_speed_target_node_path)
				if scope_container == null:
					set_error("找不到参数 custom_speed 的作用域容器")
					finished.emit()
					return
				custom_speed_val = scope_container.get_variable(custom_speed_variable, custom_speed_val)
		else:
			custom_speed_val = VariableOperations.get_variable(context, custom_speed_variable, custom_speed_scope, custom_speed_val)

	var from_end_val: bool = from_end_value
	if from_end_source == FromEndSource.VARIABLE and not from_end_variable.is_empty():
		if from_end_scope == BaseVariable.VariableScope.SCOPE:
			if from_end_scope_source == VariableScopeUtils.ScopeSource.NEAREST:
				from_end_val = VariableOperations.get_variable(context, from_end_variable, BaseVariable.VariableScope.SCOPE, from_end_val)
			else:
				var scope_container = VariableScopeUtils.get_scope_container_by_source(context, from_end_scope_source as VariableScopeUtils.ScopeSource, from_end_custom_scope_id, from_end_target_node_path)
				if scope_container == null:
					set_error("找不到参数 from_end 的作用域容器")
					finished.emit()
					return
				from_end_val = scope_container.get_variable(from_end_variable, from_end_val)
		else:
			from_end_val = VariableOperations.get_variable(context, from_end_variable, from_end_scope, from_end_val)


	# 调用方法
	node.play(name_val, custom_speed_val, from_end_val)

	_on_execution_completed()

func get_description() -> String:
	return "调用 AnimatedSprite2D.play on " + str(target_node)

func validate() -> Array[String]:
	var errors = super.validate()
	if target_node.is_empty():
		errors.append("目标节点路径为空")
	return errors

func _validate_property(property: Dictionary) -> void:
	if name_source != NameSource.VARIABLE:
		if property.name in ["name_variable", "name_scope", "name_scope_source", "name_custom_scope_id", "name_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
			return
	if name_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["name_scope_source", "name_custom_scope_id", "name_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
			return
	if name_scope == BaseVariable.VariableScope.SCOPE and name_source == NameSource.VARIABLE:
		VariableScopeUtils.validate_scope_source_property(property, name_scope_source as VariableScopeUtils.ScopeSource)

	if custom_speed_source != CustomSpeedSource.VARIABLE:
		if property.name in ["custom_speed_variable", "custom_speed_scope", "custom_speed_scope_source", "custom_speed_custom_scope_id", "custom_speed_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
			return
	if custom_speed_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["custom_speed_scope_source", "custom_speed_custom_scope_id", "custom_speed_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
			return
	if custom_speed_scope == BaseVariable.VariableScope.SCOPE and custom_speed_source == CustomSpeedSource.VARIABLE:
		VariableScopeUtils.validate_scope_source_property(property, custom_speed_scope_source as VariableScopeUtils.ScopeSource)

	if from_end_source != FromEndSource.VARIABLE:
		if property.name in ["from_end_variable", "from_end_scope", "from_end_scope_source", "from_end_custom_scope_id", "from_end_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
			return
	if from_end_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["from_end_scope_source", "from_end_custom_scope_id", "from_end_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
			return
	if from_end_scope == BaseVariable.VariableScope.SCOPE and from_end_source == FromEndSource.VARIABLE:
		VariableScopeUtils.validate_scope_source_property(property, from_end_scope_source as VariableScopeUtils.ScopeSource)

