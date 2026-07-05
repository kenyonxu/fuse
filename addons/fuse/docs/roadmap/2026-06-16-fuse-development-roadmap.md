# Fuse 推进路线图

**创建日期:** 2026-06-16
**基线:** 架构整改全链闭环(Phase 0-4),本地化迁移至 TranslationDomain
**关联:** [组件缺口分析](2026-03-20-component-gap-analysis.md)、[特性路线图](20206-03-20-future-features-roadmap.md)

---

## 整改后基线

| 指标 | 值 |
|------|-----|
| 指令 | 129 |
| 事件 | 65 |
| 条件 | 43 |
| plugin.gd | 130 行(编排器) |
| ExecutionContext | 770 行(三层门面) |
| 组件注册 | 扫描自动注册,upsert 去重,重复统计 |
| 全局变量 | Service(RefCounted) + Assistant(Node) 双层,无脱树兜底 |
| 本地化 | Godot TranslationDomain,3797 条目 |

**整改后能力:** 加一个新指令只需在 `instructions/` 放 `.gd` 文件 → 插件重载 → 自动注册。组件开发摩擦降至最低。

---

## 推进总览

```
Stage 1 ──→ Stage 2 ──→ Stage 3 ──→ Stage 4 ──→ Stage 5 ──→ Stage 6 ──→ Stage 6.5 ──→ Stage 7 ──→ Stage 8
P0组件(14)  工具链基础   P1组件(23)   P2组件(17)   数据流      多层级Preset 组件自描述   变量监视器   高级调试
3-5天       4-6天        5-8天        3-4天        可视化      3-4天        +分析器修复  V2+静态声明  录播+GraphEdit
                                        5-7天                    2天          2-3天         3-5天
```

## Stage 1: 组件扩展验证(P0 组件)

**目标:** 验证整改后架构的组件开发吞吐量,建立标准化组件开发工作流。

**输入:** 架构基线(组件注册/变量服务/EC 门面稳定)

| 分类 | 类型 | 组件 | 工时 |
|------|------|------|:--:|
| 物理 | 指令 | `SetGravityScale` | 0.5h |
| 物理 | 指令 | `EnableDisableCollision` | 0.5h |
| 物理 | 指令 | `SetCollisionMask` | 0.5h |
| 物理 | 条件 | `CheckOverlapArea` | 0.5h |
| 动画 | 指令 | `SetAnimationTreeParameter` | 1h |
| 动画 | 指令 | `SetSpriteFlip` | 0.5h |
| 变量 | 指令 | `AddVariable` | 0.5h |
| 变量 | 指令 | `ToggleVariable` | 0.5h |
| UI | 指令 | `SetUIColor` | 0.5h |
| 渲染 | 指令 | `SetMaterialProperty` | 1h |
| 渲染 | 条件 | `CheckIsOnScreen` | 0.5h |
| 导航 | 指令 | `NavigateToPosition` | 1.5h |
| 输入 | 事件 | `OnInputBuffered` | 1h |
| 通用 | 指令 | `SetProcessMode` | 0.5h |
| 通用 | 指令 | `MouseWorldPosition` | 0.5h |

**产出:**
- 14 个新组件(含 `_get_*_metadata()` + `execute()`/`check()` + 本地化条目)
- 组件开发模板(从第一批组件提炼通用模式)
- `instructions/physics/`、`instructions/rendering/`、`instructions/navigation/` 新目录

**验证点:**
- 新目录是否被 ComponentScanner 自动扫描到 ✓(已知:扫描 `instructions/` 递归子目录)
- 组件元数据是否被 Inspector 选择器正确展示 ✓(ComponentRegistry 去重)
- `AddVariable`/`ToggleVariable` 是否直接委托 `GlobalVariableService` ✓(Phase 3)
- 翻译条目能否快速追加(CSV 补行 → 重新导入 `.translation`)✓

**里程碑:** 逻辑流视图可选中Trigger渲染数据流卡片;全场景拓扑可视化;多层级Preset(L1-L4)支持导出导入;变量监视器支持运行时编辑+折线图。

---

## Stage 2: 工具链基础设施 ✅ 已完成（2026-06-17）

**目标:** 建立预设系统和多选操作,让组件有"模板复用"能力。

**依赖:** Stage 1 完成(需要足够的组件池作为预设素材)

| # | 特性 | 复杂度 | 工时 | 产出 |
|---|------|:---:|:--:|------|
| 2a | InstructionListEditor 多选改造 | 低 | 1-2天 | 指令列表支持 Shift/Ctrl 多选 → 批量删除/复制/移动 |
| 2b | 预设系统 V1 | 中 | 2-3天 | Logic Template(tres)保存/应用;Inspector 一键导出/导入 ActionRunner |
| 2c | 变量监视器 V1 | 中 | 1-2天 | 运行时 Dock:三层作用域(local/scope/global)变量名+值+类型实时显示 |

**依赖关系:**
```
2a(多选改造) ──→ 2b(预设系统) ──→ Stage 4(Snippet)
2b(预设系统) ──→ Stage 3(变量监视器复用变量组件调试)
```


**实际产出:**
- 2a 多选改造 → 改为极简方案:Inspector 上方 3 个按钮(添加指令/导出为预设/导入预设)+ 原生数组编辑器处理内联展开
- 2b 预设系统 → FusePreset Resource + JSON 双格式,FileDialog 自选保存路径,导入记目录
- 2c 变量监视器 → Bottom Dock 显示全局变量(始终),Runner 编辑模式扫描(场景运行后 local/scope 可见)

**里程碑:** 逻辑流视图可选中Trigger渲染数据流卡片;全场景拓扑可视化;多层级Preset(L1-L4)支持导出导入;变量监视器支持运行时编辑+折线图。

---

## Stage 3: 组件批量填充 ✅ 已完成（2026-06-18）(P1 组件)

**目标:** 利用 Stage 1 打磨的流程批量产出,同时组件池丰富后反哺预设系统素材。

**输入:** Stage 1 组件开发工作流 + Stage 2 预设系统(让新组件可被复用)

| 分类 | 数量 | 组件 |
|------|:--:|------|
| 物理 | 3 | `GroundSnap`, `CheckSlope`, `OnGroundStateChanged` |
| 动画 | 1 | `CheckAnimationTreeParameter` |
| Tween | 2 | `TweenPause`/`TweenResume` |
| 相机 | 2 | `CameraFadeIn`/`CameraFadeOut` |
| UI | 4 | `AddRemoveUIChild`, `OnUIMouseEntered`/`Exited`, `CheckUIVisible` |
| 字符串 | 1 | `StringFormat` |
| 渲染 | 2 | `SetLight`, `ControlParticles` |
| 导航 | 2 | `OnNavigationTargetReached`, `CheckPathAvailable` |
| 输入 | 2 | `CheckInputMagnitude`, `OnDirectionalInputChanged` |
| 通用 | 3 | `EmitSignal`, `GetViewportSize`, `CloneNode` |
| 变量 | 1 | `SwapVariables` |

**产出:** 23 个新组件

**里程碑:** 逻辑流视图可选中Trigger渲染数据流卡片;全场景拓扑可视化;多层级Preset(L1-L4)支持导出导入;变量监视器支持运行时编辑+折线图。

---

## Stage 4: 组件补全 ✅ 已完成（2026-06-18）(P2 组件)

**目标:** 完成最后 17 个组件,组件总数达到 183。

| 分类 | 数量 | 组件 |
|------|:--:|------|
| 物理 | 1 | `SetGravityDirection` |
| 动画 | 2 | `SetAnimationBlendPosition`, `SetSpriteFrame` |
| 字符串 | 6 | `StringSplit`/`Join`/`Contains`/`Replace`/`Length` + `CheckString*`×2 |
| 渲染 | 2 | `SetZIndex`, `ScreenFlash` |
| 输入 | 2 | `OnInputCombo`, `CheckInputDirection` |
| 通用 | 4 | `LoadResourceByPath`, `SetGlobalPosition`, `CheckPlatform`, `CheckFrameRate` |

**产出:** 17 个新组件

**里程碑:** 逻辑流视图可选中Trigger渲染数据流卡片;全场景拓扑可视化;多层级Preset(L1-L4)支持导出导入;变量监视器支持运行时编辑+折线图。

---


## Stage 5: 数据流可视化 ✅ 已完成（2026-06-19）

**目标:** 逻辑流引擎 + 单 Trigger 数据流卡片 + 全场景拓扑。

| # | 特性 | 复杂度 | 工时 | 依赖 |
|---|------|:---:|:--:|------|
| 5a | 逻辑流引擎 + Inspector 卡片 | 高 | 3-4天 | — |
| 5b | 全场景拓扑(主屏幕 Tab) | 高 | 2-3天 | 5a 解析引擎 |

**里程碑:** 选中 Trigger 在 Inspector 底部显示数据流卡片(节点/变量/信号);底部 Tab 显示全场景 Trigger 拓扑树。

---

## Stage 6: 多层级 Preset(L1-L4) ✅ 已完成（2026-06-19）

**目标:** Preset 从 ActionRunner(L1)扩展到 Trigger(L2)/Runner(L3)/MultiEventTrigger(L4)。

| # | 特性 | 复杂度 | 工时 | 依赖 |
|---|------|:---:|:--:|------|
| 6a | FusePreset 扩展(level 字段 + L2-L4 结构) | 中 | 1-2天 | Stage 2 Preset V1 |
| 6b | 多层级导出(自动检测节点类型) | 中 | 1天 | 6a |
| 6c | 多层级导入(创建对应节点) | 中 | 1天 | 6a |

**里程碑:** 选中 Trigger/Runner/MultiEventTrigger 可导出为 JSON;导入时自动创建对应节点结构。

**实际产出:**
- FusePreset 新增 `level`/`event_json`/`trigger_config`/`signal_binding`/`event_bindings_json` 字段
- `FusePresetSerializer` 支持 L1-L4 序列化,`FusePresetDeserializer` 支持反序列化 + 导入后校验
- Inspector 导出按钮(Trigger/触发器, Runner/信号适配器, MultiEventTrigger/多重事件触发器)
- 预设面板显示 level 标签,目标文件夹浏览器替代 category 文本框
- 导入支持应用到当前节点(同类型替换配置) + 层级不匹配守护
- 导出前最小校验,属性填充顺序,PresetExportDialog API 兼容

---

## Stage 6.5: 分析器修复（反射 + 命名启发式） ✅ 已完成（2026-06-27）

**目标:** 修复 InstructionAnalyzer 变量提取失效 bug,为 Stage 7/8 提供准确的拓扑/变量分析基础。

**关联:** [可行性报告](2026-06-26-gdscript-ast-flow-integration-feasibility.md) · [执行计划](2026-06-26-stage6.5-implementation-plan.md)

**背景:** 审计发现 InstructionAnalyzer 硬编码 `variable_name`,但实际 24 个变量组件全用 `target_variable`(0 匹配),变量提取 100% 失效。

**方案转向:** 原计划方案 Y（codegen @export AST 扫描生成组件自描述）。执行中发现 95% 组件用 `_get_property_list` 动态属性（非 @export var），codegen AST 路径覆盖不足（26%）。**转向方案 B：InstructionAnalyzer 改运行时反射 `get_property_list` + 命名启发式**（`*_variable`→变量、`*_node`→节点），覆盖动态属性,不需 codegen/改组件。

**实际产出:**
- 6.5a BaseInstruction 加 3 个自描述虚方法（默认空，Phase C/D 备用；方案 B 下未实际使用）
- 6.5b codegen 脚本探索后**废弃**（动态属性不适用），[fuse_self_describe_codegen.gd](../../tools/codegen/fuse_self_describe_codegen.gd) 保留作参考
- 6.5c InstructionAnalyzer 改反射+命名启发式：删硬编码 `_VARIABLE_PROP`/`_SCOPE_PROP`/`_NODE_PATH_PATTERNS`，`_extract_variables`/`_extract_nodepaths` 改反射 + `*_variable`/`*_node` 命名启发式
- 副产品：修 gdscript_ast 3 处语法 bug（限定类型/dict 等号/static var），记录在 gdscript-ast-flow 仓库 docs

**验证:**
- [test_stage65_extract.gd](../../tests/test_stage65_extract.gd) 通过（变量 bug 修复 + 动态 NodePath 覆盖）
- 编辑器实机验收：Topology 面板变量/操作节点正确显示
- 顺带：Topology 节点路径可读化（`../..` → `[2层上级]`）

**里程碑:** ✅ Topology 变量数据真实可信；动态属性组件 NodePath 覆盖；零 SCRIPT ERROR。

---

## Stage 7: 变量监视器 V2 + 静态声明融合 ✅ 已完成（2026-06-29）

**目标:** V1 升级 — 运行时编辑变量值 + 历史折线图 + 注入组件自描述的静态变量声明。

**依赖:** Stage 6.5(组件自描述,提供静态变量声明数据源)

| # | 特性 | 复杂度 | 工时 | 依赖 |
|---|------|:---:|:--:|------|
| 7a | 双击编辑变量值 + LineEdit | 低 | 0.5天 | Stage 2c V1 |
| 7b | 历史折线图(60s 快照) | 中 | 1天 | 7a |
| 7c | 静态变量声明注入 | 低 | 0.5天 | Stage 6.5 |
| 7d | get_snapshot() 补全 | 低 | 0.5天 | Stage 6.5 |

**里程碑:** 双击可修改变量值;数值变量显示最近 60s 折线图;变量列表显示组件自描述的静态声明(即使变量未运行);快照接口含 local/scope/runner 完整数据(为 Stage 8 录播铺路)。

**Event/Condition 节点/变量提取 ✅ 完成（2026-06-29）:** 「待评估」项已评估并完成。扩展 InstructionAnalyzer 三处：condition 深入（if/while 的 BaseCondition 调 `_extract_*`）+ event 提取（`analyze_trigger` 对 event_definition 调 `_extract_*`）+ `_is_variable_prop` 精确列表（`variable_name`/`compare_variable`/`source_variable`/`*_variable_name`）。测试 5/5 ✓ + 编辑器实机验收 ✓。详见 [spec](2026-06-28-event-condition-extraction-spec.md) + [plan](2026-06-28-event-condition-extraction-plan.md)。

**运行时变量访问（TCP 桥）✅ 完成（2026-06-27）:** Stage 7 验收发现 local/scope 运行时不可见（V1 既有限制，编辑器 Dock 看不到运行游戏实例变量）。调研确认 Godot 远程调试 API 不暴露 GDScript（[调研](2026-06-27-runtime-variable-access-research.md)），改用 TCP 桥（纯 GDScript）：运行游戏每 0.5s 推送变量快照，编辑器接收显示。调试中踩了 4 个 Godot StreamPeerTCP 主线程阻塞陷阱（[修复经验](../development/godot-streampeertcp-mainthread-pitfalls.md)），最终卡源是 `get_utf8_string(-1)`。详见 [TCP 桥 plan](2026-06-27-runtime-variable-tcp-bridge-plan.md)。

---

## Stage 8: 预设 NodePath 重映射 + Topology 可视化强化 ✅ 已完成（2026-07-04）

**目标:** 预设系统跨场景复用（NodePath 重映射）+ Topology 可视化强化。

**背景:** Pre-mortem #3 早就标记 NodePath 重映射为预设系统核心缺失。录播（原 8a）经 thinking-model-router 评估后**暂缓**（现有 print + 折线图 + TCP 桥 local/scope 够日常调试；Type 2 不可逆 + 中高复杂度，等用户需求验证再投入）。

**方案转向（8b GraphEdit → Tree 强化）:** 原计划用 GraphEdit 节点-连线图替代 Tree。实施后用户反馈「连线图不如左侧树状看得清楚」，经评估改为**强化 Tree + 右侧详情面板**，GraphEdit 降级保留不默认显示。

**实际产出:**
- 8a NodePath 重映射：NodePathResolver（提取+自动匹配）+ NodePathMappingDialog（映射 UI）+ FusePresetDeserializer 集成
- 8b-0 InstructionAnalyzer 树结构增强：`instructions_tree`（明确 parent + branch label then/else/loop）
- 8b Topology Tree 强化：
  - 指令可选 + builtin icon（EditorIcons）+ emoji 回退
  - if/else 分支标记（✓then 绿 / ✗else 红 / ↻loop 蓝）
  - 嵌套场景分组（`owner != scene_root` 检测，📦 蓝色标题）
  - MultiEventTrigger event_bindings 展开（每个 binding 子项 + 指令链）
  - 选中指令 → 右侧详情（参数表 + 节点/变量引用 + 上下文）
  - 选中 EventBinding → 右侧 binding 详情
  - GraphEdit 代码保留但不默认显示
- 修复：`_SUB_INSTRUCTIONS` 缺 `true_instructions`/`false_instructions`（IfElse 分支不渲染）
- 修复：`trigger_type` 用 `script.get_global_name()` 替代 `get_class()`
- 修复：3 个缺失翻译 key（IF_ELSE_MODE_ASYNC/SYNC + TEXT_UNLIMITED）
- 修复：trigger_path 用场景根相对路径

**关联:** [spec](2026-06-29-stage8-spec.md) · [plan](2026-06-29-stage8-plan.md) · [Topology 强化 spec](2026-07-04-topology-tree-enhance-spec.md) · [Topology 强化 plan](2026-07-04-topology-tree-enhance-plan.md)

**里程碑:** ✅ 预设 NodePath 重映射；Topology Tree 强化（图标+分支+嵌套场景+MultiEventTrigger+指令详情）。

---

## Stage 9: Instruction/Event/Condition 图标补全 ✅ 已完成（2026-06-29）

**目标:** 为所有组件（174 指令 + 69 事件 + 55 条件）补全 Inspector/选择器图标，统一视觉一致性。

**背景:** 部分组件有 builtin_icon（如 "int"/"float"），但 42/153 个图标名在 `icons/builtin/` 目录下无对应文件。另外 22 个 EditorTheme 提取的 PNG 图标图案相同（坏图标），需替换。

**实际产出:**

| # | 特性 | 详情 |
|---|------|------|
| 9a | 审计 | 发现 42 个缺失文件、6 个语义错误、静态 var 共享 bug |
| 9b | at-icons 集成 | 从 `addons/at-icons` 选取 44 个 SVG，按颜色规则：control(绿)→条件，node2d(蓝)→指令，node3d(红)→事件 |
| 9c | @icon 装饰器修正 | ~90 处扩展名/路径修正，4 处条件 condition.svg→专属图标 |
| 9d | 语义修正 | 6 个指令图标替换（Hash→Groups/Children、Signal→Array/Dictionary、Loop→Swap、HashArray→Dice） |
| 9e | API 对齐 | BaseCondition.get_icon()/BaseEvent.get_event_icon() 改为读 metadata.builtin_icon；FuseIconManager 优先级改为本地文件>EditorTheme；修复 static var 共享 bug |
| 9f | 死文件清理 | 删除 22 个未使用的坏 PNG |

**核心修复 — static var 共享 bug:**
- `BaseInstruction.metadata` 是 `static var`，被所有指令实例共享，最后一个 `_get_instruction_metadata()` 调用会覆盖前面的
- 组件选择器（直接调 script 静态方法）正常，但指令列表（读 `instruction.metadata`）显示错误图标
- 修复: `get_icon()` 改为 `get_script()._get_instruction_metadata()`；`instructions_array_property.gd` 改为调用 `get_icon()`

**里程碑:** 156 图标文件（45 SVG + 111 PNG），296 组件全部 `@icon` ↔ `builtin_icon` 一致，选择器和 Inspector 显示统一图标。详见 [实施记录](2026-06-29-stage9-implementation.md)。

---

## Stage 10: 文档与发布准备 ⬜

**目标:** 完善用户文档 + 发布准备（仓库拆分 + 上手指南）。

**背景:** Fuse 有 183 组件 + 完整功能（预设/拓扑/变量监视器/TCP 桥/GraphEdit），但缺新用户上手指南。commit bd3f183 已设计仓库拆分（juicy-mixer/fuse 独立发布）。

| # | 特性 | 复杂度 | 工时 | 产出 |
|---|------|:---:|:--:|------|
| 10a | 快速上手指南（5 分钟入门） | 中 | 1天 | 新用户文档 |
| 10b | 组件分类指南（183 组件怎么选） | 中 | 1天 | 分类导航 |
| 10c | 仓库拆分执行（fuse 独立发布） | 中 | 1-2天 | 独立 repo |
| 10d | README + screenshots + demo | 低 | 0.5天 | 发布门面 |

**里程碑:** 新用户 5 分钟上手；Fuse 可独立发布。
## 总览

| Stage | 核心 | 工时 | 累计组件 | 状态 |
|:-----:|------|:--:|:---:|:--:|
| 1 | P0 组件 | 3-5 天 | 143 | ✅ 已完成 |
| 2 | 预设 + 多选 + 变量监视器 | 4-6 天 | 143 | ✅ 已完成 |
| 3 | P1 组件 | 5-8 天 | 166 | ✅ 已完成 |
| 4 | P2 组件 | 3-4 天 | 183 | ✅ 已完成 |
| 5 | 数据流可视化 | 5-7 天 | 183 | ✅ 已完成 |
| 6 | 多层级 Preset | 3-4 天 | 183 | ✅ 已完成（2026-06-19） |
| 6.5 | 分析器修复（反射+命名启发式） | 2 天 | 183 | ✅ 已完成（2026-06-27） |
| 7 | 变量监视器 V2 + 静态声明 | 2-3 天 | 183 | ✅ 已完成（2026-06-29） |
| 8 | NodePath 重映射 + Topology 强化 | 3-5 天 | 183 | ✅ 已完成（2026-07-04） |
| 9 | 图标补全 | 2-3 天 | 183 | ✅ 已完成（2026-06-29） |
| 10 | 文档与发布 | 3-4 天 | 183 | ⬜ 下一阶段 |

**总工时估算:** Stage 1-9 已完成。剩余 Stage 10 约 3-4 天。

## 风险与注意事项

### 已有风险

| 风险 | 缓解 |
|------|------|
| 逻辑流视图 V1 复杂度高(编辑器 UI 新 Tab) | 先做最小原型:仅渲染单个 Trigger 的指令链,不做编辑/拖拽 |
| 导航组件(`NavigateToPosition`)首次引入 NavigationAgent 依赖 | Stage 1 早期验证,若 API 稳定再批量铺 Stage 3 的导航组件 |
| 本地化条目随组件增长(54 条新 key) | TranslationDomain 迁移后加条目只需补 CSV + 重导入,成本极低 |
| 组件质量一致性(54 个独立脚本) | Stage 1 建立模板 + checklist,后续 Stage 按模板批量生产 |

### mental-model 审视补充(Pre-mortem + Systems Thinking + Second-Order)

**1. ~~Stage 1 工时重校准~~ ✅ 已过时**

> 已过时(2026-06-26): Stage 1 已完成,本条为启动前预警的历史记录。

`CheckOverlapArea`(Area2D 重叠回调)、`OnInputBuffered`(输入缓冲区)的实际复杂度可能超 0.5-1h 估算。**建议 Stage 1 的前 3 个组件做完全流程(代码+测试+翻译+编辑器验证)后,用实际耗时重新校准剩余 11 个的估算**。若平均工时从 0.5h 升至 1h,Stage 1 总工时从 3-5 天变为 5-7 天,需如实反映到后续 Stage 排期。

**2. ~~Stage 0.5 组件模板~~ ✅ 已过时**

> 已过时(2026-06-26): Stage 1-4 已完成,组件模板预警不再适用(实际采用了 skill 驱动的组件生成流程)。

14 个 P0 组件之前,先花 0.5-1 天做一个**标准化组件模板**(含 `_get_*_metadata()` 完整字段、`execute()`/`check()` 骨架、翻译条目占位、测试场景骨架)。用这个模板指导后续 53 个组件,而不是"从第一批组件事后提炼"。模板进 `addons/fuse/docs/templates/component_template.gd`。

**3. ~~预设系统必须设计 NodePath 重映射策略~~ 已纳入 Stage 8**

> 已纳入(2026-06-29): NodePath 重映射纳入 Stage 8a，录播暂缓（thinking-model-router 评估）。

`ActionRunner` 中的指令常常引用 `target_node = NodePath("..")` —— 这是相对于原始 Trigger 节点的路径。当预设应用到新场景时,NodePath 必定断裂。**V1 至少需支持两种策略:**(a) 保持原路径,用户手动修复;(b) 基于节点名模糊匹配。**若不做重映射设计,预设系统会成为"只能在同一场景复用"的半成品。**

**4. 变量监视器需预留快照序列化接口**

> 已被覆盖(2026-06-26): Stage 7d 将补全 `get_snapshot()` 的 local/scope/runner 完整数据(接口已预留于 [variable_watcher.gd:234](../../editor/debugging/variable_watcher.gd#L234),仅缺填充),见 [Stage 6.5 执行计划](2026-06-26-stage6.5-implementation-plan.md)。

录播(Stage 5a)需要重放执行时的变量状态,这要求 Stage 2c 的变量监视器不仅做 UI 显示,还要**设计变量快照的序列化格式**(JSON 或 Dictionary),并暴露 `get_snapshot()` API。如果 Stage 2c 只做实时 UI,Stage 5a 启动时需要额外 1-2 天补序列化层。

**5. ~~逻辑流视图 V1 scope 锁定~~ ✅ 已过时**

> 已过时(2026-06-26): Stage 5 已完成,V1 按锁定 scope 交付(平铺指令列表)。逻辑流 V2(GraphEdit)纳入 Stage 8。

仅渲染**平铺指令列表**(不展开嵌套 if/else/for),不做条件分支可视化,不做编辑/拖拽,不做全场景。明确写进 V1 验收标准——"用户看到逻辑链"是 V1 目标,"用户想编辑逻辑链"是 V2 的事。**不锁 scope,V1 3-4 天膨胀为 2 周。**

**6. Snippet 与预设系统的边界定义**

两者都提供"保存+复用指令序列",区别必须明确:**预设 = 完整 ActionRunner(tres 资源,Inspector 导入/导出);Snippet = 部分指令片段(剪贴板级,多选后 Ctrl+C/V 粘贴)。**若边界模糊,用户不知道该用哪个,两个系统都难用。

**7. Stage 3-4 触发选择器性能瓶颈**

指令从 129→183(增长 42%)。`InstructionSelector` 当前搜索是线性遍历。建议在 Stage 2 预设系统开发时顺带评估选择器搜索性能,必要时加**分类折叠 + 最近使用(MRU)缓存 + 模糊搜索索引**。若到 Stage 4 才发现搜索卡顿,改动成本更高。

**8. ~~事件总线提案需重新评审~~ 已实现 — 基于现有实现评估,而非旧提案**

> 更正(2026-06-26): 原 pre-mortem 假设事件总线仍是待评审提案,实际它早已是完成功能。

事件总线现状(均已完成上线):
- [FuseEventBus](../../core/fuse_event_bus.gd) — Autoload 全局单例(215 行),send_event / 订阅 / 历史记录 / 调试信号
- [SendEvent](../../instructions/event/send_event.gd) 指令 + [OnReceiveEvent](../../events/event/on_receive_event.gd) 事件
- [test_event_bus.gd](../../tests/test_event_bus.gd) 测试覆盖
- 经 [fuse_runtime_bootstrap.gd](../../editor/bootstrap/fuse_runtime_bootstrap.gd) 注册为 Autoload

**后续 Stage 涉及跨 Trigger 通信时,基于上述现有实现评估扩展能力,不要再引用旧提案。** 旧提案已归档至 `proposals/implemented/2026-02-27-event-bus-system-design.md`(2026-06-26)。

## 与旧文档的关系

| 旧文档 | 新 roadmap 对应 |
|--------|----------------|
| `component-gap-analysis.md` | Stage 1(P0)/3(P1)/4(P2) |
| `future-features-roadmap.md` | Stage 2(预设/多选/变量监视器)/4(逻辑流/Snippet)/5(录播/事件总线) |
| 整改 Phase 文档 | Stage 0 基线(已完成) |

## 可用资源（Claude Code 技能）

本仓库提供 5 个 Fuse 专用 Claude Code 技能，位于 `.claude/skills/`，可直接加载使用：

| 技能 | 路径 | 用途 |
|------|------|------|
| **fuse-instruction-generator** | `.claude/skills/fuse-instruction-generator/` | 快速生成新的 Fuse 指令代码、元数据和翻译条目 |
| **fuse-event-generator** | `.claude/skills/fuse-event-generator/` | 快速生成新的 Fuse 事件代码、元数据和翻译条目 |
| **fuse-condition-generator** | `.claude/skills/fuse-condition-generator/` | 快速生成新的 Fuse 条件代码、元数据和翻译条目 |
| **fuse-localization-fixer** | `.claude/skills/fuse-localization-fixer/` | 批量修复 Fuse 组件的本地化条目，同步翻译键和 CSV |
| **fuse_event_runtime_instance_migration** | `.claude/skills/fuse_event_runtime_instance_migration/` | 将 Event 迁移至 RuntimeEventInstance 模式，含完整迁移指南 |

使用方式：在 Claude Code 会话中通过 Skill 工具加载对应技能。用于 Stage 1-4 的组件批量生产、Stage 0 的本地化维护、以及架构迁移工作。
