# 一张图看懂全场景逻辑：Fuse Topology 拓扑主屏与静态分析

上一篇我们用断点、执行追踪和变量监视器把单点调试做到了 IDE 级别。但调试有个前提——你得先知道问题出在哪个 Trigger。项目里有几十个场景、上百个 Trigger 互相通过 Event Bus 联动时，"去哪查"本身就变成了最大的成本。Fuse 的答案是给整个项目装一个上帝视角：Fuse Topology 拓扑主屏。看完这篇你会明白它不只是一张好看的图——它是一个内置的静态分析器，在你没运行游戏的时候就能把"未声明变量""NodePath 失效""写写竞态"这些问题直接标红，还能告诉你哪个 Trigger 写了变量、哪个 Trigger 读了它。可视化系统的工程化护城河，从这一屏开始成型。

承接上一篇：单点调试到位了，但需要全局视角才能知道去哪断。

## Topology 主屏：全场景的上帝视角

Topology 注册在编辑器顶部的 "Fuse" Tab，和 2D/3D/Script 并列。界面左右分栏：左侧是 Trigger 树，扫描当前场景所有 Trigger 和 Runner，按节点结构分组；右侧是详情面板，用 BBCode 富文本渲染选中的指令或 Trigger。

树形视图大概这样：

```
Trigger(OnInputKey)    on_input_key
  ├ SetVariable
  ├ CompareVariable
  └ EmitSignal
Runner(OnTimer)        timer
  └ TweenMoveTo
```

## 不用手动刷新的交互设计

自动刷新，0.5 秒防抖：切换场景时和保存场景（Ctrl+S）时自动重建拓扑。配套选中保持（刷新后恢复之前选中的节点）和双击跳转（双击 Trigger 直接跳转 Inspector，双击指令跳转 Resource 编辑）。

## 静态分析：编辑阶段就标红（护城河加重）

每次刷新时分析问题，就地标注在树节点上。覆盖五类问题：

- **local 未声明变量**：读了但整条链没任何 SetVariable 声明它
- **NodePath 解析失败**：引用的路径在场景里找不到实际节点
- **信号引用检测**：EmitSignal 引用的信号在目标节点上不存在
- **事件白名单**：有些输入类事件会注入变量，这些不算未声明
- **StatusError/Warning 图标**：红色/黄色标注 + 行尾问题计数

## 跨 Trigger 关联扫描（护城河加重）

自动分析四类关联：

- **写-读箭头**：谁写了、谁读了，确认数据流是否符合预期
- **写-写竞态预警**：多个 Trigger 写同一变量，标注 ⚠ 警告
- **孤写**：只有写没有读，可能是冗余逻辑
- **孤读**：只有读没有写，标注 error（运行时必然拿默认值）

## Inspector 数据流卡片

选中任一 BaseTrigger 节点，Inspector 底部显示数据流按钮，格式如 `📊 数据流: OnInterval (5指令, 3节点, 8变量, 2信号)`。展开后看到结构化的指令链、变量分类和信号引用。当有静态分析问题时，按钮显示问题计数角标，红色表示有 error。

## 三档过滤与导出报告

顶部 banner 三档过滤：全部 / 仅错误 / 无。还有导出问题报告按钮，把全场景问题汇总写进 `user://fuse_problems_report_*.txt`，适合 CI 或离线审查。

## 新角色：交接工件的源头

面板里这张图，还有一条 CLI 通道可以整机导出：

```bash
Godot --headless --path . res://addons/fuse/editor/topology/export_topology.tscn -- --scene res://<你的场景>.tscn
```

导出的拓扑 JSON 就是你在主屏看到的一切的结构化版本——全部 Trigger / Runner 单元与跨单元关联（事件、RunRunner 调用、变量读写、信号、竞态预警），附源场景溯源字段。它下一步流向 `derive_systems` 推导 System 工件，最终进入交接包，交给 AI agent 编写脱离 Fuse 的工程代码——整条链路在第 16 篇走完。**拓扑面板不只是审查工具，它是"毕业"这条腿的源头。**

## 实战：把一个脏场景扫干净

接手一个原型，十几个 Trigger 偶尔出问题。切 Fuse Tab → 过滤仅错误 → 双击修复 → Ctrl+S 自动刷新验证 → 查看写写竞态 → 导出报告留档。全程不跑一次游戏。

## 小结

Topology 把全场景 Trigger 关系和静态分析放在一张图上，让配置错误在编辑阶段就暴露；它同时是交接工件的源头，拓扑 JSON 沿 CLI 通道流向毕业链路。调试和审查都到位了，下一关是性能和复用——下一篇讲预设系统、对象池、多线程条件和工程化性能；系列真正的收官在第 16 篇：AI 协作与毕业交接。
