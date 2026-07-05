# GlobalVariableManager 使用指南

## 概述

GlobalVariableManager 是一个简化但功能强大的全局变量管理系统，提供变量的存储、管理和持久化功能。系统采用单例模式，确保全局访问的一致性。

## 核心功能

### 1. 单例模式
- 全局唯一的实例访问
- 自动初始化和清理
- 线程安全的单例实现

### 2. 变量管理
- 支持 BaseVariable 类型变量
- 变量添加、获取、删除操作
- 变量值变化信号通知

### 3. 资源持久化
- 支持保存到 .tres 资源文件
- 从资源文件加载变量
- 自动版本管理

### 4. 信号系统
- `variable_added`：变量添加时发出
- `variable_removed`：变量移除时发出
- `variable_changed`：变量值变化时发出

### 5. 本地化支持
- 完整的本地化日志系统
- 自动翻译系统消息
- 支持多语言错误提示

## 快速开始

### 基本使用

```gdscript
# 获取管理器实例
var manager = GlobalVariableManager.get_instance()

# 创建全局变量
var player_health = BaseVariable.new()
player_health.variable_name = "player_health"
player_health.value = 100
player_health.scope = BaseVariable.VariableScope.GLOBAL

# 添加到管理器
manager.add_variable("player_health", player_health)

# 获取变量
var health_var = manager.get_variable("player_health")
print("玩家生命值: ", health_var.value)

# 修改变量值（会自动触发信号）
health_var.value = 80
```

### 监听变量变化

```gdscript
# 连接变量变化信号
manager.variable_changed.connect(_on_variable_changed)

func _on_variable_changed(name: String, old_value: Variant, new_value: Variant):
    print("变量 %s 从 %s 变为 %s" % [name, old_value, new_value])

# 或者连接单个变量的信号
var health_var = manager.get_variable("player_health")
health_var.value_changed.connect(_on_health_changed)

func _on_health_changed(old_value: Variant, new_value: Variant):
    print("生命值从 %d 变为 %d" % [old_value, new_value])
```

### 资源持久化

> **注意：** 推荐使用 `GlobalVariableManager.save_to_resource()` 和 `load_from_resource()` 进行持久化。
> `BaseVariable` 的 `_save_to_storage()` 方法已废弃，不建议在新项目中使用。

```gdscript
# 保存变量到资源文件
manager.save_to_resource("user://game_data.tres")

# 从资源文件加载变量
manager.load_from_resource("user://game_data.tres")

# 检查是否存在变量
if manager.has_variable("player_health"):
    print("玩家生命值变量存在")

# 获取所有变量名称
var var_names = manager.get_all_variable_names()
for name in var_names:
    print("变量: ", name)

# 获取变量数量
var count = manager.get_variable_count()
print("变量总数: ", count)
```

## API 参考

### 单例访问

#### `get_instance() -> GlobalVariableManager`
获取全局变量管理器的单例实例。

```gdscript
var manager = GlobalVariableManager.get_instance()
```

### 变量操作方法

#### `add_variable(name: String, variable: BaseVariable) -> bool`
添加变量到管理器。

**参数：**
- `name`：变量名称
- `variable`：BaseVariable 实例

**返回：** 成功返回 true，失败返回 false

**示例：**
```gdscript
var var = BaseVariable.new()
var.variable_name = "score"
var.value = 0
manager.add_variable("score", var)
```

#### `get_variable(name: String) -> BaseVariable`
获取指定名称的变量。

**参数：**
- `name`：变量名称

**返回：** BaseVariable 实例，如果不存在返回 null

#### `has_variable(name: String) -> bool`
检查变量是否存在。

**参数：**
- `name`：变量名称

**返回：** 存在返回 true，否则返回 false

#### `remove_variable(name: String) -> bool`
移除指定变量。

**参数：**
- `name`：变量名称

**返回：** 成功返回 true，失败返回 false

#### `get_all_variable_names() -> Array[String]`
获取所有变量的名称列表。

**返回：** 变量名称数组

#### `get_variable_count() -> int`
获取变量总数。

**返回：** 变量数量

#### `clear_all_variables()`
清空所有变量。

### 资源操作方法

#### `save_to_resource(path: String) -> bool`
保存所有变量到资源文件。

**参数：**
- `path`：资源文件路径（.tres 文件）

**返回：** 成功返回 true，失败返回 false

**存储内容：**
- 变量值
- 变量作用域（scope）
- 持久化标志（persistent）
- 变量描述（description）
- 版本信息
- 创建时间

#### `load_from_resource(path: String) -> bool`
从资源文件加载变量。

**参数：**
- `path`：资源文件路径

**返回：** 成功返回 true，失败返回 false

**注意：** 加载时会清空现有变量

### 信号

#### `variable_added(name: String, variable: BaseVariable)`
当变量被添加时发出。

#### `variable_removed(name: String)`
当变量被移除时发出。

#### `variable_changed(name: String, old_value: Variant, new_value: Variant)`
当变量值发生变化时发出。

### 调试方法

#### `get_debug_info() -> String`
获取详细的调试信息。

**返回：** 包含以下信息的字符串：
- 变量总数
- 资源路径
- 所有变量的详细信息（名称、类型、值）

#### `get_statistics() -> Dictionary`
获取统计信息。

**返回：** 包含以下键的字典：
- `total_variables`：变量总数
- `resource_path`：当前资源路径
- `persistent_variables`：持久化变量数量

## 最佳实践

### 1. 变量命名规范
- 使用描述性的变量名
- 采用小写字母和下划线（snake_case）
- 避免使用特殊字符和空格

```gdscript
# 好的变量名
"player_health"
"high_score"
"current_level"

# 不好的变量名
"pH"
"score1"
"temp var"
```

### 2. 初始化模式
在游戏启动时初始化全局变量：

```gdscript
# Game.gd
extends Node

func _ready():
	var manager = GlobalVariableManager.get_instance()

	# 初始化游戏变量
	_init_game_variables(manager)

	# 加载保存的数据
	if FileAccess.file_exists("user://save_data.tres"):
		manager.load_from_resource("user://save_data.tres")

func _init_game_variables(manager: GlobalVariableManager):
	# 只添加不存在的变量
	if not manager.has_variable("player_health"):
		var health = BaseVariable.new()
		health.variable_name = "player_health"
		health.value = 100
		health.persistent = true
		manager.add_variable("player_health", health)
```

### 3. 保存策略
在关键节点保存变量：

```gdscript
# 完成关卡时保存
func on_level_completed():
	var manager = GlobalVariableManager.get_instance()

	# 更新分数
	var score = manager.get_variable("score")
	score.value += level_score

	# 保存进度
	manager.save_to_resource("user://save_data.tres")
```

#### 使用 GlobalVariableAssistant 自动保存

推荐使用 `GlobalVariableAssistant` 节点来实现自动保存功能：

```gdscript
# 在场景中添加 GlobalVariableAssistant 节点
# 配置属性：
# - resource_path: "user://save_data.tres"
# - auto_save: true（退出时自动保存）
# - auto_load_on_ready: true（启动时自动加载）
# - cleanup_on_exit: true（退出时清理非持久化变量）
```

或在代码中创建：

```gdscript
func _ready():
	var assistant = GlobalVariableAssistant.new()
	assistant.resource_path = "user://save_data.tres"
	assistant.auto_save = true
	assistant.auto_load_on_ready = true
	assistant.cleanup_on_exit = true
	add_child(assistant)
```

**自动保存时机：**
- 节点退出场景树时（`tree_exiting` 信号）
- 只保存标记为 `persistent = true` 的变量

### 4. 错误处理
```gdscript
func load_game_data():
	var manager = GlobalVariableManager.get_instance()

	var result = manager.load_from_resource("user://save_data.tres")
	if not result:
		print("加载失败，使用默认值")
		# 使用默认值初始化
		init_default_variables()
```

### 5. 性能优化
- 避免频繁调用 `get_instance()`，缓存管理器引用
- 批量操作时减少信号连接
- 合理使用持久化标志

```gdscript
# 缓存管理器引用
var _global_var_manager: GlobalVariableManager

func _ready():
	_global_var_manager = GlobalVariableManager.get_instance()

# 使用缓存的引用
func update_score(points: int):
	var score = _global_var_manager.get_variable("score")
	score.value += points
```

## 实际应用示例

### 游戏状态管理

```gdscript
# GameState.gd
extends Node

var manager: GlobalVariableManager

func _ready():
	manager = GlobalVariableManager.get_instance()
	_init_game_state()

	# 连接信号监听变量变化
	manager.variable_changed.connect(_on_variable_changed)

func _init_game_state():
	# 初始化游戏状态变量
	var game_state = BaseVariable.new()
	game_state.variable_name = "game_state"
	game_state.value = "menu"  # menu, playing, paused, game_over
	manager.add_variable("game_state", game_state)

	var current_level = BaseVariable.new()
	current_level.variable_name = "current_level"
	current_level.value = 1
	manager.add_variable("current_level", current_level)

func _on_variable_changed(name: String, old_val, new_val):
	match name:
		"game_state":
			print("游戏状态: %s -> %s" % [old_val, new_val])
			handle_state_change(new_val)
		"current_level":
			print("当前关卡: %d" % new_val)
			load_level(new_val)

func get_game_state() -> String:
	var state_var = manager.get_variable("game_state")
	return state_var.value if state_var else "menu"

func set_game_state(state: String):
	var state_var = manager.get_variable("game_state")
	if state_var:
		state_var.value = state
```

### 玩家属性管理

```gdscript
# PlayerManager.gd
extends Node

var manager: GlobalVariableManager

func _ready():
	manager = GlobalVariableManager.get_instance()

func init_player_stats():
	# 生命值
	var health = BaseVariable.new()
	health.variable_name = "player_health"
	health.value = 100
	health.persistent = true
	manager.add_variable("player_health", health)

	# 最大生命值
	var max_health = BaseVariable.new()
	max_health.variable_name = "player_max_health"
	max_health.value = 100
	manager.add_variable("player_max_health", max_health)

	# 得分
	var score = BaseVariable.new()
	score.variable_name = "score"
	score.value = 0
	score.persistent = true
	manager.add_variable("score", score)

func take_damage(damage: int):
	var health = manager.get_variable("player_health")
	if health:
		health.value = max(0, health.value - damage)

func heal(amount: int):
	var health = manager.get_variable("player_health")
	var max_health = manager.get_variable("player_max_health")
	if health and max_health:
		health.value = min(max_health.value, health.value + amount)

func add_score(points: int):
	var score = manager.get_variable("score")
	if score:
		score.value += points
```

## 调试技巧

### 1. 使用调试信息

```gdscript
func debug_print_all_variables():
	var manager = GlobalVariableManager.get_instance()
	print(manager.get_debug_info())
```

### 2. 监控变量变化

```gdscript
func setup_variable_monitoring():
	var manager = GlobalVariableManager.get_instance()
	manager.variable_changed.connect(func(name, old_val, new_val):
		print("[变量变化] %s: %s -> %s" % [name, old_val, new_val])
	)
```

### 3. 导出变量状态

```gdscript
func export_variable_state() -> Dictionary:
	var manager = GlobalVariableManager.get_instance()
	var state = {}

	for var_name in manager.get_all_variable_names():
		var variable = manager.get_variable(var_name)
		if variable:
			state[var_name] = {
				"value": variable.value,
				"type": variable.get_type_name(),
				"scope": variable.scope
			}

	return state
```

## 常见问题

### Q: 如何处理变量不存在的情况？

```gdscript
# 安全获取变量
func get_variable_safely(name: String) -> Variant:
	var manager = GlobalVariableManager.get_instance()
	var variable = manager.get_variable(name)

	if not variable:
		push_warning("变量 '%s' 不存在" % name)
		return null

	return variable.value
```

### Q: 如何重置所有变量？

```gdscript
func reset_all_variables():
	var manager = GlobalVariableManager.get_instance()
	manager.clear_all_variables()
	# 重新初始化默认变量
	init_default_variables()
```

### Q: 如何验证资源文件是否有效？

```gdscript
func validate_save_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var manager = GlobalVariableManager.get_instance()
	var result = manager.load_from_resource(path)

	return result and manager.get_variable_count() > 0
```

## 总结

GlobalVariableManager 提供了一个简单而强大的全局变量管理解决方案：

1. **单例模式**：全局统一访问
2. **持久化支持**：轻松保存和加载游戏数据
3. **信号系统**：实时监听变量变化
4. **类型安全**：使用 BaseVariable 确保类型一致性
5. **本地化支持**：完整的本地化日志系统
6. **调试友好**：丰富的调试信息和统计功能

通过合理使用 GlobalVariableManager，可以有效地管理游戏中的全局状态，简化代码逻辑，提高开发效率。