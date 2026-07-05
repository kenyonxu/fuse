# Property Track Phase 2 测试指南

## 测试目标

验证 Phase 2 的双向 Bake 系统功能：
- **Curve → Keyframes**: 将动画曲线烘焙为关键帧数组
- **Keyframes → Curve**: 将关键帧数组反向烘焙为动画曲线
- **Round Trip Test**: 验证双向转换的精度

## 测试环境

### 测试场景
- **文件**: `test_property_track_phase2.tscn`
- **脚本**: `test_property_track_phase2.gd`
- **运行方式**: 在 Godot 编辑器中打开场景并按 F5 运行

### 测试配置
- **测试节点**: Sprite2D (TestSprite)
- **测试属性**: `position` (Vector2 类型)
- **时间范围**: 0.0 ~ 2.0 秒
- **值域**: Vector2(100, 100) ~ Vector2(500, 100)

## 测试流程

### 1. 测试 Curve → Keyframes

**目的**: 验证将动画曲线转换为关键帧数组的功能

**步骤**:
1. 运行测试场景
2. 按键 `1` 开始测试
3. 观察 Console 输出

**预期结果**:
```
=== 测试 Curve → Keyframes ===
原始曲线点数: 3
  - 点 0: (0, 0)
  - 点 1: (0.5, 1)
  - 点 2: (1, 0)

Bake 结果:
  - 编辑模式: KEYFRAME_BASED
  - 关键帧数量: 11
  - Bake 元数据: True
  - 关键帧 0: time=0.00, value=(100, 100)
  - 关键帧 1: time=0.20, value=(180, 100)
  - ...

✅ Curve → Keyframes 转换测试 PASSED
```

**验收标准**:
- ✅ 编辑模式切换为 `KEYFRAME_BASED`
- ✅ 生成指定数量的关键帧（11 个）
- ✅ `keyframes_baked_from_curve` 标记为 `true`
- ✅ 关键帧时间均匀分布在 time_start ~ time_end 范围内
- ✅ 关键帧值正确映射（使用 `_map_curve_value_to_property_type()`）

---

### 2. 测试 Keyframes → Curve

**目的**: 验证将关键帧数组反向转换为动画曲线的功能

**步骤**:
1. 运行测试场景
2. 按键 `2` 开始测试
3. 观察 Console 输出

**预期结果**:
```
=== 测试 Keyframes → Curve ===
原始关键帧数量: 3
  - 关键帧 0: time=0.00, value=(100, 100)
  - 关键帧 1: time=1.00, value=(300, 100)
  - 关键帧 2: time=2.00, value=(100, 100)

Bake Back 结果:
  - 编辑模式: CURVE_BASED
  - 曲线点数: 3
  - 曲线点 0: (0, 0)
  - 曲线点 1: (0.5, 0.5)
  - 曲线点 2: (1, 0)

✅ Keyframes → Curve 转换测试 PASSED
```

**验收标准**:
- ✅ 编辑模式切换为 `CURVE_BASED`
- ✅ 创建新的曲线资源
- ✅ 曲线点数量与关键帧数量一致
- ✅ `keyframes_baked_from_curve` 标记为 `false`
- ✅ 曲线点正确归一化到 0-1 范围

---

### 3. 测试双向转换精度

**目的**: 验证 Curve → Keyframes → Curve 的转换精度

**步骤**:
1. 运行测试场景
2. 按键 `3` 开始测试
3. 观察 Console 输出

**预期结果**:
```
=== 测试双向转换精度 ===

步骤 1: Curve → Keyframes
  生成关键帧数: 21

步骤 2: Keyframes → Curve
  生成曲线点数: 21

步骤 3: 验证精度
  最大误差: 3.4567 像素
  验收标准: 误差 < 10.0 像素

✅ 双向转换精度测试 PASSED
```

**验收标准**:
- ✅ 最大误差 < 10.0 像素（对于 Vector2 类型）
- ✅ 转换后的曲线与原始曲线在采样点上保持一致
- ✅ 编辑模式正确切换（KEYFRAME_BASED → CURVE_BASED）

---

## 可视化验证

### 动画播放
测试过程中，Sprite 会从左向右移动，演示 Parabolic 曲线（抛物线）：
- **起点**: (100, 100)
- **顶点**: (500, 100) at t=1.0s
- **终点**: (100, 100) at t=2.0s

### 标签显示
实时显示：
- 当前测试类型
- 运行时间
- Sprite 位置

---

## 故障排查

### 问题 1: bake_curve_to_keyframes() 报错
**错误信息**: `无法 bake：没有 animation_curve`

**解决方法**:
- 确保在调用 `bake_curve_to_keyframes()` 前已设置 `animation_curve`
- 检查曲线资源是否有效

---

### 问题 2: bake_keyframes_to_curve() 报错
**错误信息**: `无法 bake：没有 keyframes`

**解决方法**:
- 确保在调用 `bake_keyframes_to_curve()` 前 keyframes 数组不为空
- 检查关键帧资源是否有效

---

### 问题 3: 关键帧值类型错误
**错误信息**: `Invalid cast: could not convert value to 'Vector2'`

**解决方法**:
- 确保 `value_min` 和 `value_max` 的类型与属性类型匹配
- 检查 `_current_property_type` 是否正确设置
- 尝试重新选择 `property_path` 以触发类型自动调整

---

### 问题 4: 转换精度超出预期
**错误信息**: `Assertion failed: 最大误差应小于 10 像素`

**可能原因**:
1. 曲线过于复杂，关键帧数量不足以表示
2. `_normalize_value()` 函数对 Vector2/Vector3 的归一化策略不够精确

**解决方法**:
- 增加 bake 时的关键帧数量（例如从 20 增加到 50）
- 检查曲线形状是否过于复杂

---

## 扩展测试

### 手动测试步骤

#### 1. 在 Inspector 中测试 Bake 功能

1. 创建一个 `JuicyFeedback` 资源
2. 添加 `JuicyPropertyTrack`
3. 配置属性：
   - `target`: 选择场景中的 Sprite2D
   - `property_path`: 选择 "position"
   - `edit_mode`: CURVE_BASED
   - `time_start`: 0.0
   - `time_end`: 2.0
   - `value_min`: Vector2(100, 100)
   - `value_max`: Vector2(500, 100)
4. 创建 AnimationCurve 资源并添加点
5. 在脚本中调用 `bake_curve_to_keyframes()`
6. 观察 Inspector 中 `keyframes` 数组的变化

#### 2. 测试不同属性类型

支持的属性类型：
- **Float**: `modulate.a` (透明度)
- **Vector2**: `position`, `scale`
- **Vector3**: `position` (Node3D)
- **Color**: `modulate`
- **Int**: `rotation_degrees`

修改测试脚本中的 `property_path` 和对应的 `value_min`/`value_max` 来测试不同类型。

---

## 性能基准

### Bake 操作性能
- **10 个关键帧**: < 10ms
- **20 个关键帧**: < 20ms
- **50 个关键帧**: < 50ms

### 采样性能
- **Curve 模式**: ~60 FPS
- **Keyframe 模式**: ~60 FPS
- **转换开销**: 可忽略不计

---

## 相关文档

- [Property Track 改进提案](../docs/property_track_curve_keyframe_improvement_proposal.md)
- [Phase 1 测试指南](./TEST_PHASE1_GUIDE.md)
- [JuicyPropertyTrack API 文档](../docs/api_reference.md)

---

**文档版本**: v1.0
**最后更新**: 2026-01-07
**作者**: Claude
