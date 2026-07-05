# 文件：addons/fuse/editor/instruction_generator/method_selector_dialog.gd
@tool
class_name MethodSelectorDialog extends Window

## 方法/属性选择对话框
## 继承 Window 而非 AcceptDialog，避免内置按钮与自定义 UI 冲突
## 支持方法指令和属性指令两种生成模式

## 信号：方法被选中
signal method_selected(method_info: Dictionary, target_class: String, use_variables: bool)

## 信号：属性被选中
## mode: 0=SET, 1=GET, 2=SET_AND_GET
signal property_selected(property_info: PropertyInfo, target_class: String, mode: int, use_variables: bool)

## 生成模式枚举
enum GenerateMode { SET, GET, SET_AND_GET }

## 预加载本地化工具类
const FuseLocalization = preload("res://addons/fuse/localization/fuse_localization.gd")

## 搜索防抖定时器
var _search_timer: Timer = null
const SEARCH_DEBOUNCE_MS := 200

## UI 组件 — 通用
var _tab_bar: TabBar = null
var _generate_button: Button

## UI 组件 — 方法面板
var _method_search_box: LineEdit
var _method_tree: Tree
var _method_info_label: RichTextLabel
var _methods_panel: PanelContainer = null

## UI 组件 — 属性面板
var _property_search_box: LineEdit = null
var _property_tree: Tree = null
var _property_info_label: RichTextLabel = null
var _properties_panel: PanelContainer = null
var _generate_mode_hbox: HBoxContainer = null
var _set_radio: BaseButton = null
var _get_radio: BaseButton = null
var _both_radio: BaseButton = null

## 使用变量复选框
var _use_variables_checkbox: CheckBox = null

## 数据 — 方法
var _target_node: Node = null
var _target_class: String = ""
var _methods_by_class: Dictionary = {}
var _selected_method: Dictionary = {}

## 数据 — 属性
var _properties_by_class: Dictionary = {}  ## {class_name: [PropertyInfo, ...]}
var _selected_property: PropertyInfo = null
var _generate_mode: int = GenerateMode.SET

func _ready() -> void:
	_setup_dialog()

## 设置对话框
func _setup_dialog() -> void:
	var _title_key := "FUSE_INSTRUCTION_GENERATOR_TITLE"
	title = FuseLocalization.translate(_title_key)
	if title == _title_key:
		title = "生成指令"

	# Window 配置
	wrap_controls = true
	min_size = Vector2i(700, 500)
	exclusive = true
	unresizable = true
	transient = true
	close_requested.connect(_on_cancel_pressed)

	_create_ui()

## 创建 UI
func _create_ui() -> void:
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	add_child(main_vbox)

	# 标题区域
	var header_label = Label.new()
	header_label.text = _get_header_text()
	header_label.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(header_label)

	# TabBar
	_tab_bar = TabBar.new()
	_tab_bar.tab_count = 2
	_tab_bar.set_tab_title(0, "方法")
	_tab_bar.set_tab_title(1, "属性")
	_tab_bar.tab_changed.connect(_on_tab_changed)
	main_vbox.add_child(_tab_bar)

	# 防抖定时器（方法搜索）
	_search_timer = Timer.new()
	_search_timer.wait_time = SEARCH_DEBOUNCE_MS / 1000.0
	_search_timer.one_shot = true
	_search_timer.timeout.connect(_on_search_timer_timeout)
	add_child(_search_timer)

	# 方法面板
	_methods_panel = PanelContainer.new()
	_methods_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_methods_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_methods_panel)
	_create_methods_panel(_methods_panel)

	# 属性面板（默认隐藏）
	_properties_panel = PanelContainer.new()
	_properties_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_properties_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_properties_panel.visible = false
	main_vbox.add_child(_properties_panel)
	_create_properties_panel(_properties_panel)

	# 使用变量复选框
	_use_variables_checkbox = CheckBox.new()
	_use_variables_checkbox.text = "使用变量"
	_use_variables_checkbox.tooltip_text = "为每个参数生成变量绑定支持（LOCAL/SCOPE/GLOBAL）"
	main_vbox.add_child(_use_variables_checkbox)

	# 生成模式 RadioGroup（仅属性 Tab 时显示）
	_generate_mode_hbox = HBoxContainer.new()
	_generate_mode_hbox.visible = false
	main_vbox.add_child(_generate_mode_hbox)
	_create_generate_mode_radio_group(_generate_mode_hbox)

	# 底部按钮
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(button_hbox)

	_generate_button = Button.new()
	var _generate_key := "FUSE_INSTRUCTION_GENERATOR_GENERATE"
	_generate_button.text = FuseLocalization.translate(_generate_key)
	if _generate_button.text == _generate_key:
		_generate_button.text = "生成指令"
	_generate_button.disabled = true
	_generate_button.pressed.connect(_on_generate_pressed)
	button_hbox.add_child(_generate_button)

	var cancel_button = Button.new()
	var _cancel_key := "FUSE_UI_CANCEL"
	cancel_button.text = FuseLocalization.translate(_cancel_key)
	if cancel_button.text == _cancel_key:
		cancel_button.text = "取消"
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_hbox.add_child(cancel_button)

## 创建方法面板内容
func _create_methods_panel(parent: PanelContainer) -> void:
	var vbox = VBoxContainer.new()
	parent.add_child(vbox)

	# 搜索框
	_method_search_box = LineEdit.new()
	var _search_key := "FUSE_INSTRUCTION_GENERATOR_SEARCH"
	_method_search_box.placeholder_text = FuseLocalization.translate(_search_key)
	if _method_search_box.placeholder_text == _search_key:
		_method_search_box.placeholder_text = "搜索方法..."
	_method_search_box.clear_button_enabled = true
	_method_search_box.text_changed.connect(_on_search_text_changed)
	vbox.add_child(_method_search_box)

	# 中间区域：方法树 + 方法信息
	var h_split = HSplitContainer.new()
	h_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(h_split)

	# 方法树
	_method_tree = Tree.new()
	_method_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_method_tree.columns = 1
	_method_tree.select_mode = Tree.SELECT_ROW
	_method_tree.item_selected.connect(_on_method_selected)
	h_split.add_child(_method_tree)

	# 方法信息面板
	_method_info_label = RichTextLabel.new()
	_method_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_method_info_label.bbcode_enabled = true
	_method_info_label.fit_content = true
	_method_info_label.scroll_following = true
	h_split.add_child(_method_info_label)

## 创建属性面板内容
func _create_properties_panel(parent: PanelContainer) -> void:
	var vbox = VBoxContainer.new()
	parent.add_child(vbox)

	# 搜索框
	_property_search_box = LineEdit.new()
	_property_search_box.placeholder_text = "搜索属性..."
	_property_search_box.clear_button_enabled = true
	_property_search_box.text_changed.connect(_on_property_search_text_changed)
	vbox.add_child(_property_search_box)

	# 中间区域：属性树 + 属性信息
	var h_split = HSplitContainer.new()
	h_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(h_split)

	# 属性树
	_property_tree = Tree.new()
	_property_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_property_tree.columns = 1
	_property_tree.select_mode = Tree.SELECT_ROW
	_property_tree.item_selected.connect(_on_property_item_selected)
	h_split.add_child(_property_tree)

	# 属性信息面板
	_property_info_label = RichTextLabel.new()
	_property_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_property_info_label.bbcode_enabled = true
	_property_info_label.fit_content = true
	_property_info_label.scroll_following = true
	h_split.add_child(_property_info_label)

## 创建生成模式单选按钮组
func _create_generate_mode_radio_group(parent: HBoxContainer) -> void:
	var mode_label = Label.new()
	mode_label.text = "生成: "
	parent.add_child(mode_label)

	# 使用 ButtonGroup 实现单选行为（Godot 4.x 无 RadioButton 类）
	var radio_group = ButtonGroup.new()

	_set_radio = CheckButton.new()
	_set_radio.text = "SET"
	_set_radio.button_pressed = true
	_set_radio.button_group = radio_group
	_set_radio.tooltip_text = "生成设置属性值指令"
	_set_radio.toggled.connect(func(_pressed: bool): if _pressed: _generate_mode = GenerateMode.SET)
	parent.add_child(_set_radio)

	_get_radio = CheckButton.new()
	_get_radio.text = "GET"
	_get_radio.button_group = radio_group
	_get_radio.tooltip_text = "生成获取属性值指令"
	_get_radio.toggled.connect(func(_pressed: bool): if _pressed: _generate_mode = GenerateMode.GET)
	parent.add_child(_get_radio)

	_both_radio = CheckButton.new()
	_both_radio.text = "两者都生成"
	_both_radio.button_group = radio_group
	_both_radio.tooltip_text = "同时生成 SET 和 GET 指令"
	_both_radio.toggled.connect(func(_pressed: bool): if _pressed: _generate_mode = GenerateMode.SET_AND_GET)
	parent.add_child(_both_radio)

## 获取标题文本
func _get_header_text() -> String:
	if _target_node:
		var node_name = _target_node.name
		var cls_name = _target_node.get_class()
		return "为 %s (%s) 生成指令" % [node_name, cls_name]
	return "生成指令"

## 设置目标节点
func set_target_node(node: Node) -> void:
	_target_node = node
	_target_class = node.get_class()

	# 获取方法列表
	var all_methods = MethodFilter.get_class_methods_with_inheritance(_target_class)
	_methods_by_class = MethodFilter.filter_methods(all_methods)

	# 获取可写属性列表（按继承类分组，与方法 Tab 一致）
	_properties_by_class.clear()
	var inheritance_chain = MethodFilter.get_inheritance_chain(_target_class)
	for cls in inheritance_chain:
		var class_props: Array[PropertyInfo] = []
		# true = no_inheritance，仅获取该类自身定义的属性
		var class_property_list = ClassDB.class_get_property_list(cls, true)
		for prop_dict in class_property_list:
			var prop_name = prop_dict.get("name", "")
			if prop_name.is_empty():
				continue
			var prop_usage = prop_dict.get("usage", 0)
			# 跳过分组/子分组标题
			# GROUP=64: 分组标题（如 Offset, Transform）
			# GROUP|SUBGROUP=192: 子分组标题（如 Animation, Material）
			# 旧版子分组标题（如 Thread Group）在 Godot 4.6 中 usage=256（非当前 SCRIPT_VARIABLE=4096）
			if prop_usage & PROPERTY_USAGE_GROUP or prop_usage == 256:
				continue
			# 跳过纯存储属性（PROPERTY_USAGE_STORAGE=2 且无其他标志，是内部实现细节）
			if prop_usage == PROPERTY_USAGE_STORAGE:
				continue
			var prop_info = PropertyInfo.create(prop_dict)
			if prop_info.is_writable() and not prop_info.name.begins_with("_"):
				class_props.append(prop_info)
		if class_props.size() > 0:
			_properties_by_class[cls] = class_props

	# 延迟填充 UI，确保 _ready() 已完成
	if is_inside_tree():
		call_deferred("_deferred_populate_all", "")
	else:
		ready.connect(func(): call_deferred("_deferred_populate_all", ""), Object.CONNECT_ONE_SHOT)


func _deferred_populate_all(_search_text: String) -> void:
	_populate_method_tree("")
	if _tab_bar and _tab_bar.current_tab == 1:
		_populate_properties("")

func _deferred_populate() -> void:
	call_deferred("_populate_method_tree", "")

# ============================================================
# 方法相关逻辑
# ============================================================

## 填充方法树
func _populate_method_tree(search_text: String) -> void:
	_method_tree.clear()

	var root = _method_tree.create_item()
	_method_tree.hide_root = true

	# 获取继承链用于排序
	var inheritance_chain = MethodFilter.get_inheritance_chain(_target_class)

	# 按继承顺序显示（子类在前）
	for cls_name in inheritance_chain:
		if not _methods_by_class.has(cls_name):
			continue

		var methods = _methods_by_class[cls_name]
		var filtered_methods = _filter_methods_by_search(methods, search_text.to_lower())

		if filtered_methods.is_empty():
			continue

		# 创建类分类项
		var class_item = _method_tree.create_item(root)
		class_item.set_text(0, "%s (%d)" % [cls_name, filtered_methods.size()])
		class_item.set_selectable(0, false)
		class_item.set_collapsed(false)  # 默认展开

		# 添加方法
		for method_info in filtered_methods:
			var method_item = _method_tree.create_item(class_item)
			method_item.set_text(0, method_info.get("name", ""))
			method_item.set_metadata(0, method_info)

## 按搜索文本过滤方法
func _filter_methods_by_search(methods: Array, search_text: String) -> Array:
	if search_text.is_empty():
		return methods

	var result = []
	for method in methods:
		if method.get("name", "").to_lower().contains(search_text):
			result.append(method)

	return result

## 搜索文本变化回调（方法搜索，带防抖）
func _on_search_text_changed(text: String) -> void:
	_search_timer.start()

## 防抖定时器到期
func _on_search_timer_timeout() -> void:
	_populate_method_tree(_method_search_box.text)

## 方法选中回调
func _on_method_selected() -> void:
	var selected = _method_tree.get_selected()
	if selected == null:
		return

	var method_info = selected.get_metadata(0)
	if method_info == null:
		return

	_selected_method = method_info
	_generate_button.disabled = false
	_update_method_info(method_info)

## 更新方法信息显示
func _update_method_info(method_info: Dictionary) -> void:
	var method_name = method_info.get("name", "")
	var args = method_info.get("args", [])
	var return_info = method_info.get("return", {})
	var defined_in = method_info.get("defined_in_class", "")

	# 构建方法签名
	var signature = method_name + "("
	var arg_strs = []
	for arg in args:
		var arg_name = arg.get("name", "param")
		var arg_type = TypeMapper.get_type_declaration(
			arg.get("type", TYPE_NIL),
			arg.get("hint", PROPERTY_HINT_NONE),
			arg.get("hint_string", "")
		)
		var default_val = arg.get("default_value", null)
		if default_val != null:
			arg_strs.append("%s: %s = %s" % [arg_name, arg_type, TypeMapper.value_to_string(default_val, arg.get("type", TYPE_NIL))])
		else:
			arg_strs.append("%s: %s" % [arg_name, arg_type])
	signature += ", ".join(arg_strs) + ")"

	# 返回类型
	var return_type = TypeMapper.get_type_declaration(
		return_info.get("type", TYPE_NIL),
		return_info.get("hint", PROPERTY_HINT_NONE),
		return_info.get("hint_string", "")
	)
	if return_type != "Variant" and return_type != "nil":
		signature += " -> " + return_type

	# 显示信息
	var info_text = "[b]方法签名:[/b]\n[code]%s[/code]\n\n" % signature
	info_text += "[b]定义于:[/b] %s\n\n" % defined_in
	info_text += "[b]参数数量:[/b] %d\n" % args.size()

	if args.size() > 0:
		info_text += "\n[b]参数列表:[/b]\n"
		for i in range(args.size()):
			var arg = args[i]
			info_text += "  %d. %s\n" % [i + 1, arg.get("name", "param")]

	_method_info_label.text = info_text

# ============================================================
# 属性相关逻辑
# ============================================================

## 填充属性树
func _populate_properties(search_text: String) -> void:
	_property_tree.clear()
	_selected_property = null
	_generate_button.disabled = true
	_property_info_label.clear()

	if _target_node == null:
		return

	var root = _property_tree.create_item()
	_property_tree.hide_root = true

	# 按继承链顺序显示（子类在前，与方法 Tab 一致）
	var inheritance_chain = MethodFilter.get_inheritance_chain(_target_class)
	var lower_search = search_text.to_lower()

	for cls_name in inheritance_chain:
		if not _properties_by_class.has(cls_name):
			continue
		var properties: Array = _properties_by_class[cls_name]
		var filtered: Array = []

		for prop in properties:
			if lower_search.is_empty():
				filtered.append(prop)
			elif prop.name.to_lower().contains(lower_search):
				filtered.append(prop)
			elif prop.get_type_name().to_lower().contains(lower_search):
				filtered.append(prop)

		if filtered.is_empty():
			continue

		# 创建类分类项
		var class_item = _property_tree.create_item(root)
		class_item.set_text(0, "%s (%d)" % [cls_name, filtered.size()])
		class_item.set_selectable(0, false)
		class_item.set_collapsed(false)  # 默认展开

		# 添加属性
		for prop in filtered:
			var prop_item = _property_tree.create_item(class_item)
			var type_name = prop.get_type_name()
			prop_item.set_text(0, "%s  [%s]" % [prop.name, type_name])
			prop_item.set_metadata(0, prop)

## 属性搜索文本变化回调（属性搜索，带防抖）
var _property_search_timer: Timer = null

func _on_property_search_text_changed(text: String) -> void:
	if _property_search_timer == null:
		_property_search_timer = Timer.new()
		_property_search_timer.wait_time = SEARCH_DEBOUNCE_MS / 1000.0
		_property_search_timer.one_shot = true
		_property_search_timer.timeout.connect(func(): _populate_properties(_property_search_box.text))
		add_child(_property_search_timer)
	_property_search_timer.start()

## 属性选中回调
func _on_property_item_selected() -> void:
	var selected = _property_tree.get_selected()
	if selected == null:
		_selected_property = null
		_property_info_label.clear()
		return

	# 跳过类分类项（根的子节点，没有 metadata 或 metadata 为 null）
	var prop: PropertyInfo = selected.get_metadata(0)
	if prop == null:
		_selected_property = null
		_property_info_label.clear()
		return

	_selected_property = prop
	_generate_button.disabled = false
	_update_property_info_display(prop)

## 更新属性信息显示
func _update_property_info_display(prop: PropertyInfo) -> void:
	var type_name: String
	if prop.type == TYPE_OBJECT and not prop.class_type.is_empty():
		type_name = prop.class_type
	else:
		type_name = TypeConverter.get_type_name(prop.type)

	var bbcode = "[b]属性名:[/b] %s\n" % prop.name
	bbcode += "[b]类型:[/b] %s\n" % type_name
	bbcode += "[b]可写:[/b] %s\n" % ("是" if prop.is_writable() else "否")

	if prop.hint != PROPERTY_HINT_NONE:
		var hint_name = _get_property_hint_name(prop.hint)
		bbcode += "[b]提示:[/b] %s\n" % hint_name
	if not prop.hint_string.is_empty():
		bbcode += "[b]提示字符串:[/b] %s\n" % prop.hint_string
	if prop.default_value != null:
		bbcode += "[b]默认值:[/b] %s\n" % str(prop.default_value)

	if prop.is_numeric() and (prop.min_value != null or prop.max_value != null):
		bbcode += "[b]范围:[/b] "
		if prop.min_value != null:
			bbcode += str(prop.min_value)
		else:
			bbcode += "-inf"
		bbcode += " ~ "
		if prop.max_value != null:
			bbcode += str(prop.max_value)
		else:
			bbcode += "inf"
		if prop.step > 0.0:
			bbcode += " (步长: %s)" % str(prop.step)
		bbcode += "\n"

	_property_info_label.parse_bbcode(bbcode)

## 获取属性提示名称
func _get_property_hint_name(hint: PropertyHint) -> String:
	match hint:
		PROPERTY_HINT_RANGE:
			return "RANGE"
		PROPERTY_HINT_ENUM:
			return "ENUM"
		PROPERTY_HINT_ENUM_SUGGESTION:
			return "ENUM_SUGGESTION"
		PROPERTY_HINT_EXP_EASING:
			return "EXP_EASING"
		PROPERTY_HINT_LINK:
			return "LINK"
		PROPERTY_HINT_FLAGS:
			return "FLAGS"
		PROPERTY_HINT_LAYERS_2D_RENDER:
			return "LAYERS_2D_RENDER"
		PROPERTY_HINT_LAYERS_2D_PHYSICS:
			return "LAYERS_2D_PHYSICS"
		PROPERTY_HINT_LAYERS_3D_RENDER:
			return "LAYERS_3D_RENDER"
		PROPERTY_HINT_LAYERS_3D_PHYSICS:
			return "LAYERS_3D_PHYSICS"
		PROPERTY_HINT_FILE:
			return "FILE"
		PROPERTY_HINT_DIR:
			return "DIR"
		PROPERTY_HINT_GLOBAL_FILE:
			return "GLOBAL_FILE"
		PROPERTY_HINT_GLOBAL_DIR:
			return "GLOBAL_DIR"
		PROPERTY_HINT_RESOURCE_TYPE:
			return "RESOURCE_TYPE"
		PROPERTY_HINT_MULTILINE_TEXT:
			return "MULTILINE_TEXT"
		PROPERTY_HINT_EXPRESSION:
			return "EXPRESSION"
		PROPERTY_HINT_PLACEHOLDER_TEXT:
			return "PLACEHOLDER_TEXT"
		PROPERTY_HINT_COLOR_NO_ALPHA:
			return "COLOR_NO_ALPHA"
		PROPERTY_HINT_NODE_PATH_VALID_TYPES:
			return "NODE_PATH_VALID_TYPES"
		_:
			return "%d" % hint

## 检查属性冲突（返回冲突列表）
## SET_AND_GET 模式下同时检查 SET 和 GET 两个文件
func _check_property_conflicts() -> Array[Dictionary]:
	if _selected_property == null:
		return []
	var cls_name = _target_class
	var output_dir = InstructionGenerator.DEFAULT_OUTPUT_DIR.path_join(cls_name.to_lower())
	var use_vars = _use_variables_checkbox.button_pressed if _use_variables_checkbox else false
	var conflicts: Array[Dictionary] = []

	if _generate_mode == GenerateMode.SET or _generate_mode == GenerateMode.SET_AND_GET:
		var set_conflict = ConflictHandler.check_property_conflict(cls_name, _selected_property.name, "set", output_dir, use_vars)
		if set_conflict.get("has_conflict", false):
			conflicts.append(set_conflict)

	if _generate_mode == GenerateMode.GET or _generate_mode == GenerateMode.SET_AND_GET:
		var get_conflict = ConflictHandler.check_property_conflict(cls_name, _selected_property.name, "get", output_dir, false)
		if get_conflict.get("has_conflict", false):
			conflicts.append(get_conflict)

	return conflicts

# ============================================================
# TabBar 切换逻辑
# ============================================================

## Tab 切换回调
func _on_tab_changed(tab_index: int) -> void:
	match tab_index:
		0:
			# 方法 Tab
			_methods_panel.visible = true
			_properties_panel.visible = false
			_use_variables_checkbox.visible = true
			_generate_mode_hbox.visible = false
			_generate_button.disabled = _selected_method.is_empty()
		1:
			# 属性 Tab
			_methods_panel.visible = false
			_properties_panel.visible = true
			_use_variables_checkbox.visible = true
			_generate_mode_hbox.visible = true
			_generate_button.disabled = _selected_property == null
			# 首次切换到属性 Tab 时填充属性列表
			if _property_tree.get_root() == null or _property_tree.get_root().get_child_count() == 0:
				_populate_properties("")

# ============================================================
# 生成逻辑
# ============================================================

## 生成按钮点击回调
func _on_generate_pressed() -> void:
	# 属性 Tab 逻辑
	if _tab_bar.current_tab == 1:
		if _selected_property == null:
			return
		var conflicts = _check_property_conflicts()
		if conflicts.size() > 0:
			_show_property_conflict_dialogs(conflicts)
			return
		_emit_property_selection()
		return

	# 方法 Tab 逻辑（原有逻辑）
	if _selected_method.is_empty():
		return

	# 检查冲突（复用 ConflictHandler）
	var conflict_result = _check_conflict()
	if conflict_result.get("exists", false):
		_show_conflict_dialog(conflict_result)
		return

	# 直接生成
	_emit_selection()

## 检查冲突（复用 ConflictHandler）
func _check_conflict() -> Dictionary:
	var cls_name = _target_class
	var method_name = _selected_method.get("name", "")
	var output_dir = InstructionGenerator.DEFAULT_OUTPUT_DIR.path_join(cls_name.to_lower())
	var use_variables = _use_variables_checkbox.button_pressed if _use_variables_checkbox else false

	return ConflictHandler.check_conflict(cls_name, method_name, output_dir, use_variables)

## 显示冲突对话框（方法）
func _show_conflict_dialog(conflict_info: Dictionary) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "指令文件已存在：\n%s\n\n是否覆盖？" % conflict_info.get("path", "")
	dialog.title = "文件冲突"

	var self_ref = self
	var info = conflict_info

	dialog.confirmed.connect(func():
		self_ref._emit_selection("overwrite")
		dialog.queue_free()
	)

	dialog.add_cancel_button("跳过")
	dialog.canceled.connect(func():
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()

## 显示属性冲突对话框（支持多个文件）
func _show_property_conflict_dialogs(conflicts: Array[Dictionary]) -> void:
	var paths_text = ""
	for c in conflicts:
		paths_text += "  %s\n" % c.get("file_path", "")

	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "以下指令文件已存在：\n%s\n是否覆盖？" % paths_text
	dialog.title = "文件冲突"

	dialog.confirmed.connect(func():
		_emit_property_selection()
		dialog.queue_free()
	)

	dialog.add_cancel_button("跳过")
	dialog.canceled.connect(func():
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()

## 发送属性选中信号
func _emit_property_selection() -> void:
	var use_vars = _use_variables_checkbox.button_pressed if _use_variables_checkbox else false
	property_selected.emit(_selected_property, _target_class, _generate_mode, use_vars)
	hide()
	queue_free()

## 发送选中信号（方法）
func _emit_selection(action: String = "create") -> void:
	var use_variables = _use_variables_checkbox.button_pressed if _use_variables_checkbox else false
	method_selected.emit(_selected_method, _target_class, use_variables)
	hide()
	queue_free()

## 取消按钮点击回调
func _on_cancel_pressed() -> void:
	hide()
	queue_free()
