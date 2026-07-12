# Fuse 特性总结

Fuse 是 Godot 4.6 的可视化编程插件，通过 Inspector 配置事件、指令和条件来构建游戏逻辑，无需编写代码。

## 核心理念

在场景中放置 Trigger 或 Runner 节点，在 Inspector 中配置"什么时候做"（Event）、"做什么"（Instruction）、"满足什么条件才做"（Condition），运行时自动执行。

## 组件规模

| 组件 | 数量 | 分类 |
|------|------|------|
| 指令 (Instruction) | 133 | 17 个分类 |
| 事件 (Event) | 62 | 14 个分类 |
| 条件 (Condition) | 49 | 14 个分类 |
| 编辑器工具 | 35 | Inspector / 生成器 / 调试 |

## 触发体系

三种方式触发指令执行：

**Trigger** — 事件驱动。放置一个 Trigger，绑定一个 Event（如按键、碰撞），触发后执行 ActionRunner 中的指令序列。

**MultiEventTrigger** — 多事件合并。一个节点管理多个 EventBinding，支持独立冷却、并行条件评估。可以从场景树右键菜单将多个 Trigger 合并或拆分。

**Runner** — 信号绑定或代码调用。绑定任意节点的任意信号，信号触发后自动执行。支持 `await runner.wait_completed()`。

## 指令分类

| 分类 | 数量 | 示例 |
|------|------|------|
| 节点操作 | 16 | FindNode, SetPropertyValue, InstantiateScene, ReparentNode |
| 流程控制 | 14 | IfElse, ForLoop, WhileLoop, Wait, BreakLoop |
| Tween 动画 | 13 | TweenMoveTo, TweenFadeIn, TweenScaleTo, TweenPulseAnimation |
| 数组操作 | 18 | ArrayAdd, ArraySort, ArrayShuffle, ArrayRandom |
| 字典操作 | 16 | DictMerge, DictGetByPath, DictToJson, DictMathOp |
| 变换操作 | 7 | SetPosition, MoveBy, RotateBy, LookAt |
| 物理 | 5 | ApplyImpulse, ApplyForce, SetVelocity, Raycast |
| 数学 | 7 | MathExpression, MathOperation, Lerp, VectorOperation |
| 动画 | 4 | PlayAnimation, StopAnimation, BlendAnimation |
| 音频 | 6 | PlaySound, PlayMusic, CrossfadeToMusic, SetAudioVolume |
| 相机 | 4 | CameraFollow, CameraShake, SetCameraZoom, SetCameraLimit |
| UI | 4 | SetUIText, SetUITexture, SetUIProgress, ShowHideUI |
| 场景管理 | 6 | ChangeScene, ReloadScene, LoadSceneBackground |
| 变量 | 7 | SetVariable, CreateVariable, SaveGlobalVariables |

## 事件分类

| 分类 | 数量 | 示例 |
|------|------|------|
| 输入 | 13 | OnInputKey, OnMouseButton, OnTouchSwipe, OnGamepadButton |
| 物理 | 10 | OnBodyEntered, OnCollision, OnRaycastHit, OnShapeCast |
| 生命周期 | 7 | OnReady, OnEnterTree, OnProcess, OnInterval |
| 动画 | 6 | OnAnimationFinished, OnAnimationStarted, OnAnimationLoop |
| 节点 | 4 | OnTargetSignalEmit, OnPropertyChanged, OnNodeInstance |
| UI | 5 | OnButtonPressed, OnTextChanged, OnValueChanged, OnFocus |
| 场景 | 5 | OnSceneLoaded, OnSceneAboutToChange, OnTreeChanged |
| 时间 | 4 | OnTimer, OnCountdown, OnCooldownFinished, OnRealtime |
| 音频 | 4 | OnAudioStarted, OnAudioFinished, OnMusicBeat |
| 变量 | 1 | OnVariableChanged |

## 条件分类

| 分类 | 数量 | 示例 |
|------|------|------|
| 变量 | 5 | CheckVariable, CompareVariable, CheckHealthValue |
| 节点 | 7 | CheckNodeExists, CheckNodeActive, CheckDirection, CheckGroupCount |
| 物理 | 5 | CheckOnFloor, CheckInAir, CheckVelocity, CheckOnWall |
| 输入 | 4 | CheckInputPressed, CheckInputHeld, CheckInputReleased |
| 动画 | 4 | CheckIsPlaying, CheckAnimationFinished, CheckAnimationTreeState |
| 复合 | 4 | CheckAll (AND), CheckAny (OR), CheckNot (NOT) |
| 数学 | 1 | ExpressionCondition |
| 时间 | 4 | CheckTimeReached, CheckGameTime, CheckCountdownFinished |

## 架构特性

**RuntimeInstance 分离** — 资源定义（Resource）和运行时状态（Instance）分离，支持池化重用，同一个 ActionRunner 资源可以被多个 Trigger 并发执行而互不干扰。

**对象池** — 内置通用对象池系统，支持预热和自动回收。指令实例、场景实例都可以池化管理，减少运行时 GC 压力。

**多线程** — 条件评估支持 WorkerThreadPool 并行计算（ParallelConditionEvaluator），在条件数量多时显著减少主线程负载。

**执行模式** — ActionRunner 支持顺序、并行、异步三种执行模式。指令有同步/异步自动检测，异步指令会自动 await。

**变量系统** — 三层作用域：局部变量（ExecutionContext 内）、作用域变量（ScopeVariableContainer 子树）、全局变量（GlobalVariableManager 单例）。全局变量支持存档和读档。

**编译缓存** — ActionRunner 的指令序列支持编译为 CompiledInstructionSequence，跳过重复的类型检查和初始化开销。

## 编辑器工具

- **指令选择器** — 按分类浏览、搜索、添加指令到 ActionRunner
- **指令生成器** — 从节点的公开方法自动生成对应指令
- **上下文菜单** — 合并/拆分 Trigger，一键操作
- **输入键选择器** — 可视化选择键盘、鼠标、手柄按键
- **调试面板** — DebugVisualizer + ExecutionTracker，实时查看执行流程
- **静态分析** — InstructionAnalyzer.analyze_problems 在编辑阶段检测以下问题，FuseTopology 主屏就地标注（StatusError / StatusWarning 主题图标）：
  - **local 未声明变量** — 指令链中读写但未通过 `SetVariable` 声明的 local 变量，含条件嵌套分支内的声明追溯
  - **事件提供变量白名单** — 部分事件（如 OnInput）向 ExecutionContext 注入的变量不算未声明
  - **NodePath 解析失败** — 指令引用的 NodePath 在当前场景中无法解析到实际节点
  - **信号引用检测** — EmitSignal 指令引用的信号名是否在目标节点上存在
  - **跨 Trigger 变量关联** — 写-读箭头 / 竞态预警（多 Trigger 写同一变量）/ 孤写孤读（仅写无读 / 仅读无写）
- **Fuse Topology 主屏** — 编辑器顶部 "Fuse" Tab，全场景 Trigger 拓扑总览：
  - **自动刷新** — 切换场景 / 保存场景（Ctrl+S）时自动刷新（0.5s 防抖）
  - **选中保持** — 刷新后自动恢复之前选中的 Trigger / 指令条目
  - **双击跳转** — 双击 Trigger → Inspector 跳转到场景节点；双击指令 → Inspector 显示指令 Resource
  - **问题过滤** — OptionButton 三档：全部 / 仅错误 / 无
  - **主题图标** — 使用 Godot 主题图标，跟随编辑器明暗主题
  - **Inspector 问题计数** — 数据流按钮角标显示该 Trigger 的问题数，展开卡片查看分级详情

## 本地化

支持简体中文和英语，2498+ 翻译键。所有用户可见的字符串通过 FuseLocalization 统一管理。

## 代码规模

- 271 个 GDScript 文件
- 219 个测试文件
- 137 篇文档
