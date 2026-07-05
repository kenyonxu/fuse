# Bricks Array 操作指令实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
>
> ⚠️ **必读文档**: 开始开发前，请务必阅读 [array-instructions-development.md](addons/bricks/docs/dev_docs/array-instructions-development.md)，其中包含：
> - `element_value` 属性定义的正确方式
> - 变量变化通知（GLOBAL 和 SCOPE）
> - 翻译键命名规范
> - 调试日志最佳实践
> - 指令分类（修改数组 vs 只读操作）

**Goal:** 为 Bricks 可视化编程系统添加 19 个 Array 操作指令和条件，构建完整的数组操作能力

**Architecture:** 基于现有 ForEach 和 VariableOperations 架构，支持三层作用域（LOCAL/SCOPE/GLOBAL），采用混合 Array 来源方案（VARIABLE/NODE_CHILDREN/NODE_GROUP），使用 @tool 和动态属性列表实现可视化编辑

**Tech Stack:** Godot 4.6, GDScript 2.0, BaseInstruction, BaseCondition, VariableOperations

---

## 📋 进度概览

| 阶段 | 任务 | 状态 |
|------|------|------|
| Phase 1: 核心操作 | Task 1: ArrayAdd | ✅ 已完成 |
| Phase 1: 核心操作 | Task 2: ArrayRemove | ✅ 已完成 |
| Phase 1: 核心操作 | Task 3: ArrayGet | ✅ 已完成 |
| Phase 1: 核心操作 | Task 4: ArraySet | ✅ 已完成 |
| Phase 1: 核心操作 | Task 5: ArrayClear | ✅ 已完成 |
| Phase 1: 核心操作 | Task 6: ArraySize | ✅ 已完成 |
| Phase 2: 查询搜索 | Task 7: ArrayFind | ✅ 已完成 |
| Phase 2: 查询搜索 | Task 8: ArrayContains | ✅ 已完成 |
| Phase 2: 查询搜索 | Task 9: ArrayRandom | ✅ 已完成 |
| Phase 3: 高级操作 | Task 10: ArrayInsert | ✅ 已完成 |
| Phase 3: 高级操作 | Task 11: ArraySlice | ⏳ 待开发 |
| Phase 3: 高级操作 | Task 12: ArrayMerge | ⏳ 待开发 |
| Phase 3: 高级操作 | Task 13: ArrayReverse | ✅ 已完成 |
| Phase 3: 高级操作 | Task 14: ArrayShuffle | ✅ 已完成 |
| Phase 4: 创建转换 | Task 15: ArrayCreate | ⏳ 待开发 |
| Phase 4: 创建转换 | Task 16: ArrayFromNodes | ⏳ 待开发 |
| Phase 5: 条件 | Task 17: CheckArraySize | ✅ 已完成 |
| Phase 5: 条件 | Task 18: CheckArrayContains | ✅ 已完成 |
| Phase 5: 条件 | Task 19: CheckArrayEmpty | ⏳ 待开发 |
| Phase 6: 收尾 | Task 20: 本地化 | ⏳ 待开发 |
| Phase 6: 收尾 | Task 21: 注册指令 | ⏳ 待开发 |

---

## 概述

本计划为 Bricks 可视化编程系统实现数组操作能力，包含：
- **16 个指令 (Instructions)**: 核心操作、查询搜索、高级操作、创建转换
- **3 个条件 (Conditions)**: 数组大小检查、包含检查、空检查
- **支持三层变量作用域**: LOCAL / SCOPE / GLOBAL
- **支持三种数组来源**: 变量、子节点、节点组

### 架构参考

参考现有实现：
- `addons/bricks/instructions/flow_control/for_each.gd` - 数组/节点组遍历
- `addons/bricks/instructions/variables/get_scope_variable.gd` - 变量读取
- `addons/bricks/instructions/variables/set_scope_variable.gd` - 变量写入
- `addons/bricks/core/utils/variable_operations.gd` - 统一变量访问 API
- `addons/bricks/core/base/base_condition.gd` - 条件基类

### Array 来源类型

```gdscript
enum ArraySource {
    VARIABLE,       # 从三层作用域变量获取
    NODE_CHILDREN,  # 从节点子节点获取
    NODE_GROUP      # 从节点组获取
}
```

---

## Phase 1: 核心数组操作指令 (6 个)

### Task 1: ArrayAdd - 向数组末尾添加元素 ✅ 已完成

**Files:**
- Create: `addons/bricks/instructions/arrays/array_add.gd`
- Test: `addons/bricks/tests/instructions/test_array_add.gd`

**Step 1: 创建测试文件**

```gdscript
# addons/bricks/tests/instructions/test_array_add.gd
extends GutTest

var array_add: ArrayAdd
var mock_context: ExecutionContext

func before_each():
    array_add = ArrayAdd.new()
    mock_context = ExecutionContext.new()

func test_array_add_pushes_element():
    # 设置数组变量
    VariableOperations.set_variable(mock_context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

    # 配置指令
    array_add.array_variable = "my_array"
    array_add.array_scope = BaseVariable.VariableScope.LOCAL
    array_add.element_value = 4

    # 执行
    array_add.execute(mock_context)
    await array_add.finished

    # 验证
    var result = VariableOperations.get_variable(mock_context, "my_array", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, [1, 2, 3, 4], "Element should be pushed to array")

func test_array_add_creates_array_if_not_exists():
    array_add.array_variable = "new_array"
    array_add.array_scope = BaseVariable.VariableScope.LOCAL
    array_add.element_value = 1

    array_add.execute(mock_context)
    await array_add.finished

    var result = VariableOperations.get_variable(mock_context, "new_array", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, [1], "New array should be created with element")
```

**Step 2: 运行测试验证失败**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: FAIL - file not found

**Step 3: 创建 ArrayAdd 指令**

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/Array.png")
extends BaseInstruction
class_name ArrayAdd

## Array Add 指令
##
## 向数组末尾添加元素（push_back）

## 源类型
enum SourceType {
    VARIABLE,       # 从变量获取
    NODE_CHILDREN,  # 从节点子节点获取
    NODE_GROUP      # 从节点组获取
}

var source_type: SourceType = SourceType.VARIABLE

# 数组变量名
var array_variable: String = ""

# 数组变量作用域
@export var array_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
    set(value):
        array_scope = value
        _update_resource_name()

# 节点组名（NODE_GROUP 使用）
var group_name: String = ""

# 要添加的元素
var element_value: Variant = null

# 节点路径（NODE_CHILDREN 使用）
var target_node_path: NodePath = NodePath("")

## 作用域来源枚举
enum ScopeSource {
    NEAREST,
    CUSTOM_ID,
    TRIGGER_SCOPE,
    TARGET_NODE
}

var array_scope_source: ScopeSource = ScopeSource.NEAREST
var array_custom_scope_id: String = ""
var array_target_node_path: NodePath = NodePath("")

static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_ARRAY_ADD_NAME"
    metadata.category_key = "BRICKS_CATEGORY_ARRAYS"
    metadata.description_key = "BRICKS_INSTRUCTION_ARRAY_ADD_DESC"
    metadata.keywords = ["array", "add", "push", "元素", "添加"]
    metadata.builtin_icon = "Array"
    return metadata

func _setup_metadata():
    pass

func _get_property_list() -> Array[Dictionary]:
    var properties := []

    properties.append({
        name = "Source",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    properties.append({
        name = "source_type",
        type = TYPE_INT,
        hint = PROPERTY_HINT_ENUM,
        hint_string = "Variable,NodeChildren,NodeGroup",
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    # Variable 配置
    if source_type == SourceType.VARIABLE:
        properties.append({
            name = "array_variable",
            type = TYPE_STRING,
            usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
        })

        properties.append({
            name = "array_scope",
            type = TYPE_INT,
            hint = PROPERTY_HINT_ENUM,
            hint_string = "Local,Scope,Global",
            usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
        })

        # SCOPE 额外配置
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
                    usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
                })
            elif array_scope_source == ScopeSource.TARGET_NODE:
                properties.append({
                    name = "array_target_node_path",
                    type = TYPE_NODE_PATH,
                    usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
                })

    # NodeGroup 配置
    if source_type == SourceType.NODE_GROUP:
        properties.append({
            name = "group_name",
            type = TYPE_STRING,
            usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
        })

    # NodeChildren 配置
    if source_type == SourceType.NODE_CHILDREN:
        properties.append({
            name = "target_node_path",
            type = TYPE_NODE_PATH,
            usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
        })

    # Element 配置
    properties.append({
        name = "Element",
        type = TYPE_NIL,
        hint = PROPERTY_HINT_NONE,
        usage = PROPERTY_USAGE_CATEGORY
    })

    properties.append({
        name = "element_value",
        type = TYPE_VARIANT,
        usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
    })

    return properties

func _update_resource_name():
    var source_str := ""
    match source_type:
        SourceType.VARIABLE:
            source_str = array_variable if not array_variable.is_empty() else "No Variable"
        SourceType.NODE_GROUP:
            source_str = group_name if not group_name.is_empty() else "No Group"
        SourceType.NODE_CHILDREN:
            source_str = "Children"

    var elem_str = str(element_value) if element_value != null else "null"
    resource_name = "ArrayAdd: %s + %s" % [source_str, elem_str]

func _set(property: StringName, value: Variant) -> bool:
    if property == "source_type":
        source_type = value
        notify_property_list_changed()
        _update_resource_name()
        return true
    if property == "element_value":
        element_value = value
        _update_resource_name()
        return false
    return false

func execute(context: ExecutionContext):
    _start_execution(context)

    var array_ref: Array = []

    match source_type:
        SourceType.VARIABLE:
            if array_variable.is_empty():
                set_error_localized("BRICKS_ERROR_ARRAY_VARIABLE_EMPTY")
                finished.emit()
                return

            array_ref = _get_array_from_variable(context)
            if array_ref == null:
                array_ref = []

        SourceType.NODE_GROUP:
            if group_name.is_empty():
                set_error_localized("BRICKS_ERROR_GROUP_NAME_EMPTY")
                finished.emit()
                return
            var node_tree = context.get_node_tree()
            if node_tree:
                var nodes = node_tree.get_nodes_in_group(group_name)
                array_ref = nodes
            else:
                array_ref = []

        SourceType.NODE_CHILDREN:
            var node = context.get_node(target_node_path)
            if node:
                array_ref = node.get_children()
            else:
                array_ref = []

    # 添加元素
    array_ref.push_back(element_value)

    # 保存回变量（如果是 VARIABLE 模式）
    if source_type == SourceType.VARIABLE:
        _save_array_to_variable(context, array_ref)

    _log_info("Added element to array: %s" % str(element_value))
    _on_execution_completed()

func _get_array_from_variable(context: ExecutionContext) -> Array:
    var value = null
    match array_scope:
        BaseVariable.VariableScope.LOCAL:
            value = VariableOperations.get_variable(context, array_variable, BaseVariable.VariableScope.LOCAL, null)
        BaseVariable.VariableScope.SCOPE:
            if array_scope_source == ScopeSource.NEAREST:
                value = VariableOperations.get_variable(context, array_variable, BaseVariable.VariableScope.SCOPE, null)
            else:
                var scope_container = VariableScopeUtils.get_scope_container_by_source(
                    context,
                    array_scope_source as VariableScopeUtils.ScopeSource,
                    array_custom_scope_id,
                    array_target_node_path
                )
                if scope_container:
                    value = scope_container.get_variable(array_variable, null)
        BaseVariable.VariableScope.GLOBAL:
            value = VariableOperations.get_variable(context, array_variable, BaseVariable.VariableScope.GLOBAL, null)

    if value is Array:
        return value
    return null

func _save_array_to_variable(context: ExecutionContext, array_ref: Array):
    match array_scope:
        BaseVariable.VariableScope.LOCAL:
            VariableOperations.set_variable(context, array_variable, BaseVariable.VariableScope.LOCAL, array_ref)
        BaseVariable.VariableScope.SCOPE:
            if array_scope_source == ScopeSource.NEAREST:
                VariableOperations.set_variable(context, array_variable, BaseVariable.VariableScope.SCOPE, array_ref)
            else:
                var scope_container = VariableScopeUtils.get_scope_container_by_source(
                    context,
                    array_scope_source as VariableScopeUtils.ScopeSource,
                    array_custom_scope_id,
                    array_target_node_path
                )
                if scope_container:
                    scope_container.set_variable(array_variable, array_ref)
        BaseVariable.VariableScope.GLOBAL:
            VariableOperations.set_variable(context, array_variable, BaseVariable.VariableScope.GLOBAL, array_ref)

func validate() -> Array[String]:
    var errors = super.validate()
    if source_type == SourceType.VARIABLE and array_variable.is_empty():
        errors.append("Array variable name is required")
    if source_type == SourceType.NODE_GROUP and group_name.is_empty():
        errors.append("Group name is required")
    return errors

func get_description() -> String:
    return "ArrayAdd: %s.push_back(%s)" % [array_variable, str(element_value)]
```

**Step 4: 运行测试验证通过**

Run: `E:\Godot\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64.exe --headless --check-only --quit`
Expected: PASS

**Step 5: 提交**

```bash
git add addons/bricks/instructions/arrays/array_add.gd addons/bricks/tests/instructions/test_array_add.gd
git commit -m "feat: add ArrayAdd instruction for pushing elements to arrays

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 2: ArrayRemove - 移除指定索引或值的元素 ✅ 已完成

**Files:**
- Create: `addons/bricks/instructions/arrays/array_remove.gd`
- Test: `addons/bricks/tests/instructions/test_array_remove.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_remove.gd
extends GutTest

func test_array_remove_by_index():
    var array_remove = ArrayRemove.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 4, 5])

    array_remove.array_variable = "my_array"
    array_remove.array_scope = BaseVariable.VariableScope.LOCAL
    array_remove.remove_mode = ArrayRemove.RemoveMode.INDEX
    array_remove.index_value = 2

    array_remove.execute(context)
    await array_remove.finished

    var result = VariableOperations.get_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, [1, 2, 4, 5], "Element at index 2 should be removed")

func test_array_remove_by_value():
    var array_remove = ArrayRemove.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 2, 5])

    array_remove.array_variable = "my_array"
    array_remove.array_scope = BaseVariable.VariableScope.LOCAL
    array_remove.remove_mode = ArrayRemove.RemoveMode.VALUE
    array_remove.element_value = 2

    array_remove.execute(context)
    await array_remove.finished

    var result = VariableOperations.get_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, [1, 3, 5], "First occurrence of value 2 should be removed")
```

**Step 2: 创建 ArrayRemove 指令**

参考 ArrayAdd 模式，实现以下额外属性：
- `remove_mode`: INDEX (按索引) / VALUE (按值)
- `index_value`: int - 要移除的索引
- `element_value`: Variant - 要移除的值

```gdscript
# addons/bricks/instructions/arrays/array_remove.gd
@tool
extends BaseInstruction
class_name ArrayRemove

enum RemoveMode {
    INDEX,  # 按索引移除
    VALUE   # 按值移除
}

var source_type: SourceType = SourceType.VARIABLE
var array_variable: String = ""
@export var array_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

var remove_mode: RemoveMode = RemoveMode.INDEX
var index_value: int = 0
var element_value: Variant = null

var group_name: String = ""
var target_node_path: NodePath = NodePath("")

# ... (参考 ArrayAdd 的属性定义)

static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_ARRAY_REMOVE_NAME"
    metadata.category_key = "BRICKS_CATEGORY_ARRAYS"
    metadata.description_key = "BRICKS_INSTRUCTION_ARRAY_REMOVE_DESC"
    metadata.keywords = ["array", "remove", "delete", "元素", "移除", "删除"]
    metadata.builtin_icon = "Array"
    return metadata

func _setup_metadata():
    pass

# ... (参考 ArrayAdd 的 _get_property_list 和 _update_resource_name)

func execute(context: ExecutionContext):
    _start_execution(context)

    var array_ref = _get_array_from_variable(context)
    if array_ref == null or array_ref.is_empty():
        _log_warning("Array is null or empty")
        _on_execution_completed()
        return

    match remove_mode:
        RemoveMode.INDEX:
            var idx = index_value
            # 支持负索引（从末尾计数）
            if idx < 0:
                idx = array_ref.size() + idx
            if idx >= 0 and idx < array_ref.size():
                array_ref.remove_at(idx)
                _log_info("Removed element at index: %d" % index_value)
        RemoveMode.VALUE:
            var idx = array_ref.find(element_value)
            if idx >= 0:
                array_ref.remove_at(idx)
                _log_info("Removed element at index: %d (value: %s)" % [idx, str(element_value)])

    _save_array_to_variable(context, array_ref)
    _on_execution_completed()

# ... (参考 ArrayAdd 的 _get_array_from_variable 和 _save_array_to_variable)
```

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_remove.gd addons/bricks/tests/instructions/test_array_remove.gd
git commit -m "feat: add ArrayRemove instruction for removing elements

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: ArrayGet - 获取指定索引的元素 ✅ 已完成

**Files:**
- Create: `addons/bricks/instructions/arrays/array_get.gd`
- Test: `addons/bricks/tests/instructions/test_array_get.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_get.gd
extends GutTest

func test_array_get_by_index():
    var array_get = ArrayGet.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [10, 20, 30, 40, 50])

    array_get.array_variable = "my_array"
    array_get.array_scope = BaseVariable.VariableScope.LOCAL
    array_get.index_value = 2
    array_get.target_variable = "result"
    array_get.target_scope = BaseVariable.VariableScope.LOCAL

    array_get.execute(context)
    await array_get.finished

    var result = VariableOperations.get_variable(context, "result", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, 30, "Should get element at index 2")

func test_array_get_negative_index():
    var array_get = ArrayGet.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [10, 20, 30])

    array_get.array_variable = "my_array"
    array_get.array_scope = BaseVariable.VariableScope.LOCAL
    array_get.index_value = -1
    array_get.target_variable = "result"
    array_get.target_scope = BaseVariable.VariableScope.LOCAL

    array_get.execute(context)
    await array_get.finished

    var result = VariableOperations.get_variable(context, "result", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, 30, "Negative index -1 should get last element")
```

**Step 2: 创建 ArrayGet 指令**

额外属性：
- `index_value`: int - 索引（支持负数从末尾计数）
- `target_variable`: String - 存储结果的变量名
- `target_scope`: BaseVariable.VariableScope - 结果变量作用域

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_get.gd addons/bricks/tests/instructions/test_array_get.gd
git commit -m "feat: add ArrayGet instruction for retrieving elements

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 4: ArraySet - 设置指定索引的元素值 ✅ 已完成

**Files:**
- Create: `addons/bricks/instructions/arrays/array_set.gd`
- Test: `addons/bricks/tests/instructions/test_array_set.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_set.gd
extends GutTest

func test_array_set_by_index():
    var array_set = ArraySet.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 4, 5])

    array_set.array_variable = "my_array"
    array_set.array_scope = BaseVariable.VariableScope.LOCAL
    array_set.index_value = 2
    array_set.element_value = 999

    array_set.execute(context)
    await array_set.finished

    var result = VariableOperations.get_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, [1, 2, 999, 4, 5], "Element at index 2 should be set to 999")
```

**Step 2: 创建 ArraySet 指令**

属性：
- `index_value`: int - 要设置的索引
- `element_value`: Variant - 要设置的值

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_set.gd addons/bricks/tests/instructions/test_array_set.gd
git commit -m "feat: add ArraySet instruction for setting element values

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 5: ArrayClear - 清空数组 ✅ 已完成

**Files:**
- Create: `addons/bricks/instructions/arrays/array_clear.gd`
- Test: `addons/bricks/tests/instructions/test_array_clear.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_clear.gd
extends GutTest

func test_array_clear():
    var array_clear = ArrayClear.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

    array_clear.array_variable = "my_array"
    array_clear.array_scope = BaseVariable.VariableScope.LOCAL

    array_clear.execute(context)
    await array_clear.finished

    var result = VariableOperations.get_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, [], "Array should be cleared")
```

**Step 2: 创建 ArrayClear 指令**

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_clear.gd addons/bricks/tests/instructions/test_array_clear.gd
git commit -m "feat: add ArrayClear instruction for clearing arrays

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 6: ArraySize - 获取数组大小 ✅ 已完成

**Files:**
- Create: `addons/bricks/instructions/arrays/array_size.gd`
- Test: `addons/bricks/tests/instructions/test_array_size.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_size.gd
extends GutTest

func test_array_size():
    var array_size = ArraySize.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 4, 5])

    array_size.array_variable = "my_array"
    array_size.array_scope = BaseVariable.VariableScope.LOCAL
    array_size.target_variable = "size"
    array_size.target_scope = BaseVariable.VariableScope.LOCAL

    array_size.execute(context)
    await array_size.finished

    var result = VariableOperations.get_variable(context, "size", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, 5, "Array size should be 5")
```

**Step 2: 创建 ArraySize 指令**

属性：
- `target_variable`: String - 存储大小的变量名
- `target_scope`: BaseVariable.VariableScope - 结果变量作用域

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_size.gd addons/bricks/tests/instructions/test_array_size.gd
git commit -m "feat: add ArraySize instruction for getting array length

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Phase 2: 查询与搜索指令 (3 个)

### Task 7: ArrayFind - 查找元素索引 ✅ 已完成

**Files:**
- Create: `addons/bricks/instructions/arrays/array_find.gd`
- Test: `addons/bricks/tests/instructions/test_array_find.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_find.gd
extends GutTest

func test_array_find_found():
    var array_find = ArrayFind.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [10, 20, 30, 40])

    array_find.array_variable = "my_array"
    array_find.array_scope = BaseVariable.VariableScope.LOCAL
    array_find.search_value = 30
    array_find.target_variable = "index"
    array_find.target_scope = BaseVariable.VariableScope.LOCAL

    array_find.execute(context)
    await array_find.finished

    var result = VariableOperations.get_variable(context, "index", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, 2, "Should find value at index 2")

func test_array_find_not_found():
    var array_find = ArrayFind.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [10, 20, 30])

    array_find.array_variable = "my_array"
    array_find.array_scope = BaseVariable.VariableScope.LOCAL
    array_find.search_value = 999
    array_find.target_variable = "index"
    array_find.target_scope = BaseVariable.VariableScope.LOCAL

    array_find.execute(context)
    await array_find.finished

    var result = VariableOperations.get_variable(context, "index", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, -1, "Should return -1 when not found")
```

**Step 2: 创建 ArrayFind 指令**

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_find.gd addons/bricks/tests/instructions/test_array_find.gd
git commit -m "feat: add ArrayFind instruction for searching elements

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 8: ArrayContains - 检查数组是否包含元素 ✅ 已完成

**Files:**
- Create: `addons/bricks/instructions/arrays/array_contains.gd`
- Test: `addons/bricks/tests/instructions/test_array_contains.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_contains.gd
extends GutTest

func test_array_contains_true():
    var array_contains = ArrayContains.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

    array_contains.array_variable = "my_array"
    array_contains.array_scope = BaseVariable.VariableScope.LOCAL
    array_contains.search_value = 2
    array_contains.target_variable = "result"
    array_contains.target_scope = BaseVariable.VariableScope.LOCAL

    array_contains.execute(context)
    await array_contains.finished

    var result = VariableOperations.get_variable(context, "result", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, true, "Should return true when value exists")

func test_array_contains_false():
    var array_contains = ArrayContains.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

    array_contains.array_variable = "my_array"
    array_contains.array_scope = BaseVariable.VariableScope.LOCAL
    array_contains.search_value = 999
    array_contains.target_variable = "result"
    array_contains.target_scope = BaseVariable.VariableScope.LOCAL

    array_contains.execute(context)
    await array_contains.finished

    var result = VariableOperations.get_variable(context, "result", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, false, "Should return false when value not exists")
```

**Step 2: 创建 ArrayContains 指令**

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_contains.gd addons/bricks/tests/instructions/test_array_contains.gd
git commit -m "feat: add ArrayContains instruction for checking element existence

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 9: ArrayRandom - 获取随机元素 ✅ 已完成

**Files:**
- Create: `addons/bricks/instructions/arrays/array_random.gd`
- Test: `addons/bricks/tests/instructions/test_array_random.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_random.gd
extends GutTest

func test_array_random():
    var array_random = ArrayRandom.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 4, 5])

    array_random.array_variable = "my_array"
    array_random.array_scope = BaseVariable.VariableScope.LOCAL
    array_random.target_variable = "random_item"
    array_random.target_scope = BaseVariable.VariableScope.LOCAL

    array_random.execute(context)
    await array_random.finished

    var result = VariableOperations.get_variable(context, "random_item", BaseVariable.VariableScope.LOCAL, null)
    assert_true(result >= 1 and result <= 5, "Random value should be within array range")
```

**Step 2: 创建 ArrayRandom 指令**

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_random.gd addons/bricks/tests/instructions/test_array_random.gd
git commit -m "feat: add ArrayRandom instruction for getting random elements

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Phase 3: 高级操作指令 (5 个)

### Task 10: ArrayInsert - 在指定位置插入元素 ✅ 已完成

**Files:**
- Create: `addons/bricks/instructions/arrays/array_insert.gd`
- Test: `addons/bricks/tests/instructions/test_array_insert.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_insert.gd
extends GutTest

func test_array_insert():
    var array_insert = ArrayInsert.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

    array_insert.array_variable = "my_array"
    array_insert.array_scope = BaseVariable.VariableScope.LOCAL
    array_insert.index_value = 1
    array_insert.element_value = 999

    array_insert.execute(context)
    await array_insert.finished

    var result = VariableOperations.get_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, [1, 999, 2, 3], "Element should be inserted at index 1")
```

**Step 2: 创建 ArrayInsert 指令**

属性：
- `index_value`: int - 插入位置（支持负数从末尾计数）

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_insert.gd addons/bricks/tests/instructions/test_array_insert.gd
git commit -m "feat: add ArrayInsert instruction for inserting elements

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 11: ArraySlice - 获取数组切片

**Files:**
- Create: `addons/bricks/instructions/arrays/array_slice.gd`
- Test: `addons/bricks/tests/instructions/test_array_slice.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_slice.gd
extends GutTest

func test_array_slice():
    var array_slice = ArraySlice.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [0, 1, 2, 3, 4, 5])

    array_slice.array_variable = "my_array"
    array_slice.array_scope = BaseVariable.VariableScope.LOCAL
    array_slice.start_index = 1
    array_slice.end_index = 4
    array_slice.target_variable = "slice"
    array_slice.target_scope = BaseVariable.VariableScope.LOCAL

    array_slice.execute(context)
    await array_slice.finished

    var result = VariableOperations.get_variable(context, "slice", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, [1, 2, 3], "Should get slice from index 1 to 4")
```

**Step 2: 创建 ArraySlice 指令**

属性：
- `start_index`: int - 起始索引
- `end_index`: int - 结束索引（不包含）
- `target_variable`: String - 存储切片的变量名

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_slice.gd addons/bricks/tests/instructions/test_array_slice.gd
git commit -m "feat: add ArraySlice instruction for array slicing

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 12: ArrayMerge - 合并两个数组

**Files:**
- Create: `addons/bricks/instructions/arrays/array_merge.gd`
- Test: `addons/bricks/tests/instructions/test_array_merge.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_merge.gd
extends GutTest

func test_array_merge():
    var array_merge = ArrayMerge.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "array1", BaseVariable.VariableScope.LOCAL, [1, 2])
    VariableOperations.set_variable(context, "array2", BaseVariable.VariableScope.LOCAL, [3, 4])

    array_merge.source_array_variable = "array1"
    array_merge.source_array_scope = BaseVariable.VariableScope.LOCAL
    array_merge.target_array_variable = "array2"
    array_merge.target_array_scope = BaseVariable.VariableScope.LOCAL
    array_merge.result_variable = "merged"
    array_merge.result_scope = BaseVariable.VariableScope.LOCAL

    array_merge.execute(context)
    await array_merge.finished

    var result = VariableOperations.get_variable(context, "merged", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, [1, 2, 3, 4], "Should merge arrays")
```

**Step 2: 创建 ArrayMerge 指令**

属性：
- `source_array_variable`: String - 源数组变量名
- `target_array_variable`: String - 目标数组变量名
- `result_variable`: String - 结果变量名

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_merge.gd addons/bricks/tests/instructions/test_array_merge.gd
git commit -m "feat: add ArrayMerge instruction for merging arrays

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 13: ArrayReverse - 反转数组 ✅ 已完成

**Files:**
- Create: `addons/bricks/instructions/arrays/array_reverse.gd`
- Test: `addons/bricks/tests/instructions/test_array_reverse.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_reverse.gd
extends GutTest

func test_array_reverse():
    var array_reverse = ArrayReverse.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 4, 5])

    array_reverse.array_variable = "my_array"
    array_reverse.array_scope = BaseVariable.VariableScope.LOCAL

    array_reverse.execute(context)
    await array_reverse.finished

    var result = VariableOperations.get_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, [5, 4, 3, 2, 1], "Array should be reversed")
```

**Step 2: 创建 ArrayReverse 指令**

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_reverse.gd addons/bricks/tests/instructions/test_array_reverse.gd
git commit -m "feat: add ArrayReverse instruction for reversing arrays

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 14: ArrayShuffle - 随机打乱数组 ✅ 已完成

**Files:**
- Create: `addons/bricks/instructions/arrays/array_shuffle.gd`
- Test: `addons/bricks/tests/instructions/test_array_shuffle.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_shuffle.gd
extends GutTest

func test_array_shuffle():
    var array_shuffle = ArrayShuffle.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 4, 5])

    array_shuffle.array_variable = "my_array"
    array_shuffle.array_scope = BaseVariable.VariableScope.LOCAL

    array_shuffle.execute(context)
    await array_shuffle.finished

    var result = VariableOperations.get_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result.size(), 5, "Array should still have 5 elements")
    assert_true(result.has(1) and result.has(2) and result.has(3) and result.has(4) and result.has(5), "All elements should be preserved")
```

**Step 2: 创建 ArrayShuffle 指令**

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_shuffle.gd addons/bricks/tests/instructions/test_array_shuffle.gd
git commit -m "feat: add ArrayShuffle instruction for shuffling arrays

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Phase 4: 创建与条件指令 (5 个)

### Task 15: ArrayCreate - 创建新数组

**Files:**
- Create: `addons/bricks/instructions/arrays/array_create.gd`
- Test: `addons/bricks/tests/instructions/test_array_create.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_create.gd
extends GutTest

func test_array_create():
    var array_create = ArrayCreate.new()
    var context = ExecutionContext.new()

    array_create.target_variable = "new_array"
    array_create.target_scope = BaseVariable.VariableScope.LOCAL
    array_create.initial_values = [1, 2, 3]

    array_create.execute(context)
    await array_create.finished

    var result = VariableOperations.get_variable(context, "new_array", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, [1, 2, 3], "Should create new array with initial values")

func test_array_create_empty():
    var array_create = ArrayCreate.new()
    var context = ExecutionContext.new()

    array_create.target_variable = "empty_array"
    array_create.target_scope = BaseVariable.VariableScope.LOCAL

    array_create.execute(context)
    await array_create.finished

    var result = VariableOperations.get_variable(context, "empty_array", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result, [], "Should create empty array")
```

**Step 2: 创建 ArrayCreate 指令**

属性：
- `initial_values`: Array[Variant] - 初始值数组

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_create.gd addons/bricks/tests/instructions/test_array_create.gd
git commit -m "feat: add ArrayCreate instruction for creating new arrays

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 16: ArrayFromNodes - 从节点创建数组

**Files:**
- Create: `addons/bricks/instructions/arrays/array_from_nodes.gd`
- Test: `addons/bricks/tests/instructions/test_array_from_nodes.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/instructions/test_array_from_nodes.gd
extends GutTest

func test_array_from_children():
    var array_from_nodes = ArrayFromNodes.new()
    var context = ExecutionContext.new()

    # 创建测试节点
    var parent = Node.new()
    parent.name = "Parent"
    var child1 = Node.new()
    child1.name = "Child1"
    var child2 = Node.new()
    child2.name = "Child2"
    parent.add_child(child1)
    parent.add_child(child2)
    context.set_node_tree(parent)

    array_from_nodes.source_type = ArrayFromNodes.NodeSourceType.CHILDREN
    array_from_nodes.target_node_path = NodePath(".")
    array_from_nodes.target_variable = "children"
    array_from_nodes.target_scope = BaseVariable.VariableScope.LOCAL

    array_from_nodes.execute(context)
    await array_from_nodes.finished

    var result = VariableOperations.get_variable(context, "children", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result.size(), 2, "Should get 2 children")

    parent.free()

func test_array_from_group():
    var array_from_nodes = ArrayFromNodes.new()
    var context = ExecutionContext.new()

    # 创建测试节点树
    var tree = Node.new()
    var node1 = Node.new()
    node1.name = "Node1"
    var node2 = Node.new()
    node2.name = "Node2"
    tree.add_child(node1)
    tree.add_child(node2)
    node1.add_to_group("enemies")
    node2.add_to_group("enemies")
    context.set_node_tree(tree)

    array_from_nodes.source_type = ArrayFromNodes.NodeSourceType.GROUP
    array_from_nodes.group_name = "enemies"
    array_from_nodes.target_variable = "enemies_array"
    array_from_nodes.target_scope = BaseVariable.VariableScope.LOCAL

    array_from_nodes.execute(context)
    await array_from_nodes.finished

    var result = VariableOperations.get_variable(context, "enemies_array", BaseVariable.VariableScope.LOCAL, null)
    assert_eq(result.size(), 2, "Should get 2 nodes from group")

    tree.free()
```

**Step 2: 创建 ArrayFromNodes 指令**

```gdscript
# addons/bricks/instructions/arrays/array_from_nodes.gd
@tool
extends BaseInstruction
class_name ArrayFromNodes

enum NodeSourceType {
    CHILDREN,  # 子节点
    GROUP      # 节点组
}

var source_type: NodeSourceType = NodeSourceType.CHILDREN
var target_node_path: NodePath = NodePath("")
var group_name: String = ""
var target_variable: String = ""
@export var target_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL

# ... (参考其他指令的完整实现)
```

**Step 3: 提交**

```bash
git add addons/bricks/instructions/arrays/array_from_nodes.gd addons/bricks/tests/instructions/test_array_from_nodes.gd
git commit -m "feat: add ArrayFromNodes instruction for creating arrays from nodes

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 17: CheckArraySize - 检查数组大小条件 ✅ 已完成

**Files:**
- Create: `addons/bricks/conditions/arrays/check_array_size.gd`
- Test: `addons/bricks/tests/conditions/test_check_array_size.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/conditions/test_check_array_size.gd
extends GutTest

func test_check_array_size_greater():
    var check = CheckArraySize.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3, 4, 5])

    check.array_variable = "my_array"
    check.array_scope = BaseVariable.VariableScope.LOCAL
    check.comparison = CheckArraySize.Comparison.GREATER_THAN
    check.value = 3

    var result = check.check(context)
    assert_true(result, "Should return true when size > 3")

func test_check_array_size_equals():
    var check = CheckArraySize.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

    check.array_variable = "my_array"
    check.array_scope = BaseVariable.VariableScope.LOCAL
    check.comparison = CheckArraySize.Comparison.EQUALS
    check.value = 3

    var result = check.check(context)
    assert_true(result, "Should return true when size == 3")
```

**Step 2: 创建 CheckArraySize 条件**

```gdscript
# addons/bricks/conditions/arrays/check_array_size.gd
@tool
@icon("res://addons/bricks/icons/condition.svg")
extends BaseCondition
class_name CheckArraySize

enum Comparison {
    EQUALS,          # 等于
    NOT_EQUALS,      # 不等于
    GREATER_THAN,    # 大于
    LESS_THAN,       # 小于
    GREATER_OR_EQUAL, # 大于等于
    LESS_OR_EQUAL    # 小于等于
}

var array_variable: String = ""
@export var array_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL
var comparison: Comparison = Comparison.EQUALS
var value: int = 0

# ... (参考其他条件的实现)

func _evaluate_condition(context: ExecutionContext) -> bool:
    var array_ref = _get_array_from_variable(context)
    if array_ref == null:
        return false

    var size = array_ref.size()
    match comparison:
        Comparison.EQUALS:
            return size == value
        Comparison.NOT_EQUALS:
            return size != value
        Comparison.GREATER_THAN:
            return size > value
        Comparison.LESS_THAN:
            return size < value
        Comparison.GREATER_OR_EQUAL:
            return size >= value
        Comparison.LESS_OR_EQUAL:
            return size <= value

    return false
```

**Step 3: 提交**

```bash
git add addons/bricks/conditions/arrays/check_array_size.gd addons/bricks/tests/conditions/test_check_array_size.gd
git commit -m "feat: add CheckArraySize condition for array size checks

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 18: CheckArrayContains - 检查数组包含条件 ✅ 已完成

**Files:**
- Create: `addons/bricks/conditions/arrays/check_array_contains.gd`
- Test: `addons/bricks/tests/conditions/test_check_array_contains.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/conditions/test_check_array_contains.gd
extends GutTest

func test_check_array_contains_true():
    var check = CheckArrayContains.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

    check.array_variable = "my_array"
    check.array_scope = BaseVariable.VariableScope.LOCAL
    check.search_value = 2

    var result = check.check(context)
    assert_true(result, "Should return true when value exists")

func test_check_array_contains_false():
    var check = CheckArrayContains.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

    check.array_variable = "my_array"
    check.array_scope = BaseVariable.VariableScope.LOCAL
    check.search_value = 999

    var result = check.check(context)
    assert_false(result, "Should return false when value not exists")
```

**Step 2: 创建 CheckArrayContains 条件**

属性：
- `search_value`: Variant - 要搜索的值

**Step 3: 提交**

```bash
git add addons/bricks/conditions/arrays/check_array_contains.gd addons/bricks/tests/conditions/test_check_array_contains.gd
git commit -m "feat: add CheckArrayContains condition for element existence checks

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 19: CheckArrayEmpty - 检查数组为空条件

**Files:**
- Create: `addons/bricks/conditions/arrays/check_array_empty.gd`
- Test: `addons/bricks/tests/conditions/test_check_array_empty.gd`

**Step 1: 创建测试**

```gdscript
# addons/bricks/tests/conditions/test_check_array_empty.gd
extends GutTest

func test_check_array_empty_true():
    var check = CheckArrayEmpty.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [])

    check.array_variable = "my_array"
    check.array_scope = BaseVariable.VariableScope.LOCAL

    var result = check.check(context)
    assert_true(result, "Should return true for empty array")

func test_check_array_empty_false():
    var check = CheckArrayEmpty.new()
    var context = ExecutionContext.new()

    VariableOperations.set_variable(context, "my_array", BaseVariable.VariableScope.LOCAL, [1, 2, 3])

    check.array_variable = "my_array"
    check.array_scope = BaseVariable.VariableScope.LOCAL

    var result = check.check(context)
    assert_false(result, "Should return false for non-empty array")
```

**Step 2: 创建 CheckArrayEmpty 条件**

**Step 3: 提交**

```bash
git add addons/bricks/conditions/arrays/check_array_empty.gd addons/bricks/tests/conditions/test_check_array_empty.gd
git commit -m "feat: add CheckArrayEmpty condition for empty array checks

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Phase 5: 本地化与注册

### Task 20: 添加本地化键值

**Files:**
- Modify: `addons/bricks/localization/translations.csv`

**Step 1: 添加本地化键值**

在 CSV 文件中添加以下键值：

```csv
# Array Instructions
BRICKS_INSTRUCTION_ARRAY_ADD_NAME;Array Add;Array添加
BRICKS_INSTRUCTION_ARRAY_ADD_DESC;Add an element to the end of an array;向数组末尾添加元素
BRICKS_INSTRUCTION_ARRAY_REMOVE_NAME;Array Remove;Array移除
BRICKS_INSTRUCTION_ARRAY_REMOVE_DESC;Remove an element from array by index or value;从数组中移除指定索引或值的元素
# ... (为所有 16 个指令添加本地化)

# Array Conditions
BRICKS_CONDITION_ARRAY_SIZE_NAME;Check Array Size;检查数组大小
BRICKS_CONDITION_ARRAY_SIZE_DESC;Check if array size meets condition;检查数组大小是否满足条件
BRICKS_CONDITION_ARRAY_CONTAINS_NAME;Check Array Contains;检查数组包含
BRICKS_CONDITION_ARRAY_CONTAINS_DESC;Check if array contains a specific value;检查数组是否包含特定值
BRICKS_CONDITION_ARRAY_EMPTY_NAME;Check Array Empty;检查数组为空
BRICKS_CONDITION_ARRAY_EMPTY_DESC;Check if array is empty;检查数组是否为空
```

**Step 2: 提交**

```bash
git add addons/bricks/localization/translations.csv
git commit -m "feat: add localization keys for array instructions and conditions

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 21: 注册指令和条件

**Files:**
- Modify: `addons/bricks/editor/plugins/bricks_editor_plugin.gd`
- Modify: `addons/bricks/core/managers/instruction_registry.gd` (如需要)

**Step 1: 注册到指令选择器**

确保新指令在指令选择器中可用。

**Step 2: 提交**

```bash
git add addons/bricks/editor/plugins/bricks_editor_plugin.gd
git commit -m "feat: register array instructions and conditions in editor

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## MVP 实现顺序

如果时间有限，按以下优先级实现：

1. **优先级 1**: ArrayCreate, ArrayAdd, ArrayGet, ArraySize (核心基础)
2. **优先级 2**: ArrayRemove, ArraySet, CheckArrayEmpty (常用操作)
3. **优先级 3**: ArrayFind, ArrayContains, CheckArrayContains (查询)
4. **优先级 4**: 剩余指令和条件

---

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 变量类型不匹配 | 中 | 类型检查 + 错误提示 + 可选强制转换 |
| 属性配置复杂 | 高 | 使用 Category 分组 + 条件属性显示 |
| 索引越界混淆 | 中 | 提供负索引支持（GDScript 风格） |
| 作用域查找失败 | 中 | 清晰的错误日志 |

---

## 验证清单

- [ ] 所有 16 个指令实现完成
- [ ] 所有 3 个条件实现完成
- [ ] 本地化键值添加完整
- [ ] 指令在选择器中可用
- [ ] 单元测试通过
- [ ] 手动测试覆盖主要场景
