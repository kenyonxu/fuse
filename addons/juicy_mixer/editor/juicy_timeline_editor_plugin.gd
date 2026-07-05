@tool
class_name JuicyTimelineEditorPlugin
extends EditorPlugin

const JuicyTimelineEditor = preload("res://addons/juicy_mixer/editor/juicy_timeline_editor.gd")
const JuicyTimelineInspector = preload("res://addons/juicy_mixer/editor/juicy_timeline_inspector.gd")
const JuicyTimelineResourceCreator = preload("res://addons/juicy_mixer/editor/juicy_timeline_resource_creator.gd")

var timeline_editor: JuicyTimelineEditor
var timeline_inspector: JuicyTimelineInspector
var resource_creator: JuicyTimelineResourceCreator
var tree: Tree
static var editor: EditorInterface
static var instance: JuicyTimelineEditorPlugin

func _enter_tree():
	instance = self
	editor = get_editor_interface()
	print("Juicy Timeline编辑器插件已加载完成")

	
static func get_editor() -> EditorInterface:
	return editor

static func get_instance() -> JuicyTimelineEditorPlugin:
	if instance == null:
		instance = JuicyTimelineEditorPlugin.new()
		return instance
	else:
		return instance


func _exit_tree():

	# 移除属性检查器扩展
	if timeline_inspector:
		remove_inspector_plugin(timeline_inspector)
	
	# 移除工具菜单项
	remove_tool_menu_item("创建Juicy Timeline")
	
	print("Juicy Timeline编辑器插件已卸载")

func _has_main_screen():
	return false

func _get_plugin_name():
	return "Juicy Timeline"

func _create_timeline_resource():
	resource_creator.show_create_dialog()

func make_panel_visible(panel:Control):
	# 添加参数验证，避免传递null或无效对象给Godot内部API
	if not panel:
		print("JuicyTimelineEditorPlugin: panel参数为null，跳过")
		return
	
	if not panel is Control:
		print("JuicyTimelineEditorPlugin: panel参数不是Control类型: ", panel.get_class())
		return
	
	make_bottom_panel_item_visible(panel)
	print("JuicyTimelineEditorPlugin: 已设置panel可见: ", panel.get_class())
