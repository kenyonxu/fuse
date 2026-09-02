> 🌐 中文 | [**English**](../../../en_US/system_docs/analysis/base_condition_analysis.md)

# BaseCondition 分析报告


> **分析时点**：2026-07-07（经同日全量文档审计逐篇核对代码；此后实现演进以源码为准，近期已核对的机制性结论见 threading / runtime_instance / preset_nested 等篇）
## 文档概述

本报告对 Fuse 可视化编程系统中的 `BaseCondition` 核心脚本进行现状描述。`BaseCondition` 是条件系统的抽象基类（`@abstract class_name BaseCondition extends Resource`），定义条件检查的生命周期接口、缓存系统、依赖图、线程安全、批量操作族以及序列化/克隆框架，为 Trigger / ActionRunner / ParallelConditionEvaluator 等上层模块提供统一的条件抽象。

**源文件:** [base_condition.gd](../../../../core/base/base_condition.gd)
**行数:** 942 行
**基类:** Resource（`@tool` + `@abstract`，可序列化为 .tres）
**配套并行评估器:** [parallel_condition_evaluator.gd](../../../../core/threading/parallel_condition_evaluator.gd)（251 行）
**子类规模:** 66 个 `extends BaseCondition` 实现，分布于 physics / node / input / animation / composite / variable / time / string / dictionaries / arrays / scope / distance / navigation / system / rendering / scene / ui / math 等目录

> ⚠️ **澄清**：`BaseCondition` **不声明任何 signal**（grep `^signal\s` 在源文件无匹配）。条件检查的结果通过 `check()` 返回值传递；`on_condition_met(context)` 与 `on_condition_failed(context)` 是普通实例方法（497–512 行），由调用方主动调用，作为子类响应结果的钩子。早期文档称"条件满足/失败信号"为误述。

---

## 1. 类概述和职责

`BaseCondition` 是所有具体条件（如 `CheckAll` / `CheckAny` / `CheckVariable` / `CheckOnFloor` 等）的基类。它以 `Resource` 形式存在，可被序列化、被 Trigger 持有、被复合条件嵌套、被 ParallelConditionEvaluator 池化到工作线程评估。

### 核心职责

1. **条件评估入口**：`check(context)` 作为统一入口，处理禁用/缓存/计数/取反，最终调用子类 `_evaluate_condition()`
2. **缓存系统**：基于时间戳 + 上下文哈希的结果缓存，可按依赖变量集合失效
3. **依赖图**：`get_dependencies()` 声明变量依赖，`get_dependency_graph()` 输出可视化结构
4. **线程安全标记**：`is_thread_safe` 属性 + `_compute_thread_safety()` 子类钩子，供并行评估器筛选
5. **批量操作**：6 个 `*_batch` 方法覆盖检查/优化检查/验证/状态信息/依赖检查/依赖状态
6. **序列化与克隆**：`serialize()` / `deserialize()` / `clone()`
7. **元数据接口**：静态 `_get_condition_metadata()` 提供 ConditionMetadata（名称/分类/描述/关键词/图标）
8. **统一错误与日志**：`FuseError` 实例字段 + `FuseLogger` 委托的分级 `_log_*` 方法族

### 设计特点

- `@abstract` 标注三个必须子类化的方法：`_evaluate_condition()`、`_compute_dependencies()`、`_update_resource_name()`
- `@tool` 支持编辑器内运行（用于属性面板预览与资源名同步）
- 类内置状态字段（`check_count` / `last_check_time` / `last_result`）直接存放于 Resource 实例上；高频共享/池化场景的状态分离由上层 Runtime 实例体系承担（与 BaseEvent 同构）
- 通过 `_set()` 拦截 `resource_name`，在编辑器语言切换时自动调用 `_update_resource_name()` 重译

---

## 2. 核心属性

### 2.1 Condition Configuration（@export_group）

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enabled` | bool | true | 条件是否启用；setter 触发 debug 日志 |
| `log_level` | FuseLogger.LogLevel | INFO | 日志输出级别 |
| `negate_result` | bool | false | 评估结果取反（在 `check()` 末尾应用） |

### 2.2 Cache Configuration（@export_group）

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enable_cache` | bool | false | 是否启用结果缓存 |
| `cache_duration` | float | 1.0 | 缓存有效期（秒）；setter 强制最小 0.1 |
| `cache_context_changes` | bool | true | 上下文变化时是否失效缓存（参与哈希） |
| `hash_all_variables` | bool | false | 哈希是否纳入全部局部变量（默认仅依赖变量） |

### 2.3 缓存状态字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `_cached_result` | bool | 上次缓存的结果 |
| `_cache_timestamp` | float | 上次缓存写入时间（`Time.get_ticks_msec()/1000.0`） |
| `_cache_context_hash` | int | 上次缓存写入时的上下文哈希 |
| `_cached_dependencies` | Array[String] | `get_dependencies()` 的内部缓存，避免重复计算 |

### 2.4 运行时状态字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `last_check_time` | float | 最近一次 `check()` 时间戳 |
| `check_count` | int | 累计 `check()` 次数 |
| `last_result` | bool | 最近一次 `check()` 结果 |
| `_fuse_error` | FuseError | 统一错误实例（`null` 表示无错误） |
| `_description` | String | 描述缓存（基类未填充） |
| `_last_locale` | String | 上次更新 resource_name 时的语言代码 |

### 2.5 线程安全缓存字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `_thread_safety_cached` | bool | 缓存的线程安全评估结果 |
| `_thread_safety_computed` | bool | 是否已完成线程安全评估 |

### 2.6 静态字段与常量

| 名称 | 类型 | 说明 |
|------|------|------|
| `_fuse_localization_class` | RefCounted | 缓存的 FuseLocalization 类引用，避免重复 `load()` |
| `DEFAULT_CHECK_INTERVAL` | float = 0.1 | 默认重检查间隔常量（基类未直接使用，供子类/调用方参考） |

### 2.7 预加载常量

`FuseLocalization`、`VariableOperations`、`VariableScopeUtils`、`FuseNodeUtils`。

### 2.8 派生属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `is_thread_safe` | bool（getter only） | 通过 `_compute_thread_safety()` 计算，结果缓存于 `_thread_safety_cached` |

---

## 3. 关键方法

### 3.1 条件评估主入口

#### `check(context: ExecutionContext) -> bool` — 评估入口（168–202 行）

统一处理禁用、缓存命中、计数、取反、缓存写入的中央方法。

```
执行流程:
  1. context == null → 记录错误 + 创建 FuseError + 返回 false
  2. enabled == false → debug 日志 + 返回 false
  3. enable_cache 且 _is_cache_valid(context) → 命中缓存，返回 _cached_result
  4. check_count += 1；记录 last_check_time
  5. result = _evaluate_condition(context)         # 子类必须实现（@abstract）
  6. negate_result 为 true → result = not result
  7. last_result = result
  8. enable_cache 为 true → _update_cache(result, context)
  9. 返回 result
```

#### `_evaluate_condition(context: ExecutionContext) -> bool` — 抽象评估（207–208 行）

`@abstract` 方法，无默认实现。子类编写实际判断逻辑。例：`CheckAll` 在此遍历子条件并短路求值；`CheckVariable` 在此读取并比较变量。

### 3.2 抽象方法清单

| 方法 | 行号 | 说明 |
|------|------|------|
| `_evaluate_condition(context) -> bool` | 207–208 | 条件评估主体 |
| `_compute_dependencies() -> Array[String]` | 365–366 | 声明此条件依赖的变量名列表 |
| `_update_resource_name()` | 76–77 | 根据 property 与当前语言生成本地化 resource_name |

### 3.3 验证与描述方法

| 方法 | 返回 | 说明 |
|------|------|------|
| `validate() -> Array[String]` | 错误列表 | 基类检查 `enabled`，禁用时追加错误并创建 FuseError |
| `is_valid(context) -> bool` | bool | 调用 `validate()`，记录每个错误；context 为空时仍执行基础校验并创建 FuseError |
| `get_description() -> String` | String | 基类返回 "Base Condition"，子类一般返回本地化文本 |
| `get_detailed_info() -> Dictionary` | Dictionary | 含 type/description/enabled/negate_result/check_count/last_check_time/last_result，附 `_fuse_error` 详情 |
| `get_status_info() -> Dictionary` | Dictionary | enabled/check_count/last_check_time/last_result/needs_recheck/is_valid |
| `get_condition_type() -> String` | String | 基类返回 "base" |
| `get_condition_category() -> String` | String | 基类返回 "general" |
| `get_priority() -> int` | int | 基类返回 0；数值越小优先级越高 |
| `get_parameters() / set_parameters(p)` | Dictionary / void | 参数读写；set 内部尝试 `set_<key>` 方法或直接赋值 |
| `needs_recheck(context) -> bool` | bool | 基类默认返回 true（每次都重检查）；context 为空时返回 true 并 warning |
| `get_history() / clear_history()` | Array[Dictionary] / void | 历史钩子，基类空实现，子类可选实现 |
| `get_performance_metrics() -> Dictionary` | Dictionary | 含 check_count/last_check_time/average_check_time（基类 0.0） |
| `get_debug_info() -> String` | String | 单行调试字符串 |

### 3.4 图标获取（四级回退）

#### `get_condition_icon() -> Texture2D`（277–305 行）

```
回退顺序（与 BaseInstruction.get_icon() 一致）:
  1. metadata.builtin_icon  → FuseIconManager.get_builtin_icon()
  2. metadata.custom_icon   → FuseIconManager.get_custom_icon()
  3. metadata.icon_name     → FuseIconManager（先 custom 后 builtin）
  4. metadata.icon          → 直接返回 Texture2D
  5. 回退 res://addons/fuse/icons/condition.svg；不存在则 warning + null
```

`get_icon()` 是 `get_condition_icon()` 的兼容别名（309–310 行）。

### 3.5 缓存系统方法

#### `_is_cache_valid(context) -> bool`（615–633 行）

```
有效性判定:
  1. _cache_timestamp == 0.0 → false（从未缓存）
  2. (now - _cache_timestamp) > cache_duration → false（过期）
  3. _generate_context_hash(context) != _cache_context_hash → false（上下文变化）
  4. 否则 → true
```

#### `_update_cache(result, context)`（638–642 行）

写入 `_cached_result` / `_cache_timestamp` / `_cache_context_hash`。

#### `_generate_context_hash(context) -> int`（647–665 行）

```
哈希构成:
  - 基础: context.execution_id.hash()
  - cache_context_changes 为 true 时:
      * 遍历 get_dependencies() 的每个变量值 → hash_value ^= (hash<<5) + str(value).hash()
      * hash_all_variables 为 true 时进一步纳入 context.local_variables 全部变量
  - context == null → 返回 0
```

#### 缓存清理方法

| 方法 | 说明 |
|------|------|
| `clear_result_cache()` | 清空结果缓存三件套 |
| `clear_context_cache(context)` | 仅当传入上下文哈希匹配时清空 |
| `clear_cache()` | 清空全部缓存（与 clear_result_cache 等价，名称更通用） |
| `clear_dependencies_cache()` | 清空 `_cached_dependencies`，下次 `get_dependencies()` 重新计算 |
| `get_cache_info() -> Dictionary` | 返回 enabled/duration/cached_result/cache_timestamp/cache_age/context_hash/is_valid |

### 3.6 依赖图方法

#### `get_dependencies() -> Array[String]`（357–361 行）

带缓存：首次为空时调用 `_compute_dependencies()` 填充 `_cached_dependencies`，后续直接返回缓存。

#### 依赖关系族

| 方法 | 行号 | 说明 |
|------|------|------|
| `add_dependencies(depends_on)` | 716–718 | 钩子方法，基类仅日志；子类可重写以维护结构化依赖 |
| `remove_dependencies(depends_on)` | 722–724 | 同上，移除 |
| `get_dependency_graph() -> Dictionary` | 728–776 | 输出 `{nodes, edges, condition_info}` 图结构；dependency 类型边由变量指向 condition，affected 类型边由 condition 指向变量 |
| `check_dependencies(context) -> bool` | 781–793 | 检查 `get_dependencies()` 中每个变量是否存在于 context |
| `get_dependency_status(context) -> Dictionary` | 798–822 | 返回 `{total_dependencies, satisfied_dependencies, missing_dependencies, dependency_details}` |
| `get_dependency_visualization_data() -> Dictionary` | 852–873 | 聚合 condition 元信息 + dependencies + affected_variables + dependency_graph，附 fuse_error（如有） |
| `get_affected_variables() -> Array[String]` | 391–393 | 基类返回空数组；子类可重写声明影响的变量 |

### 3.7 线程安全方法

#### `is_thread_safe`（getter，60–62 行）

返回 `_compute_thread_safety()`，结果缓存。

#### `_compute_thread_safety() -> bool`（374–381 行）

基类默认实现：首次访问时设 `_thread_safety_cached = false`、`_thread_safety_computed = true`，返回 false。子类重写以反映自身实现是否可在工作线程运行（典型条件：不访问节点属性、仅做纯数学/变量比较、使用快照数据）。

#### `reset_thread_safety_cache()`（385–387 行）

清空 `_thread_safety_computed` 与 `_thread_safety_cached`，配置变化时调用以触发重算。

> **设计契约**：`_compute_thread_safety()` 应自包含且无副作用。复合条件（如 `CheckAll`）通过递归查询子条件的 `is_thread_safe` 决定自身安全性——见 §6 子类模式。

### 3.8 结果回调方法（非信号）

#### `on_condition_met(context)`（497–503 行）

普通实例方法。基类实现：context 为空时 warning；否则 debug 日志记录描述。子类可重写以响应"满足"事件。

#### `on_condition_failed(context)`（505–512 行）

同上，对应"不满足"事件。

> ⚠️ **再次澄清**：这两个方法是普通方法，调用方需主动 `condition.on_condition_met(ctx)` 触发；不存在 signal，因此不能用 `.connect()`。早期文档将其描述为"条件满足/失败信号"是错误的。

### 3.9 批量操作族（6 个 `*_batch` 方法）

| 方法 | 行号 | 入参 | 返回 | 说明 |
|------|------|------|------|------|
| `check_batch(contexts)` | 551–564 | Array[ExecutionContext] | Array[bool] | 顺序调用 `check()`，统计总/平均耗时 |
| `optimized_check_batch(contexts)` | 569–582 | 同上 | Array[bool] | 调用 `optimized_check()`（基类默认走 `check()`，子类可重写为优化路径） |
| `validate_batch(contexts)` | 587–595 | 同上 | Array[bool] | 逐个 `is_valid()` |
| `get_status_info_batch(contexts)` | 600–608 | 同上 | Array[Dictionary] | 逐个 `get_status_info()`（注意：当前实现忽略 context 入参） |
| `check_dependencies_batch(contexts)` | 827–835 | 同上 | Array[bool] | 逐个 `check_dependencies()` |
| `get_dependency_status_batch(contexts)` | 840–848 | 同上 | Array[Dictionary] | 逐个 `get_dependency_status()` |

> **设计现状**：批量方法在本 Resource 实例上串行循环，**不直接调用并行评估器**。并行调度由 `ParallelConditionEvaluator` 在多个 *条件对象* 之间分发，与这里的 *多个上下文* 批处理是两个不同维度。

### 3.10 优化检查

#### `optimized_check(context) -> bool`（526–534 行）

基类默认实现：context 为空 → 错误日志 + 返回 false；否则走标准 `check()`。子类可重写以提供优化路径（如预计算、短路）。

### 3.11 序列化与克隆

#### `serialize() -> Dictionary`（436–442 行）

```gdscript
{
    "type": get_condition_type(),
    "enabled": enabled,
    "negate_result": negate_result,
    "parameters": get_parameters()
}
```

#### `deserialize(data)`（446–454 行）

按 key 还原 `enabled` / `negate_result` / `parameters`（通过 `set_parameters()`）。

#### `clone() -> BaseCondition`（458–468 行）

`duplicate()` 复制后调用 `reset()` 清空运行时状态；若克隆体无 `reset` 方法则 warning。

### 3.12 生命周期与状态重置

#### `reset()`（396–404 行）

清零 `check_count` / `last_check_time` / `last_result`；置空 `_fuse_error`；依次调用 `clear_cache()` / `clear_dependencies_cache()` / `reset_thread_safety_cache()`。

#### `set_enabled(value)`（412–414 行）

设置 enabled 并记录日志（与 @export setter 等价的命令式入口）。

### 3.13 元数据接口

#### `static _get_condition_metadata() -> ConditionMetadata`（941–942 行）

基类返回 `null`。子类实现以提供 ConditionMetadata（name_key / category_key / description_key / keywords / builtin_icon / custom_icon / icon_name / icon），供条件选择器、`get_condition_icon()` 使用。

### 3.14 FuseError 集成

| 方法 | 行号 | 说明 |
|------|------|------|
| `_create_fuse_error(message, error_type, context)` | 879–884 | 创建 FuseError 并存入 `_fuse_error`；自动附加 condition_type / condition_description 上下文 |
| `_create_fuse_error_localized(message_key, error_type, args, context)` | 893–925 | 通过 FuseLocalization 翻译 message_key（带 args 用 translate_format，否则 translate）；翻译系统不可用时回退手动 `{key}` 替换；附加 message_key/message_args 上下文 |
| `get_fuse_error() -> FuseError` | 929–930 | 返回 `_fuse_error`（无错误返回 null） |
| `has_fuse_error() -> bool` | 934–935 | 是否有错误 |

### 3.15 日志方法（委托 FuseLogger）

| 方法 | 委托 |
|------|------|
| `_log_debug(msg)` | `FuseLogger.log_debug("BaseCondition", log_level, msg)` |
| `_log_info(msg)` | `FuseLogger.log_info("BaseCondition", log_level, msg)` |
| `_log_warning(msg)` | `FuseLogger.log_warning("BaseCondition", log_level, msg)` |
| `_log_error(msg)` | `FuseLogger.log_error("BaseCondition", log_level, msg)` |

### 3.16 资源名本地化拦截

#### `_set(property, value) -> bool`（145–163 行）

拦截 `resource_name` 设置：初始化 FuseLocalization；若当前语言与 `_last_locale` 不同（或首次设置），更新 `_last_locale` 并调用 `_update_resource_name()` 重新翻译；返回 false 让 Godot 使用更新后的值。其他属性直接返回 false 走默认处理。

### 3.17 节点路径显示名解析

#### `_get_node_display_name(path: NodePath) -> String`（95–110 行）

用于 `_update_resource_name()` 与 `get_description()` 中显示目标节点。

```
解析策略:
  1. 路径为空 → ""
  2. 末尾有明确节点名（非纯 .. 或 .）→ 直接提取 get_file()
  3. 编辑器模式 → FuseNodeUtils.resolve_node_name_for_display()
  4. 解析失败 → _get_parent_level_display() 智能回退
  5. 非编辑器 → 返回原路径字符串
```

#### `static _get_parent_level_display(path_str) -> String`（113–127 行）

将纯 `..` 路径转为可读层级描述：1 层 → "[上级]"，n 层 → "[n层上级]"。重启后的刷新由 EditorPlugin.scene_changed 信号处理（见方法注释）。

---

## 4. 缓存系统架构

### 4.1 缓存写入与读取

```
check(context)
  │
  ├── enable_cache && _is_cache_valid(context)
  │       └── 命中 → 返回 _cached_result
  │
  ├── result = _evaluate_condition(context)
  │
  └── enable_cache
          └── _update_cache(result, context)
                  ├── _cached_result = result
                  ├── _cache_timestamp = now
                  └── _cache_context_hash = _generate_context_hash(context)
```

### 4.2 上下文哈希构成

```
_generate_context_hash(context):
  base = context.execution_id.hash()
  if cache_context_changes:
      for dep in get_dependencies():       # 仅依赖变量
          base ^= (base << 5) + str(value).hash()
      if hash_all_variables:               # 可选：全部局部变量
          for k,v in context.local_variables:
              base ^= (base << 3) + str(v).hash()
  return base
```

### 4.3 失效策略

| 触发 | 行为 |
|------|------|
| `cache_duration` 到期 | `_is_cache_valid()` 返回 false，下次 `check()` 重算 |
| 上下文哈希变化（依赖变量值变） | 同上 |
| 手动 `clear_cache()` / `clear_result_cache()` / `clear_context_cache(ctx)` | 立即失效 |
| `reset()` | 一并清空缓存、依赖缓存、线程安全缓存 |
| 子条件配置变更（典型场景） | 复合条件在 setter 中调用 `clear_dependencies_cache()` 触发重算（见 CheckAll） |

---

## 5. 依赖图与可视化

### 5.1 依赖声明链

```
BaseCondition.get_dependencies()              # 带缓存
        │
        └── _compute_dependencies()           # @abstract，子类实现
                │
                └── 典型：扫描自身的 variable_name 等字段
                          复合条件：聚合所有子条件的 get_dependencies()
```

### 5.2 get_dependency_graph() 输出结构

```gdscript
{
    "nodes": [
        {"id": "condition_<instance_id>", "label": <description>, "type": "condition"},
        {"id": "<var_name>", "label": "<var_name>", "type": "dependency"},   # 每个 dep 一个
        {"id": "<var_name>", "label": "<var_name>", "type": "affected"}      # 每个 affected 一个
    ],
    "edges": [
        {"from": "<dep_var>", "to": "condition_<id>", "type": "dependency"},
        {"from": "condition_<id>", "to": "<affected_var>", "type": "affects"}
    ],
    "condition_info": {
        "type": <condition_type>,
        "description": <description>,
        "enabled": <bool>,
        "priority": <int>
    }
}
```

### 5.3 可视化数据聚合

`get_dependency_visualization_data()` 在上图基础上额外封装 condition 元信息与 `fuse_error`（如有），是面向编辑器/调试工具的上层入口。

---

## 6. 线程安全与 ParallelConditionEvaluator

### 6.1 线程安全标记链

```
BaseCondition.is_thread_safe  (getter)
        │
        └── _compute_thread_safety()         # 带缓存（_thread_safety_computed）
                │
                └── 基类默认: false
                    子类重写: 根据实现是否访问节点属性 / 是否纯计算 返回 true/false
                    复合条件（CheckAll）: 仅当所有子条件 is_thread_safe 为 true 时才 true

reset_thread_safety_cache()  # 配置变化时清空缓存触发重算
```

### 6.2 ParallelConditionEvaluator 协作

`ParallelConditionEvaluator`（`core/threading/parallel_condition_evaluator.gd`）使用 `WorkerThreadPool` 并行评估多个条件对象，依据 `condition.is_thread_safe` 筛选可并行集合。

```
evaluate_parallel(context, conditions)
  │
  ├── SEQUENTIAL     → _evaluate_sequential()      # 串行回退
  ├── PARALLEL_SAFE  → _evaluate_parallel_safe()   # 仅对 is_thread_safe=true 的条件并行
  └── PARALLEL_ALL   → _evaluate_parallel_all()    # 强制并行全部（危险，仅测试）
```

**PARALLEL_SAFE 内部流程**：

1. 分类：`is_thread_safe=true` → safe_indices；其余 → unsafe_indices
2. 调用 `_create_context_snapshot(context)`：复制 local_variables + 全局变量快照 + trigger/target/execution_id
3. safe_indices 走 `_evaluate_safe_conditions_parallel()`：每个任务 `WorkerThreadPool.add_task`，内部用临时 context 调用 `condition.check(temp_context)`，结果数组与计数器用 Mutex 保护，Semaphore 同步
4. unsafe_indices 串行 `condition.check(context)`
5. 超时保护：总超时 = max(target_count × timeout_per_condition, 5.0)，超时退出并 warning

**统计信息**：`total_conditions_evaluated` 由 `_stats_mutex` 保护（串行与并行模式均加锁，注释标注为竞态条件修复）。

### 6.3 与 FuseThreadSafe 的关系

`FuseThreadSafe`（`core/threading/fuse_thread_safe.gd`）是纯工具类，提供 `dict_get_safe` / `dict_set_safe` / `array_append_safe` 等带可选 Mutex 参数的字典/数组操作封装。`BaseCondition` **不继承也不直接使用** `FuseThreadSafe`——后者供需要线程安全容器操作的场景按需调用。`ParallelConditionEvaluator` 内部直接使用 Godot 原生 `Mutex` / `Semaphore`。

---

## 7. 序列化与克隆

### 7.1 serialize() 数据形态

仅包含 `type` / `enabled` / `negate_result` / `parameters`。`parameters` 来自 `get_parameters()`，子类一般返回自身 @export 字段的字典形式。

### 7.2 deserialize() 还原流程

按 key 存在性还原 `enabled` → `negate_result` → `set_parameters(parameters)`。`set_parameters()` 内部对每个 key 优先尝试 `set_<key>` 方法，否则直接 `set(key, value)`；属性不存在则 warning。

### 7.3 clone() 行为

`duplicate()` → 调用克隆体的 `reset()`（无 reset 方法则 warning）→ 返回。运行时状态（计数/缓存/错误）被清零，@export 配置保留。

---

## 8. 子类实现模式

基于对 66 个子类的抽样（重点 `CheckAll`、`CheckVariable`），子类通常遵循以下模式：

### 8.1 必须实现的方法

| 方法 | 说明 |
|------|------|
| `_evaluate_condition(context) -> bool` | 实际判断逻辑 |
| `_compute_dependencies() -> Array[String]` | 声明依赖变量（复合条件聚合子条件依赖） |
| `_update_resource_name()` | 生成本地化资源名 |
| `static _get_condition_metadata() -> ConditionMetadata` | 提供选择器/图标元数据 |

### 8.2 常见重写

| 方法 | 重写场景 |
|------|----------|
| `get_condition_type() / get_condition_category() / get_description()` | 返回类型/分类/描述（一般本地化） |
| `validate()` | 调用 `super.validate()` 后追加子类特定校验 |
| `get_parameters() / set_parameters()` | 序列化字段读写 |
| `reset()` | 调用 `super.reset()` 后清理子结构（如复合条件重置所有子条件） |
| `_compute_thread_safety()` | 声明自身是否可并行（复合条件递归查询子条件） |
| `on_condition_met/failed()` | 响应结果钩子（基类仅日志） |
| `optimized_check()` | 优化路径（基类默认走 `check()`） |

### 8.3 典型子类结构（以 CheckAll 为例）

```gdscript
@tool
extends BaseCondition
class_name CheckAll

@export var conditions: Array[BaseCondition] = []:
    set(value):
        conditions = value
        clear_dependencies_cache()      # 配置变化清空依赖缓存
        _update_resource_name()

@export var short_circuit: bool = true

func _evaluate_condition(context: ExecutionContext) -> bool:
    if conditions.is_empty():
        return false
    for i in conditions.size():
        var condition = conditions[i]
        if condition == null:
            _create_fuse_error(..., FuseError.ErrorType.VALIDATION_ERROR)
            return false
        if not condition.check(context):
            return false                # 短路
    return true

func _compute_dependencies() -> Array[String]:
    var all_deps: Array[String] = []
    for condition in conditions:
        if condition != null:
            for dep in condition.get_dependencies():
                if not dep in all_deps:
                    all_deps.append(dep)
    return all_deps

func _compute_thread_safety() -> bool:
    if _thread_safety_computed:
        return _thread_safety_cached
    var is_safe := true
    for condition in conditions:
        if condition != null and not condition.is_thread_safe:
            is_safe = false
            break
    _thread_safety_cached = is_safe
    _thread_safety_computed = true
    return _thread_safety_cached

static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_ALL_NAME"
    metadata.category_key = "FUSE_CATEGORY_COMPOSITE"
    metadata.description_key = "FUSE_CONDITION_ALL_DESC"
    metadata.keywords = ["所有", "AND", "且", "全部", "满足", "all", "every", "each"]
    metadata.builtin_icon = "AnimationTrackList"
    return metadata
```

### 8.4 复合条件族

`conditions/composite/` 下四个逻辑运算符：

| 类 | 类型 | 说明 |
|------|------|------|
| `CheckAll` | composite_all | AND，支持短路 |
| `CheckAny` | composite（any） | OR |
| `CheckNot` | composite（not） | NOT 取反包装 |
| `CheckComposite` | composite | 通用组合（按子条件 + 运算符） |

复合条件的 `_compute_dependencies` 与 `_compute_thread_safety` 均递归聚合子条件，是依赖图与线程安全传递性的关键。

### 8.5 条件目录分布

按域划分的子类目录（每个目录若干条件）：

```
conditions/
├── animation/    （check_is_playing, check_animation_tree_parameter, ...）
├── arrays/       （check_array_size, check_array_contains）
├── composite/    （check_all, check_any, check_not, check_composite）
├── dictionaries/ （check_dict_size, check_dict_contains_key）
├── distance/     （check_distance）
├── input/        （check_input_pressed, check_input_held, check_input_released, ...）
├── math/         （expression_condition）
├── navigation/   （check_path_available）
├── node/         （check_node_exists, check_node_active, check_node_property, ...）
├── physics/      （check_on_floor, check_on_wall, check_is_falling, check_velocity, ...）
├── rendering/    （check_is_on_screen）
├── scene/        （check_preload_status）
├── scope/        （check_scope_variable）
├── string/       （check_string_length, check_string_contains）
├── system/       （check_frame_rate, check_platform）
├── time/         （check_time_reached, check_time_range, check_countdown_finished, check_game_time）
├── ui/           （check_ui_visible）
└── variable/     （check_variable, compare_variable, check_health_value, ...）
```

---

## 9. 与其他系统的关系

### 9.1 与 BaseEvent / Trigger / ActionRunner 的关系

条件由 Trigger / Runner / 复合条件等上层持有，通过 `check(context)` 参与事件触发决策与指令执行门控。条件本身不持有 Trigger 引用，状态自包含。

### 9.2 与 ExecutionContext 的关系

`check(context)` 是条件的唯一外部入口；context 提供 `execution_id` / `local_variables` / `get_variable()` / `has_variable()` 等，是缓存哈希与依赖检查的数据源。

### 9.3 与 Runtime 实例体系的关系

`BaseCondition` 是 Resource，运行时状态字段直接存放于实例上。在资源共享 / 池化场景中，状态隔离由上层 Runtime 实例体系（与 BaseEvent 同构的 Runtime*Instance 模式）承担；条件本身的 `check_count` / `last_result` 等是单实例视角的累计统计。

### 9.4 与 FuseLogger / FuseError 的关系

- 所有 `_log_*` 方法委托 `FuseLogger`，统一日志前缀 `"BaseCondition"`
- 所有错误通过 `_create_fuse_error[_localized]` 创建 `FuseError` 并存于 `_fuse_error`，调用方可通过 `get_fuse_error()` / `has_fuse_error()` 查询，`get_detailed_info()` / `get_dependency_visualization_data()` 自动附带错误详情

### 9.5 与 FuseLocalization 的关系

- 静态缓存 `_fuse_localization_class` 避免重复 `load()`
- `_set()` 拦截 `resource_name`，语言切换时自动调用 `_update_resource_name()`
- `_create_fuse_error_localized()` 通过 translate / translate_format 翻译错误键

---

## 10. 现状备注

- `get_status_info_batch(contexts)` 当前实现忽略入参 context，每个上下文返回相同 status（基类 `get_status_info()` 也未使用 context）。子类如需 context 相关状态需自行重写。
- 批量方法（§3.9）在单 Resource 实例上串行循环；并行多条件评估需通过 `ParallelConditionEvaluator` 调用，两者是不同维度。
- `add_dependencies` / `remove_dependencies` 在基类仅日志，实际依赖管理依赖子类 `_compute_dependencies()` 静态声明；动态增删需子类重写。
- `get_history` / `clear_history` / `get_performance_metrics().average_check_time` 在基类为占位实现，由子类按需提供。

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-07-07
**版本**: 2.0（现状描述体例重写，依据 `base_condition.gd` 942 行 + `parallel_condition_evaluator.gd` 251 行 + `fuse_thread_safe.gd` 79 行实测）
