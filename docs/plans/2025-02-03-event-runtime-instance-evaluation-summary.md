# Event RuntimeInstance 迁移评估总结

**日期**: 2026-02-03
**工具**: `tools/evaluate_events_migration.py`
**评估范围**: 所有 59 个 Bricks Event

---

## 执行摘要

### 评估背景

Bricks Event 系统引入了 **RuntimeInstance 架构**来解决资源共享导致的运行时状态冲突问题。当同一个 Event 资源被多个所有者节点共享时，传统的 `var` 状态变量会导致状态污染，触发逻辑错误。

### 评估目的

1. 识别所有需要迁移到 RuntimeInstance 架构的 Event
2. 评估迁移优先级（基于共享风险和状态复杂度）
3. 生成迁移建议和行动计划
4. 验证评估工具的准确性

### 评估结果

| 指标 | 数量 | 占比 |
|------|------|------|
| **总 Event 数** | 59 | 100% |
| **有状态变量的 Event** | 47 | 79% |
| **需要迁移的 Event** | 10 | 16% |
| **已迁移的 Event** | 2 | 3% |
| **可选迁移的 Event** | 37 | 62% |
| **无需迁移的 Event** | 12 | 20% |

### 关键发现

1. **已有 2 个 Event 成功迁移**
   - `OnMouseEnter` - 使用 RuntimeInstance 管理鼠标悬停状态
   - `OnMouseExit` - 使用 RuntimeInstance 管理鼠标退出状态

2. **10 个 Event 需要立即迁移**
   - 7 个高优先级（强烈建议迁移）
   - 3 个中优先级（建议迁移）

3. **47 个 Event 有运行时状态**
   - 其中 10 个需要迁移（高+中优先级）
   - 37 个可选迁移（低优先级，但仍有状态）

4. **12 个 Event 无需迁移**
   - 10 个无运行时状态
   - 2 个已迁移

---

## 评估方法论

### 决策矩阵

| 有状态变量 | 共享风险 | 是否需要迁移 | 优先级 |
|-----------|---------|-------------|--------|
| ✓ | 高 | ✓ | **高** |
| ✓ | 中 | ✓ | **中** |
| ✓ | 低 | ✗ | **低（可选）** |
| ✗ | 任意 | ✗ | **无** |

### 状态变量检测

工具检测以下运行时状态变量模式：

- `_has_triggered` - 是否已触发
- `_is_hovered` / `_has_exited` - 鼠标/碰撞状态
- `_is_active` / `_is_running` / `_is_completed` - 执行状态
- `_trigger_count` / `_execution_count` / `_current_repeat_count` - 计数器
- `_last_trigger_time` / `_last_time` / `_last_input_time` - 时间戳
- `_remaining_time` - 剩余时间
- `_timer` / `_tween` / `_main_timer` / `_progress_timer` - 定时器和补间
- `_triggered_bodies` - 已触发的碰撞体列表
- `_owner_node_ref` - 所有者节点引用

### 共享风险评估

**高风险**（常用 Event，容易在多个场景中被同时使用）:
- `OnMouseEnter`, `OnMouseExit`, `OnInterval`
- `OnInputKey`, `OnMouseButton`, `OnArea2DEnter`
- `OnArea3DEntered`, `OnTimer`, `OnCooldown`

**中风险**（通用 Event，有一定共享可能）:
- `OnSignalFromGroup`, `OnPropertyChanged`, `OnVariableChanged`

**低风险**（专用 Event，很少被共享）:
- 大多数生命周期、动画、音频 Event

---

## 迁移优先级分组

### 高优先级迁移（强烈建议）- 7 个

这些 Event 有运行时状态且共享风险高，强烈建议尽快迁移。

| Event Name | State Variables | Sharing Risk |
|------------|-----------------|--------------|
| **OnInputKey** | _has_triggered, _timer | high |
| **OnMouseButton** | _owner_node_ref | high |
| **OnInterval** | _is_running, _is_completed, _current_repeat_count, _last_input_time, _timer, _owner_node_ref | high |
| **OnArea2DEnter** | _triggered_bodies | high |
| **OnArea3DEntered** | _triggered_bodies | high |
| **OnCooldownFinished** | _is_running, _is_completed, _remaining_time, _timer, _main_timer, _progress_timer, _owner_node_ref | high |
| **OnTimer** | _current_repeat_count, _timer, _owner_node_ref | high |

**迁移收益**: 这些是最常用的 Event，迁移后能最大程度避免状态污染问题。

---

### 中优先级迁移（建议）- 3 个

这些 Event 有运行时状态且有一定共享风险，建议迁移。

| Event Name | State Variables | Sharing Risk |
|------------|-----------------|--------------|
| **OnPropertyChanged** | _timer, _owner_node_ref | medium |
| **OnSignalFromGroup** | _owner_node_ref | medium |
| **OnVariableChanged** | _timer, _owner_node_ref | medium |

**迁移收益**: 这些 Event 有一定共享可能，迁移后可以提高系统稳定性。

---

### 低优先级迁移（可选）- 37 个

这些 Event 有运行时状态但共享风险低，可以稍后迁移。

示例（部分）:
- `OnAnimationBlend`, `OnAnimationFrameReached`, `OnAnimationLoop`
- `OnAudioBusVolumeChanged`, `OnAudioStarted`, `OnMusicBeat`
- `OnGamepadAxis`, `OnGamepadButton`, `OnInputAction`
- `OnReady`, `OnPhysicsProcess`, `OnProcess`
- `OnBodyEntered`, `OnOverlappingBodies`
- `OnRaycastHit`, `OnScreenEnteredExited`, `OnShapeCast`
- `OnCountdown`, `OnRealtime`, `OnTweenCompleted`
- 等等...

**迁移收益**: 这些 Event 很少被共享，迁移的收益较小。可以在有时间时逐步迁移，或者在实际遇到问题时再迁移。

---

### 无需迁移 - 12 个

这些 Event 无运行时状态或已迁移，不需要迁移。

**已迁移（2 个）**:
- `OnMouseEnter` - 已使用 RuntimeInstance
- `OnMouseExit` - 已使用 RuntimeInstance

**无状态（10 个）**:
- `OnNodeInstance`, `OnAnimationFinished`, `OnSceneLoaded`, `OnTreeChanged`
- `OnButtonPressed`, `OnItemSelected`, `OnTextChanged`, `OnValueChanged`
- `OnAudioFinished`, `OnFocus`

---

## 下一步迁移计划

### 第一阶段：高优先级 Event（1-2 周）

**目标**: 迁移 7 个高优先级 Event

**优先级排序**:
1. `OnInterval` - 间隔触发，最容易出现状态冲突
2. `OnInputKey` - 输入事件，常用且易共享
3. `OnMouseButton` - 鼠标按钮，常用且易共享
4. `OnTimer` - 定时器，常用且易共享
5. `OnCooldownFinished` - 冷却完成，状态复杂
6. `OnArea2DEnter` / `OnArea3DEntered` - 碰撞检测，常用

**迁移步骤**:
1. 创建 RuntimeInstance 类（如 `OnIntervalRuntime.gd`）
2. 将状态变量移动到 RuntimeInstance
3. 在 Event 中实现 `initialize_with_runtime_instance()`
4. 测试功能和状态隔离
5. 更新文档

### 第二阶段：中优先级 Event（1 周）

**目标**: 迁移 3 个中优先级 Event

1. `OnTargetSignalEmit`（实际检测为 `OnSignalFromGroup`）
2. `OnPropertyChanged`
3. `OnVariableChanged`

### 第三阶段：低优先级 Event（可选）

**目标**: 在有时间时逐步迁移 37 个低优先级 Event

- 可以按需迁移（遇到问题时）
- 或者在重构时批量迁移
- 不影响系统稳定性，可以延后

---

## 评估工具验证

### 测试结果

所有测试通过（4/4）:

1. **已迁移的 Event** - ✓ PASS
   - OnMouseEnter, OnMouseExit 正确识别为已迁移

2. **无状态 Event** - ✓ PASS
   - OnNodeInstance, OnAnimationFinished 等正确识别为无状态

3. **高优先级 Event** - ✓ PASS
   - OnInputKey, OnInterval 等正确识别为高优先级
   - 状态变量和共享风险评估准确

4. **评估计数准确性** - ✓ PASS
   - 总 Event 数: 59
   - 已迁移: 2
   - 高优先级: 7
   - 中优先级: 3
   - 需要迁移: 10

### 工具特性

评估工具提供以下功能：

1. **自动扫描**: 自动扫描所有 Event 文件
2. **状态检测**: 使用正则表达式检测运行时状态变量
3. **风险评估**: 基于 Event 类型评估共享风险
4. **决策逻辑**: 应用决策矩阵确定迁移优先级
5. **Markdown 报告**: 生成详细的评估报告
6. **命令行参数**: 支持 `--verbose`, `--output`, `--filter` 等参数

---

## 工具使用指南

### 基本使用

```bash
# 运行完整评估
python tools/evaluate_events_migration.py

# 显示详细输出
python tools/evaluate_events_migration.py --verbose

# 指定输出路径
python tools/evaluate_events_migration.py --output my_report.md

# 按优先级过滤
python tools/evaluate_events_migration.py --filter high

# 显示帮助
python tools/evaluate_events_migration.py --help
```

### 测试评估工具

```bash
# 运行测试脚本
python tools/test_evaluation.py
```

### 查看报告

评估报告默认输出到 `docs/reports/event_migration_evaluation_YYYYMMDD.md`

---

## 相关文档

- **迁移指南**: `addons/bricks/docs/development/runtime-instance-migration-guide.md`
- **状态分离方案**: `addons/bricks/docs/event-resource-sharing-solution.md`
- **OnTargetSignalEmit 修复**: `addons/bricks/docs/development/on_target_signal_emit_fix.md`
- **工具文档**: `tools/README.md`

---

## 总结

### 成果

1. **评估工具开发完成**
   - 自动评估所有 Event 的迁移需求
   - 准确检测状态变量和共享风险
   - 生成详细的评估报告

2. **评估结果清晰**
   - 59 个 Event 中，10 个需要立即迁移
   - 2 个已迁移，证明架构可行性
   - 37 个可选迁移，不影响当前稳定性

3. **迁移计划明确**
   - 三阶段迁移计划
   - 优先级排序清晰
   - 迁移步骤文档化

### 下一步行动

1. **立即开始高优先级 Event 迁移**
   - 从 `OnInterval` 开始
   - 逐步迁移 7 个高优先级 Event

2. **持续改进评估工具**
   - 根据实际迁移经验优化决策逻辑
   - 添加更多状态变量模式
   - 完善风险评估

3. **更新迁移指南**
   - 添加实际迁移案例
   - 记录常见问题和解决方案
   - 优化迁移流程

### 预期收益

完成迁移后：

1. **解决资源共享问题**
   - 同一 Event 可以被多个节点安全使用
   - 不再有状态污染问题

2. **提高系统稳定性**
   - 减少因状态冲突导致的 bug
   - 提高代码可维护性

3. **改善开发体验**
   - 开发者无需担心资源共享问题
   - 更灵活的 Event 使用方式

---

**评估完成日期**: 2026-02-03
**下次评估**: 完成第一阶段迁移后（约 2 周后）
**负责人**: 开发团队
