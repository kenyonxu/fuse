# Godot 4.x 可视化编程系统完整架构设计

## 目录
1. [核心架构设计概述](#1-核心架构设计概述)
2. [主要组件及其职责](#2-主要组件及其职责)
3. [数据流和控制流设计](#3-数据流和控制流设计)
4. [扩展点设计](#4-扩展点设计)
5. [与Godot特性的集成方案](#5-与godot特性的集成方案)

---

## 1. 核心架构设计概述

### 1.1 设计理念

本架构融合了GameCreator的先进设计理念和Godot 4.x的核心特性，创建了一个既强大又灵活的可视化编程系统。核心理念包括：

- **资源优先**：充分利用Godot的Resource系统实现逻辑重用和内嵌
- **信号驱动**：基于Godot的Signal系统实现事件驱动的异步执行
- **原子化设计**：每个指令执行单一职责，通过组合实现复杂逻辑
- **类型安全**：利用GDScript的类型系统确保编译时安全
- **编辑器原生**：深度集成Godot编辑器，提供直观的可视化体验

### 1.2 整体架构图

```mermaid
graph TB
    subgraph "编辑器层 (Editor Layer)"
        VisualEditor[可视化编辑器]
        Inspector[Inspector面板]
        Gizmos[3D/2D辅助工具]
    end
    
    subgraph "执行层 (Execution Layer)"
        TriggerSystem[触发器系统]
        InstructionSystem[指令系统]
        ConditionSystem[条件系统]
        VariableSystem[变量系统]
    end
    
    subgraph "资源层 (Resource Layer)"
        ActionRunner[动作执行器]
        BaseInstruction[指令基类]
        BaseCondition[条件基类]
        VariableContainer[变量容器]
    end
    
    subgraph "核心层 (Core Layer)"
        ExecutionContext[执行上下文]
        EventSystem[事件系统]
        TypeRegistry[类型注册器]
    end
    
    subgraph "Godot集成层 (Godot Integration Layer)"
        Node[Node系统]
        Resource[Resource系统]
        Signal[Signal系统]
        SceneTree[SceneTree系统]
    end
    
    VisualEditor --> Inspector
    Inspector --> TriggerSystem
    TriggerSystem --> ActionRunner
    ActionRunner --> BaseInstruction
    BaseInstruction --> ExecutionContext
    ExecutionContext --> Signal
```

### 1.3 核心设计原则

#### 1.3.1 资源与节点的分离设计
- **资源(Resource)**：存储可重用的逻辑和数据（指令、条件、变量）
- **节点(Node)**：负责执行和交互（触发器、执行器）

#### 1.3.2 异步优先的执行模型
- 所有指令执行基于Signal和await机制
- 避免阻塞主线程，确保游戏流畅性

#### 1.3.3 上下文驱动的参数传递
- 统一的ExecutionContext提供执行上下文
- 支持局部变量和全局变量的安全访问

---

## 2. 主要组件及其职责

### 2.1 核心资源组件

#### 2.1.1 BaseInstruction - 指令基类

```gdscript
@tool
class_name BaseInstruction extends Resource
signal finished

## 指令执行接口
## context: ExecutionContext - 执行上下文
func execute(context: ExecutionContext):
    print("Executing: %s" % resource_path)
    finished.emit()

## 指令验证接口
func validate() -> Array[String]:
    return []

## 指令描述信息
func get_description() -> String:
    return "Base Instruction"

## 指令图标
func get_icon() -> Texture2D:
    return null
```

**职责**：
- 定义所有指令的基本接口和行为
- 提供统一的执行完成信号机制
- 支持指令验证和描述信息

#### 2.1.2 ActionRunner - 动作执行器

```gdscript
@tool
class_name ActionRunner extends Resource

@export var instructions: Array[BaseInstruction] = []
@export var execution_mode: ExecutionMode = ExecutionMode.SEQUENTIAL
@export var stop_on_error: bool = true

enum ExecutionMode { SEQUENTIAL, PARALLEL, CONDITIONAL }

var is_running: bool = false
var current_context: ExecutionContext = null

## 执行指令序列
func run(context: ExecutionContext):
    if is_running:
        context.print_warning("ActionRunner is already running")
        return
    
    is_running = true
    current_context = context
    
    match execution_mode:
        ExecutionMode.SEQUENTIAL:
            await _run_sequential(context)
        ExecutionMode.PARALLEL:
            await _run_parallel(context)
        ExecutionMode.CONDITIONAL:
            await _run_conditional(context)
    
    is_running = false
    current_context = null

## 停止执行
func stop():
    if is_running and current_context:
        current_context.request_cancel()
```

**职责**：
- 管理指令序列的执行流程
- 支持多种执行模式（顺序、并行、条件）
- 提供执行状态控制和错误处理

#### 2.1.3 BaseCondition - 条件基类

```gdscript
@tool
class_name BaseCondition extends Resource

## 条件检查接口
## context: ExecutionContext - 执行上下文
## returns: bool - 条件是否满足
func check(context: ExecutionContext) -> bool:
    return true

## 条件验证接口
func validate() -> Array[String]:
    return []

## 条件描述信息
func get_description() -> String:
    return "Base Condition"

## 条件图标
func get_icon() -> Texture2D:
    return null
```

**职责**：
- 定义条件检查的基本接口
- 支持复杂的条件逻辑组合
- 提供条件验证和描述功能

### 2.2 核心节点组件

#### 2.2.1 BaseTrigger - 触发器基类

```gdscript
@tool
class_name BaseTrigger extends Node

@export var action_runner: ActionRunner
@export var conditions: Array[BaseCondition] = []
@export var local_variables: VariableContainer = null
@export var enabled: bool = true

var execution_context: ExecutionContext = null

## 触发动作执行
func trigger_actions(target: Node = null):
    if not enabled or not action_runner:
        return
    
    # 创建执行上下文
    execution_context = ExecutionContext.new(self, target)
    
    # 检查条件
    if not _check_conditions(execution_context):
        return
    
    # 执行动作
    action_runner.run(execution_context)

## 检查所有条件
func _check_conditions(context: ExecutionContext) -> bool:
    for condition in conditions:
        if condition and not condition.check(context):
            return false
    return true
```

**职责**：
- 作为事件系统的入口点
- 管理局部变量和执行上下文
- 协调条件检查和动作执行

#### 2.2.2 ExecutionContext - 执行上下文

```gdscript
@tool
class_name ExecutionContext extends RefCounted

var trigger: BaseTrigger
var target: Node
var local_variables: Dictionary = {}
var global_variables: VariableContainer
var is_cancelled: bool = false

signal cancel_requested

func _init(trigger_node: BaseTrigger, target_node: Node = null):
    trigger = trigger_node
    target = target_node
    global_variables = VariableManager.get_global_variables()

## 获取变量值
func get_variable(name: String, default_value = null):
    # 优先级：局部变量 > 触发器变量 > 全局变量
    if local_variables.has(name):
        return local_variables[name]
    elif trigger and trigger.local_variables and trigger.local_variables.has(name):
        return trigger.local_variables.get(name)
    elif global_variables and global_variables.has(name):
        return global_variables.get(name)
    return default_value

## 设置变量值
func set_variable(name: String, value):
    if local_variables.has(name):
        local_variables[name] = value
    elif trigger and trigger.local_variables:
        trigger.local_variables.set(name, value)
    elif global_variables:
        global_variables.set(name, value)

## 请求取消执行
func request_cancel():
    is_cancelled = true
    cancel_requested.emit()

## 打印日志
func print_message(message: String, type: String = "INFO"):
    var prefix = "[VisualScript][%s]" % trigger.name if trigger else "[VisualScript]"
    match type:
        "ERROR":
            push_error("%s %s" % [prefix, message])
        "WARNING":
            push_warning("%s %s" % [prefix, message])
        _:
            print("%s %s" % [prefix, message])
```

**职责**：
- 提供统一的执行上下文环境
- 管理变量的访问和修改
- 支持执行取消和日志记录

### 2.3 变量系统组件

#### 2.3.1 VariableContainer - 变量容器

```gdscript
@tool
class_name VariableContainer extends Resource

@export var variables: Dictionary = {}

## 获取变量值
func get(name: String, default_value = null):
    return variables.get(name, default_value)

## 设置变量值
func set(name: String, value):
    variables[name] = value

## 检查变量是否存在
func has(name: String) -> bool:
    return variables.has(name)

## 删除变量
func erase(name: String):
    variables.erase(name)

## 获取所有变量名
func get_variable_names() -> Array[String]:
    return variables.keys()

## 清空所有变量
func clear():
    variables.clear()
```

**职责**：
- 提供类型安全的变量存储和访问
- 支持变量的增删改查操作
- 作为局部和全局变量的统一容器

#### 2.3.2 VariableManager - 变量管理器

```gdscript
@tool
class_name VariableManager extends Node

static var instance: VariableManager
var global_variables: VariableContainer

func _init():
    if not instance:
        instance = self
        global_variables = VariableContainer.new()

## 获取全局变量容器
static func get_global_variables() -> VariableContainer:
    if not instance:
        instance = VariableManager.new()
    return instance.global_variables

## 创建变量容器
static func create_container() -> VariableContainer:
    return VariableContainer.new()
```

**职责**：
- 管理全局变量的生命周期
- 提供变量容器的创建和访问接口
- 实现单例模式确保全局唯一性

---

## 3. 数据流和控制流设计

### 3.1 数据流图

```mermaid
sequenceDiagram
    participant User as 用户/游戏事件
    participant Trigger as BaseTrigger
    participant Condition as BaseCondition
    participant Context as ExecutionContext
    participant ActionRunner as ActionRunner
    participant Instruction as BaseInstruction
    
    User->>Trigger: 事件触发
    Trigger->>Context: 创建执行上下文
    Trigger->>Condition: 检查条件
    
    loop 条件检查
        Condition->>Context: 读取变量
        Condition-->>Trigger: 返回检查结果
    end
    
    alt 条件满足
        Trigger->>ActionRunner: 执行动作
        ActionRunner->>Instruction: 执行指令
        
        loop 指令执行
            Instruction->>Context: 读取/写入变量
            Instruction->>Context: 访问目标节点
            Instruction-->>ActionRunner: 发出完成信号
        end
        
        ActionRunner-->>Trigger: 执行完成
    else 条件不满足
        Trigger-->>User: 忽略触发
    end
```

### 3.2 控制流设计

#### 3.2.1 触发器控制流

```mermaid
flowchart TD
    A[事件触发] --> B{触发器启用?}
    B -->|否| C[忽略事件]
    B -->|是| D{有动作执行器?}
    D -->|否| E[记录警告]
    D -->|是| F[创建执行上下文]
    F --> G[检查条件列表]
    G --> H{所有条件满足?}
    H -->|否| I[忽略触发]
    H -->|是| J[执行动作序列]
    J --> K[执行完成]
```

#### 3.2.2 指令执行控制流

```mermaid
flowchart TD
    A[开始执行] --> B{执行模式}
    B -->|顺序| C[顺序执行模式]
    B -->|并行| D[并行执行模式]
    B -->|条件| E[条件执行模式]
    
    C --> F[获取下一个指令]
    F --> G{指令为空?}
    G -->|是| H[执行完成]
    G -->|否| I[执行指令]
    I --> J[等待完成信号]
    J --> K{请求取消?}
    K -->|是| L[停止执行]
    K -->|否| M[继续下一个指令]
    M --> F
    
    D --> N[同时执行所有指令]
    N --> O[等待所有指令完成]
    O --> P[执行完成]
    
    E --> Q[评估条件]
    Q --> R{条件满足?}
    R -->|是| S[执行对应指令]
    R -->|否| T[跳过指令]
    S --> U[执行完成]
    T --> U
```

### 3.3 变量访问流程

```mermaid
flowchart TD
    A[变量访问请求] --> B{变量类型}
    B -->|局部变量| C[检查局部变量字典]
    B -->|触发器变量| D[检查触发器变量容器]
    B -->|全局变量| E[检查全局变量容器]
    
    C --> F{找到变量?}
    D --> G{找到变量?}
    E --> H{找到变量?}
    
    F -->|是| I[返回局部变量值]
    F -->|否| J[检查触发器变量]
    G -->|是| K[返回触发器变量值]
    G -->|否| L[检查全局变量]
    H -->|是| M[返回全局变量值]
    H -->|否| N[返回默认值]
    
    J --> G
    L --> H
```

---

## 4. 扩展点设计

### 4.1 指令系统扩展点

#### 4.1.1 自定义指令接口

```gdscript
@tool
class_name CustomInstruction extends BaseInstruction

@export_group("Custom Settings")
@export var custom_property: String = ""
@export var target_node: NodePath

func execute(context: ExecutionContext):
    # 自定义执行逻辑
    var node = context.get_node(target_node)
    if node:
        # 执行自定义操作
        _perform_custom_action(node, context)
    
    finished.emit()

func _perform_custom_action(node: Node, context: ExecutionContext):
    # 子类实现具体逻辑
    pass

func get_description() -> String:
    return "Custom Instruction: %s" % custom_property
```

#### 4.1.2 指令注册系统

```gdscript
@tool
class_name InstructionRegistry extends RefCounted

static var registered_instructions: Dictionary = {}

## 注册指令类型
static func register_instruction(instruction_name: String, instruction_script: Script):
    registered_instructions[instruction_name] = instruction_script

## 获取所有注册的指令
static func get_registered_instructions() -> Dictionary:
    return registered_instructions

## 创建指令实例
static func create_instruction(instruction_name: String) -> BaseInstruction:
    var script = registered_instructions.get(instruction_name)
    if script:
        return script.new()
    return null

## 自动发现并注册指令
static func auto_register_instructions():
    var directory = DirAccess.open("res://addons/visual_programming/instructions/")
    if directory:
        _scan_directory_for_instructions(directory)
```

### 4.2 触发器系统扩展点

#### 4.2.1 自定义触发器基类

```gdscript
@tool
class_name CustomTrigger extends BaseTrigger

@export_group("Trigger Settings")
@export var trigger_event: String = "custom_event"
@export var target_group: String = ""

func _ready():
    super._ready()
    _setup_custom_listeners()

func _setup_custom_listeners():
    # 子类实现具体的事件监听逻辑
    pass

func _on_custom_event_occurred(data: Dictionary = {}):
    # 处理自定义事件
    trigger_actions(data.get("target", null))
```

#### 4.2.2 通用信号触发器

```gdscript
@tool
class_name TriggerOnSignal extends BaseTrigger

@export_group("Signal Settings")
@export var signal_source: NodePath
@export var signal_name: String = ""
@export var target_argument_index: int = 0

var source_node: Node = null

func _ready():
    super._ready()
    _connect_to_signal()

func _connect_to_signal():
    if signal_name.is_empty():
        return
    
    source_node = get_node_or_null(signal_source)
    if source_node:
        if not source_node.has_signal(signal_name):
            print_warning("Node %s does not have signal: %s" % [source_node.name, signal_name])
            return
        
        # 动态连接到指定信号
        source_node.connect(signal_name, _on_signal_triggered)

func _on_signal_triggered(...):
    var args = Array([...])
    var target = null
    
    if target_argument_index >= 0 and target_argument_index < args.size():
        target = args[target_argument_index]
    
    trigger_actions(target)
```

### 4.3 条件系统扩展点

#### 4.3.1 复合条件

```gdscript
@tool
class_name CompositeCondition extends BaseCondition

@export_group("Composite Settings")
@export var logical_operator: LogicalOperator = LogicalOperator.AND
@export var sub_conditions: Array[BaseCondition] = []

enum LogicalOperator { AND, OR, NOT, NAND, NOR }

func check(context: ExecutionContext) -> bool:
    match logical_operator:
        LogicalOperator.AND:
            return _check_and(context)
        LogicalOperator.OR:
            return _check_or(context)
        LogicalOperator.NOT:
            return _check_not(context)
        LogicalOperator.NAND:
            return not _check_and(context)
        LogicalOperator.NOR:
            return not _check_or(context)
    return false

func _check_and(context: ExecutionContext) -> bool:
    for condition in sub_conditions:
        if condition and not condition.check(context):
            return false
    return true

func _check_or(context: ExecutionContext) -> bool:
    for condition in sub_conditions:
        if condition and condition.check(context):
            return true
    return false

func _check_not(context: ExecutionContext) -> bool:
    if sub_conditions.size() > 0:
        return not sub_conditions[0].check(context)
    return true
```

### 4.4 编辑器扩展点

#### 4.4.1 自定义Inspector插件

```gdscript
@tool
@icon("res://addons/visual_programming/icons/visual_script_editor.svg")
extends EditorInspectorPlugin

const ActionRunnerEditor = preload("res://addons/visual_programming/editor/action_runner_editor.gd")

func _can_handle(object):
    return object is ActionRunner

func _parse_begin(object):
    var editor = ActionRunnerEditor.new()
    editor.set_object(object)
    add_custom_control(editor)
```

#### 4.4.2 可视化编辑器

```gdscript
@tool
class_name VisualScriptEditor extends Control

var current_action_runner: ActionRunner
var instruction_library: VBoxContainer
var workspace: Control

func _ready():
    _setup_ui()
    _load_instruction_library()

func _setup_ui():
    # 创建编辑器界面
    var split_container = HSplitContainer.new()
    add_child(split_container)
    
    # 左侧：指令库
    instruction_library = VBoxContainer.new()
    instruction_library.custom_minimum_size.x = 200
    split_container.add_child(instruction_library)
    
    # 右侧：工作区
    workspace = Control.new()
    split_container.add_child(workspace)

func _load_instruction_library():
    # 加载所有可用指令
    var instructions = InstructionRegistry.get_registered_instructions()
    for instruction_name in instructions.keys():
        var button = Button.new()
        button.text = instruction_name
        button.pressed.connect(_on_instruction_button_pressed.bind(instruction_name))
        instruction_library.add_child(button)

func _on_instruction_button_pressed(instruction_name: String):
    # 创建指令并添加到当前ActionRunner
    var instruction = InstructionRegistry.create_instruction(instruction_name)
    if instruction and current_action_runner:
        current_action_runner.instructions.append(instruction)
        _refresh_workspace()
```

---

## 5. 与Godot特性的集成方案

### 5.1 Resource系统深度集成

#### 5.1.1 资源重用机制

```gdscript
@tool
class_name ResourceManager extends RefCounted

## 创建可重用的ActionRunner
static func create_reusable_action_runner(name: String) -> ActionRunner:
    var action_runner = ActionRunner.new()
    action_runner.resource_name = name
    ResourceSaver.save(action_runner, "res://visual_scripts/%s.tres" % name)
    return action_runner

## 加载可重用的ActionRunner
static func load_reusable_action_runner(name: String) -> ActionRunner:
    var path = "res://visual_scripts/%s.tres" % name
    if ResourceLoader.exists(path):
        return ResourceLoader.load(path)
    return null

## 创建内嵌的ActionRunner
static func create_embedded_action_runner() -> ActionRunner:
    return ActionRunner.new()
```

#### 5.1.2 资源版本管理

```gdscript
@tool
class_name ResourceVersionManager extends RefCounted

## 资源版本信息
class ResourceVersion:
    var version: String
    var changelog: String
    var migration_script: Script

static var version_history: Dictionary = {}

## 注册资源版本
static func register_version(resource_type: String, version_info: ResourceVersion):
    if not version_history.has(resource_type):
        version_history[resource_type] = []
    version_history[resource_type].append(version_info)

## 检查资源是否需要迁移
static func needs_migration(resource: Resource, target_version: String) -> bool:
    var current_version = resource.get("version", "1.0.0")
    return current_version != target_version

## 执行资源迁移
static func migrate_resource(resource: Resource, target_version: String) -> Resource:
    var resource_type = resource.get_class()
    var versions = version_history.get(resource_type, [])
    
    for version_info in versions:
        if version_info.version == target_version and version_info.migration_script:
            return version_info.migration_script.new().migrate(resource)
    
    return resource
```

### 5.2 Signal系统优化集成

#### 5.2.1 信号连接管理器

```gdscript
@tool
class_name SignalConnectionManager extends RefCounted

var active_connections: Array[Dictionary] = []

## 安全连接信号
func connect_signal(source: Object, signal_name: String, target: Callable, flags: int = 0) -> Error:
    if not source or not source.has_signal(signal_name):
        return ERR_METHOD_NOT_FOUND
    
    var connection = {
        "source": source,
        "signal": signal_name,
        "target": target,
        "flags": flags
    }
    
    var result = source.connect(signal_name, target, flags)
    if result == OK:
        active_connections.append(connection)
    
    return result

## 断开所有连接
func disconnect_all():
    for connection in active_connections:
        if connection.source and connection.source.is_connected(connection.signal, connection.target):
            connection.source.disconnect(connection.signal, connection.target)
    
    active_connections.clear()

## 清理无效连接
func cleanup_invalid_connections():
    var valid_connections = []
    for connection in active_connections:
        if connection.source and is_instance_valid(connection.source):
            valid_connections.append(connection)
    
    active_connections = valid_connections
```

#### 5.2.2 异步执行优化

```gdscript
@tool
class_name AsyncExecutionManager extends Node

var active_tasks: Array[AsyncTask] = []
var max_concurrent_tasks: int = 10

## 异步任务类
class AsyncTask:
    var id: String
    var context: ExecutionContext
    var instruction: BaseInstruction
    var status: String = "pending"
    var start_time: float
    var end_time: float

## 执行异步指令
func execute_async(instruction: BaseInstruction, context: ExecutionContext) -> String:
    # 检查并发限制
    if _get_running_task_count() >= max_concurrent_tasks:
        await _wait_for_task_completion()
    
    var task = AsyncTask.new()
    task.id = _generate_task_id()
    task.context = context
    task.instruction = instruction
    task.start_time = Time.get_ticks_msec()
    
    active_tasks.append(task)
    
    # 连接完成信号
    instruction.finished.connect(_on_instruction_finished.bind(task.id))
    
    # 执行指令
    instruction.execute(context)
    
    return task.id

## 等待任务完成
func _on_instruction_finished(task_id: String):
    var task = _find_task(task_id)
    if task:
        task.status = "completed"
        task.end_time = Time.get_ticks_msec()
        active_tasks.erase(task)

## 获取正在运行的任务数量
func _get_running_task_count() -> int:
    var count = 0
    for task in active_tasks:
        if task.status == "running":
            count += 1
    return count
```

### 5.3 NodePath系统集成

#### 5.3.1 路径解析器

```gdscript
@tool
class_name NodePathResolver extends RefCounted

## 解析相对路径
static func resolve_relative_path(context: ExecutionContext, path: NodePath) -> Node:
    if path.is_empty():
        return null
    
    var base_node = context.trigger if context.trigger else context.target
    if not base_node:
        return null
    
    return base_node.get_node_or_null(path)

## 解析绝对路径
static func resolve_absolute_path(path: NodePath) -> Node:
    if path.is_empty():
        return null
    
    var scene_tree = Engine.get_main_loop() as SceneTree
    if not scene_tree or not scene_tree.current_scene:
        return null
    
    return scene_tree.current_scene.get_node_or_null(path)

## 解析组路径
static func resolve_group_path(group_name: String) -> Array[Node]:
    var scene_tree = Engine.get_main_loop() as SceneTree
    if not scene_tree or not scene_tree.current_scene:
        return []
    
    return scene_tree.get_nodes_in_group(group_name)
```

#### 5.3.2 路径验证器

```gdscript
@tool
class_name NodePathValidator extends RefCounted

## 验证路径有效性
static func validate_path(context: ExecutionContext, path: NodePath) -> Dictionary:
    var result = {
        "valid": false,
        "node": null,
        "error": ""
    }
    
    if path.is_empty():
        result.error = "Path is empty"
        return result
    
    var node = NodePathResolver.resolve_relative_path(context, path)
    if not node:
        result.error = "Node not found at path: %s" % path
        return result
    
    result.valid = true
    result.node = node
    return result

## 验证节点类型
static func validate_node_type(node: Node, expected_type: String) -> bool:
    if not node:
        return false
    
    return node.is_class(expected_type) or ClassDB.class_exists(expected_type) and node.get_script().get_base_script().get_global_name() == expected_type
```

### 5.4 SceneTree系统集成

#### 5.4.1 场景生命周期管理

```gdscript
@tool
class_name SceneLifecycleManager extends Node

var active_triggers: Array[BaseTrigger] = []
var scene_state: String = "loading"

func _ready():
    scene_state = "ready"
    _notify_triggers_scene_ready()

func _enter_tree():
    scene_state = "entering"
    _notify_triggers_scene_entering()

func _exit_tree():
    scene_state = "exiting"
    _notify_triggers_scene_exiting()

## 注册触发器
func register_trigger(trigger: BaseTrigger):
    if trigger not in active_triggers:
        active_triggers.append(trigger)

## 注销触发器
func unregister_trigger(trigger: BaseTrigger):
    active_triggers.erase(trigger)

## 通知触发器场景就绪
func _notify_triggers_scene_ready():
    for trigger in active_triggers:
        if trigger.enabled:
            trigger.on_scene_ready()

## 通知触发器场景进入
func _notify_triggers_scene_entering():
    for trigger in active_triggers:
        if trigger.enabled:
            trigger.on_scene_entering()

## 通知触发器场景退出
func _notify_triggers_scene_exiting():
    for trigger in active_triggers:
        if trigger.enabled:
            trigger.on_scene_exiting()
```

#### 5.4.2 跨场景通信

```gdscript
@tool
class_name CrossSceneCommunicator extends Node

static var instance: CrossSceneCommunicator
var scene_data: Dictionary = {}

func _init():
    if not instance:
        instance = self

## 设置场景数据
static func set_scene_data(scene_name: String, key: String, value):
    if instance:
        if not instance.scene_data.has(scene_name):
            instance.scene_data[scene_name] = {}
        instance.scene_data[scene_name][key] = value

## 获取场景数据
static func get_scene_data(scene_name: String, key: String, default_value = null):
    if instance and instance.scene_data.has(scene_name):
        return instance.scene_data[scene_name].get(key, default_value)
    return default_value

## 清理场景数据
static func clear_scene_data(scene_name: String):
    if instance and instance.scene_data.has(scene_name):
        instance.scene_data.erase(scene_name)
```

### 5.5 编辑器工具集成

#### 5.5.1 自定义编辑器插件

```gdscript
@tool
extends EditorPlugin

const VisualScriptDock = preload("res://addons/visual_programming/editor/visual_script_dock.gd")
var visual_script_dock: Control

func _enter_tree():
    # 添加自定义类型
    add_custom_type(
        "BaseTrigger",
        "Node",
        preload("res://addons/visual_programming/triggers/base_trigger.gd"),
        preload("res://addons/visual_programming/icons/trigger.svg")
    )
    
    add_custom_type(
        "ActionRunner",
        "Resource",
        preload("res://addons/visual_programming/core/action_runner.gd"),
        preload("res://addons/visual_programming/icons/action_runner.svg")
    )
    
    # 添加Inspector插件
    add_inspector_plugin(preload("res://addons/visual_programming/editor/action_runner_inspector.gd").new())
    
    # 添加停靠面板
    visual_script_dock = VisualScriptDock.new()
    add_control_to_dock(DOCK_SLOT_LEFT_UL, visual_script_dock)

func _exit_tree():
    # 移除自定义类型
    remove_custom_type("BaseTrigger")
    remove_custom_type("ActionRunner")
    
    # 移除停靠面板
    remove_control_from_docks(visual_script_dock)
    visual_script_dock.queue_free()
```

#### 5.5.2 可视化编辑界面

```gdscript
@tool
class_name VisualScriptDock extends Control

var scene_tree: Tree
var property_editor: Control
var toolbar: HBoxContainer

func _ready():
    _setup_ui()
    _connect_signals()

func _setup_ui():
    # 创建垂直布局
    var vbox = VBoxContainer.new()
    add_child(vbox)
    
    # 工具栏
    toolbar = HBoxContainer.new()
    vbox.add_child(toolbar)
    
    var new_trigger_btn = Button.new()
    new_trigger_btn.text = "New Trigger"
    new_trigger_btn.pressed.connect(_on_new_trigger_pressed)
    toolbar.add_child(new_trigger_btn)
    
    var new_action_btn = Button.new()
    new_action_btn.text = "New Action"
    new_action_btn.pressed.connect(_on_new_action_pressed)
    toolbar.add_child(new_action_btn)
    
    # 场景树
    scene_tree = Tree.new()
    scene_tree.custom_minimum_size.y = 200
    vbox.add_child(scene_tree)
    
    # 属性编辑器
    property_editor = Control.new()
    property_editor.custom_minimum_size.y = 300
    vbox.add_child(property_editor)

func _connect_signals():
    scene_tree.item_selected.connect(_on_tree_item_selected)
    scene_tree.item_activated.connect(_on_tree_item_activated)

func _on_tree_item_selected():
    var item = scene_tree.get_selected()
    if item:
        _show_properties(item.get_meta("object"))

func _on_tree_item_activated():
    var item = scene_tree.get_selected()
    if item:
        _focus_node_in_scene(item.get_meta("object"))

func _show_properties(object: Object):
    # 显示选中对象的属性
    pass

func _focus_node_in_scene(object: Object):
    # 在场景中聚焦节点
    pass
```

---

## 总结

本架构设计充分融合了GameCreator的先进设计理念和Godot 4.x的核心特性，创建了一个既强大又灵活的可视化编程系统。主要特点包括：

1. **资源与节点的分离设计**：实现了逻辑的可重用性和内嵌的灵活性
2. **异步优先的执行模型**：基于Signal和await机制确保游戏流畅性
3. **完整的组件体系**：涵盖指令、触发器、条件、变量等核心组件
4. **强大的扩展机制**：支持自定义指令、触发器、条件和编辑器工具
5. **深度Godot集成**：充分利用Resource、Signal、NodePath、SceneTree等核心特性

这个架构为Godot 4.x提供了一个完整的可视化编程解决方案，既保持了系统的简洁性，又确保了强大的功能和良好的扩展性。

## 架构更新（2026-03）

- 新增 Runtime Instance 层：RuntimeEventInstance、RuntimeInstructionInstance、RuntimeActionRunnerInstance
- 新增统一变量系统：GlobalVariableAssistant + ScopeVariableContainer
- 新增 FuseError/FuseLogger 基础设施
- Trigger 使用两层继承：Trigger extends BaseTrigger
- 详细参考: [Runtime Instance 模式](../../archive/architecture/runtime-instance-pattern.md)