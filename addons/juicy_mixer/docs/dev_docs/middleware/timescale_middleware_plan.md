# 时间缩放中间件开发计划

## 系统集成与优化要求

### 与Driver系统的协同优化
**Driver执行优化**：
- TimeScaleMiddleware需要与Driver的时间处理机制协调，确保缩放后的时间能正确传递给Driver

### 与JuicyContext的增强集成
**时间管理协调**：
- TimeScaleMiddleware需要与Context的时间系统深度集成
- 实现中间件级别的时间暂停和恢复机制
- 支持中间件对Context进度的控制和调整

## 核心组件详细设计

### 6. JuicyTimeGroupConfig (时间组配置资源)

**文件路径**：`addons/juicy_mixer/resources/juicy_time_group_config.gd`

**核心职责**：
- 定义多个时间组的配置参数
- 提供可序列化的时间组配置存储
- 支持编辑器中的可视化配置
- 提供时间组配置验证功能
- 集中管理所有时间组的时间缩放值

**详细实现计划**：

```gdscript
@tool
class_name JuicyTimeGroupConfig
extends Resource

# 时间组配置属性
@export var config_name: String = "default_time_groups"
@export var time_groups: Dictionary = {
    "default": 1.0,
    "player": 1.0,
    "enemies": 1.0,
    "npc": 1.0,
    "projectiles": 1.0,
    "ui": 1.0,
    "vfx": 1.0,
    "unscaled": 1.0
}
@export var description: String = ""

func _init():
    """初始化时间组配置"""
    resource_name = "TimeGroupConfig: " + config_name

# 验证配置
func validate() -> Dictionary:
    """验证配置的有效性"""
    var result = {
        "valid": true,
        "issues": [],
        "warnings": []
    }
    
    if config_name.is_empty():
        result.valid = false
        result.issues.append("Config name cannot be empty")
    
    if time_groups.is_empty():
        result.valid = false
        result.issues.append("Time groups dictionary cannot be empty")
    
    # 验证每个时间组的时间缩放值
    for group_name in time_groups.keys():
        var time_scale = time_groups[group_name]
        if time_scale < 0.0:
            result.valid = false
            result.issues.append("Time scale for group '" + group_name + "' cannot be negative")
    
    return result

# 获取配置描述
func get_description() -> String:
    """获取配置的友好描述"""
    return "TimeGroups '%s': %d groups configured" % [
        config_name,
        time_groups.size()
    ]

# 获取时间组缩放值
func get_time_scale(group_name: String) -> float:
    """获取指定时间组的时间缩放值"""
    return time_groups.get(group_name, 1.0)

# 设置时间组缩放值
func set_time_scale(group_name: String, scale: float) -> void:
    """设置指定时间组的时间缩放值"""
    time_groups[group_name] = max(0.0, scale)

# 移除时间组
func remove_time_group(group_name: String) -> void:
    """移除指定的时间组"""
    time_groups.erase(group_name)

# 获取所有时间组名称
func get_time_group_names() -> Array[String]:
    """获取所有时间组的名称"""
    var names: Array[String] = []
    for group_name in time_groups.keys():
        names.append(group_name)
    return names

# 检查时间组是否存在
func has_time_group(group_name: String) -> bool:
    """检查指定的时间组是否存在"""
    return time_groups.has(group_name)

# 编辑器支持
func _get_property_list() -> Array[Dictionary]:
    """获取属性列表，用于编辑器显示"""
    var properties = []
    
    properties.append({
        "name": "time_groups",
        "type": TYPE_DICTIONARY,
        "hint": PROPERTY_HINT_NONE,
        "usage": PROPERTY_USAGE_DEFAULT
    })
    
    return properties

# 序列化支持
func _to_string() -> String:
    """获取字符串表示"""
    return get_description()

# 获取详细配置信息
func get_detailed_info() -> String:
    """获取详细的配置信息"""
    var info = "TimeGroupConfig: " + config_name + "\n"
    for group_name in time_groups.keys():
        info += "  " + group_name + ": " + str(time_groups[group_name]) + "\n"
    return info
```

**开发任务分解**：
- [ ] 第8周第5天：基础资源类结构
- [ ] 第8周第5天：时间组字典管理
- [ ] 第8周第5天：属性定义和验证
- [ ] 第8周第5天：编辑器支持和序列化
- [ ] 第8周第5天：单元测试

**验收标准**：
- 资源类正确继承Resource
- 时间组字典管理功能完整
- 属性序列化和反序列化正常
- 编辑器显示友好
- 配置验证功能完整
- 单元测试覆盖率100%

---

### 7. TimeScaleMiddleware (时间缩放中间件)

**文件路径**：`addons/juicy_mixer/middleware/timescale_middleware.gd`

**核心职责**：
- 应用全局和局部时间缩放
- 支持时间组管理
- 提供时间缩放动画
- 实现时间暂停和恢复
- 加载和管理时间组配置资源

**详细实现计划**：

```gdscript
class_name JuicyTimeScaleMiddleware
extends JuicyMiddleware

# 时间缩放配置
var global_time_scale: float = 1.0
var time_group_config: JuicyTimeGroupConfig  # 时间组配置资源
var time_group_animations: Dictionary = {}  # group_name -> animation_data

# 时间组动画数据
class TimeGroupAnimation:
    var from_scale: float
    var to_scale: float
    var duration: float
    var elapsed_time: float
    var ease_type: Tween.EaseType
    var callback: Callable

func _init():
    middleware_name = "TimeScaleMiddleware"
    priority = 800  # 中等优先级
    description = "Applies time scaling to effects"

func process(context: JuicyContext, next: Callable) -> bool:
    """应用时间缩放"""
    var start_time = _start_execution_timer()
    
    # 应用全局时间缩放
    context.time_scale *= global_time_scale
    
    # 应用时间组缩放
    var time_group = context.resource.time_group
    if not time_group.is_empty() and time_group_config and time_group_config.has_time_group(time_group):
        context.time_scale *= time_group_config.get_time_scale(time_group)
    
    # 更新时间组动画
    _update_time_group_animations()
    
    _end_execution_timer(start_time)
    return next.call(context)

# 时间缩放管理
func set_global_time_scale(scale: float) -> void:
    """设置全局时间缩放"""
    global_time_scale = max(0.0, scale)

func get_global_time_scale() -> float:
    """获取全局时间缩放"""
    return global_time_scale

func set_time_group_scale(group_name: String, scale: float) -> void:
    """设置时间组缩放"""
    if time_group_config:
        time_group_config.set_time_scale(group_name, scale)

func get_time_group_scale(group_name: String) -> float:
    """获取时间组缩放"""
    if time_group_config:
        return time_group_config.get_time_scale(group_name)
    return 1.0

func remove_time_group(group_name: String) -> void:
    """移除时间组"""
    if time_group_config:
        time_group_config.remove_time_group(group_name)
    time_group_animations.erase(group_name)

# 时间组配置管理
func set_time_group_config(config: JuicyTimeGroupConfig) -> void:
    """设置时间组配置"""
    time_group_config = config

func get_time_group_config() -> JuicyTimeGroupConfig:
    """获取时间组配置"""
    return time_group_config

func load_time_group_config(resource_path: String) -> JuicyTimeGroupConfig:
    """从文件加载时间组配置"""
    if ResourceLoader.exists(resource_path):
        var config = load(resource_path) as JuicyTimeGroupConfig
        if config:
            time_group_config = config
        return config
    return null

func save_time_group_config(config: JuicyTimeGroupConfig, resource_path: String) -> bool:
    """保存时间组配置到文件"""
    time_group_config = config
    return ResourceSaver.save(config, resource_path) == OK

# 时间组动画
func animate_time_group_scale(group_name: String, to_scale: float, duration: float,
                           ease_type: Tween.EaseType = Tween.EASE_IN_OUT,
                           callback: Callable = Callable()) -> void:
    """动画时间组缩放"""
    var from_scale = get_time_group_scale(group_name)
    
    var animation = TimeGroupAnimation.new()
    animation.from_scale = from_scale
    animation.to_scale = to_scale
    animation.duration = duration
    animation.elapsed_time = 0.0
    animation.ease_type = ease_type
    animation.callback = callback
    
    time_group_animations[group_name] = animation

func stop_time_group_animation(group_name: String) -> void:
    """停止时间组动画"""
    time_group_animations.erase(group_name)

func _update_time_group_animations() -> void:
    """更新时间组动画"""
    var groups_to_remove: Array[String] = []
    
    for group_name in time_group_animations.keys():
        var animation = time_group_animations[group_name]
        
        animation.elapsed_time += get_process_delta_time()
        
        if animation.elapsed_time >= animation.duration:
            # 动画完成
            set_time_group_scale(group_name, animation.to_scale)
            groups_to_remove.append(group_name)
            
            # 调用回调
            if animation.callback.is_valid():
                animation.callback.call()
        else:
            # 计算当前值
            var progress = animation.elapsed_time / animation.duration
            progress = _apply_easing(progress, animation.ease_type)
            
            var current_scale = lerp(animation.from_scale, animation.to_scale, progress)
            set_time_group_scale(group_name, current_scale)
    
    # 移除完成的动画
    for group_name in groups_to_remove:
        time_group_animations.erase(group_name)

func _apply_easing(progress: float, ease_type: Tween.EaseType) -> float:
    """应用缓动函数"""
    match ease_type:
        Tween.EASE_IN:
            return progress * progress
        Tween.EASE_OUT:
            return 1.0 - (1.0 - progress) * (1.0 - progress)
        Tween.EASE_IN_OUT:
            if progress < 0.5:
                return 2.0 * progress * progress
            else:
                return 1.0 - 2.0 * (1.0 - progress) * (1.0 - progress)
        _:
            return progress

# 统计和调试
func get_time_scale_stats() -> Dictionary:
    """获取时间缩放统计"""
    var time_group_stats = {}
    if time_group_config:
        for group_name in time_group_config.get_time_group_names():
            time_group_stats[group_name] = {
                "time_scale": time_group_config.get_time_scale(group_name)
            }
    
    return {
        "global_time_scale": global_time_scale,
        "time_groups": time_group_stats,
        "active_animations": time_group_animations.size(),
        "animated_groups": time_group_animations.keys()
    }

func debug_print_time_scales() -> void:
    """打印时间缩放信息"""
    print("=== JuicyMixer Time Scales ===")
    print("Global: ", global_time_scale)
    if time_group_config:
        print("Time Groups:")
        for group_name in time_group_config.get_time_group_names():
            print("  ", group_name, ": ", time_group_config.get_time_scale(group_name))
    
    if not time_group_animations.is_empty():
        print("Active Animations:")
        for group_name in time_group_animations.keys():
            var animation = time_group_animations[group_name]
            print("  ", group_name, ": ", animation.from_scale, " -> ", animation.to_scale,
                  " (", animation.elapsed_time, "/", animation.duration, ")")
```

**开发任务分解**：
- [ ] 第8周第4天：基础时间缩放逻辑
- [ ] 第8周第4天：时间组管理
- [ ] 第8周第5天：时间组动画
- [ ] 第8周第5天：统计和调试功能
- [ ] 第8周第5天：单元测试

**验收标准**：
- 时间缩放正确应用
- 时间组管理有效
- 动画播放流畅
- 单元测试覆盖率100%
---

## 测试计划

### 测试场景6：时间组配置资源序列化测试
```gdscript
func test_time_group_config_serialization():
    var config = JuicyTimeGroupConfig.new()
    config.config_name = "test_time_groups"
    config.time_groups = {
        "default": 1.0,
        "player": 1.2,
        "enemies": 0.8,
        "npc": 1.0,
        "projectiles": 1.5,
        "ui": 1.0,
        "vfx": 0.9,
        "unscaled": 1.0,
        "slow_motion": 0.3
    }
    config.description = "Test time group configuration"
    
    # 保存配置
    var temp_path = "user://temp_time_group_config.tres"
    assert_true(ResourceSaver.save(config, temp_path) == OK)
    
    # 加载配置
    var loaded_config = load(temp_path) as JuicyTimeGroupConfig
    assert_not_null(loaded_config)
    assert_eq(loaded_config.config_name, "test_time_groups")
    assert_eq(loaded_config.description, "Test time group configuration")
    
    # 测试时间组功能
    assert_true(loaded_config.has_time_group("player"))
    assert_true(loaded_config.has_time_group("enemies"))
    assert_false(loaded_config.has_time_group("nonexistent"))
    
    assert_eq(loaded_config.get_time_scale("player"), 1.2)
    assert_eq(loaded_config.get_time_scale("enemies"), 0.8)
    assert_eq(loaded_config.get_time_scale("nonexistent"), 1.0)  # 默认值
    
    # 测试时间组名称获取
    var group_names = loaded_config.get_time_group_names()
    assert_eq(group_names.size(), 10)
    assert_true("player" in group_names)
    assert_true("enemies" in group_names)
    assert_true("slow_motion" in group_names)
    
    # 测试设置时间组缩放
    loaded_config.set_time_scale("new_group", 2.0)
    assert_eq(loaded_config.get_time_scale("new_group"), 2.0)
    assert_true(loaded_config.has_time_group("new_group"))
    
    # 测试移除时间组
    loaded_config.remove_time_group("new_group")
    assert_false(loaded_config.has_time_group("new_group"))
    assert_eq(loaded_config.get_time_scale("new_group"), 1.0)  # 默认值
    
    # 测试配置验证
    var validation = loaded_config.validate()
    assert_true(validation.valid)
    assert_eq(validation.issues.size(), 0)
    
    # 测试无效配置
    loaded_config.time_groups["invalid"] = -1.0
    validation = loaded_config.validate()
    assert_false(validation.valid)
    assert_true(validation.issues.size() > 0)
    
    # 清理
    DirAccess.remove_absolute(temp_path)
```