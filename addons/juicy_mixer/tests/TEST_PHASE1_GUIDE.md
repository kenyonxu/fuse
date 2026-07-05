# Property Track Phase 1 测试指南

## 测试文件

- **测试场景**: `addons/juicy_mixer/tests/test_property_track_phase1.tscn`
- **测试脚本**: `addons/juicy_mixer/tests/test_property_track_phase1.gd`

## 快速开始

1. 在 Godot 编辑器中打开 `test_property_track_phase1.tscn`
2. 按 F5 运行场景
3. 按数字键 1-5 选择不同的测试类型
4. 观察控制台输出和场景中的变化

## 测试内容

### 1. Float 类型测试（按 1）
**属性**: `modulate.a` (透明度)
- **值域**: 0.0 → 1.0
- **曲线**: 线性渐变
- **预期**: Sprite 从完全透明渐变到完全不透明

**验证点**:
- ✅ 时间归一化正确（0s → 0, 1s → 1）
- ✅ Float 插值正确
- ✅ 值域映射正确

### 2. Vector2 类型测试（按 2）
**属性**: `position` (位置)
- **值域**: Vector2(100, 100) → Vector2(400, 100)
- **曲线**: 上升然后下降（中间达到最大值）
- **预期**: Sprite 向右移动 300 像素然后返回

**验证点**:
- ✅ Vector2 插值正确（逐通道）
- ✅ 时间映射正确（曲线的 0.5 对应实际时间 1.0s）
- ✅ Vector2 类型的 value_min/value_max 正常工作

### 3. Vector3 类型测试（按 3）
**属性**: `scale` (缩放)
- **值域**: Vector3(1, 1, 1) → Vector3(2, 2, 2)
- **曲线**: 上升然后下降
- **预期**: Sprite 放大 2 倍然后恢复

**验证点**:
- ✅ Vector3 插值正确
- ✅ 缩放动画流畅

### 4. Color 类型测试（按 4）
**属性**: `modulate` (颜色)
- **值域**: Color(0, 0, 0, 1) → Color(1, 1, 1, 1)
- **曲线**: 上升然后下降
- **预期**: Sprite 从黑色渐变到白色再回到黑色

**验证点**:
- ✅ Color 插值正确（逐通道）
- ✅ Color 类型的 value_min/value_max 正常工作
- ✅ 颜色选择器正常显示

### 5. Int 类型测试（按 5）
**属性**: `rotation_degrees` (旋转)
- **值域**: 0 → 360
- **曲线**: 线性增长
- **预期**: Sprite 旋转一整圈（360度）

**验证点**:
- ✅ Int 插值正确（四舍五入）
- ✅ 旋转动画流畅

## Inspector 可视化测试

在编辑器中选择 Property Track，测试以下内容：

### 时间范围属性
1. **time_start**: 应显示为 float 输入框
2. **time_end**: 应显示为 float 输入框
3. 验证：设置 time_end > time_start

### 值域属性（根据 property_path 自动切换）
| property_path | value_min 类型 | value_max 类型 | 预期默认值 |
|---------------|----------------|----------------|-----------|
| modulate.a | float 输入框 | float 输入框 | 0.0 / 1.0 |
| position | Vector2 编辑器 | Vector2 编辑器 | (0,0) / (1,1) |
| scale | Vector3 编辑器 | Vector3 编辑器 | (0,0,0) / (1,1,1) |
| modulate | Color 选择器 | Color 选择器 | 黑色 / 白色 |
| rotation_degrees | int 输入框 | int 输入框 | 0 / 100 |

### property_path 切换测试
1. 选择 property_path = "position"
2. 观察 Inspector 中 value_min/value_max 变为 Vector2 编辑器
3. 控制台应输出：`[JuicyPropertyTrack] 值域已自动调整以匹配属性类型 5` (TYPE_VECTOR2)
4. 选择 property_path = "modulate"
5. 观察 Inspector 中 value_min/value_max 变为颜色选择器
6. 控制台应输出：`[JuicyPropertyTrack] 值域已自动调整以匹配属性类型 7` (TYPE_COLOR)

## 控制台输出验证

每个测试都会输出详细的采样日志，例如：

```
🚀 Starting test type: VECTOR2_POSITION
📊 Test configured: Vector2 (position) (100, 100) → (400, 100)
⏱ Time: 0.00/2.00 | Position: (100, 100)
⏱ Time: 0.02/2.00 | Position: (103, 100)
⏱ Time: 0.04/2.00 | Position: (106, 100)
...
✅ Test completed: VECTOR2_POSITION
   Duration: 2 s
   Sample count: ~120 frames

🔍 Verification:
   Final position: (100, 100)
   ✅ Vector2 interpolation test PASSED
```

## 常见问题排查

### 问题 1: 值域类型没有自动切换
**症状**: 切换 property_path 后，value_min/value_max 类型不变

**检查**:
- [ ] 控制台是否有 `[JuicyPropertyTrack] 值域已自动调整...` 输出
- [ ] `_cached_property_type` 是否初始化为 -1
- [ ] `property_path` setter 是否调用了 `_auto_adjust_value_range_for_property_type()`

### 问题 2: 采样值不正确
**症状**: 运行测试时，值不按预期变化

**检查**:
- [ ] `animation_curve` 是否正确设置
- [ ] `time_start` 和 `time_end` 是否正确
- [ ] `_normalize_time()` 返回值是否在 0-1 范围内
- [ ] `_map_curve_value_to_property_type()` 是否返回正确的类型

### 问题 3: 类型转换错误
**症状**: 控制台输出类型转换错误

**检查**:
- [ ] `_current_property_type` 是否正确更新
- [ ] `value_min` 和 `value_max` 的类型是否与属性类型匹配
- [ ] `_get_property_list()` 中的类型定义是否正确

## 测试检查清单

### Inspector 测试
- [ ] edit_mode 可以切换
- [ ] time_start/time_end 正常显示
- [ ] Float 类型属性：显示 float 输入框
- [ ] Vector2 类型属性：显示 Vector2 编辑器
- [ ] Vector3 类型属性：显示 Vector3 编辑器
- [ ] Color 类型属性：显示颜色选择器
- [ ] Int 类型属性：显示 int 输入框
- [ ] property_path 切换时值域类型自动调整
- [ ] 控制台输出自动调整日志

### 运行时测试
- [ ] Float 插值正确（测试 1）
- [ ] Vector2 插值正确（测试 2）
- [ ] Vector3 插值正确（测试 3）
- [ ] Color 插值正确（测试 4）
- [ ] Int 插值正确（测试 5）
- [ ] 时间归一化正确
- [ ] 值域映射正确
- [ ] 曲线采样正确

## 性能测试

在测试场景运行时，观察 Godot 的性能监视器（Profiler）：

- **FPS**: 应保持 60 FPS（或显示器的刷新率）
- **Process Time**: `_process()` 和 `_physics_process()` 的时间应该很低
- **CPU Usage**: 应该没有异常的 CPU 占用

如果发现性能问题：
- [ ] 检查是否有不必要的 `notify_property_list_changed()` 调用
- [ ] 检查 `_normalize_time()` 是否被重复调用
- [ ] 检查 `_map_curve_value_to_property_type()` 中的类型转换开销

## 测试完成标准

Phase 1 测试通过的标志：
- ✅ 所有 Inspector 测试项通过
- ✅ 所有 5 个运行时测试通过
- ✅ 控制台没有错误或警告
- ✅ 性能指标正常
- ✅ 所有断言（assert）通过
