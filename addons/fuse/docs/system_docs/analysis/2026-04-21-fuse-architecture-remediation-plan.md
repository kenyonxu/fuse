# Fuse 插件架构整改计划

日期：2026-04-21

> **📋 完成状态（2026-06-16）**
> 
> | Phase | 状态 | 完成日期 | 备注 |
> |-------|:----:|----------|------|
> | Phase 0: 基线固化 | ✅ 完成 | 2026-06-16 | 基线文档+白名单+快照已落地 |
> | Phase 1: 一致性与注册层修复 | ✅ 完成 | 2026-06-16 | 4 项修复任务全部完成 |
> | Phase 2: 插件入口拆分 | ✅ 完成 | 2026-06-16 | plugin.gd 666→129 行，4 个 bootstrap 模块 |
> | Phase 3: 全局变量服务重构 | ✅ 完成 | 2026-06-16 | GlobalVariableService 新增，Assistant 脱树兜底已修复 |
> | Phase 4: ExecutionContext 拆分 | ✅ 完成 | 2026-06-16 | EC 1623→770 行，VariableContext + ExecutionDiagnostics 已提取 |
> | Phase 5: 编辑器边界收口 | ⬜ 待开始 | — | |

关联文档：

- `addons/fuse/docs/system_docs/analysis/2026-04-21-fuse-architecture-assessment.md`

## 1. 目标

本计划用于指导 Fuse 插件下一阶段的架构治理，目标不是“大重写”，而是在保持现有功能可用的前提下，优先消除结构性风险，降低后续功能迭代成本。

本次整改遵循四个原则：

- 先修确定性错误，再做结构优化
- 先收口边界，再增加抽象
- 尽量保持现有资源格式和外部 API 兼容
- 每个阶段都要能独立验收、独立回退

## 2. 整改范围

本计划覆盖以下重点模块：

- 插件入口：`addons/fuse/plugin.gd`
- 注册体系：`addons/fuse/editor/component_registry.gd`
- 编辑器扩展：`addons/fuse/editor/fuse_inspector_plugin.gd`
- 运行时上下文：`addons/fuse/core/base/execution_context.gd`
- 全局变量系统：`addons/fuse/core/global_variable_assistant.gd`、`addons/fuse/core/global_variable_manager.gd`
- 运行时引导与基础设施注册

## 3. 分阶段总览

### Phase 0：基线固化

目标：

- 在整改前固定当前行为，避免“边改边漂移”

输出：

- 基线测试清单
- 核心回归场景列表
- 现有已知问题白名单

### Phase 1：一致性与注册层修复

目标：

- 修复明确错误和数据一致性缺陷

输出：

- 自定义类型注册修正
- 注册表去重机制
- 组件扫描统计与日志改进

### Phase 2：插件入口拆分

目标：

- 把 `plugin.gd` 从上帝对象改成编排器

输出：

- 启动编排模块化
- 编辑器注册与运行时注册解耦

### Phase 3：全局变量服务重构

目标：

- 统一“场景节点助手”和“运行时服务”职责

输出：

- `GlobalVariableService`
- `GlobalVariableAssistant` 包装层

### Phase 4：ExecutionContext 拆分

目标：

- 降低上下文类复杂度，收敛职责边界

输出：

- `ExecutionContext` 核心骨架
- 变量访问子系统
- 诊断/历史子系统

### Phase 5：编辑器边界收口

目标：

- 减少 Inspector 全局侵入，建立明确元数据驱动边界

输出：

- 更严格的 `_can_handle()` 逻辑
- 选择器与注册表接口稳定化

## 4. Phase 0：基线固化

### 4.1 目标

在进入整改前，把当前“可工作的行为”和“允许暂存的问题”记录下来，防止后续把原有功能误伤后还无法判断。

### 4.2 关键任务

- 整理当前已有 Fuse 测试，筛选核心回归集
- 建立以下回归维度：
  - 单事件 `Trigger`
  - 多事件 `MultiEventTrigger`
  - 指令执行：顺序 / 并行
  - 运行时实例隔离
  - 变量：local / scope / global
  - EventBus 通信
  - Inspector 组件选择器
- 记录当前已知问题白名单：
  - 注册重复导致的潜在 UI 重复项
  - `GlobalVariableAssistant` 脱树实例行为不一致
  - Inspector 全量介入

### 4.3 建议产出

- `addons/fuse/tests/README_architecture_regression.md`
- 核心测试场景索引表

### 4.4 验收标准

- 可以明确列出整改后必须保持不变的核心行为
- 每个整改阶段都有对应的最低回归清单

## 5. Phase 1：一致性与注册层修复

### 5.1 目标

先解决当前最明确、最不应该继续带着往后走的问题。

### 5.2 任务 1：修正自定义类型注册基类

问题：

- `BaseInstruction` 注册为 `RefCounted`，实际继承 `Resource`
- `BaseCondition` 注册为 `Node`，实际继承 `Resource`

> **[验证 2026-04-30] 确认问题仍存在。** 额外发现：`plugin.gd:23` 的 `ExecutionContext` 也注册为 `RefCounted`，需要一并校验其真实继承关系。

改动范围：

- `addons/fuse/plugin.gd`

实施动作：

- 对照每个 `add_custom_type()` 的真实继承类做一次全面校验（包括 `ExecutionContext`）
- 修正不一致项
- 补一个简单校验函数，开发期输出不一致警告

验收标准：

- 所有 `add_custom_type()` 的基类与真实脚本继承关系一致
- 插件启用后无类型不一致警告

回滚点：

- 仅单文件修改，可直接回滚

> **[验证 2026-04-30] 确认。** `component_registry.gd:100-101` 的 append+赋值逻辑未变，`get_all()` 返回的 Array 存在重复风险。

### 5.3 任务 2：修复 ComponentRegistry 重复注册累积

问题：

- Map 覆盖，Array 追加，导致 `get_all()` 结果可能重复

改动范围：

- `addons/fuse/editor/component_registry.gd`

实施动作：

- 将注册逻辑改成“按 identifier 更新或插入”，而非无条件追加
- 为三类组件建立稳定索引更新逻辑
- 增加 `get_all_unique()` 或直接保证 `get_all()` 唯一

验收标准：

- 相同 identifier 重复注册后，结果列表中只保留一份
- 搜索、列表和数量统计一致

回滚点：

- 保持公共 API 名称不变，只修改内部存储逻辑

### 5.4 任务 3：组件扫描流程补去重和统计

> **[验证 2026-04-30] 补充建议：** 此阶段可顺手做一项低成本高收益修复——将 `fuse_inspector_plugin.gd:17` 的 `return true` 改为基于 Fuse 类型的判断。改一行代码，即可消除 Inspector 对非 Fuse 对象的全局侵入。

问题：

- 当前扫描流程可用，但可观测性不够强

改动范围：

- `addons/fuse/plugin.gd`
- 如有必要新增 `scanner` 工具脚本

实施动作：

- 扫描前后输出：
  - 总文件数
  - 成功数
  - 失败数
  - 重复 identifier 数
- 失败原因结构化打印
- 扫描结果可选按类型汇总

验收标准：

- 插件启动日志可用于直接判断注册健康度
- 出现重复和缺元数据脚本时能快速定位

## 6. Phase 2：插件入口拆分

### 6.1 目标

把 `plugin.gd` 从“实现主体”降级为“生命周期编排器”。

### 6.2 目标结构

建议新增以下内部模块：

- `addons/fuse/editor/bootstrap/fuse_type_registrar.gd`
- `addons/fuse/editor/bootstrap/fuse_component_scanner.gd`
- `addons/fuse/editor/bootstrap/fuse_editor_bootstrap.gd`
- `addons/fuse/editor/bootstrap/fuse_runtime_bootstrap.gd`

### 6.3 职责划分

`plugin.gd` 仅负责：

- `_enter_tree()`
- `_exit_tree()`
- 调度各 bootstrap 模块

`FuseTypeRegistrar` 负责：

- 所有 `add_custom_type()` / `remove_custom_type()`

`FuseComponentScanner` 负责：

- 扫描脚本
- 提取元数据
- 注册到 Registry

`FuseEditorBootstrap` 负责：

- Inspector 插件
- 上下文菜单
- 场景切换回调
- 图标、本地化编辑器侧初始化

`FuseRuntimeBootstrap` 负责：

- EventBus Autoload
- 运行时缓存清理钩子

### 6.4 实施顺序

1. 先提取无状态工具函数
2. 再提取注册器
3. 最后压缩 `plugin.gd`

### 6.5 验收标准

- `plugin.gd` 明显缩短，主要保留生命周期编排
- 各模块可以单独阅读和测试
- 启用/停用插件的行为与当前版本保持一致

## 7. Phase 3：全局变量服务重构

### 7.1 目标

消除 `GlobalVariableAssistant` 既像服务又像场景节点的混合职责。

### 7.2 目标结构

建议引入：

- `GlobalVariableService extends RefCounted`
- `GlobalVariableAssistant extends Node`

职责定义：

- `GlobalVariableService`
  - 统一单例
  - 变量增删改查
  - 持久化加载/保存
  - 事件通知
- `GlobalVariableAssistant`
  - 场景中的可配置包装器
  - 自动加载
  - 自动保存计时器
  - 与场景生命周期关联

### 7.3 实施动作

- 把 `GlobalVariableManager` 和 `GlobalVariableAssistant` 的核心服务能力收敛到 `GlobalVariableService`
- `ExecutionContext` 只依赖 Service，不依赖场景里是否存在 Assistant 节点
- `Assistant.get_instance()` 不再 `new()` 一个脱树 Node 作为兜底服务

### 7.4 兼容策略

- 保留 `GlobalVariableAssistant.get_instance()`，但内部改为返回场景包装器或包装器所持有的 service
- 现有指令尽量不改调用签名

### 7.5 验收标准

- 没有场景节点时，全局变量服务仍可稳定工作
- 有场景节点时，自动加载/自动保存依旧可用
- 行为不再依赖 `_ready()` 是否执行

## 8. Phase 4：ExecutionContext 拆分

> **[验证 2026-04-30] 补充建议：** 当前 ExecutionContext 已增长至 **1623 行**（比评估时 +167 行）。建议此 Phase 分两步走：
> - **4a**（低风险）：提取纯函数到工具类（变量名缓存、索引优化、辅助判断逻辑），不动核心 API
> - **4b**（高风险）：拆 VariableContext / ExecutionDiagnostics 门面类，需在前一步验证稳定后再进行

### 8.1 目标

控制 `ExecutionContext` 继续膨胀，把领域能力拆到可独立演化的子模块。

### 8.2 目标结构

建议结构：

- `ExecutionContext`
  - target / trigger / owner
  - 基础日志
  - 生命周期状态
  - 对外统一门面
- `VariableContext`
  - local / scope / global 访问
  - 变量名缓存
  - 索引访问优化
- `ExecutionDiagnostics`
  - 历史记录
  - 依赖图
  - 可视化数据
  - 调试统计

### 8.3 实施动作

- 第一轮只做内部委托，不立刻改外部 API
- 保留 `ExecutionContext.set_variable()` / `get_variable()` 等门面方法
- 内部转发到 `VariableContext`
- 把历史、依赖图、快照逻辑迁移到 `ExecutionDiagnostics`

### 8.4 风险控制

- 不要在同一轮顺手改变量语义
- 不要同时重构 `Trigger` 和 `ExecutionContext`
- 保证现有指令脚本不用批量改名

### 8.5 验收标准

- `ExecutionContext` 行数显著下降
- 变量系统和诊断系统可以单独测试
- 外部指令 API 保持兼容

## 9. Phase 5：编辑器边界收口

### 9.1 目标

减少 Inspector 扩展的全局侵入性，降低与其他编辑器插件冲突的概率。

### 9.2 关键任务

#### 任务 1：收紧 `_can_handle()`

当前问题：

- 对所有对象返回 `true`

整改方式：

- 只处理以下对象：
  - Fuse 自定义资源
  - 明确包含 Fuse 组件属性的对象
  - 明确属于 Fuse 相关 Node/Resource 的对象

验收标准：

- 非 Fuse 对象不再进入 Fuse Inspector 解析路径

#### 任务 2：减少基于属性名猜测的逻辑

当前问题：

- 通过 `name == "instructions"`、`ends_with("_condition")` 等约定推断

整改方式：

- 优先依赖资源类型和元数据
- 对确需兼容的历史字段名保留兜底分支

验收标准：

- 新增 Fuse 组件属性时，不需要继续堆更多名称猜测规则

#### 任务 3：选择器、注册表、元数据接口稳定化

整改方式：

- 明确 `InstructionMetadata` / Event / Condition 元数据最小契约
- 让 UI 层只消费 Registry 的稳定输出结构

验收标准：

- 选择器 UI 不直接依赖脚本扫描细节

## 10. 测试与验收策略

每个阶段都应至少做三类验证：

- 功能回归
- 结构验证
- 兼容性验证

建议最小回归集：

- `Trigger` 监听事件并触发 `ActionRunner`
- `MultiEventTrigger` 的多绑定与条件检查
- `RuntimeEventInstance` 隔离共享 Event 资源状态
- `RuntimeActionRunnerInstance` 顺序/并行执行
- `ExecutionContext` 的 local/scope/global 变量访问
- EventBus 发送与订阅
- Inspector 中事件/条件/指令选择器正常显示

## 11. 推荐执行顺序

建议按以下顺序推进：

1. Phase 0：基线固化
2. Phase 1：一致性与注册层修复
3. Phase 2：插件入口拆分
4. Phase 3：全局变量服务重构
5. Phase 5：编辑器边界收口
6. Phase 4：ExecutionContext 拆分

说明：

- `ExecutionContext` 拆分风险最高，应放在后段
- 编辑器边界收口可以早做，但不应阻塞运行时治理
- Phase 1 完成前，不建议继续扩展组件扫描或注册能力

## 12. 里程碑定义

### 里程碑 M1：注册层稳定

达成条件：

- 类型注册一致
- Registry 不重复
- 扫描结果可观测

### 里程碑 M2：插件入口可维护

达成条件：

- `plugin.gd` 主要只做编排
- 注册、扫描、编辑器引导、运行时引导已拆开

### 里程碑 M3：全局变量服务统一

达成条件：

- 不再依赖脱树 Node 兜底
- 全局变量行为在有无 Assistant 节点时一致

### 里程碑 M4：上下文结构收口

达成条件：

- `ExecutionContext` 变成门面类
- 变量和诊断能力独立

## 13. 验证记录（2026-04-30）

基于当前代码状态对整改计划的复核：

### 计划质量评价

- **Phase 顺序**：认同 1 → 2 → 3 → 5 → 4。Phase 4 风险最高放最后是正确的。
- **验收标准**：每个 Phase 的验收标准具体可测，无异议。
- **兼容策略**：Phase 3 保留 `get_instance()` 的兼容策略合理。

### 补充建议已标注位置

| 位置 | 补充内容 |
|------|----------|
| Phase 1 任务 1 | 增加 `ExecutionContext` 注册类型校验 |
| Phase 1 任务 3 | 顺手修 `_can_handle()` 一行改动 |
| Phase 4 | 分两步（4a 提取纯函数 + 4b 拆门面），降低风险 |
| Phase 5 | 建议的一行修复已提前至 Phase 1，Phase 5 专注于选择器/注册表接口 |

### 未覆盖项

- `BaseInstruction` 的 `static var metadata` 混合模式（评估 5.7）在当前计划中没有明确对应的 Phase。建议在 Phase 2 拆分 plugin.gd 时顺带规范化，或在 Phase 4 处理 ExecutionContext 时一并收敛元数据边界。

---

## 14. 暂不建议本轮处理的事项

以下内容建议暂缓，不放入本轮主整改路径：

- 全量重写静态分析器为真正语义分析器
- 全量替换所有 Fuse 元数据模型
- 对 100+ 指令做风格统一重构
- 一次性重做所有 Editor UI

原因：

- 这些事项收益较慢
- 改动面过大
- 容易与主链治理互相干扰

## 15. 结论

Fuse 当前最需要的不是再扩一轮功能，而是把关键边界收住：

- 注册层要稳定
- 插件入口要解耦
- 全局变量服务要统一
- `ExecutionContext` 要控复杂度
- 编辑器扩展要缩边界

如果按本计划推进，Fuse 可以在不推翻现有系统的情况下，从“可用但累积风险明显”进入“可维护、可演进”的状态。

