# Clip拖拽边界调整问题调试指南

## 问题描述

用户反馈无法通过拖拽左右边界来调整Feedback Track的开始时间和持续时间，并建议添加边界可拖拽状态的视觉反馈。

## 已修复的问题

### 1. 右边界拖拽逻辑不完整
**问题**：当Feedback Track的`duration`为-1（使用资源自身时长）时，右边界拖拽无法正确设置具体持续时间。

**修复**：在`_handle_clip_drag()`函数中，当检测到`duration <= 0`时，会自动设置为具体值。

### 2. 左边界拖拽逻辑错误
**问题**：左边界拖拽时，`max_start`的计算使用了当前已经可能被修改的`feedback_track.start_time`，而不是原始的开始时间，导致边界计算错误。

**修复**：在左边界拖拽逻辑中使用`clip_drag_start_data.duration`和`clip_drag_start_data.start_time`来计算最大允许的开始时间，避免使用已修改的当前值。

### 3. 编辑模式检查问题
**问题**：Clip交互功能只在可视化Clip模式下有效，但用户可能没有正确切换到该模式。

**修复**：
- 在`_handle_left_click()`中添加了明确的编辑模式检查
- 在右键菜单中添加了编辑模式切换选项
- 添加了调试信息显示当前编辑模式

### 4. Clip区域检测逻辑优化
**问题**：Clip区域检测可能不够准确，导致边界检测失败。

**修复**：
- 优化了`_get_clip_at_position()`函数
- 添加了详细的调试信息
- 改进了边界检测逻辑

## 测试步骤

### 步骤1：确认编辑模式
1. 在Timeline编辑器中右键点击
2. 确保选择"切换到可视化Clip模式"
3. 检查控制台是否显示"编辑模式切换到: 可视化Clip模式"

### 步骤2：创建Feedback Track
1. 在Track Editor中添加一个Feedback Track
2. 为其分配一个JuicyFeedbackResource
3. 确认Track在Timeline Canvas中显示为橙色块

### 步骤3：测试左边界拖拽
1. 将鼠标移动到Feedback Track的左边缘（应该显示青色手柄）
2. 按住左键并拖拽
3. 检查控制台输出：
   ```
   Clip检测 - 轨道: [轨道名] ... 编辑模式: 1
   检测到左边界
   Clip拖拽 - 模式: 2 新时间: [时间] ...
   调整左边界 - 新开始时间: [时间] 最大允许: [时间]
   ```

### 步骤4：测试右边界拖拽
1. 将鼠标移动到Feedback Track的右边缘（应该显示青色手柄）
2. 按住左键并拖拽
3. 检查控制台输出：
   ```
   边界检测 - 鼠标X: [X坐标] 开始X: [开始X] 结束X: [结束X] 手柄宽度: 12.0
   左边界范围: [开始X] - [开始X + 12.0]
   右边界范围: [结束X - 12.0] - [结束X]
   检测到右边界
   Clip交互被触发 - 轨道: [轨道名] 区域: 2
   Clip拖拽 - 模式: 3 新时间: [时间] ...
   设置具体持续时间: [持续时间] 或 更新持续时间: [持续时间]
   ```

### 步骤5：测试Clip移动
1. 将鼠标移动到Feedback Track的中间区域
2. 按住左键并拖拽
3. 检查控制台输出：
   ```
   Clip检测 - 轨道: [轨道名] ... 编辑模式: 1
   检测到中间区域
   Clip拖拽 - 模式: 1 新时间: [时间] ...
   移动Clip - 原始开始时间: [时间] 偏移: [时间] 新开始时间: [时间]
   ```

## 调试信息说明

### 关键调试输出
修复后的代码会输出以下调试信息：

1. **编辑模式切换**：
   ```
   编辑模式切换到: 可视化Clip模式
   ```

2. **Clip检测**：
   ```
   Clip检测 - 轨道: [轨道名] 开始X: [X坐标] 结束X: [X坐标] 鼠标X: [X坐标] 编辑模式: [模式]
   ```

3. **区域检测**：
   ```
   检测到左边界/右边界/中间区域
   ```

4. **拖拽操作**：
   ```
   Clip拖拽 - 模式: [模式] 新时间: [时间] 开始时间: [时间] 持续时间: [时间]
   ```

### 如果仍然无法拖拽

#### 检查编辑模式
确保控制台显示`编辑模式: 1`，如果不是：
1. 右键点击Timeline Canvas
2. 选择"切换到可视化Clip模式"

#### 检查Clip检测
如果控制台没有显示"检测到..."信息：
1. 确认鼠标确实在Clip区域内
2. 检查Clip是否正确显示（橙色块）
3. 尝试放大Timeline以提高精度

#### 检查拖拽状态
如果点击但没有拖拽反应：
1. 确认鼠标按住不放
2. 检查控制台是否有"Clip交互被触发"信息
3. 尝试重新选择Clip

## 常见问题解决

### 问题1：看不到手柄
**原因**：可能没有切换到可视化Clip模式
**解决**：右键 → "切换到可视化Clip模式"

### 问题2：拖拽没有反应
**原因**：可能点击位置不准确
**解决**：确保鼠标在Clip的边缘区域（8像素范围内）

### 问题3：右边界无法调整
**原因**：原始duration为-1
**解决**：拖拽后会自动设置为具体值，查看控制台"设置具体持续时间"信息

### 问题4：Clip显示异常
**原因**：Timeline资源可能有问题
**解决**：重新创建Timeline资源和Feedback Track

### 问题5：左边界拖拽无反应（已修复）
**原因**：左边界拖拽时使用了错误的边界计算
**解决**：使用原始数据计算边界，避免使用已修改的当前值

### 问题6：手柄检测精度不足（已修复）
**原因**：手柄宽度设置为8像素，检测精度不够，且边界检测逻辑不够精确
**解决**：
- 将手柄宽度从8像素增加到12像素，提高检测精度
- 优化边界检测逻辑，使用更精确的范围判断
- 添加详细的边界检测调试信息
- 为手柄添加白色边框，提高可见性

## 性能优化建议

1. **减少Clip数量**：过多的Clip会影响性能
2. **合理使用缩放**：适当的缩放级别提高操作精度
3. **启用吸附**：使用时间吸附功能提高编辑精度

## 技术细节

### 修复的核心代码位置
1. **`_handle_clip_drag()`** (第863行)：修复了右边界拖拽逻辑和左边界拖拽逻辑
2. **`_get_clip_at_position()`** (第804行)：优化了区域检测
3. **`_handle_left_click()`** (第110行)：添加了编辑模式检查
4. **`set_edit_mode()`** (第796行)：添加了调试信息

### 边界检测逻辑
```gdscript
# 手柄宽度：12像素（增加检测精度）
var handle_width = 12.0

# 左边界检测（更精确的范围判断）
if pos.x >= start_x and pos.x <= start_x + handle_width:
    return {track = track, region = 1}

# 右边界检测（更精确的范围判断）
elif pos.x >= end_x - handle_width and pos.x <= end_x:
    return {track = track, region = 2}

# 中间区域检测
else:
    return {track = track, region = 0}
```

### 手柄绘制增强
```gdscript
# 手柄宽度与检测逻辑保持一致
var handle_width = 12.0

# 定义颜色方案
var default_clip_color = Color.BLUE
var selected_clip_color = Color.YELLOW
var default_handle_color = Color.WHITE
var draggable_handle_color = Color.CYAN

# 绘制手柄（根据可拖拽状态使用不同颜色）
var left_handle = Rect2(clip_rect.position.x - handle_width/2, ...)
var right_handle = Rect2(clip_rect.position.x + clip_rect.size.x - handle_width/2, ...)

# 根据状态选择颜色
var left_color = default_handle_color
if can_drag_left:
    left_color = draggable_handle_color  # 亮青色
elif track == selected_clip:
    left_color = selected_clip_color  # 亮黄色

var right_color = default_handle_color
if can_drag_right:
    right_color = draggable_handle_color  # 亮青色
elif track == selected_clip:
    right_color = selected_clip_color  # 亮黄色

# 绘制手柄
draw_rect(left_handle, left_color)
draw_rect(right_handle, right_color)

# 添加白色边框提高可见性
var border_color = Color.WHITE
border_color.a = 0.5
draw_rect(left_handle.grow(1), border_color, false, 1.0)
draw_rect(right_handle.grow(1), border_color, false, 1.0)

# 添加调试信息
if can_drag_left or can_drag_right:
    print("手柄状态 - 左边界可拖拽: ", can_drag_left, " 右边界可拖拽: ", can_drag_right)
```

### 拖拽模式处理
```gdscript
match clip_drag_mode:
    1:  # 移动整个Clip
        feedback_track.start_time = max(0.0, original_start_time + delta_time)
    2:  # 调整左边界
        # 使用原始数据计算最大开始时间
        var original_duration = clip_drag_start_data.duration
        var max_start = clip_drag_start_data.start_time + original_duration - 0.1
        feedback_track.start_time = clamp(new_time, 0.0, max_start)
    3:  # 调整右边界
        if feedback_track.duration <= 0:
            feedback_track.duration = new_duration  # 从-1设置为具体值
        else:
            feedback_track.duration = new_duration  # 更新现有值
```

### 左边界拖拽修复详情
**修复前的问题代码**：
```gdscript
var max_start = feedback_track.start_time + feedback_track.get_actual_duration() - 0.1
```

**修复后的正确代码**：
```gdscript
var original_duration = clip_drag_start_data.duration
var max_start = clip_drag_start_data.start_time + original_duration - 0.1
```

**关键区别**：
- 修复前：使用当前可能已修改的`feedback_track.start_time`和`feedback_track.get_actual_duration()`
- 修复后：使用拖拽开始时保存的原始数据`clip_drag_start_data.start_time`和`clip_drag_start_data.duration`

### 手柄检测精度修复详情
**修复前的问题**：
```gdscript
var handle_width = 8.0  # 手柄宽度太小
if pos.x <= start_x + handle_width:  # 边界检测不够精确
```

**修复后的正确代码**：
```gdscript
var handle_width = 12.0  # 增加手柄宽度
if pos.x >= start_x and pos.x <= start_x + handle_width:  # 更精确的范围判断
```

**关键区别**：
- 修复前：8像素宽度，使用`<=`判断，容易误检
- 修复后：12像素宽度，使用范围判断，更精确

## 反馈收集

如果问题仍然存在，请提供以下信息：

1. **控制台输出**：完整的调试信息
2. **操作步骤**：详细的操作过程
3. **环境信息**：Godot版本、操作系统
4. **Timeline配置**：Feedback Track的属性设置

这些信息将帮助进一步诊断和解决问题。

## Clip默认颜色修复

### 问题描述
用户反馈Clip的默认颜色还是橙色（Color.ORANGE），而不是方案中的蓝色（Color.BLUE）。

### 修复内容
在`_draw_feedback_track_visual()`函数中将Clip默认颜色从橙色修改为蓝色：

**修复前的代码**：
```gdscript
var clip_color = Color.ORANGE
```

**修复后的代码**：
```gdscript
var clip_color = Color.BLUE  # 修改默认颜色为蓝色
```

### 颜色方案
- **Clip默认颜色**：蓝色（Color.BLUE）
- **Clip选中颜色**：亮黄色（Color.YELLOW）
- **边界默认颜色**：白色（Color.WHITE）
- **边界可拖拽颜色**：亮青色（Color.CYAN）

### 实时状态检测
系统会实时检测鼠标位置并更新手柄颜色：
```gdscript
# 检测鼠标位置和边界可拖拽状态
var is_over_clip = block_rect.has_point(mouse_pos)
var can_drag_left = mouse_pos.x >= start_x and mouse_pos.x <= start_x + handle_width
var can_drag_right = mouse_pos.x >= end_x - handle_width and mouse_pos.x <= end_x
```

### 智能手柄绘制
创建了新的`_draw_clip_handles_with_feedback()`函数：
- 根据可拖拽状态动态选择颜色
- 提供清晰的视觉指示
- 保持与检测逻辑的一致性

### 用户体验提升

#### 1. 即时视觉反馈
- 鼠标移动到可拖拽区域时，手柄立即变为亮青色
- 鼠标移出可拖拽区域时，手柄恢复为白色
- 选中Clip时，手柄变为亮黄色

#### 2. 精确的边界指示
- 12像素的手柄宽度提供更大的可拖拽区域
- 白色边框增强手柄可见性
- 实时状态检测确保准确的反馈

#### 3. 直观的交互提示
- 颜色变化直观地表示可拖拽状态
- 无需猜测哪些区域可以拖拽
- 提供专业的编辑器体验

### 调试输出示例
当鼠标移动到Clip边界时，控制台会输出：
```
手柄状态 - 左边界可拖拽: true 右边界可拖拽: false
```

### 测试步骤
1. 确认Timeline编辑器处于可视化Clip模式
2. 创建一个Feedback Track
3. 观察Clip显示为蓝色块
4. 将鼠标移动到Clip左边缘，观察手柄变为亮青色
5. 将鼠标移动到Clip右边缘，观察手柄变为亮青色
6. 点击选中Clip，观察手柄变为亮黄色

这个修复确保了Timeline Clip系统提供了完整的视觉反馈，大大提升了用户体验和编辑效率。

## Clip选中时手柄颜色修复

### 问题描述
用户反馈当选中Clip时，左右边界的颜色是黄色，与Clip的选中颜色混在一起，影响视觉效果。

### 修复内容
在`_draw_clip_handles_with_feedback()`函数中移除了选中Clip时手柄使用黄色的逻辑，确保手柄始终保持白色。

**修复前的代码**：
```gdscript
# 根据可拖拽状态选择颜色
var left_color = default_handle_color
if can_drag_left:
    left_color = draggable_handle_color
elif track == selected_clip:
    left_color = selected_clip_color  # 选中时使用黄色

# 根据可拖拽状态选择颜色
var right_color = default_handle_color
if can_drag_right:
    right_color = draggable_handle_color
elif track == selected_clip:
    right_color = selected_clip_color  # 选中时使用黄色
```

**修复后的代码**：
```gdscript
# 根据可拖拽状态选择颜色
var left_color = default_handle_color
if can_drag_left:
    left_color = draggable_handle_color
# 修复：选中Clip时手柄保持白色，不使用黄色

# 根据可拖拽状态选择颜色
var right_color = default_handle_color
if can_drag_right:
    right_color = draggable_handle_color
# 修复：选中Clip时手柄保持白色，不使用黄色
```

### 最终颜色方案
- **Clip默认颜色**：蓝色（Color.BLUE）
- **Clip选中颜色**：亮黄色（Color.YELLOW）
- **手柄默认颜色**：白色（Color.WHITE）
- **手柄可拖拽颜色**：亮青色（Color.CYAN）
- **手柄选中时颜色**：白色（Color.WHITE）【修复后】

### 视觉效果改进
1. **清晰的颜色区分**：Clip主体使用黄色表示选中状态，手柄保持白色，避免颜色混淆
2. **更好的可见性**：白色手柄在黄色Clip背景上更加清晰可见
3. **一致的视觉语言**：手柄颜色只反映可拖拽状态，不重复表示选中状态
4. **专业的编辑体验**：颜色层次更加清晰，符合专业编辑器的设计规范

### 测试步骤
1. 在Timeline编辑器中创建一个Feedback Track
2. 点击选中该Clip，观察Clip变为黄色
3. 确认左右边界手柄保持白色，而不是黄色
4. 将鼠标移动到边界上，观察手柄变为亮青色
5. 移开鼠标，手柄恢复为白色

这个修复进一步优化了Timeline Clip系统的视觉反馈，提供了更加清晰和专业的编辑体验。

## 时间刻度显示修复

### 问题描述
用户反馈Timeline的时间轴刻度从5秒开始而不是0秒开始，导致时间显示不准确。

### 问题分析
问题出现在`_draw_grid()`函数中的双重偏移计算：

1. **时间范围计算**：`start_time = view_offset`
2. **屏幕坐标转换**：`x = _time_to_screen(current_time) = (current_time - view_offset) * pixels_per_second * zoom_level`

这导致了双重偏移：先加上`view_offset`，然后又减去`view_offset`，造成时间刻度显示错误。

### 修复内容
在`_draw_grid()`函数中直接计算屏幕位置，避免双重偏移：

**修复前的代码**：
```gdscript
func _draw_grid():
    var rect = get_rect()
    var start_time = view_offset
    var end_time = view_offset + rect.size.x / (pixels_per_second * zoom_level)
    
    # 绘制垂直网格线（时间刻度）
    var interval = _get_grid_interval()
    var current_time = floor(start_time / interval) * interval
    
    while current_time <= end_time:
        var x = _time_to_screen(current_time)  # 这里会再次减去view_offset，造成双重偏移
        if x >= 0 and x <= rect.size.x:
            draw_line(Vector2(x, 0), Vector2(x, rect.size.y), grid_color)
        current_time += interval
```

**修复后的代码**：
```gdscript
func _draw_grid():
    var rect = get_rect()
    # 修复：直接计算可见时间范围，避免双重偏移
    var start_time = view_offset
    var end_time = view_offset + rect.size.x / (pixels_per_second * zoom_level)
    
    # 绘制垂直网格线（时间刻度）
    var interval = _get_grid_interval()
    var current_time = floor(start_time / interval) * interval
    
    while current_time <= end_time:
        # 修复：直接计算屏幕位置，避免双重偏移
        var x = (current_time - view_offset) * pixels_per_second * zoom_level
        if x >= 0 and x <= rect.size.x:
            draw_line(Vector2(x, 0), Vector2(x, rect.size.y), grid_color)
        current_time += interval
```

### 关键修复点
1. **消除双重偏移**：直接计算屏幕坐标，而不是调用`_time_to_screen()`
2. **保持一致性**：确保网格绘制与其他绘制逻辑使用相同的坐标转换
3. **正确的0点对齐**：时间刻度现在正确从0秒开始显示

### 测试步骤
1. 创建一个新的Timeline资源
2. 在Timeline编辑器中查看时间刻度
3. 确认最左侧的时间刻度显示为0秒，而不是5秒
4. 滚动时间轴，确认时间刻度始终保持正确的显示

### 技术细节
**问题根源**：
- `view_offset`用于控制时间轴的滚动偏移
- `_time_to_screen()`函数内部会减去`view_offset`
- 在网格绘制中先使用`view_offset`计算时间范围，再调用`_time_to_screen()`造成双重偏移

**解决方案**：
- 在网格绘制中直接计算屏幕坐标：`(current_time - view_offset) * pixels_per_second * zoom_level`
- 避免调用`_time_to_screen()`函数，消除双重偏移问题
- 保持与其他绘制函数的坐标转换一致性

这个修复确保了Timeline时间刻度的正确显示，提供了准确的时间参考，大大提升了编辑的精确性和用户体验。