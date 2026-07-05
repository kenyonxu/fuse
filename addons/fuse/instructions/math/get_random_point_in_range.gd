@tool
@icon("res://addons/fuse/icons/builtin/Vector3i.svg")
extends BaseInstruction
class_name GetRandomPointInRange

## 从指定起点范围内获取随机点
##
## 功能说明：
## - 支持手动设置起点/范围或从三重作用域变量获取
## - 支持 2D 和 3D 模式
## - 3D 模式支持不同平面（XY/XZ/YZ）或完整 3D 空间
## - 结果保存到三重作用域变量

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 维度模式
enum DimensionMode {
	MODE_2D,  ## 2D 模式
	MODE_3D   ## 3D 模式
}

## 3D 平面类型
enum Plane3D {
	XY,      ## XY 平面（Z 轴不变）
	XZ,      ## XZ 平面（Y 轴不变）
	YZ,      ## YZ 平面（X 轴不变）
	FULL_3D  ## 完整 3D 空间
}

## 起点模式
enum OriginMode {
	DIRECT,   ## 直接设置
	VARIABLE  ## 从变量获取
}

## 范围模式
enum RangeMode {
	DIRECT,   ## 直接设置
	VARIABLE  ## 从变量获取
}

# =============================================
# 维度配置
# =============================================

var dimension_mode: DimensionMode = DimensionMode.MODE_2D:
	set(value):
		dimension_mode = value
		_update_resource_name()
		notify_property_list_changed()

## 3D 平面类型（仅 MODE_3D 使用）
var plane_3d: Plane3D = Plane3D.XY:
	set(value):
		plane_3d = value
		_update_resource_name()

# =============================================
# 起点配置
# =============================================

var origin_mode: OriginMode = OriginMode.DIRECT:
	set(value):
		origin_mode = value
		_update_resource_name()
		notify_property_list_changed()

## 直接设置起点（2D/3D 根据模式显示）
var origin_direct_2d: Vector2 = Vector2.ZERO:
	set(value):
		origin_direct_2d = value
		_update_resource_name()

var origin_direct_3d: Vector3 = Vector3.ZERO:
	set(value):
		origin_direct_3d = value
		_update_resource_name()

## 变量模式起点
var origin_variable: String = "":
	set(value):
		origin_variable = value
		_update_resource_name()

var origin_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		origin_scope = value
		_update_resource_name()
		notify_property_list_changed()

var origin_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		origin_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

var origin_custom_scope_id: String = "":
	set(value):
		origin_custom_scope_id = value
		_update_resource_name()

var origin_target_node_path: NodePath = NodePath(""):
	set(value):
		origin_target_node_path = value
		_update_resource_name()

# =============================================
# 范围配置
# =============================================

var range_mode: RangeMode = RangeMode.DIRECT:
	set(value):
		range_mode = value
		_update_resource_name()
		notify_property_list_changed()

## 直接设置范围（2D/3D 根据模式显示）
var range_direct_2d: Vector2 = Vector2(100.0, 100.0):
	set(value):
		range_direct_2d = value
		_update_resource_name()

var range_direct_3d: Vector3 = Vector3(100.0, 100.0, 100.0):
	set(value):
		range_direct_3d = value
		_update_resource_name()

## 变量模式范围
var range_variable: String = "":
	set(value):
		range_variable = value
		_update_resource_name()

var range_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		range_scope = value
		_update_resource_name()
		notify_property_list_changed()

var range_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		range_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

var range_custom_scope_id: String = "":
	set(value):
		range_custom_scope_id = value
		_update_resource_name()

var range_target_node_path: NodePath = NodePath(""):
	set(value):
		range_target_node_path = value
		_update_resource_name()

# =============================================
# 结果保存配置
# =============================================

var save_to_variable: String = "random_point":
	set(value):
		save_to_variable = value
		_update_resource_name()

var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		save_to_scope = value
		_update_resource_name()
		notify_property_list_changed()

var save_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		save_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

var save_custom_scope_id: String = "":
	set(value):
		save_custom_scope_id = value
		_update_resource_name()

var save_target_node_path: NodePath = NodePath(""):
	set(value):
		save_target_node_path = value
		_update_resource_name()

# =============================================
# 元数据方法
# =============================================

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_GET_RANDOM_POINT_IN_RANGE_NAME"
	metadata.category_key = "FUSE_CATEGORY_MATH"
	metadata.description_key = "FUSE_INSTRUCTION_GET_RANDOM_POINT_IN_RANGE_DESC"
	metadata.keywords = ["random", "point", "position", "range", "2d", "3d", "vector", "随机", "点", "位置", "范围", "向量"]
	metadata.builtin_icon = "Vector3i"
	return metadata

func _setup_metadata():
	pass

# =============================================
# 属性列表
# =============================================

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# ============================================
	# Dimension 配置
	# ============================================
	properties.append({
		name = "Dimension",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "dimension_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "2D,3D",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 3D 平面选择（仅 3D 模式显示）
	if dimension_mode == DimensionMode.MODE_3D:
		properties.append({
			name = "plane_3d",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "XY Plane,XZ Plane,YZ Plane,Full 3D",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# ============================================
	# Origin (起点) 配置
	# ============================================
	properties.append({
		name = "Origin",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "origin_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if origin_mode == OriginMode.DIRECT:
		# 直接设置起点
		if dimension_mode == DimensionMode.MODE_2D:
			properties.append({
				name = "origin_direct_2d",
				type = TYPE_VECTOR2,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		else:
			properties.append({
				name = "origin_direct_3d",
				type = TYPE_VECTOR3,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
	else:
		# 变量模式
		properties.append({
			name = "origin_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "origin_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 仅当 origin_scope == SCOPE 时显示
		if origin_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "origin_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if origin_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "origin_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif origin_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "origin_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# ============================================
	# Range (范围) 配置
	# ============================================
	properties.append({
		name = "Range",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "range_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if range_mode == RangeMode.DIRECT:
		# 直接设置范围
		if dimension_mode == DimensionMode.MODE_2D:
			properties.append({
				name = "range_direct_2d",
				type = TYPE_VECTOR2,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		else:
			properties.append({
				name = "range_direct_3d",
				type = TYPE_VECTOR3,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
	else:
		# 变量模式
		properties.append({
			name = "range_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "range_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 仅当 range_scope == SCOPE 时显示
		if range_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "range_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if range_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "range_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif range_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "range_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# ============================================
	# Save To (结果保存) 配置
	# ============================================
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

	# 仅当 save_to_scope == SCOPE 时显示
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "save_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if save_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "save_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif save_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "save_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties

## 属性验证（控制属性可见性）
func _validate_property(property: Dictionary) -> void:
	# 控制 2D/3D 直接值属性
	if dimension_mode == DimensionMode.MODE_2D:
		if property.name == "origin_direct_3d":
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if property.name == "range_direct_3d":
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "origin_direct_2d":
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if property.name == "range_direct_2d":
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 控制起点变量相关属性
	if origin_mode == OriginMode.DIRECT:
		if property.name in ["origin_variable", "origin_scope", "origin_scope_source", "origin_custom_scope_id", "origin_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["origin_direct_2d", "origin_direct_3d"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 控制 origin_scope_source 相关属性
		if origin_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["origin_scope_source", "origin_custom_scope_id", "origin_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var utils_scope_source = origin_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, utils_scope_source)

	# 控制范围变量相关属性
	if range_mode == RangeMode.DIRECT:
		if property.name in ["range_variable", "range_scope", "range_scope_source", "range_custom_scope_id", "range_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["range_direct_2d", "range_direct_3d"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

		# 控制 range_scope_source 相关属性
		if range_scope != BaseVariable.VariableScope.SCOPE:
			if property.name in ["range_scope_source", "range_custom_scope_id", "range_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		else:
			var utils_scope_source = range_scope_source as VariableScopeUtils.ScopeSource
			VariableScopeUtils.validate_scope_source_property(property, utils_scope_source)

	# 控制 3D 平面属性
	if dimension_mode != DimensionMode.MODE_3D:
		if property.name == "plane_3d":
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 控制保存作用域相关属性
	if save_to_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["save_scope_source", "save_custom_scope_id", "save_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		var utils_scope_source = save_scope_source as VariableScopeUtils.ScopeSource
		VariableScopeUtils.validate_scope_source_property(property, utils_scope_source)

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	var prop_str = String(property)
	if prop_str in ["dimension_mode", "origin_mode", "origin_scope", "origin_scope_source",
					"range_mode", "range_scope", "range_scope_source",
					"save_to_scope", "save_scope_source"]:
		set(prop_str, value)
		notify_property_list_changed()
		return true
	return false

# =============================================
# 资源名称和描述
# =============================================

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_RANDOM_POINT_IN_RANGE_BASE"))

	# 维度模式
	var dim_str = "2D" if dimension_mode == DimensionMode.MODE_2D else "3D"
	parts.append("[%s]" % dim_str)

	# 3D 平面信息
	if dimension_mode == DimensionMode.MODE_3D:
		var plane_str = ""
		match plane_3d:
			Plane3D.XY: plane_str = "XY"
			Plane3D.XZ: plane_str = "XZ"
			Plane3D.YZ: plane_str = "YZ"
			Plane3D.FULL_3D: plane_str = "3D"
		parts.append("[%s]" % plane_str)

	# 起点信息
	if origin_mode == OriginMode.DIRECT:
		if dimension_mode == DimensionMode.MODE_2D:
			parts.append("@(%.0f, %.0f)" % [origin_direct_2d.x, origin_direct_2d.y])
		else:
			parts.append("@(%.0f, %.0f, %.0f)" % [origin_direct_3d.x, origin_direct_3d.y, origin_direct_3d.z])
	else:
		if origin_variable.is_empty():
			parts.append("@[?]")
		else:
			parts.append("@[%s]" % origin_variable)

	# 范围信息
	if range_mode == RangeMode.DIRECT:
		if dimension_mode == DimensionMode.MODE_2D:
			parts.append("±(%.0f, %.0f)" % [range_direct_2d.x, range_direct_2d.y])
		else:
			parts.append("±(%.0f, %.0f, %.0f)" % [range_direct_3d.x, range_direct_3d.y, range_direct_3d.z])
	else:
		if range_variable.is_empty():
			parts.append("±[?]")
		else:
			parts.append("±[%s]" % range_variable)

	# 保存变量
	parts.append("→")
	if save_to_variable.is_empty():
		parts.append("[?]")
	else:
		var scope_str = _get_save_scope_string()
		parts.append("%s [%s]" % [save_to_variable, scope_str])

	resource_name = " ".join(parts)

## 获取保存作用域字符串
func _get_save_scope_string() -> String:
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				save_scope_source as VariableScopeUtils.ScopeSource,
				save_custom_scope_id,
				save_target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

## 获取指令描述
func get_description() -> String:
	var desc_parts := []

	desc_parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_GET_RANDOM_POINT_IN_RANGE_DESC"))

	# 维度
	var dim_str = "2D" if dimension_mode == DimensionMode.MODE_2D else "3D"
	desc_parts.append("[%s]" % dim_str)

	# 起点描述
	var origin_desc := ""
	if origin_mode == OriginMode.DIRECT:
		if dimension_mode == DimensionMode.MODE_2D:
			origin_desc = "(%.1f, %.1f)" % [origin_direct_2d.x, origin_direct_2d.y]
		else:
			origin_desc = "(%.1f, %.1f, %.1f)" % [origin_direct_3d.x, origin_direct_3d.y, origin_direct_3d.z]
	else:
		origin_desc = "[%s]" % origin_variable
	desc_parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_RANDOM_POINT_IN_RANGE_ORIGIN", {"origin": origin_desc}))

	# 范围描述
	var range_desc := ""
	if range_mode == RangeMode.DIRECT:
		if dimension_mode == DimensionMode.MODE_2D:
			range_desc = "(%.1f, %.1f)" % [range_direct_2d.x, range_direct_2d.y]
		else:
			range_desc = "(%.1f, %.1f, %.1f)" % [range_direct_3d.x, range_direct_3d.y, range_direct_3d.z]
	else:
		range_desc = "[%s]" % range_variable
	desc_parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_RANDOM_POINT_IN_RANGE_RANGE", {"range": range_desc}))

	# 保存描述
	var scope_str = _get_save_scope_string()
	desc_parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_GET_RANDOM_POINT_IN_RANGE_SAVE", {
		"variable": save_to_variable,
		"scope": scope_str
	}))

	return " ".join(desc_parts)

# =============================================
# 执行逻辑
# =============================================

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# ============================================
	# 1. 验证保存变量名
	# ============================================
	if save_to_variable.is_empty():
		_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
		set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# ============================================
	# 2. 获取起点
	# ============================================
	var origin: Vector3
	if origin_mode == OriginMode.DIRECT:
		if dimension_mode == DimensionMode.MODE_2D:
			origin = Vector3(origin_direct_2d.x, origin_direct_2d.y, 0.0)
		else:
			origin = origin_direct_3d
	else:
		# 从变量获取起点
		origin = _get_origin_from_variable(context)
		if is_nan(origin.x):
			# 错误已在 _get_origin_from_variable 中设置
			return

	# ============================================
	# 3. 获取范围
	# ============================================
	var range_val: Vector3
	if range_mode == RangeMode.DIRECT:
		if dimension_mode == DimensionMode.MODE_2D:
			range_val = Vector3(range_direct_2d.x, range_direct_2d.y, 0.0)
		else:
			range_val = range_direct_3d
	else:
		# 从变量获取范围
		range_val = _get_range_from_variable(context)
		if is_nan(range_val.x):
			# 错误已在 _get_range_from_variable 中设置
			return

	# ============================================
	# 4. 生成随机点
	# ============================================
	var random_point: Variant
	if dimension_mode == DimensionMode.MODE_2D:
		random_point = _generate_2d(origin, range_val)
	else:
		random_point = _generate_3d(origin, range_val)

	# ============================================
	# 5. 保存结果
	# ============================================
	var save_success = _save_result(context, random_point)
	if not save_success:
		return

	_log_info_localized("FUSE_LOG_GET_RANDOM_POINT_IN_RANGE", {
		"variable": save_to_variable,
		"value": str(random_point)
	})

	_on_execution_completed()

## 从变量获取起点
func _get_origin_from_variable(context: ExecutionContext) -> Vector3:
	if origin_variable.is_empty():
		_log_error_localized("FUSE_ERROR_ORIGIN_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_ORIGIN_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return Vector3(NAN, NAN, NAN)

	var value: Variant

	if origin_scope == BaseVariable.VariableScope.SCOPE:
		if origin_scope_source == ScopeSource.NEAREST:
			value = VariableOperations.get_variable(context, origin_variable, BaseVariable.VariableScope.SCOPE, null)
		else:
			var scope_container = VariableScopeUtils.get_scope_container_by_source(
				context,
				origin_scope_source as VariableScopeUtils.ScopeSource,
				origin_custom_scope_id,
				origin_target_node_path
			)
			if scope_container == null:
				_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
				set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
				finished.emit()
				return Vector3(NAN, NAN, NAN)
			value = scope_container.get_variable(origin_variable, null)
	else:
		value = VariableOperations.get_variable(context, origin_variable, origin_scope, null)

	if value == null:
		_log_error_localized("FUSE_ERROR_ORIGIN_VARIABLE_NOT_FOUND", {"variable": origin_variable})
		set_error_localized("FUSE_ERROR_ORIGIN_VARIABLE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": origin_variable})
		finished.emit()
		return Vector3(NAN, NAN, NAN)

	# 类型转换
	return _convert_to_vector3(value)

## 从变量获取范围
func _get_range_from_variable(context: ExecutionContext) -> Vector3:
	if range_variable.is_empty():
		_log_error_localized("FUSE_ERROR_RANGE_VARIABLE_EMPTY", {})
		set_error_localized("FUSE_ERROR_RANGE_VARIABLE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return Vector3(NAN, NAN, NAN)

	var value: Variant

	if range_scope == BaseVariable.VariableScope.SCOPE:
		if range_scope_source == ScopeSource.NEAREST:
			value = VariableOperations.get_variable(context, range_variable, BaseVariable.VariableScope.SCOPE, null)
		else:
			var scope_container = VariableScopeUtils.get_scope_container_by_source(
				context,
				range_scope_source as VariableScopeUtils.ScopeSource,
				range_custom_scope_id,
				range_target_node_path
			)
			if scope_container == null:
				_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
				set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
				finished.emit()
				return Vector3(NAN, NAN, NAN)
			value = scope_container.get_variable(range_variable, null)
	else:
		value = VariableOperations.get_variable(context, range_variable, range_scope, null)

	if value == null:
		_log_error_localized("FUSE_ERROR_RANGE_VARIABLE_NOT_FOUND", {"variable": range_variable})
		set_error_localized("FUSE_ERROR_RANGE_VARIABLE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"variable": range_variable})
		finished.emit()
		return Vector3(NAN, NAN, NAN)

	# 类型转换
	return _convert_to_vector3(value)

## 转换为 Vector3
func _convert_to_vector3(value: Variant) -> Vector3:
	if value is Vector2:
		return Vector3(value.x, value.y, 0.0)
	elif value is Vector2i:
		return Vector3(float(value.x), float(value.y), 0.0)
	elif value is Vector3:
		return value
	elif value is Vector3i:
		return Vector3(float(value.x), float(value.y), float(value.z))
	else:
		_log_error_localized("FUSE_ERROR_INVALID_VECTOR_TYPE", {"actual_type": type_string(typeof(value))})
		set_error_localized("FUSE_ERROR_INVALID_VECTOR_TYPE", FuseError.ErrorType.VALIDATION_ERROR, {"actual_type": type_string(typeof(value))})
		finished.emit()
		return Vector3(NAN, NAN, NAN)

## 生成 2D 随机点
func _generate_2d(origin: Vector3, range_val: Vector3) -> Vector2:
	return Vector2(
		origin.x + randf_range(-range_val.x, range_val.x),
		origin.y + randf_range(-range_val.y, range_val.y)
	)

## 生成 3D 随机点
func _generate_3d(origin: Vector3, range_val: Vector3) -> Vector3:
	match plane_3d:
		Plane3D.XY:
			return Vector3(
				origin.x + randf_range(-range_val.x, range_val.x),
				origin.y + randf_range(-range_val.y, range_val.y),
				origin.z  # Z 轴保持不变
			)
		Plane3D.XZ:
			return Vector3(
				origin.x + randf_range(-range_val.x, range_val.x),
				origin.y,  # Y 轴保持不变
				origin.z + randf_range(-range_val.z, range_val.z)
			)
		Plane3D.YZ:
			return Vector3(
				origin.x,  # X 轴保持不变
				origin.y + randf_range(-range_val.y, range_val.y),
				origin.z + randf_range(-range_val.z, range_val.z)
			)
		Plane3D.FULL_3D:
			return Vector3(
				origin.x + randf_range(-range_val.x, range_val.x),
				origin.y + randf_range(-range_val.y, range_val.y),
				origin.z + randf_range(-range_val.z, range_val.z)
			)
		_:
			return origin

## 保存结果到变量
func _save_result(context: ExecutionContext, value: Variant) -> bool:
	var success := false

	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			success = VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, value)

		BaseVariable.VariableScope.SCOPE:
			if save_scope_source == ScopeSource.NEAREST:
				success = VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, value)
			else:
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					save_scope_source as VariableScopeUtils.ScopeSource,
					save_custom_scope_id,
					save_target_node_path
				)
				if scope_container == null:
					_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
					finished.emit()
					return false
				success = scope_container.set_variable(save_to_variable, value)

		BaseVariable.VariableScope.GLOBAL:
			success = VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, value)

	if not success:
		_log_error_localized("FUSE_ERROR_SAVE_VARIABLE_FAILED", {"variable": save_to_variable})
		set_error_localized("FUSE_ERROR_SAVE_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"variable": save_to_variable})
		finished.emit()
		return false

	return true

# =============================================
# 验证
# =============================================

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 验证保存变量名
	if save_to_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY"))

	# 验证起点变量模式
	if origin_mode == OriginMode.VARIABLE:
		if origin_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_ORIGIN_VARIABLE_EMPTY"))

		if origin_scope == BaseVariable.VariableScope.SCOPE:
			var utils_scope_source = origin_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				origin_custom_scope_id,
				origin_target_node_path
			))

	# 验证范围变量模式
	if range_mode == RangeMode.VARIABLE:
		if range_variable.is_empty():
			errors.append(FuseLocalization.translate("FUSE_ERROR_RANGE_VARIABLE_EMPTY"))

		if range_scope == BaseVariable.VariableScope.SCOPE:
			var utils_scope_source = range_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				range_custom_scope_id,
				range_target_node_path
			))

	# 验证保存作用域
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = save_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			save_custom_scope_id,
			save_target_node_path
		))

	return errors
