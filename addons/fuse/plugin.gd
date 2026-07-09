@tool
extends EditorPlugin

## Fuse Visual Programming 插件主入口
##
## 生命周期编排器：按序委托给 4 个 bootstrap 模块：
##   FuseEditorBootstrap  → 本地化/图标/Inspector/菜单/场景刷新
##   FuseTypeRegistrar    → 50 个自定义类型注册（数据驱动）
##   FuseComponentScanner → 指令/事件/条件组件扫描
##   FuseRuntimeBootstrap → EventBus Autoload + 反射缓存清理

# Bootstrap 模块
var _editor_bootstrap: FuseEditorBootstrap = null
var _scanner: FuseComponentScanner = null
var _registrar: FuseTypeRegistrar = null
var _runtime_bootstrap: FuseRuntimeBootstrap = null

# Stage 2.5: 变量监视器
var _watcher: FuseVariableWatcher = null

# Stage 5.3: 全场景拓扑面板
var _topology: FuseTopology = null

## 当插件激活时调用
func _enter_tree():
    # 编辑器侧引导（本地化/图标/Inspector/菜单/场景刷新，必须最先，本地化优先）
    _editor_bootstrap = FuseEditorBootstrap.new(self)
    _editor_bootstrap.setup()

    # 注册核心类（数据驱动类型表）
    _registrar = FuseTypeRegistrar.new(self)
    _registrar.setup()

    # 扫描并注册所有组件
    _scanner = FuseComponentScanner.new(self)
    _scanner.setup()

    # 运行时基础设施（EventBus + 反射缓存）
    _runtime_bootstrap = FuseRuntimeBootstrap.new(self)
    _runtime_bootstrap.setup()

    # Stage 2.5: 注册变量监视器 (底部面板)
    _watcher = preload("res://addons/fuse/editor/debugging/variable_watcher.gd").new()
    add_control_to_bottom_panel(_watcher, "Fuse Variables")
    print("Fuse 变量监视器已注册")

    # Stage 5.3: 注册全场景拓扑面板 (主屏幕 Tab)
    _topology = preload("res://addons/fuse/editor/topology/fuse_topology.gd").new()
    EditorInterface.get_editor_main_screen().add_child(_topology)
    print("Fuse 拓扑面板已注册")

	# 初始隐藏,用户切换到 Fuse Tab 时 _make_visible(true) 显示
    _make_visible(false)

    print("Fuse Visual Programming 插件已激活")

## 当插件停用时调用
func _exit_tree():
    # 逆序清理
    # Stage 5.3: 移除拓扑面板
    if _topology:
        
        _topology.queue_free()
        _topology = null

    # Stage 2.5: 移除变量监视器
    if _watcher:
        remove_control_from_bottom_panel(_watcher)
        _watcher = null

    if _runtime_bootstrap:
        _runtime_bootstrap.teardown()
        _runtime_bootstrap = null

    if _scanner:
        _scanner.teardown()
        _scanner = null
    if _registrar:
        _registrar.teardown()
        _registrar = null
    if _editor_bootstrap:
        _editor_bootstrap.teardown()
        _editor_bootstrap = null
    print("Fuse Visual Programming 插件已停用")

## 获取插件名称
func _get_plugin_name() -> String:
    return "Fuse"

## 获取插件图标
func _get_main_screen_icon() -> Texture2D:
    return EditorInterface.get_editor_theme().get_icon("VisualShader", "EditorIcons")

## 编辑器工具方法
func _has_main_screen() -> bool:
    return true

func _make_visible(visible: bool):
    if _topology:
        _topology.visible = visible

## 配置检查
func _get_configuration_warnings() -> PackedStringArray:
    var warnings: PackedStringArray = []

    # 必要脚本文件清单：[类名, 文件路径]
    var required_scripts: Array[Dictionary] = [
        {"name": "BaseInstruction", "path": "res://addons/fuse/core/base/base_instruction.gd"},
        {"name": "ExecutionContext", "path": "res://addons/fuse/core/base/execution_context.gd"},
        {"name": "BaseCondition", "path": "res://addons/fuse/core/base/base_condition.gd"},
        {"name": "BaseVariable", "path": "res://addons/fuse/core/base/base_variable.gd"},
        {"name": "ActionRunner", "path": "res://addons/fuse/core/base/action_runner.gd"},
        {"name": "InstructionSerializer", "path": "res://addons/fuse/core/serialization/instruction_serializer.gd"},
        {"name": "BaseEvent", "path": "res://addons/fuse/core/base/base_event.gd"},
        {"name": "BaseTrigger", "path": "res://addons/fuse/core/base_trigger.gd"},
        {"name": "Trigger", "path": "res://addons/fuse/core/trigger.gd"},
        {"name": "GlobalVariableManager", "path": "res://addons/fuse/core/global_variable_manager.gd"},
        {"name": "GlobalVariableResource", "path": "res://addons/fuse/core/global_variable_resource.gd"},
        {"name": "GlobalVariableAssistant", "path": "res://addons/fuse/core/global_variable_assistant.gd"},
        {"name": "FuseLogger", "path": "res://addons/fuse/core/logging/fuse_logger.gd"},
        {"name": "FuseError", "path": "res://addons/fuse/core/logging/fuse_error.gd"},
        {"name": "RuntimeEventInstance", "path": "res://addons/fuse/core/runtime_event_instance.gd"},
        {"name": "ExecutionTracker", "path": "res://addons/fuse/editor/debugging/execution_tracker.gd"},
        {"name": "DebugVisualizer", "path": "res://addons/fuse/editor/debugging/debug_visualizer.gd"},
        {"name": "FuseMetadata", "path": "res://addons/fuse/editor/metadata/fuse_metadata.gd"},
        {"name": "EventMetadata", "path": "res://addons/fuse/editor/metadata/event_metadata.gd"},
        {"name": "ConditionMetadata", "path": "res://addons/fuse/editor/metadata/condition_metadata.gd"},
        {"name": "ComponentRegistry", "path": "res://addons/fuse/editor/component_registry.gd"},
        {"name": "EventRegistry", "path": "res://addons/fuse/editor/event_registry.gd"},
        {"name": "ConditionRegistry", "path": "res://addons/fuse/editor/condition_registry.gd"},
        {"name": "InstructionMetadata", "path": "res://addons/fuse/editor/instruction_selector/instructions_metadata.gd"},
        {"name": "InstructionRegistry", "path": "res://addons/fuse/editor/instruction_selector/instruction_registry.gd"},
        {"name": "InstructionSearch", "path": "res://addons/fuse/editor/instruction_selector/instructions_search.gd"},
        {"name": "InstructionSelector", "path": "res://addons/fuse/editor/instruction_selector/instructions_selector.gd"},
        {"name": "PropertyInfo", "path": "res://addons/fuse/utils/property_info.gd"},
        {"name": "TypeConverter", "path": "res://addons/fuse/utils/type_converter.gd"},
        {"name": "PropertyManager", "path": "res://addons/fuse/utils/property_manager.gd"},
        {"name": "SignalInfo", "path": "res://addons/fuse/utils/signal_info.gd"},
        {"name": "SignalManager", "path": "res://addons/fuse/utils/signal_manager.gd"},
        {"name": "FunctionInfo", "path": "res://addons/fuse/utils/function_info.gd"},
        {"name": "FunctionManager", "path": "res://addons/fuse/utils/function_manager.gd"},
        {"name": "InputKeySelector", "path": "res://addons/fuse/editor/input_key_selector/input_key_selector.gd"},
        {"name": "InputKeyDialog", "path": "res://addons/fuse/editor/input_key_selector/input_key_dialog.gd"},
        {"name": "InputKeyInspectorPlugin", "path": "res://addons/fuse/editor/input_key_selector/input_key_inspector_plugin.gd"},
        {"name": "ComponentSelector", "path": "res://addons/fuse/editor/component_selector/component_selector.gd"},
        {"name": "FuseInspectorPlugin", "path": "res://addons/fuse/editor/fuse_inspector_plugin.gd"},
    ]

    for entry in required_scripts:
        if not FileAccess.file_exists(entry.path):
            warnings.append("%s script not found" % entry.name)

    return warnings


