# Trigger Merger Context Menu - 设计文档

## 概述

为 Bricks 插件添加场景树右键菜单功能，允许用户将多个 `Trigger` 节点合并为一个 `MultiEventTrigger` 节点，简化场景树结构，提升编辑体验。

## 功能规格

### 触发条件

菜单项 "Merge into Multi Event Trigger" 仅在以下条件**全部满足**时显示：

| 条件 | 说明 |
|------|------|
| 选中数量 ≥ 2 | 至少选中 2 个节点 |
| 类型检查 | 所有选中节点必须是 `Trigger` 类型 |
| 同级检查 | 所有选中节点必须拥有相同的父节点 |

### 菜单项规格

- **名称**: "Merge into Multi Event Trigger"
- **位置**: 场景树右键菜单
- **样式**: 拥有独立的分隔线，与其他菜单项分开

### 合并行为

```
┌─────────────────────────────────────────────────────────┐
│                    合并流程                              │
├─────────────────────────────────────────────────────────┤
│  1. 按 scene_tree_index 排序选中的 Trigger              │
│                    ↓                                    │
│  2. 创建 MultiEventTrigger 节点                         │
│                    ↓                                    │
│  3. 遍历排序后的 Trigger：                               │
│     a. 创建 EventBinding                                │
│     b. 深拷贝 event_definition → binding.event          │
│     c. 深拷贝 action_runner → binding.action_runner     │
│     d. 复制 trigger_once, cooldown_mode, cooldown_time  │
│     e. 追加到 event_bindings 数组                       │
│                    ↓                                    │
│  4. 将 MultiEventTrigger 添加到父节点（第一个位置）      │
│                    ↓                                    │
│  5. 删除所有原 Trigger 节点                              │
│                    ↓                                    │
│  6. 选中新创建的 MultiEventTrigger                       │
└─────────────────────────────────────────────────────────┘
```

### 资源处理策略

采用**深拷贝**方式处理资源：

- 每个 EventBinding 获得独立的 `event` 和 `action_runner` 副本
- 使用 `resource.duplicate(true)` 实现深拷贝
- 避免资源共享导致的状态冲突

### 属性映射

| Trigger 属性 | EventBinding 属性 | 说明 |
|--------------|-------------------|------|
| `event_definition` | `event` | 深拷贝 |
| `action_runner` | `action_runner` | 深拷贝 |
| `trigger_once` | `trigger_once` | 直接复制 |
| `cooldown_mode` | `cooldown_mode` | 直接复制 |
| `cooldown_time` | `cooldown_time` | 直接复制 |
| (无) | `enabled` | 固定为 `true` |

## 技术架构

### 文件结构

```
addons/bricks/editor/
├── context_menu/
│   ├── bricks_context_menu_plugin.gd    # EditorContextMenuPlugin 入口
│   └── trigger_merger.gd                # Trigger 合并功能模块
```

### 类设计

#### BricksContextMenuPlugin

统一的上下文菜单入口，管理所有 Bricks 相关的菜单项。

```gdscript
class_name BricksContextMenuPlugin extends EditorContextMenuPlugin

const TriggerMerger = preload("./trigger_merger.gd")

func _popup_menu(scene_tree: SceneTree, nodes: Array[Node], menu: PopupMenu) -> void:
    # Trigger 合并功能
    if TriggerMerger.can_merge(nodes):
        menu.add_separator()
        menu.add_item("Merge into Multi Event Trigger")
        menu.id_pressed.connect(_on_menu_pressed.bind(nodes))

func _on_menu_pressed(id: int, nodes: Array[Node]) -> void:
    TriggerMerger.merge(get_editor_interface(), get_undo_redo(), nodes)
```

#### TriggerMerger

独立的功能模块，封装合并逻辑。

```gdscript
class_name TriggerMerger extends RefCounted

## 检查是否可以合并
static func can_merge(nodes: Array[Node]) -> bool:
    # 检查：≥2个节点、全部是 Trigger、同一父节点
    if nodes.size() < 2:
        return false

    var parent: Node = null
    for node in nodes:
        if not node is Trigger:
            return false
        if parent == null:
            parent = node.get_parent()
        elif node.get_parent() != parent:
            return false

    return true

## 执行合并
static func merge(editor_interface: EditorInterface,
                  undo_redo: EditorUndoRedoManager,
                  nodes: Array[Node]) -> void:
    # 实现合并逻辑...
```

### 注册方式

在 `addons/bricks/plugin.gd` 中注册：

```gdscript
func _enter_tree():
    # 现有代码...

    # 注册 Bricks 上下文菜单
    add_context_menu_plugin(
        EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE,
        BricksContextMenuPlugin.new()
    )
```

### UndoRedo 支持

使用 Godot 的 `EditorUndoRedoManager` 支持撤销操作：

```gdscript
undo_redo.create_action("Merge Triggers into MultiEventTrigger")
undo_redo.add_do_method(_do_merge.bind(nodes))
undo_redo.add_undo_method(_undo_merge.bind(backup_data))
undo_redo.commit_action()
```

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| Trigger 没有 event_definition | 正常合并，EventBinding.event 为 null |
| Trigger 没有 action_runner | 正常合并，EventBinding.action_runner 为 null |
| 深拷贝失败 | 记录警告日志，该 binding 对应资源为 null |
| 父节点已被删除 | 提前检查，不显示菜单项 |

## 国际化

菜单文本使用 BricksLocalization：

```gdscript
menu.add_item(BricksLocalization.translate("BRICKS_MERGE_TRIGGERS"))
```

需要在本地化 CSV 中添加：

| Key | en | zh |
|-----|----|----|
| BRICKS_MERGE_TRIGGERS | Merge into Multi Event Trigger | 合并为多事件触发器 |

## 测试计划

### 测试文件

```
addons/bricks/tests/test_trigger_merger/
├── test_trigger_merger.tscn      # 测试场景
└── test_trigger_merger.gd        # 测试脚本
```

### 测试用例

| 用例 | 描述 |
|------|------|
| `test_can_merge_two_triggers` | 2个同父节点 Trigger 应通过检查 |
| `test_can_merge_rejects_single_trigger` | 单个 Trigger 应不通过 |
| `test_can_merge_rejects_mixed_nodes` | 混合节点类型应不通过 |
| `test_can_merge_rejects_different_parents` | 不同父节点应不通过 |
| `test_merge_preserves_event_binding` | 验证深拷贝和属性复制正确 |
| `test_merge_deletes_originals` | 验证原节点被删除 |
| `test_merge_position_correct` | 验证新节点在正确位置 |
| `test_undo_restore_originals` | 验证撤销恢复原状态 |

## 未来扩展

`BricksContextMenuPlugin` 设计为可扩展架构，未来可添加：

- 批量编辑 Instruction
- 批量复制 Event
- Trigger 拆分（MultiEventTrigger → 多个 Trigger）
- 其他场景树快捷操作

## 实现优先级

1. **P0** - 核心合并功能
2. **P1** - UndoRedo 支持
3. **P2** - 国际化
4. **P3** - 测试用例

---

**文档版本**: 1.1
**创建日期**: 2026-03-14
**更新日期**: 2026-03-14
**作者**: Claude Code + User

**更新记录**:
- v1.1: 添加 `enabled` 属性映射说明
