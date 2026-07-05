# LOD中间件开发计划

## 核心组件详细设计

### 8. JuicyLODConfig (LOD配置资源)

**文件路径**：`addons/juicy_mixer/resources/juicy_lod_config.gd`

**核心职责**：
- 定义LOD的配置参数
- 提供可序列化的LOD配置存储
- 支持编辑器中的可视化配置
- 提供LOD配置验证功能

**详细实现计划**：

```gdscript
@tool
class_name JuicyLODConfig
extends Resource

# LOD配置属性
@export var config_name: String = "default_lod"
@export var max_distance: float = 500.0
@export var distance_thresholds: Array[float] = [100.0, 200.0, 300.0]
@export var intensity_multipliers: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.0]
@export var enable_frustum_culling: bool = true
@export var enable_distance_culling: bool = true
@export var description: String = ""

func _init():
    """初始化LOD配置"""
    resource_name = "LODConfig: " + config_name

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
    
    if max_distance <= 0:
        result.valid = false
        result.issues.append("Max distance must be greater than 0")
    
    if distance_thresholds.size() + 1 != intensity_multipliers.size():
        result.valid = false
        result.issues.append("Intensity multipliers array must be one element larger than distance thresholds array")
    
    # 检查距离阈值是否递增
    for i in range(1, distance_thresholds.size()):
        if distance_thresholds[i] <= distance_thresholds[i-1]:
            result.valid = false
            result.issues.append("Distance thresholds must be in ascending order")
            break
    
    return result

# 获取配置描述
func get_description() -> String:
    """获取配置的友好描述"""
    return "LOD '%s': max_dist=%.1f, thresholds=%d, frustum=%s, distance=%s" % [
        config_name,
        max_distance,
        distance_thresholds.size(),
        enable_frustum_culling,
        enable_distance_culling
    ]

# 计算强度倍数
func calculate_intensity_multiplier(distance: float) -> float:
    """根据距离计算强度倍数"""
    if distance > max_distance:
        return 0.0
    
    for i in range(distance_thresholds.size()):
        if distance <= distance_thresholds[i]:
            return intensity_multipliers[i]
    
    # 超出所有阈值，返回最小倍数
    return intensity_multipliers[-1] if intensity_multipliers.size() > 0 else 0.0

# 编辑器支持
func _get_property_list() -> Array[Dictionary]:
    """获取属性列表，用于编辑器显示"""
    var properties = []
    
    properties.append({
        "name": "distance_thresholds",
        "type": TYPE_ARRAY,
        "hint": PROPERTY_HINT_ARRAY_TYPE,
        "hint_string": "float",
        "usage": PROPERTY_USAGE_DEFAULT
    })
    
    properties.append({
        "name": "intensity_multipliers",
        "type": TYPE_ARRAY,
        "hint": PROPERTY_HINT_ARRAY_TYPE,
        "hint_string": "float",
        "usage": PROPERTY_USAGE_DEFAULT
    })
    
    return properties

# 序列化支持
func _to_string() -> String:
    """获取字符串表示"""
    return get_description()
```

**开发任务分解**：
- [ ] 第8周第4天：基础资源类结构
- [ ] 第8周第4天：属性定义和验证
- [ ] 第8周第5天：编辑器支持和序列化
- [ ] 第8周第5天：单元测试

**验收标准**：
- 资源类正确继承Resource
- 属性序列化和反序列化正常
- 编辑器显示友好
- 配置验证功能完整
- 强度计算准确
- 单元测试覆盖率100%

---

### 9. LODMiddleware (LOD中间件)

**文件路径**：`addons/juicy_mixer/middleware/lod_middleware.gd`

**核心职责**：
- 实现距离相关的效果强度调整
- 提供视锥剔除功能
- 支持自定义LOD策略
- 优化性能表现
- 加载和管理LOD配置资源

**详细实现计划**：

```gdscript
class_name JuicyLODMiddleware
extends JuicyMiddleware

# LOD状态
var _lod_config: JuicyLODConfig
var _camera_reference: Camera2D

func _init():
    middleware_name = "LODMiddleware"
    priority = 700  # 较低优先级，在其他处理后执行
    description = "Applies level of detail optimizations"

func process(context: JuicyContext, next: Callable) -> bool:
    """应用LOD优化"""
    var start_time = _start_execution_timer()
    
    # 初始化LOD配置
    if not _lod_config:
        _initialize_default_config()
    
    # 获取当前摄像机
    var camera = _get_current_camera()
    if not camera:
        _end_execution_timer(start_time)
        return next.call(context)
    
    # 计算距离
    var distance = _calculate_distance_to_target(camera, context.target)
    
    # 视锥剔除
    if _lod_config.enable_frustum_culling and not _is_target_visible(camera, context.target):
        context.time_scale = 0.0
        _end_execution_timer(start_time)
        return next.call(context)
    
    # 距离剔除
    if _lod_config.enable_distance_culling and distance > _lod_config.max_distance:
        context.time_scale = 0.0
        _end_execution_timer(start_time)
        return next.call(context)
    
    # 应用距离相关的强度调整
    var intensity_multiplier = _calculate_intensity_multiplier(distance)
    context.time_scale *= intensity_multiplier
    
    _end_execution_timer(start_time)
    return next.call(context)

# 内部实现
func _initialize_default_config() -> void:
    """初始化默认配置"""
    _lod_config = _create_default_lod_config()
    
    # 尝试获取主摄像机
    _camera_reference = _get_main_camera()

func _create_default_lod_config() -> JuicyLODConfig:
    """创建默认LOD配置"""
    var config = JuicyLODConfig.new()
    config.config_name = "default"
    return config

func _get_current_camera() -> Camera2D:
    """获取当前摄像机"""
    if _lod_config and _lod_config.camera:
        return _lod_config.camera
    
    if _camera_reference and is_instance_valid(_camera_reference):
        return _camera_reference
    
    # 尝试获取主摄像机
    _camera_reference = _get_main_camera()
    return _camera_reference

func _get_main_camera() -> Camera2D:
    """获取主摄像机"""
    var viewport = Engine.get_main_loop().get_viewport()
    if not viewport:
        return null
    
    return viewport.get_camera_2d()

func _calculate_distance_to_target(camera: Camera2D, target: Node) -> float:
    """计算到目标的距离"""
    if not camera or not target:
        return INF
    
    var camera_pos = camera.global_position
    var target_pos = target.global_position
    
    return camera_pos.distance_to(target_pos)

func _is_target_visible(camera: Camera2D, target: Node) -> bool:
    """检查目标是否在视锥内"""
    if not camera or not target:
        return false
    
    var camera_pos = camera.global_position
    var target_pos = target.global_position
    
    # 获取视口大小
    var viewport_size = camera.get_viewport().get_visible_rect().size
    var viewport_center = camera_pos
    
    # 简单的矩形视锥检查
    var half_width = viewport_size.x * 0.5
    var half_height = viewport_size.y * 0.5
    
    return (abs(target_pos.x - viewport_center.x) <= half_width and
            abs(target_pos.y - viewport_center.y) <= half_height)

func _calculate_intensity_multiplier(distance: float) -> float:
    """计算强度倍数"""
    return _lod_config.calculate_intensity_multiplier(distance)

# 配置管理
func set_lod_config(config: JuicyLODConfig) -> void:
    """设置LOD配置"""
    _lod_config = config

func get_lod_config() -> JuicyLODConfig:
    """获取LOD配置"""
    return _lod_config

func load_lod_config(resource_path: String) -> JuicyLODConfig:
    """从文件加载LOD配置"""
    if ResourceLoader.exists(resource_path):
        return load(resource_path) as JuicyLODConfig
    return null

func save_lod_config(config: JuicyLODConfig, resource_path: String) -> bool:
    """保存LOD配置到文件"""
    return ResourceSaver.save(config, resource_path) == OK

func set_camera(camera: Camera2D) -> void:
    """设置摄像机"""
    _camera_reference = camera
    if _lod_config:
        _lod_config.camera = camera

func set_distance_thresholds(thresholds: Array[float], multipliers: Array[float]) -> void:
    """设置距离阈值和强度倍数"""
    if thresholds.size() + 1 != multipliers.size():
        push_error("Multipliers array must be one element larger than thresholds array")
        return
    
    _lod_config.distance_thresholds = thresholds
    _lod_config.intensity_multipliers = multipliers

# 统计和调试
func get_lod_stats() -> Dictionary:
    """获取LOD统计信息"""
    if not _lod_config:
        return {}
    
    return {
        "camera_set": _lod_config.camera != null,
        "max_distance": _lod_config.max_distance,
        "distance_thresholds": _lod_config.distance_thresholds,
        "intensity_multipliers": _lod_config.intensity_multipliers,
        "frustum_culling_enabled": _lod_config.enable_frustum_culling,
        "distance_culling_enabled": _lod_config.enable_distance_culling
    }

func debug_print_lod_info() -> void:
    """打印LOD信息"""
    print("=== JuicyMixer LOD Info ===")
    var stats = get_lod_stats()
    
    for key in stats.keys():
        print(key, ": ", stats[key])
```

**开发任务分解**：
- [ ] 第8周第5天：基础LOD逻辑
- [ ] 第8周第5天：距离计算和强度调整
- [ ] 第8周第5天：视锥剔除
- [ ] 第8周第5天：配置管理和调试
- [ ] 第8周第5天：单元测试

**验收标准**：
- LOD策略正确应用
- 距离计算准确
- 性能优化有效
- 单元测试覆盖率100%
---

## 测试计划

### 测试场景5：LOD配置资源序列化测试
```gdscript
func test_lod_config_serialization():
    var config = JuicyLODConfig.new()
    config.config_name = "test_lod"
    config.max_distance = 800.0
    config.distance_thresholds = [150.0, 300.0, 450.0]
    config.intensity_multipliers = [1.0, 0.8, 0.6, 0.4, 0.2]
    config.enable_frustum_culling = false
    config.enable_distance_culling = true
    config.description = "Test LOD configuration"
    
    # 保存配置
    var temp_path = "user://temp_lod_config.tres"
    assert_true(ResourceSaver.save(config, temp_path) == OK)
    
    # 加载配置
    var loaded_config = load(temp_path) as JuicyLODConfig
    assert_not_null(loaded_config)
    assert_eq(loaded_config.config_name, "test_lod")
    assert_eq(loaded_config.max_distance, 800.0)
    assert_eq(loaded_config.distance_thresholds, [150.0, 300.0, 450.0])
    assert_eq(loaded_config.intensity_multipliers, [1.0, 0.8, 0.6, 0.4, 0.2])
    assert_eq(loaded_config.enable_frustum_culling, false)
    assert_eq(loaded_config.enable_distance_culling, true)
    assert_eq(loaded_config.description, "Test LOD configuration")
    
    # 测试强度计算
    assert_eq(loaded_config.calculate_intensity_multiplier(100.0), 1.0)
    assert_eq(loaded_config.calculate_intensity_multiplier(200.0), 0.8)
    assert_eq(loaded_config.calculate_intensity_multiplier(400.0), 0.6)
    assert_eq(loaded_config.calculate_intensity_multiplier(500.0), 0.4)
    assert_eq(loaded_config.calculate_intensity_multiplier(900.0), 0.0)
    
    # 清理
    DirAccess.remove_absolute(temp_path)
```