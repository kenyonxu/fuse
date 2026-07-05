# Method Track 交互增强设计

## 概述

为 JuicyMethodTrack 在 TimelineCanvas 中添加交互能力，提升可用性体验。

**设计日期**: 2025-01-13
**目标文件**: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd`

---

## 功能范围

1. **拖拽移动触发时间** - 支持时间吸附
2. **选中状态高亮** - 使用编辑器图标 + 显示额外信息
3. **重复触发视觉化** - 主触发点（可拖拽）+ 重复触发标记（仅视觉）

**排除的功能**（留待后续迭代）:
- 双击编辑
- 右键菜单（将统一考虑所有 Track 类型）

---

## 架构设计

### 新增状态变量

```gdscript
# Method Track 交互状态
var selected_method_track: JuicyMethodTrack = null  # 当前选中的Method Track
var method_track_drag_mode: int = 0                  # 0=无, 1=移动触发时间
var method_track_drag_start_data: Dictionary          # 保存拖拽开始时的数据
```

### 视觉层次

```
├── 主触发点 (trigger_time)
│   ├── 可拖拽图标 (KeyBezierPoint / KeySelected)
│   ├── 方法名
│   └── 选中时显示: 触发时间、重复间隔信息
│
└── 重复触发点
    └── 弱化色块标记 (半透明紫色，不可拖拽)
```

---

## 函数设计

### 1. `_get_method_track_at_position(pos: Vector2) -> Dictionary`

检测鼠标位置是否有 Method Track 标记。

**返回值**: `{track: JuicyMethodTrack, region: int}`
- `track`: 命中的 Method Track，无则 `null`
- `region`: 固定为 `0`（标记主体）

**检测范围**: 标记左右各 6 像素，提高可点击性

---

### 2. `_calculate_method_trigger_times(track: JuicyMethodTrack) -> Array[float]`

计算所有触发时间点（主触发 + 重复触发）。

**逻辑**:
```gdscript
times = [trigger_time]
if repeat_interval > 0:
    for i in 1..max_repeats:
        times.append(trigger_time + i * repeat_interval)
```

---

### 3. `_draw_method_track(track, track_rect)` - 重写

绘制 Method Track 的入口函数。

**流程**:
1. 计算所有触发时间点
2. 遍历每个触发时间:
   - 主触发点: 调用 `_draw_primary_method_trigger()`
   - 重复触发点: 调用 `_draw_repeat_method_marker()`

---

### 4. `_draw_primary_method_trigger(track, x, y, track_rect)`

绘制主触发点（可拖拽）。

**视觉元素**:
- 图标: `KeyBezierPoint` (默认) / `KeySelected` (选中)
- 方法名文本
- 选中时显示:
  - 触发时间 (Cyan)
  - 重复间隔信息 (Gray, 如果有)

---

### 5. `_draw_repeat_method_marker(x, y, track_rect)`

绘制重复触发标记（弱化视觉）。

**视觉元素**:
- 8x8 半透明紫色矩形 (`Color(0.8, 0.2, 0.8, 0.4)`)
- 无文本，无交互

---

### 6. 拖拽处理函数

#### `_handle_method_track_selection(track, pos)`
- 设置 `selected_method_track`
- 保存拖拽起始数据
- 发送 `track_selected` 信号

#### `_handle_method_track_drag(pos)`
- 计算新的 `trigger_time`
- 应用时间吸附 (`snap_enabled`)
- 更新 `trigger_time`

#### `_handle_method_track_release()`
- 验证 `trigger_time >= 0`
- 清理拖拽状态
- 发送 `timeline_changed` 信号

---

## 交互流程

### 点击选择

```
用户点击 → _get_method_track_at_position() 检测
         ↓
    _handle_method_track_selection()
         ↓
    设置 selected_method_track
         ↓
    重绘 (显示选中状态 + 额外信息)
```

### 拖拽移动

```
用户拖动 → _handle_mouse_motion() 检测 is_dragging
         ↓
    _handle_method_track_drag()
         ↓
    计算新时间 (支持吸附)
         ↓
    更新 trigger_time
         ↓
    重绘 + 发送 timeline_changed
```

### 释放

```
用户释放 → _handle_left_release()
         ↓
    _handle_method_track_release()
         ↓
    验证数据 + 清理状态
         ↓
    发送 timeline_changed
```

---

## 修改现有函数

### `_handle_left_click(pos)`

在检测关键帧和 Clip 之前，优先检测 Method Track:

```gdscript
# 优先检查 Method Track
var method_result = _get_method_track_at_position(pos)
if method_result.track:
    _handle_method_track_selection(method_result.track, pos)
    return

# 原有的 Clip 和 Property Track 检测...
```

### `_handle_mouse_motion(event)`

添加 Method Track 拖拽处理:

```gdscript
# Method Track 拖拽逻辑
if is_dragging and selected_method_track and method_track_drag_mode > 0:
    _handle_method_track_drag(event.position)
    return

# 原有的关键帧和 Clip 拖拽...
```

### `_handle_left_release()`

添加 Method Track 释放处理:

```gdscript
# Method Track 拖拽释放
if is_dragging and selected_method_track and method_track_drag_mode > 0:
    _handle_method_track_release()

# 原有的释放处理...
```

---

## 视觉规范

| 状态 | 图标 | 颜色 | 信息显示 |
|------|------|------|----------|
| 默认 | KeyBezierPoint | 紫色 | 方法名 |
| 选中 | KeySelected | 黄色边框 | 方法名 + 触发时间 + 重复间隔 |
| 悬停 | - | - | 鼠标指针变化 |
| 重复触发 | - | 半透明紫色 | 无 |

---

## 实施检查清单

- [ ] 添加状态变量
- [ ] 实现 `_get_method_track_at_position()`
- [ ] 实现 `_calculate_method_trigger_times()`
- [ ] 实现 `_draw_repeat_method_marker()`
- [ ] 实现 `_draw_primary_method_trigger()`
- [ ] 重写 `_draw_method_track()`
- [ ] 修改 `_handle_left_click()`
- [ ] 修改 `_handle_mouse_motion()`
- [ ] 修改 `_handle_left_release()`
- [ ] 测试拖拽功能
- [ ] 测试时间吸附
- [ ] 测试重复触发显示
- [ ] 测试选中状态高亮

---

## 未来改进方向

1. **双击编辑** - 打开方法/参数编辑对话框
2. **右键菜单** - 统一所有 Track 类型的右键菜单
3. **参数预览** - 在时间轴上直接显示参数值
4. **批量操作** - 同时选择多个 Method Track 进行编辑
