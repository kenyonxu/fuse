# ScopeSource 架构修复实现计划

**创建日期:** 2026-02-10
**状态:** 待执行
**预估总时间:** 4-5 小时（按优先级分批执行）

---

## 目标（Goal）

为 Bricks 可视化编程系统的 23 个组件添加完整的三层变量系统支持（LOCAL/SCOPE/GLOBAL），修复之前错误使用 ScopeSource 作为唯一作用域选择方式的架构问题。

### 核心架构原则

1. **第一层：VariableScope 枚举** - LOCAL/SCOPE/GLOBAL 三选一
2. **第二层：ScopeSource 枚举** - 仅当选择 SCOPE 时才显示（NEAREST/CUSTOM_ID/TRIGGER_SCOPE/TARGET_NODE）
3. **统一执行逻辑** - 使用 VariableOperations 和 VariableScopeUtils

---

## 架构参考（Architecture）

### 正确实现示例

**参考文件:** `addons/bricks/instructions/variables/create_variable.gd`

```gdscript
# 第一层：变量作用域枚举（始终显示）
@export var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(value):
        variable_scope = value
        _update_resource_name()
        notify_property_list_changed()

# 第二层：作用域来源（仅当 variable_scope == SCOPE 时显示）
enum ScopeSource {
    NEAREST,        # 最近的作用域容器（默认）
    CUSTOM_ID,      # 指定 scope_id
    TRIGGER_SCOPE,  # Trigger 节点上的作用域
    TARGET_NODE     # Target 节点上的作用域
}

var scope_source: ScopeSource = ScopeSource.NEAREST:
    set(value):
        scope_source = value
        _update_resource_name()
        notify_property_list_changed()

var custom_scope_id: String = ""
var target_node_path: NodePath = NodePath("")

# 属性列表控制
func _get_property_list() -> Array[Dictionary]:
    var properties := []

    # 始终显示 variable_scope
    properties.append({
        name = "variable_scope",
        type = TYPE_INT,
        hint = PROPERTY_HINT_ENUM,
        hint_string = "Local,Scope,Global"
    })

    # 只在 SCOPE 时显示 ScopeSource
    if variable_scope == BaseVariable.VariableScope.SCOPE:
        properties.append({
            name = "scope_source",
            type = TYPE_INT,
            hint = PROPERTY_HINT_ENUM,
            hint_string = "Nearest,Custom ID,Trigger Scope,Target Node"
        })

        if scope_source == ScopeSource.CUSTOM_ID:
            properties.append({ name = "custom_scope_id", ... })
        elif scope_source == ScopeSource.TARGET_NODE:
            properties.append({ name = "target_node_path", ... })

    return properties
```

### 工具类参考

**文件:** `addons/bricks/core/utils/variable_scope_utils.gd`

```gdscript
# 类型转换
var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource

# 获取作用域容器
var scope_container = VariableScopeUtils.get_scope_container_by_source(
    context, utils_scope_source, custom_scope_id, target_node_path
)

# 获取作用域字符串
var scope_str = VariableScopeUtils.get_scope_source_string(
    utils_scope_source, custom_scope_id, target_node_path
)

# 验证属性可见性
VariableScopeUtils.validate_scope_source_property(property, utils_scope_source)

# 验证参数
errors.append_array(VariableScopeUtils.validate_scope_source_params(
    utils_scope_source, custom_scope_id, target_node_path
))
```

---

## 技术栈（Tech Stack）

- **Godot 版本:** 4.6-stable
- **GDScript 版本:** 2.0
- **核心类:** BaseVariable, VariableOperations, VariableScopeUtils
- **测试工具:** Godot headless 模式语法检查

---

## 阶段一：高优先级组件（4个，~90分钟）

### 1.1 set_int_variable.gd - 双作用域系统（~25分钟）

**文件路径:** `addons/bricks/instructions/variables/set_int_variable.gd`
**修改类型:** 双作用域（写入目标 + 读取源，条件化）
**参考:** `set_variable.gd` (已完成)

---

#### Task 1.1.1: 添加目标作用域枚举（3分钟）

**操作:** 在现有 `scope` 属性后添加新的 `target_variable_scope` 枚举属性

**插入位置:** 在第 50 行左右（现有 `scope` 属性声明之后）

```gdscript
## 目标变量作用域（写入）
@export var target_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		target_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()
```

**验证:** 确认变量名与现有 `scope` 不冲突

---

#### Task 1.1.2: 添加目标作用域的 ScopeSource（4分钟）

**操作:** 添加目标作用域的 ScopeSource 相关属性

**插入位置:** 在 `target_variable_scope` 之后

```gdscript
## 目标作用域来源（仅当 target_variable_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

var target_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		target_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 自定义目标作用域 ID（CUSTOM_ID 模式使用）
var target_custom_scope_id: String = "":
	set(value):
		target_custom_scope_id = value
		_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var target_target_node_path: NodePath = NodePath(""):
	set(value):
		target_target_node_path = value
		_update_resource_name()
```

**验证:** 检查 enum 定义不与其他命名冲突

---

#### Task 1.1.3: 添加源作用域枚举（3分钟）

**操作:** 添加源变量作用域枚举（用于 `set_with_another_variable = true` 时）

**插入位置:** 在 `target_target_node_path` 之后

```gdscript
## 源变量作用域（读取，仅当 set_with_another_variable = true 时使用）
@export var from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		from_variable_scope = value
		_update_resource_name()
		notify_property_list_changed()
```

**验证:** 确认条件化使用场景

---

#### Task 1.1.4: 添加源作用域的 ScopeSource（4分钟）

**操作:** 添加源作用域的 ScopeSource 相关属性

**插入位置:** 在 `from_variable_scope` 之后

```gdscript
## 源作用域来源（仅当 from_variable_scope == SCOPE 时使用）
var from_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		from_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 自定义源作用域 ID
var from_custom_scope_id: String = "":
	set(value):
		from_custom_scope_id = value
		_update_resource_name()

## 源节点路径
var from_target_node_path: NodePath = NodePath(""):
	set(value):
		from_target_node_path = value
		_update_resource_name()
```

**验证:** 确认属性命名一致性

---

#### Task 1.1.5: 修改 _get_property_list() - 添加目标作用域（5分钟）

**操作:** 在现有属性列表中添加目标作用域配置

**插入位置:** 在 `variable_name` 属性之后

```gdscript
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# ... 现有代码 ...

	# 目标作用域配置
	properties.append({
		name = "Target Scope",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_variable_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在选择 SCOPE 时显示 ScopeSource
	if target_variable_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "target_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if target_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "target_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif target_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "target_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# ... 继续源作用域配置 ...

	return properties
```

**验证:** 运行 Godot 编辑器，检查 Inspector 显示

---

#### Task 1.1.6: 修改 _get_property_list() - 添加源作用域（3分钟）

**操作:** 添加源作用域配置（条件化显示）

**插入位置:** 在目标作用域配置之后，包装在 `if set_with_another_variable:` 条件中

```gdscript
	# 源作用域配置（仅在使用另一个变量时显示）
	if set_with_another_variable:
		properties.append({
			name = "Source Scope",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_CATEGORY
		})

		properties.append({
			name = "from_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if from_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "from_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if from_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "from_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif from_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "from_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
```

**验证:** 切换 `set_with_another_variable` 检查 UI 变化

---

#### Task 1.1.7: 修改 execute() - 目标作用域写入逻辑（3分钟）

**操作:** 替换现有的写入逻辑为三层作用域分支

**查找位置:** 搜索 `# 保存到变量` 或 `VariableOperations.set_variable`

**替换代码:**

```gdscript
	# 根据目标作用域类型保存变量
	match target_variable_scope:
		BaseVariable.VariableScope.LOCAL:
			# 保存到 LOCAL 变量
			var success = VariableOperations.set_variable(context, variable_name, BaseVariable.VariableScope.LOCAL, value)
			if not success:
				_log_error_localized("BRICKS_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": variable_name})
				set_error_localized("BRICKS_ERROR_SET_LOCAL_VARIABLE_FAILED", BricksError.ErrorType.RUNTIME_ERROR, {"name": variable_name})
				finished.emit()
				return

		BaseVariable.VariableScope.SCOPE:
			# 保存到 SCOPE 变量
			if target_scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, variable_name, BaseVariable.VariableScope.SCOPE, value)
			else:
				var utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					target_custom_scope_id,
					target_target_node_path
				)

				if scope_container == null:
					_log_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					set_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {})
					finished.emit()
					return

				var success = scope_container.set_variable(variable_name, value)
				if not success:
					_log_error_localized("BRICKS_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": variable_name})
					set_error_localized("BRICKS_ERROR_SET_SCOPE_VARIABLE_FAILED", BricksError.ErrorType.RUNTIME_ERROR, {"name": variable_name})
					finished.emit()
					return

		BaseVariable.VariableScope.GLOBAL:
			# 保存到 GLOBAL 变量
			var success = VariableOperations.set_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL, value)
			if not success:
				_log_error_localized("BRICKS_ERROR_SET_GLOBAL_VARIABLE_FAILED", {"name": variable_name})
				set_error_localized("BRICKS_ERROR_SET_GLOBAL_VARIABLE_FAILED", BricksError.ErrorType.RUNTIME_ERROR, {"name": variable_name})
				finished.emit()
				return
```

**验证:** 确认所有错误路径都有 emit finished

---

#### Task 1.1.8: 修改 execute() - 源作用域读取逻辑（3分钟）

**操作:** 替换现有的源变量读取逻辑

**查找位置:** 搜索 `VariableOperations.get_variable(context, from_variable, ...)`

**替换代码:**

```gdscript
# 根据源作用域类型读取变量
var from_value := 0
match from_variable_scope:
	BaseVariable.VariableScope.LOCAL:
		from_value = int(VariableOperations.get_variable(context, from_variable, BaseVariable.VariableScope.LOCAL, 0))

	BaseVariable.VariableScope.SCOPE:
		if from_scope_source == ScopeSource.NEAREST:
			from_value = int(VariableOperations.get_variable(context, from_variable, BaseVariable.VariableScope.SCOPE, 0))
		else:
			var utils_scope_source = from_scope_source as VariableScopeUtils.ScopeSource
			var scope_container = VariableScopeUtils.get_scope_container_by_source(
				context,
				utils_scope_source,
				from_custom_scope_id,
				from_target_node_path
			)

			if scope_container == null:
				_log_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
				set_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {})
				finished.emit()
				return

			from_value = int(scope_container.get_variable(from_variable, 0))

	BaseVariable.VariableScope.GLOBAL:
		from_value = int(VariableOperations.get_variable(context, from_variable, BaseVariable.VariableScope.GLOBAL, 0))
```

**验证:** 确认默认值 0 适用于所有分支

---

#### Task 1.1.9: 添加 _validate_property()（3分钟）

**操作:** 添加属性可见性验证方法

**插入位置:** 在文件末尾，`get_description()` 方法之前

```gdscript
## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 目标作用域相关属性
	if target_variable_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, target_scope_source as VariableScopeUtils.ScopeSource)
	else:
		if property.name in ["target_scope_source", "target_custom_scope_id", "target_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 源作用域相关属性（仅在使用另一个变量时）
	if set_with_another_variable:
		if from_variable_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, from_scope_source as VariableScopeUtils.ScopeSource)
		else:
			if property.name in ["from_scope_source", "from_custom_scope_id", "from_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 隐藏所有源作用域相关属性
		if property.name in ["from_variable_scope", "from_scope_source", "from_custom_scope_id", "from_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
```

**验证:** 在编辑器中切换 `target_variable_scope` 和 `from_variable_scope`，检查属性显示/隐藏

---

#### Task 1.1.10: 修改 validate() - 添加作用域验证（3分钟）

**操作:** 在现有验证逻辑中添加作用域相关验证

**插入位置:** 在 `return errors` 之前

```gdscript
	# 验证目标 SCOPE 作用域需要 ScopeVariableManager
	if target_variable_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(BricksLocalization.translate("BRICKS_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var target_utils_scope_source = target_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			target_utils_scope_source,
			target_custom_scope_id,
			target_target_node_path
		))

	# 验证源 SCOPE 作用域（仅在使用另一个变量时）
	if set_with_another_variable and from_variable_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(BricksLocalization.translate("BRICKS_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var from_utils_scope_source = from_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			from_utils_scope_source,
			from_custom_scope_id,
			from_target_node_path
		))
```

**验证:** 在编辑器中创建指令，检查验证消息

---

#### Task 1.1.11: 测试与语法检查（3分钟）

**操作:** 运行 Godot headless 模式检查语法

**命令:**
```bash
"E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit
```

**验证:** 确认无语法错误，提交代码

---

### 1.2 instantiate_scene.gd - 单作用域写入（~20分钟）

**文件路径:** `addons/bricks/instructions/node_operations/instantiate_scene.gd`
**修改类型:** 单作用域写入（保存实例ID）
**参考:** `random_number.gd` (已完成)

---

#### Task 1.2.1: 添加 save_to_scope 属性（3分钟）

**操作:** 在 `target_variable` 属性后添加作用域枚举

**插入位置:** 第 45 行左右

```gdscript
## 保存到作用域
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		save_to_scope = value
		_update_resource_name()
		notify_property_list_changed()
```

**验证:** 确认 setter 调用必要方法

---

#### Task 1.2.2: 添加 ScopeSource 枚举（4分钟）

**操作:** 添加 ScopeSource 相关属性

**插入位置:** 在 `save_to_scope` 之后

```gdscript
## 作用域来源（仅当 save_to_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 自定义作用域 ID（CUSTOM_ID 模式使用）
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 目标节点路径（TARGET_NODE 模式使用）
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()
```

**验证:** 确认 enum 定义正确

---

#### Task 1.2.3: 修改 _get_property_list()（5分钟）

**操作:** 在输出属性部分添加作用域配置

**插入位置:** 在 `target_variable` 属性之后

```gdscript
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# ... 现有代码 ...

	properties.append({
		name = "Output",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "target_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "save_to_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 只在 save_to_scope == SCOPE 时显示 ScopeSource 配置
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties
```

**验证:** 运行编辑器检查 Inspector

---

#### Task 1.2.4: 添加 _get_scope_source_string()（2分钟）

**操作:** 添加作用域字符串获取方法

**插入位置:** 在 `_update_resource_name()` 方法之后

```gdscript
## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	# 根据 save_to_scope 返回不同的作用域字符串
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			return BricksLocalization.translate("BRICKS_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return BricksLocalization.translate("BRICKS_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域时，使用 ScopeSource 获取具体域信息
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				target_node_path
			)
		_:
			return BricksLocalization.translate("BRICKS_VARIABLE_SCOPE_UNKNOWN")
```

**验证:** 在 `_update_resource_name()` 中调用此方法

---

#### Task 1.2.5: 修改 execute() - 保存实例ID（4分钟）

**操作:** 替换现有的保存实例ID逻辑

**查找位置:** 搜索 `# 保存实例ID` 或类似注释

**替换代码:**

```gdscript
	# 根据作用域类型保存实例ID
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			var success = VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.LOCAL, instance_id)
			if not success:
				_log_error_localized("BRICKS_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": target_variable})
				set_error_localized("BRICKS_ERROR_SET_LOCAL_VARIABLE_FAILED", BricksError.ErrorType.RUNTIME_ERROR, {"name": target_variable})
				finished.emit()
				return

		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.SCOPE, instance_id)
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					custom_scope_id,
					target_node_path
				)

				if scope_container == null:
					_log_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					set_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {})
					finished.emit()
					return

				var success = scope_container.set_variable(target_variable, instance_id)
				if not success:
					_log_error_localized("BRICKS_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": target_variable})
					set_error_localized("BRICKS_ERROR_SET_SCOPE_VARIABLE_FAILED", BricksError.ErrorType.RUNTIME_ERROR, {"name": target_variable})
					finished.emit()
					return

		BaseVariable.VariableScope.GLOBAL:
			var success = VariableOperations.set_variable(context, target_variable, BaseVariable.VariableScope.GLOBAL, instance_id)
			if not success:
				_log_error_localized("BRICKS_ERROR_SET_GLOBAL_VARIABLE_FAILED", {"name": target_variable})
				set_error_localized("BRICKS_ERROR_SET_GLOBAL_VARIABLE_FAILED", BricksError.ErrorType.RUNTIME_ERROR, {"name": target_variable})
				finished.emit()
				return
```

**验证:** 确认所有错误分支都调用 finished.emit()

---

#### Task 1.2.6: 添加 _validate_property()（2分钟）

**操作:** 添加属性可见性验证

**插入位置:** 在 `get_description()` 方法之前

```gdscript
## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
```

**验证:** 在编辑器中切换 save_to_scope，检查属性显示

---

#### Task 1.2.7: 修改 validate()（2分钟）

**操作:** 添加作用域验证

**插入位置:** 在 `return errors` 之前

```gdscript
	# 验证 SCOPE 作用域需要 ScopeVariableManager
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(BricksLocalization.translate("BRICKS_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		# 验证 ScopeSource 参数
		var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			custom_scope_id,
			target_node_path
		))
```

**验证:** 在编辑器中测试验证逻辑

---

#### Task 1.2.8: 测试与语法检查（3分钟）

**操作:** 运行语法检查

**命令:**
```bash
"E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit
```

**验证:** 确认无语法错误，提交代码

---

### 1.3 raycast.gd - 单作用域写入（~20分钟）

**文件路径:** `addons/bricks/instructions/physics/raycast.gd`
**修改类型:** 单作用域写入（保存射线检测结果）
**参考:** `instantiate_scene.gd` (同上)

---

**修改步骤:** 同 1.2（instantiate_scene.gd），替换以下内容：
- `target_variable` → `result_variable`（第 60 行左右）
- `instance_id` → `result`（执行逻辑中的结果变量）
- 其他步骤完全相同

**Task 1.3.1-1.3.8:** 参考 Task 1.2.1-1.2.8，替换变量名即可

**注意:** raycast 的结果是 Dictionary 类型，包含 `{ "collider": Node, "position": Vector3, "normal": Vector3 }`

---

### 1.4 set_property_value.gd - 单作用域读取（~25分钟）

**文件路径:** `addons/bricks/instructions/node_operations/set_property_value.gd`
**修改类型:** 单作用域读取（从变量读取属性值）
**参考:** `clamp_value.gd` (已完成)

---

#### Task 1.4.1: 添加 value_scope 属性（3分钟）

**操作:** 在现有 `use_variable` 和 `variable_name` 之间添加作用域枚举

**插入位置:** 第 75 行左右

```gdscript
## 变量作用域
@export var value_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		value_scope = value
		_update_resource_name()
		notify_property_list_changed()
```

**验证:** 确认插入位置正确

---

#### Task 1.4.2: 添加 ScopeSource 枚举（4分钟）

**操作:** 添加 ScopeSource 相关属性

**插入位置:** 在 `value_scope` 之后

```gdscript
## 作用域来源（仅当 value_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()

## 自定义作用域 ID
var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

## 目标节点路径
var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()
```

**验证:** 确认属性定义完整

---

#### Task 1.4.3: 修改 _get_property_list()（6分钟）

**操作:** 在变量值部分添加作用域配置

**插入位置:** 在 `use_variable == true` 分支中，`variable_name` 属性之后

```gdscript
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# ... 现有代码 ...

	# Value 来源
	properties.append({
		name = "Value",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_variable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if use_variable:
		properties.append({
			name = "variable_name",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "value_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		# 只在 value_scope == SCOPE 时显示 ScopeSource 配置
		if value_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
	else:
		properties.append({
			name = "value",
			type = TYPE_NIL,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties
```

**验证:** 运行编辑器，切换 `use_variable` 和 `value_scope` 检查 UI

---

#### Task 1.4.4: 添加 _get_scope_source_string()（2分钟）

**操作:** 添加作用域字符串获取方法

**插入位置:** 在 `_update_resource_name()` 之后

```gdscript
## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	# 根据 value_scope 返回不同的作用域字符串
	match value_scope:
		BaseVariable.VariableScope.LOCAL:
			return BricksLocalization.translate("BRICKS_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return BricksLocalization.translate("BRICKS_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域时，使用 ScopeSource 获取具体域信息
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				target_node_path
			)
		_:
			return BricksLocalization.translate("BRICKS_VARIABLE_SCOPE_UNKNOWN")
```

**验证:** 在资源名称中使用此方法

---

#### Task 1.4.5: 修改 execute() - 读取变量值（5分钟）

**操作:** 替换现有的变量读取逻辑

**查找位置:** 搜索 `use_variable and not variable_name.is_empty()` 分支

**替换代码:**

```gdscript
			# 从变量读取值
			var var_value = null
			match value_scope:
				BaseVariable.VariableScope.LOCAL:
					var_value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.LOCAL, null)

				BaseVariable.VariableScope.SCOPE:
					if scope_source == ScopeSource.NEAREST:
						var_value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.SCOPE, null)
					else:
						var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
						var scope_container = VariableScopeUtils.get_scope_container_by_source(
							context,
							utils_scope_source,
							custom_scope_id,
							target_node_path
						)

						if scope_container == null:
							_log_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
							set_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {})
							finished.emit()
							return

						var_value = scope_container.get_variable(variable_name, null)

				BaseVariable.VariableScope.GLOBAL:
					var_value = VariableOperations.get_variable(context, variable_name, BaseVariable.VariableScope.GLOBAL, null)

			# 检查变量是否存在
			if var_value == null and not VariableOperations.has_variable(context, variable_name, value_scope):
				_log_error_localized("BRICKS_ERROR_VAR_NOT_FOUND", {"variable": variable_name})
				set_error_localized("BRICKS_ERROR_VAR_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"variable": variable_name})
				finished.emit()
				return

			value = var_value
```

**验证:** 确认所有作用域分支都有错误处理

---

#### Task 1.4.6: 添加 _validate_property()（2分钟）

**操作:** 添加属性可见性验证

**插入位置:** 在 `get_description()` 之前

```gdscript
## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 只在使用变量且 SCOPE 作用域时验证 ScopeSource 相关属性
	if use_variable:
		if value_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
		else:
			# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
			if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		# 不使用变量时，隐藏所有作用域相关属性
		if property.name in ["value_scope", "scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
```

**验证:** 在编辑器中切换 `use_variable` 和 `value_scope`

---

#### Task 1.4.7: 修改 validate()（3分钟）

**操作:** 添加作用域验证

**插入位置:** 在现有变量验证逻辑中

```gdscript
	# 验证变量作用域
	if use_variable:
		if variable_name.is_empty():
			errors.append(BricksLocalization.translate("BRICKS_ERROR_VAR_NAME_EMPTY"))

		# 验证 SCOPE 作用域需要 ScopeVariableManager
		if value_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(BricksLocalization.translate("BRICKS_ERROR_SCOPE_MANAGER_NOT_FOUND"))

			# 验证 ScopeSource 参数
			var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source,
				custom_scope_id,
				target_node_path
			))
```

**验证:** 在编辑器中测试验证

---

#### Task 1.4.8: 测试与语法检查（3分钟）

**操作:** 运行语法检查

**命令:**
```bash
"E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit
```

**验证:** 确认无语法错误，提交代码

---

## 阶段一总结（Checkpoint 1）

**完成组件:** 4个（高优先级）
**预估时间:** ~90分钟
**验证方式:** Godot headless 语法检查 + 编辑器 Inspector 测试

**提交建议:**
```
feat: 添加高优先级组件的 ScopeSource 支持

- set_int_variable.gd: 双作用域系统（目标+源）
- instantiate_scene.gd: 单作用域写入（实例ID）
- raycast.gd: 单作用域写入（射线结果）
- set_property_value.gd: 单作用域读取（属性值）

参考：random_number.gd, set_variable.gd, clamp_value.gd
```

---

## 阶段二：中优先级组件 - Conditions（3个，~45分钟）

### 2.1 check_countdown_finished.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/conditions/time/check_countdown_finished.gd`
**修改类型:** 单作用域读取（读取开始时间变量）
**参考:** `check_variable.gd` (已完成)

---

#### Task 2.1.1: 添加 variable_scope 属性（3分钟）

**操作:** 在 `start_time_variable` 属性后添加作用域枚举

**插入位置:** 第 35 行左右

```gdscript
## 变量作用域
@export var variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_scope = value
		_update_resource_name()
```

**验证:** 确认属性名不冲突

---

#### Task 2.1.2: 添加 ScopeSource 枚举（3分钟）

**操作:** 添加 ScopeSource 相关属性

**插入位置:** 在 `variable_scope` 之后

```gdscript
## 作用域来源（仅当 variable_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST, CUSTOM_ID, TRIGGER_SCOPE, TARGET_NODE
}

var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()

var custom_scope_id: String = "":
	set(value):
		custom_scope_id = value
		_update_resource_name()

var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()
```

**验证:** 确认 setter 调用 `_update_resource_name()`

---

#### Task 2.1.3: 修改 _get_property_list()（4分钟）

**操作:** 添加作用域配置到属性列表

```gdscript
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# ... 现有代码 ...

	properties.append({
		name = "start_time_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "variable_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if variable_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties
```

**验证:** 运行编辑器检查 UI

---

#### Task 2.1.4: 修改 execute() - 读取开始时间（5分钟）

**操作:** 替换变量读取逻辑

```gdscript
func execute(context: ExecutionContext) -> bool:
	_start_execution(context)

	# 读取开始时间
	var start_time = 0
	match variable_scope:
		BaseVariable.VariableScope.LOCAL:
			start_time = int(VariableOperations.get_variable(context, start_time_variable, BaseVariable.VariableScope.LOCAL, 0))

		BaseVariable.VariableScope.SCOPE:
			if scope_source == ScopeSource.NEAREST:
				start_time = int(VariableOperations.get_variable(context, start_time_variable, BaseVariable.VariableScope.SCOPE, 0))
			else:
				var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context, utils_scope_source, custom_scope_id, target_node_path
				)
				if scope_container == null:
					_log_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					set_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {})
					_on_execution_completed()
					return false
				start_time = int(scope_container.get_variable(start_time_variable, 0))

		BaseVariable.VariableScope.GLOBAL:
			start_time = int(VariableOperations.get_variable(context, start_time_variable, BaseVariable.VariableScope.GLOBAL, 0))

	# 检查倒计时是否完成
	var current_time = Time.get_ticks_msec()
	var elapsed = (current_time - start_time) / 1000.0
	var is_finished = elapsed >= countdown_duration

	# ... 继续现有逻辑 ...

	return is_finished
```

**验证:** 确认返回值类型为 bool

---

#### Task 2.1.5: 测试与语法检查（3分钟）

**操作:** 运行语法检查并验证

**命令:**
```bash
"E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit
```

**验证:** 确认无错误，提交代码

---

### 2.2 check_health_value.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/conditions/variable/check_health_value.gd`
**修改类型:** 单作用域读取（读取生命值变量）
**参考:** Task 2.1（完全相同的模式）

---

**Task 2.2.1-2.2.5:** 参考 Task 2.1.1-2.1.5，替换以下内容：
- `start_time_variable` → `health_variable`（变量名）
- `start_time` → `health_value`（结果变量名）
- `check_countdown_finished.gd` → `check_health_value.gd`（文件名）

---

### 2.3 compare_health_threshold.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/conditions/variable/compare_health_threshold.gd`
**修改类型:** 单作用域读取（读取生命值变量）
**参考:** Task 2.1（完全相同的模式）

---

**Task 2.3.1-2.3.5:** 参考 Task 2.1.1-2.1.5，替换以下内容：
- `start_time_variable` → `health_variable`（变量名）
- `start_time` → `health_value`（结果变量名）
- `check_countdown_finished.gd` → `compare_health_threshold.gd`（文件名）

---

## 阶段二总结（Checkpoint 2）

**完成组件:** 3个（中优先级 - Conditions）
**预估时间:** ~45分钟

**提交建议:**
```
feat: 添加 Conditions 的 ScopeSource 支持

- check_countdown_finished.gd: 单作用域读取（开始时间）
- check_health_value.gd: 单作用域读取（生命值）
- compare_health_threshold.gd: 单作用域读取（生命值）

参考：check_variable.gd
```

---

## 阶段三：中优先级组件 - Flow Control（3个，~70分钟）

### 3.1 while_loop.gd - 单作用域读取（~20分钟）

**文件路径:** `addons/bricks/instructions/flow_control/while_loop.gd`
**修改类型:** 单作用域读取（读取条件变量）
**参考:** `check_countdown_finished.gd` (同上)

---

**Task 3.1.1-3.1.5:** 参考 Task 2.1.1-2.1.5，替换以下内容：
- `start_time_variable` → `condition_variable`（变量名）
- `start_time` → `condition_value`（结果变量名）
- `check_countdown_finished.gd` → `while_loop.gd`（文件名）

**注意:** while_loop 是循环指令，需要在每次迭代时重新读取条件变量

---

### 3.2 for_each.gd - 双作用域（一读一写）（~30分钟）

**文件路径:** `addons/bricks/instructions/flow_control/for_each.gd`
**修改类型:** 双作用域（读取数组 + 写入当前元素）
**参考:** 需要组合读写两种模式

---

#### Task 3.2.1: 添加 array_scope 属性（3分钟）

**操作:** 添加数组变量作用域枚举

**插入位置:** 第 45 行左右（`array_variable` 之后）

```gdscript
## 数组变量作用域
@export var array_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		array_scope = value
		_update_resource_name()
		notify_property_list_changed()
```

---

#### Task 3.2.2: 添加数组 ScopeSource（3分钟）

**操作:** 添加数组作用域的 ScopeSource

```gdscript
## 数组作用域来源（仅当 array_scope == SCOPE 时使用）
enum ScopeSource {
	NEAREST, CUSTOM_ID, TRIGGER_SCOPE, TARGET_NODE
}

var array_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		array_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

var array_custom_scope_id: String = ""
var array_target_node_path: NodePath = NodePath("")
```

---

#### Task 3.2.3: 添加 item_scope 属性（3分钟）

**操作:** 添加当前元素作用域枚举

```gdscript
## 当前元素作用域
@export var item_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		item_scope = value
		_update_resource_name()
		notify_property_list_changed()
```

---

#### Task 3.2.4: 添加 item ScopeSource（3分钟）

**操作:** 添加元素作用域的 ScopeSource

```gdscript
## 元素作用域来源（仅当 item_scope == SCOPE 时使用）
var item_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		item_scope_source = value
		_update_resource_name()
		notify_property_list_changed()

var item_custom_scope_id: String = ""
var item_target_node_path: NodePath = NodePath("")
```

---

#### Task 3.2.5: 修改 _get_property_list()（8分钟）

**操作:** 添加双作用域配置

```gdscript
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# ... 现有代码 ...

	# 数组配置
	properties.append({
		name = "Array",
		type = TYPE_NIL,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "array_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "array_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if array_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "array_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if array_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "array_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif array_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "array_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# 当前元素配置
	properties.append({
		name = "Item",
		type = TYPE_NIL,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "item_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "item_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if item_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "item_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if item_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "item_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif item_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "item_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	return properties
```

**验证:** 运行编辑器检查 UI

---

#### Task 3.2.6: 修改 execute() - 读取数组（5分钟）

**操作:** 替换数组读取逻辑

```gdscript
func execute(context: ExecutionContext):
	_start_execution(context)

	# 读取数组
	var array = null
	match array_scope:
		BaseVariable.VariableScope.LOCAL:
			array = VariableOperations.get_variable(context, array_variable, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.SCOPE:
			if array_scope_source == ScopeSource.NEAREST:
				array = VariableOperations.get_variable(context, array_variable, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = array_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context, utils_scope_source, array_custom_scope_id, array_target_node_path
				)
				if scope_container == null:
					_log_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
					set_error_localized("BRICKS_ERROR_SCOPE_CONTAINER_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {})
					finished.emit()
					return
				array = scope_container.get_variable(array_variable, null)

		BaseVariable.VariableScope.GLOBAL:
			array = VariableOperations.get_variable(context, array_variable, BaseVariable.VariableScope.GLOBAL, null)

	# 验证数组
	if array == null:
		_log_error_localized("BRICKS_ERROR_VAR_NOT_FOUND", {"variable": array_variable})
		set_error_localized("BRICKS_ERROR_VAR_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"variable": array_variable})
		finished.emit()
		return

	if not array is Array:
		_log_error_localized("BRICKS_ERROR_NOT_ARRAY", {"variable": array_variable})
		set_error_localized("BRICKS_ERROR_NOT_ARRAY", BricksError.ErrorType.RUNTIME_ERROR, {"variable": array_variable})
		finished.emit()
		return

	# 遍历数组
	for item in array:
		# 保存当前元素
		match item_scope:
			BaseVariable.VariableScope.LOCAL:
				VariableOperations.set_variable(context, item_variable, BaseVariable.VariableScope.LOCAL, item)

			BaseVariable.VariableScope.SCOPE:
				if item_scope_source == ScopeSource.NEAREST:
					VariableOperations.set_variable(context, item_variable, BaseVariable.VariableScope.SCOPE, item)
				else:
					var utils_scope_source = item_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context, utils_scope_source, item_custom_scope_id, item_target_node_path
					)
					if scope_container != null:
						scope_container.set_variable(item_variable, item)

			BaseVariable.VariableScope.GLOBAL:
				VariableOperations.set_variable(context, item_variable, BaseVariable.VariableScope.GLOBAL, item)

		# 执行子指令
		_execute_child_instructions(context)

	_on_execution_completed()
```

**验证:** 确认循环逻辑正确

---

#### Task 3.2.7: 添加 _validate_property()（3分钟）

**操作:** 添加属性验证

```gdscript
func _validate_property(property: Dictionary) -> void:
	# 数组作用域
	if array_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, array_scope_source as VariableScopeUtils.ScopeSource)
	else:
		if property.name in ["array_scope_source", "array_custom_scope_id", "array_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 元素作用域
	if item_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, item_scope_source as VariableScopeUtils.ScopeSource)
	else:
		if property.name in ["item_scope_source", "item_custom_scope_id", "item_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
```

**验证:** 在编辑器中测试

---

#### Task 3.2.8: 修改 validate()（3分钟）

**操作:** 添加作用域验证

```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	if array_variable.is_empty():
		errors.append(BricksLocalization.translate("BRICKS_ERROR_VAR_NAME_EMPTY"))

	if item_variable.is_empty():
		errors.append(BricksLocalization.translate("BRICKS_ERROR_VAR_NAME_EMPTY"))

	# 验证数组 SCOPE
	if array_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(BricksLocalization.translate("BRICKS_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		var utils_scope_source = array_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source, array_custom_scope_id, array_target_node_path
		))

	# 验证元素 SCOPE
	if item_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(BricksLocalization.translate("BRICKS_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		var utils_scope_source = item_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source, item_custom_scope_id, item_target_node_path
		))

	return errors
```

**验证:** 在编辑器中测试验证

---

#### Task 3.2.9: 测试与语法检查（4分钟）

**操作:** 运行语法检查

**命令:**
```bash
"E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit
```

**验证:** 确认无错误，提交代码

---

### 3.3 for_loop.gd - 双作用域（条件化读写）（~30分钟）

**文件路径:** `addons/bricks/instructions/flow_control/for_loop.gd`
**修改类型:** 双作用域（读取循环次数 + 写入循环索引，条件化）
**参考:** `for_each.gd` (类似模式)

---

**Task 3.3.1-3.3.9:** 参考 Task 3.2.1-3.2.9，调整以下内容：
- `array_variable` → `loop_count_variable`（循环次数变量，可选）
- `array_scope` → `loop_count_scope`（循环次数作用域，可选）
- `item_variable` → `index_variable`（索引变量）
- `item_scope` → `index_scope`（索引作用域）
- 添加条件：仅在 `use_loop_count_variable = true` 时显示循环次数配置

---

## 阶段三总结（Checkpoint 3）

**完成组件:** 3个（中优先级 - Flow Control）
**预估时间:** ~70分钟

**提交建议:**
```
feat: 添加 Flow Control 的 ScopeSource 支持

- while_loop.gd: 单作用域读取（条件变量）
- for_each.gd: 双作用域（数组读 + 元素写）
- for_loop.gd: 双作用域（循环次数读 + 索引写，条件化）

参考：check_variable.gd, for_each.gd
```

---

## 阶段四：中优先级组件 - Debug & Scene & Variables（3个，~60分钟）

### 4.1 print_variable_value.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/instructions/debug/print_variable_value.gd`
**修改类型:** 单作用域读取（读取要打印的变量）
**参考:** Task 2.1（完全相同的模式）

---

**Task 4.1.1-4.1.5:** 参考 Task 2.1.1-2.1.5，替换以下内容：
- `start_time_variable` → `variable_name`（变量名）
- `start_time` → `value`（结果变量名）

---

### 4.2 get_delta_time.gd - 单作用域写入（~15分钟）

**文件路径:** `addons/bricks/instructions/time/get_delta_time.gd`
**修改类型:** 单作用域写入（保存时间增量）
**参考:** Task 1.2（instantiate_scene.gd 模式）

---

**Task 4.2.1-4.2.8:** 参考 Task 1.2.1-1.2.8，替换以下内容：
- `target_variable` → `save_to_variable`（变量名）
- `instance_id` → `delta`（结果变量名，值为 float）

---

### 4.3 load_scene_background.gd - 单作用域写入（~30分钟）

**文件路径:** `addons/bricks/instructions/scene/load_scene_background.gd`
**修改类型:** 单作用域写入（保存加载状态）
**优先级:** 低（复杂度较高，后台加载）

---

**Task 4.3.1-4.3.8:** 参考 Task 1.2.1-1.2.8，替换以下内容：
- `target_variable` → `result_variable`（变量名）
- `instance_id` → `resource_id`（结果变量名，值为 ResourceLoader.load() 返回的 RID）

**注意:** 后台加载使用 ResourceLoader.load_threaded()，需要在回调中保存结果

---

## 阶段四总结（Checkpoint 4）

**完成组件:** 3个（中优先级 - Debug/Scene）
**预估时间:** ~60分钟

**提交建议:**
```
feat: 添加 Debug/Scene 的 ScopeSource 支持

- print_variable_value.gd: 单作用域读取（打印变量）
- get_delta_time.gd: 单作用域写入（时间增量）
- load_scene_background.gd: 单作用域写入（加载状态）

参考：check_variable.gd, random_number.gd
```

---

## 阶段五：中优先级组件 - Node Operations（1个，~20分钟）

### 5.1 find_node.gd - 单作用域写入（~20分钟）

**文件路径:** `addons/bricks/instructions/node_operations/find_node.gd`
**修改类型:** 单作用域写入（保存节点引用）
**参考:** Task 1.2（instantiate_scene.gd 模式）

---

**Task 5.1.1-5.1.8:** 参考 Task 1.2.1-1.2.8，替换以下内容：
- `target_variable` → `result_variable`（变量名）
- `instance_id` → `found_node`（结果变量名，值为 Node）

---

## 阶段五总结（Checkpoint 5）

**完成组件:** 1个（中优先级 - Node Operations）
**预估时间:** ~20分钟

**提交建议:**
```
feat: 添加 Node Operations 的 ScopeSource 支持

- find_node.gd: 单作用域写入（节点引用）

参考：instantiate_scene.gd
```

---

## 阶段六：中优先级组件 - Animation/Camera/UI/Transform（11个，~165分钟）

此阶段包含多个相似的组件，可批量处理。

### 6.1 blend_animation.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/instructions/animation/blend_animation.gd`
**修改类型:** 单作用域读取（读取混合变量）
**参考:** Task 2.1（完全相同的模式）

---

**Task 6.1.1-6.1.5:** 参考 Task 2.1.1-2.1.5，替换以下内容：
- `start_time_variable` → `blend_variable`（变量名）
- `start_time` → `blend_amount`（结果变量名，值为 float）

---

### 6.2 set_camera_zoom.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/instructions/camera/set_camera_zoom.gd`
**修改类型:** 单作用域读取（读取缩放变量）
**参考:** Task 2.1（完全相同的模式）

---

**Task 6.2.1-6.2.5:** 参考 Task 2.1.1-2.1.5，替换以下内容：
- `start_time_variable` → `zoom_variable`（变量名）
- `start_time` → `zoom`（结果变量名，值为 float）

---

### 6.3-6.5 UI组件（3个，~45分钟）

#### 6.3 set_ui_progress.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/instructions/ui/set_ui_progress.gd`
**参考:** Task 2.1

**替换内容:**
- `start_time_variable` → `value_variable`
- `start_time` → `progress_value`

---

#### 6.4 set_ui_text.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/instructions/ui/set_ui_text.gd`
**参考:** Task 2.1

**替换内容:**
- `start_time_variable` → `text_variable`
- `start_time` → `text_content`

---

#### 6.5 set_ui_texture.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/instructions/ui/set_ui_texture.gd`
**参考:** Task 2.1

**替换内容:**
- `start_time_variable` → `texture_variable`
- `start_time` → `texture_resource`（值为 Texture2D）

---

### 6.6-6.11 Transform组件（6个，~90分钟）

所有 Transform 组件使用相同的模式：单作用域读取（读取向量/浮点变量）

#### 6.6 look_at.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/instructions/transform/look_at.gd`
**参考:** Task 2.1

**替换内容:**
- `start_time_variable` → `offset_variable`
- `start_time` → `offset`（值为 Vector3）

---

#### 6.7 move_by.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/instructions/transform/move_by.gd`
**参考:** Task 2.1

**替换内容:**
- `start_time_variable` → `position_variable`
- `start_time` → `position`（值为 Vector2 或 Vector3）

---

#### 6.8 rotate_by.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/instructions/transform/rotate_by.gd`
**参考:** Task 2.1

**替换内容:**
- `start_time_variable` → `rotation_variable`
- `start_time` → `rotation`（值为 float 或 Vector3）

---

#### 6.9 set_scale.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/instructions/transform/set_scale.gd`
**参考:** Task 2.1

**替换内容:**
- `start_time_variable` → `scale_variable`
- `start_time` → `scale`（值为 Vector2 或 Vector3）

---

#### 6.10 set_rotation.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/instructions/transform/set_rotation.gd`
**参考:** Task 2.1

**替换内容:**
- `start_time_variable` → `rotation_variable`
- `start_time` → `rotation`（值为 float 或 Vector3）

---

#### 6.11 set_position.gd - 单作用域读取（~15分钟）

**文件路径:** `addons/bricks/instructions/transform/set_position.gd`
**参考:** Task 2.1

**替换内容:**
- `start_time_variable` → `position_variable`
- `start_time` → `position`（值为 Vector2 或 Vector3）

---

## 阶段六总结（Checkpoint 6）

**完成组件:** 11个（中优先级 - Animation/Camera/UI/Transform）
**预估时间:** ~165分钟（2小时45分钟）

**提交建议:**
```
feat: 添加 Animation/Camera/UI/Transform 的 ScopeSource 支持

Animation:
- blend_animation.gd: 单作用域读取（混合变量）

Camera:
- set_camera_zoom.gd: 单作用域读取（缩放变量）

UI:
- set_ui_progress.gd: 单作用域读取（进度值）
- set_ui_text.gd: 单作用域读取（文本内容）
- set_ui_texture.gd: 单作用域读取（纹理资源）

Transform:
- look_at.gd: 单作用域读取（偏移量）
- move_by.gd: 单作用域读取（位置）
- rotate_by.gd: 单作用域读取（旋转）
- set_scale.gd: 单作用域读取（缩放）
- set_rotation.gd: 单作用域读取（旋转）
- set_position.gd: 单作用域读取（位置）

参考：check_variable.gd
```

---

## 阶段七：低优先级组件（1个，~60分钟）

### 7.1 wait_until.gd - 三作用域（条件化）（~60分钟）

**文件路径:** `addons/bricks/instructions/flow_control/wait_until.gd`
**修改类型:** 三作用域读取（条件化显示，复杂）
**优先级:** 低（复杂度较高）

---

#### Task 7.1.1: 分析条件类型（5分钟）

**操作:** 阅读 execute() 方法，了解不同条件类型使用的变量

**条件类型:**
1. **VARIABLE_VALUE_EQUALS** - 使用 `variable_a` 和 `variable_a_scope`
2. **VARIABLE_VALUE_GREATER** - 使用 `variable_a` 和 `variable_a_scope`
3. **VARIABLE_B_EQUALS** - 使用 `variable_a`, `variable_b` 和对应作用域
4. **VARIABLE_EXISTS** - 使用 `check_variable` 和 `check_variable_scope`

---

#### Task 7.1.2: 添加 variable_a_scope（5分钟）

**操作:** 添加变量A的作用域枚举

```gdscript
## 变量A作用域
@export var variable_a_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_a_scope = value
		_update_resource_name()
```

---

#### Task 7.1.3: 添加 variable_a ScopeSource（5分钟）

**操作:** 添加变量A的 ScopeSource

```gdscript
## 变量A作用域来源
enum ScopeSource {
	NEAREST, CUSTOM_ID, TRIGGER_SCOPE, TARGET_NODE
}

var variable_a_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		variable_a_scope_source = value
		_update_resource_name()

var variable_a_custom_scope_id: String = ""
var variable_a_target_node_path: NodePath = NodePath("")
```

---

#### Task 7.1.4: 添加 variable_b_scope（5分钟）

**操作:** 添加变量B的作用域枚举（仅在使用 VARIABLE_B_EQUALS 时显示）

```gdscript
## 变量B作用域（仅在某些条件类型时使用）
@export var variable_b_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		variable_b_scope = value
		_update_resource_name()
```

---

#### Task 7.1.5: 添加 variable_b ScopeSource（5分钟）

**操作:** 添加变量B的 ScopeSource

```gdscript
## 变量B作用域来源
var variable_b_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		variable_b_scope_source = value
		_update_resource_name()

var variable_b_custom_scope_id: String = ""
var variable_b_target_node_path: NodePath = NodePath("")
```

---

#### Task 7.1.6: 添加 check_variable_scope（5分钟）

**操作:** 添加检查变量的作用域枚举（仅在使用 VARIABLE_EXISTS 时显示）

```gdscript
## 检查变量作用域（仅在某些条件类型时使用）
@export var check_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		check_variable_scope = value
		_update_resource_name()
```

---

#### Task 7.1.7: 添加 check_variable ScopeSource（5分钟）

**操作:** 添加检查变量的 ScopeSource

```gdscript
## 检查变量作用域来源
var check_variable_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		check_variable_scope_source = value
		_update_resource_name()

var check_variable_custom_scope_id: String = ""
var check_variable_target_node_path: NodePath = NodePath("")
```

---

#### Task 7.1.8: 修改 _get_property_list()（10分钟）

**操作:** 条件化显示三个作用域配置

```gdscript
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# ... 现有代码 ...

	# 变量A配置（始终显示）
	properties.append({
		name = "variable_a_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if variable_a_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "variable_a_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if variable_a_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "variable_a_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif variable_a_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "variable_a_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# 变量B配置（仅在使用变量B的条件类型时显示）
	if condition_type in [ConditionType.VARIABLE_B_EQUALS]:
		properties.append({
			name = "variable_b_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if variable_b_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "variable_b_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if variable_b_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "variable_b_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif variable_b_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "variable_b_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	# 检查变量配置（仅在使用 VARIABLE_EXISTS 时显示）
	if condition_type == ConditionType.VARIABLE_EXISTS:
		properties.append({
			name = "check_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if check_variable_scope == BaseVariable.VariableScope.SCOPE:
			properties.append({
				name = "check_variable_scope_source",
				type = TYPE_INT,
				hint = PROPERTY_HINT_ENUM,
				hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

			if check_variable_scope_source == ScopeSource.CUSTOM_ID:
				properties.append({
					name = "check_variable_custom_scope_id",
					type = TYPE_STRING,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			elif check_variable_scope_source == ScopeSource.TARGET_NODE:
				properties.append({
					name = "check_variable_target_node_path",
					type = TYPE_NODE_PATH,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	return properties
```

**验证:** 运行编辑器，切换 `condition_type` 检查属性显示

---

#### Task 7.1.9: 修改 execute() - 变量A读取（8分钟）

**操作:** 替换变量A的读取逻辑

```gdscript
	# 读取变量A
	var variable_a_value = null
	match variable_a_scope:
		BaseVariable.VariableScope.LOCAL:
			variable_a_value = VariableOperations.get_variable(context, variable_a, BaseVariable.VariableScope.LOCAL, null)

		BaseVariable.VariableScope.SCOPE:
			if variable_a_scope_source == ScopeSource.NEAREST:
				variable_a_value = VariableOperations.get_variable(context, variable_a, BaseVariable.VariableScope.SCOPE, null)
			else:
				var utils_scope_source = variable_a_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context, utils_scope_source, variable_a_custom_scope_id, variable_a_target_node_path
				)
				if scope_container != null:
					variable_a_value = scope_container.get_variable(variable_a, null)

		BaseVariable.VariableScope.GLOBAL:
			variable_a_value = VariableOperations.get_variable(context, variable_a, BaseVariable.VariableScope.GLOBAL, null)
```

---

#### Task 7.1.10: 修改 execute() - 变量B读取（8分钟）

**操作:** 替换变量B的读取逻辑（仅在需要时）

```gdscript
	# 读取变量B（如果需要）
	var variable_b_value = null
	if condition_type == ConditionType.VARIABLE_B_EQUALS:
		match variable_b_scope:
			BaseVariable.VariableScope.LOCAL:
				variable_b_value = VariableOperations.get_variable(context, variable_b, BaseVariable.VariableScope.LOCAL, null)

			BaseVariable.VariableScope.SCOPE:
				if variable_b_scope_source == ScopeSource.NEAREST:
					variable_b_value = VariableOperations.get_variable(context, variable_b, BaseVariable.VariableScope.SCOPE, null)
				else:
					var utils_scope_source = variable_b_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context, utils_scope_source, variable_b_custom_scope_id, variable_b_target_node_path
					)
					if scope_container != null:
						variable_b_value = scope_container.get_variable(variable_b, null)

			BaseVariable.VariableScope.GLOBAL:
				variable_b_value = VariableOperations.get_variable(context, variable_b, BaseVariable.VariableScope.GLOBAL, null)
```

---

#### Task 7.1.11: 修改 execute() - 检查变量存在（5分钟）

**操作:** 替换变量存在性检查逻辑（仅在需要时）

```gdscript
	# 检查变量存在（如果需要）
	if condition_type == ConditionType.VARIABLE_EXISTS:
		match check_variable_scope:
			BaseVariable.VariableScope.LOCAL:
				return VariableOperations.has_variable(context, check_variable, BaseVariable.VariableScope.LOCAL)

			BaseVariable.VariableScope.SCOPE:
				if check_variable_scope_source == ScopeSource.NEAREST:
					return VariableOperations.has_variable(context, check_variable, BaseVariable.VariableScope.SCOPE)
				else:
					var utils_scope_source = check_variable_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context, utils_scope_source, check_variable_custom_scope_id, check_variable_target_node_path
					)
					if scope_container != null:
						return scope_container.has_variable(check_variable)
					return false

			BaseVariable.VariableScope.GLOBAL:
				return VariableOperations.has_variable(context, check_variable, BaseVariable.VariableScope.GLOBAL)
```

---

#### Task 7.1.12: 添加 _validate_property()（5分钟）

**操作:** 添加属性可见性验证

```gdscript
func _validate_property(property: Dictionary) -> void:
	# 变量A
	if variable_a_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, variable_a_scope_source as VariableScopeUtils.ScopeSource)
	else:
		if property.name in ["variable_a_scope_source", "variable_a_custom_scope_id", "variable_a_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 变量B（仅在使用时）
	if condition_type == ConditionType.VARIABLE_B_EQUALS:
		if variable_b_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, variable_b_scope_source as VariableScopeUtils.ScopeSource)
		else:
			if property.name in ["variable_b_scope", "variable_b_scope_source", "variable_b_custom_scope_id", "variable_b_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["variable_b_scope", "variable_b_scope_source", "variable_b_custom_scope_id", "variable_b_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 检查变量（仅在使用时）
	if condition_type == ConditionType.VARIABLE_EXISTS:
		if check_variable_scope == BaseVariable.VariableScope.SCOPE:
			VariableScopeUtils.validate_scope_source_property(property, check_variable_scope_source as VariableScopeUtils.ScopeSource)
		else:
			if property.name in ["check_variable_scope", "check_variable_scope_source", "check_variable_custom_scope_id", "check_variable_target_node_path"]:
				property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name in ["check_variable_scope", "check_variable_scope_source", "check_variable_custom_scope_id", "check_variable_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
```

---

#### Task 7.1.13: 修改 validate()（5分钟）

**操作:** 添加作用域验证

```gdscript
func validate() -> Array[String]:
	var errors = super.validate()

	# 基础验证...
	# ...

	# 变量A SCOPE 验证
	if variable_a_scope == BaseVariable.VariableScope.SCOPE:
		var manager = ScopeVariableManager.get_instance()
		if manager == null:
			errors.append(BricksLocalization.translate("BRICKS_ERROR_SCOPE_MANAGER_NOT_FOUND"))

		var utils_scope_source = variable_a_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source, variable_a_custom_scope_id, variable_a_target_node_path
		))

	# 变量B SCOPE 验证
	if condition_type == ConditionType.VARIABLE_B_EQUALS:
		if variable_b_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(BricksLocalization.translate("BRICKS_ERROR_SCOPE_MANAGER_NOT_FOUND"))

			var utils_scope_source = variable_b_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source, variable_b_custom_scope_id, variable_b_target_node_path
			))

	# 检查变量 SCOPE 验证
	if condition_type == ConditionType.VARIABLE_EXISTS:
		if check_variable_scope == BaseVariable.VariableScope.SCOPE:
			var manager = ScopeVariableManager.get_instance()
			if manager == null:
				errors.append(BricksLocalization.translate("BRICKS_ERROR_SCOPE_MANAGER_NOT_FOUND"))

			var utils_scope_source = check_variable_scope_source as VariableScopeUtils.ScopeSource
			errors.append_array(VariableScopeUtils.validate_scope_source_params(
				utils_scope_source, check_variable_custom_scope_id, check_variable_target_node_path
			))

	return errors
```

---

#### Task 7.1.14: 测试与语法检查（5分钟）

**操作:** 运行语法检查

**命令:**
```bash
"E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit
```

**验证:** 确认无错误，提交代码

---

## 阶段七总结（Checkpoint 7）

**完成组件:** 1个（低优先级 - Flow Control 复杂）
**预估时间:** ~60分钟

**提交建议:**
```
feat: 添加 wait_until 的 ScopeSource 支持（三作用域条件化）

- variable_a_scope: 变量A作用域（始终使用）
- variable_b_scope: 变量B作用域（仅 VARIABLE_B_EQUALS 时）
- check_variable_scope: 检查变量作用域（仅 VARIABLE_EXISTS 时）

根据条件类型动态显示不同的作用域配置

参考：check_variable.gd, for_loop.gd
```

---

## 总结与验证

### 总体进度

| 阶段 | 组件数 | 预估时间 | 优先级 |
|------|--------|----------|--------|
| 阶段一 | 4 | ~90分钟 | 高 |
| 阶段二 | 3 | ~45分钟 | 中 |
| 阶段三 | 3 | ~70分钟 | 中 |
| 阶段四 | 3 | ~60分钟 | 中 |
| 阶段五 | 1 | ~20分钟 | 中 |
| 阶段六 | 11 | ~165分钟 | 中 |
| 阶段七 | 1 | ~60分钟 | 低 |
| **总计** | **26** | **~8.5小时** | - |

**注意:** 原 scope_source_todos.md 中列出了 23 个组件，但计划中包含了所有相关组件（包括之前文档中列出的 26 个）

### 最终验证步骤

#### 1. 语法检查（必做）

```bash
"E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit
```

**验证标准:**
- ✅ 无语法错误
- ⚠️ 可能有本地化警告（BRICKS_VARIABLE_SCOPE_LOCAL_STR 等），可忽略

---

#### 2. 功能测试（推荐）

创建测试场景 `test_scope_source_fixes.tscn`，包含：

**场景树结构:**
```
TestScene (ScopeVariableContainer, scope_id: "test_root")
├── TestTrigger (Trigger)
│   └── TestInstructions (包含各种测试指令)
├── PlayerStats (ScopeVariableContainer, scope_id: "player_stats")
│   └── Player
└── EnemyStats (ScopeVariableContainer, scope_id: "enemy_stats")
    └── Enemy
```

**测试用例:**

1. **LOCAL 变量测试**
   - 指令：set_int_variable.gd
   - 配置：target_variable_scope = LOCAL, from_variable_scope = LOCAL
   - 验证：指令执行后 LOCAL 变量正确设置

2. **GLOBAL 变量测试**
   - 指令：set_int_variable.gd
   - 配置：target_variable_scope = GLOBAL, from_variable_scope = GLOBAL
   - 验证：指令执行后 GLOBAL 变量正确设置

3. **SCOPE + NEAREST 测试**
   - 指令：set_int_variable.gd
   - 配置：target_variable_scope = SCOPE, target_scope_source = NEAREST
   - 验证：使用最近的 ScopeVariableContainer

4. **SCOPE + CUSTOM_ID 测试**
   - 指令：set_int_variable.gd
   - 配置：target_variable_scope = SCOPE, target_scope_source = CUSTOM_ID, target_custom_scope_id = "player_stats"
   - 验证：使用指定的 ScopeVariableContainer

5. **SCOPE + TRIGGER_SCOPE 测试**
   - 指令：instantiate_scene.gd
   - 配置：save_to_scope = SCOPE, scope_source = TRIGGER_SCOPE
   - 验证：使用 Trigger 节点上的 ScopeVariableContainer

6. **SCOPE + TARGET_NODE 测试**
   - 指令：set_property_value.gd
   - 配置：value_scope = SCOPE, scope_source = TARGET_NODE, target_node_path = "../PlayerStats"
   - 验证：使用目标节点上的 ScopeVariableContainer

7. **双作用域测试**
   - 指令：for_each.gd
   - 配置：array_scope = SCOPE, item_scope = LOCAL
   - 验证：从 SCOPE 读取数组，写入 LOCAL 元素

8. **条件化作用域测试**
   - 指令：wait_until.gd
   - 配置：condition_type = VARIABLE_B_EQUALS
   - 验证：只显示 variable_a 和 variable_b 的作用域配置

---

#### 3. UI 验证（推荐）

在 Godot 编辑器中验证：

1. **Inspector 显示**
   - ✅ 选择 LOCAL/GLOBAL 时，ScopeSource 相关选项隐藏
   - ✅ 选择 SCOPE 时，ScopeSource 相关选项显示
   - ✅ ScopeSource 切换时，custom_scope_id 和 target_node_path 正确显示/隐藏

2. **资源名称更新**
   - ✅ 切换作用域时，资源名称实时更新
   - ✅ 作用域字符串正确显示（LOCAL/SCOPE[Nearest]/SCOPE[Custom ID:xxx]/GLOBAL）

3. **验证消息**
   - ✅ SCOPE 作用域时，ScopeVariableManager 不存在时显示错误
   - ✅ CUSTOM_ID 模式时，custom_scope_id 为空显示错误
   - ✅ TARGET_NODE 模式时，target_node_path 为空显示错误

---

#### 4. 对比验证（推荐）

与已完成的组件对比，确保实现一致性：

- **单作用域读取:** 对比 `clamp_value.gd`
- **单作用域写入:** 对比 `random_number.gd`
- **双作用域:** 对比 `set_variable.gd`
- **完全正确:** 对比 `create_variable.gd`

---

#### 5. 性能验证（可选）

**测试场景:** 大量使用 SCOPE 变量的指令

**性能指标:**
- ❌ 避免在循环中重复查找 ScopeContainer
- ✅ 循环外查找一次，缓存引用
- ✅ 使用 NEAREST 模式时，VariableOperations 内部有缓存优化

**测试方法:**
```gdscript
# 测试循环性能
for i in range(1000):
    # ❌ 错误：每次循环都查找
    var container = VariableScopeUtils.get_scope_container_by_source(...)
    container.set_variable("count", i)

    # ✅ 正确：循环外查找一次
    var container = VariableScopeUtils.get_scope_container_by_source(...)
    for i in range(1000):
        container.set_variable("count", i)
```

---

## 执行方式选择

完成计划后，您可以选择以下执行方式：

### 方式 A：Subagent-Driven（推荐用于分批执行）

**优点:**
- 每个阶段独立，可并行处理
- 失败后可单独重试该阶段
- 适合长时间任务（>2小时）

**缺点:**
- 需要多次启动子代理
- 上下文无法跨阶段共享

**命令示例:**
```bash
# 执行阶段一
/execute-plan 2026-02-10-scope-source-fixes.md --stage 1

# 执行阶段二
/execute-plan 2026-02-10-scope-source-fixes.md --stage 2
```

---

### 方式 B：Parallel Session（推荐用于快速完成）

**优点:**
- 可同时执行多个阶段
- 上下文共享
- 适合快速完成任务

**缺点:**
- 需要管理多个并行任务
- 失败后可能需要重试整个批次

**命令示例:**
```bash
# 并行执行阶段一、二、三
/execute-plan 2026-02-10-scope-source-fixes.md --parallel --stages 1,2,3

# 并行执行阶段四、五、六
/execute-plan 2026-02-10-scope-source-fixes.md --parallel --stages 4,5,6
```

---

### 方式 C：Manual Execution（推荐用于学习和调试）

**优点:**
- 完全控制执行过程
- 可随时暂停和调试
- 适合学习修改模式

**缺点:**
- 需要手动跟踪进度
- 容易遗漏步骤

**执行步骤:**
1. 打开计划文件
2. 按照 Task 顺序逐个执行
3. 每个阶段完成后运行语法检查
4. 提交代码并进入下一阶段

---

## 常见问题

### Q1: 类型转换错误 `Cannot convert int to VariableScopeUtils.ScopeSource`

**解决方法:**
```gdscript
# ❌ 错误
var utils_scope_source = scope_source  # 本地枚举无法直接转换

# ✅ 正确
var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
```

---

### Q2: Inspector 属性不显示/隐藏

**可能原因:**
1. `notify_property_list_changed()` 未调用
2. `_validate_property()` 逻辑错误
3. 属性名拼写错误

**解决方法:**
```gdscript
var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		save_to_scope = value
		_update_resource_name()
		notify_property_list_changed()  # 必须调用
```

---

### Q3: ScopeContainer 返回 null

**可能原因:**
1. 场景中没有 `ScopeVariableContainer` 节点
2. `scope_id` 未设置或错误
3. `ScopeVariableManager` 实例不存在

**解决方法:**
```gdscript
# 添加验证
var manager = ScopeVariableManager.get_instance()
if manager == null:
	_log_error("未找到 ScopeVariableManager 实例")
	return

var scope_container = VariableScopeUtils.get_scope_container_by_source(...)
if scope_container == null:
	_log_error("未找到 ScopeContainer")
	return
```

---

### Q4: 变量值不更新

**可能原因:**
1. 使用了错误的作用域
2. 变量名拼写错误
3. 多个同名变量在不同作用域

**解决方法:**
```gdscript
# 使用日志调试
print("作用域: %s, 变量名: %s, 值: %s" % [save_to_scope, save_to_variable, result])
```

---

## 附录：快速查找表

### 修改模式速查

| 模式 | 参考组件 | 关键文件 |
|------|----------|----------|
| 单作用域读取 | check_variable.gd | Task 2.1 |
| 单作用域写入 | random_number.gd | Task 1.2 |
| 双作用域（读写） | set_variable.gd | Task 1.1 |
| 双作用域（条件化） | for_loop.gd | Task 3.3 |
| 三作用域（条件化） | wait_until.gd | Task 7.1 |

### 文件路径速查

| 组件类别 | 文件路径 |
|----------|----------|
| Conditions | `addons/bricks/conditions/` |
| Instructions | `addons/bricks/instructions/` |
| Debug | `instructions/debug/` |
| Flow Control | `instructions/flow_control/` |
| Math | `instructions/math/` |
| Variables | `instructions/variables/` |
| Node Operations | `instructions/node_operations/` |
| Physics | `instructions/physics/` |
| Scene | `instructions/scene/` |
| Time | `instructions/time/` |
| Animation | `instructions/animation/` |
| Camera | `instructions/camera/` |
| UI | `instructions/ui/` |
| Transform | `instructions/transform/` |

---

**计划创建完成！** 🎉

现在您可以选择执行方式：
1. **Subagent-Driven** - 分阶段执行（推荐）
2. **Parallel Session** - 并行快速完成
3. **Manual Execution** - 手动逐步执行

请告诉我您希望使用哪种方式，我将开始执行计划。
