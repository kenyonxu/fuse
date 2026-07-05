# MultiEventTrigger 拆分功能实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现 MultiEventTrigger 拆分为独立 Trigger 节点的功能，作为 TriggerMerger 的逆操作。

**Architecture:** 创建 `TriggerSplitter` 工具类，从 `EventBinding` 数组重建独立 `Trigger` 节点，支持 UndoRedo 操作。复用 TriggerMerger 的备份/恢复逻辑。

**Tech Stack:** GDScript 2.0, Godot 4.6 EditorUndoRedoManager

---

## Task 1: 创建 TriggerSplitter 工具类

**Files:**
- Create: `addons/bricks/editor/context_menu/trigger_splitter.gd`
- Reference: `addons/bricks/editor/context_menu/trigger_merger.gd`

**Step 1: 创建文件骨架和静态检查方法**

```gdscript
# 文件：addons/bricks/editor/context_menu/trigger_splitter.gd
@tool
class_name TriggerSplitter extends RefCounted

## TriggerSplitter - MultiEventTrigger 拆分工具类
##
## 用于将 MultiEventTrigger 节点拆分为多个独立的 Trigger 节点。
## 支持 UndoRedo 操作，确保用户可以撤销拆分。

## ==================== 常量 ====================

const TriggerClass = preload("res://addons/bricks/core/trigger.gd")
const MultiEventTriggerClass = preload("res://addons/bricks/core/multi_event_trigger.gd")
const EventBindingClass = preload("res://addons/bricks/core/event_binding.gd")
const BricksLocalizationClass = preload("res://addons/bricks/localization/bricks_localization.gd")

## ==================== 成员变量 ====================

var _editor_interface: EditorInterface
var _undo_redo: EditorUndoRedoManager

## ==================== 初始化 ====================

func _init(editor_interface: EditorInterface, undo_redo: EditorUndoRedoManager) -> void:
	_editor_interface = editor_interface
	_undo_redo = undo_redo

## ==================== 静态检查方法 ====================

## 检查是否可以拆分指定的节点
## @param node 要检查的节点
## @return 是否可以拆分
static func can_split(node: Node) -> bool:
	# 必须是 MultiEventTrigger 类型
	if not node is MultiEventTrigger:
		return false

	# 必须有至少 2 个 EventBinding
	var multi_trigger: MultiEventTrigger = node as MultiEventTrigger
	if multi_trigger.event_bindings.size() < 2:
		return false

	return true
```

**Step 2: 添加拆分主方法**

在 `trigger_splitter.gd` 中添加 `split` 方法：

```gdscript
## ==================== 拆分操作 ====================

## 执行拆分操作
## @param node 要拆分的 MultiEventTrigger 节点
func split(node: Node) -> void:
	# 预检查
	if not can_split(node):
		push_error("TriggerSplitter: 无法拆分节点，检查失败")
		return

	var multi_trigger: MultiEventTrigger = node as MultiEventTrigger

	# 获取父节点和索引
	var parent: Node = multi_trigger.get_parent()
	if parent == null:
		push_error("TriggerSplitter: MultiEventTrigger 没有父节点")
		return

	var trigger_index: int = multi_trigger.get_index()

	# 创建备份数据（用于 Undo）
	var backup: Dictionary = _create_backup(multi_trigger)

	# 创建 Trigger 节点数组
	var triggers: Array[Node] = []
	for binding: EventBinding in multi_trigger.event_bindings:
		var trigger: Trigger = _create_trigger_from_binding(binding)
		triggers.append(trigger)

	# 添加 UndoRedo 操作
	_undo_redo.create_action("拆分 MultiEventTrigger")

	# Do 操作
	_undo_redo.add_do_method(self, "_do_split", parent, triggers, multi_trigger, trigger_index)

	# Undo 操作
	_undo_redo.add_undo_method(self, "_undo_split", parent, triggers, backup, trigger_index)

	# 提交操作
	_undo_redo.commit_action()

	# 选中所有新创建的 Trigger
	_select_nodes(triggers)

	print("[TriggerSplitter] %s" % BricksLocalizationClass.translate("BRICKS_SPLIT_COMPLETED"))
```

**Step 3: 添加辅助方法**

```gdscript
## ==================== 私有辅助方法 ====================

## 从 EventBinding 创建 Trigger
## @param binding 源 EventBinding
## @return 创建的 Trigger
func _create_trigger_from_binding(binding: EventBinding) -> Trigger:
	var trigger := TriggerClass.new()

	# 深拷贝事件定义
	if binding.event != null:
		trigger.event_definition = binding.event.duplicate(true)

	# 深拷贝 ActionRunner
	if binding.action_runner != null:
		trigger.action_runner = binding.action_runner.duplicate(true)

	# 复制其他属性
	trigger.trigger_once = binding.trigger_once
	trigger.cooldown_mode = binding.cooldown_mode
	trigger.cooldown_time = binding.cooldown_time
	trigger.enabled = true

	return trigger

## 创建备份数据（用于 Undo）
## @param multi_trigger MultiEventTrigger 节点
## @return 备份数据字典
func _create_backup(multi_trigger: MultiEventTrigger) -> Dictionary:
	# 深拷贝所有 EventBinding
	var bindings_copy: Array[EventBinding] = []
	for binding: EventBinding in multi_trigger.event_bindings:
		var copy := EventBindingClass.new()
		if binding.event != null:
			copy.event = binding.event.duplicate(true)
		if binding.action_runner != null:
			copy.action_runner = binding.action_runner.duplicate(true)
		copy.trigger_once = binding.trigger_once
		copy.cooldown_mode = binding.cooldown_mode
		copy.cooldown_time = binding.cooldown_time
		copy.enabled = binding.enabled
		bindings_copy.append(copy)

	return {
		"name": multi_trigger.name,
		"index": multi_trigger.get_index(),
		"event_bindings": bindings_copy
	}

## 获取事件名称（用于 Trigger 命名）
## @param event 事件对象
## @return 事件类名（不含后缀）
func _get_event_name(event: Resource) -> String:
	if event == null:
		return "Trigger"
	var event_name: String = event.get_script().get_global_name()
	if event_name.is_empty():
		event_name = event.get_script().resource_path.get_file().get_basename()
	return event_name

## 生成唯一的 Trigger 名称
## @param base_name 基础名称（事件名）
## @param existing_names 已存在的名称集合
## @return 唯一名称
func _generate_unique_name(base_name: String, existing_names: Dictionary) -> String:
	if not existing_names.has(base_name):
		existing_names[base_name] = true
		return base_name

	var counter: int = 1
	while existing_names.has("%s_%d" % [base_name, counter]):
		counter += 1

	var unique_name: String = "%s_%d" % [base_name, counter]
	existing_names[unique_name] = true
	return unique_name

## Do 操作：执行拆分
func _do_split(parent: Node, triggers: Array[Node], multi_trigger: MultiEventTrigger, start_index: int) -> void:
	# 删除 MultiEventTrigger
	if is_instance_valid(multi_trigger):
		multi_trigger.get_parent().remove_child(multi_trigger)
		multi_trigger.queue_free()

	# 添加所有 Trigger 到父节点，使用事件名命名
	var used_names: Dictionary = {}
	for i in range(triggers.size()):
		var trigger: Trigger = triggers[i]
		# 使用事件名称命名
		var base_name: String = _get_event_name(trigger.event_definition)
		trigger.name = _generate_unique_name(base_name, used_names)
		parent.add_child(trigger)
		trigger.owner = parent.owner
		parent.move_child(trigger, start_index + i)

## Undo 操作：撤销拆分
func _undo_split(parent: Node, triggers: Array[Node], backup: Dictionary, start_index: int) -> void:
	# 删除所有 Trigger
	for trigger: Node in triggers:
		if is_instance_valid(trigger):
			trigger.get_parent().remove_child(trigger)
			trigger.queue_free()

	# 重建 MultiEventTrigger
	var multi_trigger := MultiEventTriggerClass.new()
	multi_trigger.name = backup.name

	# 恢复 EventBindings
	var bindings: Array[EventBinding] = []
	for binding: EventBinding in backup.event_bindings:
		bindings.append(binding)
	multi_trigger.event_bindings = bindings

	# 添加回父节点
	parent.add_child(multi_trigger)
	multi_trigger.owner = parent.owner
	parent.move_child(multi_trigger, start_index)

## 选中多个节点
## @param nodes 要选中的节点数组
func _select_nodes(nodes: Array[Node]) -> void:
	if _editor_interface == null:
		return

	var selection: EditorSelection = _editor_interface.get_selection()
	if selection == null:
		return

	selection.clear()
	for node: Node in nodes:
		if is_instance_valid(node):
			selection.add_node(node)
```

**Step 4: 保存文件**

保存完整的 `trigger_splitter.gd` 文件。

**Step 5: Commit**

```bash
git add addons/bricks/editor/context_menu/trigger_splitter.gd
git commit -m "feat(bricks): add TriggerSplitter utility class"
```

---

## Task 2: 更新上下文菜单插件

**Files:**
- Modify: `addons/bricks/editor/context_menu/bricks_context_menu_plugin.gd`

**Step 1: 添加 TriggerSplitter 引用**

在文件顶部的常量区域添加：

```gdscript
## 预加载模块
const TriggerMergerClass = preload("./trigger_merger.gd")
const TriggerSplitterClass = preload("./trigger_splitter.gd")  # 新增
```

在成员变量区域添加：

```gdscript
## TriggerMerger 实例
var _trigger_merger: TriggerMerger = null

## TriggerSplitter 实例  # 新增
var _trigger_splitter: TriggerSplitter = null
```

**Step 2: 在 set_editor_plugin 中初始化 Splitter**

修改 `set_editor_plugin` 方法：

```gdscript
func set_editor_plugin(plugin: EditorPlugin) -> void:
	_editor_plugin = plugin
	if plugin != null:
		_trigger_merger = TriggerMergerClass.new(
			plugin.get_editor_interface(),
			plugin.get_undo_redo()
		)
		# 新增：初始化 TriggerSplitter
		_trigger_splitter = TriggerSplitterClass.new(
			plugin.get_editor_interface(),
			plugin.get_undo_redo()
		)
```

**Step 3: 在 _popup_menu 中添加拆分菜单项**

修改 `_popup_menu` 方法，在现有代码后添加拆分检查：

```gdscript
func _popup_menu(paths: PackedStringArray) -> void:
	if _editor_plugin == null:
		return

	var edited_scene_root := _editor_plugin.get_editor_interface().get_edited_scene_root()
	if edited_scene_root == null:
		return

	# 从路径获取实际的节点
	var nodes: Array[Node] = []
	for path in paths:
		if path.is_empty():
			continue
		var node := edited_scene_root.get_node_or_null(path)
		if node != null:
			nodes.append(node)

	# 检查是否可以合并选中的节点
	if TriggerMergerClass.can_merge(nodes):
		_pending_paths = paths
		add_context_menu_item("合并为多事件触发器", Callable(self, "_on_merge_triggers"))

	# 新增：检查是否可以拆分选中的 MultiEventTrigger
	if nodes.size() == 1 and TriggerSplitterClass.can_split(nodes[0]):
		_pending_paths = paths
		add_context_menu_item("拆分为独立触发器", Callable(self, "_on_split_trigger"))
```

**Step 4: 添加拆分回调方法**

在信号处理区域添加：

```gdscript
## 拆分触发器回调
## @param _paths 选中的节点路径数组
func _on_split_trigger(_paths: PackedStringArray) -> void:
	if _editor_plugin == null or _trigger_splitter == null:
		push_error("[BricksContextMenuPlugin] _editor_plugin or _trigger_splitter is null!")
		return

	var edited_scene_root := _editor_plugin.get_editor_interface().get_edited_scene_root()
	if edited_scene_root == null:
		push_error("[BricksContextMenuPlugin] edited_scene_root is null!")
		return

	var node := edited_scene_root.get_node_or_null(_pending_paths[0])
	if node == null:
		push_error("[BricksContextMenuPlugin] Node not found: ", _pending_paths[0])
		return

	# 执行拆分
	_trigger_splitter.split(node)
```

**Step 5: Commit**

```bash
git add addons/bricks/editor/context_menu/bricks_context_menu_plugin.gd
git commit -m "feat(bricks): add split option to context menu for MultiEventTrigger"
```

---

## Task 3: 添加本地化字符串

**Files:**
- Modify: `addons/bricks/localization/bricks_localization.csv`

**Step 1: 添加新的翻译键**

在 CSV 文件末尾添加：

```csv
BRICKS_SPLIT_COMPLETED,拆分完成,Split completed
```

**Step 2: Commit**

```bash
git add addons/bricks/localization/bricks_localization.csv
git commit -m "feat(bricks): add localization for split feature"
```

---

## Task 4: 添加单元测试

**Files:**
- Create: `addons/bricks/tests/test_trigger_splitter/test_trigger_splitter.gd`

**Step 1: 创建测试文件**

```gdscript
# 文件：addons/bricks/tests/test_trigger_splitter/test_trigger_splitter.gd
extends Node

## TriggerSplitter 单元测试
##
## 测试 TriggerSplitter.can_split() 静态方法的各种场景

## ==================== 常量 ====================

const TriggerSplitterClass = preload("res://addons/bricks/editor/context_menu/trigger_splitter.gd")
const TriggerClass = preload("res://addons/bricks/core/trigger.gd")
const MultiEventTriggerClass = preload("res://addons/bricks/core/multi_event_trigger.gd")
const EventBindingClass = preload("res://addons/bricks/core/event_binding.gd")

## ==================== 测试状态 ====================

var _test_count: int = 0
var _pass_count: int = 0
var _fail_count: int = 0

## ==================== 生命周期 ====================

func _ready() -> void:
	print("========================================")
	print("TriggerSplitter 单元测试")
	print("========================================")

	# 运行所有测试
	test_can_split_multi_trigger_with_two_bindings()
	test_can_split_rejects_single_binding()
	test_can_split_rejects_regular_trigger()
	test_can_split_rejects_regular_node()

	# 输出测试报告
	_print_test_report()

	# 退出场景
	get_tree().quit()

## ==================== 测试用例 ====================

## 测试：可以拆分有 2 个绑定的 MultiEventTrigger
func test_can_split_multi_trigger_with_two_bindings() -> void:
	_test_count += 1
	var test_name: String = "test_can_split_multi_trigger_with_two_bindings"
	print("\n[%s] 开始测试..." % test_name)

	# 创建 MultiEventTrigger
	var multi_trigger := MultiEventTriggerClass.new()
	multi_trigger.name = "MultiEventTrigger"

	# 添加两个 EventBinding
	var binding1 := EventBindingClass.new()
	var binding2 := EventBindingClass.new()
	multi_trigger.event_bindings = [binding1, binding2]

	# 执行测试
	var result: bool = TriggerSplitterClass.can_split(multi_trigger)

	# 清理
	multi_trigger.queue_free()

	# 验证结果
	if result == true:
		_pass_count += 1
		print("[PASS] %s: 有 2 个绑定的 MultiEventTrigger 可以拆分" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 true，实际返回 %s" % [test_name, result])

## 测试：拒绝拆分只有 1 个绑定的 MultiEventTrigger
func test_can_split_rejects_single_binding() -> void:
	_test_count += 1
	var test_name: String = "test_can_split_rejects_single_binding"
	print("\n[%s] 开始测试..." % test_name)

	# 创建 MultiEventTrigger
	var multi_trigger := MultiEventTriggerClass.new()
	multi_trigger.name = "MultiEventTrigger"

	# 只添加一个 EventBinding
	var binding1 := EventBindingClass.new()
	multi_trigger.event_bindings = [binding1]

	# 执行测试
	var result: bool = TriggerSplitterClass.can_split(multi_trigger)

	# 清理
	multi_trigger.queue_free()

	# 验证结果
	if result == false:
		_pass_count += 1
		print("[PASS] %s: 只有 1 个绑定的 MultiEventTrigger 无法拆分" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 false，实际返回 %s" % [test_name, result])

## 测试：拒绝拆分普通 Trigger
func test_can_split_rejects_regular_trigger() -> void:
	_test_count += 1
	var test_name: String = "test_can_split_rejects_regular_trigger"
	print("\n[%s] 开始测试..." % test_name)

	# 创建普通 Trigger
	var trigger := TriggerClass.new()
	trigger.name = "Trigger"

	# 执行测试
	var result: bool = TriggerSplitterClass.can_split(trigger)

	# 清理
	trigger.queue_free()

	# 验证结果
	if result == false:
		_pass_count += 1
		print("[PASS] %s: 普通 Trigger 无法拆分" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 false，实际返回 %s" % [test_name, result])

## 测试：拒绝拆分普通 Node
func test_can_split_rejects_regular_node() -> void:
	_test_count += 1
	var test_name: String = "test_can_split_rejects_regular_node"
	print("\n[%s] 开始测试..." % test_name)

	# 创建普通 Node
	var node := Node.new()
	node.name = "RegularNode"

	# 执行测试
	var result: bool = TriggerSplitterClass.can_split(node)

	# 清理
	node.queue_free()

	# 验证结果
	if result == false:
		_pass_count += 1
		print("[PASS] %s: 普通 Node 无法拆分" % test_name)
	else:
		_fail_count += 1
		print("[FAIL] %s: 期望返回 false，实际返回 %s" % [test_name, result])

## ==================== 辅助方法 ====================

## 打印测试报告
func _print_test_report() -> void:
	print("\n========================================")
	print("测试报告")
	print("========================================")
	print("总测试数: %d" % _test_count)
	print("通过: %d" % _pass_count)
	print("失败: %d" % _fail_count)
	print("通过率: %.1f%%" % (float(_pass_count) / float(_test_count) * 100.0))
	print("========================================")

	if _fail_count == 0:
		print("所有测试通过!")
	else:
		print("存在失败的测试!")
```

**Step 2: 创建测试场景文件**

创建 `addons/bricks/tests/test_trigger_splitter/test_trigger_splitter.tscn`：

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_trigger_splitter"]

[ext_resource type="Script" path="res://addons/bricks/tests/test_trigger_splitter/test_trigger_splitter.gd" id="1"]

[node name="TestTriggerSplitter" type="Node"]
script = ExtResource("1")
```

**Step 3: 运行测试**

```bash
"E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe" --headless --script res://addons/bricks/tests/test_trigger_splitter/test_trigger_splitter.gd
```

Expected: 所有 4 个测试通过

**Step 4: Commit**

```bash
git add addons/bricks/tests/test_trigger_splitter/
git commit -m "test(bricks): add unit tests for TriggerSplitter"
```

---

## Task 5: 手动集成测试

**Step 1: 打开 Godot 编辑器**

**Step 2: 创建测试场景**

1. 创建新场景，添加 Node2D 作为根节点
2. 添加 2 个 Trigger 节点
3. 选中 2 个 Trigger，右键 → "合并为多事件触发器"
4. 验证：创建了 MultiEventTrigger

**Step 3: 测试拆分**

1. 选中 MultiEventTrigger
2. 右键 → "拆分为独立触发器"
3. 验证：创建了 2 个 Trigger 节点

**Step 4: 测试 Undo/Redo**

1. Ctrl+Z 撤销拆分
2. 验证：恢复为 MultiEventTrigger
3. Ctrl+Shift+Z 重做
4. 验证：再次拆分为 2 个 Trigger

**Step 5: 测试边界情况**

1. 创建只有 1 个绑定的 MultiEventTrigger
2. 右键 → 验证：没有"拆分为独立触发器"选项

---

## 文件变更摘要

| 文件 | 操作 | 描述 |
|------|------|------|
| `addons/bricks/editor/context_menu/trigger_splitter.gd` | 创建 | 拆分工具类 |
| `addons/bricks/editor/context_menu/bricks_context_menu_plugin.gd` | 修改 | 添加拆分菜单项 |
| `addons/bricks/localization/bricks_localization.csv` | 修改 | 添加翻译键 |
| `addons/bricks/tests/test_trigger_splitter/test_trigger_splitter.gd` | 创建 | 单元测试 |
| `addons/bricks/tests/test_trigger_splitter/test_trigger_splitter.tscn` | 创建 | 测试场景 |

---

## 风险与注意事项

1. **深拷贝性能** - 大量 EventBinding 时可能有性能影响
2. **节点命名** - 拆分后的 Trigger 使用 `Trigger_1`, `Trigger_2` 命名，可能与现有节点冲突
3. **Undo 链** - 合并后拆分再撤销，状态链完整

---

**计划创建时间:** 2026-03-16
