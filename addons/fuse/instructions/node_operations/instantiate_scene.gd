@tool
@icon("res://addons/fuse/icons/builtin/New.png")
extends BaseInstruction
class_name InstantiateScene

## 实例化场景
##
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问
## 添加对象池支持: 2026-02-12
## RuntimeInstance 架构迁移: 2026-03-12 - 统一执行模式，消除重复代码

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 位置来源枚举
enum PositionMode {
	MANUAL,         ## 手动指定位置
	VARIABLE        ## 从变量读取位置
}

## 获取池管理器实例
func _get_pool_manager() -> FusePoolManager:
	return FusePoolManager.get_instance()

# 场景路径
var scene_path: String = ""

# 父节点路径
var parent_node: NodePath = NodePath("")

# 是否保存实例 ID
var save_instance_id: bool = false:
	set(id):
		save_instance_id = id
		notify_property_list_changed()

# 目标变量名
var target_variable: String = "instance_id"

## 保存到作用域
var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
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

## ========== 生成位置配置 ==========

## 位置来源模式
var position_mode: PositionMode = PositionMode.MANUAL:
	set(value):
		if position_mode != value:
			position_mode = value
			_update_resource_name()
			notify_property_list_changed()

## 手动生成位置
var spawn_position: Vector3 = Vector3.ZERO:
	set(value):
		if spawn_position != value:
			spawn_position = value
			_update_resource_name()
			notify_property_list_changed()

## 位置变量名
var position_variable: String = "":
	set(value):
		if position_variable != value:
			position_variable = value
			_update_resource_name()

## 位置变量作用域
var position_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if position_scope != value:
			position_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 位置作用域来源
var position_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if position_scope_source != value:
			position_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 位置自定义作用域 ID
var position_custom_scope_id: String = "":
	set(value):
		if position_custom_scope_id != value:
			position_custom_scope_id = value
			_update_resource_name()

## 位置目标节点路径
var position_target_node_path: NodePath = NodePath(""):
	set(value):
		if position_target_node_path != value:
			position_target_node_path = value
			_update_resource_name()

## 生成位置偏移
var spawn_offset: Vector3 = Vector3.ZERO:
	set(value):
		if spawn_offset != value:
			spawn_offset = value
			_update_resource_name()
			notify_property_list_changed()

## ========== 对象池配置 ==========

## 是否使用对象池
var use_object_pool: bool = false:
	set(value):
		use_object_pool = value
		_update_resource_name()
		notify_property_list_changed()

## 池初始大小
var pool_initial_size: int = 20:
	set(value):
		pool_initial_size = value
		notify_property_list_changed()

## 池最大大小
var pool_max_size: int = 100:
	set(value):
		pool_max_size = value
		notify_property_list_changed()

## 是否自动回收对象
var auto_recycle: bool = true:
	set(value):
		auto_recycle = value
		_update_resource_name()
		notify_property_list_changed()

## 回收延迟（秒）
var recycle_delay: float = 0.0:
	set(value):
		recycle_delay = value
		_update_resource_name()
		notify_property_list_changed()

## ========== 运行时状态（遗留模式兼容） ==========

var _recycle_timer: FuseRecycleTimer = null
var _pooled_instance: Node = null

## 获取默认运行时状态（RuntimeInstance 模式）
func get_default_runtime_state() -> Dictionary:
	var state = super.get_default_runtime_state()
	state["recycle_timer"] = null
	state["pooled_instance"] = null
	state["deferred_callback"] = null
	return state

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_INSTANTIATE_SCENE_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_INSTANTIATE_SCENE_DESC"
	metadata.keywords = ["instantiate", "spawn", "create", "scene", "实例化", "生成", "创建"]
	metadata.builtin_icon = "New"
	return metadata

func _setup_metadata():
	pass

## 声明变量读写模式（target=write 保存 instance_id, position=read）
func get_variable_modes() -> Array[Dictionary]:
	return [
		{"name": "target_variable", "mode": "write"},
		{"name": "position_variable", "mode": "read"},
	]

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Scene 分类
	properties.append({
		name = "Scene",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "scene_path",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_FILE,
		hint_string = "*.tscn,*.scn",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "parent_node",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Position 分类
	properties.append({
		name = "Position",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "position_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Manual,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "spawn_position",
		type = TYPE_VECTOR3,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "spawn_offset",
		type = TYPE_VECTOR3,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "position_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "position_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 位置 SCOPE 相关属性
	if position_mode == PositionMode.VARIABLE and position_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "position_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if position_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "position_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif position_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "position_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# Variable 分类
	properties.append({
		name = "Variable",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "save_instance_id",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "target_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_PLACEHOLDER_TEXT,
		hint_string = "instance_id",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "save_to_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# SCOPE 作用域相关属性
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
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

	# Object Pool 分类
	properties.append({
		name = "Object Pool",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_object_pool",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if use_object_pool:
		properties.append({
			name = "pool_initial_size",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "1,100,1",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "pool_max_size",
			type = TYPE_INT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "10,500,10",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "auto_recycle",
			type = TYPE_BOOL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "recycle_delay",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_RANGE,
			hint_string = "0,60,0.5,or_greater",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

## 验证属性
func _validate_property(property: Dictionary) -> void:
	# 变量相关
	if not save_instance_id:
		if property.name in ["target_variable", "save_to_scope", "scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if save_to_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
		else:
			if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR

	# 位置相关
	if property.name == "spawn_position" and position_mode != PositionMode.MANUAL:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "position_variable" and position_mode != PositionMode.VARIABLE:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if property.name == "position_scope" and position_mode != PositionMode.VARIABLE:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	if position_mode != PositionMode.VARIABLE or position_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["position_scope_source", "position_custom_scope_id", "position_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		VariableScopeUtils.validate_scope_source_property(property, position_scope_source as VariableScopeUtils.ScopeSource)

## 获取场景文件显示名（处理 UID 路径）
func _get_scene_display_name() -> String:
	return FuseNodeUtils.get_path_display_name(scene_path)

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_INSTANTIATE_SCENE_ACTION"))

	if not scene_path.is_empty():
		parts.append("'%s'" % _get_scene_display_name())
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_INSTANTIATE_SCENE_NO_SCENE"))

	if not parent_node.is_empty():
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_INSTANTIATE_SCENE_TO_PARENT", {
			"parent": _get_node_display_name(parent_node)
		}))

	if position_mode == PositionMode.MANUAL:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_INSTANTIATE_SCENE_AT_POSITION", {
			"x": spawn_position.x,
			"y": spawn_position.y,
			"z": spawn_position.z
		}))
	elif position_mode == PositionMode.VARIABLE and not position_variable.is_empty():
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_INSTANTIATE_SCENE_FROM_POSITION_VAR", {
			"variable": position_variable,
			"scope": _get_position_scope_source_string()
		}))

	if spawn_offset != Vector3.ZERO:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_INSTANTIATE_SCENE_WITH_OFFSET", {
			"x": spawn_offset.x,
			"y": spawn_offset.y,
			"z": spawn_offset.z
		}))

	if save_instance_id:
		parts.append("→ %s [%s]" % [target_variable, _get_scope_source_string()])

	if use_object_pool:
		parts.append(FuseLocalization.translate("FUSE_POOLED"))

	resource_name = " ".join(parts)

## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	match save_to_scope:
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

## 获取位置作用域来源字符串
func _get_position_scope_source_string() -> String:
	match position_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			return VariableScopeUtils.get_scope_source_string(
				position_scope_source as VariableScopeUtils.ScopeSource,
				position_custom_scope_id,
				position_target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")

## 获取生成位置
func _get_spawn_position(context: ExecutionContext) -> Vector3:
	var base_position: Vector3

	match position_mode:
		PositionMode.MANUAL:
			base_position = spawn_position

		PositionMode.VARIABLE:
			if position_variable.is_empty():
				return Vector3.ZERO

			var var_value = _get_position_variable(context)

			if var_value is Vector2 or var_value is Vector2i:
				base_position = Vector3(var_value.x, var_value.y, 0.0)
			elif var_value is Vector3 or var_value is Vector3i:
				base_position = var_value
			else:
				return Vector3.ZERO

		_:
			return Vector3.ZERO

	return base_position + spawn_offset

## 获取位置变量值
func _get_position_variable(context: ExecutionContext) -> Variant:
	match position_scope:
		BaseVariable.VariableScope.LOCAL:
			return VariableOperations.get_variable(context, position_variable, BaseVariable.VariableScope.LOCAL, null)
		BaseVariable.VariableScope.GLOBAL:
			return VariableOperations.get_variable(context, position_variable, BaseVariable.VariableScope.GLOBAL, null)
		BaseVariable.VariableScope.SCOPE:
			if position_scope_source == ScopeSource.NEAREST:
				return VariableOperations.get_variable(context, position_variable, BaseVariable.VariableScope.SCOPE, null)
			else:
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					position_scope_source as VariableScopeUtils.ScopeSource,
					position_custom_scope_id,
					position_target_node_path
				)
				if scope_container:
					return scope_container.get_variable(position_variable, null)
				return null
		_:
			return null

## ============================================================
## 统一执行入口
## ============================================================

## 执行指令（遗留模式）
func execute(context: ExecutionContext):
	_start_execution(context)

	# 验证场景路径
	if scene_path.is_empty():
		_handle_error_legacy(context, "FUSE_ERROR_SCENE_PATH_EMPTY")
		return

	# 获取父节点
	var parent = _get_parent_node(context)
	if not parent:
		finished.emit()
		return

	# 创建实例
	var result = _create_instance(context, {})
	if result.is_empty():
		finished.emit()
		return

	# 调度延迟添加（遗留模式）
	_schedule_deferred_add_legacy(parent, result["instance"], result.get("pool"), context)

## 调度延迟添加（遗留模式）
func _schedule_deferred_add_legacy(parent: Node, instance: Node, pool, context: ExecutionContext) -> void:
	_on_deferred_add_legacy.bind(parent, instance, pool, context).call_deferred()

## 延迟添加回调（遗留模式）
func _on_deferred_add_legacy(parent: Node, instance: Node, pool, context: ExecutionContext) -> void:
	# 处理已有父节点（池化对象竞态条件）
	if instance.get_parent():
		instance.get_parent().remove_child(instance)

	parent.add_child(instance)

	# 池化实例重置
	if pool:
		pool.reset_object(instance)

	# 完成初始化并发射信号
	_finalize_instance_legacy(instance, context)

## 完成实例初始化（遗留模式）
func _finalize_instance_legacy(instance: Node, context: ExecutionContext) -> void:
	# 应用位置
	_apply_spawn_position(instance, context)

	# 保存实例 ID
	if save_instance_id:
		if not _save_instance_id(instance, context):
			finished.emit()
			return

	_log_info_localized("FUSE_LOG_INSTANTIATED_SCENE", {
		"scene": scene_path,
		"name": instance.name
	})

	finished.emit()

## 遗留模式错误处理
func _handle_error_legacy(context: ExecutionContext, error_key: String) -> void:
	_log_error_localized(error_key, {})
	set_error_localized(error_key, FuseError.ErrorType.RUNTIME_ERROR, {})
	finished.emit()

## 使用运行时实例执行（推荐模式）
## 返回 true 表示同步完成，false 表示异步执行
func execute_with_runtime_instance(runtime_instance: RuntimeInstructionInstance) -> bool:
	_start_execution(runtime_instance.execution_context)

	var state = runtime_instance.runtime_state
	var context = runtime_instance.execution_context

	# 验证场景路径
	if scene_path.is_empty():
		_handle_error(runtime_instance, "FUSE_ERROR_SCENE_PATH_EMPTY", {})
		return true

	# 获取父节点
	var parent = _get_parent_node(context)
	if not parent:
		_handle_error(runtime_instance, "FUSE_ERROR_NO_SCENE_TREE", {})
		return true

	# 创建实例
	var result = _create_instance(context, state)
	if result.is_empty():
		_handle_error(runtime_instance, "FUSE_ERROR_POOL_INSTANTIATE_FAILED", {})
		return true

	# 调度延迟添加
	_schedule_deferred_add(runtime_instance, parent, result["instance"], result.get("pool"))
	return false

## ============================================================
## 核心方法（统一实现，消除重复）
## ============================================================

## 获取父节点
func _get_parent_node(context: ExecutionContext) -> Node:
	var parent: Node

	if parent_node.is_empty():
		var scene_tree = Engine.get_main_loop()
		if scene_tree:
			parent = scene_tree.current_scene
		else:
			_log_error_localized("FUSE_ERROR_NO_SCENE_TREE", {})
			return null
	else:
		parent = context.get_node(parent_node)

	if not parent:
		_log_warning_localized("FUSE_WARNING_PARENT_NOT_FOUND_USE_CURRENT", {})
		var scene_tree = Engine.get_main_loop()
		if scene_tree:
			parent = scene_tree.current_scene
		else:
			_log_error_localized("FUSE_ERROR_NO_SCENE_TREE", {})
			return null

	return parent

## 创建实例（统一入口）
func _create_instance(context: ExecutionContext, state: Dictionary) -> Dictionary:
	if use_object_pool:
		return _create_pooled_instance(context, state)
	else:
		return _create_fresh_instance(context)

## 创建池化实例
func _create_pooled_instance(context: ExecutionContext, state: Dictionary) -> Dictionary:
	var pool_config = {
		"initial_size": pool_initial_size,
		"max_size": pool_max_size
	}
	var result = _get_pool_manager().get_pooled_instance(scene_path, pool_config)

	if result.is_empty():
		return {}

	var instance = result["instance"]
	var pool = result["pool"]

	# 存储引用（兼容两种模式）
	if state.is_empty():
		_pooled_instance = instance
	else:
		state["pooled_instance"] = instance

	return { "instance": instance, "pool": pool }

## 创建新实例
func _create_fresh_instance(context: ExecutionContext) -> Dictionary:
	var scene_resource = load(scene_path)
	if not scene_resource:
		_log_error_localized("FUSE_ERROR_FAILED_LOAD_SCENE", {"scene_path": scene_path})
		return {}

	if not scene_resource is PackedScene:
		_log_error_localized("FUSE_ERROR_NOT_PACKED_SCENE", {"scene_path": scene_path})
		return {}

	var instance = scene_resource.instantiate()
	if not instance:
		_log_error_localized("FUSE_ERROR_FAILED_INSTANTIATE", {"scene_path": scene_path})
		return {}

	return { "instance": instance, "pool": null }

## 调度延迟添加
func _schedule_deferred_add(runtime_instance: RuntimeInstructionInstance, parent: Node, instance: Node, pool) -> void:
	var callback = func():
		_on_deferred_add(runtime_instance, parent, instance, pool)

	runtime_instance.runtime_state["deferred_callback"] = callback
	call_deferred("_execute_deferred_callback", callback)

func _execute_deferred_callback(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()

## 延迟添加回调（统一实现）
func _on_deferred_add(runtime_instance: RuntimeInstructionInstance, parent: Node, instance: Node, pool) -> void:
	# 检查有效性
	if not runtime_instance or runtime_instance.is_completed():
		return

	if not is_instance_valid(parent) or not is_instance_valid(instance):
		_handle_error(runtime_instance, "FUSE_ERROR_INSTANCE_INVALID", {})
		return

	# 处理已有父节点（池化对象竞态条件）
	if instance.get_parent():
		instance.get_parent().remove_child(instance)

	parent.add_child(instance)

	# 池化实例重置
	if pool:
		pool.reset_object(instance)

	# 完成初始化
	_finalize_instance(instance, runtime_instance.execution_context, runtime_instance)

## 完成实例初始化（统一实现）
func _finalize_instance(instance: Node, context: ExecutionContext, runtime_instance: RuntimeInstructionInstance) -> void:
	# 应用位置
	_apply_spawn_position(instance, context)

	# 保存实例 ID
	if save_instance_id:
		if not _save_instance_id(instance, context):
			runtime_instance._complete_execution()
			return

	_log_info_localized("FUSE_LOG_INSTANTIATED_SCENE", {
		"scene": scene_path,
		"name": instance.name
	})

	runtime_instance._complete_execution()

## 应用生成位置
func _apply_spawn_position(instance: Node, context: ExecutionContext) -> void:
	var spawn_pos = _get_spawn_position(context)

	if instance is Node2D:
		instance.global_position = Vector2(spawn_pos.x, spawn_pos.y)
	elif instance is Node3D:
		instance.global_position = spawn_pos

## 保存实例 ID（统一实现）
func _save_instance_id(instance: Node, context: ExecutionContext) -> bool:
	var instance_id = instance.get_instance_id()

	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			var success = VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.LOCAL, instance_id)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": target_variable})
				return false

		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.SCOPE, instance_id)
			else:
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					scope_source as VariableScopeUtils.ScopeSource,
					custom_scope_id,
					target_node_path
				)
				if not scope_container:
					_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					return false
				if not scope_container.set_variable(target_variable, instance_id):
					_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": target_variable})
					return false

		BaseVariable.VariableScope.GLOBAL:
			var success = VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.GLOBAL, instance_id)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", {"name": target_variable})
				return false

	return true

## 统一错误处理
func _handle_error(runtime_instance: RuntimeInstructionInstance, error_key: String, params: Dictionary) -> void:
	_log_error_localized(error_key, params)
	set_error_localized(error_key, FuseError.ErrorType.RUNTIME_ERROR, params)
	runtime_instance._complete_execution()

## 清理资源（遗留模式）
func _cleanup_resources() -> void:
	_recycle_timer = null

## 清理资源（RuntimeInstance 模式）
func on_runtime_cleanup(runtime_instance: RuntimeInstructionInstance) -> void:
	var state = runtime_instance.runtime_state
	state["deferred_callback"] = null
	state["recycle_timer"] = null

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if scene_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCENE_PATH_EMPTY"))

	if save_instance_id and target_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_VARIABLE_CANNOT_BE_EMPTY"))

	if position_mode == PositionMode.VARIABLE and position_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_POSITION_VARIABLE_NAME_EMPTY"))

	return errors

## 获取指令描述
func get_description() -> String:
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_INSTANTIATE_SCENE_ACTION"))
	parts.append("'%s'" % _get_scene_display_name() if not scene_path.is_empty() else FuseLocalization.translate("FUSE_INSTRUCTION_INSTANTIATE_SCENE_NO_SCENE"))

	if not parent_node.is_empty():
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_INSTANTIATE_SCENE_TO_PARENT", {"parent": _get_node_display_name(parent_node)}))

	if position_mode == PositionMode.MANUAL:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_INSTANTIATE_SCENE_AT_POSITION", {
			"x": spawn_position.x, "y": spawn_position.y, "z": spawn_position.z
		}))
	elif position_mode == PositionMode.VARIABLE and not position_variable.is_empty():
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_INSTANTIATE_SCENE_FROM_POSITION_VAR", {
			"variable": position_variable, "scope": _get_position_scope_source_string()
		}))

	if spawn_offset != Vector3.ZERO:
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_INSTANTIATE_SCENE_WITH_OFFSET", {
			"x": spawn_offset.x, "y": spawn_offset.y, "z": spawn_offset.z
		}))

	if save_instance_id:
		parts.append("→ %s [%s]" % [target_variable, _get_scope_source_string()])

	if use_object_pool:
		parts.append(FuseLocalization.translate("FUSE_POOLED"))

	return " ".join(parts)
