# get_variable_modes() 声明 — 变量读写语义精确化设计规格

> 日期：2026-07-11
> 状态：设计已批准（基于代码库深度分析），待实现
> 关联：E3 跨 Trigger 关联（`00770f0`）、CODE_ISSUES _infer_variable_mode 遗留

---

## 1. 背景与动机

### 问题
`InstructionAnalyzer._infer_variable_mode(pname)`（instruction_analyzer.gd:254-259）用属性名前缀推导变量读写语义：
- `target_` → write
- `from_` → read
- 其他 → **read_write（致命默认）**

下游 `_build_variable_cross_references` 中：`read_write` **同时进入 writers 和 readers**。任何非 `target_`/`from_` 的变量属性都被当 writer → 跨 Trigger **误报竞态**（`variable_write_to_write` warning）。

### 根本矛盾（启发式不可解）
**同名属性、不同语义**——属性名推导无法区分：

| 属性名 | 组件 A | 语义 | 组件 B | 语义 |
|--------|--------|------|--------|------|
| `array_variable` | ForEach | **read**（只读迭代源） | ArrayAdd | **read_write**（原地修改） |
| `variable_name` | PrintVariableValue | **read**（打印值） | CreateVariable | **write**（创建变量） |
| `variable_name` | CheckVariable | **read**（检查值） | SetScopeVariable | **write**（设置值） |

**必须靠组件级声明**（每个组件最懂自己的 execute() 语义），属性名推导永远无法消除这类冲突。

### 误判规模
深度分析（2026-07-11 代码库扫描）确认 **~35-40 个组件** 的变量属性被误判（read-only 或 write-only 被当 read_write）。

---

## 2. 方案：get_variable_modes() 声明

### 设计
`BaseInstruction` / `BaseCondition` 加虚方法：
```gdscript
## 声明本组件变量属性的精确读写模式（供静态分析用）
## 返回 [{name: String, mode: String}]，mode ∈ "read"/"write"/"read_write"
## 默认空数组 → fallback _infer_variable_mode（向后兼容）
func get_variable_modes() -> Array[Dictionary]:
    return []
```

`_extract_variables` 加 hook：
```gdscript
# 优先用组件声明的精确 mode，空则 fallback 启发式
var declared_modes := {}
if inst.has_method("get_variable_modes"):
    for entry in inst.get_variable_modes():
        declared_modes[entry.name] = entry.mode
...
# 在 _extract_variables 循环中：
var mode: String = declared_modes.get(pname, _infer_variable_mode(pname))
```

### 向后兼容
- 未覆盖的组件（`get_variable_modes()` 返空）→ fallback `_infer_variable_mode`（现状不变）
- 覆盖的组件 → 精确 mode
- 渐进迁移，无破坏性

---

## 3. 误判清单 + 覆盖计划

### Phase 1：高频误判（15 文件）

#### variable_name read-only（7 文件）
| 组件 | 属性 | 精确 mode | 文件 |
|------|------|----------|------|
| PrintVariableValue | variable_name | read | instructions/debug/print_variable_value.gd |
| CheckVariable | variable_name, compare_variable | read, read | conditions/variable/check_variable.gd |
| CompareVariable | variable_name | read | conditions/variable/compare_variable.gd |
| CheckScopeVariable | variable_name, compare_variable | read, read | conditions/scope/check_scope_variable.gd |
| CheckHealthValue | health_variable | read | conditions/variable/check_health_value.gd |
| CompareHealthThreshold | health_variable | read | conditions/variable/compare_health_threshold.gd |
| CheckCountdownFinished | start_time_variable | read | conditions/time/check_countdown_finished.gd |

#### array_variable read-only（3 文件，ForEach 最严重）
| 组件 | 属性 | 精确 mode | 文件 |
|------|------|----------|------|
| **ForEach** | array_variable | **read** | instructions/flow_control/for_each.gd |
| CheckArrayContains | array_variable | read | conditions/arrays/check_array_contains.gd |
| CheckVector2VariableAxis | variable_name | read | conditions/variable/check_vector2_variable_axis.gd |

#### variable_name write（2 文件，当前误判 rw）
| 组件 | 属性 | 精确 mode | 文件 |
|------|------|----------|------|
| CreateVariable | variable_name | write | instructions/variables/create_variable.gd |
| SetScopeVariable | variable_name | write | instructions/variables/set_scope_variable.gd |

#### 条件节点变量（3 文件）
| 组件 | 属性 | 精确 mode | 文件 |
|------|------|----------|------|
| CheckAnimationFinished | node_variable_name | read | conditions/animation/check_animation_finished.gd |
| CheckChildCount | source/target_variable_name | read | conditions/node/check_child_count.gd |
| CheckDirection | target_variable_name | read | conditions/node/check_direction.gd |

### Phase 2：批量覆盖（~25 文件）

#### save_to_variable write-only（~15 文件）
Math/Random/MathExpression/StringExpression/Clamp/Lerp/VectorOp/GetRandomPointInRange/GetScenePath/LoadSceneBackground/GetDeltaTime/String{Contains,Format,Join,Length,Split}/GetViewportSize 等

`save_to_variable` → **write**（仅写结果，不读）

#### operand/value 变量 read（~5 文件）
MathOperation.operand_a/b_variable → read；ClampValue.value_variable → read；GetRandomPointInRange.origin/range_variable → read

#### position/rotation/scale 变量 read（~3 文件）
Set{Position,Rotation,Scale}/RotateBy 的位置/旋转/缩放变量 → read（读取目标值，非写）

#### dict 变量 read（~2 文件）
DictGet* 的 dict_variable/key_variable → read

### Phase 3：单元测试
每覆盖组件加测试断言 `get_variable_modes()` 返回值 + `analyze_problems` 对应 mode 正确。

### Phase 4：skill 更新
`/fuse-instruction-generator` skill（preset_ai_context/cheatsheet + workflow brief）加"新组件必须声明 get_variable_modes()"约定。

---

## 4. 实现规格

### 4.1 BaseInstruction / BaseCondition API
```gdscript
## 声明本组件变量属性的精确读写模式（供静态分析用）
## mode: "read" = 仅读（get_variable）/ "write" = 仅写（set_variable）/ "read_write" = 读写
## 默认空数组 → fallback _infer_variable_mode（向后兼容，存量组件渐进迁移）
func get_variable_modes() -> Array[Dictionary]:
    return []
```

加到 `core/base/base_instruction.gd` + `core/base/base_condition.gd`（两基类都加，条件也需精确化）。

### 4.2 _extract_variables hook
```gdscript
static func _extract_variables(inst, report: Dictionary) -> void:
    # 优先用组件声明的精确 mode
    var declared_modes := {}
    if inst.has_method("get_variable_modes"):
        for entry in inst.get_variable_modes():
            declared_modes[entry.get("name", "")] = entry.get("mode", "read_write")
    ...
    for prop in inst.get_property_list():
        ...
        var mode: String = declared_modes.get(pname, _infer_variable_mode(pname))
        var entry := {"name": name, "source_prop": pname, "mode": mode}
```

### 4.3 组件 override 示例
```gdscript
# PrintVariableValue
func get_variable_modes() -> Array[Dictionary]:
    return [{"name": "variable_name", "mode": "read"}]

# ForEach
func get_variable_modes() -> Array[Dictionary]:
    return [
        {"name": "array_variable", "mode": "read"},
        {"name": "item_variable", "mode": "write"},
        {"name": "index_variable", "mode": "write"},
    ]

# CheckVariable
func get_variable_modes() -> Array[Dictionary]:
    return [
        {"name": "variable_name", "mode": "read"},
        {"name": "compare_variable", "mode": "read"},
    ]
```

---

## 5. 验收标准

- [ ] BaseInstruction + BaseCondition 加 `get_variable_modes()`（默认空）
- [ ] `_extract_variables` hook（声明优先，fallback _infer_variable_mode）
- [ ] Phase 1（15 文件）覆盖完成，每组件 get_variable_modes 返回精确 mode
- [ ] Phase 2（~25 文件）批量覆盖
- [ ] test_topology_warning.tscn：Trigger（PrintVariable read）+ Trigger2（ArrayAdd rw）→ 不报竞态，报读写关联（write_to_read）
- [ ] 现有 ~56 analyze_problems 测试不回归
- [ ] 新增 get_variable_modes 单元测试（Phase 3）
- [ ] 未覆盖组件 fallback 行为不变（向后兼容）

---

## 6. Out of Scope

- ❌ 不改 `_infer_variable_mode` 启发式（保留作 fallback）
- ❌ 不改组件的 execute() 逻辑（仅声明 mode，不改行为）
- ❌ 不改 variable_write_to_read/write_to_write 检测逻辑（仅 mode 输入精确化）
- ❌ 不改 preset_ai_context（Phase 4 skill 更新单独做）

---

## 7. 风险

| 风险 | 缓解 |
|------|------|
| 组件 override 的 mode 与 execute() 实际行为不符 | Phase 3 测试断言 + 代码审查 |
| 覆盖不全（漏某组件） | fallback _infer_variable_mode 兜底（行为=现状，不会更差） |
| 新组件忘声明 | Phase 4 skill 约定 + 可选 CI 检查 |

---

**下一步**：用户审 spec → writing-plans（Phase 1 先行）。
