# 序列化与编译缓存分析报告


> **分析时点**：2026-07-07（经同日全量文档审计逐篇核对代码；此后实现演进以源码为准，近期已核对的机制性结论见 threading / runtime_instance / preset_nested 等篇）
## 文档概述

本报告对 Fuse 可视化编程系统中的两个底层基础设施进行分析：

- `InstructionSerializer`（指令序列化器）— 指令对象的反射式序列化/反序列化
- `CompiledInstructionSequence`（编译指令序列缓存）— Phase 3 性能优化的预编译缓存

两者分属不同子系统（持久化 vs. 运行时性能优化），但在 Fuse 的"ActionRunner → RuntimeActionRunnerInstance"执行链上分别承担"状态保留"与"热路径加速"职责，是 analysis 系列此前未单独覆盖的两块缺口。

**源文件:**
- [instruction_serializer.gd](../../../../core/serialization/instruction_serializer.gd)（135 行）
- [compiled_instruction_sequence.gd](../../../../core/execution/compiled_instruction_sequence.gd)（142 行）

**基类:** 两者均 `extends RefCounted`（非 Resource，纯逻辑组件）

---

## 1. InstructionSerializer

### 1.1 类概述和职责

`InstructionSerializer`（`core/serialization/instruction_serializer.gd:1-3`）是 `@tool extends RefCounted` 的工具类，负责把指令对象 (`BaseInstruction` 子类) 转换为纯字典数据，以及反向重建指令实例。

**设计要点（脚本头部注释明确）：**
> 提供指令的序列化和反序列化功能，独立于编辑器工具类。确保核心运行时代码不依赖编辑器模块。

即：解耦"运行时核心"与"编辑器反射工具"，让 `core/` 在非编辑器运行时也能做指令的字典化处理。

### 1.2 序列化格式

序列化产物是 **扁平字典**：

```
{
    "type": "<class_name 字符串>",   # 类型信息，必填键
    "<属性名1>": <值>,                # 所有 usage 含 PROPERTY_USAGE_STORAGE 的属性
    "<属性名2>": <值>,
    ...
}
```

格式特征：
- 无版本号字段、无元数据字段，只靠 `"type"` 键路由类型
- 属性值原样取自 `instruction.get(name)`（未做深拷贝/类型转换），复杂子资源（嵌套 Resource）直接塞进字典
- 批量 API (`serialize_instructions_batch`) 产出 `Array[Dictionary]`，外层无包装结构

### 1.3 API（均为 static）

| 方法 | 签名（:行号） | 行为 |
|------|--------------|------|
| `serialize_instruction` | `(instruction: BaseInstruction) -> Dictionary`（:16） | 反射取 `PROPERTY_USAGE_STORAGE` 属性并写入字典；末尾追加 `"type"`。空指令返回 `{}`。属性列表按 `class_name` 做静态缓存（见 1.5） |
| `deserialize_instruction` | `(data: Dictionary) -> BaseInstruction`（:46） | 读 `data["type"]` → `ClassDB.instantiate(type)` 创建实例 → 遍历字典其余键 `set(name, value)`。无 `"type"` 键或类型不存在返回 `null` |
| `serialize_instructions_batch` | `(instructions: Array[BaseInstruction]) -> Array[Dictionary]`（:76） | 对每条 `is BaseInstruction` 的指令调用 `serialize_instruction` |
| `deserialize_instructions_batch` | `(data_array: Array[Dictionary]) -> Array[BaseInstruction]`（:86） | 对每条调用 `deserialize_instruction`，跳过返回 `null` 的项 |
| `validate_serialized_data` | `(data: Dictionary) -> bool`（:97） | `data and data.has("type") and ClassDB.class_exists(data["type"])` |
| `get_instruction_description` | `(instruction: BaseInstruction) -> String`（:103） | 硬编码 match 几个内置指令类型（PlaySound/PlayAnimation/ScreenShake/Print/Wait/Count）拼接可读描述；默认返回 `class_name` |
| `_create_instruction` | `(type: String) -> BaseInstruction`（:66，私有） | `ClassDB.class_exists(type)` ? `ClassDB.instantiate(type)` : `push_error` + 返回 `null` |

**反序列化的关键约束**：依赖 `ClassDB`。这意味着所有可被序列化的指令必须以 `class_name XxxInstruction extends BaseInstruction` 声明，并经插件注册（参见 [plugin.gd:113](../../../../plugin.gd)、[fuse_type_registrar.gd:21](../../../../editor/bootstrap/fuse_type_registrar.gd)）注册到 ClassDB，否则 `ClassDB.class_exists()` 会失败并返回 `null`。

### 1.4 与 BaseInstruction 的关系

**关键澄清**：`BaseInstruction`（`core/base/base_instruction.gd`）**并未定义** `serialize()` 或 `deserialize()` 方法。经 `Grep` 核实，基类只有 `get_description()` 等业务方法，不存在协议式的序列化接口。

因此 `InstructionSerializer` 是**纯反射式序列化器**：
- 写：扫描 `instruction.get_property_list()`，筛 `property.usage & PROPERTY_USAGE_STORAGE` 的属性（Godot 内置的"会被 ResourceSaver 持久化的属性"标志位）
- 读：`instruction.set(name, value)`
- 完全不依赖指令子类自定义任何序列化协议

这种设计的代价与好处见 §3。

### 1.5 属性列表缓存

```gdscript
static var _property_cache: Dictionary = {}   # :11
```

- 键：指令的 `class_name`（通过 `instruction.get_script().get_class_name()` 获取）
- 值：`Array<StringName>`，仅含 `PROPERTY_USAGE_STORAGE` 属性名
- 首次遇到某类型走完整反射（`get_property_list()` 遍历），之后命中缓存直接复用

> 注：`_property_cache` 是进程级静态字典，无失效机制。由于 GDScript 类结构在运行期不变，这通常是安全的；但若开发期热重载脚本，旧缓存可能残留。

### 1.6 ActionRunner 中的集成

`ActionRunner.serialize()` / `deserialize(data)`（[action_runner.gd:608-643](../../../../core/base/action_runner.gd)）使用 `InstructionSerializer` 序列化自身配置：

```
ActionRunner.serialize() → Dictionary
{
    "execution_mode": int,
    "stop_on_error": bool,
    "instructions": [InstructionSerializer.serialize_instruction(i), ...]   # :622
}

ActionRunner.deserialize(data):
    execution_mode = data["execution_mode"]
    stop_on_error = data["stop_on_error"]
    for d in data["instructions"]:
        instructions.append(InstructionSerializer.deserialize_instruction(d))   # :639
```

### 1.7 preload 与全局类解析（重要澄清）

**当前事实状态（已逐行核实）：**

| 文件 | 行号 | 内容 | 状态 |
|------|------|------|------|
| `action_runner.gd` | :6 | `# const InstructionSerializer = preload(...)` | **已注释** |
| `action_runner.gd` | :622, :639 | `InstructionSerializer.serialize_instruction(...)` / `deserialize_instruction(...)` | **活跃调用** |
| `instruction_serializer.gd` | :3 | `class_name InstructionSerializer` | **全局类** |
| `runtime_action_runner_instance.gd` | :9 | `# const CompiledInstructionSequenceClass = preload(...)` | **已注释** |
| `action_runner.gd` | :9 | `const CompiledInstructionSequenceClass = preload(...)` | **活跃** |

`InstructionSerializer` 在 `action_runner.gd:6` 的 preload 已被注释，但因 `class_name InstructionSerializer` 的存在，符号经全局类表（ClassDB）解析仍可在 :622/:639 直接引用。**早期注释是历史遗留，当前调用链完全有效**。`[AUDIT_REPORT_2026-07-07.md](AUDIT_REPORT_2026-07-07.md)` 已就此作过澄清（"三目录及 CompiledInstructionSequence/InstructionInstancePool/InstructionSerializer 类均真实存在且引用有效"）。

### 1.8 实际持久化路径（重要）

虽然 `ActionRunner` 自身有 `serialize()/deserialize()` API，但 **Fuse 主流持久化路径并不经过它**：

| 持久化目标 | 机制 | 是否用 InstructionSerializer |
|------------|------|------------------------------|
| **运行时场景中的 Trigger → ActionRunner → 指令**（保存为 `.tscn`/`.tres`） | Godot 原生 Resource 序列化（基于 `@export` + `PROPERTY_USAGE_STORAGE`） | **否** — 由 Godot 引擎自身完成 |
| `ActionRunner.serialize()` → Dictionary | 字典化"逻辑快照"（程序化传输/克隆用） | **是**（:622, :639） |
| Preset 导出/导入（`.tres` + `.json` 双写） | `ResourceSaver.save(preset, tres_path)` + `to_json()` | 否（走 `editor/serialization/fuse_preset_serializer.gd`，另成体系） |

也就是说，`InstructionSerializer` 不是"保存到磁盘"的工具——它只是"把指令变成可塞进 Dictionary 的形式"的工具。`@export var instructions: Array[BaseInstruction]`（[action_runner.gd:12](../../../../core/base/action_runner.gd)）这条声明才是 `.tres` 落地的真正承担者。

---

## 2. CompiledInstructionSequence

### 2.1 类概述和职责

`CompiledInstructionSequence`（`core/execution/compiled_instruction_sequence.gd:1-2`）是 Phase 3 性能优化引入的**指令序列预编译缓存**。脚本头部注释明确意图：

> Phase 3 性能优化：预编译指令序列的描述和方法绑定，减少 RuntimeActionRunnerInstance 执行时的重复计算开销。
> - 预缓存描述字符串（避免每帧重复调用 `get_description()`）
> - 预绑定执行方法（避免运行时方法查找）
> - 指令数量变化检测（快速缓存失效）

### 2.2 缓存数据结构

| 字段 | 类型（:行） | 用途 |
|------|-------------|------|
| `_descriptions` | `PackedStringArray`（:17） | 预缓存的描述字符串，按指令索引对应 |
| `_execution_callables` | `Array[Callable]`（:20） | 预绑定的 `instruction.execute`，**Phase 3.2 预留**（当前未被热路径消费） |
| `_instruction_count` | `int`（:23） | 编译时的指令数量，用于快速失效检查 |
| `_is_valid` | `bool`（:26） | 缓存整体有效性标志 |

### 2.3 API（实例方法）

| 方法 | 签名（:行） | 行为 |
|------|-------------|------|
| `compile` | `(action_runner: ActionRunner) -> bool`（:40） | 清空两个数组 → 遍历 `action_runner.instructions`：append `instruction.get_description()`（null 则空串）；若 `has_method("execute")` append `instruction.execute` 否则 `Callable()`。记录 `_instruction_count`、置 `_is_valid = true`。`action_runner == null` 直接置无效返回 `false` |
| `is_valid_for` | `(action_runner: ActionRunner) -> bool`（:71） | `_is_valid and action_runner != null and _instruction_count == action_runner.instructions.size()` |
| `get_cached_description` | `(index: int) -> String`（:83） | 边界检查后返回 `_descriptions[index]`，越界返回 `""` |
| `get_cached_callable` | `(index: int) -> Callable`（:95） | 同上，返回 `_execution_callables[index]`，越界返回 `Callable()` |
| `get_instruction_count` | `() -> int`（:106） | 返回 `_instruction_count` |
| `is_valid` | `() -> bool`（:113） | 返回 `_is_valid`（注意：不比较实际数量，纯标志位查询） |
| `invalidate` | `() -> void`（:119） | `_is_valid = false`、清空两个数组、`_instruction_count = 0` |
| `get_cache_stats` | `() -> Dictionary`（:129） | 调试用，返回 4 项状态字典 |
| `get_all_descriptions` | `() -> PackedStringArray`（:141） | 返回 `_descriptions` 副本引用 |

### 2.4 缓存失效条件

**唯一的失效检查是"指令数量"**（`is_valid_for`，:74）：

```
失效 ⟺  ¬_is_valid  ∨  action_runner == null  ∨  _instruction_count ≠ instructions.size()
```

> **设计权衡**：仅按数量做快速比较，**不检测指令内容变化**。这意味着：
> - 安全场景：仅"添加/删除指令"导致失效（典型编辑流）
> - 风险场景：仅修改某条指令的属性值（数量不变）→ **缓存不会失效，描述仍为旧值**
>
> 由于 `ActionRunner.instructions` 的 setter（[action_runner.gd:12-16](../../../../core/base/action_runner.gd)）只清 `_validation_cache`，不清 `_compiled_cache`，因此"原地改指令属性"会导致描述缓存陈旧。当前实际使用中描述主要用于调试显示（见 2.5），影响有限，但这是已知的设计缺口。

### 2.5 ActionRunner / RuntimeActionRunnerInstance 集成

**存储位置（共享语义）：**

```
ActionRunner (Resource)                       ← 定义层，可被多个 Trigger 共享
  └── _compiled_cache: RefCounted = null      # :64，类型注释为 CompiledInstructionSequence
                                                ↑ 所有 RuntimeActionRunnerInstance 共享同一份
```

**懒加载与失效检测链**（[runtime_action_runner_instance.gd:259-288](../../../../core/runtime_action_runner_instance.gd)）：

```
RuntimeActionRunnerInstance._get_cached_description(index)    # :284 热路径入口
  └── _get_or_create_compiled_cache()                          # :259
        ├── cache = action_runner._compiled_cache              # :264 取共享实例
        ├── if cache == null:
        │     cache = CompiledInstructionSequence.new()        # :266 首次懒创建
        │     action_runner._compiled_cache = cache            # :267 回填到 ActionRunner
        └── if not cache.is_valid_for(action_runner):          # :270
              cache.compile(action_runner)                     # :271 失效则重编译
  └── cache.get_cached_description(index)                      # :287 命中
```

**消费点**：仅 `_get_cached_description(index)` 一处直接调用，主要用于日志/调试输出指令描述，避免在 `is_running` 高频触发时反复调用每条指令的 `get_description()`（该方法可能涉及本地化翻译、字符串拼接）。

**未消费的预留**：`_execution_callables` 和 `get_cached_callable()` 在当前代码中**没有任何调用方**（脚本注释标注 "Phase 3.2 预留"），是为未来"轻量级执行上下文绕过方法查找"做的占位。

### 2.6 性能优化意图与实际效果

| 优化点 | 实现状态 | 当前消费情况 |
|--------|----------|--------------|
| 描述字符串预缓存 | ✅ 已实现（`compile`） | ✅ 已被 `_get_cached_description` 消费（热路径） |
| 执行 Callable 预绑定 | ✅ 已实现（`compile` 中的 `instruction.execute`） | ❌ 无调用方（Phase 3.2 占位） |
| 数量级失效检查 | ✅ 已实现（`is_valid_for`） | ✅ 已被 `_get_or_create_compiled_cache` 使用 |
| 内容级失效检测 | ❌ 未实现 | —（已知缺口） |

---

## 3. 两者对比与协作

| 维度 | InstructionSerializer | CompiledInstructionSequence |
|------|----------------------|------------------------------|
| **所属子系统** | `core/serialization/`（持久化层） | `core/execution/`（运行时执行层） |
| **职责** | 状态保留（Dictionary 化） | 性能优化（预编译缓存） |
| **基类** | `RefCounted` | `RefCounted` |
| **API 风格** | 全 `static` 方法 | 实例方法（持状态） |
| **触发时机** | 显式调用（`ActionRunner.serialize/deserialize`） | 懒加载 + 失效重编译 |
| **生命周期** | 无状态（除静态 `_property_cache`） | 与 ActionRunner 同生命周期（`_compiled_cache` 字段持有） |
| **共享范围** | 无（每次调用独立） | 一个 ActionRunner 的所有 RuntimeActionRunnerInstance 共享 |
| **失效机制** | 不适用 | 数量变化（`is_valid_for`）+ 手动 `invalidate()` |

二者无直接调用关系：序列化器不知道缓存存在，缓存也不调用序列化器。它们各自独立服务于 ActionRunner 的不同侧面。

---

## 4. 总体评估

### 4.1 优点

1. **职责清晰**：序列化器专注"字典化"，编译缓存专注"预计算"，边界分明
2. **解耦合理**：`InstructionSerializer` 把反射逻辑从 `ActionRunner` 主体剥离，`CompiledInstructionSequence` 把缓存策略从 `RuntimeActionRunnerInstance` 主体剥离，符合单一职责
3. **零依赖设计**：两者均 `extends RefCounted`、无节点引用、无信号，可在任意上下文（含 `@tool` 编辑器模式）安全使用
4. **反射缓存有效**：`_property_cache` 避免了每次序列化的 `get_property_list()` 开销（archive 中 `archive/proposals/internal_optimization_plan.md` 记录的优化点已落地）
5. **共享缓存语义正确**：`_compiled_cache` 放在 ActionRunner 而非 RuntimeActionRunnerInstance，避免每个 Trigger 触发都重编译

### 4.2 不足

1. **序列化格式无版本号**：`InstructionSerializer` 产物只有 `"type"` 键，无 schema 版本字段，未来指令字段变更将面临反序列化兼容问题
2. **`get_instruction_description` 硬编码**（:103-135）：用 `match` 枚举 6 个内置指令类型，新增指令必须改序列化器代码——与 `BaseInstruction.get_description()` 多语种本地化能力冲突（这里直接拼英文字面量）
3. **编译缓存的内容级失效缺失**（见 2.4）：原地改指令属性时描述陈旧
4. **Phase 3.2 预留未落地**：`_execution_callables`/`get_cached_callable` 至今无消费方，是潜在死代码
5. **`InstructionSerializer` preload 注释残留**（action_runner.gd:6）：依赖全局类解析虽有效，但注释与活跃调用并存易误导读者，建议清理
6. **序列化器无深拷贝**：复杂子资源属性原样塞进字典，反序列化后可能与原对象共享引用（除非调用方明确意图如此）

### 4.3 建议改进方向

1. 在 `serialize_instruction` 产物加 `"schema_version"` 字段，预留迁移路径
2. 把 `get_instruction_description` 的硬编码 match 改为委托 `instruction.get_description()`，复用本地化能力
3. `CompiledInstructionSequence.is_valid_for` 增加轻量内容指纹（如各指令描述的拼接哈希），覆盖"属性变更"场景
4. 若 Phase 3.2 暂无计划，移除 `_execution_callables` 死代码，或明确文档化为"API 预留"
5. 清理 `action_runner.gd:6` 的注释 preload，或恢复 preload 以消除对全局类表的隐式依赖

---

## 5. 与既有 analysis 的关系

| 既有文档 | 本文关系 |
|---------|----------|
| [action_runner_analysis.md](action_runner_analysis.md) | 该文 §8 已简述 `CompiledInstructionSequence`；本文对其展开为完整 API 与失效机制分析 |
| [fuse_architecture_analysis.md](fuse_architecture_analysis.md) | 该文 §11.5.1 提及 `CompiledInstructionSequence`，§（"序列化与反序列化" 节）提及 `InstructionSerializer`；本文补足 API 细节、preload 状态澄清、实际持久化路径区分 |
| [AUDIT_REPORT_2026-07-07.md](AUDIT_REPORT_2026-07-07.md) | 该文已澄清"三目录及序列化/缓存类均真实存在"；本文提供深度佐证 |
| [fuse_core_analysis_report.md](fuse_core_analysis_report.md) | 该文 §"CompiledInstructionSequence 编译指令序列"简述；本文为权威展开 |

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-07-07
**版本**: 1.0.0
