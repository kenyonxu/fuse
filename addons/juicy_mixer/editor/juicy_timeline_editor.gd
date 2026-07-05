@tool
class_name JuicyTimelineEditor
extends Control

const JuicyTimelineCanvas = preload("res://addons/juicy_mixer/editor/juicy_timeline_canvas.gd")
const JuicyTrackEditor = preload("res://addons/juicy_mixer/editor/juicy_track_editor.gd")
const JuicyTimeRuler = preload("res://addons/juicy_mixer/editor/juicy_time_ruler.gd")
const UndoRedoManager = preload("res://addons/juicy_mixer/utils/undo_redo_manager.gd")
const TargetHighlightManager = preload("res://addons/juicy_mixer/editor/target_highlight_manager.gd")

signal timeline_changed(timeline: JuicyTimelineResource)
signal playback_time_changed(time: float)

var current_timeline: JuicyTimelineResource
var timeline_canvas: JuicyTimelineCanvas
var track_editor: JuicyTrackEditor

# 撤销/重做管理器
var undo_redo_manager: UndoRedoManager

# UI组件
var toolbar: HBoxContainer
var play_button: Button
var pause_button: Button
var stop_button: Button
var time_label: Label
var zoom_slider: HSlider
var timeline_scroll: HScrollBar
var time_ruler: JuicyTimeRuler  # 使用独立的时间标尺组件
var status_bar: HBoxContainer
var status_label: Label
var undo_button: Button
var redo_button: Button

# Plugin 引用（用于更新编辑器叠加层）
var plugin: EditorPlugin

# 播放控制
var is_playing: bool = false
var playback_time: float = 0.0
var playback_speed: float = 1.0
var zoom_level: float = 1.0

# 时间轴设置
var pixels_per_second: float = 100.0
var timeline_length: float = 10.0
var snap_enabled: bool = true
var snap_interval: float = 0.1

# 智能操作区域（双容器架构）
var context_actions_container: HBoxContainer
var global_actions_container: HBoxContainer    # 全局功能容器（不重建）
var track_specific_container: HBoxContainer   # 轨道专属容器（动态重建）
var context_separator: VSeparator
var _edit_mode_button: Button  # 保存编辑模式按钮引用
var _drag_mode_button: Button  # 保存拖动模式按钮引用
var _batch_drag_button: Button  # 保存批量拖动模式按钮引用
var _target_node_button: Button                # 保存目标选择按钮引用
var _target_node_hint_label: Label             # 目标节点提示标签（内联显示）

# 目标节点提示Control（浮动显示在toolbar中）
var _target_node_hint: Control

func _init():
	name = "Timeline编辑器"
	set_custom_minimum_size(Vector2(600, 400))  # 减小最小尺寸，提高适配性
	# 调整自身大小
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 初始化撤销/重做管理器
	undo_redo_manager = UndoRedoManager.new()
	
	_setup_ui()

func _ready():
	# 基础设置，让容器的默认行为生效
	# 初始化滚动条比例
	call_deferred("_update_scroll_bar_ratio")
	
	# 启用GUI输入处理以支持快捷键
	gui_input.connect(_on_shortcut_input)
	
	# 连接draw信号用于绘制目标节点提示
	draw.connect(_on_draw)
	
	# 创建目标节点提示Label
	_create_target_node_hint()

## 绘制回调（用于绘制目标节点提示）
func _on_draw():
	"""绘制回调，用于绘制目标节点提示"""
	# 目标节点提示现在使用Panel+Label，不需要在这里绘制

## 快捷键输入处理
func _on_shortcut_input(event: InputEvent):
	"""处理快捷键输入"""
	if event is InputEventKey and event.pressed:
		# Ctrl+Z: 撤销
		if event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed):
			_on_undo_pressed()
			accept_event()
		# Ctrl+Y: 重做
		elif event.keycode == KEY_Y and (event.ctrl_pressed or event.meta_pressed):
			_on_redo_pressed()
			accept_event()
		# Ctrl+Shift+Z: 重做（替代方案）
		elif event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed) and event.shift_pressed:
			_on_redo_pressed()
			accept_event()

func _setup_ui():


	# 创建主布局 - 不设置flags，让子组件自己控制	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # 强制填满根节点
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)
	
	# 创建工具栏
	_create_toolbar(main_vbox)
	
	# 创建编辑区域
	var edit_area = HSplitContainer.new()
	edit_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit_area.split_offset = 300  # 减小轨道编辑器初始宽度，为画布留出更多空间
	main_vbox.add_child(edit_area)

	# 创建轨道编辑器
	track_editor = JuicyTrackEditor.new()

	edit_area.add_child(track_editor)

	# 创建时间轴画布区域
	var canvas_area = VBoxContainer.new()
	canvas_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit_area.add_child(canvas_area)
	
	# 创建时间标尺
	_create_time_ruler(canvas_area)
	
	# 创建时间轴画布
	timeline_canvas = JuicyTimelineCanvas.new()
	timeline_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timeline_canvas.timeline_editor = self
	canvas_area.add_child(timeline_canvas)
	
	# 创建时间轴滚动条
	timeline_scroll = HScrollBar.new()
	timeline_scroll.min_value = 0.0
	timeline_scroll.max_value = timeline_length
	timeline_scroll.value = 0.0  # 初始位置设为0，确保从左边开始
	timeline_scroll.value_changed.connect(_on_timeline_scroll_changed)
	canvas_area.add_child(timeline_scroll)

	# 创建状态栏
	_create_status_bar(main_vbox)

	# 连接信号
	_connect_signals()

func _create_toolbar(parent: VBoxContainer):
	var editor_theme = EditorInterface.get_editor_theme()

	toolbar = HBoxContainer.new()
	toolbar.size_flags_vertical = Control.SIZE_FILL  # 固定高度，不扩展
	parent.add_child(toolbar)

	# 撤销/重做控制组
	var undo_redo_group = HBoxContainer.new()
	toolbar.add_child(undo_redo_group)

	undo_button = Button.new()
	undo_button.icon = editor_theme.get_icon("UndoRedo", "EditorIcons")
	undo_button.tooltip_text = "撤销 (Ctrl+Z)"
	undo_button.custom_minimum_size = Vector2(30, 0)
	undo_button.disabled = true
	undo_button.pressed.connect(_on_undo_pressed)
	undo_redo_group.add_child(undo_button)

	redo_button = Button.new()
	redo_button.icon = editor_theme.get_icon("Redo", "EditorIcons")
	redo_button.tooltip_text = "重做 (Ctrl+Y)"
	redo_button.custom_minimum_size = Vector2(30, 0)
	redo_button.disabled = true
	redo_button.pressed.connect(_on_redo_pressed)
	undo_redo_group.add_child(redo_button)

	# 分隔符
	toolbar.add_child(VSeparator.new())

	# 播放控制组
	var playback_group = HBoxContainer.new()
	toolbar.add_child(playback_group)

	play_button = Button.new()
	play_button.icon = editor_theme.get_icon("Play", "EditorIcons")
	play_button.tooltip_text = "播放"
	play_button.custom_minimum_size = Vector2(30, 0)  # 设置按钮最小尺寸
	play_button.pressed.connect(_on_play_pressed)
	playback_group.add_child(play_button)

	pause_button = Button.new()
	pause_button.icon = editor_theme.get_icon("Pause", "EditorIcons")
	pause_button.tooltip_text = "暂停"
	pause_button.custom_minimum_size = Vector2(30, 0)
	pause_button.pressed.connect(_on_pause_pressed)
	playback_group.add_child(pause_button)

	stop_button = Button.new()
	stop_button.icon = editor_theme.get_icon("Stop", "EditorIcons")
	stop_button.tooltip_text = "停止"
	stop_button.custom_minimum_size = Vector2(30, 0)
	stop_button.pressed.connect(_on_stop_pressed)
	playback_group.add_child(stop_button)

	# 分隔符
	toolbar.add_child(VSeparator.new())

	# 时间显示组
	var time_group = HBoxContainer.new()
	toolbar.add_child(time_group)

	var time_label_prefix = Label.new()
	time_label_prefix.text = "时间:"
	time_group.add_child(time_label_prefix)

	time_label = Label.new()
	time_label.text = "0.00s"
	time_label.custom_minimum_size = Vector2(60, 0)  # 为时间标签预留空间
	time_group.add_child(time_label)

	# 分隔符
	toolbar.add_child(VSeparator.new())

	# 视图控制组
	var view_group = HBoxContainer.new()
	view_group.size_flags_horizontal = Control.SIZE_FILL  # 使用SIZE_FILL而不是SIZE_EXPAND_FILL，避免挤出context_actions_container
	toolbar.add_child(view_group)
	
	var zoom_label = Label.new()
	zoom_label.text = "缩放:"
	view_group.add_child(zoom_label)
	
	zoom_slider = HSlider.new()
	zoom_slider.min_value = 0.1
	zoom_slider.max_value = 5.0
	zoom_slider.value = 1.0
	zoom_slider.step = 0.1
	zoom_slider.size_flags_horizontal = Control.SIZE_FILL  # 使用SIZE_FILL而不是SIZE_EXPAND_FILL，防止无限扩展
	zoom_slider.custom_minimum_size = Vector2(100, 0)  # 设置滑块最小宽度
	zoom_slider.value_changed.connect(_on_zoom_changed)
	view_group.add_child(zoom_slider)

	var zoom_value_label = Label.new()
	zoom_value_label.text = "1.0x"
	zoom_value_label.custom_minimum_size = Vector2(40, 0)
	zoom_slider.value_changed.connect(func(value: float): zoom_value_label.text = "%.1fx" % value)
	view_group.add_child(zoom_value_label)

	# 吸附控制
	var snap_check = CheckButton.new()
	snap_check.text = "吸附"
	snap_check.button_pressed = snap_enabled
	snap_check.toggled.connect(_on_snap_toggled)
	view_group.add_child(snap_check)

	# 创建智能操作区域
	_create_context_actions(toolbar)

func _create_status_bar(parent: VBoxContainer):
	status_bar = HBoxContainer.new()
	status_bar.custom_minimum_size = Vector2(0, 25)
	status_bar.size_flags_vertical = Control.SIZE_FILL  # 固定高度，不扩展
	parent.add_child(status_bar)

	# 状态信息分隔符
	status_bar.add_child(VSeparator.new())

	# 状态标签
	status_label = Label.new()
	status_label.text = "就绪"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_bar.add_child(status_label)

	# 轨道数量信息
	var track_info_label = Label.new()
	track_info_label.text = "轨道: 0"
	track_info_label.custom_minimum_size = Vector2(80, 0)
	status_bar.add_child(track_info_label)

	# 时间轴长度信息
	var duration_info_label = Label.new()
	duration_info_label.text = "时长: 0.0s"
	duration_info_label.custom_minimum_size = Vector2(80, 0)
	status_bar.add_child(duration_info_label)

func _create_time_ruler(parent: VBoxContainer):
	time_ruler = JuicyTimeRuler.new()
	time_ruler.size_flags_vertical = Control.SIZE_FILL  # 固定高度，不扩展
	parent.add_child(time_ruler)
	
	# 连接TimeRuler信号
	time_ruler.time_selected.connect(_on_ruler_time_selected)
	time_ruler.time_dragged.connect(_on_ruler_time_dragged)
	time_ruler.jump_to_start_requested.connect(_on_ruler_jump_to_start)
	time_ruler.jump_to_end_requested.connect(_on_ruler_jump_to_end)

# TimeRuler信号处理函数
func _on_ruler_time_selected(time: float):
	playback_time = time
	_update_playback_head()
	_update_time_display()

func _on_ruler_time_dragged(time: float):
	playback_time = time
	_update_playback_head()
	_update_time_display()

func _on_ruler_jump_to_start():
	playback_time = 0.0
	_update_playback_head()
	_update_time_display()

func _on_ruler_jump_to_end():
	if current_timeline:
		playback_time = current_timeline.timeline_duration
		_update_playback_head()
		_update_time_display()

func _refresh_time_ruler():
	if not time_ruler:
		return
	
	# 更新TimeRuler配置
	time_ruler.start_time = timeline_scroll.value
	time_ruler.pixels_per_second = pixels_per_second
	time_ruler.zoom_level = zoom_level
	time_ruler.snap_enabled = snap_enabled
	time_ruler.snap_interval = snap_interval
	
	# 触发重绘
	time_ruler.queue_redraw()

func _force_update_time_ruler():
	"""强制更新时间标尺，确保滚动条变化后立即生效"""
	_refresh_time_ruler()

func _connect_signals():
	if timeline_canvas:
		timeline_canvas.timeline_changed.connect(_on_canvas_timeline_changed)
		timeline_canvas.playback_time_changed.connect(_on_canvas_time_changed)
		timeline_canvas.track_selected.connect(_on_track_selected)

	if track_editor:
		track_editor.track_added.connect(_on_track_added)
		# 🔥 移除 track_removed 信号连接 - 轨道删除已经在 _handle_context_menu_action() 中完成
		# 不需要额外的信号处理，而且会导致双重删除问题
		# track_editor.track_removed.connect(_on_track_removed)
		track_editor.track_reordered.connect(_on_track_reordered)
		track_editor.track_selected.connect(_on_track_selected)

	if undo_redo_manager:
		undo_redo_manager.undo_redo_changed.connect(_on_undo_redo_changed)

## 撤销/重做状态改变处理
func _on_undo_redo_changed(can_undo: bool, can_redo: bool):
	"""撤销/重做状态改变时更新按钮"""
	_update_undo_redo_buttons()

func edit_timeline(timeline: JuicyTimelineResource):
	current_timeline = timeline

	if timeline_canvas:
		timeline_canvas.set_timeline(timeline)

	if track_editor:
		track_editor.set_timeline(timeline)

	# 连接Timeline的zoom_changed信号
	if timeline:
		if not timeline.zoom_changed.is_connected(_on_timeline_zoom_changed):
			timeline.zoom_changed.connect(_on_timeline_zoom_changed)

		# 初始化zoom_slider值
		zoom_slider.value = timeline.timeline_zoom
		zoom_level = timeline.timeline_zoom

	# 更新时间轴长度
	if timeline:
		timeline_length = timeline.timeline_duration

		# 添加null检查，避免在timeline_scroll未初始化时访问
		if timeline_scroll:
			timeline_scroll.max_value = timeline_length
			timeline_scroll.value = 0.0  # 重置滚动条位置到左边
		_update_scroll_bar_ratio()  # 使用专门的方法更新比例
		_update_status_bar("已加载 Timeline: " + str(timeline.resource_path))
	else:
		if timeline_canvas:
			timeline_canvas.set_timeline(null)
		if track_editor:
			track_editor.set_timeline(null)
		_update_status_bar("无 Timeline")

func _process(delta):
	if is_playing and current_timeline:
		playback_time += delta * playback_speed
		
		if playback_time >= current_timeline.timeline_duration:
			playback_time = current_timeline.timeline_duration
			_on_stop_pressed()
		
		_update_time_display()
		_update_playback_head()
		_update_property_preview()

## 更新属性预览
func _update_property_preview():
	"""更新属性预览"""
	if not current_timeline:
		return
	
	# 获取选中的 Property Track
	var selected_track = timeline_canvas.get_selected_track()
	if selected_track and selected_track is JuicyPropertyTrack:
		var property_track = selected_track as JuicyPropertyTrack
		var value = property_track.get_value_at_time(playback_time, null)
		
		# 在状态栏显示当前值
		if status_label:
			var value_str = str(value)
			if value is float:
				status_label.text = "当前值: %.3f" % value
			elif value is Vector2:
				status_label.text = "当前值: (%.2f, %.2f)" % [value.x, value.y]
			elif value is Vector3:
				status_label.text = "当前值: (%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
			else:
				status_label.text = "当前值: " + value_str

func _update_time_display():
	time_label.text = "%.2fs" % playback_time

func _update_playback_head():
	if timeline_canvas:
		timeline_canvas.set_playback_head(playback_time)

func _on_play_pressed():
	is_playing = true
	play_button.disabled = true
	pause_button.disabled = false

func _on_pause_pressed():
	is_playing = false
	play_button.disabled = false
	pause_button.disabled = true

func _on_stop_pressed():
	is_playing = false
	playback_time = 0.0
	play_button.disabled = false
	pause_button.disabled = true
	_update_time_display()
	_update_playback_head()

func _on_zoom_changed(value: float):
	"""处理zoom_slider变化"""
	zoom_level = value
	if timeline_canvas:
		timeline_canvas.set_zoom(zoom_level)
	
	# 更新Timeline资源的zoom（会触发zoom_changed信号）
	if current_timeline:
		current_timeline.timeline_zoom = value
	
	# 更新滚动条页面比例
	_update_scroll_bar_ratio()
	
	# 刷新时间标尺
	_refresh_time_ruler()
	queue_redraw()

func _on_timeline_zoom_changed(new_zoom: float):
	"""响应Timeline的zoom_changed信号"""
	# 避免循环更新：如果值相同则跳过
	if abs(zoom_slider.value - new_zoom) < 0.01:
		return
	
	# 更新UI显示
	zoom_slider.value = new_zoom
	zoom_level = new_zoom
	
	if timeline_canvas:
		timeline_canvas.set_zoom(new_zoom)
	
	# 更新滚动条页面比例
	_update_scroll_bar_ratio()
	
	# 刷新时间标尺
	_refresh_time_ruler()
	queue_redraw()

func _on_snap_toggled(enabled: bool):
	snap_enabled = enabled
	if timeline_canvas:
		timeline_canvas.set_snap_enabled(enabled, snap_interval)
	if time_ruler:
		time_ruler.snap_enabled = enabled
		_refresh_time_ruler()

func _on_timeline_scroll_changed(value: float):
	if timeline_canvas:
		timeline_canvas.set_view_offset(value)

	# 更新时间标尺显示范围
	_refresh_time_ruler()

	# 额外确保时间标尺立即响应滚动条变化
	call_deferred("_force_update_time_ruler")

func _on_canvas_timeline_changed():
	# 当Canvas中的Timeline发生变化时，同步更新Track Editor
	if track_editor and current_timeline:
		track_editor.refresh_track_list()

	timeline_changed.emit(current_timeline)

func _on_canvas_time_changed(time: float):
	playback_time = time
	_update_time_display()

func _on_track_added(track: JuicyTrack):
	# 轨道已经在 TrackEditor 中添加过了，这里只需要更新UI和发送信号
	if current_timeline:
		timeline_changed.emit(current_timeline)
		_update_status_bar("已添加轨道: " + track.track_name)

# 🔥 移除 _on_track_removed() 函数
# 这个函数会导致双重删除问题：
# 1. _handle_context_menu_action() 已经调用了 remove_track()
# 2. 这个函数又会调用 remove_track_at() 导致第二次删除
# 而且使用了错误的索引（全局索引 vs property_tracks索引）
# 轨道删除后的 UI 更新已经由 refresh_track_list() 处理
func _on_track_reordered(from_index: int, to_index: int):
	if current_timeline:
		var all_tracks = current_timeline.get_all_tracks()
		if from_index >= 0 and from_index < all_tracks.size():
			var track = all_tracks[from_index]
			var track_type = track.get_track_type() if track.has_method("get_track_type") else "Property"
			current_timeline.remove_track(track)
			# 重新添加到新位置
			current_timeline.add_track(track, track_type)
			timeline_changed.emit(current_timeline)

func _on_track_selected(track: JuicyTrack):
	if timeline_canvas:
		timeline_canvas.select_track(track)

	# 不在这里直接操作按钮，完全由_update_context_actions处理
	# 更新智能操作区域
	_update_context_actions(track)

	# 直接更新目标节点提示（避免依赖get_selected_track()的返回值）
	update_target_node_hint_from_track(track)

	# 🔥 新增：更新场景高亮
	_update_scene_highlight(track)

	# 连接轨道的 changed 信号，监听属性变化
	if track:
		# 先断开之前的连接（如果有）
		if track.changed.is_connected(_on_track_property_changed):
			track.changed.disconnect(_on_track_property_changed)
		# 连接新的信号
		if not track.changed.is_connected(_on_track_property_changed):
			track.changed.connect(_on_track_property_changed)

## 更新场景中的目标节点高亮
func _update_scene_highlight(track: JuicyTrack):
	"""更新场景中的目标节点高亮

	@param track: 选中的轨道，null 表示取消选择
	"""
	var highlight_manager = TargetHighlightManager.get_instance()
	if not highlight_manager:
		return

	var viewport = EditorInterface.get_editor_viewport_2d()
	if not viewport:
		return

	if track:
		# 清除之前的高亮，然后添加新的（当前UI仅支持单轨选择）
		highlight_manager.clear_all()
		highlight_manager.add_highlight(track, viewport)
		# 强制更新编辑器的2D叠加层
		if plugin:
			plugin.update_overlays()
	else:
		# 取消选择时清除所有高亮
		highlight_manager.clear_all()
		# 强制更新编辑器的2D叠加层
		if plugin:
			plugin.update_overlays()

func set_snap_interval(interval: float):
	snap_interval = interval
	if timeline_canvas:
		timeline_canvas.set_snap_enabled(snap_enabled, snap_interval)

func set_pixels_per_second(pps: float):
	pixels_per_second = pps
	if timeline_canvas:
		timeline_canvas.set_pixels_per_second(pps)
	# 刷新时间标尺
	_refresh_time_ruler()
	queue_redraw()

# 显示/隐藏无Timeline提示信息
func _show_no_timeline_hint():
	"""显示无Timeline资源时的提示信息"""
	if timeline_canvas:
		timeline_canvas.show_no_timeline_hint()

func _hide_no_timeline_hint():
	"""隐藏无Timeline资源时的提示信息"""
	if timeline_canvas:
		timeline_canvas.hide_no_timeline_hint()

func _update_status_bar(message: String = ""):
	"""更新状态栏信息"""
	if not status_bar:
		return

	# 更新状态消息
	if status_label and not message.is_empty():
		status_label.text = message

	# 更新轨道和时长信息
	if current_timeline and status_bar.get_child_count() >= 3:
		var track_info_label = status_bar.get_child(2) as Label
		var duration_info_label = status_bar.get_child(3) as Label

		if track_info_label and duration_info_label:
			# 🔥 修改：使用 timeline_tracks
			var all_tracks = current_timeline.timeline_tracks  # 🔥 修改
			track_info_label.text = "轨道: " + str(all_tracks.size())
			duration_info_label.text = "时长: %.1fs" % current_timeline.timeline_duration

func _create_context_actions(parent: HBoxContainer):
	"""创建智能操作区域（双容器架构：全局功能 + 轨道专属）"""
	var editor_theme = EditorInterface.get_editor_theme()

	# 添加分隔符
	context_separator = VSeparator.new()
	context_separator.custom_minimum_size = Vector2(10, 0)  # 确保分隔线可见
	parent.add_child(context_separator)

	# 创建智能操作主容器
	context_actions_container = HBoxContainer.new()
	parent.add_child(context_actions_container)

	# 🔥 新增：创建全局功能容器（只创建一次，不重建）
	global_actions_container = HBoxContainer.new()
	context_actions_container.add_child(global_actions_container)

	# 🔥 新增：添加分隔符（视觉分隔两个区域）
	var actions_separator = VSeparator.new()
	actions_separator.custom_minimum_size = Vector2(10, 0)  # 确保分隔线可见
	context_actions_container.add_child(actions_separator)

	# 🔥 新增：创建轨道专属容器（根据轨道类型动态重建）
	track_specific_container = HBoxContainer.new()
	context_actions_container.add_child(track_specific_container)

	# 初始化全局功能区域
	_initialize_global_actions()

	# 初始化轨道专属区域（显示提示）
	var hint_label = Label.new()
	hint_label.text = "选择轨道查看相关操作"
	hint_label.modulate = Color.GRAY
	track_specific_container.add_child(hint_label)

func _initialize_global_actions():
	"""初始化全局功能区域（只调用一次）

	全局功能对所有轨道类型都可见，不随轨道切换重建
	"""
	var editor_theme = EditorInterface.get_editor_theme()

	# 创建目标节点选择按钮
	_target_node_button = Button.new()
	_target_node_button.icon = editor_theme.get_icon("Node", "EditorIcons")
	_target_node_button.tooltip_text = "选择目标节点"
	_target_node_button.custom_minimum_size = Vector2(30, 0)
	_target_node_button.pressed.connect(_on_target_node_picker_pressed.bind(null))
	_target_node_button.visible = true  # 始终可见
	_target_node_button.disabled = true  # 初始状态禁用，等待选择轨道
	global_actions_container.add_child(_target_node_button)

	# 🔥 修改：创建目标节点提示 Label（内联显示，不使用浮动 Panel）
	_target_node_hint_label = Label.new()
	_target_node_hint_label.text = ""
	_target_node_hint_label.modulate = Color.GRAY
	_target_node_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_target_node_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	global_actions_container.add_child(_target_node_hint_label)

func _update_context_actions(track: JuicyTrack):
	"""根据选中的轨道类型更新智能操作按钮"""
	if not context_actions_container:
		return

	if not track_specific_container:
		return

	# 优化1：在未选中轨道时，隐藏目标节点提示
	if not track:
		_update_target_node_hint_display("")

	# 先隐藏状态切换按钮（在清空前）
	if _edit_mode_button:
		_edit_mode_button.visible = false

	# 隐藏拖动模式按钮
	if _drag_mode_button:
		_drag_mode_button.visible = false

	# 隐藏批量拖动模式按钮
	if _batch_drag_button:
		_batch_drag_button.visible = false

	# 立即重置按钮变量为null，避免引用已删除的对象
	_edit_mode_button = null
	_drag_mode_button = null
	_batch_drag_button = null

	# 🔥 修改：只清空轨道专属容器（track_specific_container），保留全局功能容器（global_actions_container）
	for child in track_specific_container.get_children():
		track_specific_container.remove_child(child)
		child.queue_free()

	var editor_theme = EditorInterface.get_editor_theme()

	# 🔥 优化：根据轨道选择状态启用/禁用目标选择按钮
	if _target_node_button:
		_target_node_button.disabled = (track == null)

	# 根据轨道类型创建不同的按钮
	if not track:
		# 未选中轨道，显示提示（不显示任何操作按钮）
		var hint_label = Label.new()
		hint_label.text = "选择轨道查看相关操作"
		hint_label.modulate = Color.GRAY
		track_specific_container.add_child(hint_label)
		return

	match track.get_track_type():
		"Feedback":
			_create_feedback_track_actions(editor_theme, track)
		"Property":
			_create_property_track_actions(editor_theme, track)
		"Method":
			_create_method_track_actions(editor_theme, track)
		"Event":
			_create_event_track_actions(editor_theme, track)

func _create_feedback_track_actions(editor_theme: Theme, track: JuicyFeedbackTrack):
	"""创建Feedback Track的操作按钮"""

	var edit_mode_button = Button.new()
	edit_mode_button.custom_minimum_size = Vector2(30, 0)
	edit_mode_button.tooltip_text = "切换编辑模式 (传统/可视化Clip)"
	edit_mode_button.pressed.connect(_on_edit_mode_toggled)
	edit_mode_button.visible = true  # 确保按钮创建时默认可见
	track_specific_container.add_child(edit_mode_button)

	# 保存按钮引用（类级别变量）
	_edit_mode_button = edit_mode_button

	# 根据当前编辑模式设置图标
	var current_mode = timeline_canvas.get_edit_mode() if timeline_canvas else 0
	if current_mode == 1:  # 可视化Clip模式
		edit_mode_button.icon = editor_theme.get_icon("GuiToggleOn", "EditorIcons")
	else:
		edit_mode_button.icon = editor_theme.get_icon("GuiToggleOff", "EditorIcons")

func _create_property_track_actions(editor_theme: Theme, track: JuicyPropertyTrack):
	"""创建Property Track的操作按钮"""

	# 添加关键帧按钮
	var add_keyframe_button = Button.new()
	add_keyframe_button.icon = editor_theme.get_icon("KeyNext", "EditorIcons")
	add_keyframe_button.tooltip_text = "在播放头位置添加关键帧"
	add_keyframe_button.custom_minimum_size = Vector2(30, 0)
	add_keyframe_button.pressed.connect(_on_add_keyframe_pressed)
	track_specific_container.add_child(add_keyframe_button)

	# 添加拖动模式切换按钮
	var drag_mode_button = Button.new()
	drag_mode_button.custom_minimum_size = Vector2(30, 0)
	drag_mode_button.tooltip_text = "拖动模式：点击切换时间/值拖动"
	drag_mode_button.pressed.connect(_on_drag_mode_toggled)
	drag_mode_button.visible = true
	track_specific_container.add_child(drag_mode_button)

	# 立即保存按钮引用（在添加到容器后）
	_drag_mode_button = drag_mode_button

	# 根据当前拖动模式设置图标
	var current_drag_mode = timeline_canvas.get_drag_mode() if timeline_canvas else 0
	_update_drag_mode_button_icon(current_drag_mode)

	# 添加批量拖动模式切换按钮
	var batch_drag_button = Button.new()
	batch_drag_button.custom_minimum_size = Vector2(30, 0)
	batch_drag_button.tooltip_text = "批量拖动模式：点击启用/禁用"
	batch_drag_button.pressed.connect(_on_batch_drag_toggled)
	batch_drag_button.visible = true
	track_specific_container.add_child(batch_drag_button)

	# 立即保存按钮引用（在添加到容器后）
	_batch_drag_button = batch_drag_button

	# 根据当前批量拖动模式设置图标
	var batch_enabled = timeline_canvas.get_batch_drag_enabled() if timeline_canvas else false
	_update_batch_drag_button_icon(batch_enabled)

	# 🔥 目标节点选择器按钮已移至全局功能区域（_initialize_global_actions）
	# 不再需要在这里重复创建
	# 直接更新目标节点提示（避免依赖get_selected_track()的返回值）
	update_target_node_hint_from_track(track)

func _create_method_track_actions(editor_theme: Theme, track: JuicyMethodTrack):
	"""创建Method Track的操作按钮"""
	var edit_method_button = Button.new()
	edit_method_button.icon = editor_theme.get_icon("ListSelect", "EditorIcons")
	edit_method_button.tooltip_text = "编辑方法触发配置"
	edit_method_button.custom_minimum_size = Vector2(30, 0)
	edit_method_button.pressed.connect(_on_edit_method_pressed)
	edit_method_button.disabled = true  # 暂时禁用，等待TODO完成
	track_specific_container.add_child(edit_method_button)

func _create_event_track_actions(editor_theme: Theme, track: JuicyEventTrack):
	"""创建Event Track的操作按钮"""
	var edit_event_button = Button.new()
	edit_event_button.icon = editor_theme.get_icon("EditorCommandPalette", "EditorIcons")
	edit_event_button.tooltip_text = "编辑事件触发配置"
	edit_event_button.custom_minimum_size = Vector2(30, 0)
	edit_event_button.pressed.connect(_on_edit_event_pressed)
	track_specific_container.add_child(edit_event_button)

func _on_edit_mode_toggled():
	"""切换编辑模式"""

	if not timeline_canvas:
		return

	var current_mode = timeline_canvas.get_edit_mode()
	var new_mode = 1 if current_mode == 0 else 0

	timeline_canvas.set_edit_mode(new_mode)

	# 更新按钮图标
	var track = timeline_canvas.get_selected_track()

	if track and track is JuicyFeedbackTrack:
		_update_context_actions(track)

func _on_add_keyframe_pressed():
	"""在播放头位置添加关键帧"""
	var track = timeline_canvas.get_selected_track()
	if track and track is JuicyPropertyTrack:
		var property_track = track as JuicyPropertyTrack
		
		# 检查是否已存在相同位置的关键帧
		for keyframe in property_track.keyframes:
			if abs(keyframe.time - playback_time) < 0.001:
				_update_status_bar("关键帧已存在于此位置")
				return
		
		# 使用 Property Track 的 create_keyframe 方法创建正确类型的关键帧
		var keyframe = property_track.create_keyframe(playback_time)
		
		property_track.keyframes.append(keyframe)
		timeline_canvas.queue_redraw()
		timeline_changed.emit(current_timeline)
		_update_status_bar("已添加关键帧于: %.2fs" % playback_time)

func _on_target_node_picker_pressed(track: JuicyTrack = null):
	"""打开目标节点选择器（支持所有轨道类型）

	@param track: 如果为null，使用当前选中的轨道
	"""

	# 如果没有传入轨道，使用当前选中的轨道
	if not track:
		track = timeline_canvas.get_selected_track() if timeline_canvas else null

	if not track:
		_update_status_bar("请先选择一个轨道")
		return

	# 获取当前编辑的场景
	var editor_interface = Engine.get_singleton("EditorInterface")
	var edited_root = editor_interface.get_edited_scene_root()

	if edited_root:
		# 创建节点树对话框
		var node_dialog = AcceptDialog.new()
		node_dialog.title = "选择目标节点"
		node_dialog.size = Vector2(400, 500)
		node_dialog.unresizable = false

		var vbox = VBoxContainer.new()
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		node_dialog.add_child(vbox)

		var label = Label.new()
		label.text = "选择要控制的目标节点:"
		vbox.add_child(label)

		var tree = Tree.new()
		tree.set_columns(1)
		tree.set_column_titles_visible(false)
		tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(tree)

		# 填充节点树
		_populate_node_tree(tree, edited_root)

		# AcceptDialog默认自带"确定"按钮，这里只添加"取消"按钮
		node_dialog.add_button("取消", false)

		# 存储对话框引用以便在关闭时清理
		node_dialog.set_meta("track", track)

		# 保存当前选中的轨道，以便在对话框关闭后恢复
		var current_track = track

		node_dialog.confirmed.connect(func():
			var selected = tree.get_selected()
			if selected:
				var node_path = selected.get_metadata(0)
				current_track.target = node_path
				_update_status_bar("已设置目标节点: " + str(node_path))
				# 重绘画布和状态栏
				if timeline_canvas:
					timeline_canvas.queue_redraw()
				# 延迟重新选择轨道，确保对话框完全关闭后再重建按钮
				# 同时也延迟更新目标节点提示，避免线程安全问题
				call_deferred("_reselect_track_after_dialog", current_track)
				call_deferred("update_target_node_hint_from_track", current_track)
		)
		
		# 将对话框添加到编辑器主窗口而不是场景树
		var base_control = editor_interface.get_base_control()
		if base_control:
			base_control.add_child(node_dialog)
			# 使用popup_centered而不是popup_exclusive_centered，避免重复父节点错误
			node_dialog.popup_centered()
			# 在对话框关闭时自动清理（延迟执行，确保对话框操作完成）
			node_dialog.close_requested.connect(func():
				call_deferred("_cleanup_dialog", node_dialog)
			)

func _cleanup_dialog(dialog: AcceptDialog):
	"""清理对话框"""
	if dialog and dialog.get_parent():
		dialog.get_parent().remove_child(dialog)
	if dialog:
		dialog.queue_free()
	
	# 强制刷新UI
	if toolbar:
		toolbar.queue_redraw()
	if context_actions_container:
		context_actions_container.queue_redraw()
		context_actions_container.visible = true  # 确保容器可见

func _populate_node_tree(tree: Tree, node: Node, parent_item: TreeItem = null):
	"""递归填充节点树"""
	var item = tree.create_item(parent_item)
	item.set_text(0, node.name)
	# 修复：使用 get_path_to() 获取相对于场景根节点的路径，避免编辑器路径前缀
	var editor_interface = Engine.get_singleton("EditorInterface")
	if editor_interface:
		var edited_root = editor_interface.get_edited_scene_root()
		if edited_root:
			var relative_path = edited_root.get_path_to(node)
			item.set_metadata(0, relative_path)
		else:
			item.set_metadata(0, node.get_path())
	else:
		item.set_metadata(0, node.get_path())
	
	# 添加子节点
	for child in node.get_children():
		_populate_node_tree(tree, child, item)

func _on_edit_method_pressed():
	"""编辑方法触发"""
	var track = timeline_canvas.get_selected_track()
	if track and track is JuicyMethodTrack:
		_update_status_bar("方法编辑 - 请在Inspector中编辑")
		# TODO: 可以打开一个专门的方法编辑对话框

func _on_drag_mode_toggled():
	"""切换拖动模式"""
	if not timeline_canvas:
		return
	
	var current_mode = timeline_canvas.get_drag_mode()
	var new_mode = 1 if current_mode == 0 else 0
	
	timeline_canvas.set_drag_mode(new_mode)
	
	# 更新按钮图标
	_update_drag_mode_button_icon(new_mode)
	
	# 更新状态栏提示
	var mode_text = "时间拖动模式" if new_mode == 0 else "值拖动模式"
	_update_status_bar("已切换到: " + mode_text)

func _update_drag_mode_button_icon(drag_mode: int):
	"""更新拖动模式按钮图标"""
	if not _drag_mode_button:
		return
	
	var editor_theme = EditorInterface.get_editor_theme()
	if not editor_theme:
		return
	
	if drag_mode == 0:  # 时间拖动
		_drag_mode_button.icon = editor_theme.get_icon("ArrowRight", "EditorIcons")
		_drag_mode_button.tooltip_text = "时间拖动模式 (点击切换到值拖动)"
	else:  # 值拖动
		_drag_mode_button.icon = editor_theme.get_icon("ArrowUp", "EditorIcons")
		_drag_mode_button.tooltip_text = "值拖动模式 (点击切换到时间拖动)"

func _on_batch_drag_toggled():
	"""切换批量拖动模式"""
	if not timeline_canvas:
		return
	
	var current_enabled = timeline_canvas.get_batch_drag_enabled()
	var new_enabled = not current_enabled
	
	timeline_canvas.set_batch_drag_enabled(new_enabled)
	
	# 更新按钮图标
	_update_batch_drag_button_icon(new_enabled)
	
	# 更新状态栏提示
	var mode_text = "批量拖动模式已启用" if new_enabled else "单个拖动模式"
	_update_status_bar(mode_text)

func _update_batch_drag_button_icon(enabled: bool):
	"""更新批量拖动模式按钮图标"""
	if not _batch_drag_button:
		return
	
	var editor_theme = EditorInterface.get_editor_theme()
	if not editor_theme:
		return
	
	if enabled:
		_batch_drag_button.icon = editor_theme.get_icon("BoxMultiple", "EditorIcons")
		_batch_drag_button.tooltip_text = "批量拖动模式已启用 (点击禁用)"
	else:
		_batch_drag_button.icon = editor_theme.get_icon("ThemeSelectAll", "EditorIcons")
		_batch_drag_button.tooltip_text = "单个拖动模式 (点击启用批量拖动)"

func _on_edit_event_pressed():
	"""编辑事件触发"""
	var track = timeline_canvas.get_selected_track()
	if track and track is JuicyEventTrack:
		_update_status_bar("事件编辑 - 请在Inspector中编辑")
		# TODO: 可以打开一个专门的事件编辑对话框

func _update_scroll_bar_ratio():
	"""更新滚动条的页面大小，确保正确的显示"""
	# 添加null检查，避免在timeline_scroll未初始化时访问
	if not timeline_scroll:
		return
	
	if get_rect().size.x > 0 and timeline_length > 0:
		var visible_width = get_rect().size.x
		var total_width = timeline_length * pixels_per_second * zoom_level
		var visible_time = visible_width / (pixels_per_second * zoom_level)

		# 确保页面大小不会超过总长度，并且留出一些操作空间
		visible_time = min(visible_time, timeline_length * 0.8)  # 最多80%的可见范围

		timeline_scroll.page = visible_time  # 使用page属性设置可见时间范围

func _update_edit_mode_button_icon():
	"""更新编辑模式按钮图标"""
	var edit_mode_button = get_meta("_edit_mode_button") if has_meta("_edit_mode_button") else null
	if not edit_mode_button:
		return
	
	var editor_theme = EditorInterface.get_editor_theme()
	if not editor_theme:
		return
	
	var current_mode = timeline_canvas.get_edit_mode() if timeline_canvas else 0
	if current_mode == 1:  # 可视化Clip模式
		edit_mode_button.icon = editor_theme.get_icon("GuiToggleOn", "EditorIcons")
		edit_mode_button.tooltip_text = "切换到传统模式"
	else:
		edit_mode_button.icon = editor_theme.get_icon("GuiToggleOff", "EditorIcons")
		edit_mode_button.tooltip_text = "切换到可视化Clip模式"

## 撤销操作
func _on_undo_pressed():
	"""执行撤销操作"""
	if undo_redo_manager and undo_redo_manager.undo():
		timeline_canvas.queue_redraw()
		_update_status_bar("已撤销操作")
		_update_undo_redo_buttons()

## 重做操作
func _on_redo_pressed():
	"""执行重做操作"""
	if undo_redo_manager and undo_redo_manager.redo():
		timeline_canvas.queue_redraw()
		_update_status_bar("已重做操作")
		_update_undo_redo_buttons()

## 更新撤销/重做按钮状态
func _update_undo_redo_buttons():
	"""根据撤销/重做状态更新按钮"""
	if undo_redo_manager:
		if undo_button:
			undo_button.disabled = not undo_redo_manager.can_undo()
		if redo_button:
			redo_button.disabled = not undo_redo_manager.can_redo()

## 获取撤销/重做管理器
func get_undo_redo_manager() -> UndoRedoManager:
	"""获取撤销/重做管理器实例"""
	return undo_redo_manager

## 对话框后重新选择轨道
func _reselect_track_after_dialog(track: JuicyTrack):
	"""对话框关闭后重新选择轨道，触发正常的重建流程"""
	# 延迟重建按钮，确保对话框完全关闭
	call_deferred("_rebuild_buttons_after_dialog", track)

## 延迟重建按钮
func _rebuild_buttons_after_dialog(track: JuicyTrack):
	"""延迟重建按钮，确保对话框完全关闭"""
	# 通过timeline_canvas重新选择轨道，触发正常的_on_track_selected流程
	if timeline_canvas:
		timeline_canvas.select_track(track)
	# 注意：update_target_node_hint_from_track()已在对话框确认回调中延迟调用，这里不需要重复调用
	# 同时也触发track_editor的轨道选择（不传递参数，由track_editor内部获取选中的轨道）
	if track_editor:
		track_editor._on_track_selected()
	
	# 强制刷新UI
	if toolbar:
		toolbar.queue_redraw()
	if context_actions_container:
		context_actions_container.queue_redraw()
		context_actions_container.visible = true

## 创建目标节点提示Label
func _create_target_node_hint():
	"""创建目标节点提示Label（浮动在toolbar中）

	🔥 已废弃：改用内联 Label，不再使用浮动 Panel
	保留此函数以避免错误，但实际使用 _target_node_hint_label（内联 Label）
	"""
	# 保留空函数以避免错误
	# _target_node_hint 不再使用，改为使用 _target_node_hint_label（内联显示）

## 更新目标节点提示显示
func _update_target_node_hint_display(text: String):
	"""更新目标节点提示显示"""

	# 🔥 修改：优先使用内联 Label
	if _target_node_hint_label:
		_target_node_hint_label.text = text
		# 如果有文本，显示标签；否则隐藏
		_target_node_hint_label.visible = not text.is_empty()
		return  # 完成，直接返回

	# 旧的浮动 Panel 方式已废弃，不再使用
	# 如果 _target_node_hint_label 不存在，记录警告
	if not _target_node_hint_label:
		return

	# 优化2：如果传入的文本为空，则检查选中的轨道是否是Property Track，如果是则根据target显示
	if text.is_empty():
		# 获取选中的轨道
		var selected_track = timeline_canvas.get_selected_track() if timeline_canvas else null

		if selected_track and selected_track is JuicyPropertyTrack:
			var property_track = selected_track as JuicyPropertyTrack
			# 检查是否设置了target
			if not property_track.target.is_empty():
				# 获取当前编辑的场景
				var editor_interface = Engine.get_singleton("EditorInterface")
				if editor_interface:
					var edited_root = editor_interface.get_edited_scene_root()
					if edited_root:
						# 尝试获取目标节点并计算相对路径
						var display_path = str(property_track.target)

						# 使用 get_node_or_null 避免错误抛出
						var target_node = edited_root.get_node_or_null(property_track.target)
						if target_node:
							# 获取从场景根节点到目标节点的相对路径
							var relative_path = edited_root.get_path_to(target_node)
							if not relative_path.is_empty():
								display_path = str(relative_path)
						else:
							# 如果目标节点不存在，尝试从路径中提取
							var scene_root_pattern = ":root/"
							var root_pattern = "/root/"

							# 修复：将 NodePath 转换为 String 后再调用 find()
							var path_string = str(display_path)
							var scene_root_idx = path_string.find(scene_root_pattern)
							var root_idx = path_string.find(root_pattern)

							if scene_root_idx >= 0:
								# 从场景根节点开始截取
								display_path = path_string.substr(scene_root_idx + scene_root_pattern.length())
							elif root_idx >= 0:
								# 从根节点开始截取
								display_path = path_string.substr(root_idx + root_pattern.length())
							else:
								# 尝试从第一个 "/" 开始截取（去除开头的斜杠）
								var first_slash = path_string.find("/")
								if first_slash >= 0:
									display_path = path_string.substr(first_slash + 1)

						text = "目标: " + display_path

## 从轨道直接更新目标节点提示（避免依赖get_selected_track()）
func update_target_node_hint_from_track(track: JuicyTrack):
	"""从轨道直接更新目标节点提示，避免依赖get_selected_track()的返回值

	支持所有轨道类型（Feedback/Method/Event/Property）

	@param track: 选中的轨道
	"""

	if not track:
		_update_target_node_hint_display("")
		return

	if not track.target.is_empty():
		# 获取当前编辑的场景
		var editor_interface = Engine.get_singleton("EditorInterface")
		if editor_interface:
			var edited_root = editor_interface.get_edited_scene_root()
			if edited_root:
				# 尝试获取目标节点并计算相对路径
				var display_path = str(track.target)

				# 使用 get_node_or_null 避免错误抛出
				var target_node = edited_root.get_node_or_null(track.target)
				if target_node:
					# 获取从场景根节点到目标节点的相对路径
					var relative_path = edited_root.get_path_to(target_node)
					if not relative_path.is_empty():
						display_path = str(relative_path)
				else:
					# 如果目标节点不存在，尝试从路径中提取
					var scene_root_pattern = ":root/"
					var root_pattern = "/root/"

					# 修复：将 NodePath 转换为 String 后再调用 find()
					var path_string = str(display_path)
					var scene_root_idx = path_string.find(scene_root_pattern)
					var root_idx = path_string.find(root_pattern)

					if scene_root_idx >= 0:
						# 从场景根节点开始截取
						display_path = path_string.substr(scene_root_idx + scene_root_pattern.length())
					elif root_idx >= 0:
						# 从根节点开始截取
						display_path = path_string.substr(root_idx + root_pattern.length())
					else:
						# 尝试从第一个 "/" 开始截取（去除开头的斜杠）
						var first_slash = path_string.find("/")
						if first_slash >= 0:
							display_path = path_string.substr(first_slash + 1)

				# 调用_update_target_node_hint_display显示提示
				var hint_text = "目标: " + display_path
				_update_target_node_hint_display(hint_text)
	else:
		# target为空，隐藏提示
		_update_target_node_hint_display("")

## 轨道属性改变回调
func _on_track_property_changed():
	"""当轨道属性改变时调用，更新场景高亮"""
	# 获取当前选中的轨道
	var current_track = null
	if timeline_canvas:
		current_track = timeline_canvas.get_selected_track()

	if current_track:
		_update_scene_highlight(current_track)
		# 更新目标节点提示
		update_target_node_hint_from_track(current_track)
