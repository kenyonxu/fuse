# game_flow — 交接工件包（Handoff Bundle）

> 你（AI agent）的任务：为该系统编写**脱离 Fuse 插件**的等价 GDScript 实现。
> 约束：不得依赖 `addons/fuse/`（不 preload、不引用类名、不假设 autoload 存在）。

## 系统意图
砖块射击主循环：接收敌死/玩家死/全灭事件，驱动波次推进、敌机刷新与计分结算（L4 多事件单元 GameManager/GameFlow）。
毕业动机：脱离 Fuse 插件独立运行（验收重点：行为等价与事件时序，而非保留编辑器能力）。

## 工件导航
| 文件 | 是什么 | 怎么用 |
|------|--------|--------|
| `system.json` | 系统划分定稿：单元清单 / 外联事件与变量（externals）/ 已确认警告 | 先读 units 与 externals——这是系统的边界 |
| `topology.json` | 源场景全量拓扑（含 source_scene 溯源） | 查节点层级与邻居单元；本系统只负责 units 列出的单元 |
| `presets/*.json` | 行为规格主体：指令序列（含参数与嵌套） | 逐 binding 阅读并翻译为代码 |
| `components.json` | 涉及组件的参数 schema（含 requires 门控） | 理解 preset 中各组件的参数含义与枚举值 |
| `semantics.md` | Fuse 运行时语义契约 | **翻译 preset 前必读**；等价性标准 |
| `acceptance.md` | 行为验收清单 | 交付前逐条核对并回标 |
| `templates/*.gd` | 基建参考实现（event_bus / object_pool / global_state） | 可采用 / 改写 / 替换；API 与 Fuse 概念对齐 |

## 本系统范围
- 单元：`GameManager/GameFlow`（MultiEventTrigger，L4，5 个事件 binding）——见 system.json units
- 消费的外部事件：EnemyDie、PlayerDie、AllEnemyDied
- 产出的外部事件：ScoreUpdate、AllEnemyDied、GameEnd、StartCountDown
- 读写的外部变量：
  - local（单次触发链内）：event_score、c_score
  - scope（节点邻域共享）：start_pos、current_wave、spawn_pos、enemy_count、current_score、player_life、instance_id（其中 current_wave / spawn_pos / enemy_count / player_life / instance_id 被系统外单元共享）
  - global（全游戏持久）：score_list（高分列表；OnReady 时经 LoadGlobalVariables 读档，死亡结算时写入）

## 语义要点（详见 semantics.md）
- 执行中重触发默认忽略（SKIP）；**例外：b0（OnInterval 音乐 binding）源配 RESTART**——重触发时取消上一轮并重启，且取消动作推迟到该次触发的条件检查通过之后、新一轮经帧末延迟启动（见 semantics.md §1）。注意该 retrigger_policy 字段未包含在 preset 导出中，此结论来自打包时的源场景校验告警（W_RESTART_DEGRADED）与毕业导出降级备案
- 一次触发 = 一个上下文：local 变量跨指令连续
- 冷却"检查通过即计时"；trigger_once"条件通过才消耗"
- 事件参数以 `event_<key>` 引用；`$var` 为变量引用

## 已知数据差异（打包时记录，接包前先读）
1. **b0 触发周期**：preset 的 `event.interval_seconds = 51.0`，而 topology.json 快照（当前源场景）同一 binding 为 25.0s。按 semantics.md 冲突规则，**以 preset 原文（51.0s）为行为规格与验收基准**；若需对齐源场景当前值，由系统所有者重导 preset 后重打包。
2. **b0 retrigger_policy**：源场景配置为 RESTART，但 preset 导出不含该字段（见"语义要点"）。等价实现按 RESTART 处理；若实现为 SKIP，须在交付说明中标注该差异。
3. **instance_id 变量**：system.json externals 列出 scope 变量 `instance_id`（来自静态分析读取 target_variable），但 preset 中唯一相关的 InstantiateScene 配置 `save_instance_id = false`——**运行时实际不写入该变量**。以 preset 运行时行为为准。

## 验收要求
交付前逐条核对 `acceptance.md`，在交付说明中对每条断言标注"已实现 / 不适用（附原因）"。

## 有歧义时
以 `semantics.md` 与 `presets/*.json` 原文为准；仍无法判定时，**显式列出你的假设**并标注影响面，不要静默猜测。
