> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/00-index.md) | English

# Fuse User Guides Index

> **Goal**: The navigation entry point for all user guides, grouped by use case to help you quickly locate the documents you need.

**Audience**: Fuse plugin users

**Last updated**: 2026-09-02

---

## 📖 How to Use

- Guides are organized into **numbered sections**: `00-0x` getting started ∥ `1x-2x` core systems ∥ `25-26` debugging ∥ `3x` events ∥ `4x` conditions ∥ `5x` advanced topics
- For recommended reading paths, see [Recommended Learning Paths](#-recommended-learning-paths) at the end of this page
- Developer documentation (component creation, architecture principles) lives in the [dev_docs/](../../dev_docs) directory

---

## 🚀 Getting Started (00-07)

First time with Fuse? Start here: meet the panels, variables, and the trigger trio.

| No. | Guide | Summary |
|------|------|----------|
| 00 | [Editor Panels Overview](00-editor-panels-overview.md) | A tour of Fuse's editor panels / Inspector entry points |
| 01 | [Fuse Variables Guide](01-variable-system-guide.md) | The LOCAL/SCOPE/GLOBAL three-layer variable system |
| 02 | [Trigger Selection Guide](02-trigger-selection-guide.md) | How to choose between Runner, Trigger, and MultiEventTrigger |
| 03 | [Runner Guide](03-runner-guide.md) | Signal-binding triggers |
| 04 | [MultiEventTrigger Guide](04-multi-event-trigger-guide.md) | Multi-event combined triggers |
| 05 | [Expression System Guide](05-expression-guide.md) | Writing dynamic expressions in instruction parameters |
| 06 | [Instruction Generator Guide](06-instruction-generator-guide.md) | Scaffold custom instructions quickly with the generator |
| 07 | [Variable Binding Guide](07-variable-binding-guide.md) | Direct value / variable dual-track instruction parameters |

---

## 🧩 Core Systems (10-24)

Detailed guides for each instruction category: transform, movement, animation, audio, physics, UI, data operations, and flow control.

| No. | Guide | Summary |
|------|------|----------|
| 10 | [Transform System Guide](10-transform-guide.md) | Position/rotation/scale instructions |
| 11 | [Fuse Movement System Guide](11-movement-system-guide.md) | Character movement and pathfinding |
| 12 | [Animation System Guide](12-animation-guide.md) | AnimationPlayer control |
| 13 | [Audio System Guide](13-audio-guide.md) | Sound/music playback and buses |
| 14 | [Physics System Guide](14-physics-guide.md) | Rigid bodies/collisions/raycasting |
| 15 | [UI System Guide](15-ui-guide.md) | Control manipulation and interface logic |
| 16 | [Camera System Guide](16-camera-guide.md) | Camera switching and following |
| 17 | [Scene Management Instructions Guide](17-scene-management-guide.md) | Scene switching/loading/unloading |
| 18 | [Tween Animation Guide](18-tween-animation-guide.md) | Programmatic tween animations |
| 20 | [Node Operations Instructions Guide](20-node-operations-guide.md) | Node add/remove/properties/calls |
| 21 | [Array Operations Guide](21-array-operations-guide.md) | Array read/write and iteration |
| 22 | [Dictionary Operations Guide](22-dictionary-operations-guide.md) | Dictionary read/write and merging |
| 23 | [Flow Control Guide](23-flow-control-guide.md) | If/Else, loops, waits |
| 24 | [Math/Vector Instructions Guide](24-math-vector-guide.md) | Math operations and vector computation |

---

## 🔍 Debugging (25-26)

| No. | Guide | Summary |
|------|------|----------|
| 25 | [Debugging System Guide](25-debugging-guide.md) | Logging, execution tracing, and diagnostics |
| 26 | [Breakpoint Instructions Guide](26-breakpoint-guide.md) | Setting breakpoints in instruction chains |

> For live variable monitoring, see the [Variable Watcher Guide](56-variable-watcher-guide.md) under Advanced Topics.

---

## ⚡ Events (30-34)

Events are what set a Trigger off, deciding "when to execute".

| No. | Guide | Summary |
|------|------|----------|
| 30 | [Lifecycle Events Guide](30-lifecycle-events-guide.md) | Ready/enter tree/exit and other lifecycle events |
| 31 | [Timing Events Guide](31-timing-events-guide.md) | Interval/delay/timed triggering |
| 32 | [Input Events Guide](32-input-events-guide.md) | Keyboard/mouse/gamepad input triggering |
| 33 | [Node Events Guide](33-node-events-guide.md) | Node signal events |
| 34 | [Event Bus Guide](34-event-bus-guide.md) | Decoupled communication over a global event bus |

---

## ✅ Conditions (40-46)

Conditions decide "whether to execute" and can be combined into composite conditions.

| No. | Guide | Summary |
|------|------|----------|
| 40 | [Input Conditions Guide](40-input-conditions-guide.md) | Input state checks |
| 41 | [Node Conditions Guide](41-node-conditions-guide.md) | Node state/property checks |
| 42 | [Physics Conditions Guide](42-physics-conditions-guide.md) | Collision/area detection checks |
| 43 | [Animation Conditions Guide](43-animation-conditions-guide.md) | Animation playback state checks |
| 44 | [Time Conditions Guide](44-time-conditions-guide.md) | Time/cooldown checks |
| 45 | [Composite Conditions Guide](45-composite-conditions-guide.md) | AND/OR/NOT combined conditions |
| 46 | [Comprehensive Conditions Collection](46-comprehensive-conditions-guide.md) | A comprehensive reference for the condition system |

---

## 🏗️ Advanced Topics (50-57)

Performance optimization, asset reuse, and deep customization.

| No. | Guide | Summary |
|------|------|----------|
| 50 | [Scene Preloading System](50-scene-preloading-guide.md) | Preload scene resources in the background |
| 51 | [Fuse Object Pool System Guide](51-object-pool-system-guide.md) | Performance optimization for high-frequency instantiation |
| 52 | [Fuse Multithreading Optimization - User Guide](52-multithreading-optimization.md) | Multithreaded execution configuration |
| 53 | [Fuse Icon Manager Guide](53-icon-manager-guide.md) | Built-in/custom icon system |
| 54 | [Global Variables Management Guide](54-global-variables-guide.md) | Global variable persistence and saving |
| 55 | [Preset System Guide](55-preset-system-guide.md) | Workflow export/import/reuse |
| 56 | [Variable Watcher Guide](56-variable-watcher-guide.md) | Live variable monitoring/editing/line charts |
| 57 | [Graduation Exporter Guide](57-graduation-exporter-guide.md) | GDScript export (experimental feature) |

---

## 🎯 Recommended Learning Paths

### Beginner Path (Day 1)

```
00 面板总览 → 01 变量系统 → 02 触发器选型 → 03 Runner → 23 流程控制
```

### Feature Development Path

```
10 变换 → 11 移动 → 12 动画 → 13 音频 → 15 UI → 17 场景管理
                                    ↘ 30-34 事件 ↗
                                    ↘ 40-46 条件 ↗
```

### Advanced Path

```
05 表达式 → 45 复合条件 → 34 Event Bus → 54 全局变量 → 55 预设系统 → 57 GDScript 导出（实验特性）
```

### Debugging & Troubleshooting Path

```
25 调试系统 → 26 断点 → 56 变量监视器
```

---

## 📚 Developer Documentation Entry Points

To **extend Fuse itself** (create custom instructions/events/conditions, understand the architecture), read the developer documentation:

| Topic | Path |
|------|------|
| Instruction creation | [dev_docs/guides/instruction-creation-guide.md](../../dev_docs/guides/instruction-creation-guide.md) |
| Event creation | [dev_docs/guides/event-creation-guide.md](../../dev_docs/guides/event-creation-guide.md) |
| Condition creation | [dev_docs/guides/condition-creation-guide.md](../../dev_docs/guides/condition-creation-guide.md) |
| Preset system development | [dev_docs/guides/57-preset-system-dev-guide.md](../../dev_docs/guides/57-preset-system-dev-guide.md) |
| Variable watcher development | [dev_docs/guides/58-variable-watcher-dev-guide.md](../../dev_docs/guides/58-variable-watcher-dev-guide.md) |
| Global variables development | [dev_docs/guides/59-global-variables-dev-guide.md](../../dev_docs/guides/59-global-variables-dev-guide.md) |
| Multithreading | [multithreading.md](52-multithreading-optimization.md) |

---

**Maintained by**: Fuse development team
**Last updated**: 2026-09-02
