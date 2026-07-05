@tool
class_name JuicyTimeRuler
extends Control

# 信号定义
signal time_selected(time: float)       # 用户选择时间
signal time_dragged(time: float)        # 用户拖拽时间
signal jump_to_start_requested()        # 跳转到开头
signal jump_to_end_requested()          # 跳转到结尾

# 时间配置
var start_time: float = 0.0            # 显示的时间范围起点
var pixels_per_second: float = 100.0      # 每秒像素数
var zoom_level: float = 1.0              # 缩放级别
var snap_enabled: bool = true             # 吸附启用
var snap_interval: float = 0.1            # 吸附间隔

# 交互状态
var is_dragging: bool = false
var is_clicking: bool = false              # 区分点击和拖拽
var drag_start_pos: Vector2
var click_start_pos: Vector2
var is_hovering: bool = false

# 视觉配置
var bg_color: Color = Color(0.2, 0.2, 0.25, 1.0)
var hover_color: Color = Color(0.25, 0.25, 0.3, 1.0)
var drag_color: Color = Color(0.3, 0.3, 0.35, 1.0)
var border_color: Color = Color(0.35, 0.35, 0.4, 1.0)
var tick_color: Color = Color(0.7, 0.7, 0.8, 1.0)
var label_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var highlight_color: Color = Color(0.5, 0.8, 1.0, 0.3)
var cursor_color: Color = Color(1.0, 0.5, 0.2, 1.0)

func _init():
	set_custom_minimum_size(Vector2(0, 35))  # 稍微增加时间标尺高度，确保文本清晰显示

func _ready():
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

func _on_mouse_entered():
	is_hovering = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()

func _on_mouse_exited():
	is_hovering = false
	is_dragging = false
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()

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
	# 如果正在点击（按住左键）或已经拖拽，处理拖拽逻辑
	if is_clicking or is_dragging:
		_handle_drag(event.position)
	elif is_hovering:
		# 悬停时也需要重绘以更新指示器位置
		queue_redraw()

func _handle_left_click(pos: Vector2):
	# 点击时标记为点击状态，不立即设为拖拽
	is_clicking = true
	click_start_pos = pos
	
	# 设置鼠标指针为指手型（更直观）
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# 计算点击位置对应的时间
	var time = _screen_to_time(pos.x)
	if snap_enabled:
		time = _snap_time(time)
	
	# 发送时间选择信号
	time_selected.emit(time)
	
	# 立即重绘以显示红色播放头指示器
	queue_redraw()
	
	print("JuicyTimeRuler左键点击 - 跳转到: ", time, "s")

func _handle_left_release():
	is_clicking = false
	is_dragging = false
	# 恢复鼠标指针
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	# 重绘以恢复正常显示
	queue_redraw()

func _handle_drag(pos: Vector2):
	# 计算鼠标移动距离
	var drag_distance = pos.distance_to(click_start_pos)
	var drag_threshold = 3.0  # 拖拽阈值（像素）
	
	# 只有移动距离超过阈值才进入拖拽状态
	if not is_dragging and drag_distance > drag_threshold:
		is_dragging = true
		is_clicking = false
		# 拖拽时使用十字光标
		mouse_default_cursor_shape = Control.CURSOR_MOVE
	
	if is_dragging:
		# 计算新位置对应的时间
		var time = _screen_to_time(pos.x)
		if snap_enabled:
			time = _snap_time(time)
		
		# 发送时间拖拽信号
		time_dragged.emit(time)
		
		# 重绘以更新指示器位置
		queue_redraw()

func _handle_right_click(pos: Vector2):
	_show_context_menu(pos)

func _show_context_menu(pos: Vector2):
	var context_menu = PopupMenu.new()
	
	# 保存右键点击位置，用于跳转
	var right_click_pos = pos
	
	# 添加菜单项
	context_menu.add_item("跳转到此处", 0)
	context_menu.add_separator()
	context_menu.add_item("跳转到开头 (0s)", 1)
	context_menu.add_item("跳转到结尾", 2)
	context_menu.add_separator()
	context_menu.add_item("播放", 3)
	context_menu.add_item("暂停", 4)
	context_menu.add_item("停止", 5)
	
	# 将菜单添加到场景树
	var editor_interface = Engine.get_singleton("EditorInterface")
	if editor_interface:
		var base_control = editor_interface.get_base_control()
		if base_control:
			base_control.add_child(context_menu)
		else:
			add_child(context_menu)
	else:
		add_child(context_menu)
	
	# 连接菜单项信号
	context_menu.id_pressed.connect(func(id: int):
		match id:
			0: _jump_to_position(right_click_pos)
			1: _jump_to_start()
			2: _jump_to_end()
			3: pass  # 由父组件处理播放
			4: pass  # 由父组件处理暂停
			5: pass  # 由父组件处理停止
	)
	
	# 确保菜单关闭时释放内存
	context_menu.popup_hide.connect(func():
		context_menu.queue_free()
	)
	
	# 获取全局鼠标位置
	var global_pos = DisplayServer.mouse_get_position()
	context_menu.position = global_pos
	context_menu.popup()

func _jump_to_start():
	jump_to_start_requested.emit()
	print("JuicyTimeRuler: 跳转到开头")

func _jump_to_end():
	jump_to_end_requested.emit()
	print("JuicyTimeRuler: 跳转到结尾")

func _jump_to_position(pos: Vector2):
	var time = _screen_to_time(pos.x)
	if snap_enabled:
		time = _snap_time(time)
	
	time_selected.emit(time)
	print("JuicyTimeRuler: 跳转到位置: ", time, "s")

func _screen_to_time(screen_x: float) -> float:
	return screen_x / (pixels_per_second * zoom_level) + start_time

func _snap_time(time: float) -> float:
	return round(time / snap_interval) * snap_interval

func _get_time_interval() -> float:
	# 根据缩放级别选择合适的时间间隔
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

func _draw():
	var rect = get_rect()
	
	# 绘制背景（根据状态选择颜色）
	var bg = drag_color if is_dragging else (hover_color if is_hovering else bg_color)
	draw_rect(rect, bg)
	
	# 绘制边界
	draw_rect(rect.grow(0.5), border_color, false, 1.0)
	
	# 直接使用start_time作为起始时间
	var end_time = start_time + rect.size.x / (pixels_per_second * zoom_level)
	
	# 绘制时间刻度
	var interval = _get_time_interval()
	var current_time = floor(start_time / interval) * interval
	
	while current_time <= end_time:
		var x = (current_time - start_time) * pixels_per_second * zoom_level
		
		if x >= 0 and x <= rect.size.x:
			# 主刻度
			draw_line(Vector2(x, rect.size.y - 5), Vector2(x, rect.size.y), tick_color, 1.0)
			
			# 时间标签
			var time_text = "%.2fs" % current_time
			draw_string(ThemeDB.fallback_font, Vector2(x + 2, rect.size.y - 8), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_color)
		
		current_time += interval
	
	# 绘制时间指示器（悬停、点击或拖拽状态下都显示）
	if is_hovering or is_dragging or is_clicking:
		_draw_hover_indicator(rect, start_time)

func _draw_hover_indicator(rect: Rect2, start_time: float):
	var mouse_pos = get_local_mouse_position()
	if mouse_pos.x < 0 or mouse_pos.x > rect.size.x:
		return
	
	# 计算鼠标位置对应的时间
	var time = _screen_to_time(mouse_pos.x)
	if snap_enabled:
		time = _snap_time(time)
	
	# 重新计算吸附后的屏幕位置
	var x = (time - start_time) * pixels_per_second * zoom_level
	
	# 绘制垂直指示线
	draw_line(Vector2(x, 0), Vector2(x, rect.size.y), cursor_color, 2.0)
	
	# 绘制时间标签背景
	var time_text = "%.2fs" % time
	var font = ThemeDB.fallback_font
	var text_size = font.get_string_size(time_text)
	var label_bg = Rect2(x + 5, 5, text_size.x + 8, text_size.y + 8)
	
	# 确保标签不会超出边界
	if label_bg.position.x + label_bg.size.x > rect.size.x:
		label_bg.position.x = x - label_bg.size.x - 5
	
	# 绘制标签背景
	var bg_rect_style = StyleBoxFlat.new()
	bg_rect_style.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	bg_rect_style.corner_radius_top_left = 3
	bg_rect_style.corner_radius_top_right = 3
	bg_rect_style.corner_radius_bottom_left = 3
	bg_rect_style.corner_radius_bottom_right = 3
	draw_style_box(bg_rect_style, label_bg)
	
	# 绘制标签文本
	draw_string(font, Vector2(label_bg.position.x + 4, label_bg.position.y + 4), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
