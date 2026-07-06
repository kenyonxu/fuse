# Fuse 架构整改 Phase 0+1 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development(推荐)或 superpowers:executing-plans 逐任务实现本计划。步骤使用复选框(`- [ ]`)语法跟踪。

**Goal:** 完成 Fuse 架构整改 Phase 0(基线固化)与 Phase 1(一致性与注册层修复),消除已确认的注册层缺陷,为后续 Phase 2+ 建立可回归的基线。

**Architecture:** 不做大重写。Phase 0 仅产出回归基线文档与已知问题白名单(零代码风险);Phase 1 修复 4 处确定性缺陷:`plugin.gd` 类型注册基类、`ComponentRegistry.register()` 重复累积、`fuse_inspector_plugin._can_handle()` 全量介入、扫描流程可观测性。每步独立可验收、独立可回退。

**Tech Stack:** Godot 4.6 / GDScript 2.0。测试为 `extends Node` 自包含脚本(`_ready()` 跑 print 断言 + `get_tree().quit()`),通过 Godot headless 运行场景,无 GUT 框架。

> **📋 完成状态（2026-06-16）**
> 
> | Phase | 状态 | 完成日期 | 备注 |
> |-------|:----:|----------|------|
> | Phase 0: 基线固化 | ✅ 完成 | 2026-06-16 | Tasks 0.1/0.2/0.3 全部完成 |
> | Phase 1: 一致性与注册层修复 | ✅ 完成 | 2026-06-16 | Tasks 1.1-1.5 全部完成 |

---

## 关联文档

- 评估报告:`addons/fuse/docs/system_docs/analysis/2026-04-21-fuse-architecture-assessment.md`
- 整改总计划:`addons/fuse/docs/system_docs/analysis/2026-04-21-fuse-architecture-remediation-plan.md`
- 本计划覆盖:总计划 §4(Phase 0)、§5(Phase 1)

## 整改前事实核验(2026-06-15 ground truth)

执行前已对当前代码逐项核验,结论如下(行号以当前工作树为准):

| 核验项 | 文件:行 | 当前状态 |
|--------|---------|----------|
| `plugin.gd` 行数 | plugin.gd | 606 行,上帝对象未缓解 |
| `BaseInstruction` 注册 | plugin.gd:22 | 注册 `RefCounted`,实际 `extends Resource`(base_instruction.gd:4)❌ |
| `BaseCondition` 注册 | plugin.gd:24 | 注册 `Node`,实际 `extends Resource`(base_condition.gd:4)❌ |
| `ExecutionContext` 注册 | plugin.gd:23 | 注册 `RefCounted`,实际 `extends RefCounted`(execution_context.gd:2)✓ |
| `ComponentRegistry.register` 去重 | component_registry.gd:100-101 | Array 无条件 `append` + Map 覆盖,`get_all()` 重复风险 ❌ |
| 注册流程真相 | plugin.gd:418-424 | 实际走 `InstructionRegistry/EventRegistry/ConditionRegistry`,三者均为 `ComponentRegistry.register()` 薄封装 → 修复点确在 `ComponentRegistry` |
| `_can_handle()` | fuse_inspector_plugin.gd:15-17 | `return true`,介入所有对象 ❌ |
| 扫描统计 | plugin.gd:391-431 | 已打印 找到/成功/失败数与失败原因,缺「重复 identifier 数」 |
| `ExecutionContext` 行数 | execution_context.gd | 1623 行(评估时 +167),膨胀未遏制 |
| 测试基础设施 | tests/ | 无 GUT;`extends Node` 自包含脚本;runner:test_runner.gd / memory_test_runner.gd / validate_syntax.gd |

> Phase 1 仅处理「注册基类」「重复累积」「_can_handle」「扫描可观测性」4 项。`ExecutionContext` 膨胀(1623 行)、`GlobalVariableAssistant` 脱树兜底、`BaseInstruction` 静态 metadata 边界留待 Phase 3/4。

---

## File Structure

本计划涉及以下文件:

**Phase 0(新增文档,零代码):**
- Create: `addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md` — 核心回归场景索引 + headless 运行命令 + 基线快照
- Create: `addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-known-issues-allowlist.md` — 整改前允许暂存的问题白名单

**Phase 1(代码修复):**
- Modify: `addons/fuse/plugin.gd:22` — `BaseInstruction` 注册基类 RefCounted→Resource
- Modify: `addons/fuse/plugin.gd:24` — `BaseCondition` 注册基类 Node→Resource
- Create: `addons/fuse/tests/fixtures/fixture_instruction.gd` — 固定 identifier 的测试用指令(去重测试夹具)
- Create: `addons/fuse/tests/test_registry_dedup.gd` — 去重行为测试脚本
- Create: `addons/fuse/tests/test_registry_dedup.tscn` — 测试场景
- Modify: `addons/fuse/editor/component_registry.gd:95-103` — `register()` 改 upsert,`component_info` 增 `identifier` 字段
- Modify: `addons/fuse/editor/component_registry.gd`(新增 static var/方法) — 重复计数与查询
- Modify: `addons/fuse/plugin.gd:391-431` — 扫描末尾输出重复 identifier 数
- Modify: `addons/fuse/editor/fuse_inspector_plugin.gd:15-17` — `_can_handle()` 收紧

**职责边界:** `ComponentRegistry` 是注册唯一真相源(去重 + 计数);三个专用 Registry 保持薄封装不动;`fixture_instruction.gd` 仅测试用,不进生产扫描目录(instructions/),放在 tests/fixtures/ 避免被 `_register_all_instructions` 扫到。

---

## 运行环境约定

本计划所有命令假设以下变量(执行者按实际环境调整):

```bash
# bash (Git Bash on Windows)
# 按运行环境二选一(取消注释其一)
GODOT="E:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64.exe"; PROJECT="E:/Godot/GodotProjects/project-juicy-godot"  # Windows
#GODOT="/home/kai-remote/.local/bin/godot"; PROJECT="/home/kai-remote/github/project-juicy-godot"  # Linux
```

测试运行统一格式:

```bash
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/<test>.tscn"
```

> 提交(commit)时机遵循项目规范:征得用户同意后再提交。本计划每个 Task 末尾给出建议 commit message,执行者按需在用户确认后执行。

---

# Phase 0:基线固化

**目标:** 在改代码前固定当前行为,后续每个 Phase 用此基线判断是否引入回归。

## Task 0.1:创建架构回归基线文档

**Files:**
- Create: `addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md`

- [x] **Step 1:写入基线文档骨架与回归维度映射** ✅ 已完成（2026-06-16，commit 6fe3b8a6）

创建文件,内容如下(7 个回归维度来自整改总计划 §10,映射到现有测试):

````markdown
# Fuse 架构整改回归基线

日期:2026-06-15
关联:整改总计划 §10 最小回归集

## 用途

本文件是 Phase 1+ 的回归基准。每次代码改动后,重跑「核心回归集」并对照「基线快照」,
确认无新增 fail。基线记录的是「整改前现状」,允许存在历史 fail,但整改不得使其恶化。

## 核心回归集(7 维度 → 现有测试)

| # | 回归维度 | 测试脚本 | 场景 | 运行命令 |
|---|---------|---------|------|----------|
| 1 | Trigger 监听事件触发 ActionRunner | test_action_runner_signals.gd | test_action_runner_signals.tscn | 见下 |
| 2 | MultiEventTrigger 多绑定+条件 | test_complete_system_refactor.gd | —(需手动场景) | 见下 |
| 3 | RuntimeEventInstance 隔离 | test_runtime_instruction_instance.gd | test_runtime_instruction_instance.tscn | 见下 |
| 4 | RuntimeActionRunnerInstance 顺序/并行 | test_instruction_concurrent_execution.gd | test_instruction_concurrent_execution.gd | 见下 |
| 5 | ExecutionContext local/scope/global 变量 | variable_lookup_optimization_test.gd | —(经 test_runner.gd) | 见下 |
| 6 | EventBus 收发 | test_event_bus.gd | test_event_bus.tscn | 见下 |
| 7 | Inspector 选择器显示 | test_component_selector.gd / test_event_condition_selector.gd | — | 编辑器手动 |

### 运行命令

```bash
# 按运行环境二选一(取消注释其一)
GODOT="E:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64.exe"; PROJECT="E:/Godot/GodotProjects/project-juicy-godot"  # Windows
#GODOT="/home/kai-remote/.local/bin/godot"; PROJECT="/home/kai-remote/github/project-juicy-godot"  # Linux

# 维度 1
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_action_runner_signals.tscn"
# 维度 3
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runtime_instruction_instance.tscn"
# 维度 4
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_instruction_concurrent_execution.gd"
# 维度 5(经 runner)
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runner.gd"
# 维度 6
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_event_bus.tscn"
```

> 维度 2、7 无独立 headless 场景,标记为「编辑器手动验证」,在 Phase 1 完成后于编辑器内确认。

## 基线快照(Phase 0 记录,Task 0.3 填充)

| 维度 | 脚本 | 基线结果 | 备注 |
|------|------|---------|------|
| 1 | test_action_runner_signals | <待填> | |
| 3 | test_runtime_instruction_instance | <待填> | |
| 4 | test_instruction_concurrent_execution | <待填> | |
| 5 | variable_lookup_optimization | <待填> | |
| 6 | test_event_bus | <待填> | |

## Phase 1 完成后复跑记录

<Phase 1 Task 1.5 填充,对照上方基线,确认无新增 fail>
````

- [x] **Step 2:commit** ✅ 已完成（commit 6fe3b8a6）

```bash
git add addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md
git commit -m "docs(fuse): add phase0 architecture regression baseline"
```

## Task 0.2:创建已知问题白名单

**Files:**
- Create: `addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-known-issues-allowlist.md`

- [x] **Step 1:写入白名单文档** ✅ 已完成（2026-06-16，commit 6fe3b8a6）

创建文件,内容如下:

````markdown
# Fuse 整改已知问题白名单

日期:2026-06-15
关联:评估报告 §5(8 个架构问题)

## 用途

记录整改前「已知存在、本轮暂不修」的问题。整改过程中若这些问题行为变化,必须记录;
Phase 1 不得让它们恶化,但也不负责修复(留待对应 Phase)。

## 白名单(本轮暂存)

| 评估项 | 问题 | 处理 Phase | 当前表现 |
|--------|------|-----------|----------|
| 5.3 | ComponentRegistry 重复累积 | **Phase 1 修(Task 1.2)** | get_all() 可能重复 |
| 5.5 | Inspector _can_handle 全量介入 | **Phase 1 修(Task 1.3)** | return true |
| 5.2 | 类型注册不一致 | **Phase 1 修(Task 1.1)** | BaseInstruction/BaseCondition |
| 5.1 | plugin.gd 上帝对象(606 行) | Phase 2 | 启动编排耦合 |
| 5.4 | GlobalVariableAssistant 脱树兜底 | Phase 3 | new() 后 _ready 不执行 |
| 5.6 | ExecutionContext 1623 行 | Phase 4 | 职责过重 |
| 5.7 | BaseInstruction 静态 metadata 边界 | Phase 4 | 静态/实例模糊 |
| 5.8 | 静态分析文本启发式 | 暂缓(总计划 §14) | 非 AST 语义 |

## 验收对照

Phase 1 完成后:5.2 / 5.3 / 5.5 应移出本白名单(已修);5.1 / 5.4 / 5.6 / 5.7 / 5.8 保持不变。
````

- [x] **Step 2:commit** ✅ 已完成（commit 6fe3b8a6）

```bash
git add addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-known-issues-allowlist.md
git commit -m "docs(fuse): add phase0 known-issues allowlist"
```

## Task 0.3:跑基线快照并回填

**Files:**
- Modify: `addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md`(回填「基线快照」表)

- [x] **Step 1:逐个跑核心回归集,记录输出** ✅ 已完成（2026-06-16，commit 79bc0614）

```bash
# 按运行环境二选一(取消注释其一)
GODOT="E:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64.exe"; PROJECT="E:/Godot/GodotProjects/project-juicy-godot"  # Windows
#GODOT="/home/kai-remote/.local/bin/godot"; PROJECT="/home/kai-remote/github/project-juicy-godot"  # Linux

"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_action_runner_signals.tscn" 2>&1 | tee /tmp/baseline_1.txt
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runtime_instruction_instance.tscn" 2>&1 | tee /tmp/baseline_3.txt
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_instruction_concurrent_execution.gd" 2>&1 | tee /tmp/baseline_4.txt
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runner.gd" 2>&1 | tee /tmp/baseline_5.txt
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_event_bus.tscn" 2>&1 | tee /tmp/baseline_6.txt
```

- [x] **Step 2:从输出提取通过/失败数,回填 baseline 文档的「基线快照」表** ✅ 已完成（2026-06-16，commit 79bc0614）

对每个测试,在输出里找「通过/失败」「passed/failed」「✓/✗」汇总行,如实填入表格(即使有 fail 也记录,基线只要求「记录现状」)。

- [ ] **Step 3:commit**

```bash
git add addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md
git commit -m "docs(fuse): record phase0 baseline snapshot"
```
✅ 已完成（commit 79bc0614）

---

# Phase 1:一致性与注册层修复

**目标:** 修复确定性错误与数据一致性缺陷(总计划 §5)。改动小、风险低、收益明确。

## Task 1.1:修正类型注册基类 + 全量校验

**Files:**
- Modify: `addons/fuse/plugin.gd:22`
- Modify: `addons/fuse/plugin.gd:24`
- Modify: `addons/fuse/plugin.gd`(可选:新增校验函数)

- [ ] **Step 1:跑核验脚本,确认全量不一致项**

在 bash 用 ripgrep 对照 `add_custom_type` 注册基类与脚本实际继承:

```bash
# 列出 plugin.gd 所有 add_custom_type 的 (类型名, 注册基类, 脚本路径)
rg "add_custom_type\(" addons/fuse/plugin.gd
# 列出对应脚本的 extends
rg "^class_name \w+ extends \w+|^extends \w+" addons/fuse/core addons/fuse/editor addons/fuse/utils
```

预期:仅 `BaseInstruction`(RefCounted vs Resource)、`BaseCondition`(Node vs Resource)两处不一致,其余一致(已预核验)。

- [ ] **Step 2:修正 BaseInstruction 注册基类**

`addons/fuse/plugin.gd:22`,将:

```gdscript
add_custom_type("BaseInstruction", "RefCounted", preload("res://addons/fuse/core/base/base_instruction.gd"), preload("res://icon.svg"))
```

改为:

```gdscript
add_custom_type("BaseInstruction", "Resource", preload("res://addons/fuse/core/base/base_instruction.gd"), preload("res://icon.svg"))
```

- [ ] **Step 3:修正 BaseCondition 注册基类**

`addons/fuse/plugin.gd:24`,将:

```gdscript
add_custom_type("BaseCondition", "Node", preload("res://addons/fuse/core/base/base_condition.gd"), preload("res://icon.svg"))
```

改为:

```gdscript
add_custom_type("BaseCondition", "Resource", preload("res://addons/fuse/core/base/base_condition.gd"), preload("res://icon.svg"))
```

- [ ] **Step 4(可选,评估报告要求):新增类型注册校验函数**

在 `plugin.gd` 的 `_enter_tree()` 内、所有 `add_custom_type` 之后,加入开发期校验调用;并在文件末尾新增辅助函数。

在 `_enter_tree()` 末尾(`print("Fuse Visual Programming 插件已激活")` 之前)插入:

```gdscript
    # 开发期校验:类型注册基类与脚本实际继承一致性
    if Engine.is_editor_hint():
        _validate_custom_type_registrations()
```

在 `plugin.gd` 类内(建议放在 `_get_configuration_warnings` 之后)新增:

```gdscript
## 校验所有 add_custom_type 的注册基类与脚本实际继承是否一致
## 开发期输出不一致警告,防止类型注册偏差
func _validate_custom_type_registrations() -> void:
    # [类型名, 注册基类, 脚本路径]
    var registrations: Array[Dictionary] = [
        {"name": "BaseInstruction", "base": "Resource", "script": "res://addons/fuse/core/base/base_instruction.gd"},
        {"name": "ExecutionContext", "base": "RefCounted", "script": "res://addons/fuse/core/base/execution_context.gd"},
        {"name": "BaseCondition", "base": "Resource", "script": "res://addons/fuse/core/base/base_condition.gd"},
        {"name": "BaseVariable", "base": "Resource", "script": "res://addons/fuse/core/base/base_variable.gd"},
        {"name": "ActionRunner", "base": "Resource", "script": "res://addons/fuse/core/base/action_runner.gd"},
        {"name": "BaseEvent", "base": "Resource", "script": "res://addons/fuse/core/base/base_event.gd"},
        {"name": "BaseTrigger", "base": "Node", "script": "res://addons/fuse/core/base_trigger.gd"},
        {"name": "Trigger", "base": "Node", "script": "res://addons/fuse/core/trigger.gd"},
    ]
    for reg in registrations:
        var script = load(reg.script) as GDScript
        if script == null:
            push_warning("[Fuse] 校验失败:无法加载 %s" % reg.script)
            continue
        var actual_base := ""
        var base_script = script.get_base_script()
        if base_script != null:
            actual_base = base_script.get_global_name()
        else:
            actual_base = script.get_instance_base_type()
        if actual_base != reg.base:
            push_warning("[Fuse] 类型注册不一致:%s 注册为 %s,实际继承 %s" % [reg.name, reg.base, actual_base])
```

> 说明:`get_base_script()` 对继承自定义类的脚本(如 Trigger→BaseTrigger)返回基脚本,`get_global_name()` 取其类名;对直接继承引擎类的脚本,`get_base_script()` 返回 null,回退到 `get_instance_base_type()`。

- [ ] **Step 5:手动验证**

1. 打开 Godot 编辑器,启用/重新加载 Fuse 插件。
2. 预期:控制台无「类型注册不一致」警告(若 Step 4 已加)。
3. 在 Inspector 中尝试创建 BaseInstruction、BaseCondition 资源,确认类型识别正常。

- [ ] **Step 6:commit**

```bash
git add addons/fuse/plugin.gd
git commit -m "fix(fuse): correct BaseInstruction/BaseCondition custom type registration base"
```

## Task 1.2:ComponentRegistry 去重(TDD)

**Files:**
- Create: `addons/fuse/tests/fixtures/fixture_instruction.gd`
- Create: `addons/fuse/tests/test_registry_dedup.gd`
- Create: `addons/fuse/tests/test_registry_dedup.tscn`
- Modify: `addons/fuse/editor/component_registry.gd:95-103`

- [ ] **Step 1:创建测试夹具指令(固定 identifier)**

创建 `addons/fuse/tests/fixtures/fixture_instruction.gd`:

```gdscript
@tool
class_name FixtureInstruction extends BaseInstruction

## 测试专用指令,固定 identifier,用于 ComponentRegistry 去重测试
## 放在 tests/fixtures/ 不被 _register_all_instructions 扫描(instructions/ 目录外)

static func _get_instruction_metadata() -> InstructionMetadata:
    var meta = InstructionMetadata.new()
    meta.name_key = "TestFixtureInstruction"
    meta.name = "测试夹具指令"
    meta.category = "Test"
    meta.description = "仅供 ComponentRegistry 去重测试使用"
    return meta
```

> 注意:`tests/fixtures/` 不在 `_register_all_instructions` 扫描的 `instructions/`、`integration/`、`fuse_generated/instructions/` 路径内,不会被生产扫描注册,避免污染真实注册表。

- [ ] **Step 2:写去重测试脚本(此时应 FAIL)**

创建 `addons/fuse/tests/test_registry_dedup.gd`:

```gdscript
extends Node

## ComponentRegistry 去重行为测试
## 验证:同一 identifier 重复注册后,get_all() 仅返回一份

const FixtureInstruction = preload("res://addons/fuse/tests/fixtures/fixture_instruction.gd")

var _passed := 0
var _failed := 0

func _ready():
    print("=== ComponentRegistry 去重测试 ===")
    _test_dedup_on_duplicate_identifier()
    _test_unique_identifiers_unchanged()
    _print_summary()
    await get_tree().create_timer(0.5).timeout
    get_tree().quit(1 if _failed > 0 else 0)

func _test_dedup_on_duplicate_identifier() -> void:
    ComponentRegistry.clear_all(ComponentRegistry.ComponentType.INSTRUCTION)

    # 同一脚本注册两次 → 同一 identifier
    ComponentRegistry.register(ComponentRegistry.ComponentType.INSTRUCTION, FixtureInstruction, "_get_instruction_metadata")
    ComponentRegistry.register(ComponentRegistry.ComponentType.INSTRUCTION, FixtureInstruction, "_get_instruction_metadata")

    var all = ComponentRegistry.get_all(ComponentRegistry.ComponentType.INSTRUCTION)
    var count = all.size()

    if count == 1:
        print("✓ 重复注册去重:get_all 返回 %d 项(期望 1)" % count)
        _passed += 1
    else:
        print("✗ 重复注册去重:get_all 返回 %d 项(期望 1)" % count)
        _failed += 1

    # map 查询应能命中且为最后一份
    var by_name = ComponentRegistry.get_by_name(ComponentRegistry.ComponentType.INSTRUCTION, "TestFixtureInstruction")
    if by_name.size() > 0:
        print("✓ get_by_name 命中")
        _passed += 1
    else:
        print("✗ get_by_name 未命中")
        _failed += 1

func _test_unique_identifiers_unchanged() -> void:
    ComponentRegistry.clear_all(ComponentRegistry.ComponentType.INSTRUCTION)
    # 单次注册
    ComponentRegistry.register(ComponentRegistry.ComponentType.INSTRUCTION, FixtureInstruction, "_get_instruction_metadata")
    var count = ComponentRegistry.get_all(ComponentRegistry.ComponentType.INSTRUCTION).size()
    if count == 1:
        print("✓ 单次注册:get_all 返回 %d 项(期望 1)" % count)
        _passed += 1
    else:
        print("✗ 单次注册:get_all 返回 %d 项(期望 1)" % count)
        _failed += 1

func _print_summary() -> void:
    print("\n=== 测试结果:%d 通过,%d 失败 ===" % [_passed, _failed])
```

- [ ] **Step 3:创建测试场景**

新建场景文件 `addons/fuse/tests/test_registry_dedup.tscn`(根节点 Node,挂载脚本)。因 .tscn 手写易错,用 Godot 命令行生成更稳;此处给出最小文本内容,执行者可直接写入:

```
[gd_scene load_steps=2 format=3 uid="uid://bfusededuptest0001"]

[ext_resource type="Script" path="res://addons/fuse/tests/test_registry_dedup.gd" id="1"]

[node name="TestRegistryDedup" type="Node"]
script = ExtResource("1")
```

> 若 uid 冲突,执行者可在 Godot 编辑器打开该场景让其自动分配 uid,或删除 `uid=` 字段。

- [ ] **Step 4:跑测试,确认 FAIL(修复前)**

```bash
# 按运行环境二选一(取消注释其一)
GODOT="E:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64.exe"; PROJECT="E:/Godot/GodotProjects/project-juicy-godot"  # Windows
#GODOT="/home/kai-remote/.local/bin/godot"; PROJECT="/home/kai-remote/github/project-juicy-godot"  # Linux
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_registry_dedup.tscn"
```

预期输出包含:`✗ 重复注册去重:get_all 返回 2 项(期望 1)`(修复前 Array 无条件 append 导致重复)。退出码 1。

- [ ] **Step 5:修复 ComponentRegistry.register() 为 upsert**

修改 `addons/fuse/editor/component_registry.gd`。当前 95-103 行为:

```gdscript
	var component_info = {
		"class": component_class,
		"metadata": metadata
	}

	components_array.append(component_info)
	components_map[identifier] = component_info

	return true
```

改为(新增 identifier 字段用于 array 定位 + upsert 逻辑 + 重复计数):

```gdscript
	var component_info = {
		"identifier": identifier,
		"class": component_class,
		"metadata": metadata
	}

	if components_map.has(identifier):
		print("警告：%s '%s' 已经注册，将更新" % [type_name, identifier])
		# upsert:map 更新 + array 中定位并替换对应项
		components_map[identifier] = component_info
		var updated := false
		for i in range(components_array.size()):
			if components_array[i].get("identifier", "") == identifier:
				components_array[i] = component_info
				updated = true
				break
		if not updated:
			components_array.append(component_info)
		# 累加重复计数(Task 1.4 使用)
		_increment_duplicate_count(component_type)
	else:
		components_array.append(component_info)
		components_map[identifier] = component_info

	return true
```

> `_increment_duplicate_count` 在 Task 1.4 定义。Task 1.2 先加一个占位空函数避免编译错误,或直接在 Task 1.4 一起完成。**为保证本步可独立编译运行**,先在 ComponentRegistry 类内(static var 区域附近)加入 Task 1.4 的计数设施(见 Step 6),再回来跑测试。

- [ ] **Step 6:加入重复计数设施(供 Step 5 引用,亦属 Task 1.4)**

在 `component_registry.gd` 顶部 static var 区(约 24 行后)新增:

```gdscript
# 重复注册计数(扫描可观测性,Task 1.4 使用)
static var _duplicate_counts: Dictionary = {}  # ComponentType -> int
```

在类内新增(建议放在 `clear_all` 附近):

```gdscript
## 累加重复注册计数(内部使用)
static func _increment_duplicate_count(component_type: ComponentType) -> void:
	_duplicate_counts[component_type] = _duplicate_counts.get(component_type, 0) + 1

## 获取指定类型的重复注册次数
static func get_duplicate_count(component_type: ComponentType) -> int:
	return _duplicate_counts.get(component_type, 0)

## 重置指定类型的重复注册计数
static func reset_duplicate_count(component_type: ComponentType = -1) -> void:
	if component_type == -1:
		_duplicate_counts.clear()
	else:
		_duplicate_counts.erase(component_type)
```

并在 `clear_all` 方法内(清空 components 的同时)补一行清重复计数,避免跨扫描累积:

```gdscript
# 在 clear_all 末尾追加
_duplicate_counts.erase(component_type)  # 清空时一并清重复计数
```

> 注意:`clear_all` 的「清空所有」分支(component_type == -1)已 `_duplicate_counts.clear()`(由 reset_duplicate_count(-1) 或直接 clear);若用 erase 需对 -1 分支单独处理。简化:在 clear_all 的全清分支直接 `_duplicate_counts.clear()`,在指定类型分支 `_duplicate_counts.erase(component_type)`。

- [ ] **Step 7:跑测试,确认 PASS**

```bash
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_registry_dedup.tscn"
```

预期:`✓ 重复注册去重:get_all 返回 1 项(期望 1)` + 其余 ✓,退出码 0。

- [ ] **Step 8:commit**

```bash
git add addons/fuse/tests/fixtures/fixture_instruction.gd addons/fuse/tests/test_registry_dedup.gd addons/fuse/tests/test_registry_dedup.tscn addons/fuse/tests/fixtures/ addons/fuse/editor/component_registry.gd
git commit -m "fix(fuse): dedupe ComponentRegistry.register to prevent get_all duplicates"
```

## Task 1.3:fuse_inspector_plugin._can_handle() 收紧

**Files:**
- Modify: `addons/fuse/editor/fuse_inspector_plugin.gd:15-17`

- [ ] **Step 1:收紧 _can_handle 为「Fuse 类型白名单 + 属性名探测」**

当前 `fuse_inspector_plugin.gd:15-17`:

```gdscript
func _can_handle(object: Object) -> bool:
	# 处理所有对象，只要包含 Fuse 相关属性
	return true
```

改为:

```gdscript
func _can_handle(object: Object) -> bool:
	if object == null:
		return false
	# 1. Fuse 核心类型直接放行
	if object is BaseInstruction or object is BaseEvent or object is BaseCondition \
			or object is BaseVariable or object is ActionRunner \
			or object is BaseTrigger:
		return true
	# 2. 其余对象:快速探测是否含 Fuse 组件属性
	#    (每对象仅调用一次 _can_handle,非 Fuse 对象提前返回 false,跳过整个 _parse_property)
	var prop_list = object.get_property_list()
	for p in prop_list:
		var pname: String = p.get("name", "")
		if pname == "instructions" or pname.ends_with("_instructions") \
				or pname == "event" or pname.ends_with("_event") \
				or pname == "condition" or pname.ends_with("_condition") \
				or pname == "event_definition":
			return true
	return false
```

> 设计权衡:`return true` 让所有对象进入 `_parse_property`(每属性调用),开销大且与其他 Inspector 插件冲突概率高。本实现对 Fuse 核心类秒过;非 Fuse 对象只扫一次属性名列表,无 Fuse 属性则整体跳过 `_parse_property`。既收敛边界,又不丢「挂 Fuse 属性的非 Fuse 节点」(如自定义 Node 挂 `instructions: Array[BaseInstruction]`)的选择器功能。

- [ ] **Step 2:手动验证(编辑器内)**

打开 `demos/fuse/` 下任一场景(如含 Trigger 的场景),选中:
- Trigger / MultiEventTrigger 节点 → Inspector 中 `event_definition`、`condition` 应仍有「选择器」按钮。
- ActionRunner 资源 → `instructions` 数组应有「选择器」按钮。
- 选中一个无关节点(如纯 Sprite2D)→ 不应触发 Fuse Inspector 解析(无异常、无多余按钮)。

- [ ] **Step 3:commit**

```bash
git add addons/fuse/editor/fuse_inspector_plugin.gd
git commit -m "refactor(fuse): narrow fuse_inspector_plugin._can_handle to Fuse objects"
```

## Task 1.4:扫描统计增强(重复 identifier 计数)

**Files:**
- Modify: `addons/fuse/plugin.gd:350-431`(`_register_all_instructions`/`_register_events`/`_register_conditions`/`_register_components_from_folders`)

> 前置:ComponentRegistry 的重复计数设施已在 Task 1.2 Step 6 加入。本 Task 只需在 plugin.gd 扫描末尾读取并打印。

- [ ] **Step 1:在扫描前重置计数,扫描后输出重复数**

修改 `plugin.gd` 的 `_register_components_from_folders`(当前 378-431 行)。在方法开头 `var all_files` 之前插入重置:

```gdscript
    # 扫描前重置该类型的重复计数
    var ctype_for_reset: ComponentRegistry.ComponentType
    match registry_name:
        "InstructionRegistry":
            ctype_for_reset = ComponentRegistry.ComponentType.INSTRUCTION
        "EventRegistry":
            ctype_for_reset = ComponentRegistry.ComponentType.EVENT
        "ConditionRegistry":
            ctype_for_reset = ComponentRegistry.ComponentType.CONDITION
        _:
            ctype_for_reset = -1
    if ctype_for_reset != -1:
        ComponentRegistry.reset_duplicate_count(ctype_for_reset)
```

在方法末尾现有的 `print("Fuse: 注册完成 - 找到 %d 个文件，成功注册 %d 个%s" % ...)` 之后,追加重复数输出:

```gdscript
    # 输出重复 identifier 统计
    if ctype_for_reset != -1:
        var dup_count = ComponentRegistry.get_duplicate_count(ctype_for_reset)
        if dup_count > 0:
            print("Fuse: 发现 %d 个重复 %s identifier(已自动去重更新)" % [dup_count, component_label])
```

- [ ] **Step 2:验证启动日志**

打开 Godot 编辑器,启用/重载 Fuse 插件,观察控制台输出。预期:
- 正常情况:三行「注册完成」(指令/事件/条件),无重复提示(或若存在重复 identifier,显示「发现 N 个重复…已自动去重更新」)。
- 无报错。

- [ ] **Step 3:commit**

```bash
git add addons/fuse/plugin.gd
git commit -m "feat(fuse): report duplicate component identifiers during scan"
```

## Task 1.5:Phase 1 回归验证

**Files:**
- Modify: `addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md`(回填「Phase 1 完成后复跑记录」)

- [ ] **Step 1:复跑 Task 0.3 的核心回归集**

```bash
# 按运行环境二选一(取消注释其一)
GODOT="E:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64.exe"; PROJECT="E:/Godot/GodotProjects/project-juicy-godot"  # Windows
#GODOT="/home/kai-remote/.local/bin/godot"; PROJECT="/home/kai-remote/github/project-juicy-godot"  # Linux

"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_action_runner_signals.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runtime_instruction_instance.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_instruction_concurrent_execution.gd"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runner.gd"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_event_bus.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_registry_dedup.tscn"
```

预期:通过数 ≥ Phase 0 基线(Task 0.3 记录值),无新增 fail。`test_registry_dedup` 全绿。

- [ ] **Step 2:手动验证清单**

- [ ] 插件启用无「类型注册不一致」警告(Task 1.1)
- [ ] demos/fuse 场景 Inspector 选择器按钮正常(Task 1.3)
- [ ] 启动日志含三行「注册完成」,重复数正确(Task 1.4)
- [ ] 已知问题白名单中 5.2/5.3/5.5 已移出(已修)

- [ ] **Step 3:回填 baseline 文档「Phase 1 完成后复跑记录」段**

如实记录复跑结果,与基线对照。

- [ ] **Step 4:更新白名单(5.2/5.3/5.5 移出)**

修改 `2026-06-15-fuse-known-issues-allowlist.md`,将 5.2/5.3/5.5 标记为「Phase 1 已修复」。

- [ ] **Step 5:commit**

```bash
git add addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-known-issues-allowlist.md
git commit -m "docs(fuse): mark phase1 complete against regression baseline"
```

---

## Self-Review

执行前自检清单(对照总计划 §4 Phase 0、§5 Phase 1):

**1. 总计划覆盖:**
- Phase 0 §4.2 回归维度(7 项)→ Task 0.1 映射表 ✓
- Phase 0 §4.2 已知问题白名单 → Task 0.2 ✓
- Phase 1 §5.2 类型注册修正(含 ExecutionContext 校验)→ Task 1.1(ExecutionContext 已预核验为正确,校验函数覆盖)✓
- Phase 1 §5.3 Registry 重复累积 → Task 1.2 ✓
- Phase 1 §5.4 扫描去重与统计 → Task 1.4 ✓
- Phase 1 §5.4 补充:`_can_handle` 一行修复提前 → Task 1.3 ✓
- Phase 1 §5.1 开发期校验函数 → Task 1.1 Step 4 ✓

**2. Placeholder 扫描:** 无 TBD/TODO;所有代码步骤含完整代码;所有命令含确切路径与预期输出。

**3. 类型/签名一致性:**
- `ComponentRegistry._increment_duplicate_count` / `get_duplicate_count` / `reset_duplicate_count`(Task 1.2 Step 6 定义)↔ Task 1.4 Step 1 调用 ✓
- `component_info["identifier"]` 字段(Task 1.2 Step 5)↔ 搜索/查询逻辑未依赖该字段,仅 register 内部去重使用 ✓
- `FixtureInstruction._get_instruction_metadata()` 返回 `InstructionMetadata`(name_key="TestFixtureInstruction")↔ 测试断言 `get_by_name(..., "TestFixtureInstruction")` ✓

**4. 风险点:**
- Task 1.2 Step 3 的 `.tscn` uid 可能冲突 → 已注明可编辑器自动分配或删 uid 字段。
- Task 1.2 Step 5/6 互相依赖(register 引用 `_increment_duplicate_count`)→ 已合并到同一 Task,顺序执行可编译。
- Task 1.3 属性探测可能漏掉非常规命名的 Fuse 属性 → 已覆盖 instructions/event/condition/event_definition 及 _instructions/_event/_condition 后缀,这是 `_parse_property` 实际处理的全部模式(见 fuse_inspector_plugin.gd:19-62)。

---

## 执行交接

计划已保存至 `addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-phase0-1-implementation-plan.md`。两种执行方式:

**1. Subagent 驱动(推荐)** — 每个 Task 派发独立 subagent,任务间审查,迭代快。
**2. 内联执行** — 本会话内按 executing-plans 批量执行,带检查点审查。

选择哪种?
