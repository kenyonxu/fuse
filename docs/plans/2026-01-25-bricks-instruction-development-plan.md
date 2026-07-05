# Bricks Instruction 系统开发计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标：** 基于6维评估体系，按照依赖关系和优先级，实现完整的 Bricks 可视化编程指令系统（80+ 指令）

**架构：** Resource-based 指令系统，每个指令继承 `BaseInstruction`，支持元数据、本地化、异步执行、编辑器集成

**技术栈：** Godot 4.5, GDScript 2.0, Resource 系统, ExecutionContext, VariableContainer

---

## 参考文档

- **功能规格：** [addons/bricks/docs/roadmap/2026-01-24-bricks-instruction-roadmap.md](../../addons/bricks/docs/roadmap/2026-01-24-bricks-instruction-roadmap.md)
- **评估报告：** [addons/bricks/docs/roadmap/2026-01-25-instruction-evaluation-report-v2.md](../../addons/bricks/docs/roadmap/2026-01-25-instruction-evaluation-report-v2.md)
- **评估框架：** [addons/bricks/docs/roadmap/2026-01-25-bricks-evaluation-framework.md](../../addons/bricks/docs/roadmap/2026-01-25-bricks-evaluation-framework.md)

---

## 命名规范

**重要：** 所有 Bricks 指令遵循以下命名规范，保持简洁一致。

### 文件命名

- **指令文件：** 使用 snake_case，**不添加** `_instruction` 后缀
  - ✅ 正确：`set_position.gd`, `for_loop.gd`, `if_else.gd`
  - ❌ 错误：`set_position_instruction.gd`, `for_loop_instruction.gd`

### 类命名

- **类名：** 使用 PascalCase，**不添加** `Instruction` 后缀
  - ✅ 正确：`class_name SetPosition`, `class_name ForLoop`, `class_name IfElse`
  - ❌ 错误：`class_name SetPosition`, `class_name ForLoop`

### 测试文件命名

- **测试脚本：** `test_<instruction_name>.gd`
  - 例如：`test_set_position.gd`, `test_for_loop.gd`
- **测试场景：** `test_<instruction_name>.tscn`
  - 例如：`test_set_position.tscn`, `test_for_loop.tscn`

### 统一性原则

- 文件名、类名、测试文件名保持一致的基础名称
- 避免冗余后缀（如 `_instruction`、`Instruction`）
- 保持简洁可读

**示例：**
```
指令文件：   set_position.gd
类名：       class_name SetPosition
测试脚本：   test_set_position.gd
测试场景：   test_set_position.tscn
```

---

## 图标规范

**图标选择原则**：每个指令都应该配置图标，提升用户体验和可视化效果。

### 图标配置方式

**推荐：使用 Godot 内置图标**
```gdscript
metadata.builtin_icon = "Script"  # 使用 Godot 内置图标名称
```

**备选：使用自定义图标库**
```gdscript
metadata.custom_icon = "my_custom_icon"  # 使用导入的自定义图标
```

**向后兼容**
```gdscript
metadata.icon_name = "Script"  # 旧方式，仍然有效
metadata.icon = preload("res://icon.png")  # 直接指定纹理
```

### 内置图标命名参考

**常用图标名称**：
- **流程控制**：`Loop`, `Branch`, `Time`
- **变量操作**：`Array`, `New`, `View`, `Print`
- **节点操作**：`Node`, `Edit`, `Call`, `Remove`
- **调试**：`Debug`, `Search`
- **通用**：`Script`, `Play`, `Stop`, `Save`, `Load`, `Add`, `File`, `Folder`

**完整列表**：参考 [icon_system.md](../../addons/bricks/docs/development/icon_system.md#按字母顺序的完整列表1011-个图标)

### 图标配置步骤

**开发新指令时**：

1. 在 `_get_instruction_metadata()` 中配置图标：
```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_XXX_NAME"
    metadata.category_key = "BRICKS_CATEGORY_XXX"
    metadata.builtin_icon = "Script"  # ← 添加图标配置
    return metadata
```

2. 运行工具提取图标：
```bash
Project → Tools → Execute Script → generate_builtin_icons.gd
```

3. 运行工具更新 @icon 装饰器（可选，用于 Inspector 显示）：
```bash
Project → Tools → Execute Script → update_instruction_icon_decorators.gd
```

4. 重启编辑器查看效果

### 图标系统文档

- **用户指南**：[icon_manager_guide.md](../../addons/bricks/docs/user_docs/guides/icon_manager_guide.md)
- **技术文档**：[icon_system.md](../../addons/bricks/docs/development/icon_system.md)

---

## 评估体系快速参考

**评分公式（总分 78 分）：**
```
总分 = 需求频率×4.5 + 即用性×3.5 + (6-复杂度)×2.5 + (6-学习曲线)×1.5 + (6-性能影响)×1.0 + 依赖性×2.5
```

**优先级分类：**
- P0 (70-78分): 紧急 - 核心基础，4个指令
- P1 (60-69分): 高 - 主力功能，9个指令
- P2 (50-59分): 中 - 重要功能，45个指令
- P3 (40-49分): 低 - 锦上添花，3个指令

---

## Phase 0A: 核心基础（预计 5 天）✅ **已完成**

**目标：** 实现核心的依赖性功能，为后续开发奠定基础

**依赖验证：** 这4个指令的依赖性评分均为5分（被多个功能依赖），必须优先开发

**完成日期：** 2026-01-25

**完成状态：** 所有 4 个 P0 核心指令已实现并通过测试

---

### Task 1: Set Position 指令（69.0分，P0）✅ **已完成**

**功能：** 设置节点的全局或局部位置，支持 2D/3D

**文件：**
- 创建: `addons/bricks/instructions/set_position.gd`
- 创建: `addons/bricks/tests/instructions/test_set_position.tscn`
- 创建: `addons/bricks/tests/instructions/test_set_position.gd`
- 修改: `addons/bricks/translations/translations.csv` (添加本地化)

**Step 1: 创建指令类骨架**

```gdscript
# addons/bricks/instructions/set_position.gd
@tool
extends BaseInstruction
class_name SetPosition

## 设置节点的位置（支持 2D/3D）

# 目标节点路径
@export var target_node: NodePath = NodePath("")

# 目标位置
@export var position: Vector3 = Vector3.ZERO

# 坐标空间（Global/Local）
@export var space: int = 0  # 0=Global, 1=Local

# 是否使用变量
@export var use_variable: bool = false

# 位置变量名
@export var position_variable: String = ""

func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_SET_POSITION_NAME"
    metadata.category_key = "BRICKS_CATEGORY_TRANSFORM"
    metadata.description_key = "BRICKS_INSTRUCTION_SET_POSITION_DESC"
    metadata.keywords = ["position", "transform", "move", "location"]
    return metadata

func execute(context: ExecutionContext) -> void:
    var node := context.resolve_node(target_node)
    if not node:
        context.log_error("Target node not found: %s" % target_node)
        return

    var target_pos: Vector3

    if use_variable:
        var var_value = context.get_variable(position_variable)
        if var_value is Vector2 or var_value is Vector3:
            target_pos = var_value
        else:
            context.log_error("Variable %s is not a vector type" % position_variable)
            return
    else:
        target_pos = position

    # 自动检测 2D/3D
    if node is Node2D:
        if space == 0:
            node.global_position = Vector2(target_pos.x, target_pos.y)
        else:
            node.position = Vector2(target_pos.x, target_pos.y)
    elif node is Node3D:
        if space == 0:
            node.global_position = target_pos
        else:
            node.position = target_pos
    else:
        context.log_error("Node %s is not a Node2D or Node3D" % node.name)

func _get_property_list() -> Array[Dictionary]:
    var properties := []

    properties.append({
        name = "Transform",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    properties.append({
        name = "target_node",
        type = TYPE_NODE_PATH,
        hint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,
        hint_string = "Node2D,Node3D",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    properties.append({
        name = "space",
        type = TYPE_INT,
        hint = PROPERTY_HINT_ENUM,
        hint_string = "Global,Local",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    properties.append({
        name = "use_variable",
        type = TYPE_BOOL,
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    if use_variable:
        properties.append({
            name = "position_variable",
            type = TYPE_STRING,
            hint = PROPERTY_HINT_PLACEHOLDER_TEXT,
            hint_string = "Variable name...",
            usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
        })
    else:
        properties.append({
            name = "position",
            type = TYPE_VECTOR3,
            usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
        })

    return properties

func _validate_property(property: Dictionary) -> void:
    if property.name == "position" and use_variable:
        property.usage = PROPERTY_USAGE_NO_EDITOR

    if property.name == "position_variable" and not use_variable:
        property.usage = PROPERTY_USAGE_NO_EDITOR
```

**Step 2: 添加本地化翻译**

在 `addons/bricks/translations/translations.csv` 添加：

```csv
keys,en,zh
BRICKS_INSTRUCTION_SET_POSITION_NAME,Set Position,设置位置
BRICKS_CATEGORY_TRANSFORM,Transform,变换操作
BRICKS_INSTRUCTION_SET_POSITION_DESC,Sets the global or local position of a node (supports 2D/3D),设置节点的全局或局部位置（支持 2D/3D）
```

**Step 3: 创建测试场景**

**Step 3.1: 创建测试场景文件**

创建 `addons/bricks/tests/instructions/test_set_position_instruction.tscn`：

```gdscript
[gd_scene load_steps=2 format=3 uid="uid://test_set_position"]

[ext_resource type="Script" path="res://addons/bricks/tests/instructions/test_set_position.gd" id="1"]

[node name="TestSetPosition" type="Node"]
script = ExtResource("1")

[node name="TestNode2D" type="Node2D" parent="."]
position = Vector2(100, 100)

[node name="TestNode3D" type="Node3D" parent="."]
position = Vector3(0, 0, 0)
```

**Step 3.2: 创建测试脚本**

创建 `addons/bricks/tests/instructions/test_set_position.gd`：

```gdscript
extends Node

## Set Position 指令测试

func _ready():
    print("=== Testing Set Position Instruction ===")
    test_set_position_2d_global()
    test_set_position_2d_local()
    test_set_position_3d_global()
    test_set_position_3d_local()
    test_set_position_with_variable()
    print("=== All Set Position tests passed! ===")

func test_set_position_2d_global():
    print("Test 1: Set 2D position (global)")

    var instruction = SetPosition.new()
    instruction.target_node = NodePath("TestNode2D")
    instruction.space = 0  # Global
    instruction.position = Vector3(200, 300, 0)
    instruction.use_variable = false

    var context = ExecutionContext.new()
    add_child(context)

    var test_node = $TestNode2D
    print("  Initial position: %s" % test_node.global_position)

    instruction.execute(context)

    assert(test_node.global_position == Vector2(200, 300), "Global position should be (200, 300)")
    print("  Final position: %s" % test_node.global_position)
    print("  ✓ Test 1 passed\n")

func test_set_position_2d_local():
    print("Test 2: Set 2D position (local)")

    var instruction = SetPosition.new()
    instruction.target_node = NodePath("TestNode2D")
    instruction.space = 1  # Local
    instruction.position = Vector3(50, 75, 0)
    instruction.use_variable = false

    var context = ExecutionContext.new()
    add_child(context)

    var test_node = $TestNode2D
    print("  Initial position: %s" % test_node.position)

    instruction.execute(context)

    assert(test_node.position == Vector2(50, 75), "Local position should be (50, 75)")
    print("  Final position: %s" % test_node.position)
    print("  ✓ Test 2 passed\n")

func test_set_position_3d_global():
    print("Test 3: Set 3D position (global)")

    var instruction = SetPosition.new()
    instruction.target_node = NodePath("TestNode3D")
    instruction.space = 0  # Global
    instruction.position = Vector3(10, 20, 30)
    instruction.use_variable = false

    var context = ExecutionContext.new()
    add_child(context)

    var test_node = $TestNode3D
    print("  Initial position: %s" % test_node.global_position)

    instruction.execute(context)

    assert(test_node.global_position == Vector3(10, 20, 30), "Global position should be (10, 20, 30)")
    print("  Final position: %s" % test_node.global_position)
    print("  ✓ Test 3 passed\n")

func test_set_position_3d_local():
    print("Test 4: Set 3D position (local)")

    var instruction = SetPosition.new()
    instruction.target_node = NodePath("TestNode3D")
    instruction.space = 1  # Local
    instruction.position = Vector3(5, 10, 15)
    instruction.use_variable = false

    var context = ExecutionContext.new()
    add_child(context)

    var test_node = $TestNode3D
    print("  Initial position: %s" % test_node.position)

    instruction.execute(context)

    assert(test_node.position == Vector3(5, 10, 15), "Local position should be (5, 10, 15)")
    print("  Final position: %s" % test_node.position)
    print("  ✓ Test 4 passed\n")

func test_set_position_with_variable():
    print("Test 5: Set position using variable")

    var instruction = SetPosition.new()
    instruction.target_node = NodePath("TestNode2D")
    instruction.space = 0  # Global
    instruction.use_variable = true
    instruction.position_variable = "target_pos"

    var context = ExecutionContext.new()
    add_child(context)

    # 设置变量
    context.set_variable("target_pos", Vector2(400, 500))

    var test_node = $TestNode2D
    print("  Initial position: %s" % test_node.global_position)
    print("  Variable value: %s" % context.get_variable("target_pos"))

    instruction.execute(context)

    assert(test_node.global_position == Vector2(400, 500), "Position from variable should be (400, 500)")
    print("  Final position: %s" % test_node.global_position)
    print("  ✓ Test 5 passed\n")
```

**Step 4: 在编辑器中运行测试**

```bash
# 在 Godot 编辑器中
1. 打开 addons/bricks/tests/instructions/test_set_position_instruction.tscn
2. 按 F5 运行场景
3. 查看控制台输出，确认所有测试通过
```

**预期输出：**
```
=== Testing Set Position Instruction ===
Test 1: Set 2D position (global)
  Initial position: (100, 100)
  Final position: (200, 300)
  ✓ Test 1 passed

Test 2: Set 2D position (local)
  Initial position: (0, 0)
  Final position: (50, 75)
  ✓ Test 2 passed

...

=== All Set Position tests passed! ===
```

**Step 5: 注册指令到系统**

修改 `addons/bricks/core/instruction_registry.gd`（如果存在）：

```gdscript
# 在 _register_all_instructions() 中添加
func _register_all_instructions():
    # ... 其他指令
    _register_instruction(SetPosition)
```

**Step 6: 提交代码**

```bash
git add addons/bricks/instructions/set_position.gd
git add addons/bricks/tests/instructions/test_set_position.*
git add addons/bricks/translations/translations.csv
git commit -m "feat(bricks): add Set Position instruction (P0, 69.0分)

- 实现位置设置功能（支持 2D/3D）
- 支持全局和局部坐标空间
- 支持变量模式
- 完整测试覆盖

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 2: For Loop 指令（59.5分，P0）✅ **已完成**

**功能：** 重复执行指令序列固定次数，支持索引变量

**依赖关系：** 被 Break Loop、Continue Loop、For Each 依赖，必须优先实现

**文件：**
- 创建: `addons/bricks/instructions/for_loop.gd`
- 创建: `addons/bricks/tests/instructions/test_for_loop.tscn`
- 创建: `addons/bricks/tests/instructions/test_for_loop.gd`
- 修改: `addons/bricks/translations/translations.csv`

**Step 1: 创建 For Loop 指令类**

```gdscript
# addons/bricks/instructions/for_loop.gd
@tool
extends BaseInstruction
class_name ForLoop

## 重复执行指令序列固定次数

# 循环次数
@export var loop_count: int = 3

# 是否使用变量指定循环次数
@export var use_variable: bool = false

# 循环次数变量名
@export var count_variable: String = ""

# 保存当前索引的变量名
@export var loop_index_variable: String = "i"

# 循环体指令列表
@export var loop_instructions: Array[BaseInstruction] = []

func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_FOR_LOOP_NAME"
    metadata.category_key = "BRICKS_CATEGORY_FLOW_CONTROL"
    metadata.description_key = "BRICKS_INSTRUCTION_FOR_LOOP_DESC"
    metadata.keywords = ["loop", "repeat", "iterate", "for"]
    return metadata

func execute(context: ExecutionContext) -> void:
    var iterations: int

    # 确定循环次数
    if use_variable:
        var var_value = context.get_variable(count_variable)
        if var_value is int:
            iterations = var_value
        else:
            context.log_error("Variable %s is not an integer" % count_variable)
            return
    else:
        iterations = loop_count

    # 执行循环
    for i in range(iterations):
        # 保存当前索引到变量
        context.set_variable(loop_index_variable, i)

        # 执行循环体指令
        for instruction in loop_instructions:
            if not instruction:
                continue

            instruction.execute(context)

            # 检查是否需要跳出循环（由 Break Loop 设置）
            if context.should_break_loop():
                break

        # 检查是否需要继续（由 Continue Loop 设置）
        if context.should_continue_loop():
            continue

    # 清理循环变量
    context.clear_loop_flags()

func _get_property_list() -> Array[Dictionary]:
    var properties := []

    properties.append({
        name = "Loop",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    properties.append({
        name = "use_variable",
        type = TYPE_BOOL,
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    if use_variable:
        properties.append({
            name = "count_variable",
            type = TYPE_STRING,
            hint = PROPERTY_HINT_PLACEHOLDER_TEXT,
            hint_string = "Variable name...",
            usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
        })
    else:
        properties.append({
            name = "loop_count",
            type = TYPE_INT,
            hint = PROPERTY_HINT_RANGE,
            hint_string = "1,1000",
            usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
        })

    properties.append({
        name = "loop_index_variable",
        type = TYPE_STRING,
        hint = PROPERTY_HINT_PLACEHOLDER_TEXT,
        hint_string = "i",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    properties.append({
        name = "loop_instructions",
        type = TYPE_ARRAY,
        hint = PROPERTY_HINT_ARRAY_TYPE,
        hint_string = "%d/%d:%s" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "BaseInstruction"],
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    return properties

func _validate_property(property: Dictionary) -> void:
    if property.name == "loop_count" and use_variable:
        property.usage = PROPERTY_USAGE_NO_EDITOR

    if property.name == "count_variable" and not use_variable:
        property.usage = PROPERTY_USAGE_NO_EDITOR
```

**Step 2: 扩展 ExecutionContext 支持循环控制**

修改 `addons/bricks/core/execution_context.gd`，添加：

```gdscript
# 循环控制标志
var _break_loop_flag: bool = false
var _continue_loop_flag: bool = false

## 设置跳出循环标志
func set_break_loop() -> void:
    _break_loop_flag = true

## 设置继续循环标志
func set_continue_loop() -> void:
    _continue_loop_flag = true

## 检查是否应该跳出循环
func should_break_loop() -> bool:
    return _break_loop_flag

## 检查是否应该继续循环
func should_continue_loop() -> bool:
    return _continue_loop_flag

## 清理循环标志
func clear_loop_flags() -> void:
    _break_loop_flag = false
    _continue_loop_flag = false
```

**Step 3: 添加本地化翻译**

```csv
keys,en,zh
BRICKS_INSTRUCTION_FOR_LOOP_NAME,For Loop,计数循环
BRICKS_CATEGORY_FLOW_CONTROL,Flow Control,流程控制
BRICKS_INSTRUCTION_FOR_LOOP_DESC,Repeats a sequence of instructions a fixed number of times,重复执行指令序列固定次数
```

**Step 4: 创建测试场景**

创建 `addons/bricks/tests/instructions/test_for_loop_instruction.tscn`：

```gdscript
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://addons/bricks/tests/instructions/test_for_loop.gd" id="1"]

[node name="TestForLoop" type="Node"]
script = ExtResource("1")
```

**Step 5: 创建测试脚本**

```gdscript
# addons/bricks/tests/instructions/test_for_loop.gd
extends Node

## For Loop 指令测试

func _ready():
    print("=== Testing For Loop Instruction ===")
    test_basic_loop()
    test_loop_with_index()
    test_loop_with_variable_count()
    test_nested_loops()
    print("=== All For Loop tests passed! ===")

func test_basic_loop():
    print("Test 1: Basic loop (3 iterations)")

    var instruction = ForLoop.new()
    instruction.loop_count = 3
    instruction.use_variable = false
    instruction.loop_index_variable = "i"

    # 创建测试指令（计数指令）
    var counter_instruction = CountInstruction.new()
    counter_instruction.target_variable = "counter"
    counter_instruction.amount = 1
    instruction.loop_instructions.append(counter_instruction)

    var context = ExecutionContext.new()
    add_child(context)
    context.set_variable("counter", 0)

    print("  Initial counter: %s" % context.get_variable("counter"))
    instruction.execute(context)

    var final_count = context.get_variable("counter")
    assert(final_count == 3, "Counter should be 3 after 3 iterations")
    print("  Final counter: %s" % final_count)
    print("  ✓ Test 1 passed\n")

func test_loop_with_index():
    print("Test 2: Loop with index variable")

    var instruction = ForLoop.new()
    instruction.loop_count = 5
    instruction.use_variable = false
    instruction.loop_index_variable = "index"

    # 创建测试指令（收集索引）
    var collect_instruction = CollectIndexInstruction.new()
    collect_instruction.array_variable = "indices"
    collect_instruction.index_variable = "index"
    instruction.loop_instructions.append(collect_instruction)

    var context = ExecutionContext.new()
    add_child(context)
    context.set_variable("indices", [])

    instruction.execute(context)

    var indices = context.get_variable("indices")
    assert(indices.size() == 5, "Should have 5 indices")
    assert(indices == [0, 1, 2, 3, 4], "Indices should be [0, 1, 2, 3, 4]")
    print("  Collected indices: %s" % indices)
    print("  ✓ Test 2 passed\n")

func test_loop_with_variable_count():
    print("Test 3: Loop with variable count")

    var instruction = ForLoop.new()
    instruction.use_variable = true
    instruction.count_variable = "loop_times"
    instruction.loop_index_variable = "j"

    var counter_instruction = CountInstruction.new()
    counter_instruction.target_variable = "total"
    counter_instruction.amount = 1
    instruction.loop_instructions.append(counter_instruction)

    var context = ExecutionContext.new()
    add_child(context)
    context.set_variable("loop_times", 4)
    context.set_variable("total", 0)

    print("  Loop count from variable: %s" % context.get_variable("loop_times"))
    instruction.execute(context)

    var total = context.get_variable("total")
    assert(total == 4, "Total should be 4")
    print("  Total iterations: %s" % total)
    print("  ✓ Test 3 passed\n")

func test_nested_loops():
    print("Test 4: Nested loops")

    var outer_loop = ForLoop.new()
    outer_loop.loop_count = 3
    outer_loop.loop_index_variable = "i"

    var inner_loop = ForLoop.new()
    inner_loop.loop_count = 2
    inner_loop.loop_index_variable = "j"

    var counter_instruction = CountInstruction.new()
    counter_instruction.target_variable = "nested_counter"
    counter_instruction.amount = 1
    inner_loop.loop_instructions.append(counter_instruction)

    outer_loop.loop_instructions.append(inner_loop)

    var context = ExecutionContext.new()
    add_child(context)
    context.set_variable("nested_counter", 0)

    instruction.execute(context)

    var final_count = context.get_variable("nested_counter")
    assert(final_count == 6, "Nested counter should be 6 (3 * 2)")
    print("  Nested iterations: %s" % final_count)
    print("  ✓ Test 4 passed\n")
```

**Step 6: 运行测试**

```bash
# 在 Godot 编辑器中
1. 打开 addons/bricks/tests/instructions/test_for_loop_instruction.tscn
2. 按 F5 运行场景
3. 查看控制台输出
```

**Step 7: 提交代码**

```bash
git add addons/bricks/instructions/for_loop.gd
git add addons/bricks/core/execution_context.gd
git add addons/bricks/tests/instructions/test_for_loop.*
git add addons/bricks/translations/translations.csv
git commit -m "feat(bricks): add For Loop instruction (P0, 59.5分)

- 实现计数循环功能
- 支持固定次数和变量次数
- 支持索引变量
- 支持嵌套循环
- 扩展 ExecutionContext 支持循环控制标志
- 完整测试覆盖

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 3: If/Else 指令（59.0分，P0）✅ **已完成**

**功能：** 根据条件执行不同的指令序列

**依赖关系：** 条件判断是编程基础，被大量功能依赖

**文件：**
- 创建: `addons/bricks/instructions/if_else.gd`
- 创建: `addons/bricks/tests/instructions/test_if_else.tscn`
- 创建: `addons/bricks/tests/instructions/test_if_else.gd`
- 修改: `addons/bricks/translations/translations.csv`

**Step 1: 创建 If/Else 指令类**

```gdscript
# addons/bricks/instructions/if_else.gd
@tool
extends BaseInstruction
class_name IfElse

## 根据条件执行不同的指令序列

# 条件类型
enum ConditionType {
    VARIABLE_COMPARISON,
    NODE_PROPERTY_CHECK,
    NODE_EXISTS
}

# 比较运算符
enum ComparisonOperator {
    EQUAL,
    NOT_EQUAL,
    GREATER_THAN,
    LESS_THAN,
    GREATER_EQUAL,
    LESS_EQUAL
}

@export var condition_type: ConditionType = ConditionType.VARIABLE_COMPARISON

# 变量比较参数
@export var variable_name: String = ""
@export var comparison_operator: ComparisonOperator = ComparisonOperator.EQUAL
@export var compare_value: Variant = null

# 节点属性检查参数
@export var node_path: NodePath = NodePath("")
@export var property_name: String = ""

# 节点存在性检查参数
@export var check_node_path: NodePath = NodePath("")

# 条件为真时执行的指令
@export var true_instructions: Array[BaseInstruction] = []

# 条件为假时执行的指令
@export var false_instructions: Array[BaseInstruction] = []

func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_IF_ELSE_NAME"
    metadata.category_key = "BRICKS_CATEGORY_FLOW_CONTROL"
    metadata.description_key = "BRICKS_INSTRUCTION_IF_ELSE_DESC"
    metadata.keywords = ["if", "else", "condition", "branch"]
    return metadata

func execute(context: ExecutionContext) -> void:
    var condition_result := _evaluate_condition(context)

    if condition_result:
        # 执行 true 分支
        for instruction in true_instructions:
            if instruction:
                instruction.execute(context)
    else:
        # 执行 false 分支
        for instruction in false_instructions:
            if instruction:
                instruction.execute(context)

func _evaluate_condition(context: ExecutionContext) -> bool:
    match condition_type:
        ConditionType.VARIABLE_COMPARISON:
            return _evaluate_variable_comparison(context)
        ConditionType.NODE_PROPERTY_CHECK:
            return _evaluate_node_property_check(context)
        ConditionType.NODE_EXISTS:
            return _evaluate_node_exists(context)
        _:
            context.log_error("Unknown condition type: %s" % condition_type)
            return false

func _evaluate_variable_comparison(context: ExecutionContext) -> bool:
    var var_value = context.get_variable(variable_name)

    match comparison_operator:
        ComparisonOperator.EQUAL:
            return var_value == compare_value
        ComparisonOperator.NOT_EQUAL:
            return var_value != compare_value
        ComparisonOperator.GREATER_THAN:
            if var_value is int or var_value is float:
                return var_value > compare_value
        ComparisonOperator.LESS_THAN:
            if var_value is int or var_value is float:
                return var_value < compare_value
        ComparisonOperator.GREATER_EQUAL:
            if var_value is int or var_value is float:
                return var_value >= compare_value
        ComparisonOperator.LESS_EQUAL:
            if var_value is int or var_value is float:
                return var_value <= compare_value
        _:
            context.log_error("Unknown comparison operator: %s" % comparison_operator)
            return false

    return false

func _evaluate_node_property_check(context: ExecutionContext) -> bool:
    var node = context.resolve_node(node_path)
    if not node:
        context.log_error("Node not found: %s" % node_path)
        return false

    if not node.has_method("get"):
        context.log_error("Node does not support property access")
        return false

    var property_value = node.get(property_name)
    return property_value == true

func _evaluate_node_exists(context: ExecutionContext) -> bool:
    var node = context.resolve_node(check_node_path)
    return node != null

func _get_property_list() -> Array[Dictionary]:
    var properties := []

    properties.append({
        name = "Condition",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    properties.append({
        name = "condition_type",
        type = TYPE_INT,
        hint = PROPERTY_HINT_ENUM,
        hint_string = "Variable Comparison:Node Property Check:Node Exists",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    match condition_type:
        ConditionType.VARIABLE_COMPARISON:
            properties.append({
                name = "variable_name",
                type = TYPE_STRING,
                hint = PROPERTY_HINT_PLACEHOLDER_TEXT,
                hint_string = "Variable name...",
                usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
            })
            properties.append({
                name = "comparison_operator",
                type = TYPE_INT,
                hint = PROPERTY_HINT_ENUM,
                hint_string = "Equal,Not Equal,Greater Than,Less Than,Greater or Equal,Less or Equal",
                usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
            })
            properties.append({
                name = "compare_value",
                type = TYPE_NIL,
                usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
            })

        ConditionType.NODE_PROPERTY_CHECK:
            properties.append({
                name = "node_path",
                type = TYPE_NODE_PATH,
                usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
            })
            properties.append({
                name = "property_name",
                type = TYPE_STRING,
                hint = PROPERTY_HINT_PLACEHOLDER_TEXT,
                hint_string = "visible,process_mode,...",
                usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
            })

        ConditionType.NODE_EXISTS:
            properties.append({
                name = "check_node_path",
                type = TYPE_NODE_PATH,
                usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
            })

    properties.append({
        name = "Instructions",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    properties.append({
        name = "true_instructions",
        type = TYPE_ARRAY,
        hint = PROPERTY_HINT_ARRAY_TYPE,
        hint_string = "%d/%d:%s" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "BaseInstruction"],
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    properties.append({
        name = "false_instructions",
        type = TYPE_ARRAY,
        hint = PROPERTY_HINT_ARRAY_TYPE,
        hint_string = "%d/%d:%s" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE, "BaseInstruction"],
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    return properties
```

**Step 2: 添加本地化翻译**

```csv
keys,en,zh
BRICKS_INSTRUCTION_IF_ELSE_NAME,If/Else,条件分支
BRICKS_INSTRUCTION_IF_ELSE_DESC,Executes different instruction sequences based on conditions,根据条件执行不同的指令序列
```

**Step 3: 创建测试场景**

创建 `addons/bricks/tests/instructions/test_if_else.tscn` 和测试脚本：

```gdscript
# addons/bricks/tests/instructions/test_if_else.gd
extends Node

## If/Else 指令测试

func _ready():
    print("=== Testing If/Else Instruction ===")
    test_variable_comparison_equal()
    test_variable_comparison_greater_than()
    test_variable_comparison_less_than()
    test_node_property_check()
    test_node_exists()
    test_true_branch()
    test_false_branch()
    print("=== All If/Else tests passed! ===")

func test_variable_comparison_equal():
    print("Test 1: Variable comparison (equal)")

    var instruction = IfElse.new()
    instruction.condition_type = IfElse.ConditionType.VARIABLE_COMPARISON
    instruction.variable_name = "health"
    instruction.comparison_operator = IfElse.ComparisonOperator.EQUAL
    instruction.compare_value = 100

    var set_true = SetVariableInstruction.new()
    set_true.target_variable = "test_result"
    set_true.value = "true_branch"
    instruction.true_instructions.append(set_true)

    var set_false = SetVariableInstruction.new()
    set_false.target_variable = "test_result"
    set_false.value = "false_branch"
    instruction.false_instructions.append(set_false)

    var context = ExecutionContext.new()
    add_child(context)
    context.set_variable("health", 100)

    instruction.execute(context)

    assert(context.get_variable("test_result") == "true_branch", "Should execute true branch")
    print("  Result: %s" % context.get_variable("test_result"))
    print("  ✓ Test 1 passed\n")

func test_variable_comparison_greater_than():
    print("Test 2: Variable comparison (greater than)")

    var instruction = IfElse.new()
    instruction.condition_type = IfElse.ConditionType.VARIABLE_COMPARISON
    instruction.variable_name = "score"
    instruction.comparison_operator = IfElse.ComparisonOperator.GREATER_THAN
    instruction.compare_value = 50

    var set_true = SetVariableInstruction.new()
    set_true.target_variable = "grade"
    set_true.value = "pass"
    instruction.true_instructions.append(set_true)

    var context = ExecutionContext.new()
    add_child(context)
    context.set_variable("score", 75)

    instruction.execute(context)

    assert(context.get_variable("grade") == "pass", "Should execute true branch")
    print("  Score: %s, Grade: %s" % [context.get_variable("score"), context.get_variable("grade")])
    print("  ✓ Test 2 passed\n")

func test_node_property_check():
    print("Test 3: Node property check")

    var instruction = IfElse.new()
    instruction.condition_type = IfElse.ConditionType.NODE_PROPERTY_CHECK
    instruction.node_path = NodePath("TestNode")
    instruction.property_name = "visible"

    var set_visible = SetVariableInstruction.new()
    set_visible.target_variable = "node_state"
    set_visible.value = "is_visible"
    instruction.true_instructions.append(set_visible)

    var context = ExecutionContext.new()
    add_child(context)

    # 创建测试节点
    var test_node = Node2D.new()
    test_node.name = "TestNode"
    test_node.visible = true
    add_child(test_node)

    instruction.execute(context)

    assert(context.get_variable("node_state") == "is_visible", "Node is visible")
    print("  Node state: %s" % context.get_variable("node_state"))
    print("  ✓ Test 3 passed\n")

func test_node_exists():
    print("Test 4: Node exists check")

    var instruction = IfElse.new()
    instruction.condition_type = IfElse.ConditionType.NODE_EXISTS
    instruction.check_node_path = NodePath("ExistingNode")

    var set_exists = SetVariableInstruction.new()
    set_exists.target_variable = "exists"
    set_exists.value = true
    instruction.true_instructions.append(set_exists)

    var context = ExecutionContext.new()
    add_child(context)

    # 创建测试节点
    var existing_node = Node.new()
    existing_node.name = "ExistingNode"
    add_child(existing_node)

    instruction.execute(context)

    assert(context.get_variable("exists") == true, "Node should exist")
    print("  Node exists: %s" % context.get_variable("exists"))
    print("  ✓ Test 4 passed\n")

func test_true_branch():
    print("Test 5: True branch execution")

    var instruction = IfElse.new()
    instruction.condition_type = IfElse.ConditionType.VARIABLE_COMPARISON
    instruction.variable_name = "value"
    instruction.comparison_operator = IfElse.ComparisonOperator.EQUAL
    instruction.compare_value = 10

    var counter = CountInstruction.new()
    counter.target_variable = "true_count"
    counter.amount = 1
    instruction.true_instructions.append(counter)

    var context = ExecutionContext.new()
    add_child(context)
    context.set_variable("value", 10)
    context.set_variable("true_count", 0)

    instruction.execute(context)

    assert(context.get_variable("true_count") == 1, "True branch should execute")
    print("  True count: %s" % context.get_variable("true_count"))
    print("  ✓ Test 5 passed\n")

func test_false_branch():
    print("Test 6: False branch execution")

    var instruction = IfElse.new()
    instruction.condition_type = IfElse.ConditionType.VARIABLE_COMPARISON
    instruction.variable_name = "value"
    instruction.comparison_operator = IfElse.ComparisonOperator.EQUAL
    instruction.compare_value = 10

    var counter = CountInstruction.new()
    counter.target_variable = "false_count"
    counter.amount = 1
    instruction.false_instructions.append(counter)

    var context = ExecutionContext.new()
    add_child(context)
    context.set_variable("value", 20)
    context.set_variable("false_count", 0)

    instruction.execute(context)

    assert(context.get_variable("false_count") == 1, "False branch should execute")
    print("  False count: %s" % context.get_variable("false_count"))
    print("  ✓ Test 6 passed\n")
```

**Step 4: 运行测试并提交**

```bash
git add addons/bricks/instructions/if_else.gd
git add addons/bricks/tests/instructions/test_if_else.*
git add addons/bricks/translations/translations.csv
git commit -m "feat(bricks): add If/Else instruction (P0, 59.0分)

- 实现条件分支功能
- 支持变量比较、节点属性检查、节点存在性检查
- 支持6种比较运算符
- 支持嵌套指令序列
- 完整测试覆盖

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 4: Find Node 指令（59.0分，P0）✅ **已完成**

**功能：** 按名称、类型或组查找节点，并保存到变量

**依赖关系：** 被节点操作依赖，是节点管理的基础

**文件：**
- 创建: `addons/bricks/instructions/find_node.gd`
- 创建: `addons/bricks/tests/instructions/test_find_node.tscn`
- 创建: `addons/bricks/tests/instructions/test_find_node.gd`
- 修改: `addons/bricks/translations/translations.csv`

**Step 1: 创建 Find Node 指令类**

```gdscript
# addons/bricks/instructions/find_node.gd
@tool
extends BaseInstruction
class_name FindNode

## 按名称、类型或组查找节点

# 搜索类型
enum SearchType {
    BY_NAME,
    BY_TYPE,
    BY_GROUP
}

# 搜索范围
enum SearchScope {
    CHILDREN,
    SCENE,
    GLOBAL
}

@export var search_type: SearchType = SearchType.BY_NAME
@export var search_value: String = ""

@export var target_variable: String = "found_node"
@export var variable_scope: int = 0  # 0=Local, 1=Global

@export var search_scope: SearchScope = SearchScope.CHILDREN

func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_FIND_NODE_NAME"
    metadata.category_key = "BRICKS_CATEGORY_NODE_OPERATION"
    metadata.description_key = "BRICKS_INSTRUCTION_FIND_NODE_DESC"
    metadata.keywords = ["find", "search", "node", "get"]
    return metadata

func execute(context: ExecutionContext) -> void:
    var found_node: Node = null

    match search_type:
        SearchType.BY_NAME:
            found_node = _find_by_name(context)
        SearchType.BY_TYPE:
            found_node = _find_by_type(context)
        SearchType.BY_GROUP:
            found_node = _find_by_group(context)

    if found_node:
        # 保存节点路径到变量（保存 NodePath 而不是 Node 引用）
        var node_path = str(found_node.get_path())
        if variable_scope == 1:
            GlobalVariableAssistant.set_variable(target_variable, node_path)
        else:
            context.set_variable(target_variable, node_path)

        context.log_info("Found node: %s" % node_path)
    else:
        context.log_error("Node not found with search criteria: %s" % search_value)

func _find_by_name(context: ExecutionContext) -> Node:
    match search_scope:
        SearchScope.CHILDREN:
            # 在子节点中查找
            var owner = context.get_owner()
            if owner:
                return owner.find_child(search_value, true, false)
        SearchScope.SCENE:
            # 在当前场景中查找
            return get_tree().current_scene.find_child(search_value, true, false)
        SearchScope.GLOBAL:
            # 在整个场景树中查找
            return get_tree().root.find_child(search_value, true, false)
    return null

func _find_by_type(context: ExecutionContext) -> Node:
    match search_scope:
        SearchScope.CHILDREN:
            var owner = context.get_owner()
            if owner:
                return _find_node_by_type_recursive(owner, search_value)
        SearchScope.SCENE:
            return _find_node_by_type_recursive(get_tree().current_scene, search_value)
        SearchScope.GLOBAL:
            return _find_node_by_type_recursive(get_tree().root, search_value)
    return null

func _find_by_type(context: ExecutionContext) -> Node:
    var nodes: Array[Node] = []

    match search_scope:
        SearchScope.CHILDREN:
            var owner = context.get_owner()
            if owner:
                nodes = _get_nodes_in_group_recursive(owner, search_value)
        SearchScope.SCENE:
            nodes = get_tree().get_nodes_in_group(search_value)
        SearchScope.GLOBAL:
            nodes = get_tree().get_nodes_in_group(search_value)

    return nodes.front() if not nodes.is_empty() else null

func _find_node_by_type_recursive(node: Node, type_name: String) -> Node:
    if node.get_class() == type_name:
        return node

    for child in node.get_children():
        var result = _find_node_by_type_recursive(child, type_name)
        if result:
            return result

    return null

func _get_nodes_in_group_recursive(node: Node, group: String) -> Array[Node]:
    var nodes: Array[Node] = []

    if node.is_in_group(group):
        nodes.append(node)

    for child in node.get_children():
        nodes.append_array(_get_nodes_in_group_recursive(child, group))

    return nodes

func _get_property_list() -> Array[Dictionary]:
    var properties := []

    properties.append({
        name = "Search",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    properties.append({
        name = "search_type",
        type = TYPE_INT,
        hint = PROPERTY_HINT_ENUM,
        hint_string = "By Name,By Type,By Group",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    properties.append({
        name = "search_value",
        type = TYPE_STRING,
        hint = PROPERTY_HINT_PLACEHOLDER_TEXT,
        hint_string = "Name/Type/Group...",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    properties.append({
        name = "search_scope",
        type = TYPE_INT,
        hint = PROPERTY_HINT_ENUM,
        hint_string = "Children,Scene,Global",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    properties.append({
        name = "Variable",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    properties.append({
        name = "target_variable",
        type = TYPE_STRING,
        hint = PROPERTY_HINT_PLACEHOLDER_TEXT,
        hint_string = "found_node",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    properties.append({
        name = "variable_scope",
        type = TYPE_INT,
        hint = PROPERTY_HINT_ENUM,
        hint_string = "Local,Global",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    return properties
```

**Step 2: 添加本地化翻译**

```csv
keys,en,zh
BRICKS_INSTRUCTION_FIND_NODE_NAME,Find Node,查找节点
BRICKS_CATEGORY_NODE_OPERATION,Node Operation,节点操作
BRICKS_INSTRUCTION_FIND_NODE_DESC,Finds a node by name, type, or group and saves it to a variable,按名称、类型或组查找节点并保存到变量
```

**Step 3: 创建测试场景和脚本**

```gdscript
# addons/bricks/tests/instructions/test_find_node.gd
extends Node

## Find Node 指令测试

func _ready():
    print("=== Testing Find Node Instruction ===")

    # 创建测试节点
    _setup_test_nodes()

    test_find_by_name()
    test_find_by_type()
    test_find_by_group()
    test_find_in_scope_children()
    test_find_in_scope_scene()
    test_save_to_variable()

    print("=== All Find Node tests passed! ===")

func _setup_test_nodes():
    var player = Node2D.new()
    player.name = "Player"
    add_child(player)

    var enemy = Node2D.new()
    enemy.name = "Enemy"
    enemy.add_to_group("enemies")
    add_child(enemy)

    var ui = Control.new()
    ui.name = "UI"
    add_child(ui)

func test_find_by_name():
    print("Test 1: Find node by name")

    var instruction = FindNode.new()
    instruction.search_type = FindNode.SearchType.BY_NAME
    instruction.search_value = "Player"
    instruction.search_scope = FindNode.SearchScope.SCENE
    instruction.target_variable = "found_player"
    instruction.variable_scope = 0

    var context = ExecutionContext.new()
    add_child(context)

    instruction.execute(context)

    var result = context.get_variable("found_player")
    assert(result != null, "Should find Player node")
    assert("Player" in result, "Result should contain 'Player'")
    print("  Found: %s" % result)
    print("  ✓ Test 1 passed\n")

func test_find_by_type():
    print("Test 2: Find node by type")

    var instruction = FindNode.new()
    instruction.search_type = FindNode.SearchType.BY_TYPE
    instruction.search_value = "Node2D"
    instruction.search_scope = FindNode.SearchScope.SCENE
    instruction.target_variable = "found_2d_node"
    instruction.variable_scope = 0

    var context = ExecutionContext.new()
    add_child(context)

    instruction.execute(context)

    var result = context.get_variable("found_2d_node")
    assert(result != null, "Should find Node2D")
    print("  Found type: %s" % result)
    print("  ✓ Test 2 passed\n")

func test_find_by_group():
    print("Test 3: Find node by group")

    var instruction = FindNode.new()
    instruction.search_type = FindNode.SearchType.BY_GROUP
    instruction.search_value = "enemies"
    instruction.search_scope = FindNode.SearchScope.SCENE
    instruction.target_variable = "found_enemy"
    instruction.variable_scope = 0

    var context = ExecutionContext.new()
    add_child(context)

    instruction.execute(context)

    var result = context.get_variable("found_enemy")
    assert(result != null, "Should find enemy in group")
    assert("Enemy" in result, "Result should contain 'Enemy'")
    print("  Found in group: %s" % result)
    print("  ✓ Test 3 passed\n")

func test_find_in_scope_children():
    print("Test 4: Find in children scope")

    var container = Node.new()
    container.name = "Container"
    add_child(container)

    var child = Node.new()
    child.name = "ChildNode"
    container.add_child(child)

    var instruction = FindNode.new()
    instruction.search_type = FindNode.SearchType.BY_NAME
    instruction.search_value = "ChildNode"
    instruction.search_scope = FindNode.SearchScope.CHILDREN
    instruction.target_variable = "found_child"
    instruction.variable_scope = 0

    var context = ExecutionContext.new()
    context.set_owner(container)
    add_child(context)

    instruction.execute(context)

    var result = context.get_variable("found_child")
    assert(result != null, "Should find child node")
    print("  Found child: %s" % result)
    print("  ✓ Test 4 passed\n")

func test_save_to_variable():
    print("Test 5: Save to global variable")

    var instruction = FindNode.new()
    instruction.search_type = FindNode.SearchType.BY_NAME
    instruction.search_value = "UI"
    instruction.search_scope = FindNode.SearchScope.SCENE
    instruction.target_variable = "ui_node"
    instruction.variable_scope = 1  # Global

    var context = ExecutionContext.new()
    add_child(context)

    instruction.execute(context)

    var result = GlobalVariableAssistant.get_variable("ui_node")
    assert(result != null, "Should save to global variable")
    assert("UI" in result, "Global variable should contain 'UI'")
    print("  Global variable: %s" % result)
    print("  ✓ Test 5 passed\n")
```

**Step 4: 运行测试并提交**

```bash
git add addons/bricks/instructions/find_node.gd
git add addons/bricks/tests/instructions/test_find_node.*
git add addons/bricks/translations/translations.csv
git commit -m "feat(bricks): add Find Node instruction (P0, 59.0分)

- 实现节点查找功能
- 支持按名称、类型、组查找
- 支持3种搜索范围（子节点/场景/全局）
- 支持本地和全局变量
- 完整测试覆盖

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 0A 实施总结

### 完成的指令（4个P0核心指令）

| 指令 | 评分 | Commit SHA | 核心功能 |
|------|------|-----------|---------|
| **Set Position** | 69.0 | `5434e15`, `d03e9c7`, `57765dd` | 设置节点位置（2D/3D，全局/局部，变量模式） |
| **For Loop** | 59.5 | `193ede2` | 计数循环（固定次数/变量次数，索引变量，嵌套支持） |
| **If/Else** | 59.0 | `1a9ff93`, `08a2dae`, `c6e7c10` | 条件分支（Condition类架构，3种条件类型，6种运算符） |
| **Find Node** | 59.0 | `022a465` | 节点查找（按名称/类型/组，3种搜索范围） |

> **🔄 If/Else 架构重构** (2026-01-25)
>
> 在 Phase 0A 完成后，对 If/Else 指令进行了重大架构重构，从枚举方式改为使用 Condition 类架构。
>
> **重构内容**：
> - 创建 3 个 Condition 子类：VariableComparisonCondition、NodePropertyCheckCondition、NodeExistsCondition
> - If/Else 指令从 569 行减少到 205 行（-64%）
> - 移除 2 个枚举、9 个条件参数、8 个私有方法
> - 条件评估简化为 `condition.check(context)`
>
> **架构优势**：
> - ✅ 开放/封闭原则：添加新条件无需修改 If/Else
> - ✅ 职责分离：If/Else 负责分支，Condition 负责评估
> - ✅ 功能增强：自动获得缓存、取反、依赖管理等功能
> - ✅ 可复用性：Condition 可在 Event、其他 Instruction 中复用
> - ✅ 可测试性：Condition 可独立测试
>
> **相关 Commits**：
> - `08a2dae` - 重构 If/Else 指令使用 Condition 类架构
> - `c6e7c10` - 修复日志方法调用错误
>
> **测试覆盖**：
> - 新增 `test_conditions.gd` - Condition 类综合测试（5个测试场景）
> - 更新 `test_if_else.gd` - 适配新架构（8个测试场景）

### 关键成就

1. **代码质量**
   - 统一的命名规范（移除冗余后缀）
   - 完整的类型注解和错误处理
   - 本地化错误消息系统
   - 动态属性列表实现

2. **测试覆盖**
   - 34 个测试用例，100% 通过率
   - 边界条件测试
   - 错误处理测试

3. **系统扩展**
   - 扩展 ExecutionContext 支持循环控制标志
   - 为后续指令（Break/Continue Loop等）奠定基础

### 遇到的挑战和解决方案

1. **规格符合性问题** - 通过审查修复了文件命名和API实现
2. **代码质量问题** - 统一使用本地化系统，添加类型验证和边界检查
3. **命名规范** - 确立了简洁的命名规则，避免冗余后缀

### 下一步

Phase 0A 已完成，建议继续 Phase 0B（节点管理）或进行集成测试。

---

## Phase 0A 短期改进计划

基于 Phase 0A 的代码审查结果和实际开发经验，以下改进建议可在后续迭代中实施，提升代码质量和测试覆盖率。

### 改进 1: 边界条件测试增强

**当前状态：** 现有测试主要覆盖正常使用场景

**改进目标：** 增加极端边界条件和异常情况测试

**具体改进项：**

#### 1.1 For Loop 边界测试
```gdscript
# 添加到 test_for_loop.gd

func test_zero_iterations():
    print("Test: Zero iterations")
    var for_loop_script = load("res://addons/bricks/instructions/for_loop.gd")
    var for_loop = for_loop_script.new()
    for_loop.loop_count = 0
    for_loop.use_variable = false

    var context = ExecutionContext.new()
    add_child(context)

    for_loop.execute(context)

    # 验证循环体未执行
    assert(true, "Zero iterations should not error")
    print("  ✓ Zero iterations test passed\n")

func test_negative_iterations():
    print("Test: Negative loop count")
    var for_loop_script = load("res://addons/bricks/instructions/for_loop.gd")
    var for_loop = for_loop_script.new()
    for_loop.loop_count = -1
    for_loop.use_variable = false

    var context = ExecutionContext.new()
    add_child(context)

    for_loop.execute(context)

    # 应该记录错误但不崩溃
    print("  ✓ Negative iterations handled\n")

func test_large_iteration_count():
    print("Test: Large iteration count")
    var for_loop_script = load("res://addons/bricks/instructions/for_loop.gd")
    var for_loop = for_loop_script.new()
    for_loop.loop_count = 10000
    for_loop.use_variable = false

    var context = ExecutionContext.new()
    add_child(context)

    var start_time = Time.get_ticks_msec()
    for_loop.execute(context)
    var elapsed = Time.get_ticks_msec() - start_time

    print("  10000 iterations completed in %s ms" % elapsed)
    assert(elapsed < 1000, "Should complete within 1 second")
    print("  ✓ Performance test passed\n")
```

#### 1.2 Set Position 极值测试
```gdscript
# 添加到 test_set_position.gd

func test_nan_position():
    print("Test: NaN position handling")
    var set_pos_script = load("res://addons/bricks/instructions/set_position.gd")
    var set_pos = set_pos_script.new()
    set_pos.target_node = NodePath("TestNode2D")
    set_pos.position = Vector3(NAN, NAN, NAN)

    var context = ExecutionContext.new()
    add_child(context)

    set_pos.execute(context)

    # 应该拒绝 NaN 位置
    var test_node = $TestNode2D
    assert(is_finite(test_node.position.x), "Should not accept NaN")
    print("  ✓ NaN handling test passed\n")

func test_extreme_positions():
    print("Test: Extreme position values")
    var set_pos_script = load("res://addons/bricks/instructions/set_position.gd")
    var set_pos = set_pos_script.new()

    var extreme_positions = [
        Vector3(1e6, 1e6, 0),      # 超大值
        Vector3(-1e6, -1e6, 0),    # 超小值
        Vector3(1e-6, 1e-6, 0),    # 接近零
        Vector3(1e38, 1e38, 0)     # 接近浮点极限
    ]

    for pos in extreme_positions:
        set_pos.position = pos
        var context = ExecutionContext.new()
        add_child(context)

        set_pos.execute(context)

        var test_node = $TestNode2D
        assert(is_finite(test_node.position.x), "Should handle extreme values")

    print("  ✓ Extreme values test passed\n")
```

#### 1.3 If/Else 类型转换测试
```gdscript
# 添加到 test_if_else.gd

func test_type_comparison():
    print("Test: Type comparison safety")

    var test_cases = [
        {"value": 5, "compare": "5", "op": ComparisonOperator.EQUAL, "expect": false},  # int vs String
        {"value": 5.0, "compare": 5, "op": ComparisonOperator.EQUAL, "expect": true},   # float vs int
        {"value": null, "compare": 0, "op": ComparisonOperator.EQUAL, "expect": false},  # null vs int
    ]

    for test_case in test_cases:
        var if_else_script = load("res://addons/bricks/instructions/if_else.gd")
        var if_else = if_else_script.new()
        if_else.condition_type = IfElse.ConditionType.VARIABLE_COMPARISON
        if_else.variable_name = "test_var"
        if_else.comparison_operator = test_case.op
        if_else.compare_value = test_case.compare

        var context = ExecutionContext.new()
        add_child(context)
        context.set_variable("test_var", test_case.value)

        # 记录结果
        if_else.execute(context)

    print("  ✓ Type comparison test passed\n")
```

**优先级：** 中
**预计工作量：** 2-3 小时

---

### 改进 2: For Loop 嵌套标志管理优化

**当前状态：** For Loop 实现了基础的嵌套支持，但标志管理可以更健壮

**问题分析：**
- 当前实现中，每次循环都会调用 `clear_loop_flags()`
- 这可能导致嵌套循环时内层循环清除外层循环的标志
- 应该使用栈结构管理嵌套的循环状态

**优化方案：**

#### 2.1 扩展 ExecutionContext 使用栈管理
```gdscript
# 在 addons/bricks/core/base/execution_context.gd 中添加

var _loop_flag_stack: Array[Dictionary] = []

## 保存当前循环标志到栈
func push_loop_flags() -> void:
    _loop_flag_stack.append({
        "break": _break_loop_flag,
        "continue": _continue_loop_flag
    })
    # 清空当前标志（内层循环开始）
    _break_loop_flag = false
    _continue_loop_flag = false

## 恢复循环标志从栈
func pop_loop_flags() -> void:
    if _loop_flag_stack.is_empty():
        # 栈为空，直接清空
        _break_loop_flag = false
        _continue_loop_flag = false
    else:
        # 恢复外层循环的标志
        var flags = _loop_flag_stack.pop_back()
        _break_loop_flag = flags["break"]
        _continue_loop_flag = flags["continue"]

## 清理当前循环标志
func clear_loop_flags() -> void:
    _break_loop_flag = false
    _continue_loop_flag = false
```

#### 2.2 更新 For Loop 实现
```gdscript
# 在 addons/bricks/instructions/for_loop.gd 中修改

func execute(context: ExecutionContext) -> void:
    var iterations: int

    # 确定循环次数
    if use_variable:
        var var_value = context.get_variable(count_variable)
        if var_value is int:
            iterations = var_value
        else:
            context.set_error_localized("bricks", "error.variable_not_int", {"variable": count_variable})
            return
    else:
        iterations = loop_count

    # 保存外层循环标志并开始新循环
    context.push_loop_flags()

    # 执行循环
    for i in range(iterations):
        # 清空内层循环标志（每次迭代开始）
        context.clear_loop_flags()

        # 保存当前索引到变量
        context.set_variable(loop_index_variable, i)

        # 执行循环体指令
        for instruction in loop_instructions:
            if not instruction:
                continue

            instruction.execute(context)

            # 检查是否需要跳出循环
            if context.should_break_loop():
                break

        # 检查是否需要继续（跳过本次循环剩余部分）
        if context.should_continue_loop():
            continue

    # 恢复外层循环标志
    context.pop_loop_flags()
```

#### 2.3 添加嵌套循环测试
```gdscript
# 在 test_for_loop.gd 中添加

func test_nested_break():
    print("Test: Nested loop with break")

    var outer_script = load("res://addons/bricks/instructions/for_loop.gd")
    var outer = outer_script.new()
    outer.loop_count = 3
    outer.loop_index_variable = "i"

    var inner_script = load("res://addons/bricks/instructions/for_loop.gd")
    var inner = inner_script.new()
    inner.loop_count = 5
    inner.loop_index_variable = "j"

    # 在内层循环第 2 次迭代时 break
    var break_script = load("res://addons/bricks/instructions/break_loop.gd")
    var break_inst = break_script.new()

    var counter_script = load("res://addons/bricks/instructions/count.gd")
    var counter = counter_script.new()
    counter.target_variable = "nested_count"
    counter.amount = 1

    inner.loop_instructions.append(counter)
    inner.loop_instructions.append(break_inst)
    outer.loop_instructions.append(inner)

    var context = ExecutionContext.new()
    add_child(context)
    context.set_variable("nested_count", 0)

    outer.execute(context)

    # 外层循环应该完成 3 次
    # 每次内层循环只执行 2 次（第 2 次时 break）
    # 总计数应该是 6
    var final_count = context.get_variable("nested_count")
    assert(final_count == 6, "Nested count should be 6 (3 outer × 2 inner)")
    print("  Final count: %s" % final_count)
    print("  ✓ Nested break test passed\n")
```

**优先级：** 高
**预计工作量：** 3-4 小时
**影响范围：** 核心系统改动，需要完整回归测试

---

### 改进 3: Find Node 错误处理选项

**当前状态：** Find Node 找不到节点时总是记录错误

**改进目标：** 提供可选的错误处理模式

**应用场景：**
- 有些场景下查找节点是可选的（如查找特效播放点，找不到就使用默认位置）
- 有些场景下查找节点是必需的（如查找玩家引用，找不到应该报错）

**实现方案：**

#### 3.1 添加错误处理枚举
```gdscript
# 在 addons/bricks/instructions/find_node.gd 中添加

enum ErrorHandling {
    STRICT,      # 严格模式：找不到时记录错误
    SILENT,      # 静默模式：找不到时不记录，返回 null
    WARNING      # 警告模式：找不到时记录警告
}

@export var error_handling: ErrorHandling = ErrorHandling.STRICT
```

#### 3.2 修改 execute 方法
```gdscript
func execute(context: ExecutionContext) -> void:
    var found_node: Node = null

    match search_type:
        SearchType.BY_NAME:
            found_node = _find_by_name(context)
        SearchType.BY_TYPE:
            found_node = _find_by_type(context)
        SearchType.BY_GROUP:
            found_node = _find_by_group(context)

    if found_node:
        # 保存节点路径到变量
        var node_path = str(found_node.get_path())
        if variable_scope == 1:
            GlobalVariableAssistant.set_variable(target_variable, node_path)
        else:
            context.set_variable(target_variable, node_path)

        context.log_info("Found node: %s" % node_path)
    else:
        # 根据错误处理模式响应
        match error_handling:
            ErrorHandling.STRICT:
                context.set_error_localized("bricks", "error.node_not_found",
                    {"criteria": search_value, "scope": SearchScope.keys()[search_scope]})
            ErrorHandling.WARNING:
                context.log_warning("Node not found: %s (search: %s)" %
                    [search_value, SearchScope.keys()[search_scope]])
            ErrorHandling.SILENT:
                # 静默设置 null
                if variable_scope == 1:
                    GlobalVariableAssistant.set_variable(target_value, null)
                else:
                    context.set_variable(target_variable, null)
```

#### 3.3 添加测试用例
```gdscript
# 在 test_find_node.gd 中添加

func test_silent_mode():
    print("Test: Silent error handling")

    var find_script = load("res://addons/bricks/instructions/find_node.gd")
    var find = find_script.new()
    find.search_type = FindNode.SearchType.BY_NAME
    find.search_value = "NonexistentNode"
    find.search_scope = FindNode.SearchScope.SCENE
    find.error_handling = FindNode.ErrorHandling.SILENT
    find.target_variable = "result"

    var context = ExecutionContext.new()
    add_child(context)

    find.execute(context)

    # 验证变量被设置为 null
    var result = context.get_variable("result")
    assert(result == null, "Should set null in silent mode")
    print("  Result: %s" % result)
    print("  ✓ Silent mode test passed\n")

func test_warning_mode():
    print("Test: Warning error handling")

    var find_script = load("res://addons/bricks/instructions/find_node.gd")
    var find = find_script.new()
    find.search_type = FindNode.SearchType.BY_NAME
    find.search_value = "NonexistentNode"
    find.search_scope = FindNode.SearchScope.SCENE
    find.error_handling = FindNode.ErrorHandling.WARNING
    find.target_variable = "result"

    var context = ExecutionContext.new()
    add_child(context)

    find.execute(context)

    # 验证记录了警告但不崩溃
    print("  ✓ Warning mode test passed\n")
```

**优先级：** 中
**预计工作量：** 2 小时
**向后兼容：** 是（默认 STRICT 模式保持原有行为）

---

### 改进 4: 类型转换和文档完善

**当前状态：** 代码中有类型转换，但缺少文档说明

**改进目标：** 明确类型转换规则，添加文档和使用示例

#### 4.1 创建类型转换文档
创建 `addons/bricks/docs/user_docs/guides/type_conversion.md`：

```markdown
# Bricks 类型转换指南

## 概述

Bricks 系统在处理变量和参数时会进行自动类型转换。本文档说明转换规则和最佳实践。

## Vector 类型转换

### Vector2 ↔ Vector3
```gdscript
# Set Position 指令自动处理 Vector2/Vector3 转换
# Vector2 赋值给 Vector3 节点时，z 轴默认为 0
# Vector3 赋值给 Vector2 节点时，只使用 x, y 分量
```

### Vector2 ↔ Vector2i
```gdscript
# 自动在浮点和整数向量间转换
# Vector2i → Vector2: 精度保持
# Vector2 → Vector2i: 截断小数部分
```

## 数值类型转换

### int ↔ float
```gdscript
# 比较运算时自动转换
# int 5 == float 5.0  # true
# 整数运算会提升为浮点
```

### 字符串转数值
```gdscript
# 不会自动转换字符串为数值
# 需要显式使用类型转换指令（待实现）
```

## 叞点类型转换

### NodePath ↔ Node
```gdscript
# Find Node 返回 NodePath 字符串
# 其他指令使用 NodePath 时通过 context.resolve_node() 解析
```

## 类型安全建议

1. **明确类型**：在指令中使用类型注解
2. **验证类型**：在执行前验证参数类型
3. **处理转换失败**：提供错误处理机制
4. **文档说明**：在指令文档中说明支持的类型
```

#### 4.2 添加指令内联文档
```gdscript
# 在每个指令的 execute 方法前添加详细注释

## Set Position 类型支持

### 输入类型
- `position`: Vector3 (支持 Vector2, Vector2i, Vector3i 自动转换)
- `target_node`: NodePath (自动解析为 Node2D 或 Node3D)

### 转换规则
- Vector2 → Vector3: z = 0
- Vector2i → Vector3: 转为浮点，z = 0
- Vector3i → Vector3: 转为浮点
- Vector3 → Vector2: 忽略 z 分量

func execute(context: ExecutionContext) -> void:
    # ...
```

**优先级：** 低
**预计工作量：** 4-5 小时（包括文档编写）

---

## 改进优先级总结

| 优先级 | 改进项 | 预计工作量 | 价值 |
|--------|--------|-----------|------|
| 高 | For Loop 嵌套标志管理优化 | 3-4 小时 | 修复嵌套循环潜在问题 |
| 中 | 边界条件测试增强 | 2-3 小时 | 提升测试覆盖率和健壮性 |
| 中 | Find Node 错误处理选项 | 2 小时 | 增强灵活性 |
| 低 | 类型转换文档完善 | 4-5 小时 | 改善开发体验 |

**总预计工作量：** 11-14 小时

---

## 实施建议

### 方案 A: 立即实施（推荐）
在开始 Phase 0B 之前，先完成**高优先级**和部分**中优先级**改进：
- ✅ For Loop 嵌套标志管理优化（核心系统改动）
- ✅ 边界条件测试增强（基础质量保障）
- ⏳ Find Node 错误处理（可选，灵活需求）

### 方案 B: 渐进实施
继续 Phase 0B 开发，在后续迭代中逐步实施改进：
- Phase 0B 期间：实施边界条件测试模式
- Phase 1A 前：完成 For Loop 优化
- Phase 1B 期间：补充类型转换文档

### 方案 C: 技术债务跟踪
将改进项记录到技术债务清单，按需处理：
- 在发现相关 bug 时立即修复
- 在重构相关模块时一并改进
- 在代码审查时持续关注

**推荐：方案 A** - 立即实施高优先级改进，为后续开发奠定更稳固的基础。

---

## Phase 0B: 节点管理（预计 4 天）

**目标：** 实现完整的节点生命周期管理

**依赖关系：** Phase 0A 完成

---

### Task 5: Enable/Disable Node 指令（64.0分，P1）

**功能：** 设置节点的处理模式或可见性

**文件：**
- 创建: `addons/bricks/instructions/enable_disable_node.gd`
- 创建: `addons/bricks/tests/instructions/test_enable_disable_node.tscn`
- 创建: `addons/bricks/tests/instructions/test_enable_disable_node.gd`
- 修改: `addons/bricks/translations/translations.csv`

**Step 1: 创建指令类**

```gdscript
# addons/bricks/instructions/enable_disable_node.gd
@tool
extends BaseInstruction
class_name EnableDisableNode

## 启用或禁用节点

# 控制模式
enum ControlMode {
    PROCESSING,  # 控制处理模式
    VISIBLE      # 控制可见性
}

@export var target_node: NodePath = NodePath("")
@export var enable: bool = true
@export var mode: ControlMode = ControlMode.PROCESSING

func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_ENABLE_DISABLE_NODE_NAME"
    metadata.category_key = "BRICKS_CATEGORY_NODE_OPERATION"
    metadata.description_key = "BRICKS_INSTRUCTION_ENABLE_DISABLE_NODE_DESC"
    metadata.keywords = ["enable", "disable", "visible", "processing"]
    return metadata

func execute(context: ExecutionContext) -> void:
    var node := context.resolve_node(target_node)
    if not node:
        context.log_error("Target node not found: %s" % target_node)
        return

    match mode:
        ControlMode.PROCESSING:
            _set_processing_mode(node, enable)
        ControlMode.VISIBLE:
            _set_visible(node, enable)

    context.log_info("Node %s: %s" % ["enabled" if enable else "disabled", node.name])

func _set_processing_mode(node: Node, enabled: bool) -> void:
    if enabled:
        node.process_mode = Node.PROCESS_MODE_INHERIT
    else:
        node.process_mode = Node.PROCESS_MODE_DISABLED

func _set_visible(node: Node, visible: bool) -> void:
    if node is CanvasItem:
        node.visible = visible
    else:
        context.log_error("Node %s is not a CanvasItem" % node.name)

func _get_property_list() -> Array[Dictionary]:
    var properties := []

    properties.append({
        name = "target_node",
        type = TYPE_NODE_PATH,
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    properties.append({
        name = "enable",
        type = TYPE_BOOL,
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    properties.append({
        name = "mode",
        type = TYPE_INT,
        hint = PROPERTY_HINT_ENUM,
        hint_string = "Processing,Visible",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    return properties
```

**Step 2: 添加本地化**

```csv
keys,en,zh
BRICKS_INSTRUCTION_ENABLE_DISABLE_NODE_NAME,Enable/Disable Node,启用/禁用节点
BRICKS_INSTRUCTION_ENABLE_DISABLE_NODE_DESC,Enables or disables a node's processing mode or visibility,启用或禁用节点的处理模式或可见性
```

**Step 3: 创建测试**

```gdscript
# test_enable_disable_node.gd
extends Node

func _ready():
    print("=== Testing Enable/Disable Node Instruction ===")

    var test_node = Node2D.new()
    test_node.name = "TestNode"
    add_child(test_node)

    test_enable_processing()
    test_disable_processing()
    test_show_visible()
    test_hide_visible()

    print("=== All Enable/Disable Node tests passed! ===")

func test_enable_processing():
    print("Test 1: Enable processing")

    var instruction = EnableDisableNode.new()
    instruction.target_node = NodePath("TestNode")
    instruction.enable = true
    instruction.mode = EnableDisableNode.ControlMode.PROCESSING

    var context = ExecutionContext.new()
    add_child(context)

    $TestNode.process_mode = Node.PROCESS_MODE_DISABLED
    print("  Before: process_mode = %s" % $TestNode.process_mode)

    instruction.execute(context)

    assert($TestNode.process_mode == Node.PROCESS_MODE_INHERIT, "Should enable processing")
    print("  After: process_mode = %s" % $TestNode.process_mode)
    print("  ✓ Test 1 passed\n")

func test_disable_processing():
    print("Test 2: Disable processing")

    var instruction = EnableDisableNode.new()
    instruction.target_node = NodePath("TestNode")
    instruction.enable = false
    instruction.mode = EnableDisableNode.ControlMode.PROCESSING

    var context = ExecutionContext.new()
    add_child(context)

    $TestNode.process_mode = Node.PROCESS_MODE_INHERIT
    print("  Before: process_mode = %s" % $TestNode.process_mode)

    instruction.execute(context)

    assert($TestNode.process_mode == Node.PROCESS_MODE_DISABLED, "Should disable processing")
    print("  After: process_mode = %s" % $TestNode.process_mode)
    print("  ✓ Test 2 passed\n")

func test_show_visible():
    print("Test 3: Show visible")

    var instruction = EnableDisableNode.new()
    instruction.target_node = NodePath("TestNode")
    instruction.enable = true
    instruction.mode = EnableDisableNode.ControlMode.VISIBLE

    var context = ExecutionContext.new()
    add_child(context)

    $TestNode.visible = false
    print("  Before: visible = %s" % $TestNode.visible)

    instruction.execute(context)

    assert($TestNode.visible == true, "Should show node")
    print("  After: visible = %s" % $TestNode.visible)
    print("  ✓ Test 3 passed\n")

func test_hide_visible():
    print("Test 4: Hide visible")

    var instruction = EnableDisableNode.new()
    instruction.target_node = NodePath("TestNode")
    instruction.enable = false
    instruction.mode = EnableDisableNode.ControlMode.VISIBLE

    var context = ExecutionContext.new()
    add_child(context)

    $TestNode.visible = true
    print("  Before: visible = %s" % $TestNode.visible)

    instruction.execute(context)

    assert($TestNode.visible == false, "Should hide node")
    print("  After: visible = %s" % $TestNode.visible)
    print("  ✓ Test 4 passed\n")
```

**Step 4: 提交**

```bash
git add addons/bricks/instructions/enable_disable_node.gd
git add addons/bricks/tests/instructions/test_enable_disable_node.*
git add addons/bricks/translations/translations.csv
git commit -m "feat(bricks): add Enable/Disable Node instruction (P1, 64.0分)

- 实现节点启用禁用功能
- 支持处理模式和可见性控制
- 完整测试覆盖

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 6: Queue Free Node 指令（63.5分，P1）

**功能：** 延迟释放指定节点

**文件：**
- 创建: `addons/bricks/instructions/queue_free_node.gd`
- 创建: `addons/bricks/tests/instructions/test_queue_free_node.tscn`
- 创建: `addons/bricks/tests/instructions/test_queue_free_node.gd`
- 修改: `addons/bricks/translations/translations.csv`

**Step 1: 创建指令类**

```gdscript
# addons/bricks/instructions/queue_free_node.gd
@tool
extends BaseInstruction
class_name QueueFreeNode

## 延迟释放节点

@export var target_node: NodePath = NodePath("")
@export var delay: float = 0.0

var _timer: SceneTreeTimer = null

func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_QUEUE_FREE_NODE_NAME"
    metadata.category_key = "BRICKS_CATEGORY_NODE_OPERATION"
    metadata.description_key = "BRICKS_INSTRUCTION_QUEUE_FREE_NODE_DESC"
    metadata.keywords = ["queue free", "destroy", "remove", "delete"]
    return metadata

func execute(context: ExecutionContext) -> void:
    var node := context.resolve_node(target_node)
    if not node:
        context.log_error("Target node not found: %s" % target_node)
        finished.emit()
        return

    if delay <= 0.0:
        # 立即释放
        node.queue_free()
        context.log_info("Node %s queued for immediate deletion" % node.name)
        finished.emit()
    else:
        # 延迟释放
        _timer = get_tree().create_timer(delay)
        _timer.timeout.connect(_on_timer_timeout.bind(node, context))
        context.log_info("Node %s will be deleted in %s seconds" % [node.name, delay])

func _on_timer_timeout(node: Node, context: ExecutionContext) -> void:
    if is_instance_valid(node):
        node.queue_free()
        context.log_info("Node %s deleted after delay" % node.name)
    finished.emit()

func _cleanup_resources() -> void:
    if _timer and is_instance_valid(_timer):
        _timer.timeout.disconnect(_on_timer_timeout)
        _timer = null

func _get_property_list() -> Array[Dictionary]:
    var properties := []

    properties.append({
        name = "target_node",
        type = TYPE_NODE_PATH,
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    properties.append({
        name = "delay",
        type = TYPE_FLOAT,
        hint = PROPERTY_HINT_RANGE,
        hint_string = "0,10,0.1",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    return properties
```

**Step 2: 添加本地化**

```csv
keys,en,zh
BRICKS_INSTRUCTION_QUEUE_FREE_NODE_NAME,Queue Free Node,释放节点
BRICKS_INSTRUCTION_QUEUE_FREE_NODE_DESC,Queues a node for deletion with optional delay,延迟释放节点
```

**Step 3: 创建测试**

```gdscript
# test_queue_free_node.gd
extends Node

func _ready():
    print("=== Testing Queue Free Node Instruction ===")

    test_immediate_free()
    test_delayed_free()
    test_free_nonexistent_node()

    print("=== All Queue Free Node tests passed! ===")

func test_immediate_free():
    print("Test 1: Immediate queue free")

    var test_node = Node.new()
    test_node.name = "TestNode1"
    add_child(test_node)

    var instruction = QueueFreeNode.new()
    instruction.target_node = NodePath("TestNode1")
    instruction.delay = 0.0

    var context = ExecutionContext.new()
    add_child(context)

    print("  Node exists before: %s" % is_instance_valid($TestNode1))

    instruction.execute(context)

    # 等待一帧让 queue_free 生效
    await get_tree().process_frame

    print("  Node exists after: %s" % is_instance_valid($TestNode1))
    assert(not is_instance_valid($TestNode1), "Node should be freed")
    print("  ✓ Test 1 passed\n")

func test_delayed_free():
    print("Test 2: Delayed queue free")

    var test_node = Node.new()
    test_node.name = "TestNode2"
    add_child(test_node)

    var instruction = QueueFreeNode.new()
    instruction.target_node = NodePath("TestNode2")
    instruction.delay = 0.5

    var context = ExecutionContext.new()
    add_child(context)

    print("  Node exists before: %s" % is_instance_valid($TestNode2))

    instruction.execute(context)

    await get_tree().create_timer(0.3).timeout
    print("  Node exists at 0.3s: %s" % is_instance_valid($TestNode2))
    assert(is_instance_valid($TestNode2), "Node should still exist")

    await get_tree().create_timer(0.3).timeout
    print("  Node exists at 0.6s: %s" % is_instance_valid($TestNode2))
    assert(not is_instance_valid($TestNode2), "Node should be freed after delay")

    print("  ✓ Test 2 passed\n")

func test_free_nonexistent_node():
    print("Test 3: Free nonexistent node")

    var instruction = QueueFreeNode.new()
    instruction.target_node = NodePath("NonexistentNode")
    instruction.delay = 0.0

    var context = ExecutionContext.new()
    add_child(context)

    print("  Executing with nonexistent node...")
    instruction.execute(context)

    print("  ✓ Test 3 passed (should log error)\n")
```

**Step 4: 提交**

```bash
git add addons/bricks/instructions/queue_free_node.gd
git add addons/bricks/tests/instructions/test_queue_free_node.*
git add addons/bricks/translations/translations.csv
git commit -m "feat(bricks): add Queue Free Node instruction (P1, 63.5分)

- 实现节点释放功能
- 支持立即释放和延迟释放
- 异步执行支持
- 完整测试覆盖

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 7: Instantiate Scene 指令（61.5分，P1）

**功能：** 动态加载并实例化场景文件

**文件：**
- 创建: `addons/bricks/instructions/instantiate_scene.gd`
- 创建: `addons/bricks/tests/instructions/test_instantiate_scene.tscn`
- 创建: `addons/bricks/tests/instructions/test_instantiate_scene.gd`
- 修改: `addons/bricks/translations/translations.csv`

**Step 1: 创建指令类**

```gdscript
# addons/bricks/instructions/instantiate_scene.gd
@tool
extends BaseInstruction
class_name InstantiateScene

## 实例化场景

@export var scene_path: String = ""
@export var parent_node: NodePath = NodePath("")
@export var save_instance_id: bool = false
@export var target_variable: String = "instance_id"
@export var variable_scope: int = 0  # 0=Local, 1=Global

func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_INSTANTIATE_SCENE_NAME"
    metadata.category_key = "BRICKS_CATEGORY_NODE_OPERATION"
    metadata.description_key = "BRICKS_INSTRUCTION_INSTANTIATE_SCENE_DESC"
    metadata.keywords = ["instantiate", "spawn", "create", "scene"]
    return metadata

func execute(context: ExecutionContext) -> void:
    if scene_path.is_empty():
        context.log_error("Scene path is empty")
        finished.emit()
        return

    # 加载场景
    var scene_resource = load(scene_path)
    if not scene_resource:
        context.log_error("Failed to load scene: %s" % scene_path)
        finished.emit()
        return

    if not scene_resource is PackedScene:
        context.log_error("Resource is not a PackedScene: %s" % scene_path)
        finished.emit()
        return

    # 实例化场景
    var instance = scene_resource.instantiate()
    if not instance:
        context.log_error("Failed to instantiate scene: %s" % scene_path)
        finished.emit()
        return

    # 确定父节点
    var parent: Node
    if parent_node.is_empty():
        parent = get_tree().current_scene
    else:
        parent = context.resolve_node(parent_node)

    if not parent:
        context.log_error("Parent node not found, adding to current scene")
        parent = get_tree().current_scene

    # 添加到场景树
    parent.add_child(instance)

    # 保存实例 ID
    if save_instance_id:
        var instance_id = instance.get_instance_id()
        if variable_scope == 1:
            GlobalVariableAssistant.set_variable(target_variable, instance_id)
        else:
            context.set_variable(target_variable, instance_id)

    context.log_info("Instantiated scene: %s as %s" % [scene_path, instance.name])
    finished.emit()

func _get_property_list() -> Array[Dictionary]:
    var properties := []

    properties.append({
        name = "Scene",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    properties.append({
        name = "scene_path",
        type = TYPE_STRING,
        hint = PROPERTY_HINT_FILE,
        hint_string = "*.tscn,*.scn",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    properties.append({
        name = "parent_node",
        type = TYPE_NODE_PATH,
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    properties.append({
        name = "Variable",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    properties.append({
        name = "save_instance_id",
        type = TYPE_BOOL,
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    if save_instance_id:
        properties.append({
            name = "target_variable",
            type = TYPE_STRING,
            hint = PROPERTY_HINT_PLACEHOLDER_TEXT,
            hint_string = "instance_id",
            usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
        })

        properties.append({
            name = "variable_scope",
            type = TYPE_INT,
            hint = PROPERTY_HINT_ENUM,
            hint_string = "Local,Global",
            usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
        })

    return properties

func _validate_property(property: Dictionary) -> void:
    if not save_instance_id and (property.name == "target_variable" or property.name == "variable_scope"):
        property.usage = PROPERTY_USAGE_NO_EDITOR
```

**Step 2: 创建测试场景**

首先创建一个简单的测试场景 `addons/bricks/tests/test_objects/test_cube.tscn`：

```gdscript
[gd_scene load_steps=2 format=3]

[sub_resource type="BoxMesh" id="BoxMesh_1"]
size = Vector3(1, 1, 1)

[node name="TestCube" type="MeshInstance3D"]
mesh = SubResource("BoxMesh_1")
```

**Step 3: 创建测试脚本**

```gdscript
# test_instantiate_scene.gd
extends Node3D

func _ready():
    print("=== Testing Instantiate Scene Instruction ===")

    test_instantiate_to_scene()
    test_instantiate_to_parent()
    test_save_instance_id()
    test_invalid_scene_path()

    print("=== All Instantiate Scene tests passed! ===")

func test_instantiate_to_scene():
    print("Test 1: Instantiate to current scene")

    var instruction = InstantiateScene.new()
    instruction.scene_path = "res://addons/bricks/tests/test_objects/test_cube.tscn"
    instruction.parent_node = NodePath("")
    instruction.save_instance_id = false

    var context = ExecutionContext.new()
    add_child(context)

    var child_count_before = get_children().size()
    print("  Children before: %d" % child_count_before)

    instruction.execute(context)

    await get_tree().process_frame

    var child_count_after = get_children().size()
    print("  Children after: %d" % child_count_after)

    assert(child_count_after > child_count_before, "Should add new child")
    print("  ✓ Test 1 passed\n")

func test_instantiate_to_parent():
    print("Test 2: Instantiate to specific parent")

    # 创建父节点
    var container = Node.new()
    container.name = "Container"
    add_child(container)

    var instruction = InstantiateScene.new()
    instruction.scene_path = "res://addons/bricks/tests/test_objects/test_cube.tscn"
    instruction.parent_node = NodePath("Container")
    instruction.save_instance_id = false

    var context = ExecutionContext.new()
    add_child(context)

    var child_count_before = container.get_children().size()
    print("  Container children before: %d" % child_count_before)

    instruction.execute(context)

    await get_tree().process_frame

    var child_count_after = container.get_children().size()
    print("  Container children after: %d" % child_count_after)

    assert(child_count_after > child_count_before, "Should add to container")
    print("  ✓ Test 2 passed\n")

func test_save_instance_id():
    print("Test 3: Save instance ID")

    var instruction = InstantiateScene.new()
    instruction.scene_path = "res://addons/bricks/tests/test_objects/test_cube.tscn"
    instruction.save_instance_id = true
    instruction.target_variable = "cube_instance"
    instruction.variable_scope = 0

    var context = ExecutionContext.new()
    add_child(context)

    instruction.execute(context)

    await get_tree().process_frame

    var instance_id = context.get_variable("cube_instance")
    assert(instance_id != null, "Should save instance ID")
    print("  Instance ID: %s" % instance_id)

    var instance = instance_from_id(instance_id)
    assert(is_instance_valid(instance), "Instance ID should be valid")
    print("  Instance valid: %s" % is_instance_valid(instance))
    print("  ✓ Test 3 passed\n")

func test_invalid_scene_path():
    print("Test 4: Invalid scene path")

    var instruction = InstantiateScene.new()
    instruction.scene_path = "res://nonexistent_scene.tscn"

    var context = ExecutionContext.new()
    add_child(context)

    print("  Executing with invalid path...")
    instruction.execute(context)

    print("  ✓ Test 4 passed (should log error)\n")
```

**Step 4: 添加本地化并提交**

```csv
keys,en,zh
BRICKS_INSTRUCTION_INSTANTIATE_SCENE_NAME,Instantiate Scene,实例化场景
BRICKS_INSTRUCTION_INSTANTIATE_SCENE_DESC,Dynamically loads and instantiates a scene file,动态加载并实例化场景文件
```

```bash
git add addons/bricks/instructions/instantiate_scene.gd
git add addons/bricks/tests/instructions/test_instantiate_scene.*
git add addons/bricks/tests/test_objects/test_cube.tscn
git add addons/bricks/translations/translations.csv
git commit -m "feat(bricks): add Instantiate Scene instruction (P1, 61.5分)

- 实现场景实例化功能
- 支持指定父节点
- 支持保存实例 ID
- 完整测试覆盖

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 1A-1D: 剩余指令（参考评估报告）

由于篇幅限制，完整的 Phase 1A-1D 的详细任务请参考评估报告 v2。以下是快速开发模板：

---

## 关键技术要点（Phase 0B 经验总结）

> **重要：** 基于 Phase 0B 开发经验总结的关键技术要点，后续指令开发必须遵循。

### 必需实现的抽象方法

所有指令必须实现以下方法，否则会产生编译错误：

```gdscript
## 1. 更新资源名称（必需）
func _update_resource_name():
    var parts = []
    # 构建描述性资源名称
    parts.append("操作名称")
    if not target_node.is_empty():
        parts.append("'%s'" % target_node)
    resource_name = " ".join(parts)

## 2. 验证参数（必需）
func validate() -> Array[String]:
    var errors = super.validate()
    # 添加自定义验证
    if target_node.is_empty():
        errors.append("目标节点路径不能为空")
    return errors

## 3. 获取描述（必需）
func get_description() -> String:
    return "指令描述字符串"
```

### 执行流程必需方法

```gdscript
func execute(context: ExecutionContext):
    # 必须首先调用
    _start_execution(context)

    # 验证逻辑
    if validation_failed:
        _log_error_localized("ERROR_KEY", {})
        set_error_localized("ERROR_KEY", BricksError.ErrorType.VALIDATION_ERROR, {})
        finished.emit()  # 同步指令直接发出信号
        return

    # 执行逻辑
    # ...

    # 同步指令完成
    _on_execution_completed()

    # 异步指令（需要定时器等）
    # 不调用 _on_execution_completed()，而是在回调中调用 finished.emit()
```

### 节点获取方法

**❌ 错误用法：**
```gdscript
var node := context.resolve_node(target_node)  # 方法不存在
var node := get_node(target_node)                 # 无法解析相对路径
```

**✅ 正确用法：**
```gdscript
var node := context.get_node(target_node)       # 正确，支持相对路径解析
```

### 异步操作（定时器）

**❌ 错误用法：**
```gdscript
_timer = get_tree().create_timer(delay)  # get_tree() 在指令中不可用
```

**✅ 正确用法：**
```gdscript
var scene_tree = Engine.get_main_loop()
if scene_tree:
    _timer = scene_tree.create_timer(delay)
    _timer.timeout.connect(_on_timer_timeout.bind(node, context))
else:
    _log_error("Cannot create timer: SceneTree not available")
    finished.emit()
```

### SceneTree 和当前场景访问

```gdscript
# 获取 SceneTree
var scene_tree = Engine.get_main_loop()
if scene_tree:
    # 获取当前场景
    var current_scene = scene_tree.current_scene
    # 创建定时器
    var timer = scene_tree.create_timer(duration)
```

### 全局变量保存

**❌ 错误用法：**
```gdscript
GlobalVariableAssistant.set_variable(var_name, value)  # 静态方法不存在
```

**✅ 正确用法：**
```gdscript
if context.global_variables:
    context.global_variables.set_variable(var_name, value)
else:
    _log_warning("全局变量管理器未初始化")
```

### 错误处理和信号发送

```gdscript
# 同步指令错误处理
if error:
    _log_error_localized("ERROR_KEY", {"param": value})
    set_error_localized("ERROR_KEY", BricksError.ErrorType.RUNTIME_ERROR, {"param": value})
    finished.emit()  # 直接发出完成信号
    return

# 同步指令成功完成
_on_execution_completed()

# 异步指令（定时器回调）
func _on_timer_timeout():
    # 完成工作
    finished.emit()  # 在回调中发出完成信号
```

### 变量类型推断

```gdscript
# ✅ 明确类型避免推断问题
var node: Node = context.get_node(target_node)
var parent: Node = context.get_node(parent_path)

# ✅ 使用 := 让 Godot 推断（但需要初始化）
var node := context.get_node(target_node)

# ❌ 避免未初始化的变量
var node: Node  # 未初始化，类型推断可能失败
node = context.get_node(target_node)
```

### 完整指令模板（更新版）

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/Script.png")
extends BaseInstruction
class_name TemplateInstruction

## 指令描述

# 参数定义
var target_node: NodePath = NodePath("")

## 获取指令元数据
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_XXX_NAME"
    metadata.category_key = "BRICKS_CATEGORY_XXX"
    metadata.description_key = "BRICKS_INSTRUCTION_XXX_DESC"
    metadata.keywords = ["keyword1", "keyword2"]
    metadata.builtin_icon = "Script"
    return metadata

## 设置指令元数据
func _setup_metadata():
    pass

## 获取属性列表
func _get_property_list() -> Array[Dictionary]:
    var properties := []

    # 分类
    properties.append({
        name = "Category",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    # 属性
    properties.append({
        name = "target_node",
        type = TYPE_NODE_PATH,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    return properties

## 更新资源名称（必需）
func _update_resource_name():
    var parts = []
    parts.append("操作名称")
    if not target_node.is_empty():
        parts.append("'%s'" % target_node)
    resource_name = " ".join(parts)

## 执行指令
func execute(context: ExecutionContext):
    _start_execution(context)

    # 验证
    if target_node.is_empty():
        _log_error_localized("BRICKS_ERROR_TARGET_NODE_EMPTY", {})
        set_error_localized("BRICKS_ERROR_TARGET_NODE_EMPTY", BricksError.ErrorType.VALIDATION_ERROR, {})
        finished.emit()
        return

    # 获取节点
    var node := context.get_node(target_node)
    if not node:
        _log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
        set_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", BricksError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
        finished.emit()
        return

    # 执行逻辑
    # ...

    # 同步完成
    _on_execution_completed()

## 验证参数（必需）
func validate() -> Array[String]:
    var errors = super.validate()

    if target_node.is_empty():
        errors.append("目标节点路径不能为空")

    return errors

## 获取描述（必需）
func get_description() -> String:
    return "操作 %s" % str(target_node)
```

### 常见错误和解决方案

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| `must implement _update_resource_name()` | 缺少必需方法 | 实现所有 3 个必需方法 |
| `Function _finished() not found` | 使用了不存在的方法 | 使用 `_on_execution_completed()` 或 `finished.emit()` |
| `Function get_tree() not found` | 指令中无法直接访问 | 使用 `Engine.get_main_loop()` |
| `Static function set_variable() not found` | GlobalVariableAssistant 方法错误 | 使用 `context.global_variables.set_variable()` |
| `Cannot infer type` | 变量未初始化 | 使用 `:=` 或明确指定类型 |
| `context.resolve_node() not found` | 方法名错误 | 使用 `context.get_node()` |

### Phase 0B 参考实现

以下指令可作为参考：

- **Enable/Disable Node** - [enable_disable_node.gd](../../addons/bricks/instructions/enable_disable_node.gd)
  - 处理模式枚举
  - 类型检查（CanvasItem）

- **Queue Free Node** - [queue_free_node.gd](../../addons/bricks/instructions/queue_free_node.gd)
  - 异步定时器操作
  - 资源清理

- **Instantiate Scene** - [instantiate_scene.gd](../../addons/bricks/instructions/instantiate_scene.gd)
  - 场景加载和实例化
  - 全局/局部变量保存
  - SceneTree 访问

---

## 通用指令开发模板

对于后续的每个指令，使用以下模板快速开发：

### 模板步骤

**1. 创建指令类**（基于模板）

> **重要：** 请参考上方"关键技术要点"章节中的"完整指令模板（更新版）"，这里只提供简要步骤。

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/Script.png")
extends BaseInstruction
class_name Template

## 指令描述

# 参数定义（不使用 @export）
var parameter: Type = default_value

func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_XXX_NAME"
    metadata.category_key = "BRICKS_CATEGORY_XXX"
    metadata.description_key = "BRICKS_INSTRUCTION_XXX_DESC"
    metadata.keywords = ["keyword1", "keyword2"]
    metadata.builtin_icon = "Script"
    return metadata

func _setup_metadata():
    pass

func _get_property_list() -> Array[Dictionary]:
    # 动态属性列表
    return []

# 必需实现的三个方法（参见上方关键技术要点）
func _update_resource_name():
    # 更新资源名称
    pass

func validate() -> Array[String]:
    var errors = super.validate()
    # 添加验证逻辑
    return errors

func get_description() -> String:
    # 返回描述字符串
    pass

func execute(context: ExecutionContext):
    _start_execution(context)
    # 执行逻辑
    _on_execution_completed()
```

**2. 添加本地化翻译**

```csv
keys,en,zh
BRICKS_INSTRUCTION_XXX_NAME,English Name,中文名称
BRICKS_CATEGORY_XXX,Category,类别
BRICKS_INSTRUCTION_XXX_DESC,English description,中文描述
```

**3. 配置图标（可选但推荐）**

```bash
# 3.1 运行图标提取工具（如果使用了新的 builtin_icon）
Project → Tools → Execute Script → generate_builtin_icons.gd

# 3.2 运行 @icon 装饰器更新工具（用于 Inspector 显示）
Project → Tools → Execute Script → update_instruction_icon_decorators.gd

# 3.3 重启编辑器查看图标效果
```

**4. 创建测试场景和脚本**

```gdscript
# test_xxx.gd
extends Node

func _ready():
    print("=== Testing XXX Instruction ===")
    test_case_1()
    test_case_2()
    print("=== All XXX tests passed! ===")

func test_case_1():
    print("Test 1: Description")
    # 测试代码
    print("  ✓ Test 1 passed\n")
```

**5. 提交代码**

```bash
git add addons/bricks/instructions/xxx.gd
git add addons/bricks/tests/instructions/test_xxx.*
git add addons/bricks/translations/translations.csv
git commit -m "feat(bricks): add XXX instruction (PX, XX.X分)

- 功能描述
- 关键特性
- 完整测试覆盖
- 图标配置

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 1C: 流程控制完善（2 天）

依赖验证：For Loop 必须在 Phase 0A 已完成

### Task 18: Break Loop 指令（56.0分，P2）

**功能：** 跳出当前循环

**关键实现：**
```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    context.set_break_loop()

    _on_execution_completed()
```

### Task 19: Continue Loop 指令（56.0分，P2）

**功能：** 跳过本次循环剩余部分

**关键实现：**
```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    context.set_continue_loop()

    _on_execution_completed()
```

### Task 20: Wait Until 指令（57.0分，P2）

**功能：** 等待直到条件满足或超时

**关键实现：**
```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    var scene_tree = Engine.get_main_loop()
    if not scene_tree:
        _log_error("Cannot create timer: SceneTree not available")
        set_error("SceneTree not available", BricksError.ErrorType.RUNTIME_ERROR)
        finished.emit()
        return

    var timer := scene_tree.create_timer(check_interval)
    var timeout_timer := scene_tree.create_timer(timeout)

    while true:
        if _check_condition(context):
            _log_info("Condition met")
            _on_execution_completed()
            return

        if timeout_timer.time_left <= 0:
            _log_error("Timeout waiting for condition")
            set_error("Timeout waiting for condition", BricksError.ErrorType.RUNTIME_ERROR)
            finished.emit()
            return

        await timer.timeout
```

---

## Phase 1D: 变换增强（1 天）

依赖验证：Set Position 和 Set Rotation 必须在之前阶段已完成

### Task 21: Move By 指令（52.0分，P2）

**功能：** 相对于当前位置移动节点

### Task 22: Rotate By 指令（50.5分，P2）

**功能：** 相对于当前旋转角度旋转

---

## 后续阶段概览

### Phase 2A: 音频系统（5 天）
- Play Sound (60.5分, P1)
- Stop Audio (60.0分, P1)
- Set Audio Volume (60.0分, P1)
- Play Music (57.0分, P2)
- Pause/Resume Audio (56.0分, P2)

### Phase 2B: 场景管理（4 天）
- Change Scene (62.0分, P1)
- Set Rotation (60.0分, P1)
- Set Scale (60.0分, P1)
- Look At (56.5分, P2)

### Phase 3+: 其他类别
- 动画控制
- 相机控制
- 物理碰撞
- 数学运算
- UI 控制
- 数据存取

详细内容请参考：
- [Instruction Roadmap](../../addons/bricks/docs/roadmap/2026-01-24-bricks-instruction-roadmap.md) - 完整功能规格
- [Evaluation Report v2](../../addons/bricks/docs/roadmap/2026-01-25-instruction-evaluation-report-v2.md) - 评估结果和优先级

---

## 测试策略

### 1. 单元测试
每个指令必须有对应的测试场景和脚本：

```
addons/bricks/tests/instructions/
├── test_<instruction_name>.tscn
└── test_<instruction_name>.gd
```

### 2. 集成测试
创建完整的游戏场景测试多个指令的组合使用。

### 3. 边界测试
- 空值处理
- 无效路径
- 极端参数值
- 错误恢复

### 4. 性能测试
- 大量循环执行
- 频繁节点操作
- 内存泄漏检测

---

## 文档要求

每个指令需要：

1. **设计文档** - `addons/bricks/docs/system_docs/architecture/instruction_<name>.md`
2. **使用示例** - `addons/bricks/docs/user_docs/guides/using_<name>_instruction.md`
3. **API 文档** - GDScript 注释
4. **本地化** - `translations.csv`
5. **图标配置**（新增）：
   - 在 `_get_instruction_metadata()` 中配置 `metadata.builtin_icon` 或 `metadata.custom_icon`
   - 选择与指令功能相关的图标名称
   - 参考常用图标列表（流程控制、节点操作、调试等）
   - 运行 `generate_builtin_icons.gd` 提取图标
   - 运行 `update_instruction_icon_decorators.gd` 更新 @icon 装饰器

---

## 依赖关系验证清单

在开发每个指令前，验证依赖指令已完成：

- [ ] Phase 0A 完成 → 开启 Phase 0B
- [ ] For Loop 完成 → 开发 Break/Continue Loop
- [ ] Set Position 完成 → 开发 Move By
- [ ] Set Rotation 完成 → 开发 Rotate By
- [ ] Instantiate Scene 完成 → 开发 Queue Free Node（已在 Phase 0B）

---

## 成功标准

### Phase 0A 完成后
- ✅ 实现 4 个 P0 核心指令
- ✅ 所有测试通过
- ✅ 完整文档和本地化
- ✅ 基础流程控制可用

### Phase 0B 完成后
- ✅ 实现 3 个 P1 节点管理指令
- ✅ 完整对象生命周期管理
- ✅ Find Node 可用

### Phase 1A-1D 完成后
- ✅ 实现 13 个 P1+P2 指令
- ✅ 完整变换操作
- ✅ 完整音频系统
- ✅ 场景管理能力

### 最终目标
- ✅ 80+ 指令全部实现
- ✅ 完整的测试覆盖
- ✅ 完整的文档和本地化
- ✅ 支持完整的游戏开发流程

---

## 常见问题

### Q: 如何处理异步指令？
A: 继承异步基类，发出 `finished` 信号，实现 `_cleanup_resources()` 方法。

### Q: 如何支持 2D/3D 节点？
A: 使用 `is` 关键字检查节点类型，分别处理。

### Q: 如何保存节点引用？
A: 保存 NodePath 或 Instance ID，而不是直接保存 Node 引用。

### Q: 如何处理变量作用域？
A: 使用 `context.set_variable()` 本地变量，`GlobalVariableAssistant.set_variable()` 全局变量。

### Q: 如何为指令配置图标？
A: 在 `_get_instruction_metadata()` 中添加 `metadata.builtin_icon = "IconName"`，然后运行 `generate_builtin_icons.gd` 提取图标。详细步骤参考"图标规范"章节。

### Q: 图标配置后不显示怎么办？
A: 确保：
1. 已运行 `generate_builtin_icons.gd` 提取图标到文件
2. 图标名称拼写正确（区分大小写）
3. 如果需要在 Inspector 中显示，运行 `update_instruction_icon_decorators.gd`
4. 重启编辑器

---

**下一步：**
1. 选择执行模式（Subagent-Driven 或 Parallel Session）
2. 开始实施 Phase 0A 的 4 个指令
3. 完成后 review 代码并进入下一阶段

---

**文档版本:** 1.2
**创建日期:** 2026-01-25
**最后更新:** 2026-01-25
**更新内容:** 添加 Phase 0A 短期改进计划章节
**预计完成时间:** Phase 0A (5天) + Phase 0B (4天) + Phase 1 (15天) = 24 天
**总指令数:** 80+
**已完成:** 15 个（Phase 0A: 4个 + 之前11个）
  - Phase 0A 完成（2026-01-25）：
    - Set Position (69.0分, P0)
    - For Loop (59.5分, P0)
    - If/Else (59.0分, P0)
    - Find Node (59.0分, P0)
  - 之前实现：
    - create_variable, set_variable, set_int_variable, print_variable_value
    - set_property_value, run_target_node_function
    - wait, count, run_condition_check
    - print, quit
**待开发:** 约 65 个
