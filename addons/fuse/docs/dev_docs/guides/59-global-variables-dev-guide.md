# 全局变量开发指南

> **目标**: 为开发者提供 Fuse 全局变量系统的架构说明与接入指引，覆盖 `GlobalVariableManager` + `GlobalVariableService` + `GlobalVariableAssistant` 三层职责划分、声明/读写 API、线程安全、持久化管道以及与预设系统的集成。

**适用对象**: Fuse 系统开发者、贡献者

**最后更新**: 2026-07-19

**配套用户文档**: [54-global-variables-guide.md](../../user_docs/guides/54-global-variables-guide.md)

---

## 📋 目录

1. [双层架构总览](#双层架构总览)
2. [GlobalVariableManager（单例核心）](#globalvariablemanager单例核心)
3. [GlobalVariableService（脱树服务层）](#globalvariableservice脱树服务层)
4. [GlobalVariableAssistant（场景树助手）](#globalvariableassistant场景树助手)
5. [GlobalVariableResource（数据载体）](#globalvariableresource数据载体)
6. [变量声明与读写](#变量声明与读写)
7. [线程安全 API](#线程安全-api)
8. [持久化管道](#持久化管道)
9. [与预设系统集成](#与预设系统集成)
10. [最佳实践](#最佳实践)
11. [常见陷阱](#常见陷阱)

---

## 双层架构总览

全局变量系统采用 **Service + Assistant 双层架构**，底层由 Manager 单例支撑：

| 层 | 组件 | 类型 | 路径 | 职责 |
|----|------|------|------|------|
| 核心层 | GlobalVariableManager | RefCounted 单例 | `core/global_variable_manager.gd` | 变量 CRUD、信号、线程安全、持久化核心 |
| 服务层 | GlobalVariableService | RefCounted | `core/global_variable_service.gd` | 脱树 CRUD 门面，命名风格与 Assistant 一致 |
| 助手层 | GlobalVariableAssistant | Node | `core/global_variable_assistant.gd` | 场景树生命周期、资源绑定、自动保存/加载 |
| 数据层 | GlobalVariableResource | Resource | `core/global_variable_resource.gd` | `.tres` 存档格式 |

### 依赖关系

```
┌────────────────────────────────────────────────┐
│ GlobalVariableAssistant (Node, 场景树)          │
│  - 生命周期: _ready 自动加载 / _exit_tree 保存  │
│  - 持有 GlobalVariableService                   │
└───────────────┬────────────────────────────────┘
                │ 委托
                ▼
┌────────────────────────────────────────────────┐
│ GlobalVariableService (RefCounted, 脱树)        │
│  - add_global_variable / get_global_variable    │
│  - save_persistent_variables / load_resource    │
└───────────────┬────────────────────────────────┘
                │ 委托
                ▼
┌────────────────────────────────────────────────┐
│ GlobalVariableManager (RefCounted 单例)         │
│  - _variables: Dictionary (name → BaseVariable) │
│  - Mutex 保护 + 信号通知                        │
│  - save_to_resource / load_from_resource        │
└───────────────┬────────────────────────────────┘
                │ 序列化
                ▼
        GlobalVariableResource (.tres)
```

### 何时用哪一层

| 场景 | 推荐入口 |
|------|----------|
| 指令/运行时读写变量 | `VariableOperations.get/set_variable(context, name, GLOBAL, ...)` |
| 普通脚本读写变量 | `GlobalVariableManager.get_instance()` |
| 无场景树环境（工具脚本、测试） | `GlobalVariableService.new()` |
| 需要自动保存/加载、资源绑定 | 场景中放置 `GlobalVariableAssistant` 节点 |
| 编辑器工具（如变量监视器） | `GlobalVariableService`（见 [58-variable-watcher-dev-guide.md](58-variable-watcher-dev-guide.md)） |

---

## GlobalVariableManager（单例核心）

`GlobalVariableManager` 是事实上的数据核心，基于 `RefCounted` 单例。

### 单例访问

```gdscript
# ✅ 正确
var gvm := GlobalVariableManager.get_instance()

# ❌ 错误 — 不可 new() / preload()
var gvm = GlobalVariableManager.new()

# 检查单例是否存在（避免隐式创建）
if GlobalVariableManager.has_instance():
	pass
```

### CRUD API

| 方法 | 返回 | 说明 |
|------|------|------|
| `add_variable(name, variable)` | bool | 添加变量（BaseVariable） |
| `get_variable(name)` | BaseVariable | 获取，不存在返回 null |
| `has_variable(name)` | bool | 存在性检查 |
| `remove_variable(name)` | bool | 移除 |
| `get_all_variable_names()` | Array[String] | 所有变量名 |
| `get_variable_count()` | int | 变量数量 |
| `clear_all_variables()` | void | 清空 |
| `get_all_variables_snapshot()` | Dictionary | 全量快照（值拷贝） |
| `get_variables_safe()` | Dictionary | 安全获取变量字典 |

### 信号

| 信号 | 参数 | 触发时机 |
|------|------|----------|
| `variable_added` | name, variable | `add_variable()` 成功 |
| `variable_removed` | name | `remove_variable()` 成功 |
| `variable_changed` | name, old_value, new_value | 变量值变化（含内容级变化） |

内容级变化（如数组元素修改）需手动通知：

```gdscript
gvm.notify_variable_content_changed("inventory")
```

### 内部实现要点

- `_variables: Dictionary` 直接存储 `BaseVariable` 实例（非值拷贝）
- `_mutex: Mutex` 保护多线程访问（见[线程安全 API](#线程安全-api)）
- `_resource_path: String` 记录最近保存/加载路径

---

## GlobalVariableService（脱树服务层)

`GlobalVariableService` 是纯 `RefCounted` 门面，**不依赖场景树**，构造即获取 Manager：

```gdscript
var _manager: GlobalVariableManager

func _init():
	_manager = GlobalVariableManager.get_instance()
```

### API（命名与 Assistant 对齐）

| 方法 | 返回 | 说明 |
|------|------|------|
| `add_global_variable(name, variable)` | bool | 添加 |
| `get_global_variable(name)` | BaseVariable | 获取 |
| `has_global_variable(name)` | bool | 存在性 |
| `remove_global_variable(name)` | bool | 移除 |
| `get_all_global_variable_names()` | Array[String] | 名称列表 |
| `get_all_global_variables_info()` | Dictionary | 详细信息（调试/监视器用） |
| `get_variable_count()` | int | 数量 |
| `save_persistent_variables(path)` | bool | 仅保存 persistent 变量 |
| `load_resource(path)` | bool | 从 `.tres` 加载 |
| `create_new_resource(path, description)` | bool | 创建新资源文件 |
| `get_resource_path()` | String | 当前资源路径 |
| `get_statistics()` | Dictionary | 统计信息 |

### 使用示例

```gdscript
# 无场景树的工具脚本 / 编辑器插件中
var service := GlobalVariableService.new()

var score := BaseVariable.new()
score.variable_name = "score"
score.value = 0
score.persistent = true
service.add_global_variable("score", score)

var info := service.get_all_global_variables_info()
for name in info:
	print("%s = %s (%s)" % [name, info[name]["value"], info[name]["type"]])
```

> **设计意图**: Service 提供与 Assistant 相同的命名风格（`add_global_variable` 而非 `add_variable`），使调用方代码在"有场景树"与"无场景树"两种环境下可无痛切换。

---

## GlobalVariableAssistant（场景树助手）

`GlobalVariableAssistant` 是 `Node` 子类，负责把全局变量系统**接入场景树生命周期**。

### 访问方式

```gdscript
# ✅ 推荐：在场景中放置节点（编辑器拖入或 add_child 由场景文件完成）
# ✅ 运行时获取
var assistant := GlobalVariableAssistant.get_instance()

# ❌ 错误 — 不可手动 new() + add_child()
```

### 导出属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `current_resource` | GlobalVariableResource | null | 当前绑定资源 |
| `resource_path` | String | `""` | 资源文件路径 |
| `auto_save` | bool | true | 退出时自动保存 |
| `auto_load_on_ready` | bool | true | `_ready` 时自动加载 |
| `cleanup_on_exit` | bool | true | 退出时清理非持久化变量 |
| `auto_save_on_change` | bool | false | 变量变化时自动保存（高频开销，默认关） |
| `auto_save_delay` | float | 1.0 | 变化后延迟保存秒数（防抖） |
| `auto_register` | bool | true | 自动注册到 Manager |
| `log_level` | FuseLogger.LogLevel | INFO | 日志级别 |

### 生命周期

```
_enter_tree()   → 注册单例引用（auto_register）
_ready()        → _setup_save_timer()
                  if auto_load_on_ready → _load_from_current_resource()
运行中          → 监听 Manager 信号 → variable_added/removed/modified 转发
                  if auto_save_on_change → _request_delayed_save()（Timer 防抖）
_exit_tree()    → _perform_save_and_cleanup()
                  if auto_save → 保存
                  if cleanup_on_exit → 清理非持久化变量
```

### 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `resource_changed` | old_resource, new_resource | 资源切换 |
| `variable_added` | name, variable_data | 变量添加（转发 Manager） |
| `variable_removed` | name | 变量移除 |
| `variable_modified` | name, old_data, new_data | 变量修改 |
| `save_completed` | success, path | 保存完成 |
| `load_completed` | success, path, resource | 加载完成 |

### 关键方法

| 方法 | 说明 |
|------|------|
| `register_to_manager()` / `unregister_from_manager()` | 与 Manager 建立/断开信号连接 |
| `set_current_resource(resource)` | 切换绑定资源 |
| `load_resource(path)` | 加载指定资源 |
| `save_current_resource()` | 保存到当前资源 |
| `save_persistent_variables()` | 仅保存 persistent 变量 |
| `create_new_resource(path, description)` | 创建新资源文件 |
| `get_current_resource_info()` | 资源元信息 |

### 错误处理

Assistant 内置 `FuseError` 集成：

```gdscript
if assistant.has_fuse_error():
	var err: FuseError = assistant.get_fuse_error()
	push_error(err.get_formatted_message())
```

---

## GlobalVariableResource（数据载体）

`GlobalVariableResource` 是 `.tres` 存档的资源格式：

| 属性 | 类型 | 说明 |
|------|------|------|
| `variables` | Dictionary | 变量名 → 变量数据 |
| `description` | String | 描述 |
| `created_time` | float | 创建时间戳 |
| `last_modified` | float | 最后修改时间戳 |
| `version` | String | 版本（`CURRENT_VERSION = "2.0.0"`） |
| `author` | String | 作者 |
| `tags` | Array[String] | 标签 |

提供 `add_variable(name, variable_data, persistent)` / `set_variable()` 等方法，支持原始值或字典格式数据。

---

## 变量声明与读写

### 代码声明

```gdscript
var gvm := GlobalVariableManager.get_instance()

# 幂等初始化（推荐在 _ready 中）
if not gvm.has_variable("player_health"):
	var v := BaseVariable.new()
	v.variable_name = "player_health"
	v.value = 100
	v.persistent = true        # 持久化标记
	gvm.add_variable("player_health", v)
```

### 指令层读写（推荐）

指令中**不要**直接访问 Manager，统一走 `VariableOperations`：

```gdscript
# 读取
var value = VariableOperations.get_variable(
	context, "player_health",
	BaseVariable.VariableScope.GLOBAL,
	0  # 默认值
)

# 写入
VariableOperations.set_variable(
	context, "player_health",
	BaseVariable.VariableScope.GLOBAL,
	80
)
```

`VariableOperations` 内部按 `GLOBAL` 分支路由到 `context.global_variables`（即 Manager），同时处理存在性检查与错误日志。

### 作用域解析回顾

| 作用域 | 存储位置 | 生命周期 |
|--------|----------|----------|
| LOCAL | ExecutionContext | 单次执行 |
| SCOPE | ScopeVariableContainer | 节点生命周期 |
| GLOBAL | GlobalVariableManager | 游戏进程 |

详见 [变量系统使用指南](../../user_docs/guides/01-variable_system_guide.md)。

---

## 线程安全 API

Manager 内置 `Mutex`，提供一组 `_thread_safe` 后缀方法，供多线程指令使用：

| 方法 | 说明 |
|------|------|
| `get_variable_thread_safe(name)` | 加锁读取 |
| `has_variable_thread_safe(name)` | 加锁存在性检查 |
| `set_variable_thread_safe(name, variable)` | 加锁写入整个变量 |
| `set_variable_value_thread_safe(name, value)` | 加锁写入值 |
| `get_variables_batch_thread_safe(names)` | 批量加锁读取 |
| `get_variables_safe()` / `get_all_variables_snapshot()` | 安全快照 |

```gdscript
# 多线程 worker 中
var gvm := GlobalVariableManager.get_instance()
gvm.set_variable_value_thread_safe("progress", 0.75)
var batch := gvm.get_variables_batch_thread_safe(["hp", "mp", "exp"])
```

> **注意**: 直接访问 `get_variable()` / `add_variable()` 非线程安全。多线程场景必须使用 `_thread_safe` 系列。详见 [multithreading.md](../../multithreading.md)。

---

## 持久化管道

### Manager 级

```gdscript
var gvm := GlobalVariableManager.get_instance()

gvm.save_to_resource("user://save.tres")             # 保存全部
gvm.save_persistent_to_resource("user://save.tres")  # 仅 persistent
gvm.load_from_resource("user://save.tres")           # 加载（清空现有变量）
```

### 指令级

| 指令 | 路径 | 关键属性 |
|------|------|----------|
| SaveGlobalVariables | `instructions/variables/save_global_variables.gd` | `save_target`(ASSISTANT_RESOURCE/CUSTOM_PATH)、`custom_path`、`save_scope`(ALL/PERSISTENT_ONLY) |
| LoadGlobalVariables | `instructions/variables/load_global_variables.gd` | `load_source`、`custom_path` |

### 持久化标记

只有 `persistent = true` 的变量会被 `PERSISTENT_ONLY` / `save_persistent_to_resource()` 保存。冷却计时器等临时状态应 `persistent = false`。

---

## 与预设系统集成

预设系统通过**变量依赖声明**与全局变量交互（详见 [57-preset-system-dev-guide.md](57-preset-system-dev-guide.md)）：

1. **导出时**: `FusePreset.collect_variables()` 扫描指令，`variable_scope == 2`（GLOBAL）的变量名写入 `variables["global"]`
2. **导入时**: 导入对话框展示 global 依赖，但**不自动创建**变量 — 全局变量是项目级状态
3. **运行时**: 预设指令中的 `GetVariable/SetVariable [GLOBAL]` 通过 `VariableOperations` 路由到 Manager

### 集成分工

| 关注点 | 负责系统 |
|--------|----------|
| 声明"需要哪些全局变量" | 预设（`variables.global`） |
| 变量的创建/初始值/persistent | 项目初始化流程（SetVariable 指令或代码） |
| 跨场景持久化 | GlobalVariableAssistant + Save/Load 指令 |

### 接入检查清单

开发依赖全局变量的预设时：

- ✅ 指令使用 `variable_name` + `variable_scope` 属性（预设可自动收集依赖）
- ✅ 在游戏初始化 Trigger 中用 SetVariable [GLOBAL] 建立初始值
- ✅ 需要存档的变量设 `persistent = true`
- ❌ 不要期望预设导入自动注册全局变量

---

## 最佳实践

### 1. 缓存单例引用

```gdscript
# ✅ 缓存
var _gvm: GlobalVariableManager

func _ready():
	_gvm = GlobalVariableManager.get_instance()

# ❌ 每次调用 get_instance()
```

### 2. 幂等初始化

变量注册前一律 `has_variable()` 预检，避免覆盖已有值（尤其是 Assistant 自动加载的存档值）。

### 3. 关闭 auto_save_on_change

高频变化变量（如每帧更新的计时器）会触发磁盘 IO 风暴。推荐：
- `auto_save_on_change = false`（默认）
- 关键节点用 SaveGlobalVariables 指令手动保存
- 或利用 `auto_save_delay` 防抖

### 4. 分层选择

- 游戏运行时脚本 → Manager
- 编辑器插件/工具 → Service
- 场景级自动持久化 → Assistant 节点

### 5. 多线程只用 _thread_safe 系列

混用加锁与非加锁 API 会破坏互斥语义。

---

## 常见陷阱

### 陷阱 1: `new()` 创建 Manager

**问题**: `GlobalVariableManager.new()` 创建出第二个实例，数据分裂。

**解决**: 一律 `GlobalVariableManager.get_instance()`；用 `has_instance()` 做防御性检查。

### 陷阱 2: 手动 add_child Assistant

**问题**: `GlobalVariableAssistant.new()` + `add_child()` 绕过单例注册，生命周期回调时序异常。

**解决**: 在编辑器中将 Assistant 节点放入场景文件，或用 `get_instance()` 获取运行实例。

### 陷阱 3: 加载覆盖未保存数据

**问题**: `load_from_resource()` 会**清空现有变量**再加载，未保存的运行时数据丢失。

**解决**: 加载前先 `save_to_resource()`，或确认加载时机（游戏启动/读档点）。

### 陷阱 4: 内容级修改无信号

**问题**: 修改数组/字典元素后 `variable_changed` 不触发，UI 不刷新。

**解决**: 修改后调用 `notify_variable_content_changed(name)`。

### 陷阱 5: 指令中直接访问 Manager

**问题**: 指令里写 `GlobalVariableManager.get_instance().get_variable(...)`，绕过三层变量系统的统一路由与错误处理。

**解决**: 指令一律使用 `VariableOperations.get/set_variable(context, name, GLOBAL, ...)`。

### 陷阱 6: 多线程用非加锁 API

**问题**: worker 线程调用 `get_variable()`，与主线程写入竞争。

**解决**: 多线程路径全部替换为 `_thread_safe` 系列方法。

---

## 总结

全局变量系统开发核心要点：

1. ✅ **三层职责清晰** — Manager（数据核心）∥ Service（脱树门面）∥ Assistant（场景生命周期）
2. ✅ **单例纪律** — Manager/Assistant 均不可 `new()`，用 `get_instance()`
3. ✅ **指令走 VariableOperations** — 统一 GLOBAL 路由，不直接碰 Manager
4. ✅ **线程安全显式化** — `_thread_safe` 后缀 API + Mutex
5. ✅ **持久化标记驱动** — `persistent` 决定存档范围；`auto_save_on_change` 默认关闭
6. ✅ **预设只声明依赖** — 全局变量的创建权在项目，不在预设

**参考文档**:
- [全局变量管理指南](../../user_docs/guides/54-global-variables-guide.md)
- [预设系统开发者指南](57-preset-system-dev-guide.md)
- [变量监视器开发指南](58-variable-watcher-dev-guide.md)
- [变量操作工具类](variable-operations-utility.md)
- [多线程支持](../../multithreading.md)

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-07-19
