# Instruction Generator Implementation Plan

> **Status:** Phase 1-6 COMPLETE | Phase 7 PENDING
>
> **Completed:** 2026-03-17
>
> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Bricks 插件添加右键菜单指令生成器功能，允许用户从任意节点的方法生成专用指令。

**质量标准：最小功能集**

生成的指令只需要满足"可正确运行"的最低要求：
- 能正确执行方法调用并传递参数
- 能注册到 InstructionRegistry 并显示在指令选择器中
- 能通过 validate() 基本校验
- 不包含本地化（使用 `metadata.name/category/description` 直接赋值，不使用 `name_key/category_key/description_key`）
- 不包含日志输出（不调用 `_log_debug_localized` 等方法）
- 不需要 `class_name`（通过文件路径注册，避免全局命名冲突）

**Architecture:**
- 扩展现有 `BricksContextMenuPlugin` 添加"生成指令"菜单项
- 创建 `MethodSelectorDialog` 窗口显示方法列表（复用 `FunctionManager` 的过滤逻辑）
- 创建 `InstructionGenerator` 核心类负责代码生成和文件保存
- 修改 `plugin.gd` 添加启动时扫描 `res://bricks_generated/instructions/` 目录

**Tech Stack:** GDScript 2.0, Godot 4.6 ClassDB 反射, 现有 Bricks 架构

**Dependencies（复用现有代码）:**

| 现有类 | 文件路径 | 复用功能 |
|--------|---------|----------|
| `FunctionManager` | `addons/bricks/utils/function_manager.gd` | 方法过滤（`_should_filter_method`）、继承链（`get_inheritance_chain`）、方法检测（`detect_method_definition`）、参数解析（`get_method_parameters`） |
| `TypeConverter` | `addons/bricks/utils/type_converter.gd` | 类型名映射（`get_type_name`）、类型兼容性检查（`is_compatible`） |
| `PropertyManager` | `addons/bricks/utils/property_manager.gd` | Phase 2 属性访问：可写属性过滤（`get_writable_properties`）、属性搜索（`search_properties`） |
| `PropertyInfo` | `addons/bricks/utils/property_info.gd` | Phase 2 属性访问：属性元数据模型、类型判断（`is_numeric/is_vector/is_object`） |
| `InstructionRegistry` | `addons/bricks/editor/instruction_selector/instruction_registry.gd` | 指令注册 |
| `BricksLocalization` | `addons/bricks/localization/bricks_localization.gd` | 本地化支持 |
| `BricksContextMenuPlugin` | `addons/bricks/editor/context_menu/bricks_context_menu_plugin.gd` | 右键菜单扩展 |

**复用策略:**
- `MethodFilter` 不再重写过滤逻辑，改为薄层封装 `FunctionManager` + 添加"按类分组"功能
- `TypeMapper` 复用 `TypeConverter.get_type_name()` 处理基础类型名，只保留代码生成特有的 `@export` 注解和默认值逻辑

---

## Phase 1: 基础设施 ✅ COMPLETE

### Task 1.1: 创建 MethodFilter（薄层封装 FunctionManager）✅

**Files:**
- Create: `addons/bricks/editor/instruction_generator/method_filter.gd`
- Read: `addons/bricks/utils/function_manager.gd`（复用其过滤逻辑）

**复用说明：**
- `FunctionManager._should_filter_method()` - 过滤私有方法、虚方法（直接调用，不重写）
- `FunctionManager._is_getter_method()` - 过滤 getter 方法
- `FunctionManager.get_inheritance_chain()` - 获取继承链
- `FunctionManager.is_virtual_method_from_info()` / `is_static_method_from_info()` - 方法标志判断

**新增功能（仅此模块独有的部分）：**
- 按定义类分组方法（`filter_methods` 返回 `{class_name: [methods]}` 结构）
- 基于 ClassDB 的方法列表获取（`get_class_methods_with_inheritance`）

**Step 1: 创建 MethodFilter 类**

```gdscript
# 文件：addons/bricks/editor/instruction_generator/method_filter.gd
@tool
class_name MethodFilter extends RefCounted

## 方法过滤器
## 薄层封装 FunctionManager 的过滤逻辑，添加按类分组功能
## 纯新增功能：
##   - filter_methods(): 按定义类分组
##   - get_class_methods_with_inheritance(): 基于 ClassDB 的方法列表（含继承信息）
## 复用 FunctionManager 的：
##   - _should_filter_method(): 过滤私有/虚方法
##   - _is_getter_method(): 过滤 getter
##   - get_inheritance_chain(): 继承链
##   - is_virtual_method_from_info() / is_static_method_from_info(): 方法标志

## 过滤方法列表并按定义类分组
## @param methods: 原始方法列表（来自 ClassDB.class_get_method_list）
## @return: 按类分组的方法字典 {class_name: [method_info, ...]}
static func filter_methods(methods: Array[Dictionary]) -> Dictionary:
	var result := {}

	for method_info in methods:
		var method_name = method_info.get("name", "")

		# 复用 FunctionManager 的过滤逻辑
		if _should_skip_method(method_name, method_info):
			continue

		var defined_in = method_info.get("defined_in_class", "")
		if defined_in.is_empty():
			defined_in = "Unknown"

		if not result.has(defined_in):
			result[defined_in] = []

		result[defined_in].append({
			"name": method_name,
			"args": method_info.get("args", []),
			"return": method_info.get("return", {}),
			"flags": method_info.get("flags", 0),
			"defined_in_class": defined_in,
			"has_default_values": _has_default_values(method_info)
		})

	return result

## 判断方法是否应该跳过
## 组合复用 FunctionManager 的多个静态方法
static func _should_skip_method(method_name: String, method_info: Dictionary) -> bool:
	# 复用: FunctionManager._should_filter_method()
	if FunctionManager._should_filter_method(method_name):
		return true

	# 复用: FunctionManager.is_virtual_method_from_info()
	if FunctionManager.is_virtual_method_from_info(method_info):
		return true

	# 复用: FunctionManager.is_static_method_from_info()
	if FunctionManager.is_static_method_from_info(method_info):
		return true

	return false

## 检查方法是否有默认参数值
static func _has_default_values(method_info: Dictionary) -> bool:
	var args = method_info.get("args", [])
	for arg in args:
		if arg.has("default_value"):
			return true
	return false

## 获取类的继承链
## 复用 ClassDB API（FunctionManager 的版本需要 Node 实例，这里直接用类名字符串）
## @param class_name: 类名
## @return: 继承链数组 [class_name, parent_class, ...]
static func get_inheritance_chain(class_name: String) -> Array[String]:
	var chain: Array[String] = []
	var current = class_name

	while not current.is_empty():
		chain.append(current)
		current = ClassDB.get_parent_class(current)
		if chain.size() > 50:
			break

	return chain

## 获取类的方法列表（带继承信息）
## 注意：这个方法基于 ClassDB（不需要 Node 实例），与 FunctionManager 的版本互补
## @param class_name: 类名
## @return: 方法列表，每个方法包含 defined_in_class 字段
static func get_class_methods_with_inheritance(class_name: String) -> Array[Dictionary]:
	var all_methods: Array[Dictionary] = []
	var chain = get_inheritance_chain(class_name)

	chain.reverse()
	for cls in chain:
		var class_methods = ClassDB.class_get_method_list(cls, true)
		for method in class_methods:
			method["defined_in_class"] = cls

			var existing_index = -1
			for i in range(all_methods.size()):
				if all_methods[i].get("name") == method.get("name"):
					existing_index = i
					break

			if existing_index >= 0:
				all_methods[existing_index] = method
			else:
				all_methods.append(method)

	return all_methods
```

**Step 2: Commit**

```bash
git add addons/bricks/editor/instruction_generator/method_filter.gd
git commit -m "feat(bricks): add MethodFilter wrapping FunctionManager for class-based grouping"
```

---

### Task 1.2: 创建 TypeMapper（复用 TypeConverter 类型名映射）✅

**Files:**
- Create: `addons/bricks/editor/instruction_generator/type_mapper.gd`
- Read: `addons/bricks/utils/type_converter.gd`（复用 `get_type_name`）

**复用说明：**
- `TypeConverter.get_type_name()` - 类型 ID 到名称映射（已有 18 种基础类型）
- 仅新增代码生成特有的功能：`@export` 注解、GDScript 类型声明、默认值字符串

**Step 1: 创建 TypeMapper 类**

```gdscript
# 文件：addons/bricks/editor/instruction_generator/type_mapper.gd
@tool
class_name TypeMapper extends RefCounted

## 类型映射器
## 复用 TypeConverter.get_type_name() 处理基础类型名
## 仅新增代码生成特有的功能：
##   - get_type_declaration(): Godot 类型 → GDScript @export 类型声明
##   - get_default_value(): 类型 → 默认值字符串
##   - get_export_annotation(): 类型/hint → @export 注解
##   - param_to_property(): 参数字典 → 完整属性声明行

## GDScript 类型声明（TypeConverter.get_type_name 返回的是大写标识符如 "VECTOR2"）
## 这里需要 GDScript 的 PascalCase 类型名
const GDSCRIPT_TYPE_NAMES := {
	TYPE_NIL: "Variant",
	TYPE_BOOL: "bool",
	TYPE_INT: "int",
	TYPE_FLOAT: "float",
	TYPE_STRING: "String",
	TYPE_VECTOR2: "Vector2",
	TYPE_VECTOR2I: "Vector2i",
	TYPE_VECTOR3: "Vector3",
	TYPE_VECTOR3I: "Vector3i",
	TYPE_VECTOR4: "Vector4",
	TYPE_VECTOR4I: "Vector4i",
	TYPE_COLOR: "Color",
	TYPE_RECT2: "Rect2",
	TYPE_RECT2I: "Rect2i",
	TYPE_TRANSFORM2D: "Transform2D",
	TYPE_TRANSFORM3D: "Transform3D",
	TYPE_BASIS: "Basis",
	TYPE_QUATERNION: "Quaternion",
	TYPE_ARRAY: "Array",
	TYPE_DICTIONARY: "Dictionary",
	TYPE_NODE_PATH: "NodePath",
	TYPE_STRING_NAME: "StringName",
	TYPE_RID: "RID",
	TYPE_OBJECT: "Object",
	TYPE_CALLABLE: "Callable",
	TYPE_SIGNAL: "Signal",
	TYPE_PACKED_BYTE_ARRAY: "PackedByteArray",
	TYPE_PACKED_INT32_ARRAY: "PackedInt32Array",
	TYPE_PACKED_INT64_ARRAY: "PackedInt64Array",
	TYPE_PACKED_FLOAT32_ARRAY: "PackedFloat32Array",
	TYPE_PACKED_FLOAT64_ARRAY: "PackedFloat64Array",
	TYPE_PACKED_STRING_ARRAY: "PackedStringArray",
	TYPE_PACKED_VECTOR2_ARRAY: "PackedVector2Array",
	TYPE_PACKED_VECTOR3_ARRAY: "PackedVector3Array",
	TYPE_PACKED_COLOR_ARRAY: "PackedColorArray",
}

## 获取类型的 GDScript 声明
## @param type: Variant 类型 ID
## @param hint: 属性提示
## @param hint_string: 提示字符串（可能包含类名）
## @return: 类型声明字符串（如 "int", "Texture2D", "Variant"）
static func get_type_declaration(type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> String:
	if type == TYPE_OBJECT and not hint_string.is_empty():
		return hint_string

	if hint == PROPERTY_HINT_ENUM and not hint_string.is_empty():
		return "int"

	if hint == PROPERTY_HINT_FLAGS and not hint_string.is_empty():
		return "int"

	if hint == PROPERTY_HINT_RESOURCE_TYPE and not hint_string.is_empty():
		return hint_string

	if GDSCRIPT_TYPE_NAMES.has(type):
		return GDSCRIPT_TYPE_NAMES[type]

	return "Variant"

## 获取类型的默认值字符串
static func get_default_value(type: int) -> String:
	if type == TYPE_OBJECT:
		return "null"

	match type:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "false"
		TYPE_INT: return "0"
		TYPE_FLOAT: return "0.0"
		TYPE_STRING: return "\"\""
		TYPE_VECTOR2: return "Vector2.ZERO"
		TYPE_VECTOR2I: return "Vector2i.ZERO"
		TYPE_VECTOR3: return "Vector3.ZERO"
		TYPE_VECTOR3I: return "Vector3i.ZERO"
		TYPE_VECTOR4: return "Vector4.ZERO"
		TYPE_VECTOR4I: return "Vector4i.ZERO"
		TYPE_COLOR: return "Color.WHITE"
		TYPE_RECT2: return "Rect2()"
		TYPE_RECT2I: return "Rect2i()"
		TYPE_ARRAY: return "[]"
		TYPE_DICTIONARY: return "{}"
		TYPE_NODE_PATH: return "NodePath(\"\")"
		TYPE_STRING_NAME: return "&\"\""
		_: return "null"

## 获取 @export 注解
static func get_export_annotation(type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> String:
	if hint == PROPERTY_HINT_RANGE and not hint_string.is_empty():
		return "@export_range(\"%s\")" % hint_string
	if hint == PROPERTY_HINT_ENUM and not hint_string.is_empty():
		return "@export_enum(\"%s\")" % hint_string
	if hint == PROPERTY_HINT_FILE:
		return "@export_file(\"%s\")" % hint_string
	if hint == PROPERTY_HINT_DIR:
		return "@export_dir()"
	if hint == PROPERTY_HINT_GLOBAL_FILE:
		return "@export_global_file(\"%s\")" % hint_string
	if hint == PROPERTY_HINT_COLOR_NO_ALPHA:
		return "@export_color_no_alpha"
	return "@export"

## 将参数信息转换为完整的 @export 属性声明行
static func param_to_property(param: Dictionary) -> String:
	var param_name = param.get("name", "param")
	var type = param.get("type", TYPE_NIL)
	var hint = param.get("hint", PROPERTY_HINT_NONE)
	var hint_string = param.get("hint_string", "")
	var default_value = param.get("default_value", null)

	var export_annotation = get_export_annotation(type, hint, hint_string)
	var type_decl = get_type_declaration(type, hint, hint_string)

	var result = "%s var %s: %s" % [export_annotation, param_name, type_decl]

	if default_value != null:
		result += " = %s" % _value_to_string(default_value, type)
	else:
		result += " = %s" % get_default_value(type)

	return result

## 将值转换为 GDScript 代码字符串
static func value_to_string(value: Variant, type: int) -> String:
	if value == null:
		return "null"
	match type:
		TYPE_STRING:
			return "\"%s\"" % value
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_VECTOR2:
			return "Vector2(%s, %s)" % [value.x, value.y]
		TYPE_VECTOR3:
			return "Vector3(%s, %s, %s)" % [value.x, value.y, value.z]
		TYPE_COLOR:
			return "Color(%s, %s, %s, %s)" % [value.r, value.g, value.b, value.a]
		_:
			return str(value)
```

---

## Phase 2: UI 开发 ✅ COMPLETE

### Task 2.1: 创建方法选择对话框 ✅

**Files:**
- Create: `addons/bricks/editor/instruction_generator/method_selector_dialog.gd`

**Step 1: 创建 MethodSelectorDialog 类**

```gdscript
# 文件：addons/bricks/editor/instruction_generator/method_selector_dialog.gd
@tool
class_name MethodSelectorDialog extends Window

## 方法选择对话框
## 继承 Window 而非 AcceptDialog，避免内置按钮与自定义 UI 冲突

## 信号：方法被选中
signal method_selected(method_info: Dictionary, target_class: String)

## 预加载本地化工具类
const BricksLocalization = preload("res://addons/bricks/localization/bricks_localization.gd")

## 搜索防抖定时器
var _search_timer: Timer = null
const SEARCH_DEBOUNCE_MS := 200

## UI 组件
var _search_box: LineEdit
var _method_tree: Tree
var _method_info_label: RichTextLabel
var _generate_button: Button

## 数据
var _target_node: Node = null
var _target_class: String = ""
var _methods_by_class: Dictionary = {}
var _selected_method: Dictionary = {}

func _ready() -> void:
	_setup_dialog()

## 设置对话框
func _setup_dialog() -> void:
	var _title_key := "BRICKS_INSTRUCTION_GENERATOR_TITLE"
	title = BricksLocalization.translate(_title_key)
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

	# 搜索框
	_search_box = LineEdit.new()
	var _search_key := "BRICKS_INSTRUCTION_GENERATOR_SEARCH"
	_search_box.placeholder_text = BricksLocalization.translate(_search_key)
	if _search_box.placeholder_text == _search_key:
		_search_box.placeholder_text = "搜索方法..."
	_search_box.clear_button_enabled = true
	_search_box.text_changed.connect(_on_search_text_changed)
	main_vbox.add_child(_search_box)

	# 防抖定时器
	_search_timer = Timer.new()
	_search_timer.wait_time = SEARCH_DEBOUNCE_MS / 1000.0
	_search_timer.one_shot = true
	_search_timer.timeout.connect(_on_search_timer_timeout)
	add_child(_search_timer)

	# 中间区域：方法树 + 方法信息
	var h_split = HSplitContainer.new()
	h_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(h_split)

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

	# 底部按钮（自行管理，不使用 AcceptDialog 内置按钮）
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(button_hbox)

	_generate_button = Button.new()
	var _generate_key := "BRICKS_INSTRUCTION_GENERATOR_GENERATE"
	_generate_button.text = BricksLocalization.translate(_generate_key)
	if _generate_button.text == _generate_key:
		_generate_button.text = "生成指令"
	_generate_button.disabled = true
	_generate_button.pressed.connect(_on_generate_pressed)
	button_hbox.add_child(_generate_button)

	var cancel_button = Button.new()
	var _cancel_key := "BRICKS_UI_CANCEL"
	cancel_button.text = BricksLocalization.translate(_cancel_key)
	if cancel_button.text == _cancel_key:
		cancel_button.text = "取消"
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_hbox.add_child(cancel_button)

## 获取标题文本
func _get_header_text() -> String:
	if _target_node:
		var node_name = _target_node.name
		var class_name = _target_node.get_class()
		return "为 %s (%s) 生成指令" % [node_name, class_name]
	return "生成指令"

## 设置目标节点
func set_target_node(node: Node) -> void:
	_target_node = node
	_target_class = node.get_class()

	# 获取方法列表
	var all_methods = MethodFilter.get_class_methods_with_inheritance(_target_class)
	_methods_by_class = MethodFilter.filter_methods(all_methods)

	# 延迟填充（确保 tree_entered 在 _ready 之前不会导致 null 引用）
	if is_inside_tree():
		_populate_method_tree.call_deferred("")
	else:
		tree_entered.connect(_deferred_populate)

## 填充方法树
func _populate_method_tree(search_text: String) -> void:
	_method_tree.clear()

	var root = _method_tree.create_item()
	_method_tree.hide_root = true

	# 获取继承链用于排序
	var inheritance_chain = MethodFilter.get_inheritance_chain(_target_class)

	# 按继承顺序显示（子类在前）
	for class_name in inheritance_chain:
		if not _methods_by_class.has(class_name):
			continue

		var methods = _methods_by_class[class_name]
		var filtered_methods = _filter_methods_by_search(methods, search_text.to_lower())

		if filtered_methods.is_empty():
			continue

		# 创建类分类项
		var class_item = _method_tree.create_item(root)
		class_item.set_text(0, "%s (%d)" % [class_name, filtered_methods.size()])
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

## 搜索文本变化回调（带防抖）
func _on_search_text_changed(text: String) -> void:
	_search_timer.start()

## 防抖定时器到期
func _on_search_timer_timeout() -> void:
	_populate_method_tree(_search_box.text)

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

## 生成按钮点击回调
func _on_generate_pressed() -> void:
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

	return ConflictHandler.check_conflict(cls_name, method_name, output_dir)

## 显示冲突对话框
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

## 发送选中信号
func _emit_selection(action: String = "create") -> void:
	method_selected.emit(_selected_method, _target_class)
	hide()
	queue_free()

## 取消按钮点击回调
func _on_cancel_pressed() -> void:
	hide()
	queue_free()
```

**Step 2: 验证文件创建**

Expected: `addons/bricks/editor/instruction_generator/method_selector_dialog.gd` 文件已创建

**Step 3: Commit**

```bash
git add addons/bricks/editor/instruction_generator/method_selector_dialog.gd
git commit -m "feat(bricks): add MethodSelectorDialog for instruction generator"
```

---

### Task 2.2: 创建冲突处理器 ✅

**Files:**
- Create: `addons/bricks/editor/instruction_generator/conflict_handler.gd`

**Step 1: 创建 ConflictHandler 类**

```gdscript
# 文件：addons/bricks/editor/instruction_generator/conflict_handler.gd
@tool
class_name ConflictHandler extends RefCounted

## 冲突处理器
## 处理指令文件生成时的命名冲突

## 检查文件是否存在
## @param class_name: 目标类名
## @param method_name: 方法名
## @param output_dir: 输出目录
## @return: 冲突信息字典
static func check_conflict(class_name: String, method_name: String, output_dir: String) -> Dictionary:
	var file_name = generate_file_name(class_name, method_name)
	var file_path = output_dir.path_join(file_name)

	if FileAccess.file_exists(file_path):
		return {
			"exists": true,
			"path": file_path,
			"action": "ask"  # ask, overwrite, skip, rename
		}

	return {"exists": false, "path": file_path}

## 生成文件名
## @param class_name: 目标类名
## @param method_name: 方法名
## @return: 文件名（不含路径）
static func generate_file_name(class_name: String, method_name: String) -> String:
	var safe_class = _to_snake_case(class_name)
	var safe_method = _to_snake_case(method_name)
	return "%s_%s.gd" % [safe_class, safe_method]

## 生成唯一文件名
## @param class_name: 目标类名
## @param method_name: 方法名
## @param output_dir: 输出目录
## @return: 唯一文件名
static func generate_unique_file_name(class_name: String, method_name: String, output_dir: String) -> String:
	var base_name = generate_file_name(class_name, method_name)
	var file_path = output_dir.path_join(base_name)

	if not FileAccess.file_exists(file_path):
		return base_name

	# 添加数字后缀
	var counter = 1
	while true:
		var ext = base_name.get_extension()
		var base = base_name.get_basename()
		var new_name = "%s_%d.%s" % [base, counter, ext]
		var new_path = output_dir.path_join(new_name)

		if not FileAccess.file_exists(new_path):
			return new_name

		counter += 1
		if counter > 100:
			break

	return base_name

## 转换为 snake_case
## 处理规则：大写字母前插入下划线（除非前一个字符也是大写或非字母）
## 示例：Sprite2D → sprite_2d, RigidBody2D → rigid_body_2d, setPosition → set_position
static func _to_snake_case(s: String) -> String:
	var result := ""
	for i in range(s.length()):
		var c := s[i]
		if c >= "A" and c <= "Z":
			# 在大写字母前插入下划线，但跳过连续大写（缩写词）
			if i > 0:
				var prev := s[i - 1]
				if prev >= "a" and prev <= "z":
					result += "_"
		result += c.to_lower()
	return result
```

**Step 2: 验证文件创建**

Expected: `addons/bricks/editor/instruction_generator/conflict_handler.gd` 文件已创建

**Step 3: Commit**

```bash
git add addons/bricks/editor/instruction_generator/conflict_handler.gd
git commit -m "feat(bricks): add ConflictHandler for instruction generator"
```

---

## Phase 3: 核心生成器 ✅ COMPLETE

### Task 3.1: 创建指令生成器 ✅

**Files:**
- Create: `addons/bricks/editor/instruction_generator/instruction_generator.gd`

**Step 1: 创建 InstructionGenerator 类**

```gdscript
# 文件：addons/bricks/editor/instruction_generator/instruction_generator.gd
@tool
class_name InstructionGenerator extends RefCounted

## 指令生成器
## 根据节点类和方法信息生成 Bricks 指令文件

## 预加载依赖
const BricksLocalization = preload("res://addons/bricks/localization/bricks_localization.gd")

## 默认输出目录
const DEFAULT_OUTPUT_DIR := "res://bricks_generated/instructions"

## 生成指令文件
## @param target_class: 目标类名
## @param method_info: 方法信息字典
## @param output_dir: 输出目录（可选，默认为 res://bricks_generated/instructions）
## @return: 生成结果字典 {"success": bool, "path": String, "error": String}
static func generate_instruction(target_class: String, method_info: Dictionary, output_dir: String = "") -> Dictionary:
	if output_dir.is_empty():
		output_dir = DEFAULT_OUTPUT_DIR

	# 确保输出目录存在
	var class_dir = output_dir.path_join(target_class.to_lower())
	if not _ensure_directory(class_dir):
		return {"success": false, "path": "", "error": "无法创建输出目录: %s" % class_dir}

	# 生成文件内容
	var code = _generate_code(target_class, method_info)
	if code.is_empty():
		return {"success": false, "path": "", "error": "无法生成代码"}

	# 生成文件名
	var method_name = method_info.get("name", "")
	var file_name = ConflictHandler.generate_file_name(target_class, method_name)
	var file_path = class_dir.path_join(file_name)

	# 写入文件
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "path": "", "error": "无法打开文件: %s" % file_path}

	file.store_string(code)
	file.close()

	return {"success": true, "path": file_path, "error": ""}

## 确保目录存在
static func _ensure_directory(path: String) -> bool:
	var abs_path = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(abs_path):
		return true
	var dir := DirAccess.open("res://")
	if dir == null:
		return false
	return dir.make_dir_recursive_absolute(abs_path) == OK

## 生成指令代码
static func _generate_code(target_class: String, method_info: Dictionary) -> String:
	var method_name = method_info.get("name", "")
	var args = method_info.get("args", [])
	var return_info = method_info.get("return", {})

	# 生成类名（仅用于内部引用，不使用 class_name 避免全局冲突）
	var instruction_class = "Call%s%s" % [target_class, method_name.to_pascal_case()]

	# 生成代码
	var code = ""

	# 文件头（不使用 class_name，避免全局命名空间污染和重复生成冲突）
	code += "@tool\n"
	code += "@icon(\"res://addons/bricks/icons/instruction.svg\")\n"
	code += "extends BaseInstruction\n\n"

	# 类文档
	code += "## 调用 %s.%s 方法\n" % [target_class, method_name]
	code += "## 自动生成 - 请勿手动修改\n\n"

	# 目标节点路径
	code += "## 目标节点路径\n"
	code += "@export var target_node: NodePath = NodePath(\"\")\n\n"

	# 参数属性
	if args.size() > 0:
		code += "## 方法参数\n"
		for arg in args:
			code += TypeMapper.param_to_property(arg) + "\n"
		code += "\n"

	# 返回值变量
	var return_type = return_info.get("type", TYPE_NIL)
	if return_type != TYPE_NIL:
		code += "## 返回值存储变量名（可选）\n"
		code += "@export var result_variable: String = \"\"\n"
		code += "## 返回值存储作用域\n"
		code += "@export var result_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:\n"
		code += "\tset(value):\n"
		code += "\t\tresult_variable_scope = value\n"
		code += "\t\tnotify_property_list_changed()\n"
		code += "## 作用域来源（仅 SCOPE 作用域时生效）\n"
		code += "enum ScopeSource { NEAREST, CUSTOM_ID, TRIGGER_SCOPE, TARGET_NODE }\n"
		code += "@export var scope_source: ScopeSource = ScopeSource.NEAREST:\n"
		code += "\tset(value):\n"
		code += "\t\tscope_source = value\n"
		code += "\t\tnotify_property_list_changed()\n"
		code += "## 自定义作用域 ID（仅 CUSTOM_ID 模式时生效）\n"
		code += "@export var custom_scope_id: String = \"\"\n\n"

	# 元数据方法
	code += _generate_metadata_method(target_class, method_name, args)

	# _setup_metadata 方法
	code += "func _setup_metadata():\n"
	code += "\tpass\n\n"

	# _update_resource_name 方法
	code += _generate_update_resource_name(instruction_class)

	# execute 方法
	code += _generate_execute_method(target_class, method_name, args, return_info)

	# get_description 方法
	code += _generate_get_description(target_class, method_name)

	# validate 方法
	code += _generate_validate_method(args)

	return code

## 生成元数据方法
static func _generate_metadata_method(target_class: String, method_name: String, args: Array) -> String:
	var code = "static func _get_instruction_metadata() -> InstructionMetadata:\n"
	code += "\tvar md = InstructionMetadata.new()\n"
	code += "\tmd.name = \"调用 %s.%s\"\n" % [target_class, method_name]
	code += "\tmd.category = \"用户生成\"\n"
	code += "\tmd.description = \"调用 %s 节点的 %s 方法\"\n" % [target_class, method_name]
	code += "\tmd.keywords = [\"%s\", \"%s\", \"%s\"]\n" % [target_class.to_lower(), method_name.to_lower(), "call"]
	code += "\treturn md\n\n"

	return code

## 生成 _update_resource_name 方法
static func _generate_update_resource_name(instruction_class: String) -> String:
	var code = "func _update_resource_name():\n"
	code += "\tresource_name = \"%s\"\n\n" % instruction_class

	return code

## 生成 execute 方法
static func _generate_execute_method(target_class: String, method_name: String, args: Array, return_info: Dictionary) -> String:
	var code = "func execute(context: ExecutionContext):\n"
	code += "\t_start_execution(context)\n\n"

	# 验证目标节点
	code += "\t# 验证目标节点\n"
	code += "\tif target_node.is_empty():\n"
	code += "\t\tset_error(\"目标节点路径为空\")\n"
	code += "\t\tfinished.emit()\n"
	code += "\t\treturn\n\n"

	# 获取目标节点
	code += "\t# 获取目标节点\n"
	code += "\tvar node := context.get_node(target_node)\n"
	code += "\tif node == null:\n"
	code += "\t\tset_error(\"找不到目标节点: %s\" % str(target_node))\n"
	code += "\t\tfinished.emit()\n"
	code += "\t\treturn\n\n"

	# 类型检查
	code += "\t# 类型检查\n"
	code += "\tif not node is %s:\n" % target_class
	code += "\t\tset_error(\"目标节点不是 %s 类型\")\n" % target_class
	code += "\t\tfinished.emit()\n"
	code += "\t\treturn\n\n"

	# 调用方法
	code += "\t# 调用方法\n"

	if args.size() > 0:
		var arg_list = []
		for arg in args:
			arg_list.append(arg.get("name", "param"))
		code += "\tvar result = node.%s(%s)\n" % [method_name, ", ".join(arg_list)]
	else:
		code += "\tvar result = node.%s()\n" % method_name

	code += "\n"

	# 处理返回值
	var return_type = return_info.get("type", TYPE_NIL)
	if return_type != TYPE_NIL:
		code += "\t# 存储返回值\n"
		code += "\tif not result_variable.is_empty():\n"
		code += "\t\tmatch result_variable_scope:\n"
		code += "\t\t\tBaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:\n"
		code += "\t\t\t\tVariableOperations.set_variable(context, result_variable, result_variable_scope, result)\n"
		code += "\t\t\tBaseVariable.VariableScope.SCOPE:\n"
		code += "\t\t\t\tif scope_source == ScopeSource.NEAREST:\n"
		code += "\t\t\t\t\tVariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.SCOPE, result)\n"
		code += "\t\t\t\telse:\n"
		code += "\t\t\t\t\tvar utils_scope_source = scope_source as VariableScopeUtils.ScopeSource\n"
		code += "\t\t\t\t\tvar scope_container = VariableScopeUtils.get_scope_container_by_source(context, utils_scope_source, custom_scope_id, target_node)\n"
		code += "\t\t\t\t\tif scope_container == null:\n"
		code += "\t\t\t\t\t\tset_error(\"找不到作用域容器\")\n"
		code += "\t\t\t\t\t\tfinished.emit()\n"
		code += "\t\t\t\t\t\treturn\n"
		code += "\t\t\t\t\tscope_container.set_variable(result_variable, result)\n\n"

	code += "\t_on_execution_completed()\n\n"

	return code

## 生成 get_description 方法
static func _generate_get_description(target_class: String, method_name: String) -> String:
	var code = "func get_description() -> String:\n"
	code += "\treturn \"调用 %s.%s on \" + str(target_node)\n\n" % [target_class, method_name]

	return code

## 生成 validate 方法
static func _generate_validate_method(args: Array) -> String:
	var code = "func validate() -> Array[String]:\n"
	code += "\tvar errors = super.validate()\n"

	code += "\tif target_node.is_empty():\n"
	code += "\t\terrors.append(\"目标节点路径为空\")\n"

	code += "\treturn errors\n\n"

	return code
```

**Step 2: 验证文件创建**

Expected: `addons/bricks/editor/instruction_generator/instruction_generator.gd` 文件已创建

**Step 3: Commit**

```bash
git add addons/bricks/editor/instruction_generator/instruction_generator.gd
git commit -m "feat(bricks): add InstructionGenerator core class"
```

---

## Phase 4: 集成 ✅ COMPLETE

### Task 4.1: 扩展右键菜单插件 ✅

**Files:**
- Modify: `addons/bricks/editor/context_menu/bricks_context_menu_plugin.gd`

**Step 1: 添加"生成指令"菜单项**

在 `_popup_menu` 方法末尾添加：

```gdscript
# 指令生成器 - 支持任意节点（注意：必须在条件判断之前保存 _pending_paths）
# 因为后续的条件分支可能不会走到
if nodes.size() == 1:
	_pending_paths = paths  # 确保路径已保存
	add_context_menu_item("生成指令...", Callable(self, "_on_generate_instruction"))
```

**注意：** `_pending_paths` 在前面的 `TriggerMerger` 和 `TriggerSplitter` 分支中各自赋值了一次。这里需要确保在添加"生成指令"菜单项时 `_pending_paths` 一定有值。如果前面两个条件都不满足但 `nodes.size() == 1`，需要在此处赋值。

**Step 2: 添加回调方法**

在类末尾添加：

```gdscript
## 生成指令回调
func _on_generate_instruction(_paths: PackedStringArray) -> void:
    if _editor_plugin == null:
        push_error("[BricksContextMenuPlugin] _editor_plugin is null!")
        return

    var edited_scene_root := _editor_plugin.get_editor_interface().get_edited_scene_root()
    if edited_scene_root == null:
        push_error("[BricksContextMenuPlugin] edited_scene_root is null!")
        return

    # 获取选中节点
    if _pending_paths.is_empty():
        push_error("[BricksContextMenuPlugin] _pending_paths is empty!")
        return

    var node := edited_scene_root.get_node_or_null(_pending_paths[0])
    if node == null:
        push_error("[BricksContextMenuPlugin] Node not found: ", _pending_paths[0])
        return

    # 创建并显示方法选择对话框（Window 需要先设置位置再弹出）
    var dialog := MethodSelectorDialog.new()
    dialog.set_target_node(node)
    dialog.method_selected.connect(_on_method_selected.bind(node))

    _editor_plugin.get_editor_interface().get_base_control().add_child(dialog)
    dialog.popup_centered(Vector2i(700, 500))

## 方法选中回调
func _on_method_selected(method_info: Dictionary, target_class: String, node: Node) -> void:
    # 生成指令
    var result = InstructionGenerator.generate_instruction(target_class, method_info)

    if result.success:
        print("[Bricks] 指令已生成: %s" % result.path)

        # 注册新指令
        var script = load(result.path)
        if script:
            InstructionRegistry.register_instruction(script)
            print("[Bricks] 指令已注册: %s" % result.path)

        # 刷新编辑器
        _editor_plugin.get_editor_interface().get_resource_filesystem().scan()
    else:
        push_error("[Bricks] 指令生成失败: %s" % result.error)
```

**Step 3: 添加预加载**

在文件顶部添加：

```gdscript
# 在文件开头添加
const MethodSelectorDialog = preload("res://addons/bricks/editor/instruction_generator/method_selector_dialog.gd")
const InstructionGenerator = preload("res://addons/bricks/editor/instruction_generator/instruction_generator.gd")
const InstructionRegistry = preload("res://addons/bricks/editor/instruction_selector/instruction_registry.gd")
```

**Step 4: Commit**

```bash
git add addons/bricks/editor/context_menu/bricks_context_menu_plugin.gd
git commit -m "feat(bricks): integrate instruction generator into context menu"
```

---

### Task 4.2: 添加启动时扫描生成指令 ✅

**Files:**
- Modify: `addons/bricks/plugin.gd`

**Step 1: 在 `_register_all_instructions` 方法中添加扫描目录**

在 `instruction_folders` 数组中添加：

```gdscript
var instruction_folders = [
    "res://addons/bricks/instructions/",
    "res://addons/bricks/integration/",
    "res://bricks_generated/instructions/"  # 新增：扫描生成的指令
]
```

**Step 2: Commit**

```bash
git add addons/bricks/plugin.gd
git commit -m "feat(bricks): scan generated instructions on startup"
```

---

### Task 4.3: 添加对话框本地化键 ✅

**Files:**
- Modify: `addons/bricks/localization/translations.csv`

**说明：** 项目使用单一翻译文件 `translations.csv`，格式为三列 `key,zh_CN,en_US`。仅需添加对话框 UI 的翻译键（生成指令的内容不使用本地化，遵循最小功能集标准）。

**Step 1: 添加翻译条目**

在 `translations.csv` 末尾追加：

```csv
BRICKS_INSTRUCTION_GENERATOR_TITLE,生成指令,Generate Instruction
BRICKS_INSTRUCTION_GENERATOR_SEARCH,搜索方法...,Search methods...
BRICKS_INSTRUCTION_GENERATOR_GENERATE,生成指令,Generate Instruction
BRICKS_INSTRUCTION_GENERATOR_CONFLICT,文件已存在,File already exists
BRICKS_INSTRUCTION_GENERATOR_OVERWRITE,覆盖,Overwrite
BRICKS_INSTRUCTION_GENERATOR_SKIP,跳过,Skip
```

**Step 2: Commit**

```bash
git add addons/bricks/localization/translations.csv
git commit -m "feat(bricks): add localization keys for instruction generator dialog"
```

---

## Phase 5: 测试与验证 ✅ COMPLETE

### Task 5.1: 手动测试 ✅

**Step 1: 重启 Godot 编辑器**

确保插件正确加载。

**Step 2: 测试右键菜单**

1. 在场景树中选择任意节点
2. 右键打开上下文菜单
3. 应该看到"生成指令..."选项

**Step 3: 测试方法选择**

1. 点击"生成指令..."
2. 应该弹出方法选择对话框
3. 验证方法列表正确显示
4. 验证搜索功能
5. 验证方法信息显示

**Step 4: 测试指令生成**

1. 选择一个方法（如 `Sprite2D.set_texture`）
2. 点击"生成指令"
3. 验证文件生成到 `res://bricks_generated/instructions/sprite2d/`
4. 验证生成的代码结构正确

**Step 5: 测试指令注册**

1. 检查控制台输出是否有注册成功信息
2. 在 Bricks 指令选择器中搜索生成的指令
3. 验证指令可以添加到 Trigger

---

### Task 5.2: 边缘情况测试 ✅

**测试场景:**

1. **空节点选择** - 验证错误处理
2. **文件已存在** - 验证冲突对话框
3. **复杂参数类型** - 验证 Variant 类型处理
4. **带返回值方法** - 验证返回值存储功能
5. **多参数方法** - 验证参数生成正确

---

## 文件清单

### 新建文件

| 文件路径 | 说明 | 复用关系 |
|---------|------|----------|
| `addons/bricks/editor/instruction_generator/method_filter.gd` | 方法过滤器（按类分组） | 复用 `FunctionManager` 过滤逻辑 |
| `addons/bricks/editor/instruction_generator/type_mapper.gd` | 类型映射器（代码生成用） | 复用 `TypeConverter` 类型名 |
| `addons/bricks/editor/instruction_generator/method_selector_dialog.gd` | 方法选择对话框 | 使用 `MethodFilter` |
| `addons/bricks/editor/instruction_generator/conflict_handler.gd` | 冲突处理器 | 独立 |
| `addons/bricks/editor/instruction_generator/instruction_generator.gd` | 指令生成器 | 使用 `TypeMapper` |

### 修改文件

| 文件路径 | 修改内容 |
|---------|----------|
| `addons/bricks/editor/context_menu/bricks_context_menu_plugin.gd` | 添加"生成指令"菜单项 |
| `addons/bricks/plugin.gd` | 添加扫描 `res://bricks_generated/instructions/` 目录 |
| `addons/bricks/localization/translations.csv` | 添加对话框 UI 本地化键 |

### 已有文件（只读引用，不修改）

| 文件路径 | 提供的功能 | 被谁复用 |
|---------|----------|----------|
| `addons/bricks/utils/function_manager.gd` | 方法过滤、继承链、方法检测 | `MethodFilter` |
| `addons/bricks/utils/type_converter.gd` | 类型名映射、兼容性检查 | `TypeMapper`（Phase 1） |
| `addons/bricks/utils/property_manager.gd` | 属性过滤、搜索 | `PropertyInstructionGenerator`（Phase 2） |
| `addons/bricks/utils/property_info.gd` | 属性元数据模型 | `PropertyInstructionGenerator`（Phase 2） |

---

## 风险与注意事项

1. **Godot 版本兼容性** - ClassDB API 在不同版本可能有差异
2. **文件系统权限** - 使用 `ProjectSettings.globalize_path()` 转换路径，确保跨平台兼容
3. **热重载** - 生成的指令需要编辑器扫描后才能使用
4. **类型安全** - 复杂类型使用 Variant，运行时需要验证
5. ~~**class_name 冲突**~~ - **已规避：** 生成的指令不使用 `class_name`，通过文件路径注册
6. ~~**搜索性能**~~ - **已规避：** 200ms 防抖，避免继承层级深时频繁重建方法树
7. ~~**Window 弹出时序**~~ - **已修复：** 使用 `is_inside_tree()` + `call_deferred` 处理 `tree_entered` 先于 `_ready()` 的时序问题
8. **Godot 4.6 兼容性** - `PROPERTY_USAGE_SCRIPT_VARIABLE` 从 256 变为 4096，旧版子分组标题（如 "Thread Group"）的 `usage=256` 不能再用此常量过滤。详见改进 #12。

## Godot 4.6 兼容性注意事项

| 常量 | Godot 4.3 值 | Godot 4.6 值 | 影响 |
|------|-------------|-------------|------|
| `PROPERTY_USAGE_SCRIPT_VARIABLE` | 256 | 4096 | 旧版子分组标题（usage=256）不能用常量比较过滤 |
| 旧版子分组标题 usage | N/A | 256 | "Thread Group" 等，需用 `== 256` 硬编码过滤 |

## 已知限制（低优先级，可在后续版本改进）

## 实现过程中的改进（超出计划）

> 以下是实际实现中对原计划的改进和修复。

1. **[FIX] `class_name` 保留字冲突** - `class_name` 是 GDScript 保留字，不能用作参数名或变量名。所有生成器文件中已将 `class_name` 参数改为 `p_class_name`/`cls_name`。（影响 `conflict_handler.gd`、`method_selector_dialog.gd`）
2. **[FIX] `_to_snake_case` 无效 API** - 计划中使用的 `is_valid_ascii_identifier_character()` 在 Godot 4.6 中不存在，改为手动字符范围比较。（影响 `conflict_handler.gd`）
3. **[IMPROVE] 移除 `call_` 文件名前缀** - 文件名从 `call_animatedsprite2d_play.gd` 简化为 `animated_sprite2d_play.gd`。（影响 `conflict_handler.gd`）
4. **[IMPROVE] 三重作用域返回值存储** - 有返回值的方法现在支持 `BaseVariable.VariableScope`（LOCAL/SCOPE/GLOBAL），SCOPE 模式支持 `ScopeSource`（NEAREST/CUSTOM_ID/TRIGGER_SCOPE/TARGET_NODE）。使用 `VariableOperations` 和 `VariableScopeUtils` API。（影响 `instruction_generator.gd`）
5. **[IMPROVE] 条件属性显隐** - 添加 `_validate_property()` + setter 中调用 `notify_property_list_changed()`，使 scope 相关属性只在对应作用域下显示。（影响 `instruction_generator.gd`）
6. **[FIX] `reverse()` 返回 void** - `chain.reverse()` 不返回值（Godot 4 中 in-place），改为先 reverse 再遍历。（影响 `method_filter.gd`）
7. **[FIX] `get_description` 使用未定义变量** - 原计划生成 `target_class`、`method_name` 变量引用，改为编译时字符串拼接。（影响 `instruction_generator.gd`）
8. **[FEATURE] 变量绑定版本生成** - MethodSelectorDialog 添加"使用变量"复选框，勾选后生成带变量绑定的指令版本。每个参数支持 `VALUE`（直接值）或 `VARIABLE`（从变量读取）两种模式，VARIABLE 模式支持 `LOCAL/SCOPE/GLOBAL` 三重作用域，SCOPE 模式支持 `NEAREST/CUSTOM_ID/TRIGGER_SCOPE/TARGET_NODE` 四种来源。参考 `math_operation.gd` 的 `operand_a_*` 模式实现。（影响 `instruction_generator.gd`、`method_selector_dialog.gd`、`type_mapper.gd`、`conflict_handler.gd`、`bricks_context_menu_plugin.gd`）
9. **[FIX] 变量绑定版本属性不可见** - 生成的变量绑定属性没有 `@export` 也没有 `_get_property_list()`，在检查器中不显示。新增 `_generate_get_property_list_method` 动态生成 `_get_property_list()` 方法，按参数分类显示，根据 `source`/`scope` 状态条件性暴露属性，与 `math_operation.gd` 模式一致。（影响 `instruction_generator.gd`）
10. **[FIX] `%s` 格式化参数数量不匹配** - `_generate_param_read_code` 中 `_val` 赋值行有 4 个 `%s` 占位符但数组只传了 3 个元素，导致最后一个 `%s_val` 未被替换、生成无效代码。（影响 `instruction_generator.gd`）
11. **[FIX] 变量绑定版本注册名冲突** - 变量绑定版本和普通版本生成的 `metadata.name` 相同（如 "调用 AnimatedSprite2D.play"），导致注册时互相覆盖。变量版本现在追加 ` (变量)` 后缀区分。（影响 `instruction_generator.gd`）
12. **[FIX] Godot 4.6 属性过滤 — 旧版子分组标题泄漏** - `PROPERTY_USAGE_SCRIPT_VARIABLE` 在 Godot 4.6 中从 256 变为 4096，导致旧版子分组标题（如 "Thread Group"，`usage=256`）无法被常量过滤。使用 `prop_usage == 256` 硬编码精确匹配过滤。（影响 `method_selector_dialog.gd`）
13. **[FIX] 属性列表 [Unknown] 类型名** - `PropertyInfo.get_type_name()` 依赖 `TypeConverter._type_names`（仅覆盖 18 种基础类型），Transform2D、Rect2、Basis 等类型显示为 [Unknown]。新增 OBJECT 类型优先显示 `class_type`，非 OBJECT 类型使用 GDScript 内置 `type_string()` 函数兜底。（影响 `property_info.gd`）
14. **[FIX] GET 指令 target_node 重复显示** - 生成的 GET 指令同时使用 `@export var target_node` 和 `_get_property_list()` 声明 target_node，导致检查器中显示两次。改为仅用 `var target_node`（无 `@export`），由 `_get_property_list()` 统一管理。（影响 `property_instruction_generator.gd`）

### 未处理限制（低优先级）

> 以下问题不影响最小功能集的正确性，但应在后续迭代中处理。

15. **[LOW] preload 链式依赖风险** - `bricks_context_menu_plugin.gd` 中对 `MethodSelectorDialog`、`InstructionGenerator`、`InstructionRegistry` 使用 `preload`，任一文件缺失会导致整个右键菜单插件无法加载。后续可改为延迟 `load` + 缓存模式以提高容错性。
16. **[LOW] 参数名冲突** - `param_to_property` 未处理方法参数名与 GDScript 保留字（如 `class`、`signal`）或 BaseInstruction 已有属性（如 `target_node`）的冲突。后续可添加前缀或冲突检测。
17. **[LOW] 元数据 name 格式** - 生成的 `metadata.name` 为 `"调用 Sprite2D.set_texture"` 格式，同类多个方法的 name 前缀完全相同。后续可将类名移至 `category`（如 `"生成指令/Sprite2D"`），`name` 使用简短格式如 `"调用 set_texture"`。变量绑定版本已通过 `(变量)` 后缀区分，但普通版本仍有此问题。
18. **[LOW] 线程安全** - 生成的 `execute` 方法直接调用 `node.method()`，未考虑多线程场景（Bricks 支持异步指令）。同步方法调用在主线程通常安全，但涉及 tween/await 的方法需要额外处理。

---

## Phase 6: 属性访问指令生成（GET / SET） ✅ COMPLETE

> 为 Bricks 指令生成器添加属性访问功能，支持生成 GET（读取属性值存入变量）和 SET（设置属性值）两种专用指令。

### 设计目标

1. **GET 指令** — 读取目标节点的指定属性值 → 存入支持三重作用域（LOCAL/SCOPE/GLOBAL）的变量
2. **SET 指令** — 直接赋值 **或** 从三重作用域变量中读取值 → 设置目标节点的指定属性
3. **变量绑定版本** — SET 指令复用 Phase 5 的变量绑定模式（`_source`/`_value`/`_variable`/`_scope` + `_get_property_list`）
4. **质量标准** — 与 Phase 1-5 保持一致：无 `class_name`、无本地化、无日志、通过文件路径注册

### 与现有指令的关系

| 现有指令 | 生成的指令 | 差异 |
|----------|-----------|------|
| `SetPropertyValue` | 生成 SET | 现有：通用（动态属性名下拉框、运行时类型检查）。生成：**专用**（固定属性名、编译时类型安全、无 `_update_target_node_info` 等编辑器复杂度） |
| `GetPosition` | 生成 GET | 现有：仅 position/global_position。生成：**通用属性**（任意可读属性） |
| 无 | 生成 GET | **填补空白** — 当前系统无通用的"读取任意属性"指令 |

**共存策略**：生成指令和通用指令并存。生成指令在指令选择器的"用户生成"分类下，通用指令在原分类下。

### 复用的现有代码

| 现有类 | 文件路径 | 复用功能 |
|--------|---------|----------|
| `PropertyManager` | `addons/bricks/utils/property_manager.gd` | `get_writable_properties()` 过滤可写属性、`find_property()` 获取属性信息 |
| `PropertyInfo` | `addons/bricks/utils/property_info.gd` | 属性元数据（type/hint/hint_string/default_value） |
| `TypeMapper` | `instruction_generator/type_mapper.gd` | `param_to_variable_properties()` 变量绑定属性声明、`get_type_declaration()` / `get_default_value()` |
| `InstructionGenerator` | `instruction_generator/instruction_generator.gd` | `_generate_get_property_list_method()` 动态属性列表、`_generate_param_read_code()` 变量读取代码、`_generate_validate_property_method()` 作用域显隐 |

### 核心改动

#### 1. MethodSelectorDialog 扩展

添加"方法"和"属性"两个 Tab：

```
[方法] [属性]
┌─────────────────────────────────────┐
│  搜索: [______________]             │
│  ┌──────────────┬──────────────────┐│
│  │ 属性列表      │  属性信息        ││
│  │ ▸ visible     │  类型: bool      ││
│  │ ▸ position    │  提示: -         ││
│  │ ▸ scale       │  默认值: true    ││
│  │ ▸ modulate    │  可写: ✓        ││
│  │ ...           │                  ││
│  └──────────────┴──────────────────┘│
│  [✓] 使用变量                        │
│  生成: (●) SET  (○) GET  (○) 两者   │
│              [取消]  [生成]          │
└─────────────────────────────────────┘
```

**新增 UI 元素：**
- `TabBar` — "方法" / "属性" 两个 Tab
- 属性列表 Tree — 调用 `PropertyManager.get_writable_properties()` 获取可写属性，按类型分组
- 属性信息 RichTextLabel — 显示选中属性的 type、hint、default_value 等
- 生成模式 RadioGroup — `SET` / `GET` / `两者都生成`

**"使用变量"复选框的行为变化：**
- SET 模式：勾选后生成变量绑定版本（每个属性值的 `value_source`/`value_variable`/`value_scope`）
- GET 模式：**始终启用**（GET 的目的就是把值存入变量），复选框控制是否启用 SCOPE 作用域的 ScopeSource 配置

**信号变更：**
```gdscript
# 旧
signal method_selected(method_info: Dictionary, target_class: String, use_variables: bool)

# 新
signal method_selected(method_info: Dictionary, target_class: String, use_variables: bool)
signal property_selected(property_info: PropertyInfo, target_class: String, mode: int, use_variables: bool)
# mode: 0=SET, 1=GET, 2=SET_AND_GET
```

#### 2. BricksContextMenuPlugin 扩展

```gdscript
# _on_property_selected 回调
func _on_property_selected(property_info: PropertyInfo, target_class: String, mode: int, use_variables: bool, node: Node) -> void:
    var prop_dict = _property_info_to_dict(property_info)
    if mode == SET or mode == SET_AND_GET:
        var result = PropertyInstructionGenerator.generate_set_instruction(target_class, prop_dict, "", use_variables)
        _handle_generation_result(result)
    if mode == GET or mode == SET_AND_GET:
        var result = PropertyInstructionGenerator.generate_get_instruction(target_class, prop_dict)
        _handle_generation_result(result)
```

#### 3. PropertyInstructionGenerator（新建）

位置：`addons/bricks/editor/instruction_generator/property_instruction_generator.gd`

**SET 指令生成 — `generate_set_instruction()`**

**普通版本（直接赋值）：**

```gdscript
# 生成示例：Sprite2D.visible → set_sprite2d_visible.gd
@tool
@icon("res://addons/bricks/icons/instruction.svg")
extends BaseInstruction

## 设置 AnimatedSprite2D.speed_scale
## 自动生成 - 请勿手动修改

## 目标节点路径
@export var target_node: NodePath = NodePath("")

## 属性值
@export var speed_scale_value: float = 1.0

static func _get_instruction_metadata() -> InstructionMetadata:
    var md = InstructionMetadata.new()
    md.name = "设置 AnimatedSprite2D.speed_scale"
    md.category = "用户生成"
    md.description = "设置 AnimatedSprite2D 节点的 speed_scale 属性"
    md.keywords = ["animatedsprite2d", "speed_scale", "set"]
    return md

func _setup_metadata():
    pass

func _update_resource_name():
    resource_name = "SetAnimatedSprite2DSpeedScale"

func execute(context: ExecutionContext):
    _start_execution(context)
    # ... 节点获取、类型检查（与 Phase 1-5 相同）
    node.speed_scale = speed_scale_value
    _on_execution_completed()
```

**变量绑定版本（复用 Phase 5 模式）：**

```gdscript
# 生成示例：Sprite2D.visible (变量) → set_sprite2d_visible_with_variable.gd
@tool
@icon("res://addons/bricks/icons/instruction.svg")
extends BaseInstruction

## 设置 AnimatedSprite2D.speed_scale
## 变量绑定版本 - 属性值支持直接值或变量读取
## 自动生成 - 请勿手动修改

## 目标节点路径
@export var target_node: NodePath = NodePath("")

## speed_scale 来源（VALUE=直接值 / VARIABLE=从变量读取）
enum SpeedScaleSource { VALUE, VARIABLE }
var speed_scale_source: SpeedScaleSource = SpeedScaleSource.VALUE:
    set(v):
        speed_scale_source = v
        notify_property_list_changed()

## speed_scale 直接值
var speed_scale_value: float = 1.0

## speed_scale 变量名
var speed_scale_variable: String = ""
## speed_scale 变量作用域
var speed_scale_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(v):
        speed_scale_scope = v
        notify_property_list_changed()
## speed_scale 作用域来源
var speed_scale_scope_source: VariableScopeUtils.ScopeSource = VariableScopeUtils.ScopeSource.NEAREST:
    set(v):
        speed_scale_scope_source = v
        notify_property_list_changed()
var speed_scale_custom_scope_id: String = ""
var speed_scale_target_node_path: NodePath = NodePath("")

func _get_property_list() -> Array[Dictionary]:
    # 复用 InstructionGenerator._generate_get_property_list_method 的模式
    # 但只有一个"属性值"分类（不是参数列表）
    ...

func execute(context: ExecutionContext):
    _start_execution(context)
    # ... 节点获取、类型检查
    # 从变量读取值（复用 _generate_param_read_code 的逻辑）
    var speed_scale_val: float = speed_scale_value
    if speed_scale_source == SpeedScaleSource.VARIABLE and not speed_scale_variable.is_empty():
        # ... 三重作用域读取（与 Phase 5 相同）
    node.speed_scale = speed_scale_val
    _on_execution_completed()
```

**metadata.name 区分：**
- 普通版本：`"设置 AnimatedSprite2D.speed_scale"`
- 变量版本：`"设置 AnimatedSprite2D.speed_scale (变量)"`

---

**GET 指令生成 — `generate_get_instruction()`**

**核心逻辑：** 读取 `node.property` → 存入 `save_to_variable`（支持三重作用域）

```gdscript
# 生成示例：Sprite2D.position → get_sprite2d_position.gd
@tool
@icon("res://addons/bricks/icons/instruction.svg")
extends BaseInstruction

## 获取 AnimatedSprite2D.speed_scale
## 自动生成 - 请勿手动修改

## 目标节点路径
@export var target_node: NodePath = NodePath("")

## 保存到的变量名
@export var save_to_variable: String = ""

## 保存到的变量作用域
var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(v):
        save_to_scope = v
        notify_property_list_changed()

## 作用域来源（仅 SCOPE 作用域时生效）
var scope_source: ScopeSource = ScopeSource.NEAREST:
    set(v):
        scope_source = v
        notify_property_list_changed()

## 自定义作用域 ID
var custom_scope_id: String = ""
## 目标节点路径（TARGET_NODE 模式使用）
var save_target_node_path: NodePath = NodePath("")

enum ScopeSource { NEAREST, CUSTOM_ID, TRIGGER_SCOPE, TARGET_NODE }

func _get_property_list() -> Array[Dictionary]:
    var properties: Array[Dictionary] = []
    # Target 分类
    properties.append({name = "Target", type = TYPE_NIL, ...})
    properties.append({name = "target_node", type = TYPE_NODE_PATH, ...})
    # Save To 分类
    properties.append({name = "Save To", type = TYPE_NIL, ...})
    properties.append({name = "save_to_variable", type = TYPE_STRING, ...})
    properties.append({name = "save_to_scope", type = TYPE_INT, hint = PROPERTY_HINT_ENUM, hint_string = "Local,Scope,Global", ...})
    if save_to_scope == BaseVariable.VariableScope.SCOPE:
        properties.append({name = "scope_source", ...})
        # ScopeSource 条件属性...
    return properties

func execute(context: ExecutionContext):
    _start_execution(context)
    # ... 节点获取、类型检查
    var value = node.speed_scale  # 读取属性
    # 存入变量（参考 GetPosition 的三重作用域存储逻辑）
    if save_to_variable.is_empty():
        set_error("保存变量名为空")
        finished.emit()
        return
    match save_to_scope:
        BaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:
            VariableOperations.set_variable(context, save_to_variable, save_to_scope, value)
        BaseVariable.VariableScope.SCOPE:
            if scope_source == ScopeSource.NEAREST:
                VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, value)
            else:
                var scope_container = VariableScopeUtils.get_scope_container_by_source(context, scope_source as VariableScopeUtils.ScopeSource, custom_scope_id, save_target_node_path)
                if scope_container == null:
                    set_error("找不到作用域容器")
                    finished.emit()
                    return
                scope_container.set_variable(save_to_variable, value)
    _on_execution_completed()
```

**GET 指令不需要变量绑定版本** — GET 的目的就是存入变量，三重作用域通过 `save_to_scope` + `ScopeSource` 已经完全覆盖。

#### 4. ConflictHandler 扩展

```gdscript
# 新增属性指令文件名生成
# SET: {class}_{property}.gd / {class}_{property}_with_variable.gd
# GET: get_{class}_{property}.gd
static func generate_property_file_name(class_name: String, property_name: String, mode: String, use_variables: bool) -> String:
    var safe_class = _to_snake_case(class_name)
    var safe_prop = _to_snake_case(property_name)
    match mode:
        "set":
            if use_variables:
                return "%s_%s_with_variable.gd" % [safe_class, safe_prop]
            return "%s_%s.gd" % [safe_class, safe_prop]
        "get":
            return "get_%s_%s.gd" % [safe_class, safe_prop]
    return ""
```

#### 5. 文件结构

```
addons/bricks/editor/instruction_generator/
├── instruction_generator.gd          # 修改：提取公共方法供 PropertyInstructionGenerator 复用
├── property_instruction_generator.gd # 新建：属性指令生成器
├── method_selector_dialog.gd         # 修改：添加 Tab + 属性列表 + 生成模式选择
├── conflict_handler.gd               # 修改：添加属性文件名生成
├── type_mapper.gd                    # 不变
└── method_filter.gd                  # 不变

bricks_generated/instructions/
└── animatedsprite2d/
    ├── set_animatedsprite2d_speed_scale.gd          # SET 普通
    ├── set_animatedsprite2d_speed_scale_with_variable.gd  # SET 变量
    └── get_animatedsprite2d_speed_scale.gd          # GET
```

### 实现步骤

#### Step 6.1: ConflictHandler 扩展

添加 `generate_property_file_name()` 和 `check_property_conflict()`。

#### Step 6.2: PropertyInstructionGenerator — SET 普通版本

- `generate_set_instruction(target_class, property_dict, output_dir, use_variables)`
- `use_variables=false`：生成 `@export var {prop}_value: {type}` + `node.{prop} = {prop}_value`
- `use_variables=true`：复用 `TypeMapper.param_to_variable_properties()` + `InstructionGenerator._generate_get_property_list_method()` + `_generate_param_read_code()`
- 元数据 name 使用 `(变量)` 后缀区分

#### Step 6.3: PropertyInstructionGenerator — GET 版本

- `generate_get_instruction(target_class, property_dict, output_dir)`
- 固定 `save_to_variable` + `save_to_scope` + `ScopeSource` 模式（参考 `GetPosition`）
- `_get_property_list()` 动态控制 ScopeSource 属性显隐
- execute 中读取 `node.{prop}` 并通过三重作用域存入变量

#### Step 6.4: MethodSelectorDialog Tab 扩展

- 添加 `TabBar`（"方法" / "属性"）
- 属性 Tab：`PropertyManager.get_writable_properties()` 填充 Tree
- 属性选中后显示 `PropertyInfo` 详情
- 底部新增"生成模式" RadioGroup（SET / GET / 两者）
- 新增 `property_selected` 信号

#### Step 6.5: BricksContextMenuPlugin 集成

- 连接 `property_selected` 信号
- 调用 `PropertyInstructionGenerator` 生成指令
- 注册并刷新编辑器

#### Step 6.6: InstructionGenerator 公共方法提取

将以下方法改为 `static` 并公开（如果还不是的话），供 `PropertyInstructionGenerator` 复用：
- `_generate_get_property_list_method(args)` → 保持 static，PropertyInstructionGenerator 直接调用
- `_generate_param_read_code(arg)` → 保持 static
- `_generate_validate_property_method(args, return_type, use_variables)` → 保持 static

> 注意：当前这些方法已是 static，PropertyInstructionGenerator 可以直接通过 `InstructionGenerator.method_name()` 调用，无需额外改动。

### 预估工时

| 步骤 | 内容 | 预估 |
|------|------|------|
| 6.1 | ConflictHandler 扩展 | 0.5h |
| 6.2 | SET 普通版本生成 | 1h |
| 6.3 | GET 版本生成 | 1h |
| 6.4 | MethodSelectorDialog Tab 扩展 | 2h |
| 6.5 | BricksContextMenuPlugin 集成 | 0.5h |
| 6.6 | 公共方法提取确认 | 0.5h |
| — | 测试与调试 | 1h |
| **总计** | | **6.5h** |

---

## Phase 7（后续）: 类浏览器入口

> 不依赖场景中的节点，通过 Godot 类面板直接选择目标类来生成指令

### 用户流程

```
Bricks 工具栏 "从类生成" 按钮
    ↓
CreateDialog（Godot 内置新建节点对话框，复用其类搜索/浏览功能）
    ↓  用户选择类（如 Sprite2D、RigidBody2D）
    ↓
MethodSelectorDialog（使用类名，不需要 Node 实例）
    ↓
生成指令
```

### 核心改动

**MethodSelectorDialog 添加 `set_target_class` 重载：**

当前 `set_target_node(node)` 需要节点实例来获取类名。新增重载直接接受类名字符串：

```gdscript
## 设置目标节点
func set_target_node(node: Node) -> void:
    _target_node = node
    _target_class = node.get_class()
    _populate_from_class(_target_class)

## 设置目标类（无需节点实例）
func set_target_class(class_name: String) -> void:
    _target_node = null
    _target_class = class_name
    _populate_from_class(class_name)

## 共用的数据加载逻辑
func _populate_from_class(class_name: String) -> void:
    var all_methods = MethodFilter.get_class_methods_with_inheritance(class_name)
    _methods_by_class = MethodFilter.filter_methods(all_methods)
    _populate_method_tree("")
```

**标题栏适配：**

```gdscript
func _get_header_text() -> String:
    if _target_node:
        return "为 %s (%s) 生成指令" % [_target_node.name, _target_class]
    return "为 %s 类生成指令" % _target_class
```

### 新增入口点

在 Bricks 编辑器面板（或 Godot 顶部菜单）添加"从类生成指令"按钮：

```gdscript
# 弹出 Godot 内置 CreateDialog
func _on_generate_from_class() -> void:
    var dialog := CreateDialog.new()
    dialog.confirmed.connect(_on_class_selected)
    _editor_plugin.get_editor_interface().get_base_control().add_child(dialog)
    dialog.popup_centered()

func _on_class_selected() -> void:
    var selected_class = dialog.selected_type
    # 复用 MethodSelectorDialog
    var selector := MethodSelectorDialog.new()
    selector.set_target_class(selected_class)
    selector.method_selected.connect(_on_method_selected.bind(null))
    # ...
```

### 复用关系

| 现有组件 | 复用方式 |
|---------|----------|
| `CreateDialog` | Godot 内置，直接 `new()` 使用，自带类搜索和分类树 |
| `MethodFilter` | 无需改动，已支持基于类名字符串 |
| `InstructionGenerator` | 无需改动，接收 `target_class` 字符串 |
| `MethodSelectorDialog` | 新增 `set_target_class` 重载 |

### 文件变更

| 文件 | 修改内容 |
|------|----------|
| `method_selector_dialog.gd` | 新增 `set_target_class()` 重载，提取 `_populate_from_class()` |
| `bricks_context_menu_plugin.gd` 或新文件 | 新增"从类生成"按钮，弹出 `CreateDialog` |

### 预估工时

- `MethodSelectorDialog.set_target_class` 重载：**0.5h**
- 新增入口按钮 + CreateDialog 集成：**1h**
- **总计：1.5h**

---

**实现完成后，使用 `/gdscript-validate` 验证生成的 GDScript 文件。**
