@tool
class_name FuseEditorBootstrap extends RefCounted

## Fuse 编辑器侧引导
##
## 负责：本地化初始化、图标管理器、Inspector 插件注册、
## 上下文菜单插件、场景切换 resource_name 刷新。
## 持有 Inspector/上下文菜单实例引用供 teardown 清理。

var _plugin: EditorPlugin

# Inspector 插件实例（teardown 时移除）
var _fuse_plugin: EditorInspectorPlugin = null
var _input_key_plugin: EditorInspectorPlugin = null
var _instructions_array_plugin: EditorInspectorPlugin = null
# 上下文菜单插件实例
var _context_menu_plugin: FuseContextMenuPlugin = null

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin

func setup() -> void:
	# 1. 本地化（必须在所有其他操作之前）
	_init_localization()
	# 2. 图标管理器
	_init_icon_manager()
	# 3. Fuse 统一 Inspector 插件
	_fuse_plugin = preload("res://addons/fuse/editor/fuse_inspector_plugin.gd").new()
	_plugin.add_inspector_plugin(_fuse_plugin)
	print("Fuse 统一 Inspector 插件已注册")
	# 3.5. 指令数组编辑器插件 (Stage 2.1: ItemList 替换原生编辑器)
	_instructions_array_plugin = preload("res://addons/fuse/editor/instruction_selector/instructions_array_inspector_plugin.gd").new()
	_plugin.add_inspector_plugin(_instructions_array_plugin)
	print("Fuse 指令数组编辑器插件已注册")
	# 4. 输入键选择器 Inspector 插件
	_input_key_plugin = preload("res://addons/fuse/editor/input_key_selector/input_key_inspector_plugin.gd").new()
	_plugin.add_inspector_plugin(_input_key_plugin)
	print("输入键选择器 Inspector 插件已注册")
	# 5. 上下文菜单插件
	_register_context_menu_plugin()
	# 6. 场景切换信号（刷新 resource_name 显示）
	_plugin.scene_changed.connect(_on_scene_changed)

func teardown() -> void:
	# 逆序清理
	if _plugin.scene_changed.is_connected(_on_scene_changed):
		_plugin.scene_changed.disconnect(_on_scene_changed)
	_unregister_context_menu_plugin()
	if _instructions_array_plugin:
		_plugin.remove_inspector_plugin(_instructions_array_plugin)
		_instructions_array_plugin = null
	if _input_key_plugin:
		_plugin.remove_inspector_plugin(_input_key_plugin)
		_input_key_plugin = null
	if _fuse_plugin:
		_plugin.remove_inspector_plugin(_fuse_plugin)
		_fuse_plugin = null
	_cleanup_icon_manager()

## 初始化本地化系统
func _init_localization() -> void:
	var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")
	if FuseLocalization_class and FuseLocalization_class.has_method("init"):
		FuseLocalization_class.init()
		print("Fuse Localization 系统已初始化")
		if FuseLocalization_class.has_method("get_translation_stats"):
			var stats = FuseLocalization_class.get_translation_stats()
			print("  总翻译键: %d" % stats.total_keys)
			print("  中文覆盖率: %.1f%%" % stats.zh_CN_coverage)
			print("  英文覆盖率: %.1f%%" % stats.en_US_coverage)
			print("  当前语言: %s" % stats.current_locale)
	else:
		push_error("无法加载 FuseLocalization 系统")

## 初始化图标管理器
func _init_icon_manager() -> void:
	FuseIconManager.init()
	print("[FusePlugin] 图标管理器已初始化")

## 清理图标管理器
func _cleanup_icon_manager() -> void:
	FuseIconManager.cleanup()
	print("[FusePlugin] 图标管理器已清理")

## 注册上下文菜单插件
func _register_context_menu_plugin() -> void:
	var plugin_script := preload("res://addons/fuse/editor/context_menu/fuse_context_menu_plugin.gd")
	_context_menu_plugin = plugin_script.new()
	_context_menu_plugin.set_editor_plugin(_plugin)
	_plugin.add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE, _context_menu_plugin)
	print("[FusePlugin] 上下文菜单插件已注册")

## 清理上下文菜单插件
func _unregister_context_menu_plugin() -> void:
	if _context_menu_plugin != null:
		_plugin.remove_context_menu_plugin(_context_menu_plugin)
		_context_menu_plugin = null
		print("[FusePlugin] 上下文菜单插件已清理")

## 场景切换时刷新所有组件的 resource_name
func _on_scene_changed(scene_root: Node = null) -> void:
	if scene_root:
		_refresh_all_resource_names(scene_root)
		return
	var editor_interface = Engine.get_singleton("EditorInterface")
	if not editor_interface:
		return
	var root = editor_interface.get_edited_scene_root()
	if root:
		_refresh_all_resource_names(root)

## 递归遍历场景树，刷新所有组件的 resource_name
func _refresh_all_resource_names(node: Node) -> int:
	var count = 0
	if "action_runner" in node:
		var runner = node.get("action_runner")
		if runner and is_instance_valid(runner) and "instructions" in runner:
			for inst in runner.instructions:
				if inst and is_instance_valid(inst) and inst.has_method("_update_resource_name"):
					inst._update_resource_name()
					count += 1
	if "event_definition" in node:
		var event = node.get("event_definition")
		if event and is_instance_valid(event) and event.has_method("_update_resource_name"):
			event._update_resource_name()
			count += 1
	if node.has_method("_update_resource_name") and "target_node" in node:
		node._update_resource_name()
		count += 1
	for child in node.get_children():
		count += _refresh_all_resource_names(child)
	return count
