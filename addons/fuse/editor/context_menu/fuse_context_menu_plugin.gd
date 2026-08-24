# 文件：addons/fuse/editor/context_menu/fuse_context_menu_plugin.gd
@tool
class_name FuseContextMenuPlugin extends EditorContextMenuPlugin

## 预加载指令生成器依赖
const MethodSelectorDialog = preload("res://addons/fuse/editor/instruction_generator/method_selector_dialog.gd")
const InstructionGenerator = preload("res://addons/fuse/editor/instruction_generator/instruction_generator.gd")
const InstructionRegistry = preload("res://addons/fuse/editor/instruction_selector/instruction_registry.gd")
const PropertyInstructionGenerator = preload("res://addons/fuse/editor/instruction_generator/property_instruction_generator.gd")

## 输出级别子菜单的级别顺序（不含 ERROR：阈值语义下与 NONE 等价，均为只放行 ERROR）
const _LOG_LEVEL_MENU_ITEMS: Array[FuseLogger.LogLevel] = [
	FuseLogger.LogLevel.NONE,
	FuseLogger.LogLevel.WARNING,
	FuseLogger.LogLevel.INFO,
	FuseLogger.LogLevel.DEBUG,
]

## FuseContextMenuPlugin - Fuse 上下文菜单插件
##
## 监听场景树右键菜单事件，为选中的 Trigger 节点提供合并功能。
## 这是 Fuse 上下文菜单系统的入口类。

## ==================== 成员变量 ====================

## 插件引用
var _editor_plugin: EditorPlugin = null

## TriggerMerger 实例
var _trigger_merger: TriggerMerger = null

## TriggerSplitter 实例
var _trigger_splitter: TriggerSplitter = null

## LogLevelBatchSetter 实例
var _log_level_setter: LogLevelBatchSetter = null

## 保存当前选中的路径（用于回调）
var _pending_paths: PackedStringArray = []

## ==================== 初始化 ====================

## 设置编辑器插件引用
## @param plugin 编辑器插件实例
func set_editor_plugin(plugin: EditorPlugin) -> void:
	_editor_plugin = plugin
	if plugin != null:
		_trigger_merger = TriggerMerger.new(
			plugin.get_editor_interface(),
			plugin.get_undo_redo()
		)
		_trigger_splitter = TriggerSplitter.new(
			plugin.get_editor_interface(),
			plugin.get_undo_redo()
		)
		_log_level_setter = LogLevelBatchSetter.new(
			plugin.get_editor_interface(),
			plugin.get_undo_redo()
		)

## ==================== EditorContextMenuPlugin 重写 ====================

## 当场景树右键菜单弹出时调用
## @param paths 当前选中的节点路径数组
func _popup_menu(paths: PackedStringArray) -> void:
	if _editor_plugin == null:
		return

	var edited_scene_root := _editor_plugin.get_editor_interface().get_edited_scene_root()
	if edited_scene_root == null:
		return

	# 从路径获取实际的节点
	var nodes: Array[Node] = []
	for path in paths:
		if path.is_empty():
			continue
		var node := edited_scene_root.get_node_or_null(path)
		if node != null:
			nodes.append(node)

	# 检查是否可以合并选中的节点
	if TriggerMerger.can_merge(nodes):
		_pending_paths = paths
		add_context_menu_item("合并为多事件触发器", Callable(self, "_on_merge_triggers"))

	# 检查是否可以拆分选中的节点（单个 MultiEventTrigger）
	if nodes.size() == 1 and TriggerSplitter.can_split(nodes[0]):
		_pending_paths = paths
		add_context_menu_item("拆分为独立触发器", Callable(self, "_on_split_trigger"))

	# 指令生成器 - 支持任意节点
	if nodes.size() == 1:
		_pending_paths = paths
		add_context_menu_item("生成指令...", Callable(self, "_on_generate_instruction"))

	# 批量设置输出级别 - 选中节点子树内存在可修改的 Fuse 组件时显示
	# 子菜单 PopupMenu 每次 popup 后会被编辑器释放，必须在 _popup_menu 里新建
	var collected: Dictionary = LogLevelBatchSetter.collect_components(nodes, edited_scene_root)
	if not (collected["applicable"] as Array).is_empty():
		_pending_paths = paths
		var level_menu := PopupMenu.new()
		for level: int in _LOG_LEVEL_MENU_ITEMS:
			level_menu.add_item(FuseLogger.LogLevel.keys()[level])
		level_menu.index_pressed.connect(_on_log_level_menu_id)
		add_context_submenu_item("Fuse: 输出级别", level_menu)

## ==================== 信号处理 ====================

## 合并触发器回调
## @param _paths 选中的节点路径数组（注意：Godot 传递的格式不是标准路径，使用 _pending_paths 替代）
func _on_merge_triggers(_paths: PackedStringArray) -> void:
	if _editor_plugin == null or _trigger_merger == null:
		push_error("[FuseContextMenuPlugin] _editor_plugin or _trigger_merger is null!")
		return

	var edited_scene_root := _editor_plugin.get_editor_interface().get_edited_scene_root()
	if edited_scene_root == null:
		push_error("[FuseContextMenuPlugin] edited_scene_root is null!")
		return

	# 使用保存的路径（_pending_paths），因为回调参数的格式不是标准路径
	var nodes: Array[Node] = []
	for path in _pending_paths:
		if path.is_empty():
			continue
		var node := edited_scene_root.get_node_or_null(path)
		if node != null:
			nodes.append(node)

	# 执行合并
	if nodes.size() >= 2:
		_trigger_merger.merge(nodes)
	else:
		push_error("[FuseContextMenuPlugin] Not enough nodes to merge: ", nodes.size())

## 拆分触发器回调
## @param _paths 选中的节点路径数组（注意：Godot 传递的格式不是标准路径，使用 _pending_paths 替代）
func _on_split_trigger(_paths: PackedStringArray) -> void:
	if _editor_plugin == null or _trigger_splitter == null:
		push_error("[FuseContextMenuPlugin] _editor_plugin or _trigger_splitter is null!")
		return

	var edited_scene_root := _editor_plugin.get_editor_interface().get_edited_scene_root()
	if edited_scene_root == null:
		push_error("[FuseContextMenuPlugin] edited_scene_root is null!")
		return

	# 使用保存的路径（_pending_paths），因为回调参数的格式不是标准路径
	if _pending_paths.is_empty():
		push_error("[FuseContextMenuPlugin] _pending_paths is empty!")
		return

	var node := edited_scene_root.get_node_or_null(_pending_paths[0])
	if node == null:
		push_error("[FuseContextMenuPlugin] Node not found: ", _pending_paths[0])
		return

	# 执行拆分
	_trigger_splitter.split(node)

## 输出级别子菜单回调
## @param index 子菜单项索引（对应 _LOG_LEVEL_MENU_ITEMS）
func _on_log_level_menu_id(index: int) -> void:
	if _editor_plugin == null or _log_level_setter == null:
		push_error("[FuseContextMenuPlugin] _editor_plugin or _log_level_setter is null!")
		return

	if index < 0 or index >= _LOG_LEVEL_MENU_ITEMS.size():
		return

	var edited_scene_root := _editor_plugin.get_editor_interface().get_edited_scene_root()
	if edited_scene_root == null:
		push_error("[FuseContextMenuPlugin] edited_scene_root is null!")
		return

	# 使用保存的路径（_pending_paths），因为子菜单信号不带节点信息
	var nodes: Array[Node] = []
	for path in _pending_paths:
		if path.is_empty():
			continue
		var node := edited_scene_root.get_node_or_null(path)
		if node != null:
			nodes.append(node)

	if nodes.is_empty():
		return

	_log_level_setter.apply(nodes, edited_scene_root, _LOG_LEVEL_MENU_ITEMS[index])

## 生成指令回调
## @param _paths 选中的节点路径数组（注意：Godot 传递的格式不是标准路径，使用 _pending_paths 替代）
func _on_generate_instruction(_paths: PackedStringArray) -> void:
	if _editor_plugin == null:
		push_error("[FuseContextMenuPlugin] _editor_plugin is null!")
		return

	var edited_scene_root := _editor_plugin.get_editor_interface().get_edited_scene_root()
	if edited_scene_root == null:
		push_error("[FuseContextMenuPlugin] edited_scene_root is null!")
		return

	# 获取选中节点
	if _pending_paths.is_empty():
		push_error("[FuseContextMenuPlugin] _pending_paths is empty!")
		return

	var node := edited_scene_root.get_node_or_null(_pending_paths[0])
	if node == null:
		push_error("[FuseContextMenuPlugin] Node not found: ", _pending_paths[0])
		return

	# 创建并显示方法/属性选择对话框
	var dialog: Window = MethodSelectorDialog.new()
	dialog.set_target_node(node)
	dialog.method_selected.connect(_on_method_selected.bind(node))
	dialog.property_selected.connect(_on_property_selected.bind(node))

	_editor_plugin.get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered(Vector2i(700, 500))

## 方法选中回调
func _on_method_selected(method_info: Dictionary, target_class: String, use_variables: bool, node: Node) -> void:
	var result = InstructionGenerator.generate_instruction(target_class, method_info, "", use_variables)
	_handle_generation_result(result)

## 属性选中回调
## @param property_info: 选中的属性信息
## @param target_class: 目标类名
## @param mode: 生成模式 (0=SET, 1=GET, 2=SET_AND_GET)
## @param use_variables: 是否使用变量绑定（仅 SET 有效）
## @param node: 目标节点
func _on_property_selected(property_info: PropertyInfo, target_class: String, mode: int, use_variables: bool, node: Node) -> void:
	# 将 PropertyInfo 转换为字典（PropertyInstructionGenerator 接受字典格式）
	var prop_dict := {
		"name": property_info.name,
		"type": property_info.type,
		"hint": property_info.hint,
		"hint_string": property_info.hint_string,
		"default_value": property_info.default_value,
	}

	# SET 指令
	if mode == 0 or mode == 2:
		var set_result = PropertyInstructionGenerator.generate_set_instruction(target_class, prop_dict, "", use_variables)
		_handle_generation_result(set_result)

	# GET 指令
	if mode == 1 or mode == 2:
		var get_result = PropertyInstructionGenerator.generate_get_instruction(target_class, prop_dict)
		_handle_generation_result(get_result)

## 处理生成结果（注册 + 刷新编辑器）
func _handle_generation_result(result: Dictionary) -> void:
	if result.get("success", false):
		print("[Fuse] 指令已生成: %s" % result.get("path", ""))

		var script = load(result.get("path", ""))
		if script:
			InstructionRegistry.register_instruction(script)
			print("[Fuse] 指令已注册: %s" % result.get("path", ""))

		_editor_plugin.get_editor_interface().get_resource_filesystem().scan()
	else:
		push_error("[Fuse] 指令生成失败: %s" % result.get("error", "未知错误"))
