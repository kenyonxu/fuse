@tool
extends Control

signal track_added(track: JuicyTrack)
# 🔥 移除 track_removed 信号 - 会导致双重删除问题，而且 UI 更新由 refresh_track_list() 处理
# signal track_removed(track_index: int)
signal track_reordered(from_index: int, to_index: int)
signal track_selected(track: JuicyTrack)

# UI组件
var track_list: Tree
var add_track_button: Button
var remove_track_button: Button
var track_type_option: OptionButton

# UI状态标志
var _toolbar_created: bool = false
var _context_menu: PopupMenu = null
var _context_menu_open: bool = false

# 轨道数据
var current_timeline: JuicyTimelineResource
var selected_track_item: TreeItem

# 轨道类型
enum TrackType {
	PROPERTY,
	FEEDBACK,
	METHOD,
	EVENT
}

# 视觉配置
var track_item_height: int = 24
var track_icon_size: Vector2 = Vector2(16, 16)

func _init():
	name = "轨道编辑器"
	set_custom_minimum_size(Vector2(300, 300))  # 减小最小尺寸，提高空间利用率
	self.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_setup_ui()

func _ready():
	# 移除冗余的调试输出
	pass

func _setup_ui():
	var main_vbox = VBoxContainer.new()
	# main_vbox.set_custom_minimum_size(Vector2(300, 300))
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)
	
	# 创建工具栏
	_create_toolbar(main_vbox)
	
	# 创建轨道列表
	track_list = Tree.new()
	track_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track_list.set_columns(2)
	track_list.set_column_titles_visible(false)
	track_list.set_column_title(0, "轨道名称")
	track_list.set_column_title(1, "类型")
	track_list.item_selected.connect(_on_track_selected)
	track_list.item_activated.connect(_on_track_activated)
	track_list.button_clicked.connect(_on_track_button_clicked)
	# 连接gui_input信号用于处理右键菜单
	track_list.gui_input.connect(_on_track_list_gui_input)
	track_list.set_column_expand(0, true)
	track_list.set_column_expand(1, false)
	track_list.set_column_custom_minimum_width(1, 80)
	main_vbox.add_child(track_list)
	
	# 设置拖拽支持
	track_list.set_drop_mode_flags(Tree.DROP_MODE_INBETWEEN)
	track_list.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)

func _create_toolbar(parent: VBoxContainer):
	# 防止重复创建工具栏
	if _toolbar_created:
		return
	
	var toolbar = HBoxContainer.new()
	toolbar.size_flags_vertical = Control.SIZE_FILL  # 固定高度，不扩展
	parent.add_child(toolbar)
	_toolbar_created = true
	
	# 轨道类型选择
	var type_label = Label.new()
	type_label.text = "类型:"
	toolbar.add_child(type_label)
	
	track_type_option = OptionButton.new()
	track_type_option.add_item("属性轨道", TrackType.PROPERTY)
	track_type_option.add_item("反馈轨道", TrackType.FEEDBACK)
	track_type_option.add_item("方法轨道", TrackType.METHOD)
	track_type_option.add_item("事件轨道", TrackType.EVENT)
	track_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(track_type_option)
	
	# 添加轨道按钮
	add_track_button = Button.new()
	add_track_button.text = "+"
	add_track_button.tooltip_text = "添加轨道"
	# 防止重复连接信号
	if not add_track_button.pressed.is_connected(_on_add_track_pressed):
		add_track_button.pressed.connect(_on_add_track_pressed)
	toolbar.add_child(add_track_button)
	
	# 删除轨道按钮
	remove_track_button = Button.new()
	remove_track_button.text = "-"
	remove_track_button.tooltip_text = "删除轨道"
	remove_track_button.pressed.connect(_on_remove_track_pressed)
	remove_track_button.disabled = true
	toolbar.add_child(remove_track_button)

func set_timeline(timeline: JuicyTimelineResource):
	current_timeline = timeline
	refresh_track_list()

func refresh_track_list():
	if not track_list:
		return

	track_list.clear()

	# 创建隐式根节点（所有轨道项将作为根节点的子项）
	var root_item = track_list.create_item()
	root_item.set_text(0, "轨道列表")  # 隐藏根节点的文本
	root_item.set_selectable(0, false)  # 根节点不可选
	root_item.set_disable_folding(true)
	# 不设置根节点高度，让 Tree 使用 item_height 和 row_separation
	root_item.set_collapsed(false)  # 确保展开

	if not current_timeline:
		# 显示无Timeline提示
		var hint_item = track_list.create_item(root_item)
		hint_item.set_text(0, "请先选择一个Timeline资源")
		hint_item.set_text(1, "提示")
		hint_item.set_selectable(0, false)
		hint_item.set_custom_color(0, Color.GRAY)
		return

	# 检查是否有轨道（修改：使用 timeline_tracks）
	var has_any_track = current_timeline.timeline_tracks.size() > 0  # 🔥 修改

	print("[TrackEditor] refresh_track_list: has_any_track=", has_any_track)
	print("[TrackEditor] refresh_track_list: total tracks=", current_timeline.timeline_tracks.size())

	if not has_any_track:
		# 显示空列表提示
		var hint_item = track_list.create_item(root_item)
		hint_item.set_text(0, "点击'+'按钮添加轨道")
		hint_item.set_text(1, "提示")
		hint_item.set_selectable(0, false)
		hint_item.set_custom_color(0, Color.GRAY)
		return

	# 添加轨道（修改：遍历 timeline_tracks）
	for track in current_timeline.timeline_tracks:  # 🔥 修改
		# 根据轨道类型设置颜色
		var color = Color.WHITE
		match track.get_track_type():
			"Property":
				color = Color.CYAN
			"Feedback":
				color = Color.ORANGE
			"Method":
				color = Color.MAGENTA
			"Event":
				color = Color.YELLOW

		_add_track_item(track, color, root_item)

	# 🔥 确保根节点展开，并重绘
	root_item.set_collapsed(false)
	track_list.queue_redraw()

func _add_track_item(track: JuicyTrack, color: Color, parent: TreeItem = null):
	if not track_list:
		return
	
	# 如果没有指定父项，使用根项作为父项
	if not parent:
		parent = track_list.get_root()
	
	if not parent:
		return
	
	var track_item: TreeItem = track_list.create_item(parent)
	
	if not track_item:
		return
	
	# 设置轨道名称
	var track_name = "未命名轨道"
	if track.has_method("get_track_name"):
		track_name = track.get_track_name()
		
	track_item.set_text(0, track_name)
	
	# 设置轨道类型
	var track_type = track.get_track_type() if track.has_method("get_track_type") else "Unknown"
	track_item.set_text(1, track_type)
	
	# 设置轨道数据
	track_item.set_metadata(0, track)
	# 获取轨道在对应类型数组中的索引
	var track_index = _get_track_index_in_type_array(track)
	track_item.set_metadata(1, track_index)
	
	# 添加控制按钮 - 使用正确的Godot编辑器图标名称
	var visibility_icon = _get_safe_theme_icon("GuiVisibilityVisible")
	var hidden_icon = _get_safe_theme_icon("GuiVisibilityHidden")
	var audio_icon = _get_safe_theme_icon("AudioStreamPlayer")
		
	# 根据轨道状态设置初始按钮图标
	# enabled和muted是JuicyTrack基类的@export属性，所有轨道子类都包含这些属性
	var track_visible = track.enabled
	var track_muted = track.muted
	
	track_item.add_button(1, visibility_icon if track_visible else hidden_icon, 0)  # 可见性按钮
	track_item.add_button(1, audio_icon, 1)  # 静音按钮
		
	# 设置按钮工具提示
	track_item.set_button_tooltip_text(1, 0, "切换轨道可见性")
	track_item.set_button_tooltip_text(1, 1, "切换轨道静音状态")

func _on_track_selected():
	var selected = track_list.get_selected()
	if not selected:
		selected_track_item = null
		remove_track_button.disabled = true
		return
	
	var track = selected.get_metadata(0)
	if track is JuicyTrack:
		selected_track_item = selected
		remove_track_button.disabled = false
		track_selected.emit(track)
	else:
		selected_track_item = null
		remove_track_button.disabled = true

func _on_track_activated():
	var selected = track_list.get_selected()
	if not selected:
		return
	
	var track = selected.get_metadata(0)
	if track is JuicyTrack:
		# 双击轨道项，可以重命名轨道
		_rename_track(selected, track)

func _on_track_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int):
	if column != 1:
		return
	
	var track = item.get_metadata(0)
	if not track is JuicyTrack:
		return
	
	match id:
		0:  # 可见性按钮
			_toggle_track_visibility(track, item)
		1:  # 静音按钮
			_toggle_track_mute(track, item)

# 处理TrackList的右键菜单
func _on_track_list_gui_input(event: InputEvent):
	"""处理Tree的输入事件，用于显示右键菜单"""
	if not event is InputEventMouseButton:
		return

	var mouse_event = event as InputEventMouseButton

	# 只处理右键按下事件
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return

	# 获取点击位置的TreeItem
	var clicked_item = track_list.get_item_at_position(mouse_event.position)
	if not clicked_item:
		return

	# 获取轨道
	var track = clicked_item.get_metadata(0)
	print("[TrackEditor] _on_track_list_gui_input: Right-click on track '", track.track_name if track else "null", "'")

	if not track is JuicyTrack:
		return

	# 选择该轨道
	selected_track_item = clicked_item
	print("[TrackEditor] _on_track_list_gui_input: Selected track '", track.track_name, "'")
	track_selected.emit(track)

	# 显示右键菜单
	_show_track_context_menu(track, mouse_event.global_position)

func _on_add_track_pressed():
	if not current_timeline:
		return
	
	var track_type = track_type_option.selected
	var new_track: JuicyTrack
	var track_type_str: String
	
	match track_type:
		TrackType.PROPERTY:
			new_track = JuicyPropertyTrack.new()
			# 修改：使用 timeline_tracks.size() + 1 作为索引
			new_track.track_name = "属性轨道_" + str(current_timeline.timeline_tracks.size() + 1)  # 🔥 修改
			track_type_str = "Property"
		TrackType.FEEDBACK:
			new_track = JuicyFeedbackTrack.new()
			new_track.track_name = "反馈轨道_" + str(current_timeline.timeline_tracks.size() + 1)  # 🔥 修改
			track_type_str = "Feedback"
		TrackType.METHOD:
			new_track = JuicyMethodTrack.new()
			new_track.track_name = "方法轨道_" + str(current_timeline.timeline_tracks.size() + 1)  # 🔥 修改
			track_type_str = "Method"
		TrackType.EVENT:
			new_track = JuicyEventTrack.new()
			new_track.track_name = "事件轨道_" + str(current_timeline.timeline_tracks.size() + 1)  # 🔥 修改
			track_type_str = "Event"
	
	if new_track:
		var success = current_timeline.add_track(new_track, track_type_str)
		if success:
			track_added.emit(new_track)
			refresh_track_list()
			_refresh_timeline_property_list()
		else:
			push_error("Failed to add track of type: " + track_type_str)

func _on_remove_track_pressed():
	if not selected_track_item or not current_timeline:
		return

	var track = selected_track_item.get_metadata(0)
	var track_index = selected_track_item.get_metadata(1)

	print("[TrackEditor] _on_remove_track_pressed: Removing track '", track.track_name if track else "null", "' at index ", track_index)

	if track is JuicyTrack:
		var before_count = current_timeline.get_all_tracks().size()
		current_timeline.remove_track(track)
		var after_count = current_timeline.get_all_tracks().size()
		print("[TrackEditor] _on_remove_track_pressed: Before=", before_count, ", After=", after_count)
		# 🔥 移除 track_removed 信号发射 - 会导致双重删除问题
		# UI 更新由 refresh_track_list() 处理
		refresh_track_list()

func _rename_track(item: TreeItem, track: JuicyTrack):
	# 创建重命名对话框
	var dialog = AcceptDialog.new()
	dialog.title = "重命名轨道"
	add_child(dialog)
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "新轨道名称:"
	vbox.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.text = track.track_name if track.has_method("get_track_name") else "未命名轨道"
	line_edit.select_all()
	vbox.add_child(line_edit)
	
	# 连接对话框的ready信号，在对话框准备好后设置焦点
	dialog.ready.connect(func():
		line_edit.grab_focus()
		line_edit.call_deferred("grab_click_focus")  # 确保点击焦点也被激活
	)
	
	# 连接确认信号
	dialog.confirmed.connect(func():
		var new_name = line_edit.text
		if not new_name.is_empty():
			if track.has_method("set_track_name"):
				track.set_track_name(new_name)
			else:
				# track_name是@export导出的，直接访问
				track.track_name = new_name
			refresh_track_list()
		dialog.queue_free()
	)
	
	# 连接文本提交信号（Godot 4兼容）
	line_edit.text_submitted.connect(func(text: String):
		if not text.is_empty():
			if track.has_method("set_track_name"):
				track.set_track_name(text)
			else:
				# track_name是@export导出的，直接访问
				track.track_name = text
			refresh_track_list()
		dialog.queue_free()
	)
	
	dialog.popup_centered(Vector2(300, 100))

# 安全获取主题图标的方法
func _get_safe_theme_icon(icon_name: String) -> Texture2D:
	"""安全地获取主题图标，如果获取失败则返回null"""
	var gui = Engine.get_singleton("EditorInterface").get_editor_theme()
	var icon = gui.get_icon(icon_name, "EditorIcons")
	if not icon:
		# 返回一个简单的彩色矩形作为备选
		var texture = ImageTexture.new()
		var image = Image.create(16, 16, false, Image.FORMAT_RGB8)
		image.fill(Color.GRAY)
		texture.set_image(image)
		return texture
	return icon

func _toggle_track_visibility(track: JuicyTrack, item: TreeItem):
	# enabled属性是@export导出的，直接访问
	track.enabled = not track.enabled
	
	# 更新按钮图标 - 使用正确的图标名称
	var button_index = 0
	var visibility_icon = _get_safe_theme_icon("GuiVisibilityVisible")
	var hidden_icon = _get_safe_theme_icon("GuiVisibilityHidden")
	
	if track.enabled:
		item.set_button(1, button_index, visibility_icon)
	else:
		item.set_button(1, button_index, hidden_icon)

func _toggle_track_mute(track: JuicyTrack, item: TreeItem):
	# muted属性是@export导出的，直接访问
	track.muted = not track.muted
	
	# 更新按钮图标 - 使用正确的图标名称
	var button_index = 1
	var mute_icon = _get_safe_theme_icon("AudioMute")
	var play_icon = _get_safe_theme_icon("AudioStreamPlayer")
	
	if track.muted:
		item.set_button(1, button_index, mute_icon)
	else:
		item.set_button(1, button_index, play_icon)

# 拖拽支持
func _get_drag_data(position: Vector2):
	var item = track_list.get_item_at_position(position)
	if not item:
		return null
	
	var track = item.get_metadata(0)
	if not track is JuicyTrack:
		return null
	
	# 创建拖拽预览
	var preview = Label.new()
	preview.text = item.get_text(0)
	preview.custom_minimum_size = Vector2(100, 20)
	set_drag_preview(preview)
	
	return {"track": track, "item": item}

func _can_drop_data(position: Vector2, data) -> bool:
	if not data or not data.has("track"):
		return false
	
	var target_item = track_list.get_item_at_position(position)
	if not target_item:
		return false
	
	var target_track = target_item.get_metadata(0)
	if not target_track is JuicyTrack:
		return false
	
	return true

func _drop_data(position: Vector2, data):
	if not data or not data.has("track"):
		return
	
	var target_item = track_list.get_item_at_position(position)
	if not target_item:
		return
	
	var source_track = data.track
	var target_track = target_item.get_metadata(0)
	
	if not source_track is JuicyTrack or not target_track is JuicyTrack:
		return
	
	# 获取拖拽位置
	var drop_section = track_list.get_drop_section_at_position(position)
	
	# 获取源轨道和目标轨道的索引
	var source_index = _get_track_index(source_track)
	var target_index = _get_track_index(target_track)
	
	if source_index == -1 or target_index == -1:
		return
	
	# 计算新的索引位置
	var new_index = target_index
	if drop_section > 0:  # 拖到目标项下方
		new_index += 1
	
	# 如果是向下拖拽，需要调整索引
	if source_index < new_index:
		new_index -= 1
	
	# 移动轨道
	if current_timeline:
		_move_track(source_index, new_index)
		track_reordered.emit(source_index, new_index)
		refresh_track_list()

func _show_track_context_menu(track: JuicyTrack, position: Vector2):
	"""显示轨道的右键菜单"""
	var context_menu = PopupMenu.new()
	
	# 获取EditorInterface用于获取主题图标
	var editor_interface = Engine.get_singleton("EditorInterface")
	var editor_theme = editor_interface.get_editor_theme() if editor_interface else null
	
	# 添加通用菜单项
	context_menu.add_item("重命名轨道", 0)
	context_menu.set_item_icon(0, editor_theme.get_icon("Rename", "EditorIcons") if editor_theme else null)
	
	context_menu.add_separator()
	
	context_menu.add_item("复制轨道", 1)
	context_menu.set_item_icon(1, editor_theme.get_icon("Duplicate", "EditorIcons") if editor_theme else null)
	
	context_menu.add_item("删除轨道", 2)
	context_menu.set_item_icon(2, editor_theme.get_icon("Remove", "EditorIcons") if editor_theme else null)
	
	context_menu.add_item("删除其他轨道", 3)
	context_menu.add_separator()
	
	context_menu.add_item("上移", 4)
	context_menu.add_item("下移", 5)
	
	# 根据轨道类型添加特定选项
	match track.get_track_type():
		"Property":
			context_menu.add_separator()
			context_menu.add_item("清空关键帧", 10)
		"Feedback":
			context_menu.add_separator()
			context_menu.add_item("切换编辑模式", 11)
		"Method":
			context_menu.add_separator()
			context_menu.add_item("编辑方法", 12)
		"Event":
			context_menu.add_separator()
			context_menu.add_item("编辑事件", 13)
	
	# 将菜单添加到场景树
	if editor_interface:
		var base_control = editor_interface.get_base_control()
		if base_control:
			base_control.add_child(context_menu)
		else:
			add_child(context_menu)
	else:
		add_child(context_menu)

	# 🔥 修复：确保 id_pressed 只连接一次（之前连接了两次导致双重删除）
	var menu_closed = false
	context_menu.id_pressed.connect(func(id: int):
		print("[TrackEditor] context_menu.id_pressed: action_id=", id, ", menu_closed=", menu_closed)
		if not menu_closed:
			_handle_context_menu_action(track, id)
			menu_closed = true
	)

	# 确保菜单关闭时释放内存
	context_menu.popup_hide.connect(func():
		if not menu_closed:
			context_menu.queue_free()
	)

	# 获取全局鼠标位置
	var global_pos = DisplayServer.mouse_get_position()
	context_menu.position = global_pos
	context_menu.popup()

	print("[TrackEditor] _show_track_context_menu: Menu popped up at ", global_pos)

func _handle_context_menu_action(track: JuicyTrack, action_id: int):
	"""处理右键菜单的操作"""
	print("[TrackEditor] _handle_context_menu_action: action_id=", action_id, ", track='", track.track_name if track else "null", "'")

	match action_id:
		0:  # 重命名轨道
			_rename_track(selected_track_item, track)
		1:  # 复制轨道
			_duplicate_track(track)
		2:  # 删除轨道
			if selected_track_item and current_timeline:
				print("[TrackEditor] _handle_context_menu_action: DELETE - Removing track '", track.track_name, "'")
				var before_count = current_timeline.get_all_tracks().size()
				current_timeline.remove_track(track)
				var after_count = current_timeline.get_all_tracks().size()
				print("[TrackEditor] _handle_context_menu_action: Before=", before_count, ", After=", after_count)
				# 🔥 移除 track_removed 信号发射 - 会导致双重删除问题
				# UI 更新由 refresh_track_list() 处理
				refresh_track_list()
		3:  # 删除其他轨道
			_delete_other_tracks(track)
		4:  # 上移
			_move_track_up(track)
		5:  # 下移
			_move_track_down(track)
		10:  # 清空关键帧（Property Track）
			if track is JuicyPropertyTrack:
				track.keyframes.clear()
				refresh_track_list()
		11:  # 切换编辑模式（Feedback Track）
			if track is JuicyFeedbackTrack:
				# 通过Timeline Editor触发模式切换
				pass  # TODO: 需要通过信号或引用通知Editor
		12:  # 编辑方法（Method Track）
			print("编辑方法轨道: ", track.track_name)
		13:  # 编辑事件（Event Track）
			print("编辑事件轨道: ", track.track_name)

func _duplicate_track(track: JuicyTrack):
	"""复制轨道"""
	if not current_timeline:
		return
	
	var cloned_track = track.clone()
	var track_type = track.get_track_type()
	
	# 修改克隆轨道的名称 - track_name是@export导出的，直接访问
	cloned_track.track_name = track.track_name + "_副本"
	
	# 添加到Timeline
	current_timeline.add_track(cloned_track, track_type)
	track_added.emit(cloned_track)	
	refresh_track_list()
	_refresh_timeline_property_list()

func _delete_other_tracks(track: JuicyTrack):
	"""删除除了当前轨道外的所有轨道"""
	if not current_timeline:
		return
	
	var all_tracks = current_timeline.get_all_tracks()
	var tracks_to_delete = []
	
	for t in all_tracks:
		if t != track:
			tracks_to_delete.append(t)
	
	for t in tracks_to_delete:
		current_timeline.remove_track(t)
	
	refresh_track_list()

func _move_track_up(track: JuicyTrack):
	"""将轨道上移"""
	if not current_timeline:
		return

	# 🔥 使用类型数组索引，而不是全局索引
	var track_type = track.get_track_type()
	var tracks_array = _get_tracks_array_by_type(track_type)
	var track_index = _get_track_index_in_type_array(track)

	if track_index <= 0 or not tracks_array:
		return  # 已经在顶部，无法上移

	# 交换位置
	var temp = tracks_array[track_index]
	tracks_array[track_index] = tracks_array[track_index - 1]
	tracks_array[track_index - 1] = temp

	# 发送重排序信号（使用全局索引）
	var global_index = _get_track_index(track)
	track_reordered.emit(global_index, global_index - 1)
	refresh_track_list()

func _move_track_down(track: JuicyTrack):
	"""将轨道下移"""
	if not current_timeline:
		return

	# 🔥 使用类型数组索引，而不是全局索引
	var track_type = track.get_track_type()
	var tracks_array = _get_tracks_array_by_type(track_type)
	var track_index = _get_track_index_in_type_array(track)

	if not tracks_array or track_index < 0 or track_index >= tracks_array.size() - 1:
		return  # 已经在底部，无法下移

	# 交换位置
	var temp = tracks_array[track_index]
	tracks_array[track_index] = tracks_array[track_index + 1]
	tracks_array[track_index + 1] = temp

	# 发送重排序信号（使用全局索引）
	var global_index = _get_track_index(track)
	track_reordered.emit(global_index, global_index + 1)
	refresh_track_list()

func _get_track_index(track: JuicyTrack) -> int:
	if not current_timeline:
		return -1

	# 手动遍历查找，避免 TypedArray.find() 的类型检查错误
	var all_tracks = current_timeline.get_all_tracks()
	print("[TrackEditor] _get_track_index: Looking for track '", track.track_name if track else "null", "' in ", all_tracks.size(), " tracks")
	for i in range(all_tracks.size()):
		if all_tracks[i] == track:
			print("[TrackEditor] _get_track_index: Found at index ", i)
			return i

	print("[TrackEditor] _get_track_index: Track not found, returning -1")
	return -1

func _move_track(from_index: int, to_index: int):
	if not current_timeline:
		return
	
	var all_tracks = current_timeline.get_all_tracks()
	if from_index < 0 or from_index >= all_tracks.size():
		return
	
	if to_index < 0 or to_index >= all_tracks.size():
		return
	
	var track = all_tracks[from_index]
	var track_type = track.get_track_type() if track.has_method("get_track_type") else "Property"
	
	# 从原位置移除
	current_timeline.remove_track(track)
	
	# 插入到新位置
	var tracks_array = _get_tracks_array_by_type(track_type)
	if tracks_array:
		to_index = clamp(to_index, 0, tracks_array.size())
		tracks_array.insert(to_index, track)

func _get_tracks_array_by_type(track_type: String) -> Array:
	if not current_timeline:
		return []
	
	match track_type:
		"Property":
			return current_timeline.get_property_tracks()  # 🔥 修改：调用兼容方法
		"Feedback":
			return current_timeline.get_feedback_tracks()  # 🔥 修改
		"Method":
			return current_timeline.get_method_tracks()  # 🔥 修改
		"Event":
			return current_timeline.get_event_tracks()  # 🔥 修改
		_:
			return []

func _get_track_index_in_type_array(track: JuicyTrack) -> int:
	if not current_timeline or not track:
		return -1

	var track_type = track.get_track_type() if track.has_method("get_track_type") else "Property"
	var tracks_array = _get_tracks_array_by_type(track_type)

	print("[TrackEditor] _get_track_index_in_type_array: Track '", track.track_name, "' type=", track_type, ", array size=", tracks_array.size() if tracks_array else 0)

	if tracks_array:
		# 🔥 手动遍历查找，避免 TypedArray.find() 的类型检查错误
		for i in range(tracks_array.size()):
			if tracks_array[i] == track:
				print("[TrackEditor] _get_track_index_in_type_array: Found at type-array index ", i)
				return i

	print("[TrackEditor] _get_track_index_in_type_array: Not found, returning -1")
	return -1

# 公共接口
func get_selected_track() -> JuicyTrack:
	if selected_track_item:
		return selected_track_item.get_metadata(0)
	return null

func select_track(track: JuicyTrack):
	if not track_list:
		return
	
	# 获取根项
	var root = track_list.get_root()
	if not root:
		return
	
	# 遍历根项的子项（轨道项）
	var item = root.get_first_child()
	while item:
		var item_track = item.get_metadata(0)
		if item_track == track:
			item.select(0)
			selected_track_item = item
			remove_track_button.disabled = false
			return
		item = item.get_next()

func update_track_display():
	refresh_track_list()

func _refresh_timeline_property_list():
	if current_timeline:
		current_timeline.notify_property_list_changed()