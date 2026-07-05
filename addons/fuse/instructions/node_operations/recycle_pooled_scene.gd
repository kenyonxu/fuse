@tool
@icon("res://addons/fuse/icons/builtin/Refresh.svg")
extends BaseInstruction
class_name RecyclePooledScene

## 回收池化场景实例
##
## 将使用完毕的场景实例归还到对象池，以便后续复用
## 显式回收指令，用于手动管理池化对象的生命周期


## 作用域来源
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

## 获取池管理器单例实例
func _get_pool_manager() -> FusePoolManager:
	return FusePoolManager.get_instance()

## 回收池化场景实例
##
## 将使用完毕的场景实例归还到对象池，以便后续复用
## 显式回收指令，用于手动管理池化对象的生命周期

## 回收模式：0=Scene Path模式，1=Node模式
var recycle_mode: int = 0:
	set(mode):
		recycle_mode = mode
		notify_property_list_changed()

## 场景路径（Scene Path模式使用）
var scene_path: String = ""

## 目标节点路径（两种模式都使用）
var target_node: NodePath = NodePath("")

## 实例 ID 变量名（仅当 target_node 为空时使用）
var instance_id_variable: String = "instance_id"

## 变量作用域（用于读取实例 ID）
var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_scope = value
		notify_property_list_changed()

## 作用域来源（仅当 variable_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		notify_property_list_changed()

## 自定义作用域 ID（仅当 scope_source == CUSTOM_ID 时使用）
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value

## 目标节点路径（仅当 scope_source == TARGET_NODE 时使用）
var scope_target_node: NodePath = NodePath(""):
	set(value):
		scope_target_node = value

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_RECYCLE_POOLED_SCENE_NAME"
	metadata.category_key = "FUSE_CATEGORY_NODE_OPERATIONS"
	metadata.description_key = "FUSE_INSTRUCTION_RECYCLE_POOLED_SCENE_DESC"
	metadata.keywords = ["recycle", "pool", "return", "回收", "池"]
	metadata.builtin_icon = "Refresh"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Object Pool 分类
	properties.append({
		name = "Object Pool",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# 回收模式
	properties.append({
		name = "recycle_mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Scene Path模式,Node模式",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if recycle_mode == 1:
		# 目标节点
		properties.append({
			name = "target_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	else:
	# 场景路径（仅 Scene Path 模式）
		properties.append({
			name = "scene_path",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_FILE,
			hint_string = "*.tscn,*.scn",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 实例 ID 变量名
		properties.append({
			name = "instance_id_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_PLACEHOLDER_TEXT,
			hint_string = "instance_id",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 变量作用域
		properties.append({
			name = "variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 仅当 variable_scope == SCOPE 时显示 ScopeSource 配置
		if variable_scope == BaseVariable.VariableScope.SCOPE:
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
					name = "scope_target_node",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 控制 ScopeSource 属性可见性
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "scope_target_node"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 更新资源名称
func _update_resource_name():
	var parts = []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RECYCLE_POOLED_SCENE_NAME"))

	# 显示模式
	if recycle_mode == 0:
		parts.append("[Scene Path]")
		if not scene_path.is_empty():
			parts.append("'%s'" % FuseNodeUtils.get_path_display_name(scene_path))
		else:
			parts.append(FuseLocalization.translate("FUSE_NOT_SPECIFIED_SCENE"))
	else:
		parts.append("[Node]")

	if not target_node.is_empty():
		parts.append(_get_node_display_name(target_node))
	elif not instance_id_variable.is_empty():
		# 显示变量来源信息
		var scope_str = _get_variable_scope_string()
		parts.append("from var '%s' [%s]" % [instance_id_variable, scope_str])
	else:
		parts.append(FuseLocalization.translate("FUSE_NOT_SPECIFIED_TARGET"))

	resource_name = " ".join(parts)

## 获取变量作用域字符串
func _get_variable_scope_string() -> String:
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			return "Local"
		BaseVariable.VariableScope.GLOBAL:
			return "Global"
		BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域时，使用 ScopeSource 获取具体域信息
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				scope_target_node
			)
		_:
			return "Unknown"

## 执行指令
func execute(context: ExecutionContext):
	# 🔍 性能追踪：开始回收
	FusePerformanceTracker.get_instance().start_track("RecyclePooledScene.execute")

	_start_execution(context)

	# 确定目标实例
	var instance: Node
	var instance_id: int = 0
	var final_scene_path: String = ""

	# Scene Path 模式：必须填写 scene_path
	if recycle_mode == 0:
		if scene_path.is_empty():
			_log_error("Scene Path模式下，场景路径不能为空")
			set_error("Scene Path模式下，场景路径不能为空", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
		final_scene_path = scene_path

	# 获取实例节点
	# 方法 1: 从目标节点路径获取
	if not target_node.is_empty():
		instance = context.get_node(target_node)
		if not instance:
			_log_error("目标节点未找到: %s" % str(target_node))
			set_error("目标节点未找到: %s" % str(target_node), FuseError.ErrorType.RUNTIME_ERROR, {})
			finished.emit()
			return
	else:
		# 方法 2: 从变量获取实例 ID，然后查找节点
		# 根据作用域类型获取实例 ID
		match variable_scope:
			BaseVariable.VariableScope.LOCAL:
				instance_id = VariableOperations.get_variable(
					context,
					instance_id_variable,
					BaseVariable.VariableScope.LOCAL,
					null
				)

			BaseVariable.VariableScope.SCOPE:
				# 根据 scope_source 获取变量值
				if scope_source == ScopeSource.NEAREST:
					instance_id = VariableOperations.get_variable(
						context,
						instance_id_variable,
						BaseVariable.VariableScope.SCOPE,
						null
					)
				else:
					# 其他模式：获取指定作用域容器并读取变量
					var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						custom_scope_id,
						scope_target_node
					)

					if scope_container == null:
						_log_error("作用域容器未找到")
						set_error("作用域容器未找到", FuseError.ErrorType.RUNTIME_ERROR, {})
						finished.emit()
						return

					# 检查变量是否存在
					if not scope_container.has_variable(instance_id_variable):
						_log_error("变量未找到: %s" % instance_id_variable)
						set_error("变量未找到: %s" % instance_id_variable, FuseError.ErrorType.RUNTIME_ERROR, {})
						finished.emit()
						return

					instance_id = scope_container.get_variable(instance_id_variable)

			BaseVariable.VariableScope.GLOBAL:
				instance_id = VariableOperations.get_variable(
					context,
					instance_id_variable,
					BaseVariable.VariableScope.GLOBAL,
					null
				)

		if instance_id == null:
			_log_error("无法从变量获取实例 ID: %s" % instance_id_variable)
			set_error("无法从变量获取实例 ID: %s" % instance_id_variable, FuseError.ErrorType.RUNTIME_ERROR)
			finished.emit()
			return

		# 从实例 ID 获取节点
		instance = instance_from_id(instance_id)

		if not instance or not is_instance_valid(instance):
			_log_error("无法从实例 ID %d 获取有效节点" % instance_id)
			set_error("无法从实例 ID %d 获取有效节点" % instance_id, FuseError.ErrorType.RUNTIME_ERROR)
			finished.emit()
			return

	# Node 模式：从节点推断 scene_path
	if recycle_mode == 1:
		final_scene_path = _infer_scene_path(instance)
		if final_scene_path.is_empty():
			_log_error("Node模式下无法推断场景路径，请切换到Scene Path模式并手动指定")
			set_error("Node模式下无法推断场景路径", FuseError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
		_log_debug("Node模式自动推断场景路径: %s" % final_scene_path)

	# 检查实例是否已被回收（双重回收防护）
	if not is_instance_valid(instance):
		_log_debug("实例已无效，跳过回收: %s" % instance_id)
		_on_execution_completed()
		return

	# 检查实例是否仍在场景树中（如果在场景树外，说明已被回收）
	if instance.get_parent() == null:
		_log_debug("实例已不在场景树中，可能已被回收: %s" % instance.name)
		_on_execution_completed()
		return

	# 回收到池
	var recycle_success = _get_pool_manager().recycle_pooled(final_scene_path, instance)

	# 🔍 输出回收结果
	if recycle_success:
		_log_info("✅ 实例回收成功: %s (ID: %d)" % [instance.name, instance.get_instance_id()])
	else:
		_log_warning("❌ 实例回收失败: %s (ID: %d)" % [instance.name, instance.get_instance_id()])

	# 🔍 性能追踪：结束回收
	FusePerformanceTracker.get_instance().stop_track("RecyclePooledScene.execute")

	_on_execution_completed()

## 从节点推断场景路径
func _infer_scene_path(instance: Node) -> String:
	if not instance:
		return ""

	# 方法 1: 从 scene_file_path 获取
	var scene_file = instance.scene_file_path
	if not scene_file.is_empty():
		return scene_file

	# 方法 2: 向上查找直到找到有 scene_file_path 的祖先
	var current = instance
	while current:
		scene_file = current.scene_file_path
		if not scene_file.is_empty():
			return scene_file
		current = current.get_parent()

	return ""

## 清理资源
func _cleanup_resources() -> void:
	# 该指令没有需要清理的资源
	pass

## 验证指令
func validate() -> Array[String]:
	var errors = super.validate()

	# Scene Path 模式下必须填写 scene_path
	if recycle_mode == 0 and scene_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_SCENE_PATH_EMPTY_IN_SCENE_PATH_MODE"))

	# Node 模式下 scene_path 可选（会自动推断）

	# 如果没有指定目标节点，必须有实例 ID 变量
	if target_node.is_empty() and instance_id_variable.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_OR_INSTANCE_ID_REQUIRED"))

	# 验证 ScopeSource 相关参数（仅当 variable_scope == SCOPE 时）
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			scope_target_node
		))

	return errors

## 获取指令描述
func get_description() -> String:
	var target_str = ""

	if not target_node.is_empty():
		target_str = " (%s)" % _get_node_display_name(target_node)
	elif not instance_id_variable.is_empty():
		target_str = " (from var '%s')" % instance_id_variable
	else:
		target_str = " " + FuseLocalization.translate("FUSE_NOT_SPECIFIED_TARGET")

	var scene_str: String
	if recycle_mode == 0:
		# Scene Path 模式
		scene_str = FuseNodeUtils.get_path_display_name(scene_path) if not scene_path.is_empty() else FuseLocalization.translate("FUSE_NOT_SPECIFIED_SCENE")
	else:
		# Node 模式
		scene_str = FuseLocalization.translate("FUSE_AUTO_INFERRED")

	return "%s %s%s" % [
		FuseLocalization.translate("FUSE_INSTRUCTION_RECYCLE_POOLED_SCENE_NAME"),
		scene_str,
		target_str
	]
