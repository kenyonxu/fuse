# Fuse 多线程优化 - 用户指南

## 这是什么？

Fuse 插件现在可以并行执行条件检查。如果你的触发器有很多条件，游戏会更流畅。

## 如何启用

默认已启用。在 MultiEventTrigger 的 Inspector 中：

```
Use Parallel Condition Evaluation: ✓
```

就这样。系统会自动处理剩下的事情。

## 什么时候有用？

触发器有多个条件时。比如：

```
触发器 "打开宝箱"
├── 条件 1: 玩家有钥匙？
├── 条件 2: 宝箱未锁定？
├── 条件 3: 玩家距离足够近？
└── 条件 4: 游戏状态允许？
```

以前这些条件一个接一个检查。现在可以同时检查，更快。

## 性能提升

条件越多，并行收益越明显——两位数的条件并行评估通常能把判断耗时压到串行的几分之一，上百个条件时差距进一步拉开。条件很少时收益有限（线程调度本身有开销），但也不会更慢。

## 场景预加载

### 问题

场景切换时卡顿？因为 Godot 在加载场景。

### 解决方案

提前在后台加载场景：

1. 添加 `Preload Scene` 指令到触发器
2. 设置要加载的场景路径
3. 游戏运行时，场景在后台加载
4. 需要时直接实例化，无需等待

### 使用方法

```
触发器 "进入区域"
├── 事件: Area2D body_entered
├── 指令:
│   └── Preload Scene
│       └── Scene: res://scenes/boss_fight.tscn
│       └── Mode: Async Later
```

然后在另一个触发器中检查加载状态：

```
触发器 "开始 Boss 战"
├── 事件: Timer timeout
├── 条件:
│   └── Check Preload Status
│       └── Scene: res://scenes/boss_fight.tscn
│       └── Expected: Loaded
└── 指令:
    └── Change Scene → boss_fight.tscn
```

场景瞬间切换，无卡顿。

## 配置选项

在项目设置中找到 `FuseThreadingConfig`：

| 选项 | 默认值 | 说明 |
|------|--------|------|
| Enable Multithreading | ✓ | 全局开关 |
| Parallel Condition Evaluation | ✓ | 并行评估条件 |
| Max Parallel Conditions | 8（上限 16） | 并行度上限——同时进入工作线程的最大条件数 |
| Timeout Per Condition | 0.1s | 单个条件的超时时间 |
| Enable Resource Preload | ✓ | 启用场景预加载 |

## 常见问题

### 游戏变慢了？

先确认是条件评估的问题（Topology 面板 / 变量监视器定位耗时点）。如果是，按需调整：调低 `Max Parallel Conditions`（并行度过高时线程调度开销可能吃掉收益），或直接关掉 `Parallel Condition Evaluation` 开关整体回退串行——两个开关随时可切换，不影响逻辑正确性。

### 某些条件不执行？

可能该条件不是"线程安全"的。系统会自动识别：

- ✅ 线程安全：检查变量值、数学运算
- ❌ 不安全：访问节点、获取父节点

不安全的条件会在主线程执行，不影响功能。

### 场景加载超时？

增加预加载超时时间：

```
Preload Timeout: 30.0  （30秒）
```

大场景需要更长时间加载。

## 兼容性

- Godot 4.7+
- 不影响现有项目
- 可随时关闭多线程功能
- 所有旧触发器继续正常工作

## 技术细节

想知道更多？查看 [开发者指南](../../dev_docs/guides/multithreading-developer-guide.md)。
