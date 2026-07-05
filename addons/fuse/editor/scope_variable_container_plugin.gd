@tool
extends EditorInspectorPlugin

## ScopeVariableContainer Inspector 插件
##
## 为 ScopeVariableContainer 节点提供自定义 Inspector 面板
## 允许在编辑器中查看和编辑作用域变量

const ScopeVariableContainer = preload("res://addons/fuse/core/base/scope_variable_container.gd")

var _scope_container: ScopeVariableContainer = null

func _can_handle(object: Object) -> bool:
	return object is ScopeVariableContainer

func _parse_begin(object: Object):
	## 开始解析对象属性
	_scope_container = object as ScopeVariableContainer
	if _scope_container != null:
		add_custom_control(_create_variable_editor())

func _create_variable_editor() -> Control:
	## 创建作用域变量编辑器 UI
	var container = VBoxContainer.new()
	container.name = "scope_variable_editor"
	container.add_theme_constant_override("separation", 8)

	# 标题
	var title_label = Label.new()
	title_label.text = "作用域变量"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(title_label)

	# 分隔线
	var separator1 = HSeparator.new()
	container.add_child(separator1)

	# 变量列表
	var scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(0, 150)
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.name = "scroll_container"
	container.add_child(scroll_container)

	var variable_list = ItemList.new()
	variable_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	variable_list.name = "variable_list"
	scroll_container.add_child(variable_list)

	# 按钮栏
	var button_row = HBoxContainer.new()
	button_row.name = "button_row"
	container.add_child(button_row)

	var add_btn = Button.new()
	add_btn.text = "添加变量"
	add_btn.tooltip_text = "添加新的作用域变量"
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_btn.name = "add_btn"
	add_btn.pressed.connect(_on_add_variable_pressed.bind(container))
	button_row.add_child(add_btn)

	var remove_btn = Button.new()
	remove_btn.text = "删除变量"
	remove_btn.tooltip_text = "删除选中的变量"
	remove_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remove_btn.name = "remove_btn"
	remove_btn.pressed.connect(_on_remove_variable_pressed.bind(container))
	button_row.add_child(remove_btn)

	var refresh_btn = Button.new()
	refresh_btn.text = "刷新"
	refresh_btn.tooltip_text = "刷新变量列表"
	refresh_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_btn.name = "refresh_btn"
	refresh_btn.pressed.connect(_on_refresh_list_pressed.bind(container))
	button_row.add_child(refresh_btn)

	# 分隔线
	var separator2 = HSeparator.new()
	container.add_child(separator2)

	# 初始化变量列表
	call_deferred("_refresh_variable_list_deferred", container)

	return container

func _refresh_variable_list(variable_list: ItemList):
	## 刷新变量列表显示
	if variable_list == null or _scope_container == null:
		return

	variable_list.clear()

	var var_names = _scope_container.get_variable_names()
	if var_names.is_empty():
		variable_list.add_item("（无变量）")
		variable_list.set_item_disabled(0, true)
	else:
		for name in var_names:
			var value = _scope_container.get_variable(name)
			var value_str = _format_value(value)
			variable_list.add_item("%s = %s" % [name, value_str])

func _format_value(value: Variant) -> String:
	## 格式化变量值用于显示
	if value == null:
		return "null"
	elif value is String:
		return '"%s"' % value
	elif value is Array:
		return "[%d elements]" % value.size()
	elif value is Dictionary:
		return "{%d keys}" % value.size()
	else:
		return str(value)

func _on_add_variable(variable_list: ItemList):
	## 添加新变量（旧方法，保留兼容）
	if _scope_container == null:
		push_error("ScopeVariableContainer 为空，无法添加变量")
		return

	# TODO: 弹出对话框获取变量名和值
	# 暂时添加默认变量
	var var_name = "new_var_%d" % _scope_container.get_variable_names().size()
	var success = _scope_container.set_variable(var_name, 0)

	if success:
		print("已添加变量: %s = 0" % var_name)
		_refresh_variable_list(variable_list)
		# 通知编辑器属性已更改
		_scope_container.notify_property_list_changed()
	else:
		push_error("添加变量失败: %s" % var_name)

func _on_add_variable_pressed(container: Control):
	## 添加新变量（新方法，通过容器查找）
	if _scope_container == null:
		push_error("ScopeVariableContainer 为空，无法添加变量")
		return

	# 查找 variable_list
	var variable_list = container.get_node("scroll_container/variable_list") as ItemList
	if variable_list == null:
		push_error("无法找到变量列表控件")
		return

	# 添加默认变量
	var var_name = "new_var_%d" % _scope_container.get_variable_names().size()
	var success = _scope_container.set_variable(var_name, 0)

	if success:
		print("已添加变量: %s = 0" % var_name)
		_refresh_variable_list_from_container(container)
		# 通知编辑器属性已更改
		_scope_container.notify_property_list_changed()
	else:
		push_error("添加变量失败: %s" % var_name)

func _on_remove_variable(variable_list: ItemList):
	## 删除选中的变量（旧方法）
	if variable_list == null or _scope_container == null:
		return

	var selected = variable_list.get_selected_items()
	if selected.is_empty():
		push_warning("请先选择要删除的变量")
		return

	var idx = selected[0]
	var var_names = _scope_container.get_variable_names()

	if idx >= 0 and idx < var_names.size():
		var var_name = var_names[idx]
		_scope_container.remove_variable(var_name)
		_refresh_variable_list(variable_list)

		# 通知编辑器属性已更改
		if _scope_container:
			_scope_container.notify_property_list_changed()

func _on_remove_variable_pressed(container: Control):
	## 删除选中的变量（新方法）
	if _scope_container == null:
		return

	# 查找 variable_list
	var variable_list = container.get_node("scroll_container/variable_list") as ItemList
	if variable_list == null:
		push_error("无法找到变量列表控件")
		return

	var selected = variable_list.get_selected_items()
	if selected.is_empty():
		push_warning("请先选择要删除的变量")
		return

	var idx = selected[0]
	var var_names = _scope_container.get_variable_names()

	if idx >= 0 and idx < var_names.size():
		var var_name = var_names[idx]
		_scope_container.remove_variable(var_name)
		print("已删除变量: %s" % var_name)
		_refresh_variable_list_from_container(container)

		# 通知编辑器属性已更改
		_scope_container.notify_property_list_changed()

func _on_refresh_list(variable_list: ItemList):
	## 刷新变量列表（旧方法）
	_refresh_variable_list(variable_list)

func _on_refresh_list_pressed(container: Control):
	## 刷新变量列表（新方法）
	_refresh_variable_list_from_container(container)
	print("已刷新变量列表")

func _refresh_variable_list_from_container(container: Control):
	## 从容器获取变量列表并刷新
	var variable_list = container.get_node("scroll_container/variable_list") as ItemList
	if variable_list != null:
		_refresh_variable_list(variable_list)

func _refresh_variable_list_deferred(container: Control):
	## 延迟刷新变量列表（用于初始化）
	_refresh_variable_list_from_container(container)
