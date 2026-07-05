# JuicyMixer 使用指南

## 简介

JuicyMixer 是一个为 Godot 引擎设计的高性能游戏反馈系统，让你能够轻松创建各种游戏效果，如补间动画、震动效果和弹簧物理模拟。

本指南将帮助你快速上手 JuicyMixer 的基本使用方法。

---

## 快速开始

### 1. 安装插件

将 `addons/juicy_mixer` 文件夹复制到你的 Godot 项目的 `addons` 目录中，然后重启 Godot 编辑器。

### 2. 基本概念

JuicyMixer 基于以下几个核心概念：

- **资源**：定义效果配置的数据文件
- **驱动器**：处理特定类型效果的引擎
- **上下文**：管理效果执行状态和目标对象
- **属性缓冲**：处理多个效果对同一属性的混合

---

## 三种基本效果类型

### 1. 补间动画 (Tween)

补间动画用于在指定时间内平滑地改变属性值。

#### 创建补间效果

```gdscript
# 创建补间资源
var tween_resource = JuicyTweenResource.new()

# 添加位置补间数据
var position_data = TweenData.new()
position_data.property = "position"
position_data.from_value = Vector2(0, 0)
position_data.to_value = Vector2(100, 50)
position_data.duration = 1.0
position_data.ease_type = Tween.EASE_OUT
position_data.trans_type = Tween.TRANS_SINE

tween_resource.tween_data.append(position_data)

# 应用到目标节点
var target_node = $Sprite2D
JuicyMixer.play_effect(tween_resource, target_node)
```

#### 常用补间类型

- **位置动画**：移动对象
- **旋转动画**：旋转对象
- **缩放动画**：改变对象大小
- **颜色动画**：改变对象颜色

### 2. 震动效果 (Shake)

震动效果用于创建随机扰动，如相机震动或受击反馈。

#### 创建震动效果

```gdscript
# 创建震动资源
var shake_resource = JuicyShakeResource.new()

# 添加震动数据
var shake_data = ShakeData.new()
shake_data.property = "position"
shake_data.amplitude = 10.0      # 震动强度
shake_data.frequency = 15.0      # 震动频率
shake_data.duration = 0.5        # 震动持续时间
shake_data.falloff = ShakeData.Falloff.LINEAR  # 衰减类型

shake_resource.shake_data.append(shake_data)

# 应用到目标节点
var camera = $Camera2D
JuicyMixer.play_effect(shake_resource, camera)
```

#### 震动衰减类型

- **LINEAR**：线性衰减
- **EXPONENTIAL**：指数衰减
- **LOGARITHMIC**：对数衰减
- **NONE**：无衰减

### 3. 弹簧物理 (Spring)

弹簧效果模拟真实的物理弹簧运动，适合创建弹性反馈。

#### 创建弹簧效果

```gdscript
# 创建弹簧资源
var spring_resource = JuicySpringResource.new()

# 添加弹簧数据
var spring_data = SpringData.new()
spring_data.property = "scale"
spring_data.target_value = Vector2(1.2, 1.2)  # 目标缩放值
spring_data.stiffness = 100.0      # 弹簧刚度
spring_data.damping = 15.0          # 阻尼系数
spring_data.mass = 1.0              # 质量

spring_resource.spring_data.append(spring_data)

# 应用到目标节点
var button = $Button
JuicyMixer.play_effect(spring_resource, button)
```

#### 弹簧参数说明

- **stiffness**：弹簧刚度，值越大弹簧越硬
- **damping**：阻尼系数，控制震动衰减速度
- **mass**：质量，影响运动惯性
- **threshold**：稳定阈值，低于此值时停止计算

---

## 高级用法

### 组合多种效果

你可以组合多种效果类型创建复杂的反馈：

```gdscript
# 创建一个包含多种效果的资源
var combo_resource = JuicyFeedbackResource.new()

# 添加补间效果
var tween_data = TweenData.new()
tween_data.property = "modulate"
tween_data.from_value = Color.WHITE
tween_data.to_value = Color.RED
tween_data.duration = 0.3

# 添加震动效果
var shake_data = ShakeData.new()
shake_data.property = "position"
shake_data.amplitude = 5.0
shake_data.duration = 0.2

# 注意：实际组合使用需要通过 JuicyMixer 的组合功能
# 这将在阶段3中实现
```

### 在编辑器中配置

1. 在检查器中点击"添加效果"
2. 选择效果类型（Tween/Shake/Spring）
3. 配置效果参数
4. 将资源保存为 .tres 文件

---

## 实用示例

### 示例1：按钮点击反馈

```gdscript
func _on_button_pressed():
    # 创建缩放弹跳效果
    var spring_resource = JuicySpringResource.new()
    var spring_data = SpringData.new()
    spring_data.property = "scale"
    spring_data.target_value = Vector2(1.1, 1.1)
    spring_data.stiffness = 200.0
    spring_data.damping = 20.0
    spring_resource.spring_data.append(spring_data)
    
    JuicyMixer.play_effect(spring_resource, self)
```

### 示例2：相机震动

```gdscript
func create_camera_shake(intensity: float):
    var shake_resource = JuicyShakeResource.new()
    var shake_data = ShakeData.new()
    shake_data.property = "offset"
    shake_data.amplitude = intensity
    shake_data.frequency = 20.0
    shake_data.duration = 0.3
    shake_data.falloff = ShakeData.Falloff.EXPONENTIAL
    shake_resource.shake_data.append(shake_data)
    
    JuicyMixer.play_effect(shake_resource, $Camera2D)
```

### 示例3：UI元素出现动画

```gdscript
func animate_ui_entry(element: Control):
    var tween_resource = JuicyTweenResource.new()
    
    # 位置动画
    var pos_data = TweenData.new()
    pos_data.property = "position"
    pos_data.from_value = element.position + Vector2(0, 50)
    pos_data.to_value = element.position
    pos_data.duration = 0.5
    pos_data.ease_type = Tween.EASE_OUT
    pos_data.trans_type = Tween.TRANS_BACK
    
    # 透明度动画
    var mod_data = TweenData.new()
    mod_data.property = "modulate"
    mod_data.from_value = Color.TRANSPARENT
    mod_data.to_value = Color.WHITE
    mod_data.duration = 0.3
    
    tween_resource.tween_data.append(pos_data)
    tween_resource.tween_data.append(mod_data)
    
    JuicyMixer.play_effect(tween_resource, element)
```

---

## 性能优化建议

1. **重用资源**：预创建常用效果资源并重用
2. **合理设置参数**：避免过高的频率和过长的持续时间
3. **批量处理**：对多个相似效果使用统一的配置
4. **及时清理**：不再需要的效果会自动清理

---

## 常见问题

### Q: 如何停止正在播放的效果？
A: 使用 `JuicyMixer.stop_effect(context_id)` 或等待效果自然结束。

### Q: 可以同时播放多个效果吗？
A: 可以，JuicyMixer 会自动处理多个效果的混合。

### Q: 如何自定义效果参数？
A: 在编辑器中创建资源文件，或通过代码动态设置参数。

### Q: 性能如何？
A: JuicyMixer 经过优化，单个效果处理仅需几微秒，可以同时处理大量效果。

---

## 下一步

- 查看 `addons/juicy_mixer/tests/` 目录中的演示场景
- 尝试不同的参数组合创造独特效果
- 关注阶段3更新，将支持更高级的组合和序列功能

---

## API 参考

### 主要类

- `JuicyMixer`：主管理类
- `JuicyTweenResource`：补间效果资源
- `JuicyShakeResource`：震动效果资源
- `JuicySpringResource`：弹簧效果资源

### 数据类

- `TweenData`：补间数据配置
- `ShakeData`：震动数据配置
- `SpringData`：弹簧数据配置

更多详细信息请查看各类的文档注释。