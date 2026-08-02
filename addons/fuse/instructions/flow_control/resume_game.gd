@tool
@icon("res://addons/fuse/icons/builtin/Play.png")
extends BaseInstruction
class_name ResumeGame

## 恢复游戏指令

## UI 节点路径（可选，恢复时还原为 INHERIT 模式）
var ui_node_path: NodePath = NodePath("")

## 是否关闭暂停菜单
var close_pause_menu: bool = false

## 暂停菜单节点路径（如果 close_pause_menu = true）
var pause_menu_node: NodePath = NodePath("")

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_RESUME_GAME_NAME"
	metadata.category_key = "FUSE_CATEGORY_FLOW_CONTROL"
	metadata.description_key = "FUSE_INSTRUCTION_RESUME_GAME_DESC"
	metadata.keywords = ["resume", "game", "unpause", "menu", "time", "恢复", "游戏", "取消暂停", "菜单", "时间"]
	metadata.builtin_icon = "Play"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	# Resume Settings 分类
	properties.append({
		name = "Resume Settings",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	# UI 节点路径（恢复时还原 process_mode）
	properties.append({
		name = "ui_node_path",
		type = TYPE_NODE_PATH,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 是否关闭暂停菜单
	properties.append({
		name = "close_pause_menu",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# Pause Menu 分类（条件显示）
	if close_pause_menu:
		properties.append({
			name = "Pause Menu",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		# 暂停菜单节点路径
		properties.append({
			name = "pause_menu_node",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts := []

	parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RESUME_GAME_NAME"))

	# 显示 UI 节点信息
	if not ui_node_path.is_empty():
		parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_RESUME_GAME_UI_NODE", {"node": str(ui_node_path)}))

	if close_pause_menu:
		if not pause_menu_node.is_empty():
			parts.append(FuseLocalization.translate_format("FUSE_INSTRUCTION_RESUME_GAME_CLOSE_MENU_NODE", {"node": str(pause_menu_node)}))
		else:
			parts.append(FuseLocalization.translate("FUSE_INSTRUCTION_RESUME_GAME_CLOSE_MENU"))

	resource_name = " ".join(parts)

## 动态属性设置
func _set(property: StringName, value_: Variant) -> bool:
	if property == "close_pause_menu":
		set(property, value_)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_info("恢复游戏逻辑")

	# 处理 UI 节点（在恢复前还原 process_mode）
	if not ui_node_path.is_empty():
		var ui_node := context.get_node(ui_node_path)
		if ui_node:
			# 还原为 INHERIT（默认值）
			ui_node.process_mode = Node.PROCESS_MODE_INHERIT
			_log_info_localized("FUSE_INSTRUCTION_RESUME_GAME_UI_RESTORED", {"node": str(ui_node_path)})
		else:
			_log_warning_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(ui_node_path)})

	# 如果需要关闭暂停菜单
	if close_pause_menu:
		# 验证节点路径
		if pause_menu_node.is_empty():
			_log_warning_localized("FUSE_INSTRUCTION_RESUME_GAME_NO_NODE_PATH", {})
			# 继续执行恢复逻辑
		else:
			# 获取暂停菜单节点
			var menu_node := context.get_node(pause_menu_node)
			if not menu_node:
				_log_warning_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(pause_menu_node)})
				# 继续执行恢复逻辑
			else:
				# 关闭暂停菜单（使用 queue_free 延迟删除）
				menu_node.queue_free()
				_log_info_localized("FUSE_INSTRUCTION_RESUME_GAME_MENU_CLOSED", {"node": str(pause_menu_node)})

	# 标准恢复游戏
	var scene_tree = Engine.get_main_loop()
	if scene_tree and scene_tree is SceneTree:
		scene_tree.paused = false
		_log_info_localized("FUSE_INSTRUCTION_RESUME_GAME_RESUMED", {})
	else:
		_log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
		set_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", FuseError.ErrorType.RUNTIME_ERROR, {})
		finished.emit()
		return

	# 同步完成
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	# 如果要关闭暂停菜单，必须提供节点路径
	if close_pause_menu and pause_menu_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_INSTRUCTION_RESUME_GAME_ERROR_NO_NODE_PATH"))

	return errors

## 获取指令描述
func get_description() -> String:
	var desc := FuseLocalization.translate("FUSE_INSTRUCTION_RESUME_GAME_NAME")

	if not ui_node_path.is_empty():
		desc += FuseLocalization.translate_format("FUSE_INSTRUCTION_RESUME_GAME_DESC_UI_NODE", {"node": str(ui_node_path)})

	if close_pause_menu:
		desc += FuseLocalization.translate("FUSE_INSTRUCTION_RESUME_GAME_DESC_CLOSE_MENU")

	return desc

## 属性验证
func _validate_property(property: Dictionary) -> void:
	# 如果不关闭暂停菜单，隐藏相关属性
	if not close_pause_menu:
		if property.name == "pause_menu_node":
			property.usage = PROPERTY_USAGE_NO_EDITOR
