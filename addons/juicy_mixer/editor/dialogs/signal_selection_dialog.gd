## 信号选择对话框
##
## 允许用户从检测到的信号中选择要创建绑定的信号
@tool
extends AcceptDialog
class_name SignalSelectionDialog

## 信号数据（分组后）
var _grouped_signals: Dictionary = {}
var _selected_signals: Array = []  # 选中的信号信息

## UI 引用
var _tree: Tree
var _search_box: LineEdit
var _ok_button: Button

## 对话框标题
var _node_name: String = ""

## 初始化对话框
func _init():
	title = "自动检测信号"
	size = Vector2i(600, 500)

	## 连接确认信号
	confirmed.connect(_on_confirmed)

func _ready():
	# 创建主布局
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# 搜索框
	var search_container = HBoxContainer.new()
	vbox.add_child(search_container)

	var search_label = Label.new()
	search_label.text = "🔍 "
	search_container.add_child(search_label)

	_search_box = LineEdit.new()
	_search_box.placeholder_text = "搜索信号..."
	_search_box.text_changed.connect(_on_search_text_changed)
	_search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_container.add_child(_search_box)

	# 树形结构
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_tree = Tree.new()
	_tree.columns = 2
	_tree.set_column_title(0, "信号")
	_tree.set_column_title(1, "Class")
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 150)
	_tree.hide_root = true
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 监听 item 编辑事件来跟踪 checkbox 变化
	_tree.item_edited.connect(_on_tree_item_edited)
	scroll.add_child(_tree)

	# 确认按钮
	_ok_button = get_ok_button()
	if _ok_button:
		_ok_button.disabled = true

## 设置信号数据并显示
##
## @param grouped_signals: 分组的信号字典
## @param node_name: 节点名称（用于标题）
func set_signals(grouped_signals: Dictionary, node_name: String) -> void:
	_grouped_signals = grouped_signals
	_node_name = node_name
	title = "自动检测信号 - %s" % node_name

	_populate_tree()

## 填充树形结构
func _populate_tree(search_text: String = "") -> void:
	_tree.clear()
	_selected_signals.clear()

	var filtered = SignalDetector.apply_search_filter(_grouped_signals, search_text)

	# 创建根项（因为 hide_root = true，所以不会显示）
	var root = _tree.create_item()

	if filtered.is_empty():
		var no_results = _tree.create_item(root)
		no_results.set_text(0, "未找到匹配的信号")
		no_results.set_editable(0, false)
		return

	# 按字母顺序排序 class
	var source_class_names = filtered.keys()
	source_class_names.sort()

	# 将自定义信号放在最前面
	if "自定义" in source_class_names:
		source_class_names.erase("自定义")
		source_class_names.push_front("自定义")

	for source_class in source_class_names:
		var class_item = _tree.create_item(root)
		class_item.set_text(0, "%s (%d)" % [source_class, filtered[source_class].size()])
		class_item.set_editable(0, false)

		for signal_info in filtered[source_class]:
			var signal_item = _tree.create_item(class_item)
			signal_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			signal_item.set_editable(0, true)
			signal_item.set_text(0, SignalDetector.format_signal_text(signal_info))
			signal_item.set_metadata(0, signal_info)
			signal_item.set_text(1, source_class)
			signal_item.set_editable(1, false)

		class_item.set_collapsed(false)

	_update_ok_button()

## 搜索文本变化回调
func _on_search_text_changed(text: String) -> void:
	_populate_tree(text)

## Tree item 编辑回调（用于跟踪 checkbox 变化）
func _on_tree_item_edited() -> void:
	_update_ok_button()

## 更新确认按钮状态
func _update_ok_button() -> void:
	# 实时计算选中的信号数量
	var count = _count_selected_signals()
	if _ok_button:
		_ok_button.text = "确定 (%d)" % count
		_ok_button.disabled = count == 0

## 计算选中的信号数量
func _count_selected_signals() -> int:
	var count = 0
	var root = _tree.get_root()
	if root:
		for class_item in root.get_children():
			for signal_item in class_item.get_children():
				if signal_item.get_cell_mode(0) == TreeItem.CELL_MODE_CHECK:
					if signal_item.is_checked(0):
						count += 1
	return count

## 获取选中的信号
func get_selected_signals() -> Array:
	# 遍历树收集所有被勾选的项目
	_selected_signals.clear()
	var root = _tree.get_root()
	if root:
		for class_item in root.get_children():
			for signal_item in class_item.get_children():
				if signal_item.get_cell_mode(0) == TreeItem.CELL_MODE_CHECK:
					if signal_item.is_checked(0):
						var signal_info = signal_item.get_metadata(0)
						if signal_info:
							_selected_signals.append(signal_info)
	return _selected_signals

## 确认按钮回调
func _on_confirmed() -> void:
	pass  # 用户已确认选择，_selected_signals 已通过 get_selected_signals() 收集
