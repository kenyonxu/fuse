# Bricks Phase 4 指令开发计划（数学和相机增强）

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现 10 个 Phase 4 指令，涵盖基础数学运算、相机控制完善、游戏流程控制、高级动画和场景管理增强，提升 Bricks 可视化编程系统的数学计算和相机控制能力。

**Architecture:** 基于 Godot 4.6 Resource 系统，每个指令继承 BaseInstruction，使用元数据驱动架构，支持本地化和编辑器集成。数学指令完善计算能力，相机指令配合 Phase 3D 的 Set Camera Zoom 形成完整相机系统。

**Tech Stack:** GDScript 2.0, Godot 4.6, Resource 系统, 本地化系统（CSV）, 测试框架, Camera2D/3D API, AnimationTree API

---

## 📊 总体概览

**指令总数:** 10 个指令

**分类分布:**
- Phase 4A: 基础数学运算（2 个）- Math Operation, Vector Operation
- Phase 4B: 相机控制完善（3 个）- Camera Follow, Camera Shake, Set Camera Limit
- Phase 4C: 游戏流程控制（2 个）- Pause Game, Resume Game
- Phase 4D: 高级动画控制（1 个）- Blend Animation
- Phase 4E: 场景管理增强（2 个）- Load Scene Background, Set Scene to Save

**前置条件:**
- ✅ Phase 0-3 已完成（42 个指令）
- ✅ 指令创建指南已建立
- ✅ 测试框架已就绪
- ✅ Phase 3C 数学指令基础（Random Number, Clamp Value, Lerp）

**预期时间:** 1-2 周

---

## 🎯 Phase 4 指令清单

### 按优先级排序

| 排名 | 指令 | 类别 | 复杂度 | 优先级 | 文件名 |
|------|------|------|--------|--------|--------|
| 1 | Math Operation | 数学运算 | 简单 | P1 | math_operation.gd |
| 2 | Vector Operation | 数学运算 | 中等 | P1 | vector_operation.gd |
| 3 | Pause Game | 时间控制 | 简单 | P1 | pause_game.gd |
| 4 | Resume Game | 时间控制 | 简单 | P1 | resume_game.gd |
| 5 | Camera Follow | 相机控制 | 中等 | P1 | camera_follow.gd |
| 6 | Set Camera Limit | 相机控制 | 简单 | P2 | set_camera_limit.gd |
| 7 | Camera Shake | 相机控制 | 中等 | P2 | camera_shake.gd |
| 8 | Blend Animation | 动画控制 | 中等 | P2 | blend_animation.gd |
| 9 | Load Scene Background | 场景管理 | 中等 | P2 | load_scene_background.gd |
| 10 | Set Scene to Save | 场景管理 | 简单 | P2 | set_scene_to_save.gd |

---

## 📋 执行前检查清单

### 开始前必须确认

- [ ] 阅读 [instruction_creation_guide.md](../../addons/bricks/docs/development/instruction_creation_guide.md)
- [ ] 查看现有指令示例（推荐：lerp.gd, set_camera_zoom.gd, play_animation.gd）
- [ ] 确认 Godot 版本：4.6
- [ ] 确认测试环境就绪
- [ ] 确认本地化系统工作正常

### 技术要点

**必须遵循的标准:**
1. **文件命名**: snake_case，无 `_instruction` 后缀（如 `math_operation.gd`）
2. **类命名**: PascalCase，无 `Instruction` 后缀（如 `class_name MathOperation`）
3. **图标**: 使用 `metadata.builtin_icon` 配置内置图标
4. **本地化**: 所有用户可见字符串必须使用 `_log_error_localized()` 等方法
5. **GDScript 2.0 语法**: 三元运算符使用 Python 风格 `value_if_true if condition else value_if_false`
6. **测试**: 每个指令需要测试脚本和测试场景（`.gd` + `.tscn`）

**Godot 4.6 API 注意事项:**
- Camera2D 使用 `position` 和 `zoom` 属性
- AnimationTree 需要使用 `set()` 方法设置 blend 参数
- SceneTree 通过 `Engine.get_main_loop()` 获取
- 物理暂停使用 `process_mode` 属性
- 后台加载使用 `ResourceLoader.load_threaded()`

---

## Phase 4A: 基础数学运算（2 个指令）

### 任务 1: Math Operation 指令

**功能:** 基本四则运算（加减乘除取模），支持整数和浮点数

**Files:**
- Create: `addons/bricks/instructions/math_operation.gd`
- Create: `addons/bricks/instructions/math_operation.gd.uid`
- Create: `addons/bricks/tests/instructions/test_math_operation.gd`
- Create: `addons/bricks/tests/instructions/test_math_operation.gd.uid`
- Create: `addons/bricks/tests/instructions/test_math_operation.tscn`
- Modify: `addons/bricks/localization/translations.csv`

#### Step 1: 添加本地化字符串

编辑 `addons/bricks/localization/translations.csv`，在文件末尾添加：

```csv
# Phase 4A - 数学运算
BRICKS_INSTRUCTION_MATH_OPERATION_NAME,数学运算,Math Operation
BRICKS_INSTRUCTION_MATH_OPERATION_DESC,执行基本四则运算（加减乘除取模）,Performs basic arithmetic operations (add, subtract, multiply, divide, modulo)
BRICKS_ERROR_OPERATION_TYPE_INVALID,无效的运算类型,Invalid operation type
BRICKS_ERROR_DIVISION_BY_ZERO,除零错误,Division by zero
BRICKS_ERROR_OPERAND_A_EMPTY,操作数 A 不能为空,Operand A cannot be empty
BRICKS_ERROR_OPERAND_B_EMPTY,操作数 B 不能为空,Operand B cannot be empty
```

#### Step 2: 创建指令文件

创建 `addons/bricks/instructions/math_operation.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/Math.png")
extends BaseInstruction
class_name MathOperation

## 基本四则运算

# 运算类型
enum Operation {
	ADD,
	SUBTRACT,
	MULTIPLY,
	DIVIDE,
	MODULO
}
var operation: Operation = Operation.ADD:
	set(value):
		operation = value
		_update_resource_name()

# 操作数 A 来源
enum OperandASource {
	DIRECT,
	VARIABLE
}
var operand_a_source: OperandASource = OperandASource.DIRECT:
	set(value_):
		operand_a_source = value_
		notify_property_list_changed()
		_update_resource_name()

# 操作数 A（直接值）
var operand_a: float = 0.0:
	set(value_):
		operand_a = value_
		_update_resource_name()

# 操作数 A 变量名
var operand_a_variable: String = "":
	set(value_):
		operand_a_variable = value_
		_update_resource_name()

# 操作数 B 来源
enum OperandBSource {
	DIRECT,
	VARIABLE
}
var operand_b_source: OperandBSource = OperandBSource.DIRECT:
	set(value_):
		operand_b_source = value_
		notify_property_list_changed()
		_update_resource_name()

# 操作数 B（直接值）
var operand_b: float = 0.0:
	set(value_):
		operand_b = value_
		_update_resource_name()

# 操作数 B 变量名
var operand_b_variable: String = "":
	set(value_):
		operand_b_variable = value_
		_update_resource_name()

# 保存结果到变量
var save_to_variable: String = "result":
	set(value_):
		save_to_variable = value_
		_update_resource_name()

# 是否使用全局变量
var is_global: bool = false:
	set(value_):
		is_global = value
		_update_resource_name()

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_MATH_OPERATION_NAME"
	metadata.category_key = "BRICKS_CATEGORY_MATH"
	metadata.description_key = "BRICKS_INSTRUCTION_MATH_OPERATION_DESC"
	metadata.keywords = ["math", "add", "subtract", "multiply", "divide", "modulo", "数学", "加", "减", "乘", "除", "取模"]
	metadata.builtin_icon = "Math"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Math",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "operation",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Add,Subtract,Multiply,Divide,Modulo",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 操作数 A
	properties.append({
		name = "operand_a_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if operand_a_source == OperandASource.VARIABLE:
		properties.append({
			name = "operand_a_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "operand_a",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 操作数 B
	properties.append({
		name = "operand_b_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if operand_b_source == OperandBSource.VARIABLE:
		properties.append({
			name = "operand_b_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		properties.append({
			name = "operand_b",
			type = TYPE_FLOAT,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	properties.append({
		name = "save_to_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "is_global",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	# 运算符号
	var op_symbol = ""
	match operation:
		Operation.ADD: op_symbol = "+"
		Operation.SUBTRACT: op_symbol = "-"
		Operation.MULTIPLY: op_symbol = "×"
		Operation.DIVIDE: op_symbol = "÷"
		Operation.MODULO: op_symbol = "%"

	parts.append("%s 运算" % op_symbol)

	# 操作数 A
	var a_str = ""
	if operand_a_source == OperandASource.VARIABLE:
		a_str = "变量 '%s'" % operand_a_variable if not operand_a_variable.is_empty() else "(未指定)"
	else:
		a_str = "%.2f" % operand_a
	parts.append(a_str)

	# 操作数 B
	var b_str = ""
	if operand_b_source == OperandBSource.VARIABLE:
		b_str = "变量 '%s'" % operand_b_variable if not operand_b_variable.is_empty() else "(未指定)"
	else:
		b_str = "%.2f" % operand_b
	parts.append(b_str)

	parts.append("→ %s" % save_to_variable)

	resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取操作数 A
	var a_value: float = 0.0
	if operand_a_source == OperandASource.VARIABLE:
		if operand_a_variable.is_empty():
			_log_error_localized("BRICKS_ERROR_OPERAND_A_EMPTY", {})
			set_error_localized("BRICKS_ERROR_OPERAND_A_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
		var a_var = context.get_variable(operand_a_variable)
		a_value = float(a_var) if a_var != null else 0.0
	else:
		a_value = operand_a

	# 获取操作数 B
	var b_value: float = 0.0
	if operand_b_source == OperandBSource.VARIABLE:
		if operand_b_variable.is_empty():
			_log_error_localized("BRICKS_ERROR_OPERAND_B_EMPTY", {})
			set_error_localized("BRICKS_ERROR_OPERAND_B_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
		var b_var = context.get_variable(operand_b_variable)
		b_value = float(b_var) if b_var != null else 0.0
	else:
		b_value = operand_b

	# 执行运算
	var result: float = 0.0
	match operation:
		Operation.ADD:
			result = a_value + b_value
		Operation.SUBTRACT:
			result = a_value - b_value
		Operation.MULTIPLY:
			result = a_value * b_value
		Operation.DIVIDE:
			if b_value == 0.0:
				_log_error_localized("BRICKS_ERROR_DIVISION_BY_ZERO", {})
				set_error_localized("BRICKS_ERROR_DIVISION_BY_ZERO", BricksError.ErrorType.RUNTIME_ERROR, {})
				finished.emit()
				return
			result = a_value / b_value
		Operation.MODULO:
			if b_value == 0.0:
				_log_error_localized("BRICKS_ERROR_DIVISION_BY_ZERO", {})
				set_error_localized("BRICKS_ERROR_DIVISION_BY_ZERO", BricksError.ErrorType.RUNTIME_ERROR, {})
				finished.emit()
				return
			result = fmod(a_value, b_value)
		_:
			_log_error_localized("BRICKS_ERROR_OPERATION_TYPE_INVALID", {})
			set_error_localized("BRICKS_ERROR_OPERATION_TYPE_INVALID", BricksError.ErrorType.RUNTIME_ERROR, {})
			finished.emit()
			return

	# 保存结果
	if is_global and context.global_variables:
		context.global_variables.set_variable(save_to_variable, result)
	else:
		context.set_variable(save_to_variable, result)

	_log_info("数学运算: %.2f %s %.2f = %.2f" % [a_value, op_symbol, b_value, result])
	_on_execution_completed()

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if save_to_variable.is_empty():
		errors.append("结果变量名不能为空")

	if operand_a_source == OperandASource.VARIABLE and operand_a_variable.is_empty():
		errors.append("操作数 A 变量名不能为空")

	if operand_b_source == OperandBSource.VARIABLE and operand_b_variable.is_empty():
		errors.append("操作数 B 变量名不能为空")

	return errors

## 获取指令描述
func get_description() -> String:
	var op_symbol = ""
	match operation:
		Operation.ADD: op_symbol = "+"
		Operation.SUBTRACT: op_symbol = "-"
		Operation.MULTIPLY: op_symbol = "×"
		Operation.DIVIDE: op_symbol = "÷"
		Operation.MODULO: op_symbol = "%"

	var a_str = operand_a_variable if operand_a_source == OperandASource.VARIABLE else "%.2f" % operand_a
	var b_str = operand_b_variable if operand_b_source == OperandBSource.VARIABLE else "%.2f" % operand_b

	var scope_str = "全局" if is_global else "本地"
	return "%s %s %s → %s（%s）" % [a_str, op_symbol, b_str, save_to_variable, scope_str]

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property == "operand_a_source" or property == "operand_b_source":
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false
```

#### Step 3: 创建测试场景和脚本

创建测试场景 `addons/bricks/tests/instructions/test_math_operation.tscn`：

```
[节点树]
Node (root)
  └─ test_math_operation.gd (脚本)
```

创建测试脚本 `addons/bricks/tests/instructions/test_math_operation.gd`：

```gdscript
extends Node

func _ready():
	print("=== 开始测试 Math Operation 指令 ===")
	await test_add_operation()
	await test_subtract_operation()
	await test_multiply_operation()
	await test_divide_operation()
	await test_modulo_operation()
	await test_division_by_zero()
	await test_variable_operands()
	print("=== Math Operation 指令测试完成 ===")

func test_add_operation():
	print("\n[Test 1] 测试加法运算")

	var instruction = MathOperation.new()
	var context = ExecutionContext.new()

	instruction.operation = MathOperation.Operation.ADD
	instruction.operand_a_source = MathOperation.OperandASource.DIRECT
	instruction.operand_a = 10.0
	instruction.operand_b_source = MathOperation.OperandBSource.DIRECT
	instruction.operand_b = 5.0
	instruction.save_to_variable = "sum_result"
	instruction.is_global = false

	instruction.execute(context)
	await context.finished

	var result = context.get_variable("sum_result")
	assert(result == 15.0, "10 + 5 应该等于 15")
	print("✓ 加法运算测试通过")

func test_subtract_operation():
	print("\n[Test 2] 测试减法运算")

	var instruction = MathOperation.new()
	var context = ExecutionContext.new()

	instruction.operation = MathOperation.Operation.SUBTRACT
	instruction.operand_a = 20.0
	instruction.operand_b = 8.0
	instruction.save_to_variable = "diff_result"

	instruction.execute(context)
	await context.finished

	var result = context.get_variable("diff_result")
	assert(result == 12.0, "20 - 8 应该等于 12")
	print("✓ 减法运算测试通过")

func test_multiply_operation():
	print("\n[Test 3] 测试乘法运算")

	var instruction = MathOperation.new()
	var context = ExecutionContext.new()

	instruction.operation = MathOperation.Operation.MULTIPLY
	instruction.operand_a = 6.0
	instruction.operand_b = 7.0
	instruction.save_to_variable = "product_result"

	instruction.execute(context)
	await context.finished

	var result = context.get_variable("product_result")
	assert(result == 42.0, "6 × 7 应该等于 42")
	print("✓ 乘法运算测试通过")

func test_divide_operation():
	print("\n[Test 4] 测试除法运算")

	var instruction = MathOperation.new()
	var context = ExecutionContext.new()

	instruction.operation = MathOperation.Operation.DIVIDE
	instruction.operand_a = 20.0
	instruction.operand_b = 4.0
	instruction.save_to_variable = "quotient_result"

	instruction.execute(context)
	await context.finished

	var result = context.get_variable("quotient_result")
	assert(result == 5.0, "20 ÷ 4 应该等于 5")
	print("✓ 除法运算测试通过")

func test_modulo_operation():
	print("\n[Test 5] 测试取模运算")

	var instruction = MathOperation.new()
	var context = ExecutionContext.new()

	instruction.operation = MathOperation.Operation.MODULO
	instruction.operand_a = 17.0
	instruction.operand_b = 5.0
	instruction.save_to_variable = "mod_result"

	instruction.execute(context)
	await context.finished

	var result = context.get_variable("mod_result")
	assert(result == 2.0, "17 % 5 应该等于 2")
	print("✓ 取模运算测试通过")

func test_division_by_zero():
	print("\n[Test 6] 测试除零错误")

	var instruction = MathOperation.new()
	var context = ExecutionContext.new()

	instruction.operation = MathOperation.Operation.DIVIDE
	instruction.operand_a = 10.0
	instruction.operand_b = 0.0
	instruction.save_to_variable = "result"

	instruction.execute(context)
	await context.finished

	assert(context.error != null, "应该产生除零错误")
	print("✓ 除零错误测试通过")

func test_variable_operands():
	print("\n[Test 7] 测试变量操作数")

	var instruction = MathOperation.new()
	var context = ExecutionContext.new()

	# 设置变量
	context.set_variable("var_a", 15.0)
	context.set_variable("var_b", 3.0)

	instruction.operation = MathOperation.Operation.MULTIPLY
	instruction.operand_a_source = MathOperation.OperandASource.VARIABLE
	instruction.operand_a_variable = "var_a"
	instruction.operand_b_source = MathOperation.OperandBSource.VARIABLE
	instruction.operand_b_variable = "var_b"
	instruction.save_to_variable = "var_result"

	instruction.execute(context)
	await context.finished

	var result = context.get_variable("var_result")
	assert(result == 45.0, "变量 15 × 3 应该等于 45")
	print("✓ 变量操作数测试通过")
```

#### Step 4: 验证和提交

验证测试通过后提交：

```bash
git add addons/bricks/instructions/math_operation.gd
git add addons/bricks/instructions/math_operation.gd.uid
git add addons/bricks/tests/instructions/test_math_operation.gd
git add addons/bricks/tests/instructions/test_math_operation.gd.uid
git add addons/bricks/tests/instructions/test_math_operation.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat(bricks): 添加 Math Operation 指令（Phase 4A-1/2）

- 执行基本四则运算（加减乘除取模）
- 支持直接值和变量两种操作数来源
- 完整的错误处理（除零检测）
- 完整测试覆盖（7 个测试用例）

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### 任务 2: Vector Operation 指令

**功能:** 向量运算（加减、归一化、长度、距离计算）

**Files:**
- Create: `addons/bricks/instructions/vector_operation.gd`
- Create: `addons/bricks/instructions/vector_operation.gd.uid`
- Create: `addons/bricks/tests/instructions/test_vector_operation.gd`
- Create: `addons/bricks/tests/instructions/test_vector_operation.gd.uid`
- Create: `addons/bricks/tests/instructions/test_vector_operation.tscn`
- Modify: `addons/bricks/localization/translations.csv`

#### Step 1: 添加本地化字符串

```csv
BRICKS_INSTRUCTION_VECTOR_OPERATION_NAME,向量运算,Vector Operation
BRICKS_INSTRUCTION_VECTOR_OPERATION_DESC,执行向量运算（加减、归一化、长度、距离）,Performs vector operations (add, subtract, normalize, length, distance)
BRICKS_ERROR_VECTOR_OPERATION_INVALID,无效的向量运算类型,Invalid vector operation type
BRICKS_ERROR_VECTOR_A_EMPTY,向量 A 不能为空,Vector A cannot be empty
BRICKS_ERROR_VECTOR_B_EMPTY,向量 B 不能为空（当前运算需要）,Vector B cannot be empty (required for current operation)
BRICKS_ERROR_VECTOR_A_INVALID,向量 A 格式无效,Vector A format is invalid
BRICKS_ERROR_VECTOR_B_INVALID,向量 B 格式无效,Vector B format is invalid
```

#### Step 2: 创建指令文件

创建 `addons/bricks/instructions/vector_operation.gd`：

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/Vector3.png")
extends BaseInstruction
class_name VectorOperation

## 向量运算

# 向量运算类型
enum VectorOp {
	VECTOR_ADD,
	VECTOR_SUBTRACT,
	NORMALIZE,
	LENGTH,
	DISTANCE
}
var vector_operation: VectorOp = VectorOp.VECTOR_ADD:
	set(value):
		vector_operation = value
		notify_property_list_changed()
		_update_resource_name()

# 向量类型
enum VectorType {
	VECTOR2,
	VECTOR3
}
var vector_type: VectorType = VectorType.VECTOR2:
	set(value):
		vector_type = value
		notify_property_list_changed()
		_update_resource_name()

# 向量 A 来源
enum VectorASource {
	DIRECT,
	VARIABLE
}
var vector_a_source: VectorASource = VectorASource.DIRECT:
	set(value_):
		vector_a_source = value_
		notify_property_list_changed()
		_update_resource_name()

# 向量 A（直接值）
var vector_a: Vector3 = Vector3.ZERO:
	set(value_):
		vector_a = value_
		_update_resource_name()

# 向量 A 变量名
var vector_a_variable: String = "":
	set(value_):
		vector_a_variable = value_
		_update_resource_name()

# 向量 B 来源
enum VectorBSource {
	DIRECT,
	VARIABLE
}
var vector_b_source: VectorBSource = VectorBSource.DIRECT:
	set(value_):
		vector_b_source = value_
		notify_property_list_changed()
		_update_resource_name()

# 向量 B（直接值）
var vector_b: Vector3 = Vector3.ZERO:
	set(value_):
		vector_b = value_
		_update_resource_name()

# 向量 B 变量名
var vector_b_variable: String = "":
	set(value_):
		vector_b_variable = value_
		_update_resource_name()

# 保存结果到变量
var save_to_variable: String = "vector_result":
	set(value_):
		save_to_variable = value_
		_update_resource_name()

# 是否使用全局变量
var is_global: bool = false:
	set(value_):
		is_global = value
		_update_resource_name()

## 判断当前运算是否需要向量 B
func _needs_vector_b() -> bool:
	return vector_operation in [VectorOp.VECTOR_ADD, VectorOp.VECTOR_SUBTRACT, VectorOp.DISTANCE]

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "BRICKS_INSTRUCTION_VECTOR_OPERATION_NAME"
	metadata.category_key = "BRICKS_CATEGORY_MATH"
	metadata.description_key = "BRICKS_INSTRUCTION_VECTOR_OPERATION_DESC"
	metadata.keywords = ["vector", "add", "subtract", "normalize", "length", "distance", "向量", "加", "减", "归一化", "长度", "距离"]
	metadata.builtin_icon = "Vector3"
	return metadata

func _setup_metadata():
	pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
	var properties := []

	properties.append({
		name = "Vector",
		type = TYPE_NIL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		name = "vector_operation",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Add,Subtract,Normalize,Length,Distance",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "vector_type",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Vector2,Vector3",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 向量 A
	properties.append({
		name = "vector_a_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Direct,Variable",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if vector_a_source == VectorASource.VARIABLE:
		properties.append({
			name = "vector_a_variable",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	else:
		if vector_type == VectorType.VECTOR2:
			properties.append({
				name = "vector_a",
				type = TYPE_VECTOR2,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		else:
			properties.append({
				name = "vector_a",
				type = TYPE_VECTOR3,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})

	# 向量 B（仅部分运算需要）
	if _needs_vector_b():
		properties.append({
			name = "vector_b_source",
			type = TYPE_INT,
			hint = PROPERTY_HINT_ENUM,
			hint_string = "Direct,Variable",
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

		if vector_b_source == VectorBSource.VARIABLE:
			properties.append({
				name = "vector_b_variable",
				type = TYPE_STRING,
				hint = PROPERTY_HINT_NONE,
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
			})
		else:
			if vector_type == VectorType.VECTOR2:
				properties.append({
					name = "vector_b",
					type = TYPE_VECTOR2,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})
			else:
				properties.append({
					name = "vector_b",
					type = TYPE_VECTOR3,
					hint = PROPERTY_HINT_NONE,
					usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
				})

	properties.append({
		name = "save_to_variable",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	properties.append({
		name = "is_global",
		type = TYPE_BOOL,
		hint = PROPERTY_HINT_NONE,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	return properties

## 更新资源名称
func _update_resource_name():
	var parts = []

	# 运算类型
	var op_name = ""
	match vector_operation:
		VectorOp.VECTOR_ADD: op_name = "向量加"
		VectorOp.VECTOR_SUBTRACT: op_name = "向量减"
		VectorOp.NORMALIZE: op_name = "归一化"
		VectorOp.LENGTH: op_name = "长度"
		VectorOp.DISTANCE: op_name = "距离"

	parts.append(op_name)

	# 向量 A
	var a_str = ""
	if vector_a_source == VectorASource.VARIABLE:
		a_str = "变量 '%s'" % vector_a_variable if not vector_a_variable.is_empty() else "(未指定)"
	else:
		a_str = str(vector_a) if vector_type == VectorType.VECTOR3 else str(Vector2(vector_a.x, vector_a.y))
	parts.append("(%s)" % a_str)

	# 向量 B
	if _needs_vector_b():
		var b_str = ""
		if vector_b_source == VectorBSource.VARIABLE:
			b_str = "变量 '%s'" % vector_b_variable if not vector_b_variable.is_empty() else "(未指定)"
		else:
			b_str = str(vector_b) if vector_type == VectorType.VECTOR3 else str(Vector2(vector_b.x, vector_b.y))
		parts.append(", %s" % b_str)

	parts.append("→ %s" % save_to_variable)

	resource_name = " ".join(parts)

## 获取向量值
func _get_vector_value(variant_value, from_variable: bool = false) -> Variant:
	if from_variable:
		if variant_value is Vector2 or variant_value is Vector3:
			return variant_value
		# 尝试从字符串解析
		if variant_value is String:
			var str_val = variant_value as String
			if str_val.begins_with("(") and str_val.ends_with(")"):
				var components = str_val.substr(1, str_val.length() - 2).split(",")
				if components.size() == 2:
					return Vector2(float(components[0]), float(components[1]))
				elif components.size() == 3:
					return Vector3(float(components[0]), float(components[1]), float(components[2]))
		return null
	return variant_value

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)

	# 获取向量 A
	var vec_a: Variant = null
	if vector_a_source == VectorASource.VARIABLE:
		if vector_a_variable.is_empty():
			_log_error_localized("BRICKS_ERROR_VECTOR_A_EMPTY", {})
			set_error_localized("BRICKS_ERROR_VECTOR_A_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
			finished.emit()
			return
		var a_var = context.get_variable(vector_a_variable)
		vec_a = _get_vector_value(a_var, true)
		if not vec_a:
			_log_error_localized("BRICKS_ERROR_VECTOR_A_INVALID", {})
			set_error_localized("BRICKS_ERROR_VECTOR_A_INVALID", BricksError.ErrorType.RUNTIME_ERROR, {})
			finished.emit()
			return
	else:
		if vector_type == VectorType.VECTOR2:
			vec_a = Vector2(vector_a.x, vector_a.y)
		else:
			vec_a = vector_a

	# 获取向量 B（如果需要）
	var vec_b: Variant = null
	if _needs_vector_b():
		if vector_b_source == VectorBSource.VARIABLE:
			if vector_b_variable.is_empty():
				_log_error_localized("BRICKS_ERROR_VECTOR_B_EMPTY", {})
				set_error_localized("BRICKS_ERROR_VECTOR_B_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
				finished.emit()
				return
			var b_var = context.get_variable(vector_b_variable)
			vec_b = _get_vector_value(b_var, true)
			if not vec_b:
				_log_error_localized("BRICKS_ERROR_VECTOR_B_INVALID", {})
				set_error_localized("BRICKS_ERROR_VECTOR_B_INVALID", BricksError.ErrorType.RUNTIME_ERROR, {})
				finished.emit()
				return
		else:
			if vector_type == VectorType.VECTOR2:
				vec_b = Vector2(vector_b.x, vector_b.y)
			else:
				vec_b = vector_b

	# 执行向量运算
	var result: Variant = null
	match vector_operation:
		VectorOp.VECTOR_ADD:
			result = vec_a + vec_b
		VectorOp.VECTOR_SUBTRACT:
			result = vec_a - vec_b
		VectorOp.NORMALIZE:
			if vec_a is Vector2:
				result = (vec_a as Vector2).normalized()
			else:
				result = (vec_a as Vector3).normalized()
		VectorOp.LENGTH:
			if vec_a is Vector2:
				result = (vec_a as Vector2).length()
			else:
				result = (vec_a as Vector3).length()
		VectorOp.DISTANCE:
			if vec_a is Vector2:
				result = (vec_a as Vector2).distance_to(vec_b)
			else:
				result = (vec_a as Vector3).distance_to(vec_b)
		_:
			_log_error_localized("BRICKS_ERROR_VECTOR_OPERATION_INVALID", {})
			set_error_localized("BRICKS_ERROR_VECTOR_OPERATION_INVALID", BricksError.ErrorType.RUNTIME_ERROR, {})
			finished.emit()
			return

	# 保存结果
	if is_global and context.global_variables:
		context.global_variables.set_variable(save_to_variable, result)
	else:
		context.set_variable(save_to_variable, result)

	_log_info("向量运算: %s = %s" % [_get_operation_name(), str(result)])
	_on_execution_completed()

## 获取运算名称
func _get_operation_name() -> String:
	match vector_operation:
		VectorOp.VECTOR_ADD: return "向量加"
		VectorOp.VECTOR_SUBTRACT: return "向量减"
		VectorOp.NORMALIZE: return "归一化"
		VectorOp.LENGTH: return "长度"
		VectorOp.DISTANCE: return "距离"
		_: return "未知运算"

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()

	if save_to_variable.is_empty():
		errors.append("结果变量名不能为空")

	if vector_a_source == VectorASource.VARIABLE and vector_a_variable.is_empty():
		errors.append("向量 A 变量名不能为空")

	if _needs_vector_b() and vector_b_source == VectorBSource.VARIABLE and vector_b_variable.is_empty():
		errors.append("向量 B 变量名不能为空")

	return errors

## 获取指令描述
func get_description() -> String:
	var op_name = _get_operation_name()
	var a_str = vector_a_variable if vector_a_source == VectorASource.VARIABLE else str(vector_a)
	var scope_str = "全局" if is_global else "本地"

	if _needs_vector_b():
		var b_str = vector_b_variable if vector_b_source == VectorBSource.VARIABLE else str(vector_b)
		return "%s(%s, %s) → %s（%s）" % [op_name, a_str, b_str, save_to_variable, scope_str]
	else:
		return "%s(%s) → %s（%s）" % [op_name, a_str, save_to_variable, scope_str]

## 动态属性设置
func _set(property: StringName, value: Variant) -> bool:
	if property in ["vector_operation", "vector_type", "vector_a_source", "vector_b_source"]:
		set(property, value)
		notify_property_list_changed()
		_update_resource_name()
		return true
	return false
```

#### Step 3: 创建测试场景和脚本

创建测试脚本 `addons/bricks/tests/instructions/test_vector_operation.gd`：

```gdscript
extends Node

func _ready():
	print("=== 开始测试 Vector Operation 指令 ===")
	await test_vector_add()
	await test_vector_subtract()
	await test_vector_normalize()
	await test_vector_length()
	await test_vector_distance()
	print("=== Vector Operation 指令测试完成 ===")

func test_vector_add():
	print("\n[Test 1] 测试向量加法")

	var instruction = VectorOperation.new()
	var context = ExecutionContext.new()

	instruction.vector_operation = VectorOperation.VectorOp.VECTOR_ADD
	instruction.vector_type = VectorOperation.VectorType.VECTOR2
	instruction.vector_a_source = VectorOperation.VectorASource.DIRECT
	instruction.vector_a = Vector2(10, 20)
	instruction.vector_b_source = VectorOperation.VectorBSource.DIRECT
	instruction.vector_b = Vector2(5, 15)
	instruction.save_to_variable = "sum_vector"

	instruction.execute(context)
	await context.finished

	var result = context.get_variable("sum_vector")
	assert(result is Vector2, "结果应该是 Vector2")
	assert(result.is_equal_approx(Vector2(15, 35)), "(10,20) + (5,15) 应该等于 (15,35)")
	print("✓ 向量加法测试通过")

func test_vector_subtract():
	print("\n[Test 2] 测试向量减法")

	var instruction = VectorOperation.new()
	var context = ExecutionContext.new()

	instruction.vector_operation = VectorOperation.VectorOp.VECTOR_SUBTRACT
	instruction.vector_type = VectorOperation.VectorType.VECTOR3
	instruction.vector_a = Vector3(10, 20, 30)
	instruction.vector_b = Vector3(3, 5, 7)
	instruction.save_to_variable = "diff_vector"

	instruction.execute(context)
	await context.finished

	var result = context.get_variable("diff_vector")
	assert(result is Vector3, "结果应该是 Vector3")
	assert(result.is_equal_approx(Vector3(7, 15, 23)), "(10,20,30) - (3,5,7) 应该等于 (7,15,23)")
	print("✓ 向量减法测试通过")

func test_vector_normalize():
	print("\n[Test 3] 测试向量归一化")

	var instruction = VectorOperation.new()
	var context = ExecutionContext.new()

	instruction.vector_operation = VectorOperation.VectorOp.NORMALIZE
	instruction.vector_type = VectorOperation.VectorType.VECTOR2
	instruction.vector_a = Vector2(30, 40)
	instruction.save_to_variable = "normalized_vector"

	instruction.execute(context)
	await context.finished

	var result = context.get_variable("normalized_vector")
	assert(result is Vector2, "结果应该是 Vector2")
	assert(result.is_normalized(), "结果应该是单位向量")
	print("✓ 向量归一化测试通过")

func test_vector_length():
	print("\n[Test 4] 测试向量长度")

	var instruction = VectorOperation.new()
	var context = ExecutionContext.new()

	instruction.vector_operation = VectorOperation.VectorOp.LENGTH
	instruction.vector_type = VectorOperation.VectorType.VECTOR2
	instruction.vector_a = Vector2(3, 4)
	instruction.save_to_variable = "vec_length"

	instruction.execute(context)
	await context.finished

	var result = context.get_variable("vec_length")
	assert(result is float, "结果应该是浮点数")
	assert(is_equal_approx(result, 5.0), "向量 (3,4) 的长度应该是 5")
	print("✓ 向量长度测试通过")

func test_vector_distance():
	print("\n[Test 5] 测试向量距离")

	var instruction = VectorOperation.new()
	var context = ExecutionContext.new()

	instruction.vector_operation = VectorOperation.VectorOp.DISTANCE
	instruction.vector_type = VectorOperation.VectorType.VECTOR2
	instruction.vector_a = Vector2(0, 0)
	instruction.vector_b = Vector2(3, 4)
	instruction.save_to_variable = "distance"

	instruction.execute(context)
	await context.finished

	var result = context.get_variable("distance")
	assert(result is float, "结果应该是浮点数")
	assert(is_equal_approx(result, 5.0), "向量 (0,0) 和 (3,4) 的距离应该是 5")
	print("✓ 向量距离测试通过")
```

#### Step 4: 验证和提交

```bash
git add addons/bricks/instructions/vector_operation.gd
git add addons/bricks/instructions/vector_operation.gd.uid
git add addons/bricks/tests/instructions/test_vector_operation.gd
git add addons/bricks/tests/instructions/test_vector_operation.gd.uid
git add addons/bricks/tests/instructions/test_vector_operation.tscn
git add addons/bricks/localization/translations.csv
git commit -m "feat(bricks): 添加 Vector Operation 指令（Phase 4A-2/2）

- 执行向量运算（加减、归一化、长度、距离）
- 支持 Vector2 和 Vector3 两种向量类型
- 支持直接值和变量两种向量来源
- 完整错误处理和测试覆盖
- Phase 4A 完成（基础数学运算）

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 4B: 相机控制完善（3 个指令）

### 任务 3-5: 相机控制指令概览

由于篇幅限制，相机控制指令（Camera Follow, Camera Shake, Set Camera Limit）的详细实现步骤遵循相同模式：

**每个指令的标准步骤:**
1. 添加本地化字符串到 `translations.csv`
2. 创建指令文件（参考 set_camera_zoom.gd 和 lerp.gd）
3. 创建测试场景和脚本
4. 验证功能
5. 提交

**关键文件路径:**
- `addons/bricks/instructions/camera_follow.gd`
- `addons/bricks/instructions/camera_shake.gd`
- `addons/bricks/instructions/set_camera_limit.gd`

**关键技术要点:**

**Camera Follow:**
- 使用 Camera2D/3D 的 `position` 属性
- 支持平滑跟随（使用 `lerp()` 插值）
- 可选的阻尼模式

**Camera Shake:**
- 可集成 JuicyMixer Shake Driver
- 或使用简单的随机偏移实现
- 支持持续时间和强度配置

**Set Camera Limit:**
- Camera2D 使用 `limit_*` 属性（limit_top, limit_bottom, limit_left, limit_right）
- 支持独立设置每个方向的限制

**测试文件路径:**
- `addons/bricks/tests/instructions/test_camera_follow.gd`
- `addons/bricks/tests/instructions/test_camera_shake.gd`
- `addons/bricks/tests/instructions/test_set_camera_limit.gd`

---

## Phase 4C-E: 其他指令概览

### 游戏流程控制（2 个）
- `pause_game.gd` - 使用 `Engine.time_scale = 0.0` 或 `process_mode`
- `resume_game.gd` - 恢复 `time_scale = 1.0` 或 `process_mode`

### 高级动画控制（1 个）
- `blend_animation.gd` - 使用 AnimationTree 的 `set()` 方法

### 场景管理增强（2 个）
- `load_scene_background.gd` - 使用 `ResourceLoader.load_threaded()`
- `set_scene_to_save.gd` - 标记场景存档状态

---

## 📊 完成检查清单 ✅

### Phase 4A: 基础数学运算 ✅ **已完成**
- [x] Math Operation
- [x] Vector Operation

### Phase 4C: 游戏流程控制 ✅ **已完成**
- [x] Pause Game
- [x] Resume Game

### Phase 4B: 相机控制完善 ✅ **已完成**
- [x] Camera Follow
- [x] Camera Shake
- [x] Set Camera Limit

### Phase 4D: 高级动画控制（待实现）
- [ ] Blend Animation

### Phase 4E: 场景管理增强（待实现）
- [ ] Load Scene Background
- [ ] Set Scene to Save

---

## 📚 参考文档

- [指令创建指南](../../addons/bricks/docs/development/instruction_creation_guide.md)
- [Phase 3 开发计划](./2026-01-27-bricks-phase3-instruction-plan.md)
- [Bricks 指令路线图](../../addons/bricks/docs/roadmap/2026-01-24-bricks-instruction-roadmap.md)

---

**文档维护:** Bricks 开发团队
**创建日期:** 2026-01-27
**状态:** 📝 计划中
**预计完成:** 1-2 周

---

## 下一步行动

1. ⏳ Phase 4A (数学运算) - 2 个指令 - 详细计划已完成
2. ⏳ Phase 4B (相机控制) - 3 个指令 - 需要补充详细步骤
3. ⏳ Phase 4C (流程控制) - 2 个指令 - 需要补充详细步骤
4. ⏳ Phase 4D (高级动画) - 1 个指令 - 需要补充详细步骤
5. ⏳ Phase 4E (场景管理) - 2 个指令 - 需要补充详细步骤
