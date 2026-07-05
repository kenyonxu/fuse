@tool
extends Control

signal timeline_changed()
signal playback_time_changed(time: float)
signal track_selected(track: JuicyTrack)
signal keyframe_selected(track: JuicyTrack, keyframe: JuicyKeyframe)
signal keyframe_moved(track: JuicyTrack, keyframe: JuicyKeyframe, new_time: float)

# 时间轴配置
var current_timeline: JuicyTimelineResource
var zoom_level: float = 1.0
var pixels_per_second: float = 100.0
var view_offset: float = 0.0
var vertical_offset: float = 6.0  # 垂直偏移，用于调整轨道绘制区域的起始位置
var playback_head_position: float = 0.0

# 吸附配置
var snap_enabled: bool = true
var snap_interval: float = 0.1

# 交互状态
var is_dragging: bool = false
var drag_start_pos: Vector2
var drag_start_time: float
var selected_track: JuicyTrack
var selected_keyframe: JuicyKeyframe
var drag_mode: int = 0  # 0=时间拖动, 1=值拖动, 2=切线拖动
var tangent_handle_type: int = 0  # 0=无, 1=入切线, 2=出切线

# 批量拖动模式（需要用户明确启用）
var batch_drag_enabled: bool = false  # 是否启用批量拖动模式

# 批量选择状态
var selected_keyframes: Array[Dictionary] = []  # [{track, keyframe}, ...]
var is_selecting: bool = false
var is_multi_select: bool = false  # 是否按住Shift/Ctrl键（多选）
var selection_start_pos: Vector2
var mouse_down_pos: Vector2  # 记录鼠标按下时的位置，用于区分点击和拖拽
var selection_threshold: float = 5.0  # 框选阈值（像素），鼠标移动超过这个距离才开始框选

# Clip交互状态
var selected_clip: JuicyTrack  # 当前选中的Clip（Feedback Track）
var clip_drag_mode: int = 0     # Clip拖拽模式：0=无, 1=移动, 2=左边界, 3=右边界
var clip_drag_start_data: Dictionary  # Clip拖拽开始时的数据

# Method Track 交互状态
var selected_method_track: JuicyMethodTrack = null  # 当前选中的Method Track
var method_track_drag_mode: int = 0                  # 0=无, 1=移动触发时间
var method_track_drag_start_data: Dictionary          # 保存拖拽开始时的数据

# 🔥 Phase 3A: Property Track 时间范围交互状态
var time_range_drag_mode: int = 0  # Property Track 时间范围拖拽模式：0=无, 1=移动, 2=左边界, 3=右边界
var time_range_drag_start_data: Dictionary  # 时间范围拖拽开始时的数据
var time_range_tooltip_time: float = -1.0  # 当前拖拽的时间值（用于显示提示）
var time_range_tooltip_pos: Vector2  # 时间提示的屏幕位置

# 提示信息状态
var _no_timeline_hint_visible: bool = false

# 视觉配置
var track_height: float = 35.0
var track_spacing: float = 4.0
var keyframe_size: float = 35.0  # 增加默认关键帧尺寸
var playback_head_width: float = 2.0
var track_name_width: float = 120.0  # 轨道名称显示区宽度
var track_name_padding: float = 5.0  # 轨道名称内边距

# 编辑模式
var edit_mode: int = 0  # 0=传统模式, 1=可视化Clip模式

# 颜色配置
var bg_color: Color = Color(0.15, 0.15, 0.15, 1.0)
var track_bg_color: Color = Color(0.2, 0.2, 0.2, 1.0)
var track_selected_color: Color = Color(0.3, 0.3, 0.4, 1.0)
var grid_color: Color = Color(0.25, 0.25, 0.25, 1.0)
var playback_head_color: Color = Color(1.0, 0.0, 0.0, 1.0)
var keyframe_color: Color = Color(0.0, 1.0, 0.0, 1.0)
var keyframe_selected_color: Color = Color(1.0, 1.0, 0.0, 1.0)

# 当前timeline editor实例
var timeline_editor: JuicyTimelineEditor

# 资源编辑状态
var _is_editing_resource: bool = false  # 是否正在编辑资源
var _last_edited_resource: Resource = null  # 最后编辑的资源

func _init():
	set_custom_minimum_size(Vector2(300, 200))  # 减小最小尺寸，提高适配性
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL

func _ready():
	# 连接输入事件
	gui_input.connect(_on_gui_input)
	draw.connect(_on_draw)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		# 检测双击事件
		if event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_double_click(event.position)
			return  # 双击时不处理单击
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey:
		_handle_key_input(event)

func _handle_mouse_button(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_left_click(event.position)
		else:
			_handle_left_release()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_handle_right_click(event.position)

func _handle_mouse_motion(event: InputEventMouseMotion):
	# 优先处理拖动逻辑（关键帧、批量拖动、Clip拖动）
	# 框选逻辑只在非拖动状态下执行
	
	# 批量拖动逻辑
	if is_dragging and not selected_keyframes.is_empty():
		print("批量拖动 - 模式: ", drag_mode, " 选中关键帧数: ", selected_keyframes.size())
		
		# 计算统一的delta
		var delta_time = _screen_to_time(event.position.x) - _screen_to_time(drag_start_pos.x)
		
		# 根据拖动模式处理
		for sel in selected_keyframes:
			if sel.track is JuicyPropertyTrack:
				var property_track = sel.track as JuicyPropertyTrack
				
				if drag_mode == 0:  # 时间拖动
					# 修复：基于拖动开始时的原始时间计算，避免累积偏移
					# 需要为每个关键帧保存原始时间
					if not sel.has("original_time"):
						sel.original_time = sel.keyframe.time
					
					var new_time = sel.original_time + delta_time
					if snap_enabled:
						new_time = _snap_time(new_time)
					sel.keyframe.time = new_time
					print("  关键帧时间: ", sel.original_time, " -> ", new_time, " (delta: ", delta_time, ")")
				elif drag_mode == 1:  # 值拖动
					var track_rect = _get_track_rect(sel.track)
					var new_value = _screen_to_value(event.position.y, track_rect, property_track)
					new_value = clamp(new_value, property_track.value_range.x, property_track.value_range.y)
					sel.keyframe.value = new_value
					print("  关键帧值: ", sel.keyframe.value, " -> ", new_value)
		
		timeline_changed.emit()
		queue_redraw()
		return
	
	# 关键帧拖拽逻辑（只在批量选择为空时执行）
	if is_dragging and selected_keyframes.is_empty() and selected_keyframe and selected_track and selected_track is JuicyPropertyTrack:
		var property_track = selected_track as JuicyPropertyTrack
		
		if drag_mode == 0:  # 时间拖动
			# 修复：使用增量偏移而不是绝对位置，确保关键帧跟随鼠标移动
			var delta_time = _screen_to_time(event.position.x) - _screen_to_time(drag_start_pos.x)
			var new_time = drag_start_time + delta_time
			if snap_enabled:
				new_time = _snap_time(new_time)
			
			print("单个关键帧拖动 - 模式: 时间, 鼠标X: ", event.position.x, " delta_time: ", delta_time, " 新时间: ", new_time)
			selected_keyframe.time = new_time
			keyframe_moved.emit(selected_track, selected_keyframe, new_time)
			timeline_changed.emit()
			queue_redraw()
		elif drag_mode == 1:  # 值拖动
			var track_rect = _get_track_rect(selected_track)
			var new_value = _screen_to_value(event.position.y, track_rect, property_track)
			new_value = clamp(new_value, property_track.value_range.x, property_track.value_range.y)
			
			print("单个关键帧拖动 - 模式: 值, 鼠标Y: ", event.position.y, " 新值: ", new_value)
			selected_keyframe.value = new_value
			timeline_changed.emit()
			queue_redraw()
		return
	
	# Clip拖拽逻辑
	if is_dragging and selected_clip and clip_drag_mode > 0:
		_handle_clip_drag(event.position)
		return

	# 🔥 Phase 3A: Property Track 时间范围拖拽逻辑
	if is_dragging and selected_track and selected_track is JuicyPropertyTrack and time_range_drag_mode > 0:
		_handle_time_range_drag(event.position)
		return

	# 🔥 Method Track: 拖拽逻辑
	if is_dragging and selected_method_track and method_track_drag_mode > 0:
		_handle_method_track_drag(event.position)
		return

	# 框选逻辑 - 只在非拖动状态下执行
	if is_dragging:
		# 如果正在拖动关键帧或Clip，不进行框选
		return
	
	# 检查是否满足框选条件
	# 1. 批量拖拽模式已启用
	# 2. 按住 Shift 键
	if not batch_drag_enabled or not is_multi_select:
		# 不满足框选条件，清除框选状态
		if is_selecting:
			is_selecting = false
		return
	
	# 检查鼠标是否按下且正在移动
	if not is_selecting and mouse_down_pos != Vector2.ZERO:
		# 计算鼠标移动距离
		var move_distance = event.position.distance_to(mouse_down_pos)
		
		# 只有移动超过阈值才开始框选
		if move_distance > selection_threshold:
			is_selecting = true
			selection_start_pos = mouse_down_pos
			print("鼠标移动超过阈值 (", move_distance, "px)，开始框选")
	
	# 框选逻辑
	if is_selecting:
		queue_redraw()
		_update_selection_from_box(selection_start_pos, event.position)
		return

func _handle_key_input(event: InputEventKey):
	if event.pressed:
		match event.keycode:
			KEY_DELETE:
				_delete_selected_keyframe()
			KEY_SPACE:
				_toggle_playback()

func _handle_double_click(pos: Vector2):
	"""处理双击事件，用于快速编辑Feedback Resource"""
	# 仅在可视化Clip模式下支持双击编辑
	if edit_mode != 1:
		return
	
	var clip_result = _get_clip_at_position(pos)
	if clip_result.track and clip_result.track is JuicyFeedbackTrack:
		var feedback_track = clip_result.track as JuicyFeedbackTrack
		if feedback_track.resource:
			# 设置编辑状态，标记正在编辑Feedback Resource
			_is_editing_resource = true
			_last_edited_resource = feedback_track.resource
			
			# 在检视器中打开资源
			_open_resource_in_inspector(feedback_track.resource)
			
			# 注意：编辑状态将在_handle_left_click中重置

func _open_resource_in_inspector(resource: Resource):
	"""在Godot编辑器检视器中打开资源"""
	# 方案1：添加资源有效性检查和类型检查
	# 注意：Resource类型不支持is_instance_valid()，只检查null即可
	if not resource:
		push_warning("资源无效，无法在检视器中打开")
		return
	
	# 确保只处理Feedback Resource类型，避免类型转换错误
	if not resource is JuicyFeedbackResource:
		push_warning("资源类型不是Feedback Resource，无法在检视器中打开: " + resource.get_class())
		return
	
	var editor_plugin_instance = JuicyTimelineEditorPlugin.get_instance()
	if not editor_plugin_instance:
		push_warning("无法获取Timeline编辑器插件实例")
		return
	
	var editor_interface = Engine.get_singleton("EditorInterface")
	if not editor_interface:
		push_warning("无法获取EditorInterface")
		return
	
	# 检查timeline_editor引用
	# 注意：编辑器UI组件由插件管理，只检查null即可
	if not timeline_editor:
		push_warning("Timeline编辑器引用无效")
		return
	
	# 设置资源编辑状态
	_is_editing_resource = true
	_last_edited_resource = resource
	
	# 使用inspect_object在Inspector中显示资源
	editor_interface.inspect_object(resource)
	editor_plugin_instance.make_bottom_panel_item_visible(timeline_editor)
	
	# 方案3：立即重置编辑状态，不使用延迟
	_is_editing_resource = false
	_last_edited_resource = null

func _handle_left_click(pos: Vector2):
	# 记录鼠标按下时的位置
	mouse_down_pos = pos
	
	# 检查是否按住 Ctrl/Shift 键（多选）
	is_multi_select = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT)
	
	# 优先检查Clip交互（仅在可视化Clip模式下）
	if edit_mode == 1:
		var clip_result = _get_clip_at_position(pos)
		if clip_result.track:
			print("Clip交互被触发 - 轨道: ", clip_result.track.track_name, " 区域: ", clip_result.region)
			_handle_clip_selection(clip_result.track, clip_result.region, pos)
			return

	# 🔥 Phase 3A: 优先检查 Property Track 时间范围交互
	var time_range_result = _get_property_track_time_range_at_position(pos)
	if time_range_result.track and time_range_result.region >= 0:
		print("Property Track 时间范围交互被触发 - 轨道: ", time_range_result.track.track_name, " 区域: ", time_range_result.region)
		_handle_time_range_selection(time_range_result.track, time_range_result.region, pos)
		return

	# 🔥 Method Track: 优先检查 Method Track 标记交互
	var method_result = _get_method_track_at_position(pos)
	if method_result.track:
		print("Method Track 标记交互被触发 - 轨道: ", method_result.track.track_name)
		_handle_method_track_selection(method_result.track, pos)
		return

	# 检查是否点击了关键帧
	var track_index = _get_track_at_position(pos.y)
	if track_index >= 0:
		var track = _get_track_by_index(track_index)
		if track and track is JuicyPropertyTrack:
			var keyframe = _get_keyframe_at_position(track, pos.x)
			if keyframe:
				print("点击关键帧 - 轨道: ", track.track_name, " 时间: ", keyframe.time)
				print("批量拖动模式: ", batch_drag_enabled)
				
				selected_track = track
				selected_keyframe = keyframe
				selected_clip = null  # 清除Clip选择
				is_dragging = true
				drag_start_pos = pos
				drag_start_time = keyframe.time
				
				# 只有在批量拖动模式或按住多选键时才添加到selected_keyframes
				if batch_drag_enabled or is_multi_select:
					# 处理多选
					if not is_multi_select:
						selected_keyframes.clear()
					
					# 检查是否已经选择
					var already_selected = false
					for sel in selected_keyframes:
						if sel.keyframe == keyframe:
							already_selected = true
							break
					
					if not already_selected:
						selected_keyframes.append({track = track, keyframe = keyframe})
					print("添加到批量选择: selected_keyframes.size = ", selected_keyframes.size())
				else:
					# 单个拖动模式：清空批量选择
					selected_keyframes.clear()
					print("单个拖动模式: selected_keyframes已清空")
				
				print("设置拖动状态 - drag_mode: ", drag_mode, " (0=时间, 1=值)")
				print("拖动开始 - start_pos: ", drag_start_pos, " start_time: ", drag_start_time)
				
				# 使用按钮设置的拖动模式，不再自动检测
				# drag_mode 已由用户通过工具栏按钮设置（0=时间拖动，1=值拖动）
				
				keyframe_selected.emit(track, keyframe)
				queue_redraw()
				return
	
	# 检查是否点击了轨道
	if track_index >= 0:
		var track = _get_track_by_index(track_index)
		if track:
			# 点击轨道区域：保持或设置选中状态
			selected_track = track
			selected_keyframe = null
			selected_clip = null
			selected_method_track = null  # 清除 Method Track 选择
			track_selected.emit(track)
			queue_redraw()
			return
	
	# 点击空白区域，开始框选或清除选择
	if not is_multi_select:
		# 清除选择
		selected_keyframes.clear()
		selected_track = null
		selected_keyframe = null
		selected_clip = null
		selected_method_track = null  # 清除 Method Track 选择
		
		# 框选功能需要同时满足两个条件：
		# 1. 批量拖拽模式已启用 (batch_drag_enabled = true)
		# 2. 按住 Shift 键 (is_multi_select = true)
		# 只有同时满足这两个条件才允许框选
		if not batch_drag_enabled or not is_multi_select:
			print("框选功能未启用 - 批量拖拽模式: ", batch_drag_enabled, " Shift键: ", is_multi_select)
			# 发送track_selected信号（null），通知编辑器轨道变为未选中
			track_selected.emit(null)
			return
		
		# 不立即开始框选，等待鼠标移动超过阈值
		print("框选功能已启用，等待鼠标移动以开始框选")
		return
	
	# 发送track_selected信号（null），通知编辑器轨道变为未选中
	track_selected.emit(null)
	
	queue_redraw()
	
	# 在检视器中显示Timeline资源
	_show_timeline_resource_in_inspector()
	
	# 重置资源编辑状态，确保下次操作正常
	if _is_editing_resource:
		print("用户单击空白处，重置资源编辑状态")
		_is_editing_resource = false
		_last_edited_resource = null

func _handle_left_release():
	# 重置框选状态
	is_selecting = false
	
	# 清理批量拖动时保存的原始时间
	if is_dragging:
		for sel in selected_keyframes:
			if sel.has("original_time"):
				sel.erase("original_time")
	
	# 现有的关键帧释放逻辑
	if is_dragging and selected_keyframe:
		# 现有逻辑保持不变
		pass
	
	# 新增：Clip拖拽释放处理
	if is_dragging and selected_clip and clip_drag_mode > 0:
		_handle_clip_release()

	# 🔥 Phase 3A: Property Track 时间范围拖拽释放处理
	if is_dragging and selected_track and selected_track is JuicyPropertyTrack and time_range_drag_mode > 0:
		_handle_time_range_release()

	# 🔥 Method Track: 拖拽释放处理
	if is_dragging and selected_method_track and method_track_drag_mode > 0:
		_handle_method_track_release()

	# 结束框选状态
	if is_selecting:
		is_selecting = false
	
	is_dragging = false

func _handle_right_click(pos: Vector2):
	# 显示上下文菜单
	var context_menu = PopupMenu.new()
	
	# 修复：使用Engine单例直接获取EditorInterface
	var editor_interface = Engine.get_singleton("EditorInterface")
	if editor_interface:
		# 获取编辑器主界面
		var base_control = editor_interface.get_base_control()
		if base_control:
			base_control.add_child(context_menu)
		else:
			# 备选方案：添加到主屏幕
			var main_screen = editor_interface.get_editor_main_screen()
			if main_screen:
				main_screen.add_child(context_menu)
			else:
				# 最后备选：添加到Canvas的父节点
				var parent = get_parent()
				while parent and not parent is Window:
					parent = parent.get_parent()
				if parent:
					parent.add_child(context_menu)
				else:
					add_child(context_menu)
	else:
		# 最后备选：添加到Canvas的父节点
		var parent = get_parent()
		while parent and not parent is Window:
			parent = parent.get_parent()
		if parent:
			parent.add_child(context_menu)
		else:
			add_child(context_menu)
	
	var track_index = _get_track_at_position(pos.y)
	var clip_result = null
	if track_index >= 0:
		var track = _get_track_by_index(track_index)
		if track:
			# 检查是否点击了Clip
			clip_result = _get_clip_at_position(pos)
			print("右键菜单检查 - 轨道: ", track.track_name, " Clip结果: ", clip_result.track != null, " 编辑模式: ", edit_mode)
			if clip_result.track and edit_mode == 1:
				# Clip相关的右键菜单
				context_menu.add_item("复制Clip", 10)
				context_menu.add_item("删除Clip", 11)
				context_menu.add_separator()
				
				# 时长相关菜单
				if track is JuicyFeedbackTrack:
					var feedback_track = track as JuicyFeedbackTrack
					var duration_source = feedback_track.get_duration_source()
					
					if feedback_track.duration > 0:
						# 手动模式菜单
						context_menu.add_item("重置为资源时长", 13)
						context_menu.add_item("更新为当前资源时长", 14)
					else:
						# 跟随模式菜单
						context_menu.add_item("设为固定时长", 15)
						if duration_source == JuicyFeedbackResource.DurationSource.ESTIMATED:
							context_menu.add_item("锁定当前估算时长", 16)
						if duration_source == JuicyFeedbackResource.DurationSource.EXACT:
							context_menu.add_item("同步资源时长", 17)
					
					context_menu.add_separator()
				
				context_menu.add_item("Clip属性...", 12)
			else:
				# 现有的轨道菜单
				context_menu.add_item("添加关键帧", 0)
				context_menu.add_separator()
				context_menu.add_item("删除轨道", 1)
				
				# 为选中的关键帧添加插值类型切换菜单
				if selected_keyframe and selected_track is JuicyPropertyTrack:
					context_menu.add_separator()
					context_menu.add_item("插值类型:", 100)
					context_menu.add_item("  线性 (Linear)", 101)
					context_menu.add_item("  缓入 (Ease In)", 102)
					context_menu.add_item("  缓出 (Ease Out)", 103)
					context_menu.add_item("  缓入缓出 (Ease In-Out)", 104)
					context_menu.add_item("  阶跃 (Step)", 105)
					context_menu.add_item("  自定义 (Custom)", 106)
					# 设置当前插值类型的选中标记
					match selected_keyframe.interpolation:
						JuicyKeyframe.InterpolationType.LINEAR:
							context_menu.set_item_checked(101, true)
						JuicyKeyframe.InterpolationType.EASE_IN:
							context_menu.set_item_checked(102, true)
						JuicyKeyframe.InterpolationType.EASE_OUT:
							context_menu.set_item_checked(103, true)
						JuicyKeyframe.InterpolationType.EASE_IN_OUT:
							context_menu.set_item_checked(104, true)
						JuicyKeyframe.InterpolationType.STEP:
							context_menu.set_item_checked(105, true)
						JuicyKeyframe.InterpolationType.CUSTOM:
							context_menu.set_item_checked(106, true)

				# 🔥 Phase 3A: 为 Property Track 添加时间范围菜单
				var time_range_result = _get_property_track_time_range_at_position(pos)
				if time_range_result.track and time_range_result.region >= 0:
					context_menu.add_separator()
					context_menu.add_item("重置时间范围", 30)
					context_menu.add_item("适应关键帧范围", 31)

			# 🔥 Phase 3B: 为 Property Track 添加 Bake 菜单
			if track is JuicyPropertyTrack:
				var property_track = track as JuicyPropertyTrack
				context_menu.add_separator()
				if property_track.edit_mode == JuicyPropertyTrack.EditMode.CURVE_BASED:
					# Curve 模式：显示 Bake Curve → Keyframes 选项
					if property_track.animation_curve != null:
						context_menu.add_item("Bake Curve → Keyframes", 32)
				elif property_track.edit_mode == JuicyPropertyTrack.EditMode.KEYFRAME_BASED:
					# Keyframe 模式：显示 Bake Keyframes → Curve 选项
					if not property_track.keyframes.is_empty():
						context_menu.add_item("Bake Keyframes → Curve", 33)

				# 🔥 Phase 3C: 为 Property Track 添加 Curve Preset 子菜单
				context_menu.add_separator()
				var preset_submenu = PopupMenu.new()
				preset_submenu.name = "CurvePresetSubmenu"  # 设置子菜单名称
				context_menu.add_child(preset_submenu)  # 添加为子节点
				_add_curve_preset_submenu_items(preset_submenu)
				context_menu.add_submenu_item("Apply Preset", "CurvePresetSubmenu", 300)
				# 连接子菜单的信号
				preset_submenu.id_pressed.connect(func(id: int):
					var preset_index = id - 301  # 调整偏移量到 0-24
					if preset_index >= 0 and preset_index <= 24:
						# 🔥 使用 -2 标志强制应用，即使值相同也会应用
						property_track._pending_curve_preset = -2
						# 设置 curve_preset（setter 会检测到 -2 标志并强制应用）
						property_track.curve_preset = preset_index
						# 恢复默认状态
						property_track._pending_curve_preset = -1
						timeline_changed.emit()
						queue_redraw()
				)
	else:
		context_menu.add_item("添加轨道", 2)
	
	# 添加批量操作选项（如果有选中的关键帧）
	if not selected_keyframes.is_empty():
		context_menu.add_separator()
		context_menu.add_item("删除选中关键帧", 200)
		context_menu.add_item("复制选中关键帧", 201)
		context_menu.add_item("清空选择", 202)
	
	# 添加编辑模式切换选项
	context_menu.add_separator()
	if edit_mode == 0:
		context_menu.add_item("切换到可视化Clip模式", 20)
	else:
		context_menu.add_item("切换到传统模式", 21)
	
	# 创建菜单关闭回调
	var menu_closed = false
	context_menu.id_pressed.connect(func(id: int):
		match id:
			0: _add_keyframe_at_position(pos)
			1: _remove_track_at_index(track_index)
			2: _add_new_track()
			10:
				if clip_result: _duplicate_clip(clip_result.track)
			11:
				if clip_result: _delete_clip(clip_result.track)
			12:
				if clip_result: _show_clip_properties(clip_result.track)
			13:
				if clip_result: _reset_clip_to_resource_duration(clip_result.track)
			14:
				if clip_result: _update_clip_to_current_resource_duration(clip_result.track)
			15:
				if clip_result: _set_clip_fixed_duration(clip_result.track)
			16:
				if clip_result: _lock_clip_estimated_duration(clip_result.track)
			17:
				if clip_result: _sync_clip_with_resource(clip_result.track)
			20: set_edit_mode(1)
			21: set_edit_mode(0)
			101:
				if selected_keyframe: selected_keyframe.interpolation = JuicyKeyframe.InterpolationType.LINEAR
			102:
				if selected_keyframe: selected_keyframe.interpolation = JuicyKeyframe.InterpolationType.EASE_IN
			103:
				if selected_keyframe: selected_keyframe.interpolation = JuicyKeyframe.InterpolationType.EASE_OUT
			104:
				if selected_keyframe: selected_keyframe.interpolation = JuicyKeyframe.InterpolationType.EASE_IN_OUT
			105:
				if selected_keyframe: selected_keyframe.interpolation = JuicyKeyframe.InterpolationType.STEP
			106:
				if selected_keyframe: selected_keyframe.interpolation = JuicyKeyframe.InterpolationType.CUSTOM
			200:  # 批量删除关键帧
				_delete_selected_keyframes()
			201:  # 批量复制关键帧
				_copy_selected_keyframes()
			202:  # 清空选择
				selected_keyframes.clear()
				queue_redraw()
			30:  # 🔥 Phase 3A: 重置时间范围
				if selected_track and selected_track is JuicyPropertyTrack:
					var property_track = selected_track as JuicyPropertyTrack
					property_track.time_start = 0.0
					property_track.time_end = current_timeline.timeline_duration if current_timeline else 2.0
					timeline_changed.emit()
					queue_redraw()
			31:  # 🔥 Phase 3A: 适应关键帧范围
				if selected_track and selected_track is JuicyPropertyTrack:
					var property_track = selected_track as JuicyPropertyTrack
					if not property_track.keyframes.is_empty():
						# 找到最早和最晚的关键帧时间
						var min_time = property_track.keyframes[0].time
						var max_time = property_track.keyframes[0].time
						for kf in property_track.keyframes:
							min_time = min(min_time, kf.time)
							max_time = max(max_time, kf.time)
						property_track.time_start = min_time
						property_track.time_end = max_time
						timeline_changed.emit()
						queue_redraw()
			32:  # 🔥 Phase 3B: Bake Curve → Keyframes
				if selected_track and selected_track is JuicyPropertyTrack:
					var property_track = selected_track as JuicyPropertyTrack
					property_track.bake_curve_to_keyframes()
					timeline_changed.emit()
					queue_redraw()
			33:  # 🔥 Phase 3B: Bake Keyframes → Curve
				if selected_track and selected_track is JuicyPropertyTrack:
					var property_track = selected_track as JuicyPropertyTrack
					property_track.bake_keyframes_to_curve()
					timeline_changed.emit()
					queue_redraw()

		# 插值类型改变后更新
		if id >= 101 and id <= 106:
			timeline_changed.emit()
			queue_redraw()
		menu_closed = true
		context_menu.queue_free()
	)
	
	# 添加菜单关闭信号监听，确保菜单能正确消失
	context_menu.popup_hide.connect(func():
		if not menu_closed:
			context_menu.queue_free()
	)
	
	# 获取正确的全局鼠标位置
	var global_pos = DisplayServer.mouse_get_position()
	
	context_menu.position = global_pos
	context_menu.popup()

func _on_draw():
	# 绘制背景
	draw_rect(Rect2(Vector2.ZERO, size), bg_color)
	
	# 绘制无Timeline提示信息
	if not current_timeline:
		_draw_no_timeline_hint()
		return
	
	# 绘制网格
	_draw_grid()
	
	# 绘制轨道
	_draw_tracks()
	
	# 绘制选择框（如果在框选状态）
	if is_selecting:
		var mouse_pos = get_local_mouse_position()
		_draw_selection_box(selection_start_pos, mouse_pos)
	
	# 绘制播放头
	_draw_playback_head()

	# 🔥 Phase 3A: 绘制时间范围拖拽提示
	if time_range_tooltip_time >= 0:
		_draw_time_tooltip(time_range_tooltip_pos, time_range_tooltip_time)

# 显示/隐藏无Timeline提示信息
func show_no_timeline_hint():
	"""显示无Timeline资源时的提示信息"""
	_no_timeline_hint_visible = true
	queue_redraw()

func hide_no_timeline_hint():
	"""隐藏无Timeline资源时的提示信息"""
	_no_timeline_hint_visible = false
	queue_redraw()

func _draw_no_timeline_hint():
	"""绘制无Timeline资源时的提示信息"""
	if not _no_timeline_hint_visible:
		return
	
	var rect = get_rect()
	var font = ThemeDB.fallback_font
	var hint_text = "请选择一个Timeline资源以开始编辑"
	var text_size = font.get_string_size(hint_text)
	var text_pos = Vector2(
		(rect.size.x - text_size.x) / 2,
		(rect.size.y - text_size.y) / 2
	)
	
	# 绘制半透明背景
	var bg_rect = Rect2(
		text_pos.x - 20,
		text_pos.y - 10,
		text_size.x + 40,
		text_size.y + 20
	)
	draw_rect(bg_rect, Color(0.0, 0.0, 0.0, 0.5))
	
	# 绘制文本
	draw_string(font, text_pos, hint_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

func _draw_grid():
	var rect = get_rect()
	# 修复：直接计算可见时间范围，避免双重偏移
	var start_time = view_offset
	var end_time = view_offset + rect.size.x / (pixels_per_second * zoom_level)
	
	# 绘制垂直网格线（时间刻度）
	var interval = _get_grid_interval()
	var current_time = floor(start_time / interval) * interval
	
	while current_time <= end_time:
		# 修复：直接计算屏幕位置，避免双重偏移
		var x = (current_time - view_offset) * pixels_per_second * zoom_level
		if x >= 0 and x <= rect.size.x:
			draw_line(Vector2(x, 0), Vector2(x, rect.size.y), grid_color)
		current_time += interval

func _get_grid_interval() -> float:
	# 根据缩放级别选择合适的网格间隔
	var pixels_per_interval = pixels_per_second * zoom_level
	
	if pixels_per_interval >= 200:
		return 1.0
	elif pixels_per_interval >= 100:
		return 0.5
	elif pixels_per_interval >= 50:
		return 0.25
	elif pixels_per_interval >= 25:
		return 0.1
	else:
		return 0.05

func _draw_tracks():
	if not current_timeline:
		return
	
	var all_tracks = current_timeline.get_all_tracks()
	var y_offset = vertical_offset  # 使用垂直偏移
	
	# 绘制默认占位轨道（用于对齐，无法被选择）
	var placeholder_rect = Rect2(0, y_offset, size.x, track_height)
	var placeholder_color = Color(0.2, 0.2, 0.2, 0.5)  # 半透明灰色
	draw_rect(placeholder_rect, placeholder_color)
	
	# 绘制占位轨道文本
	var placeholder_text = "占位轨道（不可选择）"
	var font = ThemeDB.fallback_font
	var text_pos = Vector2(
		track_name_padding,
		y_offset + track_height / 2 + 1
	)
	draw_string(font, text_pos, placeholder_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.5, 1.0))
	
	y_offset += track_height + track_spacing
	
	for i in range(all_tracks.size()):
		var track = all_tracks[i]
		var track_rect = Rect2(0, y_offset, size.x, track_height)
		
		# 只有当轨道在可见区域内时才绘制背景
		var track_visible = track_rect.position.y + track_rect.size.y > 0 and track_rect.position.y < size.y
		if not track_visible:
			print("轨道背景不在可见区域内 - 轨道: ", track.track_name, " 轨道Y: ", track_rect.position.y, " 轨道高度: ", track_rect.size.y, " Canvas高度: ", size.y)
			y_offset += track_height + track_spacing
			continue
		
		# 绘制轨道背景
		var track_color = track_bg_color
		if track == selected_track:
			track_color = track_selected_color
		draw_rect(track_rect, track_color)
		
		# 绘制轨道名称（固定在左侧）
		_draw_track_name(track, track_rect)
		
		# 绘制轨道内容
		_draw_track_content(track, track_rect)
		
		y_offset += track_height + track_spacing

func _draw_track_name(track: JuicyTrack, track_rect: Rect2):
	"""绘制轨道名称（固定在左侧，不随横向滚动）"""
	var font = ThemeDB.fallback_font
	
	# 获取轨道名称
	var track_name = "未命名轨道"
	if track.has_method("get_track_name"):
		track_name = track.get_track_name()
	elif track.has_property("track_name"):
		track_name = track.track_name
	
	# 定义名称显示区域（固定在左侧）
	var name_rect = Rect2(
		track_name_padding,
		track_rect.position.y + 2,
		track_name_width - track_name_padding * 2,
		track_rect.size.y - 4
	)
	
	# 绘制半透明背景（提高可读性）
	var bg_color = Color(0.0, 0.0, 0.0, 0.3)
	if track == selected_track:
		bg_color = Color(1.0, 1.0, 1.0, 0.15)
	draw_rect(name_rect, bg_color)
	
	# 绘制轨道名称文本
	var text_pos = Vector2(
		name_rect.position.x + track_name_padding,
		track_rect.position.y + track_rect.size.y / 2 + 1
	)
	
	# 限制文本宽度，超出时使用省略号
	var text_size = font.get_string_size(track_name)
	if text_size.x > name_rect.size.x - track_name_padding * 2:
		# 简单处理：直接绘制，超出部分会被裁剪
		draw_string(font, text_pos, track_name, HORIZONTAL_ALIGNMENT_LEFT, name_rect.size.x, 10, Color.WHITE)
	else:
		draw_string(font, text_pos, track_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func _draw_track_content(track: JuicyTrack, track_rect: Rect2):
	# 根据轨道类型绘制不同的内容
	# 注意：轨道内容绘制区域需要为轨道名称预留空间
	var content_rect = Rect2(
		track_name_width,
		track_rect.position.y,
		track_rect.size.x - track_name_width,
		track_rect.size.y
	)
	
	match track.get_track_type():
		"Property":
			_draw_property_track(track, content_rect)
		"Feedback":
			_draw_feedback_track(track, content_rect)
		"Method":
			_draw_method_track(track, content_rect)
		"Event":
			_draw_event_track(track, content_rect)

func _draw_property_track(track: JuicyTrack, track_rect: Rect2):
	if not track is JuicyPropertyTrack:
		return

	var property_track = track as JuicyPropertyTrack

	# 只有当轨道在可见区域内时才绘制
	var track_visible = track_rect.position.y + track_rect.size.y > 0 and track_rect.position.y < size.y
	if not track_visible:
		print("属性轨道不在可见区域内 - 轨道: ", track.track_name, " 轨道Y: ", track_rect.position.y, " 轨道高度: ", track_rect.size.y, " Canvas高度: ", size.y)
		return

	# 🔥 Phase 3B: 根据 edit_mode 决定绘制内容
	match property_track.edit_mode:
		property_track.EditMode.CURVE_BASED:
			# Curve 模式：只绘制 animation_curve
			if property_track.animation_curve:
				_draw_animation_curve(property_track, track_rect)

		property_track.EditMode.KEYFRAME_BASED:
			# Keyframe 模式：绘制关键帧曲线（如果有足够的关���帧）
			if property_track.keyframes.size() >= 2:
				_draw_keyframe_curve(property_track, track_rect)

	# 🔥 Phase 3A: 绘制时间范围标记
	_draw_property_track_time_range(property_track, track_rect)

	# 🔥 Phase 3B: 只在 Keyframe Based 模式下绘制关键帧
	if property_track.edit_mode == property_track.EditMode.KEYFRAME_BASED:
		for keyframe in property_track.keyframes:
			var x = _time_to_screen(keyframe.time)
			# 只有当关键帧在可见区域内时才绘制
			if x >= 0 and x <= size.x:
				_draw_keyframe(keyframe, track_rect)

func _draw_feedback_track(track: JuicyTrack, track_rect: Rect2):
	if not track is JuicyFeedbackTrack:
		return
	
	var feedback_track = track as JuicyFeedbackTrack
	
	match edit_mode:
		0:  # 传统模式
			_draw_feedback_track_traditional(feedback_track, track_rect)
		1:  # 可视化Clip模式
			_draw_feedback_track_visual(feedback_track, track_rect)

func _draw_feedback_track_traditional(track: JuicyFeedbackTrack, track_rect: Rect2):
	# 传统模式绘制逻辑
	var start_x = _time_to_screen(track.start_time)
	var duration = track.get_actual_duration()
	var end_x = _time_to_screen(track.start_time + duration)
	var block_rect = Rect2(start_x, track_rect.position.y + 2, end_x - start_x, track_rect.size.y - 4)
	draw_rect(block_rect, Color.ORANGE)
	
	if track.resource:
		var label = track.resource.get_class()
		draw_string(ThemeDB.fallback_font, block_rect.position + Vector2(2, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

func _draw_feedback_track_visual(track: JuicyFeedbackTrack, track_rect: Rect2):
	# 可视化Clip模式绘制逻辑
	var start_x = _time_to_screen(track.start_time)
	var duration = track.get_actual_duration()
	var end_x = _time_to_screen(track.start_time + duration)
	
	# 只有当Clip在可见区域内时才绘制
	if start_x > size.x or end_x < 0:
		# Clip超出可见范围，跳过绘制
		return
	
	var block_rect = Rect2(start_x, track_rect.position.y + 2, end_x - start_x, track_rect.size.y - 4)
	
	# 获取时长类型
	var duration_source = track.get_duration_source()
	var duration_desc = track.get_duration_description()
	
	# 根据时长类型选择样式
	var clip_color = Color.CADET_BLUE
	var border_solid = true
	var show_duration_label = true
	var show_lock_icon = false
	var show_wave_icon = false
	
	match duration_source:
		JuicyFeedbackResource.DurationSource.MANUAL:
			clip_color = Color.GREEN
			border_solid = true
			show_duration_label = true
		JuicyFeedbackResource.DurationSource.EXACT:
			clip_color = Color.CADET_BLUE
			border_solid = true
			show_lock_icon = true
		JuicyFeedbackResource.DurationSource.ESTIMATED:
			clip_color = Color.ORANGE
			border_solid = false
			show_wave_icon = true
	
	# 如果被选中，使用黄色
	if track == selected_clip:
		clip_color = Color.YELLOW
	
	# 绘制Clip主体
	draw_rect(block_rect, clip_color)
	
	# 如果是估算时长，绘制虚线边框
	if not border_solid:
		_draw_dashed_border(block_rect, Color.WHITE)
	
	# 绘制Clip内容 - 资源类型
	if track.resource:
		var label = track.resource.get_class()
		draw_string(ThemeDB.fallback_font, block_rect.position + Vector2(2, 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	
	# 绘制时长描述
	if show_duration_label:
		var duration_label = duration_desc.split(": ")[1]  # 提取时长部分
		draw_string(ThemeDB.fallback_font, block_rect.position + Vector2(2, 22), duration_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
	
	# 绘制图标
	if show_lock_icon:
		_draw_lock_icon(block_rect.position + Vector2(block_rect.size.x - 18, 4))
	elif show_wave_icon:
		_draw_wave_icon(block_rect.position + Vector2(block_rect.size.x - 18, 4))
	
	# 绘制交互元素
	if track == selected_clip:
		_draw_clip_selection(track, block_rect)
	
	# 检查鼠标位置和边界可拖拽状态
	var mouse_pos = get_local_mouse_position()
	var is_over_clip = block_rect.has_point(mouse_pos)
	var can_drag_left = false
	var can_drag_right = false
	
	if is_over_clip:
		var handle_width = 12.0
		can_drag_left = mouse_pos.x >= start_x and mouse_pos.x <= start_x + handle_width
		can_drag_right = mouse_pos.x >= end_x - handle_width and mouse_pos.x <= end_x
	
	# 绘制手柄（根据可拖拽状态使用不同颜色）
	if track == selected_clip or is_over_clip:
		_draw_clip_handles_with_feedback(track, block_rect, can_drag_left, can_drag_right)

func _draw_method_track(track: JuicyTrack, track_rect: Rect2):
	if not track is JuicyMethodTrack:
		return

	var method_track = track as JuicyMethodTrack

	# 可见性检查
	var track_visible = track_rect.position.y + track_rect.size.y > 0 and track_rect.position.y < size.y
	if not track_visible:
		return

	# 计算所有触发时间点
	var trigger_times = _calculate_method_trigger_times(method_track)

	for i in range(trigger_times.size()):
		var trigger_time = trigger_times[i]
		var x = _time_to_screen(trigger_time)

		# 只有当标记在可见区域内时才绘制
		if x >= 0 and x <= size.x:
			var y = track_rect.position.y + track_rect.size.y / 2
			var is_primary = (i == 0)  # 第一个是主触发点

			if is_primary:
				# 主触发点：绘制可拖拽图标 + 详细信息
				_draw_primary_method_trigger(method_track, x, y, track_rect)
			else:
				# 重复触发点：绘制弱化标记
				_draw_repeat_method_marker(x, y, track_rect)

func _draw_event_track(track: JuicyTrack, track_rect: Rect2):
	if not track is JuicyEventTrack:
		return
	
	var event_track = track as JuicyEventTrack
	
	# 只有当轨道在可见区域内时才绘制
	var track_visible = track_rect.position.y + track_rect.size.y > 0 and track_rect.position.y < size.y
	if not track_visible:
		print("事件轨道不在可见区域内 - 轨道: ", track.track_name, " 轨道Y: ", track_rect.position.y, " 轨道高度: ", track_rect.size.y, " Canvas高度: ", size.y)
		return
	
	# 绘制事件标记
	var x = _time_to_screen(event_track.trigger_time)
	# 只有当标记在可见区域内时才绘制
	if x >= 0 and x <= size.x:
		var marker_rect = Rect2(x - 4, track_rect.position.y + 4, 8, track_rect.size.y - 8)
		draw_rect(marker_rect, Color.YELLOW)
		
		# 绘制事件名
		if event_track.juicy_event or event_track.event_template:
			var event_name = "Event"
			if event_track.juicy_event:
				event_name = event_track.juicy_event.get_class()
			elif event_track.event_template:
				event_name = event_track.event_template.get_class()
			draw_string(ThemeDB.fallback_font, Vector2(x + 6, track_rect.position.y + 12), event_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

func _draw_keyframe(keyframe: JuicyKeyframe, track_rect: Rect2):
	var x = _time_to_screen(keyframe.time)
	var y = track_rect.position.y + track_rect.size.y / 2
	
	# 调试：检查关键帧选中状态
	var is_selected = (keyframe == selected_keyframe)
	if is_selected:
		print("绘制选中关键帧 - 时间: ", keyframe.time)
	
	# 获取关键帧图标
	var keyframe_icon = _get_keyframe_icon(keyframe)
	
	# 调试：输出图标信息
	if keyframe_icon:
		print("绘制关键帧图标 - 插值类型: ", keyframe.interpolation, " 图标尺寸: ", keyframe_icon.get_size())
	else:
		print("绘制关键帧图标 - 使用钻石形状，尺寸: ", keyframe_size)
	
	# 计算实际图标尺寸 - 考虑缩放级别
	var base_size = keyframe_size
	var scaled_size = base_size * max(0.5, min(2.0, zoom_level))  # 根据缩放级别调整尺寸
	
	var actual_icon_size = scaled_size
	if keyframe_icon and keyframe_icon is Texture2D:
		var icon_texture_size = keyframe_icon.get_size()
		# 如果主题图标较小，使用缩放后的尺寸；如果较大，限制最大尺寸
		if icon_texture_size.x < scaled_size and icon_texture_size.y < scaled_size:
			# 主题图标较小，放大到缩放后尺寸
			actual_icon_size = scaled_size
		else:
			# 主题图标较大，限制最大尺寸为缩放后尺寸
			actual_icon_size = min(icon_texture_size.x, icon_texture_size.y, scaled_size)
	
	# 计算图标绘制位置
	var icon_rect = Rect2(x - actual_icon_size/2, y - actual_icon_size/2, actual_icon_size, actual_icon_size)
	
	# 绘制图标
	if keyframe_icon:
		# 修复：添加空值检查，避免纹理为null时的错误
		if keyframe_icon is Texture2D:
			# 使用实际图标尺寸进行绘制
			var src_rect = Rect2(Vector2.ZERO, keyframe_icon.get_size())
			draw_texture_rect_region(keyframe_icon, icon_rect, src_rect, Color.WHITE, false, false)
	else:
		# 备选方案：绘制钻石形状的关键帧
		var points = PackedVector2Array([
			Vector2(x, y - actual_icon_size/2),      # 顶点
			Vector2(x + actual_icon_size/2, y),      # 右点
			Vector2(x, y + actual_icon_size/2),      # 底点
			Vector2(x - actual_icon_size/2, y)       # 左点
		])
		
		var color = keyframe_color
		# 使用之前计算的 is_selected 变量
		if is_selected:
			color = keyframe_selected_color
			print("使用选中颜色绘制关键帧")
		
		draw_colored_polygon(points, color)

# 获取关键帧图标
func _get_keyframe_icon(keyframe: JuicyKeyframe) -> Texture2D:
	"""根据关键帧类型获取对应的图标 - 使用编辑器内置图标"""
	# 使用编辑器主题图标
	var editor_interface = Engine.get_singleton("EditorInterface")
	if not editor_interface:
		return null
	
	var editor_theme = editor_interface.get_editor_theme()
	if not editor_theme:
		return null
	
	# 根据选中状态选择不同的图标
	if keyframe == selected_keyframe:
		# 选中状态使用 KeySelected 图标
		return editor_theme.get_icon("KeySelected", "EditorIcons")
	else:
		# 默认状态使用 KeyValue 图标
		return editor_theme.get_icon("KeyValue", "EditorIcons")

## 根据插值类型创建图标（已弃用 - 现在使用编辑器内置图标）
## 保留此函数以备将来需要自定义图标时使用
func _create_interpolation_icon(keyframe: JuicyKeyframe, is_selected: bool) -> Texture2D:
	var size = max(12, int(keyframe_size))
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var color = keyframe_selected_color if is_selected else keyframe_color
	
	match keyframe.interpolation:
		JuicyKeyframe.InterpolationType.LINEAR:
			# 菱形
			_draw_diamond_shape(image, size, color)
		JuicyKeyframe.InterpolationType.EASE_IN:
			# 三角形（指向右）
			_draw_triangle_shape(image, size, color, false)
		JuicyKeyframe.InterpolationType.EASE_OUT:
			# 三角形（指向左）
			_draw_triangle_shape(image, size, color, true)
		JuicyKeyframe.InterpolationType.EASE_IN_OUT:
			# 圆形
			_draw_circle_shape(image, size, color)
		JuicyKeyframe.InterpolationType.STEP:
			# 正方形
			_draw_square_shape(image, size, color)
		JuicyKeyframe.InterpolationType.CUSTOM:
			# 星形
			_draw_star_shape(image, size, color)
		_:
			# 默认菱形
			_draw_diamond_shape(image, size, color)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

## 绘制菱形
func _draw_diamond_shape(image: Image, size: int, color: Color):
	var center = size / 2
	for y in range(size):
		for x in range(size):
			var dx = abs(x - center)
			var dy = abs(y - center)
			if dx + dy <= center:
				image.set_pixel(x, y, color)

## 绘制三角形
func _draw_triangle_shape(image: Image, size: int, color: Color, point_left: bool):
	if point_left:
		# 指向左的三角形
		var p0 = Vector2(2, size / 2)
		var p1 = Vector2(size - 2, 2)
		var p2 = Vector2(size - 2, size - 2)
		_fill_triangle(image, p0, p1, p2, color)
	else:
		# 指向右的三角形
		var p0 = Vector2(size - 2, size / 2)
		var p1 = Vector2(2, 2)
		var p2 = Vector2(2, size - 2)
		_fill_triangle(image, p0, p1, p2, color)

## 填充三角形
func _fill_triangle(image: Image, p0: Vector2, p1: Vector2, p2: Vector2, color: Color):
	var min_x = max(0, min(p0.x, p1.x, p2.x))
	var max_x = min(image.get_width() - 1, max(p0.x, p1.x, p2.x))
	var min_y = max(0, min(p0.y, p1.y, p2.y))
	var max_y = min(image.get_height() - 1, max(p0.y, p1.y, p2.y))
	
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if _point_in_triangle(Vector2(x, y), p0, p1, p2):
				image.set_pixel(x, y, color)

## 检查点是否在三角形内（使用重心坐标）
func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var as_x = p.x - a.x
	var as_y = p.y - a.y
	var s_ab = (b.x - a.x) * as_y - (b.y - a.y) * as_x > 0.0
	
	if ((c.x - a.x) * as_y - (c.y - a.y) * as_x > 0.0) == s_ab:
		return false
	
	if ((c.x - b.x) * (p.y - b.y) - (c.y - b.y) * (p.x - b.x) > 0.0) != s_ab:
		return false
	
	return true

## 绘制圆形
func _draw_circle_shape(image: Image, size: int, color: Color):
	var center = size / 2.0
	var radius = center - 1
	for y in range(size):
		for x in range(size):
			var dx = x - center
			var dy = y - center
			if dx * dx + dy * dy <= radius * radius:
				image.set_pixel(x, y, color)

## 绘制正方形
func _draw_square_shape(image: Image, size: int, color: Color):
	var margin = 1
	for y in range(margin, size - margin):
		for x in range(margin, size - margin):
			image.set_pixel(x, y, color)

## 绘制星形
func _draw_star_shape(image: Image, size: int, color: Color):
	var center = Vector2(size / 2.0, size / 2.0)
	var outer_radius = center.x - 1
	var inner_radius = outer_radius * 0.4
	var num_points = 5
	
	for y in range(size):
		for x in range(size):
			var point = Vector2(x, y)
			var angle = atan2(point.y - center.y, point.x - center.x)
			var dist = point.distance_to(center)
			
			# 计算星形在这个角度的半径
			var point_index = floor(angle / (PI / num_points))
			var segment_angle = angle - point_index * (PI / num_points)
			var segment_radius = outer_radius if point_index % 2 == 0 else inner_radius
			
			# 使用线性插值计算实际半径
			var actual_radius = lerp(inner_radius, outer_radius, cos(segment_angle) * 0.5 + 0.5)
			
			if dist <= actual_radius:
				image.set_pixel(x, y, color)

# 创建钻石形状图标
func _create_diamond_icon(size: float, color: Color) -> Texture2D:
	"""创建一个钻石形状的图标"""
	# 确保尺寸至少为8x8，提供更好的可见性
	var actual_size = max(8, int(size))
	var image = Image.create(actual_size, actual_size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# 绘制钻石形状
	var center = actual_size / 2
	var points = PackedVector2Array([
		Vector2(center, 0),              # 顶点
		Vector2(actual_size, center),      # 右点
		Vector2(center, actual_size),      # 底点
		Vector2(0, center)               # 左点
	])
	
	# 使用简单的算法绘制填充的钻石
	for y in range(actual_size):
		for x in range(actual_size):
			var dx = abs(x - center)
			var dy = abs(y - center)
			if dx + dy <= center:
				image.set_pixel(x, y, color)
	
	# 添加边框以提高可见性
	for y in range(actual_size):
		for x in range(actual_size):
			var dx = abs(x - center)
			var dy = abs(y - center)
			# 在边界附近绘制白色边框
			if abs(dx + dy - center) < 1.5:
				image.set_pixel(x, y, Color.WHITE)
	
	var texture = ImageTexture.new()
	texture.set_image(image)
	
	# 调试：输出创建的图标信息
	print("创建钻石形状图标 - 请求尺寸: ", size, " 实际尺寸: ", actual_size)
	
	return texture

func _draw_playback_head():
	# 计算播放头在屏幕上的位置
	var x = _time_to_screen(playback_head_position)

	# 只有当播放头在可见区域内时才绘制
	if x >= 0 and x <= size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), playback_head_color, playback_head_width)

		# 在每个 Property Track 上显示当前值
		if current_timeline:
			var all_tracks = current_timeline.get_all_tracks()
			for track in all_tracks:
				if track is JuicyPropertyTrack:
					var track_rect = _get_track_rect(track)
					if track_rect.has_point(Vector2(x, track_rect.position.y + track_rect.size.y / 2)):
						var property_track = track as JuicyPropertyTrack
						var value = property_track.get_value_at_time(playback_head_position, null)
						_draw_value_tooltip(Vector2(x + 5, track_rect.position.y), value)

	# 注意：播放头在屏幕外是正常行为（用户滚动时间轴时），不需要报告错误

## 绘制值提示框
func _draw_value_tooltip(pos: Vector2, value: Variant):
	var text: String
	var value_type = typeof(value)

	# 根据值类型生成不同的文本
	match value_type:
		TYPE_FLOAT:
			text = "%.3f" % value
		TYPE_INT:
			text = str(value)
		TYPE_VECTOR2:
			var v2 = value as Vector2
			text = "(%.2f, %.2f)" % [v2.x, v2.y]
		TYPE_VECTOR3:
			var v3 = value as Vector3
			text = "(%.2f, %.2f, %.2f)" % [v3.x, v3.y, v3.z]
		TYPE_COLOR:
			var c = value as Color
			text = "(%.2f, %.2f, %.2f, %.2f)" % [c.r, c.g, c.b, c.a]
		TYPE_BOOL:
			text = "true" if value else "false"
		_:
			text = str(value)

	var font = ThemeDB.fallback_font
	var font_size = 14  # 🔥 增大字体大小（从默认10改为14）
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	# 🔥 修复文字位置：确保文字在框内
	# bg_rect 的位置需要考虑文字的 baseline，文字会从 baseline 向上延伸
	var bg_rect = Rect2(pos.x, pos.y - text_size.y - 4, text_size.x + 10, text_size.y + 8)
	draw_rect(bg_rect, Color(0.0, 0.0, 0.0, 0.8))
	draw_rect(bg_rect, Color.WHITE, false, 1.0)

	# 🔥 文字居中显示
	# 水平居中：计算文字的 x 位置
	var text_x = bg_rect.position.x + (bg_rect.size.x - text_size.x) / 2
	# 垂直居中：调整 baseline 位置（文字从 baseline 向上延伸，但约有 20% 在 baseline 下方）
	var text_y = bg_rect.position.y + bg_rect.size.y / 2 + text_size.y * 0.2
	draw_string(font, Vector2(text_x, text_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

## 🔥 Phase 3A: 绘制时间提示框（用于时间范围拖拽）
func _draw_time_tooltip(pos: Vector2, time: float):
	var text = "%.2fs" % time
	var font = ThemeDB.fallback_font
	var font_size = 14
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	# 创建背景矩形（位置需要考虑文字的 baseline）
	var bg_rect = Rect2(pos.x + 15, pos.y - text_size.y - 8, text_size.x + 10, text_size.y + 6)
	draw_rect(bg_rect, Color(0.0, 0.0, 0.0, 0.8))
	draw_rect(bg_rect, Color.CYAN, false, 1.0)

	# 绘制文字：y 坐标设置为 baseline 位置（接近矩形底部）
	# 在 Godot 中，draw_string 的 y 参数是字体 baseline 的位置
	# 文字会从 baseline 向上延伸，所以我们需要把 baseline 设置在接近矩形底部的位置
	draw_string(font, Vector2(bg_rect.position.x + 5, bg_rect.end.y - 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

# 坐标转换函数
func _time_to_screen(time: float) -> float:
	# 将时间映射到屏幕坐标（可能在屏幕外）
	# 不使用 max() 限制，允许负值以便正确处理屏幕外的标记
	return (time - view_offset) * pixels_per_second * zoom_level

func _screen_to_time(screen_x: float) -> float:
	return screen_x / (pixels_per_second * zoom_level) + view_offset

func _snap_time(time: float) -> float:
	return round(time / snap_interval) * snap_interval

## 值坐标转换函数 - 将值映射到屏幕Y坐标
func _value_to_screen(value: Variant, track_rect: Rect2, property_track: JuicyPropertyTrack) -> float:
	# 将值映射到屏幕Y坐标
	# 注意：目前只支持float类型的值，其他类型不进行值拖动
	var value_type = typeof(value)
	if value_type != TYPE_FLOAT:
		# 非float类型返回轨道中心位置（不支持值拖动）
		return track_rect.position.y + track_rect.size.y / 2
	
	var float_value = value as float
	var normalized = (float_value - property_track.value_range.x) / (property_track.value_range.y - property_track.value_range.x)
	return track_rect.position.y + track_rect.size.y * (1.0 - normalized)

## 屏幕坐标到值转换函数
func _screen_to_value(screen_y: float, track_rect: Rect2, property_track: JuicyPropertyTrack) -> Variant:
	# 将屏幕Y坐标映射到值
	# 注意：目前只支持float类型的值，其他类型不进行值拖动
	var normalized = 1.0 - (screen_y - track_rect.position.y) / track_rect.size.y
	return property_track.value_range.x + normalized * (property_track.value_range.y - property_track.value_range.x)

## 绘制值范围背景
func _draw_value_range(track: JuicyPropertyTrack, track_rect: Rect2):
	# 绘制值范围的背景区域
	var min_y = _value_to_screen(track.value_range.y, track_rect, track)
	var max_y = _value_to_screen(track.value_range.x, track_rect, track)#
	var range_rect = Rect2(
		track_rect.position.x + track_name_width,
		min_y,
		track_rect.size.x - track_name_width,
		max_y - min_y
	)
	draw_rect(range_rect, Color(0.2, 0.2, 0.25, 0.5))
	
	# 绘制范围标记
	var font = ThemeDB.fallback_font
	draw_string(font,
		Vector2(track_rect.position.x + track_name_width + 5, max_y + 10),
		str(track.value_range.x), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.GRAY)
	draw_string(font,
		Vector2(track_rect.position.x + track_name_width + 5, min_y - 2),
		str(track.value_range.y), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.GRAY)

## 绘制关键帧曲线
func _draw_keyframe_curve(track: JuicyPropertyTrack, track_rect: Rect2):
	var points = PackedVector2Array()
	var step = 1.0 / max(1.0, track_rect.size.x / 10.0)  # 采样步长

	# 🔥 Phase 3A: 根据 time_start 和 time_end 限制绘制范围
	var time_duration = track.time_end - track.time_start

	for i in range(0, 101):
		var t = i / 100.0  # 归一化时间 (0-1)

		# 🔥 映射到实际时间范围
		var actual_time = track.time_start + t * time_duration
		var value = track.get_value_at_time(actual_time, null)

		# 🔥 计算屏幕位置：只在 time_start 到 time_end 范围内绘制
		var start_x = _time_to_screen(track.time_start)
		var end_x = _time_to_screen(track.time_end)
		var x = start_x + t * (end_x - start_x)
		var y = _value_to_screen(value, track_rect, track)
		points.append(Vector2(x, y))

	if points.size() >= 2:
		draw_polyline(points, Color.CYAN, 2.0)

## 绘制动画曲线
func _draw_animation_curve(track: JuicyPropertyTrack, track_rect: Rect2):
	if not track.animation_curve:
		return

	var points = PackedVector2Array()

	# 🔥 Phase 3A: 根据 time_start 和 time_end 限制绘制范围
	var start_x = _time_to_screen(track.time_start)
	var end_x = _time_to_screen(track.time_end)

	for i in range(0, 101):
		var t = i / 100.0  # 归一化时间 (0-1)
		var curve_value = track.animation_curve.sample(t)
		var value = lerp(track.value_range.x, track.value_range.y, curve_value)

		# 🔥 计算屏幕位置：只在 time_start 到 time_end 范围内绘制
		var x = start_x + t * (end_x - start_x)
		var y = _value_to_screen(value, track_rect, track)
		points.append(Vector2(x, y))

	if points.size() >= 2:
		draw_polyline(points, Color.CYAN, 2.0)

## 获取轨道矩形
func _get_track_rect(track: JuicyTrack) -> Rect2:
	"""获取轨道在屏幕上的矩形区域"""
	if not current_timeline:
		return Rect2()
	
	var all_tracks = current_timeline.get_all_tracks()
	var track_index = all_tracks.find(track)
	if track_index < 0:
		return Rect2()
	
	var y_offset = vertical_offset + (track_index + 1) * (track_height + track_spacing)
	return Rect2(0, y_offset, size.x, track_height)

## 获取轨道矩形
func _get_track_from_rect(track_rect: Rect2) -> JuicyTrack:
	"""从矩形区域获取对应的轨道"""
	if not current_timeline:
		return null
	
	var all_tracks = current_timeline.get_all_tracks()
	for track in all_tracks:
		var rect = _get_track_rect(track)
		if rect == track_rect:
			return track
	
	return null

# 轨道和关键帧查找函数
func _get_track_at_position(y: float) -> int:
	if not current_timeline:
		return -1
	
	var all_tracks = current_timeline.get_all_tracks()
	var current_y = vertical_offset  # 使用垂直偏移
	
	# 检查是否点击了占位轨道（第一个轨道位置）
	if y >= current_y and y <= current_y + track_height:
		return -1  # 占位轨道无法选择
	
	current_y += track_height + track_spacing  # 跳过占位轨道
	
	for i in range(all_tracks.size()):
		if y >= current_y and y <= current_y + track_height:
			return i
		current_y += track_height + track_spacing
	
	return -1

func _get_track_by_index(index: int) -> JuicyTrack:
	if not current_timeline:
		return null
	
	var all_tracks = current_timeline.get_all_tracks()
	if index >= 0 and index < all_tracks.size():
		return all_tracks[index]
	
	return null

func _get_keyframe_at_position(track: JuicyTrack, screen_x: float) -> JuicyKeyframe:
	if not track:
		return null
	
	var time = _screen_to_time(screen_x)
	var tolerance = snap_interval / 2
	
	# 根据轨道类型查找关键帧
	match track.get_track_type():
		"Property":
			if track is JuicyPropertyTrack:
				for keyframe in track.keyframes:
					if abs(keyframe.time - time) <= tolerance:
						return keyframe
		"Method":
			if track is JuicyMethodTrack:
				var method_track = track as JuicyMethodTrack
				if abs(method_track.trigger_time - time) <= tolerance:
					# 创建一个临时关键帧对象用于交互
					var temp_keyframe = JuicyKeyframe.new()
					temp_keyframe.time = method_track.trigger_time
					return temp_keyframe
		"Event":
			if track is JuicyEventTrack:
				var event_track = track as JuicyEventTrack
				if abs(event_track.trigger_time - time) <= tolerance:
					# 创建一个临时关键帧对象用于交互
					var temp_keyframe = JuicyKeyframe.new()
					temp_keyframe.time = event_track.trigger_time
					return temp_keyframe
	
	return null

# 操作函数
func _add_keyframe_at_position(pos: Vector2):
	var track_index = _get_track_at_position(pos.y)
	if track_index >= 0:
		var track = _get_track_by_index(track_index)
		if track and track is JuicyPropertyTrack:
			var property_track = track as JuicyPropertyTrack
			var time = _screen_to_time(pos.x)
			if snap_enabled:
				time = _snap_time(time)
			
			# 使用 Property Track 的 create_keyframe 方法创建正确类型的关键帧
			var keyframe = property_track.create_keyframe(time)
			
			track.keyframes.append(keyframe)
			timeline_changed.emit()
			queue_redraw()

func _remove_track_at_index(index: int):
	if current_timeline and index >= 0:
		var all_tracks = current_timeline.get_all_tracks()
		if index < all_tracks.size():
			var track = all_tracks[index]
			current_timeline.remove_track(track)
			timeline_changed.emit()
			
			# 通知Track Editor刷新轨道列表
			_notify_track_editor_refresh()
			
			queue_redraw()

# 新增方法：通知Track Editor刷新
func _notify_track_editor_refresh():
	"""通知Track Editor刷新轨道列表"""
	# 通过信号机制通知父编辑器
	var parent_editor = _get_parent_editor()
	if parent_editor and parent_editor.has_method("refresh_track_list"):
		parent_editor.refresh_track_list()

# 新增方法：获取父编辑器引用
func _get_parent_editor():
	"""获取父级Timeline编辑器引用"""
	var parent = get_parent()
	while parent:
		# 查找Timeline编辑器
		if parent.has_method("edit_timeline") or parent.has_method("set_current_timeline"):
			return parent
		parent = parent.get_parent()
	return null

func _add_new_track():
	if current_timeline:
		var new_track = JuicyPropertyTrack.new()
		new_track.track_name = "新轨道"
		current_timeline.add_track(new_track)
		timeline_changed.emit()
		queue_redraw()

func _delete_selected_keyframe():
	if selected_track and selected_keyframe:
		if selected_track is JuicyPropertyTrack:
			var property_track = selected_track as JuicyPropertyTrack
			property_track.keyframes.erase(selected_keyframe)
			selected_keyframe = null
			timeline_changed.emit()
			queue_redraw()

func _toggle_playback():
	# 这个函数将由父编辑器处理
	pass

# 公共接口
func set_timeline(timeline: JuicyTimelineResource):
	current_timeline = timeline
	if timeline:
		playback_head_position = 0.0
		# 从Timeline资源读取缩放设置
		zoom_level = timeline.timeline_zoom
		
		# 连接Timeline的zoom_changed信号
		if not timeline.zoom_changed.is_connected(_on_timeline_zoom_changed):
			timeline.zoom_changed.connect(_on_timeline_zoom_changed)
			print("TimelineCanvas: 已连接Timeline的zoom_changed信号")
	
	queue_redraw()

func update_zoom_from_timeline():
	"""从Timeline资源更新缩放级别"""
	if current_timeline:
		zoom_level = current_timeline.timeline_zoom
		queue_redraw()

func _on_timeline_zoom_changed(new_zoom: float):
	"""响应Timeline的zoom_changed信号"""
	if not current_timeline:
		return
	
	# 避免循环更新：如果值相同则跳过
	if abs(zoom_level - new_zoom) < 0.01:
		return
	
	print("TimelineCanvas: 接收到zoom_changed信号: ", new_zoom)
	zoom_level = new_zoom
	queue_redraw()

func set_zoom(zoom: float):
	zoom_level = zoom
	queue_redraw()

func set_pixels_per_second(pps: float):
	pixels_per_second = pps
	queue_redraw()

func set_view_offset(offset: float):
	view_offset = offset
	queue_redraw()

func set_vertical_offset(offset: float):
	"""设置垂直偏移，用于调整轨道绘制区域的起始位置"""
	vertical_offset = offset
	queue_redraw()

func get_vertical_offset() -> float:
	"""获取当前垂直偏移"""
	return vertical_offset

func set_playback_head(time: float):
	playback_head_position = time
	queue_redraw()

func set_snap_enabled(enabled: bool, interval: float):
	snap_enabled = enabled
	snap_interval = interval

func select_track(track: JuicyTrack):
	selected_track = track
	selected_keyframe = null
	queue_redraw()

func get_selected_track() -> JuicyTrack:
	return selected_track

func get_selected_keyframe() -> JuicyKeyframe:
	return selected_keyframe

# 公共接口：设置编辑模式
func set_edit_mode(mode: int):
	edit_mode = mode
	print("编辑模式切换到: ", "传统模式" if mode == 0 else "可视化Clip模式")
	queue_redraw()

func get_edit_mode() -> int:
	return edit_mode

# 公共接口：设置拖动模式
func set_drag_mode(mode: int):
	"""设置拖动模式：0=时间拖动，1=值拖动"""
	drag_mode = mode
	print("TimelineCanvas: 拖动模式设置为: ", "时间" if mode == 0 else "值")

func get_drag_mode() -> int:
	"""获取当前拖动模式"""
	return drag_mode

# 公共接口：设置批量拖动模式
func set_batch_drag_enabled(enabled: bool):
	"""设置是否启用批量拖动模式"""
	batch_drag_enabled = enabled
	print("TimelineCanvas: 批量拖动模式: ", "启用" if enabled else "禁用")

func get_batch_drag_enabled() -> bool:
	"""获取批量拖动模式状态"""
	return batch_drag_enabled

# Clip交互相关函数
func _get_clip_at_position(pos: Vector2) -> Dictionary:
	"""返回 {track: JuicyTrack, region: int}，region: 0=中间, 1=左边界, 2=右边界"""
	var track_index = _get_track_at_position(pos.y)
	if track_index < 0:
		return {track = null, region = -1}
	
	var track = _get_track_by_index(track_index)
	if not track or track.get_track_type() != "Feedback":
		return {track = null, region = -1}
	
	var feedback_track = track as JuicyFeedbackTrack
	var start_x = _time_to_screen(feedback_track.start_time)
	var duration = feedback_track.get_actual_duration()
	var end_x = _time_to_screen(feedback_track.start_time + duration)
	
	# 检查具体区域（考虑手柄区域）
	var handle_width = 12.0  # 增加手柄宽度，提高检测精度
	
	if pos.x < start_x or pos.x > end_x:
		push_error("鼠标不在Clip范围内 - 位置: ", pos.x, " Clip范围: ", start_x, " - ", end_x)
		return {track = null, region = -1}
	
	if pos.x >= start_x and pos.x <= start_x + handle_width:
		print("检测到左边界")
		return {track = track, region = 1}  # 左边界
	elif pos.x >= end_x - handle_width and pos.x <= end_x:
		print("检测到右边界")
		return {track = track, region = 2}  # 右边界
	else:
		print("检测到中间区域")
		return {track = track, region = 0}  # 中间区域

# Method Track 交互相关函数
func _get_method_track_at_position(pos: Vector2) -> Dictionary:
	"""返回 {track: JuicyMethodTrack, region: int}
	region: 0=标记主体

	检测 Method Track 标记是否被点击
	"""
	var track_index = _get_track_at_position(pos.y)
	if track_index < 0:
		return {track = null, region = -1}

	var track = _get_track_by_index(track_index)
	if not track or track.get_track_type() != "Method":
		return {track = null, region = -1}

	var method_track = track as JuicyMethodTrack
	var marker_x = _time_to_screen(method_track.trigger_time)

	# 扩展检测范围，提高可点击性
	var hit_width = 12.0

	if pos.x >= marker_x - hit_width and pos.x <= marker_x + hit_width:
		return {track = method_track, region = 0}

	return {track = null, region = -1}

func _calculate_method_trigger_times(track: JuicyMethodTrack) -> Array[float]:
	"""计算 Method Track 的所有触发时间点（包括重复触发）"""
	var times: Array[float] = []

	# 主触发时间
	times.append(track.trigger_time)

	# 如果有重复间隔，计算重复触发时间
	if track.repeat_interval > 0.0:
		var max_count = track.max_repeats if track.max_repeats > 0 else 100
		var current_time = track.trigger_time

		for i in range(1, max_count + 1):
			current_time += track.repeat_interval
			# 限制在合理范围内
			if current_time > 3600.0:  # 最多1小时
				break
			times.append(current_time)

	return times

func _draw_repeat_method_marker(x: float, y: float, track_rect: Rect2):
	"""绘制重复触发标记（弱化视觉，不可拖拽）"""
	var marker_size = 8.0
	var marker_rect = Rect2(x - marker_size/2, y - marker_size/2, marker_size, marker_size)

	# 半透明紫色，表示这是重复触发
	var color = Color(0.8, 0.2, 0.8, 0.4)
	draw_rect(marker_rect, color)

func _draw_primary_method_trigger(track: JuicyMethodTrack, x: float, y: float, track_rect: Rect2):
	"""绘制主触发点（可拖拽）"""
	var editor_interface = Engine.get_singleton("EditorInterface")
	var editor_theme = editor_interface.get_editor_theme()

	var is_selected = (track == selected_method_track)
	var icon: Texture2D = null

	# 根据选中状态选择图标
	if editor_theme:
		if is_selected:
			icon = editor_theme.get_icon("KeySelected", "EditorIcons")
		else:
			icon = editor_theme.get_icon("KeyBezierPoint", "EditorIcons")

	# 计算图标尺寸（放大到两倍，提高可见性）
	var icon_size = 32.0 * max(0.75, min(1.5, zoom_level))
	var icon_rect = Rect2(x - icon_size/2, y - icon_size/2, icon_size, icon_size)

	# 绘制图标
	if icon:
		draw_texture_rect(icon, icon_rect, false)
	else:
		# 备选方案：绘制钻石形状
		var points = PackedVector2Array([
			Vector2(x, y - icon_size/2),
			Vector2(x + icon_size/2, y),
			Vector2(x, y + icon_size/2),
			Vector2(x - icon_size/2, y)
		])
		var color = Color.YELLOW if is_selected else Color.MAGENTA
		draw_colored_polygon(points, color)

	# 绘制方法名
	if not track.method_name.is_empty():
		var text_pos = Vector2(x + icon_size/2 + 4, track_rect.position.y + 10)
		draw_string(ThemeDB.fallback_font, text_pos, track.method_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

		# 选中时显示额外信息
		if is_selected:
			# 显示触发时间
			var time_text = "%.2fs" % track.trigger_time
			var time_pos = Vector2(x + icon_size/2 + 4, track_rect.position.y + 26)
			draw_string(ThemeDB.fallback_font, time_pos, time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.CYAN)

			# 如果有重复间隔，显示重复信息
			if track.repeat_interval > 0.0:
				var repeat_text = "每 %.2fs 重复" % track.repeat_interval
				if track.max_repeats > 0:
					repeat_text += " (最多%d次)" % track.max_repeats
				var repeat_pos = Vector2(x + icon_size/2 + 4, track_rect.position.y + 42)
				draw_string(ThemeDB.fallback_font, repeat_pos, repeat_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.GRAY)

# 🔥 Phase 3A: Property Track 时间范围交互相关函数
func _get_property_track_time_range_at_position(pos: Vector2) -> Dictionary:
	"""
	返回 {track: JuicyPropertyTrack, region: int, time_start: float, time_end: float}
	region: 0=中间, 1=左边界, 2=右边界, -1=无

	检测 Property Track 的时间范围标记是否被点击
	"""
	var track_index = _get_track_at_position(pos.y)
	if track_index < 0:
		return {track = null, region = -1}

	var track = _get_track_by_index(track_index)
	if not track or track.get_track_type() != "Property":
		return {track = null, region = -1}

	var property_track = track as JuicyPropertyTrack

	# 转换时间到屏幕坐标
	var start_x = _time_to_screen(property_track.time_start)
	var end_x = _time_to_screen(property_track.time_end)

	# 检查具体区域（考虑手柄区域）
	var handle_width = 12.0

	if pos.x < start_x or pos.x > end_x:
		return {track = null, region = -1}

	if pos.x >= start_x and pos.x <= start_x + handle_width:
		return {track = property_track, region = 1, time_start = property_track.time_start, time_end = property_track.time_end}  # 左边界
	elif pos.x >= end_x - handle_width and pos.x <= end_x:
		return {track = property_track, region = 2, time_start = property_track.time_start, time_end = property_track.time_end}  # 右边界
	else:
		return {track = property_track, region = 0, time_start = property_track.time_start, time_end = property_track.time_end}  # 中间区域

func _handle_clip_selection(track: JuicyTrack, region: int, pos: Vector2):
	selected_clip = track
	selected_track = track
	selected_keyframe = null
	is_dragging = true
	drag_start_pos = pos
	
	# 设置拖拽模式
	match region:
		0: clip_drag_mode = 1  # 移动
		1: clip_drag_mode = 2  # 左边界
		2: clip_drag_mode = 3  # 右边界
	
	# 保存拖拽开始时的数据
	var feedback_track = track as JuicyFeedbackTrack
	clip_drag_start_data = {
		"start_time": feedback_track.start_time,
		"duration": feedback_track.get_actual_duration(),
		"original_track": track
	}
	
	track_selected.emit(track)
	queue_redraw()

func _handle_method_track_selection(track: JuicyMethodTrack, pos: Vector2):
	"""处理 Method Track 的选择"""
	selected_method_track = track
	selected_track = track
	selected_clip = null  # 清除 Clip 选择
	selected_keyframe = null

	is_dragging = true
	drag_start_pos = pos
	method_track_drag_mode = 1  # 移动触发时间

	# 保存拖拽开始时的数据
	method_track_drag_start_data = {
		"trigger_time": track.trigger_time,
		"original_track": track
	}

	track_selected.emit(track)
	queue_redraw()

func _handle_method_track_drag(pos: Vector2):
	"""处理 Method Track 的拖拽"""
	if not selected_method_track:
		return

	var new_time = _screen_to_time(pos.x)

	# 应用时间吸附
	if snap_enabled:
		new_time = _snap_time(new_time)

	selected_method_track.trigger_time = max(0.0, new_time)
	timeline_changed.emit()
	queue_redraw()

func _handle_method_track_release():
	"""处理 Method Track 的拖拽释放"""
	if selected_method_track:
		selected_method_track.trigger_time = max(0.0, selected_method_track.trigger_time)

	method_track_drag_mode = 0
	method_track_drag_start_data.clear()

	timeline_changed.emit()
	queue_redraw()

func _handle_clip_drag(pos: Vector2):
	if not selected_clip or not selected_clip is JuicyFeedbackTrack:
		return
	
	var feedback_track = selected_clip as JuicyFeedbackTrack
	var new_time = _screen_to_time(pos.x)
	if snap_enabled:
		new_time = _snap_time(new_time)
	
	# 添加调试信息
	print("Clip拖拽 - 模式: ", clip_drag_mode, " 新时间: ", new_time, " 开始时间: ", feedback_track.start_time, " 持续时间: ", feedback_track.duration)
	
	match clip_drag_mode:
		1:  # 移动整个Clip
			var delta_time = new_time - _screen_to_time(drag_start_pos.x)
			feedback_track.start_time = max(0.0, clip_drag_start_data.start_time + delta_time)
			print("移动Clip - 原始开始时间: ", clip_drag_start_data.start_time, " 偏移: ", delta_time, " 新开始时间: ", feedback_track.start_time)
			
		2:  # 调整左边界
			var min_start = 0.0
			# 使用原始数据计算最大开始时间，避免使用已修改的当前值
			var original_duration = clip_drag_start_data.duration
			var max_start = clip_drag_start_data.start_time + original_duration - 0.1
			feedback_track.start_time = clamp(new_time, min_start, max_start)
			print("调整左边界 - 新开始时间: ", feedback_track.start_time, " 最大允许: ", max_start, " 原始持续时间: ", original_duration)
			
		3:  # 调整右边界
			var new_duration = new_time - feedback_track.start_time
			if new_duration >= 0.1:
				# 获取当前时长来源
				var duration_source = feedback_track.get_duration_source()
				
				# 如果当前duration为-1（使用资源自身时长），则设置为具体值
				if feedback_track.duration <= 0:
					feedback_track.duration = new_duration
					print("从跟随模式切换为手动模式，设置持续时间: ", new_duration)
					
					# 对于估算型资源，提供视觉反馈
					if duration_source == JuicyFeedbackResource.DurationSource.ESTIMATED:
						print("已锁定估算时长为固定值: %.2f秒" % new_duration)
				else:
					feedback_track.duration = new_duration
					print("更新持续时间: ", new_duration)
			else:
				print("持续时间过小，不更新: ", new_duration)
	
	timeline_changed.emit()
	queue_redraw()

# Clip绘制相关函数
func _draw_clip_selection(track: JuicyTrack, clip_rect: Rect2):
	# 绘制选择边框
	var border_color = Color.CYAN
	border_color.a = 0.8
	draw_rect(clip_rect.grow(1), border_color, false, 2.0)
	
	# 绘制选择高亮
	var highlight_color = Color.WHITE
	highlight_color.a = 0.1
	draw_rect(clip_rect, highlight_color)

func _draw_clip_handles(track: JuicyTrack, clip_rect: Rect2):
	var handle_color = Color.CYAN
	var handle_width = 12.0  # 与检测逻辑保持一致
	
	# 左手柄
	var left_handle = Rect2(
		clip_rect.position.x - handle_width/2,
		clip_rect.position.y,
		handle_width,
		clip_rect.size.y
	)
	draw_rect(left_handle, handle_color)
	
	# 右手柄
	var right_handle = Rect2(
		clip_rect.position.x + clip_rect.size.x - handle_width/2,
		clip_rect.position.y,
		handle_width,
		clip_rect.size.y
	)
	draw_rect(right_handle, handle_color)
	
	# 添加手柄边框，提高可见性
	var border_color = Color.WHITE
	border_color.a = 0.5
	draw_rect(left_handle.grow(1), border_color, false, 1.0)
	draw_rect(right_handle.grow(1), border_color, false, 1.0)

func _draw_clip_handles_with_feedback(track: JuicyTrack, clip_rect: Rect2, can_drag_left: bool, can_drag_right: bool):
	var handle_width = 12.0  # 与检测逻辑保持一致
	
	# 定义颜色方案
	var default_clip_color = Color.BLUE
	var selected_clip_color = Color.YELLOW
	var default_handle_color = Color.CYAN
	var draggable_handle_color = Color.WHITE
	
	# 左手柄
	var left_handle = Rect2(
		clip_rect.position.x - handle_width/2,
		clip_rect.position.y,
		handle_width,
		clip_rect.size.y
	)
	
	# 根据可拖拽状态选择颜色
	var left_color = default_handle_color
	if can_drag_left:
		left_color = draggable_handle_color
	# 修复：选中Clip时手柄保持白色，不使用黄色
	
	draw_rect(left_handle, left_color)
	
	# 右手柄
	var right_handle = Rect2(
		clip_rect.position.x + clip_rect.size.x - handle_width/2,
		clip_rect.position.y,
		handle_width,
		clip_rect.size.y
	)
	
	# 根据可拖拽状态选择颜色
	var right_color = default_handle_color
	if can_drag_right:
		right_color = draggable_handle_color
	# 修复：选中Clip时手柄保持白色，不使用黄色
	
	draw_rect(right_handle, right_color)
	
	# 添加手柄边框，提高可见性
	var border_color = Color.WHITE
	border_color.a = 0.5
	draw_rect(left_handle.grow(1), border_color, false, 1.0)
	draw_rect(right_handle.grow(1), border_color, false, 1.0)
	
	# 添加调试信息
	if can_drag_left or can_drag_right:
		print("手柄状态 - 左边界可拖拽: ", can_drag_left, " 右边界可拖拽: ", can_drag_right)

func _is_mouse_over_clip(track: JuicyTrack, clip_rect: Rect2) -> bool:
	var mouse_pos = get_local_mouse_position()
	return clip_rect.has_point(mouse_pos)

func _handle_clip_release():
	# 验证Clip的有效性
	if selected_clip and selected_clip is JuicyFeedbackTrack:
		var feedback_track = selected_clip as JuicyFeedbackTrack
		
		# 确保start_time不为负数
		feedback_track.start_time = max(0.0, feedback_track.start_time)
		
		# 确保duration不为负数或过小
		if feedback_track.duration > 0:
			feedback_track.duration = max(0.1, feedback_track.duration)
	
	# 重置Clip拖拽状态
	clip_drag_mode = 0
	clip_drag_start_data.clear()
	
	# 如果Timeline启用了自动计算时长，则重新计算
	if current_timeline and current_timeline.auto_calculate_duration:
		current_timeline.recalculate_duration()
	
	timeline_changed.emit()
	queue_redraw()

# 🔥 Phase 3A: Property Track 时间范围绘制函数
func _draw_property_track_time_range(track: JuicyPropertyTrack, track_rect: Rect2):
	"""绘制 Property Track 的时间范围标记"""
	# 转换时间到屏幕坐标
	var start_x = _time_to_screen(track.time_start)
	var end_x = _time_to_screen(track.time_end)

	# 计算时间范围矩形
	var range_rect = Rect2(
		start_x,
		track_rect.position.y + 2,
		end_x - start_x,
		track_rect.size.y - 4
	)

	# 颜色选择
	var range_color = Color(0.0, 0.8, 0.8, 0.3)  # 半透明青色
	if track == selected_track:
		range_color = Color(1.0, 1.0, 0.0, 0.3)  # 半透明黄色

	# 绘制半透明矩形
	draw_rect(range_rect, range_color)

	# 绘制边界线
	draw_line(Vector2(start_x, range_rect.position.y), Vector2(start_x, range_rect.end.y), Color.CYAN, 2.0)
	draw_line(Vector2(end_x, range_rect.position.y), Vector2(end_x, range_rect.end.y), Color.CYAN, 2.0)

	# 选中时绘制手柄
	if track == selected_track:
		_draw_time_range_handles(range_rect)

func _draw_time_range_handles(range_rect: Rect2):
	"""绘制 Property Track 时间范围的手柄"""
	var handle_width = 12.0
	var handle_color = Color.CYAN

	# 左手柄
	var left_handle = Rect2(
		range_rect.position.x - handle_width/2,
		range_rect.position.y,
		handle_width,
		range_rect.size.y
	)
	draw_rect(left_handle, handle_color)

	# 右手柄
	var right_handle = Rect2(
		range_rect.position.x + range_rect.size.x - handle_width/2,
		range_rect.position.y,
		handle_width,
		range_rect.size.y
	)
	draw_rect(right_handle, handle_color)

	# 添加手柄边框
	var border_color = Color.WHITE
	border_color.a = 0.5
	draw_rect(left_handle.grow(1), border_color, false, 1.0)
	draw_rect(right_handle.grow(1), border_color, false, 1.0)

func _handle_time_range_selection(track: JuicyPropertyTrack, region: int, pos: Vector2):
	"""处理 Property Track 时间范围的选择"""
	selected_clip = null  # 清除 Clip 选择
	selected_track = track
	selected_keyframe = null
	is_dragging = true
	drag_start_pos = pos

	# 设置拖拽模式
	match region:
		0: time_range_drag_mode = 1  # 移动
		1: time_range_drag_mode = 2  # 左边界
		2: time_range_drag_mode = 3  # 右边界

	# 保存拖拽开始时的数据
	time_range_drag_start_data = {
		"time_start": track.time_start,
		"time_end": track.time_end,
		"original_track": track
	}

	track_selected.emit(track)
	queue_redraw()

func _handle_time_range_drag(pos: Vector2):
	"""处理 Property Track 时间范围的拖拽"""
	if not selected_track or not selected_track is JuicyPropertyTrack:
		return

	var property_track = selected_track as JuicyPropertyTrack
	var new_time = _screen_to_time(pos.x)

	# 吸附功能
	if snap_enabled:
		new_time = _snap_time(new_time)

	# 更新时间提示
	time_range_tooltip_time = new_time
	time_range_tooltip_pos = pos

	# 根据拖拽模式处理
	match time_range_drag_mode:
		1:  # 移动整个时间范围
			var delta_time = new_time - _screen_to_time(drag_start_pos.x)
			var duration = time_range_drag_start_data.time_end - time_range_drag_start_data.time_start
			property_track.time_start = max(0.0, time_range_drag_start_data.time_start + delta_time)
			property_track.time_end = property_track.time_start + duration

		2:  # 调整左边界
			var min_start = 0.0
			var max_start = time_range_drag_start_data.time_end - 0.1
			property_track.time_start = clamp(new_time, min_start, max_start)

		3:  # 调整右边界
			var min_end = property_track.time_start + 0.1
			# 移除上限限制，允许自由拖动
			property_track.time_end = max(min_end, new_time)

	timeline_changed.emit()
	queue_redraw()

func _handle_time_range_release():
	"""处理 Property Track 时间范围的释放"""
	if selected_track and selected_track is JuicyPropertyTrack:
		var property_track = selected_track as JuicyPropertyTrack

		# 验证数值有效性
		property_track.time_start = max(0.0, property_track.time_start)
		property_track.time_end = max(property_track.time_start + 0.1, property_track.time_end)

	# 重置拖拽状态
	time_range_drag_mode = 0
	time_range_drag_start_data.clear()

	# 清除时间提示
	time_range_tooltip_time = -1.0
	time_range_tooltip_pos = Vector2.ZERO

	timeline_changed.emit()
	queue_redraw()

# Clip操作函数
func _duplicate_clip(track: JuicyTrack):
	if not track or not track is JuicyFeedbackTrack:
		return
	
	if not current_timeline:
		return
	
	var original_track = track as JuicyFeedbackTrack
	var new_track = JuicyFeedbackTrack.new()
	
	# 复制基本属性
	new_track.track_name = original_track.track_name + " (副本)"
	new_track.enabled = original_track.enabled
	new_track.muted = original_track.muted
	new_track.track_color = original_track.track_color
	new_track.start_time = original_track.start_time + 0.5  # 稍微偏移避免重叠
	new_track.duration = original_track.duration
	new_track.resource = original_track.resource
	new_track.condition = original_track.condition
	new_track.target_path = original_track.target_path
	new_track.inherit_time_scale = original_track.inherit_time_scale
	new_track.interrupt_on_restart = original_track.interrupt_on_restart
	new_track.blend_in_time = original_track.blend_in_time
	new_track.blend_out_time = original_track.blend_out_time
	
	# 复制参数映射
	new_track.use_parameter_mapping = original_track.use_parameter_mapping
	new_track.parameter_mappings = []
	for mapping in original_track.parameter_mappings:
		if mapping:
			new_track.parameter_mappings.append(mapping.duplicate())
	
	# 添加到Timeline
	current_timeline.add_track(new_track)
	timeline_changed.emit()
	queue_redraw()

func _delete_clip(track: JuicyTrack):
	if not track or not current_timeline:
		return
	
	current_timeline.remove_track(track)
	timeline_changed.emit()
	
	# 清除选择状态
	if selected_clip == track:
		selected_clip = null
		selected_track = null
	
	queue_redraw()

func _show_clip_properties(track: JuicyTrack):
	if not track or not track is JuicyFeedbackTrack:
		return
	
	# 这里可以打开一个属性对话框
	# 暂时使用简单的打印输出
	var feedback_track = track as JuicyFeedbackTrack
	print("Clip属性:")
	print("  轨道名称: ", feedback_track.track_name)
	print("  开始时间: ", feedback_track.start_time)
	print("  持续时间: ", feedback_track.get_actual_duration())
	print("  时长类型: ", feedback_track.get_duration_description())
	print("  资源类型: ", feedback_track.resource.get_class() if feedback_track.resource else "无")

# 绘制虚线边框
func _draw_dashed_border(rect: Rect2, color: Color):
	"""绘制虚线边框"""
	var dash_size = 4.0
	var gap_size = 2.0
	var border_thickness = 2.0
	
	# 上边
	var x = rect.position.x
	while x < rect.position.x + rect.size.x:
		var end_x = min(x + dash_size, rect.position.x + rect.size.x)
		draw_line(Vector2(x, rect.position.y), Vector2(end_x, rect.position.y), color, border_thickness)
		x += dash_size + gap_size
	
	# 下边
	x = rect.position.x
	while x < rect.position.x + rect.size.x:
		var end_x = min(x + dash_size, rect.position.x + rect.size.x)
		draw_line(Vector2(x, rect.position.y + rect.size.y), Vector2(end_x, rect.position.y + rect.size.y), color, border_thickness)
		x += dash_size + gap_size
	
	# 左边
	var y = rect.position.y
	while y < rect.position.y + rect.size.y:
		var end_y = min(y + dash_size, rect.position.y + rect.size.y)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x, end_y), color, border_thickness)
		y += dash_size + gap_size
	
	# 右边
	y = rect.position.y
	while y < rect.position.y + rect.size.y:
		var end_y = min(y + dash_size, rect.position.y + rect.size.y)
		draw_line(Vector2(rect.position.x + rect.size.x, y), Vector2(rect.position.x + rect.size.x, end_y), color, border_thickness)
		y += dash_size + gap_size

# 绘制锁图标
func _draw_lock_icon(pos: Vector2):
	"""绘制锁图标（表示精确时长）"""
	var size = 12.0
	var rect = Rect2(pos, Vector2(size, size))
	var icon_color = Color.WHITE
	
	# 锁体
	draw_rect(Rect2(pos.x + 2, pos.y + 4, size - 4, size - 4), icon_color)
	# 锁环
	draw_arc(pos + Vector2(size/2, size/2 - 2), 2, PI, 0, 4, icon_color, 1)

# 绘制波浪图标
func _draw_wave_icon(pos: Vector2):
	"""绘制波浪图标（表示估算时长）"""
	var size = 12.0
	var icon_color = Color.WHITE
	
	# 绘制波浪线
	var points = PackedVector2Array()
	for i in range(5):
		var x = pos.x + i * (size / 4)
		var y = pos.y + size/2 + sin(float(i)) * 2
		points.append(Vector2(x, y))
	
	if points.size() >= 2:
		draw_polyline(points, icon_color, 1.5)

# 重置Clip为资源时长
func _reset_clip_to_resource_duration(track: JuicyTrack):
	"""重置Clip为跟随资源时长"""
	if not track or not track is JuicyFeedbackTrack:
		return
	
	var feedback_track = track as JuicyFeedbackTrack
	feedback_track.reset_to_resource_duration()
	timeline_changed.emit()
	queue_redraw()

# 更新Clip为当前资源时长
func _update_clip_to_current_resource_duration(track: JuicyTrack):
	"""更新Clip为当前资源时长（固定值）"""
	if not track or not track is JuicyFeedbackTrack:
		return
	
	var feedback_track = track as JuicyFeedbackTrack
	feedback_track.sync_to_resource_duration()
	timeline_changed.emit()
	queue_redraw()

# 设置Clip为固定时长
func _set_clip_fixed_duration(track: JuicyTrack):
	"""设置Clip为固定时长模式"""
	if not track or not track is JuicyFeedbackTrack:
		return
	
	var feedback_track = track as JuicyFeedbackTrack
	# 设置为当前时长（转为手动模式）
	feedback_track.sync_to_resource_duration()
	timeline_changed.emit()
	queue_redraw()

# 锁定估算时长
func _lock_clip_estimated_duration(track: JuicyTrack):
	"""锁定估算时长（将估算值转为固定值）"""
	if not track or not track is JuicyFeedbackTrack:
		return
	
	var feedback_track = track as JuicyFeedbackTrack
	# 将估算时长转为手动设置
	feedback_track.sync_to_resource_duration()
	timeline_changed.emit()
	queue_redraw()

func _show_timeline_resource_in_inspector():
	"""在检视器中显示当前Timeline资源"""
	# 方案2：检查是否正在编辑资源，避免冲突
	# 当_is_editing_resource为true时，说明正在编辑Feedback Resource
	# 此时应该跳过Timeline资源的显示，避免类型转换错误
	if _is_editing_resource:
		print("正在编辑资源，跳过Timeline资源显示以避免冲突")
		return
	
	# 添加全面的验证
	# 检查current_timeline
	if not current_timeline:
		print("current_timeline为null，跳过显示")
		return
	
	# 检查timeline_editor引用
	if not timeline_editor:
		print("timeline_editor为null，跳过显示")
		return
	
	# 同时验证timeline_editor和current_timeline
	_open_resource_in_inspector(current_timeline)

func _reset_resource_editing_state():
	"""重置资源编辑状态"""
	_is_editing_resource = false
	_last_edited_resource = null

# 同步Clip与资源
func _sync_clip_with_resource(track: JuicyTrack):
	"""同步Clip与资源时长（保持跟随模式）"""
	if not track or not track is JuicyFeedbackTrack:
		return
	
	# 已经在跟随模式，无需操作
	# 这个函数用于确保Clip的duration为-1
	queue_redraw()

## 绘制选择框
func _draw_selection_box(start: Vector2, end: Vector2):
	var rect = Rect2(
		min(start.x, end.x),
		min(start.y, end.y),
		abs(end.x - start.x),
		abs(end.y - start.y)
	)
	draw_rect(rect, Color.CYAN, false, 1.0)
	draw_rect(rect, Color(0.0, 1.0, 1.0, 0.1))

## 从选择框更新关键帧选择
func _update_selection_from_box(start: Vector2, end: Vector2):
	var rect = Rect2(
		min(start.x, end.x),
		min(start.y, end.y),
		abs(end.x - start.x),
		abs(end.y - start.y)
	)
	
	if not current_timeline:
		return
	
	var all_tracks = current_timeline.get_all_tracks()
	for track in all_tracks:
		if track is JuicyPropertyTrack:
			var track_rect = _get_track_rect(track)
			for keyframe in track.keyframes:
				var x = _time_to_screen(keyframe.time)
				var y = track_rect.position.y + track_rect.size.y / 2
				
				if rect.has_point(Vector2(x, y)):
					# 添加到选择
					var already_selected = false
					for sel in selected_keyframes:
						if sel.keyframe == keyframe:
							already_selected = true
							break
					
					if not already_selected:
						selected_keyframes.append({track = track, keyframe = keyframe})

## 删除选中的关键帧
func _delete_selected_keyframes():
	"""删除选中的关键帧"""
	for sel in selected_keyframes:
		if sel.track is JuicyPropertyTrack:
			var property_track = sel.track as JuicyPropertyTrack
			property_track.keyframes.erase(sel.keyframe)
	
	selected_keyframes.clear()
	timeline_changed.emit()
	queue_redraw()

## 复制选中的关键帧
func _copy_selected_keyframes():
	"""复制选中的关键帧"""
	if selected_keyframes.is_empty():
		return
	
	for sel in selected_keyframes:
		if sel.track is JuicyPropertyTrack:
			var property_track = sel.track as JuicyPropertyTrack
			var new_keyframe = sel.keyframe.duplicate()
			new_keyframe.time += 0.1  # 稍微偏移
			property_track.keyframes.append(new_keyframe)
	
	timeline_changed.emit()
	queue_redraw()

## 更新目标节点提示
func update_target_node_hint(track: JuicyPropertyTrack):
	"""更新目标节点提示 - 调用timeline_editor的显示函数"""
	print("TimelineCanvas: update_target_node_hint() 被调用，track = ", track.track_name if track else "null")
	
	if not track:
		print("TimelineCanvas: track为null，隐藏提示")
		if timeline_editor and timeline_editor.has_method("_update_target_node_hint_display"):
			timeline_editor._update_target_node_hint_display("")
		else:
			print("TimelineCanvas: timeline_editor为null或没有_update_target_node_hint_display方法")
		return
	
	# 获取目标节点路径
	var display_path = "未选择"
	print("TimelineCanvas: target = ", track.target)
	if not track.target.is_empty():
		display_path = str(track.target)
		
		# 获取当前编辑的场景根节点
		var editor_interface = Engine.get_singleton("EditorInterface")
		if editor_interface:
			var edited_root = editor_interface.get_edited_scene_root()
			if edited_root:
				# 尝试获取目标节点并计算相对路径
				var target_node = edited_root.get_node(track.target)
				if target_node:
					# 获取从场景根节点到目标节点的相对路径
					var relative_path = edited_root.get_path_to(target_node)
					if not relative_path.is_empty():
						display_path = str(relative_path)
				else:
					# 如果目标节点不存在，尝试从路径中提取
					# 路径格式可能为: "res://scene.tscn:root/NodeName" 或 "/root/NodeName"
					var scene_root_pattern = ":root/"
					var root_pattern = "/root/"
					
					var scene_root_idx = display_path.find(scene_root_pattern)
					var root_idx = display_path.find(root_pattern)
					
					if scene_root_idx >= 0:
						# 从场景根节点开始截取
						display_path = display_path.substr(scene_root_idx + scene_root_pattern.length())
					elif root_idx >= 0:
						# 从根节点开始截取
						display_path = display_path.substr(root_idx + root_pattern.length())
					else:
						# 尝试从第一个 "/" 开始截取（去除开头的斜杠）
						var first_slash = display_path.find("/")
						if first_slash >= 0:
							display_path = display_path.substr(first_slash + 1)
	
	# 调用timeline_editor的显示函数
	var hint_text = "目标: " + display_path
	print("TimelineCanvas: 准备调用_update_target_node_hint_display，hint_text = ", hint_text)
	if timeline_editor and timeline_editor.has_method("_update_target_node_hint_display"):
		# 修复：使用call_deferred()延迟调用，避免线程安全问题
		timeline_editor.call_deferred("_update_target_node_hint_display", hint_text)
		print("TimelineCanvas: 已延迟调用_update_target_node_hint_display")
	else:
		print("TimelineCanvas: timeline_editor为null或没有_update_target_node_hint_display方法")


## ============================================================================
# Phase 3C: Curve Preset Submenu Items
## ============================================================================

## 添加曲线预设子菜单项
func _add_curve_preset_submenu_items(menu: PopupMenu):
	"""添加曲线预设子菜单项（按分类，ID 301-325）"""
	var JuicyCurveFactory = preload("res://addons/juicy_mixer/utils/juicy_curve_factory.gd")
	var item_id = 301

	# Basic presets (0-3)
	menu.add_item("  ▸ Linear", item_id); item_id += 1
	menu.add_item("  ▸ Ease In", item_id); item_id += 1
	menu.add_item("  ▸ Ease Out", item_id); item_id += 1
	menu.add_item("  ▸ Ease In Out", item_id); item_id += 1

	# Back presets (4-6)
	menu.add_separator()
	menu.add_item("  ▸ Ease In Back", item_id); item_id += 1
	menu.add_item("  ▸ Ease Out Back", item_id); item_id += 1
	menu.add_item("  ▸ Ease In Out Back", item_id); item_id += 1

	# Elastic presets (7-9)
	menu.add_separator()
	menu.add_item("  ▸ Ease In Elastic", item_id); item_id += 1
	menu.add_item("  ▸ Ease Out Elastic", item_id); item_id += 1
	menu.add_item("  ▸ Ease In Out Elastic", item_id); item_id += 1

	# Bounce presets (10-12)
	menu.add_separator()
	menu.add_item("  ▸ Bounce In", item_id); item_id += 1
	menu.add_item("  ▸ Bounce Out", item_id); item_id += 1
	menu.add_item("  ▸ Bounce In Out", item_id); item_id += 1

	# Exponential presets (13-15)
	menu.add_separator()
	menu.add_item("  ▸ Ease In Expo", item_id); item_id += 1
	menu.add_item("  ▸ Ease Out Expo", item_id); item_id += 1
	menu.add_item("  ▸ Ease In Out Expo", item_id); item_id += 1

	# Sine presets (16-18)
	menu.add_separator()
	menu.add_item("  ▸ Ease In Sine", item_id); item_id += 1
	menu.add_item("  ▸ Ease Out Sine", item_id); item_id += 1
	menu.add_item("  ▸ Ease In Out Sine", item_id); item_id += 1

	# Quadratic presets (19-21)
	menu.add_separator()
	menu.add_item("  ▸ Ease In Quad", item_id); item_id += 1
	menu.add_item("  ▸ Ease Out Quad", item_id); item_id += 1
	menu.add_item("  ▸ Ease In Out Quad", item_id); item_id += 1

	# Cubic presets (22-24)
	menu.add_separator()
	menu.add_item("  ▸ Ease In Cubic", item_id); item_id += 1
	menu.add_item("  ▸ Ease Out Cubic", item_id); item_id += 1
	menu.add_item("  ▸ Ease In Out Cubic", item_id); item_id += 1
