# Bricks 性能调查报告：Brickian 子弹系统

**日期**: 2026-03-12
**状态**: 调查进行中
**影响场景**: `demos/bricks/brickian/`

## 问题描述

在 Brickian 游戏中，当 `RandomFireOnInterval` 的间隔降到 ~0.2 秒时，出现以下问题：

| 指标 | 正常值 | 问题值 |
|------|--------|--------|
| FPS | 60 | 15 |
| Physics Time | ~8ms | 16-26ms |
| Node Count | ~100 | 372 |

## 已修复的问题

### 1. 信号重复触发问题 ✅

**症状**: 每次回收 enemy bullet 时，日志输出会越来越多

**根本原因**: `OnArea2DEnter` 事件中，`_area_node` 是共享的成员变量。当多个 Trigger 实例使用同一个 Event 资源时，后一个实例会覆盖前一个的引用。

**修复位置**: `addons/bricks/events/physics/on_area_2d_enter.gd`

**修复方案**:
```gdscript
# 之前：共享的成员变量
var _area_node: Area2D

# 之后：每个 owner 独立存储
var _signal_connections: Dictionary = {}  # key: owner_id, value: { "area_node": Area2D, ... }
```

**关键代码**:
- `initialize_with_runtime_instance()` 中存储每个 owner 的 area_node
- `terminate()` 和 `_disconnect_all_signals_for_owner()` 使用存储的引用
- `trigger.gd` 中 `pool_reset()` 添加 `event_definition.terminate(self)` 调用

### 2. pool_reset() 未断开信号 ✅

**症状**: 对象池回收后重新使用时，旧的信号连接仍然存在

**根本原因**: `pool_reset()` 重置对象时没有先调用 `terminate()` 断开信号

**修复位置**: `addons/bricks/core/trigger.gd`

**修复代码**:
```gdscript
func pool_reset() -> void:
    reset()
    # ... 其他初始化 ...

    if event_definition:
        # 🔧 关键修复：先调用 terminate() 断开所有信号连接
        event_definition.terminate(self)

        if _runtime_event_instance:
            _runtime_event_instance.cleanup()
        # ... 继续初始化
```

## 新增性能追踪工具

为了定位剩余的性能问题，创建了性能追踪系统。

### 文件结构

```
addons/bricks/utils/
└── performance_tracker.gd  # 新建：BricksPerformanceTracker 单例

demos/bricks/brickian/
└── game_scene_performance.gd  # 新建：键盘快捷键控制
```

### 使用方法

| 快捷键 | 功能 |
|--------|------|
| P | 打印性能报告 |
| R | 重置追踪数据 |
| O | 切换详细日志模式 |

### 追踪位置

在以下关键位置添加了性能追踪：

| 文件 | 追踪项 | 目的 |
|------|--------|------|
| `on_physics_process.gd` | `OnPhysicsProcess.on_physics_process` | 每帧物理处理开销 |
| `on_physics_process.gd` | `OnPhysicsProcess._trigger_event` | 事件触发开销 |
| `recycle_pooled_scene.gd` | `RecyclePooledScene.execute` | 回收指令执行开销 |
| `bricks_pool_manager.gd` | `BricksPoolManager.recycle_pooled` | 池回收总开销 |
| `bricks_pool_manager.gd` | `BricksPoolManager._find_pool_by_instance_id` | 池查找开销 |

## 已确认的性能瓶颈 ✅

### 根本原因：OnPhysicsProcess 每帧执行

**位置**: `demos/bricks/brickian/enemy_bullet.tscn` 第 500-505 行

```tscn
[sub_resource type="Resource" id="Resource_4eqq1"]
script = ExtResource("8_yyfim")  # OnPhysicsProcess
log_level = 0
# ❌ 缺少 execution_interval = 0.0，意味着每帧都执行！
```

**问题分析**：
- 每个子弹每帧执行 **4 个指令**：
  1. 检查变量 `velocity != (0, 0)`
  2. 获取 `delta_time`
  3. 向量缩放 `velocity * delta`
  4. 相对移动子弹
- 每次 `_trigger_event` 需要 **440μs**
- 342 节点 × 4 指令 × 60 FPS = **82,080 次/秒**
- 每帧总时间：342 × 0.45ms = **153.9ms**（远超 16.67ms 帧预算！）

**性能数据**：
| 操作 | 平均耗时 | 调用次数 | 总耗时 |
|------|----------|----------|--------|
| `OnPhysicsProcess.on_physics_process` | **450.73μs** | 6242 | **2813.47ms** |
| `OnPhysicsProcess._trigger_event` | **440.28μs** | 6242 | **2748.21ms** |
| `RecyclePooledScene.execute` | 115.60μs | 35 | 4.05ms |
| `BricksPoolManager.recycle_pooled` | 72.69μs | 35 | 2.54ms |

## 已排除的嫌疑 ✅

1. **`OnIntervalWithVariable._get_next_interval`** - 平均 31μs，非常快，不是瓶颈
2. **池查找逻辑** - 平均 16μs，非常快，不是瓶颈
3. **池回收操作** - 平均 72μs，可接受
4. **物理碰撞检测** - Physics Time 12ms，正常范围

### 性能数据（interval=0.2s, ~350 节点）

```
=== Performance Tracker Report ===

OnIntervalWithVariable._get_next_interval: calls=137, avg=31.10μs

=== System Stats ===
FPS: 60
Process Time: 6.76ms
Physics Time: 15.40ms
Node Count: 369
```

**观察**: 当前条件下 FPS 稳定在 60，问题可能在更极端条件（interval<1.2s, node>400）下出现。

## 优化方案

### 方案 1：使用 Godot 内置物理移动（推荐）✨

将子弹从 `Area2D` 改为 `CharacterBody2D`，使用内置的 `velocity` + `move_and_slide()`。

**优点**：
- 引擎级别优化，性能最佳
- 自动处理碰撞
- 代码简洁

**缺点**：
- 需要修改场景结构
- 可能影响现有碰撞逻辑

### 方案 2：使用 Tween 代替每帧计算

在 `OnReady` 时创建一个 Tween 动画，让子弹朝着目标方向移动。

**优点**：
- 无需修改场景结构
- Tween 由引擎优化，比每帧指令高效
- 可以设置动画时长 = 子弹生命周期

**缺点**：
- 不能动态改变方向
- 需要额外指令支持

### 方案 3：设置 execution_interval（快速修复）

为 `OnPhysicsProcess` 设置 `execution_interval` 属性：

```tscn
[sub_resource type="Resource" id="Resource_4eqq1"]
script = ExtResource("8_yyfim")
execution_interval = 0.033  # 约 30FPS
log_level = 0
```

**优点**：
- 最小改动
- 立即生效

**缺点**：
- 仍然每帧执行，只是频率降低
- 移动会变得卡顿

### 方案 4：添加子弹生命周期限制

添加 `RecycleAfterDelay` 指令或使用 `OnTimer` 事件，在 5 秒后自动回收子弹。

**优点**：
- 防止子弹无限堆积
- 减少同时存在的子弹数量

**缺点**：
- 不解决根本问题
- 需要新指令支持

## 建议的修复顺序

1. **立即**：设置 `execution_interval = 0.016`（快速缓解）
2. **短期**：添加子弹生命周期限制（5秒超时）
3. **长期**：重构为 Tween 或 CharacterBody2D 方案

## 修改文件清单

| 文件 | 修改类型 | 说明 |
|------|----------|------|
| `addons/bricks/core/trigger.gd` | 修改 | pool_reset() 添加 terminate() 调用 |
| `addons/bricks/events/physics/on_area_2d_enter.gd` | 修改 | 信号连接改为每个 owner 独立存储 |
| `addons/bricks/utils/performance_tracker.gd` | 新建 | 性能追踪工具类 |
| `demos/bricks/brickian/game_scene_performance.gd` | 新建 | 键盘快捷键控制 |
| `addons/bricks/events/lifecycle/on_physics_process.gd` | 修改 | 添加性能追踪 |
| `addons/bricks/instructions/node_operations/recycle_pooled_scene.gd` | 修改 | 添加性能追踪 |
| `addons/bricks/core/pooling/bricks_pool_manager.gd` | 修改 | 添加性能追踪 |

## 结论

**已确认的性能瓶颈**：`OnPhysicsProcess` 每帧执行 4 个指令，当子弹数量超过 300 时，每帧总开销超过 150ms，远超帧预算。

**池化系统不是问题**：回收操作平均 72μs，池查找平均 16μs，都非常快。

**建议**：
1. 优先使用方案 3（设置 `execution_interval`）快速缓解
2. 后续重构为方案 1（CharacterBody2D）或方案 2（Tween）

## 测试方法

1. 运行 Brickian 游戏场景
2. 等待子弹开始发射
3. 按 **O** 开启详细日志
4. 按 **P** 打印性能报告
5. 观察不同 interval 下的性能变化
