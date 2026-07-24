# Fuse 知乎预热文章清单

> 基于 `addons/fuse/docs/user_docs/` 全量用户文档（quick_start、FEATURES、00-56 共 47 篇指南）梳理。
> 共 15 篇，从"Fuse 是什么"递进到"工程化与性能"，覆盖全部核心能力。
> 每篇标注：标题建议、目标读者、重点能力、引用文档。

**引用文档根路径**：`addons/fuse/docs/user_docs/`
- 概览类：`quick_start.md`、`FEATURES.md`
- 指南类：`guides/00-index.md`（导航索引）、`guides/NN-*.md`

---

## 整体节奏

| 阶段 | 篇目 | 目的 |
|------|------|------|
| **总览** | 1 | 让读者知道 Fuse 是什么、能做什么 |
| **入门** | 2–4 | 触发器、变量、表达式，掌握基本搭建能力 |
| **专项** | 5–12 | 分系统深入：逻辑、动画、角色操控、交互、事件、条件、场景、扩展 |
| **进阶** | 13–15 | 调试、编辑器集成、工程化与性能，体现差异化护城河 |

**覆盖原则**：133 指令 / 62 事件 / 49 条件 / 35 编辑器工具的能力在 15 篇内全覆盖；每篇都有对应的用户文档作为素材底座，避免凭空发挥。

---

## 第 1 篇 · 总览概要（开篇必读）

**标题建议**：《Fuse：让 Godot 策划和美术也能搭逻辑的可视化编程插件（附能力全图）》

**目标读者**：所有 Godot 开发者、独立游戏团队、想参与逻辑搭建的策划 / 美术、GameJam 选手。

**重点能力**：
- Fuse 是什么：Godot 4 可视化编程插件，"什么时候做 / 做什么 / 满足什么条件才做"三句话讲清。
- 三大砖块：Event（62）、Instruction（133）、Condition（49），共 17/14/14 个分类。
- 三种触发器一句话定位：Runner / Trigger / MultiEventTrigger。
- 规模数据与编辑器集成（35 个工具、Fuse Topology 主屏、Inspector 数据流卡片）。
- 适用场景：游戏逻辑、UI 交互、关卡事件、状态管理、音效特效。
- 给出一张"能力地图"，预告后续 14 篇会逐块拆解。

**引用文档**：`quick_start.md`、`FEATURES.md`、`guides/00-index.md`、`guides/00-editor-panels-overview.md`

---

## 第 2 篇 · 5 分钟上手 + 触发器三件套

**标题建议**：《5 分钟搭出第一个游戏逻辑：Runner / Trigger / MultiEventTrigger 到底怎么选》

**目标读者**：刚装好 Fuse、想跑通第一个案例的开发者。

**重点能力**：
- 从零搭一条"按钮点击 → 执行指令"的逻辑（Runner 方式）。
- 三件套选型决策：简单信号绑定用 Runner、需要事件过滤/冷却/只触发一次用 Trigger、同节点多事件用 MultiEventTrigger。
- Runner 的代码调用方式（`runner.run()` + `await runner.wait_completed()`）。
- Trigger 的 `trigger_once` / `cooldown` 防重复触发。
- MultiEventTrigger 的右键"合并/拆分"工作流、独立冷却与动态启用/禁用。

**引用文档**：`quick_start.md`、`guides/02-trigger-selection-guide.md`、`guides/03-runner-guide.md`、`guides/04-multi-event-trigger-guide.md`

---

## 第 3 篇 · 三层变量系统

**标题建议**：《别让全局变量满天飞：Fuse 的 LOCAL / SCOPE / GLOBAL 三层变量怎么管》

**目标读者**：开始写实际逻辑、关心数据组织和作用域的开发者。

**重点能力**：
- 三层作用域：LOCAL（执行上下文内）、SCOPE（子树作用域容器，支持最近/自定义 ID/Trigger/目标节点来源）、GLOBAL（全局单例）。
- 作用域链继承（父容器 READ_ONLY / READ_WRITE，子树可继承读取）。
- 作用域选择指南：单次计算用 LOCAL、UI 数据共享用 SCOPE、跨场景/持久化用 GLOBAL。
- GLOBAL 持久化：`SaveGlobalVariables` / `LoadGlobalVariables`，多存档槽位、自动触发 `OnVariableChanged` 信号。

**引用文档**：`guides/01-variable_system_guide.md`、`guides/54-global-variables-guide.md`

---

## 第 4 篇 · 表达式系统（动态计算不用写代码）

**标题建议**：《不写一行代码算伤害公式：Fuse 表达式系统实战》

**目标读者**：需要动态计算伤害 / 文本格式化 / 复杂判断的开发者。

**重点能力**：
- 三件套：`MathExpression`（数学，输出 Float/Int/Vector2/3）、`StringExpression`（字符串）、`ExpressionCondition`（布尔条件）。
- 统一变量引用语法 `{local:hp}` `{scope:name}` `{global:max}`，三种作用域一套写法。
- 实战例子：伤害计算（攻击-防御）、HP 归一化映射、伤害飘字拼接、进度条文本、数字补零、分级显示（三元运算）。
- 可用函数库（数学/向量/字符串格式化）、未找到变量在数学上下文安全降级为 0。

**引用文档**：`guides/05-expression-guide.md`

---

## 第 5 篇 · 流程控制 + 数据结构（写出"程序化"逻辑）

**标题建议**：《If、循环、数组、字典：在可视化系统里搭出复杂逻辑》

**目标读者**：需要分支、循环、数据集合处理的开发者。

**重点能力**：
- 流程控制：`IfElse` / `ForLoop` / `WhileLoop` / `Wait` / `BreakLoop` / `CallInstruction`，敌人 AI 决策、波次生成、暂停菜单、遍历敌人批量操作。
- 数组操作（18 个）：增删、查找、排序、打乱、随机、数值统计、向量运算；敌人列表、排行榜、寻找最近敌人。
- 字典操作（16 个）：嵌套路径访问、`DictMerge`、`DictToJson`、数值运算；玩家数据、配置表、物品栏。
- 强调"可视化不等于简单"——照样能写出有分支有循环的真实逻辑。

**引用文档**：`guides/23-flow-control-guide.md`、`guides/21-array-operations-guide.md`、`guides/22-dictionary-operations-guide.md`

---

## 第 6 篇 · 动画系统 + Tween 补间全家桶

**标题建议**：《从动画播放到弹性补间：Fuse 的动画全家桶与手感打磨》

**目标读者**：做角色动画、UI 动效、打击反馈的开发者。

**重点能力**：
- AnimationPlayer 控制：`PlayAnimation` / `StopAnimation` / `BlendAnimation` / `SetAnimationSpeed`，混合权重、慢动作。
- 动画事件：`OnAnimationFinished` / `OnAnimationLoop` / `OnAnimationFrameReached` / `OnAnimationMarker` / `OnAnimationBlend`，帧到达、标记点触发。
- Tween 预置动画：淡入淡出、移动、缩放、旋转、颜色过渡，以及弹出 / 震动 / 弹跳 / 脉冲特效。
- 缓动类型与过渡类型搭配、通用 `TweenProperty`、UI 悬停 / 受击反馈 / 收集特效 / 呼吸效果最佳实践。

**引用文档**：`guides/12-animation-guide.md`、`guides/18-tween-animation-guide.md`

---

## 第 7 篇 · 角色操控实战（输入 + 移动 + 物理条件）

**标题建议**：《不写代码做出一个能跳能攀墙的角色：Fuse 输入与物理实战》

**目标读者**：做平台跳跃 / 动作 RPG 角色控制的开发者。

**重点能力**：
- 输入事件：键盘 / 鼠标 / 触摸手势 / 手柄按钮，`OnInputKey` 上下文数据传递。
- 移动系统：`MoveCharacterBody` 基础/平滑/物理移动、自定义输入动作、手柄映射、移动模式选择。
- 物理条件（亮点）：`CheckOnFloor` / `CheckOnWall` / `CheckInAir` / `CheckIsFalling` / `CheckVelocity` / `CheckSlope` / `CheckOverlapArea`。
- 实战组合：跳跃判定（OnFloor）、二段跳（InAir + Velocity）、攀墙检测（OnWall + 方向输入）、滑铲（Slope 角度）。

**引用文档**：`guides/32-input-events-guide.md`、`guides/11-movement-system-guide.md`、`guides/42-physics-conditions-guide.md`

---

## 第 8 篇 · 交互体验三件套（UI + 相机 + 音频）

**标题建议**：《给游戏加满"手感"：用 Fuse 搞定 UI、相机与音频反馈》

**目标读者**：打磨游戏表现力与反馈感的开发者。

**重点能力**：
- UI 系统：`SetUIText` / `SetUITexture` / `SetUIProgress` / `ShowHideUI`，`OnButtonPressed` / `OnTextChanged` / `OnValueChanged` / `OnFocus`；血条更新、分数显示、暂停菜单切换。
- 相机系统：`CameraFollow` / `CameraShake` / `SetCameraZoom` / `SetCameraLimit`；横版跟随、关卡边界、受击震动。
- 音频系统：`PlaySound` / `PlayMusic` / `CrossfadeToMusic` / `SetAudioVolume`，`OnMusicBeat`；场景音乐切换、暂停菜单、节奏游戏节拍同步。
- 主线：UI + 相机 + 音频 = 反馈"三连击"，让操作有回响。

**引用文档**：`guides/15-ui-guide.md`、`guides/16-camera-guide.md`、`guides/13-audio-guide.md`

---

## 第 9 篇 · 事件系统全解（什么时候执行）

**标题建议**：《把"触发"讲透：Fuse 的生命周期、时序事件与 Event Bus》

**目标读者**：想系统理解 Fuse 事件机制、做跨场景通信的开发者。

**重点能力**：
- 生命周期事件：`OnReady` / `OnEnterTree` / `OnExitTree` / `OnProcess` / `OnPhysicsProcess` / `OnInterval`（含变量版），性能分级建议（用 OnInterval 替代 OnProcess）。
- 时序事件：`OnTimer` / `OnCooldownFinished` / `OnCountdown` / `OnRealtime`；技能冷却、关卡倒计时、每日任务刷新。
- 节点事件：`OnPropertyChanged` / `OnTargetSignalEmit` / `OnSignalFromGroup` / `OnNodeInstance`。
- Event Bus（亮点）：`SendEvent` + `OnReceiveEvent` 全局事件总线，跨场景解耦通信、带参数事件、一次性事件、事件命名规范与调试历史。

**引用文档**：`guides/30-lifecycle-events-guide.md`、`guides/31-timing-events-guide.md`、`guides/33-node-events-guide.md`、`guides/34-event_bus_guide.md`

---

## 第 10 篇 · 条件系统（满足什么才做）

**标题建议**：《让逻辑会"思考"：Fuse 条件系统与 AND/OR/NOT 复合判断》

**目标读者**：需要条件分支、复合判断、智能触发的开发者。

**重点能力**：
- 复合条件：`CheckAll`（AND）/ `CheckAny`（OR）/ `CheckNot`（NOT）/ `CheckComposite`（自定义组合），支持嵌套（智能寻敌、拾取判定）。
- 综合条件：`CheckDistance` / `CheckPathAvailable` / `ExpressionCondition` / `CheckIsOnScreen` / `CheckUIVisible` / `CheckHealthValue` / `CompareHealthThreshold` / `CheckStringContains` / `CheckPlatform`。
- 时间条件：`CheckTimeReached` / `CheckTimeRange` / `CheckCountdownFinished` / `CheckGameTime`；限制战斗时长、日夜循环、技能冷却判断。
- 分专题延伸参考：输入条件（40）、节点条件（41）、物理条件（42，第 7 篇已用）、动画条件（43）。
- 强调"条件 + 事件 + 指令"三者配合，做出真正有判断力的逻辑。

**引用文档**：`guides/45-composite-conditions-guide.md`、`guides/46-comprehensive-conditions-guide.md`、`guides/44-time-conditions-guide.md`（延伸：40 / 41 / 43）

---

## 第 11 篇 · 场景与节点管理

**标题建议**：《场景切换、后台加载、节点增删改：Fuse 管好你的游戏世界》

**目标读者**：处理关卡切换、动态生成、节点操作的开发者。

**重点能力**：
- 场景管理指令：`ChangeScene` / `ReloadScene` / `GetScenePath` / `AddSceneAsChild` / `PreloadSceneInstruction` / `LoadSceneBackground`；立即切换、延迟切换、后台预加载、与普通预加载的区别。
- 节点操作（39 个）：实例化、`FindNode` / `GetAllChildren` / `GetRandomChild` / `GetChildCount`、组操作、`CloneNode` / `ReparentNode` / `QueueFreeNode`、`SetPropertyValue` / `SetProcessMode`。
- 节点通信：`EmitSignal`、`RunTargetNodeFunction`（运行时调用节点方法）。
- 场景预加载流程：开始预加载 → 检查状态 → 加载完成实例化 → 超时处理。

**引用文档**：`guides/17-scene-management-guide.md`、`guides/20-node-operations-guide.md`、`guides/50-scene-preloading-guide.md`

---

## 第 12 篇 · 零代码扩展：指令生成器

**标题建议**：《不想等官方出新指令？用 Fuse 生成器从节点方法一键生成指令》

**目标读者**：想快速扩展能力库、封装自定义节点的开发者、技术美术。

**重点能力**：
- 指令生成器：扫描节点的公开方法 / 属性（GET / SET），自动生成对应指令文件。
- 方法 / 属性两个标签页、变量绑定（固定值 vs 运行时变量）、搜索功能、命名规则与自动注册。
- 生成文件存放位置、文件冲突处理、使用示例（play 方法指令、带变量 SET 指令、GET 读取位置）。
- 与节点操作的 `RunTargetNodeFunction` 对比，说明生成器适合"沉淀为可复用资源"的场景。

**引用文档**：`guides/06-instruction-generator-guide.md`、`guides/20-node-operations-guide.md`

---

## 第 13 篇 · 调试体系（断点 + 追踪 + 变量监视器）

**标题建议**：《可视化逻辑也能单步调试：Fuse 的断点、执行追踪与实时变量监视》

**目标读者**：遇到逻辑不生效、需要排查变量与执行流程的开发者。

**重点能力**：
- 调试指令：`Print`（带验证规则）、`PrintVariableValue`（按作用域 + 类型格式化）、`BreakpointInstruction`。
- 断点进阶：条件断点、跳过前 N 次命中、命中即暂停执行、指定作用域来源。
- 编辑器工具：`DebugVisualizer` 调试可视化面板、`ExecutionTracker` 执行追踪器，五套调试工作流。
- 变量监视器（亮点）：底部 Dock 实时面板，三层变量显示、双击编辑、折线图录制（60 秒滑动窗口）、快照导出、静态声明补全。

**引用文档**：`guides/25-debugging-guide.md`、`guides/26-breakpoint-guide.md`、`guides/56-variable-watcher-guide.md`

---

## 第 14 篇 · 编辑器深度集成（Topology + 静态分析）

**标题建议**：《一张图看懂全场景逻辑：Fuse Topology 拓扑主屏与静态分析》

**目标读者**：项目变大后需要全局视角、提前发现逻辑问题的开发者、团队协作者。

**重点能力**：
- Fuse Topology 主屏（编辑器顶部 "Fuse" Tab）：全场景 Trigger 拓扑总览，左侧 Trigger 树 + 右侧 BBCode 详情。
- 自动刷新（切场景 / Ctrl+S 0.5s 防抖）、选中保持、双击跳转 Inspector / 场景节点。
- 静态分析问题标注：local 未声明变量、NodePath 解析失败、信号引用检测、事件变量白名单，StatusError/Warning 主题图标就地标注。
- 跨 Trigger 关联扫描：写-读箭头、写-写竞态预警、孤写/孤读（仅读无写 = error）。
- Inspector 数据流卡片 + 问题计数角标 + 导出问题报告、问题三档过滤。

**引用文档**：`guides/00-editor-panels-overview.md`、`guides/25-debugging-guide.md`（静态分析章节）、`guides/02-trigger-selection-guide.md`

---

## 第 15 篇 · 工程化与性能（预设 + 对象池 + 预加载 + 多线程）

**标题建议**：《把 Fuse 用到生产级：预设复用、对象池、后台加载与多线程条件》

**目标读者**：准备上线 / 大型项目、关心复用与性能的团队负责人与主程。

**重点能力**：
- 预设系统（L1–L4 四层）：ActionRunner / Trigger / Runner / MultiEventTrigger 全可导出为 `.tres` + `.json`，NodePath 映射（结构匹配 / 同名 / 手动）、跨项目导入复用、附赠样本预设、变量依赖检查。
- 对象池：`InstantiateScene` 池化、预热（WarmUpPool）、回收（RecyclePooledScene）、性能基准与内存对比、池化实例 reset 要求。
- 场景预加载：后台加载消除切换卡顿、`CheckPreloadStatus` 配合、超时处理。
- 多线程条件评估：`ParallelConditionEvaluator` 用 WorkerThreadPool 并行，条件 ≥20 个时 2.5x–4x 提升，默认开启、可配置。
- RuntimeInstance 分离 + 编译缓存，同一 ActionRunner 可被多 Trigger 并发执行而不互扰。

**引用文档**：`guides/55-preset-system-guide.md`、`guides/51-object_pool_system_guide.md`、`guides/50-scene-preloading-guide.md`、`guides/52-multithreading-optimization.md`

---

## 写作建议

- **配图优先**：每篇尽量配编辑器截图（Inspector、Topology 主屏、变量监视器折线图、指令选择器），知乎对图文友好。
- **一句话价值锚**：每篇开头用一句"看完你能解决什么问题"点题，避免堆术语。
- **案例驱动**：优先用文档里的"常见用例 / 场景"小节改写（伤害公式、二段跳、排行榜、节奏同步都是现成好案例）。
- **引流串联**：篇尾统一引导"下一篇"，第 1 篇放出能力全图并预告整个系列。
- **差异化强调**：第 4、9、12、13、14、15 篇是 Fuse 区别于普通事件系统的护城河（表达式 / Event Bus / 生成器 / 监视器 / Topology / 预设与性能），可适当加重笔墨。

**文档未单独成篇但可在相关篇顺带覆盖**：
- `guides/53-icon_manager_guide.md`（图标管理器）→ 第 12 篇自定义指令时提及。
- `guides/24-math-vector-guide.md`（数学/向量）→ 第 4 篇表达式与第 7 篇角色操控中引用。
- `guides/10-transform-guide.md`（变换系统）→ 第 6/7 篇顺带。
- `guides/14-physics-guide.md`（物理指令/事件）→ 第 7 篇或第 11 篇顺带。

**最后更新**：2026-07-21
