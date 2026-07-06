# AGENTS.md - AI 代理开发指南

本文档为在此 Godot 4.7 游戏插件项目中工作的 AI 代理提供必要信息。

<CRITICAL>
  总是用中文回复
</CRITICAL>

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

### 无 Lint 命令

项目中未配置 GDScript 的 linter。

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
