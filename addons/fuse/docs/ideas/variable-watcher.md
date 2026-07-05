# 运行时变量监视器（Variable Watcher）

## 状态

提案

## 动机

Fuse 的三层变量系统（局部/作用域/全局）在运行时是"黑盒"。用户无法实时看到变量值的变化，调试时只能靠 Print 指令手动输出。现有的 DebugVisualizer 虽然在执行步骤详情中记录了变量变化，但信息嵌在执行历史中，不够直观。

## 与现有系统的关系

DebugVisualizer（`editor/debugging/debug_visualizer.gd`）已有变量变化记录能力（`_format_step_details` 中的 `variable_state` 和 `variable_changes`），但无法做到实时监视。

Variable Watcher 将作为 DebugVisualizer 的**新增 Tab**（"执行历史" / "变量监视"），复用其面板框架、本地化机制和 ExecutionTracker 数据通道。

## 与现有能力的差距

| 能力 | 现有 DebugVisualizer | Variable Watcher |
|------|---------------------|-----------------|
| 变量值查看 | 嵌在执行步骤详情中 | 独立面板，一览所有变量 |
| 实时更新 | 手动刷新/定时刷新 | 实时推送变量变化 |
| 作用域切换 | 不支持 | Global / Scope / Local 三层 |
| 值变更高亮 | 无 | 变化时闪烁提示 |
| 运行时修改 | 无 | 双击修改变量值 |
| Array/Dict 展开 | 只显示数量 | 点击展开查看内容 |

## 核心设计

### 变量监视面板

```
┌─ Fuse Variables ───────────────────────────────┐
│ Scope: [Global ▾] / [Scope: Player ▾] / [Local]  │
│                                                   │
│  Name              Type      Value               │
│  ────────────────  ────────  ────────────────    │
│  health            int       85                   │
│  max_health        int       100                  │
│  jump_count        int       1                    │
│  score             float     1250.0               │
│  player_name       String    "Hero"              │
│  inventory         Array     [3 items]  ▸         │
│  is_alive          bool      true                │
│  last_damage_time  float     2.341               │
│                                                   │
│  💾 Values updated 0.02s ago                      │
└───────────────────────────────────────────────────┘
```

### 关键特性

1. **三层作用域切换** — Global / Scope（按节点筛选）/ Local（跟随当前执行上下文）
2. **实时刷新** — 运行时自动更新，支持暂停时冻结当前值
3. **值变更高亮** — 变量值变化时短暂高亮（黄色闪烁）
4. **Array/Dict 展开** — 点击 ▸ 展开查看内容
5. **运行时修改** — 双击值直接修改（调试用）
6. **变量历史** — 右键 → "Show History"，弹出值变化折线图

## 新增组件

- **VariableSnapshotService** — 从三层变量系统定期采样当前值，通过 ExecutionTracker 框架推送到编辑器
- **VariableWatcherPanel** — 独立的变量监视 UI，作为 DebugVisualizer 的子 Tab
- 复用：ExecutionTracker（数据通道）、FuseLocalization（本地化）、DebugVisualizer 面板框架

## 交付计划

### V1 - 基础监视

- [ ] VariableSnapshotService（定期采样 + 变化检测）
- [ ] VariableWatcherPanel（三层作用域 + 实时显示）
- [ ] 集成到 DebugVisualizer 作为新 Tab
- [ ] 值变更高亮
- [ ] Array/Dict 展开

### V2 - 调试增强

- [ ] 运行时修改变量值
- [ ] 变量历史折线图
- [ ] 条件断点（变量达到特定值时暂停）
