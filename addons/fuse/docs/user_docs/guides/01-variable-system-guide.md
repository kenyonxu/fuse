# Fuse 变量使用指南

> 学会在 Fuse 可视化编程中正确使用三层变量系统

## 基础概念

Fuse 变量系统分为三个层级：LOCAL（局部）、SCOPE（作用域）、GLOBAL（全局）。大多数情况下，你只需要 LOCAL 和 GLOBAL，但 SCOPE 在特定场景下非常有用。

**快速决策树：**
- 单次指令临时数据？用 LOCAL
- 跨场景共享数据？用 GLOBAL
- 场景内节点间共享？用 SCOPE

## LOCAL 变量

LOCAL 变量存储在执行上下文中，生命周期最短但速度最快。适合指令执行的中间结果。

```gdscript
# 指令：计算两点距离
func execute(context: ExecutionContext):
    var point_a = Vector2(0, 0)
    var point_b = Vector2(100, 100)

    # 计算距离，保存到 LOCAL 变量
    var distance = point_a.distance_to(point_b)
    VariableOperations.set_variable(
        context,
        "temp_distance",
        BaseVariable.VariableScope.LOCAL,
        distance
    )
```

**何时使用 LOCAL：**
- ✅ 计算中间结果
- ✅ 单次指令临时数据
- ✅ 循环计数器
- ❌ 需要跨指令共享的数据
- ❌ 需要持久化的数据

## GLOBAL 变量

GLOBAL 变量在整个游戏运行期间保持，跨场景共享。用于游戏配置、玩家数据等全局状态。

```gdscript
# 指令：更新玩家分数
func execute(context: ExecutionContext):
    # 读取当前分数
    var current_score = VariableOperations.get_variable(
        context,
        "player_score",
        BaseVariable.VariableScope.GLOBAL,
        0
    )

    # 增加分数
    VariableOperations.set_variable(
        context,
        "player_score",
        BaseVariable.VariableScope.GLOBAL,
        current_score + 100
    )
```

**何时使用 GLOBAL：**
- ✅ 游戏配置（音量、画质）
- ✅ 玩家数据（等级、经验、背包）
- ✅ 游戏进度（当前关卡、任务状态）
- ❌ 临时数据
- ❌ 场景局部数据

## SCOPE 变量

SCOPE 变量是场景内节点间的共享数据，随节点生命周期自动清理。这是 LOCAL 和 GLOBAL 之间的折中方案。

### 基础用法（NEAREST 模式）

默认情况下，SCOPE 变量使用最近的 `ScopeVariableContainer` 节点。

```gdscript
# 指令：更新 UI 血量显示
func execute(context: ExecutionContext):
    var hp = 80

    # 保存到最近的 SCOPE 容器
    VariableOperations.set_variable(
        context,
        "current_hp",
        BaseVariable.VariableScope.SCOPE,
        hp
    )
```

**场景树示例：**
```
Main
└── GameUI (ScopeVariableContainer, scope_id: "ui")
    ├── HPBar
    └── ScoreDisplay
```

HPBar 和 ScoreDisplay 指令都可以访问同一个 SCOPE 容器中的变量。

### 指定容器（CUSTOM_ID 模式）

当你需要精确控制使用哪个容器时，使用 `save_to_scope` + `scope_source` 组合。

```gdscript
# 指令属性
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.SCOPE
var scope_source: ScopeSource = ScopeSource.CUSTOM_ID
var custom_scope_id: String = "player_stats"

# 执行逻辑
func execute(context: ExecutionContext):
    if save_to_scope == BaseVariable.VariableScope.SCOPE:
        if scope_source == ScopeSource.CUSTOM_ID:
            var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
            var scope_container = VariableScopeUtils.get_scope_container_by_source(
                context,
                utils_scope_source,
                custom_scope_id,
                target_node_path
            )

            if scope_container != null:
                scope_container.set_variable("player_hp", 100)
```

**复杂场景树示例：**
```
Main
├── PlayerStats (ScopeVariableContainer, scope_id: "player_stats")
├── EnemyStats (ScopeVariableContainer, scope_id: "enemy_stats")
└── EnemyAI
    └── Instruction (需要读取玩家血量)
```

使用 `custom_scope_id = "player_stats"` 可以精确读取 PlayerStats 容器中的数据，而不是最近的 EnemyStats。

### 作用域链继承

SCOPE 容器支持继承模式，子容器可以访问父容器的变量。

```gdscript
# 父容器：GameSettings (scope_id: "game_settings", 继承模式: READ_WRITE)
#   └── 子容器：Level1 (scope_id: "level1", 继承模式: READ_ONLY)

# Level1 中的指令可以读取 GameSettings 的变量
var difficulty = VariableOperations.get_variable(
    context,
    "difficulty",
    BaseVariable.VariableScope.SCOPE,
    "normal"
)
```

**继承模式：**
- `NONE` - 不继承父作用域
- `READ_ONLY` - 只读继承父作用域
- `READ_WRITE` - 读写继承父作用域

## 作用域选择指南

### 场景 1：单次计算

```gdscript
# 错误：不必要地使用 GLOBAL
func execute(context: ExecutionContext):
    var temp_result = calculate()
    VariableOperations.set_variable(context, "temp", BaseVariable.VariableScope.GLOBAL, temp_result)

# 正确：使用 LOCAL
func execute(context: ExecutionContext):
    var temp_result = calculate()
    VariableOperations.set_variable(context, "temp", BaseVariable.VariableScope.LOCAL, temp_result)
```

### 场景 2：UI 数据共享

```gdscript
# 错误：UI 数据使用 GLOBAL
func execute(context: ExecutionContext):
    VariableOperations.set_variable(context, "ui_hp", BaseVariable.VariableScope.GLOBAL, 100)

# 正确：UI 数据使用 SCOPE
# 在 UI 根节点添加 ScopeVariableContainer
func execute(context: ExecutionContext):
    VariableOperations.set_variable(context, "hp", BaseVariable.VariableScope.SCOPE, 100)
```

**场景树：**
```
GameUI (ScopeVariableContainer, scope_id: "ui")
├── HPBar (指令：设置 hp = 100)
├── ScoreDisplay (指令：读取 hp)
└── ManaBar (指令：读取 hp 显示血条)
```

### 场景 3：跨敌人数据共享

```gdscript
# 场景树
Main
├── EnemyManager (ScopeVariableContainer, scope_id: "enemy_manager")
│   ├── Enemy1 (指令：enemy_count++)
│   └── Enemy2 (指令：enemy_count++)
└── EnemyAI
    └── Instruction (读取 enemy_count)

# Enemy1 中的指令
func execute(context: ExecutionContext):
    var count = VariableOperations.get_variable(
        context,
        "enemy_count",
        BaseVariable.VariableScope.SCOPE,
        0
    )

    VariableOperations.set_variable(
        context,
        "enemy_count",
        BaseVariable.VariableScope.SCOPE,
        count + 1
    )
```

## 在指令中使用变量系统

### 标准模式

```gdscript
## 重构变量系统: 2026-02-09 - 使用 VariableOperations 统一变量访问

@tool
extends BaseInstruction
class_name MyInstruction

# 变量名
var variable_name: String = ""

# 变量作用域
@export var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_scope = value
		_update_resource_name()

func execute(context: ExecutionContext):
	# 读取变量
	var value = VariableOperations.get_variable(
		context,
		variable_name,
		variable_scope,
		null  # 默认值
	)

	# 检查变量是否存在
	if value == null and not VariableOperations.has_variable(
		context,
		variable_name,
		variable_scope
	):
		_log_error_localized("FUSE_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
		return

	# 处理值
	var result = _process(value)

	# 写入变量
	VariableOperations.set_variable(
		context,
		variable_name,
		variable_scope,
		result
	)

func validate() -> Array[String]:
	var errors = super.validate()

	if variable_name.is_empty():
		errors.append("变量名不能为空")

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors
```

### SCOPE 变量的高级用法

#### 使用自定义 scope_id

```gdscript
# 属性定义
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.SCOPE
var scope_source: ScopeSource = ScopeSource.CUSTOM_ID
var custom_scope_id: String = "my_custom_scope"

# 执行逻辑
func execute(context: ExecutionContext):
    match save_to_scope:
        BaseVariable.VariableScope.LOCAL:
            # LOCAL 逻辑
            pass
        BaseVariable.VariableScope.SCOPE:
            if scope_source == ScopeSource.CUSTOM_ID:
                var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
                var scope_container = VariableScopeUtils.get_scope_container_by_source(
                    context,
                    utils_scope_source,
                    custom_scope_id,
                    target_node_path
                )

                if scope_container != null:
                    scope_container.set_variable("my_var", 42)
        BaseVariable.VariableScope.GLOBAL:
            # GLOBAL 逻辑
            pass
```

#### 属性列表控制

```gdscript
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# 始终显示作用域选择
	properties.append({
		name = "save_to_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global"
	})

	# 只在选择 SCOPE 时显示 ScopeSource 选项
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node"
		})

		if scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE
			})

	return properties

func _validate_property(property: Dictionary) -> void:
	# 只在 SCOPE 作用域时验证 ScopeSource 属性
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(
			property,
			scope_source as VariableScopeUtils.ScopeSource
		)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
```

## 常见模式

### 模式 1：读写操作

```gdscript
# 读取输入变量，写入输出变量
@export var input_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
@export var output_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func execute(context: ExecutionContext):
	var input_value = VariableOperations.get_variable(
		context, "input", input_scope, 0
	)

	var result = input_value * 2

	VariableOperations.set_variable(
		context, "output", output_scope, result
	)
```

### 模式 2：默认值处理

```gdscript
# 使用默认值避免变量不存在的错误
var player_level = VariableOperations.get_variable(
    context,
    "player_level",
    BaseVariable.VariableScope.GLOBAL,
    1  # 默认值
)
```

### 模式 3：存在性检查

```gdscript
# 区分"变量不存在"和"变量值为 null"
var value = VariableOperations.get_variable(
    context,
    "my_variable",
    BaseVariable.VariableScope.GLOBAL,
    null
)

# 检查变量是否真的存在
if not VariableOperations.has_variable(
    context,
    "my_variable",
    BaseVariable.VariableScope.GLOBAL
):
	_log_error("变量 '%s' 不存在" % "my_variable")
	return

# 此时 value 为 null 是有效的（变量确实存在，但值为 null）
```

## 性能考虑

### 访问速度排序

1. **LOCAL** - 直接字典访问，最快
2. **SCOPE** - 需要查找容器节点，稍慢
3. **GLOBAL** - 需要通过管理器访问，相对较慢

### 优化建议

```gdscript
# 不推荐：在循环中重复访问 GLOBAL 变量
for i in range(100):
    var config = VariableOperations.get_variable(
        context, "config", BaseVariable.VariableScope.GLOBAL, null
    )
    # 使用 config...

# 推荐：循环外读取一次
var config = VariableOperations.get_variable(
    context, "config", BaseVariable.VariableScope.GLOBAL, null
)
for i in range(100):
    # 使用 config...
```

## 最佳实践

### 1. 优先使用 LOCAL

```gdscript
# ✅ 推荐：临时数据使用 LOCAL
var temp_distance = point_a.distance_to(point_b)
VariableOperations.set_variable(context, "temp", BaseVariable.VariableScope.LOCAL, temp_distance)

# ❌ 避免：临时数据使用 GLOBAL
VariableOperations.set_variable(context, "temp", BaseVariable.VariableScope.GLOBAL, temp_distance)
```

### 2. 变量命名规范

```gdscript
# LOCAL 变量 - 使用 temp_ 前缀
"temp_distance"
"temp_index"
"temp_result"

# SCOPE 变量 - 按功能分组
"ui_hp"
"ui_score"
"player_current_state"
"enemy_spawn_count"

# GLOBAL 变量 - 使用描述性名称
"player_level"
"game_difficulty"
"audio_master_volume"
"current_scene_name"
```

### 3. 验证前提条件

```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	if variable_name.is_empty():
		errors.append("变量名不能为空")

	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if variable_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors
```

### 4. 统一的显示格式

```gdscript
func _update_resource_name():
	var scope_str = VariableScopeUtils.enum_to_string(variable_scope).to_upper()
	resource_name = "Set %s → %s [%s]" % [target_property, variable_name, scope_str]

func get_description() -> String:
	var scope_str = VariableScopeUtils.enum_to_string(variable_scope).to_upper()
	return "设置 %s = %s [%s]" % [target_property, value, scope_str]
```

## 故障排查

### 问题：SCOPE 变量返回 null

**可能原因：**
1. 场景中没有添加 `ScopeVariableContainer` 节点
2. 没有设置 `scope_id`
3. `ScopeVariableManager` 实例不存在
4. 节点不在场景树中

**验证代码：**
```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	if value_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append("未找到 ScopeVariableManager 实例")

	return errors
```

### 问题：变量值不更新

**检查清单：**
1. 确认使用了正确的作用域
2. 确认变量名拼写正确
3. 检查是否有多个同名变量在不同作用域
4. 验证指令执行顺序是否正确

**调试方法：**
```gdscript
# 添加日志指令查看变量值
PrintVariableValue:
    variable_name: "my_var"
    variable_scope: SCOPE
```

## 参考资源

- **完整架构文档：** [变量系统设计文档](../../system_docs/architecture/variable_system_design.md)
- **示例场景：** `addons/fuse/demos/variable_system_demo.tscn`

## 快速参考

### VariableOperations 方法

```gdscript
# 获取变量
VariableOperations.get_variable(context, name, scope, default_value) -> Variant

# 设置变量
VariableOperations.set_variable(context, name, scope, value) -> bool

# 检查变量存在
VariableOperations.has_variable(context, name, scope) -> bool
```

### VariableScope 枚举

```gdscript
BaseVariable.VariableScope.LOCAL   # 局部变量
BaseVariable.VariableScope.SCOPE   # 作用域变量
BaseVariable.VariableScope.GLOBAL  # 全局变量
```

### ScopeSource 枚举（仅在 SCOPE 时使用）

```gdscript
ScopeSource.NEAREST         # 最近的容器
ScopeSource.CUSTOM_ID       # 指定 scope_id
ScopeSource.TRIGGER_SCOPE   # Trigger 节点的容器
ScopeSource.TARGET_NODE     # 目标节点的容器
```

就这样！掌握了 LOCAL、SCOPE、GLOBAL 三层变量系统，你就可以在 Fuse 可视化编程中灵活管理数据了。记住：优先 LOCAL，必要时 SCOPE，慎用 GLOBAL。
