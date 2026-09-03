@tool
@icon("res://addons/fuse/icons/builtin/Blend.png")
extends BaseInstruction
class_name BlendAnimation

## 混合 AnimationTree 的动画轨道
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问
## 重构 ScopeSource: 2026-02-10 - 添加 ScopeSource 支持

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 目标 AnimationTree 节点路径
var target_tree: NodePath = NodePath("")

## 是否从变量获取AnimationTree
var use_variable_for_target: bool = false:
	set(value):
		use_variable_for_target = value
		_update_resource_name()
		notify_property_list_changed()

## AnimationTree变量名
var target_variable: String = "":
	set(value):
		target_variable = value
		_update_resource_name()

## AnimationTree变量作用域
var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_scope = value
		_update_resource_name()
		notify_property_list_changed()

## AnimationTree作用域来源（仅当 target_scope == SCOPE 时使用）
var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## AnimationTree自定义作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		target_custom_scope_id = value
		_update_resource_name()

## AnimationTree目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		target_target_node_path = value
		_update_resource_name()

# 混合路径（如 "parameters/blend_position"）
var blend_path: String = ""

# 混合量（0.0 - 1.0）
var blend_amount: float = 0.5

# 是否使用变量控制混合量
var use_variable: bool = false

# 混合量变量名
var blend_variable: String = ""

# 混合变量作用域
var blend_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if blend_scope != value:
			blend_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 作用域来源（仅当 blend_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if scope_source != value:
			scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = "":
	set(value):
		if custom_scope_id != value:
			custom_scope_id = value
			_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		if target_node_path != value:
			target_node_path = value
			_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_BLEND_ANIMATION_NAME"
	metadata.category_key = "FUSE_CATEGORY_ANIMATION"
	metadata.description_key = "FUSE_INSTRUCTION_BLEND_ANIMATION_DESC"
	metadata.keywords = ["animation", "blend", "mix", "tree", "混合", "动画"]
	metadata.builtin_icon = "Blend"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 声明变量读写模式
func get_variable_modes() -> Array[Dictionary]:
	var modes: Array[Dictionary] = []
	if use_variable_for_target:
		modes.append({"name": "target_variable", "mode": "read"})
	return modes


## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# AnimationTree 分类
	properties.append({
		name = "AnimationTree",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标 AnimationTree

	# 是否从变量获取AnimationTree
	properties.append({
		name = "use_variable_for_target",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if not use_variable_for_target:
		# 直接指定节点路径
		properties.append({
			name = "target_tree",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
			hint_string = "AnimationTree",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		# 从变量获取节点
		properties.append({
			name = "target_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "target_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if target_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "target_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if target_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "target_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif target_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "target_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# 混合路径
	properties.append({
		name = "blend_path",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Blend Amount 分类
	properties.append({
		name = "Blend Amount",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否使用变量
	properties.append({
		name = "use_variable",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 混合量（直接值）
	if not use_variable:
		properties.append({
			name = "blend_amount",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.0,1.0,0.01",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 混合量变量
	if use_variable:
		properties.append({
			name = "blend_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 混合变量作用域
		properties.append({
			name = "blend_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 blend_scope == SCOPE 时显示 ScopeSource 配置
		if blend_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "Scope Configuration",
				type = TYPE_NIL,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_CATEGORY
			})

			properties.append({
				name = "scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_BLEND_ANIMATION_SHORT"))

	if not target_tree.is_empty():
		parts.append("'%s'" % target_tree)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_BLEND_ANIMATION_NO_TREE"))

	if not blend_path.is_empty():
		parts.append("'%s'" % blend_path)
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_BLEND_ANIMATION_NO_PATH"))

	if use_variable:
		if not blend_variable.is_empty():
			var scope_str = _get_scope_source_string()
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_BLEND_ANIMATION_WITH_VAR", {"var": "%s[%s]" % [blend_variable, scope_str]}))
		else:
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_BLEND_ANIMATION_VAR_NOT_SET"))
	else:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_BLEND_ANIMATION_WITH_VALUE", {"value": blend_amount}))

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证目标节点

	# 获取 AnimationTree 节点
	var node := _resolve_node(
		context,
		use_variable_for_target,
		target_tree,
		target_variable,
		target_scope,
		target_scope_source,
		target_custom_scope_id,
		target_target_node_path,
		"FUSE_ERROR_TARGET_VARIABLE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_EMPTY",
		"FUSE_ERROR_TARGET_NODE_NOT_FOUND"
	)
	if not node:
		finished.emit()
		return

	# 验证节点类型
	if not node is AnimationTree:
		var type_str = node.get_class()
		_log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": node.name, "actual_type": type_str})
		set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"node": node.name, "actual_type": type_str})
		finished.emit()
		return

	var animation_tree := node as AnimationTree

	# 验证混合路径
	if blend_path.is_empty():
		_log_error_localized("FUSE_ERROR_BLEND_PATH_EMPTY", {})
		set_error_localized("FUSE_ERROR_BLEND_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取混合量
	var amount: float
	if use_variable:
		if blend_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		# 根据作用域类型获取变量值
		match blend_scope:
			BaseVariable.VariableScope.LOCAL:
				var var_value = VariableOperations.get_variable(context, blend_variable, BaseVariable.VariableScope.LOCAL, null)
				if var_value == null and not VariableOperations.has_variable(context, blend_variable, BaseVariable.VariableScope.LOCAL):
					_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": blend_variable})
					set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": blend_variable})
					finished.emit()
					return

				# 类型转换
				if var_value is float or var_value is int:
					amount = float(var_value)
				else:
					_log_error_localized("FUSE_ERROR_VAR_TYPE_MISMATCH", {
						"variable": blend_variable,
						"expected": "float",
						"actual": typeof(var_value)
					})
					set_error_localized("FUSE_ERROR_VAR_TYPE_MISMATCH", FuseError.ErrorType.RUNTIME_ERROR, {
						"variable": blend_variable,
						"expected": "float",
						"actual": typeof(var_value)
					})
					finished.emit()
					return

			BaseVariable.VariableScope.SCOPE:
				# 根据源 ScopeSource 获取变量值
				if scope_source == ScopeSource.NEAREST:
					# NEAREST 模式：使用 VariableOperations
					var var_value = VariableOperations.get_variable(context, blend_variable, BaseVariable.VariableScope.SCOPE, null)
					if var_value == null and not VariableOperations.has_variable(context, blend_variable, BaseVariable.VariableScope.SCOPE):
						_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": blend_variable})
						set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": blend_variable})
						finished.emit()
						return

					# 类型转换
					if var_value is float or var_value is int:
						amount = float(var_value)
					else:
						_log_error_localized("FUSE_ERROR_VAR_TYPE_MISMATCH", {
							"variable": blend_variable,
							"expected": "float",
							"actual": typeof(var_value)
						})
						set_error_localized("FUSE_ERROR_VAR_TYPE_MISMATCH", FuseError.ErrorType.RUNTIME_ERROR, {
							"variable": blend_variable,
							"expected": "float",
							"actual": typeof(var_value)
						})
						finished.emit()
						return
				else:
					# 其他模式：获取指定作用域容器并读取变量
					var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						custom_scope_id,
						target_node_path
					)

					if scope_container == null:
						_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
						set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
						finished.emit()
						return

					# 检查变量是否存在
					if not scope_container.has_variable(blend_variable):
						_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": blend_variable})
						set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": blend_variable})
						finished.emit()
						return

					var var_value = scope_container.get_variable(blend_variable)

					# 类型转换
					if var_value is float or var_value is int:
						amount = float(var_value)
					else:
						_log_error_localized("FUSE_ERROR_VAR_TYPE_MISMATCH", {
							"variable": blend_variable,
							"expected": "float",
							"actual": typeof(var_value)
						})
						set_error_localized("FUSE_ERROR_VAR_TYPE_MISMATCH", FuseError.ErrorType.RUNTIME_ERROR, {
							"variable": blend_variable,
							"expected": "float",
							"actual": typeof(var_value)
						})
						finished.emit()
						return

			BaseVariable.VariableScope.GLOBAL:
				var var_value = VariableOperations.get_variable(context, blend_variable, BaseVariable.VariableScope.GLOBAL, null)
				if var_value == null and not VariableOperations.has_variable(context, blend_variable, BaseVariable.VariableScope.GLOBAL):
					_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": blend_variable})
					set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": blend_variable})
					finished.emit()
					return

				# 类型转换
				if var_value is float or var_value is int:
					amount = float(var_value)
				else:
					_log_error_localized("FUSE_ERROR_VAR_TYPE_MISMATCH", {
						"variable": blend_variable,
						"expected": "float",
						"actual": typeof(var_value)
					})
					set_error_localized("FUSE_ERROR_VAR_TYPE_MISMATCH", FuseError.ErrorType.RUNTIME_ERROR, {
						"variable": blend_variable,
						"expected": "float",
						"actual": typeof(var_value)
					})
					finished.emit()
					return
	else:
		amount = blend_amount

	# 限制混合量在 0-1 范围
	amount = clamp(amount, 0.0, 1.0)

	# 设置混合值
	animation_tree.set(blend_path, amount)

	_log_info_localized("FUSE_LOG_BLEND_ANIMATION_SET", {
		"path": blend_path,
		"amount": amount
	})

	_on_execution_completed()

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()
	# 验证 AnimationTree
	if use_variable_for_target:
		if target_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VARIABLE_EMPTY"))
		if target_scope == BaseVariable.VariableScope.SCOPE:
			var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				target_utils_scope_source,
				target_custom_scope_id,
				target_target_node_path
			))
	else:
		if target_tree.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))


	if blend_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_BLEND_PATH_EMPTY"))

	if use_variable and blend_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

	# 验证作用域 (SCOPE)
	if use_variable and blend_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			target_node_path
		))

	return errors

## 获取描述
func get_description() -> String:
	var amount_str = ""
	if use_variable:
		if not blend_variable.is_empty():
			var scope_str = _get_scope_source_string()
			amount_str = FuseLocalization.translate_format("FUSE_INSTRUCTION_BLEND_ANIMATION_VAR", {"var": "%s[%s]" % [blend_variable, scope_str]})
		else:
			amount_str = FuseLocalization.translate("FUSE_INSTRUCTION_BLEND_ANIMATION_VAR_NOT_SET")
	else:
		amount_str = str(blend_amount)

	var path_str = blend_path if not blend_path.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_BLEND_ANIMATION_NO_PATH")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_BLEND_ANIMATION_DESC_FORMAT", {"path": path_str, "amount": amount_str})

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match blend_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 只在使用变量时验证 ScopeSource 相关属性
	if use_variable:
		# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
		if blend_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
		else:
			# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
			if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 不使用变量时隐藏所有 ScopeSource 属性
		if property.name in ["blend_variable", "blend_scope", "scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	# 控制AnimationTree相关属性可见性
	if not use_variable_for_target:
		if property.name in ["target_variable", "target_scope", "target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "target_tree":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		if target_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, target_utils_scope_source)

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["use_variable_for_target", "target_scope", "target_scope_source"]:
		set(property, value)
		notify_property_list_changed()
		return true
	if property == "use_variable":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false

## 从变量或节点路径解析节点
func _resolve_node(
	context: ExecutionContext,
	use_variable: bool,
	node_path: NodePath,
	variable_name: String,
	variable_scope: BaseVariable.VariableScope,
	scope_source: ScopeSource,
	custom_scope_id: String,
	target_node_path: NodePath,
	empty_variable_error_key: String,
	empty_node_error_key: String,
	not_found_error_key: String
) -> Node:
	if use_variable:
		if variable_name.is_empty():
			_log_error_localized(empty_variable_error_key, {})
			set_error_localized(empty_variable_error_key, FuseError.ErrorType.VALIDATION_ERROR, {})
			return null

		var node_value = VariableOperations.get_variable(
			context,
			variable_name,
			variable_scope,
			null
		)

		if node_value == null and not VariableOperations.has_variable(context, variable_name, variable_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": variable_name})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.VALIDATION_ERROR, {"name": variable_name})
			return null

		# 支持多种类型：Node、String（节点路径）、NodePath
		if node_value is Node:
			return node_value
		elif node_value is String or node_value is NodePath:
			var resolved_path = NodePath(node_value)
			var resolved_node = context.get_node(resolved_path)
			if not resolved_node:
				_log_error_localized(not_found_error_key, {"node": str(node_value)})
				set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"node": str(node_value)})
				return null
			return resolved_node
		else:
			_log_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", {"variable": variable_name, "actual_type": type_string(typeof(node_value))})
			set_error_localized("FUSE_ERROR_VAR_TYPE_NOT_NODE_OR_PATH", FuseError.ErrorType.VALIDATION_ERROR, {"variable": variable_name, "actual_type": type_string(typeof(node_value))})
			return null
	else:
		if node_path.is_empty():
			_log_error_localized(empty_node_error_key, {})
			set_error_localized(empty_node_error_key, FuseError.ErrorType.VALIDATION_ERROR, {})
			return null

		var resolved_node = context.get_node(node_path)
		if not resolved_node:
			_log_error_localized(not_found_error_key, {"node": str(node_path)})
			set_error_localized(not_found_error_key, FuseError.ErrorType.RUNTIME_ERROR, {"node": str(node_path)})
			return null
		return resolved_node

