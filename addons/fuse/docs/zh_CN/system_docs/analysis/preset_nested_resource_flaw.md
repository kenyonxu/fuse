> 🌐 中文 | [**English**](../../../en_US/system_docs/analysis/preset_nested_resource_flaw.md)

# Preset 反序列化嵌套资源缺陷分析与修复方案

> **发现日期**: 2026-08-10
> **触发场景**: B2 条件分支 preset 设计（见 `demos/fuse/fuse_adventure/B2条件分支技术约束.md`）
> **缺陷等级**: 中（限制 preset JSON 的表达力，但不破坏既有功能）
> **状态**: 已修复

---

## 1. 摘要

Fuse preset 反序列化管道**不支持嵌套子资源（BaseCondition / BaseInstruction / BaseEvent）的递归构造**。含嵌套字段的组件——容器型指令（`IfElse`/`IfThen`/`ForLoop`/`ForEach`/`WhileLoop`/`RunConditionCheck`）、复合条件（`CheckAll`/`CheckAny`/`CheckNot`）、带条件事件（`OnInterval`），共 **10 个点**——都无法从纯 preset JSON 内联还原，必须依赖 `.tscn` 内嵌资源指针（`SubResource` / `ExtResource`），而这类指针 AI 无法在生成 JSON 时凭空创造。

**后果**：AI 生成的 preset JSON（走 `/fuse-instruction-generator`、`/fuse-preset-generator`）无法包含可工作的 IfElse / 循环体 / 复合条件 / 带条件事件。条件分派目前只能通过 L4 `EventBinding.conditions` 绕过，且 L4 也仅支持扁平叶子条件——复合条件（`CheckAll` 等）在 L4 同样不可用（详见 §4.2）。

**修复结果**：引入核心层通用编解码器 `PresetValueCodec`，通过 property-list 类型感知把 Dictionary/Array 递归转换为嵌套资源。所有序列化/反序列化入口统一调用该 codec，解决了 10 个嵌套点的反序列化与序列化对称性问题。

---

## 2. 缺陷现象

### 2.1 复现路径

期望在 L2 preset JSON 中表达一个带条件的 IfElse：

```json
{
  "type": "IfElse",
  "condition": {
    "type": "CheckScopeVariable",
    "scope_source": 1,
    "custom_scope_id": "level_scope",
    "variable_name": "current_level",
    "operator": 0,
    "compare_value": 1
  },
  "true_instructions": [
    { "type": "ChangeScene", "scene_path": "res://demos/.../level_02.tscn" }
  ],
  "false_instructions": []
}
```

### 2.2 实际行为

导入后 `IfElse.condition` 被赋为一个 **Dictionary**（而非 `CheckScopeVariable` 实例）。运行时执行到 [if_else.gd:153](../../../../instructions/flow_control/if_else.gd#L153)：

```gdscript
var condition_result: bool = condition.check(context)   # ← Dictionary 无 check() 方法 → 崩溃
```

`true_instructions` / `false_instructions` 同理——变成 `Array[Dictionary]`，子指令 `execute()` 时崩溃。

---

## 3. 根因分析

### 3.1 反序列化调用链（L2 路径）

```
FusePreset.from_json()                              # fuse_preset.gd:114
  └─ _deserialize_instructions()                    # fuse_preset.gd:128, 154
       └─ for each entry:
            inst = script.new()
            for key in entry:
                _set_property_value(inst, key, entry[key])   # ← 缺陷点
```

### 3.2 缺陷点：`_set_property_value` 扁平赋值

[fuse_preset_deserializer.gd:245-251](../../../../editor/serialization/fuse_preset_deserializer.gd#L245-L251)：

```gdscript
static func _set_property_value(obj: Object, key: String, val) -> void:
    if val is String and (val.begins_with("uid://") or val.begins_with("res://")):
        var res = load(val)        # 只识别资源引用字符串
        if res != null:
            obj.set(key, res)
            return
    obj.set(key, val)              # 其它一律裸 set —— Dictionary 原样塞进去
```

函数**不检查目标属性 `obj.key` 的期望类型**。当 `val` 是 Dictionary 时，本应根据 `obj` 的 property list 判断它应当被解释成 BaseCondition / BaseInstruction / BaseEvent 实例并递归反序列化，实际却直接 `obj.set(key, val)`。

### 3.3 `InstructionSerializer` 同病

[instruction_serializer.gd:46-61](../../../../core/serialization/instruction_serializer.gd#L46-L61) 的 `deserialize_instruction` 同样是扁平 `instruction.set(property, data[property])`，无递归。

序列化侧 [instruction_serializer.gd:34-36](../../../../core/serialization/instruction_serializer.gd#L34-L36) 也只做 `data[name] = instruction.get(name)`——若 `condition` 是 BaseCondition 对象，写入字典后无法被 `JSON.stringify` 正确处理（对象引用丢失）。这解释了现有 JSON（如 game_flow.json）里 condition 为何总是 `.tscn::Resource_xxx` 指针形式。

### 3.4 唯一的"正确实现"：L4 EventBinding.conditions

[fuse_preset_deserializer.gd:168-174](../../../../editor/serialization/fuse_preset_deserializer.gd#L168-L174)：

```gdscript
if data.has("conditions"):
    var conds: Array[BaseCondition] = []
    for cdata in data["conditions"]:
        var cond := _deserialize_condition(cdata)   # ← 显式递归
        if cond:
            conds.append(cond)
    binding.conditions = conds
```

`_deserialize_binding` **显式**知道 conditions 字段语义，调 `_deserialize_condition` 做字典→实例的转换（[fuse_preset_deserializer.gd:140-151](../../../../editor/serialization/fuse_preset_deserializer.gd#L140-L151)）。这是整个管道里**唯一**支持条件字典反序列化的路径。

> 通用 `_set_property_value` 缺这条路 → 容器型指令的嵌套字段全部失效。

---

## 4. 影响范围

> 2026-08-10 实测扩充：缺陷是**系统性**的，不止 IfElse。对 `instructions/`、`conditions/`、`events/` 全量 grep 声明了 `Base(Condition|Instruction|Event)` 类型属性的组件，确认 **10 个点**当前全部受影响。

### 4.1 当前受影响组件（实测清单）

| 类别 | 组件 | 嵌套字段 | 文件 |
|------|------|---------|------|
| 容器指令 | `IfElse` | `condition` + `true_instructions` + `false_instructions` | `instructions/flow_control/if_else.gd:25,32,37` |
| 容器指令 | `IfThen` | `condition` + `instructions` | `instructions/flow_control/if_then.gd:25,32` |
| 容器指令 | `ForLoop` | `loop_instructions` | `instructions/flow_control/for_loop.gd:110` |
| 容器指令 | `ForEach` | `loop_instructions` | `instructions/flow_control/for_each.gd:153` |
| 容器指令 | `WhileLoop` | `loop_instructions` | `instructions/flow_control/while_loop.gd:79` |
| 容器指令 | `RunConditionCheck` | `condition` | `instructions/flow_control/run_condition_check.gd:18` |
| 复合条件 | `CheckAll` | `conditions: Array[BaseCondition]` | `conditions/composite/check_all.gd:12` |
| 复合条件 | `CheckAny` | `conditions: Array[BaseCondition]` | `conditions/composite/check_any.gd:12` |
| 复合条件 | `CheckNot` | `inner_condition` | `conditions/composite/check_not.gd:12` |
| 事件 | `OnInterval` | `stop_condition` | `events/lifecycle/on_interval.gd:66` |

**注 1**：`WhileLoop` 的循环条件用 `condition_variable` + `condition_check` 枚举（非 BaseCondition，见 `while_loop.gd:73,120`），但其 `loop_instructions` 仍是 `Array[BaseInstruction]` → 循环体构造不出来，WhileLoop 照样不可用。

**注 2**：`OnInterval.stop_condition` 是事件内嵌条件——事件反序列化走 `_deserialize_event` → `_set_property_value`，隐蔽中招。

### 4.2 关键发现：L4 的"绕过"也不完整

L4 的 `EventBinding.conditions` 用 `_deserialize_condition` 构造每个顶层条件，但 `_deserialize_condition` 内部仍走 `_set_property_value` 设字段。因此若在 L4 里用 **`CheckAll`/`CheckAny`/`CheckNot`** 做复合条件（如 `current_level==1 AND has_key`），子条件数组同样构造不出来 → 崩。

**L4 实际只支持"扁平叶子条件列表"，不支持嵌套复合条件。** B2 以为升 L4 即可，是高估了。

### 4.3 未来扩展同样落入

任何新增的容器型指令/复合条件/带条件的事件——只要含 BaseCondition / BaseInstruction / BaseEvent 类型的属性——都会落入同一缺陷（如假想的 `SwitchCase`、`TryCatch`）。方案 A 一处修复，全部预防。

### 4.3 不受影响

- 顶层 `action_runner.instructions`：`_deserialize_instructions` 显式处理（顶层不嵌套）
- L4 `EventBinding.conditions`：显式递归
- L4 每个 binding 的 `action_runner.instructions`：同上
- 普通扁平指令（GetNode / ChangeScene / ShowHideUI 等）：无嵌套字段，正常

---

## 5. 现有绕过方案及局限

### 5.1 绕过：升级到 L4 MultiEventTrigger

用多个 EventBinding + 各自的 `conditions` 表达条件分派，而非 IfElse：

```
binding 1: OnButtonPressed(NextLevel) + [CheckScopeVariable(current_level==1)] → ChangeScene(level_02)
binding 2: OnButtonPressed(NextLevel) + [CheckScopeVariable(current_level==2)] → ChangeScene(level_01)
```

✅ 纯 JSON 可表达，导入即用。

### 5.2 局限

1. **`IfElse` 指令本身在任何 Level 下都不可用**——L4 只是绕过它，并非让它在 L4 复活。若有用户在 L4 binding 的 instructions 里写 IfElse，依然崩。
2. **复合条件在 L4 里同样崩**——`CheckAll`/`CheckAny`/`CheckNot` 的子条件数组也走扁平 `_set_property_value`（详见 §4.2）。L4 实际只支持扁平叶子条件，不能做 AND/OR/NOT 组合。
3. **其它容器指令全部不可用**——`ForEach`/`ForLoop`/`WhileLoop`/`IfThen`/`RunConditionCheck` 同病，循环体和子指令都构造不出来。
4. **语义错位**：用"多个绑定 + 条件"表达"同一事件按状态分派"，教学成本高于一个 IfElse。对复杂分支（嵌套 if、多级 else）表达力不足。
5. **教学体系缺口**：B2 想教的"条件分支"被迫改成"多事件绑定 + 条件"，概念偏移。

---

## 6. 修复方案

### 方案 A：`_set_property_value` 加类型感知递归（推荐）

**思路**：让通用赋值函数根据目标属性的期望类型，自动把 Dictionary/Array 递归还原成对应子资源实例。一处修复，通治所有容器型指令。

**关键实现**：通过 `obj.get_property_list()` 取目标属性的 `hint_string`（动态声明的 BaseCondition/BaseInstruction 属性都带 `PROPERTY_HINT_RESOURCE_TYPE` + `hint_string="BaseCondition"` 等，见 [if_else.gd:69-99](../../../../instructions/flow_control/if_else.gd#L69-L99)）。

**伪码**（替换 [fuse_preset_deserializer.gd:245-251](../../../../editor/serialization/fuse_preset_deserializer.gd#L245-L251)）：

```gdscript
static func _set_property_value(obj: Object, key: String, val) -> void:
    # 1. 资源引用字符串（保留原逻辑）
    if val is String and (val.begins_with("uid://") or val.begins_with("res://")):
        var res = load(val)
        if res != null:
            obj.set(key, res)
            return

    # 2. 嵌套子资源：按目标属性期望类型递归
    var expected := _get_property_type_hint(obj, key)   # 返回 {"kind": "object"|"array", "class": "BaseCondition"|...}
    if expected.kind == "object" and val is Dictionary:
        match expected.class:
            "BaseCondition":      val = _deserialize_condition(val)
            "BaseInstruction":    val = _deserialize_instruction(val)
            "BaseEvent":          val = _deserialize_event(val)
            _:                    # 其它资源类型，原样 set（保持兼容）
                pass
    elif expected.kind == "array" and val is Array and expected.class != "":
        val = _deserialize_typed_array(val, expected.class)

    obj.set(key, val)


static func _get_property_type_hint(obj: Object, key: String) -> Dictionary:
    for prop in obj.get_property_list():
        if prop.name == key:
            if prop.type == TYPE_OBJECT and prop.hint == PROPERTY_HINT_RESOURCE_TYPE:
                return {"kind": "object", "class": prop.hint_string}
            if prop.type == TYPE_ARRAY and prop.hint == PROPERTY_HINT_RESOURCE_TYPE:
                return {"kind": "array", "class": prop.hint_string}
            break
    return {"kind": "", "class": ""}


static func _deserialize_typed_array(raw: Array, element_class: String) -> Array:
    var result: Array = []
    for item in raw:
        if item is Dictionary:
            match element_class:
                "BaseInstruction": result.append(_deserialize_instruction(item))
                "BaseCondition":   result.append(_deserialize_condition(item))
                "BaseEvent":       result.append(_deserialize_event(item))
                _:                result.append(item)
        else:
            result.append(item)
    return result
```

**优点**：
- 一处修复，所有容器型指令（含未来扩展）自动受益
- 不破坏现有扁平指令路径
- 与 L4 EventBinding.conditions 的显式递归语义一致（只是下沉到通用层）

**风险**：
- 需回归测试现有 preset 导入（确保扁平字段不受误判）
- `_get_property_list()` 在 `@tool` 下的时序需注意（参考 CLAUDE.md 编辑器线程安全条目）

**实施细节（Array 元素类型检测需兼容两种 hint）**：

两种 property 声明方式的 hint 不同，`_get_property_type_hint` 都要识别，否则会"修了 IfElse 漏了 CheckAll"：

| 声明方式 | 示例 | hint | hint_string |
|---------|------|------|-------------|
| 动态 `_get_property_list` | IfElse/ForEach 的 instructions | `PROPERTY_HINT_RESOURCE_TYPE` | `"BaseInstruction"` |
| `@export var` | CheckAll/Any 的 conditions | `PROPERTY_HINT_ARRAY_TYPE` | `"BaseCondition"` 或 `"Array[BaseCondition]"` |

GET_PROPERTY_LIST 都能拿到，只是分支判断要覆盖两种 hint + hint_string 的两种格式（裸类名 / `Array[...]` 包装）。

### 方案 B：`InstructionSerializer` 配套修复

方案 A 只修反序列化。`InstructionSerializer` 的序列化侧（`serialize_instruction`）也要对称修复——遇到 BaseCondition/BaseInstruction 属性值时递归序列化成嵌套字典，否则导出的 JSON 仍无法内联。

**伪码**（[instruction_serializer.gd:34-36](../../../../core/serialization/instruction_serializer.gd#L34-L36) 改造）：

```gdscript
for property_name in properties:
    var value = instruction.get(property_name)
    data[property_name] = _serialize_value(value)


static func _serialize_value(value: Variant) -> Variant:
    if value is BaseCondition:
        return _serialize_condition(value)        # 复用 deserialize_condition 的逆操作
    if value is BaseInstruction:
        return serialize_instruction(value)       # 已存在，递归
    if value is BaseEvent:
        return _serialize_event(value)
    if value is Array:
        var arr: Array = []
        for item in value:
            arr.append(_serialize_value(item))
        return arr
    return value
```

> 建议同时把 `fuse_preset.gd` 与 `fuse_preset_deserializer.gd` 里**重复**的两份 `_deserialize_instructions` 合并，避免修一处漏一处（见 §8 代码质量）。

### 方案 C：不修代码，加文档约束

在 `/fuse-preset-generator` skill 和 B2 文档里固化约束：

> 容器型指令（`IfElse` 等）的嵌套字段**禁止**在 preset JSON 内联。条件分派一律走 L4 `EventBinding.conditions`。

**优点**：零代码改动，零回归风险。
**缺点**：缺陷永久存在；未来容器型指令全部受累；教学体系被迫绕开 IfElse。

---

## 7. 推荐实施步骤（方案 A + B）

1. **抽取公共工具** `preset_value_codec.gd`（或在现有 utils 加静态方法）：`_get_property_type_hint` / `_deserialize_typed_array` / `_serialize_value`，供 deserializer 和 serializer 共用。
2. **改造 `_set_property_value`**（方案 A），保留原 uid/res 分支。
3. **改造 `InstructionSerializer.serialize_instruction`**（方案 B），保证对称。
4. **合并重复的 `_deserialize_instructions`**（fuse_preset.gd ↔ deserializer）。
5. **更新 `/fuse-preset-generator` skill**：移除"不能用 IfElse"约束，补充嵌套 JSON 示例。
6. **回归 + 新增测试**（见 §8）。

预估工作量：0.5–1 天（含测试）。

---

## 8. 测试验证

### 8.1 新增测试（验证修复）

构造 preset JSON `test_ifelse_inline.json`：

```json
{
  "format_version": "2.0",
  "level": "L2",
  "display_name": "test_ifelse_inline",
  "event": { "type": "OnArea2DEnter", "area_node_path": "Area2D", "target_group": "player" },
  "action_runner": {
    "execution_mode": 0,
    "instructions": [
      {
        "type": "IfElse",
        "sequence_mode": 0,
        "condition": {
          "type": "CheckScopeVariable",
          "scope_source": 1,
          "custom_scope_id": "level_scope",
          "variable_name": "current_level",
          "operator": 0,
          "compare_value": 1
        },
        "true_instructions": [
          { "type": "Print", "message": "branch-true" }
        ],
        "false_instructions": [
          { "type": "Print", "message": "branch-false" }
        ]
      }
    ]
  },
  "variables": { "global": [], "local": [], "scope": [] },
  "trigger_config": { "trigger_once": true, "cooldown_mode": 0, "cooldown_time": 1.0 }
}
```

断言：
- 导入后 `IfElse.condition is BaseCondition`（`is CheckScopeVariable`）✓
- `IfElse.true_instructions[0] is BaseInstruction`（`is Print`）✓
- 触发后日志输出正确的 `branch-true` / `branch-false`（根据 current_level 值）
- **序列化再反序列化**（round-trip）结果等价

### 8.2 回归测试

- 现有 L4 preset（含 `binding.conditions`）导入行为不变
- 现有扁平指令 preset 导入行为不变
- `ChangeScene` / `GetNode` / `ShowHideUI` 等无嵌套字段指令正常

---

## 9. 相关文件清单

| 文件 | 角色 | 改动 |
|------|------|------|
| `addons/fuse/core/serialization/preset_value_codec.gd` | 通用编解码器 | 新建，承担所有嵌套资源 serde |
| `addons/fuse/editor/serialization/fuse_preset_deserializer.gd` | 反序列化管道 | 调用 codec，`_set_property_value` 走 `deserialize_value` |
| `addons/fuse/core/serialization/instruction_serializer.gd` | 序列化器 | 调用 codec，支持递归序列化 |
| `addons/fuse/core/resources/fuse_preset.gd` | Preset 资源 + from_json | 调用 codec，合并重复反序列化逻辑 |
| `addons/fuse/editor/serialization/fuse_preset_serializer.gd` | 序列化器 | 调用 codec |
| `addons/fuse/instructions/flow_control/if_else.gd` | 容器型指令样本 | 无需改（只是受益方） |
| `addons/fuse/core/event_binding.gd` | L4 绑定（现有正确实现） | 无需改（参考样板） |
| `~/.claude/skills/fuse-preset-generator/SKILL.md` | preset 生成 skill | 约束更新 |

---

## 10. 附录：为何 L4 能绕过、IfElse 不能

| 维度 | L4 `EventBinding.conditions` | L2 `IfElse.condition` |
|------|------------------------------|----------------------|
| 反序列化入口 | `_deserialize_binding` 显式遍历 conditions 数组 | 通用 `_set_property_value` 扁平赋值 |
| 是否递归 | ✅ 调 `_deserialize_condition` | ❌ 直接 set Dictionary |
| JSON 可表达 | ✅ 内联字典 | ❌ 必须资源引用 |

本质区别：**L4 对 conditions 做了字段级的特化处理，IfElse 走通用管道而通用管道不认嵌套**。方案 A 把这种特化下沉到通用层，让所有字段共享同一能力。

---

## 11. 修复状态

- **状态**: 已修复
- **修复提交**: 见 `PresetValueCodec` 引入及相关序列化器改造
- **验证**: `tests/serialization/test_preset_nested_serde.gd` 覆盖 IfElse、CheckAll、OnInterval 的 round-trip；现有 IfElse / 复合条件 / OnInterval 测试通过。

修复后：
- L2 preset JSON 可内联 `IfElse`、`IfThen`、`ForLoop`、`ForEach`、`WhileLoop`、`RunConditionCheck`。
- 复合条件 `CheckAll` / `CheckAny` / `CheckNot` 可内联子条件。
- `OnInterval.stop_condition` 可内联条件。
- L4 `EventBinding.conditions` 也自动支持复合条件。

---

## 12. 实施过程中发现的额外技术细节

实际实现 `PresetValueCodec` 时，遇到若干 Godot 运行时的"陷阱"，已在代码中处理：

### 12.1 GDScript `class_name` 在 headless / 运行时未必注册到 ClassDB

`ClassDB.class_exists("CheckScopeVariable")` 在编辑器中可能为 `true`，但在 `--headless` 或运行时导出中为 `false`。因此 `_deserialize_resource` 做了双路径：

1. 先尝试 `ClassDB.class_exists` / `ClassDB.instantiate`（原生或已注册类）。
2. 失败时按 `type_name` 扫描 `addons/fuse/{instructions,events,conditions,integration}/` 下的 `.gd` 文件，用 `script.get_global_name()` 匹配并实例化。

### 12.2 `@export var conditions: Array[BaseCondition]` 的 hint 并非 `PROPERTY_HINT_ARRAY_TYPE`

Godot 对 typed-array 属性的报告格式是 `PROPERTY_HINT_TYPE_STRING`，`hint_string` 形如 `"24/17:BaseCondition"`。因此 `_property_to_hint` 必须额外解析这种格式：

```gdscript
elif hint == PROPERTY_HINT_TYPE_STRING:
    element_class = _parse_type_string_hint(hint_string)
```

### 12.3 无 hint 的 `TYPE_OBJECT` 属性仍可能通过 `class_name` 字段识别

某些动态属性（如 `IfElse.condition`）在 `get_property_list()` 中报告 `hint == PROPERTY_HINT_NONE`，但 `class_name` 字段仍带 `"BaseCondition"`。`_property_to_hint` 会把 `class_name_str` 作为后备：

```gdscript
var target_class := hint_string if hint == PROPERTY_HINT_RESOURCE_TYPE and hint_string != "" else class_name_str
```

### 12.4 类型化数组 `set()` 会静默失败

Godot 拒绝把无类型 `Array` 赋给 `Array[BaseCondition]` 属性。`_set_property_safely` 在首次 `set` 后检查数组长度，若未生效则用属性自身的类型化副本重新填充：

```gdscript
var typed: Array = current.duplicate()
typed.clear()
typed.append_array(value)
obj.set(key, typed)
```

### 12.5 `_find_property` 可能返回不带类型信息的条目

同一属性名在 `get_property_list()` 中可能出现多次（如脚本属性 + 内置属性）。实现中优先返回带 `hint` 或 `class_name` 的条目，避免把数组误判为无类型。

---

## 决策建议

| 选项 | 取舍 |
|------|------|
| **A + B（推荐）** | 根治缺陷，IfElse 全功能可用，未来容器型指令零成本。约 0.5–1 天。 |
| 仅 A | 修了反序列化，但导出 JSON 仍不对称（手工写 JSON 能用，编辑器导出会丢）。不完整。 |
| C（不修） | 零风险，但缺陷永久化，教学/扩展受限。 |

建议走 **A + B**，并在修完后把 B2 的"升 L4"决策从"必须"降级为"可选教学路径"。
