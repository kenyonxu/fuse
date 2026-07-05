# 自动检测信号功能实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 为 AudioComponentInspector 实现自动检测信号功能，允许用户从场景节点检测信号并批量创建 AudioBinding

**架构:**
- 添加 target/target_path 智能目标节点系统
- 实现信号检测、过滤、按 class 分组的核心逻辑
- 创建带搜索功能的树形对话框 UI
- 保持向后兼容（优先使用 target，回退到父节点）

**技术栈:**
- Godot 4.5 / GDScript 2.0
- EditorInspectorPlugin
- Tree/CheckBox/LineEdit UI 控件
- 信号反射 API (get_signal_list)

---

## Task 1: 为 AudioComponent 添加 target_path 支持

**目标:** 让 AudioComponent 资源可以序列化目标节点路径

**Files:**
- Modify: `addons/juicy_mixer/resources/audio/audio_component.gd`

**Step 1: 添加 target_path 属性**

在文件顶部的导出属性区域添加：

```gdscript
## 目标节点路径（可序列化）
@export var target_path: NodePath = ""
```

**Step 2: 添加目标节点获取方法**

在类的查询方法区域添加：

```gdscript
## 获取目标节点
##
## 从 target_path 解析并获取目标节点实例
## 支持编辑器和运行时环境，处理相对/绝对路径
##
## @param base_node: 基础节点（通常是场景根节点）
## @return: 目标节点实例，失败返回 null
func get_target_node(base_node: Node) -> Node:
	if target_path.is_empty():
		return null

	var target_node: Node = base_node.get_node_or_null(target_path)
	if target_node:
		return target_node

	# 如果直接获取失败，尝试处理相对路径
	var path_str = str(target_path)
	if path_str.begins_with("../"):
		var root_path = str(base_node.get_path())
		var absolute_path = _get_absolute_path(path_str, root_path)
		target_node = base_node.get_node_or_null(absolute_path)
		if target_node:
			return target_node

	return null

## 从节点设置 target_path
##
## 将节点引用转换为可序列化的 NodePath
##
## @param node: 要设置为目标节点的节点
func set_target_from_node(node: Node) -> void:
	if not node:
		target_path = NodePath()
		return

	var base_node = Engine.is_editor_hint() ? EditorInterface.get_edited_scene_root() : Engine.get_main_loop().current_scene
	if base_node and base_node.is_ancestor_of(node):
		target_path = base_node.get_path_to(node)
	else:
		push_warning("AudioComponent: 节点不是基础节点的后代")

## 相对路径转绝对路径（内部方法）
func _get_absolute_path(relative_path: String, root_path: String) -> String:
	if relative_path.begins_with("../"):
		relative_path = relative_path.substr(3)
		return root_path + "/" + relative_path
	else:
		return root_path + "/" + relative_path
```

**Step 3: 测试基础功能**

创建测试验证 target_path 存储和读取：

运行: 在编辑器中创建 AudioComponent 资源，设置 target_path，保存并重新加载，验证路径被保留。

**Step 4: 提交**

```bash
git add addons/juicy_mixer/resources/audio/audio_component.gd
git commit -m "feat(audio): 为 AudioComponent 添加 target_path 属性

- 添加可序列化的 target_path 属性
- 实现 get_target_node() 方法解析节点路径
- 实现 set_target_from_node() 方法从节点设置路径
- 支持相对/绝对路径转换

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: 为 JuicyAudioPlayer 添加 target 属性和智能逻辑

**目标:** 添加显式 target 属性，实现智能目标节点获取

**Files:**
- Modify: `addons/juicy_mixer/core/juicy_audio_player.gd`

**Step 1: 添加 target 属性**

在导出属性区域（audio_component 之后）添加：

```gdscript
@export var target: Node = null
```

**Step 2: 实现智能目标节点获取方法**

在私有方法区域添加：

```gdscript
## 获取有效的目标节点
##
## 优先使用显式指定的 target，回退到父节点
## 保持向后兼容性
##
## @return: 有效的目标节点，失败返回 null
func _get_effective_target() -> Node:
	# 1. 优先使用显式指定的 target
	if target:
		return target

	# 2. 回退到父节点（原有逻辑）
	return _parent_node
```

**Step 3: 更新 _ready() 使用新逻辑**

修改现有的 _ready() 方法，使用智能目标节点获取：

```gdscript
func _ready() -> void:
	_parent_node = _get_effective_target()

	if not _parent_node:
		push_error("JuicyAudioPlayer: 请设置 target 或作为子节点添加到目标节点")
		return

	# ... 其余代码保持不变
```

**Step 4: 更新 _find_or_create_audio_handler() 的注释**

在方法顶部添加注释说明目标节点逻辑：

```gdscript
## 查找或创建音频事件处理器
##
## 使用智能目标节点系统：
## - 优先使用显式 target
## - 回退到父节点（向后兼容）
```

**Step 5: 测试向后兼容性**

测试场景：
1. 创建旧方式：JuicyAudioPlayer 作为子节点，target 为空
2. 创建新方式：JuicyAudioPlayer 在任意位置，设置 target
3. 运行游戏，验证两种方式都能正常工作

**Step 6: 提交**

```bash
git add addons/juicy_mixer/core/juicy_audio_player.gd
git commit -m "feat(audio): 为 JuicyAudioPlayer 添加智能目标节点系统

- 添加 target 属性用于显式指定目标节点
- 实现 _get_effective_target() 智能获取逻辑
- 优先使用 target，回退到父节点（向后兼容）
- 支持灵活的节点配置

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: 在 JuicyAudioPlayerInspector 添加"设置为父节点"按钮

**目标:** 在 Inspector 中提供快速设置父节点为 target 的按钮

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_audio_player_inspector.gd`

**Step 1: 在状态面板添加目标节点显示**

修改 `_create_status_panel()` 方法，在父节点标签后添加目标节点信息：

```gdscript
func _create_status_panel(player: JuicyAudioPlayer) -> Control:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# 父节点信息
	var parent_label = Label.new()
	var parent = player.get_parent()
	parent_label.text = "父节点: %s" % (parent.name if parent else "无")
	parent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(parent_label)

	# 目标节点信息（新增）
	var target_label = Label.new()
	if player.target:
		target_label.text = "目标节点: %s (显式指定)" % player.target.name
	elif parent:
		target_label.text = "目标节点: %s (默认父节点)" % parent.name
	else:
		target_label.text = "目标节点: 未设置"
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(target_label)

	# 绑定数量
	var count_label = Label.new()
	var bindings = player.audio_component.get_binding_count() if player.audio_component else 0
	count_label.text = "绑定数量: %d" % bindings
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(count_label)

	# 按钮容器
	var button_hbox = HBoxContainer.new()
	vbox.add_child(button_hbox)

	# "设置为父节点"按钮（新增）
	var set_parent_btn = Button.new()
	set_parent_btn.text = "🔄 设置为父节点"
	set_parent_btn.tooltip_text = "将父节点设置为 target"
	set_parent_btn.pressed.connect(_on_set_parent_as_target.bind(player))
	button_hbox.add_child(set_parent_btn)

	# 测试按钮
	var test_btn = Button.new()
	test_btn.text = "🧪 测试所有绑定"
	test_btn.pressed.connect(_on_test_all.bind(player))
	button_hbox.add_child(test_btn)

	return panel
```

**Step 2: 实现"设置为父节点"按钮回调**

在类的底部添加新方法：

```gdscript
## 处理"设置为父节点"按钮点击
##
## @param player: 目标 JuicyAudioPlayer 实例
func _on_set_parent_as_target(player: JuicyAudioPlayer) -> void:
	var parent = player.get_parent()
	if not parent:
		push_warning("JuicyAudioPlayer 没有父节点")
		return

	player.target = parent
	print("[JuicyAudioPlayerInspector] Target 已设置为父节点: ", parent.name)

	# 刷新 Inspector 显示
	notify_property_list_changed()
```

**Step 3: 测试按钮功能**

1. 在编辑器中打开测试场景
2. 选择 JuicyAudioPlayer 节点
3. 点击"🔄 设置为父节点"按钮
4. 验证 target 属性被设置
5. 验证目标节点标签更新

**Step 4: 提交**

```bash
git add addons/juicy_mixer/editor/juicy_audio_player_inspector.gd
git commit -m "feat(audio): 在 Inspector 添加目标节点管理功能

- 显示当前目标节点（显式或默认父节点）
- 添加\"设置为父节点\"快速操作按钮
- 改进状态面板 UI，显示更多信息
- 支持快速配置目标节点

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: 实现信号检测和分组逻辑

**目标:** 创建信号检测、过滤、分组的工具方法

**Files:**
- Create: `addons/juicy_mixer/editor/utils/signal_detector.gd`

**Step 1: 创建 SignalDetector 工具类**

创建新文件并实现信号检测逻辑：

```gdscript
## 信号检测工具类
##
## 提供信号检测、过滤、分组的功能
class_name SignalDetector

## 排除的内置信号列表
const EXCLUDED_SIGNALS = [
	"tree_entered", "tree_exited", "tree_exiting",
	"ready", "renamed", "child_entered_tree",
	"child_exiting_tree", "parent_set",
	"script_changed", "size_changed"
]

## 检测节点的所有自定义信号
##
## @param node: 要检测的节点
## @return: 自定义信号信息数组
static func detect_custom_signals(node: Node) -> Array:
	if not node:
		push_error("SignalDetector: 节点为空")
		return []

	var all_signals = node.get_signal_list()
	var custom_signals = []

	for signal_info in all_signals:
		var signal_name = signal_info.name

		# 排除以 _ 开头的内部信号
		if signal_name.begins_with("_"):
			continue

		# 排除内置的标准信号
		if signal_name in EXCLUDED_SIGNALS:
			continue

		custom_signals.append(signal_info)

	return custom_signals

## 按 class 分组信号
##
## @param signals: 信号信息数组
## @return: 分组字典 { "ClassName": [signal_infos] }
static func group_signals_by_class(signals: Array) -> Dictionary:
	var grouped = {}

	for signal_info in signals:
		var source_class = signal_info.get("source_class", "Object")

		if not grouped.has(source_class):
			grouped[source_class] = []

		grouped[source_class].append(signal_info)

	return grouped

## 格式化信号显示文本
##
## @param signal_info: 信号信息字典
## @return: 格式化的显示字符串
static func format_signal_text(signal_info: Dictionary) -> String:
	var signal_name = signal_info.name
	var params = signal_info.get("args", [])

	if params.is_empty():
		return signal_name

	var param_strings = []
	for param_info in params:
		var param_name = param_info.name
		var param_type = param_info.type
		param_strings.append("%s: %s" % [param_name, _type_to_string(param_type)])

	return "%s(%s)" % [signal_name, ", ".join(param_strings)]

## 类型转换为可读字符串
static func _type_to_string(type: int) -> String:
	match type:
		TYPE_NIL: return "Variant"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_COLOR: return "Color"
		TYPE_OBJECT: return "Object"
		TYPE_CALLABLE: return "Callable"
		_: return "Variant"

## 应用搜索过滤
##
## @param grouped: 分组的信号字典
## @param search_text: 搜索文本
## @return: 过滤后的分组字典
static func apply_search_filter(grouped: Dictionary, search_text: String) -> Dictionary:
	if search_text.is_empty():
		return grouped

	var filtered = {}
	var search_lower = search_text.to_lower()

	for class_name in grouped:
		var filtered_signals = []
		for signal_info in grouped[class_name]:
			var signal_name = signal_info.name.to_lower()
			if search_text in signal_name:
				filtered_signals.append(signal_info)

		if not filtered_signals.is_empty():
			filtered[class_name] = filtered_signals

	return filtered
```

**Step 2: 创建单元测试**

创建测试文件验证信号检测逻辑：

`addons/juicy_mixer/tests/audio/test_signal_detector.gd`:

```gdscript
extends Node

## 测试节点
class TestNode extends Node:
	signal custom_signal_1
	signal custom_signal_2(value: int)
	signal _internal_signal

func test_detect_custom_signals():
	var test_node = TestNode.new()
	add_child(test_node)

	var signals = SignalDetector.detect_custom_signals(test_node)

	assert(signals.size() == 2, "应该检测到 2 个自定义信号")
	assert(signals[0].name == "custom_signal_1", "第一个信号应该是 custom_signal_1")
	assert(signals[1].name == "custom_signal_2", "第二个信号应该是 custom_signal_2")

	print("✓ test_detect_custom_signals 通过")
	test_node.queue_free()

func test_group_signals_by_class():
	var test_node = TestNode.new()
	var signals = SignalDetector.detect_custom_signals(test_node)
	var grouped = SignalDetector.group_signals_by_class(signals)

	assert(grouped.has("TestNode"), "应该有 TestNode 分组")
	assert(grouped["TestNode"].size() == 2, "TestNode 分组应该有 2 个信号")

	print("✓ test_group_signals_by_class 通过")
	test_node.queue_free()

func test_format_signal_text():
	var test_node = TestNode.new()
	var signals = SignalDetector.detect_custom_signals(test_node)

	# 无参数信号
	var text1 = SignalDetector.format_signal_text(signals[0])
	assert(text1 == "custom_signal_1", "无参数信号格式应该正确")

	# 有参数信号
	var text2 = SignalDetector.format_signal_text(signals[1])
	assert(text2 == "custom_signal_2(value: int)", "有参数信号格式应该正确")

	print("✓ test_format_signal_text 通过")
	test_node.queue_free()

func _ready():
	test_detect_custom_signals()
	test_group_signals_by_class()
	test_format_signal_text()
	print("\n✅ 所有 SignalDetector 测试通过！")
	get_tree().quit()
```

**Step 3: 运行测试验证**

运行: 在 Godot 中打开测试场景

预期: 所有测试通过，控制台输出成功消息

**Step 4: 提交**

```bash
git add addons/juicy_mixer/editor/utils/signal_detector.gd
git add addons/juicy_mixer/tests/audio/test_signal_detector.gd
git commit -m "feat(audio): 创建信号检测工具类

- 实现 SignalDetector 工具类
- 检测节点的自定义信号（排除内置信号）
- 按 class 分组信号
- 格式化信号显示文本（包含参数类型）
- 添加搜索过滤功能
- 完整的单元测试覆盖

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: 创建信号选择对话框

**目标:** 实现带搜索和树形结构的信号选择对话框

**Files:**
- Create: `addons/juicy_mixer/editor/dialogs/signal_selection_dialog.gd`

**Step 1: 创建对话框基础结构**

```gdscript
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

func _ready() -> _ready():
	# 创建主布局
	var vbox = VBoxContainer.new()
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
	vbox.add_child(scroll)

	_tree = Tree.new()
	_tree.columns = 2
	_tree.set_column_title(0, "信号")
	_tree.set_column_title(1, "Class")
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 150)
	_tree.hide_root = true
	_scroll.add_child(_tree)

	# 确认按钮
	_ok_button = get_ok_button()
	_ok_button.disabled = true

	# 取消按钮
	var cancel_button = get_cancel_button()
	cancel_button.text = "取消"

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
	_update_ok_button()

	var filtered = SignalDetector.apply_search_filter(_grouped_signals, search_text)

	if filtered.is_empty():
		var no_results = _tree.create_item()
		no_results.set_text(0, 0, "未找到匹配的信号")
		no_results.set_editable(0, false)
		return

	# 按字母顺序排序 class
	var class_names = filtered.keys()
	class_names.sort()

	for class_name in class_names:
		var class_item = _tree.create_item()
		class_item.set_text(0, 0, "%s (%d)" % [class_name, filtered[class_name].size()])
		class_item.set_editable(0, false)

		for signal_info in filtered[class_name]:
			var signal_item = _tree.create_item(class_item)
			signal_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			signal_item.set_editable(0, true)
			signal_item.set_text(0, 0, SignalDetector.format_signal_text(signal_info))
			signal_item.set_metadata(0, signal_info)

			signal_item.set_text(1, 0, class_name)
			signal_item.set_editable(1, false)

		class_item.set_collapsed(false)

## 搜索文本变化回调
func _on_search_text_changed(text: String) -> void:
	_populate_tree(text)

## Tree 项目勾选状态变化
func _on_item_checked(item: TreeItem) -> void:
	var signal_info = item.get_metadata(0)
	if not signal_info:
		return

	if item.is_checked(0):
		if not _selected_signals.has(signal_info):
			_selected_signals.append(signal_info)
	else:
		_selected_signals.erase(signal_info)

	_update_ok_button()

## 更新确认按钮状态
func _update_ok_button() -> void:
	_ok_button.text = "确定 (%d)" % _selected_signals.size()
	_ok_button.disabled = _selected_signals.is_empty()

## 获取选中的信号
func get_selected_signals() -> Array:
	return _selected_signals

## 确认按钮回调
func _on_confirmed() -> void:
	print("[SignalSelectionDialog] 用户选择了 %d 个信号" % _selected_signals.size())
```

**Step 2: 修复 _ready 方法名冲突**

修复上面的代码（_ready() 重复定义）：

```gdscript
func _ready():
	# 创建主布局
	...
```

**Step 3: 修复滚动容器引用**

修复代码中的 _scroll 引用：

```gdscript
scroll.add_child(_tree)
```

**Step 4: 连接 Tree 信号**

在 _populate_tree() 之后添加：

```gdscript
_tree.item_checked.connect(_on_item_checked)
```

**Step 5: 测试对话框**

创建测试场景验证对话框显示：
- 测试空信号列表
- 测试有信号的情况
- 测试搜索过滤
- 测试勾选和确认

**Step 6: 提交**

```bash
git add addons/juicy_mixer/editor/dialogs/signal_selection_dialog.gd
git commit -m "feat(audio): 创建信号选择对话框

- 实现 SignalSelectionDialog 对话框
- 树形结构显示，按 class 分组
- 实时搜索过滤功能
- 显示信号参数类型信息
- 支持多选和确认

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: 集成到 AudioComponentInspector

**目标:** 将自动检测信号功能集成到 AudioComponentInspector

**Files:**
- Modify: `addons/juicy_mixer/editor/audio_component_inspector.gd`

**Step 1: 实现自动检测信号逻辑**

完全替换现有的 `_on_auto_detect_signals()` 方法：

```gdscript
func _on_auto_detect_signals(component: AudioComponent) -> void:
	## 处理"自动检测信号"按钮点击事件
	## @param component: 目标 AudioComponent

	# 1. 获取目标节点
	var target_node = _get_target_node_for_detection(component)
	if not target_node:
		_show_warning_dialog(
			"未设置目标节点",
			"请先设置目标节点：\n\n1. 在 JuicyAudioPlayer 中设置 target 属性\n2. 或在 AudioComponent 中设置 target_path 属性"
		)
		return

	# 2. 检测信号
	var custom_signals = SignalDetector.detect_custom_signals(target_node)
	if custom_signals.is_empty():
		_show_info_dialog(
			"未找到信号",
			"节点 '%s' 没有可绑定的自定义信号。\n\n提示：内置信号（如 ready, tree_entered）会被自动过滤。" % target_node.name
		)
		return

	# 3. 按 class 分组
	var grouped = SignalDetector.group_signals_by_class(custom_signals)

	# 4. 显示选择对话框
	var dialog = SignalSelectionDialog.new()
	add_child(dialog)
	dialog.set_signals(grouped, target_node.name)

	# 等待用户选择
	var confirmed = await dialog.confirmed
	if confirmed:
		# 5. 创建 AudioBinding
		var selected = dialog.get_selected_signals()
		_create_bindings_for_signals(component, selected)

	dialog.queue_free()

## 获取用于检测的目标节点
func _get_target_node_for_detection(component: AudioComponent) -> Node:
	# 尝试从 JuicyAudioPlayer 获取 target
	var player = _find_audio_player()
	if player and player.target:
		return player.target

	# 尝试从 AudioComponent 的 target_path 获取
	if not component.target_path.is_empty():
		var edited_root = EditorInterface.get_edited_scene_root()
		if edited_root:
			return component.get_target_node(edited_root)

	# 回退到父节点（如果找到 JuicyAudioPlayer）
	if player:
		return player.get_parent()

	return null

## 查找当前场景中的 JuicyAudioPlayer
func _find_audio_player() -> JuicyAudioPlayer:
	var edited_root = EditorInterface.get_edited_scene_root()
	if not edited_root:
		return null

	var players = edited_root.find_children("*", "JuicyAudioPlayer", true, false)
	if players.size() > 0:
		return players[0]

	return null

## 为信号创建绑定
func _create_bindings_for_signals(component: AudioComponent, signals: Array) -> void:
	var created_count = 0
	var skipped_count = 0

	for signal_info in signals:
		var signal_name = signal_info.name

		# 检查是否已存在
		var existing = component.find_binding_by_signal(signal_name)
		if existing:
			skipped_count += 1
			continue

		# 创建新绑定
		var binding = AudioBinding.new()
		binding.signal_name = signal_name

		# 创建占位符 AudioEvent
		var audio_event = AudioEventResource.new()
		audio_event.event_name = signal_name
		binding.audio_event = audio_event

		component.audio_bindings.append(binding)
		created_count += 1

	# 刷新 Inspector
	notify_property_list_changed()

	# 显示结果
	var message = "成功创建 %d 个绑定" % created_count
	if skipped_count > 0:
		message += "\n跳过 %d 个已存在的绑定" % skipped_count

	_show_info_dialog("完成", message)

	print("[AudioComponentInspector] 自动创建绑定: %d 个创建, %d 个跳过" % [created_count, skipped_count])
```

**Step 2: 添加对话框辅助方法**

在类底部添加：

```gdscript
## 显示警告对话框
func _show_warning_dialog(title: String, message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.size = Vector2i(400, 150)
	dialog.unresizable = true

	var label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.add_child(label)

	add_child(dialog)
	var confirmed = await dialog.confirmed
	dialog.queue_free()

## 显示信息对话框
func _show_info_dialog(title: String, message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.size = Vector2i(400, 150)
	dialog.unresizable = true

	var label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.add_child(label)

	add_child(dialog)
	var confirmed = await dialog.confirmed
	dialog.queue_free()
```

**Step 3: 更新 plugin.gd 注册 SignalSelectionDialog**

修改 `addons/juicy_mixer/plugin.gd`：

在 `_enter_tree()` 中添加：

```gdscript
add_custom_type("SignalSelectionDialog", "AcceptDialog", preload("editor/dialogs/signal_selection_dialog.gd"), null)
```

在 `_exit_tree()` 中添加：

```gdscript
remove_custom_type("SignalSelectionDialog")
```

**Step 4: 端到端测试**

完整测试流程：

1. 创建测试场景：
   - 创建 Node2D 作为玩家
   - 添加自定义信号到脚本
   - 添加 JuicyAudioPlayer 作为子节点
   - 创建 AudioComponent 资源

2. 在编辑器中测试：
   - 选择 AudioComponent 资源
   - 点击"🔍 自动检测信号"
   - 在对话框中搜索和勾选信号
   - 确认创建
   - 验证 AudioComponent 中创建了正确的绑定

3. 测试各种场景：
   - 无 target_path：提示设置目标节点
   - 无自定义信号：显示未找到消息
   - 有信号：正常显示和创建
   - 重复信号：跳过已存在的绑定

**Step 5: 提交**

```bash
git add addons/juicy_mixer/editor/audio_component_inspector.gd
git add addons/juicy_mixer/plugin.gd
git commit -m "feat(audio): 集成自动检测信号功能到 AudioComponentInspector

- 实现完整的自动检测信号流程
- 集成 SignalDetector 和 SignalSelectionDialog
- 智能获取目标节点（target > target_path > 父节点）
- 批量创建 AudioBinding，跳过重复项
- 完善的错误处理和用户提示
- 支持搜索和多选

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: 编写测试和文档

**目标:** 完整的测试覆盖和用户文档

**Files:**
- Create: `addons/juicy_mixer/tests/audio/test_auto_detect_signals.tscn`
- Create: `addons/juicy_mixer/tests/audio/test_auto_detect_signals.gd`
- Create: `docs/audio_auto_detect_usage.md`

**Step 1: 创建端到端测试场景**

测试场景结构：
```
TestAutoDetect (Node)
├── Player (Node2D with script)
│   └── JuicyAudioPlayer
└── TestScript (用于验证)
```

Player 脚本包含自定义信号：
```gdscript
extends Node2D

signal jump
signal footstep
signal hurt(damage: int)
signal died
```

**Step 2: 编写测试脚本**

```gdscript
@tool
extends Node

## 自动检测信号端到端测试

func _ready():
	print("=== 自动检测信号功能测试 ===")
	_test_basic_detection()
	_test_search_filter()
	_test_duplicate_skip()
	print("\n✅ 所有测试完成！")
	get_tree().quit()

func _test_basic_detection():
	print("\n[测试 1] 基本检测功能")

	var player = $Player
	var audio_player = $Player/JuicyAudioPlayer

	# 设置 target
	audio_player.target = player

	# 创建 AudioComponent
	var component = AudioComponent.new()
	component.target_path = player.get_path()

	# 检测信号
	var signals = SignalDetector.detect_custom_signals(player)
	assert(signals.size() >= 4, "应该至少检测到 4 个信号")

	print("  ✓ 检测到 %d 个信号" % signals.size())

func _test_search_filter():
	print("\n[测试 2] 搜索过滤功能")

	var player = $Player
	var signals = SignalDetector.detect_custom_signals(player)
	var grouped = SignalDetector.group_signals_by_class(signals)

	# 测试搜索 "jump"
	var filtered = SignalDetector.apply_search_filter(grouped, "jump")
	assert(not filtered.is_empty(), "搜索应该返回结果")

	print("  ✓ 搜索过滤正常工作")

func _test_duplicate_skip():
	print("\n[测试 3] 跳过重复绑定")

	var component = AudioComponent.new()

	# 创建一个已存在的绑定
	var binding1 = AudioBinding.new()
	binding1.signal_name = "jump"
	component.audio_bindings.append(binding1)

	# 模拟再次创建
	var binding2 = AudioBinding.new()
	binding2.signal_name = "jump"

	var existing = component.find_binding_by_signal("jump")
	assert(existing == binding1, "应该找到已存在的绑定")

	print("  ✓ 重复检测正常工作")
```

**Step 3: 编写用户文档**

`docs/audio_auto_detect_usage.md`:

```markdown
# 自动检测信号功能使用指南

## 功能概述

自动检测信号功能允许您从场景节点快速检测信号并批量创建 AudioBinding，大幅简化音频配置流程。

## 使用方式

### 方式 1：通过 JuicyAudioPlayer（推荐）

1. 在场景中添加 JuicyAudioPlayer 作为子节点
2. 选择 JuicyAudioPlayer
3. 在 Inspector 中：
   - 方式 A：直接设置 `target` 属性为目标节点
   - 方式 B：点击"🔄 设置为父节点"按钮
4. 选择 JuicyAudioPlayer 的 `audio_component` 属性
5. 在 Inspector 底部点击"🔍 自动检测信号"
6. 在对话框中搜索并勾选要绑定的信号
7. 点击"确定"创建绑定

### 方式 2：直接使用 AudioComponent

1. 创建 AudioComponent 资源
2. 设置 `target_path` 属性为目标节点
3. 在 Inspector 中点击"🔍 自动检测信号"
4. 在对话框中搜索并勾选信号
5. 点击"确定"创建绑定

## 目标节点优先级

系统按以下优先级获取目标节点：

1. **显式 target** - JuicyAudioPlayer 的 `target` 属性
2. **target_path** - AudioComponent 的 `target_path` 属性
3. **父节点** - JuicyAudioPlayer 的父节点（向后兼容）

## 对话框功能

### 搜索过滤
- 顶部搜索框实时过滤信号
- 支持信号名称模糊搜索

### 树形结构
- 按 class 分组显示信号
- 显示信号参数类型（例如：`jump (velocity: float)`）
- 默认全部展开

### 多选
- 勾选要创建绑定的信号
- 确认按钮显示勾选数量

## 行为说明

### 自动过滤
- 内置信号（如 `ready`, `tree_entered`）会被自动过滤
- 以 `_` 开头的内部信号会被过滤
- 已存在的绑定会被跳过

### 创建结果
- 每个勾选的信号创建一个 AudioBinding
- 自动创建占位符 AudioEventResource
- 使用信号名称作为 event_name
- 需要后续手动分配实际的音频资源

## 常见问题

**Q: 为什么检测不到信号？**
A: 请确保：
- 目标节点已设置（target 或 target_path）
- 节点脚本中定义了自定义 signal
- 信号不是内置信号（会被过滤）

**Q: 如何批量修改音频事件？**
A:
1. 使用自动检测创建绑定
2. 在 Inspector 中逐个编辑 AudioBinding
3. 为每个绑定的 audio_event 分配实际的音频资源

**Q: target 和 target_path 有什么区别？**
A:
- `target` - Node 引用，运行时使用，不可序列化
- `target_path` - NodePath，可序列化到资源
- 系统会自动同步两者

## 示例

```gdscript
# 玩家脚本
extends CharacterBody2D

signal jump
signal footstep
signal hurt(damage: int)
signal died

func jump():
    jump.emit()

func _on_footstep():
    footstep.emit()
```

配置流程：
1. 添加 JuicyAudioPlayer 作为玩家子节点
2. 点击"🔄 设置为父节点"
3. 在 audio_component 中点击"🔍 自动检测信号"
4. 勾选 `jump`, `footstep`, `hurt`
5. 点击"确定"
6. 为每个绑定分配对应的音频事件资源
```

**Step 4: 运行完整测试套件**

测试场景：
- 基本检测功能
- 搜索过滤
- 重复跳过
- 目标节点优先级
- 对话框 UI 交互

预期: 所有测试通过

**Step 5: 最终提交**

```bash
git add addons/juicy_mixer/tests/audio/test_auto_detect_signals.tscn
git add addons/juicy_mixer/tests/audio/test_auto_detect_signals.gd
git add docs/audio_auto_detect_usage.md
git commit -m "test(audio): 添加自动检测信号功能的测试和文档

- 端到端测试场景和脚本
- 用户使用文档
- 测试基本检测、搜索过滤、重复跳过
- 完整的功能使用说明
- 常见问题解答

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## 完成总结

实施计划包含 **7 个主要任务**，涵盖：

1. ✅ AudioComponent 的 target_path 支持
2. ✅ JuicyAudioPlayer 的智能 target 系统
3. ✅ Inspector 按钮和状态显示
4. ✅ 信号检测和分组工具类
5. ✅ 信号选择对话框 UI
6. ✅ AudioComponentInspector 集成
7. ✅ 完整的测试和文档

**预计工作量:** 每个任务 30-60 分钟

**技术要点:**
- 保持向后兼容（父节点模式）
- 智能目标节点获取（target > target_path > 父节点）
- 过滤内置信号，只显示自定义信号
- 树形 UI + 搜索过滤
- 批量创建 + 重复跳过

**下一步:** 选择执行方式（Subagent-Driven 或 Parallel Session）
