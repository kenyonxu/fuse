# Timeline Editor 目标高亮系统设计文档

> **创建日期:** 2025-01-12
> **状态:** 设计已完成，待实现

---

## 1. 概述

### 1.1 设计目标

在 Timeline Editor 中选择轨道时，在2D场景编辑器中绘制**彩色矩形框**标记目标节点，在场景树中使用**背景色高亮**对应节点，提供直观的空间位置反馈。

### 1.2 核心价值

- ✅ **可视化关联**：直观看到轨道与场景节点的对应关系
- ✅ **非侵入式**：不改变节点本身，只在绘制层添加标记
- ✅ **多轨道支持**：同时显示多个目标，使用不同颜色区分
- ✅ **自动清理**：轨道取消选择时自动移除标记

---

## 2. 系统架构

### 2.1 组件关系图

```
用户操作
    ↓
TrackEditor.track_selected 信号
    ↓
JuicyTimelineEditor._on_track_selected()
    ↓
TargetHighlightManager.add_highlight()
    ↓
┌─────────────────┬─────────────────┐
│                 │                 │
Scene编辑器绘制   Scene树高亮     Viewport重绘
(2D标记框)       (背景色)        (queue_redraw)
```

### 2.2 核心组件

**1. TargetHighlightManager**
- 位置：`addons/juicy_mixer/editor/target_highlight_manager.gd`
- 职责：管理活动高亮列表，协调绘制请求
- 类型：单例模式

**2. JuicyTimelineEditor**
- 修改：`_on_track_selected()` 连接高亮管理器
- 修改：轨道选择变化时更新高亮

**3. JuicyMixer Plugin**
- 修改：注册 `TargetHighlightManager` 类型
- 修改：实现 `forward_canvas_draw_pre_gui()` 绘制2D标记

**4. HighlightInfo 数据结构**
```gdscript
class HighlightInfo:
    extends RefCounted

    var track: JuicyTrack          # 来源轨道
    var node_path: NodePath         # 目标节点路径
    var color: Color                # 标记颜色（使用 track_color）
    var viewport: Viewport          # 所属视口
    var cached_global_rect: Rect2   # 缓存全局位置
```

---

## 3. 数据流设计

### 3.1 轨道选择流程

```
1. 用户点击轨道
   ↓
2. TrackEditor.track_selected.emit(track)
   ↓
3. TimelineEditor._on_track_selected(track)
   ├─ 原有逻辑：更新 UI
   └─ 新增：highlight_manager.add_highlight(track, viewport)
   ↓
4. HighlightManager 验证节点路径
   ├─ 获取当前编辑的场景根节点
   ├─ 通过 node_path 获取目标节点
   └─ 创建 HighlightInfo 并添加到 active_highlights
   ↓
5. 触发 viewport.queue_redraw()
   ↓
6. 下次场景绘制时
   Plugin.forward_canvas_draw_pre_gui() 被调用
   ↓
7. 遍历 active_highlights，绘制彩色矩形框
```

### 3.2 轨道取消选择流程

```
1. 用户点击空白区域
   ↓
2. TrackEditor.track_selected.emit(null)
   ↓
3. TimelineEditor 检测到 track == null
   ↓
4. highlight_manager.clear_all()
   ↓
5. viewport.queue_redraw()
   ↓
6. 标记消失
```

### 3.3 多轨道选择流程（Ctrl+Click）

```
1. 用户按住 Ctrl 点击多个轨道
   ↓
2. 每次选择都调用 add_highlight(track, viewport)
   ↓
3. active_highlights 包含多个 HighlightInfo
   ↓
4. 绘制时循环渲染，每个使用各自的 track_color
   ↓
5. 场景中显示多个不同颜色的标记框
```

---

## 4. 实现细节

### 4.1 TargetHighlightManager 核心实现

```gdscript
class_name TargetHighlightManager
extends RefCounted

static var instance: TargetHighlightManager
var active_highlights: Array[HighlightInfo] = []

static func get_instance() -> TargetHighlightManager:
    if not instance:
        instance = TargetHighlightManager.new()
    return instance

func add_highlight(track: JuicyTrack, viewport: Viewport) -> bool:
    """添加轨道目标的高亮"""
    if not track or track.target.is_empty():
        return false

    var node = _get_target_node(track.target, viewport)
    if not node:
        return false

    var info = HighlightInfo.new()
    info.track = track
    info.node_path = track.target
    info.color = track.track_color
    info.viewport = viewport
    info.cached_global_rect = _get_node_bounds(node)

    active_highlights.append(info)
    return true

func remove_highlights_for_track(track: JuicyTrack):
    """移除指定轨道的所有高亮"""
    active_highlights = active_highlights.filter(
        func(h): return h.track != track
    )

func clear_all():
    """清除所有高亮"""
    active_highlights.clear()

func get_visible_highlights(viewport: Viewport) -> Array[HighlightInfo]:
    """获取在指定视口中可见的高亮"""
    return active_highlights.filter(
        func(h): return h.viewport == viewport
    )

func cleanup_invalid_highlights():
    """清理无效的高亮（节点被删除等）"""
    active_highlights = active_highlights.filter(func(h):
        return h.is_valid() and _get_target_node(h.node_path, h.viewport) != null
    )

func _get_target_node(node_path: NodePath, viewport: Viewport) -> Node:
    """安全获取目标节点"""
    var edited_root = EditorInterface.get_edited_scene_root()
    if not edited_root:
        return null

    var node = edited_root.get_node_or_null(node_path)
    if node:
        return node

    # 尝试绝对路径
    if str(node_path).is_absolute():
        node = get_node_or_null(node_path)

    return node

func _get_node_bounds(node: Node) -> Rect2:
    """获取节点的绘制边界"""
    if node is Control:
        return node.get_global_rect()
    elif node is Node2D:
        var transform = node.get_global_transform()
        var size = _estimate_node2d_size(node)
        return Rect2(transform.get_origin(), size)
    else:
        return Rect2(0, 0, 32, 32)

func _estimate_node2d_size(node: Node2D) -> Vector2:
    """估算 Node2D 节点的大小"""
    # TODO: 根据节点类型返回合理的大小
    return Vector2(64, 64)
```

### 4.2 Plugin 绘制实现

**在 plugin.gd 中添加：**

```gdscript
func _enter_tree():
    # ... 现有代码 ...

    # 注册 TargetHighlightManager
    add_custom_type(
        "TargetHighlightManager",
        "RefCounted",
        preload("res://addons/juicy_mixer/editor/target_highlight_manager.gd"),
        preload("res://icon.svg")
    )

    # 获取高亮管理器实例
    var highlight_manager = TargetHighlightManager.get_instance()

func forward_canvas_draw_pre_gui(overlay: Control):
    """绘制2D场景叠加层"""
    var highlight_manager = TargetHighlightManager.get_instance()
    if not highlight_manager:
        return

    var highlights = highlight_manager.get_visible_highlights(overlay)
    if highlights.is_empty():
        return

    var canvas_transform = overlay.get_canvas_transform()
    var viewport_rect = overlay.get_visible_rect()

    for highlight in highlights:
        var rect = highlight.cached_global_rect

        # 视口裁剪
        if not viewport_rect.intersects(rect):
            continue

        # 转换到画布坐标系
        var canvas_rect = canvas_transform * rect

        # 绘制空心矩形框（3px宽）
        overlay.draw_rect(canvas_rect, highlight.color, false, 3.0)
```

### 4.3 TimelineEditor 集成

**修改 _on_track_selected() 函数：**

```gdscript
func _on_track_selected(track: JuicyTrack):
    """轨道选择处理"""

    # 原有逻辑...
    if timeline_canvas:
        timeline_canvas.select_track(track)

    # 更新智能操作区域
    _update_context_actions(track)

    # 🔥 新增：更新场景高亮
    _update_scene_highlight(track)

func _update_scene_highlight(track: JuicyTrack):
    """更新场景中的目标节点高亮"""
    var highlight_manager = TargetHighlightManager.get_instance()
    if not highlight_manager:
        return

    var viewport = EditorInterface.get_editor_viewport_2d()
    if not viewport:
        return

    if track:
        # 添加新的高亮（不清除之前的，支持多选）
        highlight_manager.add_highlight(track, viewport)
        viewport.queue_redraw()
    else:
        # 取消选择时清除所有高亮
        highlight_manager.clear_all()
        viewport.queue_redraw()
```

---

## 5. 错误处理和边界情况

### 5.1 节点有效性验证

- ✅ 目标节点被删除 → `cleanup_invalid_highlights()` 自动清理
- ✅ 目标路径错误 → `add_highlight()` 返回 false
- ✅ 场景切换 → 自动清理旧场景的高亮

### 5.2 节点类型兼容性

| 节点类型 | 边界获取方式 | 备注 |
|---------|-------------|------|
| Control | `get_global_rect()` | UI 节点 |
| Node2D | 全局变换 + 估算大小 | 需要估算 |
| 其他类型 | 使用默认 32x32 | 未来扩展 |

### 5.3 性能优化

- ✅ **视口裁剪**：只绘制可见区域内的标记
- ✅ **位置缓存**：避免每帧重新计算边界
- ✅ **自动清理**：无效高亮及时移除

---

## 6. 实现阶段

### Phase 1: 核心功能（MVP）

**目标：** 实现基础的单轨道目标标记

- [ ] 创建 `TargetHighlightManager.gd`
- [ ] 在 `plugin.gd` 中注册类型
- [ ] 在 `plugin.gd` 中实现 `forward_canvas_draw_pre_gui()`
- [ ] 修改 `JuicyTimelineEditor._on_track_selected()`
- [ ] 实现2D场景中绘制矩形框
- [ ] 处理轨道取消选择时清除标记
- [ ] 基础测试

**预期时间：** 2-3小时

### Phase 2: 多轨道支持

**目标：** 支持同时选中多个轨道

- [ ] 支持累积高亮（不清除之前的）
- [ ] 为每个轨道使用不同的颜色
- [ ] 优化多个标记的绘制性能
- [ ] 处理轨道切换时的标记更新
- [ ] 多轨道测试

**预期时间：** 1-2小时

### Phase 3: 场景树高亮

**目标：** 在场景树中高亮目标节点

- [ ] 扩展 `TargetHighlightManager` 管理场景树 TreeItem
- [ ] 实现 TreeItem 的背景色设置
- [ ] 处理场景树展开/折叠时的样式保持
- [ ] 添加节点名称旁的图标标记（可选）
- [ ] 场景树测试

**预期时间：** 2-3小时

### Phase 4: 完善和优化

**目标：** 完善细节，优化体验

- [ ] 自动清理机制实现
- [ ] 场景切换时的处理
- [ ] 3D场景支持（未来）
- [ ] 性能优化和测试
- [ ] 文档完善

**预期时间：** 1-2小时

---

## 7. 测试计划

### 7.1 Phase 1 测试用例

| 测试场景 | 预期结果 | 优先级 |
|---------|---------|-------|
| 选择单个 Property Track | 场景中显示彩色矩形框 | P0 |
| 取消选择 | 标记消失 | P0 |
| 选择没有目标的轨道 | 不显示标记 | P1 |
| 目标节点被删除 | 标记自动消失 | P1 |
| 选择轨道后切换场景 | 标记自动清理 | P2 |

### 7.2 Phase 2 测试用例

| 测试场景 | 预期结果 | 优先级 |
|---------|---------|-------|
| Ctrl+Click 选择2个轨道 | 显示2个不同颜色的标记 | P0 |
| 选中另一个轨道 | 所有标记保持显示 | P0 |
| 取消选择一个轨道 | 只移除对应标记 | P1 |
| 快速切换多个轨道 | 所有标记正确显示 | P2 |

### 7.3 Phase 3 测试用例

| 测试场景 | 预期结果 | 优先级 |
|---------|---------|-------|
| 选择轨道 | 场景树节点背景高亮 | P0 |
| 取消选择 | 高亮消失 | P0 |
| 多轨道选中 | 多个节点同时高亮 | P1 |
| 场景树展开/折叠 | 高亮样式保持 | P2 |

---

## 8. 相关文件

### 新建文件
- `addons/juicy_mixer/editor/target_highlight_manager.gd`

### 修改文件
- `addons/juicy_mixer/plugin.gd` - 注册类型，实现绘制
- `addons/juicy_mixer/editor/juicy_timeline_editor.gd` - 集成高亮管理

### 参考文档
- `docs/plans/2026-01-12-timeline-editor-universal-target-selection.md` - 之前的目标选择功能实现

---

## 9. 技术栈

- **Godot 4.5** GDScript
- **EditorPlugin** - 插件系统
- **forward_canvas_draw_pre_gui()** - 2D场景绘制
- **TreeItem.custom_bg_color** - 场景树高亮
- **EditorInterface** - 编辑器API

---

## 10. 总结

本设计方案通过在2D场景编辑器中绘制彩色矩形框和在场景树中使用背景色高亮，为用户提供了直观的目标节点视觉反馈。系统采用非侵入式设计，不修改场景节点本身，只在绘制层添加标记，支持多轨道同时选择，并能自动清理无效高亮。

**关键创新点：**
1. 跨编辑器集成（Timeline Editor → Scene Editor + Scene Tree）
2. 非侵入式可视化（绘制层叠加）
3. 多轨道智能标记（颜色区分）
4. 自动清理机制（无内存泄漏）

**用户价值：**
- 一目了然看到轨道控制哪个节点
- 快速定位和验证目标配置
- 提升编辑效率和准确性
