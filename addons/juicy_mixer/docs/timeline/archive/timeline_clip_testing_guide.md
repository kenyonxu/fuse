# Timeline可视化Clip功能测试指南

## 概述

本文档提供了测试JuicyTimeline可视化Clip功能的完整指南，包括功能验证、使用示例和故障排除。

## 功能特性

### 1. 混合模式支持
- **传统模式**：保持原有的start_time + duration操作方式
- **可视化Clip模式**：提供拖拽、缩放等直观操作
- **模式切换**：通过右键菜单或API调用切换

### 2. 可视化Clip交互
- **Clip选择**：点击Feedback Track进行选择
- **拖拽移动**：拖拽Clip主体改变时间位置
- **边界调整**：拖拽左右边界调整开始时间和持续时间
- **视觉反馈**：选中高亮、手柄显示、鼠标悬停效果

### 3. Clip操作
- **复制Clip**：右键菜单复制选中的Clip
- **删除Clip**：右键菜单删除选中的Clip
- **属性查看**：右键菜单查看Clip属性
- **参数映射支持**：完整支持现有的参数映射系统

## 测试步骤

### 基础功能测试

#### 1. 创建Timeline资源
```gdscript
# 创建Timeline资源
var timeline = JuicyTimelineResource.new()
timeline.duration = 5.0

# 添加Feedback Track
var audio_resource = preload("res://assets/hit_sound.tres")
var feedback_track = JuicyFeedbackTrack.new()
feedback_track.track_name = "Hit Sound"
feedback_track.resource = audio_resource
feedback_track.start_time = 1.0
feedback_track.duration = 2.0
timeline.tracks.append(feedback_track)

# 保存资源
ResourceSaver.save(timeline, "res://test_timeline.tres")
```

#### 2. 在编辑器中测试
1. 在Godot编辑器中选择Timeline资源
2. 确保Timeline Canvas正确显示
3. 验证Feedback Track以橙色块显示

#### 3. 模式切换测试
```gdscript
# 获取Timeline Canvas引用
var canvas = get_node("JuicyTimelineCanvas")

# 切换到可视化Clip模式
canvas.set_edit_mode(1)

# 切换回传统模式
canvas.set_edit_mode(0)

# 检查当前模式
var current_mode = canvas.get_edit_mode()
print("当前编辑模式: ", "传统" if current_mode == 0 else "可视化Clip")
```

### 可视化交互测试

#### 1. Clip选择测试
- **操作**：点击Feedback Track
- **预期结果**：
  - Track变为黄色高亮
  - 显示左右边界手柄（青色）
  - 控制台输出选择信息

#### 2. 拖拽移动测试
- **操作**：
  1. 选中Clip
  2. 拖拽Clip主体（非边界区域）
  3. 释放鼠标
- **预期结果**：
  - Clip移动到新位置
  - start_time相应更新
  - timeline_changed信号触发

#### 3. 边界调整测试
- **操作**：
  1. 选中Clip
  2. 拖拽左边界或右边界手柄
  3. 释放鼠标
- **预期结果**：
  - 左边界拖拽：调整start_time
  - 右边界拖拽：调整duration
  - 保持最小值限制（0.1秒）

#### 4. 右键菜单测试
- **操作**：在可视化Clip模式下右键点击Clip
- **预期结果**：
  - 显示"复制Clip"、"删除Clip"、"Clip属性..."选项
  - 显示模式切换选项

### 高级功能测试

#### 1. 参数映射测试
```gdscript
# 为Feedback Track添加参数映射
var intensity_mapping = JuicyParameterMapping.new()
intensity_mapping.input_parameter = "intensity"
intensity_mapping.target_property = "amplitude"
intensity_mapping.curve = preload("res://intensity_curve.tres")

feedback_track.use_parameter_mapping = true
feedback_track.parameter_mappings.append(intensity_mapping)
```

#### 2. 多Clip测试
```gdscript
# 添加多个Feedback Track
for i in range(3):
    var track = JuicyFeedbackTrack.new()
    track.track_name = "Effect " + str(i)
    track.start_time = i * 1.5
    track.duration = 1.0
    track.resource = audio_resource
    timeline.tracks.append(track)
```

## 验证清单

### 基础功能
- [ ] Timeline资源正确加载
- [ ] Feedback Track正确显示
- [ ] 传统模式正常工作
- [ ] 可视化Clip模式正常工作
- [ ] 模式切换无错误

### 交互功能
- [ ] Clip选择正确响应
- [ ] 拖拽移动流畅
- [ ] 边界调整准确
- [ ] 视觉反馈清晰
- [ ] 吸附功能正常

### 操作功能
- [ ] 右键菜单正确显示
- [ ] Clip复制功能正常
- [ ] Clip删除功能正常
- [ ] 属性查看功能正常
- [ ] 模式切换选项正常

### 性能和稳定性
- [ ] 大量Clip时性能良好
- [ ] 长时间轴操作流畅
- [ ] 内存使用稳定
- [ ] 无内存泄漏
- [ ] 错误处理完善

## 故障排除

### 常见问题

#### 1. Clip无法选择
**可能原因**：
- edit_mode未设置为1（可视化Clip模式）
- Feedback Track类型检测失败
- 鼠标事件被其他控件拦截

**解决方案**：
```gdscript
# 确保模式正确
canvas.set_edit_mode(1)

# 检查Track类型
print("Track类型: ", track.get_track_type())

# 检查鼠标事件
print("鼠标过滤器: ", canvas.mouse_filter)
```

#### 2. 拖拽无响应
**可能原因**：
- is_dragging状态未正确设置
- clip_drag_mode未正确初始化
- 坐标转换错误

**解决方案**：
```gdscript
# 调试拖拽状态
print("拖拽状态: ", canvas.is_dragging)
print("Clip拖拽模式: ", canvas.clip_drag_mode)
print("选中Clip: ", canvas.selected_clip)

# 测试坐标转换
var test_pos = Vector2(100, 50)
var time = canvas._screen_to_time(test_pos.x)
var screen_x = canvas._time_to_screen(time)
print("坐标转换测试: ", test_pos.x, " -> ", time, " -> ", screen_x)
```

#### 3. 视觉反馈异常
**可能原因**：
- 绘制函数调用顺序错误
- 颜色设置问题
- queue_redraw()未调用

**解决方案**：
```gdscript
# 强制重绘
canvas.queue_redraw()

# 检查绘制状态
print("编辑模式: ", canvas.edit_mode)
print("选中Clip: ", canvas.selected_clip)
```

## 性能优化建议

### 1. 大量Clip优化
- 限制同时显示的Clip数量
- 使用视口裁剪，只绘制可见区域
- 优化手柄绘制，减少不必要的重绘

### 2. 交互优化
- 使用鼠标悬停检测，避免频繁的命中测试
- 实现拖拽预览，提供实时反馈
- 优化坐标转换计算

### 3. 内存管理
- 及时清理临时对象
- 避免在绘制函数中创建新对象
- 使用对象池管理Clip相关资源

## 扩展建议

### 1. 多选支持
- 实现Ctrl+点击多选Clip
- 批量操作支持
- 选择框工具

### 2. 键盘快捷键
- Delete键删除选中Clip
- Ctrl+D复制Clip
- Ctrl+V粘贴Clip
- 方向键微调位置

### 3. 撤销重做支持
- 记录操作历史
- 实现撤销/重做功能
- 支持多级撤销

## 总结

Timeline可视化Clip功能为JuicyMixer V3提供了现代化的编辑体验，通过直观的拖拽操作和视觉反馈，大大提升了Timeline编辑的效率和易用性。建议按照本指南进行系统化测试，确保所有功能正常工作。