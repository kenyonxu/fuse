> 🌐 中文 | [**English**](../../../en_US/user_docs/best_practices/preset_reuse.md)

# Preset 复用与 AI 协作实践

## 概述

Preset（预设）是 Fuse 逻辑的"积木化"形态：一段调好的 Trigger 逻辑导出为 JSON，导入到任意项目复用；AI 也能按 schema 直接生成它。这篇实践指南回答两个问题——**怎么写出让 AI 生成得好、让人迁移得顺的 preset**，以及**怎么把 AI 纳入生成-校验-调参的循环**。

操作层面（面板怎么点、导出导入流程）见[预设系统指南](../guides/55-preset-system-guide.md)；本篇只讲"怎么做好"。

## 一、粒度：一个交互单元一份

粒度是 preset 实践的第一决定因素，两个极端都有代价：

- **太细**（单条指令、单个信号绑定）：复用价值趋零，不如直接搭
- **太粗**（整个关卡、整个 UI 界面）：导入后 NodePath 与变量映射工作量大，一处不合用就整包作废

**推荐粒度是"一个可独立描述的交互单元"**——能用一句话说清它是什么的整段逻辑：

> "受击无敌帧"、"波次生成器"、"Boss 三阶段循环"、"拾取飘字"

深度测试语料（`demos/fuse/deep_tests/presets/`，28 个领域 preset）就是这个粒度：`deep_tween`（Tween 补间集）、`deep_audio`（音频控制）、`deep_camera`（相机运镜）——每个都是独立可描述、可单独导入的能力单元。

语料同时给出**复杂度分级**的参照（L1-L4）：

| 级别 | 形态 | 例子 |
|------|------|------|
| L1 | 单事件 + 简单指令链 | 按键打印 |
| L2 | 定时器/间隔驱动 | 呼吸灯、周期巡逻 |
| L3 | Runner 单元（代码调用型） | 受击处理函数 |
| L4 | 多事件复合（MultiEventTrigger） | 同一对象的攻防一体逻辑 |

L2-L4 是复用价值最高的区间；L1 通常当场搭更快。

## 二、元数据：导入前的"简历"

preset JSON 头部的元数据字段决定它在注册表和团队协作中的可发现性。导出前检查四项齐全：

```json
{
  "format_version": "...",
  "level": "L4",
  "display_name": "Boss 三阶段循环",
  "category": "boss",
  "description": "血量阈值驱动三阶段行为切换，含受击无敌帧与死亡结算",
  "variables": [ ... ],
  "trigger_config": { ... }
}
```

- **`display_name` 用中文短语**，别说"逻辑 1"；导入者的 preset 浏览列表里它就是唯一标识
- **`category` 按交互域起名**（combat / ui / camera / boss…），不要用项目名——跨项目复用时的分类一致性比来源项目重要
- **`description` 写清输入输出**：这个 preset 期望哪些变量已存在（读什么）、产出什么（写什么）——这是导入者最需要的信息
- **`variables` 数组如实声明**：变量依赖检查用它扫描缺失，瞒报漏报都会让导入者在运行时才发现问题

## 三、依赖最小化：迁移成本 = 依赖数量

preset 跨项目迁移的全部摩擦来自两类依赖，实践按此排优先级：

1. **变量依赖**（最可控）：只在 preset 内部流转的中间值用 LOCAL 变量，让依赖清单里只剩真正的输入输出。十个 GLOBAL 依赖的 preset 几乎不可复用；改成"读 2 个全局、写 1 个全局、其余 LOCAL"，迁移就是填三个变量名的事
2. **NodePath 依赖**（可映射）：目标节点在新场景路径不同没关系——导入时的[三级映射](../guides/55-preset-system-guide.md)（节点名 → 类型 → 层级近似匹配）会生成建议，但**节点命名本身要可读**：`Hurtbox` 比 `Area2D7` 的映射成功率高得多

反模式清单：

- preset 内部用 GLOBAL 变量传中间值（应改 LOCAL）
- 指令参数写死节点路径而不是变量绑定（改用[变量绑定](../guides/07-variable-binding-guide.md)双轨，迁移时只改变量来源）
- 一个 preset 依赖另一个 preset 的副作用（耦合拆开，各自声明变量接口）

## 四、AI 协作：生成-校验-调参循环

AI 生成 preset 不是"让 AI 写完直接用"，而是一个三步循环：

### 第 1 步：喂清单、说需求

把 `addons/fuse/preset_ai_context/` 下的三个 JSON（components / schemas / enums）提供给 AI——这是全部组件的机器可读清单，含条件参数的门控关系。需求描述按"事件 → 条件 → 动作序列 → 变量接口"四要素说：

> "生成一个受击无敌帧 preset：事件 OnDamaged，把 invincible 置 true、Wait 1.2 秒后置回 false；期望输入变量 invincible（GLOBAL），另加闪烁 Tween。"

四要素越全，AI 一次生成的命中率越高；组件名不确定时让 AI 先从 components.json 检索再写。

### 第 2 步：离线校验把关

```bash
Godot --headless --path . res://addons/fuse/editor/preset_ai/validate_preset.tscn -- <preset.json>
# 退出码 0 = 无 error；非 0 = 看 findings 逐条修
```

校验器做结构、组件引用、参数类型、语义约束四层检查。**有 error 的 preset 不要导入**——把校验 findings 贴回给 AI 让它自修，通常一轮就能过。

### 第 3 步：导入后人工调参

校验保证"合法"，不保证"好玩"。手感参数（时长、缓动、力度）在 Inspector 里拖滑块调——这正是 preset 走 JSON 而不是编译产物的意义：**AI 出结构，人出手感**，各做擅长的事。

### 迭代边界

- 参数级调整：导入后直接 Inspector 调，不要回到 AI 重生成
- 结构级调整（加指令、改事件）：改需求描述重新生成，别在 JSON 里手改指令树——手改容易破坏 schema 细节（条件门控、变量模式声明），校验器会告诉你哪里断了

## 五、版本管理与团队协作

- preset JSON 是纯文本，**进 git 可 diff 可评审**——结构变更（增删指令）和参数变更（调时长）在 diff 里一目了然，这是".tres 场景内嵌"形态给不了的
- 团队分工的自然切线：策划在 Inspector 调参、程序审 JSON diff、AI 按需求生成初稿——三者操作同一份 JSON 的不同层面
- preset 演进出 v2 时**复制新文件而非覆盖**（`boss_loop_v2.json`），老场景引用老版本不受影响

## 常见问题

### 导入后变量依赖检查报缺失，但变量明明有？

检查作用域：preset 声明的是 GLOBAL，你项目里建的是 SCOPE。作用域不一致等于变量不存在。

### AI 生成的 preset 校验过了，运行时行为不对？

校验的是合法性不是语义。先开[变量监视器](../guides/56-variable-watcher-guide.md)看变量流水，多数问题出在变量作用域选错或事件触发时机理解偏差——把监视器观测结果描述回给 AI，让它定位。

### 从别的项目导出的 preset，NodePath 全部映射失败？

多半是原场景节点命名不可读（Area2D3 之类）。在新场景按 preset 的语义重命名目标节点后重新导入，映射建议会刷新。

---

**相关文档：**

- [预设系统指南](../guides/55-preset-system-guide.md)——导出/导入/映射的操作面
- [变量绑定使用指南](../guides/07-variable-binding-guide.md)——参数双轨，减少路径依赖的手段
- [AI 协作与毕业交接](../Introductions/16-ai-collaboration-and-graduation-handoff.md)——preset 在"桥梁"全景中的位置
- [触发器组织与竞态规避](trigger_organization.md)——preset 落回场景后的组织实践
