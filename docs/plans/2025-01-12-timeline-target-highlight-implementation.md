# Timeline Editor 目标高亮系统实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 Timeline Editor 中选择轨道时，在2D场景编辑器中绘制彩色矩形框标记目标节点，在场景树中使用背景色高亮对应节点，提供直观的空间位置反馈。

**Architecture:** 基于 EditorPlugin 的 forward_canvas_draw_pre_gui() 在2D场景绘制层叠加标记，使用 TargetHighlightManager 单例管理活动高亮列表，非侵入式可视化设计。

**Tech Stack:** Godot 4.5 GDScript, EditorPlugin, forward_canvas_draw_pre_gui(), TreeItem.custom_bg_color

---

## Task 1: 创建 TargetHighlightManager 核心类

**Files:**
- Create: `addons/juicy_mixer/editor/target_highlight_manager.gd`

**Step 1: 创建 TargetHighlightManager 类文件**

创建 `target_highlight_manager.gd` 文件，包含以下完整代码：

```gdscript
# TargetHighlightManager - 目标节点高亮管理器
# 管理场景编辑器和场景树中的目标节点高亮显示

class_name TargetHighlightManager
extends RefCounted

## 高亮信息数据结构
class HighlightInfo:
	extends RefCounted

	var track: JuicyTrack          # 来源轨道
	var node_path: NodePath         # 目标节点路径
	var color: Color                # 标记颜色（使用 track_color）
	var viewport: Viewport          # 所属视口
	var cached_global_rect: Rect2   # 缓存全局位置，减少每帧计算

	func is_valid() -> bool:
		"""检查高亮是否仍然有效"""
		return track != null and not track.target.is_empty()

static var instance: TargetHighlightManager = null

## 活动高亮列表
var active_highlights: Array[HighlightInfo] = []

## 单例模式
static func get_instance() -> TargetHighlightManager:
	"""获取高亮管理器单例"""
	if not instance:
		instance = TargetHighlightManager.new()
	return instance

## 添加轨道目标的高亮
func add_highlight(track: JuicyTrack, viewport: Viewport) -> bool:
	"""添加轨道目标的高亮

	@param track: 要高亮的轨道
	@param viewport: 目标视口
	@return: 成功返回 true，失败返回 false
	"""
	if not track or track.target.is_empty():
		return false

	var node = _get_target_node(track.target, viewport)
	if not node:
		return false

	# 检查是否已存在该轨道的高亮
	for highlight in active_highlights:
		if highlight.track == track:
			# 更新颜色和缓存位置
			highlight.color = track.track_color
			highlight.cached_global_rect = _get_node_bounds(node)
			return true

	# 创建新的高亮信息
	var info = HighlightInfo.new()
	info.track = track
	info.node_path = track.target
	info.color = track.track_color
	info.viewport = viewport
	info.cached_global_rect = _get_node_bounds(node)

	active_highlights.append(info)
	return true

## 移除指定轨道的所有高亮
func remove_highlights_for_track(track: JuicyTrack):
	"""移除指定轨道的所有高亮

	@param track: 要移除高亮的轨道
	"""
	active_highlights = active_highlights.filter(
		func(h): return h.track != track
	)

## 清除所有高亮
func clear_all():
	"""清除所有高亮"""
	active_highlights.clear()

## 获取在指定视口中可见的高亮
func get_visible_highlights(viewport: Viewport) -> Array[HighlightInfo]:
	"""获取在指定视口中可见的高亮

	@param viewport: 目标视口
	@return: 高亮信息数组
	"""
	return active_highlights.filter(
		func(h): return h.viewport == viewport
	)

## 清理无效的高亮
func cleanup_invalid_highlights():
	"""清理无效的高亮（节点被删除等）"""
	active_highlights = active_highlights.filter(func(h):
		if not h.is_valid():
			return false
		return _get_target_node(h.node_path, h.viewport) != null
	)

## 安全获取目标节点
func _get_target_node(node_path: NodePath, viewport: Viewport) -> Node:
	"""安全获取目标节点，处理各种边界情况

	@param node_path: 节点路径
	@param viewport: 视口（用于获取编辑场景）
	@return: 目标节点，失败返回 null
	"""
	# 1. 获取当前编辑的场景根节点
	var edited_root = EditorInterface.get_edited_scene_root()
	if not edited_root:
		return null

	# 2. 尝试使用相对路径获取节点
	var node = edited_root.get_node_or_null(node_path)
	if node:
		return node

	# 3. 尝试绝对路径（向后兼容）
	if str(node_path).is_absolute():
		node = get_node_or_null(node_path)

	return node

## 获取节点的绘制边界
func _get_node_bounds(node: Node) -> Rect2:
	"""获取节点的绘制边界

	@param node: 目标节点
	@return: 节点的全局边界矩形
	"""
	# Control 节点（UI）
	if node is Control:
		return node.get_global_rect()

	# Node2D 节点
	elif node is Node2D:
		var transform = node.get_global_transform()
		var size = _estimate_node2d_size(node)
		return Rect2(transform.get_origin(), size)

	# 其他类型节点（使用默认大小）
	else:
		var transform = node.get_global_transform() if node.has_method("get_global_transform") else Transform2D()
		return Rect2(transform.get_origin(), Vector2(32, 32))

## 估算 Node2D 节点的大小
func _estimate_node2d_size(node: Node2D) -> Vector2:
	"""估算 Node2D 节点的大小

	@param node: Node2D 节点
	@return: 估算的大小
	"""
	# 尝试从节点的属性获取大小信息
	if node.has_method("get_size"):
		var size = node.call("get_size")
		if size is Vector2:
			return size

	# 根据节点类型返回合理的大小
	if node is Sprite2D:
		if node.texture:
			return node.texture.get_size() * node.scale
		return Vector2(64, 64)
	elif node is Label:
		var theme = ThemeDB.get_default_theme()
		if theme:
			var font = theme.get_font(&"font&quot;, &quot;Label&quot;)
			if font:
				return font.get_string_size(node.text)
		return Vector2(100, 20)
	elif node is TileMap:
		return Vector2(128, 128)
	else:
		# 默认大小
		return Vector2(64, 64)
```

**Step 2: 提交 TargetHighlightManager 创建**

```bash
git add addons/juicy_mixer/editor/target_highlight_manager.gd
git commit -m "feat(timeline): 创建 TargetHighlightManager

- 实现高亮管理器单例模式
- 支持 HighlightInfo 数据结构
- 提供添加/移除/清理高亮的接口
- 处理多种节点类型的边界计算
- 安全的节点获取和验证

相关: docs/plans/2025-01-12-timeline-target-highlight-system.md Task 1"
```

---

## Task 2: 在 plugin.gd 中注册 TargetHighlightManager 类型

**Files:**
- Modify: `addons/juicy_mixer/plugin.gd`

**Step 1: 添加 TargetHighlightManager 的 preload 声明**

在文件顶部的 preload 区域（约 line 8 之后）添加：

```gdscript
const TargetHighlightManager = preload("res://addons/juicy_mixer/editor/target_highlight_manager.gd")
```

**Step 2: 在 _enter_tree() 中注册类型**

在 `_enter_tree()` 函数中（约 line 278 之后，在 `add_custom_type("JuicyTimelineResource")` 之前）添加：

```gdscript
	# 注册目标高亮管理器
	add_custom_type(
		"TargetHighlightManager",
		"RefCounted",
		TargetHighlightManager,
		preload("res://icon.svg")
	)
```

**Step 3: 在 _exit_tree() 中移除类型**

在 `_exit_tree()` 函数中（约 line 363 之后）添加：

```gdscript
	# 移除目标高亮管理器
	remove_custom_type("TargetHighlightManager")
```

**Step 4: 提交类型注册修改**

```bash
git add addons/juicy_mixer/plugin.gd
git commit -m "feat(timeline): 注册 TargetHighlightManager 类型

- 在 plugin.gd 中注册 TargetHighlightManager
- 支持类型系统的自动加载
- 在插件卸载时正确清理类型

相关: docs/plans/2025-01-12-timeline-target-highlight-system.md Task 2"
```

---

## Task 3: 在 plugin.gd 中实现 forward_canvas_draw_pre_gui

**Files:**
- Modify: `addons/juicy_mixer/plugin.gd`

**Step 1: 添加类成员变量**

在类的顶部变量声明区域（约 line 12 之后）添加：

```gdscript
var highlight_manager: RefCounted
```

**Step 2: 在 _enter_tree() 中初始化高亮管理器**

在 `_enter_tree()` 函数中（约 line 304 之前，在 `print("JuicyMixer V3 plugin enabled")` 之前）添加：

```gdscript
	# 初始化目标高亮管理器
	highlight_manager = TargetHighlightManager.get_instance()
```

**Step 3: 实现 forward_canvas_draw_pre_gui() 方法**

在类的底部（约 line 456 之后，`_on_file_selected()` 函数之后）添加：

```gdscript
func forward_canvas_draw_pre_gui(overlay: Control):
	"""绘制2D场景叠加层 - 用于显示目标节点高亮标记"""
	if not highlight_manager:
		return

	var highlights = highlight_manager.get_visible_highlights(overlay)
	if highlights.is_empty():
		return

	var canvas_transform = overlay.get_canvas_transform()
	var viewport_rect = overlay.get_visible_rect()

	for highlight in highlights:
		var rect = highlight.cached_global_rect

		# 视口裁剪：只绘制可见区域内的标记
		if not viewport_rect.intersects(rect):
			continue

		# 转换到画布坐标系
		var canvas_rect = canvas_transform * rect

		# 绘制空心矩形框（3px宽，使用轨道颜色）
		overlay.draw_rect(canvas_rect, highlight.color, false, 3.0)
```

**Step 4: 提交绘制功能实现**

```bash
git add addons/juicy_mixer/plugin.gd
git commit -m "feat(timeline): 实现 forward_canvas_draw_pre_gui 绘制目标标记

- 在 plugin.gd 中实现 forward_canvas_draw_pre_gui()
- 遍历活动高亮并在2D场景中绘制矩形框
- 使用视口裁剪优化性能
- 使用轨道颜色绘制3px宽空心矩形

相关: docs/plans/2025-01-12-timeline-target-highlight-system.md Task 3"
```

---

## Task 4: 在 JuicyTimelineEditor 中集成高亮管理器

**Files:**
- Modify: `addons/juicy_mixer/editor/juicy_timeline_editor.gd`

**Step 1: 添加 _update_scene_highlight() 方法**

在 `JuicyTimelineEditor` 类中添加新方法（建议放在 `_on_track_selected()` 函数附近，约 line 605 之后）：

```gdscript
## 更新场景中的目标节点高亮
func _update_scene_highlight(track: JuicyTrack):
	"""更新场景中的目标节点高亮

	@param track: 选中的轨道，null 表示取消选择
	"""
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

**Step 2: 在 _on_track_selected() 中调用高亮更新**

找到 `_on_track_selected()` 函数（约 line 605），在函数末尾添加调用：

```gdscript
func _on_track_selected(track: JuicyTrack):
	print("TimelineEditor: _on_track_selected() 被调用，track = ", track.track_name if track else "null")
	if timeline_canvas:
		timeline_canvas.select_track(track)
		print("TimelineEditor: 已调用timeline_canvas.select_track()")

	# 不在这里直接操作按钮，完全由_update_context_actions处理
	# 更新智能操作区域
	_update_context_actions(track)

	# 直接更新目标节点提示（避免依赖get_selected_track()的返回值）
	if track and track is JuicyPropertyTrack:
		var property_track = track as JuicyPropertyTrack
		update_target_node_hint_from_track(property_track)

	# 🔥 新增：更新场景高亮
	_update_scene_highlight(track)
```

**Step 3: 测试基础功能**

在 Godot Editor 中：
1. 打开包含 Timeline 的场景（如 `demos/bricks_juicy_demo.tscn`）
2. 选择一个有目标的 Property Track
3. 观察2D场景编辑器中是否出现彩色矩形框
4. 取消选择轨道，观察矩形框是否消失

**预期结果：**
- ✅ 选择轨道后，目标节点周围出现彩色矩形框
- ✅ 矩形框颜色与轨道的 track_color 一致
- ✅ 取消选择后，矩形框消失
- ❌ 如果没有出现，检查控制台是否有错误

**Step 4: 提交集成代码**

```bash
git add addons/juicy_mixer/editor/juicy_timeline_editor.gd
git commit -m "feat(timeline): 集成目标高亮管理器到 Timeline Editor

- 添加 _update_scene_highlight() 方法
- 在轨道选择时自动更新场景高亮
- 取消选择时清除所有高亮
- 实现基础的2D场景标记框显示

相关: docs/plans/2025-01-12-timeline-target-highlight-system.md Task 4"
```

---

## Task 5: 优化和清理

**Files:**
- Modify: `addons/juicy_mixer/editor/target_highlight_manager.gd`

**Step 1: 添加自动清理机制**

在 `TargetHighlightManager` 类中添加场景变化监听（在类定义的适当位置）：

```gdscript
## 自动清理机制
func _init():
	"""初始化时连接场景变化信号"""
	# 监听场景变化，自动清理无效高亮
	EditorInterface.get_singleton().scene_changed.connect(_on_scene_changed)

func _on_scene_changed(scene_root: Node):
	"""场景切换时自动清理无效高亮

	@param scene_root: 新的场景根节点
	"""
	cleanup_invalid_highlights()

	# 触发场景重绘
	var viewport = EditorInterface.get_editor_viewport_2d()
	if viewport:
		viewport.queue_redraw()
```

**Step 2: 添加调试支持方法（可选）**

在 `TargetHighlightManager` 类中添加调试方法（便于排查问题）：

```gdscript
## 调试信息
func get_debug_info() -> String:
	"""获取调试信息"""
	var info = "TargetHighlightManager 活动高亮:\n"
	for i in range(active_highlights.size()):
		var h = active_highlights[i]
		info += "  [%d] 轨道: %s, 目标: %s, 颜色: %s\n" % [
			i,
			h.track.track_name if h.track else "null",
			h.node_path,
			h.color
		]
	return info
```

**Step 3: 移除调试日志（如果不需要）**

检查所有文件，移除不必要的 `print()` 调试语句（保留关键的错误日志）。

**Step 4: 提交优化代码**

```bash
git add addons/juicy_mixer/editor/target_highlight_manager.gd
git commit -m "feat(timeline): 添加高亮自动清理和调试支持

- 添加场景变化监听，自动清理无效高亮
- 添加 get_debug_info() 方法便于调试
- 优化高亮管理器的生命周期处理

相关: docs/plans/2025-01-12-timeline-target-highlight-system.md Task 5"
```

---

## Task 6: 实现多轨道同时选择支持

**Files:**
- No file changes needed (already supported)

**Step 1: 测试多轨道选择**

在 Godot Editor 中：
1. 打开包含 Timeline 的场景
2. 按住 Ctrl 键点击多个轨道
3. 观察2D场景编辑器中是否显示多个不同颜色的矩形框
4. 取消选择其中一个轨道，观察是否只移除对应标记

**预期结果：**
- ✅ 每个选中的轨道都有独立的标记框
- ✅ 标记框颜色与各自的 track_color 一致
- ✅ 取消选择一个轨道时，只移除对应的标记
- ❌ 如果所有标记都消失了，说明需要调试

**Step 2: 如果多轨道选择不工作，检查代码**

检查 `_update_scene_highlight()` 函数，确保调用的是 `add_highlight()` 而不是 `clear_all()`：

```gdscript
func _update_scene_highlight(track: JuicyTrack):
	# ... 现有代码 ...

	if track:
		# 这会累积添加，不清除之前的
		highlight_manager.add_highlight(track, viewport)
		viewport.queue_redraw()
	else:
		# 只有在 track 为 null 时才清除所有
		highlight_manager.clear_all()
		viewport.queue_redraw()
```

**Step 3: 提交多轨道支持（如果需要修改）**

如果没有需要修改的代码，跳过此步骤。如果进行了修改，提交：

```bash
git add addons/juicy_mixer/editor/juicy_timeline_editor.gd
git commit -m "feat(timeline): 支持多轨道同时高亮

- 优化 _update_scene_highlight() 支持累积高亮
- 每个轨道使用独立的颜色标记
- 取消选择时只移除对应轨道的标记

相关: docs/plans/2025-01-12-timeline-target-highlight-system.md Task 6"
```

---

## Task 7: 完善文档和注释

**Files:**
- Modify: `addons/juicy_mixer/editor/target_highlight_manager.gd`
- Create: `docs/juicy_mixer/target-highlight-system.md`

**Step 1: 添加完善的文件头注释**

在 `target_highlight_manager.gd` 文件顶部添加详细注释：

```gdscript
# TargetHighlightManager - 目标节点高亮管理器
#
# 功能说明：
# - 管理场景编辑器和场景树中的目标节点高亮显示
# - 在2D场景编辑器中绘制彩色矩形框标记目标节点
# - 支持多轨道同时选择，使用不同颜色区分
# - 自动清理无效节点的高亮，避免内存泄漏
#
# 使用方式：
# var manager = TargetHighlightManager.get_instance()
# manager.add_highlight(track, viewport)
# manager.clear_all()
#
# 架构：
# - 单例模式：全局唯一实例
# - HighlightInfo：高亮信息数据结构
# - 非 RTI：每帧动态绘制，不保存绘制状态
#
# 相关类：
# - JuicyTimelineEditor: 轨道选择监听
# - JuicyMixer Plugin: 场景绘制层
#
# @see docs/juicy_mixer/target-highlight-system.md
```

**Step 2: 创建用户文档**

创建 `docs/juicy_mixer/target-highlight-system.md`:

````markdown
# 目标高亮系统使用文档

## 概述

目标高亮系统在 Timeline Editor 中选择轨道时，在2D场景编辑器中显示彩色矩形框，帮助用户直观地看到轨道控制哪个场景节点。

## 功能特性

### 1. 自动高亮
- 在 Timeline Editor 中选择轨道时自动显示
- 取消选择时自动清除
- 无需手动操作

### 2. 多轨道支持
- 支持同时选择多个轨道（Ctrl+Click）
- 每个轨道使用不同的颜色
- 独立管理每个轨道的标记

### 3. 智能清理
- 节点被删除时自动清理标记
- 场景切换时自动清理
- 避免内存泄漏

## 视觉反馈

### 2D场景标记
- **外观**：空心矩形框，3px宽
- **颜色**：使用轨道的 track_color
- **位置**：覆盖目标节点的边界

### 多轨道示例
```
轨道1（红色）→ 目标节点显示红色矩形框
轨道2（蓝色）→ 目标节点显示蓝色矩形框
轨道3（绿色）→ 目标节点显示绿色矩形框
```

## 技术实现

- **EditorPlugin**: 使用 forward_canvas_draw_pre_gui() 绘制
- **TargetHighlightManager**: 单例模式管理高亮列表
- **视口裁剪**: 只绘制可见区域内的标记
- **性能优化**: 缓存节点边界，避免每帧计算

## 相关文件

- `addons/juicy_mixer/editor/target_highlight_manager.gd` - 高亮管理器
- `addons/juicy_mixer/plugin.gd` - 插件绘制层
- `addons/juicy_mixer/editor/juicy_timeline_editor.gd` - 集成点
``````

**Step 3: 提交文档完善**

```bash
git add addons/juicy_mixer/editor/target_highlight_manager.gd docs/juicy_mixer/target-highlight-system.md
git commit -m "docs(timeline): 完善目标高亮系统文档

- 添加详细的文件头注释
- 创建用户使用文档
- 说明功能特性和技术实现

相关: docs/plans/2025-01-12-timeline-target-highlight-system.md Task 7"
```

---

## Task 8: 最终测试和验证

**Files:**
- No file creation

**Step 1: 完整功能测试**

在 Godot Editor 中进行完整测试：

### 测试用例 1: 单轨道选择
1. 打开 `demos/bricks_juicy_demo.tscn`
2. 选择一个有目标的 Property Track
3. **验证**：2D场景编辑器中显示彩色矩形框
4. 记录矩形框的颜色和位置

### 测试用例 2: 轨道取消选择
1. 点击空白区域取消选择
2. **验证**：矩形框消失
3. **验证**：没有残留标记

### 测试用例 3: 多轨道选择
1. 按住 Ctrl 键点击多个轨道
2. **验证**：每个轨道都有独立的标记框
3. **验证**：标记框颜色不同
4. 记录各颜色是否与 track_color 一致

### 测试用例 4: 轨道切换
1. 快速切换不同的轨道
2. **验证**：标记框正确切换
3. **验证**：没有延迟或卡顿

### 测试用例 5: 目标节点删除
1. 选择一个轨道
2. 在场景树中删除目标节点
3. **验证**：标记框自动消失（或下次绘制时消失）

### 测试用例 6: 场景切换
1. 选择一个轨道，确认标记显示
2. 切换到另一个场景
3. **验证**：旧场景的标记被清理
4. **验证**：没有错误或警告

**Step 2: 性能检查**

1. 选择10个轨道（如果场景中有）
2. 观察编辑器性能
3. **验证**：没有明显的帧率下降
4. **验证**：标记框绘制流畅

**Step 3: 错误处理检查**

打开 Godot 编辑器的控制台，观察是否有：
- 节点路径错误
- 空引用错误
- 类型转换错误

**Step 4: 代码审查清单**

- [ ] 所有公开函数都有文档注释
- [ ] 代码风格一致（Tab 缩进）
- [ ] 没有调试用的 print() 残留
- [ ] 变量命名清晰
- [ ] 没有硬编码的值（除了常量）
- [ ] 错误处理完善

**Step 5: 提交最终版本**

如果进行了任何小的调整或修复，提交：

```bash
git add addons/juicy_mixer/editor/target_highlight_manager.gd
git commit -m "fix(timeline): 修复高亮系统问题并完善实现

- 修复多轨道选择时的颜色正确性
- 优化标记框的绘制性能
- 完善错误处理和边界情况
- 通过所有测试用例

相关: docs/plans/2025-01-12-timeline-target-highlight-system.md Task 8"
```

---

## 总结

### 实现的功能

✅ **TargetHighlightManager** - 高亮管理器单例
✅ **2D场景标记框** - 在场景编辑器中绘制彩色矩形框
✅ **多轨道支持** - 同时显示多个不同颜色的标记
✅ **自动清理** - 节点删除或场景切换时自动清理
✅ **非侵入式** - 不修改场景节点，只在绘制层显示

### 文件修改

- **新建**: `addons/juicy_mixer/editor/target_highlight_manager.gd`
- **修改**: `addons/juicy_mixer/plugin.gd` - 注册类型，实现绘制
- **修改**: `addons/juicy_mixer/editor/juicy_timeline_editor.gd` - 集成高亮管理

### 用户价值

- 🎯 **可视化关联** - 一目了然看到轨道控制哪个节点
- 🚀 **快速定位** - 快速找到目标节点在场景中的位置
- ✅ **准确性验证** - 直观验证目标配置是否正确
- 💪 **提升效率** - 减少在场景树中手动查找节点的时间
