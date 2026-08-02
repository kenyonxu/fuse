@tool
@icon("res://addons/fuse/icons/builtin/TextEdit.png")
extends BaseInstruction
class_name SetUIText

## 设置 UI 节点的文本内容
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问
## 完善变量支持: 2026-03-03 - 添加完整的 ScopeSource 支持和类型转换

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 目标 UI 节点路径
var target_node: NodePath = NodePath("")

# 是否使用变量控制文本内容
var use_variable: bool = false:
	set(value):
		use_variable = value
		notify_property_list_changed()
		_update_resource_name()

# 直接文本内容
var text: String = ""

# 文本变量名
var text_variable: String = "":
	set(value):
		text_variable = value
		_update_resource_name()

# 文本变量作用域
var text_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		text_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 作用域来源（仅当 text_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 作用域目标节点路径（TARGET_NODE 模式使用）
var scope_target_node_path: NodePath = NodePath(""):
	set(value):
		scope_target_node_path = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_UI_TEXT_NAME"
	metadata.category_key = "FUSE_CATEGORY_UI"
	metadata.description_key = "FUSE_INSTRUCTION_SET_UI_TEXT_DESC"
	metadata.keywords = ["ui", "text", "label", "content", "UI", "文本", "标签", "内容"]
	metadata.builtin_icon = "TextEdit"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# UI 分类
	properties.append({
		name = "UI",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 目标 UI 节点
	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Label,RichTextLabel",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 文本内容分类
	properties.append({
		name = "Text Content",
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

	# 直接文本内容 - 仅在不使用变量时显示
	if not use_variable:
		properties.append({
			name = "text",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_MULTILINE_TEXT,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 变量文本内容 - 仅在使用变量时显示
	if use_variable:
		properties.append({
			name = "text_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 变量作用域
		properties.append({
			name = "text_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 text_scope == SCOPE 时显示 ScopeSource 配置
		if text_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			# 根据作用域来源添加额外属性
			if scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "scope_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties

## 属性验证和显示控制
func _validate_property(property: Dictionary) -> void:
	# 根据是否使用变量控制属性显示
	if not use_variable:
		# 直接文本模式：隐藏变量相关属性
		if property.name in ["text_variable", "text_scope", "scope_source", "custom_scope_id", "scope_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 变量文本模式：隐藏直接文本属性
		if property.name == "text":
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
		if text_scope == BaseVariable.VariableScope.SCOPE:
			var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, utils_scope_source)
		else:
			# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
			if property.name in ["scope_source", "custom_scope_id", "scope_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_UI_TEXT_RESOURCE"))

	if not target_node.is_empty():
		parts.append("→ %s" % _get_node_display_name(target_node))
	else:
		parts.append("→ %s" % FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED"))

	var source_str = ""
	if use_variable:
		if not text_variable.is_empty():
			if text_scope == BaseVariable.VariableScope.SCOPE:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				source_str = "%s [%s]" % [text_variable, VariableScopeUtils.get_scope_source_string(
					utils_scope_source, custom_scope_id, scope_target_node_path
				)]
			else:
				var scope_str = VariableScopeUtils.enum_to_string(text_scope).to_upper()
				source_str = "%s [%s]" % [text_variable, scope_str]
		else:
			source_str = FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
	else:
		if not text.is_empty():
			source_str = text.substr(0, min(20, text.length()))
			if text.length() > 20:
				source_str += "..."
		else:
			source_str = FuseLocalization.translate("FUSE_TEXT_SOURCE_DIRECT")

	parts.append("(%s)" % source_str)

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取目标节点
	var node := context.get_node(target_node)
	if not node:
		_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
		finished.emit()
		return

	# 验证节点类型
	if not (node is Label or node is RichTextLabel):
		_log_error_localized("FUSE_ERROR_UI_NODE_NOT_LABEL", {})
		set_error_localized("FUSE_ERROR_UI_NODE_NOT_LABEL", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 获取文本内容
	var text_content := ""
	if use_variable:
		if text_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		# 检查变量是否存在
		if not VariableOperations.has_variable(context, text_variable, text_scope):
			_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"name": text_variable})
			set_error_localized("FUSE_ERROR_VAR_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"name": text_variable})
			finished.emit()
			return

		# 获取变量值并转换为字符串（支持 int、float、Vector2、Vector3、Color 等类型）
		text_content = _get_variable_value(context)
	else:
		text_content = text

	# 设置文本
	if node is Label:
		(node as Label).text = text_content
	elif node is RichTextLabel:
		(node as RichTextLabel).text = text_content

	_log_info_localized("FUSE_LOG_SET_UI_TEXT", {"node": node.name, "text": text_content})
	_on_execution_completed()

## 获取变量值（支持 ScopeSource 和类型转换）
func _get_variable_value(context: ExecutionContext) -> String:
	if context == null:
		_log_error_localized("FUSE_ERROR_CONTEXT_NULL", {})
		return ""

	# 根据作用域类型读取变量
	var value = null
	match text_scope:
		BaseVariable.VariableScope.LOCAL:
			value = VariableOperations.get_variable(context, text_variable, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				value = VariableOperations.get_variable(context, text_variable, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					scope_target_node_path
				)

				if scope_container == null:
					_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					return ""

				value = scope_container.get_variable(text_variable, null)

		BaseVariable.VariableScope.GLOBAL:
			value = VariableOperations.get_variable(context, text_variable, BaseVariable.VariableScope.GLOBAL, null)

	# 如果是 BaseVariable 对象，获取其值
	var actual_value: Variant = null
	if value is BaseVariable:
		actual_value = value.get_value()
	else:
		# 直接使用值（SCOPE 变量可能直接返回值）
		actual_value = value

	# 使用 TypeConverter 安全转换为字符串
	# 支持将 int、float、Vector2、Vector3、Color 等类型转换为字符串
	return TypeConverter.safe_convert_to_string(actual_value)

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if use_variable:
		if text_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_TEXT_VAR_NAME_EMPTY"))

		# 验证 SCOPE 作用域需要 ScopeVariableManager
		if text_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_FOUND"))

			# 验证 ScopeSource 参数
			var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				custom_scope_id,
				scope_target_node_path
			))

		# 非 SCOPE 作用域时检查 GlobalVariableAssistant
		if text_scope == BaseVariable.VariableScope.GLOBAL:
			var assistant = GlobalVariableAssistant.get_instance()
			if assistant == null:
				errors.append(FuseLocalization.translate("FUSE_ERROR_GLOBAL_VARIABLE_ASSISTANT_NOT_FOUND"))

	return errors

## 获取指令描述
func get_description() -> String:
	var source_str = ""
	if use_variable:
		if not text_variable.is_empty():
			if text_scope == BaseVariable.VariableScope.SCOPE:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				source_str = "%s [%s]" % [text_variable, VariableScopeUtils.get_scope_source_string(
					utils_scope_source, custom_scope_id, scope_target_node_path
				)]
			else:
				var scope_str = VariableScopeUtils.enum_to_string(text_scope).to_upper()
				source_str = "%s [%s]" % [text_variable, scope_str]
		else:
			source_str = FuseLocalization.translate("FUSE_VALUE_VARIABLE_EMPTY")
	else:
		if not text.is_empty():
			source_str = "\"%s\"" % text.substr(0, min(30, text.length()))
			if text.length() > 30:
				source_str = source_str.substr(0, source_str.length() - 1) + "...\""
		else:
			source_str = FuseLocalization.translate("FUSE_TEXT_SOURCE_DIRECT")

	var node_str = _get_node_display_name(target_node) if not target_node.is_empty() else "(%s)" % FuseLocalization.translate("FUSE_UI_NODE_NOT_SELECTED")
	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_UI_TEXT_DESC_FORMAT", {"node": node_str, "value": source_str})

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("SetUIText", log_level, message)

func _log_info(message: String):
	FuseLogger.log_info("SetUIText", log_level, message)

func _log_warning(message: String):
	FuseLogger.log_warning("SetUIText", log_level, message)

func _log_error(message: String):
	FuseLogger.log_error("SetUIText", log_level, message)