# Bricks 本地化阶段3 - 运行时消息本地化实施计划

## 📋 文档信息

- **创建日期**: 2026-01-25
- **版本**: 1.0
- **状态**: 计划中
- **预计周期**: 3-4 天
- **目标**: 本地化所有运行时日志和错误消息

---

## 🎯 阶段目标

为 Bricks 可视化编程系统实现完整的运行时消息本地化，包括：
- 所有指令执行的日志消息
- 所有事件触发的日志消息
- 所有错误和警告消息
- 确保运行时输出支持中英双语

---

## 📊 现状分析

### 已有基础设施
- ✅ **BricksLocalization 系统**（阶段1完成）
  - 282 个翻译键
  - translate() 和 translate_format() 方法
  - 自动语言检测

- ✅ **BricksLogger 系统**
  - 日志级别枚举（DEBUG, INFO, WARNING, ERROR）
  - 日志格式化功能
  - 与 BricksError 集成

- ✅ **BricksError 系统**
  - 错误类型分类
  - 错误创建工厂方法
  - 自动日志记录

- ✅ **BaseInstruction 部分本地化**
  - `_start_execution()` 已支持本地化
  - `set_error()` 已支持翻译键自动翻译

### 待完成工作
- ⚠️ **BricksLogger 缺少本地化方法**
  - 需要添加 log_debug_localized() 等方法
  - 需要添加自动翻译键检测功能

- ⚠️ **BricksError 缺少本地化创建方法**
  - 需要添加 create_*_localized() 静态方法
  - 需要支持翻译键参数

- ⚠️ **指令类未完全使用本地化**
  - 11 个指令文件需要检查和更新
  - 确保所有日志和错误使用翻译键

- ⚠️ **事件类未使用本地化**
  - 5 个事件文件需要检查和更新
  - 需要添加本地化支持

### 文件清单

**指令文件（11个）**:
1. `print.gd` - 打印消息指令
2. `print_variable_value.gd` - 打印变量值指令
3. `set_variable.gd` - 设置变量指令
4. `set_int_variable.gd` - 设置整数变量指令
5. `create_variable.gd` - 创建变量指令
6. `wait.gd` - 等待指令
7. `count.gd` - 计数指令
8. `quit.gd` - 退出应用指令
9. `run_condition_check.gd` - 运行条件检查指令
10. `set_property_value.gd` - 设置属性值指令
11. `run_target_node_function.gd` - 运行节点函数指令

**事件文件（5个）**:
1. `event_on_ready.gd` - 场景就绪事件
2. `event_on_area_2d_enter.gd` - 2D区域进入事件
3. `event_on_input_key.gd` - 按键输入事件
4. `event_on_input_action.gd` - 动作输入事件
5. `event_on_target_signal_emit.gd` - 目标信号发出事件

---

## 📝 详细任务清单

### 任务 3.1: 扩展 BricksLogger 支持本地化

**目标**: 在 BricksLogger 中添加本地化日志方法

**文件**: `addons/bricks/core/logging/bricks_logger.gd`

**实施步骤**:

#### 步骤 3.1.1: 添加本地化日志方法

在现有 `log_debug()`, `log_info()`, `log_warning()`, `log_error()` 方法后添加对应的本地化版本：

```gdscript
## 本地化日志方法 - Debug
static func log_debug_localized(
	component_name: String,
	component_level: LogLevel,
	message_key: String,
	args: Dictionary = {},
	context: String = ""
):
	var localized_message = _translate_message(message_key, args)
	log_debug(component_name, component_level, localized_message, context)

## 本地化日志方法 - Info
static func log_info_localized(
	component_name: String,
	component_level: LogLevel,
	message_key: String,
	args: Dictionary = {},
	context: String = ""
):
	var localized_message = _translate_message(message_key, args)
	log_info(component_name, component_level, localized_message, context)

## 本地化日志方法 - Warning
static func log_warning_localized(
	component_name: String,
	component_level: LogLevel,
	message_key: String,
	args: Dictionary = {},
	context: String = ""
):
	var localized_message = _translate_message(message_key, args)
	log_warning(component_name, component_level, localized_message, context)

## 本地化日志方法 - Error
static func log_error_localized(
	component_name: String,
	component_level: LogLevel,
	message_key: String,
	args: Dictionary = {},
	context: String = ""
):
	var localized_message = _translate_message(message_key, args)
	log_error(component_name, component_level, localized_message, context)

## 翻译消息的辅助方法
static func _translate_message(message_key: String, args: Dictionary = {}) -> String:
	var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")

	if not BricksLocalization_class or not BricksLocalization_class.has_method("translate_format"):
		# 如果本地化系统不可用，返回原始键
		if args.is_empty():
			return message_key
		# 尝试手动替换参数
		var result = message_key
		for key in args:
			result = result.replace("{%s}" % key, str(args[key]))
		return result

	# 使用本地化系统翻译
	if args.is_empty():
		return BricksLocalization_class.translate(message_key)
	else:
		return BricksLocalization_class.translate_format(message_key, args)
```

#### 步骤 3.1.2: 添加类型注解

确保所有新增方法都有正确的类型注解：
- 所有参数使用类型注解
- 所有返回值使用 `-> void`

**验收标准**:
- ✅ 4 个本地化日志方法添加完成
- ✅ `_translate_message()` 辅助方法实现
- ✅ 所有方法有类型注解
- ✅ 向后兼容（原有方法不受影响）
- ✅ 本地化系统不可用时正确回退

**测试方法**:
创建测试脚本验证本地化日志输出：
```gdscript
func test_logger_localization():
	# 测试基本翻译
	BricksLogger.log_info_localized("TestComponent", BricksLogger.LogLevel.INFO, "BRICKS_LOG_EXECUTION_STARTED", {})

	# 测试参数化翻译
	BricksLogger.log_info_localized("TestComponent", BricksLogger.LogLevel.INFO, "BRICKS_ERROR_VAR_NOT_FOUND", {"name": "test_var"})

	# 验证输出包含翻译后的文本
```

---

### 任务 3.2: 扩展 BricksError 支持本地化

**目标**: 在 BricksError 中添加本地化错误创建方法

**文件**: `addons/bricks/core/logging/bricks_error.gd`

**实施步骤**:

#### 步骤 3.2.1: 添加本地化静态工厂方法

在现有 `create_validation_error()` 等方法后添加对应的本地化版本：

```gdscript
## 本地化错误创建方法 - Validation Error
static func create_validation_error_localized(
	component: String,
	message_key: String,
	args: Dictionary = {},
	context: Dictionary = {}
) -> BricksError:
	var localized_message = _translate_error_message(message_key, args)
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	return BricksError.new(ErrorType.VALIDATION_ERROR, component, localized_message, "VALIDATION_ERROR", error_context)

## 本地化错误创建方法 - Execution Error
static func create_execution_error_localized(
	component: String,
	message_key: String,
	args: Dictionary = {},
	context: Dictionary = {}
) -> BricksError:
	var localized_message = _translate_error_message(message_key, args)
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	return BricksError.new(ErrorType.EXECUTION_ERROR, component, localized_message, "EXECUTION_ERROR", error_context)

## 本地化错误创建方法 - Configuration Error
static func create_configuration_error_localized(
	component: String,
	message_key: String,
	args: Dictionary = {},
	context: Dictionary = {}
) -> BricksError:
	var localized_message = _translate_error_message(message_key, args)
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	return BricksError.new(ErrorType.CONFIGURATION_ERROR, component, localized_message, "CONFIGURATION_ERROR", error_context)

## 本地化错误创建方法 - Runtime Error
static func create_runtime_error_localized(
	component: String,
	message_key: String,
	args: Dictionary = {},
	context: Dictionary = {}
) -> BricksError:
	var localized_message = _translate_error_message(message_key, args)
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	return BricksError.new(ErrorType.RUNTIME_ERROR, component, localized_message, "RUNTIME_ERROR", error_context)

## 本地化错误创建方法 - Timeout Error
static func create_timeout_error_localized(
	component: String,
	message_key: String,
	args: Dictionary = {},
	context: Dictionary = {}
) -> BricksError:
	var localized_message = _translate_error_message(message_key, args)
	var error_context = context.duplicate()
	error_context["message_key"] = message_key
	error_context["message_args"] = args
	return BricksError.new(ErrorType.TIMEOUT_ERROR, component, localized_message, "TIMEOUT_ERROR", error_context)

## 翻译错误消息的辅助方法
static func _translate_error_message(message_key: String, args: Dictionary = {}) -> String:
	var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")

	if not BricksLocalization_class or not BricksLocalization_class.has_method("translate_format"):
		# 如果本地化系统不可用，返回原始键并手动替换参数
		var result = message_key
		for key in args:
			result = result.replace("{%s}" % key, str(args[key]))
		return result

	# 使用本地化系统翻译
	if args.is_empty():
		return BricksLocalization_class.translate(message_key)
	else:
		return BricksLocalization_class.translate_format(message_key, args)
```

#### 步骤 3.2.2: 修改 get_formatted_message() 支持本地化

更新 `get_formatted_message()` 方法，使其在错误上下文包含 `message_key` 时能够重新翻译：

```gdscript
func get_formatted_message() -> String:
	# 检查是否有翻译键信息
	if context.has("message_key"):
		var message_key = context["message_key"]
		var message_args = context.get("message_args", {})
		var localized_message = _translate_error_message(message_key, message_args)

		var context_str = "" if context.is_empty() else " | Context: %s" % str(context)
		return "[%s][%s] %s%s" % [ErrorType.keys()[error_type], component_name, localized_message, context_str]

	# 原有逻辑
	var context_str = "" if context.is_empty() else " | Context: %s" % str(context)
	return "[%s][%s] %s%s" % [ErrorType.keys()[error_type], component_name, message, context_str]

# 将 _translate_error_message 改为实例方法或保留为静态方法并在上方调用
static func _translate_error_message(message_key: String, args: Dictionary = {}) -> String:
	# ... (与上方定义相同)
```

**验收标准**:
- ✅ 5 个本地化错误创建方法添加完成
- ✅ `_translate_error_message()` 辅助方法实现
- ✅ `get_formatted_message()` 支持重新翻译
- ✅ 所有方法有类型注解
- ✅ 向后兼容（原有方法不受影响）

**测试方法**:
```gdscript
func test_error_localization():
	# 测试基本错误翻译
	var error1 = BricksError.create_validation_error_localized("TestComponent", "BRICKS_ERROR_VAR_NAME_EMPTY", {})
	print(error1.get_formatted_message())

	# 测试参数化错误翻译
	var error2 = BricksError.create_runtime_error_localized("TestComponent", "BRICKS_ERROR_VAR_NOT_FOUND", {"name": "test_var"})
	print(error2.get_formatted_message())

	# 验证输出包含翻译后的错误消息
```

---

### 任务 3.3: 更新 BaseInstruction 添加便捷方法

**目标**: 在 BaseInstruction 中添加便捷的本地化日志方法

**文件**: `addons/bricks/core/base/base_instruction.gd`

**实施步骤**:

#### 步骤 3.3.1: 添加便捷本地化日志方法

在现有 `_log_debug()`, `_log_info()`, `_log_warning()`, `_log_error()` 方法后添加对应的本地化版本：

```gdscript
## 记录本地化调试日志
##
## 参数：
## - message_key: String - 翻译键
## - args: Dictionary - 翻译参数（可选）
func _log_debug_localized(message_key: String, args: Dictionary = {}):
	BricksLogger.log_debug_localized("BaseInstruction", log_level, message_key, args, get_name())

## 记录本地化信息日志
##
## 参数：
## - message_key: String - 翻译键
## - args: Dictionary - 翻译参数（可选）
func _log_info_localized(message_key: String, args: Dictionary = {}):
	BricksLogger.log_info_localized("BaseInstruction", log_level, message_key, args, get_name())

## 记录本地化警告日志
##
## 参数：
## - message_key: String - 翻译键
## - args: Dictionary - 翻译参数（可选）
func _log_warning_localized(message_key: String, args: Dictionary = {}):
	BricksLogger.log_warning_localized("BaseInstruction", log_level, message_key, args, get_name())

## 记录本地化错误日志
##
## 参数：
## - message_key: String - 翻译键
## - args: Dictionary - 翻译参数（可选）
func _log_error_localized(message_key: String, args: Dictionary = {}):
	BricksLogger.log_error_localized("BaseInstruction", log_level, message_key, args, get_name())
```

#### 步骤 3.3.2: 添加便捷本地化错误创建方法

添加便捷方法来创建本地化的 BricksError：

```gdscript
## 创建本地化错误并设置
##
## 参数：
## - message_key: String - 翻译键
## - error_type: BricksError.ErrorType - 错误类型
## - args: Dictionary - 翻译参数（可选）
## - context: Dictionary - 错误上下文（可选）
func set_error_localized(message_key: String, error_type: BricksError.ErrorType = BricksError.ErrorType.EXECUTION_ERROR, args: Dictionary = {}, context: Dictionary = {}):
	var error_context = context.duplicate()
	error_context["instruction_name"] = get_name()
	error_context["instruction_description"] = get_description()

	_bricks_error = BricksError.create_with_context(error_type, "BaseInstruction", message_key, error_context)
	execution_status = ExecutionStatus.ERROR

	# 获取翻译后的消息用于显示
	var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")
	if BricksLocalization_class and BricksLocalization_class.has_method("translate_format"):
		error_message = BricksLocalization_class.translate_format(message_key, args)
	else:
		error_message = message_key

	_log_error_localized(message_key, args)
```

**验收标准**:
- ✅ 4 个便捷本地化日志方法添加完成
- ✅ `set_error_localized()` 方法实现
- ✅ 所有方法有类型注解
- ✅ 向后兼容（原有方法不受影响）

**测试方法**:
```gdscript
func test_instruction_localization():
	var instruction = MyInstruction.new()
	instruction.execute(context)

	# 验证日志输出使用翻译键
	# 验证错误消息使用翻译键
```

---

### 任务 3.4: 更新 BaseEvent 添加便捷方法

**目标**: 在 BaseEvent 中添加便捷的本地化日志方法

**文件**: `addons/bricks/core/base/base_event.gd`

**实施步骤**:

#### 步骤 3.4.1: 添加本地化支持

首先读取 `base_event.gd` 文件了解其结构，然后参考 BaseInstruction 的实现添加类似的方法：

```gdscript
# 假设 BaseEvent 有类似的日志方法，添加对应的本地化版本

## 记录本地化调试日志
func _log_debug_localized(message_key: String, args: Dictionary = {}):
	BricksLogger.log_debug_localized("BaseEvent", log_level, message_key, args, get_name())

## 记录本地化信息日志
func _log_info_localized(message_key: String, args: Dictionary = {}):
	BricksLogger.log_info_localized("BaseEvent", log_level, message_key, args, get_name())

## 记录本地化警告日志
func _log_warning_localized(message_key: String, args: Dictionary = {}):
	BricksLogger.log_warning_localized("BaseEvent", log_level, message_key, args, get_name())

## 记录本地化错误日志
func _log_error_localized(message_key: String, args: Dictionary = {}):
	BricksLogger.log_error_localized("BaseEvent", log_level, message_key, args, get_name())

## 创建本地化错误并设置
func set_error_localized(message_key: String, error_type: BricksError.ErrorType = BricksError.ErrorType.EXECUTION_ERROR, args: Dictionary = {}, context: Dictionary = {}):
	var error_context = context.duplicate()
	error_context["event_name"] = get_name()
	error_context["event_description"] = get_description()

	_bricks_error = BricksError.create_with_context(error_type, "BaseEvent", message_key, error_context)

	# 获取翻译后的消息
	var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")
	if BricksLocalization_class and BricksLocalization_class.has_method("translate_format"):
		error_message = BricksLocalization_class.translate_format(message_key, args)
	else:
		error_message = message_key

	_log_error_localized(message_key, args)
```

**验收标准**:
- ✅ 4 个便捷本地化日志方法添加完成
- ✅ `set_error_localized()` 方法实现
- ✅ 所有方法有类型注解
- ✅ 向后兼容

---

### 任务 3.5: 修改所有指令类使用本地化

**目标**: 更新所有 11 个指令文件使用本地化日志和错误

**文件列表**:
1. `addons/bricks/instructions/print.gd`
2. `addons/bricks/instructions/print_variable_value.gd`
3. `addons/bricks/instructions/set_variable.gd`
4. `addons/bricks/instructions/set_int_variable.gd`
5. `addons/bricks/instructions/create_variable.gd`
6. `addons/bricks/instructions/wait.gd`
7. `addons/bricks/instructions/count.gd`
8. `addons/bricks/instructions/quit.gd`
9. `addons/bricks/instructions/run_condition_check.gd`
10. `addons/bricks/instructions/set_property_value.gd`
11. `addons/bricks/instructions/run_target_node_function.gd`

**实施步骤**:

#### 步骤 3.5.1: 为每个指令创建翻译键

在 `translations.csv` 中添加每个指令的日志翻译键：

```csv
# Print Instruction
BRICKS_LOG_PRINT_MESSAGE,打印消息: {message},Printing message: {message}

# PrintVariableValue Instruction
BRICKS_LOG_PRINTING_VARIABLE,打印变量: {name},Printing variable: {name}
BRICKS_LOG_VARIABLE_VALUE,变量值: {name} = {value},Variable value: {name} = {value}

# SetVariable Instruction
BRICKS_LOG_SETTING_VARIABLE,设置变量: {name} = {value},Setting variable: {name} = {value}

# CreateVariable Instruction
BRICKS_LOG_CREATING_VARIABLE,创建变量: {name} = {value},Creating variable: {name} = {value}

# Wait Instruction
BRICKS_LOG_WAITING_START,开始等待 {duration} 秒,Starting to wait for {duration} seconds
BRICKS_LOG_WAITING_COMPLETE,等待完成,Waiting completed

# Count Instruction
BRICKS_LOG_COUNT_INCREMENT,计数增加: {count} -> {new_count},Count incremented: {count} -> {new_count}

# Quit Instruction
BRICKS_LOG_QUITTING,退出应用程序,Quitting application

# RunConditionCheck Instruction
BRICKS_LOG_EVALUATING_CONDITION,评估条件,Evaluating condition
BRICKS_LOG_CONDITION_RESULT,条件结果: {result},Condition result: {result}

# SetPropertyValue Instruction
BRICKS_LOG_SETTING_PROPERTY,设置属性: {node}.{property} = {value},Setting property: {node}.{property} = {value}

# RunTargetNodeFunction Instruction
BRICKS_LOG_CALLING_FUNCTION,调用函数: {node}.{function}(),Calling function: {node}.{function}()
```

#### 步骤 3.5.2: 更新指令文件使用本地化

为每个指令文件添加本地化支持。以 `print.gd` 为例：

**修改前**:
```gdscript
func execute(context: ExecutionContext):
	_start_execution(context)

	if message_template.is_empty():
		_log_error("消息内容不能为空")
		set_error("消息内容不能为空")
		finished.emit()
		return

	# ... 执行逻辑

	_log_info("打印消息: %s" % formatted_message)
	context.print_message(formatted_message)

	_on_execution_completed()
```

**修改后**:
```gdscript
func execute(context: ExecutionContext):
	_start_execution(context)

	if message_template.is_empty():
		_log_error_localized("BRICKS_ERROR_MESSAGE_EMPTY")
		set_error_localized("BRICKS_ERROR_MESSAGE_EMPTY", BricksError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return

	# ... 执行逻辑

	_log_info_localized("BRICKS_LOG_PRINT_MESSAGE", {"message": formatted_message})
	context.print_message(formatted_message)

	_on_execution_completed()
```

**修改模式**:
1. 查找所有硬编码的日志消息
2. 查找所有硬编码的错误消息
3. 替换为对应的翻译键
4. 使用 `_log_*_localized()` 方法
5. 使用 `set_error_localized()` 方法

**批量处理策略**:
- 先处理 3-4 个代表性指令（print, set_variable, create_variable, wait）
- 总结模式和问题
- 完成剩余 7-8 个指令

**验收标准**:
- ✅ 所有 11 个指令文件更新完成
- ✅ 所有硬编码日志消息替换为翻译键
- ✅ 所有硬编码错误消息替换为翻译键
- ✅ 所有指令在运行时输出正确的本地化消息
- ✅ 保持向后兼容性

**测试方法**:
```gdscript
# 为每个指令创建测试场景
func test_print_instruction_localization():
	var print_inst = Print.new()
	print_inst.message = "Hello"

	var context = ExecutionContext.new()
	print_inst.execute(context)

	# 验证日志输出包含翻译后的消息
	# 验证中英文切换正常工作
```

---

### 任务 3.6: 修改所有事件类使用本地化

**目标**: 更新所有 5 个事件文件使用本地化日志

**文件列表**:
1. `addons/bricks/events/event_on_ready.gd`
2. `addons/bricks/events/event_on_area_2d_enter.gd`
3. `addons/bricks/events/event_on_input_key.gd`
4. `addons/bricks/events/event_on_input_action.gd`
5. `addons/bricks/events/event_on_target_signal_emit.gd`

**实施步骤**:

#### 步骤 3.6.1: 为每个事件创建翻译键

在 `translations.csv` 中添加每个事件的日志翻译键：

```csv
# OnReady Event
BRICKS_LOG_EVENT_READY_TRIGGERED,场景就绪事件触发,Scene ready event triggered
BRICKS_LOG_EVENT_READY_DELAY,延迟 {delay} 秒后触发,Triggering after {delay} seconds delay

# OnArea2DEnter Event
BRICKS_LOG_EVENT_AREA_ENTERED,2D区域进入事件触发,Area2D entered event triggered
BRICKS_LOG_EVENT_AREA_ENTERED_BODY,物体进入区域: {body},Body entered area: {body}

# OnInputKey Event
BRICKS_LOG_EVENT_INPUT_KEY_TRIGGERED,按键输入事件触发: {key},Input key event triggered: {key}

# OnInputAction Event
BRICKS_LOG_EVENT_INPUT_ACTION_TRIGGERED,动作输入事件触发: {action},Input action event triggered: {action}

# OnTargetSignalEmit Event
BRICKS_LOG_EVENT_SIGNAL_EMITTED,信号发出事件触发: {signal},Signal emit event triggered: {signal}
BRICKS_LOG_EVENT_SIGNAL_SOURCE,信号源: {source},Signal source: {source}
```

#### 步骤 3.6.2: 更新事件文件使用本地化

参考指令的修改模式，为每个事件文件添加本地化支持。

以 `event_on_ready.gd` 为例：

**修改前**:
```gdscript
func _on_timer_timeout():
	if is_instance_valid(target_node):
		_log_info("场景就绪事件触发（延迟）")
		execute_actions(context)
```

**修改后**:
```gdscript
func _on_timer_timeout():
	if is_instance_valid(target_node):
		_log_info_localized("BRICKS_LOG_EVENT_READY_TRIGGERED")
		execute_actions(context)
```

**验收标准**:
- ✅ 所有 5 个事件文件更新完成
- ✅ 所有硬编码日志消息替换为翻译键
- ✅ 所有事件在运行时输出正确的本地化消息
- ✅ 保持向后兼容性

**测试方法**:
```gdscript
# 为每个事件创建测试场景
func test_on_ready_event_localization():
	var event = EventOnReady.new()
	event.delay = 1.0

	# 触发事件并验证日志输出
	# 验证中英文切换正常工作
```

---

## 📦 交付成果

### 代码文件

**核心扩展**:
1. `addons/bricks/core/logging/bricks_logger.gd` - 添加本地化日志方法
2. `addons/bricks/core/logging/bricks_error.gd` - 添加本地化错误创建方法
3. `addons/bricks/core/base/base_instruction.gd` - 添加便捷本地化方法
4. `addons/bricks/core/base/base_event.gd` - 添加便捷本地化方法

**指令文件（11个）**:
- 所有指令文件更新为使用本地化日志和错误

**事件文件（5个）**:
- 所有时间文件更新为使用本地化日志

**翻译数据**:
- `addons/bricks/localization/translations.csv` - 添加约 30-40 个新的翻译键

### 测试文件

5. `addons/bricks/tests/test_stage3_runtime_localization.gd` - 集成测试脚本
6. `addons/bricks/tests/test_stage3_runtime_localization.tscn` - 测试场景

### 文档

7. `addons/bricks/docs/stage3_runtime_localization_complete.md` - 完成报告
8. `addons/bricks/docs/runtime_localization_usage_guide.md` - 使用指南

---

## ✅ 验收标准

### 功能验收

- ✅ 所有指令执行的日志消息支持中英双语
- ✅ 所有事件触发的日志消息支持中英双语
- ✅ 所有错误和警告消息支持中英双语
- ✅ 运行时测试显示正确的语言
- ✅ 控制台输出正确的翻译文本
- ✅ 语言切换后输出立即更新

### 技术验收

- ✅ 代码规范符合项目标准
  - Tab 缩进
  - LF 行尾
  - 类型注解完整
  - 文件以换行符结尾

- ✅ 性能标准
  - 本地化开销 < 5%
  - 无明显性能退化

- ✅ 向后兼容
  - 旧的硬编码消息仍能工作
  - 本地化系统不可用时正确回退

### 测试验收

- ✅ 单元测试覆盖率 > 90%
- ✅ 集成测试通过率 100%
- ✅ 所有 11 个指令测试通过
- ✅ 所有 5 个事件测试通过
- ✅ 中英文切换测试通过

---

## 🧪 测试策略

### 单元测试

**BricksLogger 扩展测试**:
```gdscript
func test_logger_localized_methods():
	# 测试 log_debug_localized
	BricksLogger.log_debug_localized("Test", BricksLogger.LogLevel.DEBUG, "BRICKS_LOG_EXECUTION_STARTED", {})

	# 测试 log_info_localized with args
	BricksLogger.log_info_localized("Test", BricksLogger.LogLevel.INFO, "BRICKS_ERROR_VAR_NOT_FOUND", {"name": "test_var"})

	# 测试 log_warning_localized
	BricksLogger.log_warning_localized("Test", BricksLogger.LogLevel.WARNING, "BRICKS_ERROR_VAR_TYPE_MISMATCH", {"expected": "int", "actual": "string"})

	# 测试 log_error_localized
	BricksLogger.log_error_localized("Test", BricksLogger.LogLevel.ERROR, "BRICKS_ERROR_EXECUTION_FAILED", {"error": "test error"})
```

**BricksError 扩展测试**:
```gdscript
func test_error_localized_methods():
	# 测试所有 5 个本地化错误创建方法
	var error1 = BricksError.create_validation_error_localized("Test", "BRICKS_ERROR_VAR_NAME_EMPTY", {})
	var error2 = BricksError.create_execution_error_localized("Test", "BRICKS_ERROR_EXECUTION_FAILED", {"error": "test"})
	var error3 = BricksError.create_configuration_error_localized("Test", "BRICKS_ERROR_CONFIG_ERROR", {})
	var error4 = BricksError.create_runtime_error_localized("Test", "BRICKS_ERROR_RUNTIME_ERROR", {})
	var error5 = BricksError.create_timeout_error_localized("Test", "BRICKS_ERROR_TIMEOUT_ERROR", {})

	# 验证错误消息正确翻译
	assert(error1.message.contains("变量名称") or error1.message.contains("Variable name"))
```

### 集成测试

**指令本地化测试**:
```gdscript
func test_instruction_runtime_localization():
	# 测试每个指令的日志输出
	var instructions = [
		Print.new(),
		PrintVariableValue.new(),
		SetVariable.new(),
		# ... 其他指令
	]

	for instruction in instructions:
		var context = ExecutionContext.new()
		instruction.execute(context)

		# 验证日志包含翻译后的文本
		# 验证中英文切换正常
```

**事件本地化测试**:
```gdscript
func test_event_runtime_localization():
	# 测试每个事件的日志输出
	var events = [
		EventOnReady.new(),
		EventOnArea2DEnter.new(),
		# ... 其他事件
	]

	for event in events:
		# 触发事件
		# 验证日志包含翻译后的文本
```

### 语言切换测试

```gdscript
func test_language_switching():
	var BricksLocalization_class = load("res://addons/bricks/localization/bricks_localization.gd")

	# 切换到中文
	BricksLocalization_class.set_locale(BricksLocalization_class.Locale.ZH_CN)
	var instruction = Print.new()
	instruction.message = "Test"
	instruction.execute(context)
	# 验证日志输出中文

	# 切换到英文
	BricksLocalization_class.set_locale(BricksLocalization_class.Locale.EN_US)
	instruction.execute(context)
	# 验证日志输出英文
```

---

## 📈 进度跟踪

### 任务完成度

- [ ] 任务 3.1: 扩展 BricksLogger 支持本地化 (0/2 步骤)
- [ ] 任务 3.2: 扩展 BricksError 支持本地化 (0/2 步骤)
- [ ] 任务 3.3: 更新 BaseInstruction 添加便捷方法 (0/2 步骤)
- [ ] 任务 3.4: 更新 BaseEvent 添加便捷方法 (0/1 步骤)
- [ ] 任务 3.5: 修改所有指令类使用本地化 (0/2 步骤)
- [ ] 任务 3.6: 修改所有事件类使用本地化 (0/2 步骤)

### 文件修改统计

**核心文件**: 4 个
**指令文件**: 11 个
**事件文件**: 5 个
**翻译文件**: 1 个（添加 30-40 键）
**测试文件**: 2 个
**文档文件**: 2 个

**总计**: 23-25 个文件

---

## 🚀 执行顺序

### 第一阶段：基础设施（1天）
1. 任务 3.1: 扩展 BricksLogger
2. 任务 3.2: 扩展 BricksError
3. 任务 3.3: 更新 BaseInstruction
4. 任务 3.4: 更新 BaseEvent

### 第二阶段：指令本地化（1-1.5天）
5. 任务 3.5: 修改 11 个指令文件
   - 先完成 3-4 个代表性指令
   - 总结模式后完成剩余指令

### 第三阶段：事件本地化（0.5天）
6. 任务 3.6: 修改 5 个事件文件

### 第四阶段：测试和文档（1天）
7. 创建集成测试
8. 编写使用文档
9. 编写完成报告

---

## 🎯 成功标准

### 阶段完成条件

当满足以下所有条件时，阶段3视为完成：

1. ✅ 所有 6 个任务标记为完成
2. ✅ 所有 23-25 个文件修改完成
3. ✅ 所有测试通过（单元测试 + 集成测试）
4. ✅ 文档完整（使用指南 + 完成报告）
5. ✅ 代码审查通过（符合代码规范）
6. ✅ 性能测试通过（开销 < 5%）
7. ✅ 向后兼容性验证通过

### 质量标准

- **代码质量**: 所有修改符合项目代码规范
- **测试覆盖**: 单元测试覆盖率 > 90%，集成测试 100% 通过
- **性能**: 本地化开销 < 5%，无性能退化
- **文档**: 完整的使用指南和 API 文档
- **兼容性**: 向后兼容，本地化系统不可用时正确回退

---

## 📝 备注

### 关键注意事项

1. **向后兼容性**:
   - 所有新增方法必须是可选的
   - 旧的硬编码消息仍能正常工作
   - 本地化系统不可用时正确回退

2. **性能考虑**:
   - 使用缓存避免重复加载本地化类
   - 最小化运行时开销
   - 避免在热路径中频繁分配内存

3. **代码规范**:
   - 使用 Tab 缩进（Godot 标准）
   - 使用 LF 行尾
   - 所有方法添加类型注解
   - 文件以换行符结尾

4. **测试策略**:
   - 先完成基础设施并充分测试
   - 批量修改指令前先完成 3-4 个样本
   - 每个阶段完成后进行集成测试

### 风险和缓解

**风险1**: 大量文件修改可能引入错误
- **缓解**: 分阶段执行，每阶段完成后测试

**风险2**: 翻译键可能不完整
- **缓解**: 使用回退机制，确保原始键可用

**风险3**: 性能影响
- **缓解**: 使用缓存，避免重复加载，性能测试验证

---

**文档创建**: 2026-01-25
**预计开始日期**: 待定
**预计完成日期**: 开始后 3-4 天
**状态**: 📝 计划中
