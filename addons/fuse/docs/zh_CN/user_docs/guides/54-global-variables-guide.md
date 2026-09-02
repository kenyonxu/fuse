> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/54-global-variables-guide.md)

# 全局变量管理指南

## 概述

Fuse 全局变量系统提供**存储管理 + 持久化**一体化方案，覆盖从变量创建到存档/读档的完整工作流。系统由以下组件构成：

| 组件 | 类型 | 路径 | 用途 |
|------|------|------|------|
| GlobalVariableManager | 单例 (RefCounted) | `core/global_variable_manager.gd` | 变量 CRUD、信号监听、持久化核心逻辑 |
| GlobalVariableAssistant | 节点 (Node) | `core/global_variable_assistant.gd` | 场景树助手，管理资源文件、自动保存加载 |
| GlobalVariableResource | 资源 (Resource) | `core/global_variable_resource.gd` | .tres 资源文件，存储变量快照 |
| SaveGlobalVariables | 指令 | `instructions/variables/save_global_variables.gd` | 存档指令 |
| LoadGlobalVariables | 指令 | `instructions/variables/load_global_variables.gd` | 读档指令 |

---

## 概念准备

Fuse 变量系统分为三层：

| 层级 | 作用域 | 用途 |
|------|--------|------|
| **Local 变量** | 所属指令序列内 | 临时中间值、传递参数 |
| **Scope 变量** | 执行上下文 (Trigger Scope、Custom ID、Target Node) | 跨指令数据传递 |
| **Global 变量** | 全局 (游戏进程生命周期) | 跨场景持久化游戏状态 |

本指南聚焦 **Global 变量**的管理与持久化。完整变量系统见 `01-variable-system-guide.md`。

---

## 快速开始

```
# 1. 创建变量 → 2. 设置值 → 3. 保存 → 4. 加载

1. 在 GlobalVariableAssistant 中配置 resource_path: "user://save.tres"
2. 放置 SetVariable → scope: GLOBAL、variable_name: "player_health"、value: 100
3. 放置 SaveGlobalVariables → save_target: Assistant Resource
4. 下次启动时 LoadGlobalVariables → load_source: Assistant Resource
```

---

## GlobalVariableManager 使用

> **⚠️ 单例模式**：`GlobalVariableManager` 基于 `RefCounted`，通过 `GlobalVariableManager.get_instance()` 获取。**不可**使用 `new()` 或 `preload()`。

### 变量 CRUD

| 方法 | 返回 | 说明 |
|------|------|------|
| `get_instance()` | GlobalVariableManager | 获取单例实例 |
| `add_variable(name, variable)` | bool | 添加变量 |
| `get_variable(name)` | BaseVariable | 获取变量，不存在返回 null |
| `has_variable(name)` | bool | 检查变量是否存在 |
| `remove_variable(name)` | bool | 移除变量 |
| `get_all_variable_names()` | Array[String] | 所有变量名称列表 |
| `get_variable_count()` | int | 变量数量 |
| `clear_all_variables()` | void | 清空所有变量 |

```gdscript
var gvm = GlobalVariableManager.get_instance()

# 创建全局变量
var hp = BaseVariable.new()
hp.variable_name = "player_health"
hp.value = 100
hp.persistent = true
gvm.add_variable("player_health", hp)

# 读取
var val = gvm.get_variable("player_health")
if val:
	print(val.value)  # 100

# 更新（自动触发信号）
val.value = 80

# 删除
gvm.remove_variable("temp_var")
```

### 信号监听

| 信号 | 参数 | 说明 |
|------|------|------|
| `variable_added` | name, variable | 变量被添加 |
| `variable_removed` | name | 变量被移除 |
| `variable_changed` | name, old_value, new_value | 变量值变化 |

```gdscript
var gvm = GlobalVariableManager.get_instance()
gvm.variable_changed.connect(func(name, old_val, new_val):
	print("[变化] %s: %s → %s" % [name, old_val, new_val])
)
```

### 调试方法

| 方法 | 返回 | 说明 |
|------|------|------|
| `get_debug_info()` | String | 变量总数、资源路径、每个变量的名称/类型/值 |
| `get_statistics()` | Dictionary | `total_variables`、`persistent_variables`、`resource_path` |

---

## 持久化系统

### SaveGlobalVariables（存档）

| 属性 | 类型 | 说明 |
|------|------|------|
| `save_target` | SaveTarget | `ASSISTANT_RESOURCE`（使用 Assistant 配置路径）或 `CUSTOM_PATH` |
| `custom_path` | String | 自定义路径（`save_target == CUSTOM_PATH` 时生效） |
| `save_scope` | SaveScope | `ALL`（全部）或 `PERSISTENT_ONLY`（仅持久化标记的变量） |

### LoadGlobalVariables（读档）

| 属性 | 类型 | 说明 |
|------|------|------|
| `load_source` | LoadSource | `ASSISTANT_RESOURCE` 或 `CUSTOM_PATH` |
| `custom_path` | String | 自定义路径 |

### Manager 级方法

```gdscript
var gvm = GlobalVariableManager.get_instance()

# 保存所有变量到指定路径
gvm.save_to_resource("user://save.tres")

# 从文件加载（会清空现有变量）
gvm.load_from_resource("user://save.tres")
```

---

## GlobalVariableResource

`GlobalVariableResource` 是 `.tres` 资源文件，存储变量快照。

### 属性配置

| 属性 | 类型 | 说明 |
|------|------|------|
| `variables` | Dictionary | 变量名 → 变量数据的映射 |
| `description` | String | 资源描述 |

在 Inspector 中可以直接查看和编辑持久化数据。

---

## GlobalVariableAssistant

> **⚠️ 单例模式**：`GlobalVariableAssistant` 可作为场景树中的节点放置（推荐），也可以通过 `GlobalVariableAssistant.get_instance()` 获取运行实例。**不可**使用 `new()` 和 `add_child()` 手动创建后再添加。

### 属性配置

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `current_resource` | GlobalVariableResource | null | 当前绑定的资源文件 |
| `resource_path` | String | "" | 资源文件路径 |
| `auto_save` | bool | true | 退出时自动保存 |
| `auto_load_on_ready` | bool | true | 就绪时自动加载 |
| `cleanup_on_exit` | bool | true | 退出时清理非持久化变量 |
| `auto_save_on_change` | bool | false | 变量变化时自动保存 |
| `auto_save_delay` | float | 1.0 | 自动保存延迟秒数 |

### 信号

| 信号 | 参数 | 说明 |
|------|------|------|
| `resource_changed` | old_resource, new_resource | 资源文件切换 |
| `variable_added` | name, variable_data | 变量被添加 |
| `variable_removed` | name | 变量被移除 |
| `variable_modified` | name, old_data, new_data | 变量被修改 |
| `save_completed` | success, path | 保存完成 |
| `load_completed` | success, path, resource | 加载完成 |

---

## 完整示例

### 多存档槽位

```
Trigger: SaveToSlot1 (快捷键 S)
├── SetVariable
│   variable_name: "current_save_slot"
│   value: "user://saves/slot_01.tres"
│   scope: GLOBAL
├── SaveGlobalVariables
│   save_target: CUSTOM_PATH
│   custom_path: "user://saves/slot_01.tres"
│   save_scope: PERSISTENT_ONLY
└── LogInstruction
    message: "已保存到存档槽 1"

Trigger: LoadFromSlot1 (快捷键 L)
├── LoadGlobalVariables
│   load_source: CUSTOM_PATH
│   custom_path: "user://saves/slot_01.tres"
└── LogInstruction
    message: "已从存档槽 1 加载"
```

### 自动保存（Assistant 配置）

在场景中添加 `GlobalVariableAssistant` 节点，设置：
- `resource_path` → `"user://saves/autosave.tres"`
- `auto_save` → `true`
- `auto_save_on_change` → `false`（推荐通过指令手动触发保存）
- `auto_load_on_ready` → `true`

### 跨场景共享状态

```
# 场景 A：设置玩家属性
SetVariable → scope: GLOBAL, name: "player_health", value: 100
SetVariable → scope: GLOBAL, name: "player_score", value: 0

# 切换场景后场景 B 中读取
CompareVariable → variable_name: "player_health", operator: LESS_THAN, value: 30
    └── (触发低血量警告)
```

---

## 持久化变量标记

只有标记为 `persistent = true` 的变量才会被 `PERSISTENT_ONLY` 范围保存。

```gdscript
var gvm = GlobalVariableManager.get_instance()

# 标记为持久化
var score = BaseVariable.new()
score.variable_name = "score"
score.value = 0
score.persistent = true
gvm.add_variable("score", score)

# 非持久化临时变量
var timer = BaseVariable.new()
timer.variable_name = "cooldown_timer"
timer.value = 0
timer.persistent = false
gvm.add_variable("cooldown_timer", timer)
```

---

## 调试与监控

```gdscript
var gvm = GlobalVariableManager.get_instance()

# 打印所有变量调试信息
print(gvm.get_debug_info())

# 获取统计
var stats = gvm.get_statistics()
print("总变量: %d, 持久化: %d" % [stats.total_variables, stats.persistent_variables])

# 监控所有变化
gvm.variable_changed.connect(func(name, old_val, new_val):
	push_error("[监控] %s: %s → %s" % [name, old_val, new_val])
)

# 导出状态
func export_state() -> Dictionary:
	var state = {}
	for name in gvm.get_all_variable_names():
		var v = gvm.get_variable(name)
		if v:
			state[name] = {"value": v.value, "persistent": v.persistent}
	return state
```

---

## 最佳实践

### 命名规范
- 使用 `snake_case`：`player_health`、`current_level`
- 避免特殊字符、空格、纯数字开头

### 初始化模式
```gdscript
func _ready():
	var gvm = GlobalVariableManager.get_instance()
	if not gvm.has_variable("player_health"):
		var v = BaseVariable.new()
		v.variable_name = "player_health"
		v.value = 100
		v.persistent = true
		gvm.add_variable("player_health", v)
```

### 保存策略
- 使用 `PERSISTENT_ONLY` 避免保存临时状态（冷却计时器等）
- 仅在关键节点保存（过场完成、退出前、手动存档）
- 缓存 `get_instance()` 返回值，避免频繁调用

### 性能优化
- `auto_save_on_change` 默认关闭，高频变化时性能开销大
- 合理使用持久化标记，控制存档大小

---

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 文件不存在 | 加载时存档未创建 | 先保存再加载，或检查文件是否存在 |
| 路径无效 | 自定义路径格式错误 | 使用 `user://saves/xxx.tres` 格式 |
| 权限不足 | 无法写入目录 | 确保 `user://saves/` 目录存在 |
| 变量为 null | 未初始化或已被删除 | 使用 `has_variable()` 预检 |

---

**相关文档:**
- [变量系统指南](01-variable-system-guide.md)
- [场景管理指南](17-scene-management-guide.md)
