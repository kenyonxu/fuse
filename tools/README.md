# Tools 文档

本目录包含项目开发和维护的工具脚本。

## 工具列表

### Event 迁移评估工具

**文件**: `evaluate_events_migration.py`

**用途**: 评估所有 Bricks Event 是否需要迁移到 RuntimeInstance 架构。

**背景**:
- Bricks Event 系统引入了 RuntimeInstance 架构来解决资源共享导致的运行时状态冲突问题
- 需要评估所有 59 个 Event 的迁移优先级
- 工具自动检测状态变量、评估共享风险、生成迁移建议

**使用方法**:

```bash
# 基本使用 - 运行完整评估
python tools/evaluate_events_migration.py

# 显示详细输出（调试模式）
python tools/evaluate_events_migration.py --verbose

# 指定输出路径
python tools/evaluate_events_migration.py --output my_report.md

# 按优先级过滤（只显示高优先级 Event）
python tools/evaluate_events_migration.py --filter high

# 显示帮助信息
python tools/evaluate_events_migration.py --help
```

**输出**:
- **控制台输出**: 评估结果摘要、高/中优先级 Event 列表
- **Markdown 报告**: 详细的评估报告（默认输出到 `docs/reports/event_migration_evaluation_YYYYMMDD.md`）

**报告内容**:
1. **执行摘要**
   - 总体统计（总 Event 数、有状态 Event 数、需要迁移的 Event 数等）
   - 迁移优先级分布
   - 关键发现

2. **优先级分组**
   - 高优先级迁移（强烈建议）
   - 中优先级迁移（建议）
   - 低优先级迁移（可选）
   - 无需迁移（已迁移或无状态）

3. **迁移建议**
   - 三阶段迁移计划
   - 详细迁移步骤（参考文档）
   - 代码示例

4. **详细评估结果**
   - 按分类列出所有 Event
   - 每个 Event 的状态变量、优先级、迁移状态

**评估逻辑**:

工具使用以下决策矩阵：

| 有状态变量 | 共享风险 | 是否需要迁移 | 优先级 |
|-----------|---------|-------------|--------|
| ✓ | 高 | ✓ | 高 |
| ✓ | 中 | ✓ | 中 |
| ✓ | 低 | ✗ | 低（可选） |
| ✗ | 任意 | ✗ | 无 |

**共享风险评估**:

- **高风险**: 常用 Event，容易在多个场景中被同时使用
  - 示例: `OnMouseEnter`, `OnMouseExit`, `OnInterval`, `OnInputKey`, `OnMouseButton`

- **中风险**: 通用 Event，有一定共享可能
  - 示例: `OnSignalFromGroup`, `OnPropertyChanged`, `OnVariableChanged`

- **低风险**: 专用 Event，很少被共享
  - 示例: 大多数生命周期、动画、音频 Event

**状态变量检测**:

工具检测以下运行时状态变量模式：

```python
STATE_PATTERNS = [
    r'_has_triggered\s*[:=]',
    r'_is_hovered\s*[:=]',
    r'_has_exited\s*[:=]',
    r'_is_active\s*[:=]',
    r'_is_running\s*[:=]',
    r'_is_completed\s*[:=]',
    r'_trigger_count\s*[:=]',
    r'_execution_count\s*[:=]',
    r'_current_repeat_count\s*[:=]',
    r'_last_trigger_time\s*[:=]',
    r'_last_time\s*[:=]',
    r'_last_input_time\s*[:=]',
    r'_remaining_time\s*[:=]',
    r'_timer\s*[:=]',
    r'_tween\s*[:=]',
    r'_main_timer\s*[:=]',
    r'_progress_timer\s*[:=]',
    r'_triggered_bodies\s*[:=]',
    r'_owner_node_ref\s*[:=]',
]
```

**迁移检测**:

工具检测 Event 是否已迁移：

```python
has_runtime_instance = (
    "RuntimeEventInstance" in content and
    "initialize_with_runtime_instance" in content
)
```

**评估结果示例**:

```
============================================================
Event 迁移评估结果
============================================================
总 Event 数: 59
有状态变量的 Event: 47
需要迁移的 Event: 10
已迁移的 Event: 2
可选迁移的 Event: 37

优先级分布:
  - 高优先级: 7
  - 中优先级: 3
  - 低优先级: 37
============================================================

已迁移的 Event (使用 RuntimeEventInstance):
  ✓ OnMouseEnter
  ✓ OnMouseExit

高优先级 Event (强烈建议迁移):
  🚨 OnInputKey
      状态变量: _has_triggered, _timer
      推理: 有状态变量 + 高共享风险 = 强烈建议迁移
  ...
```

## 开发指南

### 添加新工具

1. 在 `tools/` 目录创建脚本文件
2. 添加完整的文档字符串
3. 使用 `argparse` 添加命令行参数支持
4. 在本 README 中添加使用说明

### 工具脚本规范

- 使用 UTF-8 编码
- 添加类型注解
- 使用 `pathlib` 处理路径
- 提供清晰的错误信息
- 支持 `--help` 参数
- 在 Windows 上处理编码问题

## 相关文档

- **RuntimeInstance 迁移指南**: `addons/bricks/docs/development/runtime-instance-migration-guide.md`
- **Event 状态分离方案**: `addons/bricks/docs/event-resource-sharing-solution.md`
- **OnTargetSignalEmit 修复文档**: `addons/bricks/docs/development/on_target_signal_emit_fix.md`

---

**最后更新**: 2026-02-03
