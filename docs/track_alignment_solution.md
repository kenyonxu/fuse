# 轨道编辑器对齐解决方案 - 动态可见性同步方案

## 概述

本文档详细说明了如何解决时间轴编辑器中左侧轨道列表（Tree）与右侧时间轴画布（Canvas）之间的对齐问题，特别是在支持分类折叠的场景下。

**核心思路**：当左侧折叠/展开分类时，右侧同步隐藏/显示对应轨道，确保两侧显示的轨道始终保持一致。

## 问题分析

### 当前架构

```
┌─────────────────────────────────────────────────────────┐
│  JuicyTimelineEditor (主编辑器)                        │
│  ┌───────────────────────────────────────────────────┐  │
│  │  HSplitContainer (水平分割容器)                 │  │
│  │  ┌──────────────┬─────────────────────────────┐  │  │
│  │  │ JuicyTrack   │  VBoxContainer            │  │  │
│  │  │ Editor       │  ├─ JuicyTimeRuler        │  │  │
│  │  │ (Tree)       │  ├─ JuicyTimelineCanvas  │  │  │
│  │  │              │  └─ HScrollBar           │  │  │
│  │  │ - 属性轨道    │                          │  │  │
│  │  │   ├ 轨道1    │  时间轴画布显示所有轨道   │  │  │
│  │  │   └ 轨道2    │                          │  │  │
│  │  │ - 反馈轨道    │                          │  │  │
│  │  │   └ 轨道3    │                          │  │  │
│  │  └──────────────┴─────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### 主要问题

1. **轨道高度不一致**
   - `JuicyTrackEditor.track_item_height = 24`
   - `JuicyTimelineCanvas.track_height = 30.0`

2. **滚动不同步**
   - 左侧 `Tree` 有自己的滚动机制
   - 右侧 `Canvas` 是自定义绘制，滚动独立

3. **折叠导致错位**
   - 左侧分类折叠后，轨道数量减少
   - 右侧仍显示所有轨道，导致对齐失败

## 解决方案设计

### 架构设计

```
┌─────────────────────────────────────────────────────────────────────┐
│  信号流                                                         │
│                                                                 │
│  Tree.item_collapsed                                              │
│       ↓                                                         │
│  TrackEditor._on_item_collapsed()                                │
│       ↓                                                         │
│  TrackEditor.category_toggled(category_name, is_expanded)         │
│       ↓                                                         │
│  TimelineEditor._on_category_toggled(category_name, is_expanded)   │
│       ↓                                                         │
│  TimelineCanvas.set_category_visible(category_name, visible)        │
│       ↓                                                         │
│  TimelineCanvas._update_visible_tracks()                           │
│       ↓                                                         │
│  TimelineCanvas.queue_redraw()                                    │
└─────────────────────────────────────────────────────────────────────┘
```

### 核心概念

**可见轨道数组**：`TimelineCanvas` 维护一个 `visible_tracks` 数组，只包含当前应该显示的轨道。

**隐藏分类列表**：维护一个 `hidden_categories` 数组，记录所有被折叠的分类名称。

**统一轨道高度**：在 `TimelineEditor` 中定义共享常量，确保两侧使用相同的轨道高度。

## 实施步骤

### 步骤 1：定义共享常量

**文件**：`addons/juicy_mixer/editor/juicy_timeline_editor.gd`

在类开头添加轨道高度常量：

```gdscript
# 轨道高度配置（与 JuicyTimelineCanvas 和 JuicyTrackEditor 共享）
const TRACK_HEIGHT = 30.0
const TRACK_SPACING = 2.0
```

### 步骤 2：修改 JuicyTrackEditor

**文件**：`addons/juicy_mixer/editor/juicy_track_editor.gd`

#### 2.1 添加分类切换信号

在信号声明区域添加：

```gdscript
signal category_toggled(category_name: String, is_expanded: bool)
```

#### 2.2 监听折叠/展开事件

在 `_setup_ui()` 方法中，找到创建 `track_list` 的位置，添加信号连接：

```gdscript
func _setup_ui():
    # ... 现有代码 ...
    
    # 创建轨道列表
    track_list = Tree.new()
    track_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    track_list.set_columns(2)
    track_list.set_column_titles_visible(true)
    track_list.set_column_title(0, "轨道名称")
    track_list.set_column_title(1, "类型")
    
    # 添加折叠/展开事件监听
    track_list.item_collapsed.connect(_on_item_collapsed)
    
    track_list.item_selected.connect(_on_track_selected)
    track_list.item_activated.connect(_on_track_activated)
    track_list.button_clicked.connect(_on_track_button_clicked)
    track_list.gui_input.connect(_on_track_list_gui_input)
    # ... 其余代码 ...
```

#### 2.3 实现折叠事件处理

在文件末尾添加新方法：

```gdscript
func _on_item_collapsed(item: TreeItem):
    """处理Tree项的折叠/展开事件"""
    if not item:
        return
    
    # 检查是否是分类项（根节点的直接子节点）
    var root = track_list.get_root()
    if not root:
        return
    
    var is_category = item.get_parent() == root
    if not is_category:
        return  # 只处理分类项的折叠
    
    # 获取分类名称（去掉轨道数量后缀）
    var text = item.get_text(0)
    var category_name = text.split(" (")[0]  # 例如："属性轨道 (2)" -> "属性轨道"
    
    # 发送分类切换信号
    var is_expanded = not item.collapsed
    category_toggled.emit(category_name, is_expanded)
    
    print("TrackEditor: 分类切换 - ", category_name, ", 展开: ", is_expanded)
```

#### 2.4 设置轨道高度

在 `_setup_ui()` 方法中，设置 `track_list` 的行高：

```gdscript
func _setup_ui():
    # ... 现有代码 ...
    
    track_list = Tree.new()
    track_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    track_list.set_columns(2)
    
    # 设置行高以匹配 Canvas
    track_list.set_custom_minimum_size(Vector2(0, 0))
    # 注意：Tree的行高由主题控制，可能需要通过自定义主题设置
    # 这里我们通过设置字体大小来间接影响行高
    
    # ... 其余代码 ...
```

### 步骤 3：修改 JuicyTimelineEditor

**文件**：`addons/juicy_mixer/editor/juicy_timeline_editor.gd`

#### 3.1 连接分类切换信号

在 `_connect_signals()` 方法中添加信号连接：

```gdscript
func _connect_signals():
    print("连接编辑器信号...")
    
    if timeline_canvas:
        print("连接Timeline Canvas信号...")
        timeline_canvas.timeline_changed.connect(_on_canvas_timeline_changed)
        timeline_canvas.playback_time_changed.connect(_on_canvas_time_changed)
        timeline_canvas.track_selected.connect(_on_track_selected)
        print("Timeline Canvas信号已连接")
    
    if track_editor:
        print("连接Track Editor信号...")
        track_editor.track_added.connect(_on_track_added)
        track_editor.track_removed.connect(_on_track_removed)
        track_editor.track_reordered.connect(_on_track_reordered)
        track_editor.track_selected.connect(_on_track_selected)
        
        # 新增：连接分类切换信号
        track_editor.category_toggled.connect(_on_category_toggled)
        
        print("Track Editor信号已连接")
    
    print("所有编辑器信号连接完成")
```

#### 3.2 实现分类切换处理

在文件末尾添加新方法：

```gdscript
func _on_category_toggled(category_name: String, is_expanded: bool):
    """处理分类折叠/展开事件"""
    print("TimelineEditor: 接收分类切换 - ", category_name, ", 展开: ", is_expanded)
    
    # 转发给 TimelineCanvas
    if timeline_canvas:
        timeline_canvas.set_category_visible(category_name, is_expanded)
```

#### 3.3 传递轨道高度配置

在 `edit_timeline()` 方法中，确保轨道高度配置传递给子组件：

```gdscript
func edit_timeline(timeline: JuicyTimelineResource):
    print("edit_timeline() 被调用，Timeline: ", timeline)
    current_timeline = timeline
    
    if timeline_canvas:
        print("设置 Timeline 到 Canvas")
        timeline_canvas.set_timeline(timeline)
        # 设置轨道高度
        timeline_canvas.track_height = TRACK_HEIGHT
        timeline_canvas.track_spacing = TRACK_SPACING
    
    if track_editor:
        print("设置 Timeline 到 Track Editor")
        track_editor.set_timeline(timeline)
        # 设置轨道高度（通过方法或直接访问）
        if track_editor.has_method("set_track_height"):
            track_editor.set_track_height(TRACK_HEIGHT)
    
    # ... 其余代码 ...
```

### 步骤 4：修改 JuicyTimelineCanvas

**文件**：`addons/juicy_mixer/editor/juicy_timeline_canvas.gd`

#### 4.1 添加可见性管理变量

在类变量声明区域添加：

```gdscript
# 可见性管理
var visible_tracks: Array[JuicyTrack] = []  # 当前可见的轨道
var hidden_categories: Array[String] = []    # 隐藏的分类名称
```

#### 4.2 实现分类可见性设置

在公共接口区域添加方法：

```gdscript
func set_category_visible(category_name: String, visible: bool):
    """设置分类的可见性"""
    if visible:
        if category_name in hidden_categories:
            hidden_categories.erase(category_name)
            print("TimelineCanvas: 显示分类 - ", category_name)
    else:
        if category_name not in hidden_categories:
            hidden_categories.append(category_name)
            print("TimelineCanvas: 隐藏分类 - ", category_name)
    
    _update_visible_tracks()
    queue_redraw()
```

#### 4.3 实现可见轨道更新

添加核心方法：

```gdscript
func _update_visible_tracks():
    """根据隐藏分类更新可见轨道列表"""
    if not current_timeline:
        visible_tracks.clear()
        return
    
    visible_tracks.clear()
    
    # 遍历所有轨道，只添加可见分类中的轨道
    for track in current_timeline.get_all_tracks():
        var track_type = track.get_track_type()
        var category_name = _get_category_name(track_type)
        
        if category_name not in hidden_categories:
            visible_tracks.append(track)
    
    print("TimelineCanvas: 可见轨道数量 - ", visible_tracks.size(), "/", current_timeline.get_all_tracks().size())

func _get_category_name(track_type: String) -> String:
    """根据轨道类型获取分类名称"""
    match track_type:
        "Property":
            return "属性轨道"
        "Feedback":
            return "反馈轨道"
        "Method":
            return "方法轨道"
        "Event":
            return "事件轨道"
        _:
            return "未知轨道"
```

#### 4.4 修改轨道绘制逻辑

修改 `_draw_tracks()` 方法，只绘制可见轨道：

```gdscript
func _draw_tracks():
    if not current_timeline:
        return
    
    # 使用 visible_tracks 而不是 all_tracks
    var y_offset = 0.0
    
    for i in range(visible_tracks.size()):
        var track = visible_tracks[i]
        var track_rect = Rect2(0, y_offset, size.x, track_height)
        
        # 只有当轨道在可见区域内时才绘制背景
        var track_visible = track_rect.position.y + track_rect.size.y > 0 and track_rect.position.y < size.y
        if not track_visible:
            y_offset += track_height + track_spacing
            continue
        
        # 绘制轨道背景
        var track_color = track_bg_color
        if track == selected_track:
            track_color = track_selected_color
        draw_rect(track_rect, track_color)
        
        # 绘制轨道名称（固定在左侧）
        _draw_track_name(track, track_rect)
        
        # 绘制轨道内容
        _draw_track_content(track, track_rect)
        
        y_offset += track_height + track_spacing
```

#### 4.5 修改轨道查找方法

修改 `_get_track_at_position()` 方法，基于可见轨道查找：

```gdscript
func _get_track_at_position(y: float) -> int:
    if not current_timeline:
        return -1
    
    # 在可见轨道中查找
    var current_y = 0.0
    
    for i in range(visible_tracks.size()):
        if y >= current_y and y <= current_y + track_height:
            return i
        current_y += track_height + track_spacing
    
    return -1
```

修改 `_get_track_by_index()` 方法：

```gdscript
func _get_track_by_index(index: int) -> JuicyTrack:
    if not current_timeline:
        return null
    
    # 从可见轨道中获取
    if index >= 0 and index < visible_tracks.size():
        return visible_tracks[index]
    
    return null
```

#### 4.6 更新 set_timeline 方法

修改 `set_timeline()` 方法，在设置Timeline后更新可见轨道：

```gdscript
func set_timeline(timeline: JuicyTimelineResource):
    current_timeline = timeline
    if timeline:
        playback_head_position = 0.0
        zoom_level = timeline.timeline_zoom
        
        # 连接Timeline的zoom_changed信号
        if not timeline.zoom_changed.is_connected(_on_timeline_zoom_changed):
            timeline.zoom_changed.connect(_on_timeline_zoom_changed)
            print("TimelineCanvas: 已连接Timeline的zoom_changed信号")
        
        # 更新可见轨道列表
        _update_visible_tracks()
    
    queue_redraw()
```

### 步骤 5：实现垂直滚动同步

**文件**：`addons/juicy_mixer/editor/juicy_timeline_editor.gd`

#### 5.1 添加垂直滚动条

在 `_setup_ui()` 方法中，修改编辑区域的布局：

```gdscript
func _setup_ui():
    # ... 现有代码 ...
    
    # 创建编辑区域
    var edit_area = HBoxContainer.new()  # 改为 HBoxContainer
    edit_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main_vbox.add_child(edit_area)
    
    # 创建轨道编辑器容器（带滚动）
    var track_container = ScrollContainer.new()
    track_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    track_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    track_container.scroll_horizontal_enabled = false  # 禁用水平滚动
    edit_area.add_child(track_container)
    
    # 创建轨道编辑器
    track_editor = JuicyTrackEditor.new()
    track_container.add_child(track_editor)
    
    # 创建时间轴画布区域
    var canvas_area = VBoxContainer.new()
    canvas_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    canvas_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
    edit_area.add_child(canvas_area)
    
    # 创建时间标尺
    _create_time_ruler(canvas_area)
    
    # 创建时间轴画布
    timeline_canvas = JuicyTimelineCanvas.new()
    timeline_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
    timeline_canvas.timeline_editor = self
    canvas_area.add_child(timeline_canvas)
    
    # 创建时间轴滚动条
    timeline_scroll = HScrollBar.new()
    timeline_scroll.min_value = 0.0
    timeline_scroll.max_value = timeline_length
    timeline_scroll.value = 0.0
    timeline_scroll.value_changed.connect(_on_timeline_scroll_changed)
    canvas_area.add_child(timeline_scroll)
    
    # ... 其余代码 ...
```

#### 5.2 连接垂直滚动同步

添加滚动同步逻辑：

```gdscript
func _setup_ui():
    # ... 现有代码 ...
    
    # 获取轨道编辑器的滚动容器
    var track_container = track_editor.get_parent() as ScrollContainer
    if track_container:
        track_container.scroll_changed.connect(_on_track_scroll_changed)
    
    # ... 其余代码 ...
```

```gdscript
func _on_track_scroll_changed(horizontal: float, vertical: float):
    """同步轨道编辑器的垂直滚动到画布"""
    # 注意：Canvas使用自定义绘制，需要手动处理滚动
    # 这里我们通过设置Canvas的垂直偏移来实现同步
    if timeline_canvas:
        timeline_canvas.vertical_offset = -vertical
        timeline_canvas.queue_redraw()
```

**文件**：`addons/juicy_mixer/editor/juicy_timeline_canvas.gd`

添加垂直偏移变量：

```gdscript
var vertical_offset: float = 0.0  # 垂直滚动偏移
```

修改 `_draw_tracks()` 方法，应用垂直偏移：

```gdscript
func _draw_tracks():
    if not current_timeline:
        return
    
    var y_offset = vertical_offset  # 应用垂直偏移
    
    for i in range(visible_tracks.size()):
        var track = visible_tracks[i]
        var track_rect = Rect2(0, y_offset, size.x, track_height)
        
        # 只有当轨道在可见区域内时才绘制背景
        var track_visible = track_rect.position.y + track_rect.size.y > 0 and track_rect.position.y < size.y
        if not track_visible:
            y_offset += track_height + track_spacing
            continue
        
        # ... 绘制逻辑 ...
        
        y_offset += track_height + track_spacing
```

## 测试验证

### 测试场景 1：基本对齐

1. 打开时间轴编辑器
2. 加载一个包含多个轨道的Timeline
3. 验证左右两侧轨道数量一致
4. 滚动左侧Tree，观察右侧Canvas是否同步滚动

### 测试场景 2：分类折叠

1. 展开"属性轨道"分类
2. 验证右侧Canvas显示所有属性轨道
3. 折叠"属性轨道"分类
4. 验证右侧Canvas隐藏所有属性轨道
5. 验证其他轨道位置正确

### 测试场景 3：多分类折叠

1. 折叠多个分类
2. 验证右侧Canvas只显示未折叠分类的轨道
3. 逐个展开分类
4. 验证轨道按正确顺序重新出现

### 测试场景 4：滚动同步

1. 折叠部分分类
2. 滚动左侧Tree到底部
3. 验证右侧Canvas也滚动到底部
4. 滚动到顶部
5. 验证两侧顶部对齐

### 测试场景 5：轨道选择

1. 点击左侧Tree中的轨道
2. 验证右侧Canvas对应轨道高亮
3. 点击右侧Canvas中的轨道
4. 验证左侧Tree对应轨道选中

## 注意事项

### 1. Tree行高问题

Godot的 `Tree` 控件的行高由主题控制，可能需要自定义主题来精确控制行高。

**解决方案**：
- 创建自定义主题
- 设置 `Tree` 的 `font_size` 属性
- 或者使用 `Tree.set_custom_minimum_size()` 来间接影响行高

### 2. 滚动性能

频繁的滚动同步可能影响性能。

**优化建议**：
- 使用 `call_deferred()` 延迟重绘
- 只重绘可见区域
- 缓存可见轨道列表

### 3. 分类名称一致性

确保 `JuicyTrackEditor` 和 `JuicyTimelineCanvas` 使用相同的分类名称映射。

**建议**：
- 将分类名称映射提取为共享常量
- 或者在 `JuicyTimelineResource` 中定义分类名称

### 4. 初始状态

确保编辑器初始化时，所有分类默认展开，避免初始状态不一致。

**实现**：
```gdscript
func _ready():
    # ... 现有代码 ...
    
    # 确保所有分类默认展开
    if track_editor:
        track_editor.expand_all_categories()
```

## 扩展功能

### 功能 1：记住折叠状态

保存用户的折叠偏好，下次打开编辑器时恢复。

```gdscript
# 在 JuicyTrackEditor 中
var saved_category_states: Dictionary = {}

func save_category_states():
    saved_category_states.clear()
    var root = track_list.get_root()
    var item = root.get_first_child()
    while item:
        saved_category_states[item.get_text(0)] = not item.collapsed
        item = item.get_next()

func restore_category_states():
    var root = track_list.get_root()
    var item = root.get_first_child()
    while item:
        var category_name = item.get_text(0)
        if saved_category_states.has(category_name):
            item.set_collapsed(not saved_category_states[category_name])
        item = item.get_next()
```

### 功能 2：全部展开/折叠按钮

在工具栏添加按钮，快速展开或折叠所有分类。

```gdscript
# 在 JuicyTrackEditor 中
func expand_all_categories():
    var root = track_list.get_root()
    var item = root.get_first_child()
    while item:
        item.set_collapsed(false)
        item = item.get_next()

func collapse_all_categories():
    var root = track_list.get_root()
    var item = root.get_first_child()
    while item:
        item.set_collapsed(true)
        item = item.get_next()
```

### 功能 3：轨道搜索过滤

添加搜索框，根据轨道名称过滤显示的轨道。

```gdscript
# 在 JuicyTrackEditor 中
var search_filter: String = ""

func set_search_filter(filter: String):
    search_filter = filter.to_lower()
    _apply_filter()

func _apply_filter():
    var root = track_list.get_root()
    var category = root.get_first_child()
    while category:
        var has_visible_tracks = false
        var track = category.get_first_child()
        while track:
            var track_name = track.get_text(0).to_lower()
            var visible = search_filter.is_empty() or search_filter in track_name
            track.set_visible(visible)
            if visible:
                has_visible_tracks = true
            track = track.get_next()
        category.set_visible(has_visible_tracks)
        category = category.get_next()
```

## 总结

本方案通过动态可见性同步机制，完美解决了轨道编辑器中左侧Tree与右侧Canvas的对齐问题，特别是在支持分类折叠的场景下。

**核心优势**：
1. ✅ 完美支持分类折叠/展开
2. ✅ 左右两侧始终保持对齐
3. ✅ 滚动同步流畅
4. ✅ 易于扩展和维护

**实施建议**：
1. 按步骤逐步实施，每步完成后进行测试
2. 优先实现核心功能（可见性同步），再添加扩展功能
3. 注意性能优化，避免频繁重绘
4. 保留详细的调试日志，便于问题排查

通过本方案的实施，用户将获得一个功能完善、体验流畅的时间轴编辑器。
