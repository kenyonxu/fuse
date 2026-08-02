@tool
@icon("res://addons/fuse/icons/builtin/RayCast2D.png")
extends BaseInstruction
class_name Raycast

## 射线检测指令（支持 2D/3D）
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 是否使用 3D 射线
var use_3d: bool = false

# 2D 射线起点
var from_position: Vector2 = Vector2.ZERO

# 2D 射线终点
var to_position: Vector2 = Vector2(100, 0)

# 3D 射线起点
var from_position_3d: Vector3 = Vector3.ZERO

# 3D 射线终点
var to_position_3d: Vector3 = Vector3(0, 0, 100)

# 碰撞层掩码
var collision_mask: int = 0xFFFFFFFF

# 排除的节点
var exclude_target: NodePath = NodePath("")

# 是否保存结果到变量
var save_result: bool = false

# 结果变量名
var result_variable: String = ""

## 保存到作用域
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if save_to_scope != value:
			save_to_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 作用域来源（仅当 save_to_scope == SCOPE 时使用）
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
	metadata.name_key = "FUSE_INSTRUCTION_RAYCAST_NAME"
	metadata.category_key = "FUSE_CATEGORY_PHYSICS"
	metadata.description_key = "FUSE_INSTRUCTION_RAYCAST_DESC"
	metadata.keywords = ["raycast", "ray", "physics", "collision", "detect", "射线", "物理", "碰撞", "检测"]
	metadata.builtin_icon = "RayCast2D"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Ray Settings 分类
	properties.append({
		name = "Ray Settings",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否使用 3D
	properties.append({
		name = "use_3d",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 2D 射线起点
	if not use_3d:
		properties.append({
			name = "from_position",
			type = TYPE_VECTOR2,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 3D 射线起点
	if use_3d:
		properties.append({
			name = "from_position_3d",
			type = TYPE_VECTOR3,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 2D 射线终点
	if not use_3d:
		properties.append({
			name = "to_position",
			type = TYPE_VECTOR2,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 3D 射线终点
	if use_3d:
		properties.append({
			name = "to_position_3d",
			type = TYPE_VECTOR3,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# Collision Settings 分类
	properties.append({
		name = "Collision Settings",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 碰撞层掩码
	properties.append({
		name = "collision_mask",
		type = TYPE_INT,
		hint = PROPERTY_HINT_LAYERS_2D_PHYSICS if not use_3d else PROPERTY_HINT_LAYERS_3D_PHYSICS,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 排除的节点
	properties.append({
		name = "exclude_target",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Result Settings 分类
	properties.append({
		name = "Result Settings",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 是否保存结果
	properties.append({
		name = "save_result",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 结果变量名
	if save_result:
		properties.append({
			name = "result_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 保存到作用域
		properties.append({
			name = "save_to_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 save_to_scope == SCOPE 时显示 ScopeSource 配置
		if save_to_scope == BaseVariable.VariableScope.SCOPE:
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
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties

## 更新资源名称
func _update_resource_name():
	if save_result:
		var scope_str = _get_scope_source_string()
		if use_3d:
			resource_name = "Raycast3D %s→%s" % [str(from_position_3d), str(to_position_3d)]
			resource_name += " → %s [%s]" % [result_variable, scope_str]
		else:
			resource_name = "Raycast2D %s→%s" % [str(from_position), str(to_position)]
			resource_name += " → %s [%s]" % [result_variable, scope_str]
	else:
		if use_3d:
			resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_RAYCAST_3D", {
				"from": str(from_position_3d),
				"to": str(to_position_3d)
			})
		else:
			resource_name = FuseLocalization.translate_format("FUSE_INSTRUCTION_RAYCAST_2D", {
				"from": str(from_position),
				"to": str(to_position)
			})

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	# 根据 save_to_scope 返回不同的作用域字符串
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域时，使用 ScopeSource 获取具体域信息
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取物理空间
	var space_state: Variant = _get_physics_space(context, use_3d)
	if not space_state:
		_log_error_localized("FUSE_ERROR_RAYCAST_NO_PHYSICS_SPACE", {})
		set_error_localized("FUSE_ERROR_RAYCAST_NO_PHYSICS_SPACE", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 获取射线起点和终点
	var from: Variant
	var to: Variant

	if use_3d:
		from = from_position_3d
		to = to_position_3d
	else:
		from = from_position
		to = to_position

	# 验证位置
	if not _is_valid_position(from, use_3d) or not _is_valid_position(to, use_3d):
		_log_error_localized("FUSE_ERROR_INVALID_POSITION", {})
		set_error_localized("FUSE_ERROR_INVALID_POSITION", FuseError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 创建射线查询参数
	var query := _create_ray_query(from, to, collision_mask, use_3d)

	# 添加排除节点
	if not exclude_target.is_empty():
		var exclude_node := context.get_node(exclude_target)
		if exclude_node:
			var rid: RID = exclude_node.get_rid()
			if rid.is_valid():
				query.exclude = [rid]

	# 执行射线检测
	var result = space_state.intersect_ray(query)

	# 转换结果为标准格式
	var result_dict := _convert_result(result, from, use_3d)

	# 保存到变量
	if save_result:
		if result_variable.is_empty():
			_log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
			set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return

		# 根据作用域类型保存变量
		match save_to_scope:
			BaseVariable.VariableScope.LOCAL:
				# 保存到 LOCAL 变量
				var success = VariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.LOCAL, result_dict)
				if not success:
					_log_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": result_variable})
					set_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": result_variable})
					finished.emit()
					return

			BaseVariable.VariableScope.SCOPE:
				# 保存到 SCOPE 变量
				if scope_source == ScopeSource.NEAREST:
					VariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.SCOPE, result_dict)
				else:
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

					var success = scope_container.set_variable(result_variable, result_dict)
					if not success:
						_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": result_variable})
						set_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": result_variable})
						finished.emit()
						return

			BaseVariable.VariableScope.GLOBAL:
				# 保存到 GLOBAL 变量
				var success = VariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.GLOBAL, result_dict)
				if not success:
					_log_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", {"name": result_variable})
					set_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": result_variable})
					finished.emit()
					return

	# 记录日志
	if result_dict.collider:
		var collider_name = ""
		if result_dict.collider is Node:
			collider_name = result_dict.collider.name
		else:
			collider_name = "<Object>"
		_log_info_localized("FUSE_LOG_RAYCAST_HIT", {
			"node": collider_name,
			"dist": "%.2f" % result_dict.distance
		})
	else:
		_log_info_localized("FUSE_LOG_RAYCAST_MISS", {})

	_on_execution_completed()

## 获取物理空间状态
func _get_physics_space(context: ExecutionContext, use_3d: bool) -> Variant:
	if use_3d:
		# 3D 物理空间
		if context.owner and context.owner is Node3D:
			return context.owner.get_world_3d().direct_space_state
		else:
			var scene_tree = Engine.get_main_loop() as SceneTree
			if scene_tree and scene_tree.root:
				return scene_tree.root.get_world_3d().direct_space_state
	else:
		# 2D 物理空间
		if context.owner and context.owner is Node2D:
			return context.owner.get_world_2d().direct_space_state
		else:
			var scene_tree = Engine.get_main_loop() as SceneTree
			if scene_tree and scene_tree.root:
				return scene_tree.root.get_world_2d().direct_space_state

	return null

## 创建射线查询参数
func _create_ray_query(from: Variant, to: Variant, mask: int, use_3d: bool) -> Variant:
	if use_3d:
		return PhysicsRayQueryParameters3D.create(from, to, mask)
	else:
		return PhysicsRayQueryParameters2D.create(from, to, mask)

## 转换射线检测结果
func _convert_result(result: Dictionary, from_pos: Variant, use_3d: bool) -> Dictionary:
	if result.is_empty():
		# 未击中
		var zero_pos: Variant
		if use_3d:
			zero_pos = Vector3.ZERO
		else:
			zero_pos = Vector2.ZERO

		return {
			"collider": null,
			"point": zero_pos,
			"normal": zero_pos,
			"distance": 0.0
		}

	# 获取碰撞点（Godot 4.x 使用 position）
	var point = result.get("position", result.get("point", Vector2.ZERO))
	var normal = result.get("normal", Vector2.ZERO if not use_3d else Vector3.ZERO)
	var collider = result.get("collider")

	# 计算距离
	var distance := 0.0
	if use_3d:
		var from_vec := from_pos as Vector3
		var point_vec := point as Vector3
		distance = from_vec.distance_to(point_vec)
	else:
		var from_vec := from_pos as Vector2
		var point_vec := point as Vector2
		distance = from_vec.distance_to(point_vec)

	return {
		"collider": collider,
		"point": point,
		"normal": normal,
		"distance": distance
	}

## 验证位置是否有效
func _is_valid_position(pos: Variant, use_3d: bool) -> bool:
	if use_3d:
		var vec := pos as Vector3
		return not (is_nan(vec.x) or is_inf(vec.x) or
					is_nan(vec.y) or is_inf(vec.y) or
					is_nan(vec.z) or is_inf(vec.z))
	else:
		var vec := pos as Vector2
		return not (is_nan(vec.x) or is_inf(vec.x) or
					is_nan(vec.y) or is_inf(vec.y))

## 验证参数
func validate() -> Array[String]:
	var errors = super.validate()

	if save_result and result_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_RESULT_VARIABLE_NAME_EMPTY"))

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if save_result and save_to_scope == BaseVariable.VariableScope.SCOPE:
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
	if use_3d:
		var from_str = str(from_position_3d)
		var to_str = str(to_position_3d)
		if save_result:
			var scope_str = _get_scope_source_string()
			return "Raycast3D %s→%s → %s [%s]" % [from_str, to_str, result_variable, scope_str]
		else:
			return "Raycast3D %s→%s" % [from_str, to_str]
	else:
		var from_str = str(from_position)
		var to_str = str(to_position)
		if save_result:
			var scope_str = _get_scope_source_string()
			return "Raycast2D %s→%s → %s [%s]" % [from_str, to_str, result_variable, scope_str]
		else:
			return "Raycast2D %s→%s" % [from_str, to_str]

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property == "use_3d" or property == "save_result" or property == "save_to_scope":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	if not save_result:
		if property.name in ["result_variable", "save_to_scope", "scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
		if save_to_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
		else:
			# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
			if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
