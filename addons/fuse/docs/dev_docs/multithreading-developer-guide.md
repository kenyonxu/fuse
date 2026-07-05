# Fuse 多线程系统 - 开发者指南

## 概述

Fuse 现在支持并行条件评估和异步场景预加载。核心思路很简单：把耗时的条件检查放到工作线程执行，主线程只处理结果。

## 快速开始

### 并行条件评估

```gdscript
# 在 MultiEventTrigger 中启用
@export var use_parallel_condition_evaluation: bool = true
```

就这一行。触发器会自动检测哪些条件是线程安全的，并行执行它们。

### 创建线程安全的条件

继承 `BaseCondition`，重写 `_compute_thread_safety()`:

```gdscript
class_name MyThreadSafeCondition extends BaseCondition

func _compute_thread_safety() -> bool:
    # 只有满足这些条件才安全
    if uses_target_node or accesses_context:
        return false
    return true
```

**线程安全的条件必须：**
- 不访问节点属性
- 不调用 `get_node()` 或 `get_parent()`
- 只读取 `GlobalVariableManager` 的数据
- 不修改任何状态

## 核心类

### FuseThreadSafe

线程安全工具类。提供了 Mutex 包装的字典和数组操作。

```gdscript
# 安全地修改字典
FuseThreadSafe.safe_dict_write(my_dict, "key", value)

# 安全地读取并处理
var snapshot = FuseThreadSafe.safe_dict_read(my_dict, "key", default_value)
```

### FuseTaskManager

`WorkerThreadPool` 的封装。提交任务，等待结果。

```gdscript
var task_manager = FuseTaskManager.get_instance()

# 提交后台任务
var task_id = task_manager.submit_task(func():
    return do_expensive_work()
)

# 等待结果（带超时）
var result = await task_manager.await_task(task_id, 5.0)

# 取消任务
task_manager.cancel_task(task_id)
```

| 方法 | 说明 |
|------|------|
| `submit_task(callable)` | 提交任务，返回任务 ID |
| `await_task(id, timeout)` | 等待任务完成 |
| `cancel_task(id)` | 取消任务 |
| `get_task_status(id)` | 获取状态（返回 `TaskStatus` 或 `null`） |

### ParallelConditionEvaluator

并行评估多个条件。三种模式：

| 模式 | 行为 |
|------|------|
| `SEQUENTIAL` | 全部串行执行 |
| `PARALLEL_SAFE` | 只并行线程安全的条件 |
| `PARALLEL_ALL` | 强制并行所有（危险，仅测试用） |

```gdscript
var evaluator = ParallelConditionEvaluator.new()
evaluator.evaluation_mode = ParallelConditionEvaluator.EvaluationMode.PARALLEL_SAFE

var results = evaluator.evaluate_parallel(context, conditions)
# results: Array[bool]，与 conditions 一一对应
```

### FuseThreadingConfig

配置资源。放在 `resources://` 下自动加载。

```gdscript
var config = FuseThreadingConfig.get_instance()

# 读取配置
if config.enable_multithreading:
    evaluator.evaluation_mode = evaluator.EvaluationMode.PARALLEL_SAFE
```

## 实现线程安全的条件

### 示例：CheckVariable

```gdscript
func _compute_thread_safety() -> bool:
    if _thread_safety_computed:
        return _thread_safety_cached

    var is_safe := true

    # SCOPE 类型需要访问 ExecutionContext，不安全
    if variable_scope == BaseVariable.VariableScope.SCOPE:
        match scope_source:
            ScopeSource.TARGET_NODE, ScopeSource.TRIGGER_SCOPE:
                is_safe = false
            ScopeSource.NEAREST, ScopeSource.CUSTOM_ID:
                is_safe = false

    # 比较变量也要检查
    if is_safe and check_with_another_variable:
        if compare_variable_scope == BaseCondition.VariableScope.SCOPE:
            match compare_scope_source:
                ScopeSource.TARGET_NODE, ScopeSource.TRIGGER_SCOPE:
                    is_safe = false
                ScopeSource.NEAREST, ScopeSource.CUSTOM_ID:
                    is_safe = false

    _thread_safety_cached = is_safe
    _thread_safety_computed = true
    return _thread_safety_cached
```

### 线程安全检查清单

在 `_compute_thread_safety()` 中返回 `true` 之前，确认：

- [ ] 不访问 `context.trigger` 或 `context.target`
- [ ] 不调用 `get_node()`, `get_parent()`, `get_tree()`
- [ ] 不访问节点的任何属性
- [ ] 只使用 `GlobalVariableManager.get_all_variables_snapshot()`
- [ ] 不修改任何全局状态

## 信号与线程

Godot 的信号在多线程中使用需要 `CONNECT_DEFERRED`：

```gdscript
# ❌ 错误 - 可能在工作线程触发，导致崩溃
signal.completed.connect(_on_completed)

# ✅ 正确 - 延迟到主线程处理
signal.completed.connect(_on_completed, Object.CONNECT_DEFERRED)
```

`RefCounted` 没有 `call_deferred()`。用信号 + `CONNECT_DEFERRED` 替代：

```gdscript
# 在 RefCounted 类中
signal _work_completed(result: Variant)

func do_work():
    WorkerThreadPool.add_task(_worker_func)

func _worker_func():
    var result = compute()
    _work_completed.emit(result)  # 发射信号
    # 主线程通过 CONNECT_DEFERRED 接收
```

## 场景预加载

异步加载场景，避免卡顿。

```gdscript
# 开始加载
var instruction = PreloadSceneInstruction.new()
instruction.scene_path = "res://scenes/level_2.tscn"
instruction.preload_mode = PreloadSceneInstruction.PreloadMode.ASYNC_LATER
instruction.execute(context)

# 检查状态
var check = CheckPreloadStatus.new()
check.scene_path = "res://scenes/level_2.tscn"
check.expected_status = CheckPreloadStatus.PreloadStatus.LOADED
if check.check(context):
    # 加载完成，可以实例化
    var scene = PreloadSceneInstruction.get_loaded_scene("res://scenes/level_2.tscn")
```

| 状态 | 说明 |
|------|------|
| `NOT_LOADED` | 尚未开始加载 |
| `LOADING` | 正在加载中 |
| `LOADED` | 加载完成，可以实例化 |
| `FAILED` | 加载失败 |
| `TIMEOUT` | 加载超时 |

## 调试

启用日志查看详细执行过程：

```gdscript
# 在触发器上设置日志级别
trigger.log_level = FuseLogger.LogLevel.DEBUG
```

查看并行评估统计：

```gdscript
var stats = evaluator.get_statistics()
print("总评估次数: %d" % stats["total_conditions_evaluated"])
print("串行模式: %d" % stats["serial_evaluations"])
print("并行模式: %d" % stats["parallel_evaluations"])
```

## 常见问题

### Q: 并行反而更慢？

并行有开销。条件数量少（<10）时，串行通常更快。在 `FuseThreadingConfig` 中调整阈值：

```gdscript
config.min_conditions_for_parallel = 8
```

### Q: 随机崩溃？

检查你的条件是否真的线程安全。在 `_compute_thread_safety()` 中保守一点 - 不确定就返回 `false`。

### Q: 信号没收到？

确保使用了 `CONNECT_DEFERRED`。WorkerThreadPool 的任务在工作线程执行，直接 emit 信号不会触发主线程回调。

## 文件结构

```
addons/fuse/
├── core/
│   ├── threading/
│   │   ├── fuse_thread_safe.gd          # 工具类
│   │   ├── fuse_task_manager.gd         # 任务管理器
│   │   ├── parallel_condition_evaluator.gd # 并行评估器
│   │   └── fuse_threading_config.gd     # 配置资源
│   └── base/
│       └── base_condition.gd              # 添加了 is_thread_safe
├── conditions/
│   └── variable/
│       └── check_variable.gd              # 线程安全实现示例
└── instructions/
    └── scene/
        └── preload_scene_instruction.gd   # 场景预加载
```

## 已优化的条件

| 条件 | 线程安全条件 | 优先级 |
|------|-------------|--------|
| CheckVariable | LOCAL/GLOBAL 作用域 | P0 ✅ |
| CheckPreloadStatus | 总是安全 | P0 ✅ |
| CheckInputPressed | 总是安全 | P1 ✅ |
| CheckInputHeld | 总是安全 | P1 ✅ |
| CheckInputReleased | 总是安全 | P1 ✅ |
| CheckAll | 所有子条件安全 | P2 ✅ |
| CheckAny | 所有子条件安全 | P2 ✅ |
| CheckNot | 子条件安全 | P2 ✅ |
| CheckArraySize | VARIABLE + LOCAL/GLOBAL | P2 ✅ |
| CheckArrayContains | VARIABLE + LOCAL/GLOBAL | P2 ✅ |
| CheckDictSize | LOCAL/GLOBAL 作用域 | P2 ✅ |
| CheckDictContainsKey | LOCAL/GLOBAL 作用域 + 键源安全 | P2 ✅ |

## 不优化的条件（保持串行）

以下条件需要访问节点或 ExecutionContext，无法优化：

- `CheckNodeProperty` - 需要访问节点属性
- `CheckNodeActive` - 需要访问节点
- `CheckNodeExists` - 需要访问节点
- `CheckChildCount` - 需要访问节点子节点
- `CheckGroupCount` - 需要访问 SceneTree
- `CheckAnimationFinished` - 需要访问动画状态
- `CheckArraySize` (NODE_CHILDREN/NODE_GROUP 模式) - 需要访问节点
