@tool
@icon("res://addons/fuse/icons/builtin/Pause.png")
extends BaseInstruction
class_name PauseGame

## 暂停游戏指令

## UI 节点路径（可选，暂停时自动设置为 ALWAYS 模式以保持响应）
var ui_node_path: NodePath = NodePath("")

## 是否显示暂停菜单
var show_pause_menu: bool = false

## 暂停菜单场景路径（如果 show_pause_menu = true）
var pause_menu_scene: String = ""

## 暂停菜单父节点路径（可选，默认为当前场景根节点）
var pause_menu_parent: NodePath = NodePath("")

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_PAUSE_GAME_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_PAUSE_GAME_DESC"
	metadata.keywords = ["pause", "game", "menu", "stop", "暂停", "游戏", "菜单", "停止"]
	metadata.builtin_icon = "Pause"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Pause Settings 分类
	properties.append({
		name = "Pause Settings",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# UI 节点路径（暂停时保持响应）
	properties.append({
		name = "ui_node_path",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否显示暂停菜单
	properties.append({
		name = "show_pause_menu",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Pause Menu 分类（条件显示）
	if show_pause_menu:
		properties.append({
			name = "Pause Menu",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		# 暂停菜单场景路径
		properties.append({
			name = "pause_menu_scene",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_FILE,
			hint_string = "*.tscn,*.scn",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 暂停菜单父节点路径
		properties.append({
			name = "pause_menu_parent",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PAUSE_GAME_NAME"))

	# 显示 UI 节点信息
	if not ui_node_path.is_empty():
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PAUSE_GAME_UI_NODE", {"node": str(ui_node_path)}))

	if show_pause_menu:
		if not pause_menu_scene.is_empty():
			var scene_name = FuseNodeUtils.get_path_display_name(pause_menu_scene)
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_PAUSE_GAME_SHOW_MENU_SCENE", {"scene": scene_name}))
		else:
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PAUSE_GAME_SHOW_MENU"))
	else:
		parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_PAUSE_GAME_PAUSE_ONLY"))

	resource_name = " ".join(parts)

## 动态属性设置
func _set(property: StringName, value_: Variant) -> bool:
	if property == "show_pause_menu":
		set(property, value_)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_info("暂停游戏逻辑")

	# 处理 UI 节点（在暂停前设置，确保 UI 能响应）
	if not ui_node_path.is_empty():
		var ui_node := context.get_node(ui_node_path)
		if ui_node:
			# 只有当 process_mode 是 INHERIT 或 PAUSABLE 时才需要修改
			if ui_node.process_mode in [Node.PROCESS_MODE_INHERIT, Node.PROCESS_MODE_PAUSABLE]:
				ui_node.process_mode = Node.PROCESS_MODE_ALWAYS
				_log_info_localized("FUSE_INSTRUCTION_PAUSE_GAME_UI_SET_ALWAYS", {"node": str(ui_node_path)})
		else:
			_log_warning_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(ui_node_path)})

	# 标准暂停游戏
	var scene_tree = Engine.get_main_loop()
	if scene_tree and scene_tree is SceneTree:
		scene_tree.paused = true
		_log_info_localized("FUSE_INSTRUCTION_PAUSE_GAME_PAUSED", {})
	else:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
		set_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 如果需要显示暂停菜单
	if show_pause_menu:
		# 验证场景路径
		if pause_menu_scene.is_empty():
			_log_warning_localized("FUSE_INSTRUCTION_PAUSE_GAME_NO_SCENE_PATH", {})
			_on_execution_completed()
			return

		# 加载暂停菜单场景
		var packed_scene = load(pause_menu_scene)
		if not packed_scene:
			_log_error_localized("FUSE_ERROR_PAUSE_MENU_SCENE_NOT_FOUND", {})
			set_error_localized("FUSE_ERROR_PAUSE_MENU_SCENE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
			finished.emit()
			return

		if not packed_scene is PackedScene:
			_log_error_localized("FUSE_ERROR_NOT_PACKED_SCENE", {"scene": pause_menu_scene})
			set_error_localized("FUSE_ERROR_NOT_PACKED_SCENE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": pause_menu_scene})
			finished.emit()
			return

		# 实例化暂停菜单
		var pause_menu_instance = packed_scene.instantiate()
		if not pause_menu_instance:
			_log_error_localized("FUSE_ERROR_FAILED_INSTANTIATE", {"scene": pause_menu_scene})
			set_error_localized("FUSE_ERROR_FAILED_INSTANTIATE", FuseError.ErrorType.RUNTIME_ERROR, {"scene": pause_menu_scene})
			finished.emit()
			return

		# 确定父节点
		var parent_node: Node
		if pause_menu_parent.is_empty():
			# 使用当前场景根节点
			parent_node = scene_tree.current_scene
		else:
			# 使用指定的父节点
			parent_node = context.get_node(pause_menu_parent)

		if not parent_node:
			_log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(pause_menu_parent)})
			set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(pause_menu_parent)})
			finished.emit()
			return

		# 添加暂停菜单到场景
		parent_node.add_child(pause_menu_instance)
		_log_info_localized("FUSE_INSTRUCTION_PAUSE_GAME_MENU_SHOWN", {"scene": FuseNodeUtils.get_path_display_name(pause_menu_scene)})

	# 同步完成
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 如果要显示暂停菜单，必须提供场景路径
	if show_pause_menu and pause_menu_scene.is_empty():
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_PAUSE_GAME_ERROR_NO_SCENE_PATH"))

	return errors

## 获取指令描述
func get_description() -> String:
	var desc := FuseLocalization.translate("FUSE_INSTRUCTION_PAUSE_GAME_NAME")

	if not ui_node_path.is_empty():
		desc += FuseLocalization.translate_format("FUSE_INSTRUCTION_PAUSE_GAME_DESC_UI_NODE", {"node": str(ui_node_path)})

	if show_pause_menu:
		desc += FuseLocalization.translate("FUSE_INSTRUCTION_PAUSE_GAME_DESC_AND_MENU")

	return desc

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 如果不显示暂停菜单，隐藏相关属性
	if not show_pause_menu:
		if property.name == "pause_menu_scene" or property.name == "pause_menu_parent":
			property.usage = PROPERTY_USAGE_NO_EDITOR
