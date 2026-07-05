# Phase 3C: Curve Preset System - 详细设计文档

## 文档信息

- **创建日期**: 2026-01-09
- **版本**: v1.0
- **状态**: 设计阶段
- **优先级**: P1（重要）
- **预计工作量**: 13-19 小时（约 2-3 天）

## 概述

Phase 3C 旨在为 JuicyPropertyTrack 添加完整的曲线预设系统，将现有的简单 `ease_preset` (0-3) 扩展为支持 25 种缓动函数的 `curve_preset` 系统。该功能将显著提升用户在创建动画时的工作效率，提供专业级的缓动曲线预设。

### 核心目标

1. **扩展预设库** - 从 4 种基础预设扩展到 25 种专业预设
2. **Inspector 集成** - 提供直观的下拉菜单和智能应用按钮
3. **Canvas 快捷访问** - 右键菜单快速应用预设
4. **向后兼容** - 自动迁移旧的 ease_preset 系统

---

## 功能需求

### 1. Curve Preset 属性

**需求描述**：
- 添加 `curve_preset` 属性到 JuicyPropertyTrack
- 替换现有的 `ease_preset` (0-3) 系统
- 支持 25 种预设类型（0-24）
- 保持向后兼容性

**属性定义**：
```gdscript
@export_category("Curve Presets")
@export var curve_preset: int = JuicyCurveFactory.CurvePreset.LINEAR:
    set(value):
        if curve_preset != value:
            curve_preset = clamp(value, 0, 24)
            _apply_curve_preset_smart(curve_preset)
            notify_property_list_changed()
```

**向后兼容**：
- 保留 `_legacy_ease_preset` 作为存储别名
- 自动映射旧值 (0-3) 到新值
- 新值 (4-24) 在旧系统中返回 0

### 2. CurveFactory 工具类

**需求描述**：
- 创建专门的工具类管理曲线预设
- 提供曲线创建、缓存和元数据管理
- 支持所有 25 种预设类型

**核心 API**：
```gdscript
class_name JuicyCurveFactory
extends RefCounted

# 预设枚举
enum CurvePreset {
    # Basic (0-3)
    LINEAR = 0,
    EASE_IN = 1,
    EASE_OUT = 2,
    EASE_IN_OUT = 3,

    # Back (4-6)
    EASE_IN_BACK = 4,
    EASE_OUT_BACK = 5,
    EASE_IN_OUT_BACK = 6,

    # Elastic (7-9)
    EASE_IN_ELASTIC = 7,
    EASE_OUT_ELASTIC = 8,
    EASE_IN_OUT_ELASTIC = 9,

    # Bounce (10-12)
    BOUNCE_IN = 10,
    BOUNCE_OUT = 11,
    BOUNCE_IN_OUT = 12,

    # Exponential (13-15)
    EASE_IN_EXPO = 13,
    EASE_OUT_EXPO = 14,
    EASE_IN_OUT_EXPO = 15,

    # Sine (16-18)
    EASE_IN_SINE = 16,
    EASE_OUT_SINE = 17,
    EASE_IN_OUT_SINE = 18,

    # Quadratic (19-21)
    EASE_IN_QUAD = 19,
    EASE_OUT_QUAD = 20,
    EASE_IN_OUT_QUAD = 21,

    # Cubic (22-24)
    EASE_IN_CUBIC = 22,
    EASE_OUT_CUBIC = 23,
    EASE_IN_OUT_CUBIC = 24
}

# 核心方法
static func create_curve(preset: CurvePreset) -> Curve
static func apply_preset(target_curve: Curve, preset: CurvePreset) -> bool
static func get_preset_name(preset: CurvePreset) -> String
static func get_preset_description(preset: CurvePreset) -> String
static func get_preset_category(preset: CurvePreset) -> int
static func clear_cache()
```

### 3. Inspector 下拉菜单

**需求描述**：
- 在 Inspector 中为 curve_preset 创建下拉菜单
- 按分类组织预设（7 个分类）
- 提供 "Apply" 按钮智能应用预设

**UI 布局**：
```
┌─────────────────────────────────────┐
│ Curve: [Ease Out ▼] [Apply]        │
└─────────────────────────────────────┘
```

**下拉菜单结构**：
```
┌─────────────────────┐
│ Basic               │
│   Linear            │
│   Ease In           │
│   Ease Out          │
│   Ease In Out       │
├─────────────────────┤
│ Back                │
│   Ease In Back      │
│   Ease Out Back     │
│   Ease In Out Back  │
├─────────────────────┤
│ Elastic             │
│   Ease In Elastic   │
│   ...               │
└─────────────────────┘
```

**Apply 按钮行为**：
- 如果已有 `animation_curve`：应用预设形状到现有曲线
- 如果没有 `animation_curve`：创建新曲线实例
- 自动刷新 Inspector 和 Timeline Canvas

### 4. Canvas 右键菜单

**需求描述**：
- 在 Timeline Canvas 的 Property Track 右键菜单中添加预设选项
- 显示为子菜单，按分类组织
- 快速应用预设到选中轨道

**菜单结构**：
```
┌──────────────────────────┐
│ Add Keyframe             │
│ Delete Track             │
├──────────────────────────┤
│ Apply Preset ▸           │
│   ▸ Linear               │
│   ▸ Ease In              │
│   ▸ Ease Out             │
│   ...                    │
├──────────────────────────┤
│ Bake Curve → Keyframes   │
│ Bake Keyframes → Curve   │
└──────────────────────────┘
```

**菜单 ID 范围**：
- 主菜单项 "Apply Preset": ID 100
- 预设子菜单项: ID 101-125（对应预设 0-24）

---

## 技术设计

### 1. 预设分类系统

**分类枚举**：
```gdscript
enum CurvePresetCategory {
    BASIC = 0,        # 0-3: 基础缓动
    BACK = 1,         # 4-6: 超越缓动
    ELASTIC = 2,      # 7-9: 弹性缓动
    BOUNCE = 3,       # 10-12: 弹跳效果
    EXPONENTIAL = 4,  # 13-15: 指数效果
    SINE = 5,         # 16-18: 正弦效果
    QUADRATIC = 6,    # 19-21: 二次/三次
    CUBIC = 7         # 22-24: 三次函数
}
```

**分类到预设的映射**：
```gdscript
static var _category_presets: Dictionary = {
    CurvePresetCategory.BASIC: [0, 1, 2, 3],
    CurvePresetCategory.BACK: [4, 5, 6],
    CurvePresetCategory.ELASTIC: [7, 8, 9],
    CurvePresetCategory.BOUNCE: [10, 11, 12],
    CurvePresetCategory.EXPONENTIAL: [13, 14, 15],
    CurvePresetCategory.SINE: [16, 17, 18],
    CurvePresetCategory.QUADRATIC: [19, 20, 21],
    CurvePresetCategory.CUBIC: [22, 23, 24]
}
```

### 2. Curve 创建算法

#### 2.1 基础预设 (0-3)

**Linear (0)**:
```gdscript
func _create_linear_curve() -> Curve:
    var curve = Curve.new()
    curve.add_point(Vector2(0, 0), 0, 0)
    curve.add_point(Vector2(1, 1), 1, 1)
    return curve
```

**Ease In (1) - Quadratic**:
```gdscript
func _create_ease_in_curve() -> Curve:
    var curve = Curve.new()
    # t²
    for i in range(11):
        var t = float(i) / 10.0
        curve.add_point(Vector2(t, t * t))
    curve.bake()
    return curve
```

**Ease Out (2) - Quadratic**:
```gdscript
func _create_ease_out_curve() -> Curve:
    var curve = Curve.new()
    # 1 - (1-t)²
    for i in range(11):
        var t = float(i) / 10.0
        var value = 1.0 - (1.0 - t) * (1.0 - t)
        curve.add_point(Vector2(t, value))
    curve.bake()
    return curve
```

**Ease In Out (3) - Quadratic**:
```gdscript
func _create_ease_in_out_curve() -> Curve:
    var curve = Curve.new()
    # 2t² (t<0.5), 1-2(1-t)² (t≥0.5)
    for i in range(11):
        var t = float(i) / 10.0
        var value: float
        if t < 0.5:
            value = 2.0 * t * t
        else:
            value = 1.0 - 2.0 * (1.0 - t) * (1.0 - t)
        curve.add_point(Vector2(t, value))
    curve.bake()
    return curve
```

#### 2.2 Back 预设 (4-6)

**Ease In Back**:
```gdscript
func _create_ease_in_back_curve() -> Curve:
    var curve = Curve.new()
    var overshoot: float = 1.70158
    for i in range(101):
        var t = float(i) / 100.0
        var value = t * t * ((overshoot + 1.0) * t - overshoot)
        curve.add_point(Vector2(t, clamp(value, 0.0, 1.0)))
    curve.bake()
    return curve
```

**Ease Out Back**:
```gdscript
func _create_ease_out_back_curve() -> Curve:
    var curve = Curve.new()
    var overshoot: float = 1.70158
    for i in range(101):
        var t = float(i) / 100.0
        t = t - 1.0
        var value = 1.0 + t * t * ((overshoot + 1.0) * t + overshoot)
        curve.add_point(Vector2(t + 1.0, clamp(value, 0.0, 1.0)))
    curve.bake()
    return curve
```

#### 2.3 Elastic 预设 (7-9)

**Ease In Elastic**:
```gdscript
func _create_ease_in_elastic_curve() -> Curve:
    var curve = Curve.new()
    var amplitude: float = 1.0
    var period: float = 0.3
    for i in range(101):
        var t = float(i) / 100.0
        var value: float
        if t == 0:
            value = 0.0
        elif t == 1:
            value = 1.0
        else:
            var s = period / 4.0
            t = t - 1.0
            value = -amplitude * pow(2.0, 10.0 * t) * sin((t - s) * (2.0 * PI) / period)
        curve.add_point(Vector2(float(i) / 100.0, clamp(value, -0.5, 1.0)))
    curve.bake()
    return curve
```

**Ease Out Elastic**:
```gdscript
func _create_ease_out_elastic_curve() -> Curve:
    var curve = Curve.new()
    var amplitude: float = 1.0
    var period: float = 0.3
    for i in range(101):
        var t = float(i) / 100.0
        var value: float
        if t == 0:
            value = 0.0
        elif t == 1:
            value = 1.0
        else:
            var s = period / 4.0
            value = amplitude * pow(2.0, -10.0 * t) * sin((t - s) * (2.0 * PI) / period) + 1.0
        curve.add_point(Vector2(t, clamp(value, 0.0, 1.5)))
    curve.bake()
    return curve
```

#### 2.4 Bounce 预设 (10-12)

**Bounce Out**:
```gdscript
func _create_bounce_out_curve() -> Curve:
    var curve = Curve.new()
    for i in range(101):
        var t = float(i) / 100.0
        var value: float
        if t < 1.0 / 2.75:
            value = 7.5625 * t * t
        elif t < 2.0 / 2.75:
            t = t - 1.5 / 2.75
            value = 7.5625 * t * t + 0.75
        elif t < 2.5 / 2.75:
            t = t - 2.25 / 2.75
            value = 7.5625 * t * t + 0.9375
        else:
            t = t - 2.625 / 2.75
            value = 7.5625 * t * t + 0.984375
        curve.add_point(Vector2(float(i) / 100.0, clamp(value, 0.0, 1.0)))
    curve.bake()
    return curve
```

**Bounce In**:
```gdscript
func _create_bounce_in_curve() -> Curve:
    # Bounce In 是 Bounce Out 的反向
    var out_curve = _create_bounce_out_curve()
    var curve = Curve.new()
    for i in range(101):
        var t = float(i) / 100.0
        var value = 1.0 - out_curve.sample(1.0 - t)
        curve.add_point(Vector2(t, value))
    curve.bake()
    return curve
```

#### 2.5 Exponential 预设 (13-15)

**Ease In Expo**:
```gdscript
func _create_ease_in_expo_curve() -> Curve:
    var curve = Curve.new()
    for i in range(101):
        var t = float(i) / 100.0
        var value: float
        if t == 0:
            value = 0.0
        elif t == 1:
            value = 1.0
        else:
            value = pow(2.0, 10.0 * t - 10.0)
        curve.add_point(Vector2(t, clamp(value, 0.0, 1.0)))
    curve.bake()
    return curve
```

**Ease Out Expo**:
```gdscript
func _create_ease_out_expo_curve() -> Curve:
    var curve = Curve.new()
    for i in range(101):
        var t = float(i) / 100.0
        var value: float
        if t == 1:
            value = 1.0
        elif t == 0:
            value = 0.0
        else:
            value = 1.0 - pow(2.0, -10.0 * t)
        curve.add_point(Vector2(t, clamp(value, 0.0, 1.0)))
    curve.bake()
    return curve
```

#### 2.6 Sine 预设 (16-18)

**Ease In Sine**:
```gdscript
func _create_ease_in_sine_curve() -> Curve:
    var curve = Curve.new()
    for i in range(101):
        var t = float(i) / 100.0
        var value = -cos(t * PI / 2.0) + 1.0
        curve.add_point(Vector2(t, clamp(value, 0.0, 1.0)))
    curve.bake()
    return curve
```

**Ease Out Sine**:
```gdscript
func _create_ease_out_sine_curve() -> Curve:
    var curve = Curve.new()
    for i in range(101):
        var t = float(i) / 100.0
        var value = sin(t * PI / 2.0)
        curve.add_point(Vector2(t, clamp(value, 0.0, 1.0)))
    curve.bake()
    return curve
```

#### 2.7 Quadratic/Cubic 预设 (19-24)

这些预设与 Basic 类似，使用不同的多项式：

**Quad In** (t²) - 与 Ease In 相同
**Quad Out** ( -t² + 2t)
**Cubic In** (t³)
**Cubic Out** (t³ - 3t² + 3t)

### 3. 缓存系统

**缓存策略**：
```gdscript
static var _curve_cache: Dictionary = {}

static func create_curve(preset: CurvePreset) -> Curve:
    # 检查缓存
    if _curve_cache.has(preset):
        return _curve_cache[preset].duplicate()

    # 创建新曲线
    var curve = _create_curve_for_preset(preset)

    # 存入缓存
    _curve_cache[preset] = curve

    # 返回副本（防止修改缓存）
    return curve.duplicate()
```

**缓存管理**：
- `clear_cache()` - 清空所有缓存
- `get_cache_size()` - 获取缓存大小
- 预计内存占用：~50KB（25 曲线 × 2KB）

### 4. 元数据系统

**元数据结构**：
```gdscript
static var _preset_metadata: Dictionary = {
    CurvePreset.LINEAR: {
        "name": "Linear",
        "description": "Linear interpolation (no easing)",
        "category": CurvePresetCategory.BASIC
    },
    CurvePreset.EASE_IN: {
        "name": "Ease In",
        "description": "Quadratic ease in (gradual start)",
        "category": CurvePresetCategory.BASIC
    },
    CurvePreset.BOUNCE_OUT: {
        "name": "Bounce Out",
        "description": "Bounce easing at the end",
        "category": CurvePresetCategory.BOUNCE
    },
    # ... 所有 25 个预设
}
```

**元数据访问**：
```gdscript
static func get_preset_name(preset: CurvePreset) -> String:
    if _preset_metadata.has(preset):
        return _preset_metadata[preset]["name"]
    return "Unknown"

static func get_preset_description(preset: CurvePreset) -> String:
    if _preset_metadata.has(preset):
        return _preset_metadata[preset]["description"]
    return ""

static func get_preset_category(preset: CurvePreset) -> int:
    if _preset_metadata.has(preset):
        return _preset_metadata[preset]["category"]
    return -1
```

---

## 实施步骤

### Step 1: 创建 JuicyCurveFactory 工具类

**文件**: `addons/juicy_mixer/utils/juicy_curve_factory.gd` (新建)

**任务清单**:
- [ ] 定义 CurvePreset 和 CurvePresetCategory 枚举
- [ ] 实现 25 个曲线创建函数
- [ ] 实现缓存系统
- [ ] 实现元数据字典
- [ ] 实现工具函数（get_preset_name 等）
- [ ] 添加错误处理和验证

**预计时间**: 4-6 小时

**验收标准**:
- 所有 25 种预设曲线创建成功
- 曲线形状符合数学定义
- 缓存系统正常工作
- 性能测试通过（< 5ms 创建）

### Step 2: 集成到 JuicyPropertyTrack

**文件**: `addons/juicy_mixer/resources/juicy_property_track.gd` (修改)

**任务清单**:
- [ ] 添加 `curve_preset` 属性（替换 ease_preset）
- [ ] 添加 `_legacy_ease_preset` 向后兼容属性
- [ ] 实现 `_apply_curve_preset_smart()` 方法
- [ ] 更新 `_apply_easing_preset()` 支持新预设
- [ ] 更新 `_get_property_list()` 显示新属性
- [ ] 测试向后兼容性

**预计时间**: 2-3 小时

**验收标准**:
- curve_preset 属性正常工作
- 向后兼容（旧项目可正常加载）
- 智能应用模式工作正常

### Step 3: 实现 Inspector 下拉菜单

**文件**: `addons/juicy_mixer/editor/juicy_timeline_inspector.gd` (修改)

**任务清单**:
- [ ] 添加 `_create_curve_preset_editor()` 方法
- [ ] 实现 `_populate_curve_preset_menu()` 按分类填充
- [ ] 创建 Apply 按钮并连接信号
- [ ] 连接 timeline_canvas 刷新
- [ ] 测试 UI 交互

**预计时间**: 2-3 小时

**验收标准**:
- 下拉菜单显示所有 25 个预设
- 预设选择正确应用
- Apply 按钮工作正常

### Step 4: 实现 Canvas 右键菜单

**文件**: `addons/juicy_mixer/editor/juicy_timeline_canvas.gd` (修改)

**任务清单**:
- [ ] 修改 `_handle_right_click()` 添加预设子菜单
- [ ] 实现 `_add_curve_preset_submenu_items()` 方法
- [ ] 更新 `id_pressed` 处理预设选择
- [ ] 测试菜单交互

**预计时间**: 2-3 小时

**验收标准**:
- 右键菜单显示预设子菜单
- 预设应用正常
- Canvas 立即刷新

### Step 5: 测试与优化

**任务清单**:
- [ ] 创建单元测试（test_curve_factory.gd）
- [ ] 创建集成测试场景
- [ ] 性能测试和优化
- [ ] UI/UX 优化
- [ ] 文档更新

**预计时间**: 3-4 小时

**验收标准**:
- 所有单元测试通过
- 性能指标达标
- 用户验收测试通过

---

## 测试计划

### 单元测试

**文件**: `addons/juicy_mixer/tests/test_curve_factory.gd` (新建)

**测试用例**:
```gdscript
func test_create_linear_curve():
    var curve = JuicyCurveFactory.create_curve(JuicyCurveFactory.CurvePreset.LINEAR)
    assert_not_null(curve)
    assert_eq(curve.sample(0.0), 0.0)
    assert_eq(curve.sample(0.5), 0.5)
    assert_eq(curve.sample(1.0), 1.0)

func test_create_ease_in_curve():
    var curve = JuicyCurveFactory.create_curve(JuicyCurveFactory.CurvePreset.EASE_IN)
    assert_almost_eq(curve.sample(0.5), 0.25, 0.01)  # t²

func test_bounce_out_curve_shape():
    var curve = JuicyCurveFactory.create_curve(JuicyCurveFactory.CurvePreset.BOUNCE_OUT)
    # Bounce 应该有峰值超过 1.0
    var peak_value = 0.0
    for i in range(101):
        var t = float(i) / 100.0
        peak_value = max(peak_value, curve.sample(t))
    assert_true(peak_value > 1.0)

func test_cache_performance():
    JuicyCurveFactory.clear_cache()
    var start = Time.get_ticks_msec()

    # Cache miss
    JuicyCurveFactory.create_curve(JuicyCurveFactory.CurvePreset.BOUNCE_OUT)

    # Cache hit
    JuicyCurveFactory.create_curve(JuicyCurveFactory.CurvePreset.BOUNCE_OUT)

    var elapsed = Time.get_ticks_msec() - start
    assert_lt(elapsed, 10)  # Should be very fast

func test_backward_compatibility():
    var track = JuicyPropertyTrack.new()
    track._legacy_ease_preset = 2  # EASE_OUT
    assert_eq(track.curve_preset, 2)
```

### 集成测试

**测试场景**:
1. **Inspector 测试**:
   - 打开 Property Track Inspector
   - 选择预设并验证应用
   - 测试 Apply 按钮

2. **Canvas 测试**:
   - 右键菜单预设应用
   - 实时预览
   - 菜单组织结构

3. **运行时测试**:
   - 创建带预设的动画
   - 验证动画效果
   - 性能监控

### 性能测试

**指标**:
- 曲线创建时间: < 5ms（首次）
- 缓存检索时间: < 1ms
- 内存占用: < 100KB
- 帧率影响: < 1%

---

## 文件清单

### 新建文件 (1)

1. **`addons/juicy_mixer/utils/juicy_curve_factory.gd`** (~800 行)
   - CurvePreset 枚举定义
   - 25 个曲线创建函数
   - 缓存系统
   - 元数据和工具函数

2. **`addons/juicy_mixer/tests/test_curve_factory.gd`** (~300 行)
   - 单元测试
   - 性能测试
   - 兼容性测试

### 修改文件 (3)

1. **`addons/juicy_mixer/resources/juicy_property_track.gd`**
   - 添加 curve_preset 属性 (~line 130)
   - 添加 _legacy_ease_preset (~line 133)
   - 实现 _apply_curve_preset_smart() (~line 1700+)
   - 更新 _apply_easing_preset() (~line 737)
   - **总添加**: ~100 行

2. **`addons/juicy_mixer/editor/juicy_timeline_inspector.gd`**
   - 更新 _parse_property() (~line 70)
   - 添加 _create_curve_preset_editor() (~line 85)
   - 添加 _populate_curve_preset_menu() (~line 120)
   - **总添加**: ~120 行

3. **`addons/juicy_mixer/editor/juicy_timeline_canvas.gd`**
   - 修改 _handle_right_click() (~line 543)
   - 添加 _add_curve_preset_submenu_items() (~line 670)
   - 更新 id_pressed 处理 (~line 574)
   - **总添加**: ~80 行

---

## 风险评估

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|-------|------|---------|
| **曲线数学实现复杂** | 中 | 中 | 参考业界标准（Tween、Unity） |
| **性能问题** | 低 | 中 | 使用缓存优化，采样点数控制 |
| **向后兼容性问题** | 低 | 高 | 保留旧属性，自动迁移 |
| **UI 复杂度** | 低 | 低 | 复用现有 UI 模式 |
| **用户学习成本** | 低 | 低 | 提供预设预览和描述 |

---

## 成功指标

### 功能完整性
- ✅ 25 种预设全部实现
- ✅ Inspector 下拉菜单正常工作
- ✅ Canvas 右键菜单正常工作
- ✅ 向后兼容性验证通过

### 性能指标
- ✅ 曲线创建 < 5ms
- ✅ 缓存检索 < 1ms
- ✅ 内存占用 < 100KB
- ✅ 帧率影响 < 1%

### 用户体验
- ✅ 预设选择直观
- ✅ 应用反馈及时
- ✅ 菜单组织清晰
- ✅ 文档完整

---

## 参考资料

### 内部参考
- Phase 3B: Inspector UI 优化完成报告
- [JuicyPropertyTrack 代码](../resources/juicy_property_track.gd)
- [Timeline Inspector 代码](../editor/juicy_timeline_inspector.gd)

### 外部参考
- [Godot Tween.ease_type](https://docs.godotengine.org/en/stable/classes/class_tween.html)
- [Unity Animation Curves](https://docs.unity3d.com/ScriptReference/AnimationCurve.html)
- [Easing Functions Cheat Sheet](https://easings.net/)

---

## 附录

### A. 预设完整列表

| ID | 名称 | 分类 | 描述 | 数学公式 |
|----|------|------|------|---------|
| 0 | Linear | Basic | 线性插值 | f(t) = t |
| 1 | Ease In | Basic | 二次缓入 | f(t) = t² |
| 2 | Ease Out | Basic | 二次缓出 | f(t) = 1-(1-t)² |
| 3 | Ease In Out | Basic | 二次缓入缓出 | f(t) = 2t² (t<0.5), 1-2(1-t)² (t≥0.5) |
| 4 | Ease In Back | Back | 超越缓入 | f(t) = t²((1.7+1)t-1.7) |
| 5 | Ease Out Back | Back | 超越缓出 | f(t) = 1-(1-t)²((1.7+1)(1-t)+1.7) |
| 6 | Ease In Out Back | Back | 超越缓入缓出 | 组合 Ease In/Out Back |
| 7 | Ease In Elastic | Elastic | 弹性缓入 | sin(13π/2·t)·2^(10(t-1)) |
| 8 | Ease Out Elastic | Elastic | 弹性缓出 | sin(-13π/2·(t+1))·2^(-10t)+1 |
| 9 | Ease In Out Elastic | Elastic | 弹性缓入缓出 | 组合弹性 |
| 10 | Bounce In | Bounce | 弹跳进入 | 反向 Bounce Out |
| 11 | Bounce Out | Bounce | 弹跳结束 | 7.5625t² (分段) |
| 12 | Bounce In Out | Bounce | 弹跳进入结束 | 组合弹跳 |
| 13 | Ease In Expo | Exponential | 指数缓入 | 2^(10t-10) |
| 14 | Ease Out Expo | Exponential | 指数缓出 | -2^(-10t)+1 |
| 15 | Ease In Out Expo | Exponential | 指数缓入缓出 | 组合指数 |
| 16 | Ease In Sine | Sine | 正弦缓入 | -cos(t·π/2)+1 |
| 17 | Ease Out Sine | Sine | 正弦缓出 | sin(t·π/2) |
| 18 | Ease In Out Sine | Sine | 正弦缓入缓出 | 组合正弦 |
| 19 | Ease In Quad | Quadratic | 二次缓入 | t² |
| 20 | Ease Out Quad | Quadratic | 二次缓出 | -t²+2t |
| 21 | Ease In Out Quad | Quadratic | 二次缓入缓出 | 组合二次 |
| 22 | Ease In Cubic | Cubic | 三次缓入 | t³ |
| 23 | Ease Out Cubic | Cubic | 三次缓出 | t³-3t²+3t |
| 24 | Ease In Out Cubic | Cubic | 三次缓入缓出 | 组合三次 |

### B. 预设应用场景建议

**常用预设** (推荐新手使用):
- Linear - 恒定速度
- Ease Out - 快速开始，缓慢结束
- Ease In Out - 平滑过渡

**动画效果**:
- Bounce Out - 落地弹跳
- Elastic Out - 弹性震动
- Ease Out Back - 超越回归

**UI 动画**:
- Ease In Sine - 平滑进入
- Ease Out Sine - 平滑退出
- Ease Out Expo - 快速淡出

---

**文档结束**
