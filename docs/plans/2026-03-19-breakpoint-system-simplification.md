# 断点系统简化方案：从编辑器断点转向断点指令

**版本:** 2.0
**日期:** 2026-03-19
**状态:** 阶段 1 已完成（待执行阶段 2-5）
**前置文档:** [2026-03-18-bricks-breakpoint-system-design-v2.md](2026-03-18-bricks-breakpoint-system-design-v2.md)
**评估记录:** v1.1 通过技术评估（7/7 + 3/3 PASS），v1.2 通过 Godot 官方 API 校验，v2.0 通过运行时验证

---

## 1. 背景

### 1.1 现状

v2 断点系统实现了完整的编辑器 Inspector UI 方案，包含：

| 组件 | 文件 | 代码量 | 修订次数 |
|------|------|--------|---------|
| BreakpointConfig | `core/debugging/breakpoint_config.gd` | 34 行 | H3 修正 |
| BreakpointManager | `core/debugging/breakpoint_manager.gd` | 156 行 | H4/M3/C1 修正 |
| InstructionListEditor | `editor/instruction_selector/instruction_list_editor.gd` | 504 行 | C4/C5/C6/H6/M2/N1/N8 共 7 次修正 |
| Runner 集成 | `runtime_action_runner_instance.gd` | ~60 行修改 | C1 死锁修正 |
| ActionRunner 修改 | `base/action_runner.gd` | ~15 行修改 | H5 修正 |
| Inspector 插件修改 | `editor/bricks_inspector_plugin.gd` | ~4 行修改 | C5/N2 修正 |
| ExecutionContext 修改 | `base/execution_context.gd` | ~20 行修改 | C3 修正 |

**总计：** ~700 行新增 + ~100 行修改，15+ 次设计修订，6 个核心文件变更。

### 1.2 问题

1. **投入产出比低** — 断点本质上是一个调试工具，但实现复杂度接近核心指令系统
2. **维护负担重** — InstructionListEditor 一个文件经历了 7 次修订，涉及 Godot 插件 API 合规性问题
3. **架构侵入性强** — 修改了 RuntimeActionRunnerInstance 的执行循环、ActionRunner 的数据模型
4. **使用场景有限** — 无外部信号连接，无 .tres 序列化数据，实际使用频率低

### 1.3 决策

将断点从"系统级功能"降级为"指令级功能"：

- **移除编辑器断点 UI** — 回退到 Godot 原生数组编辑器
- **新增 BreakpointInstruction** — 标准指令，通过指令选择器添加
- **保留暂停执行** — 通过 BreakpointInstruction 内部实现
- **保留变量快照** — ExecutionContext 的 3 个快照方法可复用

---

## 2. 架构对比

### 2.1 当前架构（移除）

```
编辑器层: InstructionListEditor (504 行)
  → 右键菜单、条件对话框、忽略次数对话框、日志断点模式

数据层: BreakpointConfig (34 行) + ActionRunner.breakpoint_configs
  → @export_storage 数组，与 instructions 一一对应

运行时层: BreakpointManager (156 行) + Runner 循环集成 (60 行)
  → 静态单例、UID 生成、条件评估、await _breakpoint_resumed
```

### 2.2 新架构（指令方案）

```
指令层: BreakpointInstruction (~170 行)
  → @export: condition, log_variables, pause_execution, ignore_count, label
  → execute(): 条件评估 → 输出变量 → 可选暂停 → 完成

运行时层: 无额外组件
  → 指令自包含，不需要 Runner 循环集成

编辑器层: Godot 原生数组编辑器 + 添加指令按钮
  → 新增 _add_instruction_selector_button() 方法，参考 Event/Condition 按钮模式
```

### 2.3 核心差异

| 维度 | 编辑器断点 | 断点指令 |
|------|-----------|---------|
| 添加方式 | 右键任意指令行 | 指令选择器添加，插入到列表中 |
| 调试目标 | 任意指令（透明附加） | 需要在目标指令前插入 |
| 条件断点 | BreakpointManager 评估 | 指令内部评估（复用 ExpressionHelper） |
| 暂停机制 | Runner loop await _breakpoint_resumed | Input 轮询 + CanvasLayer 视觉提示 |
| 输出方式 | 信号 emit（无 UI 消费者） | print_rich 直接输出到 Godot 输出窗口 |
| 序列化 | @export_storage 数组 + BreakpointConfig Resource | 标准 @export 属性，随 .tres 保存 |
| 代码量 | ~700 行新 + 100 行改 | ~170 行新 + ~80 行清理 |

---

## 3. BreakpointInstruction 设计

### 3.1 导出属性

```gdscript
class_name BreakpointInstruction
extends BaseInstruction

## 条件表达式（空字符串 = 无条件命中）
## 支持: {local:x}, {scope:x}, {global:x} 变量引用
@export var condition: String = ""

## 命中时是否输出变量信息到输出窗口
@export var log_variables: bool = true

## 命中时是否暂停执行（显示提示面板，按 Enter 键恢复，仅编辑器模式有效）
@export var pause_execution: bool = false

## 忽略前 N 次命中（每次 ActionRunner 执行开始时重置）
@export var ignore_count: int = 0

## 自定义标签（用于在输出中标识断点）
@export var label: String = ""

## 运行时命中计数（不序列化，每次 ActionRunner 执行开始时重置）
var _hit_count: int = 0

## 上一次的 execution_id，用于检测新的执行周期
var _last_execution_id: String = ""
```

### 3.2 执行流程

```
execute(context):
  ① 检测新执行周期（context.execution_id 变化 → 重置 _hit_count）
  ② _hit_count += 1
  ③ ignore_count 检查 → 不满足则直接完成
  ④ condition 非空 → ExpressionHelper 评估
     → false → 直接完成
     → 错误 → 降级为无条件，继续
  ⑤ log_variables == true → 输出变量快照到输出窗口
  ⑥ pause_execution == true 且编辑器模式 → 显示 CanvasLayer 提示面板 → 等待 Enter 键
     → 导出构建中 → 降级为仅日志输出 + 警告提示
  ⑦ _on_execution_completed()
```

### 3.3 输出格式

命中时输出到 Godot 输出窗口（使用 `print_rich` 带颜色格式化）：

```
[BREAKPOINT] "检查血量" — 命中 #2 (忽略前 3 次)
  条件: {scope:health} < 50 → true
  局部变量: { counter: 5, temp: "test" }
  作用域变量: { health: 45, max_health: 100 }
  全局变量: { player_score: 1200 }
```

### 3.4 暂停机制

> **v2.0 重大变更：** 从 AcceptDialog 方案改为 Input 轮询 + CanvasLayer 视觉提示方案。
> 详见 [运行时验证记录](#9-运行时验证记录)。

暂停功能通过 Input 单例轮询实现，CanvasLayer 面板仅作为视觉提示：

```gdscript
func _show_pause_dialog(context: ExecutionContext) -> void:
    var tree = Engine.get_main_loop() as SceneTree

    # 创建提示面板（纯视觉，不需要接收输入）
    var canvas_layer = CanvasLayer.new()
    canvas_layer.layer = 128
    var parent: Node = tree.current_scene if tree.current_scene else tree.root
    parent.add_child(canvas_layer)

    # 面板内容：标题 + 提示 + 按键提示
    var panel = PanelContainer.new()
    # ... Label 节点布局 ...
    canvas_layer.add_child(panel)

    # 通过 Input 单例轮询 Enter 键（绕过 GUI 输入路由）
    while not Input.is_action_just_pressed("ui_accept"):
        await tree.process_frame

    canvas_layer.queue_free()
```

**设计决策：为什么用 Input 轮询而不是 GUI 控件？**

运行时验证发现（详见第 9 节）：
- 在 Bricks 运行时中，动态创建的 Control（Button、AcceptDialog）**无法通过 GUI 输入路由接收点击事件**
- `Input.is_mouse_button_pressed()` 和 `Input.is_action_just_pressed()` **可以正常检测输入**
- 原因分析：可能与 Bricks 的异步执行架构（RuntimeInstructionInstance + 信号桥接）影响 GUI 事件分发
- 因此采用 **CanvasLayer 视觉提示 + Input 轮询** 的混合方案

### 3.5 同步/异步处理

```gdscript
func _init():
    _is_synchronous_hint = false
    _sync_hint_manually_set = true
```

始终声明为异步指令（`_is_synchronous_hint = false`）：
- **非暂停模式：** `execute()` 同步调用 `_on_execution_completed()` → `finished` 立即发射 → Runner 的 await 立即解析，无性能影响
- **暂停模式：** `execute()` await Input 轮询 → `finished` 在 Enter 键按下后发射 → Runner 正常挂起/恢复

> **执行链路验证：** `RuntimeActionRunnerInstance` → `RuntimeInstructionInstance.execute_sync()` →
> `BaseInstruction.execute_sync()` → `can_execute_sync()` 返回 false → 调用 `execute(context)` 返回 false →
> Runner 进入 `await runtime_instruction.finished` 路径。

### 3.6 文件位置

```
addons/bricks/instructions/debug/breakpoint_instruction.gd
```

与现有 `print.gd` 同目录，归类为 Debug 类别。

---

## 4. 实施阶段

### 阶段 1：创建 BreakpointInstruction（✅ 已完成）

**新增文件：**
- `addons/bricks/instructions/debug/breakpoint_instruction.gd` (~170 行)
- `addons/bricks/instructions/debug/breakpoint_instruction.gd.uid`

**已完成内容：**
- 继承 BaseInstruction
- `_init()` 中设置 `_is_synchronous_hint = false`（支持异步暂停）
- 实现 execute() 方法（执行周期检测 + 条件评估 + 变量输出 + 可选暂停）
- 实现 `_print_breakpoint_info(context, condition_met)` 辅助方法（格式化变量快照输出）
- 实现 `_evaluate_condition(condition, context)` 辅助方法（复用 ExpressionHelper）
- 实现 `_show_pause_dialog(context)` 辅助方法（CanvasLayer 视觉提示 + Input 轮询）
- 实现 static `_get_instruction_metadata()`（归类到 Debug 类别）
- 实现本地化键（BRICKS_INSTRUCTION_BREAKPOINT_*）
- 运行时验证通过：条件评估、变量输出、暂停/恢复、命中计数重置、导出构建降级

### 阶段 2：清理运行时层

**修改文件：**
- `addons/bricks/core/runtime_action_runner_instance.gd`
  - 移除 `signal breakpoint_paused(context_info: Dictionary)` (L25)
  - 移除 `signal _breakpoint_resumed` (L26)
  - 移除 `var _is_breakpoint_paused: bool = false` (L55)
  - 移除 `var _breakpoint_context_info: Dictionary = {}` (L56)
  - 移除 `cancel_execution()` 中的断点恢复逻辑 (L159-161)
  - 移除循环中的断点注册 + 检查 + await 块 (L314-366)
  - 移除 `resume_breakpoint()` 方法 (L611-615)

**删除文件：**
- `addons/bricks/core/debugging/breakpoint_manager.gd` (156 行)
- `addons/bricks/core/debugging/breakpoint_manager.gd.uid`
- `addons/bricks/core/debugging/breakpoint_config.gd` (34 行)
- `addons/bricks/core/debugging/breakpoint_config.gd.uid`

**清理空目录：**
- 删除 `addons/bricks/core/debugging/` 目录（移除全部文件后为空）

**风险：** 低（breakpoint_paused 信号无外部连接，无 .tres 序列化数据）

### 阶段 3：清理数据层

**修改文件：**
- `addons/bricks/core/base/action_runner.gd`
  - 移除 `@export_storage var breakpoint_configs: Array = []` (L59-61)
  - 移除 `_sync_breakpoint_configs()` 方法 (L91-95)
  - 移除 instructions setter 中的 `_sync_breakpoint_configs()` 调用
  - 移除 `clone()` 中的断点配置复制 (L674)
  - 移除 `deserialize()` 中的 `_sync_breakpoint_configs()` 调用 (L658)

**风险：** 低（无 .tres 文件包含 breakpoint_configs 数据）

### 阶段 4：回退编辑器层

**修改文件：**
- `addons/bricks/editor/bricks_inspector_plugin.gd`
  - 移除 `InstructionListEditor.new()` + `setup()` + `add_custom_control()` (L31-33)
  - 替换为 `_add_instruction_selector_button(object, name)` + `return false`
  - **新增** `_add_instruction_selector_button(object, property_name)` 方法：
    - 参考现有的 `_add_component_selector_button()` 模式（L68-126）
    - 创建 HBoxContainer + Button
    - 按钮点击时打开 `InstructionSelector` 弹窗
    - 通过 `add_custom_control()` 添加，保留原生数组编辑器
  - **注意：** 此方法在当前代码中不存在，被 InstructionListEditor 替代，需要重新编写

**删除文件：**
- `addons/bricks/editor/instruction_selector/instruction_list_editor.gd` (504 行)
- `addons/bricks/editor/instruction_selector/instruction_list_editor.gd.uid`

**风险：** 低（InstructionListEditor 仅在 bricks_inspector_plugin.gd L31-33 中创建）

### 阶段 5：更新文档

- 更新 `2026-03-18-bricks-breakpoint-system-design-v2.md` 状态标记为"已废弃，转向断点指令方案"
- 更新本文档中引用的行号（阶段 2-4 完成后）

---

## 5. 保留资产

以下代码在调整后继续保留：

| 资产 | 位置 | 理由 |
|------|------|------|
| 变量快照方法 | `execution_context.gd:1572-1593` | BreakpointInstruction 输出变量时复用 |
| ExpressionHelper 条件评估 | `core/utils/expression_helper.gd` | BreakpointInstruction 条件评估复用 |
| InstructionSelector | `editor/instruction_selector/instructions_selector.gd` | 阶段 4 回退后继续用于添加指令 |
| instructions_array_property.gd | `editor/instruction_selector/instructions_array_property.gd` | 遗留代码，保持未启用 |

---

## 6. 文件变更清单

| 文件 | 操作 | 变更量 |
|------|------|--------|
| `instructions/debug/breakpoint_instruction.gd` | **新增** ✅ | ~170 行 |
| `instructions/debug/breakpoint_instruction.gd.uid` | **新增** ✅ | 1 |
| `core/debugging/breakpoint_manager.gd` | **删除** | -156 行 |
| `core/debugging/breakpoint_manager.gd.uid` | **删除** | -1 |
| `core/debugging/breakpoint_config.gd` | **删除** | -34 行 |
| `core/debugging/breakpoint_config.gd.uid` | **删除** | -1 |
| `core/debugging/` 目录 | **删除** | 空目录清理 |
| `editor/instruction_selector/instruction_list_editor.gd` | **删除** | -504 行 |
| `editor/instruction_selector/instruction_list_editor.gd.uid` | **删除** | -1 |
| `core/runtime_action_runner_instance.gd` | **修改** | ~-60 行 |
| `core/base/action_runner.gd` | **修改** | ~-15 行 |
| `editor/bricks_inspector_plugin.gd` | **修改** | ~+10 行（新增按钮方法） |
| **净变更** | | **~-596 行** |

---

## 7. v2 与简化方案功能对照

| 功能 | v2 编辑器断点 | 简化方案 |
|------|-------------|---------|
| 任意指令右键添加断点 | ✅ | ❌ 需要手动插入 |
| 条件断点 | ✅ BreakpointManager 评估 | ✅ 指令内部评估 |
| 忽略次数 | ✅ 每次执行重置 | ✅ execution_id 检测自动重置 |
| 日志断点（仅输出） | ✅ | ✅ log_variables + !pause_execution |
| 暂停执行 | ✅ Runner loop await | ✅ CanvasLayer 提示 + Enter 键恢复 |
| 变量输出 | ✅ 信号（无消费者） | ✅ 直接输出到输出窗口 |
| 随 .tres 持久化 | ✅ | ✅ 标准 @export |
| 视觉指示器（背景色） | ✅ | ❌ |
| 全局断点管理 | ✅ BreakpointManager 单例 | ❌ 每条指令独立 |
| 内联编辑指令属性 | ✅ EditorInspector 展开 | ✅ 原生数组编辑器点击展开 |
| 导出构建中可用 | ❌ | ✅ 日志输出可用，暂停自动降级 |

---

## 8. 评估记录

### 评估日期：2026-03-19

### 能力评估（7/7 PASS）

| # | 评估项 | 结果 |
|---|--------|------|
| C1 | BreakpointInstruction 条件评估可复用 ExpressionHelper | PASS |
| C2 | 暂停执行可通过指令内部 await 自包含实现 | PASS（方案从 AcceptDialog 调整为 Input 轮询） |
| C3 | 变量快照方法可复用 | PASS |
| C4 | 回退原生编辑器不影响指令选择器 | PASS |
| C5 | 无 .tres 序列化数据风险 | PASS |
| C6 | 无外部信号连接风险 | PASS |
| C7 | `_is_synchronous_hint` 处理正确 | PASS |

### 回归评估（3/3 PASS）

| # | 评估项 | 结果 |
|---|--------|------|
| R1 | 移除后现有指令执行不受影响 | PASS |
| R2 | ActionRunner 移除 breakpoint_configs 后 .tres 兼容 | PASS |
| R3 | clone()/deserialize() 移除断点同步后正确 | PASS |

### 已修正问题

| # | 严重度 | 问题 | 修正 |
|---|--------|------|------|
| E1 | 中等 | `_hit_count` 跨 ActionRunner 执行累积，导致 ignore_count 首次执行后失效 | 利用 `ExecutionContext.execution_id` 检测新执行周期并重置（3.1 节、3.2 节） |
| E2 | 低 | 导出构建中 `pause_execution = true` 导致永久挂起 | 添加 `OS.has_feature("editor")` guard，导出构建降级为仅日志输出（3.4 节） |
| E3 | 严重 | AcceptDialog 方案：动态创建的 Control 无法接收 GUI 输入事件 | 改为 CanvasLayer 视觉提示 + Input 单例轮询方案（3.4 节，详见第 9 节） |

---

## 9. 运行时验证记录

### 验证日期：2026-03-19

### 问题排查过程

#### 问题 1：`await` 未生效

**现象：** 暂停功能不生效，`pause_execution = true` 时执行不会暂停。

**根因：** `execute()` 中调用 `_show_pause_dialog(context)` 缺少 `await` 关键字。函数返回后 `_on_execution_completed()` 立即调用，`finished` 信号立即发射，Runner 不会等待对话框关闭。

**修复：** 添加 `await _show_pause_dialog(context)`。

#### 问题 2：AcceptDialog `canceled` 信号不存在

**现象：** 运行时错误 `Invalid access to property 'canceled' on AcceptDialog`。

**根因：** Godot 4 中 `AcceptDialog` 没有 `canceled` 信号，只有子类 `ConfirmationDialog` 才有。方案中参考了 v1.2 评估记录中错误的 API 校验结果。

**修复：** 移除 `dialog.canceled.connect(...)` 调用。

#### 问题 3：AcceptDialog/Window/CanvasLayer+Button 均无法接收点击

**现象：** UI 元素可见但点击无响应，`pressed`/`confirmed`/`gui_input` 信号均不触发。

**诊断过程：**

| 诊断测试 | 结果 | 含义 |
|----------|------|------|
| `Input.is_mouse_button_pressed()` 轮询 | ✅ 检测到点击 | 引擎正常处理输入 |
| `SceneTree.input_event` 信号 | ❌ 不存在 | Godot 4 已移除此信号 |
| `Button.gui_input` 信号 | ❌ 未收到事件 | GUI 输入路由不通 |

**根因：** 在 Bricks 运行时中，动态创建的 Control（Button、AcceptDialog）无法通过 GUI 输入路由接收事件。可能与 RuntimeInstructionInstance 的异步执行架构影响 GUI 事件分发有关。`Input` 单例不受影响。

**修复：** 改为 CanvasLayer 纯视觉提示 + `Input.is_action_just_pressed("ui_accept")` 轮询方案。

#### 最终方案

```
暂停 = 显示 CanvasLayer 居中面板（纯视觉提示）
恢复 = 按 Enter 键（Input 单例轮询，绕过 GUI 路由）
清理 = canvas_layer.queue_free()
```

### 验证结果

| 功能 | 状态 |
|------|------|
| 变量信息输出到输出窗口 | ✅ |
| 条件表达式评估 | ✅ |
| ignore_count 忽略次数 | ✅ |
| 暂停执行 | ✅ |
| Enter 键恢复运行 | ✅ |
| 导出构建降级（日志输出） | ✅（代码已 guard） |
| 恢复后后续指令正常执行 | ✅ |

---

## 10. 参考

### 项目内参考

- [Print 指令](../../addons/bricks/instructions/debug/print.gd) — 同步指令实现模式参考
- [Wait 指令](../../addons/bricks/instructions/flow_control/wait.gd) — 异步指令 + `_is_synchronous_hint` 模式参考
- [ExpressionCondition](../../addons/bricks/conditions/math/expression_condition.gd) — ExpressionHelper 集成参考
- [ExecutionContext 变量快照](../../addons/bricks/core/base/execution_context.gd) — get_all_*_variables_snapshot()
- [ExecutionContext.execution_id](../../addons/bricks/core/base/execution_context.gd) — 唯一执行标识符
- [InstructionSelector](../../addons/bricks/editor/instruction_selector/instructions_selector.gd) — 指令选择器弹窗
- [bricks_inspector_plugin._add_component_selector_button()](../../addons/bricks/editor/bricks_inspector_plugin.gd) — Inspector 按钮模式参考
