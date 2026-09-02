# Tween 补间动画使用指南

> Fuse 可视化编程系统的 Tween 动画指令完整使用指南

**最后更新：** 2026-01-28
**Godot 版本：** 4.7+

---

## 目录

1. [概述](#概述)
2. [基础动画指令](#基础动画指令)
3. [预置动画指令](#预置动画指令)
4. [高级功能](#高级功能)
5. [参数说明](#参数说明)
6. [常见使用场景](#常见使用场景)
7. [最佳实践](#最佳实践)

---

## 概述

Fuse Tween 指令系统提供了一组完整的补间动画指令，基于 Godot 原生 Tween 系统，支持几乎所有游戏动画需求。

### 指令分类

**基础属性动画 (P0-P1)**：
- Tween Fade In/Out - 透明度淡入淡出
- Tween Move To - 位置移动
- Tween Scale To - 缩放
- Tween Rotate To - 旋转
- Tween Color Transition - 颜色过渡

**预置动画 (P2-P3)**：
- Tween Pop Animation - 弹出效果
- Tween Shake Animation - 震动效果
- Tween Bounce Animation - 弹跳效果
- Tween Pulse Animation - 脉冲/呼吸效果

**高级功能 (P3)**：
- Tween Property - 通用属性动画（支持任意属性）

### 核心特性

- ✅ **异步执行** - 所有 Tween 指令都是异步的，不会阻塞游戏逻辑
- ✅ **可取消** - 所有动画都支持中途取消
- ✅ **参数丰富** - 支持缓动类型、过渡类型等高级参数
- ✅ **自动释放** - Fade Out 和 Property 指令支持动画完成后自动释放节点
- ✅ **本地化** - 完整的中文界面支持
- ✅ **易用性** - 可视化编辑器，无需编码

---

## 基础动画指令

### Tween Fade In - 淡入动画

让节点逐渐变为不透明。

**参数：**
- `target_node` - 目标节点
- `duration` - 持续时间（秒）
- `from_alpha` - 起始透明度（0.0-1.0）
- `to_alpha` - 目标透明度（0.0-1.0）
- `easing_type` - 缓动类型（In/Out/InOut/OutIn）
- `trans_type` - 过渡类型（Linear/Sine/Quad 等）

**典型用途：**
- UI 淡入显示
- 角色传送出现
- 场景过渡效果

**示例：**
```
淡入速度：1.0 秒
透明度：0.0 → 1.0
缓动：Out + Sine（平滑减速）
```

---

### Tween Fade Out - 淡出动画

让节点逐渐变为透明，并可选择自动释放节点。

**参数：**
- `target_node` - 目标节点
- `duration` - 持续时间（秒）
- `auto_free` - 动画结束后是否自动释放节点
- `easing_type` - 缓动类型
- `trans_type` - 过渡类型

**典型用途：**
- UI 淡出关闭
- 物品收集消失
- 临时对象清理（启用 auto_free）

**auto_free 用法：**
- `auto_free = false`（默认）- 节点保留，只是透明
- `auto_free = true` - 动画完成后自动删除节点

**示例：**
```
淡出速度：0.5 秒
auto_free：true（收集物品后自动删除）
```

---

### Tween Move To - 移动动画

平滑移动节点到目标位置。

**参数：**
- `target_node` - 目标节点
- `target_position` - 目标位置 (Vector2)
- `duration` - 持续时间（秒）
- `space_mode` - 坐标空间（Global/Local）
- `easing_type` - 缓动类型
- `trans_type` - 过渡类型

**坐标空间说明：**
- `Global` - 全局坐标（世界坐标）
- `Local` - 本地坐标（相对父节点）

**典型用途：**
- 角色移动
- UI 滑入滑出
- 门开关动画

**示例：**
```
移动到：(100, 200)
持续：1.0 秒
坐标：Global
缓动：InOut + Sine（平滑加速和减速）
```

---

### Tween Scale To - 缩放动画

平滑缩放节点到目标大小。

**参数：**
- `target_node` - 目标节点
- `target_scale` - 目标缩放值 (Vector2)
- `duration` - 持续时间（秒）
- `easing_type` - 缓动类型
- `trans_type` - 过渡类型

**缩放值说明：**
- `Vector2(1, 1)` - 原始大小
- `Vector2(2, 2)` - 放大 2 倍
- `Vector2(0.5, 0.5)` - 缩小到一半
- `Vector2(0, 0)` - 缩小到零

**典型用途：**
- 按钮悬停放大
- 收集物品放大
- UI 强调效果

**示例：**
```
缩放到：1.5 倍
持续：0.3 秒
缓动：Out + Back（略微超过后返回）
```

---

### Tween Rotate To - 旋转动画

平滑旋转节点到目标角度。

**参数：**
- `target_node` - 目标节点
- `target_rotation` - 目标角度（度）
- `duration` - 持续时间（秒）
- `space_mode` - 坐标空间（Global/Local）
- `easing_type` - 缓动类型
- `trans_type` - 过渡类型

**典型用途：**
- 攻击挥动
- 门旋转开关
- 指针转向

**示例：**
```
旋转到：90 度
持续：0.5 秒
坐标：Local
缓动：InOut + Sine
```

---

### Tween Color Transition - 颜色过渡

平滑改变节点颜色。

**参数：**
- `target_node` - 目标节点
- `target_color` - 目标颜色 (Color)
- `duration` - 持续时间（秒）
- `easing_type` - 缓动类型
- `trans_type` - 过渡类型

**典型用途：**
- 受伤变红
- 状态指示（绿色=安全，黄色=警告）
- 环境变化

**示例：**
```
颜色：白色 → 红色
持续：0.3 秒
用途：角色受伤
```

---

## 预置动画指令

### Tween Pop Animation - 弹出动画

弹簧弹出效果，从缩放 0 快速弹出。

**参数：**
- `target_node` - 目标节点
- `target_scale` - 目标缩放值
- `duration` - 持续时间

**效果特点：**
- 使用 TRANS_SPRING + EASE_OUT
- 从缩放 0 开始，弹簧式到达目标值
- 适合弹窗、宝箱、气泡等

**典型用途：**
- 弹出框显示
- 宝箱打开
- 气泡提示

**示例：**
```
目标缩放：1.0
持续：0.4 秒
效果：弹簧弹出
```

---

### Tween Shake Animation - 震动动画

震动效果，支持不同轴向和强度。

**参数：**
- `target_node` - 目标节点
- `intensity` - 震动强度（像素）
- `duration` - 每次震动持续时间
- `shake_count` - 震动次数
- `shake_axis` - 震动轴向（X/Y/XY）

**轴向说明：**
- `X` - 水平震动
- `Y` - 垂直震动
- `XY` - 双向震动

**典型用途：**
- 受击反馈
- 爆炸震动
- 错误提示

**示例：**
```
强度：15 像素
次数：3 次
轴向：XY
```

---

### Tween Bounce Animation - 弹跳动画

弹跳效果，模拟掉落后的反弹。

**参数：**
- `target_node` - 目标节点
- `bounce_height` - 弹跳高度（像素）
- `bounce_count` - 弹跳次数
- `duration` - 持续时间

**效果特点：**
- 使用 TRANS_BOUNCE + EASE_OUT
- 到达目标时弹跳
- 适合掉落效果

**典型用途：**
- 物品掉落
- 弹跳球
- 落地效果

**示例：**
```
弹跳高度：50 像素
次数：3 次
持续：0.5 秒
```

---

### Tween Pulse Animation - 脉冲动画

呼吸/脉冲效果，缩放往复动画。

**参数：**
- `target_node` - 目标节点
- `min_scale` - 最小缩放值
- `max_scale` - 最大缩放值
- `duration` - 单次循环持续时间
- `loop_count` - 循环次数（0 = 无限循环）

**循环说明：**
- `loop_count = 0` - 无限循环（需要手动停止）
- `loop_count = 3` - 循环 3 次后停止

**典型用途：**
- 待机动画
- 呼吸效果
- 可交互提示

**示例：**
```
最小缩放：0.9
最大缩放：1.1
持续：1.0 秒
循环：0（无限）
```

---

## 高级功能

### Tween Property - 通用属性动画

动画化节点的任意属性，支持 Material 动画。

**参数：**
- `target_node` - 目标节点
- `property_path` - 属性路径（下拉选择）
- `to_value` - 目标值
- `duration` - 持续时间
- `auto_free` - 是否自动释放节点
- `easing_type` - 缓动类型
- `trans_type` - 过渡类型

**支持的属性类型：**
- 基础属性：position, scale, rotation, modulate 等
- 子属性：modulate:a, position:x, position:y 等
- Material 属性：material, material_override
- Shader 参数：material:shader_param/name

**Material 动画支持：**
- Shared Material（共享材质）
- Material Override（材质覆盖）
- Shader Uniform 参数

**典型用途：**
- 特殊属性动画
- Material 效果动画
- Shader 参数动画

**示例：**
```
属性：modulate:a（透明度）
目标值：0.0
持续：1.0 秒
```

---

## 参数说明

### 缓动类型 (Easing Type)

控制动画速度的变化方式。

| 缓动类型 | 效果 | 典型用途 |
|---------|------|---------|
| **In** | 慢速开始，快速结束 | 重力下落、加速启动 |
| **Out** | 快速开始，慢速结束 | 减速停止、平滑着陆 |
| **InOut** | 慢速开始和结束 | 平滑移动、UI 过渡 |
| **OutIn** | 快速开始和结束 | 快速过渡 |

**推荐：**
- UI 动画：Out
- 自然移动：InOut
- 掉落效果：Out

---

### 过渡类型 (Transition Type)

控制动画的数学曲线。

| 过渡类型 | 效果 | 典型用途 |
|---------|------|---------|
| **Linear** | 线性匀速 | 简单移动 |
| **Sine** | 正弦曲线 | 自然运动、平滑过渡 |
| **Quad** | 二次曲线 | 基础加速/减速 |
| **Cubic** | 三次曲线 | 标准动画曲线 |
| **Back** | 回弹效果 | UI 滑入、弹出效果 |
| **Spring** | 弹簧效果 | 弹性动画、快速弹出 |
| **Bounce** | 弹跳效果 | 掉落动画、落地效果 |
| **Elastic** | 弹性拉伸 | 夸张动画、特殊效果 |

**推荐：**
- UI 交互：Out + Back 或 Spring
- 自然移动：InOut + Sine
- 掉落效果：Out + Bounce
- 弹性效果：Out + Elastic

---

## 常见使用场景

### 场景 1：UI 按钮悬停效果

**目标：** 鼠标悬停时按钮放大

**实现：**
1. 使用 **Tween Scale To**
2. 目标缩放：`Vector2(1.1, 1.1)`
3. 持续时间：`0.1` 秒
4. 缓动：`Out` + `Back`

**Fuse 事件：**
```
On Mouse Enter → Tween Scale To (1.1)
On Mouse Exit → Tween Scale To (1.0)
```

---

### 场景 2：角色受击反馈

**目标：** 角色受伤时闪烁并震动

**实现：**
1. 使用 **Tween Shake Animation**
2. 强度：`10` 像素
3. 次数：`3` 次
4. 轴向：`XY`

**Fuse 事件：**
```
On Take Damage → Tween Shake Animation
```

---

### 场景 3：物品收集效果

**目标：** 收集物品时放大并淡出

**实现：**
1. 使用 **Tween Scale To**（放大到 1.5 倍）
2. 使用 **Tween Fade Out**（auto_free = true）
3. 并行执行

**Fuse 事件：**
```
On Item Collected → Parallel:
    - Tween Scale To (1.5)
    - Tween Fade Out (auto_free = true)
```

---

### 场景 4：弹出框显示

**目标：** 弹窗从零缩放弹簧弹出

**实现：**
1. 使用 **Tween Pop Animation**
2. 目标缩放：`Vector2(1, 1)`
3. 持续时间：`0.4` 秒

**Fuse 事件：**
```
On Show Popup → Tween Pop Animation
```

---

### 场景 5：无限呼吸效果

**目标：** 按钮无限脉冲提示可交互

**实现：**
1. 使用 **Tween Pulse Animation**
2. 最小缩放：`0.95`
3. 最大缩放：`1.05`
4. 循环次数：`0`（无限）

**Fuse 事件：**
```
On Quest Available → Tween Pulse Animation (loop = 0)
On Quest Accepted → Cancel Pulse Animation
```

---

## 最佳实践

### 1. 动画持续时间选择

- **快速反馈：** 0.05-0.15 秒（按钮点击、闪烁）
- **UI 动画：** 0.2-0.5 秒（淡入淡出、滑入滑出）
- **角色动作：** 0.3-0.8 秒（移动、攻击）
- **过场动画：** 0.5-2.0 秒（场景切换、复杂序列）

### 2. 缓动和过渡搭配

- **UI 交互：** Out + Back 或 Spring
- **自然移动：** InOut + Sine
- **掉落效果：** Out + Bounce
- **弹性效果：** Out + Elastic

### 3. 性能优化

- 避免同时运行过多 Tween（建议 < 50 个）
- 使用 `auto_free` 自动清理临时对象
- 无限循环动画（Pulse）记得手动停止
- 大量对象动画时考虑使用对象池

### 4. 代码组织

- 将常用动画封装成 Fuse Events
- 使用 Signal 连接动画完成回调
- 保持动画逻辑清晰可读
- 为动画添加有意义的资源名称

### 5. 调试技巧

- 在编辑器中查看资源名称确认参数
- 使用 `FuseLogger` 输出调试日志
- 测试场景中验证动画效果
- 检查节点路径是否正确

---

## 常见问题

### Q: 为什么动画没有播放？

**可能原因：**
1. 目标节点路径错误
2. 节点在动画开始前被释放
3. 执行上下文不正确

**解决方法：**
- 检查 `target_node` 路径
- 确认节点在场景树中存在
- 查看 FuseLogger 日志

---

### Q: 如何在动画完成后执行其他操作？

**方法：**
使用 Fuse Event 系统的信号连接：
1. 创建 Tween Animation Completed Event
2. 在动画完成时触发后续操作

---

### Q: 无限循环动画如何停止？

**方法：**
调用指令的 `cancel()` 方法：
1. 保存 Tween Pulse Animation 指令引用
2. 需要停止时调用 `cancel()`

---

### Q: 可以同时播放多个动画吗？

**答案：**
可以！使用 Fuse 的并行执行：
1. 使用 ActionRunner 的并行功能
2. 或在同一个 Event 中添加多个 Tween 指令

---

### Q: 如何动画化自定义属性？

**方法：**
使用 **Tween Property** 指令：
1. 选择目标节点
2. 在属性列表中选择任意可写属性
3. 设置目标值和参数

---

## 参考资源

### 内部文档
- [Fuse 指令开发指南](../../dev_docs/guides/instruction-creation-guide.md)

### 外部资源
- [Godot 官方文档 - Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html)
- [Easing Functions Cheat Sheet](https://easings.net/)

---

## 更新日志

**2026-01-28**
- 初始版本
- 包含 11 个 Tween 指令的完整使用指南
- 添加常见场景示例和最佳实践

---

**维护者：** JuicyGodot 项目组
**许可：** 项目内部文档
