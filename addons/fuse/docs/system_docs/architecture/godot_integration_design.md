# Godot特性集成设计方案

## 1. 概述

本文档详细描述了可视化编程系统与Godot 4.x引擎特性的深度集成方案。通过充分利用Godot的核心特性，我们创建了一个既符合Godot设计理念又具有强大功能的可视化编程系统。

## 2. Resource系统深度集成

### 2.1 资源重用机制

```gdscript
# ActionRunner资源化存储
class_name ActionRunnerResource
extends Resource

@export var instructions: Array[BaseInstruction] = []
@export var variables: VariableContainer
@export var metadata: Dictionary = {}

# 运行时创建ActionRunner
func create_runner(context: ExecutionContext) -> ActionRunner:
    var runner = ActionRunner.new(context)
    runner.instructions = instructions.duplicate(true)
    runner.variable_container = variables.duplicate(true)
    return runner

# 资源模板系统
class_name InstructionTemplate
extends Resource

@export var instruction_scene: PackedScene
@export var default_parameters: Dictionary = {}
@export var category: String = ""
@export var description: String = ""

func create_instruction() -> BaseInstruction:
    var instruction = instruction_scene.instantiate()
    if instruction.has_method("apply_template"):
        instruction.apply_template(default_parameters)
    return instruction
```

### 2.2 内嵌逻辑支持

```gdscript
# 场景内嵌逻辑组件
class_name SceneLogicComponent
extends Node

@export var logic_resources: Array[ActionRunnerResource] = []
@export var auto_start: bool = false
@export var start_delay: float = 0.0

var runners: Array[ActionRunner] = []
var context: ExecutionContext

func _ready():
    context = ExecutionContext.new(self)
    
    # 创建ActionRunner实例
    for resource in logic_resources:
        var runner = resource.create_runner(context)
        runners.append(runner)
    
    # 自动启动
    if auto_start:
        if start_delay > 0:
            await get_tree().create_timer(start_delay).timeout
        start_all()

func start_all():
    for runner in runners:
        runner.start()

func stop_all():
    for runner in runners:
        runner.stop()
```

### 2.3 资源版本管理

```gdscript
# 资源版本管理器
class_name ResourceVersionManager
extends RefCounted

class VersionInfo:
    var version: String
    var migration_script: Script
    var description: String

var version_history: Array[VersionInfo] = []
var current_version: String = "1.0.0"

func register_version(version: String, migration_script: Script, description: String = ""):
    var info = VersionInfo.new()
    info.version = version
    info.migration_script = migration_script
    info.description = description
    version_history.append(info)

func migrate_resource(resource: Resource, from_version: String, to_version: String) -> Resource:
    var from_index = _find_version_index(from_version)
    var to_index = _find_version_index(to_version)
    
    if from_index == -1 or to_index == -1:
        push_error("Invalid version for migration")
        return resource
    
    # 逐步迁移
    for i in range(from_index, to_index):
        var migration = version_history[i].migration_script
        if migration and migration.has_method("migrate"):
            resource = migration.migrate(resource)
    
    return resource
```

## 3. Signal系统优化集成

### 3.1 信号连接管理器

```gdscript
# 信号连接管理器
class_name SignalConnectionManager
extends RefCounted

class ConnectionInfo:
    var source: Object
    var signal_name: String
    var target: Object
    var method_name: String
    var binds: Array = []
    var flags: int = 0

var connections: Array[ConnectionInfo] = []

func connect_signal(source: Object, signal_name: String, target: Object, method_name: String, binds: Array = [], flags: int = 0) -> ConnectionInfo:
    var info = ConnectionInfo.new()
    info.source = source
    info.signal_name = signal_name
    info.target = target
    info.method_name = method_name
    info.binds = binds
    info.flags = flags
    
    # 安全连接
    if not source.is_connected(signal_name, _create_safe_callback(info)):
        source.connect(signal_name, _create_safe_callback(info), binds, flags)
    
    connections.append(info)
    return info

func _create_safe_callback(info: ConnectionInfo) -> Callable:
    return func(args):
        if is_instance_valid(info.target) and info.target.has_method(info.method_name):
            info.target.callv(info.method_name, args)

func disconnect_all():
    for info in connections:
        if is_instance_valid(info.source):
            info.source.disconnect(info.signal_name, _create_safe_callback(info))
    connections.clear()

func cleanup_invalid_connections():
    connections = connections.filter(func(info): return is_instance_valid(info.source) and is_instance_valid(info.target))
```

### 3.2 异步执行优化

```gdscript
# 基于Signal的异步执行器
class_name SignalAsyncExecutor
extends RefCounted

class AsyncTask:
    var id: String
    var callable: Callable
    var timeout: float = -1
    var on_complete: Callable
    var on_timeout: Callable
    var on_error: Callable

var active_tasks: Dictionary = {}
var task_counter: int = 0

func execute_async(callable: Callable, timeout: float = -1, on_complete: Callable = Callable(), on_timeout: Callable = Callable(), on_error: Callable = Callable()) -> String:
    var task_id = "task_%d" % task_counter
    task_counter += 1
    
    var task = AsyncTask.new()
    task.id = task_id
    task.callable = callable
    task.timeout = timeout
    task.on_complete = on_complete
    task.on_timeout = on_timeout
    task.on_error = on_error
    
    active_tasks[task_id] = task
    
    # 执行任务
    _execute_task(task)
    
    return task_id

func _execute_task(task: AsyncTask):
    var result = null
    var error = null
    
    try:
        # 如果callable返回Signal，等待信号
        var callable_result = task.callable.call()
        if callable_result is Signal:
            await callable_result
            result = callable_result
        else:
            result = callable_result
    except:
        error = "Task execution failed"
    
    # 完成回调
    active_tasks.erase(task.id)
    
    if error:
        if task.on_error.is_valid():
            task.on_error.call(error)
    else:
        if task.on_complete.is_valid():
            task.on_complete.call(result)
```

### 3.3 事件分发机制

```gdscript
# 事件分发器
class_name EventDispatcher
extends Node

signal event_dispatched(event_name: String, data: Dictionary)

class EventListener:
    var event_name: String
    var callback: Callable
    var priority: int = 0
    var filter: Callable = Callable()
    var once: bool = false

var listeners: Dictionary = {}
var event_queue: Array[Dictionary] = []
var processing_events: bool = false

func register_listener(event_name: String, callback: Callable, priority: int = 0, filter: Callable = Callable(), once: bool = false):
    if not listeners.has(event_name):
        listeners[event_name] = []
    
    var listener = EventListener.new()
    listener.event_name = event_name
    listener.callback = callback
    listener.priority = priority
    listener.filter = filter
    listener.once = once
    
    listeners[event_name].append(listener)
    _sort_listeners(event_name)

func dispatch_event(event_name: String, data: Dictionary = {}):
    event_queue.append({"name": event_name, "data": data})
    
    if not processing_events:
        _process_event_queue()

func _process_event_queue():
    processing_events = true
    
    while event_queue.size() > 0:
        var event = event_queue.pop_front()
        _dispatch_event_immediate(event.name, event.data)
    
    processing_events = false

func _dispatch_event_immediate(event_name: String, data: Dictionary):
    if not listeners.has(event_name):
        return
    
    var to_remove = []
    
    for listener in listeners[event_name]:
        # 应用过滤器
        if listener.filter.is_valid() and not listener.filter.call(data):
            continue
        
        # 调用回调
        listener.callback.call(data)
        
        # 一次性监听器
        if listener.once:
            to_remove.append(listener)
    
    # 移除一次性监听器
    for listener in to_remove:
        listeners[event_name].erase(listener)
```

## 4. NodePath系统集成

### 4.1 路径解析器

```gdscript
# NodePath解析器
class_name NodePathResolver
extends RefCounted

class PathContext:
    var root_node: Node
    var current_node: Node
    var variables: VariableContainer

func resolve_path(path: String, context: PathContext) -> Node:
    if path.is_empty():
        return null
    
    # 处理特殊路径
    if path.begins_with("$"):
        return _resolve_variable_path(path, context)
    elif path.begins_with("@"):
        return _resolve_relative_path(path, context)
    else:
        return _resolve_absolute_path(path, context)

func _resolve_variable_path(path: String, context: PathContext) -> Node:
    var var_name = path.substr(1)
    if context.variables and context.variables.has_variable(var_name):
        var value = context.variables.get_variable(var_name).get_value()
        if value is Node:
            return value
        elif value is NodePath:
            return context.root_node.get_node(value)
    return null

func _resolve_relative_path(path: String, context: PathContext) -> Node:
    var relative_path = path.substr(1)
    return context.current_node.get_node(relative_path)

func _resolve_absolute_path(path: String, context: PathContext) -> Node:
    return context.root_node.get_node(path)

func validate_path(path: String, context: PathContext) -> bool:
    var node = resolve_path(path, context)
    return node != null
```

### 4.2 路径验证器

```gdscript
# 路径验证器
class_name NodePathValidator
extends RefCounted

class ValidationResult:
    var is_valid: bool
    var resolved_node: Node
    var error_message: String
    var suggestions: Array[String] = []

func validate_and_suggest(path: String, context: PathContext) -> ValidationResult:
    var result = ValidationResult.new()
    
    if path.is_empty():
        result.is_valid = false
        result.error_message = "Path is empty"
        return result
    
    # 尝试解析路径
    var node = context.root_node.get_node_or_null(path)
    
    if node:
        result.is_valid = true
        result.resolved_node = node
        return result
    
    # 路径无效，生成建议
    result.is_valid = false
    result.error_message = "Invalid path: " + path
    result.suggestions = _generate_suggestions(path, context)
    
    return result

func _generate_suggestions(path: String, context: PathContext) -> Array[String]:
    var suggestions: Array[String] = []
    var parts = path.split("/")
    var current_path = ""
    
    # 逐级检查并生成建议
    for i in range(parts.size()):
        if parts[i].is_empty():
            continue
        
        var partial_path = "/".join(parts.slice(0, i + 1))
        var parent_path = "/".join(parts.slice(0, i))
        
        if i == 0:
            current_path = parts[0]
        else:
            current_path = parent_path + "/" + parts[i]
        
        var parent_node = context.root_node
        if parent_path:
            parent_node = context.root_node.get_node_or_null(parent_path)
        
        if parent_node:
            var children = _get_children_names(parent_node)
            var matches = _find_similar_names(parts[i], children)
            
            for match in matches:
                suggestions.append(parent_path + "/" + match if parent_path else match)
    
    return suggestions

func _get_children_names(node: Node) -> Array[String]:
    var names: Array[String] = []
    for child in node.get_children():
        names.append(child.name)
    return names

func _find_similar_names(target: String, candidates: Array[String]) -> Array[String]:
    var matches: Array[String] = []
    
    for candidate in candidates:
        if candidate.to_lower().contains(target.to_lower()):
            matches.append(candidate)
    
    return matches
```

### 4.3 场景实例化

```gdscript
# 场景实例化管理器
class_name SceneInstantiationManager
extends RefCounted

class InstanceRequest:
    var scene_path: String
    var parent: Node
    var position: Vector2 = Vector2.ZERO
    var properties: Dictionary = {}
    var on_instance_created: Callable
    var on_instance_ready: Callable

var pending_requests: Array[InstanceRequest] = []

func instantiate_scene_async(request: InstanceRequest) -> Node:
    # 加载场景
    var packed_scene = load(request.scene_path) as PackedScene
    if not packed_scene:
        push_error("Failed to load scene: " + request.scene_path)
        return null
    
    # 实例化场景
    var instance = packed_scene.instantiate()
    
    # 设置父节点
    if request.parent:
        request.parent.add_child(instance)
    
    # 设置位置
    if instance.has_method("set_position"):
        instance.set_position(request.position)
    elif instance is Node2D:
        instance.position = request.position
    
    # 应用属性
    for property in request.properties:
        if instance.set(property, request.properties[property]) != OK:
            push_warning("Failed to set property: " + property)
    
    # 调用创建回调
    if request.on_instance_created.is_valid():
        request.on_instance_created.call(instance)
    
    # 等待ready信号
    if request.on_instance_ready.is_valid():
        if not instance.is_node_ready():
            await instance.ready
        request.on_instance_ready.call(instance)
    
    return instance

func instantiate_scene_batch(requests: Array[InstanceRequest]) -> Array[Node]:
    var instances: Array[Node] = []
    
    for request in requests:
        var instance = instantiate_scene_async(request)
        if instance:
            instances.append(instance)
    
    return instances
```

## 5. 编辑器工具集成

### 5.1 自定义编辑器插件

```gdscript
# 主编辑器插件
@tool
extends EditorPlugin

var visual_programming_dock: Control
var node_graph_editor: Control
var inspector_plugin: EditorInspectorPlugin

func _enter_tree():
    # 创建停靠面板
    visual_programming_dock = preload("res://addons/visual_programming/dock/visual_programming_dock.tscn").instantiate()
    add_control_to_dock(DOCK_SLOT_LEFT_UL, visual_programming_dock)
    
    # 创建节点图编辑器
    node_graph_editor = preload("res://addons/visual_programming/editor/node_graph_editor.tscn").instantiate()
    add_control_to_bottom_panel(node_graph_editor, "Visual Programming")
    
    # 添加Inspector插件
    inspector_plugin = preload("res://addons/visual_programming/editor/visual_programming_inspector.gd").new()
    add_inspector_plugin(inspector_plugin)
    
    # 注册自定义类型
    _register_custom_types()

func _exit_tree():
    remove_control_from_docks(visual_programming_dock)
    remove_control_from_bottom_panel(node_graph_editor)
    remove_inspector_plugin(inspector_plugin)
    _unregister_custom_types()

func _register_custom_types():
    add_custom_type(
        "VisualScriptNode",
        "Node",
        preload("res://addons/visual_programming/nodes/visual_script_node.gd"),
        preload("res://addons/visual_programming/icons/visual_script_node.svg")
    )
    
    add_custom_type(
        "TriggerComponent",
        "Node",
        preload("res://addons/visual_programming/components/trigger_component.gd"),
        preload("res://addons/visual_programming/icons/trigger_component.svg")
    )

func _unregister_custom_types():
    remove_custom_type("VisualScriptNode")
    remove_custom_type("TriggerComponent")
```

### 5.2 可视化编辑界面

```gdscript
# 节点图编辑器
@tool
class_name NodeGraphEditor
extends GraphEdit

var node_factory: NodeFactory
var connection_manager: ConnectionManager
var context_menu: PopupMenu

func _ready():
    node_factory = NodeFactory.new()
    connection_manager = ConnectionManager.new()
    
    # 设置右键菜单
    context_menu = PopupMenu.new()
    add_child(context_menu)
    
    context_menu.add_item("Create Instruction", 0)
    context_menu.add_item("Create Trigger", 1)
    context_menu.add_item("Create Condition", 2)
    context_menu.add_separator()
    context_menu.add_item("Create Comment", 3)
    
    context_menu.id_pressed.connect(_on_context_menu_id_pressed)
    connection_request.connect(_on_connection_request)
    disconnection_request.connect(_on_disconnection_request)

func _on_gui_input(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
        context_menu.position = get_global_mouse_position()
        context_menu.popup()

func _on_context_menu_id_pressed(id: int):
    var mouse_pos = get_local_mouse_position()
    
    match id:
        0:
            _show_instruction_menu(mouse_pos)
        1:
            _show_trigger_menu(mouse_pos)
        2:
            _show_condition_menu(mouse_pos)
        3:
            _create_comment_node(mouse_pos)

func _show_instruction_menu(pos: Vector2):
    var menu = PopupMenu.new()
    add_child(menu)
    
    var categories = node_factory.get_instruction_categories()
    for category in categories:
        menu.add_item(category, categories.find(category))
    
    menu.id_pressed.connect(func(id): _create_instruction_node(categories[id], pos))
    menu.position = get_global_mouse_position()
    menu.popup()

func _create_instruction_node(category: String, pos: Vector2):
    var instruction_types = node_factory.get_instructions_by_category(category)
    if instruction_types.size() > 0:
        var node = node_factory.create_instruction_node(instruction_types[0])
        add_child(node)
        node.position_offset = pos
```

### 5.3 Inspector集成

```gdscript
# 自定义Inspector插件
@tool
extends EditorInspectorPlugin

func _can_handle(object: Object) -> bool:
    return object is BaseInstruction or object is BaseTrigger or object is BaseCondition

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
    # 自定义变量属性的编辑
    if name == "variables" and object is BaseInstruction:
        var property_editor = VariableListEditor.new()
        property_editor.setup(object, name)
        add_property_editor(name, property_editor)
        return true
    
    # 自定义NodePath属性的编辑
    if type == TYPE_NODE_PATH:
        var property_editor = NodePathEditor.new()
        property_editor.setup(object, name)
        add_property_editor(name, property_editor)
        return true
    
    return false

# 变量列表编辑器
@tool
class_name VariableListEditor
extends EditorProperty

var instruction: BaseInstruction
var property_name: String
var list: ItemList
var add_button: Button
var remove_button: Button

func setup(object: Object, name: String):
    instruction = object
    property_name = name
    
    # 创建UI
    var hbox = HBoxContainer.new()
    add_child(hbox)
    
    list = ItemList.new()
    list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    hbox.add_child(list)
    
    var vbox = VBoxContainer.new()
    hbox.add_child(vbox)
    
    add_button = Button.new()
    add_button.text = "Add"
    add_button.pressed.connect(_on_add_pressed)
    vbox.add_child(add_button)
    
    remove_button = Button.new()
    remove_button.text = "Remove"
    remove_button.pressed.connect(_on_remove_pressed)
    vbox.add_child(remove_button)
    
    # 连接信号
    list.item_selected.connect(_on_item_selected)
    
    # 更新显示
    _update_list()

func _update_list():
    list.clear()
    var variables = instruction.get(property_name)
    if variables:
        for i in range(variables.size()):
            list.add_item("Variable %d" % (i + 1))

func _on_add_pressed():
    var variables = instruction.get(property_name)
    if not variables:
        variables = []
    variables.append("")
    instruction.set(property_name, variables)
    _update_list()
    emit_changed(property_name)

func _on_remove_pressed():
    var selected = list.get_selected_items()
    if selected.size() > 0:
        var variables = instruction.get(property_name)
        variables.remove_at(selected[0])
        instruction.set(property_name, variables)
        _update_list()
        emit_changed(property_name)

func _on_item_selected(index: int):
    remove_button.disabled = false
```

## 6. 性能优化集成

### 6.1 对象池集成

```gdscript
# Godot对象池管理器
class_name GodotObjectPoolManager
extends Node

class PoolConfig:
    var scene_path: String
    var initial_size: int = 10
    var max_size: int = 100
    var auto_expand: bool = true

var pools: Dictionary = {}

func register_pool(pool_name: String, config: PoolConfig):
    var pool = ObjectPool.new()
    pool.setup(config.scene_path, config.initial_size, config.max_size, config.auto_expand)
    pools[pool_name] = pool

func get_object(pool_name: String) -> Node:
    if pools.has(pool_name):
        return pools[pool_name].get_object()
    return null

func return_object(pool_name: String, object: Node):
    if pools.has(pool_name):
        pools[pool_name].return_object(object)

func warm_up_pool(pool_name: String, count: int):
    if pools.has(pool_name):
        pools[pool_name].warm_up(count)

# 对象池实现
class_name ObjectPool
extends RefCounted

var scene: PackedScene
var available: Array[Node] = []
var in_use: Array[Node] = []
var max_size: int
var auto_expand: bool

func setup(scene_path: String, initial_size: int, max_size: int, auto_expand: bool):
    scene = load(scene_path)
    self.max_size = max_size
    self.auto_expand = auto_expand
    
    # 预创建对象
    for i in range(initial_size):
        _create_object()

func get_object() -> Node:
    if available.size() > 0:
        var object = available.pop_back()
        in_use.append(object)
        return object
    elif auto_expand and in_use.size() < max_size:
        var object = _create_object()
        in_use.append(object)
        return object
    else:
        push_warning("Pool exhausted")
        return null

func return_object(object: Node):
    if object in in_use:
        in_use.erase(object)
        _reset_object(object)
        available.append(object)

func _create_object() -> Node:
    var object = scene.instantiate()
    object.set_process(false)
    return object

func _reset_object(object: Node):
    object.set_process(false)
    if object.get_parent():
        object.get_parent().remove_child(object)
```

### 6.2 资源管理优化

```gdscript
# 资源管理器
class_name ResourceManager
extends Node

var loaded_resources: Dictionary = {}
var resource_refs: Dictionary = {}

func load_resource(path: String) -> Resource:
    if loaded_resources.has(path):
        _add_ref(path)
        return loaded_resources[path]
    
    var resource = load(path)
    if resource:
        loaded_resources[path] = resource
        resource_refs[path] = 1
    return resource

func unload_resource(path: String):
    if resource_refs.has(path):
        resource_refs[path] -= 1
        if resource_refs[path] <= 0:
            loaded_resources.erase(path)
            resource_refs.erase(path)

func _add_ref(path: String):
    if resource_refs.has(path):
        resource_refs[path] += 1

func get_memory_usage() -> Dictionary:
    var usage = {}
    for path in loaded_resources:
        usage[path] = loaded_resources[path].get_size()
    return usage

func cleanup_unused_resources():
    var to_remove = []
    for path in resource_refs:
        if resource_refs[path] <= 0:
            to_remove.append(path)
    
    for path in to_remove:
        loaded_resources.erase(path)
        resource_refs.erase(path)
```

## 7. 调试和分析集成

### 7.1 调试工具集成

```gdscript
# 调试管理器
class_name DebugManager
extends Node

var debug_enabled: bool = false
var debug_info: Dictionary = {}
var performance_monitor: PerformanceMonitor

func _ready():
    performance_monitor = PerformanceMonitor.new()
    add_child(performance_monitor)

func enable_debug():
    debug_enabled = true
    performance_monitor.start_monitoring()

func disable_debug():
    debug_enabled = false
    performance_monitor.stop_monitoring()

func log_execution(instruction: BaseInstruction, context: ExecutionContext):
    if not debug_enabled:
        return
    
    var entry = {
        "timestamp": Time.get_unix_time_from_system(),
        "instruction": instruction.get_script().get_global_name(),
        "context": context.get_debug_info(),
        "execution_time": instruction.last_execution_time
    }
    
    if not debug_info.has("executions"):
        debug_info["executions"] = []
    debug_info["executions"].append(entry)

func get_debug_report() -> Dictionary:
    return {
        "debug_info": debug_info,
        "performance": performance_monitor.get_report(),
        "memory_usage": performance_monitor.get_memory_usage()
    }

# 性能监控器
class_name PerformanceMonitor
extends Node

var monitoring: bool = false
var start_time: float = 0
var frame_times: Array[float] = []
var memory_snapshots: Array[Dictionary] = []

func start_monitoring():
    monitoring = true
    start_time = Time.get_unix_time_from_system()
    frame_times.clear()
    memory_snapshots.clear()

func stop_monitoring():
    monitoring = false

func _process(_delta):
    if monitoring:
        frame_times.append(get_process_delta_time())
        
        # 每秒记录一次内存使用情况
        if Engine.get_frames_drawn() % 60 == 0:
            memory_snapshots.append(_get_memory_snapshot())

func _get_memory_snapshot() -> Dictionary:
    return {
        "timestamp": Time.get_unix_time_from_system(),
        "static_memory": OS.get_static_memory_usage_by_type(),
        "dynamic_memory": OS.get_dynamic_memory_usage_by_type()
    }

func get_report() -> Dictionary:
    if frame_times.size() == 0:
        return {}
    
    var total_time = 0.0
    for time in frame_times:
        total_time += time
    
    return {
        "total_time": Time.get_unix_time_from_system() - start_time,
        "frame_count": frame_times.size(),
        "average_frame_time": total_time / frame_times.size(),
        "min_frame_time": frame_times.min(),
        "max_frame_time": frame_times.max(),
        "fps": frame_times.size() / (Time.get_unix_time_from_system() - start_time)
    }

func get_memory_usage() -> Array[Dictionary]:
    return memory_snapshots
```

## 8. 总结

通过深度集成Godot 4.x的核心特性，我们的可视化编程系统实现了：

1. **Resource系统集成**：提供了资源重用、内嵌逻辑和版本管理
2. **Signal系统优化**：实现了安全的信号连接、异步执行和事件分发
3. **NodePath系统集成**：提供了智能路径解析、验证和场景实例化
4. **编辑器工具集成**：创建了完整的可视化编辑环境和Inspector集成
5. **性能优化集成**：实现了对象池、资源管理和性能监控
6. **调试工具集成**：提供了全面的调试和分析功能

这种深度集成确保了系统与Godot引擎的完美融合，既保持了Godot的设计理念，又提供了强大的可视化编程能力。

## 更新说明（2026-03）

- Runtime Instance 模式：Event/Instruction/ActionRunner 均支持运行时实例分离
- 统一错误处理：FuseError 类提供本地化错误上下文
- 统一日志：FuseLogger 类提供分级日志输出
- 对象池集成：FusePoolManager 和 _on_pool_reset() 生命周期