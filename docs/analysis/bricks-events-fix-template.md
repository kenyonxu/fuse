# Bricks 事件组件修复模板

**用途**: 快速修复事件组件中的节点路径解析问题
**适用**: 所有使用 `owner_node.get_node_or_null()` 的事件组件

---

## 📋 修复检查清单

修复每个组件前，请确认：
- [ ] 组件使用 `owner_node.get_node_or_null(target_node)` 获取节点
- [ ] 组件有 `initialize_with_runtime_instance()` 方法
- [ ] 组件已迁移到 RuntimeInstance 模式
- [ ] 组件在 `_trigger_ref` 中保存了 owner_node 引用

---

## 🔧 标准修复步骤

### Step 1: 定位问题代码

搜索以下模式：
```gdscript
# 在 initialize_with_runtime_instance() 中
_target_node_ref = owner_node.get_node_or_null(target_node)

# 或在 initialize() 中
_target_node_ref = owner_node.get_node_or_null(target_node)
```

### Step 2: 替换节点获取方法

#### 原始代码 (Before)
```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        return

    _runtime_instance_ref = runtime_instance
    _trigger_ref = owner_node

    # 验证 owner_node
    if not owner_node:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 验证目标节点路径
    if target_node.is_empty():
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_EMPTY", BricksError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # ❌ 问题代码
    _target_node_ref = owner_node.get_node_or_null(target_node)
    if not _target_node_ref:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
        return
```

#### 修复后代码 (After)
```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        return

    _runtime_instance_ref = runtime_instance
    _trigger_ref = owner_node

    # 验证 owner_node
    if not owner_node:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 验证目标节点路径
    if target_node.is_empty():
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_EMPTY", BricksError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # ✅ 修复：使用 BricksNodeUtils
    _target_node_ref = BricksNodeUtils.find_node_at_runtime(_trigger_ref, target_node)
    if not _target_node_ref:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
        return
```

### Step 3: 同步修复 initialize() 方法（如果存在）

如果组件还保留了向后兼容的 `initialize()` 方法，也需要修复：

```gdscript
func initialize(owner_node: Node) -> void:
    # 验证 owner_node
    if not owner_node:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # 验证目标节点路径
    if target_node.is_empty():
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_EMPTY", BricksError.ErrorType.CONFIGURATION_ERROR, {})
        return

    # ✅ 同样修复这里
    _target_node_ref = BricksNodeUtils.find_node_at_runtime(owner_node, target_node)
    if not _target_node_ref:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node)})
        return
```

---

## 🎯 具体组件修复示例

### 示例 1: Animation Events

#### 文件: animation/on_animation_finished.gd

**位置 1**: initialize_with_runtime_instance() 方法
```gdscript
# Line ~62
# Before
_anim_player_ref = owner_node.get_node_or_null(animation_player)

# After
_anim_player_ref = BricksNodeUtils.find_node_at_runtime(_trigger_ref, animation_player)
```

**位置 2**: initialize() 方法
```gdscript
# Line ~101
# Before
_anim_player_ref = owner_node.get_node_or_null(animation_player)

# After
_anim_player_ref = BricksNodeUtils.find_node_at_runtime(owner_node, animation_player)
```

### 示例 2: Physics Events

#### 文件: physics/on_body_entered.gd

**位置 1**: initialize_with_runtime_instance() 方法
```gdscript
# Line ~108
# Before
_area_ref = owner_node.get_node_or_null(area_node)

# After
_area_ref = BricksNodeUtils.find_node_at_runtime(_trigger_ref, area_node)
```

**位置 2**: initialize() 方法
```gdscript
# Line ~73
# Before
_area_ref = owner_node.get_node_or_null(area_node)

# After
_area_ref = BricksNodeUtils.find_node_at_runtime(owner_node, area_node)
```

### 示例 3: UI Events

#### 文件: ui/on_button_pressed.gd

**位置 1**: initialize_with_runtime_instance() 方法
```gdscript
# Line ~69
# Before
_button_ref = owner_node.get_node_or_null(target_button)

# After
_button_ref = BricksNodeUtils.find_node_at_runtime(_trigger_ref, target_button)
```

**位置 2**: initialize() 方法
```gdscript
# Line ~98
# Before
_button_ref = owner_node.get_node_or_null(target_button)

# After
_button_ref = BricksNodeUtils.find_node_at_runtime(owner_node, target_button)
```

---

## ⚠️ 特殊情况处理

### 情况 1: 使用 _owner_node_ref 而非 _trigger_ref

某些组件可能使用 `_owner_node_ref` 而不是 `_trigger_ref`：

```gdscript
# Before
_target_ref = _owner_node.get_node_or_null(target_node)

# After
_target_ref = BricksNodeUtils.find_node_at_runtime(_owner_node_ref, target_node)
```

### 情况 2: 没有保存 _trigger_ref

如果组件没有保存 `_trigger_ref`，需要先添加：

```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        return

    _runtime_instance_ref = runtime_instance

    # ✅ 添加这一行
    _trigger_ref = owner_node

    # 然后才能使用 BricksNodeUtils
    _target_node_ref = BricksNodeUtils.find_node_at_runtime(_trigger_ref, target_node)
```

### 情况 3: 仅使用 initialize()，未迁移到 RuntimeInstance

如果组件还没有 `initialize_with_runtime_instance()` 方法，建议参考 `on_timer.gd` 或 `on_target_signal_emit.gd` 进行完整迁移。

---

## 🧪 测试验证

修复完成后，请进行以下测试：

### 测试 1: 基本功能测试
```gdscript
# 测试场景
Node (Trigger)
  └─ Node2D (target_node)
       └─ Event (on_animation_finished)

# 预期结果: 事件能够正确触发
```

### 测试 2: 相对路径测试
```gdscript
# 测试场景
Node (Trigger)
  └─ Event (on_animation_finished)
       target_node: "../AnimationPlayer"  # 使用相对路径

# 预期结果: 相对路径能够正确解析
```

### 测试 3: 嵌套 Trigger 测试
```gdscript
# 测试场景
Node
  └─ Trigger1
       └─ Trigger2
            └─ AnimationPlayer
            └─ Event (on_animation_finished)
                 target_node: "AnimationPlayer"

# 预期结果: 从 Trigger2 能够找到 AnimationPlayer
```

### 测试 4: 资源上下文测试
```gdscript
# 测试场景
Trigger
  └─ EventResource (on_property_changed)
       stored_in: Trigger 的子节点

# 预期结果: BricksNodeUtils.find_node_from_resource_context() 能够正确解析
```

---

## 📝 修复完成检查

修复每个组件后，确认：
- [ ] 所有 `owner_node.get_node_or_null()` 已替换
- [ ] 所有 `get_node_or_null(target_node)` 已替换
- [ ] `_trigger_ref` 已正确设置
- [ ] 错误处理逻辑保持不变
- [ ] 代码格式正确（使用 Tab 缩进）
- [ ] 注释更新（如果有必要）

---

## 🚀 批量修复脚本

如需批量修复，可以使用以下搜索模式：

### 搜索模式 1: owner_node.get_node_or_null
```bash
# 在事件目录中搜索
cd addons/bricks/events
grep -n "owner_node.get_node_or_null" */*.gd
```

### 搜索模式 2: _trigger_ref 是否设置
```bash
# 检查是否设置了 _trigger_ref
grep -n "_trigger_ref = owner_node" */*.gd
```

### 搜索模式 3: find_node_at_runtime 使用情况
```bash
# 检查已使用 BricksNodeUtils 的组件
grep -n "BricksNodeUtils.find_node_at_runtime" */*.gd
```

---

## 📚 参考资源

- **BricksNodeUtils API**: `addons/bricks/core/utilities/bricks_node_utils.gd`
- **优秀范例**: `addons/bricks/events/node/on_target_signal_emit.gd`
- **RuntimeInstance 指南**: `addons/bricks/docs/migration-guide-to-runtime-instance.md`

---

## 💡 常见问题

### Q1: 为什么要使用 BricksNodeUtils 而不是 get_node_or_null?

**A**: 因为 BricksNodeUtils 提供了多种查找策略，能够正确处理：
- Resource 上下文中的相对路径
- 嵌套 Trigger 中的节点查找
- 场景加载顺序问题
- 编辑器模式和运行时模式的差异

### Q2: 修复后会影响现有功能吗？

**A**: 不会。BricksNodeUtils 是 `get_node_or_null()` 的增强版本，向后兼容。修复后功能完全相同，但更加健壮。

### Q3: 如果组件没有 _trigger_ref 怎么办？

**A**: 需要先添加 `_trigger_ref = owner_node`，然后才能使用 BricksNodeUtils.find_node_at_runtime()。

### Q4: 是否需要同时修复 initialize() 和 initialize_with_runtime_instance()?

**A**: 是的。如果组件保留了 `initialize()` 方法用于向后兼容，两个方法都需要修复。

---

**模板版本**: 1.0
**最后更新**: 2026-02-05
**维护者**: Claude Code Agent
