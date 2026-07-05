@tool
extends EditorPlugin

# Timeline编辑器组件
const JuicyTimelineEditor = preload("res://addons/juicy_mixer/editor/juicy_timeline_editor.gd")
const JuicyTimelineInspector = preload("res://addons/juicy_mixer/editor/juicy_timeline_inspector.gd")
const JuicyTimelineResourceCreator = preload("res://addons/juicy_mixer/editor/juicy_timeline_resource_creator.gd")
const JuicyTimelineResource = preload("res://addons/juicy_mixer/resources/juicy_timeline_resource.gd")
const TargetHighlightManager = preload("res://addons/juicy_mixer/editor/target_highlight_manager.gd")

# 检查器插件
const AudioComponentInspector = preload("res://addons/juicy_mixer/editor/audio_component_inspector.gd")
const JuicyAudioPlayerInspector = preload("res://addons/juicy_mixer/editor/juicy_audio_player_inspector.gd")
const MusicPlayerInspector = preload("res://addons/juicy_mixer/editor/music_player_inspector.gd")

# 通用图标
const _icon = preload("res://icon.svg")
const _timeline_icon = preload("res://addons/juicy_mixer/icons/timeline.svg")

var timeline_editor: Control
var timeline_inspector: EditorInspectorPlugin
var audio_component_inspector: EditorInspectorPlugin
var audio_player_inspector: EditorInspectorPlugin
var music_player_inspector: EditorInspectorPlugin
var resource_creator: Object
var file_system_tree: Tree
var highlight_manager: RefCounted
var scenetree_tree: Tree  # 场景树控件引用

func _enter_tree():
	# 注册核心组件类型
	add_custom_type("JuicyContext", "RefCounted", preload("res://addons/juicy_mixer/core/juicy_context.gd"), _icon)
	add_custom_type("JuicyPropertyBuffer", "RefCounted", preload("res://addons/juicy_mixer/core/juicy_property_buffer.gd"), _icon)
	add_custom_type("JuicyDriverRegistry", "RefCounted", preload("res://addons/juicy_mixer/core/juicy_driver_registry.gd"), _icon)
	add_custom_type("JuicyDirector", "RefCounted", preload("res://addons/juicy_mixer/core/juicy_director.gd"), _icon)
	add_custom_type("JuicyFeedbackResource", "Resource", preload("res://addons/juicy_mixer/resources/juicy_feedback_resource.gd"), _icon)
	add_custom_type("JuicyMixer", "RefCounted", preload("res://addons/juicy_mixer/core/juicy_mixer.gd"), _icon)
	add_custom_type("JuicyDriver", "RefCounted", preload("res://addons/juicy_mixer/drivers/juicy_driver.gd"), _icon)
	add_custom_type("JuicyMixerEnums", "RefCounted", preload("res://addons/juicy_mixer/core/juicy_mixer_enums.gd"), _icon)

	# 方法反射辅助类
	add_custom_type("JuicyMethodInfo", "RefCounted", preload("res://addons/juicy_mixer/utils/juicy_method_info.gd"), _icon)
	add_custom_type("JuicyMethodReflection", "RefCounted", preload("res://addons/juicy_mixer/utils/juicy_method_reflection.gd"), _icon)
	add_custom_type("JuicyParameterEditor", "RefCounted", preload("res://addons/juicy_mixer/utils/juicy_parameter_editor.gd"), _icon)

	# 中间件
	add_custom_type("JuicyMiddleware", "RefCounted", preload("res://addons/juicy_mixer/middleware/juicy_middleware.gd"), _icon)
	add_custom_type("JuicyMiddlewarePipeline", "RefCounted", preload("res://addons/juicy_mixer/core/juicy_middleware_pipeline.gd"), _icon)

	# 事件系统
	add_custom_type("JuicyEventBuffer", "RefCounted", preload("res://addons/juicy_mixer/events/juicy_event_buffer.gd"), _icon)
	add_custom_type("JuicyEventScheduler", "RefCounted", preload("res://addons/juicy_mixer/events/juicy_event_scheduler.gd"), _icon)
	add_custom_type("JuicyEventHandler", "RefCounted", preload("res://addons/juicy_mixer/events/juicy_event_handler.gd"), _icon)
	add_custom_type("JuicyEvent", "RefCounted", preload("res://addons/juicy_mixer/events/juicy_event.gd"), _icon)

	# 池化系统
	add_custom_type("JuicyPoolItem", "RefCounted", preload("res://addons/juicy_mixer/core/juicy_pool_item.gd"), _icon)
	add_custom_type("JuicyContextPool", "RefCounted", preload("res://addons/juicy_mixer/core/juicy_context_pool.gd"), _icon)
	add_custom_type("JuicyObjectPool", "RefCounted", preload("res://addons/juicy_mixer/core/juicy_object_pool.gd"), _icon)
	add_custom_type("JuicyPoolManager", "RefCounted", preload("res://addons/juicy_mixer/core/juicy_pool_manager.gd"), _icon)

	# 中断系统
	add_custom_type("InterruptionState", "RefCounted", preload("res://addons/juicy_mixer/core/interruption_state.gd"), _icon)
	add_custom_type("ChannelInterruptionConfig", "Resource", preload("res://addons/juicy_mixer/resources/channel_interruption_config.gd"), _icon)
	add_custom_type("JuicyInterruptionManager", "RefCounted", preload("res://addons/juicy_mixer/core/juicy_interruption_manager.gd"), _icon)
	add_custom_type("InterruptionMiddleware", "RefCounted", preload("res://addons/juicy_mixer/middleware/interruption_middleware.gd"), _icon)

	# 状态管理
	add_custom_type("ContextStateManager", "RefCounted", preload("res://addons/juicy_mixer/core/context_state_manager.gd"), _icon)
	add_custom_type("PropertyStateManager", "RefCounted", preload("res://addons/juicy_mixer/core/property_state_manager.gd"), _icon)
	add_custom_type("StateRestorationMiddleware", "RefCounted", preload("res://addons/juicy_mixer/middleware/state_restoration_middleware.gd"), _icon)
	add_custom_type("EventHandlingMiddleware", "RefCounted", preload("res://addons/juicy_mixer/middleware/event_handling_middleware.gd"), _icon)
	add_custom_type("StateSnapshot", "RefCounted", preload("res://addons/juicy_mixer/core/state_snapshot.gd"), _icon)
	add_custom_type("RestorationConfig", "Resource", preload("res://addons/juicy_mixer/resources/restoration_config.gd"), _icon)

	# 音频资源
	add_custom_type("AudioVariant", "Resource", preload("res://addons/juicy_mixer/resources/audio/audio_variant.gd"), _icon)
	add_custom_type("AudioRandomizationConfig", "Resource", preload("res://addons/juicy_mixer/resources/audio/audio_randomization_config.gd"), _icon)
	add_custom_type("DuckingRule", "Resource", preload("res://addons/juicy_mixer/resources/audio/ducking_rule.gd"), _icon)
	add_custom_type("AudioMixingConfig", "Resource", preload("res://addons/juicy_mixer/resources/audio/audio_mixing_config.gd"), _icon)
	add_custom_type("AudioEventResource", "Resource", preload("res://addons/juicy_mixer/resources/audio/audio_event_resource.gd"), _icon)
	add_custom_type("AudioCategory", "Resource", preload("res://addons/juicy_mixer/resources/audio/audio_category.gd"), _icon)
	add_custom_type("GlobalAudioLimitConfig", "Resource", preload("res://addons/juicy_mixer/resources/audio/global_audio_limit_config.gd"), _icon)
	add_custom_type("AudioBinding", "Resource", preload("res://addons/juicy_mixer/resources/audio/audio_binding.gd"), _icon)
	add_custom_type("AudioComponent", "Resource", preload("res://addons/juicy_mixer/resources/audio/audio_component.gd"), _icon)

	# 音频核心
	add_custom_type("AudioUtils", "RefCounted", preload("res://addons/juicy_mixer/core/audio/audio_utils.gd"), _icon)
	add_custom_type("AudioVariationManager", "RefCounted", preload("res://addons/juicy_mixer/core/audio/audio_variation_manager.gd"), _icon)
	add_custom_type("AudioMixingController", "RefCounted", preload("res://addons/juicy_mixer/core/audio/audio_mixing_controller.gd"), _icon)
	add_custom_type("VirtualVoiceManager", "RefCounted", preload("res://addons/juicy_mixer/core/audio/virtual_voice_manager.gd"), _icon)
	add_custom_type("JuicyAudioPlayer", "Node", preload("res://addons/juicy_mixer/core/juicy_audio_player.gd"), _icon)
	add_custom_type("AudioManager", "Node", preload("res://addons/juicy_mixer/core/audio_manager.gd"), _icon)

	# 音乐资源
	add_custom_type("MusicTrackResource", "Resource", preload("res://addons/juicy_mixer/resources/music/music_track_resource.gd"), _icon)
	add_custom_type("MusicLayerResource", "Resource", preload("res://addons/juicy_mixer/resources/music/music_layer_resource.gd"), _icon)
	add_custom_type("MusicStateMap", "Resource", preload("res://addons/juicy_mixer/resources/music/music_state_map.gd"), _icon)
	add_custom_type("MusicPriorityEntry", "Resource", preload("res://addons/juicy_mixer/resources/music/music_priority_entry.gd"), _icon)
	add_custom_type("MusicPriorityConfig", "Resource", preload("res://addons/juicy_mixer/resources/music/music_priority_config.gd"), _icon)

	# 音乐核心
	add_custom_type("MusicManager", "Node", preload("res://addons/juicy_mixer/core/music_manager.gd"), _icon)
	add_custom_type("ActiveMusicState", "RefCounted", preload("res://addons/juicy_mixer/core/music/active_music_state.gd"), _icon)
	add_custom_type("MusicBusController", "RefCounted", preload("res://addons/juicy_mixer/core/music/music_bus_controller.gd"), _icon)
	add_custom_type("MusicTransitionScheduler", "RefCounted", preload("res://addons/juicy_mixer/core/music/music_transition_scheduler.gd"), _icon)
	add_custom_type("MusicEventHandler", "RefCounted", preload("res://addons/juicy_mixer/core/music/music_event_handler.gd"), _icon)
	add_custom_type("MusicPlayer", "Node", preload("res://addons/juicy_mixer/core/music_player.gd"), _icon)

	# Timeline
	add_custom_type("JuicyTrack", "Resource", preload("res://addons/juicy_mixer/resources/juicy_track.gd"), _timeline_icon)
	add_custom_type("JuicyKeyframe", "Resource", preload("res://addons/juicy_mixer/resources/juicy_keyframe.gd"), _timeline_icon)
	add_custom_type("JuicyParameterMapping", "Resource", preload("res://addons/juicy_mixer/resources/juicy_parameter_mapping.gd"), _timeline_icon)
	add_custom_type("TargetHighlightManager", "RefCounted", TargetHighlightManager, _icon)
	add_custom_type("JuicyTimelineResource", "Resource", JuicyTimelineResource, _icon)

	# 初始化Timeline编辑器组件
	print("正在初始化Timeline编辑器...")

	# 创建并添加编辑器面板到底部区域
	timeline_editor = JuicyTimelineEditor.new()
	# 设置 plugin 引用，用于更新编辑器叠加层
	timeline_editor.plugin = self
	# 确保编辑器能够扩展
	timeline_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_control_to_bottom_panel(timeline_editor, "Juicy Timeline")
	print("Timeline编辑器面板已创建并添加")

	# 创建属性检查器扩展
	timeline_inspector = JuicyTimelineInspector.new()
	# 设置 TimelineEditor 引用，用于更新高亮
	timeline_inspector.set_timeline_editor(timeline_editor)
	add_inspector_plugin(timeline_inspector)
	print("Timeline检查器扩展已添加")

	# 创建 AudioComponent 检查器扩展
	audio_component_inspector = AudioComponentInspector.new()
	add_inspector_plugin(audio_component_inspector)
	print("AudioComponent检查器扩展已添加")

	# 创建 JuicyAudioPlayer 检查器扩展
	audio_player_inspector = JuicyAudioPlayerInspector.new()
	add_inspector_plugin(audio_player_inspector)
	print("JuicyAudioPlayer检查器扩展已添加")

	# 创建 MusicPlayer 检查器扩展
	music_player_inspector = MusicPlayerInspector.new()
	add_inspector_plugin(music_player_inspector)
	print("MusicPlayer检查器扩展已添加")

	# 创建资源创建工具
	resource_creator = JuicyTimelineResourceCreator.new()
	add_tool_menu_item("创建Juicy Timeline", _create_timeline_resource)
	print("Timeline资源创建工具已添加")

	# 设置文件系统选择监听
	_setup_file_system_monitor()

	# 初始化目标高亮管理器
	highlight_manager = TargetHighlightManager.get_instance()

	# 初始化场景树高亮支持
	_setup_scenetree_highlight()

	print("JuicyMixer V3 plugin enabled")

func _exit_tree():
	# 移除自定义类型
	remove_custom_type("JuicyContext")
	remove_custom_type("JuicyPropertyBuffer")
	remove_custom_type("JuicyDriverRegistry")
	remove_custom_type("JuicyDirector")
	remove_custom_type("JuicyFeedbackResource")
	remove_custom_type("JuicyMixer")
	remove_custom_type("JuicyDriver")
	remove_custom_type("JuicyMixerEnums")

	# 移除方法反射辅助类
	remove_custom_type("JuicyMethodInfo")
	remove_custom_type("JuicyMethodReflection")
	remove_custom_type("JuicyParameterEditor")

	remove_custom_type("JuicyMiddleware")
	remove_custom_type("JuicyMiddlewarePipeline")
	remove_custom_type("JuicyEventBuffer")
	remove_custom_type("JuicyEventScheduler")
	remove_custom_type("JuicyEventHandler")
	remove_custom_type("JuicyEvent")

	# 移除池化系统组件
	remove_custom_type("JuicyPoolItem")
	remove_custom_type("JuicyContextPool")
	remove_custom_type("JuicyObjectPool")
	remove_custom_type("JuicyPoolManager")

	# 移除中断系统组件
	remove_custom_type("InterruptionState")
	remove_custom_type("ChannelInterruptionConfig")
	remove_custom_type("JuicyInterruptionManager")
	remove_custom_type("InterruptionMiddleware")

	# 移除状态管理组件
	remove_custom_type("ContextStateManager")
	remove_custom_type("PropertyStateManager")
	remove_custom_type("StateRestorationMiddleware")
	remove_custom_type("EventHandlingMiddleware")
	remove_custom_type("StateSnapshot")
	remove_custom_type("RestorationConfig")

	# 移除音频资源类型
	remove_custom_type("AudioVariant")
	remove_custom_type("AudioRandomizationConfig")
	remove_custom_type("DuckingRule")
	remove_custom_type("AudioMixingConfig")
	remove_custom_type("AudioEventResource")
	remove_custom_type("AudioCategory")
	remove_custom_type("GlobalAudioLimitConfig")
	remove_custom_type("AudioBinding")
	remove_custom_type("AudioComponent")

	# 移除音频核心类
	remove_custom_type("AudioUtils")
	remove_custom_type("AudioVariationManager")
	remove_custom_type("AudioMixingController")
	remove_custom_type("VirtualVoiceManager")
	remove_custom_type("JuicyAudioPlayer")
	remove_custom_type("AudioManager")

	# 移除音乐资源类型
	remove_custom_type("MusicTrackResource")
	remove_custom_type("MusicLayerResource")
	remove_custom_type("MusicStateMap")
	remove_custom_type("MusicPriorityEntry")
	remove_custom_type("MusicPriorityConfig")

	# 移除音乐核心类
	remove_custom_type("MusicManager")
	remove_custom_type("ActiveMusicState")
	remove_custom_type("MusicBusController")
	remove_custom_type("MusicTransitionScheduler")
	remove_custom_type("MusicEventHandler")
	remove_custom_type("MusicPlayer")

	# 移除Timeline相关类型
	remove_custom_type("JuicyTrack")
	remove_custom_type("JuicyKeyframe")
	remove_custom_type("JuicyParameterMapping")
	remove_custom_type("JuicyTimelineResource")
	remove_custom_type("TargetHighlightManager")

	# 移除Timeline编辑器组件
	if timeline_editor:
		remove_control_from_bottom_panel(timeline_editor)
		timeline_editor.queue_free()
		timeline_editor = null

	if timeline_inspector:
		remove_inspector_plugin(timeline_inspector)
		timeline_inspector = null

	if audio_component_inspector:
		remove_inspector_plugin(audio_component_inspector)
		audio_component_inspector = null

	if audio_player_inspector:
		remove_inspector_plugin(audio_player_inspector)
		audio_player_inspector = null

	if music_player_inspector:
		remove_inspector_plugin(music_player_inspector)
		music_player_inspector = null

	if resource_creator:
		remove_tool_menu_item("创建Juicy Timeline")
		resource_creator = null

	if file_system_tree:
		file_system_tree.cell_selected.disconnect(_on_file_selected)
		file_system_tree = null

	# 清理高亮管理器
	highlight_manager = null
	scenetree_tree = null

	print("JuicyMixer V3 plugin disabled")

func _get_plugin_name():
	return "JuicyMixer V3"

func _get_plugin_icon():
	return preload("res://icon.svg")

# Timeline编辑器相关方法
func _handles(object):
	return object is JuicyTimelineResource

func _edit(object):
	if object is JuicyTimelineResource:
		if timeline_editor:
			timeline_editor.edit_timeline(object)
			# 自动切换到Timeline编辑器面板
			make_bottom_panel_item_visible(timeline_editor)

		if timeline_inspector:
			timeline_inspector.edit_timeline(object)

func _make_visible(visible):
	if timeline_editor:
		timeline_editor.visible = visible
		# 如果没有Timeline资源被编辑，显示提示信息
		if visible and not timeline_editor.current_timeline:
			timeline_editor._show_no_timeline_hint()
		elif visible and timeline_editor.current_timeline:
			timeline_editor._hide_no_timeline_hint()

func _create_timeline_resource():
	if resource_creator:
		resource_creator.show_create_dialog()

func _setup_file_system_monitor():
	# 设置文件系统dock选择监听
	var file_system_dock = EditorInterface.get_file_system_dock()
	# 获取文件系统树控件（结构可能在Godot版本间有所变化）
	for child in file_system_dock.get_children():
		if child is Tree:
			file_system_tree = child
			file_system_tree.cell_selected.connect(_on_file_selected)
			break

func _on_file_selected():
	var selected_paths = EditorInterface.get_selected_paths()
	print("文件被选中: ", selected_paths)

	if selected_paths.size() > 0:
		var path = selected_paths[0]
		if path.ends_with(".tres") or path.ends_with(".res"):
			var resource = load(path)
			if resource is JuicyTimelineResource:
				print("检测到Timeline资源被选中，调用编辑...")
				_edit(resource)

func _forward_canvas_draw_over_viewport(viewport_control: Control):
	"""绘制2D场景叠加层 - 用于显示目标节点高亮标记"""
	if not highlight_manager:
		return

	var viewport = viewport_control.get_viewport()
	var highlights = highlight_manager.get_visible_highlights(viewport)

	if highlights.is_empty():
		return

	for highlight in highlights:
		if not highlight.node:
			continue

		# 使用 get_viewport_transform() 获取到视口的变换
		var viewport_transform = highlight.node.get_viewport_transform()
		var world_pos = highlight.node.global_position if highlight.node is Node2D else Vector2.ZERO
		var size = highlight.cached_global_rect.size

		# 使用视口变换转换位置
		var viewport_pos = viewport_transform * world_pos

		# 应用缩放到大小
		var scale = viewport_transform.get_scale().x
		var scaled_size = size * scale

		# 调整矩形位置，使其中心对齐目标位置
		var rect_pos = viewport_pos - scaled_size / 2
		var rect = Rect2(rect_pos, scaled_size)

		# 绘制半透明实心矩形（更容易看到）
		var fill_color = Color(highlight.color.r, highlight.color.g, highlight.color.b, 0.3)
		viewport_control.draw_rect(rect, fill_color, true)
		# 绘制边框
		viewport_control.draw_rect(rect, highlight.color, false, 3.0)

## 场景树高亮支持
func _setup_scenetree_highlight():
	"""初始化场景树高亮功能"""
	# 获取编辑器基础控件
	var base_control = get_editor_interface().get_base_control()

	# 通过反射获取场景树控件
	var scenetree_dock = _get_child_of_type(base_control, "SceneTreeDock", true)
	if not scenetree_dock:
		print("Warning: Could not find SceneTreeDock")
		return

	var scenetree_editor = _get_child_of_type(scenetree_dock, "SceneTreeEditor")
	if not scenetree_editor:
		print("Warning: Could not find SceneTreeEditor")
		return

	scenetree_tree = _get_child_of_type(scenetree_editor, "Tree")
	if not scenetree_tree:
		print("Warning: Could not find SceneTree Tree control")
		return

func _get_child_of_type(node: Node, type_name: String, recursive: bool = false) -> Node:
	"""获取指定类型的子节点

	@param node: 父节点
	@param type_name: 类型名称
	@param recursive: 是否递归查找
	@return: 找到的子节点，未找到返回 null
	"""
	var children = node.find_children("", type_name, recursive, false)
	if children.is_empty():
		return null
	return children[0]

func _process(delta):
	"""每帧处理，用于更新场景树高亮"""
	# 处理场景树高亮
	if scenetree_tree:
		_process_scenetree_highlights()

func _process_scenetree_highlights():
	"""处理场景树高亮显示"""
	# 遍历场景树的所有可见项
	var current_item = scenetree_tree.get_root()
	var item_count = 0
	while current_item:
		item_count += 1
		_process_scene_tree_item(current_item)
		current_item = current_item.get_next_visible()

func _process_scene_tree_item(item: TreeItem):
	"""处理单个场景树项的高亮

	@param item: TreeItem
	"""
	# 获取节点路径
	var node_path = item.get_metadata(0)
	if not node_path:
		return

	# 获取实际节点
	var edited_root = EditorInterface.get_edited_scene_root()
	if not edited_root:
		return

	var node = edited_root.get_node_or_null(node_path)
	if not node:
		return

	# 检查节点是否有高亮元数据
	if node.has_meta("timeline_track_highlight"):
		var color = node.get_meta("timeline_track_highlight")
		# 设置背景色（使用30%透明度的轨道颜色）
		var bg_color = Color(color.r, color.g, color.b, 0.3)
		item.set_custom_bg_color(0, bg_color)
	else:
		# 清除背景色
		item.clear_custom_bg_color(0)
