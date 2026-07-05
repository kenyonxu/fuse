# JuicyMixer 插件架构整改计划

日期：2026-04-21
验证日期：2026-04-30（逐文件源码对照验证，凡标注 `[验证备注]` 处均为验证后添加的补充意见）

关联文档：

- `addons/juicy_mixer/docs/system_docs/analysis/2026-04-21-juicy-mixer-architecture-assessment.md`

## 1. 目标

本计划用于指导 `juicy_mixer` 下一阶段的架构治理。目标不是推翻现有系统，而是在保留核心能力可用的前提下，优先统一运行时边界、澄清主执行链、拆分过度集中的入口与大类。

本次整改遵循以下原则：

- 先统一主链语义，再治理大类
- 先收敛边界，再决定是否重构内部实现
- 尽量保持现有资源格式、主要 API 和用户工作流兼容
- 每个阶段都必须可独立验收、独立回退

## 2. 整改范围

本计划重点覆盖：

- 运行时入口：`core/juicy_mixer.gd`、`core/juicy_mixer_manager.gd`
- 调度与执行链：`core/juicy_director.gd`
- 驱动机制：`core/juicy_driver_registry.gd`、`drivers/juicy_driver.gd`
- Context 与中间件：`core/juicy_context.gd`、`core/juicy_middleware_pipeline.gd`
- 时间线系统：`resources/juicy_timeline_resource.gd`、`drivers/juicy_timeline_driver.gd`
- 编辑器入口：`plugin.gd`、`editor/juicy_timeline_editor_plugin.gd`

> **[验证备注 - 2026-04-30]** 经逐文件源码验证，评估报告中全部 8 项风险均已确认。此外发现两个评估报告未覆盖的重要问题：
> 
> 1. **`has_method()` 鸭子类型泛滥**：代码中大量使用 `if x.has_method("foo")` 做运行时类型检查（如 `juicy_mixer.gd:136-142`、`juicy_director.gd:276-278`、`juicy_context.gd:288`），缺乏接口契约。任何重构都可能触发静默失败，应在 Phase 0 基线阶段定义核心接口。
> 2. **`JuicyMixer` 自身也过载**：570 行，除初始化外还包装了中间件 API、事件 API、中断 API、池化 API，已从"全局入口"变成"万能代理"。建议在 Phase 3（插件入口拆分）中一并处理，或单独列为一项风险。

## 3. 分阶段总览

### Phase 0：基线固化

目标：

- 固定当前核心行为，建立整改前回归基线

输出：

- 核心回归场景清单
- 运行时入口行为说明
- 兼容性白名单

### Phase 1：统一运行时入口语义

目标：

- 明确 `JuicyMixer` 和 `JuicyMixerManager` 的角色分工

输出：

- 统一的运行时启动模型
- 明确的服务层/宿主层定义

### Phase 2：澄清驱动主链与注册表职责

目标：

- 解决“注册表承诺”和“资源工厂执行链”不一致的问题

输出：

- 驱动主路径定稿
- 注册表职责收口

### Phase 3：插件入口拆分与编辑器残留清理

目标：

- 把 `plugin.gd` 从集中式入口改成编排器

输出：

- 编辑器 bootstrap 拆分
- Timeline 旁路插件去留明确

### Phase 4：Timeline 子系统收口

目标：

- 降低 Timeline 资源、驱动和编辑器之间的交叉耦合

输出：

- 更清晰的 Timeline 资源层 / 运行层 / 编辑器层职责

### Phase 5：Context 与 MiddlewarePipeline 减肥

目标：

- 控制核心大类继续膨胀，拆出子职责

输出：

- 精简后的 Context 门面
- 拆分后的 Pipeline 内部模块

## 4. Phase 0：基线固化

### 4.1 目标

在整改前，先把 JuicyMixer 的现有核心行为固定下来，避免改完以后不知道哪些是新增问题，哪些是原有行为。

### 4.2 关键任务

- 整理当前已有测试，建立最小回归集
- 明确以下行为是否是“当前设计的一部分”：
  - 仅调用 `JuicyMixer.play()`，没有 `JuicyMixerManager` 时是否能正常推进
  - 有 `JuicyMixerManager` 时每帧调度是否唯一
  - Timeline 通过 `JuicyTimelinePlayer` 播放时的依赖链
  - 中间件默认注册顺序
  - Context 池与 PoolManager 预热行为
- 建立已知问题白名单：
  - Driver auto discover 为空实现
  - `JuicyTimelineEditorPlugin` 旁路实例化
  - Timeline 资源/驱动为大类

### 4.3 建议产出

- `addons/juicy_mixer/tests/README_architecture_regression.md`
- 运行时启动方式说明文档

### 4.4 验收标准

- 能明确列出整改后必须保持不变的核心行为
- 每个整改阶段都有对应的最小验证清单

## 5. Phase 1：统一运行时入口语义

### 5.1 目标

解决当前“静态服务入口”和“场景节点驱动器”并存却未显式建模的问题。

### 5.2 现状问题

当前表现为：

- `JuicyMixer` 负责初始化核心系统
- `JuicyMixerManager` 在 `_process()` 中实际驱动 `Director.process(delta)`

这会让系统处于“看似全局服务，实则依赖普通 Node 推进”的灰区。

### 5.3 方案方向

优先建议采用：

- `JuicyMixerRuntimeService`
- `JuicyMixerManager extends Node`

角色定义：

- `RuntimeService`
  - 初始化 Director / Middleware / Pool
  - 维护全局状态
  - 提供 play / stop / query API
- `Manager`
  - 作为场景中的宿主和时钟驱动器
  - 仅负责推进 runtime 的 `process(delta)`
  - 负责场景级配置应用

如果项目更偏全局系统，也可改为真正的 Autoload 运行时，但这需要更大改动。

> **[验证备注]** 源码确认：`JuicyMixer`（`RefCounted` 静态单例，行 7）负责初始化核心系统，`JuicyMixerManager`（`extends Node`，行 7）在 `_process()` 中驱动 `Director.process(delta)`（行 37-41）。两套角色隐式耦合——没有 Manager 节点时 `JuicyMixer.play()` 可创建 Context 但主循环不被推进。这是当前最优先需要解决的边界问题。

### 5.4 关键任务

- 文档化当前推荐启动方式
- 为 `JuicyMixer` 增加“当前是否有活动驱动器”的显式状态
- `JuicyMixerManager` 不再隐式承担“必须存在才有运行时推进”的隐藏职责
- 如果继续保留 Manager 驱动模式，应在 `JuicyMixer.play()` 时检测并警告无宿主驱动器状态

### 5.5 验收标准

- 使用者能明确知道系统应如何被驱动
- “能创建 Context 但不推进”的隐性失败被消除或显式暴露
- 服务层和宿主层分工清晰

## 6. Phase 2：澄清驱动主链与注册表职责

### 6.1 目标

统一“驱动从哪里来”的架构语义。

### 6.2 当前问题

当前同时存在两条路径：

- `JuicyDriverRegistry.auto_discover_drivers()`
- `context.resource.create_drivers()`

其中前者是空实现，后者是真实执行链。

### 6.3 决策建议

建议优先采用：

- 资源工厂是运行时主路径
- 注册表退化为”索引/验证/编辑器诊断工具”

原因：

- 目前代码已经围绕 `resource.create_drivers()` 展开
- 迁移成本最低
- 更符合资源驱动型插件的实际使用方式

> **[验证备注]** 源码确认：`_scan_project_drivers()`（行 107-110）返回空数组 `[]`，注释”暂时返回空数组，后续实现”。而 `_execute_drivers()`（行 338-341）直接调用 `context.resource.create_drivers()` 并缓存到 meta，完全绕过注册表。当前是典型的”名义架构与真实执行链不一致”——建议方向 A（资源工厂为主路径）是正确选择，因为迁移成本最低。

### 6.4 关键任务

- 在架构文档和代码注释中明确：
  - 运行时驱动创建由 Resource 负责
  - Registry 仅负责索引、分析和编辑器辅助
- 如果不打算实现自动发现，应删除或降级 `auto_discover_drivers()` 的主流程地位
- 如果保留自动发现接口，应明确标记为未启用/实验性能力

### 6.5 验收标准

- 维护者能明确说出驱动主路径
- 注册表与资源工厂不再争夺“主入口”角色
- `JuicyMixer._initialize()` 不再调用无实际意义的自动发现流程，或有真实实现支撑

## 7. Phase 3：插件入口拆分与编辑器残留清理

### 7.1 目标

减少 `plugin.gd` 过载，清理 Timeline 编辑器双入口痕迹。

### 7.2 目标结构

建议拆分为：

- `editor/bootstrap/juicy_type_registrar.gd`
- `editor/bootstrap/juicy_timeline_editor_bootstrap.gd`
- `editor/bootstrap/juicy_audio_editor_bootstrap.gd`
- `editor/bootstrap/juicy_scene_tools_bootstrap.gd`

`plugin.gd` 自身只负责：

- `_enter_tree()`
- `_exit_tree()`
- 调度各 bootstrap 模块

### 7.3 `JuicyTimelineEditorPlugin` 的处理建议

必须先做去留判断：

- 如果已废弃：删除并迁移引用
- 如果仍有用途：改成普通辅助类，不得直接 `new()` 出一个脱离 Godot 生命周期的 EditorPlugin

> **[验证备注]** 源码确认：`get_instance()`（行 25-30）在 `instance == null` 时直接 `JuicyTimelineEditorPlugin.new()`，创建一个脱离 Godot 插件生命周期的 EditorPlugin 对象。此外，该文件的功能与主 `plugin.gd` 高度重叠（同样 preload TimelineEditor/Inspector/ResourceCreator），建议直接废弃并合并到主入口。

### 7.4 关键任务

- 把类型注册从 `plugin.gd` 提取出去
- 把 Timeline 编辑器 UI 创建逻辑提取出去
- 把文件系统监听和场景树高亮提取成独立编辑器增强模块
- 明确主插件与 Timeline 编辑器辅助模块的唯一入口

### 7.5 验收标准

- `plugin.gd` 明显缩短
- Timeline 编辑器没有双入口或旁路实例化
- 插件启停行为与现有版本保持一致

## 8. Phase 4：Timeline 子系统收口

### 8.1 目标

把 Timeline 从“超级资源 + 超级驱动 + 超级编辑器”收敛成更清晰的子系统结构。

### 8.2 目标结构

建议划分为三层：

- `TimelineConfig`
  - 资源定义
  - 序列化
  - 最小校验
- `TimelineRuntime`
  - 轨道分类缓存
  - 播放状态
  - 循环与触发状态
- `TimelineEditorSupport`
  - 编辑器属性生成
  - 旧格式迁移工具
  - 编辑器专属辅助逻辑

### 8.3 关键任务

- 将 `JuicyTimelineResource` 中的下列职责逐步外移：
  - 轨道分组同步
  - 迁移逻辑
  - 复杂编辑器属性定义
- 将 `JuicyTimelineDriver` 中的运行态状态明确集中到 runtime state 对象
- 让 Inspector / Canvas / Resource 的数据接口稳定化

### 8.4 风险控制

- 不在第一轮同时重构所有 Track 子类
- 不要改变已有 `.tres` 资源格式，除非加兼容迁移层
- 先做内部委托，再逐步拆类

### 8.5 验收标准

- `JuicyTimelineResource` 不再承担过多编辑器和迁移职责
- `JuicyTimelineDriver` 的运行时状态管理更集中
- Timeline 编辑器仍能正常读写现有资源

## 9. Phase 5：Context 与 MiddlewarePipeline 减肥

### 9.1 目标

避免 `JuicyContext` 和 `JuicyMiddlewarePipeline` 继续演化成难以维护的大一统核心类。

### 9.2 Context 拆分建议

建议保持 `JuicyContext` 作为门面，但将内部职责拆分为：

- `ContextRuntimeState`
  - active / paused / completed / progress / duration
- `ContextMiddlewareStore`
  - middleware_data / property_overrides
- `ContextEventStore`
  - 事件列表
- `ContextParameterStore`
  - 动态参数与参数映射

### 9.3 Pipeline 拆分建议

建议把 `JuicyMiddlewarePipeline` 内部职责拆为：

- `MiddlewareRegistry`
  - 注册、删除、排序、启停
- `MiddlewareExecutionChain`
  - 执行链构建与执行
- `PipelineDiagnostics`
  - 错误、日志、性能统计

### 9.4 关键任务

- 第一轮只做内部组合，不改外部 API
- 保留 `JuicyContext` 和 `JuicyMiddlewarePipeline` 的主要公共方法
- 通过委托方式逐步将内部实现迁出

### 9.5 验收标准

- 两个核心大类的行数显著下降
- 功能回归保持稳定
- 日志、性能统计和执行链不再挤在同一实现类里

> **[验证备注]** 拆分 Pipeline 和 Context 之前，强烈建议先在 Phase 0 基线阶段定义核心接口契约。当前代码中大量使用 `has_method()` 做运行时鸭子类型检查（如 `juicy_director.gd:276` 的 `_middleware_pipeline.has_method("execute")`、`juicy_director.gd:346` 的 `driver.has_method("prepare")`），缺乏编译期保证。如果先拆类而不先定义接口，重构后的调用链会变得更加脆弱——每个拆分出来的子对象都需要 `has_method()` 守卫。建议优先级：**先定义接口 → 再拆类**。

## 10. 测试与验收策略

每个阶段至少应执行以下验证：

- 主反馈播放与停止
- `JuicyMixerManager` 推进 Director 的行为
- 默认中间件注册顺序与执行
- Context 池获取/归还
- Timeline 资源编辑、保存、加载
- Timeline Driver 轨道执行
- 音频/音乐系统不受主链治理影响
- 编辑器面板、Inspector 与高亮功能正常

推荐最小回归集：

- 主反馈基础播放场景
- Timeline 播放场景
- Pooling 测试
- Middleware 集成测试
- Audio / Music 核心集成测试

## 11. 推荐执行顺序

建议顺序如下：

1. Phase 0：基线固化
2. Phase 1：统一运行时入口语义
3. Phase 2：澄清驱动主链与注册表职责
4. Phase 3：插件入口拆分与编辑器残留清理
5. Phase 4：Timeline 子系统收口
6. Phase 5：Context 与 MiddlewarePipeline 减肥

说明：

- `Phase 1` 和 `Phase 2` 必须优先，因为它们决定主架构语义
- `Timeline` 收口应放在主运行时边界清楚之后
- 大类减肥放在后段，避免一边拆一边改主链定义

> **[验证备注 - 2026-04-30]** 经源码验证后建议调整优先级：
> 
> | 原顺序 | 建议调整 | 理由 |
> |--------|---------|------|
> | Phase 0 | Phase 0 | 不变，必须先行 |
> | Phase 1 | Phase 1 | 不变，决定主语义 |
> | Phase 2 | Phase 2 | 不变，澄清执行路径 |
> | Phase 3 | **Phase 5（Pipeline 先行）** | `JuicyMiddlewarePipeline` 1379 行是当前最大单点维护负担，比 plugin.gd 的 459 行严重得多 |
> | Phase 4 | Phase 3 | Timeline 旁路插件清理跟入口拆分天然关联 |
> | Phase 5 | Phase 4 | 入口清晰后再拆 Timeline |
> 
> **核心理由**：Pipeline 1379 行 > Director 393 行 × 3.5 倍。在入口语义尚未统一之前拆分 Pipeline 确实有风险，但将 1379 行的类拖到 Phase 5 才处理也不太合理。折中建议：Phase 2 完成后先做 Pipeline 的"内部委托拆分"（不改外部 API，只拆内部职责为 MiddlewareRegistry / ExecutionChain / Diagnostics 三个子对象），Cost 低、风险可控。

## 12. 里程碑定义

### 里程碑 M1：运行时入口清晰

达成条件：

- `JuicyMixer` 与 `JuicyMixerManager` 的角色边界明确
- 系统如何被驱动有单一、清晰的说明

### 里程碑 M2：驱动主链定稿

达成条件：

- 运行时驱动来源明确
- Registry 不再作为名义主入口

### 里程碑 M3：编辑器入口可维护

达成条件：

- `plugin.gd` 主要只做编排
- Timeline 双入口/残留插件问题被消除

### 里程碑 M4：Timeline 子系统收口

达成条件：

- Timeline 资源、运行时和编辑器职责更清晰
- 大部分复杂逻辑不再集中在单一资源类上

### 里程碑 M5：核心大类控复杂度

达成条件：

- `JuicyContext` 与 `JuicyMiddlewarePipeline` 变成稳定门面
- 内部职责可以独立维护和测试

## 13. 暂不建议本轮处理的事项

以下事项建议暂不纳入本轮主整改路径：

- 全量重写所有 Driver 子类
- 一次性重做 Timeline 编辑器 UI
- 大规模改动音频/音乐模块公共 API
- 全面替换现有资源序列化格式

原因：

- 这些改动面过大
- 与主链边界治理关联不够直接
- 容易分散整改资源

## 14. 结论

`juicy_mixer` 当前最需要的，不是继续堆更多功能，而是先把主架构语义说清楚、做扎实：

- 运行时入口要统一
- 驱动主链要明确
- 插件入口要拆分
- Timeline 子系统要收口
- Context 与 Pipeline 要控复杂度

如果按本计划推进，JuicyMixer 可以在保持现有能力的前提下，从“强功能复合插件”进入“边界清晰、可持续扩展的反馈平台”状态。

