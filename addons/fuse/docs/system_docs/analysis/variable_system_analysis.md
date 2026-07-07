# Variable System 分析报告

## 文档概述

本报告对 Fuse 可视化编程系统的「变量子系统」进行整体分析。变量系统是事件驱动 / 指令执行的数据底座：Events、Conditions、Instructions 通过统一的读写接口访问变量，无需关心存储位置。

变量系统经过多次分化演进，目前由 **7 个生产类 + 2 个工具类 + 1 个废弃类** 组成，覆盖「值定义 / 三层作用域存储 / 全局持久化服务 / 静态门面」四个层次。早期文档（base_variable_analysis、fuse_architecture §4）多停留在「BaseVariable + 单例 Manager」2~3 类的旧描述，本报告依据源码梳理完整的 7+ 类职责与协作链路。

**关键源文件:**

| 文件 | 行数 | 角色 |
|------|------|------|
| `core/base/base_variable.gd` | 1073 | 变量值基类（Resource） |
| `core/base/variable_context.gd` | 463 | EC 变量子系统（RefCounted） |
| `core/base/variable_container.gd` | 1188 | **@deprecated 2026-02-08** |
| `core/base/scope_variable_container.gd` | 184 | 作用域容器（Node） |
| `core/scope_variable_manager.gd` | 159 | 作用域单例（Node） |
| `core/global_variable_manager.gd` | 438 | 全局变量服务（RefCounted 单例） |
| `core/global_variable_assistant.gd` | 639 | 场景代理（Node） |
| `core/global_variable_resource.gd` | 447 | 持久化数据载体（Resource） |
| `core/global_variable_service.gd` | 113 | 无场景服务层（RefCounted） |
| `core/utils/variable_operations.gd` | 338 | 静态门面工具 |
| `core/utils/variable_scope_utils.gd` | 388 | 作用域转换工具 |

---

## 1. 类清单与职责对照表

| 类名 | 基类 | 单例 | 行数 | 职责 |
|------|------|------|------|------|
| `BaseVariable` | Resource | 否 | 1073 | 单变量值载体：值 / 类型 / scope / 持久化标志 / 修改计数 / 信号；内建工厂 `create / create_local / create_global / from_config / clone_variable` |
| `VariableContext` | RefCounted | 否 | 463 | `ExecutionContext` 的变量子系统：三层作用域分发、LRU 名字缓存（1000）、索引访问、变量快照、循环控制 break/continue 栈 |
| `ScopeVariableContainer` | Node | 否 | 184 | 附加到节点的 SCOPE 变量容器；维护父子作用域链；`scope_id` 注册 |
| `ScopeVariableManager` | Node | 是 | 159 | 作用域注册表 + 查找（向上遍历父链）；`find_nearest_scope(node)` |
| `GlobalVariableManager` | RefCounted | 是 | 438 | 全局变量核心服务：CRUD + Mutex 线程安全 + 8 个 `_thread_safe` API + 信号；纯逻辑层 |
| `GlobalVariableAssistant` | Node | 是 | 639 | 场景代理：注册到 Manager、自动加载 / 自动保存、Timer 延迟保存、清理非持久化变量；持有 `GlobalVariableService` 兜底 |
| `GlobalVariableResource` | Resource | 否 | 447 | 持久化数据载体：`variables: Dictionary`，每个值标准化为 `{value, scope, persistent, description}`；`validate()` / `cleanup_invalid_variables()` |
| `GlobalVariableService` | RefCounted | 否 | 113 | 无场景时的薄层服务，命名风格对齐 Assistant，全部委托 Manager |
| `VariableOperations` | RefCounted | 否（全静态） | 338 | 静态门面：`get/set/has_variable(context, name, scope, ...)` 三层分发；面向指令 |
| `VariableScopeUtils` | RefCounted | 否（全静态） | 388 | 枚举↔字符串↔显示名互转；`ScopeSource` 枚举与 Inspector 属性注入 |
| `VariableContainer` ⚠️ | Resource | 否 | 1188 | **@deprecated 2026-02-08**，被 `ExecutionContext.local_variables` + `GlobalVariableAssistant` 取代 |

---

## 2. 三层作用域模型

### 2.1 作用域枚举

`BaseVariable.VariableScope`（base_variable.gd:41-45）定义三值：

```gdscript
enum VariableScope {
    LOCAL = 0,   # 局部变量（ExecutionContext.local_variables）
    SCOPE  = 1,  # 作用域变量（ScopeVariableContainer）
    GLOBAL = 2   # 全局变量（GlobalVariableAssistant → Manager）
}
```

> 注：废弃的 `VariableContainer.VariableScope`（variable_container.gd:33-36）只有 `LOCAL/GLOBAL` 二值，已落后于三层模型。

### 2.2 各层存储位置与生命周期

| 层 | 存储位置 | 生命周期 | 持久化 | 创建方式 |
|----|----------|----------|--------|----------|
| **LOCAL** | `VariableContext.local_variables: Dictionary` | 单次 ExecutionContext | 否 | 指令运行时 set 即创建 |
| **SCOPE** | `ScopeVariableContainer._variables: Dictionary[String, Variant]` | 节点进/出场景树 | 否 | 在场景中放置 `ScopeVariableContainer` 节点 |
| **GLOBAL** | `GlobalVariableManager._variables: Dictionary`（单例） | 整个应用 | 是（`persistent=true`） | Assistant / Service / Manager 任意 API 添加 |

### 2.3 作用域查找链（写入与读取的统一规则）

**LOCAL 写入**（`VariableOperations._set_local_variable`, variable_operations.gd:256-271）：双写策略
1. `context.set_variable(name, value, "local")` 写入 EC
2. 同时写入 `context.trigger.set_meta("local_variable_<name>", value)` —— 让 Event（如 `OnIntervalWithVariable`）也能访问 LOCAL 变量的变通方案

**SCOPE 查找**（`VariableContext._find_scope_container`, variable_context.gd:168-181）：
- 通过 `ScopeVariableManager.get_instance().find_nearest_scope(node)` 向上遍历父链
- 搜索起点优先级：`context.trigger` → `context.target` → `context.owner`
- 未找到则 fallback 到 LOCAL（push_warning）

**GLOBAL 读取**（`VariableContext.get_variable` local 分支, variable_context.gd:97-104）：
- LOCAL 未命中时，**自动 fallback 检查 GLOBAL**（通过 `_global_variable_assistant.get_global_variable(name)`）
- 这是隐式的「LOCAL 找不到就找 GLOBAL」链路，与 SCOPE 的显式 fallback 不同

### 2.4 ScopeSource 二级选择（仅 SCOPE 层）

`VariableScopeUtils.ScopeSource`（variable_scope_utils.gd:160-165）为 SCOPE 变量提供 4 种容器定位策略：

| 值 | 含义 | 实现 |
|----|------|------|
| `NEAREST` | 最近的作用域容器（默认） | `VariableOperations.get_scope_container(context)` |
| `CUSTOM_ID` | 指定 `scope_id` | `manager.get_scope_by_id(custom_scope_id)` |
| `TRIGGER_SCOPE` | Trigger 节点上的作用域 | `get_scope_container(context, context.trigger)` |
| `TARGET_NODE` | Target 节点上的作用域 | `get_scope_container(context, context.get_node(target_node_path))` |

`validate_scope_source_property`（line 248）控制 Inspector 中 `custom_scope_id` / `target_node_path` 的动态可见性；`append_scope_source_properties`（line 360）注入动态属性列表。

---

## 3. 核心 API

### 3.1 BaseVariable（单变量 API）

```gdscript
# 工厂（静态）
static func create(name, val, scope = LOCAL) -> BaseVariable
static func create_local(name, val) -> BaseVariable
static func create_global(name, val, persist = true) -> BaseVariable
static func from_config(config: Dictionary) -> BaseVariable
static func clone_variable(original, new_name = "") -> BaseVariable

# 读写
func get_value() -> Variant       # 自增 access_count，懒初始化
func set_value(new_value) -> bool # 无类型校验，直接赋值
func has_value() / is_empty()

# 类型与比较
func get_type_name() / get_godot_type() / to_number() / to_bool() / to_array()
func equals / not_equals / greater_than / less_than / greater_equal / less_equal

# 状态
func reset()                       # 清值、清错误、emit variable_reset
func get_info() -> Dictionary      # 调试快照
func get_creation_info()           # 含 scope / access_count / persistent
func validate_configuration() -> Array[String]

# 序列化
func serialize() / deserialize(data)
func clone() -> BaseVariable
```

**信号**：`value_changed(old, new)` / `value_modified(value)` / `variable_reset()`

> ⚠️ `set_value` 直接赋值，**无任何类型校验**（AUDIT_REPORT §3.7 已确认旧文档中 `_validate_value()` 是臆造 API）。

### 3.2 VariableContext（三层分发）

```gdscript
func set_variable(name, value, scope = "local") -> bool   # 三层分发
func get_variable(name, default = null, scope = "local") -> Variant
func add_variable(name, variable: BaseVariable) -> bool   # 按 variable.scope 路由
func has_variable(name) -> bool                           # 三层合并检查
func get_variable_object(name) -> BaseVariable            # 高级 API

# 索引访问优化（预编译）
func precompile_variable_access(names: Array[String])
func set/get_variable_by_index(index)
func get_variable_index(name) -> int

# 快照（断点调试）
func get_all_local_variables_snapshot() -> Dictionary
func get_all_scope_variables_snapshot() -> Dictionary
func get_all_global_variables_snapshot() -> Dictionary

# 循环控制
func set_break_loop() / set_continue_loop()
func should_break_loop() / should_continue_loop()
func clear_loop_flags() / push_loop_flags() / pop_loop_flags()

# 清理与复制
func cleanup()
func duplicate(p_deep = true) -> VariableContext
```

### 3.3 GlobalVariableManager（全局服务核心）

```gdscript
# CRUD
func add_variable(name, variable) -> bool
func get_variable(name) -> BaseVariable
func has_variable(name) -> bool
func remove_variable(name) -> bool
func get_all_variable_names() -> Array[String]
func get_variable_count() -> int
func clear_all_variables()

# 持久化
func save_to_resource(path) -> bool              # 全量
func save_persistent_to_resource(path) -> bool   # 仅 persistent=true
func load_from_resource(path) -> bool            # 支持新/旧两种格式

# 线程安全（Mutex 保护，8 个 API）
func get_variable_thread_safe(name)
func has_variable_thread_safe(name)
func set_variable_thread_safe(name, variable)
func set_variable_value_thread_safe(name, value)
func get_variables_batch_thread_safe(names) -> Dictionary
func get_all_variables_snapshot() -> Dictionary   # 深拷贝快照
func get_variables_safe() -> Dictionary           # 安全迭代器

# 引用类型通知
func notify_variable_content_changed(name)  # Array/Dictionary 内容修改时手动触发
```

**信号**：`variable_added(name, variable)` / `variable_removed(name)` / `variable_changed(name, old, new)`

### 3.4 GlobalVariableAssistant（场景代理）

```gdscript
# 单例
static func get_instance() -> GlobalVariableAssistant  # 优先场景节点，无场景时构造 Service 兜底

# 资源管理
func load_resource(path) / save_current_resource() / save_persistent_variables()
func set_current_resource(resource) / create_new_resource(path, description)
func register_to_manager() / unregister_from_manager()

# 变量 CRUD（全部委托 _service → Manager）
func add_global_variable(name, variable) / remove_global_variable(name)
func get_global_variable(name) / has_global_variable(name)
func get_all_global_variable_names() / get_all_global_variables_info()
```

**关键 @export**：`auto_save` / `auto_load_on_ready` / `cleanup_on_exit` / `auto_save_on_change`（默认 false）/ `auto_save_delay`（默认 1.0s）

**信号**：`resource_changed` / `variable_added` / `variable_removed` / `variable_modified` / `save_completed` / `load_completed`

### 3.5 ScopeVariableContainer + ScopeVariableManager

```gdscript
# ScopeVariableContainer
func set_variable(name, value) / get_variable(name, default) / has_variable / remove_variable
func get_variable_names() -> PackedStringArray
func clear_variables()
func get_parent_scope() / get_child_scopes() / get_scope_chain()

# ScopeVariableManager（单例）
static func get_instance() -> ScopeVariableManager
func register_scope(container) / unregister_scope(container)
func get_scope_by_id(scope_id)
func find_nearest_scope(node)                  # MAX_SCOPE_SEARCH_DEPTH=100
func find_scope_by_node_path(node_path, ctx)
func get_scope_node_chain(node) -> Array[ScopeVariableContainer]
```

**InheritanceMode**（scope_variable_container.gd:45-49）：`NONE` / `READ_ONLY`（默认）/ `READ_WRITE`

### 3.6 VariableOperations（静态门面）

```gdscript
static func get_variable(context, name, scope, default = null) -> Variant
static func set_variable(context, name, scope, value) -> bool
static func has_variable(context, name, scope) -> bool
static func get_scope_container(context, search_node = null) -> ScopeVariableContainer
static func set_log_level(level)
```

---

## 4. 架构关系

### 4.1 三层架构（GLOBAL 层）

```
┌──────────────────────────────────────────────────────────────┐
│  指令 / Event / Condition                                    │
│     ↓ (静态调用)                                             │
│  VariableOperations.set/get_variable(context, name, scope)   │
│     ↓ (GLOBAL 分支)                                          │
│  GlobalVariableAssistant (Node, 场景代理)                    │
│     ↓ (_service 委托)                                        │
│  GlobalVariableService (RefCounted, 无场景兜底)              │
│     ↓ (_manager 委托)                                        │
│  GlobalVariableManager (RefCounted 单例, Mutex)              │
│     ↓ (load/save)                                            │
│  GlobalVariableResource (Resource) ← ResourceSaver/Loader    │
└──────────────────────────────────────────────────────────────┘
```

**双层委托设计动机**：
- **Manager 是事实服务核心**：纯 RefCounted + Mutex，可在任何线程使用
- **Assistant 是场景代理**：承担 `_ready` 自动加载、`_exit_tree` 自动保存与清理、Timer 延迟保存等节点生命周期联动
- **Service 是无场景兜底**：当 `Engine.get_main_loop().current_scene` 为空（编辑器、单元测试）时，`get_instance()` 构造一个 `_service = GlobalVariableService.new()` 的 Assistant，保证 CRUD 可用，但 auto_load/auto_save/cleanup 不生效

### 4.2 SCOPE 层架构

```
ScopeVariableManager (Node 单例, 挂在 root 下)
    ↑ register_scope / find_nearest_scope
ScopeVariableContainer (Node, 任意场景节点)
    ↑ _parent_scope / _child_scopes（作用域链）
    └── _variables: Dictionary[String, Variant]
```

### 4.3 LOCAL 层架构

```
ExecutionContext (Node)
    └── VariableContext (RefCounted)
            ├── local_variables: Dictionary
            ├── _variable_name_cache: Dictionary (LRU, 1000)
            ├── _variable_index_map / _variable_array (预编译索引)
            ├── _global_variable_assistant: GlobalVariableAssistant (跨层引用)
            └── _loop_flag_stack (循环控制)
```

### 4.4 VariableContext ↔ GlobalVariableAssistant 跨层耦合

`VariableContext` 持有 `_global_variable_assistant` 引用（variable_context.gd:21, 247-256）：
- LOCAL 读未命中时，直接走 assistant 查 GLOBAL（隐式 fallback）
- 由 `set_global_variable_assistant(assistant)` 在 EC 初始化时注入

这是 LOCAL→GLOBAL fallback 链路的事实实现，无需经过 VariableOperations。

---

## 5. 生命周期与持久化

### 5.1 LOCAL 变量生命周期

```
ExecutionContext 创建
    └── VariableContext._init(owner) → 空 local_variables
指令运行时 set_variable(name, value, "local")
    ├── _set_local_variable → local_variables[name] = value
    └── VariableOperations._set_local_variable → trigger.set_meta("local_variable_<name>", value)
ExecutionContext.cleanup()
    └── VariableContext.cleanup() → 清空 local_variables、断开 global 引用
```

**无持久化**：LOCAL 变量随 EC 销毁即丢失。

### 5.2 SCOPE 变量生命周期

```
ScopeVariableContainer._enter_tree()
    ├── call_deferred("_register_scope")        → ScopeVariableManager.register_scope(self)
    └── call_deferred("_register_with_parent_scope")  → 维护父子链
节点存在期间：set/get/remove_variable
ScopeVariableContainer._exit_tree()
    ├── _unregister_scope()
    ├── _unregister_from_parent_scope()
    └── _child_scopes.clear()
```

**无自动持久化**：SCOPE 变量随场景退出销毁。如需保留，开发者自行序列化 `_variables`。

### 5.3 GLOBAL 变量持久化流程

```
1. 应用启动
   GlobalVariableAssistant._ready()
     ├── auto_register → register_to_manager() 连接 Manager 信号
     └── auto_load_on_ready
            ├── resource_path 非空 → load_resource(path) → Manager.load_from_resource(path)
            └── current_resource 已设 → _load_from_current_resource()

2. 运行时修改
   Manager.add_variable / variable.set_value
     └── variable_changed 信号 → Assistant._on_manager_variable_changed
            └── if persistent and auto_save_on_change → _request_delayed_save()
                   └── Timer(auto_save_delay) 超时 → _save_persistent_variables()

3. 应用退出
   Assistant._exit_tree() / _notification(WM_CLOSE_REQUEST)
     └── _perform_save_and_cleanup()
            ├── auto_save and resource_path 非空 → _save_persistent_variables()
            │     └── Manager.save_persistent_to_resource(path) → ResourceSaver.save()
            ├── cleanup_on_exit → _cleanup_non_persistent_variables()
            │     └── 遍历 Manager，remove 所有 persistent=false 的变量
            └── _is_registered → unregister_from_manager() 断开信号
```

**关键设计选择**：
- **仅持久化变量被保存**：`save_persistent_to_resource` 过滤 `persistent=false`，避免运行时临时变量污染存档
- **`auto_save_on_change` 默认 false**：推荐通过 `SaveGlobalVariables` 指令显式手动保存（global_variable_assistant.gd:21）
- **新旧格式兼容**：`Manager.load_from_resource` 检测 `GlobalVariableResource` 类型；旧 meta 格式自动转换（global_variable_manager.gd:166-178）
- **引用类型修改**：Array/Dictionary 内容修改不触发 `value_changed`，需手动 `Manager.notify_variable_content_changed(name)`（global_variable_manager.gd:256-272）

### 5.4 Resource 数据格式

`GlobalVariableResource.variables` 中每个值标准化为字典：

```gdscript
{
    "value": <Variant>,
    "scope": <int 0/1/2>,
    "persistent": <bool>,
    "description": <String>
}
```

旧格式（裸值）通过 `_normalize_variable_data`（global_variable_resource.gd:306-331）自动包装。

`validate()`（line 256）检查：版本非空、时间戳合法、变量名是合法标识符、值可序列化（递归检查 Array/Dictionary 元素）。

---

## 6. VariableContainer 废弃说明

`VariableContainer`（variable_container.gd:1-13）于 **2026-02-08 标记 @deprecated**：

```gdscript
## ⚠️ 已废弃 - 2026-02-08
## VariableContainer 已被废弃，请使用以下替代方案：
## - 局部变量：使用 ExecutionContext.local_variables (Dictionary)
## - 全局变量：使用 GlobalVariableAssistant
```

### 6.1 被取代的职责映射

| VariableContainer 旧职责 | 取代者 |
|--------------------------|--------|
| LOCAL 变量存储（`_variables_data`） | `VariableContext.local_variables` |
| GLOBAL 变量存储 | `GlobalVariableManager._variables` |
| 依赖图（`_variable_dependencies/_dependents`） | 暂无取代（未迁移） |
| 索引存储（`_indexed_variables`） | `VariableContext._variable_index_map / _variable_array` |
| 缓存（`_unified_cache`） | `VariableContext._variable_name_cache`（LRU） |
| 作用域枚举（LOCAL/GLOBAL 二值） | `BaseVariable.VariableScope`（三层 LOCAL/SCOPE/GLOBAL） |
| 序列化（serialize/deserialize） | `GlobalVariableResource` |

### 6.2 迁移状态

源文件注释（variable_container.gd:9-11）声明：
- `OnVariableChanged` 事件已重构为使用 `GlobalVariableAssistant`
- 所有变量操作指令已使用 `ExecutionContext` 和 `GlobalVariableAssistant`
- 新代码不应再依赖此类

**保留原因**：向后兼容旧 `.tres` 资源的反序列化路径。

---

## 7. 线程安全与并发

`GlobalVariableManager` 是变量系统中唯一显式线程安全的类（global_variable_manager.gd:21, 47-72）：

- **Mutex 保护所有 `_variables` 访问**：lock 在写前、unlock 在 emit 前（避免锁内回调）
- **信号连接在锁外**：`add_variable` 在 `_mutex.unlock()` 后才 `connect(value_changed)`，防止回调重入
- **8 个 `_thread_safe` API**：供 `FuseTaskManager` / `ParallelConditionEvaluator` 并行条件检测使用
- **`get_all_variables_snapshot` / `get_variables_safe`**：返回深拷贝，迭代期间不受并发修改影响

其他类（VariableContext / ScopeVariableContainer / GlobalVariableAssistant）**非线程安全**，必须在主线程使用。

详见 [multithreading-developer-guide.md](../../dev_docs/guides/multithreading-developer-guide.md)。

---

## 8. 总体评估

### 优点

1. **职责分化清晰**：值定义（BaseVariable）/ 三层存储（VC/SVC/Manager）/ 持久化（Resource）/ 场景代理（Assistant）/ 静态门面（Operations）各司其职
2. **三层作用域语义明确**：LOCAL/SCOPE/GLOBAL 对应「单次执行 / 节点子树 / 全应用」，配合 `ScopeSource` 二级选择覆盖典型用例
3. **GLOBAL 层线程安全**：Mutex + 深拷贝快照支持并行条件评估
4. **场景解耦**：Manager 为纯 RefCounted，Assistant 承担节点联动，Service 提供无场景兜底，三者组合可在编辑器、单元测试、运行时统一工作
5. **持久化格式健壮**：新旧格式自动转换、仅持久化变量过滤、引用类型修改通知、Timer 延迟保存
6. **统一门面**：`VariableOperations` 让指令无需感知三层差异，`VariableScopeUtils` 提供 Inspector 集成

### 不足

1. **VariableContext 与 GLOBAL 隐式耦合**：LOCAL 读未命中自动 fallback 到 GLOBAL（variable_context.gd:97-104），与「LOCAL/SCOPE/GLOBAL 严格分层」的直觉相悖，调试时易混淆变量来源
2. **LOCAL 双写策略的脆弱性**：`VariableOperations._set_local_variable` 同时写 EC + Trigger meta（line 256-271），是 Event 与 EC 共享 LOCAL 变量的变通方案，未在 EC 层统一抽象
3. **SCOPE 层 fallback 到 LOCAL 静默**：`VariableContext._set_scope_variable` / `_get_scope_variable` 未找到容器时仅 `push_warning` 后 fallback 到 LOCAL（variable_context.gd:188, 196），生产环境若日志被屏蔽会导致变量「消失」到 LOCAL
4. **VariableContainer 依赖图未迁移**：废弃类的 `_variable_dependencies/_dependents`（variable_container.gd:947-1028）无取代者，相关功能若仍被使用将无法迁移
5. **VariableContext 索引访问与 LOCAL 字典双轨**：`precompile_variable_access` 后 `_variable_array` 与 `local_variables` 并存，写入路径未同步索引数组（仅 `set_variable_by_index` 走索引），存在数据不一致风险
6. **GlobalVariableManager 单例时机**：`static var _instance = GlobalVariableManager.new()`（global_variable_manager.gd:14）在类加载时即构造，若脚本加载顺序异常可能早于 FuseLogger 初始化

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-07-07
**版本**: 1.0.0
**审计依据**: [AUDIT_REPORT_2026-07-07.md](AUDIT_REPORT_2026-07-07.md) §2.4 / §3.7
