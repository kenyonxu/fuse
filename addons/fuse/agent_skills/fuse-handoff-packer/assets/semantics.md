# Fuse 运行时语义契约（v1 · Fuse 4.7 · 2026-09）

> 本文件描述**源 Fuse 运行时**的行为语义。接包 agent 编写替代代码时以本契约为等价性标准；
> 与 bundle 内 preset JSON 原文冲突时，以 preset 原文为准，并在交付说明中显式列出差异假设。

## 1. 触发与重入
- 每个**触发器 binding** 同一时刻只跑一条执行链：Trigger 单 runner；MultiEventTrigger 每个 binding 各有独立 runner，不同 binding 之间可并发。
- 执行中再次触发（同一 binding）：默认**忽略（SKIP）**。
- L4 MultiEventTrigger 的单个 binding 可配置 RESTART：**取消当前执行并重启**；取消动作推迟到该次触发的条件检查通过之后才发生。重启的新一轮执行经 `call_deferred` 推迟到**帧末**才启动（旧执行取消后需收尾：顺序协程同步唤醒、并行等待为帧轮询需等一帧），等价实现必须保证新执行不与旧执行的状态收尾竞争。（源：core/multi_event_trigger.gd:299-304）
- trigger_once：生命周期内只生效一次，已触发的再触发直接忽略（Trigger 按节点记一次；MultiEventTrigger 按各 binding 分别记一次）。

## 2. 门控消耗时机（易错点）
- **冷却**（GLOBAL / PER_OBJECT 两档）：冷却检查通过**即开始计时**——即使随后的条件检查失败，冷却也已经进入。效果：条件失败期间的重试受冷却约束。
- **trigger_once**：**条件通过才消耗**——条件失败不消耗一次性机会，后续触发仍可放行。
- 冷却状态存储：GLOBAL 记最近触发时刻；PER_OBJECT 按触发者 object_id 各记各的。

## 3. 单次触发 = 一个执行上下文（LOCAL 连续性）
- 每次触发新建一个执行上下文（ctx），**整条指令链**（含 IfThen/IfElse/Loop 等嵌套内的指令与内嵌条件对象）共享它。
- **local 层变量存于 ctx**：跨指令读写只在这一次执行链内有效，链结束即消失。
- 替代代码必须保证等价的"单次触发链内状态连续性"——不要逐指令重置局部状态；一次触发链内的中间量应存活到链结束。

## 4. 事件参数注入
- 触发事件携带的参数字典以 `event_<key>` 形式写入 ctx，供指令与条件引用
  （例：OnReceiveEvent 收到 `{"score": 10}` → 条件/指令引用 `event_score`）。
- `event_source` 指向触发器节点自身；`triggered_node` 指向本次触发的事件来源节点（由事件回调传入，如碰撞体/焦点节点）。
- SendEvent 的 event_args 值支持 `$var` 形式引用变量（发送时从 ctx 解析为当前值）。

## 5. 指令序列执行
- **SEQUENTIAL**（默认）：顺序执行，每条指令 await 完成才执行下一条。
- **PARALLEL**：全部指令并行启动，等待全部结束。
- **失败传播**：stop_on_error 默认开启，仅作用于 SEQUENTIAL——某指令执行失败即停止序列剩余指令并发出失败信号（`execution_failed`）；PARALLEL 不中途取消，等全部结束后统一收集错误并发出失败信号。
- 嵌套序列（IfThen/IfElse 的分支、Loop 循环体等）递归适用同规则。

## 6. 三层变量
| 层 | 生命周期 | 等价实现建议 |
|----|---------|-------------|
| local | 单次执行链内 | 触发处理函数的局部状态（一次调用的局部变量/字典） |
| scope | 节点邻域共享（沿树向上搜索 ScopeVariableContainer） | 挂在共同祖先节点上的共享组件 |
| global | 全游戏持久；可存档/读档（粒度见下） | autoload 单例（见 templates/global_state.gd） |

**读取回退链**（写不回退，唯一例外是 scope 缺容器，见下）：
| 读取 scope | 查找顺序 |
|-----------|---------|
| local | ctx 局部变量 → **miss 回落 global 同名变量** → default |
| scope | 沿树向上找 ScopeVariableContainer → **缺容器时回退读 LOCAL**（并发 error，不再回落 global） |
| global | 仅查全局服务 → default |

- 写入：local / global 各写各层，无回退；**scope 写缺容器时回退写入 LOCAL**（并发 error）。
- `has_variable` 的存在性判定同样按 local → global 顺序。
- （源：core/base/variable_context.gd:89-119,144-161,184-200,238-247）

**global 存档粒度**：全局变量带 `persistent` 标志（默认 false）。两条保存路径粒度不同——
- 显式 SaveGlobalVariables 指令：`save_scope` 参数可选 **ALL（默认，全部保存）** 或 PERSISTENT_ONLY（仅 persistent）；
- GlobalVariableAssistant 的自动保存（变更延迟定时器 / 退出清理）**只保存 persistent 变量**；
- LoadGlobalVariables 整份加载，无范围参数。
- （源：core/base/base_variable.gd:45；instructions/variables/save_global_variables.gd:42,125-129；core/global_variable_assistant.gd:126-132,406-410,441-470；instructions/variables/load_global_variables.gd:97）

## 7. 等价性自检表（写完代码逐条对照）
- [ ] 重触发行为与源一致（默认 SKIP；源配 RESTART 的 binding 是否实现了取消重启）
- [ ] 单次触发链内状态连续（local 语义）
- [ ] 冷却"检查通过即计时"；trigger_once"条件通过才消耗"
- [ ] `event_<key>` 参数名映射正确；`$var` 引用已解析
- [ ] SEQUENTIAL/PARALLEL 与失败停止语义一致
