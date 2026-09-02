# 自定义 Instruction 创建最佳实践指南

## 概述

本指南基于 Fuse Visual Programming 系统中的 Instruction 架构，提供了创建自定义 Instruction 类的完整最佳实践。通过遵循这些实践，您可以创建高效、可靠且易于维护的自定义指令。

## 目录

1. [Instruction 架构基础](#instruction-架构基础)
2. [核心方法实现](#核心方法实现)
3. [生命周期管理](#生命周期管理)
4. [错误处理和日志](#错误处理和日志)
5. [性能优化](#性能优化)
6. [常见实现模式](#常见实现模式)
7. [完整示例](#完整示例)
8. [测试和验证](#测试和验证)

---

## Instruction 架构基础

### BaseInstruction 核心职责

`BaseInstruction` 是所有指令类的基类，提供以下核心功能：

- **执行框架**：统一的指令执行流程和状态管理
- **信号系统**：`finished` 信号用于通知执行完成
- **生命周期管理**：`execute()` 和 `_cleanup_resources()` 方法管理指令生命周期
- **错误处理**：统一的 `FuseError` 错误处理机制（包括本地化错误）
- **元数据**：指令名称、分类和描述信息（通过 InstructionMetadata 类）
- **超时管理**：内置的超时检测和处理机制
- **执行状态管理**：完整的执行状态跟踪（ExecutionStatus 枚举）
- **完成时机控制**：支持两种完成信号发送时机（CompletionSignalTiming）
- **执行模式优化**：智能执行模式检测（ExecutionMode）
- **性能优化**：本地化类缓存提升性能约 70%

### 指令生命周期

```
创建 → _init() → _setup_metadata() → execute() → [执行逻辑] → finished.emit() → _cleanup_resources()
```

1. **创建阶段**：Instruction 资源被实例化
2. **初始化阶段**：`_init()` 和 `_setup_metadata()` 被调用，设置指令信息
3. **执行阶段**：`execute()` 被调用，执行具体逻辑
4. **完成阶段**：`finished` 信号被发出，资源被清理

### 执行状态管理（ExecutionStatus 枚举）

指令在执行过程中会经历以下状态：

- **PENDING**：等待执行（初始状态）
- **RUNNING**：正在执行
- **COMPLETED**：执行完成
- **CANCELLED**：已取消
- **ERROR**：执行出错

**状态转换规则：**
```
PENDING → RUNNING → COMPLETED
                ↘ ERROR
                ↘ CANCELLED
```

### 完成信号时机（CompletionSignalTiming 枚举）

支持两种完成信号发送时机：

- **ON_START**：在执行开始时发送完成信号（适用于立即完成的指令）
- **ON_FINISH**：在执行完成时发送完成信号（默认，适用于大多数指令）

### 执行模式（ExecutionMode 枚举）

智能执行模式优化：

- **AUTO_DETECT**：自动检测执行模式（推荐，默认）
- **FORCE_ASYNC**：强制异步执行
- **FORCE_SYNC**：强制同步执行

---

## 核心方法实现

### 1. 必须实现的抽象方法

#### _get_instruction_metadata() - 静态方法

设置指令的基本信息和元数据，使用静态方法模式：

```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name = "我的指令"
	metadata.description = "这是一个自定义指令"
	metadata.category = "自定义"
	metadata.version = "1.0"
	metadata.author = "开发者"
	metadata.keywords = ["关键词1", "关键词2"]
	return metadata
```

**InstructionMetadata 类属性：**
- `name`：指令的显示名称（必需）
- `description`：指令的详细描述（必需）
- `category`：指令的分类，用于在编辑器中组织（必需）
- `version`：指令版本（可选）
- `author`：作者信息（可选）
- `keywords`：关键词列表，用于搜索（可选）
- `icon`：指令图标（可选）

**重要说明：**
- 必须实现此静态方法，用于指令选择器和注册系统
- 必须设置 `name`、`description` 和 `category`
- 必须返回 metadata 对象
- 元数据会被缓存，避免重复创建

#### _setup_metadata()

设置指令的实例元数据（可选）：

```gdscript
func _setup_metadata():
	# 通常留空，因为元数据已在静态方法中设置
	pass
```

**说明：**
- 此方法仍然需要实现（因为是抽象方法），但通常只需留空
- 实际的元数据设置在静态方法 `_get_instruction_metadata()` 中完成

#### execute(context: ExecutionContext)

实现指令的核心逻辑：

```gdscript
func execute(context: ExecutionContext):
	# 强制性：必须调用此方法初始化执行状态
	_start_execution(context)
	
	# 验证参数
	if not _validate_parameters():
		set_error("参数验证失败", FuseError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return
	
	# 执行指令逻辑
	_execute_instruction_logic(context)
	
	# 标记完成
	_on_execution_completed()
```

**重要说明：**
- `_start_execution(context)` 调用是强制性的，必须作为 `execute()` 方法的第一个操作
- 此方法会设置执行状态为 RUNNING，记录开始时间，并设置超时计时器
- 省略此调用会导致指令状态管理异常

#### _update_resource_name()

更新指令在编辑器列表中显示的名称，让使用者能够直观地看到指令的作用与参数：

```gdscript
func _update_resource_name():
	resource_name = "指令类型: 参数值"
```

**重要说明：**
- 这是一个抽象方法，必须在子类中实现
- 只在属性的 setter 中调用此方法，确保参数变化时名称同步更新
- 无需在 `_init()` 或 `_setup_metadata()` 中调用，因为此方法仅与编辑器显示相关
- 名称应该简洁明了，包含最重要的参数信息
- 避免在名称中包含过多细节，保持可读性

**实现示例：**

```gdscript
# 在属性 setter 中调用
@export var message: String = "Hello":
	set(value):
		message = value
		_update_resource_name()

@export var wait_time: float = 1.0:
	set(value):
		wait_time = value
		_update_resource_name()

# 实现更新方法
func _update_resource_name():
	if wait_time > 0:
		resource_name = "等待 %.1f 秒: %s" % [wait_time, message]
	else:
		resource_name = "立即: %s" % message
```

### 2. 推荐重写的方法

#### get_description() -> String

提供指令的描述信息：

```gdscript
func get_description() -> String:
	return "执行 %s 操作，参数: %s" % [metadata.name, parameter]
```

#### validate() -> Array[String]

验证指令配置的有效性：

```gdscript
func validate() -> Array[String]:
	var errors: Array[String] = []
	
	# 调用基类验证
	errors.append_array(super.validate())
	
	# 添加自定义验证
	if required_parameter <= 0:
		errors.append("参数值必须大于0")
	
	return errors
```

#### _cleanup_resources()

清理指令执行过程中使用的资源：

```gdscript
func _cleanup_resources():
	super._cleanup_resources()
	
	# 清理计时器
	if _timer:
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null
	
	# 清理其他资源
	_custom_resources.clear()
```

#### cancel()

处理指令取消逻辑：

```gdscript
func cancel():
	# 停止进行中的操作
	if _timer:
		_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null
	
	# 调用基类取消方法
	super.cancel()
```

---

## 生命周期管理

### 资源管理最佳实践

#### 1. 执行状态管理

```gdscript
func execute(context: ExecutionContext):
	_start_execution(context)
	
	# 检查执行状态
	if execution_status != ExecutionStatus.RUNNING:
		_log_warning("指令不在运行状态，跳过执行")
		return
	
	# 执行逻辑
	_perform_instruction_logic()
```

#### 2. 异步操作管理

```gdscript
var _timer: SceneTreeTimer = null
var _async_operation: AsyncOperation = null

func execute(context: ExecutionContext):
	_start_execution(context)
	
	# 创建异步操作
	_timer = Engine.get_main_loop().create_timer(wait_time)
	_timer.timeout.connect(_on_operation_completed)

func _cleanup_resources():
	super._cleanup_resources()
	
	# 清理异步操作
	if _timer:
		if _timer.timeout.is_connected(_on_operation_completed):
			_timer.timeout.disconnect(_on_operation_completed)
		_timer = null
	
	if _async_operation:
		_async_operation.cancel()
		_async_operation = null
```

#### 3. 超时管理

```gdscript
func execute(context: ExecutionContext):
	# 设置超时时间
	set_timeout(30.0)  # 30秒超时
	
	_start_execution(context)
	# 执行逻辑...

func _on_timeout():
	_log_error("指令执行超时")
	set_error("指令执行超时", FuseError.ErrorType.TIMEOUT_ERROR)
	finished.emit()
```

---

## 错误处理和日志

### 1. 统一错误处理

```gdscript
func execute(context: ExecutionContext):
	_start_execution(context)
	
	# 参数验证
	if not _validate_parameters():
		set_error("参数验证失败", FuseError.ErrorType.VALIDATION_ERROR, {
			"parameter_name": parameter_name,
			"parameter_value": parameter_value
		})
		finished.emit()
		return
	
	# 执行逻辑
	var result = _perform_operation()
	if result.is_error():
		set_error("操作失败: %s" % result.get_error_message(), FuseError.ErrorType.EXECUTION_ERROR)
		finished.emit()
		return
	
	_on_execution_completed()
```

**错误处理最佳实践：**
- 直接使用 `set_error()` 方法，无需预先创建 FuseError 对象
- 提供有意义的错误消息，包含足够的上下文信息
- 使用适当的错误类型
- 提供错误上下文信息，便于调试
- 在设置错误后立即发出 `finished` 信号并返回

### 2. 本地化错误处理

支持本地化错误消息，便于多语言支持：

```gdscript
func execute(context: ExecutionContext):
	_start_execution(context)

	# 参数验证 - 使用本地化错误
	if not _validate_parameters():
		set_error_localized(
			"FUSE_ERROR_PARAMETER_VALIDATION_FAILED",
			FuseError.ErrorType.VALIDATION_ERROR,
			{"param_name": parameter_name}  # 翻译参数
		)
		finished.emit()
		return

	# 执行逻辑...
```

**错误类型（FuseError.ErrorType）：**

- **VALIDATION_ERROR**：参数验证错误
- **CONFIGURATION_ERROR**：配置错误
- **EXECUTION_ERROR**：执行错误（默认）
- **RUNTIME_ERROR**：运行时错误
- **TIMEOUT_ERROR**：超时错误
- **NOT_FOUND_ERROR**：资源或节点未找到错误
- **PERMISSION_ERROR**：权限错误
- **NETWORK_ERROR**：网络错误

**本地化错误的优势：**
- 支持多语言界面
- 集中管理错误消息
- 便于翻译和维护
- 用户体验更好

### 3. 分级日志记录

```gdscript
func execute(context: ExecutionContext):
	_log_debug("开始执行指令: %s" % metadata.name)
	
	# 执行逻辑
	_log_info("正在执行操作...")
	
	if condition_met:
		_log_debug("条件满足，继续执行")
	else:
		_log_warning("条件不满足，跳过操作")
		return
	
	_log_info("指令执行完成")
```

### 3. 上下文信息记录

```gdscript
func set_error(message: String, error_type: FuseError.ErrorType = FuseError.ErrorType.EXECUTION_ERROR, context: Dictionary = {}):
	var error_context = context.duplicate()
	error_context["instruction_name"] = metadata.name
	error_context["instruction_category"] = metadata.category
	error_context["execution_time"] = get_execution_time()
	
	super.set_error(message, error_type, error_context)
```

---

## 高级功能

### 1. 超时管理

BaseInstruction 提供了完整的超时管理功能，可以防止指令无限期执行：

#### 基本超时设置

```gdscript
func execute(context: ExecutionContext):
	# 设置超时时间（秒）
	set_timeout(30.0)  # 30秒超时
	
	_start_execution(context)
	
	# 执行可能耗时的操作...
```

#### 超时处理方法

```gdscript
# 检查是否启用了超时
func has_timeout() -> bool:
	return _timeout_duration > 0.0

# 获取当前超时设置
func get_timeout() -> float:
	return _timeout_duration

# 获取已经执行的时间
func get_execution_time() -> float:
	if execution_status == ExecutionStatus.RUNNING:
		return (Time.get_ticks_msec() / 1000.0) - _execution_start_time
	return 0.0
```

#### 自定义超时处理

```gdscript
# 重写超时处理方法（可选）
func _on_timeout():
	var elapsed_time = get_execution_time()
	var error_msg = "指令执行超时 (%.2f 秒 > %.2f 秒)" % [elapsed_time, _timeout_duration]
	
	# 提供详细的超时上下文
	var timeout_context = {
		"elapsed_time": elapsed_time,
		"timeout_duration": _timeout_duration,
		"instruction_type": get_class()
	}
	
	set_error(error_msg, FuseError.ErrorType.TIMEOUT_ERROR, timeout_context)
	finished.emit()
```

**超时管理最佳实践：**
- 为可能长时间运行的指令设置合理的超时时间
- 在指令描述中说明预期的执行时间
- 对于网络操作或文件 I/O，设置较长的超时时间
- 对于计算密集型操作，根据复杂度设置超时

### 2. 完成信号时机

BaseInstruction 支持两种完成信号发送时机，通过 `CompletionSignalTiming` 枚举控制：

#### ON_FINISH 模式（默认）

```gdscript
# 在指令执行完成时发送信号（默认行为）
func _init():
	completion_timing = CompletionSignalTiming.ON_FINISH

func execute(context: ExecutionContext):
	_start_execution(context)
	
	# 执行指令逻辑...
	
	# 在这里调用 _on_execution_completed() 会发送 finished 信号
	_on_execution_completed()
```

#### ON_START 模式

```gdscript
# 在指令开始执行时立即发送信号
func _init():
	completion_timing = CompletionSignalTiming.ON_START

func execute(context: ExecutionContext):
	# _start_execution() 会自动检测并发送 finished 信号
	_start_execution(context)
	
	# 执行指令逻辑...
	
	# 这里不需要调用 _on_execution_completed()，因为信号已经发送
```

#### 使用场景

**ON_FINISH 模式适用于：**
- 需要等待执行完成的指令
- 异步操作的指令
- 大多数标准指令

**ON_START 模式适用于：**
- 立即完成的指令
- 触发器类型的指令
- 只需要启动而不需要等待完成的操作

#### 动态设置完成时机

```gdscript
@export var immediate_completion: bool = false:
	set(value):
		immediate_completion = value
		completion_timing = CompletionSignalTiming.ON_FINISH if not immediate_completion else CompletionSignalTiming.ON_START

func execute(context: ExecutionContext):
	_start_execution(context)
	
	if immediate_completion:
		# ON_START 模式：信号已在 _start_execution() 中发送
		_log_info("指令已触发，无需等待完成")
	else:
		# ON_FINISH 模式：需要等待执行完成
		_perform_full_execution()
		_on_execution_completed()
```

### 3. 变量绑定声明（get_variable_modes）

内置指令普遍支持参数"直接值 / 变量"双轨（用户侧用法见[变量绑定使用指南](../guides/07-variable-binding-guide.md)）。自定义指令通过 `use_variable_for_xxx` 布尔开关 + `get_variable_modes()` 声明加入同一体系：

```gdscript
@export var use_variable_for_damage: bool = false:
    set(value):
        use_variable_for_damage = value
        notify_property_list_changed()

@export var damage_variable: String = ""      # 勾选后的变量来源
@export var damage_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

func get_variable_modes() -> Array[Dictionary]:
    var modes: Array[Dictionary] = []
    if use_variable_for_damage:
        modes.append({"name": "damage_variable", "mode": "read"})
    return modes
```

配套在 `_get_property_list()` 里按开关动态切换属性形态（未勾选显示直接值输入框，勾选显示变量名 + 作用域下拉），行为对齐内置指令。声明了变量模式的指令会被 preset AI 上下文的 schema 收录，AI 生成 preset 时能正确使用双轨参数。

---

## 性能优化

### 1. 条件检查优化

```gdscript
# 使用短路逻辑优化条件检查
func _should_execute(context: ExecutionContext) -> bool:
	# 先检查轻量级条件
	if not context or not _enabled:
		return false
	
	# 再检查重量级条件
	if not _check_expensive_condition(context):
		return false
	
	return true
```

### 2. 资源复用

```gdscript
# 缓存常用资源
var _cached_texture: Texture2D = null
var _cached_node: Node = null

func _get_resource():
	if not _cached_texture:
		_cached_texture = load("res://textures/icon.png")
	return _cached_texture
```

### 3. 批量操作

```gdscript
# 批量处理多个对象
func _process_multiple_objects(objects: Array[Node]) -> void:
	var valid_objects: Array[Node] = []
	
	# 先过滤，再处理
	for obj in objects:
		if _is_valid_object(obj):
			valid_objects.append(obj)
	
	# 批量执行操作
	for obj in valid_objects:
		_process_object(obj)
```

---

## 常见实现模式

### 1. 同步执行模式

基于 `PrintInstruction` 的实现模式：

```gdscript
@export var message: String = "":
	set(value):
		message = value
		_update_resource_name()

func execute(context: ExecutionContext):
	_start_execution(context)
	
	# 验证参数
	if message.is_empty():
		set_error("消息不能为空", FuseError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return
	
	# 执行同步操作
	print(message)
	if context:
		context.print_message(message)
	
	_on_execution_completed()

func _update_resource_name():
	resource_name = "Print: %s" % message
```

### 2. 异步执行模式

基于 `WaitInstruction` 的实现模式：

```gdscript
@export var wait_time: float = 1.0:
	set(value):
		wait_time = value
		_update_resource_name()

var _timer: SceneTreeTimer = null

func execute(context: ExecutionContext):
	_start_execution(context)
	
	# 验证参数
	if wait_time <= 0:
		set_error("等待时间必须大于0", FuseError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return
	
	# 创建异步操作
	var scene_tree = Engine.get_main_loop()
	if scene_tree:
		_timer = scene_tree.create_timer(wait_time)
		_timer.timeout.connect(_on_timer_timeout)
	else:
		set_error("无法获取场景树", FuseError.ErrorType.RUNTIME_ERROR)
		finished.emit()

func _on_timer_timeout():
	_timer = null
	_on_execution_completed()

func _cleanup_resources():
	super._cleanup_resources()
	if _timer:
		if _timer.timeout.is_connected(_on_timer_timeout):
			_timer.timeout.disconnect(_on_timer_timeout)
		_timer = null

func _update_resource_name():
	resource_name = "Wait: %.1f secs" % wait_time
```

### 3. 状态维护模式

基于 `CountInstruction` 的实现模式：

```gdscript
@export var initial_count: int = 0:
	set(value):
		initial_count = value
		current_count = value
		_update_resource_name()

@export var increment: int = 1:
	set(value):
		increment = value
		_update_resource_name()

var current_count: int = 0

func execute(context: ExecutionContext):
	_start_execution(context)
	
	# 更新状态
	current_count += increment
	
	# 输出结果
	var message = "计数: %d" % current_count
	print(message)
	if context:
		context.print_message(message)
	
	_on_execution_completed()

func reset():
	super.reset()
	current_count = initial_count

func _update_resource_name():
	resource_name = "Count: %d→%d (+%d)" % [initial_count, current_count, increment]
```

### 4. 动态资源名称更新模式

基于 `_update_resource_name()` 的实现模式，提供直观的编辑器体验：

```gdscript
# 多参数指令的资源名称更新
@export var target_node: NodePath = "":
	set(value):
		target_node = value
		_update_resource_name()

@export var operation_type: String = "move":
	set(value):
		operation_type = value
		_update_resource_name()

@export var duration: float = 1.0:
	set(value):
		duration = value
		_update_resource_name()

func _update_resource_name():
	var parts = []
	
	# 基础操作类型
	match operation_type:
		"move":
			parts.append("移动")
		"rotate":
			parts.append("旋转")
		"scale":
			parts.append("缩放")
		_:
			parts.append("操作")
	
	# 目标节点信息
	if not target_node.is_empty():
		parts.append(target_node.get_name(0))
	
	# 持续时间信息
	if duration > 0:
		parts.append("(%.1fs)" % duration)
	
	# 组合最终名称
	resource_name = " ".join(parts)

# 条件性资源名称更新
@export var condition_type: String = "always":
	set(value):
		condition_type = value
		_update_resource_name()

@export var threshold: float = 0.0:
	set(value):
		threshold = value
		_update_resource_name()

func _update_resource_name():
	var base_name = "条件检查"
	
	match condition_type:
		"always":
			resource_name = base_name + ": 始终"
		"threshold":
			if threshold > 0:
				resource_name = "%s: 阈值%.1f" % [base_name, threshold]
			else:
				resource_name = base_name + ": 阈值未设置"
		"custom":
			resource_name = base_name + ": 自定义条件"
		_:
			resource_name = base_name + ": 未知条件"
```

### 5. 条件化属性显示模式

基于 `_validate_property()` 的实现模式，提供动态的编辑器界面：

```gdscript
# 基础属性（始终显示）
@export var target_variable: String = ""
@export var scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

# 控制属性（带 setter，触发属性更新）
@export var set_with_another_variable: bool = false:
	set(value):
		if set_with_another_variable != value:
			set_with_another_variable = value
			_update_resource_name()
			notify_property_list_changed()  # 触发属性验证

# 条件属性（始终导出，但根据条件禁用）
@export var from_variable: String = ""
@export var from_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
@export var new_value: int = 0

# 使用 _validate_property() 实现条件化显示
func _validate_property(property: Dictionary) -> void:
	# 当 set_with_another_variable = false 时，禁用源变量属性
	if not set_with_another_variable:
		if property.name == "from_variable":
			property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
		elif property.name == "from_variable_scope":
			property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
	
	# 当 set_with_another_variable = true 时，禁用新值属性
	if set_with_another_variable:
		if property.name == "new_value":
			property.usage = property.usage | PROPERTY_USAGE_READ_ONLY

# 更新资源名称以反映当前配置
func _update_resource_name():
	if target_variable.is_empty():
		resource_name = "设置变量: 未指定"
		return
	
	var operation_desc = ""
	if set_with_another_variable:
		if from_variable.is_empty():
			operation_desc = "从[未指定]复制"
		else:
			operation_desc = "从[%s]复制" % from_variable
	else:
		operation_desc = "设置为%d" % new_value
	
	resource_name = "设置 %s.%s %s" % [scope, target_variable, operation_desc]
```

#### 条件化显示的优势

1. **更好的用户体验**：属性变灰而不是消失，用户能看到所有可用选项
2. **性能更优**：不需要重建整个属性列表，只验证需要验证的属性
3. **逻辑更清晰**：每个属性的条件判断独立，易于调试和维护
4. **符合标准实践**：使用 Godot 推荐的属性验证方法

#### 实现要点

1. **使用 @export 导出所有属性**：确保所有属性都能被编辑器识别
2. **关键属性添加 setter**：在 setter 中调用 `notify_property_list_changed()` 触发更新
3. **实现 _validate_property()**：根据条件动态设置属性的 `PROPERTY_USAGE_READ_ONLY` 标志
4. **更新资源名称**：在属性变化时更新 `resource_name` 以反映当前配置

#### 常用属性使用标志

```gdscript
# 禁用属性（变灰）
property.usage = property.usage | PROPERTY_USAGE_READ_ONLY

# 隐藏属性（完全不可见）
property.usage = property.usage | PROPERTY_USAGE_NO_EDITOR

# 只在编辑器中显示
property.usage = property.usage | PROPERTY_USAGE_EDITOR

# 标记为脚本变量
property.usage = property.usage | PROPERTY_USAGE_SCRIPT_VARIABLE
```

#### 复杂条件示例

```gdscript
func _validate_property(property: Dictionary) -> void:
	# 多条件判断
	var should_disable_advanced = not advanced_mode_enabled
	var should_hide_deprecated = not show_deprecated_features
	
	# 根据多个条件控制属性
	match property.name:
		"advanced_property":
			if should_disable_advanced:
				property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
		"deprecated_property":
			if should_hide_deprecated:
				property.usage = property.usage | PROPERTY_USAGE_NO_EDITOR
		"conditional_property":
			if not condition_a or not condition_b:
				property.usage = property.usage | PROPERTY_USAGE_READ_ONLY
```

---

## 完整示例

### 自定义指令示例：MoveNodeInstruction

```gdscript
@tool
extends BaseInstruction
class_name MoveNodeInstruction

## 目标节点路径
@export var target_node_path: NodePath:
	set(value):
		target_node_path = value
		_update_resource_name()

## 目标位置
@export var target_position: Vector2 = Vector2.ZERO:
	set(value):
		target_position = value
		_update_resource_name()

## 移动持续时间（秒）
@export var move_duration: float = 1.0:
	set(value):
		move_duration = value
		_update_resource_name()

## 是否使用相对移动
@export var relative_movement: bool = false:
	set(value):
		relative_movement = value
		_update_resource_name()

## 缓动类型
@export_enum("Linear", "EaseIn", "EaseOut", "EaseInOut") var ease_type: int = 0:
	set(value):
		ease_type = value
		_update_resource_name()

# 内部状态
var _target_node: Node = null
var _tween: Tween = null
var _initial_position: Vector2

# 更新资源名称
func _update_resource_name():
	var node_name = "未指定节点"
	if not target_node_path.is_empty():
		node_name = target_node_path.get_name(0)
	
	var move_type = relative_movement ? "相对移动" : "绝对移动"
	var ease_name = ["Linear", "EaseIn", "EaseOut", "EaseInOut"][ease_type]
	
	resource_name = "移动 %s %s (%.1fs, %s)" % [
		node_name,
		move_type,
		move_duration,
		ease_name
	]

# 设置指令元数据（静态方法）
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name = "移动节点"
	metadata.description = "将节点移动到指定位置"
	metadata.category = "节点操作"
	metadata.version = "1.0"
	metadata.author = "Fuse System"
	metadata.keywords = ["移动", "节点", "动画", "位置"]
	return metadata

# 设置指令元数据（实例方法，通常留空）
func _setup_metadata():
	pass

# 执行指令
func execute(context: ExecutionContext):
	# 强制性：必须首先调用此方法
	_start_execution(context)
	
	# 设置超时时间（动画操作可能需要较长时间）
	set_timeout(move_duration + 5.0)  # 动画时间 + 5秒缓冲
	
	# 验证参数
	var errors = validate()
	if not errors.is_empty():
		set_error("参数验证失败: " + ", ".join(errors), FuseError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return
	
	# 获取目标节点
	_target_node = context.get_node(target_node_path) if context else null
	if not _target_node:
		set_error("无法找到目标节点: %s" % target_node_path, FuseError.ErrorType.RUNTIME_ERROR)
		finished.emit()
		return
	
	# 验证节点类型
	if not _target_node is Node2D and not _target_node is Control:
		set_error("目标节点必须是 Node2D 或 Control 类型", FuseError.ErrorType.VALIDATION_ERROR)
		finished.emit()
		return
	
	# 记录初始位置
	_initial_position = _target_node.position
	
	# 计算目标位置
	var final_position = target_position
	if relative_movement:
		final_position = _initial_position + target_position
	
	# 输出执行信息
	var move_message = "开始移动 %s 从 %s 到 %s" % [_target_node.name, _initial_position, final_position]
	_log_info(move_message)
	if context:
		context.print_message(move_message)
	
	# 创建补间动画
	_create_move_tween(final_position)

# 创建移动补间
func _create_move_tween(target_pos: Vector2):
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		set_error("无法获取场景树", FuseError.ErrorType.RUNTIME_ERROR)
		finished.emit()
		return
	
	_tween = scene_tree.create_tween()
	_tween.set_parallel(false)
	
	# 设置缓动类型
	match ease_type:
		0: _tween.set_ease(Tween.EASE_IN_OUT)
		1: _tween.set_ease(Tween.EASE_IN)
		2: _tween.set_ease(Tween.EASE_OUT)
		3: _tween.set_ease(Tween.EASE_IN_OUT)
	
	# 设置过渡类型
	_tween.set_trans(Tween.TRANS_SINE)
	
	# 执行移动动画
	_tween.tween_property(_target_node, "position", target_pos, move_duration)
	_tween.tween_callback(_on_move_completed)

# 移动完成回调
func _on_move_completed():
	_log_info("节点移动完成: %s" % _target_node.name)
	_tween = null
	_on_execution_completed()

# 获取指令描述
func get_description() -> String:
	var move_type = relative_movement ? "相对移动" : "绝对移动"
	var node_name = target_node_path.get_name(0) if not target_node_path.is_empty() else "未指定节点"
	
	return "%s %s 到 %s，持续时间 %.1f 秒" % [
		move_type,
		node_name,
		str(target_position),
		move_duration
	]

# 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()
	
	if target_node_path.is_empty():
		errors.append("必须指定目标节点路径")
	
	if move_duration <= 0:
		errors.append("移动持续时间必须大于0")
	
	return errors

# 取消指令执行
func cancel():
	if _tween:
		_tween.kill()
		_tween = null
		_log_debug("移动动画已取消")
	
	super.cancel()

# 资源清理
func _cleanup_resources():
	super._cleanup_resources()
	
	if _tween:
		_tween.kill()
		_tween = null
	
	_target_node = null
	_log_debug("MoveNodeInstruction 资源清理完成")

# 重置指令状态
func reset():
	super.reset()
	_target_node = null
	_tween = null
	_log_debug("MoveNodeInstruction 状态已重置")

# 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("MoveNodeInstruction", log_level, message)

func _log_info(message: String):
	FuseLogger.log_info("MoveNodeInstruction", log_level, message)

func _log_warning(message: String):
	FuseLogger.log_warning("MoveNodeInstruction", log_level, message)

func _log_error(message: String):
	FuseLogger.log_error("MoveNodeInstruction", log_level, message)
```

---

## 测试和验证

### 1. 单元测试模式

```gdscript
# 测试指令初始化
func test_instruction_initialization():
	var instruction = MoveNodeInstruction.new()
	var context = ExecutionContext.new()
	
	# 测试元数据设置
	assert(instruction.metadata.name == "移动节点")
	assert(instruction.metadata.category == "节点操作")
	
	# 测试参数设置
	instruction.target_node_path = "^/TestNode"
	instruction.target_position = Vector2(100, 100)
	instruction.move_duration = 2.0
	
	# 验证资源名称更新
	assert("TestNode" in instruction.resource_name)
	assert("100.0" in instruction.resource_name)

# 测试指令执行
func test_instruction_execution():
	var instruction = MoveNodeInstruction.new()
	var context = create_test_context()
	
	# 设置测试参数
	instruction.target_node_path = "^/TestNode"
	instruction.target_position = Vector2(50, 50)
	
	# 连接完成信号
	var completed = false
	instruction.finished.connect(func(): completed = true)
	
	# 执行指令
	instruction.execute(context)
	
	# 验证执行状态
	assert(instruction.is_running())
	
	# 等待完成（在实际测试中需要适当的等待机制）
	# await instruction.finished
	
	# 验证完成状态
	assert(completed)
	assert(instruction.is_completed())
```

### 2. 集成测试模式

```gdscript
# 在实际场景中测试指令
func test_instruction_in_scene():
	# 创建测试场景
	var scene = PackedScene.new()
	var test_node = Node2D.new()
	test_node.name = "TestNode"
	
	# 创建执行上下文
	var context = ExecutionContext.new()
	context.add_node(test_node)
	
	# 创建并执行指令
	var instruction = MoveNodeInstruction.new()
	instruction.target_node_path = "^/TestNode"
	instruction.target_position = Vector2(200, 200)
	
	# 执行并验证结果
	instruction.execute(context)
	
	# 验证节点位置变化
	assert(test_node.position.x == 200)
	assert(test_node.position.y == 200)
```

### 3. 性能测试

```gdscript
func test_instruction_performance():
	var instruction = MoveNodeInstruction.new()
	var context = create_test_context()
	var start_time = Time.get_ticks_msec()
	
	# 执行大量指令操作
	for i in range(1000):
		instruction.target_position = Vector2(i, i)
		instruction._update_resource_name()
	
	var end_time = Time.get_ticks_msec()
	print("指令资源名称更新时间: %d ms" % (end_time - start_time))
```

---

## 总结

创建自定义 Instruction 时遵循以下关键原则：

1. **完整生命周期管理**：正确实现 `execute()` 和 `_cleanup_resources()` 方法
2. **元数据管理**：使用 `_get_instruction_metadata()` 静态方法设置指令信息
3. **执行状态管理**：理解并正确使用 ExecutionStatus 枚举
4. **完成时机控制**：根据指令类型选择合适的 CompletionSignalTiming
5. **执行模式优化**：利用 ExecutionMode.AUTO_DETECT 自动检测最佳执行模式
6. **健壮的错误处理**：使用统一的错误处理机制（包括本地化错误）
7. **清晰的日志记录**：提供适当的调试信息（包括本地化日志）
8. **性能优化**：利用内置的本地化类缓存（性能提升约 70%）
9. **超时管理**：合理设置超时时间，防止指令无限期执行
10. **状态一致性**：确保指令状态在生命周期内保持一致
11. **资源清理**：及时释放不再需要的资源
12. **参数验证**：在 `validate()` 中验证配置参数
13. **直观的资源名称**：实现 `_update_resource_name()` 方法，让指令在编辑器中显示清晰的信息
14. **异步操作处理**：正确处理异步操作和资源清理
15. **强制初始化调用**：在 `execute()` 中首先调用 `_start_execution(context)`

通过遵循这些最佳实践，您可以创建高质量、高性能的自定义 Instruction 类，为 Fuse Visual Programming 系统提供强大而可靠的指令执行能力。

---
## 更新说明（2026-03）

- BaseInstruction 现在支持 `ExecutionMode` 枚举（AUTO_DETECT / FORCE_ASYNC / FORCE_SYNC）
- 新增 `get_default_runtime_state()` 方法用于 RuntimeInstance 模式
- 新增 `set_error()` / `set_error_localized()` 统一错误处理
- 新增 `set_timeout()` 超时管理
- 元数据通过 `InstructionMetadata` 类和 `_get_instruction_metadata()` 静态方法定义

---

**相关文档:**

- [自定义 Condition 创建最佳实践](custom_condition.md)
- [指令生成 skill](../../../../agent_skills/fuse-instruction-generator/SKILL.md)——指令组件规范的最终权威（模板、命名禁则与验证 gate），本指南是其架构原理的详述
- [变量绑定使用指南](../guides/07-variable-binding-guide.md)——双轨参数的用户侧用法
