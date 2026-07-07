# BaseVariable 分析报告

## 文档概述

本报告对 Fuse 可视化编程系统中的 `BaseVariable` 核心脚本进行了现状描述式分析。`BaseVariable` 是变量系统的基类（`class_name BaseVariable extends Resource`），以 Godot 原生 `Variant` 直接承载值，定义了三层作用域、统一错误处理、生命周期钩子和一组静态工厂方法。它本身不承担存储/查找职责——变量按作用域分别由 `VariableContext`（LOCAL）、`ScopeVariableContainer`（SCOPE）、`GlobalVariableManager`/`Assistant`/`Resource`/`Service` 四件套（GLOBAL）管理。

**源文件:** [base_variable.gd](../../../core/base/base_variable.gd)
**行数:** 1073 行
**基类:** Resource（`@tool` + `@icon`）
**作用域枚举:** `VariableScope.LOCAL = 0` / `SCOPE = 1` / `GLOBAL = 2`

> 历史背景：本篇替代旧稿（前 6 节基于不存在的 `_validate_value` / `get_modification_history` 等 API，且误称 GlobalVariableManager 为"单例 Node"）。旧稿已归档至 `addons/fuse/docs/archive/analysis/base_variable_analysis.md`。

---

## 1. 类概述和职责

`BaseVariable` 是一个 `Resource` 子类，单实例描述"一个具名变量"——它的名字、值、作用域、持久化倾向、统计计数。它可被序列化进 `.tres`，但不持有节点引用，不直接与场景树耦合。

### 核心职责

1. **承载值**：以 `Variant value` 字段直接存储任意 Godot 值，无类型约束、无运行时校验
2. **作用域声明**：通过 `scope: int`（取 `VariableScope` 枚举值）声明该变量归属哪一层
3. **修改追踪**：维护 `modification_count`、`last_modified_time`、`access_count`、`creation_time` 等计数
4. **变更通知**：通过 `value_changed` / `value_modified` / `variable_reset` 三个信号广播变更
5. **错误承载**：内建 `_fuse_error: FuseError` 字段与 `_create_fuse_error()` 构造器，作为统一错误容器
6. **工厂支持**：提供 `create()` / `create_local()` / `create_global()` / `create_player_health()` / `create_batch()` / `from_config()` / `clone_variable()` 等静态工厂
7. **持久化兼容**：保留旧版 ConfigFile 持久化方法（`_save_to_storage` / `_load_from_storage` / `_clear_storage`，均已 `@deprecated`）

### 设计特点

- 使用 `@tool` 注解支持编辑器模式运行（`_update_resource_name()` 会在 Inspector 中显示拼接的资源名）
- 不持节点引用，仅持有 `RefCounted`/`Resource` 友元（如 `FuseError`）
- 无强制子类化——多数场景直接 `BaseVariable.new()` 即可，不需要派生
- 类型系统完全交由 Godot Variant：`get_type_name()` / `get_godot_type()` 反射 `typeof(value)`，无独立类型校验层

---

## 2. 核心属性

### 2.1 @export 属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `variable_name` | String | `""` | 变量名；setter 仅记日志，不触发资源名重建 |
| `value` | Variant | `null` | 变量值；setter 更新计数并 `emit value_changed`（详见 §5 信号 bug） |
| `description` | String | `""` | 人类可读描述 |
| `log_level` | FuseLogger.LogLevel | `INFO` | 日志级别 |
| `scope` | int | `VariableScope.LOCAL` | 作用域；setter 触发 `_update_resource_name()` |
| `persistent` | bool | `false` | 是否参与持久化（GLOBAL 作用域默认 true） |
| `auto_create` | bool | `false` | 是否在缺失时自动创建（LOCAL/SCOPE 默认 true） |
| `access_count` | int | `0` | 通过 `get_value()` 读取的累计次数（`@export`） |

### 2.2 实例变量（非 @export）

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `creation_time` | float | `_init()` 时设为 `Time.get_ticks_msec()/1000.0` | 创建时间戳 |
| `last_modified_time` | float | 0.0 | 最近一次修改时间戳（value setter 和 set_value 都会更新） |
| `modification_count` | int | 0 | 修改次数（value setter 和 set_value 都会自增） |
| `is_initialized` | bool | `false` | 是否已通过 `get_value()` 或工厂完成惰性初始化 |
| `_fuse_error` | FuseError | `null` | 统一错误对象 |

### 2.3 常量与废弃常量

| 常量 | 值 | 说明 |
|------|----|------|
| `DEFAULT_VALUE` | `null` | 默认值占位 |
| `STORAGE_SECTION` | `"variables"` | @deprecated，旧 ConfigFile section |
| `STORAGE_CONFIG_PATH` | `"user://fuse_variables.cfg"` | @deprecated，旧 ConfigFile 路径 |

### 2.4 枚举

```gdscript
enum VariableScope {
    LOCAL = 0,      ## 局部变量（ExecutionContext.local_variables）
    SCOPE = 1,      ## 作用域变量（ScopeVariableContainer）
    GLOBAL = 2      ## 全局变量（GlobalVariableAssistant/Manager）
}
```

三值是 LOCAL/SCOPE/GLOBAL。注意：废弃类 `VariableContainer` 内部自带一个**不同的** `VariableScope = LOCAL/GLOBAL` 二值枚举（见 §7.1），不要混淆。

---

## 3. 关键方法

### 3.1 值读写

#### `get_value() -> Variant`
读取当前值，并对 `access_count` 自增；首次访问会触发 `_initialize_value()`（将 `is_initialized` 置 true）。**不做类型转换或校验。**

#### `set_value(new_value: Variant) -> bool`
**无任何类型校验，直接赋值。** 完整流程：
1. 保存 `old_value`
2. `value = new_value`（触发 value setter，但 setter 内只更新计数并 `emit value_changed`）
3. 显式更新 `last_modified_time` / `modification_count`（与 setter 重复，因 setter 已更新过——这是冗余但无害的设计）
4. `emit value_changed(old_value, new_value)`（**第二次** emit，与 setter 内的 emit 重复）
5. `emit value_modified(new_value)`（setter 内**不会** emit 此信号——见 §5）
6. 返回 `true`（无失败路径）

> 设计取舍：所有值类型都通过 Variant 透传，没有 `_validate_value()` / 类型守卫 / 范围检查。需要类型约束的调用方（如指令层）应在外部校验。

### 3.2 状态查询

| 方法 | 返回 | 说明 |
|------|------|------|
| `has_value()` | bool | `is_initialized and value != null` |
| `is_empty()` | bool | `not has_value()` |
| `get_type_name()` | String | 反射 `typeof(value)` 转字符串（覆盖 NIL/BOOL/INT/FLOAT/STRING/VECTOR2/VECTOR3/COLOR/ARRAY/DICTIONARY/OBJECT/NODE_PATH 及各类 PackedArray，未覆盖返回 `"Unknown"`） |
| `get_godot_type()` | int | 直接返回 `typeof(value)` |
| `get_info()` | Dictionary | 聚合 name/type/value/persistent/modification_count/last_modified_time/is_initialized；若 `_fuse_error` 非空则附 `fuse_error` 键 |
| `get_debug_info()` | String | 单行调试串；包含 FuseError 时附错误信息 |
| `get_creation_info()` | Dictionary | name/type/scope（用 `VariableScope.keys()[scope]` 反查名）/creation_time/access_count/persistent/auto_create/modification_count/last_modified_time |
| `equals(v)` / `not_equals(v)` / `greater_than(v)` / `less_than(v)` / `greater_equal(v)` / `less_equal(v)` | bool | 值比较；`*_than` 系列先 `to_number()` 转换，无法转换记 warning 后返回 false |

### 3.3 类型转换辅助

| 方法 | 行为 |
|------|------|
| `to_string()` | `str(value)` |
| `to_number()` | int/float 直返；string 尝试 `float()`（NaN 时回 0）；其余 0.0 |
| `to_bool()` | bool 直返；int/float 比较非零；string 判非空；其余 false |
| `to_array()` | 已是 Array 直返；否则包成 `[value]` |
| `to_dict()` | 已是 Dictionary 直返；否则 `{}` |
| `_convert_to_number(val)` | 静态辅助，与 `to_number()` 类似但接受外部值 |

### 3.4 重置与生命周期

#### `reset()`
将 `value` 置 `null`、计数清零、`is_initialized = true`、`_fuse_error = null`，并 `emit variable_reset()`。**注意**：reset 会直接清空值，与 `_initialize_value()` 的惰性初始化不同。

#### `_init()`
设置 `last_modified_time = 0`、`modification_count = 0`、`is_initialized = false`、`_fuse_error = null`、`creation_time = now`。注释明确**不**在此调 `reset()`（因为 `value` 可能还没被设置）。

#### `_notification(what)`
仅处理 `NOTIFICATION_PREDELETE`：把 `_fuse_error` 置 `null`，避免悬空引用。不做其它清理（无节点、无信号断开需求——信号由 Manager 在 `add_variable` 时连接、`remove_variable` 时断开）。

### 3.5 FuseError 集成

#### `_create_fuse_error(message, error_type = RUNTIME_ERROR, context = {})`
构造 FuseError 实例存入 `_fuse_error`。会自动向 `context` 注入 `variable_name` 和 `variable_type`（来自 `get_type_name()`）。错误源组件名固定为 `"BaseVariable"`。

#### `get_fuse_error() -> FuseError` / `has_fuse_error() -> bool`
查询接口，供外部（如指令、事件）消费。

> BaseVariable 不主动创建错误——`_fuse_error` 通常由外部检测到异常时通过 `_create_fuse_error()` 写入。错误状态在 `reset()` 和 PREDELETE 时被清除。

### 3.6 日志

四个统一日志方法 `_log_debug` / `_log_info` / `_log_warning` / `_log_error`，全部委托 `FuseLogger`，传入类名 `"BaseVariable"`、`log_level`、消息、以及 `variable_name` 作为上下文标识。

### 3.7 序列化（轻量）

#### `serialize() -> Dictionary` / `deserialize(data)`
轻量字典序列化，仅含 name/value/persistent/modification_count/last_modified_time。`deserialize` 还会把 `is_initialized` 置 true。**注意**：这不是 `.tres` 持久化路径——真正的资源持久化走 `GlobalVariableResource`（见 §6.4）。

#### `clone() -> BaseVariable`（实例方法）
深拷贝所有属性到新 `BaseVariable.new()` 实例（注意：不拷贝 `scope`、`auto_create`、`creation_time`——这是个**已存在的小遗漏**，与静态版 `clone_variable()` 行为不同）。

### 3.8 验证

#### `validate_configuration() -> Array[String]`
返回配置错误字符串数组（**非** FuseError 列表，纯本地化字符串）。当前规则：
- `variable_name` 为空 → append `FuseLocalization.translate("FUSE_ERROR_VAR_NAME_EMPTY")`
- `scope == GLOBAL and not persistent` → **不再视为错误**，仅 `_log_warning` 提示"将在场景退出时被自动清理"（旧稿描述的"全局变量必须启用持久化"的强制规则已放宽为建议）

返回空数组即通过。

---

## 4. 静态工厂方法

`BaseVariable` 提供丰富的静态工厂，全部位于文件末尾"内置工厂模式"区段。

| 方法 | 用途 | 备注 |
|------|------|------|
| `create(name, val, scope = LOCAL)` | 核心创建入口 | 空名 push_error 并返回 null；调 `_configure_by_scope` 设默认 persistent/auto_create；置 `is_initialized = true` |
| `create_local(name, val)` | 便捷 LOCAL 创建 | 转发 `create` |
| `create_global(name, val, persist = true)` | 便捷 GLOBAL 创建 | 转发 `create` 后强制 `persistent = persist` |
| `create_player_health(health = 100.0)` | 游戏常用 | GLOBAL + persistent，名 `"player_health"` |
| `create_player_score(score = 0)` | 游戏常用 | GLOBAL + persistent，名 `"player_score"` |
| `create_player_level(level = 1)` | 游戏常用 | GLOBAL + persistent，名 `"player_level"` |
| `create_temp_timer(name = "temp_timer", duration = 0.0)` | 临时计时器 | LOCAL，非持久化 |
| `create_batch(variables_data: Array)` | 批量创建 | 元素为 `{name, value, scope}` 字典；空名/格式错跳过并 push_warning |
| `from_config(config: Dictionary)` | 从配置字典创建 | 解析 `scope` 字符串（local/scope/global；`"trigger"` 视为弃用别名→LOCAL）；额外支持 persistent/auto_create/log_level 字段 |
| `clone_variable(original, new_name = "")` | 静态克隆 | 与实例 `clone()` 不同——此版**会**拷贝 scope/auto_create/creation_time |

#### `_configure_by_scope(scope)` 私有默认值

| 作用域 | auto_create | persistent |
|--------|-------------|------------|
| LOCAL  | true  | false |
| SCOPE  | true  | false |
| GLOBAL | false | true  |

---

## 5. 信号机制与已知 bug

### 5.1 三个信号

```gdscript
signal value_changed(old_value: Variant, new_value: Variant)
signal value_modified(value: Variant)
signal variable_reset()
```

### 5.2 ⚠️ 实际 bug：value setter 不 emit `value_modified`

`value` 字段的 setter（13–20 行）只 `emit value_changed`，**不 emit `value_modified`**：

```gdscript
@export var value: Variant = null:
    set(new_value):
        var old_value = value
        value = new_value
        last_modified_time = Time.get_ticks_msec() / 1000.0
        modification_count += 1
        _log_debug("Variable value changed from %s to %s" % [str(old_value), str(new_value)])
        value_changed.emit(old_value, new_value)
        # 注意：此处未 emit value_modified
```

而 `set_value()`（105–122 行）会同时 emit 两个信号：

```gdscript
func set_value(new_value: Variant) -> bool:
    var old_value = value
    value = new_value              # 触发 setter，emit value_changed（第一次）
    last_modified_time = ...
    modification_count += 1
    value_changed.emit(old_value, new_value)   # 第二次 emit value_changed
    value_modified.emit(new_value)             # emit value_modified
    return true
```

**后果**：
- 直接对 `variable.value = X` 赋值（包括 Inspector、`deserialize`、`clone`、`load_from_resource` 等内部路径）：`value_changed` 触发一次，`value_modified` **完全不触发**
- 通过 `variable.set_value(X)`：`value_changed` 触发**两次**（setter 一次 + 显式一次），`value_modified` 触发一次

监听 `value_modified` 的代码（如 UI 双向绑定）在直接赋值路径下会漏事件；监听 `value_changed` 的代码（如 `GlobalVariableManager._on_variable_changed`）在 `set_value` 路径下会收到两次。**调用方应统一使用 `set_value()`**，并避免在 setter 内重复 emit。

### 5.3 `variable_reset`
仅由 `reset()` 发出，无 payload。

---

## 6. 架构关系：BaseVariable 与变量系统七类

`BaseVariable` 是变量系统的"数据记录"，但它本身不解决"变量存在哪里、怎么找到"。这部分职责分布在下列协作类中。理解 BaseVariable 必须理解它的协作图。

### 6.1 协作总览

```
                   ┌─────────────────────────────────────┐
                   │   BaseVariable (Resource, 数据载体)   │
                   │   - value: Variant                   │
                   │   - scope: int (LOCAL/SCOPE/GLOBAL)  │
                   │   - persistent / auto_create / stats │
                   └──────────────┬──────────────────────┘
                                  │ 由下列三层按 scope 分别存放
                  ┌───────────────┼───────────────┐
                  ▼               ▼               ▼
            [LOCAL]           [SCOPE]          [GLOBAL]
        VariableContext   ScopeVariable-    GlobalVariable-
        (RefCounted,      Container         四件套
         EC 子系统)        (Node)            (见 §6.4)
        local_variables   _variables        Manager._variables
          = Variant       = Variant           = BaseVariable
        (裸值,非BV)       (裸值,非BV)        (BaseVariable 实例)
```

> 关键事实：LOCAL 与 SCOPE 层在容器中**只存裸 Variant 值**，不存 BaseVariable 实例；只有 GLOBAL 层（`GlobalVariableManager._variables`）以 BaseVariable 实例为值。BaseVariable 工厂创建的对象主要用于：GLOBAL 注册、序列化/克隆、UI 展示。

### 6.2 VariableContext（LOCAL 层核心）

**源文件:** `addons/fuse/core/base/variable_context.gd`（463 行，`extends RefCounted`）

ExecutionContext 的变量子系统，承载：
- LOCAL 变量 CRUD（`set_variable` / `get_variable` / `has_variable` / `add_variable`，按字符串 scope 分发）
- LRU 变量名缓存（`_variable_name_cache` + `_cache_access_order`，上限 1000，超限时淘汰 1/5）
- 索引访问优化（`precompile_variable_access` / `set_variable_by_index` / `get_variable_by_index`）
- 三层作用域分发（`_set_local_variable` / `_set_scope_variable` / `_set_global_variable`）
- 作用域容器查找（`_find_scope_container`：trigger → target → owner 顺序调 `ScopeVariableManager.find_nearest_scope`）
- 变量快照（断点调试用 `get_all_local_variables_snapshot` / `get_all_scope_variables_snapshot` / `get_all_global_variables_snapshot`）
- 循环控制标志（`_break_loop_flag` / `_continue_loop_flag` + 嵌套栈 `_loop_flag_stack`）

`add_variable(variable: BaseVariable)` 是 BaseVariable 与 VariableContext 的直接接口：它从 BaseVariable 读取 `variable.scope`，若是 GLOBAL 则转发 `_set_global_variable`，否则按 LOCAL 处理——即将 `variable.value` 裸值写入 `local_variables` 字典。

> EC 与 VariableContext 的关系：EC 是 VariableContext 的**门面**。`execution_context.gd` 持 `_variable_context: VariableContext`，自身保留 `local_variables` 作为"兼容引用"指向 `_variable_context.local_variables`（同一字典对象）。所有 EC 上的变量方法委托 VariableContext。

### 6.3 ScopeVariableContainer（SCOPE 层）

**源文件:** `addons/fuse/core/base/scope_variable_container.gd`（183 行，`extends Node`）

附加到场景节点的 Node 组件，为该节点子树提供作用域存储：
- `@export var variables: Dictionary[String, Variant]`（**裸 Variant 值**，非 BaseVariable）
- `scope_id: String` 标识；`_enter_tree` 时 `call_deferred("_register_scope")` 注册到 `ScopeVariableManager`
- 三种 `InheritanceMode`：NONE / READ_ONLY（默认）/ READ_WRITE
- `get_scope_chain()` 返回从根到当前的容器链
- 三个信号：`scope_variable_changed(name, old, new)` / `scope_variable_added(name)` / `scope_variable_removed(name)`
- 与 BaseVariable 无直接耦合——它存的是裸 Variant，作用域查找由 VariableContext/VariableOperations 触发

`ScopeVariableManager`（`addons/fuse/core/scope_variable_manager.gd`，`extends Node`，autoload）提供 `find_nearest_scope(node)` 自底向上查找。

### 6.4 GlobalVariable 四件套（GLOBAL 层）

GLOBAL 层是 BaseVariable 真正作为"对象"被存管的层。四个类分工：

| 类 | 类型 | 文件 | 职责 |
|----|------|------|------|
| **GlobalVariableManager** | `extends RefCounted` | `core/global_variable_manager.gd`（437 行） | 事实核心。静态 `_instance` 单例 + `get_instance()`。变量 CRUD（`add_variable` / `get_variable` / `has_variable` / `remove_variable`），所有操作 `Mutex` 保护。`_variables: Dictionary` 直接存 BaseVariable 实例。提供线程安全迭代器（`get_all_variables_snapshot` / `get_variables_safe` / `get_variables_batch_thread_safe`）和持久化（`save_to_resource` / `save_persistent_to_resource` / `load_from_resource`，全部经 `GlobalVariableResource` 序列化）。三个信号：`variable_added` / `variable_removed` / `variable_changed`。 |
| **GlobalVariableResource** | `extends Resource` | `core/global_variable_resource.gd` | 序列化数据结构。`@export var variables: Dictionary` 存标准化字典 `{value, scope, persistent, description}`。`add_variable` / `set_variable` / `get_variable` / `get_variable_names` / `validate` / `cleanup_invalid_variables`。带版本号、作者、标签元数据。 |
| **GlobalVariableService** | `extends RefCounted` | `core/global_variable_service.gd` | 纯 RefCounted 中间层。`_init` 时 `_manager = GlobalVariableManager.get_instance()`，所有方法对齐 Assistant 命名（`add_global_variable` / `get_global_variable` 等）并转发 Manager。**用途**：无场景节点时（如 Editor、单测、纯逻辑环境）作为 Assistant 脱树时的 `_service` 兜底。 |
| **GlobalVariableAssistant** | `extends Node` | `core/global_variable_assistant.gd` | 场景节点层。`@tool` Node，挂在场景树中提供 Inspector 配置（`resource_path` / `auto_load_on_ready` / `auto_save` / `auto_save_on_change` / `cleanup_on_exit`）。持有 `_service: GlobalVariableService` 引用，CRUD 全部委托。负责生命周期：`_ready` 注册 Manager 信号 + 加载资源；`_exit_tree` / `WM_CLOSE_REQUEST` 自动保存持久化变量 + 清理非持久化变量。延迟保存由 `Timer` 节点节流（`auto_save_delay`）。`get_instance()` 优先返回场景中的节点，否则构造一个无场景 Assistant + Service 兜底。 |

#### 四件套调用链

```
Event/Instruction 变量操作
        │
        ▼ （@tool Node, 场景层）
GlobalVariableAssistant.add_global_variable(name, variable)
        │  委托
        ▼ （RefCounted, 命名对齐层）
GlobalVariableService.add_global_variable(name, variable)
        │  转发
        ▼ （RefCounted, 事实核心 + Mutex）
GlobalVariableManager.add_variable(name, variable)
        │  连接 variable.value_changed → _on_variable_changed
        ▼
emit variable_added(name, variable)  → Assistant 转发为 variable_added
                                     → 持久化变量触发延迟保存
```

> `GlobalVariableManager` **不是** Node 单例。它是 `RefCounted`，通过 `static var _instance = GlobalVariableManager.new()` 在类加载时构造，配 `get_instance()` 暴露。`_notification(PREDELETE)` 仅清 `_variables`。旧稿"单例 Node"描述错误。

### 6.5 VariableOperations（统一访问工具）

**源文件:** `addons/fuse/core/utils/variable_operations.gd`（`extends RefCounted`，全静态方法）

无状态工具类，提供按 `BaseVariable.VariableScope` 枚举分发的统一 API：
- `get_variable(context, name, scope, default)` / `set_variable(context, name, scope, value)` / `has_variable(context, name, scope)`
- `get_scope_container(context, search_node = null)` —— SCOPE 查找入口，经 `ScopeVariableManager.find_nearest_scope`

特殊行为：`_set_local_variable` 在写入 `ExecutionContext.local_variables` 后，**额外**把值写入 `context.trigger.set_meta("local_variable_" + name, value)`，让 Event 子类（如 OnIntervalWithVariable）也能从 Trigger 节点 meta 读到 LOCAL 变量——这是 Event 与 ExecutionContext 共享 LOCAL 变量的变通方案。

---

## 7. 已废弃与历史遗留

### 7.1 VariableContainer（@deprecated）

**源文件:** `addons/fuse/core/base/variable_container.gd`（1188 行，`extends Resource`）

文件头明确标注 `⚠️ 已废弃 - 2026-02-08`，迁移指引：
- 局部变量 → `ExecutionContext.local_variables`（即 VariableContext）
- 全局变量 → `GlobalVariableAssistant`

它自带一个**不同的** `enum VariableScope { LOCAL = 0, GLOBAL = 1 }`（二值，与 BaseVariable 的三值枚举不兼容），内含 `VariableData` 内部类、索引存储、缓存、依赖图等大量重复实现。新代码不应使用。本报告仅作存在性记录，不展开。

### 7.2 BaseVariable 内的 ConfigFile 持久化（@deprecated）

`_save_to_storage` / `_load_from_storage` / `_clear_storage` 三个方法及常量 `STORAGE_SECTION` / `STORAGE_CONFIG_PATH` 均标 `@deprecated`，注释明确"请使用 GlobalVariableManager.save_to_resource() 进行持久化"。这些方法保留向后兼容，操作 `user://fuse_variables.cfg` ConfigFile。它们与 `_serialize_value` / `_parse_value_from_string` 等辅助方法（覆盖 NIL/BOOL/INT/FLOAT/STRING/VECTOR2/VECTOR3/COLOR/ARRAY/DICT/PackedArray/Base64/NodePath 全格式）配套，但不应在新项目使用。

---

## 8. 与 BaseEvent 的关联

`BaseEvent`（`addons/fuse/core/base/base_event.gd`）在文件头 preload 了 `VariableOperations` 和 `VariableScopeUtils`，用于在事件触发时读写变量。事件子类**不直接持有** BaseVariable，而是通过 ExecutionContext 间接交互。BaseVariable 与 BaseEvent 没有直接耦合点——它们的关联完全经由 EC/VariableContext/VariableOperations 中转。

---

## 9. 子类化模式

`BaseVariable` 设计上**不强制子类化**。绝大多数场景应直接 `BaseVariable.create(...)` 创建实例。若需要派生（例如封装业务语义），建议模式：

```gdscript
class_name MyGameVariable extends BaseVariable

# 业务字段（@export 序列化）
@export var business_tag: String = ""

# 重写验证（追加业务规则）
func validate_configuration() -> Array[String]:
    var errors = super.validate_configuration()
    if business_tag.is_empty():
        errors.append("business_tag 不能为空")
    return errors

# 业务方法（统一走 set_value 以触发完整信号链）
func apply_delta(delta: float) -> void:
    set_value(to_number() + delta)
```

注意事项：
- 子类若重写 `_init`，须调 `super._init()` 或自行设置 `creation_time` / `last_modified_time`
- 修改值时统一用 `set_value()`，避免 §5.2 描述的信号不一致
- 不要在子类持有 Node 引用（BaseVariable 是 Resource，节点引用会破坏序列化）

---

## 10. 总体评估

### 优点

1. **极简数据模型**：单字段 `value: Variant` + 作用域枚举 + 计数，覆盖绝大多数用例
2. **职责清晰**：BaseVariable 只做"数据记录"，存管职责分散到 Context/Container/Manager 三层，单一职责
3. **统一错误容器**：`_fuse_error` + `_create_fuse_error` 与 Fuse 全局错误体系一致
4. **工厂方法完备**：从通用 `create` 到游戏专用 `create_player_health/score/level`，覆盖典型场景
5. **废弃路径明确**：ConfigFile 持久化和 VariableContainer 都有清晰 @deprecated 标注和迁移指引
6. **线程安全下沉**：BaseVariable 本身无线程语义，并发安全由 `GlobalVariableManager` 的 Mutex 统一守护

### 已知问题

1. **value setter 信号 bug**（§5.2）：直接赋值不 emit `value_modified`，`set_value` 路径下 `value_changed` 双发。需要调用约定或修复 setter
2. **`clone()` 实例方法不完整**：不拷贝 `scope` / `auto_create` / `creation_time`，与静态 `clone_variable()` 行为不一致
3. **`set_value` 与 setter 计数重复**：`modification_count` 和 `last_modified_time` 在 setter 和 `set_value` 中各更新一次（值相同，无害但冗余）
4. **`set_value` 永远返回 true**：返回类型 `bool` 暗示可能失败，但无失败路径，类型语义偏弱
5. **VariableContainer 仍存在**：1188 行废弃代码仍在仓库，增加维护负担与混淆风险（其内部 VariableScope 二值枚举与 BaseVariable 三值枚举不兼容）

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-07-07
**版本**: 2.0（重写，替代臆造 API 旧稿）
**参照代码版本**: base_variable.gd @ 1073 行
