# Bricks 字典操作指令与条件实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Bricks 可视化编程系统创建完整的字典（Dictionary）操作指令和条件，覆盖游戏开发中常见的字典使用场景。

**Architecture:**
- 遵循现有 Bricks 插件的架构模式，继承 `BaseInstruction` 和 `BaseCondition`
- 复用 `VariableOperations` 统一变量访问 API（LOCAL/SCOPE/GLOBAL 三层作用域）
- 使用 `BricksLocalization` 实现多语言支持
- 使用 `ConditionMetadata` / `InstructionMetadata` 提供元数据

**Tech Stack:** GDScript 2.0, Godot 4.6, Bricks Plugin System

---

## 概述

本计划将实现以下字典操作功能：

### 指令（Instructions）- 共 16 个

| 指令名 | 分类 | 功能描述 |
|--------|------|----------|
| DictSetKeyValue | dictionaries/basic | 设置/更新键值 |
| DictGetValue | dictionaries/basic | 获取键值（支持默认值） |
| DictRemoveKey | dictionaries/basic | 移除键 |
| DictClear | dictionaries/basic | 清空字典 |
| DictModifyNumber | dictionaries/numeric | 数值增减（+= / -=） |
| DictMathOp | dictionaries/numeric | 数学运算（* / /） |
| DictToggleBoolean | dictionaries/numeric | 布尔取反 |
| DictMerge | dictionaries/data | 字典合并 |
| DictToJSON | dictionaries/data | 转为 JSON 字符串 |
| DictFromJSON | dictionaries/data | 从 JSON 解析 |
| DictSize | dictionaries/data | 获取字典大小 |
| DictGetKeys | dictionaries/list | 获取所有键（返回数组） |
| DictGetValues | dictionaries/list | 获取所有值（返回数组） |
| DictDuplicate | dictionaries/utility | 深拷贝字典 |
| DictGetByPath | dictionaries/path | 路径访问获取（嵌套） |
| DictSetByPath | dictionaries/path | 路径访问设置（嵌套） |

### 条件（Conditions）- 共 2 个

| 条件名 | 功能描述 |
|--------|----------|
| CheckDictContainsKey | 检查键是否存在 |
| CheckDictSize | 检查字典大小 |

---

## 文件结构

```
addons/bricks/
├── instructions/
│   └── dictionaries/
│       ├── dict_set_key_value.gd       # 设置键值
│       ├── dict_get_value.gd           # 获取值
│       ├── dict_remove_key.gd          # 移除键
│       ├── dict_clear.gd               # 清空
│       ├── dict_modify_number.gd       # 数值修改
│       ├── dict_math_op.gd             # 数学运算
│       ├── dict_toggle_boolean.gd      # 布尔取反
│       ├── dict_merge.gd               # 合并
│       ├── dict_to_json.gd             # 转 JSON
│       ├── dict_from_json.gd           # 从 JSON
│       ├── dict_size.gd                # 获取大小
│       ├── dict_get_keys.gd            # 获取键数组
│       ├── dict_get_values.gd          # 获取值数组
│       ├── dict_duplicate.gd           # 深拷贝
│       ├── dict_get_by_path.gd         # 路径获取
│       └── dict_set_by_path.gd         # 路径设置
├── conditions/
│   └── dictionaries/
│       ├── check_dict_contains_key.gd  # 检查键存在
│       └── check_dict_size.gd          # 检查大小
└── localization/
    └── translations.csv                 # 添加翻译键
```

---

## 参考文件

实现时应参考以下现有文件作为模板：

- **指令模板**: `addons/bricks/instructions/arrays/array_add.gd`
- **获取模板**: `addons/bricks/instructions/arrays/array_get.gd`
- **条件模板**: `addons/bricks/conditions/arrays/check_array_contains.gd`
- **大小检查模板**: `addons/bricks/conditions/arrays/check_array_size.gd`
- **基类**: `addons/bricks/core/base/base_instruction.gd`
- **条件基类**: `addons/bricks/core/base/base_condition.gd`
- **变量操作**: `addons/bricks/core/utils/variable_operations.gd`

---

## Task 1: 创建目录结构

**Files:**
- Create: `addons/bricks/instructions/dictionaries/` (directory)
- Create: `addons/bricks/conditions/dictionaries/` (directory)

**Step 1: 创建指令目录**

```bash
mkdir -p "e:/Godot/GodotProjects/project-juicy-godot/addons/bricks/instructions/dictionaries"
```

**Step 2: 创建条件目录**

```bash
mkdir -p "e:/Godot/GodotProjects/project-juicy-godot/addons/bricks/conditions/dictionaries"
```

**Step 3: 验证目录创建**

Run: `ls -la "e:/Godot/GodotProjects/project-juicy-godot/addons/bricks/instructions/dictionaries"`

Expected: 目录存在且为空

---

## Task 2: 添加本地化翻译键

**Files:**
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 在 translations.csv 末尾添加翻译键**

添加以下内容到 CSV 文件：

```csv
# Dictionary Instructions - Basic
BRICKS_INSTRUCTION_DICT_SET_NAME,设置键值,Set Key Value
BRICKS_INSTRUCTION_DICT_SET_DESC,设置字典中指定键的值,Set the value for a specified key in the dictionary
BRICKS_INSTRUCTION_DICT_GET_NAME,获取键值,Get Value by Key
BRICKS_INSTRUCTION_DICT_GET_DESC,获取字典中指定键的值,Get the value for a specified key from the dictionary
BRICKS_INSTRUCTION_DICT_REMOVE_NAME,移除键,Remove Key
BRICKS_INSTRUCTION_DICT_REMOVE_DESC,从字典中移除指定的键,Remove the specified key from the dictionary
BRICKS_INSTRUCTION_DICT_CLEAR_NAME,清空字典,Clear Dictionary
BRICKS_INSTRUCTION_DICT_CLEAR_DESC,清空字典中的所有键值对,Remove all key-value pairs from the dictionary

# Dictionary Instructions - Numeric
BRICKS_INSTRUCTION_DICT_MODIFY_NUM_NAME,修改数值,Modify Number Value
BRICKS_INSTRUCTION_DICT_MODIFY_NUM_DESC,对字典中数值类型的键进行增减操作,Add or subtract from a numeric key in the dictionary
BRICKS_INSTRUCTION_DICT_MATH_OP_NAME,数学运算,Math Operation
BRICKS_INSTRUCTION_DICT_MATH_OP_DESC,对字典中数值类型的键进行乘除运算,Multiply or divide a numeric key in the dictionary
BRICKS_INSTRUCTION_DICT_TOGGLE_BOOL_NAME,切换布尔值,Toggle Boolean
BRICKS_INSTRUCTION_DICT_TOGGLE_BOOL_DESC,切换字典中布尔值键的状态,Toggle the boolean value of a key in the dictionary

# Dictionary Instructions - Data
BRICKS_INSTRUCTION_DICT_MERGE_NAME,合并字典,Merge Dictionaries
BRICKS_INSTRUCTION_DICT_MERGE_DESC,将源字典合并到目标字典,Merge source dictionary into target dictionary
BRICKS_INSTRUCTION_DICT_TO_JSON_NAME,转为 JSON,To JSON String
BRICKS_INSTRUCTION_DICT_TO_JSON_DESC,将字典转换为 JSON 字符串,Convert dictionary to JSON string
BRICKS_INSTRUCTION_DICT_FROM_JSON_NAME,从 JSON 解析,From JSON String
BRICKS_INSTRUCTION_DICT_FROM_JSON_DESC,从 JSON 字符串解析字典,Parse dictionary from JSON string
BRICKS_INSTRUCTION_DICT_SIZE_NAME,字典大小,Dictionary Size
BRICKS_INSTRUCTION_DICT_SIZE_DESC,获取字典中键值对的数量,Get the number of key-value pairs in the dictionary

# Dictionary Instructions - List
BRICKS_INSTRUCTION_DICT_GET_KEYS_NAME,获取所有键,Get All Keys
BRICKS_INSTRUCTION_DICT_GET_KEYS_DESC,获取字典中所有键组成的数组,Get an array of all keys in the dictionary
BRICKS_INSTRUCTION_DICT_GET_VALUES_NAME,获取所有值,Get All Values
BRICKS_INSTRUCTION_DICT_GET_VALUES_DESC,获取字典中所有值组成的数组,Get an array of all values in the dictionary

# Dictionary Instructions - Utility
BRICKS_INSTRUCTION_DICT_DUPLICATE_NAME,深拷贝字典,Duplicate Dictionary
BRICKS_INSTRUCTION_DICT_DUPLICATE_DESC,创建字典的深拷贝,Create a deep copy of the dictionary

# Dictionary Instructions - Path
BRICKS_INSTRUCTION_DICT_GET_BY_PATH_NAME,路径获取,Get by Path
BRICKS_INSTRUCTION_DICT_GET_BY_PATH_DESC,通过嵌套路径获取字典中的值,Get a value from nested dictionary using path
BRICKS_INSTRUCTION_DICT_SET_BY_PATH_NAME,路径设置,Set by Path
BRICKS_INSTRUCTION_DICT_SET_BY_PATH_DESC,通过嵌套路径设置字典中的值,Set a value in nested dictionary using path

# Dictionary Conditions
BRICKS_CONDITION_DICT_CONTAINS_KEY_NAME,键存在检查,Check Key Exists
BRICKS_CONDITION_DICT_CONTAINS_KEY_DESC,检查字典中是否存在指定的键,Check if a key exists in the dictionary
BRICKS_CONDITION_DICT_SIZE_NAME,字典大小检查,Check Dictionary Size
BRICKS_CONDITION_DICT_SIZE_DESC,检查字典大小是否满足条件,Check if dictionary size meets the condition

# Dictionary Category
BRICKS_CATEGORY_DICTIONARIES,字典,Dictionaries

# Dictionary Error Messages
BRICKS_ERROR_DICT_VARIABLE_EMPTY,字典变量名为空,Dictionary variable name is empty
BRICKS_ERROR_DICT_VARIABLE_NOT_FOUND,字典变量 '{name}' 未找到,Dictionary variable '{name}' not found
BRICKS_ERROR_DICT_KEY_EMPTY,键名为空,Key name is empty
BRICKS_ERROR_DICT_KEY_NOT_FOUND,键 '{key}' 在字典中不存在,Key '{key}' does not exist in dictionary
BRICKS_ERROR_DICT_NOT_A_DICTIONARY,变量 '{name}' 不是字典类型,Variable '{name}' is not a dictionary
BRICKS_ERROR_DICT_VALUE_NOT_NUMBER,键 '{key}' 的值不是数字类型,Value for key '{key}' is not a number
BRICKS_ERROR_DICT_VALUE_NOT_BOOL,键 '{key}' 的值不是布尔类型,Value for key '{key}' is not a boolean
BRICKS_ERROR_DICT_JSON_PARSE_FAILED,JSON 解析失败: {error},JSON parsing failed: {error}
BRICKS_ERROR_DICT_PATH_INVALID,无效的字典路径: {path},Invalid dictionary path: {path}
BRICKS_ERROR_DICT_PATH_SEGMENT_NOT_DICT,路径段 '{segment}' 不是字典,Path segment '{segment}' is not a dictionary

# Dictionary Log Messages
BRICKS_LOG_DICT_SET,字典 '{dict}' 设置键 '{key}' = {value},Dictionary '{dict}' set key '{key}' = {value}
BRICKS_LOG_DICT_GET,字典 '{dict}' 获取键 '{key}' = {value},Dictionary '{dict}' get key '{key}' = {value}
BRICKS_LOG_DICT_REMOVE,字典 '{dict}' 移除键 '{key}',Dictionary '{dict}' removed key '{key}'
BRICKS_LOG_DICT_CLEARED,字典 '{dict}' 已清空,Dictionary '{dict}' cleared
BRICKS_LOG_DICT_MODIFIED,字典 '{dict}' 键 '{key}' {op} {amount} = {result},Dictionary '{dict}' key '{key}' {op} {amount} = {result}
BRICKS_LOG_DICT_MERGED,字典合并: {source} → {target},Dictionary merged: {source} → {target}
BRICKS_LOG_DICT_TO_JSON,字典转为 JSON: {json},Dictionary to JSON: {json}
BRICKS_LOG_DICT_FROM_JSON,从 JSON 解析字典,Dictionary parsed from JSON
BRICKS_LOG_DICT_DUPLICATED,字典 '{source}' 已拷贝到 '{target}',Dictionary '{source}' duplicated to '{target}'

# Dictionary Display Strings
BRICKS_DICT_NO_DICT,未指定字典,No Dictionary
BRICKS_DICT_KEY_UNSET,键未设置,Key Unset
BRICKS_DICT_VALUE_UNSET,值未设置,Value Unset
BRICKS_DICT_TARGET_VAR_UNSET,目标变量未设置,Target Variable Unset
```

**Step 2: 验证翻译添加**

Run: 检查 CSV 文件格式是否正确

---

## Task 3: 实现 DictSetKeyValue 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_set_key_value.gd`

**Step 1: 创建指令文件**

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/Dictionary.png")
extends BaseInstruction
class_name DictSetKeyValue

## DictSetKeyValue 指令
##
## 设置字典中指定键的值。
## 如果键不存在则创建，存在则覆盖。
## 支持从变量、节点获取字典。

## 作用域来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

# 字典变量名
var dict_variable: String = "":
	set(value):
		if dict_variable != value:
			dict_variable = value
			_update_resource_name()

# 字典变量作用域
var dict_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		if dict_scope != value:
			dict_scope = value
			_update_resource_name()
			notify_property_list_changed()

## 字典作用域来源（仅当 dict_scope == SCOPE 时使用）
var dict_scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		if dict_scope_source != value:
			dict_scope_source = value
			_update_resource_name()
			notify_property_list_changed()

## 自定义字典作用域 ID
var dict_custom_scope_id: String = "":
	set(value):
		if dict_custom_scope_id != value:
			dict_custom_scope_id = value
			_update_resource_name()

## 字典目标节点路径
var dict_target_node_path: NodePath = NodePath(""):
	set(value):
		if dict_target_node_path != value:
			dict_target_node_path = value
			_update_resource_name()

# 键名
var key_name: String = "":
	set(value):
		if key_name != value:
			key_name = value
			_update_resource_name()

# 键是否来自变量
var use_key_from_variable: bool = false:
	set(value):
		if use_key_from_variable != value:
			use_key_from_variable = value
			_update_resource_name()
			notify_property_list_changed()

# 键变量名
var key_from_variable: String = "":
	set(value):
		if key_from_variable != value:
			key_from_variable = value
			_update_resource_name()

# 键变量作用域
var key_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

# 要设置的值
@export var value_to_set: Variant:
	set(value):
		value_to_set = value
		_update_resource_name()

# 值是否来自变量
var use_value_from_variable: bool = false:
	set(value):
		if use_value_from_variable != value:
			use_value_from_variable = value
			_update_resource_name()
			notify_property_list_changed()

# 值变量名
var value_from_variable: String = "":
	set(value):
		if value_from_variable != value:
			value_from_variable = value
			_update_resource_name()

# 值变量作用域
var value_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_DICT_SET_NAME"
	metadata.category_key = "BRICKS_CATEGORY_DICTIONARIES"
	metadata.description_key = "BRICKS_INSTRUCTION_DICT_SET_DESC"
	metadata.keywords = ["字典", "设置", "键", "值", "dictionary", "set", "key", "value"]
	metadata.builtin_icon = "Dictionary"
	return metadata

## 设置指令元数据
func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	# Dictionary Configuration
	properties.append({
		name = "Dictionary Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "dict_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "dict_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if dict_scope == BaseVariable.VariableScope.SCOPE:
		properties.append({
			name = "dict_scope_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if dict_scope_source == ScopeSource.CUSTOM_ID:
			properties.append({
				name = "dict_custom_scope_id",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		elif dict_scope_source == ScopeSource.TARGET_NODE:
			properties.append({
				name = "dict_target_node_path",
				type = TYPE_NODE_PATH,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# Key Configuration
	properties.append({
		name = "Key Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "key_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "use_key_from_variable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if use_key_from_variable:
		properties.append({
			name = "key_from_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "key_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# Value Configuration
	properties.append({
		name = "Value Configuration",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "use_value_from_variable",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if use_value_from_variable:
		properties.append({
			name = "value_from_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		properties.append({
			name = "value_variable_scope",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Local,Scope,Global",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

## 验证属性可见性
func _validate_property(property: Dictionary) -> void:
	# 字典作用域相关
	if dict_scope != BaseVariable.VariableScope.SCOPE:
		if property.name in ["dict_scope_source", "dict_custom_scope_id", "dict_target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "dict_custom_scope_id" and dict_scope_source != ScopeSource.CUSTOM_ID:
			property.usage = PROPERTY_USAGE_NO_EDITOR
		if property.name == "dict_target_node_path" and dict_scope_source != ScopeSource.TARGET_NODE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 键配置相关
	if not use_key_from_variable:
		if property.name in ["key_from_variable", "key_variable_scope"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 值配置相关
	if not use_value_from_variable:
		if property.name in ["value_from_variable", "value_variable_scope"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	else:
		if property.name == "value_to_set":
			property.usage = PROPERTY_USAGE_NO_EDITOR

## 更新资源名称
func _update_resource_name():
	var dict_str = dict_variable if not dict_variable.is_empty() else BricksLocalization.translate("BRICKS_DICT_NO_DICT")
	var key_str = key_name if not key_name.is_empty() else BricksLocalization.translate("BRICKS_DICT_KEY_UNSET")
	var value_str = str(value_to_set)
	if value_str.length() > 15:
		value_str = value_str.substr(0, 12) + "..."

	resource_name = "Dict Set: %s[\"%s\"] = %s" % [dict_str, key_str, value_str]

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	_log_debug_localized("BRICKS_LOG_INSTRUCTION_START", {"instruction": "DictSetKeyValue"})

	# 验证字典变量名
	if dict_variable.is_empty():
		_log_error_localized("BRICKS_ERROR_DICT_VARIABLE_EMPTY", {})
		set_error_localized("BRICKS_ERROR_DICT_VARIABLE_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取键名
	var actual_key: Variant
	if use_key_from_variable:
		if key_from_variable.is_empty():
			_log_error_localized("BRICKS_ERROR_DICT_KEY_EMPTY", {})
			set_error_localized("BRICKS_ERROR_DICT_KEY_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
		actual_key = VariableOperations.get_variable(context, key_from_variable, key_variable_scope, null)
	else:
		actual_key = key_name

	if actual_key == null:
		_log_error_localized("BRICKS_ERROR_DICT_KEY_EMPTY", {})
		set_error_localized("BRICKS_ERROR_DICT_KEY_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
		finished.emit()
		return

	# 获取值
	var actual_value: Variant
	if use_value_from_variable:
		if value_from_variable.is_empty():
			actual_value = null
		else:
			actual_value = VariableOperations.get_variable(context, value_from_variable, value_variable_scope, null)
	else:
		actual_value = value_to_set

	# 获取字典
	var target_dict: Dictionary = _get_or_create_dict(context)

	if target_dict == null:
		_log_error_localized("BRICKS_ERROR_DICT_VARIABLE_NOT_FOUND", {"name": dict_variable})
		set_error_localized("BRICKS_ERROR_DICT_VARIABLE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"name": dict_variable})
		finished.emit()
		return

	# 设置键值
	target_dict[actual_key] = actual_value

	_log_info_localized("BRICKS_LOG_DICT_SET", {
		"dict": dict_variable,
		"key": str(actual_key),
		"value": str(actual_value)
	})

	# 通知变量变化
	_notify_dict_changed(context)

	_on_execution_completed()

## 获取或创建字典
func _get_or_create_dict(context: ExecutionContext) -> Variant:
	var dict_value: Variant = null

	match dict_scope:
		BaseVariable.VariableScope.LOCAL:
			if VariableOperations.has_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL):
				dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL, null)
			else:
				dict_value = {}
				VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL, dict_value)
				return dict_value

		BaseVariable.VariableScope.SCOPE:
			if dict_scope_source == ScopeSource.NEAREST:
				dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.SCOPE, null)
				if dict_value == null:
					dict_value = {}
					VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.SCOPE, dict_value)
					return dict_value
			else:
				var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
				var scope_container = VariableScopeUtils.get_scope_container_by_source(
					context,
					utils_scope_source,
					dict_custom_scope_id,
					dict_target_node_path
				)
				if scope_container == null:
					return null
				if scope_container.has_variable(dict_variable):
					dict_value = scope_container.get_variable(dict_variable, null)
				else:
					dict_value = {}
					scope_container.set_variable(dict_variable, dict_value)
					return dict_value

		BaseVariable.VariableScope.GLOBAL:
			dict_value = VariableOperations.get_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, null)
			if dict_value == null:
				dict_value = {}
				VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, dict_value)
				return dict_value

	if dict_value is Dictionary:
		return dict_value
	else:
		_log_debug("变量 '%s' 不是字典类型 (类型: %s)，创建新字典" % [dict_variable, typeof(dict_value)])
		var new_dict: Dictionary = {}
		match dict_scope:
			BaseVariable.VariableScope.LOCAL:
				VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.LOCAL, new_dict)
			BaseVariable.VariableScope.SCOPE:
				if dict_scope_source == ScopeSource.NEAREST:
					VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.SCOPE, new_dict)
				else:
					var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
					var scope_container = VariableScopeUtils.get_scope_container_by_source(
						context,
						utils_scope_source,
						dict_custom_scope_id,
						dict_target_node_path
					)
					if scope_container:
						scope_container.set_variable(dict_variable, new_dict)
			BaseVariable.VariableScope.GLOBAL:
				VariableOperations.set_variable(context, dict_variable, BaseVariable.VariableScope.GLOBAL, new_dict)
		return new_dict

## 通知字典变化
func _notify_dict_changed(context: ExecutionContext) -> void:
	if dict_scope == BaseVariable.VariableScope.GLOBAL:
		var manager = GlobalVariableManager.get_instance()
		if manager:
			var variable = manager.get_variable(dict_variable)
			if variable and variable.persistent:
				manager.notify_variable_content_changed(dict_variable)
	elif dict_scope == BaseVariable.VariableScope.SCOPE:
		if dict_scope_source != ScopeSource.NEAREST:
			var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
			var scope_container = VariableScopeUtils.get_scope_container_by_source(
				context,
				utils_scope_source,
				dict_custom_scope_id,
				dict_target_node_path
			)
			if scope_container:
				scope_container.notify_property_list_changed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if dict_variable.is_empty():
		errors.append(BricksLocalization.translate("BRICKS_ERROR_DICT_VARIABLE_EMPTY"))

	if dict_scope == BaseVariable.VariableScope.SCOPE:
		var utils_scope_source = dict_scope_source as VariableScopeUtils.ScopeSource
		errors.append_array(VariableScopeUtils.validate_scope_source_params(
			utils_scope_source,
			dict_custom_scope_id,
			dict_target_node_path
		))

	return errors

## 获取指令描述
func get_description() -> String:
	var dict_str = dict_variable if not dict_variable.is_empty() else "NoDict"
	var key_str = key_name if not key_name.is_empty() else "NoKey"
	return "Dict Set: %s[\"%s\"] = %s" % [dict_str, key_str, str(value_to_set)]

## 重置指令状态
func reset():
	super.reset()
	_log_debug("DictSetKeyValue reset")
```

**Step 2: 运行 Godot 验证脚本**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`

Expected: 无错误

**Step 3: Commit**

```bash
git add addons/bricks/instructions/dictionaries/dict_set_key_value.gd
git commit -m "feat(bricks): add DictSetKeyValue instruction for dictionary operations

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 4: 实现 DictGetValue 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_get_value.gd`

**Step 1: 创建指令文件**

创建 `dict_get_value.gd`，参考 `array_get.gd` 模式：
- 获取字典中指定键的值
- 支持默认值（键不存在时返回）
- 将结果存储到目标变量

**Step 2: 实现核心逻辑**

```gdscript
# 核心执行逻辑
func execute(context: ExecutionContext):
    _start_execution(context)

    # 获取字典
    var target_dict: Dictionary = _get_dict_variable(context)
    if target_dict == null:
        _log_error_localized("BRICKS_ERROR_DICT_VARIABLE_NOT_FOUND", {"name": dict_variable})
        finished.emit()
        return

    # 获取键
    var actual_key = _get_key(context)

    # 获取值（支持默认值）
    var result: Variant
    if target_dict.has(actual_key):
        result = target_dict[actual_key]
    else:
        result = default_value

    # 存储到目标变量
    _set_target_variable(context, result)

    _on_execution_completed()
```

**Step 3: Commit**

```bash
git add addons/bricks/instructions/dictionaries/dict_get_value.gd
git commit -m "feat(bricks): add DictGetValue instruction

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Task 5: 实现 DictRemoveKey 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_remove_key.gd`

**Step 1: 创建指令文件**

参考 `DictSetKeyValue` 结构，实现：
- 从字典中移除指定键
- 如果键不存在，记录警告但不报错

**Step 2: 核心逻辑**

```gdscript
func execute(context: ExecutionContext):
    # ... 验证代码 ...

    if target_dict.has(actual_key):
        target_dict.erase(actual_key)
        _log_info_localized("BRICKS_LOG_DICT_REMOVE", {"dict": dict_variable, "key": str(actual_key)})
    else:
        _log_warning("Key '%s' not found in dictionary '%s'" % [actual_key, dict_variable])

    _on_execution_completed()
```

**Step 3: Commit**

---

## Task 6: 实现 DictClear 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_clear.gd`

**Step 1: 创建指令文件**

实现清空字典功能：

```gdscript
func execute(context: ExecutionContext):
    # ... 验证代码 ...

    target_dict.clear()
    _log_info_localized("BRICKS_LOG_DICT_CLEARED", {"dict": dict_variable})

    _on_execution_completed()
```

**Step 2: Commit**

---

## Task 7: 实现 DictModifyNumber 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_modify_number.gd`

**Step 1: 创建指令文件**

添加操作符枚举：
```gdscript
enum ModifyOperation {
    ADD,    ## 加法 (+=)
    SUBTRACT ## 减法 (-=)
}
```

**Step 2: 核心逻辑**

```gdscript
func execute(context: ExecutionContext):
    # ... 获取字典和键 ...

    var current_value = target_dict.get(actual_key, 0)

    if not current_value is int and not current_value is float:
        _log_error_localized("BRICKS_ERROR_DICT_VALUE_NOT_NUMBER", {"key": str(actual_key)})
        finished.emit()
        return

    var result: float
    match operation:
        ModifyOperation.ADD:
            result = current_value + amount
        ModifyOperation.SUBTRACT:
            result = current_value - amount

    target_dict[actual_key] = result

    _log_info_localized("BRICKS_LOG_DICT_MODIFIED", {
        "dict": dict_variable,
        "key": str(actual_key),
        "op": "+" if operation == ModifyOperation.ADD else "-",
        "amount": str(amount),
        "result": str(result)
    })

    _on_execution_completed()
```

**Step 3: Commit**

---

## Task 8: 实现 DictMathOp 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_math_op.gd`

**Step 1: 创建指令文件**

添加数学操作枚举：
```gdscript
enum MathOperation {
    MULTIPLY,  ## 乘法 (*=)
    DIVIDE     ## 除法 (/=)
}
```

**Step 2: Commit**

---

## Task 9: 实现 DictToggleBoolean 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_toggle_boolean.gd`

**Step 1: 创建指令文件**

```gdscript
func execute(context: ExecutionContext):
    # ... 获取字典和键 ...

    var current_value = target_dict.get(actual_key, false)

    if not current_value is bool:
        _log_error_localized("BRICKS_ERROR_DICT_VALUE_NOT_BOOL", {"key": str(actual_key)})
        finished.emit()
        return

    target_dict[actual_key] = not current_value

    _on_execution_completed()
```

**Step 2: Commit**

---

## Task 10: 实现 DictMerge 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_merge.gd`

**Step 1: 创建指令文件**

添加合并选项：
```gdscript
var overwrite_existing: bool = true  ## 是否覆盖已存在的键
```

**Step 2: 核心逻辑**

```gdscript
func execute(context: ExecutionContext):
    var target_dict: Dictionary = _get_dict_variable(context, target_dict_variable, ...)
    var source_dict: Dictionary = _get_dict_variable(context, source_dict_variable, ...)

    if overwrite_existing:
        target_dict.merge(source_dict, true)
    else:
        for key in source_dict:
            if not target_dict.has(key):
                target_dict[key] = source_dict[key]

    _log_info_localized("BRICKS_LOG_DICT_MERGED", {
        "source": source_dict_variable,
        "target": target_dict_variable
    })

    _on_execution_completed()
```

**Step 3: Commit**

---

## Task 11: 实现 DictToJSON 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_to_json.gd`

**Step 1: 创建指令文件**

```gdscript
func execute(context: ExecutionContext):
    var target_dict: Dictionary = _get_dict_variable(context, ...)

    var json_string = JSON.stringify(target_dict, "  ")  # 格式化输出

    # 存储到目标变量
    _set_target_variable(context, json_string)

    _log_info_localized("BRICKS_LOG_DICT_TO_JSON", {"json": json_string.substr(0, 100)})

    _on_execution_completed()
```

**Step 2: Commit**

---

## Task 12: 实现 DictFromJSON 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_from_json.gd`

**Step 1: 创建指令文件**

```gdscript
func execute(context: ExecutionContext):
    var json_string: String = _get_json_string(context)

    var json = JSON.new()
    var error = json.parse(json_string)

    if error != OK:
        _log_error_localized("BRICKS_ERROR_DICT_JSON_PARSE_FAILED", {
            "error": json.get_error_message()
        })
        finished.emit()
        return

    var parsed_data = json.data

    if not parsed_data is Dictionary:
        _log_error("Parsed JSON is not a dictionary")
        finished.emit()
        return

    # 存储到目标字典变量
    _set_dict_variable(context, parsed_data)

    _log_info_localized("BRICKS_LOG_DICT_FROM_JSON", {})

    _on_execution_completed()
```

**Step 2: Commit**

---

## Task 13: 实现 DictSize 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_size.gd`

**Step 1: 创建指令文件**

```gdscript
func execute(context: ExecutionContext):
    var target_dict: Dictionary = _get_dict_variable(context, ...)

    var size = target_dict.size()

    # 存储到目标变量
    _set_target_variable(context, size)

    _on_execution_completed()
```

**Step 2: Commit**

---

## Task 14: 实现 DictGetKeys 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_get_keys.gd`

**Step 1: 创建指令文件**

```gdscript
func execute(context: ExecutionContext):
    var target_dict: Dictionary = _get_dict_variable(context, ...)

    var keys_array: Array = target_dict.keys()

    # 存储到目标变量
    _set_target_variable(context, keys_array)

    _on_execution_completed()
```

**Step 2: Commit**

---

## Task 15: 实现 DictGetValues 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_get_values.gd`

**Step 1: 创建指令文件**

```gdscript
func execute(context: ExecutionContext):
    var target_dict: Dictionary = _get_dict_variable(context, ...)

    var values_array: Array = target_dict.values()

    # 存储到目标变量
    _set_target_variable(context, values_array)

    _on_execution_completed()
```

**Step 2: Commit**

---

## Task 16: 实现 DictDuplicate 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_duplicate.gd`

**Step 1: 创建指令文件**

添加深拷贝选项：
```gdscript
var deep_copy: bool = true  ## 是否深拷贝（递归复制嵌套对象）
```

**Step 2: 核心逻辑**

```gdscript
func execute(context: ExecutionContext):
    var source_dict: Dictionary = _get_dict_variable(context, source_dict_variable, ...)

    var duplicated: Dictionary
    if deep_copy:
        duplicated = source_dict.duplicate(true)
    else:
        duplicated = source_dict.duplicate(false)

    # 存储到目标变量
    _set_target_variable(context, duplicated, target_variable, target_scope)

    _log_info_localized("BRICKS_LOG_DICT_DUPLICATED", {
        "source": source_dict_variable,
        "target": target_variable
    })

    _on_execution_completed()
```

**Step 3: Commit**

---

## Task 17: 实现 DictGetByPath 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_get_by_path.gd`

**Step 1: 创建指令文件**

路径格式：`"player/stats/hp"` 表示 `dict["player"]["stats"]["hp"]`

```gdscript
var path: String = ""  ## 路径字符串，用 / 分隔
var path_separator: String = "/"  ## 路径分隔符

func execute(context: ExecutionContext):
    var target_dict: Dictionary = _get_dict_variable(context, ...)

    var segments = path.split(path_separator)
    var current: Variant = target_dict

    for segment in segments:
        if segment.is_empty():
            continue

        if current is Dictionary:
            if current.has(segment):
                current = current[segment]
            else:
                _log_error_localized("BRICKS_ERROR_DICT_PATH_INVALID", {"path": path})
                finished.emit()
                return
        else:
            _log_error_localized("BRICKS_ERROR_DICT_PATH_SEGMENT_NOT_DICT", {"segment": segment})
            finished.emit()
            return

    # 存储到目标变量
    _set_target_variable(context, current)

    _on_execution_completed()
```

**Step 2: Commit**

---

## Task 18: 实现 DictSetByPath 指令

**Files:**
- Create: `addons/bricks/instructions/dictionaries/dict_set_by_path.gd`

**Step 1: 创建指令文件**

```gdscript
func execute(context: ExecutionContext):
    var target_dict: Dictionary = _get_dict_variable(context, ...)

    var segments = path.split(path_separator)
    var current: Variant = target_dict

    # 导航到倒数第二层
    for i in range(segments.size() - 1):
        var segment = segments[i]
        if segment.is_empty():
            continue

        if current is Dictionary:
            if not current.has(segment):
                current[segment] = {}  # 创建中间层
            current = current[segment]
        else:
            _log_error_localized("BRICKS_ERROR_DICT_PATH_SEGMENT_NOT_DICT", {"segment": segment})
            finished.emit()
            return

    # 设置最后一层的值
    var last_key = segments[-1]
    current[last_key] = value_to_set

    _on_execution_completed()
```

**Step 2: Commit**

---

## Task 19: 实现 CheckDictContainsKey 条件

**Files:**
- Create: `addons/bricks/conditions/dictionaries/check_dict_contains_key.gd`

**Step 1: 创建条件文件**

参考 `check_array_contains.gd` 模式：

```gdscript
@tool
@icon("res://addons/bricks/icons/condition.svg")
class_name CheckDictContainsKey extends BaseCondition

## 检查字典是否包含指定的键

var dict_variable: String = ""
var dict_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
# ... 作用域配置 ...

var key_name: String = ""
var use_key_from_variable: bool = false
var key_from_variable: String = ""

func _evaluate_condition(context: ExecutionContext) -> bool:
    var target_dict: Dictionary = _get_dict_variable(context)

    if target_dict == null:
        _log_error("Dictionary not found")
        return false

    var actual_key = _get_key(context)

    return target_dict.has(actual_key)

static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name_key = "BRICKS_CONDITION_DICT_CONTAINS_KEY_NAME"
    metadata.category_key = "BRICKS_CATEGORY_DICTIONARIES"
    metadata.description_key = "BRICKS_CONDITION_DICT_CONTAINS_KEY_DESC"
    metadata.keywords = ["字典", "键", "存在", "dictionary", "key", "exists", "has"]
    metadata.builtin_icon = "Dictionary"
    return metadata
```

**Step 2: Commit**

---

## Task 20: 实现 CheckDictSize 条件

**Files:**
- Create: `addons/bricks/conditions/dictionaries/check_dict_size.gd`

**Step 1: 创建条件文件**

参考 `check_array_size.gd` 模式：

```gdscript
@tool
@icon("res://addons/bricks/icons/condition.svg")
class_name CheckDictSize extends BaseCondition

enum Comparison {
    EQUALS,
    NOT_EQUALS,
    GREATER_THAN,
    LESS_THAN,
    GREATER_OR_EQUAL,
    LESS_OR_EQUAL
}

var dict_variable: String = ""
var dict_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
# ... 作用域配置 ...

var comparison: Comparison = Comparison.EQUALS
@export var compare_value: int = 0

func _evaluate_condition(context: ExecutionContext) -> bool:
    var target_dict: Dictionary = _get_dict_variable(context)

    if target_dict == null:
        _log_error("Dictionary not found")
        return false

    var actual_size = target_dict.size()

    match comparison:
        Comparison.EQUALS:
            return actual_size == compare_value
        Comparison.NOT_EQUALS:
            return actual_size != compare_value
        Comparison.GREATER_THAN:
            return actual_size > compare_value
        Comparison.LESS_THAN:
            return actual_size < compare_value
        Comparison.GREATER_OR_EQUAL:
            return actual_size >= compare_value
        Comparison.LESS_OR_EQUAL:
            return actual_size <= compare_value

    return false

static func _get_condition_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name_key = "BRICKS_CONDITION_DICT_SIZE_NAME"
    metadata.category_key = "BRICKS_CATEGORY_DICTIONARIES"
    metadata.description_key = "BRICKS_CONDITION_DICT_SIZE_DESC"
    metadata.keywords = ["字典", "大小", "数量", "dictionary", "size", "count"]
    metadata.builtin_icon = "Dictionary"
    return metadata
```

**Step 2: Commit**

---

## Task 21: 验证所有指令

**Step 1: 运行 Godot 脚本验证**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`

Expected: 无编译错误

**Step 2: 检查所有文件**

Run: `ls -la addons/bricks/instructions/dictionaries/`

Expected: 16 个 .gd 文件

Run: `ls -la addons/bricks/conditions/dictionaries/`

Expected: 2 个 .gd 文件

---

## Task 22: 创建演示场景（可选）

**Files:**
- Create: `demos/bricks/dict/demo_dict_operations.tscn`
- Create: `demos/bricks/dict/demo_dict_operations.gd`

**Step 1: 创建演示场景**

创建一个简单的演示场景，展示字典操作的基本用法：
1. 创建一个空字典
2. 设置几个键值对（玩家属性）
3. 修改数值（金币增加）
4. 获取值并显示
5. 检查键是否存在
6. 遍历所有键

**Step 2: Commit**

---

## Task 23: 最终提交和总结

**Step 1: 检查所有修改**

```bash
git status
git diff --stat
```

**Step 2: 最终提交**

```bash
git add -A
git commit -m "feat(bricks): add comprehensive dictionary operations

- Add 16 dictionary instructions (set, get, remove, clear, modify, etc.)
- Add 2 dictionary conditions (contains key, size check)
- Support nested path access for complex data structures
- Add deep copy utility for safe data manipulation
- Add JSON serialization/deserialization support
- Add localization keys for all new components

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## 实现清单

### 指令（Instructions）

| # | 指令名 | 状态 | 文件 |
|---|--------|------|------|
| 1 | DictSetKeyValue | ⬜ | dict_set_key_value.gd |
| 2 | DictGetValue | ⬜ | dict_get_value.gd |
| 3 | DictRemoveKey | ⬜ | dict_remove_key.gd |
| 4 | DictClear | ⬜ | dict_clear.gd |
| 5 | DictModifyNumber | ⬜ | dict_modify_number.gd |
| 6 | DictMathOp | ⬜ | dict_math_op.gd |
| 7 | DictToggleBoolean | ⬜ | dict_toggle_boolean.gd |
| 8 | DictMerge | ⬜ | dict_merge.gd |
| 9 | DictToJSON | ⬜ | dict_to_json.gd |
| 10 | DictFromJSON | ⬜ | dict_from_json.gd |
| 11 | DictSize | ⬜ | dict_size.gd |
| 12 | DictGetKeys | ⬜ | dict_get_keys.gd |
| 13 | DictGetValues | ⬜ | dict_get_values.gd |
| 14 | DictDuplicate | ⬜ | dict_duplicate.gd |
| 15 | DictGetByPath | ⬜ | dict_get_by_path.gd |
| 16 | DictSetByPath | ⬜ | dict_set_by_path.gd |

### 条件（Conditions）

| # | 条件名 | 状态 | 文件 |
|---|--------|------|------|
| 1 | CheckDictContainsKey | ⬜ | check_dict_contains_key.gd |
| 2 | CheckDictSize | ⬜ | check_dict_size.gd |

---

## 注意事项

1. **代码风格**: 遵循 GDScript 2.0 规范，使用 TAB 缩进
2. **本地化**: 所有用户可见文本必须使用翻译键
3. **错误处理**: 使用 `BricksError` 系统统一处理错误
4. **变量作用域**: 正确实现 LOCAL/SCOPE/GLOBAL 三层作用域
5. **深拷贝**: 注意字典是引用类型，`DictDuplicate` 需要实现深拷贝
6. **类型检查**: 在操作前验证数据类型（如数值操作前检查是否为数字）

---

**创建日期:** 2026-03-09
**预计工作量:** 16 个指令 + 2 个条件 = 18 个组件
