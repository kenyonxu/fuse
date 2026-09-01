# AGENTS.md - AI 代理开发指南

本文档为在此 Godot 4.7 游戏插件项目中工作的 AI 代理提供必要信息。

<CRITICAL>
  总是用中文回复
</CRITICAL>

## 配套生成 skill（创建组件前必读）⚠️

`.claude/skills/` 下有本工程的组件生成规范（Claude Code 目录格式，ZCode 的 Skill 工具注册表不含它们）。**创建/修改以下内容前，必须先读对应 SKILL.md 并遵循其模板、命名规范与验证清单**：

| 任务 | 必读 |
|------|------|
| 新建/修改指令（Instruction） | `.claude/skills/fuse-instruction-generator/SKILL.md` |
| 新建/修改事件（Event） | `.claude/skills/fuse-event-generator/SKILL.md` |
| 新建/修改条件（Condition） | `.claude/skills/fuse-condition-generator/SKILL.md` |
| 本地化改动 | `.claude/skills/fuse-localization-fixer/SKILL.md` |
| 生成 preset | `.claude/skills/fuse-preset-generator/SKILL.md` |
| 事件迁移 RuntimeInstance | `.claude/skills/fuse_event_runtime_instance_migration/SKILL.md` |
| 毕业交接打包（handoff bundle） | `addons/fuse/agent_skills/fuse-handoff-packer/SKILL.md` |

`addons/fuse/agent_skills/` 下的 skill 面向插件使用者（随 `addons/fuse/` 分发、工具中立），与上表面向本仓库开发的 `.claude/skills/` 不同；用户项目通过其 AGENTS.md 指路使用。

即使 Skill 工具无法直接调用，也应以"Read 该 SKILL.md 并遵循"的方式使用——规范中的必需方法、命名禁则（如类名不加 Instruction 后缀）、双执行路径要求与验证清单是硬约束。

## 构建/测试命令

### 运行测试

测试是带有附加脚本的 Godot 场景，在 `_ready()` 中运行。不使用外部测试框架。

```gdscript
# 运行单个测试场景：
# 1. 打开 Godot 编辑器
# 2. 打开测试场景（如 res://addons/fuse/tests/conditions/test_conditions.tscn）
# 3. 按 F5 运行场景

# 以编程方式运行测试：
extends Node
func _ready():
    var test_script = load("res://addons/fuse/tests/conditions/test_conditions.gd")
    var test_instance = test_script.new()
    add_child(test_instance)
    if test_instance.has_method("run_tests"):
        test_instance.run_tests()
```

### 无构建命令

这是 Godot 项目 - 无需构建步骤。"构建"就是 Godot 引擎本身。

### Lint（gdlint）

GDScript 静态检查使用 [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) 的 `gdlint`（配置见根目录 `gdlintrc`——风格偏好类规则已按项目基线关闭/放宽，卫生类规则保持开启）：

```bash
# 全量检查（addons 与 demos 均应零违规，退出码 0）
pip install gdtoolkit   # 首次
gdlint addons/fuse demos

# 单文件
gdlint <file.gd>
```

触碰 .gd 文件的任务提交前应跑 lint 零违规；新代码行长建议守 120（硬限 250）。

### 组件清单同步（dump 上下文）⚠️ 新增组件后必做

`addons/fuse/preset_ai_context/` 下的 3 个 JSON（components/schemas/enums）是 AI 写 preset 时的组件清单，**新增或修改组件后必须重新 dump**，否则 AI 上下文过期（2026-08-09 曾漏 5 个组件）。修改组件参数或 `_get_property_list` 条件门控后同样必须重 dump——schemas 现收录条件注册的动态参数及其 `requires` 门控。

```bash
# 1. 首次需先初始化项目（生成 .godot 全局类缓存，否则 class_name 解析失败）
Godot --headless --import --path <项目路径>

# 2. 重新 dump（会重写 3 个 JSON）
Godot --headless --path <项目路径> res://addons/fuse/editor/preset_ai/dump_context.tscn
```

- Godot 4.7 路径示例：`/home/kai-remote/godot/Godot_v4.7-stable_mono_linux_x86_64/Godot_v4.7-stable_mono_linux.x86_64`
- dump 完成后用 git diff 确认：组件数应只增不减，旧条目字段不应变化

**组件 metadata 要求**：Event / Instruction / Condition 组件必须实现对应静态 metadata 方法，否则 dump 会静默跳过（CheckScopeVariable 曾因此漏掉）：
- 指令：`static func _get_instruction_metadata() -> InstructionMetadata`
- 事件：`static func _get_event_metadata() -> EventMetadata`
- 条件：`static func _get_condition_metadata() -> ConditionMetadata`

**提取器约定**：条件注册的参数须逐级嵌套（每个门控前缀态解锁下一级选择器），否则 BFS 探测可能静默漏收录（详见 schema_extractor.gd `_unlocks_registered` 注释）。

### Preset AI 工具链（validate / eval）

```bash
# 离线校验 preset JSON（文件或目录，可多个；改 preset 结构/校验器后必跑）
Godot --headless --path <项目路径> res://addons/fuse/editor/preset_ai/validate_preset.tscn -- <file-or-dir>... [--report <out.json>]
# 退出码：0 = 无 error；1 = 有 error finding；2 = 参数/IO 错误

# eval 回放评分 + baseline 回归门禁（workspace 相对 res://）
Godot --headless --path <项目路径> res://addons/fuse/editor/preset_ai/eval_runner.tscn -- --workspace fuse-preset-generator-workspace --iteration <name> [--report <dir>]
# 退出码：0 = 无回归；1 = 有回归（baseline 应过实败）；2 = 参数错误；live 模式恒 0（网络失败只计入报告）
```

惯例：
- 测试场景结尾用 `get_tree().quit(1 if _fail > 0 else 0)` 约定退出码，headless 运行可直接做门禁判断
- 触及 `preset_value_codec` 的任务须例行跑 `res://addons/fuse/tests/serialization/test_preset_nested_serde.tscn`（全量序列化往返较慢，需 `--quit-after 600`）

### export_topology CLI（拓扑 ground truth 导出）

```bash
Godot --headless --path <项目路径> res://addons/fuse/editor/topology/export_topology.tscn -- --scene res://<scene.tscn> [--out res://fuse_reports/topology]
# 退出码：0 = 成功；2 = 参数或 IO 错误
# 用途：导出场景拓扑 JSON（产物名 = 场景文件茎），毕业导出器与调试共用
```

### 毕业导出器 CLI（derive / validate / export）

> 2026-09-01 方向修订：**出口主线为 AI 交接工件**——derive / validate 为主线部件（拓扑 + System 划分 + preset 供给用户的 AI agent 写脱离 Fuse 的代码，handoff bundle 打包规划中）；`export_system`（GDScript 生成）为**实验特性**，非主线出口，生成代码仍依赖 Fuse 运行时。

```bash
# 场景拓扑 → System 草稿 JSON（kind 过滤 runner；草稿目录默认不入库）
Godot --headless --path <项目路径> res://addons/fuse/editor/graduation/derive_systems.tscn -- --scene res://<scene.tscn> [--out res://fuse_generated/systems/drafts]
# 退出码：0 = 成功；2 = 参数或 IO 错误
# 另落盘 <out>/_derive_report.json（skipped/components/warnings_by_unit 四元组，
# 据此可构造草稿的 acknowledged_warnings）

# System JSON 离线校验（文件或目录，可多个；含 topology_digest 漂移检测）
Godot --headless --path <项目路径> res://addons/fuse/editor/graduation/validate_system.tscn -- <file-or-dir>... [--report <out.json>]
# 退出码：0 = 无 error；1 = 有 error finding；2 = 参数/IO 错误

# 按 System 生成桥接模式 GDScript + 覆盖率报告（毕业产物在 fuse_generated/scripts/）
Godot --headless --path <项目路径> res://addons/fuse/editor/graduation/export_system.tscn -- <system.json> [<system.json>...]
# 退出码：0 = 全部成功；1 = 校验/生成/解析 error；2 = 参数/IO 错误
```

## 代码风格指南

### 文件命名
- 文件：`snake_case.gd`（如 `base_instruction.gd`）
- 测试文件：`test_*.gd` 前缀（如 `test_timeline_system.gd`）

### 命名约定

```gdscript
# 类名 - PascalCase with class_name
class_name BaseInstructionResource
extends Resource

# 变量 - snake_case
var duration: float = 1.0
var target_node: Node

# 私有变量 - 下划线前缀
var _internal_state: Dictionary = {}
var _cache: Array = []

# 常量 - UPPER_SNAKE_CASE
const MAX_DURATION: float = 10.0

# 枚举 - 枚举 PascalCase，值 UPPER
enum DurationType { MANUAL, EXACT, ESTIMATED }

# 函数 - snake_case
func get_value() -> float:
    return _value

# 私有函数 - 下划线前缀
func _update_internal_state() -> void:
    pass

# 信号 - snake_case，事件用过去时
signal value_changed(new_value: float)
signal completed()
```

### 类型注解

```gdscript
# 总是为变量指定类型
var value: float = 0.0
var items: Array[Resource] = []
var node: Node2D = null

# 总是指定返回类型
func get_duration() -> float:
    return duration

func create_context(target: Node) -> ExecutionContext:
    return ExecutionContext.create(resource, target)

# 优先使用 Godot 类型而非 Variant
var position: Vector2 = Vector2.ZERO
var color: Color = Color.WHITE

# 仅在真正需要动态时使用 Variant
var dynamic_data: Variant = null
```

### 导入和类结构

```gdscript
# 编辑器脚本使用 @tool
@tool
class_name MyResource
extends Resource

# 使用 extends 继承
extends Node2D

# 文件内类定义用 tab 缩进
class InnerClass:
    var property: int = 0

# 静态工厂方法
static func create(config: Dictionary) -> MyResource:
    var resource = MyResource.new()
    resource.load_from_dict(config)
    return resource
```

### 错误处理

```gdscript# 关键失败使用 push_error()
if not target:
    push_error("Target cannot be null")
    return null

# 非关键问题使用 push_warning()
if value < 0:
    push_warning("Negative value detected, using absolute value")
    value = abs(value)

# 调试使用 assert()（发布版本中移除）
assert(duration > 0, "Duration must be positive")

# @export var 带验证
@export var duration: float = 1.0:
    set(value):
        if value < 0:
            push_warning("Duration cannot be negative, clamping to 0")
            value = 0
        duration = value
```

### 信号连接

```gdscript
# 使用 Callable 语法（Godot 4.x）
object.signal_name.connect(_on_signal_name)

# 断开连接
object.signal_name.disconnect(_on_signal_name)

# 信号处理器使用 _on_{emitter}_{signal} 模式
func _on_target_value_changed(new_value: float) -> void:
    _update_value(new_value)

func _on_animation_completed() -> void:
    queue_free()
```

### 文档注释

```gdscript
## 三重斜杠注释显示在 Godot 文档系统中
## 为公共 API 提供清晰描述
func get_duration() -> float:
    """Returns the duration in seconds."""
    return duration

# 单个 # 用于实现说明
# 复杂逻辑说明写在这里
var _cached_value: float = 0.0

# 带文档的枚举
enum InterruptionPolicy {
    STACK,       ## 堆叠效果，新的在上面
    REPLACE,     ## 替换现有效果
    IGNORE       ## 忽略新效果
}
```

### 编辑器集成

```gdscript
# 使用 @export 暴露属性
@export var enabled: bool = true
@export_range(0, 100) var intensity: float = 50.0
@export_file("*.tscn") var scene_path: String = ""

# 使用 @export_group 组织检查器
@export_group("Main Settings")
@export var duration: float = 1.0

@export_group("Advanced", "advanced_")
@export var advanced_option: bool = false

# 检查编辑器环境
func _ready():
    if Engine.is_editor_hint():
        return  # 不要在编辑器中运行游戏逻辑

# 编辑器中节点操作使用 call_deferred
func _get_property_list(): -> Array[Dictionary]:
    call_deferred("_update_editor_ui")
```

### 资源管理

```gdscript
# Resource 不应持有节点引用
@export var target_path: NodePath = NodePath("")

func _ready():
    # 在运行时解析 NodePath 到 Node
    var node = get_node_or_null(target_path) as Node
    if node:
        _setup_target(node)

# 序列化支持
func get_config_dict() -> Dictionary:
    return {
        "duration": duration,
        "enabled": enabled
    }

func load_from_dict(config: Dictionary) -> void:
    duration = config.get("duration", 1.0)
    enabled = config.get("enabled", true)
```

### 数组最佳实践

```gdscript
# 始终使用类型化数组
var items: Array[Resource] = []
var names: PackedStringArray = []

# 类型化数组大小不可变
# 要修改，创建新数组
var new_items: Array[Resource] = []
new_items.append_array(items)
new_items.append(new_item)
items = new_items

# 尽可能使用类型化 Dictionary
var mapping: Dictionary[String, float] = {}
mapping["key"] = 1.0
```

### 测试模式

```gdscript
extends Node

func _ready():
    print("=== Running Test ===")
    _test_basic_functionality()
    _test_edge_cases()
    print("=== Test Complete ===")

func _test_basic_functionality():
    var result = calculate(2, 3)
    if result != 5:
        push_error("Test failed: 2 + 3 should equal 5, got " + str(result))
    print("Test passed: basic functionality")

func _test_edge_cases():
    var result = calculate(-1, 0)
    if result < 0:
        push_error("Test failed: negative values not supported")
    print("Test passed: edge cases")
```

## 重要模式

- 对纯数据对象（Contexts, Resources）使用 `RefCounted`
- 对需要生命周期管理的场景树对象使用 `Node`
- 在 Resource 中使用 NodePath，运行时解析
- 对可选引用使用 `get_node_or_null()` 而非 `get_node()`
- Godot 4.x 中使用 `await` 进行异步操作
- 编辑器上下文中的节点操作使用 `call_deferred()`
- Resource 应使用 `duplicate(true)` 进行克隆
- 所有插件继承 `EditorPlugin` 并使用 `@tool`

## 测试约定

- 测试文件：`addons/[system]/tests/test_*.gd`
- 测试场景：`addons/[system]/tests/test_*.tscn`
- 测试方法：`test_*()` 或私有测试用 `_*test_*()`
- 使用 `print()` 输出测试信息
- 使用 `push_error()` 标记测试失败
- 无外部测试框架 - 仅自定义断言

## 项目结构上下文

- **Fuse**: 可视化编程系统（Event / Instruction / Condition 三类砖块）

核心架构使用：
- 事件驱动的执行
- 指令编排（ActionRunner）
- 基于 ExecutionContext 的运行时上下文
- 全局变量 Service + Assistant 双层
- 组件自动扫描注册（ComponentScanner）
- 基于 Godot TranslationDomain 的本地化
