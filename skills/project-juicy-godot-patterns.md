---
name: project-juicy-godot-patterns
description: Coding patterns extracted from project-juicy-godot (Godot 4.6 Bricks 可视化编程系统)
version: 1.0.0
source: local-git-analysis
analyzed_commits: 200
---

# Project Juicy Godot 编码模式

此技能描述了 **project-juicy-godot** 项目的编码模式和最佳实践。

## 项目概述

- **Godot 版本**: 4.6
- **语言**: GDScript 2.0
- **核心系统**:
  - **Juicy Mixer** - 游戏特效系统（震动、弹簧、补间动画、时间线控制）
  - **Bricks** - 可视化编程/事件系统（类似 Game Creator 的无代码脚本系统）
  - **Sound Manager** - 音频管理系统

## Commit 规范

项目主要使用以下 commit 消息前缀：

| 前缀 | 用途 | 示例 |
|------|------|------|
| `feat:` | 新功能 | `feat: 添加 OnNodePausedResumed 事件` |
| `fix:` | Bug 修复 | `fix: normalize indentation in test_on_animation_loop.gd` |
| `refactor():` | 代码重构 | `refactor(bricks): standardize naming conventions` |
| `docs:` | 文档更新 | `docs: update roadmap - Phase 5 complete` |
| `chore:` | 维护任务 | `chore: create tween instructions directory structure` |
| `i18n:` | 国际化 | `i18n: add translations for Tween instructions` |

### Commit 格式

```
feat: 简短描述（中文或英文）
feat(category): 简短描述
fix(category): 修复的问题描述
```

## 代码架构

### 目录结构

```
addons/
├── bricks/               # 可视化编程系统
│   ├── core/             # 核心系统（Event、Instruction、Condition、Variable）
│   ├── events/           # 事件类型（按功能分类）
│   ├── instructions/     # 指令类型（按功能分类）
│   ├── conditions/       # 条件类型
│   ├── editor/           # 编辑器工具
│   ├── tests/            # 测试场景
│   └── docs/             # 系统文档
│
├── juicy_mixer/          # 核心特效系统
│   ├── core/             # 核心类（Context、Driver、Track、Resource）
│   ├── drivers/          # 驱动器（Shake、Spring、Tween、Timeline）
│   ├── resources/        # 资源类（Feedback、Track、Keyframe）
│   └── middleware/       # 中间件（LOD、TimeScale、Channel）
│
└── sound_manager/        # 音频管理系统
```

### 事件分类 (Events)

```
events/
├── animation/    # 动画事件
├── audio/        # 音频事件
├── gameplay/     # 游戏玩法事件
├── input/        # 输入事件
├── lifecycle/    # 生命周期事件
├── node/         # 节点事件
├── physics/      # 物理事件
├── scene/        # 场景事件
├── timing/       # 计时事件
├── tween/        # 补间事件
├── ui/           # UI 事件
└── variable/     # 变量事件
```

### 指令分类 (Instructions)

```
instructions/
├── animation/          # 动画指令
├── audio/              # 音频指令
├── camera/             # 相机指令
├── flow_control/       # 流程控制指令
├── math/               # 数学指令
├── node_operations/    # 节点操作指令
├── physics/            # 物理指令
├── scene/              # 场景指令
├── scene_management/   # 场景管理指令
├── system/             # 系统指令
├── time/               # 时间指令
├── transform/          # 变换指令
├── tween/              # 补间指令
├── ui/                 # UI 指令
└── variables/          # 变量指令
```

## 编码规范

### 1. 文件命名

- 使用 **snake_case**: `on_enter_tree.gd`, `base_event.gd`
- 类名使用 **PascalCase**: `class_name OnEnterTree`

### 2. 缩进和格式

- 使用 **Tab** 缩进（Godot 标准）
- 不使用尾随空格
- 文件末尾添加换行符

### 3. 类型注解

```gdscript
# 明确类型
var _owner_node_ref: Node = null
var _is_monitoring: bool = false

# 函数返回类型
func get_event_type() -> String:
    return "enter_tree"
```

### 4. 注释规范

```gdscript
## 使用三重斜杠的注释会显示在 Godot 文档中
func initialize(owner_node: Node) -> void:
    pass

# 内部注释说明复杂逻辑
var _internal_value: int = 0
```

### 5. 私有变量

```gdscript
var _private_var: int = 0  # 使用下划线前缀
```

### 6. 抽象标记

从 Godot 4.5 开始，使用 `@abstract` 标记抽象基类与抽象方法：

```gdscript
@tool
@abstract
class_name BaseEvent extends Resource

@abstract
func _update_resource_name():
    pass
```

## Bricks 事件开发模式

### 事件类模板

```gdscript
@tool
@icon("res://addons/bricks/icons/builtin/Reload.svg")
extends BaseEvent
class_name OnEnterTree

## 事件描述
## 详细说明...

var _owner_node_ref: Node = null
var _is_monitoring: bool = false

## 更新资源名称（必需）
func _update_resource_name() -> void:
    resource_name = "事件显示名称"

## 初始化事件监听（必需）
func initialize(owner_node: Node) -> void:
    if not owner_node:
        _create_bricks_error_localized("BRICKS_ERROR_TARGET_NODE_NULL", BricksError.ErrorType.CONFIGURATION_ERROR, {})
        return

    _owner_node_ref = owner_node
    # 连接信号
    # ...

    _is_monitoring = true
    _log_debug_localized("BRICKS_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
    _is_monitoring = false
    # 断开信号连接
    # ...
    _owner_node_ref = null

## 信号回调
func _on_signal() -> void:
    if not _is_monitoring:
        return
    _log_info_localized("BRICKS_LOG_EVENT_TRIGGERED", {})
    triggered.emit(_owner_node_ref)

## 获取事件描述
func get_description() -> String:
    return "事件描述文本"

## 获取事件类型
func get_event_type() -> String:
    return "event_type"

## 获取事件分类
func get_event_category() -> String:
    return "category"

## 验证事件配置
func validate() -> Array[String]:
    var errors: Array[String] = []
    return errors

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.name_key = "BRICKS_EVENT_XXX_NAME"
    metadata.category_key = "BRICKS_EVENT_CATEGORY_XXX"
    metadata.description_key = "BRICKS_EVENT_XXX_DESC"
    metadata.keywords = ["keyword1", "keyword2"]
    metadata.builtin_icon = "IconName"
    return metadata
```

## 测试模式

### 测试文件位置

- 测试场景: `addons/bricks/tests/events/test_on_enter_tree.tscn`
- 测试脚本: `addons/bricks/tests/events/test_on_enter_tree.gd`

### 测试脚本模板

```gdscript
extends Node

## 测试 OnEnterTree 事件

func _ready() -> void:
    test_on_enter_tree_event()

func test_on_enter_tree_event() -> void:
    print("开始测试 OnEnterTree 事件...")
    # 测试逻辑
    print("测试通过!")
```

## 工作流

### 添加新的 Bricks 事件

1. 在 `addons/fuse/events/[category]/` 创建新文件
2. 继承 `BaseEvent`
3. 实现必需方法：
   - `_update_resource_name()` — 更新编辑器中显示的资源名称
   - `initialize(owner_node: Node)` — 连接信号、启动监听
   - `terminate(owner_node: Node)` — 断开信号、清理引用
   - `get_event_type()` → String — 返回事件类型标识
   - `get_event_category()` → String — 返回分类名称
   - `_get_event_metadata()` → EventMetadata — 提供元数据（名称键、分类键、描述键、关键词、图标）
4. 可选实现：
   - `get_description()` → String — 事件描述
   - `validate()` → Array[String] — 配置验证
   - `get_default_runtime_state()` → Dictionary — 运行时状态初始化
   - `_initialize_runtime_state(runtime_instance)` — 自定义运行时状态
5. 使用 `_emit_triggered(context, owner_node)` 发出触发信号（自动设置 trigger meta，防止广播泄漏）
6. 使用 `notify_stopped(reason, context)` 通知事件停止
7. 添加测试文件到 `addons/fuse/tests/events/`
8. 添加翻译到 `addons/fuse/localization/translations.csv`
9. 运行测试验证

### 添加新的 Bricks 指令

1. 在 `addons/fuse/instructions/[category]/` 创建新文件
2. 继承 `BaseInstruction`
3. 实现必需方法：
   - `_update_resource_name()` — 更新编辑器中显示的资源名称
   - `_setup_metadata()` — 设置指令元数据（名称、描述、分类、版本等）
   - `execute(context: ExecutionContext)` — 执行指令逻辑
   - `_get_instruction_metadata()` → InstructionMetadata — 提供静态元数据
4. 执行流程：
   - 调用 `_start_execution(context)` 设置状态为 RUNNING
   - 实现具体逻辑
   - 调用 `_on_execution_completed()` 或 `finished.emit()` 标记完成
5. 可选实现：
   - `get_description()` → String — 指令描述
   - `validate()` → Array[String] — 参数验证
   - `_is_synchronous()` → bool — 声明同步/异步行为
   - `cancel()` — 取消执行清理
6. 使用 `set_error(message, error_type, context)` 或 `set_error_localized(message_key, ...)` 报告错误
7. 添加测试文件
8. 添加翻译

### 添加新的 Bricks 条件

1. 在 `addons/fuse/conditions/[category]/` 创建新文件
2. 继承 `BaseCondition`
3. 实现必需方法：
   - `_update_resource_name()` — 更新编辑器中显示的资源名称
   - `_evaluate_condition(context: ExecutionContext)` → bool — 核心条件评估逻辑
   - `_compute_dependencies()` → Array[String] — 声明依赖的变量名
4. 可选实现：
   - `get_description()` → String — 条件描述
   - `get_condition_type()` → String — 条件类型标识
   - `get_condition_category()` → String — 条件分类
   - `validate()` → Array[String] — 配置验证
   - `get_parameters()` → Dictionary — 获取参数
   - `set_parameters(parameters)` — 设置参数
   - `needs_recheck(context)` → bool — 是否需要重新评估
   - `get_affected_variables()` → Array[String] — 影响的变量
   - `_compute_thread_safety()` → bool — 声明线程安全性
   - `on_condition_met(context)` — 条件满足时的回调
   - `on_condition_failed(context)` — 条件不满足时的回调
5. 使用 `check(context)` 进行条件检查（自动处理缓存、取反、空值防御）
6. 缓存配置：
   - `enable_cache` — 启用结果缓存
   - `cache_duration` — 缓存有效期（秒）
   - `cache_context_changes` — 上下文变化时失效缓存
   - `hash_all_variables` — 哈希包含所有变量
7. 使用 `negate_result` 属性反转条件结果
8. 使用 `enabled` 属性启用/禁用条件
9. 添加测试文件
10. 添加翻译

## 重要注意事项

### 信号连接

```gdscript
# 推荐使用 Callable (Godot 4.x)
object.signal_name.connect(_on_signal_name)

func _on_signal_name():
    pass
```

### 节点路径

```gdscript
@export var target: NodePath = NodePath("")

func _ready():
    var node = get_node(target) as Node
```

### 资源生命周期

- Resource 不要持有节点引用
- 使用 NodePath 或字符串路径
- 在运行时解析节点引用

### 编辑器检测

```gdscript
if Engine.is_editor_hint():
    return  # 编辑器模式下跳过
```

## 性能优化模式

1. **缓存类引用** - 避免重复 `load()` 调用
2. **对象池** - 使用 `JuicyPoolManager` 管理频繁创建的对象
3. **运行时实例** - 使用 `RuntimeEventInstance` 避免不必要的资源复制
