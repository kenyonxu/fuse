@tool
@icon("res://addons/fuse/icons/builtin/CameraTexture.png")
extends BaseInstruction
class_name SetCameraZoom

## 设置 Camera2D 的缩放级别
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

# 目标 Camera2D 节点路径
var target_node: NodePath = NodePath("")

# 缩放级别来源
enum ZoomSource {
	DIRECT,
	VARIABLE
}
var zoom_source: ZoomSource = ZoomSource.DIRECT

# 直接缩放级别
var zoom: float = 1.0

# 缩放级别变量名
var zoom_variable: String = ""

# 缩放变量作用域
var zoom_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		zoom_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 作用域来源枚举（仅当 zoom_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 作用域来源（仅当 zoom_scope == SCOPE 时使用）
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
		notify_property_list_changed()

## 作用域目标节点路径（TARGET_NODE 模式使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()
		notify_property_list_changed()

# 缩放模式
enum ZoomMode {
	BOTH,
	HORIZONTAL,
	VERTICAL
}
var zoom_mode: ZoomMode = ZoomMode.BOTH

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_SET_CAMERA_ZOOM_NAME"
	metadata.category_key = "FUSE_CATEGORY_CAMERA"
	metadata.description_key = "FUSE_INSTRUCTION_SET_CAMERA_ZOOM_DESC"
	metadata.keywords = ["camera", "zoom", "scale", "Camera2D", "相机", "缩放", "镜头"]
	metadata.builtin_icon = "CameraTexture"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Camera",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
		hint_string = "Camera2D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "Zoom",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "zoom_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if zoom_source == ZoomSource.DIRECT:
		properties.append({
			name = "zoom",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0.1,10,0.1,or_greater",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "zoom_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
		properties.append({
			name = "zoom_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 仅在 SCOPE 作用域时显示 ScopeSource
		if zoom_scope == BaseVariable.VariableScope.SCOPE:
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
					name = "target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
					hint_string = "",
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	properties.append({
		name = "Mode",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "zoom_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Both,Horizontal,Vertical",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	if zoom_scope != BaseVariable.VariableScope.SCOPE:
		return VariableScopeUtils.enum_to_string(zoom_scope).to_upper()

	match scope_source:
		ScopeSource.NEAREST:
			return FuseLocalization.translate("FUSE_SCOPE_SOURCE_NEAREST_STR")

		ScopeSource.CUSTOM_ID:
			if custom_scope_id.is_empty():
				return FuseLocalization.translate("FUSE_SCOPE_SOURCE_CUSTOM_ID_EMPTY")
			return FuseLocalization.translate_format("FUSE_SCOPE_SOURCE_CUSTOM_ID_STR", {"id": custom_scope_id})

		ScopeSource.TRIGGER_SCOPE:
			return FuseLocalization.translate("FUSE_SCOPE_SOURCE_TRIGGER_SCOPE_STR")

		ScopeSource.TARGET_NODE:
			if target_node_path.is_empty():
				return FuseLocalization.translate("FUSE_SCOPE_SOURCE_TARGET_NODE_EMPTY")
			return FuseLocalization.translate_format("FUSE_SCOPE_SOURCE_TARGET_NODE_STR", {"node": str(target_node_path)})

		_:
			return VariableScopeUtils.enum_to_string(zoom_scope).to_upper()

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_SET_CAMERA_ZOOM_BASE_NAME"))

	if not target_node.is_empty():
		parts.append(FuseLocalization.translate_format("FUSE_CAMERA_ZOOM_TARGET", {"target": _get_node_display_name(target_node)}))
	else:
		parts.append(FuseLocalization.translate("FUSE_CAMERA_ZOOM_NO_TARGET"))

	var zoom_str = ""
	if zoom_source == ZoomSource.DIRECT:
		zoom_str = FuseLocalization.translate_format("FUSE_CAMERA_ZOOM_VALUE", {"value": "%.2f" % zoom})
	else:
		var scope_str = _get_scope_source_string()
		if not zoom_variable.is_empty():
			zoom_str = "%s [%s]" % [zoom_variable, scope_str]
		else:
			zoom_str = "[%s]" % scope_str
	parts.append("(%s)" % zoom_str)

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
	if not node is Camera2D:
		_log_error_localized("FUSE_ERROR_NOT_CAMERA2D", {})
		set_error_localized("FUSE_ERROR_NOT_CAMERA2D", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	var camera := node as Camera2D

	# 获取缩放级别
	var zoom_value := 1.0
	if zoom_source == ZoomSource.DIRECT:
		zoom_value = zoom
		if zoom_value <= 0:
			_log_error_localized("FUSE_ERROR_ZOOM_MUST_BE_POSITIVE", {})
			set_error_localized("FUSE_ERROR_ZOOM_MUST_BE_POSITIVE", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
	else:
		if zoom_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		# 根据作用域来源获取变量值
		if zoom_scope == BaseVariable.VariableScope.SCOPE:
			match scope_source:
				ScopeSource.NEAREST:
					zoom_value = float(VariableOperations.get_variable(context, zoom_variable, BaseVariable.VariableScope.SCOPE, null))
				_:
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

					zoom_value = float(scope_container.get_variable(zoom_variable, null))
		else:
			zoom_value = float(VariableOperations.get_variable(context, zoom_variable, zoom_scope, null))
		if zoom_value <= 0:
			_log_error_localized("FUSE_ERROR_ZOOM_MUST_BE_POSITIVE", {})
			set_error_localized("FUSE_ERROR_ZOOM_MUST_BE_POSITIVE", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

	# 设置缩放
	match zoom_mode:
		ZoomMode.BOTH:
			camera.zoom = Vector2(zoom_value, zoom_value)
		ZoomMode.HORIZONTAL:
			camera.zoom.x = zoom_value
		ZoomMode.VERTICAL:
			camera.zoom.y = zoom_value

	_log_info_localized("FUSE_LOG_SET_CAMERA_ZOOM", {"node": camera.name, "zoom": str(zoom_value)})
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	if zoom_source == ZoomSource.DIRECT:
		if zoom <= 0:
			errors.append(FuseLocalization.translate("FUSE_ERROR_ZOOM_MUST_BE_POSITIVE"))
	else:
		if zoom_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_ZOOM_VAR_NAME_EMPTY"))

		# 验证 SCOPE 作用域需要 ScopeVariableManager
		if zoom_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null or not manager.is_available():
				errors.append(FuseLocalization.translate("FUSE_ERROR_SCOPE_MANAGER_NOT_AVAILABLE"))

			# 验证 ScopeSource 参数
			var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				custom_scope_id,
				target_node_path
			))

	return errors

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 只在 zoom_source == VARIABLE 时显示变量相关属性
	if zoom_source == ZoomSource.DIRECT:
		if property.name in ["zoom_variable", "zoom_scope", "scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 只在 zoom_scope == SCOPE 时显示 ScopeSource 相关属性
		if zoom_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
		else:
			# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
			if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

## 获取指令描述
func get_description() -> String:
	var mode_key = ""
	match zoom_mode:
		ZoomMode.BOTH:
			mode_key = "FUSE_CAMERA_ZOOM_MODE_BOTH"
		ZoomMode.HORIZONTAL:
			mode_key = "FUSE_CAMERA_ZOOM_MODE_HORIZONTAL"
		ZoomMode.VERTICAL:
			mode_key = "FUSE_CAMERA_ZOOM_MODE_VERTICAL"

	var mode_str = FuseLocalization.translate(mode_key)

	var source_str = ""
	if zoom_source == ZoomSource.DIRECT:
		source_str = FuseLocalization.translate_format("FUSE_CAMERA_ZOOM_VALUE", {"value": "%.2f" % zoom})
	else:
		var scope_str = _get_scope_source_string()
		if not zoom_variable.is_empty():
			source_str = "%s [%s]" % [zoom_variable, scope_str]
		else:
			source_str = "[%s]" % scope_str

	var target_str = _get_node_display_name(target_node) if not target_node.is_empty() else FuseLocalization.translate("FUSE_CAMERA_TARGET_NOT_SELECTED")

	return FuseLocalization.translate_format("FUSE_INSTRUCTION_SET_CAMERA_ZOOM_DESC_FORMAT", {
		"target": target_str,
		"mode": mode_str,
		"value": source_str
	})

## 动态属性设置
func _set(property: StringName, value_: Variant) -> bool:
	if property == "zoom_source":
		set(property, value_)
		notify_property_list_changed()
		_update_resource_name()
		return true
	if property == "zoom_scope":
		set(property, value_)
		notify_property_list_changed()
		_update_resource_name()
		return true
	if property == "scope_source":
		set(property, value_)
		notify_property_list_changed()
		_update_resource_name()
		return true
	if property == "custom_scope_id":
		set(property, value_)
		notify_property_list_changed()
		_update_resource_name()
		return true
	if property == "target_node_path":
		set(property, value_)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false
