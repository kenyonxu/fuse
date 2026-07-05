# Tween 通用使用模式参考

> 本文档汇总了 Godot 游戏开发中最常用的 Tween 动画模式，适用于 JuicyMixer 系统设计和实际开发参考。

**最后更新：** 2026-01-27
**适用版本：** Godot 4.5+

---

## 目录

1. [基础动画模式](#基础动画模式)
2. [组合模式](#组合模式)
3. [时序控制](#时序控制)
4. [回调和控制](#回调和控制)
5. [缓动效果](#缓动效果)
6. [复合效果](#复合效果)
7. [特殊应用](#特殊应用)

---

## 基础动画模式

### 1. tween 透明度 fade_in
```gdscript
tween.tween_property(target, "modulate:a", 1.0, duration)
```
**典型场景：** UI 淡入、传送出现、角色显形、场景切换
**参数建议：** duration 0.3-1.0 秒

### 2. tween 透明度 fade_out
```gdscript
tween.tween_property(target, "modulate:a", 0.0, duration)
```
**典型场景：** UI 淡出、传送消失、物品收集、场景过渡
**参数建议：** duration 0.3-1.0 秒

### 3. tween 透明度 flash
```gdscript
var tween = create_tween()
tween.set_loops(count)
tween.tween_property(target, "modulate:a", 0.0, duration1)
tween.tween_property(target, "modulate:a", 1.0, duration2)
```
**典型场景：** 受击闪烁、警告闪烁、选中高亮、无敌状态
**参数建议：** duration 0.05-0.1 秒，loops 2-5 次

### 4. tween 位置 move_to
```gdscript
tween.tween_property(target, "position", target_position, duration)
```
**典型场景：** 角色移动、UI滑入滑出、门开关、平台移动
**缓动建议：** EASE_IN_OUT 用于平滑移动

### 5. tween 位置 move_relative
```gdscript
tween.tween_property(target, "position", offset, duration).as_relative()
```
**典型场景：** 震动偏移、跳跃高度、向上飘出
**参数建议：** offset Vector2(0, -50) 向上飘出效果

### 6. tween 位置 shake
```gdscript
var tween = create_tween()
tween.set_loops(count)
tween.tween_property(target, "position:axis", amplitude, duration).as_relative()
tween.tween_property(target, "position:axis", -amplitude, duration).as_relative()
```
**典型场景：** 受击震动、爆炸震动、相机震动、错误提示
**参数建议：** amplitude 5-20 像素，duration 0.03-0.1 秒

### 7. tween 缩放 scale_up
```gdscript
tween.tween_property(target, "scale", Vector2(large, large), duration)
```
**典型场景：** 按钮悬停、收集放大、选中反馈、强调效果
**参数建议：** scale 1.1-1.5 倍

### 8. tween 缩放 scale_down
```gdscript
tween.tween_property(target, "scale", Vector2(small, small), duration)
```
**典型场景：** 按钮按下、缩小消失、收集完成、收缩效果
**参数建议：** scale 0.8-0.95 倍

### 9. tween 缩放 scale_pop
```gdscript
var tween = create_tween()
tween.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
tween.tween_property(target, "scale", Vector2.ONE, duration)
```
**典型场景：** 弹出框、宝箱打开、气泡提示、通知弹窗
**初始状态：** scale = Vector2.ZERO
**参数建议：** duration 0.3-0.5 秒

### 10. tween 缩放 scale_pulse
```gdscript
var tween = create_tween()
tween.set_loops()
tween.tween_property(target, "scale", Vector2(1.1, 1.1), duration1)
tween.tween_property(target, "scale", Vector2.ONE, duration2)
```
**典型场景：** 待机动画、呼吸效果、重要提示、可交互提示
**参数建议：** duration 0.8-1.5 秒

### 11. tween 旋转 rotate_to
```gdscript
tween.tween_property(target, "rotation", target_angle, duration)
```
**典型场景：** 攻击挥动、门旋转、道具旋转、指针转向

### 12. tween 旋转 rotate_relative
```gdscript
tween.tween_property(target, "rotation", angle_offset, duration).as_relative()
```
**典型场景：** 挥动攻击、摇晃效果、摆动动画

### 13. tween 颜色 color_transition
```gdscript
tween.tween_property(target, "modulate", target_color, duration)
```
**典型场景：** 受伤变红、状态指示、环境变化、UI 主题切换
**常用颜色：** Color.RED (受伤)、Color.GREEN (治疗)、Color.YELLOW (警告)

### 14. tween 数值 value_lerp
```gdscript
tween.tween_property(progress_bar, "value", target_value, duration)
```
**典型场景：** 血条变化、经验值、进度条、加载条
**参数建议：** duration 0.3-0.5 秒

### 15. tween 文本 text_count
```gdscript
tween.tween_method(update_text, start_value, end_value, duration)

func update_text(value):
    label.text = str(value)
```
**典型场景：** 分数计数、数字滚动、金币增加、连击数

---

## 组合模式

### 16. tween 并行 parallel
```gdscript
tween.tween_parallel()
tween.tween_property(target, "property1", value1, duration1)
tween.tween_property(target, "property2", value2, duration2)
```
**典型场景：** 位置+旋转、缩放+透明度、复杂动画
**用途：** 多个属性同时变化，创造复合效果

### 17. tween 序列 sequence
```gdscript
tween.tween_property(target, "property1", value1, duration1)
tween.tween_property(target, "property2", value2, duration2)
tween.tween_property(target, "property3", value3, duration3)
```
**典型场景：** 过场动画、组合动作、流程动画
**用途：** 按顺序执行多个动画

### 18. tween 循环 loop
```gdscript
tween.set_loops()  # 无限循环
tween.set_loops(count)  # 指定次数
tween.tween_property(target, "property", value, duration)
```
**典型场景：** 待机动画、呼吸效果、背景移动、装饰动画

### 19. tween 往复 ping_pong
```gdscript
tween.set_loops()
tween.tween_property(target, "property", value1, duration1)
tween.tween_property(target, "property", value2, duration2)
```
**典型场景：** 呼吸效果、浮动效果、闪烁、摆动
**用途：** 在两个状态之间循环切换

---

## 时序控制

### 20. tween 延迟 delay
```gdscript
tween.tween_property(target, "property", value, duration).set_delay(delay_time)
```
**典型场景：** 连续动画、延迟启动、时序配合、连锁反应
**参数建议：** delay 0.1-2.0 秒

### 21. tween 等待 wait
```gdscript
tween.tween_interval(wait_time)
```
**典型场景：** 动画间停顿、过场节奏、演示暂停
**用途：** 在动画序列中插入等待时间

### 22. tween 速度 speed_based
```gdscript
tween.tween_property(target, "property", value, speed).set_speed_based()
```
**典型场景：** 恒定速度移动、匀速旋转
**用途：** 以速度而非时间控制动画

---

## 回调和控制

### 23. tween 回调 start_callback
```gdscript
tween.tween_callback(func_name).set_delay(0)
```
**典型场景：** 动画开始前的准备、状态初始化、音效播放

### 24. tween 回调 end_callback
```gdscript
tween.tween_property(target, "property", value, duration)
tween.tween_callback(func_name)
```
**典型场景：** 动画完成后的清理、状态更新、触发下一个事件

### 25. tween 回调 cleanup_callback
```gdscript
tween.tween_property(target, "modulate:a", 0.0, duration)
tween.tween_callback(target.queue_free)
```
**典型场景：** 动画完成后删除对象、资源回收、临时对象清理

---

## 缓动效果

### 26. tween 缓动 ease_in
```gdscript
tween.set_ease(Tween.EASE_IN)
tween.tween_property(target, "property", value, duration)
```
**典型场景：** 加速启动、重力下落、快速开始
**效果：** 慢速开始，快速结束

### 27. tween 缓动 ease_out
```gdscript
tween.set_ease(Tween.EASE_OUT)
tween.tween_property(target, "property", value, duration)
```
**典型场景：** 减速停止、自然停止、平滑着陆
**效果：** 快速开始，慢速结束

### 28. tween 缓动 ease_in_out
```gdscript
tween.set_ease(Tween.EASE_IN_OUT)
tween.tween_property(target, "property", value, duration)
```
**典型场景：** 平滑移动、过渡动画、UI 交互
**效果：** 慢速开始和结束，中间加速

### 29. tween 过渡 trans_back
```gdscript
tween.set_trans(Tween.TRANS_BACK)
tween.tween_property(target, "property", value, duration)
```
**典型场景：** UI滑入、弹出效果、回弹效果
**效果：** 略微超过目标值后返回

### 30. tween 过渡 trans_bounce
```gdscript
tween.set_trans(Tween.TRANS_BOUNCE)
tween.tween_property(target, "property", value, duration)
```
**典型场景：** 物品掉落、落地效果、弹性碰撞
**效果：** 到达目标时弹跳

### 31. tween 过渡 trans_spring
```gdscript
tween.set_trans(Tween.TRANS_SPRING)
tween.tween_property(target, "property", value, duration)
```
**典型场景：** 弹出框、弹性效果、快速弹出
**效果：** 弹簧式震荡到达目标

### 32. tween 过渡 trans_elastic
```gdscript
tween.set_trans(Tween.TRANS_ELASTIC)
tween.tween_property(target, "property", value, duration)
```
**典型场景：** 弹性拉伸、夸张动画、特殊效果
**效果：** 强烈的弹性震荡

---

## 复合效果

### 33. tween 复合 fade_move
```gdscript
tween.parallel()
tween.tween_property(target, "modulate:a", 0.0, duration)
tween.tween_property(target, "position", target_pos, duration)
```
**典型场景：** 收集物品、传送效果、飞向UI、消失移动

### 34. tween 复合 scale_color
```gdscript
tween.parallel()
tween.tween_property(target, "scale", target_scale, duration)
tween.tween_property(target, "modulate", target_color, duration)
```
**典型场景：** 按钮交互、状态变化、选中效果、激活效果

### 35. tween 复合 shake_flash
```gdscript
var tween = create_tween()
tween.set_parallel(true).set_loops(count)
tween.tween_property(target, "position", offset, duration).as_relative()
tween.tween_property(target, "modulate:a", 0.0, duration)
tween.tween_property(target, "modulate:a", 1.0, duration)
```
**典型场景：** 受击反馈、爆炸效果、强烈冲击、警告提示
**参数建议：** loops 3-5 次，duration 0.05-0.1 秒

### 36. tween 复合 float_rotate
```gdscript
tween.set_parallel(true).set_loops()
tween.tween_property(target, "position:y", offset, duration1).as_relative()
tween.tween_property(target, "position:y", -offset, duration2).as_relative()
tween.tween_property(target, "rotation", angle, duration1)
tween.tween_property(target, "rotation", -angle, duration2)
```
**典型场景：** 浮动物品、待机动画、装饰元素、收集物
**参数建议：** offset 5-20 像素，angle 0.05-0.2 弧度

---

## 特殊应用

### 37. tween 方法 method_tween
```gdscript
tween.tween_method(set_value, start_value, end_value, duration)
```
**典型场景：** 自定义属性更新、音频音量、相机参数、自定义数值
**用途：** 补间任意可通过方法设置的值

### 38. tween 多个对象 multi_target
```gdscript
for obj in object_list:
    var tween = create_tween()
    tween.tween_property(obj, "property", value, duration).set_delay(index * delay)
```
**典型场景：** 波浪动画、连锁反应、依次出现、队列动画
**参数建议：** delay 0.05-0.2 秒

### 39. tween 链式 chained
```gdscript
tween.tween_property(target1, "property1", value1, duration1)
tween.tween_property(target2, "property2", value2, duration2)
tween.tween_callback(final_function)
```
**典型场景：** 过场动画、故事序列、连续事件、复杂交互
**用途：** 跨多个对象的连续动画

---

## 实际应用示例

### UI 交互动画
```gdscript
# 按钮悬停
func _on_mouse_entered():
    create_tween().tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)

# 按钮按下
func _on_button_pressed():
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.05)
    tween.tween_property(self, "scale", Vector2.ONE, 0.05)
```

### 角色受击反馈
```gdscript
func take_damage():
    var tween = create_tween()
    tween.set_parallel(true)

    # 闪烁
    var flash_tween = create_tween()
    flash_tween.set_loops(3)
    flash_tween.tween_property(sprite, "modulate", Color.TRANSPARENT, 0.05)
    flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)

    # 震动
    tween.tween_property(self, "position:x", 10, 0.05).as_relative()
    tween.tween_property(self, "position:x", -10, 0.05).as_relative()
    tween.tween_property(self, "position:x", 0, 0.05).as_relative()
```

### 收集物品动画
```gdscript
func collect_item(item: Node2D, ui_target: Control):
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(item, "global_position", ui_target.global_position, 0.5)
    tween.tween_property(item, "scale", Vector2(0.2, 0.2), 0.5)
    tween.tween_property(item, "modulate:a", 0.0, 0.5)
    tween.tween_callback(item.queue_free)
```

### 弹出框动画
```gdscript
func show_popup(popup: Control):
    popup.scale = Vector2.ZERO
    popup.modulate.a = 0.0

    var tween = create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
    tween.tween_property(popup, "scale", Vector2.ONE, 0.4)
    tween.tween_property(popup, "modulate:a", 1.0, 0.3)
```

### 伤害数字飘出
```gdscript
func show_damage_number(value: int, pos: Vector2):
    var label = damage_label_scene.instantiate()
    label.global_position = pos
    label.text = str(value)
    add_child(label)

    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(label, "global_position:y", pos.y - 50, 1.0)
    tween.tween_property(label, "modulate:a", 0.0, 1.0)
    tween.tween_callback(label.queue_free)
```

---

## 缓动函数速查表

| 缓动类型 | 效果描述 | 典型用途 |
|---------|---------|---------|
| `EASE_IN` | 慢速开始，快速结束 | 重力下落、加速启动 |
| `EASE_OUT` | 快速开始，慢速结束 | 减速停止、平滑着陆 |
| `EASE_IN_OUT` | 慢速开始和结束 | 平滑移动、UI过渡 |
| `EASE_OUT_IN` | 快速开始和结束 | 快速过渡 |

| 过渡类型 | 效果描述 | 典型用途 |
|---------|---------|---------|
| `TRANS_LINEAR` | 线性匀速 | 简单移动、基础动画 |
| `TRANS_SINE` | 正弦曲线 | 自然运动、平滑过渡 |
| `TRANS_QUAD` | 二次曲线 | 基础加速/减速 |
| `TRANS_CUBIC` | 三次曲线 | 标准动画曲线 |
| `TRANS_QUART` | 四次曲线 | 明显加速/减速 |
| `TRANS_QUINT` | 五次曲线 | 强烈加速/减速 |
| `TRANS_EXPO` | 指数曲线 | 极速启动/停止 |
| `TRANS_CIRC` | 圆形曲线 | 平滑过渡动画 |
| `TRANS_BACK` | 回弹效果 | UI滑入、弹出效果 |
| `TRANS_SPRING` | 弹簧效果 | 弹性动画、快速弹出 |
| `TRANS_BOUNCE` | 弹跳效果 | 掉落动画、落地效果 |
| `TRANS_ELASTIC` | 弹性拉伸 | 夸张动画、特殊效果 |

---

## 最佳实践

### 1. 选择合适的持续时间
- **快速反馈：** 0.05-0.15 秒（按钮点击、闪烁）
- **UI 动画：** 0.2-0.5 秒（淡入淡出、滑入滑出）
- **角色动作：** 0.3-0.8 秒（移动、攻击）
- **过场动画：** 0.5-2.0 秒（场景切换、复杂序列）

### 2. 选择合适的缓动
- **UI 交互：** EASE_OUT + TRANS_BACK 或 TRANS_SPRING
- **自然移动：** EASE_IN_OUT + TRANS_SINE 或 TRANS_QUAD
- **掉落效果：** EASE_OUT + TRANS_BOUNCE
- **弹性效果：** EASE_OUT + TRANS_ELASTIC

### 3. 性能优化
- 避免同时运行过多 Tween
- 使用 `tween.kill()` 及时清理完成的 Tween
- 对于循环动画，考虑重用同一个 Tween
- 大量对象动画时使用对象池

### 4. 代码组织
- 将常用动画封装成函数
- 使用信号连接回调函数
- 为动画创建独立的辅助类
- 保持动画代码可读性和可维护性

### 5. 调试技巧
- 使用 `tween.is_valid()` 检查 Tween 是否有效
- 使用 `tween.is_running()` 检查动画状态
- 添加 `print_debug()` 输出动画关键节点
- 在编辑器中使用调试面板监控动画

---

## 参考资料

- [Godot 官方文档 - Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html)
- [JuicyMixer Tween Track](../addons/juicy_mixer/docs/tween-track.md)
- [项目开发规范](../CLAUDE.md)

---

**总计：** 39 种通用 Tween 使用模式

**维护者：** JuicyGodot 项目组
**许可：** 项目内部文档
