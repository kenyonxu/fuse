---
title: Formation Builder - Godot 实现方案
status: published
author: claude
date: 2026-02-06
order: 1
keywords:
  - formation system
  - wave system
  - editor tools
  - godot plugin
---

# Formation Builder - Godot 实现方案

Formation Builder 为游戏提供可视化阵型编辑工具，设计师可以在编辑器中创建和调整敌人阵型，保存为资源后在运行时使用。

本文档描述如何在 Godot 4.x 中实现类似 Unity GameplayDesignUtilities 的 Formation Builder 功能。

## 系统概览

```
formation_builder/
├── formation_data.gd              # 阵型资源数据
├── formation_builder.gd            # 可视化构建器节点
├── formation_shape.gd              # 形状生成器基类
├── shapes/
│   ├── circle_shape.gd
│   ├── square_shape.gd
│   ├── triangle_shape.gd
│   └── spline_shape.gd
└── editor/
    └── formation_builder_plugin.gd # 编辑器插件
```

## 核心设计

使用 Godot 的 **Resource + @tool + EditorPlugin** 三层架构：

1. **FormationData (Resource)** - 存储阵型配置，可复用和序列化
2. **FormationBuilder (@tool Node2D)** - 编辑器中的可视化节点，实时预览
3. **FormationBuilderPlugin** - 注册自定义类型到编辑器

## FormationData 资源

```gdscript
class_name FormationData extends Resource
@icon("res://addons/formation_builder/icons/formation_data.svg")

enum PointMode {
    GRID,       # 网格点阵
    RADIANT     # 辐射状
}

enum ShapeType {
    CIRCLE,
    SQUARE,
    TRIANGLE,
    PENTAGON,
    HEXAGON,
    OCTAGON,
    CUSTOM_SPLINE
}

@export var shape_type: ShapeType = ShapeType.CIRCLE
@export var point_mode: PointMode = PointMode.GRID
@export var radius: float = 100.0
@export var rotation_degrees: float = 0.0

# Grid 模式参数
@export var grid_rows: int = 3
@export var grid_columns: int = 3
@export var row_spacing: float = 30.0
@export var column_spacing: float = 30.0

# Radiant 模式参数
@export var radiant_degree: float = 360.0
@export var point_spacing: float = 30.0
@export var inner_radius: float = 0.0

# 自定义 Spline 点
@export var spline_points: Array[Vector2] = []

var _formation_points: Array[Vector2] = []

func get_formation_positions() -> Array[Vector2]:
    return _formation_points.duplicate()

func set_formation_points(points: Array[Vector2]) -> void:
    _formation_points = points
    emit_changed()
```

`FormationData` 继承 `Resource`，获得以下特性：

- 出现在资源创建菜单 (`CreateAssetMenu` 在 Godot 中通过 `@icon` 和注册实现)
- 自动序列化，保存到 `.tres` 文件
- 可在 Inspector 中编辑属性
- `changed` 信号在属性修改时触发

## FormationBuilder 可视化节点

```gdscript
class_name FormationBuilder extends Node2D
@tool

@export var formation_data: FormationData:
    set(value):
        formation_data = value
        if formation_data:
            formation_data.changed.connect(_on_formation_changed)
        _generate_points()
        queue_redraw()

@export var show_preview: bool = true:
    set(value):
        show_preview = value
        queue_redraw()

@export var preview_point_size: float = 5.0:
    set(value):
        preview_point_size = value
        queue_redraw()

@export var preview_color: Color = Color.CYAN:
    set(value):
        preview_color = value
        queue_redraw()

var _shape_generator: FormationShape

func _ready() -> void:
    if Engine.is_editor_hint():
        _create_shape_generator()

func _create_shape_generator() -> void:
    if not formation_data:
        return
    _shape_generator = FormationShape.create(formation_data.shape_type)

func _generate_points() -> void:
    if not formation_data or not _shape_generator:
        return

    var points: Array[Vector2] = []
    var shape_points: Array[Vector2] = _shape_generator.generate_shape(
        formation_data.radius,
        formation_data.spline_points
    )

    match formation_data.point_mode:
        FormationData.PointMode.GRID:
            points = _generate_grid_points(shape_points)
        FormationData.PointMode.RADIANT:
            points = _generate_radiant_points(shape_points)

    if formation_data.rotation_degrees != 0:
        var rotation_rad = deg_to_rad(formation_data.rotation_degrees)
        for i in range(points.size()):
            points[i] = points[i].rotated(rotation_rad)

    formation_data.set_formation_points(points)

func _generate_grid_points(shape_bounds: Array[Vector2]) -> Array[Vector2]:
    var points: Array[Vector2] = []
    var data := formation_data
    var total_width := (data.grid_columns - 1) * data.column_spacing
    var total_height := (data.grid_rows - 1) * data.row_spacing
    var start_x := -total_width / 2.0
    var start_y := -total_height / 2.0

    for row in range(data.grid_rows):
        for col in range(data.grid_columns):
            var point := Vector2(
                start_x + col * data.column_spacing,
                start_y + row * data.row_spacing
            )
            if Geometry2D.is_point_in_polygon(point, shape_bounds):
                points.append(point)

    return points

func _generate_radiant_points(shape_bounds: Array[Vector2]) -> Array[Vector2]:
    var points: Array[Vector2] = []
    var data := formation_data
    var degree_step := 10.0
    var start_angle := deg_to_rad(-data.radiant_degree / 2.0)
    var end_angle := deg_to_rad(data.radiant_degree / 2.0)
    var current_radius := data.inner_radius

    while current_radius <= data.radius:
        var angle := start_angle
        while angle <= end_angle:
            var point := Vector2.from_angle(angle) * current_radius
            if Geometry2D.is_point_in_polygon(point, shape_bounds):
                points.append(point)
            angle += deg_to_rad(degree_step)
        current_radius += data.point_spacing

    return points

func _draw() -> void:
    if not show_preview or not formation_data:
        return

    var points := formation_data.get_formation_positions()

    if _shape_generator:
        var shape_points := _shape_generator.generate_shape(
            formation_data.radius,
            formation_data.spline_points
        )
        draw_polyline(shape_points, Color.WHITE, 2.0)

    for point in points:
        draw_circle(point, preview_point_size, preview_color)

    draw_circle(Vector2.ZERO, preview_point_size * 1.5, Color.RED)

func _on_formation_changed() -> void:
    _generate_points()
    queue_redraw()
```

`@tool` 标记让脚本在编辑器中运行：

- `_draw()` 在 2D 视图中实时显示阵型
- `queue_redraw()` 触发重绘
- `Engine.is_editor_hint()` 检测编辑器环境

## 形状生成器

使用工厂模式创建形状生成器：

```gdscript
class_name FormationShape extends RefCounted

enum ShapeType {
    CIRCLE,
    SQUARE,
    TRIANGLE,
    PENTAGON,
    HEXAGON,
    OCTAGON,
    CUSTOM_SPLINE
}

static func create(shape_type: FormationData.ShapeType) -> FormationShape:
    match shape_type:
        FormationData.ShapeType.CIRCLE:
            return CircleShape.new()
        FormationData.ShapeType.SQUARE:
            return SquareShape.new()
        FormationData.ShapeType.TRIANGLE:
            return TriangleShape.new()
        FormationData.ShapeType.CUSTOM_SPLINE:
            return SplineShape.new()
        _:
            return CircleShape.new()

virtual func generate_shape(radius: float, custom_points: Array[Vector2]) -> Array[Vector2]:
    return []
```

### 圆形形状

```gdscript
class_name CircleShape extends FormationShape

func generate_shape(radius: float, custom_points: Array[Vector2]) -> Array[Vector2]:
    var points: Array[Vector2] = []
    var segments := 32

    for i in range(segments):
        var angle := (2.0 * PI * i) / segments
        points.append(Vector2.from_angle(angle) * radius)

    return points
```

### Spline 形状

```gdscript
class_name SplineShape extends FormationShape

func _catmull_rom_interpolate(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
    var t2 := t * t
    var t3 := t2 * t

    return 0.5 * (
        2.0 * p1 +
        (-p0 + p2) * t +
        (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
        (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    )

func generate_shape(radius: float, custom_points: Array[Vector2]) -> Array[Vector2]:
    if custom_points.size() < 2:
        return []

    var points: Array[Vector2] = []
    var segments_per_curve := 10
    var curve_points := custom_points.duplicate()
    curve_points.append(custom_points[0])
    curve_points.append(custom_points[1])

    for i in range(curve_points.size() - 3):
        for j in range(segments_per_curve):
            var t := float(j) / float(segments_per_curve)
            var point := _catmull_rom_interpolate(
                curve_points[i],
                curve_points[i + 1],
                curve_points[i + 2],
                curve_points[i + 3],
                t
            )
            points.append(point)

    return points
```

## 编辑器插件

```gdscript
class_name FormationBuilderEditorPlugin extends EditorPlugin

var _editor_inspector: FormationBuilderEditor

func _enter_tree() -> void:
    add_custom_type(
        "FormationBuilder",
        "Node2D",
        FormationBuilder,
        preload("res://addons/formation_builder/icons/formation_builder.svg")
    )

    _editor_inspector = FormationBuilderEditor.new()
    add_inspector_plugin(_editor_inspector)

    add_custom_type(
        "FormationData",
        "Resource",
        FormationData,
        preload("res://addons/formation_builder/icons/formation_data.svg")
    )

func _exit_tree() -> void:
    remove_custom_type("FormationBuilder")
    remove_custom_type("FormationData")
    remove_inspector_plugin(_editor_inspector)
```

将插件注册到 `addon.cfg`：

```ini
[plugin]

name="Formation Builder"
author="Your Name"
description="Visual formation editor for enemy waves"
version="1.0"
script="editor/formation_builder_plugin.gd"
```

## 使用方法

### 创建阵型

1. 右键点击场景树 → 创建新节点 → 搜索 "FormationBuilder"
2. 在 Inspector 中点击 FormationData 旁的 "新建" 按钮
3. 调整形状类型、点模式、半径等参数
4. 2D 视图实时预览阵型点

### 在 Wave 系统中使用

```gdscript
# 在敌人波次管理器中
@export var formation: FormationData
@export var enemy_scene: PackedScene
@export var spawn_center: Node2D

func spawn_formation() -> void:
    var positions := formation.get_formation_positions()
    var center := spawn_center.global_position

    for pos in positions:
        var enemy := enemy_scene.instantiate()
        enemy.global_position = center + pos
        get_tree().current_scene.add_child(enemy)
```

### 运行时调整阵型

```gdscript
# 改变阵型旋转
func rotate_formation(degrees: float) -> void:
    formation.rotation_degrees = degrees
    # FormationBuilder 会自动重新生成点

# 改变阵型缩放
func scale_formation(scale: float) -> void:
    formation.radius *= scale
```

## 与 Unity 版本对比

| 特性 | Unity 版本 | Godot 版本 | 说明 |
|------|-----------|-----------|------|
| 资源系统 | ScriptableObject | Resource | 两者都是数据容器，Godot 的更轻量 |
| 编辑器运行 | `ExecuteInEditMode` | `@tool` | Godot 的 `@tool` 更简洁 |
| 形状绘制 | Drawing 库 | `_draw()` 方法 | Godot 内置绘制，无需额外库 |
| 可视化 | Gizmos + Handles | 2D 视图绘制 | Godot 2D 视图原生支持 |
| 点检测 | PolygonCollider2D | `Geometry2D.is_point_in_polygon` | Godot 内置几何函数 |

## 优势

1. **代码量更少** - 不需要自定义 Editor 类，Inspector 自动工作
2. **实时预览** - `@tool` 让脚本在编辑器运行，修改立即生效
3. **原生集成** - 2D 视图直接可视化，无需额外窗口
4. **性能更好** - Resource 系统比 ScriptableObject 更轻量
5. **扩展简单** - 添加新形状只需创建新类，在工厂方法注册

## 下一步

1. 实现基础形状类（Circle, Square, Triangle 等）
2. 添加更多点生成模式（Hexagonal, Spiral）
3. 实现 Spline 编辑器（Scene 视图中拖动控制点）
4. 集成到 Wave 系统
5. 添加阵型预设库
