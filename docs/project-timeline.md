# Project Juicy Godot - 项目时间线

> 最后更新: 2026-04-02 | 总提交数约 400+ | 跨时约 5.5 个月（2025-10 ~ 2026-03）

## 一、项目启动 & Juicy Mixer 核心 (2025-10)

| 日期 | 提交 | 事件 |
|------|------|------|
| 10-16 | `3339903` | **项目初始提交** — Juicy 插件框架建立、README |
| 10-16 | `56ca5f8` | Juicy 2D 特效（Shaker）实现 |
| 10-16 | `75238af` | Shaker bug 修复 |
| 10-17 | `06884d9` | **弹簧系统** — Spring、RotationShaker、CameraShaker |
| 10-17 | `e4a5b34` | 弹簧系统完成 |
| 10-19 | `b1a5585` | TimeManager 修复、**Tween V2** 添加 |
| 10-19 | `e3cbaad` | Player 暂停/恢复功能 |
| 10-20 | `227f19c` | Player 循环/方向控制 |
| 10-20 | `aafda55` | 范围控制与 Demo |
| 10-21 ~ 10-22 | 多个 | API 安全机制、类型安全、性能优化 |

## 二、Player V2 架构重构 (2025-10-31 ~ 11-02)

| 日期 | 提交 | 事件 |
|------|------|------|
| 10-31 | `85e909f` | **大规模重构** — JuicyPlayer 架构升级 |
| 11-02 | `7edb75c` | Player V2 EffectList 简化设计文档 |
| 11-02 | `2b7a3b3` | Player V2 **统一配置设计** |

## 三、Bricks 可视化编程系统 (2025-11-03 ~ 2026-03-23)

> Clef 已转移至专用 repo 做发布准备，Bricks 正在重命名为 Fuse（分支 `refactor/bricks-to-fuse`）。

### 3.1 系统诞生 (2025-11)

| 日期 | 提交 | 事件 |
|------|------|------|
| 11-03 | `eb1408e` | **Bricks 系统首次加入项目** |
| 11-03 | `b732219` | Bricks 快速入门指南 |
| 11-04 | 多个 | Instruction 编辑器迭代完善 |

### 3.2 Timeline 编辑器 & Property Track (2025-12 ~ 2026-01)

| 日期 | 提交 | 事件 |
|------|------|------|
| 12-19 | `289d168` | Timeline Canvas 增强计划 |
| 01-07 | `22b22fb` | **Property Track Curve 模式** Phase 1 完成 |
| 01-07 | `9ba4599` | **Property Track Bake 系统** Phase 2 完成（Curve <-> Keyframes） |
| 01-07 | `3c35b3e` | **Property Track 时间范围可视化和拖拽交互** Phase 3A |
| 01-08 | `dfb88ec` | **Property Track Inspector UI 优化** Phase 3B |
| 01-09 | `8d69e7b` | 轨道删除双重删除 bug 修复 |
| 01-10 | `2c1e070` | 多轨道同时更新同一属性 + UI 优化 |
| 01-11 | `f82b06d` | **Method Track 增强** — 继承级别过滤、Getter 过滤、动态参数生成 |
| 01-12 | `a734005` | **TargetHighlightManager** 创建 |
| 01-12 | `cd46662` | **Canvas 目标标记绘制**（forward_canvas_draw_pre_gui） |
| 01-12 | `3400a51` | 场景树高亮功能（Phase 3） |
| 01-14 | `17c8664` | **Method Track 交互增强** 完成 |

### 3.3 Audio Manager 系统 (2026-01-14 ~ 01-15)

| 日期 | 提交 | 事件 |
|------|------|------|
| 01-14 | `aad2881` | AudioVariant 资源类 |
| 01-14 | `8132ace` | DuckingRule 资源 |
| 01-14 | `6a5a26f` | AudioMixingConfig 资源 |
| 01-14 | `e918ab2` | AudioVariationManager |
| 01-14 | `fb8d9c6` | AudioMixingController |
| 01-14 | — | **Audio Manager Phase 1 完成**（7+ 资源类） |
| 01-15 | `6085dfa` | 扩展为 7 种淡出策略 |
| 01-15 | `1f58a48` | 相位保护机制（防高频音效相位抵消） |

### 3.4 性能优化集中重构 (2026-01-23)

| 日期 | 提交 | 事件 |
|------|------|------|
| 01-23 | `abd2bcb` | ActionRunner 信号连接内存泄漏修复 + Callable 缓存 |
| 01-23 | `350c439` | SignalManager LRU 缓存过期机制 |
| 01-23 | `eb06b8a` | VariableContainer 统一存储 Phase 1-2 |
| 01-23 | `ba32550` | VariableContainer 统一存储 Phase 3-5 |
| 01-23 | `6a8d405` | BaseVariable 持久化序列化改进 |
| 01-23 | `7acfecb` | ExecutionContext StringName 缓存大小限制 |
| 01-23 | `a2967f7` | BaseCondition 缓存哈希机制完善 |

### 3.5 条件系统 & 国际化 (2026-01-30 ~ 01-31)

| 日期 | 提交 | 事件 |
|------|------|------|
| 01-30 | `24b11d8` | **Phase 2 全部 14 个条件实现完成** |
| 01-30 ~ 01-31 | 多个 | **全面 i18n 本地化** — 指令、条件、触发器、ActionRunner、ExecutionContext |
| 01-31 | `c58273d` | 核心类本地化完成总结 |

### 3.6 RuntimeEventInstance & 作用域变量 (2026-02)

| 日期 | 提交 | 事件 |
|------|------|------|
| 02-03 | `7b3d2d3` | **RuntimeEventInstance 架构** — mouse_enter/exit 状态完全隔离 |
| 02-03 | `93f1ed9` | JuicyTimelineDriver 状态隔离迁移 |
| 02-03 | `543ad50` | JuicyShakeDriver 噪声生成器状态污染修复 |
| 02-05 | `c5da61a` | Bricks 系统全面审查与修复 |
| 02-05 | `21bc6a5` | Brickian 演示游戏 + Galaxian 设计方案 |
| 02-06 | `be9b0c2` | CrossfadeToMusic 指令（平滑音乐过渡） |
| 02-09 | `a043130` | **ScopeVariableContainer 作用域变量系统 Phase 1 完成** |
| 02-09 | `df7952c` | ExecutionContext 作用域变量集成 |
| 02-09 | `0d01973` | 作用域变量指令和条件 |
| 02-09 | `d6011b6` | **ScopeVariableContainer 编辑器集成 Phase 4 完成** |

### 3.7 Runner 节点 & RuntimeInstructionInstance (2026-03-09 ~ 03-10)

| 日期 | 提交 | 事件 |
|------|------|------|
| 03-09 | `1395e23` | Runner 节点设计文档 |
| 03-09 | `b48b7e4` | **Runner 节点实现**（含完整测试覆盖） |
| 03-09 | `6b4e05a` | 字典操作指令（DictSetByPath 等） |
| 03-10 | `8812205` | **19 条指令迁移到 RuntimeInstructionInstance 架构** |
| 03-13 | `021faaf` | **Phase 3 指令编译缓存优化** |
| 03-13 | `87cdb6f` | 对象池场景 Event 资源共享状态覆盖修复 |

### 3.8 编辑器增强 & 表达式系统 (2026-03-14 ~ 03-21)

| 日期 | 提交 | 事件 |
|------|------|------|
| 03-14 | `366b9f8` | **TriggerMerger** 核心模块 |
| 03-14 | `eea4b59` | Godot 4.6 EditorContextMenuPlugin 适配 |
| 03-16 | `5798fc5` | **TriggerSplitter** 拆分功能 |
| 03-16 | `c5c0a58` | MathExpression 指令 |
| 03-17 | `29096a3` | 变量绑定支持 |
| 03-17 | `b7af01f` | Property 指令生成器（GET/SET） |
| 03-18 | `4f9ab15` | **ExpressionHelper** 共享工具（GameExprHelper） |
| 03-18 | `6bb74a4` | **ExpressionCondition** 布尔表达式求值 |
| 03-18 | `de168ac` | **StringExpression** 字符串格式化指令 |
| 03-19 | `f6b259c` | **断点系统** |
| 03-21 | `e46ec44` | 反射系统优化（Callable 缓存、统一缓存策略、参数绑定抽象） |
| 03-21 | `f73ce4f` | NodePath 显示名称优化 |

### 3.9 Bricks → Fuse 重命名 (2026-03-23 ~ )

| 日期 | 提交 | 事件 |
|------|------|------|
| 03-23 | `f5af360` | **Bricks-to-Fuse 重命名计划文档** |
| 03-24 | `628c357` | ResourceUID 替代 load()、编辑器级联加载修复 |

## 四、Clef MIDI/音乐系统 (2026-03-24 ~ 03-29)

> Clef 已转移至专用 repo 做发布准备，以下为项目内的完整开发历程。

### 4.1 MIDI 引擎 (2026-03-24 ~ 03-26)

| 日期 | 提交 | 事件 |
|------|------|------|
| 03-24 | `bfef2e5` | MIDI Composer 编辑器插件 |
| 03-24 | `dae2c61` | MidiResource, NoteResource, TrackResource 类型 |
| 03-24 | `7833d7a` | MidiReader（.mid 文件解析） |
| 03-24 | `11f9cb0` | EditorImportPlugin（.mid 文件导入） |
| 03-24 | `41465eb` | SF2 解析器、数据结构、乐器库 |
| 03-24 | `c009998` | SynthVoice, VoiceManager, MidiStreamPlayer |
| 03-25 | `45b2cea` | **实时 MIDI 播放 + SF2 合成** |
| 03-25 | `cb1002f` | CC 和 Pitch Bend 数据管道支持 |
| 03-25 | `b6a3580` | SynthVoice 添加 pan、pitch bend、modulation |
| 03-25 | `501782a` | **midi_composer 重命名为 clef** |
| 03-25 | `98e461d` | Clef JSON v1.1（CC, Pitch Bend, Tempo） |
| 03-25 | `cc16cb1` | MidiStreamPlayer 重写为 AudioStreamPlayer pool 架构 |
| 03-26 | `4a54aba` | 立体声 SF2 交织 AudioStreamWAV 生成 |
| 03-26 | `b15a4d1` | MidiWriter 支持 tempo_events |
| 03-26 | `56f1579` | Export MIDI/JSON & Import JSON/MIDI 编辑器菜单 |
| 03-26 | `48d19f0` | **Clef JSON v2.0** — beats-based 时间单位 |

### 4.2 Clef-Compose AI 作曲 (2026-03-26 ~ 03-29)

| 日期 | 提交 | 事件 |
|------|------|------|
| 03-26 | `c832111` | **多 Agent 管线** — Composer / Harmonist / Rhythmist / Reviewer |
| 03-26 | `fbbba6b` | Composer 旋律连续性约束 |
| 03-27 | `4454b44` | 简谱优先工作流 + 交互采样 |
| 03-27 | `5171e63` | 全部 4 个 Agent 自检清单 |
| 03-27 | `025a502` | 原子编辑（section + track 级别反馈） |
| 03-27 | `b6f1d22` | 移除单 Agent 模式，多 Agent 作为默认 |
| 03-28 | `0ab4970` | **v2 ABC 管线重写** — 全部 Agent 迁移到 ABC 输出 |
| 03-28 | `b6ee5f6` | ABC to MIDI 转换器 |
| 03-28 | `0064df7` | ABC 合并脚本（measure 对齐） |
| 03-28 | `50a3c1d` | music21 ABC 验证脚本 |
| 03-28 | `2d0888a` | mido 表情注入脚本 |
| 03-28 | `1cb72e8` | **E2E 管线集成测试** |
| 03-28 | `6d011c7` | 便携 Python 构建（统一 CLI + PyInstaller） |
| 03-29 | `66c9c3b` | **snapshot.py 版本管理 + step 日志** |
| 03-29 | `d970ada` | 专家评审修复（leader limits, import, gen order） |
