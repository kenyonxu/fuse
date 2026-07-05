@tool
extends EditorInspectorPlugin

# 当前编辑的Timeline
var current_timeline: JuicyTimelineResource
var selected_track: JuicyTrack

# 对象编辑计数追踪
var _edit_call_count: int = 0

# 自定义编辑器控件
var timeline_editor: Control
var track_editor: Control
var timeline_canvas: Control

# 缓存的编辑器控件引用（用于信号更新）
var settings_vbox: VBoxContainer

# 外部 TimelineEditor 引用（用于更新高亮）
var external_timeline_editor: Control

func _can_handle(object):
	# 防止在current_timeline未设置时被调用
	if not object:
		return false

	# 🔥 Phase 3B: 添加对 JuicyPropertyTrack 的支持
	if object is JuicyTimelineResource or object is JuicyPropertyTrack:
		return true

	return false

func _parse_begin(object):
	# 确保current_timeline有效
	if not object is JuicyTimelineResource:
		return

	current_timeline = object
	_create_timeline_editor()

func _handles(object):
	# 原有逻辑保持不变
	if object is JuicyTimelineResource:
		return true
	return false

func _parse_category(object, category):
	if category == "Track Management":
		_create_track_management_editor(object)
	elif category == "Parameter Presets":
		_create_parameter_preset_editor(object)
	elif category == "Editor Settings":
		_create_editor_settings_editor(object)

func _parse_property(object, type, path, property, hint, hint_text, usage):
	# 🔥 Phase 3C: 处理 JuicyPropertyTrack 的 curve_preset 下拉菜单
	if object is JuicyPropertyTrack and path == "curve_preset":
		return _create_curve_preset_editor(object)

	# 🔥 Phase 3B: 处理 JuicyPropertyTrack 的 Bake 按钮
	if object is JuicyPropertyTrack:
		if path == "bake_curve_to_keyframes_button":
			return _create_bake_button(object, "Bake Curve → Keyframes", func(): object.bake_curve_to_keyframes())
		elif path == "bake_keyframes_to_curve_button":
			return _create_bake_button(object, "Bake Keyframes → Curve", func(): object.bake_keyframes_to_curve())

	# 处理特殊属性的编辑
	if path == "loop_mode":
		return _create_loop_mode_editor(object, property)
	elif path == "time_scale":
		return _create_time_scale_editor(object, property)

	return false

func _create_timeline_editor():
	if not current_timeline:
		return
	
	# 清除之前的编辑器
	if timeline_editor:
		timeline_editor.queue_free()
		timeline_editor = null
	
	timeline_editor = VBoxContainer.new()
	add_custom_control(timeline_editor)
	
	# Timeline信息标题
	var title_label = Label.new()
	title_label.text = "Timeline 属性编辑器"
	title_label.add_theme_font_size_override("font_size", 14)
	timeline_editor.add_child(title_label)
	
	timeline_editor.add_child(HSeparator.new())

func _create_track_management_editor(object):
	if not current_timeline:
		return
	
	var track_vbox = VBoxContainer.new()
	add_custom_control(track_vbox)
	
	var track_label = Label.new()
	track_label.text = "轨道管理"
	track_label.add_theme_font_size_override("font_size", 12)
	track_vbox.add_child(track_label)
	
	# 轨道统计
	var stats_vbox = VBoxContainer.new()
	track_vbox.add_child(stats_vbox)

	# 轨道统计（修改：使用 timeline_tracks 并分类统计）
	var all_tracks = current_timeline.timeline_tracks  # 🔥 修改
	var property_count = 0
	var feedback_count = 0
	var method_count = 0
	var event_count = 0

	# 统计各类型轨道数量
	for track in all_tracks:
		match track.get_track_type():
			"Property":
				property_count += 1
			"Feedback":
				feedback_count += 1
			"Method":
				method_count += 1
			"Event":
				event_count += 1

	var property_tracks_label = Label.new()
	property_tracks_label.text = "属性轨道: %d" % property_count  # 🔥 修改
	stats_vbox.add_child(property_tracks_label)

	var feedback_tracks_label = Label.new()
	feedback_tracks_label.text = "反馈轨道: %d" % feedback_count  # 🔥 修改
	stats_vbox.add_child(feedback_tracks_label)

	var method_tracks_label = Label.new()
	method_tracks_label.text = "方法轨道: %d" % method_count  # 🔥 修改
	stats_vbox.add_child(method_tracks_label)

	var event_tracks_label = Label.new()
	event_tracks_label.text = "事件轨道: %d" % event_count  # 🔥 修改
	stats_vbox.add_child(event_tracks_label)
	
	# 快速添加轨道按钮
	var add_button_hbox = HBoxContainer.new()
	track_vbox.add_child(add_button_hbox)
	
	var add_property_button = Button.new()
	add_property_button.text = "添加属性轨道"
	add_property_button.pressed.connect(func(): _add_track("Property"))
	add_button_hbox.add_child(add_property_button)
	
	var add_feedback_button = Button.new()
	add_feedback_button.text = "添加反馈轨道"
	add_feedback_button.pressed.connect(func(): _add_track("Feedback"))
	add_button_hbox.add_child(add_feedback_button)

func _create_parameter_preset_editor(object):
	if not current_timeline:
		return
	
	var preset_vbox = VBoxContainer.new()
	add_custom_control(preset_vbox)
	
	var preset_label = Label.new()
	preset_label.text = "参数预设"
	preset_label.add_theme_font_size_override("font_size", 12)
	preset_vbox.add_child(preset_label)
	
	# 预设列表
	var preset_list = ItemList.new()
	preset_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preset_vbox.add_child(preset_list)
	
	# 刷新预设列表
	_refresh_preset_list(preset_list)
	
	# 预设操作按钮
	var preset_button_hbox = HBoxContainer.new()
	preset_vbox.add_child(preset_button_hbox)
	
	var add_preset_button = Button.new()
	add_preset_button.text = "添加预设"
	add_preset_button.pressed.connect(func(): _add_parameter_preset(preset_list))
	preset_button_hbox.add_child(add_preset_button)
	
	var remove_preset_button = Button.new()
	remove_preset_button.text = "删除预设"
	remove_preset_button.pressed.connect(func(): _remove_parameter_preset(preset_list))
	preset_button_hbox.add_child(remove_preset_button)

func _create_editor_settings_editor(object):
	if not current_timeline:
		return
	
	settings_vbox = VBoxContainer.new()
	add_custom_control(settings_vbox)
	
	var settings_label = Label.new()
	settings_label.text = "编辑器设置"
	settings_label.add_theme_font_size_override("font_size", 12)
	settings_vbox.add_child(settings_label)
	
	# 缩放设置
	var zoom_hbox = HBoxContainer.new()
	settings_vbox.add_child(zoom_hbox)
	
	var zoom_label = Label.new()
	zoom_label.text = "缩放:"
	zoom_label.custom_minimum_size = Vector2(60, 0)
	zoom_hbox.add_child(zoom_label)
	
	var zoom_spin = SpinBox.new()
	zoom_spin.min_value = 0.1
	zoom_spin.max_value = 10.0
	zoom_spin.step = 0.1
	zoom_spin.value = current_timeline.timeline_zoom
	zoom_spin.value_changed.connect(_on_zoom_value_changed.bind(zoom_spin))
	zoom_hbox.add_child(zoom_spin)
	
	# 连接Timeline的zoom_changed信号
	_connect_timeline_zoom_signals()
	
	# 吸附设置
	var snap_hbox = HBoxContainer.new()
	settings_vbox.add_child(snap_hbox)
	
	var snap_check = CheckButton.new()
	snap_check.text = "启用吸附"
	snap_check.button_pressed = current_timeline.snap_enabled
	snap_check.toggled.connect(func(enabled): current_timeline.snap_enabled = enabled)
	snap_hbox.add_child(snap_check)
	
	var snap_spin = SpinBox.new()
	snap_spin.min_value = 0.01
	snap_spin.max_value = 1.0
	snap_spin.step = 0.01
	snap_spin.value = current_timeline.snap_step
	snap_spin.value_changed.connect(func(value): current_timeline.snap_step = value)
	snap_hbox.add_child(snap_spin)

func _create_loop_mode_editor(object, property):
	var loop_hbox = HBoxContainer.new()
	add_custom_control(loop_hbox)
	
	var label = Label.new()
	label.text = "循环:"
	label.custom_minimum_size = Vector2(60, 0)
	loop_hbox.add_child(label)
	
	var option_button = OptionButton.new()
	for i in range(JuicyTimelineResource.LoopMode.size()):
		option_button.add_item(JuicyTimelineResource.LoopMode.keys()[i], i)
	
	var property_name = ""
	if property is Object and property.has_method("name"):
		property_name = property.name
	else:
		property_name = str(property)
	
	var property_value = object.get(property_name)
	if property_value != null:
		option_button.selected = property_value
	option_button.item_selected.connect(func(index):
		object.set(property, index)
	)
	loop_hbox.add_child(option_button)
	
	return true

func _create_time_scale_editor(object, property):
	var scale_hbox = HBoxContainer.new()
	add_custom_control(scale_hbox)
	
	var label = Label.new()
	label.text = "时间缩放:"
	label.custom_minimum_size = Vector2(60, 0)
	scale_hbox.add_child(label)
	
	var h_slider = HSlider.new()
	h_slider.custom_minimum_size = Vector2(200, 0)  # 增加slider宽度
	h_slider.min_value = 0.01
	h_slider.max_value = 10.0
	h_slider.step = 0.01
	h_slider.value = 1.0  # Timeline resource的默认值
	
	h_slider.value_changed.connect(func(value): object.set(property, value))
	scale_hbox.add_child(h_slider)
	
	# 添加数值显示
	var value_label = Label.new()
	value_label.text = "1.00"
	value_label.custom_minimum_size = Vector2(40, 0)
	scale_hbox.add_child(value_label)
	
	# 更新数值显示
	h_slider.value_changed.connect(func(value): 
		value_label.text = "%.2f" % value
	)
	
	return true

# 轨道编辑器
func edit_timeline(timeline: JuicyTimelineResource):
	# 对象有效性检查
	if not is_instance_valid(timeline):
		return

	# 参数检查
	if not timeline:
		return

	if not timeline is JuicyTimelineResource:
		return

	# 当前状态检查
	if current_timeline == timeline:
		return

	# 原有的逻辑
	current_timeline = timeline
	_edit_call_count += 1
	
	# 清除之前的编辑器
	if timeline_editor:
		timeline_editor.queue_free()
		timeline_editor = null
	
	if track_editor:
		track_editor.queue_free()
		track_editor = null
	
	# 重新创建编辑器
	if timeline:
		_create_timeline_editor()

func edit_track(track: JuicyTrack):
	selected_track = track
	
	# 清除之前的轨道编辑器
	if track_editor:
		track_editor.queue_free()
		track_editor = null
	
	if track:
		_create_track_editor(track)

func _create_track_editor(track: JuicyTrack):
	if not track:
		return
	
	track_editor = VBoxContainer.new()
	add_custom_control(track_editor)
	
	# 轨道信息标题
	var title_label = Label.new()
	title_label.text = "轨道属性: " + (track.track_name if track.has_property("track_name") else "未命名轨道")
	title_label.add_theme_font_size_override("font_size", 14)
	track_editor.add_child(title_label)
	
	track_editor.add_child(HSeparator.new())
	
	# 轨道名称
	var name_hbox = HBoxContainer.new()
	track_editor.add_child(name_hbox)
	
	var name_label = Label.new()
	name_label.text = "名称:"
	name_label.custom_minimum_size = Vector2(60, 0)
	name_hbox.add_child(name_label)
	
	var name_line = LineEdit.new()
	name_line.text = track.track_name if track.has_property("track_name") else ""
	name_line.text_changed.connect(func(text): 
		if track.has_property("track_name"):
			track.track_name = text
	)
	name_hbox.add_child(name_line)
	
	# 轨道启用状态
	var enabled_hbox = HBoxContainer.new()
	track_editor.add_child(enabled_hbox)
	
	var enabled_check = CheckButton.new()
	enabled_check.text = "启用"
	enabled_check.button_pressed = track.enabled if track.has_property("enabled") else true
	enabled_check.toggled.connect(func(enabled): 
		if track.has_property("enabled"):
			track.enabled = enabled
	)
	enabled_hbox.add_child(enabled_check)
	
	# 轨道静音状态
	var muted_hbox = HBoxContainer.new()
	track_editor.add_child(muted_hbox)
	
	var muted_check = CheckButton.new()
	muted_check.text = "静音"
	muted_check.button_pressed = track.muted if track.has_property("muted") else false
	muted_check.toggled.connect(func(muted): 
		if track.has_property("muted"):
			track.muted = muted
	)
	muted_hbox.add_child(muted_check)
	
	# 根据轨道类型添加特定编辑器
	_create_track_type_editor(track)

func _create_track_type_editor(track: JuicyTrack):
	match track.get_track_type():
		"Property":
			_create_property_track_editor(track)
		"Feedback":
			_create_feedback_track_editor(track)
		"Method":
			_create_method_track_editor(track)
		"Event":
			_create_event_track_editor(track)

func _create_property_track_editor(track: JuicyTrack):
	if not track is JuicyPropertyTrack:
		return
	
	var property_track = track as JuicyPropertyTrack
	
	# 属性轨道特定编辑器
	var property_vbox = VBoxContainer.new()
	track_editor.add_child(property_vbox)
	
	var property_title = Label.new()
	property_title.text = "属性轨道设置"
	property_title.add_theme_font_size_override("font_size", 12)
	property_vbox.add_child(property_title)
	
	# 目标节点路径
	var node_path_hbox = HBoxContainer.new()
	property_vbox.add_child(node_path_hbox)
	
	var node_path_label = Label.new()
	node_path_label.text = "目标节点:"
	node_path_label.custom_minimum_size = Vector2(80, 0)
	node_path_hbox.add_child(node_path_label)
	
	var node_path_line = LineEdit.new()
	node_path_line.text = property_track.target if property_track.has_property("target") else ""
	node_path_line.text_changed.connect(func(text):
		if property_track.has_property("target"):
			property_track.target = text
			# 通知 TimelineEditor 更新高亮
			_notify_highlight_update()
		)
	node_path_hbox.add_child(node_path_line)
	
	# 属性名称
	var property_name_hbox = HBoxContainer.new()
	property_vbox.add_child(property_name_hbox)
	
	var property_name_label = Label.new()
	property_name_label.text = "属性名称:"
	property_name_label.custom_minimum_size = Vector2(80, 0)
	property_name_hbox.add_child(property_name_label)
	
	var property_name_line = LineEdit.new()
	property_name_line.text = property_track.property_name if property_track.has_property("property_name") else ""
	property_name_line.text_changed.connect(func(text): 
		if property_track.has_property("property_name"):
			property_track.property_name = text
	)
	property_name_hbox.add_child(property_name_line)
	
	# 插值模式
	if property_track.has_property("interpolation_mode"):
		var interp_hbox = HBoxContainer.new()
		property_vbox.add_child(interp_hbox)
		
		var interp_label = Label.new()
		interp_label.text = "插值模式:"
		interp_label.custom_minimum_size = Vector2(80, 0)
		interp_hbox.add_child(interp_label)
		
		var interp_option = OptionButton.new()
		# 这里需要根据实际的插值模式枚举来填充
		interp_option.add_item("线性", 0)
		interp_option.add_item("缓入", 1)
		interp_option.add_item("缓出", 2)
		interp_option.add_item("缓入缓出", 3)
		
		interp_option.selected = property_track.interpolation_mode
		interp_option.item_selected.connect(func(index):
			property_track.interpolation_mode = index
		)
		interp_hbox.add_child(interp_option)

func _create_feedback_track_editor(track: JuicyTrack):
	if not track is JuicyFeedbackTrack:
		return
	
	var feedback_track = track as JuicyFeedbackTrack
	
	# 反馈轨道特定编辑器
	var feedback_vbox = VBoxContainer.new()
	track_editor.add_child(feedback_vbox)
	
	var feedback_title = Label.new()
	feedback_title.text = "反馈轨道设置"
	feedback_title.add_theme_font_size_override("font_size", 12)
	feedback_vbox.add_child(feedback_title)
	
	# 反馈资源列表
	var resource_list_label = Label.new()
	resource_list_label.text = "反馈资源列表:"
	feedback_vbox.add_child(resource_list_label)
	
	var resource_list = ItemList.new()
	resource_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 添加现有的反馈数据
	if feedback_track.has_property("feedback_data"):
		for i in range(feedback_track.feedback_data.size()):
			var feedback_data = feedback_track.feedback_data[i]
			var item_text = "反馈 %d: %.2fs - %.2fs" % [i+1, feedback_data.start_time, feedback_data.duration]
			resource_list.add_item(item_text)
	
	feedback_vbox.add_child(resource_list)
	
	# 添加反馈数据按钮
	var add_feedback_button = Button.new()
	add_feedback_button.text = "添加反馈数据"
	add_feedback_button.pressed.connect(func(): _add_feedback_data(feedback_track, resource_list))
	feedback_vbox.add_child(add_feedback_button)

func _create_method_track_editor(track: JuicyTrack):
	if not track is JuicyMethodTrack:
		return
	
	var method_track = track as JuicyMethodTrack
	
	# 方法轨道特定编辑器
	var method_vbox = VBoxContainer.new()
	track_editor.add_child(method_vbox)
	
	var method_title = Label.new()
	method_title.text = "方法轨道设置"
	method_title.add_theme_font_size_override("font_size", 12)
	method_vbox.add_child(method_title)
	
	# 目标节点路径
	var node_path_hbox = HBoxContainer.new()
	method_vbox.add_child(node_path_hbox)
	
	var node_path_label = Label.new()
	node_path_label.text = "目标节点:"
	node_path_label.custom_minimum_size = Vector2(80, 0)
	node_path_hbox.add_child(node_path_label)
	
	var node_path_line = LineEdit.new()
	node_path_line.text = method_track.target if method_track.has_property("target") else ""
	node_path_line.text_changed.connect(func(text):
		if method_track.has_property("target"):
			method_track.target = text
			# 通知 TimelineEditor 更新高亮
			_notify_highlight_update()
		)
	node_path_hbox.add_child(node_path_line)

func _create_event_track_editor(track: JuicyTrack):
	if not track is JuicyEventTrack:
		return
	
	var event_track = track as JuicyEventTrack
	
	# 事件轨道特定编辑器
	var event_vbox = VBoxContainer.new()
	track_editor.add_child(event_vbox)
	
	var event_title = Label.new()
	event_title.text = "事件轨道设置"
	event_title.add_theme_font_size_override("font_size", 12)
	event_vbox.add_child(event_title)
	
	# 事件列表
	var event_list_label = Label.new()
	event_list_label.text = "事件触发列表:"
	event_vbox.add_child(event_list_label)
	
	var event_list = ItemList.new()
	event_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 添加现有的事件触发器
	if event_track.has_property("event_triggers"):
		for i in range(event_track.event_triggers.size()):
			var event_trigger = event_track.event_triggers[i]
			var item_text = "事件 %d: %.2fs - %s" % [i+1, event_trigger.time, event_trigger.event_name]
			event_list.add_item(item_text)
	
	event_vbox.add_child(event_list)
	
	# 添加事件触发器按钮
	var add_event_button = Button.new()
	add_event_button.text = "添加事件触发器"
	add_event_button.pressed.connect(func(): _add_event_trigger(event_track, event_list))
	event_vbox.add_child(add_event_button)

# 辅助函数
func _add_track(track_type: String):
	if not current_timeline:
		return
	
	var new_track: JuicyTrack
	
	match track_type:
		"Property":
			new_track = JuicyPropertyTrack.new()
			new_track.track_name = "新属性轨道"
		"Feedback":
			new_track = JuicyFeedbackTrack.new()
			new_track.track_name = "新反馈轨道"
		"Method":
			new_track = JuicyMethodTrack.new()
			new_track.track_name = "新方法轨道"
		"Event":
			new_track = JuicyEventTrack.new()
			new_track.track_name = "新事件轨道"
	
	if new_track:
		current_timeline.add_track(new_track)

func _refresh_preset_list(preset_list: ItemList):
	preset_list.clear()
	
	if not current_timeline:
		return
	
	for preset_name in current_timeline.parameter_presets.keys():
		preset_list.add_item(preset_name)

func _add_parameter_preset(preset_list: ItemList):
	var dialog = AcceptDialog.new()
	dialog.title = "添加参数预设"
	EditorInterface.get_base_control().add_child(dialog)
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = "预设名称:"
	vbox.add_child(name_label)
	
	var name_line = LineEdit.new()
	vbox.add_child(name_line)
	
	name_line.grab_focus()
	
	dialog.register_text_enter(name_line)
	dialog.confirmed.connect(func():
		var preset_name = name_line.text
		if not preset_name.is_empty():
			current_timeline.add_parameter_preset(preset_name, {})
			_refresh_preset_list(preset_list)
		dialog.queue_free()
	)
	
	dialog.popup_centered(Vector2(300, 100))

func _remove_parameter_preset(preset_list: ItemList):
	var selected = preset_list.get_selected_items()
	if selected.is_empty():
		return
	
	var preset_name = preset_list.get_item_text(selected[0])
	current_timeline.remove_parameter_preset(preset_name)
	_refresh_preset_list(preset_list)

func _add_feedback_data(feedback_track: JuicyFeedbackTrack, resource_list: ItemList):
	# 创建反馈数据
	var feedback_data = null
	
	# 这里需要根据实际的反馈数据结构来创建
	# 暂时创建一个简单的反馈数据
	feedback_data = {
		"start_time": 0.0,
		"duration": 1.0,
		"feedback_resource": null
	}
	
	if feedback_track.has_property("feedback_data"):
		feedback_track.feedback_data.append(feedback_data)
		
		# 更新列表
		var item_text = "反馈 %d: %.2fs - %.2fs" % [feedback_track.feedback_data.size(), feedback_data.start_time, feedback_data.duration]
		resource_list.add_item(item_text)

func _add_event_trigger(event_track: JuicyEventTrack, event_list: ItemList):
	# 创建事件触发器
	var event_trigger = null
	
	# 这里需要根据实际的事件触发器结构来创建
	# 暂时创建一个简单的事件触发器
	event_trigger = {
		"time": 0.0,
		"event_name": "新事件"
	}
	
	if event_track.has_property("event_triggers"):
		event_track.event_triggers.append(event_trigger)
		
		# 更新列表
		var item_text = "事件 %d: %.2fs - %s" % [event_track.event_triggers.size(), event_trigger.time, event_trigger.event_name]
		event_list.add_item(item_text)

# 设置Timeline Canvas引用
func set_timeline_canvas(canvas: Control):
	"""设置Timeline Canvas引用"""
	timeline_canvas = canvas

# 连接Timeline的zoom_changed信号
func _connect_timeline_zoom_signals():
	"""连接Timeline的zoom_changed信号"""
	if not current_timeline:
		return
	
	# 避免重复连接
	if not current_timeline.zoom_changed.is_connected(_on_timeline_zoom_changed):
		current_timeline.zoom_changed.connect(_on_timeline_zoom_changed)

# 处理zoom_spin变化
func _on_zoom_value_changed(spin_box: SpinBox, value: float):
	"""处理zoom_spin变化"""
	if not current_timeline:
		return
	
	# 更新Timeline资源的zoom（会触发zoom_changed信号）
	current_timeline.timeline_zoom = value

# 响应Timeline的zoom_changed信号
func _on_timeline_zoom_changed(new_zoom: float):
	"""响应Timeline的zoom_changed信号"""
	if not current_timeline:
		return
	
	# 避免循环更新：如果当前值与new_zoom相同则跳过
	if abs(current_timeline.timeline_zoom - new_zoom) < 0.01:
		return

	# 找到并更新zoom_spin的值
	# 由于zoom_spin是局部变量，我们需要查找它
	if settings_vbox:
		for child in settings_vbox.get_children():
			if child is HBoxContainer:
				for grandchild in child.get_children():
					if grandchild is SpinBox:
						grandchild.value = new_zoom
						return

# 通知Canvas更新缩放
func _notify_canvas_zoom_update():
	"""通知Timeline Canvas更新缩放级别"""
	if timeline_canvas and timeline_canvas.has_method("update_zoom_from_timeline"):
		timeline_canvas.update_zoom_from_timeline()

## ============================================================================
# Phase 3C: Curve Preset Inspector Editor
# ============================================================================

## 创建曲线预设下拉菜单编辑器
func _create_curve_preset_editor(object: JuicyPropertyTrack) -> bool:
	"""创建曲线预设下拉菜单编辑器"""
	var preset_hbox = HBoxContainer.new()
	add_custom_control(preset_hbox)

	# Label
	var label = Label.new()
	label.text = "Curve:"
	label.custom_minimum_size = Vector2(50, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preset_hbox.add_child(label)

	# 预设下拉菜单
	var option_button = OptionButton.new()
	option_button.custom_minimum_size = Vector2(150, 0)
	option_button.tooltip_text = "选择曲线预设"

	# 填充预设选项（按分类组织）
	_populate_curve_preset_menu(option_button)

	# 设置当前值（优先显示待应用的预设，否则显示当前预设）
	var display_preset = object._pending_curve_preset if object._pending_curve_preset >= 0 else object.curve_preset
	option_button.selected = display_preset

	# 连接变化事件
	option_button.item_selected.connect(func(index: int):
		# 只更新待应用的预设，不立即应用
		object._pending_curve_preset = index
		# 刷新 Timeline Canvas 显示（显示曲线预览，但不应用）
		if timeline_canvas:
			timeline_canvas.queue_redraw()
	)

	preset_hbox.add_child(option_button)

	# 添加 "Apply" 按钮
	var apply_button = Button.new()
	apply_button.text = "Apply"
	apply_button.tooltip_text = "智能应用预设：创建新曲线或应用到现有曲线"
	apply_button.custom_minimum_size = Vector2(50, 0)
	apply_button.pressed.connect(func():
		# 应用待应用的曲线预设
		object.call_deferred("apply_pending_curve_preset")
		# 刷新 检查器
		var plugin_instance= JuicyTimelineEditorPlugin.get_instance()
		plugin_instance.get_editor_interface().get_inspector().queue_redraw()
		# 刷新 Timeline Canvas 显示
		if timeline_canvas:
			timeline_canvas.queue_redraw()
	)
	preset_hbox.add_child(apply_button)

	return true


## 填充曲线预设菜单（按分类）
func _populate_curve_preset_menu(option_button: OptionButton):
	"""填充曲线预设下拉菜单（按分类）"""
	# Phase 3C: 需要 preload JuicyCurveFactory
	var JuicyCurveFactory = preload("res://addons/juicy_mixer/utils/juicy_curve_factory.gd")

	# Basic (0-3)
	for preset in [0, 1, 2, 3]:
		var name = "[Basic] " + JuicyCurveFactory.get_preset_name(preset)
		option_button.add_item(name, preset)

	# Back (4-6)
	for preset in [4, 5, 6]:
		var name = "[Back] " + JuicyCurveFactory.get_preset_name(preset)
		option_button.add_item(name, preset)

	# Elastic (7-9)
	for preset in [7, 8, 9]:
		var name = "[Elastic] " + JuicyCurveFactory.get_preset_name(preset)
		option_button.add_item(name, preset)

	# Bounce (10-12)
	for preset in [10, 11, 12]:
		var name = "[Bounce] " + JuicyCurveFactory.get_preset_name(preset)
		option_button.add_item(name, preset)

	# Exponential (13-15)
	for preset in [13, 14, 15]:
		var name = "[Expo] " + JuicyCurveFactory.get_preset_name(preset)
		option_button.add_item(name, preset)

	# Sine (16-18)
	for preset in [16, 17, 18]:
		var name = "[Sine] " + JuicyCurveFactory.get_preset_name(preset)
		option_button.add_item(name, preset)

	# Quadratic (19-21)
	for preset in [19, 20, 21]:
		var name = "[Quad] " + JuicyCurveFactory.get_preset_name(preset)
		option_button.add_item(name, preset)

	# Cubic (22-24)
	for preset in [22, 23, 24]:
		var name = "[Cubic] " + JuicyCurveFactory.get_preset_name(preset)
		option_button.add_item(name, preset)

## 🔥 Phase 3B: 创建 Bake 按钮
func _create_bake_button(object: JuicyPropertyTrack, button_text: String, callback: Callable) -> bool:
	"""为 Bake 功能创建真实的按钮"""
	var button = Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 30)

	# 连接按钮点击事件
	button.pressed.connect(func():
		callback.call()
		# 刷新 Inspector 以显示更新后的状态
		object.notify_property_list_changed()
		# 🔥 刷新 Timeline Canvas 以显示新的关键帧/曲线
		if timeline_canvas:
			timeline_canvas.queue_redraw()
	)

	add_custom_control(button)
	return true

## 设置外部 TimelineEditor 引用
func set_timeline_editor(editor: Control):
	"""设置外部 TimelineEditor 引用，用于更新高亮显示"""
	external_timeline_editor = editor

## 通知 TimelineEditor 更新高亮
func _notify_highlight_update():
	"""通知 TimelineEditor 更新场景高亮"""
	if external_timeline_editor and external_timeline_editor.has_method("_update_scene_highlight"):
		# 如果当前有选中的轨道，更新它的高亮
		if selected_track:
			external_timeline_editor._update_scene_highlight(selected_track)


