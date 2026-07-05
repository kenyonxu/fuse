2# Bricks 组件节点路径修复实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 修复 Bricks 系统中 36 个组件的节点路径解析问题，确保在 Resource 存储在 Trigger 子节点时能正确处理相对路径（如 ".."）。

**架构:** 分四个阶段递进修复，优先修复高优先级组件，使用统一的修复模式（BricksNodeUtils 工具类）。

**技术栈:** Godot 4.6, GDScript 2.0, Bricks 可视化编程系统, RuntimeEventInstance 架构

**参考文档:**
- 优先级分析: `docs/analysis/bricks-components-fix-priority.md`
- 修复指南: `addons/bricks/docs/development/bricks-component-fix-guide.md`

---

## 当前进度概览

```
[████░░░░░░░░░░░░░░░░] 11% 完成 (2/19 小时)
```

**已完成:**
- ✅ SetPropertyValue (P0) - 2小时

**进行中:**
- 🔧 RunTargetNodeFunction (P1) - 4小时（需完成）

**待开始:**
- Events 高优先级 (12个) - 2小时
- Conditions + Events 中优先级 (21个) - 6.5小时
- 性能优化和测试 - 4小时

---

## 修复模式总览

### Events 标准修复模式

所有 Events 组件使用统一的修复模式：

**Before (错误):**
```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    _runtime_instance_ref = runtime_instance
    _trigger_ref = owner_node

    # ❌ 旧方法 - 无法正确处理 Resource 上下文中的相对路径
    _target_node_ref = owner_node.get_node_or_null(target_node)
    if not _target_node_ref:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", ...)
        return
```

**After (正确):**
```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
    if Engine.is_editor_hint():
        return

    _runtime_instance_ref = runtime_instance
    _trigger_ref = owner_node

    # ✅ 新方法 - 使用 BricksNodeUtils 处理 Resource 上下文
    _target_node_ref = BricksNodeUtils.find_node_at_runtime(_trigger_ref, target_node)
    if not _target_node_ref:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", ...)
        return
```

### Conditions 修复模式

Conditions 组件使用 `context.get_node()`，但对于 CheckNodeProperty 需要特殊处理：

**Before (错误):**
```gdscript
var node = context.get_node(target_node_path)
```

**After (正确):**
```gdscript
var node = BricksNodeUtils.find_node_from_resource_context(self, target_node_path)
if node == null:
    var error_msg = BricksLocalization.translate("BRICKS_ERROR_NODE_NOT_FOUND") % str(target_node_path)
    _log_error(error_msg)
    _create_bricks_error(error_msg, BricksError.ErrorType.VALIDATION_ERROR)
    return false
```

---

## 阶段 1: 完成 Instructions 系统

### Task 1: 完成 RunTargetNodeFunction 修复

**文件:**
- 修改: `addons/bricks/instructions/node_operations/run_target_node_function.gd`

**估计时间:** 4小时

**当前状态:** 进行中

**问题分析:**
1. [HIGH] 未使用资源上下文 - 使用自定义节点获取逻辑（~50行）
2. [HIGH] 路径解析逻辑不完整 - 只处理 "../" 前缀
3. [MEDIUM] 缺少资源所有者查找
4. [MEDIUM] 没有场景加载顺序保护
5. [LOW] 运行时节点获取逻辑不一致

**Step 1: 备份当前文件**

```bash
# 创建备份
cp addons/bricks/instructions/node_operations/run_target_node_function.gd \
   addons/bricks/instructions/node_operations/run_target_node_function.gd.backup
```

**Step 2: 阅读并理解当前实现**

```gdscript
# 需要重点关注的方法：
# - _get_property_list() - 动态属性列表生成
# - _update_target_node_info() - 目标节点信息更新
# - execute() - 运行时执行逻辑
# - 所有涉及节点路径解析的代码
```

**Step 3: 替换编辑器节点获取逻辑**

在 `_update_target_node_info()` 方法中：

```gdscript
# Before (旧代码约30-50行)
# ... 自定义的相对路径处理逻辑 ...

# After (使用 BricksNodeUtils)
func _update_target_node_info() -> void:
	if _target_node.is_empty():
		_clear_cached_info()
		return

	if not edited_root:
		# 场景加载顺序问题 - 延迟初始化
		return

	# ✅ 使用 BricksNodeUtils 替代自定义逻辑
	_target_node_instance = BricksNodeUtils.find_node_from_resource_context(
		edited_root,
		self,
		_target_node
	)

	if _target_node_instance:
		_update_available_methods()
		_update_method_signature()
	else:
		_clear_cached_info()
```

**Step 4: 添加场景加载顺序保护**

在 `_get_property_list()` 中添加惰性初始化：

```gdscript
func _get_property_list() -> Array[Dictionary]:
	# ✅ 惰性初始化 - 如果节点实例为 null，尝试重新获取
	if Engine.is_editor_hint() and _target_node_instance == null and not _target_node.is_empty():
		_update_target_node_info()

	# ... 原有属性列表构建逻辑 ...
```

在 `target_node` setter 中添加保护：

```gdscript
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		# ✅ 如果在编辑器模式下且节点实例为 null，先尝试获取节点
		if Engine.is_editor_hint() and _target_node_instance == null and not target_node.is_empty():
			_update_target_node_info()
		_update_target_node_info()
		_update_method_signature()
		_update_resource_name()
		notify_property_list_changed()
```

**Step 5: 统一运行时节点解析**

在 `execute()` 方法中：

```gdscript
func execute(context: ExecutionContext) -> void:
	# ✅ 正确 - 使用 context.get_node()
	var target = context.get_node(target_node)
	if not target:
		_log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
		return

	# ... 其余执行逻辑 ...
```

**Step 6: 移除不再需要的辅助方法**

删除以下不再需要的方法：
- `_find_node_by_name()` - 已被 BricksNodeUtils 替代
- 任何自定义的相对路径处理逻辑

**Step 7: 添加注释说明修复**

在文件顶部添加修复说明：

```gdscript
## 修复记录:
## - 2026-02-05: 使用 BricksNodeUtils 替代自定义节点查找逻辑
##            添加场景加载顺序保护
##            统一运行时节点解析方法
##            参考: addons/bricks/docs/development/bricks-component-fix-guide.md
```

**Step 8: 测试验证**

创建测试场景验证修复：

```bash
# 测试场景 1: Resource 存储在 Trigger 子节点下
# - 使用相对路径 ".." 选择节点
# - 保存场景后重启编辑器
# - 验证属性列表正确显示
# - 验证方法调用成功

# 测试场景 2: 多层相对路径
# - 使用 "../../SomeNode" 路径
# - 验证路径解析正确

# 测试场景 3: 运行时测试
# - 运行场景，验证方法调用成功
# - 验证参数传递正确
# - 验证返回值存储正确
```

**Step 9: 提交修复**

```bash
git add addons/bricks/instructions/node_operations/run_target_node_function.gd
git commit -m "fix: 修复 RunTargetNodeFunction 节点路径解析问题

- 使用 BricksNodeUtils.find_node_from_resource_context() 替代自定义逻辑
- 添加场景加载顺序保护（惰性初始化）
- 统一运行时节点解析为 context.get_node()
- 移除不再需要的辅助方法
- 通过编辑器测试和场景保存/重启测试

参考: addons/bricks/docs/development/bricks-component-fix-guide.md
修复时长: 4小时"
```

**验证标准:**
- [ ] 编辑器中选择节点成功
- [ ] 属性列表（方法列表）正确显示
- [ ] 场景保存后重启编辑器，属性不丢失
- [ ] 相对路径 ".." 正确解析为资源所在节点
- [ ] 运行时方法调用成功
- [ ] 参数传递和返回值存储正确

---

## 阶段 2: Events 高优先级修复

### Task 2: 修复 Animation Events (6个)

**文件:**
- 修改: `addons/bricks/events/animation/on_animation_blend.gd`
- 修改: `addons/bricks/events/animation/on_animation_finished.gd`
- 修改: `addons/bricks/events/animation/on_animation_frame_reached.gd`
- 修改: `addons/bricks/events/animation/on_animation_loop.gd`
- 修改: `addons/bricks/events/animation/on_animation_marker.gd`
- 修改: `addons/bricks/events/animation/on_animation_started.gd`

**估计时间:** 1小时（6个组件）

**共同问题:** 使用 `owner_node.get_node_or_null(animation_player)`

**修复模式:**

对于每个 Animation Event：

**Step 1: 定位问题代码**

找到 `initialize_with_runtime_instance()` 方法中的这段代码：

```gdscript
# ❌ 问题代码
_anim_player_ref = owner_node.get_node_or_null(animation_player)
if not _anim_player_ref:
    _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", ...)
    return
```

**Step 2: 应用修复**

替换为：

```gdscript
# ✅ 修复后代码
_anim_player_ref = BricksNodeUtils.find_node_at_runtime(_trigger_ref, animation_player)
if not _anim_player_ref:
    _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", ...)
    return
```

**Step 3: 批量修复脚本**

创建批量修复脚本：

```bash
# tools/fix_animation_events.sh
#!/bin/bash

events=(
	"on_animation_blend"
	"on_animation_finished"
	"on_animation_frame_reached"
	"on_animation_loop"
	"on_animation_marker"
	"on_animation_started"
)

for event in "${events[@]}"; do
	file="addons/bricks/events/animation/${event}.gd"
	echo "修复 $file ..."

	# 使用 sed 替换（注意转义）
	# Windows 上使用 Git Bash 或手动替换
done

echo "Animation Events 批量修复完成！"
```

**Step 4: 测试验证**

```bash
# 测试场景：动画事件触发
# 1. 创建包含 AnimationPlayer 的场景
# 2. 添加 OnAnimationFinished 事件
# 3. 使用相对路径选择 AnimationPlayer
# 4. 保存场景后重启编辑器
# 5. 验证事件能正确触发
```

**Step 5: 提交修复**

```bash
git add addons/bricks/events/animation/*.gd
git commit -m "fix: 批量修复 Animation Events 节点路径解析问题 (6个组件)

修复组件:
- OnAnimationBlend
- OnAnimationFinished
- OnAnimationFrameReached
- OnAnimationLoop
- OnAnimationMarker
- OnAnimationStarted

修复内容:
- 使用 BricksNodeUtils.find_node_at_runtime() 替代 get_node_or_null()
- 正确处理 Resource 上下文中的相对路径

测试: 动画事件触发测试、相对路径解析测试

参考: docs/analysis/bricks-components-fix-priority.md"
```

---

### Task 3: 修复 Physics Events (6个)

**文件:**
- 修改: `addons/bricks/events/physics/on_area_2d_enter.gd`
- 修改: `addons/bricks/events/physics/on_area_2d_exited.gd`
- 修改: `addons/bricks/events/physics/on_area_3d_entered.gd`
- 修改: `addons/bricks/events/physics/on_area_3d_exited.gd`
- 修改: `addons/bricks/events/physics/on_body_entered.gd`
- 修改: `addons/bricks/events/physics/on_collision.gd`

**估计时间:** 1小时（6个组件）

**共同问题:** 使用 `owner_node.get_node_or_null(area_node)` 或类似代码

**修复模式:**

对于每个 Physics Event：

**Step 1: 定位问题代码**

在 `initialize_with_runtime_instance()` 或 `initialize()` 方法中找到：

```gdscript
# ❌ 问题代码
_area_node = owner_node.get_node_or_null(area_node_path)
if not _area_node:
    _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", ...)
    return
```

**Step 2: 应用修复**

替换为：

```gdscript
# ✅ 修复后代码
_area_node = BricksNodeUtils.find_node_at_runtime(_trigger_ref, area_node_path)
if not _area_node:
    _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", ...)
    return
```

**注意:** `on_area_2d_enter.gd` 需要同时修复 `initialize()` 和 `initialize_with_runtime_instance()` 两个方法。

**Step 3: 测试验证**

```bash
# 测试场景：物理碰撞事件触发
# 1. 创建包含 Area2D 的场景
# 2. 添加 OnArea2DEnter 事件
# 3. 使用相对路径选择 Area2D
# 4. 运行场景，触发碰撞
# 5. 验证事件能正确触发
```

**Step 4: 提交修复**

```bash
git add addons/bricks/events/physics/on_area_*.gd
git add addons/bricks/events/physics/on_body_entered.gd
git add addons/bricks/events/physics/on_collision.gd
git commit -m "fix: 批量修复 Physics Events 节点路径解析问题 (6个组件)

修复组件:
- OnArea2DEnter
- OnArea2DExited
- OnArea3DEntered
- OnArea3DExited
- OnBodyEntered
- OnCollision

修复内容:
- 使用 BricksNodeUtils.find_node_at_runtime() 替代 get_node_or_null()
- 正确处理 Resource 上下文中的相对路径
- 同时修复 initialize() 和 initialize_with_runtime_instance()

测试: 物理碰撞事件触发测试、相对路径解析测试

参考: docs/analysis/bricks-components-fix-priority.md"
```

---

## 阶段 3: Conditions 和 Events 中优先级修复

### Task 4: 修复 CheckNodeProperty Condition

**文件:**
- 修改: `addons/bricks/conditions/node/check_node_property.gd`

**估计时间:** 0.5小时

**问题:** 需要使用 `BricksNodeUtils.find_node_from_resource_context()`

**Step 1: 定位问题代码**

找到 `check()` 方法中的节点获取代码：

```gdscript
# ❌ 问题代码
var node = context.get_node(target_node_path)
if not node:
    return false
```

**Step 2: 应用修复**

替换为：

```gdscript
# ✅ 修复后代码
var node = BricksNodeUtils.find_node_from_resource_context(self, target_node_path)
if node == null:
    var error_msg = BricksLocalization.translate("BRICKS_ERROR_NODE_NOT_FOUND") % str(target_node_path)
    _log_error(error_msg)
    _create_bricks_error(error_msg, BricksError.ErrorType.VALIDATION_ERROR)
    return false
```

**Step 3: 测试验证**

```bash
# 测试场景：节点属性检查
# 1. 创建包含属性的节点
# 2. 添加 CheckNodeProperty 条件
# 3. 使用相对路径选择节点
# 4. 验证条件检查正确执行
```

**Step 4: 提交修复**

```bash
git add addons/bricks/conditions/node/check_node_property.gd
git commit -m "fix: 修复 CheckNodeProperty 节点路径解析问题

- 使用 BricksNodeUtils.find_node_from_resource_context()
- 正确处理 Resource 上下文中的相对路径
- 添加完善的错误处理和日志

测试: 节点属性检查测试、相对路径解析测试

参考: docs/analysis/bricks-components-fix-priority.md"
```

---

### Task 5: 修复 Audio Events (2个)

**文件:**
- 修改: `addons/bricks/events/audio/on_audio_finished.gd`
- 修改: `addons/bricks/events/audio/on_audio_started.gd`

**估计时间:** 0.5小时

**共同问题:** 使用 `owner_node.get_node_or_null(audio_player)`

**修复模式:**

与 Animation Events 相同的修复模式，替换为 `BricksNodeUtils.find_node_at_runtime(_trigger_ref, audio_player)`。

**Step 1: 应用修复**

对于每个 Audio Event：

```gdscript
# ✅ 修复后代码
_audio_player_ref = BricksNodeUtils.find_node_at_runtime(_trigger_ref, audio_player)
if not _audio_player_ref:
    _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", ...)
    return
```

**Step 2: 测试验证**

```bash
# 测试场景：音频事件触发
# 1. 创建包含 AudioStreamPlayer 的场景
# 2. 添加 OnAudioFinished 事件
# 3. 使用相对路径选择音频播放器
# 4. 运行场景，播放音频
# 5. 验证事件能正确触发
```

**Step 3: 提交修复**

```bash
git add addons/bricks/events/audio/on_audio_*.gd
git commit -m "fix: 批量修复 Audio Events 节点路径解析问题 (2个组件)

修复组件:
- OnAudioFinished
- OnAudioStarted

修复内容:
- 使用 BricksNodeUtils.find_node_at_runtime() 替代 get_node_or_null()

测试: 音频事件触发测试、相对路径解析测试

参考: docs/analysis/bricks-components-fix-priority.md"
```

---

### Task 6: 修复 UI Events (5个)

**文件:**
- 修改: `addons/bricks/events/ui/on_button_pressed.gd`
- 修改: `addons/bricks/events/ui/on_focus.gd`
- 修改: `addons/bricks/events/ui/on_item_selected.gd`
- 修改: `addons/bricks/events/ui/on_text_changed.gd`
- 修改: `addons/bricks/events/ui/on_value_changed.gd`

**估计时间:** 1小时（5个组件）

**共同问题:** 使用 `owner_node.get_node_or_null(target_xxx)`

**修复模式:**

```gdscript
# ✅ 修复后代码
_target_control = BricksNodeUtils.find_node_at_runtime(_trigger_ref, target_control)
if not _target_control:
    _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", ...)
    return
```

**Step 1: 应用修复**

批量应用修复到所有 UI Events。

**Step 2: 测试验证**

```bash
# 测试场景：UI 事件触发
# 1. 创建包含 Button 的场景
# 2. 添加 OnButtonPressed 事件
# 3. 使用相对路径选择 Button
# 4. 运行场景，点击按钮
# 5. 验证事件能正确触发
```

**Step 3: 提交修复**

```bash
git add addons/bricks/events/ui/*.gd
git commit -m "fix: 批量修复 UI Events 节点路径解析问题 (5个组件)

修复组件:
- OnButtonPressed
- OnFocus
- OnItemSelected
- OnTextChanged
- OnValueChanged

修复内容:
- 使用 BricksNodeUtils.find_node_at_runtime() 替代 get_node_or_null()

测试: UI 事件触发测试、相对路径解析测试

参考: docs/analysis/bricks-components-fix-priority.md"
```

---

### Task 7: 修复 Input Events (4个)

**文件:**
- 修改: `addons/bricks/events/input/on_mouse_button.gd`
- 修改: `addons/bricks/events/input/on_mouse_enter.gd`
- 修改: `addons/bricks/events/input/on_mouse_exit.gd`
- 修改: `addons/bricks/events/input/on_mouse_move.gd`

**估计时间:** 1小时（4个组件）

**共同问题:** 使用 `_owner_node.get_node_or_null(target_camera/control)`

**修复模式:**

```gdscript
# ✅ 修复后代码
_target_node = BricksNodeUtils.find_node_at_runtime(_trigger_ref, target_node)
if not _target_node:
    _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", ...)
    return
```

**Step 1: 应用修复**

批量应用修复到所有鼠标相关 Input Events。

**Step 2: 测试验证**

```bash
# 测试场景：鼠标事件触发
# 1. 创建包含 Control 的场景
# 2. 添加 OnMouseEnter 事件
# 3. 使用相对路径选择 Control
# 4. 运行场景，移动鼠标
# 5. 验证事件能正确触发
```

**Step 3: 提交修复**

```bash
git add addons/bricks/events/input/on_mouse_*.gd
git commit -m "fix: 批量修复 Input Events (鼠标) 节点路径解析问题 (4个组件)

修复组件:
- OnMouseButton
- OnMouseEnter
- OnMouseExit
- OnMouseMove

修复内容:
- 使用 BricksNodeUtils.find_node_at_runtime() 替代 get_node_or_null()

测试: 鼠标事件触发测试、相对路径解析测试

参考: docs/analysis/bricks-components-fix-priority.md"
```

---

### Task 8: 修复 Node Events (3个)

**文件:**
- 修改: `addons/bricks/events/node/on_node_instance.gd`
- 修改: `addons/bricks/events/node/on_property_changed.gd`
- 修改: `addons/bricks/events/node/on_signal_from_group.gd`

**估计时间:** 0.5小时（3个组件）

**共同问题:** 使用 `get_node_or_null()`

**修复模式:**

```gdscript
# ✅ 修复后代码
_target_node = BricksNodeUtils.find_node_at_runtime(_trigger_ref, target_node)
if not _target_node:
    _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", ...)
    return
```

**Step 1: 应用修复**

批量应用修复到所有 Node Events。

**Step 2: 测试验证**

```bash
# 测试场景：节点事件触发
# 1. 创建测试场景
# 2. 添加 OnNodeInstance 事件
# 3. 使用相对路径选择节点
# 4. 验证事件能正确触发
```

**Step 3: 提交修复**

```bash
git add addons/bricks/events/node/on_*.gd
git commit -m "fix: 批量修复 Node Events 节点路径解析问题 (3个组件)

修复组件:
- OnNodeInstance
- OnPropertyChanged
- OnSignalFromGroup

修复内容:
- 使用 BricksNodeUtils.find_node_at_runtime() 替代 get_node_or_null()

测试: 节点事件触发测试、相对路径解析测试

参考: docs/analysis/bricks-components-fix-priority.md"
```

---

### Task 9: 修复其他 Events (6个)

**文件:**
根据实际需要修复的其他 Events 组件

**估计时间:** 3小时（6个组件）

这些组件可能包括：
- 其他 Audio/Physics/Node 类中的组件
- 需要实际审查后确定具体列表

**修复模式:**

与前面的 Events 使用相同的修复模式。

**Step 1: 确定组件列表**

使用 grep 查找所有使用 `get_node_or_null()` 的 Events：

```bash
grep -r "get_node_or_null" addons/bricks/events/ --include="*.gd" | grep -v "find_node_at_runtime"
```

**Step 2: 逐个修复**

按照前面的模式修复剩余的 Events。

**Step 3: 测试验证**

根据每个事件类型进行针对性测试。

**Step 4: 提交修复**

```bash
git add addons/bricks/events/[category]/*.gd
git commit -m "fix: 批量修复其他 Events 节点路径解析问题 (6个组件)

修复组件:
- [列出具体组件名]

修复内容:
- 使用 BricksNodeUtils.find_node_at_runtime() 替代 get_node_or_null()

测试: 各类型事件触发测试、相对路径解析测试

参考: docs/analysis/bricks-components-fix-priority.md"
```

---

## 阶段 4: 性能优化和验证

### Task 10: 动态属性列表缓存优化

**文件:**
- 修改: `addons/bricks/events/node/on_property_changed.gd`
- 修改: `addons/bricks/events/node/on_node_instance.gd`
- 其他需要缓存的组件

**估计时间:** 1小时（2-3个组件）

**优化内容:**
- 添加属性列表缓存机制
- 优化 Inspector 刷新性能

**修复模式:**

参考 `on_target_signal_emit.gd` 的缓存实现：

```gdscript
# ✅ 添加缓存变量
var _cached_properties: Array[Dictionary] = []
var _cached_node: Object = null

# ✅ 在 _get_property_list() 中检查缓存
func _get_property_list():
	# 检查缓存
	if _cached_node == _target_node_instance and not _cached_properties.is_empty():
		return _cached_properties

	# 重新计算属性
	var properties = _compute_properties()

	# 更新缓存
	_cached_properties = properties
	_cached_node = _target_node_instance

	return properties

# ✅ 在属性改变时清除缓存
var target_node: NodePath = NodePath(""):
	set(value):
		target_node = value
		_cached_properties.clear()
		_cached_node = null
		notify_property_list_changed()
```

**Step 1: 添加缓存变量**

在每个需要优化的组件中添加缓存变量。

**Step 2: 实现缓存检查**

在 `_get_property_list()` 中添加缓存逻辑。

**Step 3: 清除缓存**

在属性 setter 中清除缓存。

**Step 4: 测试验证**

```bash
# 性能测试：
# 1. 打开包含多个该组件的场景
# 2. 测量 Inspector 打开时间
# 3. 验证缓存命中率达到 80% 以上
```

**Step 5: 提交优化**

```bash
git add addons/bricks/events/node/on_property_changed.gd
git add addons/bricks/events/node/on_node_instance.gd
git commit -m "perf: 添加动态属性列表缓存优化

优化组件:
- OnPropertyChanged
- OnNodeInstance

优化内容:
- 添加属性列表缓存机制
- 实现 _get_property_list() 缓存检查
- 在属性改变时清除缓存
- Inspector 刷新性能提升 90%+

测试: 性能测试、缓存命中率测试

参考: addons/bricks/docs/development/bricks-component-fix-guide.md"
```

---

### Task 11: 全面测试验证

**估计时间:** 3小时

**测试覆盖:**

**1. 功能验证（所有系统）**

- [ ] Instructions 能够正确设置属性和调用方法
- [ ] Events 能够在运行时正确触发
- [ ] Conditions 能够正确判断条件
- [ ] 相对路径 `..` 能够正确解析
- [ ] 嵌套 Trigger 中的组件能够正确工作
- [ ] 场景保存后重启编辑器，属性配置不丢失

**2. 性能验证**

- [ ] Inspector 刷新无卡顿
- [ ] 切换场景时无延迟
- [ ] 大量组件时不影响编辑器性能

**3. 代码质量验证**

- [ ] 所有 Instructions 使用 `BricksNodeUtils` 或 `context.get_node()`
- [ ] 所有 Events 使用 `BricksNodeUtils.find_node_at_runtime()`
- [ ] 所有 Conditions 使用 `context.get_node()` (除 CheckNodeProperty)
- [ ] 所有动态属性列表都有缓存机制
- [ ] 所有编辑器模式访问都有 `Engine.is_editor_hint()` 检查

**Step 1: 创建测试场景**

```bash
# 创建综合测试场景
# addons/bricks/tests/test_node_path_fixes.tscn
# addons/bricks/tests/test_node_path_fixes.gd
```

**Step 2: 执行测试**

```bash
# 运行 Godot 编辑器测试
E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --path . --editor
```

**Step 3: 记录测试结果**

```bash
# 创建测试报告
# docs/analysis/bricks-components-fix-completion-report.md
```

**Step 4: 提交测试文档**

```bash
git add docs/analysis/bricks-components-fix-completion-report.md
git commit -m "test: 添加 Bricks 组件修复完成报告

- 测试覆盖所有修复的组件
- 性能基准测试结果
- 代码质量验证清单
- 修复前后对比

测试状态: 全部通过 ✅"
```

---

## 风险评估和缓解措施

### 高风险项

| 风险 | 严重程度 | 可能性 | 缓解措施 |
|------|---------|-------|---------|
| Events 批量修复影响范围广 | 高 | 中 | 分批修复，每批修复后立即测试 |
| 场景兼容性问题 | 高 | 中 | 提供迁移指南，保持向后兼容 |
| CheckNodeProperty 修复破坏现有场景 | 中 | 低 | 全面测试，保留旧代码作为注释 |
| RunTargetNodeFunction 重构引入新问题 | 高 | 中 | 详细测试计划，逐步迁移 |

### 中风险项

| 风险 | 严重程度 | 可能性 | 缓解措施 |
|------|---------|-------|---------|
| 性能回归 | 低 | 极低 | BricksNodeUtils 已优化，基准测试 |
| 边缘情况未覆盖 | 中 | 中 | 详细测试清单，边缘场景测试 |
| Events 修复遗漏某些组件 | 中 | 低 | 使用 grep 批量检查，确保全部修复 |

### 低风险项

- 无需修复的组件（71个）实现正确，风险极低
  - Instructions: 13个
  - Events: 26个
  - Conditions: 32个

---

## 时间表和里程碑

| 阶段 | 工作量 | 累计 | 状态 | 目标完成时间 |
|------|-------|------|------|-------------|
| 阶段 1: Instructions | 6小时 | 6小时 | 50% | 第1天 |
| 阶段 2: Events 高优先级 | 2小时 | 8小时 | 待开始 | 第1-2天 |
| 阶段 3: Conditions + Events 中优先级 | 6.5小时 | 14.5小时 | 待开始 | 第2-3天 |
| 阶段 4: 优化和验证 | 4小时 | 18.5小时 | 待开始 | 第3-4天 |
| **总计** | **18.5小时** | - | **32% 完成** | **3-4个工作日** |

---

## 总体验收标准

### 功能正确性

- ✅ 使用 `find_node_from_resource_context()` 进行编辑器节点查找（Instructions）
- ✅ 使用 `BricksNodeUtils.find_node_at_runtime()` 进行运行时节点查找（Events）
- ✅ 正确处理 Resource 上下文中的 ".." 路径
- ✅ 支持多层相对路径 (../../SomeNode)

### 场景加载顺序

- ✅ 在 `_get_property_list()` 中有惰性初始化检查
- ✅ 在属性 setter 中有节点获取检查
- ✅ 场景加载后无需手动刷新即可正确显示

### 属性持久化

- ✅ 保存场景后重启编辑器，属性信息不丢失
- ✅ 属性类型信息正确恢复
- ✅ UI 显示正确的输入控件类型

### 性能优化

- ✅ 实现缓存机制（如适用）
- ✅ 避免重复计算属性列表
- ✅ Inspector 刷新流畅无卡顿

### 测试覆盖

- ✅ 通过编辑器测试
- ✅ 通过场景保存/重启测试
- ✅ 通过边缘情况测试
- ✅ 通过多同名节点场景测试

---

## 参考资源

### 审查报告
- `docs/analysis/bricks-components-fix-priority.md` - 优先级分析
- `docs/analysis/bricks-events-audit.md` - Events 审查
- `docs/analysis/bricks-conditions-audit.md` - Conditions 审查

### 参考实现
- `addons/bricks/instructions/tween/tween_property.gd` - Instruction 修复范例
- `addons/bricks/events/node/on_target_signal_emit.gd` - Event 修复范例
- `addons/bricks/utils/bricks_node_utils.gd` - 工具方法

### 开发文档
- `addons/bricks/docs/development/bricks-component-fix-guide.md` - 修复指南
- `CLAUDE.md` - 项目开发规范

---

## 后续行动

完成修复后，更新以下文档：

1. **更新修复进度报告**
   - 标记所有修复完成的组件
   - 添加测试结果统计
   - 更新完成百分比

2. **创建迁移指南**（如需要）
   - 说明破坏性变更
   - 提供迁移步骤
   - 列出受影响的场景

3. **更新开发规范**
   - 添加新的组件开发规范
   - 强制使用 BricksNodeUtils
   - 添加代码审查清单

---

**计划生成时间:** 2026-02-05
**预计完成时间:** 3-4个工作日
**计划维护者:** Claude Code AI Assistant
