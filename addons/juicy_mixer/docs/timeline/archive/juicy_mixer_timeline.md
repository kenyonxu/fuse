这是一份基于 **JuicyMixer V3 "Holographic"** 架构原则设计的完整 **JuicyTimeline** 系统方案。

该方案严格遵循\*\*“数据驱动（Data-Oriented）”**和**“无状态驱动器（Stateless Driver）”\*\*原则，利用 `JuicyContext` 存储所有运行时状态（如播放进度、活跃的子效果 ID），从而实现高性能的导演级控制。

-----

# JuicyTimeline 系统设计文档

## 1\. 设计概述

**JuicyTimeline** 是 JuicyMixer V3 的终极编排工具（Director），旨在替代线性的 `Sequence`，提供非线性的、基于时间轴的多轨道控制能力。

它不仅仅是播放动画，它是**逻辑的容器**。它将属性变化、子效果触发（音频/震动）和回调事件统一在一个时间轴上管理，是实现“联觉（Synesthesia）”的核心组件。

### 核心特性

1.  **多轨道架构**：支持属性轨道（Property）、反馈轨道（Feedback/Resource）、回调轨道（Call）和事件轨道（Juicy_Event）。
2.  **纯数据资源**：所有轨道和关键帧均为 `Resource`，易于序列化和复用。
3.  **无状态执行**：`JuicyTimelineDriver` 单例负责计算，所有播放头（Playhead）状态存储在 `JuicyContext` 中。
4.  **虚拟缓冲输出**：属性轨道直接写入 V3 的 `VirtualPropertyBuffer`，天然支持混合。

-----

## 2\. 数据层：JuicyTimelineResource

**文件路径**: `addons/juicy_mixer/resources/juicy_timeline_resource.gd`

这是时间轴的静态蓝图。为了支持多态轨道，我们使用 Resource 数组。

```gdscript
@tool
class_name JuicyTimelineResource
extends JuicyFeedbackResource

# 轨道基类定义（独立文件）
class_name Track extends Resource:
    @export var enabled: bool = true
    @export var track_name: String = "Track"

# 具体轨道类型定义 (每种类型的轨道都是独立文件)
class_name PropertyTrack extends Track:
    @export var property_path: String      # 属性名 (e.g., "scale", "modulate:a")
    @export var curve: Curve               # 值变化曲线 (0-1)
    @export var value_range: Vector2       # 映射范围 (Min, Max)
    @export var relative: bool = true      # 是否是相对值(Additive)
    @export var blend_mode: int = 1        # 0: Override, 1: Additive

class_name FeedbackTrack extends Track:
    @export var resource: JuicyFeedbackResource # 触发的子效果
    @export var start_time: float = 0.0
    @export var duration: float = -1.0     # -1 表示使用资源自身时长
    @export var time_scale_curve: Curve    # 可选：动态控制子效果的时间缩放

class_name MethodTrack extends Track:
    @export var time: float = 0.0
    @export var method_name: String
    @export var args: Array = []

class_name EventTrack extends track:
    @export var juicy_event: Juicy_Event

# Timeline 主体属性
@export_group("Timeline Settings")
@export var tracks: Array[Track] = []
@export var loop_mode: int = 0 # 0: None, 1: Loop, 2: PingPong
@export var loop_count: int = -1 # -1 = Infinite

# 联觉支持：参数映射
# 允许外部通过 context.set_override("intensity", 0.5) 来驱动时间轴
@export_group("Parameters")
@export var input_parameters: Dictionary = {} # "param_name" -> Default Value

func create_drivers() -> Array[JuicyDriver]:
    # 只需要一个 TimelineDriver 即可管理所有轨道
    var driver = JuicyTimelineDriver.new()
    driver.timeline_resource = self
    return [driver]

# 验证逻辑
func validate_config() -> ValidationResult:
    var result = super.validate_config()
    if tracks.is_empty():
        result.warnings.append("Timeline has no tracks.")
    return result
```

-----

## 3\. 逻辑层：JuicyTimelineDriver

**文件路径**: `addons/juicy_mixer/drivers/juicy_timeline_driver.gd`

驱动器是无状态的。它负责根据 `Context.progress`（时间）去采样 `TimelineResource` 中的轨道，并将结果分发到 Buffer 或 Director。

### 3.1 状态结构设计 (存储于 Context)

为了保证 Driver 无状态，我们需要在 `JuicyContext.driver_data` 中定义一个专门的数据结构来存储播放状态。

```gdscript
# 运行时状态结构 (伪代码，实际存储于 Dictionary)
class TimelineState:
    var time_cursor: float = 0.0        # 当前播放头时间
    var active_sub_contexts: Dictionary = {} # track_index -> context_id
    var triggered_events: Dictionary = {}    # track_index -> last_triggered_hash
    var loop_counter: int = 0
```

### 3.2 Driver 实现

```gdscript
class_name JuicyTimelineDriver
extends JuicyDriver

var timeline_resource: JuicyTimelineResource

func _init():
    driver_name = "JuicyTimelineDriver"

# 1. 准备阶段：初始化状态
func prepare(context: JuicyContext) -> void:
    var state = {
        "time": 0.0,
        "active_subs": {},  # 记录正在播放的子效果 ContextID
        "last_time": -0.001, # 用于检测事件穿越
        "loops": 0
    }
    context.set_driver_data("timeline_state", state)

# 2. 处理阶段：每帧执行
func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var state = context.get_driver_data("timeline_state")
    
    # 更新时间 (考虑 Context 的 TimeScale)
    var prev_time = state.time
    var dt = delta * context.time_scale
    state.time += dt
    
    # 处理循环逻辑 (简化版)
    if state.time >= timeline_resource.duration:
        if timeline_resource.loop_mode == 1: # Loop
             state.time = 0.0
             # 重置事件触发状态...
        else:
             state.time = timeline_resource.duration
             context.complete() # 标记完成

    # === 轨道求值 (Evaluation) ===
    for i in range(timeline_resource.tracks.size()):
        var track = timeline_resource.tracks[i]
        if not track.enabled: continue
        
        if track is JuicyTimelineResource.PropertyTrack:
            _process_property_track(context, track, state.time, buffer)
            
        elif track is JuicyTimelineResource.FeedbackTrack:
            _process_feedback_track(context, track, i, state, buffer)
            
        elif track is JuicyTimelineResource.MethodTrack:
            _process_method_track(context, track, i, state, prev_time)

    state.last_time = state.time

# 3. 清理阶段
func cleanup(context: JuicyContext) -> void:
    var state = context.get_driver_data("timeline_state")
    if state:
        # 停止所有由 Timeline 启动的子效果
        for sub_context_id in state.active_subs.values():
            JuicyMixer.stop(sub_context_id)
```

-----

## 4\. 轨道逻辑详解

### 4.1 Property Track (属性轨道) - 视觉反馈的核心

直接向 `JuicyPropertyBuffer` 写入数据。这里利用了 Buffer 的混合能力。

```gdscript
func _process_property_track(context: JuicyContext, track: PropertyTrack, time: float, buffer: JuicyPropertyBuffer) -> void:
    # 计算采样点 (0.0 - 1.0)
    var t = clamp(time / context.duration, 0.0, 1.0)
    
    # 采样曲线
    var curve_val = track.curve.sample(t)
    
    # 映射到数值范围
    var final_val = lerp(track.value_range.x, track.value_range.y, curve_val)
    
    # 写入 Buffer
    # 注意：blend_mode 从 Track 配置读取，通常是 ADDITIVE
    buffer.add_sample(
        context.target, 
        track.property_path, 
        final_val, 
        track.blend_mode
    )
```

### 4.2 Feedback Track (反馈轨道) - 组合能力的核心

这是替代 `Sequence` 的关键。它在时间轴上管理其他 `JuicyFeedbackResource` 的生命周期。

```gdscript
func _process_feedback_track(context: JuicyContext, track: FeedbackTrack, track_idx: int, state: Dictionary, buffer: JuicyPropertyBuffer) -> void:
    var current_time = state.time
    var end_time = track.start_time + (track.duration if track.duration > 0 else track.resource.duration)
    
    var is_inside_range = current_time >= track.start_time and current_time < end_time
    var sub_id = state.active_subs.get(track_idx)
    
    # A. 触发开始
    if is_inside_range and sub_id == null:
        # 使用 JuicyMixer 递归播放子效果
        # 关键：继承 Owner，但 Target 可以是当前 Target，也可以在 Resource 里指定相对路径
        var new_id = JuicyMixer.play(track.resource, context.target)
        state.active_subs[track_idx] = new_id
        
        # 可选：将子 Context 与父 Context 建立父子关系，以便统一 TimeScale

    # B. 持续更新 (可选，用于驱动子效果参数)
    if is_inside_range and sub_id != null:
        # 例如：Timeline 曲线控制子效果的 intensity 参数
        if track.time_scale_curve:
            var t = (current_time - track.start_time) / (end_time - track.start_time)
            var scale = track.time_scale_curve.sample(t)
            # 通过 Mixer API 动态修改子 Context
            # JuicyMixer.set_context_time_scale(sub_id, scale)

    # C. 触发结束 (或超出范围)
    if not is_inside_range and sub_id != null:
        # 如果子效果是 Loop 的，必须手动停止
        # 如果子效果是 OneShot，可以不调用 stop，让其自然播放完（取决于配置）
        JuicyMixer.stop(sub_id) 
        state.active_subs.erase(track_idx)
```

### 4.3 Method/Event Track (事件轨道) - 逻辑回调

```gdscript
func _process_method_track(context: JuicyContext, track: MethodTrack, track_idx: int, state: Dictionary, prev_time: float) -> void:
    # 检测时间穿越：上一帧在 time 之前，当前帧在 time 之后
    if prev_time < track.time and state.time >= track.time:
        if context.target.has_method(track.method_name):
            context.target.callv(track.method_name, track.args)
        
        # 或者发送到 EventBuffer
        # var event = JuicyEvent.new(JuicyEventBuffer.EventType.CUSTOM_CALLBACK)
        # JuicyMixer.instance._event_buffer.add_event(event)
```

-----

## 5\. 联觉增强：Parameter Binding (参数绑定)

这是超越普通 Timeline 的地方。我们让 Timeline 接受外部输入，并影响所有轨道。

**在 JuicyContext 中**：

```gdscript
# 用户调用：JuicyMixer.create(timeline).set_override("intensity", 0.8).play()
var overrides: Dictionary = {} 
```

**在 JuicyTimelineDriver 中**：

```gdscript
func _process_property_track(...):
    # ... 计算基础 curve_val ...
    
    # 检查是否有绑定
    # 假设我们有一个 intensity 参数影响所有 Shake 轨道的幅度
    var intensity_mult = context.get_override("intensity", 1.0)
    
    final_val *= intensity_mult 
```

-----

## 6\. 编辑器集成建议 (Editor Integration)

`JuicyTimelineResource` 的强大依赖于编辑器工具。如果不写插件 UI，直接在 Inspector 里编辑 Array 会很痛苦。

**建议开发 `JuicyTimelineEditor` 插件：**

1.  **可视化时间轴**：类似 Godot 的 AnimationPlayer 面板。
2.  **拖拽支持**：将 `JuicyFeedbackResource类` 直接拖入轨道，自动创建 `FeedbackTrack`。
3.  **曲线编辑器**：直接在面板里编辑 `PropertyTrack` 的 Curve。
4.  **预览功能**：复用 V3 的架构，在编辑器内直接实例化一个 `JuicyTimelineDriver` 跑逻辑，驱动预览 Sprite。

-----

## 7\. 总结

这个设计完全摒弃了传统的 `Sequence`（数组迭代）模式，转而使用基于时间采样的**非线性编辑模式**。

  * **对于 Composite**：Timeline 本身就是多轨道的，天然支持并行（Composite）。
  * **对于 Sequence**：通过调整 Track 的 `start_time`，天然实现了串行（Sequence）。
  * **对于 联觉**：通过 `PropertyTrack` 和 `FeedbackTrack` 的同步，你可以轻松做到“在震动曲线达到顶峰的那一帧，触发爆炸音效，并调用相机 Shader 参数”。

这是 V3 架构中最具表现力的一环。实现它之后，JuicyMixer 就不仅仅是一个特效库，而是一个**游戏手感编排引擎**。



## 编辑器支持
是的，您的直觉非常准确。开发一个类似 Godot 原生 `AnimationPlayer` 的面板，最合适的位置就是 **底部面板 (Bottom Panel)**。

要实现一个类似 `AnimationPlayer` 的编辑器插件，不能仅仅堆砌标准 UI 控件（如 Button 或 Label），而是需要大量的 **自定义绘制 (`_draw`)** 和 **输入处理 (`_gui_input`)**。

以下是开发 **JuicyTimeline Editor** 的完整技术路线图和架构设计：

-----

### 1\. 插件架构概览

你需要三个核心脚本：

1.  **`plugin.gd` (EditorPlugin)**: 负责注册插件，监听资源选中状态，控制面板的显示/隐藏。
2.  **`timeline_panel.tscn` / `.gd`**: 面板的主 UI 容器，负责布局（左侧轨道头 + 右侧时间轴）。
3.  **`timeline_track_view.gd` (Custom Control)**: 核心绘制区域，负责画标尺、关键帧、处理拖拽逻辑。

-----

### 2\. 第一步：注册底部面板 (`EditorPlugin`)

这是插件的入口。你需要告诉 Godot：“当用户选中 `JuicyTimelineResource` 时，请显示我的面板”。

```gdscript
# addons/juicy_mixer/editor/juicy_timeline_plugin.gd
@tool
extends EditorPlugin

var timeline_panel_scene = preload("res://addons/juicy_mixer/editor/timeline_panel.tscn")
var timeline_panel_instance

func _enter_tree():
    timeline_panel_instance = timeline_panel_scene.instantiate()
    # 关键：将面板添加到底部，此时它是一个 Button，点击后展开
    add_control_to_bottom_panel(timeline_panel_instance, "Juicy Timeline")
    # 默认隐藏
    _make_visible(false)

func _exit_tree():
    if timeline_panel_instance:
        remove_control_from_bottom_panel(timeline_panel_instance)
        timeline_panel_instance.queue_free()

# === 核心：上下文感知 ===

# 告诉 Godot 这个插件处理什么类型的对象
func _handles(object):
    return object is JuicyTimelineResource

# 当资源被"编辑"（双击或选中）时调用
func _edit(object):
    if object is JuicyTimelineResource:
        timeline_panel_instance.set_current_timeline(object)

# 控制面板的显示与隐藏
func _make_visible(visible):
    if timeline_panel_instance:
        timeline_panel_instance.visible = visible
        # 如果需要，可以自动切换到底部面板
        if visible:
            make_bottom_panel_item_visible(timeline_panel_instance)
```

-----

### 3\. 第二步：面板布局设计 (`UI Structure`)

`AnimationPlayer` 的布局本质上是一个 **Split Container**。

**推荐的节点结构 (`timeline_panel.tscn`)**:

```text
VBoxContainer (Root)
├── HBoxContainer (Toolbar: 播放/暂停/缩放/吸附按钮)
├── HSplitContainer (Main Area)
│   ├── ScrollContainer (Left: Headers)
│   │   └── VBoxContainer (Track List - 存放轨道名称、静音按钮等)
│   └── ScrollContainer (Right: Timeline)
│       └── Control (Canvas - 自定义绘制区域，核心所在！)
```

**同步滚动技巧**：
左侧的“轨道列表”和右侧的“时间轴”必须同步垂直滚动。

  * **做法**：隐藏两个 ScrollContainer 的滚动条，在最外层加一个统一的 ScrollBar，通过信号同时设置两个 Container 的 `scroll_vertical`。或者，更简单的方法是将 Header 和 Canvas 放在同一个 `ScrollContainer` 的 `HBoxContainer` 内部。

-----

### 4\. 第三步：核心绘制与交互 (`The Canvas`)

这是最难也是最重要的部分。你需要在一个 `Control` 节点上自己画出标尺、轨道背景和关键帧。

**核心概念：像素与时间的映射**
你需要一个变量 `zoom_scale` (pixels per second)。

  * **Time -\> X**: `x_position = time * zoom_scale`
  * **X -\> Time**: `time = x_position / zoom_scale`

**`timeline_canvas.gd` 实现思路**:

```gdscript
@tool
extends Control

var current_timeline: JuicyTimelineResource
var zoom_scale: float = 100.0 # 1秒 = 100像素
var track_height: float = 30.0
var playhead_time: float = 0.0

func _draw():
    if not current_timeline: return
    
    # 1. 绘制标尺 (Ruler)
    draw_rect(Rect2(0, 0, size.x, 20), Color.DARK_GRAY)
    for t in range(0, int(size.x / zoom_scale) + 1):
        var x = t * zoom_scale
        draw_line(Vector2(x, 0), Vector2(x, 20), Color.WHITE)
        draw_string(get_theme_font("font", "Label"), Vector2(x + 5, 15), str(t) + "s")
        
    # 2. 绘制轨道背景
    var y = 20 # 标尺高度
    for track in current_timeline.tracks:
        draw_rect(Rect2(0, y, size.x, track_height), Color(0.1, 0.1, 0.1), false) # 边框
        
        # 3. 绘制关键帧/Clip
        if track is JuicyTimelineResource.FeedbackTrack:
            var x = track.start_time * zoom_scale
            var w = track.duration * zoom_scale
            # 绘制一个圆角矩形代表 Feedback Resource
            draw_style_box(get_theme_stylebox("focus", "Button"), Rect2(x, y + 2, w, track_height - 4))
            
        y += track_height
        
    # 4. 绘制播放头 (Playhead)
    var playhead_x = playhead_time * zoom_scale
    draw_line(Vector2(playhead_x, 0), Vector2(playhead_x, size.y), Color.RED, 2.0)

# 处理输入
func _gui_input(event):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                # 点击逻辑：判断点到了哪个 Keyframe，或者移动播放头
                var time_clicked = event.position.x / zoom_scale
                # ... 选中逻辑 ...
            else:
                # 释放逻辑：应用 Undo/Redo
                pass
    
    elif event is InputEventMouseMotion:
        if event.button_mask & MOUSE_BUTTON_LEFT:
            # 拖拽逻辑
            queue_redraw() # 触发重绘
```

-----

### 5\. 第四步：Undo/Redo 集成 (必不可少)

如果不集成 Undo/Redo，用户会非常痛苦。必须使用 Godot 的 `EditorUndoRedoManager`。

```gdscript
# 在 timeline_panel.gd 中
var undo_redo: EditorUndoRedoManager

func _on_keyframe_dragged(track_idx, old_time, new_time):
    undo_redo = get_undo_redo() # EditorPlugin 提供的接口
    undo_redo.create_action("Move Keyframe")
    undo_redo.add_do_method(current_timeline, "set_keyframe_time", track_idx, new_time)
    undo_redo.add_undo_method(current_timeline, "set_keyframe_time", track_idx, old_time)
    # 关键：提交动作后，还要强制刷新 UI
    undo_redo.add_do_method(self, "queue_redraw") 
    undo_redo.add_undo_method(self, "queue_redraw")
    undo_redo.commit_action()
```

-----

### 6\. 第五步：预览功能的实现 (In-Editor Preview)

这就是 V3 架构的优势所在。因为 `JuicyTimelineDriver` 是无状态的，你可以在编辑器里直接运行它！

在面板的工具栏上放一个 "Play" 按钮：

```gdscript
# timeline_panel.gd
var preview_driver: JuicyTimelineDriver
var preview_context: JuicyContext

func _on_play_button_pressed():
    # 1. 创建临时的 Driver 和 Context
    preview_driver = JuicyTimelineDriver.new()
    preview_driver.timeline_resource = current_timeline
    
    # 目标可以是一个编辑器内的临时 Sprite，或者用户当前选中的节点
    var target = EditorInterface.get_selection().get_selected_nodes()[0]
    preview_context = JuicyContext.create(current_timeline, target)
    
    # 2. 准备
    preview_driver.prepare(preview_context)
    set_process(true) # 开启 _process 循环

func _process(delta):
    if preview_context:
        # 3. 手动驱动 Driver
        # 这里需要一个假的 Buffer，或者直接应用到节点（如果是编辑器预览）
        var dummy_buffer = JuicyPropertyBuffer.new() 
        preview_driver.process(preview_context, delta, dummy_buffer)
        
        # 4. 立即应用 Buffer (因为编辑器里没有统一的 Flush 阶段)
        dummy_buffer.flush_all_samples()
        
        # 5. 更新 UI 播放头
        timeline_canvas.playhead_time += delta
        timeline_canvas.queue_redraw()
```

-----

### 7\. 进阶提示 (Pro-Tips)

1.  **使用原生图标**: 不要自己做图标。使用 `get_theme_icon("Play", "EditorIcons")` 可以获取 Godot 编辑器自带的图标，让插件看起来像原生的一样。
2.  **吸附功能 (Snapping)**: 实现一个 `snap_step` (例如 0.1s)。拖拽时 `new_time = round(mouse_time / snap_step) * snap_step`。
3.  **Inspector 集成**: 当用户在你的时间轴上点击一个 Keyframe 时，调用 `EditorInterface.inspect_object(selected_resource)`。这样用户就可以在右侧标准的 Inspector 面板里修改这个子 Resource 的详细参数，而不需要你在底部面板里重写一套属性编辑器。

通过这种方式，你不仅能得到一个强大的时间轴编辑器，还能完美复用 Godot 现有的编辑器生态。