@tool
extends RefCounted

# Timeline资源创建工具
# 提供快速创建Timeline资源的界面和预设模板

class_name JuicyTimelineResourceCreator

# 预设模板类型
enum PresetType {
	EMPTY,           # 空Timeline
	BASIC_ANIMATION, # 基础动画
	COMPLEX_SEQUENCE, # 复杂序列
	EVENT_DRIVEN,    # 事件驱动
	PARTICLE_EFFECT, # 粒子效果
	UI_FEEDBACK      # UI反馈
}

# 创建对话框
var create_dialog: AcceptDialog
var name_line_edit: LineEdit
var preset_option: OptionButton
var duration_spin: SpinBox
var description_edit: TextEdit

# 当前编辑器接口
var editor_interface

func _init():
	# EditorInterface是单例，可以直接使用
	editor_interface = EditorInterface

func show_create_dialog():
	_create_dialog()
	create_dialog.popup_centered(Vector2(500, 400))

func _create_dialog():
	if create_dialog:
		create_dialog.queue_free()
	
	create_dialog = AcceptDialog.new()
	create_dialog.title = "创建Juicy Timeline资源"
	editor_interface.get_base_control().add_child(create_dialog)
	
	var main_vbox = VBoxContainer.new()
	create_dialog.add_child(main_vbox)
	
	# 基本信息组
	var basic_vbox = VBoxContainer.new()
	main_vbox.add_child(basic_vbox)
	
	var basic_label = Label.new()
	basic_label.text = "基本信息"
	basic_label.add_theme_font_size_override("font_size", 12)
	basic_vbox.add_child(basic_label)
	
	var basic_separator = HSeparator.new()
	basic_vbox.add_child(basic_separator)
	
	# 资源名称
	var name_hbox = HBoxContainer.new()
	basic_vbox.add_child(name_hbox)
	
	var name_label = Label.new()
	name_label.text = "资源名称:"
	name_label.custom_minimum_size = Vector2(100, 0)
	name_hbox.add_child(name_label)
	
	name_line_edit = LineEdit.new()
	name_line_edit.placeholder_text = "新Timeline"
	name_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hbox.add_child(name_line_edit)
	
	# 预设模板
	var preset_hbox = HBoxContainer.new()
	basic_vbox.add_child(preset_hbox)
	
	var preset_label = Label.new()
	preset_label.text = "预设模板:"
	preset_label.custom_minimum_size = Vector2(100, 0)
	preset_hbox.add_child(preset_label)
	
	preset_option = OptionButton.new()
	_populate_preset_options()
	preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_hbox.add_child(preset_option)
	
	preset_option.item_selected.connect(_on_preset_selected)
	
	# 时间轴设置组
	var timeline_vbox = VBoxContainer.new()
	main_vbox.add_child(timeline_vbox)
	
	var timeline_label = Label.new()
	timeline_label.text = "时间轴设置"
	timeline_label.add_theme_font_size_override("font_size", 12)
	timeline_vbox.add_child(timeline_label)
	
	var timeline_separator = HSeparator.new()
	timeline_vbox.add_child(timeline_separator)
	
	# 时长
	var duration_hbox = HBoxContainer.new()
	timeline_vbox.add_child(duration_hbox)
	
	var duration_label = Label.new()
	duration_label.text = "时长(秒):"
	duration_label.custom_minimum_size = Vector2(100, 0)
	duration_hbox.add_child(duration_label)
	
	duration_spin = SpinBox.new()
	duration_spin.min_value = 0.1
	duration_spin.max_value = 3600.0
	duration_spin.step = 0.1
	duration_spin.value = 5.0
	duration_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_hbox.add_child(duration_spin)
	
	# 描述
	var desc_hbox = HBoxContainer.new()
	timeline_vbox.add_child(desc_hbox)
	
	var desc_label = Label.new()
	desc_label.text = "描述:"
	desc_label.custom_minimum_size = Vector2(100, 0)
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc_hbox.add_child(desc_label)
	
	description_edit = TextEdit.new()
	description_edit.custom_minimum_size = Vector2(0, 60)
	description_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_edit.placeholder_text = "Timeline描述信息..."
	desc_hbox.add_child(description_edit)
	
	# 预设信息显示
	var preset_info_label = Label.new()
	preset_info_label.name = "PresetInfoLabel"
	preset_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preset_info_label.custom_minimum_size = Vector2(0, 60)
	main_vbox.add_child(preset_info_label)
	
	# 连接信号
	create_dialog.confirmed.connect(_on_create_confirmed)
	create_dialog.register_text_enter(name_line_edit)
	
	# 显示初始预设信息
	_on_preset_selected(0)

func _populate_preset_options():
	preset_option.clear()
	preset_option.add_item("空Timeline", PresetType.EMPTY)
	preset_option.add_item("基础动画", PresetType.BASIC_ANIMATION)
	preset_option.add_item("复杂序列", PresetType.COMPLEX_SEQUENCE)
	preset_option.add_item("事件驱动", PresetType.EVENT_DRIVEN)
	preset_option.add_item("粒子效果", PresetType.PARTICLE_EFFECT)
	preset_option.add_item("UI反馈", PresetType.UI_FEEDBACK)

func _on_preset_selected(index: int):
	var preset_info_label = create_dialog.get_node("PresetInfoLabel") as Label
	if not preset_info_label:
		return
	
	var preset_type = preset_option.get_item_id(index) as PresetType
	var info_text = ""
	
	match preset_type:
		PresetType.EMPTY:
			info_text = "创建一个空的Timeline资源，可以手动添加轨道和关键帧。"
		PresetType.BASIC_ANIMATION:
			info_text = "创建一个基础动画Timeline，包含属性轨道和几个示例关键帧。适合简单的动画效果。"
		PresetType.COMPLEX_SEQUENCE:
			info_text = "创建一个复杂序列Timeline，包含多种轨道类型（属性、方法、事件）。适合复杂的动画序列。"
		PresetType.EVENT_DRIVEN:
			info_text = "创建一个事件驱动Timeline，主要包含事件轨道和方法轨道。适合事件触发的动画。"
		PresetType.PARTICLE_EFFECT:
			info_text = "创建一个粒子效果Timeline，包含反馈轨道用于触发粒子效果。适合粒子系统动画。"
		PresetType.UI_FEEDBACK:
			info_text = "创建一个UI反馈Timeline，包含UI相关的属性轨道和反馈轨道。适合UI动画和反馈效果。"
	
	# 根据预设类型调整默认值
	match preset_type:
		PresetType.BASIC_ANIMATION:
			duration_spin.value = 2.0
		PresetType.COMPLEX_SEQUENCE:
			duration_spin.value = 10.0
		PresetType.EVENT_DRIVEN:
			duration_spin.value = 5.0
		PresetType.PARTICLE_EFFECT:
			duration_spin.value = 3.0
		PresetType.UI_FEEDBACK:
			duration_spin.value = 1.0
		_:
			duration_spin.value = 5.0
	
	preset_info_label.text = info_text

func _on_create_confirmed():
	var resource_name = name_line_edit.text.strip_edges()
	if resource_name.is_empty():
		resource_name = "NewTimeline"
	
	var preset_type = preset_option.get_item_id(preset_option.selected) as PresetType
	var duration = duration_spin.value
	var description = description_edit.text.strip_edges()
	
	# 创建Timeline资源
	var timeline = _create_timeline_resource(preset_type, duration, description)
	
	if not timeline:
		push_error("Failed to create Timeline resource")
		return
	
	# 保存资源
	_save_timeline_resource(timeline, resource_name)
	
	# 关闭对话框
	create_dialog.queue_free()
	create_dialog = null

func _create_timeline_resource(preset_type: PresetType, duration: float, description: String) -> JuicyTimelineResource:
	var timeline = JuicyTimelineResource.new()
	timeline.timeline_duration = duration
	timeline.description = description
	
	match preset_type:
		PresetType.EMPTY:
			# 空Timeline，不需要额外设置
			pass
		
		PresetType.BASIC_ANIMATION:
			_create_basic_animation_preset(timeline, duration)
		
		PresetType.COMPLEX_SEQUENCE:
			_create_complex_sequence_preset(timeline, duration)
		
		PresetType.EVENT_DRIVEN:
			_create_event_driven_preset(timeline, duration)
		
		PresetType.PARTICLE_EFFECT:
			_create_particle_effect_preset(timeline, duration)
		
		PresetType.UI_FEEDBACK:
			_create_ui_feedback_preset(timeline, duration)
	
	return timeline

func _create_basic_animation_preset(timeline: JuicyTimelineResource, duration: float):
	# 创建属性轨道
	var property_track = JuicyPropertyTrack.new()
	property_track.track_name = "位置动画"
	property_track.target = "NodePath"
	property_track.property_name = "position"
	
	# 添加关键帧
	var keyframe1 = JuicyKeyframe.new()
	keyframe1.time = 0.0
	keyframe1.value = Vector2.ZERO
	
	var keyframe2 = JuicyKeyframe.new()
	keyframe2.time = duration * 0.5
	keyframe2.value = Vector2(100, 0)
	
	var keyframe3 = JuicyKeyframe.new()
	keyframe3.time = duration
	keyframe3.value = Vector2.ZERO
	
	property_track.keyframes = [keyframe1, keyframe2, keyframe3]
	timeline.add_track(property_track)
	
	# 创建旋转轨道
	var rotation_track = JuicyPropertyTrack.new()
	rotation_track.track_name = "旋转动画"
	rotation_track.target = "NodePath"
	rotation_track.property_name = "rotation"
	
	var rot_keyframe1 = JuicyKeyframe.new()
	rot_keyframe1.time = 0.0
	rot_keyframe1.value = 0.0
	
	var rot_keyframe2 = JuicyKeyframe.new()
	rot_keyframe2.time = duration
	rot_keyframe2.value = 360.0
	
	rotation_track.keyframes = [rot_keyframe1, rot_keyframe2]
	timeline.add_track(rotation_track)

func _create_complex_sequence_preset(timeline: JuicyTimelineResource, duration: float):
	# 创建多个不同类型的轨道
	
	# 属性轨道
	var position_track = JuicyPropertyTrack.new()
	position_track.track_name = "位置"
	position_track.target = "NodePath"
	position_track.property_name = "position"
	
	var pos_keyframe1 = JuicyKeyframe.new()
	pos_keyframe1.time = 0.0
	pos_keyframe1.value = Vector2.ZERO
	
	var pos_keyframe2 = JuicyKeyframe.new()
	pos_keyframe2.time = duration
	pos_keyframe2.value = Vector2(200, 100)
	
	position_track.keyframes = [pos_keyframe1, pos_keyframe2]
	timeline.add_track(position_track)
	
	# 方法轨道
	var method_track = JuicyMethodTrack.new()
	method_track.track_name = "方法调用"
	method_track.target = "NodePath"
	
	# 这里需要根据实际的方法调用结构来创建
	# 暂时创建一个空的方法轨道
	timeline.add_track(method_track)
	
	# 事件轨道
	var event_track = JuicyEventTrack.new()
	event_track.track_name = "事件触发"
	
	# 这里需要根据实际的事件触发器结构来创建
	# 暂时创建一个空的事件轨道
	timeline.add_track(event_track)
	
	# 反馈轨道
	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.track_name = "反馈效果"
	
	# 这里需要根据实际的反馈数据结构来创建
	# 暂时创建一个空的反馈轨道
	timeline.add_track(feedback_track)

func _create_event_driven_preset(timeline: JuicyTimelineResource, duration: float):
	# 创建事件轨道
	var event_track = JuicyEventTrack.new()
	event_track.track_name = "主事件轨道"
	
	# 这里需要根据实际的事件触发器结构来创建
	# 暂时创建一个空的事件轨道
	timeline.add_track(event_track)
	
	# 创建方法轨道
	var method_track = JuicyMethodTrack.new()
	method_track.track_name = "事件响应方法"
	method_track.target = "NodePath"
	
	timeline.add_track(method_track)

func _create_particle_effect_preset(timeline: JuicyTimelineResource, duration: float):
	# 创建反馈轨道
	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.track_name = "粒子效果"
	
	# 这里需要根据实际的反馈数据结构来创建
	# 暂时创建一个空的反馈轨道
	timeline.add_track(feedback_track)
	
	# 创建属性轨道用于控制粒子参数
	var particle_track = JuicyPropertyTrack.new()
	particle_track.track_name = "粒子参数"
	particle_track.target = "NodePath"
	particle_track.property_name = "amount"
	
	var particle_keyframe1 = JuicyKeyframe.new()
	particle_keyframe1.time = 0.0
	particle_keyframe1.value = 0
	
	var particle_keyframe2 = JuicyKeyframe.new()
	particle_keyframe2.time = duration * 0.1
	particle_keyframe2.value = 100
	
	var particle_keyframe3 = JuicyKeyframe.new()
	particle_keyframe3.time = duration * 0.9
	particle_keyframe3.value = 100
	
	var particle_keyframe4 = JuicyKeyframe.new()
	particle_keyframe4.time = duration
	particle_keyframe4.value = 0
	
	particle_track.keyframes = [particle_keyframe1, particle_keyframe2, particle_keyframe3, particle_keyframe4]
	timeline.add_track(particle_track)

func _create_ui_feedback_preset(timeline: JuicyTimelineResource, duration: float):
	# 创建缩放轨道
	var scale_track = JuicyPropertyTrack.new()
	scale_track.track_name = "UI缩放"
	scale_track.target = "NodePath"
	scale_track.property_name = "scale"
	
	var scale_keyframe1 = JuicyKeyframe.new()
	scale_keyframe1.time = 0.0
	scale_keyframe1.value = Vector2.ONE
	
	var scale_keyframe2 = JuicyKeyframe.new()
	scale_keyframe2.time = duration * 0.1
	scale_keyframe2.value = Vector2.ONE * 1.2
	
	var scale_keyframe3 = JuicyKeyframe.new()
	scale_keyframe3.time = duration * 0.3
	scale_keyframe3.value = Vector2.ONE
	
	scale_track.keyframes = [scale_keyframe1, scale_keyframe2, scale_keyframe3]
	timeline.add_track(scale_track)
	
	# 创建透明度轨道
	var opacity_track = JuicyPropertyTrack.new()
	opacity_track.track_name = "UI透明度"
	opacity_track.target = "NodePath"
	opacity_track.property_name = "modulate:a"
	
	var opacity_keyframe1 = JuicyKeyframe.new()
	opacity_keyframe1.time = 0.0
	opacity_keyframe1.value = 0.0
	
	var opacity_keyframe2 = JuicyKeyframe.new()
	opacity_keyframe2.time = duration * 0.2
	opacity_keyframe2.value = 1.0
	
	var opacity_keyframe3 = JuicyKeyframe.new()
	opacity_keyframe3.time = duration * 0.8
	opacity_keyframe3.value = 1.0
	
	var opacity_keyframe4 = JuicyKeyframe.new()
	opacity_keyframe4.time = duration
	opacity_keyframe4.value = 0.0
	
	opacity_track.keyframes = [opacity_keyframe1, opacity_keyframe2, opacity_keyframe3, opacity_keyframe4]
	timeline.add_track(opacity_track)
	
	# 创建反馈轨道
	var feedback_track = JuicyFeedbackTrack.new()
	feedback_track.track_name = "UI反馈音效"
	
	# 这里需要根据实际的反馈数据结构来创建
	# 暂时创建一个空的反馈轨道
	timeline.add_track(feedback_track)

func _save_timeline_resource(timeline: JuicyTimelineResource, resource_name: String):
	# 获取当前选中的目录
	var current_dir = editor_interface.get_current_directory()
	var save_path = current_dir.path_join(resource_name + ".tres")
	
	# 确保文件扩展名
	if not save_path.ends_with(".tres"):
		save_path += ".tres"
	
	# 保存资源
	var result = ResourceSaver.save(timeline, save_path)
	if result == OK:
		print("Timeline资源已保存到: ", save_path)
		
		# 在编辑器中打开新创建的资源
		editor_interface.get_resource_filesystem().scan()
		editor_interface.edit_resource(timeline)
	else:
		push_error("保存Timeline资源失败: " + str(result))

# 批量创建功能
func create_batch_timelines(timeline_configs: Array[Dictionary]) -> Array[JuicyTimelineResource]:
	var created_timelines: Array[JuicyTimelineResource] = []
	
	for config in timeline_configs:
		if not config.has("name") or not config.has("preset_type"):
			continue
		
		var preset_type = config.get("preset_type", PresetType.EMPTY) as PresetType
		var duration = config.get("duration", 5.0)
		var description = config.get("description", "")
		
		var timeline = _create_timeline_resource(preset_type, duration, description)
		if timeline:
			timeline.resource_name = config.name
			created_timelines.append(timeline)
	
	return created_timelines

# 创建预设模板的快捷方法
func create_empty_timeline(duration: float = 5.0) -> JuicyTimelineResource:
	return _create_timeline_resource(PresetType.EMPTY, duration, "")

func create_basic_animation_timeline(duration: float = 2.0) -> JuicyTimelineResource:
	return _create_timeline_resource(PresetType.BASIC_ANIMATION, duration, "基础动画Timeline")

func create_complex_sequence_timeline(duration: float = 10.0) -> JuicyTimelineResource:
	return _create_timeline_resource(PresetType.COMPLEX_SEQUENCE, duration, "复杂序列Timeline")

func create_event_driven_timeline(duration: float = 5.0) -> JuicyTimelineResource:
	return _create_timeline_resource(PresetType.EVENT_DRIVEN, duration, "事件驱动Timeline")

func create_particle_effect_timeline(duration: float = 3.0) -> JuicyTimelineResource:
	return _create_timeline_resource(PresetType.PARTICLE_EFFECT, duration, "粒子效果Timeline")

func create_ui_feedback_timeline(duration: float = 1.0) -> JuicyTimelineResource:
	return _create_timeline_resource(PresetType.UI_FEEDBACK, duration, "UI反馈Timeline")