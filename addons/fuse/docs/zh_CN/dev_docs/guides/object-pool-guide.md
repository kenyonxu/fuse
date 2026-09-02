> 🌐 中文 | [**English**](../../../en_US/dev_docs/guides/object-pool-guide.md)

# Fuse 对象池系统开发指南

> **目标**: 为开发者提供 Fuse 对象池系统的完整开发指引，包括池化管理、场景实例复用、触发器和变量的状态重置。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-07-07

---

## 📋 目录

1. [系统概述](#系统概述)
2. [架构设计](#架构设计)
3. [FuseObjectPool API](#fuseobjectpool-api)
4. [FusePoolItem API](#fusepoolitem-api)
5. [FusePoolManager API](#fusepoolmanager-api)
6. [使用指南](#使用指南)
7. [状态重置机制](#状态重置机制)
8. [性能监控](#性能监控)
9. [最佳实践](#最佳实践)
10. [常见陷阱](#常见陷阱)

---

## 系统概述

对象池系统是 Fuse 中管理场景实例复用的关键基础设施，提供从**单个对象池（FuseObjectPool）**到**全局池管理器（FusePoolManager）**的完整链路。

### 核心文件

| 文件 | 类名 | 用途 |
|------|------|------|
| `core/pooling/fuse_object_pool.gd` | `FuseObjectPool` | 通用对象池，管理单场景的实例池 |
| `core/pooling/fuse_pool_item.gd` | `FusePoolItem` | 池项包装器，跟踪使用状态和效率 |
| `core/pooling/fuse_pool_manager.gd` | `FusePoolManager` | 全局池管理器，统一接口 |
| `core/pooling/instruction_instance_pool.gd` | `InstructionInstancePool` | 指令实例专用池 |

### 设计目标

- **减少实例化开销**: 复用已创建的对象而非频繁 `instantiate()` / `queue_free()`
- **自动扩容/收缩**: 根据使用率动态调整池大小
- **状态重置**: 回收对象时自动重置 Fuse 组件（Trigger、ScopeVariableContainer、ActionRunner）
- **统一管理**: 通过 `FusePoolManager` 单例访问所有池
- **性能追踪**: 集成了 `FusePerformanceTracker` 监控回收性能

---

## 架构设计

```
FusePoolManager (单例 RefCounted)
    │
    │  _scene_pools: Dictionary  {scene_path -> FuseObjectPool}
    │
    ├── FuseObjectPool (场景 A)
    │       ├── FusePoolItem (Node) — in_use = true/false
    │       ├── FusePoolItem (Node)
    │       └── ...
    │
    ├── FuseObjectPool (场景 B)
    │       ├── FusePoolItem (Node)
    │       └── ...
    │
    └── _active_recycle_timers: Array[FuseRecycleTimer]
```

### 实例生命周期

```
1. instantiate_pooled(scene_path)
       │  _get_or_create_pool() → 获取或创建 FuseObjectPool
       ▼
2. pool.get_object()
       │  查找空闲 FusePoolItem → mark_used()
       │  或 加载场景 → 创建新 FusePoolItem → mark_used()
       ▼
3. parent.add_child(instance)
       ▼
4. pool.reset_object(instance)
       │  _reset_fuse_components()  ← 递归重置 Trigger/变量
       ▼
5. 使用中...

6. recycle_pooled(scene_path, instance)
       ▼
7. pool.return_object(obj)
       │  _terminate_fuse_triggers(obj) → 停止物理处理
       │  _schedule_safe_remove(obj)   → 延迟从场景树移除
       │  item.mark_unused()
       ▼
8. 池中待复用
```

---

## FuseObjectPool API

**文件位置**: `addons/fuse/core/pooling/fuse_object_pool.gd`

**类定义**:
```gdscript
class_name FuseObjectPool extends RefCounted
```

### 构造函数

```gdscript
## 创建对象池
## scene_path: 场景文件路径
## initial_size: 初始池大小（默认 20，受 min/max 约束）
func _init(scene_path: String, initial_size: int = 20) -> void
```

### 核心方法

```gdscript
## 从池中获取对象
## 返回: Node — 场景实例，池满且无可用对象时返回 null
func get_object() -> Node

## 归还对象到池中
## obj: 要归还的场景实例
func return_object(obj: Node) -> void

## 重置对象状态（基本属性 + Fuse 组件）
func reset_object(obj: Node) -> void

## 预热池，预先创建 count 个对象
func warm_up(count: int) -> void

## 清空池（释放所有对象）
func clear_pool() -> void
```

### 池配置方法

```gdscript
func set_pool_size(size: int) -> void             # 设置池大小
func set_max_pool_size(size: int) -> void          # 设置最大池大小
func set_min_pool_size(size: int) -> void          # 设置最小池大小
func enable_auto_resize(enabled: bool) -> void     # 启用/禁用自动调整
func set_resize_threshold(threshold: float) -> void # 设置调整阈值(0.1~1.0)
func process_auto_resize() -> void                 # 处理自动扩容/收缩
```

### 统计方法

```gdscript
func get_statistics() -> Dictionary      # 获取统计信息
func get_detailed_status() -> Dictionary # 获取详细状态（含池项明细）
```

统计字典包含：
```
- scene_path, total_created, total_reused
- pool_size, current_usage, unused_count
- peak_usage, reuse_ratio, efficiency_score
- auto_resize, resize_threshold
```

### 内部关键方法

```gdscript
func _load_scene() -> Node                          # 加载并实例化场景
func _reset_fuse_components(node: Node) -> void     # 递归重置 Fuse 组件
func _terminate_fuse_triggers(node: Node) -> void   # 停止所有 Trigger
func _schedule_safe_remove(obj: Node) -> void       # 延迟移除（防物理回调冲突）
func _adjust_pool_size() -> void                    # 调整池大小（移除低效对象）
```

---

## FusePoolItem API

**文件位置**: `addons/fuse/core/pooling/fuse_pool_item.gd`

**类定义**:
```gdscript
class_name FusePoolItem extends RefCounted
```

### 属性

```gdscript
var object: Node         # 池化的对象
var in_use: bool         # 使用标记
var pool_item_id: int    # 唯一 ID（自增）
var created_time: float  # 创建时间戳
var last_used_time: float # 最后使用时间戳
var usage_count: int     # 使用次数统计
```

### 方法

```gdscript
func mark_used() -> void                    # 标记为使用中
func mark_unused() -> void                  # 标记为未使用
func is_valid() -> bool                     # 检查对象是否有效
func is_expired(max_idle_time: float) -> bool  # 检查是否过期
func get_efficiency_score() -> float        # 效率评分 = 使用次数/存在时间
static func compare_by_efficiency(a, b) -> bool  # 排序比较

func get_statistics() -> Dictionary         # 获取统计
func set_debug_logging(enabled: bool, pool_path: String = "") -> void
```

### 效率评分

```gdscript
# 效率 = usage_count / age(秒)
# 用于池收缩时决定保留哪些对象：使用频繁的优先保留
```

---

## FusePoolManager API

**文件位置**: `addons/fuse/core/pooling/fuse_pool_manager.gd`

**类定义**:
```gdscript
class_name FusePoolManager extends RefCounted
```

### 单例

```gdscript
## 获取单例
static func get_instance() -> FusePoolManager
```

### 核心方法

```gdscript
## 从池中实例化场景并添加到父节点
## 返回: Node — 场景实例，失败返回 null
func instantiate_pooled(scene_path: String, parent: Node, pool_config: Dictionary = {}) -> Node

## 从池中获取实例但不添加到场景树（延迟添加）
## 返回: Dictionary — {"instance": Node, "pool": FuseObjectPool}
func get_pooled_instance(scene_path: String, pool_config: Dictionary = {}) -> Dictionary

## 回收场景实例
## 返回: bool — 成功/失败
func recycle_pooled(scene_path: String, instance: Node) -> bool

## 预热场景池
func warm_up_pool(scene_path: String, count: int, pool_config: Dictionary = {}) -> void

## 清理所有池
func clear_all_pools() -> void
```

### 查询方法

```gdscript
func is_instance_in_use(scene_path: String, instance: Node) -> bool  # 检查实例是否使用中
func get_instance_usage_count(scene_path: String, instance: Node) -> int  # 获取使用计数
func get_statistics(scene_path: String = "") -> Dictionary  # 获取统计
func get_detailed_status() -> Dictionary  # 获取详细状态
```

### 池查找策略

`recycle_pooled()` 回收时按以下顺序查找池：

1. 从实例的 `scene_file_path` 获取路径
2. 精确匹配 `_scene_pools` 字典
3. 通过实例 ID 在所有池中查找（`_find_pool_by_instance_id`）
4. 通过文件名匹配（`_find_pool_by_any_path`）

### 注册/注销回收定时器

```gdscript
func register_recycle_timer(timer: FuseRecycleTimer) -> void
func unregister_recycle_timer(timer: FuseRecycleTimer) -> void
```

---

## 使用指南

### 基本使用

```gdscript
# 获取 FusePoolManager 单例
var pool_manager = FusePoolManager.get_instance()

# 从池中实例化场景
var bullet = pool_manager.instantiate_pooled(
    "res://scenes/bullet.tscn",
    get_parent(),
    {"initial_size": 10, "max_size": 50}
)

# 使用后回收
pool_manager.recycle_pooled("", bullet)  # scene_path 为空时自动从实例获取
```

### 预热池

```gdscript
# 在游戏加载时预热
pool_manager.warm_up_pool("res://scenes/enemy.tscn", 20)
```

### 延迟添加到场景树

```gdscript
# 获取实例但不添加到场景树
var result = pool_manager.get_pooled_instance("res://scenes/particle.tscn")
if result.has("instance"):
    var particle = result["instance"]
    # 在合适的时机添加
    call_deferred("add_child", particle)
```

---

## 状态重置机制

`reset_object()` 和 `_reset_fuse_components()` 负责将对象还原到初始状态。

### 基础属性重置

```gdscript
# Node2D
obj.position = Vector2.ZERO
obj.rotation = 0.0
obj.scale = Vector2.ONE
obj.visible = true

# Node3D
obj.position = Vector3.ZERO
obj.rotation = Vector3.ZERO
obj.scale = Vector3.ONE
obj.visible = true

# 物理体
obj.set_linear_velocity(Vector2.ZERO / Vector3.ZERO)
obj.set_angular_velocity(0.0)

# 颜色
obj.modulate = Color.WHITE
obj.self_modulate = Color.WHITE
```

### Fuse 组件递归重置

```gdscript
# 遍历节点树：
# 1. Trigger → pool_reset() 或 reset()
# 2. MultiEventTrigger → pool_reset() 或 reset()
# 3. ScopeVariableContainer → 保存/恢复 _pool_default_variables
```

### 回收时的 Trigger 终止

```gdscript
# return_object() 中：
# 1. _terminate_fuse_triggers(obj)
#    - 停止物理处理 (set_physics_process(false))
#    - 调用 event_definition.terminate(trigger)
# 2. _schedule_safe_remove(obj) — 延迟一帧移除
```

---

## 性能监控

### 自动扩容/收缩

```gdscript
# 使用率 > 80% → 池大小 * 2（自动扩容）
# 使用率 < 40% → 池大小 / 2（自动收缩）
# 收缩时按效率评分排序，移除低频对象
```

### 统计指标

```gdscript
# 关键指标
reuse_ratio = total_reused / total_created
efficiency_score = 重用率*0.4 + 利用率*0.3 + 峰值率*0.2
```

### 调试日志

```gdscript
pool_manager.set_debug_logging(true)
# 输出：创建、重用、回收、扩容等事件
```

---

## 最佳实践

### 1. 根据实例类型选择初始池大小

```gdscript
# 频繁创建的对象（如子弹）→ 较大的初始池
pool_cfg = {"initial_size": 30, "max_size": 100}

# 低频使用的对象 → 较小的初始池
pool_cfg = {"initial_size": 5, "max_size": 20}
```

### 2. 在加载阶段预热

```gdscript
# 场景加载时预热，避免运行时卡顿
pool_manager.warm_up_pool("res://scenes/enemy_wave.tscn", 10)
```

### 3. 保持场景树中的 Trigger 清洁

对象池回收时自动终止 Trigger，确保离开场景树的 Trigger 不会继续发射事件。

### 4. 利用 UID 路径

`res://` 和 `uid://` 路径都可管理池。`recycle_pooled()` 支持自动从实例 `scene_file_path` 获取路径。

---

## 常见陷阱

### 陷阱 1：在物理回调中回收对象

**问题**: `_physics_process()` 中直接 `remove_child()` 会导致状态混乱。

**解决方案**: `_schedule_safe_remove()` 使用 `SceneTreeTimer` 延迟一帧移除。

### 陷阱 2：对象未重置导致状态残留

**问题**: 复用的对象保留上次使用的状态（位置、可见性、Trigger 激活）。

**解决方案**: `reset_object()` 调用 `_reset_fuse_components()` 递归重置所有 Fuse 组件。

### 陷阱 3：池查找失败

**问题**: 调用 `recycle_pooled()` 时找不到对应的池。

**解决方案**: 使用 `_find_pool_by_instance_id()` 作为回退策略。如果传入的 `scene_path` 与创建时路径不一致，会自动从实例 `scene_file_path` 获取。

### 陷阱 4：扩容无上限

**问题**: `auto_resize` 启用时，高峰期间的池大小可能无限增长。

**解决方案**: 始终设置合理的 `max_pool_size` 上限。

---

## 参考文档

- [ActionRunner 开发指南](action-runner-guide.md)
- [RuntimeInstructionInstance 指南](runtime-instruction-instance-guide.md)
- [ExecutionContext 与 Diagnostics 指南](execution-context-diagnostics-guide.md)

---

**文档维护**: Fuse 开发团队 | **最后更新**: 2026-07-07 | **Godot 版本**: 4.7
