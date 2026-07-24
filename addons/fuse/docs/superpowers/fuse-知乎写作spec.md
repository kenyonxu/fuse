# Fuse 知乎文章写作规格文档

> 基于 `fuse-知乎预热清单.md`（15 篇四阶段规划）生成
> 生成工具: Codex (GLM-5.2) · 2026-07-24

---

## 一、总体写作策略

**价值锚强约束**：每篇开头第一段必须用一句话回答"看完你能解决什么问题"，禁止以"Fuse 是一个……的插件"这种定义式开头铺陈。

**字数基准**
- 总览篇：3500–4500 字
- 入门篇（2–4）：2500–3500 字，控制密度防劝退
- 专项篇（5–12）：单系统深入 3500–4800 字；多系统合并篇（5、8、9）4500–5500 字
- 进阶护城河篇（4、9、13、14、15）：上探 4500–5500 字，差异化特性单独成节加重笔墨
- 浮动区间 ±15%，超出需说明理由（如案例步骤特别多）

**截图规范**
- 语言：强制中文 UI。Fuse 支持本地化，截图前切到中文，保证正文与截图术语一致。
- 尺寸：正文图宽 1080px；Topology 主屏等全景图 1920px 横图。统一 PNG。
- 动图：关键操作流程（右键合并/拆分、断点单步、折线图录制、生成器扫描）用 GIF，单张 < 5MB，每篇至少 1 个（专项及以后篇目）。
- 标注：红框圈重点 + 序号引线，工具统一（推荐标注后导出，不留编辑器水印）。
- 数量：每篇静态图 3–6 张 + 动图 1–2 个；总览篇放能力全图 1 张。
- 脱敏：用独立 demo 工程，不暴露真实项目路径与资产命名。
- 图注：每张图配一句话图注，说明"这张图要看什么"，不允许裸图。
- 专有面板优先取：Inspector 数据流卡片、Fuse Topology 主屏、变量监视器折线图、指令选择器、生成器标签页。

**代码块规范**
GDScript 代码块带 `gdscript` info string；变量引用语法 `{local:hp}` 用行内反引号；指令名首次出现加粗。

**术语一致性**：Runner / Trigger / MultiEventTrigger / Event Bus / Topology / RuntimeInstance 等专有名词全文大小写统一，建立一份术语表随系列维护。

---

## 二、15 篇逐篇写作规格

### 第 1 篇 · 总览概要

- **标题**：《Fuse：让 Godot 策划和美术也能搭逻辑的可视化编程插件（附能力全图）》；备选《不写代码做游戏逻辑：Fuse 完整能力地图》
- **读者**：所有 Godot 开发者、独立团队、想参与逻辑的策划/美术、GameJam 选手
- **技术点**：Fuse 三句话定位（何时做/做什么/满足什么才做）；三大砖块规模（Event 62 / Instruction 133 / Condition 49，分类 17/14/14）；三种触发器一句话定位；规模数据与编辑器集成（35 工具、Topology 主屏、Inspector 数据流卡片）；适用场景五类；放出能力全图并预告后续 14 篇
- **引用**：`quick_start.md`、`FEATURES.md`、`guides/00-index.md`、`guides/00-editor-panels-overview.md`
- **篇幅**：3500–4500 字
- **素材**：能力全图 1 张（独立制作，建议手绘风格信息图）、Topology 主屏截图 1、Inspector 数据流卡片 1、砖块规模统计表 1
- **衔接**：← 无（系列开篇） | → 预告全系列，明确"下一篇带你 5 分钟跑通第一个案例"

### 第 2 篇 · 5 分钟上手 + 触发器三件套

- **标题**：《5 分钟搭出第一个游戏逻辑：Runner / Trigger / MultiEventTrigger 怎么选》；备选《Fuse 上手第一课：三种触发器选型决策》
- **读者**：刚装好 Fuse、想跑通第一个案例的开发者
- **技术点**：从零搭"按钮点击→执行指令"（Runner）；三件套选型决策树；`runner.run()` + `await runner.wait_completed()`；`trigger_once`/`cooldown` 防重复；MultiEventTrigger 右键合并/拆分、独立冷却、动态启停
- **引用**：`quick_start.md`、`guides/02-trigger-selection-guide.md`、`guides/03-runner-guide.md`、`guides/04-multi-event-trigger-guide.md`
- **篇幅**：3000–3800 字
- **素材**：Runner 搭建分步截图 3、三件套选型决策流程图 1、右键合并/拆分 GIF 1、`runner.run()` 代码块 1
- **衔接**：← 承接第 1 篇"三件套是什么" | → 引出"逻辑需要数据，下一篇讲变量从哪来"

### 第 3 篇 · 三层变量系统

- **标题**：《别让全局变量满天飞：Fuse 的 LOCAL / SCOPE / GLOBAL 三层变量怎么管》；备选《可视化逻辑的数据怎么管：Fuse 三层作用域实战》
- **读者**：开始写实际逻辑、关心数据组织与作用域的开发者
- **技术点**：三层作用域定义；作用域链继承（READ_ONLY/READ_WRITE）；选型指南（单次/UI 共享/跨场景）；GLOBAL 持久化 `SaveGlobalVariables`/`LoadGlobalVariables`、多存档槽位、`OnVariableChanged` 信号
- **引用**：`guides/01-variable_system_guide.md`、`guides/54-global-variables-guide.md`
- **篇幅**：3500–4200 字
- **素材**：三层作用域示意图 1、SCOPE 来源选择截图 1、存档槽位演示截图 1、GLOBAL 保存/加载代码块 1、选型对照表 1
- **衔接**：← 承接第 2 篇"触发器执行需要数据" | → 引出"变量能被表达式动态计算，下一篇讲表达式"

### 第 4 篇 · 表达式系统（护城河，加重）

- **标题**：《不写一行代码算伤害公式：Fuse 表达式系统实战》；备选《可视化系统里的"计算引擎"：Fuse 表达式三件套》
- **读者**：需要动态计算伤害/文本格式化/复杂判断的开发者
- **技术点**：`MathExpression`/`StringExpression`/`ExpressionCondition` 三件套；统一变量引用语法 `{local:hp}` `{scope:name}` `{global:max}`；实战例（伤害计算、HP 归一化、伤害飘字、进度条文本、补零、三元分级）；可用函数库；未找到变量安全降级为 0
- **引用**：`guides/05-expression-guide.md`、`guides/24-math-vector-guide.md`
- **篇幅**：4000–5000 字
- **素材**：表达式编辑器截图 2、伤害公式计算演示 GIF 1、变量引用语法对照表 1、6 个实战例代码/截图
- **衔接**：← 用第 3 篇变量 | → 引出"有了计算就能搭分支循环，下一篇讲流程控制"

### 第 5 篇 · 流程控制 + 数据结构

- **标题**：《If、循环、数组、字典：在可视化系统里搭出复杂逻辑》；备选《可视化不等于简单：Fuse 的分支循环与数据集合》
- **读者**：需要分支、循环、数据集合处理的开发者
- **技术点**：流程控制 `IfElse`/`ForLoop`/`WhileLoop`/`Wait`/`BreakLoop`/`CallInstruction`（敌人 AI、波次生成、暂停菜单）；数组 18 个操作；字典 16 个操作（嵌套路径、`DictMerge`、`DictToJson`）；强调"可视化照样写出真实逻辑"
- **引用**：`guides/23-flow-control-guide.md`、`guides/21-array-operations-guide.md`、`guides/22-dictionary-operations-guide.md`
- **篇幅**：4500–5500 字
- **素材**：ForLoop 波次生成截图 1、数组排序/打乱 GIF 1、字典嵌套路径访问截图 1、敌人 AI 决策流程图 1、流程控制指令清单表 1
- **衔接**：← 承接第 4 篇表达式 | → 引出"逻辑搭好了，下一篇让画面动起来"

### 第 6 篇 · 动画系统 + Tween

- **标题**：《从动画播放到弹性补间：Fuse 动画全家桶与手感打磨》；备选《角色动画与 UI 动效：Fuse 动画 + Tween 全解》
- **读者**：做角色动画、UI 动效、打击反馈的开发者
- **技术点**：AnimationPlayer 控制（播放/停止/混合/变速）；动画事件（Finished/Loop/FrameReached/Marker/Blend）；Tween 预置动画与特效（弹出/震动/弹跳/脉冲）；缓动与过渡搭配；`TweenProperty` 通用补间；手感最佳实践
- **引用**：`guides/12-animation-guide.md`、`guides/18-tween-animation-guide.md`、`guides/10-transform-guide.md`（顺带）
- **篇幅**：3500–4200 字
- **素材**：混合权重截图 1、Tween 特效全家桶 GIF 1、受击反馈案例 GIF 1、缓动曲线对照图 1
- **衔接**：← 承接第 5 篇逻辑骨架 | → 引出"动画会动了，下一篇让角色真正受控移动"

### 第 7 篇 · 角色操控实战

- **标题**：《不写代码做出能跳能攀墙的角色：Fuse 输入与物理实战》；备选《平台跳跃角色从零搭：输入+移动+物理条件》
- **读者**：做平台跳跃/动作 RPG 角色控制的开发者
- **技术点**：输入事件（键鼠/触摸/手柄，`OnInputKey` 上下文传递）；`MoveCharacterBody` 基础/平滑/物理移动；物理条件亮点（`CheckOnFloor`/`OnWall`/`InAir`/`IsFalling`/`CheckVelocity`/`CheckSlope`/`CheckOverlapArea`）；实战组合（跳跃/二段跳/攀墙/滑铲）
- **引用**：`guides/32-input-events-guide.md`、`guides/11-movement-system-guide.md`、`guides/42-physics-conditions-guide.md`、`guides/14-physics-guide.md`
- **篇幅**：4000–4800 字
- **素材**：角色移动模式选择截图 1、二段跳组合 GIF 1、攀墙检测 GIF 1、物理条件清单表 1、输入映射截图 1
- **衔接**：← 承接第 6 篇动画 | → 引出"角色能动还不够，下一篇给游戏加满反馈手感"

### 第 8 篇 · 交互体验三件套（UI + 相机 + 音频）

- **标题**：《给游戏加满"手感"：用 Fuse 搞定 UI、相机与音频反馈》；备选《反馈三连击：Fuse 的 UI/相机/音频一体化实战》
- **读者**：打磨游戏表现力与反馈感的开发者
- **技术点**：UI（`SetUIText`/`SetUITexture`/`SetUIProgress`/`ShowHideUI` + 四个 UI 事件）；相机（`CameraFollow`/`CameraShake`/`SetCameraZoom`/`SetCameraLimit`）；音频（`PlaySound`/`PlayMusic`/`CrossfadeToMusic`/`OnMusicBeat`）；"三连击"主线——操作有回响
- **引用**：`guides/15-ui-guide.md`、`guides/16-camera-guide.md`、`guides/13-audio-guide.md`
- **篇幅**：4000–4800 字
- **素材**：血条/分数更新截图 1、相机震动 GIF 1、音乐切换淡入淡出 GIF 1、节奏游戏节拍同步截图 1
- **衔接**：← 承接第 7 篇角色操控 | → 引出"这些都靠事件驱动，下一篇系统讲事件机制"

### 第 9 篇 · 事件系统全解（护城河，加重）

- **标题**：《把"触发"讲透：Fuse 的生命周期、时序事件与 Event Bus》；备选《Fuse 事件机制全解：从生命周期到跨场景总线》
- **读者**：想系统理解 Fuse 事件机制、做跨场景通信的开发者
- **技术点**：生命周期事件（含性能分级，`OnInterval` 替代 `OnProcess`）；时序事件（Timer/Cooldown/Countdown/Realtime）；节点事件（PropertyChanged/TargetSignal/SignalFromGroup/NodeInstance）；Event Bus 亮点（`SendEvent`+`OnReceiveEvent`、带参数、一次性、命名规范、调试历史）
- **引用**：`guides/30-lifecycle-events-guide.md`、`guides/31-timing-events-guide.md`、`guides/33-node-events-guide.md`、`guides/34-event_bus_guide.md`
- **篇幅**：4500–5500 字
- **素材**：事件分类全景图 1、Event Bus 跨场景通信 GIF 1、性能分级对比截图 1、事件命名规范表 1
- **衔接**：← 承接第 8 篇交互 | → 引出"事件触发后还需要判断，下一篇讲条件系统"

### 第 10 篇 · 条件系统

- **标题**：《让逻辑会"思考"：Fuse 条件系统与 AND/OR/NOT 复合判断》；备选《满足什么才做：Fuse 条件系统全解》
- **读者**：需要条件分支、复合判断、智能触发的开发者
- **技术点**：复合条件（`CheckAll`/`CheckAny`/`CheckNot`/`CheckComposite` 嵌套）；综合条件（距离/路径/表达式/屏幕内/UI可见/血量/字符串/平台）；时间条件（`CheckTimeReached`/`TimeRange`/`CountdownFinished`/`GameTime`）；延伸参考输入/节点/动画条件；"条件+事件+指令"三者配合
- **引用**：`guides/45-composite-conditions-guide.md`、`guides/46-comprehensive-conditions-guide.md`、`guides/44-time-conditions-guide.md`
- **篇幅**：3500–4200 字
- **素材**：复合条件嵌套截图 1、智能寻敌案例 GIF 1、时间条件日夜循环截图 1、条件分类清单表 1
- **衔接**：← 承接第 9 篇事件 | → 引出"判断完要操作世界，下一篇讲场景与节点管理"

### 第 11 篇 · 场景与节点管理

- **标题**：《场景切换、后台加载、节点增删改：Fuse 管好你的游戏世界》；备选《Fuse 场景与节点操作：从切换到动态生成》
- **读者**：处理关卡切换、动态生成、节点操作的开发者
- **技术点**：场景管理指令（切换/重载/路径/挂载子场景/预加载/后台加载，立即 vs 延迟 vs 后台区别）；节点操作 39 个（实例化/查找/遍历/组/克隆/重父/释放/属性设置/进程模式）；节点通信（`EmitSignal`、`RunTargetNodeFunction`）；预加载流程四步
- **引用**：`guides/17-scene-management-guide.md`、`guides/20-node-operations-guide.md`、`guides/50-scene-preloading-guide.md`
- **篇幅**：3500–4200 字
- **素材**：后台加载消除卡顿 GIF 1、节点查找/克隆截图 1、预加载流程图 1、节点操作分类表 1
- **衔接**：← 承接第 10 篇条件 | → 引出"内置指令不够用时怎么办，下一篇讲生成器"

### 第 12 篇 · 零代码扩展：指令生成器（护城河）

- **标题**：《不想等官方出新指令？用 Fuse 生成器从节点方法一键生成指令》；备选《Fuse 扩展能力库：生成器 + 图标管理器》
- **读者**：想快速扩展能力库、封装自定义节点的开发者、技术美术
- **技术点**：生成器扫描公开方法/属性自动生成指令；方法/属性两标签页；变量绑定（固定 vs 运行时）；命名规则与自动注册；文件存放与冲突处理；与 `RunTargetNodeFunction` 对比（沉淀为可复用资源 vs 临时调用）；顺带提图标管理器
- **引用**：`guides/06-instruction-generator-guide.md`、`guides/20-node-operations-guide.md`、`guides/53-icon_manager_guide.md`
- **篇幅**：3000–3800 字
- **素材**：生成器扫描 GIF 1、方法/属性标签页截图 1、生成文件结构截图 1、生成 vs RunTargetNodeFunction 对照表 1
- **衔接**：← 承接第 11 篇节点操作 | → 引出"搭多了逻辑出问题怎么查，下一篇讲调试"

### 第 13 篇 · 调试体系（护城河，加重）

- **标题**：《可视化逻辑也能单步调试：Fuse 的断点、执行追踪与实时变量监视》；备选《Fuse 调试全家桶：断点 + 追踪 + 变量监视器》
- **读者**：遇到逻辑不生效、需排查变量与执行流程的开发者
- **技术点**：调试指令（`Print` 带验证、`PrintVariableValue` 按作用域格式化、`BreakpointInstruction`）；断点进阶（条件断点、跳过前 N 次、命中暂停、作用域来源）；`DebugVisualizer` + `ExecutionTracker` 五套工作流；变量监视器亮点（Dock 实时面板、三层显示、双击编辑、折线图 60 秒录制、快照导出、静态声明补全）
- **引用**：`guides/25-debugging-guide.md`、`guides/26-breakpoint-guide.md`、`guides/56-variable-watcher-guide.md`
- **篇幅**：4000–4800 字
- **素材**：条件断点单步 GIF 1、执行追踪面板截图 1、变量监视器折线图录制 GIF 1、五套调试工作流流程图 1
- **衔接**：← 承接第 12 篇扩展 | → 引出"单篇调试之外，项目级全局视角下一篇讲 Topology"

### 第 14 篇 · 编辑器深度集成（护城河，加重）

- **标题**：《一张图看懂全场景逻辑：Fuse Topology 拓扑主屏与静态分析》；备选《项目变大后怎么管：Fuse Topology + 静态分析》
- **读者**：项目变大后需全局视角、提前发现问题的开发者、团队协作者
- **技术点**：Topology 主屏（Trigger 树 + BBCode 详情、自动刷新 Ctrl+S 0.5s 防抖、选中保持、双击跳转）；静态分析标注（local 未声明、NodePath 失败、信号引用、事件白名单、StatusError/Warning 图标）；跨 Trigger 关联扫描（写-读箭头、写-写竞态、孤写/孤读）；Inspector 数据流卡片 + 问题计数角标 + 导出报告 + 三档过滤
- **引用**：`guides/00-editor-panels-overview.md`、`guides/25-debugging-guide.md`（静态分析章节）、`guides/02-trigger-selection-guide.md`
- **篇幅**：3500–4500 字
- **素材**：Topology 全景图 1920px 1、静态分析问题标注截图 1、跨 Trigger 写读箭头 GIF 1、问题三档过滤截图 1
- **衔接**：← 承接第 13 篇单点调试 | → 引出"从调试到生产，下一篇讲工程化与性能"

### 第 15 篇 · 工程化与性能（护城河收尾，加重）

- **标题**：《把 Fuse 用到生产级：预设复用、对象池、后台加载与多线程条件》；备选《Fuse 上线前的最后一课：复用、池化、预加载与并行》
- **读者**：准备上线/大型项目、关心复用与性能的团队负责人与主程
- **技术点**：预设系统 L1–L4 四层（`.tres`+`.json`、NodePath 映射三策略、跨项目导入、样本预设、变量依赖检查）；对象池（`InstantiateScene` 池化、`WarmUpPool`、`RecyclePooledScene`、基准对比、reset 要求）；场景预加载消除卡顿 + 超时；多线程条件 `ParallelConditionEvaluator`（≥20 条件 2.5x–4x，默认开启可配）；RuntimeInstance 分离 + 编译缓存，多 Trigger 并发不互扰
- **引用**：`guides/55-preset-system-guide.md`、`guides/51-object_pool_system_guide.md`、`guides/50-scene-preloading-guide.md`、`guides/52-multithreading-optimization.md`
- **篇幅**：4500–5500 字
- **素材**：预设四层对照表 1、对象池性能基准图 1、多线程加速对比柱状图 1、NodePath 映射策略截图 1、系列完结整合引导
- **衔接**：← 承接第 14 篇全局视角 | → 系列完结，汇总全系列索引并引导回第 1 篇能力全图

---

## 三、单篇质量检查清单（10 条）

1. 开头第一段有一句话价值锚，点明"看完能解决什么问题"，无定义式铺陈。
2. 至少一个可跑通的小案例，附分步截图与操作步骤，不是纯罗列功能。
3. 截图为中文 UI、有红框/序号标注、每张配一句话图注，动图单张 < 5MB。
4. 核心术语（Runner/Trigger/作用域/Event Bus 等）首次出现给一句白话解释。
5. 引用文档路径与实际 `user_docs` 文件一一对应，可追溯、无错引。
6. 该篇若为护城河篇（4/9/12/13/14/15），差异化特性有独立小节并加重笔墨。
7. 篇尾有"下一篇"衔接引导，承接点与上文逻辑闭环。
8. 正文字数落在建议区间 ±15% 内。
9. 所有能力承诺与性能数据（如多线程 2.5x–4x）有文档出处，无未经验证的夸大。
10. 通读校对：无错别字，专有名词大小写全文统一（对照术语表）。

---

## 四、发布节奏建议

**三阶段排期（建议 5–6 周完成）**

- 预热周：第 1 篇总览先行，配能力全图，建立"系列专栏"心智，评论区收集最想看的话题。
- 入门密集期（第 1 周内）：第 2–4 篇连发或隔天发，趁热让读者跑通案例、形成"能上手"的口碑。
- 常规期（第 2–4 周）：第 5–12 篇每周稳定 2 篇，周二/周五各一篇，专项系统逐块拆解。
- 收尾期（第 5 周）：第 13–15 篇每周 1 篇，护城河篇留足打磨时间，第 15 篇做系列完结整合（附全 15 篇索引回链第 1 篇）。

**先行测试集（可选）**
若想先验证反响再全力推进，先发第 1、2、4、9、15 篇——分别代表总览、上手、表达式、Event Bus、工程化性能，覆盖最强差异化，据互动数据调整后续投入。

**跨篇运营动作**
- 每篇固定文末"系列导航"模块，列已发篇目 + 下一篇预告。
- 第 1 篇能力全图作为系列固定封面素材复用。
- 护城河篇（4/9/12/13/14/15）可单独提炼金句做想法/短动态二次传播。
- 收集高频提问，作为第 15 篇后的"FAQ 合集"或加篇素材。
