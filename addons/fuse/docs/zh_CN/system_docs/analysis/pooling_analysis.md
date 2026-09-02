# 对象池体系分析报告


> **分析时点**：2026-07-07（经同日全量文档审计逐篇核对代码；此后实现演进以源码为准，近期已核对的机制性结论见 threading / runtime_instance / preset_nested 等篇）
## 文档概述

本报告对 Fuse 可视化编程系统中的对象池子系统进行现状描述。对象池位于 `core/pooling/`，由 5 个类组成：通用场景池 (`FuseObjectPool`)、池项包装 (`FusePoolItem`)、全局池管理器 (`FusePoolManager`)、专用回收定时器 (`FuseRecycleTimer`)，以及面向 `RuntimeInstructionInstance` 的指令实例池 (`InstructionInstancePool`)。两套池体系分别服务于"场景节点复用"（如子弹、特效）与"指令运行时实例复用"（高频执行路径的内存优化），各自有独立的池策略、生命周期与协作对象。

**源目录:** [core/pooling/](../../../../core/pooling/)
**类数量:** 5
**总行数:** 1498 行
**集成方:** `RuntimeActionRunnerInstance`（指令实例池）、`instantiate_scene`/`recycle_pooled_scene`/`warm_up_pool` 指令（场景池）

---

## 1. 类清单与职责

| 类名 | 文件 | 行数 | 基类 | 职责 |
|------|------|------|------|------|
| `FusePoolItem` | [fuse_pool_item.gd](../../../../core/pooling/fuse_pool_item.gd) | 140 | `RefCounted` | 池项包装器，跟踪单个对象的 in_use/usage_count/时间戳，提供效率评分与过期检测 |
| `FuseObjectPool` | [fuse_object_pool.gd](../../../../core/pooling/fuse_object_pool.gd) | 597 | `RefCounted` | 通用场景对象池，负责单一场景路径的实例创建/复用/回收/重置/收缩 |
| `FusePoolManager` | [fuse_pool_manager.gd](../../../../core/pooling/fuse_pool_manager.gd) | 528 | `RefCounted` | 全局单例，按 `scene_path` 索引多个 `FuseObjectPool`，提供 `instantiate_pooled`/`recycle_pooled` 入口，多策略路径匹配，管理回收定时器生命周期 |
| `FuseRecycleTimer` | [fuse_recycle_timer.gd](../../../../core/pooling/fuse_recycle_timer.gd) | 148 | `Node` | 专用延迟回收定时器，弱引用实例 + usage_count 一致性校验 + 多重"已被回收"检测，超时后回调管理器回收 |
| `InstructionInstancePool` | [instruction_instance_pool.gd](../../../../core/pooling/instruction_instance_pool.gd) | 185 | `RefCounted` | `RuntimeInstructionInstance` 专用池，通过 `acquire`/`release` 配合 `reinitialize`/`reset_for_pool` 实现高频执行路径复用 |

---

## 2. 核心属性

### 2.1 FuseObjectPool（[fuse_object_pool.gd:7-23](../../../../core/pooling/fuse_object_pool.gd)）

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `_pool_items` | `Array[FusePoolItem]` | `[]` | 池项集合 |
| `_scene_path` | `String` | `""` | 绑定的场景路径 |
| `_pool_size` | `int` | `20` | 目标池大小 |
| `_max_pool_size` | `int` | `100` | 池容量上限 |
| `_min_pool_size` | `int` | `5` | 池容量下限 |
| `_auto_resize` | `bool` | `true` | 是否启用自动扩缩容 |
| `_resize_threshold` | `float` | `0.8` | 使用率扩容阈值 |
| `_total_created/_total_reused/_peak_usage/_cleanup_count` | `int` | `0` | 统计计数 |
| `_enable_debug` | `bool` | `false` | 调试日志开关 |

### 2.2 FusePoolItem（[fuse_pool_item.gd:8-30](../../../../core/pooling/fuse_pool_item.gd)）

| 属性 | 类型 | 说明 |
|------|------|------|
| `object` | `Node` | 池化的对象引用 |
| `in_use` | `bool` | 使用中标记 |
| `pool_item_id` | `int` | 唯一 ID（`_next_id` 静态自增，从 1 开始） |
| `created_time` / `last_used_time` | `float` | 时间戳（秒） |
| `usage_count` | `int` | 被标记使用的累计次数 |
| `_next_id`（static） | `int` | 全局 ID 生成器 |

### 2.3 FusePoolManager（[fuse_pool_manager.gd:7-23](../../../../core/pooling/fuse_pool_manager.gd)）

| 属性 | 类型 | 说明 |
|------|------|------|
| `_instance`（static） | `FusePoolManager` | 单例实例（通过 `get_instance()` 懒加载） |
| `_scene_pools` | `Dictionary` | `scene_path → FuseObjectPool` 索引表 |
| `_active_recycle_timers` | `Array[FuseRecycleTimer]` | 活动定时器强引用集合（防止 RefCounted 提前释放） |
| `_enable_debug` | `bool` | 调试日志开关 |

### 2.4 FuseRecycleTimer（[fuse_recycle_timer.gd:9-25](../../../../core/pooling/fuse_recycle_timer.gd)）

| 属性 | 类型 | 说明 |
|------|------|------|
| `scene_path` | `String` | 关联场景路径 |
| `_instance_weak_ref` | `WeakRef` | 实例弱引用（避免循环引用） |
| `_creation_usage_count` | `int` | 创建时记录的 usage_count，用于检测对象是否已被复用 |
| `_timer` | `SceneTreeTimer` | 底层 Godot 定时器 |
| `_triggered` | `bool` | 防重入标志 |

### 2.5 InstructionInstancePool（[instruction_instance_pool.gd:9-25](../../../../core/pooling/instruction_instance_pool.gd)）

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `_pool` | `Array[RuntimeInstructionInstance]` | `[]` | 空闲实例栈（`pop_back` 取用） |
| `_pool_size` | `int` | `32` | 目标池大小 |
| `_max_pool_size` | `int` | `128` | 池容量上限 |
| `_total_created/_total_reused/_peak_usage` | `int` | `0` | 统计计数 |
| `_current_usage` | `int` | `0` | 当前借出未归还的实例数 |
| `_default_log_level` | `FuseLogger.LogLevel` | `INFO` | 池化实例默认日志级别 |

---

## 3. 核心 API

### 3.1 FusePoolItem（池项接口）

| 方法 | 签名 | 说明 |
|------|------|------|
| `mark_used()` | `() -> void` | 置 `in_use=true`，刷新 `last_used_time`，`usage_count += 1` |
| `mark_unused()` | `() -> void` | 置 `in_use=false` |
| `is_valid()` | `() -> bool` | `object != null and is_instance_valid(object)` |
| `is_expired(max_idle_time)` | `(float) -> bool` | 使用中返回 false；空闲超过阈值返回 true |
| `get_efficiency_score()` | `() -> float` | `usage_count / age`（使用频率） |
| `compare_by_efficiency(a, b)` | `static (FusePoolItem, FusePoolItem) -> bool` | 按效率降序排序比较器 |

### 3.2 FuseObjectPool（场景池核心 API）

**借取/归还：**

| 方法 | 签名 | 说明 |
|------|------|------|
| `get_object()` | `() -> Node` | 优先取空闲项；否则在容量内 `_load_scene()` 创建并包装；满则警告并返回 null |
| `return_object(obj)` | `(Node) -> void` | 终止子树内 Trigger/MultiEventTrigger 的处理 → 延迟从场景树移除 → `mark_unused`；未匹配项则创建新池项追加 |
| `reset_object(obj)` | `(Node) -> void` | 调 `obj.reset()`（若有）→ 递归 `_reset_fuse_components` → 重置 transform/visible/velocity/modulate |

**配置：**

| 方法 | 说明 |
|------|------|
| `_init(scene_path, initial_size=20)` | 初始化并 clamp 到 `[_min_pool_size, _max_pool_size]` |
| `warm_up(count)` | 预创建空闲实例（`mark_unused`） |
| `set_pool_size/set_max_pool_size/set_min_pool_size` | 容量配置，触发 `_adjust_pool_size()` |
| `enable_auto_resize(enabled)` / `set_resize_threshold(threshold)` | 自动调整开关与阈值（阈值 clamp 到 `[0.1, 1.0]`） |
| `process_auto_resize()` | 使用率 `> threshold` 扩容到 `min(size*2, max)`；`< threshold*0.5` 收缩到 `max(size/2, min)` |
| `clear_pool()` | `queue_free` 所有对象并清零统计 |

**Fuse 组件重置（[fuse_object_pool.gd:236-291](../../../../core/pooling/fuse_object_pool.gd)）：**

`_reset_fuse_components(node)` 通过迭代栈遍历整个子树，依次：
- `Trigger`：优先调 `pool_reset()`，否则 `reset()` + `set_physics_process(true)` + `set_process(true)`
- `MultiEventTrigger`：同上策略
- `ScopeVariableContainer` 检测（`variables` 字段 + `get_variable` 方法）：首次重置保存 `_pool_default_variables`，后续重置回写默认值

`_terminate_fuse_triggers(node)`（[:300-343](../../../../core/pooling/fuse_object_pool.gd)）则在归还时停止所有 Trigger/MultiEventTrigger 的 `set_physics_process(false)` + `set_process(false)`，并调用其 `event_definition`/`event_bindings` 的 `terminate()`。

### 3.3 FusePoolManager（全局入口）

**池化场景 API：**

| 方法 | 签名 | 说明 |
|------|------|------|
| `get_instance()` | `static () -> FusePoolManager` | 懒加载单例 |
| `instantiate_pooled(scene_path, parent, pool_config={})` | `(...) -> Node` | 取对象 + `add_child` + `reset_object`（添加到树后再重置） |
| `get_pooled_instance(scene_path, pool_config={})` | `(...) -> Dictionary` | 返回 `{"instance": Node, "pool": FuseObjectPool}`，不挂树（用于物理回调等延迟挂载场景） |
| `recycle_pooled(scene_path, instance)` | `(String, Node) -> bool` | 多策略路径解析（实例自带 `scene_file_path` → ID 查找 → 文件名匹配 → UID 匹配）后归还 |
| `warm_up_pool(scene_path, count, pool_config={})` | 预热指定池 |
| `clear_all_pools()` | 清空所有池 |
| `get_statistics(scene_path="")` | 空串返回全部池统计，否则单池统计 |
| `get_detailed_status()` | 包含 `total_pools`/`scene_paths`/`pool_statistics` |

**回收定时器协作 API：**

| 方法 | 说明 |
|------|------|
| `register_recycle_timer(timer)` | 加入 `_active_recycle_timers` 强引用集合 |
| `unregister_recycle_timer(timer)` | 完成后从集合移除 |
| `is_instance_in_use(scene_path, instance)` | 查询池项 `in_use` 标志 |
| `get_instance_usage_count(scene_path, instance)` | 查询池项 `usage_count`（未找到返回 -1） |

**路径解析策略**（[fuse_pool_manager.gd:182-316](../../../../core/pooling/fuse_pool_manager.gd)）：`recycle_pooled` 内部按顺序尝试 `_find_pool_by_instance_id` → `_find_pool_by_any_path`（含 `_get_resource_uid` 将 `res://` 转 `uid://`），并接入 `FusePerformanceTracker` 性能追踪。

### 3.4 FuseRecycleTimer（延迟回收）

| 方法 | 签名 | 说明 |
|------|------|------|
| `create(scene_path, instance, delay)` | `static (...) -> FuseRecycleTimer` | 工厂方法：记录 `_creation_usage_count` + 注册到管理器 + `_setup_timer` |
| `cancel()` | `() -> void` | 断开 timeout 连接，置 `_triggered=true`，注销 |
| `_on_timeout()` | 内部 | 多重校验（弱引用有效性、实例有效性、usage_count 一致性、是否在树、是否仍 in_use）后回调 `recycle_pooled` |
| `_cleanup_and_remove()` | 内部 | `cancel()` + 从父节点移除 + `queue_free()` |

### 3.5 InstructionInstancePool（指令实例池）

| 方法 | 签名 | 说明 |
|------|------|------|
| `_init(initial_size=32, max_size=128)` | clamp 到 `[8, max_size]` |
| `acquire(instruction, context, runner)` | `(...) -> RuntimeInstructionInstance` | 池非空时 `pop_back` + `reinitialize` 复用；否则 `new`；统计 `_total_reused/_total_created/_current_usage/_peak_usage` |
| `release(instance)` | `(RuntimeInstructionInstance) -> void` | 调 `instance.reset_for_pool()` 后入栈（满则丢弃由 GC 回收） |
| `release_all(instances)` | 批量归还 |
| `warm_up(count)` | 预创建 `RuntimeInstructionInstance.new(null, null, null)` 占位 |
| `clear()` | 清空并重置统计 |
| `set_default_log_level(level)` | 设置池化实例默认日志级别 |

---

## 4. 架构关系

### 4.1 类继承/组合关系

```
RefCounted
├── FusePoolItem          (池项包装)
├── FuseObjectPool        (单一场景池，组合多个 FusePoolItem)
├── FusePoolManager       (单例，组合多个 FuseObjectPool + 多个 FuseRecycleTimer)
└── InstructionInstancePool (独立体系，池化 RuntimeInstructionInstance)

Node
└── FuseRecycleTimer      (生命周期由 Godot 管理，由 FusePoolManager._active_recycle_timers 强引用)
```

### 4.2 场景池体系数据流

```
调用方（指令 / 业务代码）
   │
   ├── instantiate_pooled(scene_path, parent, config)
   │       │
   │       ▼
   │   FusePoolManager._get_or_create_pool  ──( miss )──▶  new FuseObjectPool
   │       │                                              注册到 _scene_pools[scene_path]
   │       ▼
   │   FuseObjectPool.get_object  ──( reuse )──▶  FusePoolItem.mark_used
   │       │            └─( miss )──▶ _load_scene → instantiate → new FusePoolItem
   │       ▼
   │   parent.add_child(instance)
   │   FuseObjectPool.reset_object  ──▶ _reset_fuse_components(Trigger/MultiEventTrigger/ScopeVariableContainer)
   │
   └── recycle_pooled(scene_path, instance)
           │
           ▼
       多策略路径解析（instance_id / filename / uid）
           │
           ▼
       FuseObjectPool.return_object
           ├── _terminate_fuse_triggers  (set_physics_process(false) + event.terminate)
           ├── _schedule_safe_remove     (deferred remove_child)
           └── FusePoolItem.mark_unused
```

### 4.3 延迟回收链路

```
FuseRecycleTimer.create(scene_path, instance, delay)
   ├── pool_manager.get_instance_usage_count → 记录 _creation_usage_count
   ├── pool_manager.register_recycle_timer   → 加入 _active_recycle_timers
   └── SceneTree.create_timer(delay).timeout → _on_timeout

_on_timeout 五重校验：
   1. _triggered 防重入
   2. _instance_weak_ref.get_ref() 非空
   3. is_instance_valid(instance)
   4. current usage_count == _creation_usage_count（防止对象被复用后误回收）
   5. instance.is_inside_tree() 且 pool_manager.is_instance_in_use() == true

全部通过 → pool_manager.recycle_pooled(scene_path, instance)
任意失败 → _cleanup_and_remove（取消定时器 + queue_free）
```

### 4.4 指令实例池与 RuntimeActionRunnerInstance 集成

`InstructionInstancePool` 与 `RuntimeActionRunnerInstance` 是协作关系，通过**共享静态实例**模式工作（[runtime_action_runner_instance.gd:51-61, 377-399](../../../../core/runtime_action_runner_instance.gd)）：

| 组件 | 字段/方法 | 行号 | 说明 |
|------|-----------|------|------|
| `RuntimeActionRunnerInstance` | `use_instruction_pool: bool = true` | L52 | 可禁用以回滚到非池化模式 |
| 同上 | `_shared_instruction_pool: RefCounted`（static） | L55 | 全局唯一池实例，类型擦除为 `RefCounted` 避免循环依赖 |
| 同上 | `get_shared_pool()`（static） | L58-61 | 懒加载 `InstructionInstancePool.new(32, 128)` |
| 同上 | `_acquire_instruction_instance(...)` | L394-399 | `use_instruction_pool` 为 true 时 `pool.acquire(instruction, context, self)`，否则 `RuntimeInstructionInstance.new(...)` |
| 同上 | 清理路径 | L378-382 | `use_instruction_pool` 为 true 时遍历 `_instruction_instances` 调 `pool.release(runtime_instruction)` |

**RuntimeInstructionInstance 配套方法**（[runtime_instruction_instance.gd:397-458](../../../../core/runtime_instruction_instance.gd)）：

| 方法 | 行号 | 说明 |
|------|------|------|
| `reinitialize(inst, context, runner=null)` | L397 | 复用路径：替换三个引用 + 同步 `log_level` + 清零执行状态 + `_connected_timer_callbacks.clear()` + `runtime_state.clear()` + 重新 `_initialize_runtime_state()` |
| `reset_for_pool()` | L433 | 归还路径：`_stop_timeout_timer` → 断开 `instruction.finished` → `_cleanup_timer_callbacks` → `_cleanup_runtime_resources` → 置空三个引用 + 清零状态 |

`InstructionInstancePool.acquire` 在池非空时 `pop_back` 后立即调 `reinitialize`，`release` 在入栈前调 `reset_for_pool`，确保复用实例的状态与新实例等价。

---

## 5. 使用模式

### 5.1 场景池：通过指令使用

业务代码通常不直接调 `FuseObjectPool`，而是通过 Fuse 指令（位于 `instructions/node_operations/`）：

| 指令 | 行为 |
|------|------|
| `warm_up_pool.gd` | 触发 `FusePoolManager.warm_up_pool(scene_path, count, pool_config)` |
| `instantiate_scene.gd` | 触发 `instantiate_pooled(scene_path, parent, pool_config)` |
| `recycle_pooled_scene.gd` | 触发 `recycle_pooled(scene_path, instance)`，可选通过 `FuseRecycleTimer.create` 延迟回收 |

`FusePoolManager` 是 `RefCounted` 单例（非 Node），由 `get_instance()` 首次访问时创建，回收定时器作为子 Node 由 SceneTree 接管生命周期，并通过 `_active_recycle_timers` 防止提前释放。

### 5.2 指令实例池：自动启用

`RuntimeActionRunnerInstance.use_instruction_pool` 默认 `true`，所有指令实例的获取/释放自动走池路径，无需业务代码改动。需要回滚到非池化模式时，将 `use_instruction_pool = false` 即可退化为 `new`/直接 GC 模式（[runtime_action_runner_instance.gd:378-399](../../../../core/runtime_action_runner_instance.gd)）。

### 5.3 类型擦除规避循环依赖

`RuntimeActionRunnerInstance` 与 `InstructionInstancePool` 互相 preload 会循环依赖，因此 `_shared_instruction_pool` 与 `get_shared_pool()` 返回值均声明为 `RefCounted`（[runtime_action_runner_instance.gd:55, 58](../../../../core/runtime_action_runner_instance.gd)），实际运行时为 `InstructionInstancePool`。

---

## 6. 设计要点

### 6.1 两套池分离

场景池（`FuseObjectPool` + `FusePoolManager` + `FuseRecycleTimer`）与指令实例池（`InstructionInstancePool`）刻意分离：
- **复用对象类型不同**：前者是 `Node`（含子树、Trigger、变量容器），后者是 `RefCounted`（无场景树负担）
- **复用策略不同**：前者需要 `_reset_fuse_components` 递归重置整个 Fuse 子系统状态，后者只需 `reinitialize` 替换引用
- **生命周期管理不同**：前者需要 `_terminate_fuse_triggers` 停止处理 + 延迟移除场景树，后者只是引用切换

### 6.2 路径多策略匹配

`recycle_pooled` 不要求调用方提供与 `instantiate_pooled` 完全一致的 `scene_path`，按以下优先级匹配（[fuse_pool_manager.gd:128-179](../../../../core/pooling/fuse_pool_manager.gd)）：
1. 优先用 `instance.scene_file_path`（实例自带真实场景路径）
2. `_scene_pools.get(final_scene_path)` 直接命中
3. `_find_pool_by_instance_id` 通过实例 ID 遍历所有池
4. `_find_pool_by_any_path` 文件名（去扩展名）匹配 + `res://` 转 `uid://` 匹配

这种设计兼容 `res://` 与 `uid://` 两种路径格式，且对调用方路径精度宽容。

### 6.3 回收安全：FuseRecycleTimer 的五重校验

延迟回收期间对象状态可能变化（被其他方式回收、被复用、从场景树移除），`_on_timeout` 通过弱引用 + `_creation_usage_count` 一致性 + `is_inside_tree` + `is_instance_in_use` 四重检测，避免误回收（[fuse_recycle_timer.gd:76-122](../../../../core/pooling/fuse_recycle_timer.gd)）。`usage_count` 不匹配说明对象已被归还后再次 `acquire`，定时器应放行。

### 6.4 物理回调安全

`return_object` 在归还时若对象在场景树中，会先 `_terminate_fuse_triggers`（关闭 Trigger 的 `_physics_process`），再 `_schedule_safe_remove` 延迟一帧 `remove_child`（[fuse_object_pool.gd:115-156, 346-357](../../../../core/pooling/fuse_object_pool.gd)）。这避免了在物理回调中直接移除节点导致的 Godot 物理引擎状态混乱。

### 6.5 Fuse 子系统的池化钩子

`_reset_fuse_components` 与 `_terminate_fuse_triggers` 检测并调用 `Trigger`/`MultiEventTrigger` 的 `pool_reset()` 方法（优先于 `reset()`），让 Trigger 自行处理运行时实例重建、信号重连等完整逻辑。同时为 `ScopeVariableContainer` 透明持久化 `_pool_default_variables`，保证变量首次状态作为后续重置基准。

### 6.6 性能观测

- 场景池：`FusePoolManager.recycle_pooled` 与 `_find_pool_by_instance_id` 接入 `FusePerformanceTracker.start_track/stop_track`
- 池统计：`get_statistics` / `get_detailed_status` 暴露 `reuse_ratio`、`efficiency_score`（场景池：重用率 0.4 + 利用率 0.3 + 峰值比 0.2；指令池：重用率 0.6 + 利用率 0.4）
- 池收缩：`_adjust_pool_size` 使用 `compare_by_efficiency` 排序，优先淘汰效率评分最低的空闲对象

### 6.7 指令池的注释预期收益

[instruction_instance_pool.gd:1-4](../../../../core/pooling/instruction_instance_pool.gd) 注释明确：池化 `RuntimeInstructionInstance` 用于减少约 25μs 的 `.new()` 开销，标记为 "Phase 2 性能优化"。注释中的 `acquire`/`release`/`reinitialize`/`reset_for_pool` 四个方法名与代码实际定义完全一致。

---

## 7. 总体评估

### 优点

1. **职责分层清晰**：`FusePoolItem`（包装）/ `FuseObjectPool`（单池）/ `FusePoolManager`（多池协调）三层职责明确，`InstructionInstancePool` 独立成体系
2. **场景池 Fuse 感知**：`_reset_fuse_components` 与 `_terminate_fuse_triggers` 深度处理 Trigger/MultiEventTrigger/ScopeVariableContainer，让池化对象状态干净
3. **延迟回收多重校验**：`FuseRecycleTimer` 通过弱引用 + usage_count + 在树状态 + in_use 标志四重检测，规避误回收
4. **路径匹配宽容**：`res://` / `uid://` / 文件名三种策略，调用方路径精度要求低
5. **可观测性**：`get_statistics` / `get_detailed_status` + `efficiency_score` + PerformanceTracker 接入
6. **可关闭回滚**：`use_instruction_pool` 开关让指令池可一键退化为非池化模式

### 注意点

1. **线性查找（CODE_ISSUES B18，⏸ 低优先 skip）**：`FuseObjectPool.get_object` 与 `return_object` 通过遍历 `_pool_items` 查找项。决策：**保留现状**——`_pool_items` 规模典型 n≤100，线性查找开销可忽略；改字典/索引查找增加内存与维护成本，收益有限。未来若池规模显著扩大再排期
2. **`_find_pool_by_instance_id` 全池遍历**：每次未命中精确路径时遍历所有池的所有池项
3. **`recycle_pooled` 内多个查找方法（`_find_pool_by_instance_filename` 等）定义但 `recycle_pooled` 实际调用链未使用**：保留作为兜底能力
4. **`get_shared_pool()` 非线程安全**：`RuntimeActionRunnerInstance._shared_instruction_pool` 静态字段的懒加载未做并发保护，多线程首次访问需注意

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-07-07
**版本**: 1.0.0
**依据**: `core/pooling/` 5 类源码 + `core/runtime_action_runner_instance.gd` + `core/runtime_instruction_instance.gd` 实际验证
