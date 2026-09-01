# {{系统名}} — 交接工件包（Handoff Bundle）

> 你（AI agent）的任务：为该系统编写**脱离 Fuse 插件**的等价 GDScript 实现。
> 约束：不得依赖 `addons/fuse/`（不 preload、不引用类名、不假设 autoload 存在）。

## 系统意图
{{system.description，一两句；必要时打包 agent 补充与用户确认的动机}}

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
- 单元：{{units 摘要（node_path / kind / level）}}
- 消费的外部事件：{{externals.events_in 名称}}
- 产出的外部事件：{{externals.events_out 名称}}
- 读写的外部变量：{{externals.variables 名称与 scope}}

## 语义要点（详见 semantics.md）
- 执行中重触发默认忽略（SKIP）{{若源配 RESTART 则注明}}
- 一次触发 = 一个上下文：local 变量跨指令连续
- 冷却"检查通过即计时"；trigger_once"条件通过才消耗"
- 事件参数以 `event_<key>` 引用；`$var` 为变量引用

## 验收要求
交付前逐条核对 `acceptance.md`，在交付说明中对每条断言标注"已实现 / 不适用（附原因）"。

## 有歧义时
以 `semantics.md` 与 `presets/*.json` 原文为准；仍无法判定时，**显式列出你的假设**并标注影响面，不要静默猜测。
