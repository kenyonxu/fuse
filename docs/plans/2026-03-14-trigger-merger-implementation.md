# Trigger Merger Context Menu - 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Bricks 插件添加场景树右键菜单功能，将多个 Trigger 节点合并为一个 MultiEventTrigger。

**Architecture:** 创建模块化的上下文菜单系统（BricksContextMenuPlugin + TriggerMerger），使用 EditorContextMenuPlugin API 注册到场景树右键菜单，支持 UndoRedo 撤销操作。

**Tech Stack:** GDScript, Godot 4.6 EditorPlugin API, EditorContextMenuPlugin, EditorUndoRedoManager

---

## ⚠️ 重要：UndoRedo 实现说明

Godot 4 的 `EditorUndoRedoManager.add_do_method()` 需要传入 **对象 + 方法名 + 参数**，而不是 `Callable.bind()`。

```gdscript
# ❌ 错误用法
undo_redo.add_do_method(some_method.bind(arg1, arg2))

# ✅ 正确用法
undo_redo.add_do_method(self, "some_method", arg1, arg2)
```

因此，`TriggerMerger` 必须设计为**非静态类**，使用实例方法来实现 UndoRedo。

---

## 参考文件

| 文件 | 用途 |
|------|------|
| `addons/bricks/core/trigger.gd` | Trigger 类定义，包含 event_definition、action_runner 等属性 |
| `addons/bricks/core/multi_event_trigger.gd` | MultiEventTrigger 类定义，目标类 |
| `addons/bricks/core/event_binding.gd` | EventBinding 类定义，合并后的数据结构 |
| `addons/bricks/plugin.gd` | 主插件文件，需要注册上下文菜单 |
| `addons/bricks/localization/translations.csv` | 本地化文件，格式：key,中文,英文 |

---

## 属性映射表（完整）

| Trigger 属性 | EventBinding 属性 | 说明 |
|--------------|-------------------|------|
| `event_definition` | `event` | 深拷贝 |
| `action_runner` | `action_runner` | 深拷贝 |
| `trigger_once` | `trigger_once` | 直接复制 |
| `cooldown_mode` | `cooldown_mode` | 直接复制 |
| `cooldown_time` | `cooldown_time` | 直接复制 |
| (无) | `enabled` | 固定为 `true` |

---

## Task 1: 创建 TriggerMerger 核心模块

**Files:**
- Create: `addons/bricks/editor/context_menu/trigger_merger.gd`

**Step 1: 创建目录结构**

```bash
mkdir -p addons/bricks/editor/context_menu
```

**Step 2: 创建 TriggerMerger 类**

```gdscript
# 文件：addons/bricks/editor/context_menu/trigger_merger.gd
@tool
class_name TriggerMerger extends RefCounted

## TriggerMerger - Trigger 合并功能模块
##
## 将多个 Trigger 节点合并为一个 MultiEventTrigger 节点。
## 深拷贝所有资源，确保独立性。
## 注意：此类设计为非静态类，因为 UndoRedo 需要实例方法。

## 编辑器接口引用
var _editor_interface: EditorInterface = null

## UndoRedo 管理器引用
var _undo_redo: EditorUndoRedoManager = null

## 初始化
func _init(editor_interface: EditorInterface, undo_redo: EditorUndoRedoManager) -> void:
	_editor_interface = editor_interface
	_undo_redo = undo_redo

## 检查是否可以合并选中的节点（静态方法，可在创建实例前调用）
##
## 条件：
## - 至少选中 2 个节点
## - 所有节点都是 Trigger 类型
## - 所有节点拥有相同的父节点
static func can_merge(nodes: Array[Node]) -> bool:
	if nodes.size() < 2:
		return false

	var parent: Node = null
	for node in nodes:
		# 检查是否为 Trigger 类型
		if not node is Trigger:
			return false
		# 检查是否同一父节点
		if parent == null:
			parent = node.get_parent()
		elif node.get_parent() != parent:
			return false

	return true

## 执行合并操作
func merge(nodes: Array[Node]) -> void:
	if nodes.is_empty():
		return

	# 按 scene_tree_index 排序
	var sorted_nodes := _sort_by_index(nodes)

	# 获取父节点和第一个节点位置
	var parent := sorted_nodes[0].get_parent()
	var first_index := sorted_nodes[0].get_index()

	# 创建 MultiEventTrigger
	var multi_trigger := MultiEventTrigger.new()
	multi_trigger.name = "MultiEventTrigger"

	# 构建 EventBindings
	for trigger: Trigger in sorted_nodes:
		var binding := _create_binding_from_trigger(trigger)
		multi_trigger.event_bindings.append(binding)

	# 创建备份数据（用于撤销）
	var backup := _create_backup(sorted_nodes)

	# 使用 UndoRedo 记录操作
	_undo_redo.create_action("Merge Triggers into MultiEventTrigger")
	_undo_redo.add_do_method(self, "_do_merge", parent, multi_trigger, sorted_nodes.duplicate(), first_index)
	_undo_redo.add_undo_method(self, "_undo_merge", parent, multi_trigger, backup)
	_undo_redo.commit_action()

	# 选中新节点（延迟执行，确保节点已添加）
	_select_node.call_deferred(multi_trigger)

## 按 scene_tree_index 排序节点
func _sort_by_index(nodes: Array[Node]) -> Array[Node]:
	var sorted: Array[Node] = []
	sorted.append_array(nodes)
	sorted.sort_custom(func(a: Node, b: Node): return a.get_index() < b.get_index())
	return sorted

## 从 Trigger 创建 EventBinding
func _create_binding_from_trigger(trigger: Trigger) -> EventBinding:
	var binding := EventBinding.new()
	binding.enabled = true

	# 深拷贝 event_definition
	if trigger.event_definition != null:
		binding.event = trigger.event_definition.duplicate(true)

	# 深拷贝 action_runner
	if trigger.action_runner != null:
		binding.action_runner = trigger.action_runner.duplicate(true)

	# 复制配置属性
	binding.trigger_once = trigger.trigger_once
	binding.cooldown_mode = trigger.cooldown_mode
	binding.cooldown_time = trigger.cooldown_time

	return binding

## 创建备份数据
func _create_backup(triggers: Array[Trigger]) -> Dictionary:
	var backup := {
		"first_index": triggers[0].get_index() if triggers.size() > 0 else 0,
		"triggers": []
	}

	for trigger: Trigger in triggers:
		var trigger_data := {
			"name": trigger.name,
			"index": trigger.get_index(),
			"event": trigger.event_definition.duplicate(true) if trigger.event_definition else null,
			"action_runner": trigger.action_runner.duplicate(true) if trigger.action_runner else null,
			"trigger_once": trigger.trigger_once,
			"cooldown_mode": trigger.cooldown_mode,
			"cooldown_time": trigger.cooldown_time
		}
		backup.triggers.append(trigger_data)

	return backup

## 执行合并（Do 操作）
func _do_merge(parent: Node, multi_trigger: MultiEventTrigger, triggers: Array[Trigger], first_index: int) -> void:
	# 添加 MultiEventTrigger 到父节点
	parent.add_child(multi_trigger)
	multi_trigger.owner = parent.owner if parent.owner else parent

	# 移动到正确位置
	parent.move_child(multi_trigger, first_index)

	# 删除原 Trigger 节点
	for trigger: Trigger in triggers:
		if trigger.get_parent() != null:
			trigger.get_parent().remove_child(trigger)
		trigger.queue_free()

## 撤销合并（Undo 操作）
func _undo_merge(parent: Node, multi_trigger: MultiEventTrigger, backup: Dictionary) -> void:
	# 重新创建原 Trigger 节点
	for trigger_data: Dictionary in backup.triggers:
		var trigger := Trigger.new()
		trigger.name = trigger_data.name
		trigger.event_definition = trigger_data.event
		trigger.action_runner = trigger_data.action_runner
		trigger.trigger_once = trigger_data.trigger_once
		trigger.cooldown_mode = trigger_data.cooldown_mode
		trigger.cooldown_time = trigger_data.cooldown_time

		parent.add_child(trigger)
		trigger.owner = parent.owner if parent.owner else parent
		parent.move_child(trigger, trigger_data.index)

	# 删除 MultiEventTrigger
	if multi_trigger.get_parent() != null:
		multi_trigger.get_parent().remove_child(multi_trigger)
	multi_trigger.queue_free()

## 选中新创建的节点
func _select_node(node: Node) -> void:
	if _editor_interface == null:
		return
	var editor_selection := _editor_interface.get_selection()
	editor_selection.clear()
	editor_selection.add_node(node)
```

**Step 3: 验证文件创建成功**

Run: `ls addons/bricks/editor/context_menu/`
Expected: 显示 `trigger_merger.gd`

**Step 4: 提交**

```bash
git add addons/bricks/editor/context_menu/trigger_merger.gd
git commit -m "feat(bricks): add TriggerMerger core module for context menu"
```

---

## Task 2: 创建 BricksContextMenuPlugin

**Files:**
- Create: `addons/bricks/editor/context_menu/bricks_context_menu_plugin.gd`

**Step 1: 创建 BricksContextMenuPlugin 类**

```gdscript
# 文件：addons/bricks/editor/context_menu/bricks_context_menu_plugin.gd
@tool
class_name BricksContextMenuPlugin extends EditorContextMenuPlugin

## BricksContextMenuPlugin - Bricks 统一的上下文菜单入口
##
## 管理所有 Bricks 相关的场景树上下文菜单项。
## 使用 EditorContextMenuPlugin API 提供右键菜单功能。

const TriggerMergerClass = preload("./trigger_merger.gd")

## 菜单项 ID
const MENU_ID_MERGE_TRIGGERS := 1000

## 插件引用（由 BricksPlugin 设置）
var _editor_plugin: EditorPlugin = null

## TriggerMerger 实例
var _trigger_merger: TriggerMerger = null

## 当前选中的节点（用于信号回调）
var _pending_nodes: Array[Node] = []

## 设置编辑器插件引用
func set_editor_plugin(plugin: EditorPlugin) -> void:
	_editor_plugin = plugin
	# 创建 TriggerMerger 实例
	if plugin != null:
		_trigger_merger = TriggerMergerClass.new(plugin.get_editor_interface(), plugin.get_undo_redo())

## 弹出菜单时调用
func _popup_menu(scene_tree: SceneTree, nodes: Array[Node], menu: PopupMenu) -> void:
	# 检查是否可以合并 Trigger
	if TriggerMergerClass.can_merge(nodes):
		# 保存当前选中的节点
		_pending_nodes = nodes.duplicate()

		# 添加分隔线
		menu.add_separator()
		# 添加菜单项（使用本地化）
		var menu_text := BricksLocalization.translate("BRICKS_MERGE_TRIGGERS")
		menu.add_item(menu_text, MENU_ID_MERGE_TRIGGERS)

		# 连接信号（使用 Callable 创建新的连接）
		if not menu.id_pressed.is_connected(_on_menu_id_pressed):
			menu.id_pressed.connect(_on_menu_id_pressed)

## 菜单项被按下时调用
func _on_menu_id_pressed(id: int) -> void:
	if id == MENU_ID_MERGE_TRIGGERS and _pending_nodes.size() > 0:
		_execute_merge(_pending_nodes.duplicate())
		_pending_nodes.clear()

## 执行合并
func _execute_merge(nodes: Array[Node]) -> void:
	if _trigger_merger == null:
		push_error("BricksContextMenuPlugin: TriggerMerger not initialized")
		return

	_trigger_merger.merge(nodes)
```

**Step 2: 验证文件创建成功**

Run: `ls addons/bricks/editor/context_menu/`
Expected: 显示 `bricks_context_menu_plugin.gd` 和 `trigger_merger.gd`

**Step 3: 提交**

```bash
git add addons/bricks/editor/context_menu/bricks_context_menu_plugin.gd
git commit -m "feat(bricks): add BricksContextMenuPlugin for scene tree context menu"
```

---

## Task 3: 注册上下文菜单插件

**Files:**
- Modify: `addons/bricks/plugin.gd`

**Step 1: 添加成员变量**

在第 9 行（`var bricks_plugin: EditorInspectorPlugin` 后）添加：

```gdscript
# 上下文菜单插件
var _context_menu_plugin: EditorContextMenuPlugin = null
```

**Step 2: 添加注册函数**

在 `_enter_tree()` 函数中，在 `print("Bricks Visual Programming 插件已激活")` 之前添加：

```gdscript
	# 注册上下文菜单插件
	_register_context_menu_plugin()
```

**Step 3: 添加清理函数**

在 `_exit_tree()` 函数中，在 `print("Bricks Visual Programming 插件已停用")` 之前添加：

```gdscript
	# 清理上下文菜单插件
	_unregister_context_menu_plugin()
```

**Step 4: 添加辅助函数**

在文件末尾（`_unregister_event_bus()` 函数后）添加：

```gdscript
## 注册上下文菜单插件
func _register_context_menu_plugin() -> void:
	var plugin_script = preload("res://addons/bricks/editor/context_menu/bricks_context_menu_plugin.gd")
	_context_menu_plugin = plugin_script.new()
	_context_menu_plugin.set_editor_plugin(self)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE, _context_menu_plugin)
	print("[BricksPlugin] 上下文菜单插件已注册")

## 清理上下文菜单插件
func _unregister_context_menu_plugin() -> void:
	if _context_menu_plugin != null:
		remove_context_menu_plugin(_context_menu_plugin)
		_context_menu_plugin = null
		print("[BricksPlugin] 上下文菜单插件已清理")
```

**Step 5: 验证修改**

Run: `grep -n "context_menu_plugin" addons/bricks/plugin.gd`
Expected: 显示 6 处引用（变量声明、注册调用、清理调用、两个函数定义、print语句）

**Step 6: 提交**

```bash
git add addons/bricks/plugin.gd
git commit -m "feat(bricks): register BricksContextMenuPlugin in main plugin"
```

---

## Task 4: 添加本地化支持

**Files:**
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加翻译键**

在 `translations.csv` 文件末尾添加：

```csv
BRICKS_MERGE_TRIGGERS,合并为多事件触发器,Merge into Multi Event Trigger
```

**Step 2: 验证添加成功**

Run: `grep "BRICKS_MERGE_TRIGGERS" addons/bricks/localization/translations.csv`
Expected: 显示新添加的行

**Step 3: 提交**

```bash
git add addons/bricks/localization/translations.csv
git commit -m "feat(bricks): add localization for Trigger Merger menu item"
```

---

## Task 5: 创建测试脚本

**Files:**
- Create: `addons/bricks/tests/test_trigger_merger/test_trigger_merger.gd`

**Step 1: 创建测试目录**

```bash
mkdir -p addons/bricks/tests/test_trigger_merger
```

**Step 2: 创建测试脚本**

```gdscript
# 文件：addons/bricks/tests/test_trigger_merger/test_trigger_merger.gd
extends Node

## TriggerMerger 测试脚本
##
## 测试 TriggerMerger 的 can_merge 静态方法
## 注意：merge() 方法需要 EditorInterface 和 UndoRedoManager，只能在编辑器中测试

var _test_parent: Node = null
var _trigger1: Trigger = null
var _trigger2: Trigger = null
var _trigger3: Trigger = null
var _other_node: Node = null

func _ready() -> void:
	_setup_test_environment()
	_run_all_tests()
	_cleanup()

## 设置测试环境
func _setup_test_environment() -> void:
	_test_parent = Node.new()
	_test_parent.name = "TestParent"
	add_child(_test_parent)

	_trigger1 = Trigger.new()
	_trigger1.name = "Trigger1"
	_test_parent.add_child(_trigger1)

	_trigger2 = Trigger.new()
	_trigger2.name = "Trigger2"
	_test_parent.add_child(_trigger2)

	_trigger3 = Trigger.new()
	_trigger3.name = "Trigger3"
	_test_parent.add_child(_trigger3)

	_other_node = Node.new()
	_other_node.name = "OtherNode"
	_test_parent.add_child(_other_node)

## 运行所有测试
func _run_all_tests() -> void:
	print("===== TriggerMerger Tests =====")

	_test_can_merge_two_triggers()
	_test_can_merge_rejects_single_trigger()
	_test_can_merge_rejects_mixed_nodes()
	_test_can_merge_rejects_different_parents()

	print("===== All tests completed =====")

## 测试：2个同父节点 Trigger 应通过检查
func _test_can_merge_two_triggers() -> void:
	var nodes: Array[Node] = [_trigger1, _trigger2]
	var result := TriggerMerger.can_merge(nodes)
	assert(result == true, "can_merge should return true for 2 triggers with same parent")
	print("  [PASS] test_can_merge_two_triggers")

## 测试：单个 Trigger 应不通过
func _test_can_merge_rejects_single_trigger() -> void:
	var nodes: Array[Node] = [_trigger1]
	var result := TriggerMerger.can_merge(nodes)
	assert(result == false, "can_merge should return false for single trigger")
	print("  [PASS] test_can_merge_rejects_single_trigger")

## 测试：混合节点类型应不通过
func _test_can_merge_rejects_mixed_nodes() -> void:
	var nodes: Array[Node] = [_trigger1, _other_node]
	var result := TriggerMerger.can_merge(nodes)
	assert(result == false, "can_merge should return false for mixed node types")
	print("  [PASS] test_can_merge_rejects_mixed_nodes")

## 测试：不同父节点应不通过
func _test_can_merge_rejects_different_parents() -> void:
	var other_parent := Node.new()
	other_parent.name = "OtherParent"
	add_child(other_parent)

	var trigger_other := Trigger.new()
	trigger_other.name = "TriggerOther"
	other_parent.add_child(trigger_other)

	var nodes: Array[Node] = [_trigger1, trigger_other]
	var result := TriggerMerger.can_merge(nodes)
	assert(result == false, "can_merge should return false for triggers with different parents")

	other_parent.queue_free()
	print("  [PASS] test_can_merge_rejects_different_parents")

## 清理测试环境
func _cleanup() -> void:
	if _test_parent:
		_test_parent.queue_free()
```

**Step 3: 提交测试文件**

```bash
git add addons/bricks/tests/test_trigger_merger/
git commit -m "test(bricks): add TriggerMerger unit tests"
```

---

## Task 6: 手动测试验证清单

**Files:**
- 无文件修改，仅验证功能

**Step 1: 重启 Godot 编辑器**

关闭并重新打开 Godot 编辑器，确保插件重新加载。

**Step 2: 运行单元测试**

1. 打开 `addons/bricks/tests/test_trigger_merger/test_trigger_merger.tscn`（需要先在编辑器中创建场景）
2. 运行场景（F6）
3. 检查输出窗口，确认所有测试通过

**Step 3: 创建测试场景**

1. 创建新场景，添加一个 Node 作为根节点
2. 添加 2-3 个 Trigger 子节点
3. 为每个 Trigger 配置不同的 event_definition 和 action_runner

**Step 4: 测试右键菜单**

1. 在场景树中选中 2 个 Trigger 节点
2. 右键点击
3. 验证：
   - [ ] 菜单中出现分隔线
   - [ ] 菜单中显示 "合并为多事件触发器" / "Merge into Multi Event Trigger"

**Step 5: 测试合并功能**

1. 点击菜单项
2. 验证：
   - [ ] 创建了新的 MultiEventTrigger 节点
   - [ ] MultiEventTrigger 位置在第一个 Trigger 的位置
   - [ ] 原 Trigger 节点被删除
   - [ ] EventBinding 数量正确
   - [ ] 每个 EventBinding 的属性正确复制（包括 enabled=true）

**Step 6: 测试撤销功能**

1. 按 Ctrl+Z
2. 验证：
   - [ ] MultiEventTrigger 节点被删除
   - [ ] 原 Trigger 节点恢复
   - [ ] 属性正确恢复

**Step 7: 测试边界情况**

| 测试场景 | 预期结果 | 通过 |
|----------|----------|------|
| 只选中 1 个 Trigger | 菜单项不显示 | [ ] |
| 选中 Trigger + 其他节点 | 菜单项不显示 | [ ] |
| 选中不同父节点的 Trigger | 菜单项不显示 | [ ] |

---

## 文件清单

| 文件 | 操作 | 描述 |
|------|------|------|
| `addons/bricks/editor/context_menu/trigger_merger.gd` | 创建 | 核心合并逻辑 |
| `addons/bricks/editor/context_menu/bricks_context_menu_plugin.gd` | 创建 | 上下文菜单入口 |
| `addons/bricks/plugin.gd` | 修改 | 注册上下文菜单插件 |
| `addons/bricks/localization/translations.csv` | 修改 | 添加本地化键 |
| `addons/bricks/tests/test_trigger_merger/test_trigger_merger.gd` | 创建 | 单元测试 |

---

## 注意事项

1. **UndoRedo 实现**: 使用 `add_do_method(self, "method_name", args...)` 格式，而非 `Callable.bind()`
2. **UndoRedo 限制**: Godot 的 UndoRedo 系统在编辑器关闭后会丢失历史，这是预期行为
3. **深拷贝性能**: 对于包含大量指令的 ActionRunner，duplicate(true) 可能有性能开销
4. **信号连接**: 使用实例变量 `_pending_nodes` 保存选中节点，避免 bind() 导致的连接问题
5. **owner 设置**: 新创建的节点必须设置 `owner` 属性才能正确保存到场景
6. **延迟选择**: 使用 `call_deferred()` 确保节点添加后再选中新节点
7. **enabled 属性**: EventBinding 的 enabled 属性固定设为 true

---

**创建日期**: 2026-03-14
**更新日期**: 2026-03-14
**版本**: 1.1 - 修复 UndoRedo 实现方式
