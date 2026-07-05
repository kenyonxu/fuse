@tool
class_name FuseTypeRegistrar extends RefCounted

## Fuse 类型注册器
##
## 统一管理所有 add_custom_type / remove_custom_type 调用，
## 数据驱动（_TYPES 表 + 循环），并提供开发期类型注册一致性校验。
## 通过持有 plugin: EditorPlugin 引用调用 add/remove_custom_type。

const _ICON: Texture2D = preload("res://icon.svg")

var _plugin: EditorPlugin

# [类型名, 注册基类, 脚本路径] —— 与 plugin.gd 原 add_custom_type 一一对应
const _TYPES: Array = [
	["BaseInstruction", "Resource", "res://addons/fuse/core/base/base_instruction.gd"],
	["ExecutionContext", "RefCounted", "res://addons/fuse/core/base/execution_context.gd"],
	["BaseCondition", "Resource", "res://addons/fuse/core/base/base_condition.gd"],
	["BaseVariable", "Resource", "res://addons/fuse/core/base/base_variable.gd"],
	["ActionRunner", "Resource", "res://addons/fuse/core/base/action_runner.gd"],
	["InstructionSerializer", "RefCounted", "res://addons/fuse/core/serialization/instruction_serializer.gd"],
	["BaseEvent", "Resource", "res://addons/fuse/core/base/base_event.gd"],
	["BaseTrigger", "Node", "res://addons/fuse/core/base_trigger.gd"],
	["Trigger", "Node", "res://addons/fuse/core/trigger.gd"],
	["FuseLogger", "RefCounted", "res://addons/fuse/core/logging/fuse_logger.gd"],
	["FuseError", "RefCounted", "res://addons/fuse/core/logging/fuse_error.gd"],
	["GlobalVariableManager", "RefCounted", "res://addons/fuse/core/global_variable_manager.gd"],
	["GlobalVariableResource", "Resource", "res://addons/fuse/core/global_variable_resource.gd"],
	["GlobalVariableAssistant", "Node", "res://addons/fuse/core/global_variable_assistant.gd"],
	["ScopeVariableContainer", "Node", "res://addons/fuse/core/base/scope_variable_container.gd"],
	["ScopeVariableManager", "Node", "res://addons/fuse/core/scope_variable_manager.gd"],
	["RuntimeEventInstance", "RefCounted", "res://addons/fuse/core/runtime_event_instance.gd"],
	["RuntimeActionRunnerInstance", "RefCounted", "res://addons/fuse/core/runtime_action_runner_instance.gd"],
	["CompiledInstructionSequence", "RefCounted", "res://addons/fuse/core/execution/compiled_instruction_sequence.gd"],
	["InstructionInstancePool", "RefCounted", "res://addons/fuse/core/pooling/instruction_instance_pool.gd"],
	["InstructionValidator", "RefCounted", "res://addons/fuse/editor/static_analysis/instruction_validator.gd"],
	["StaticAnalysisPanel", "Control", "res://addons/fuse/editor/static_analysis/static_analysis_panel.gd"],
	["ExecutionTracker", "RefCounted", "res://addons/fuse/editor/debugging/execution_tracker.gd"],
	["DebugVisualizer", "Control", "res://addons/fuse/editor/debugging/debug_visualizer.gd"],
	["FuseMetadata", "Resource", "res://addons/fuse/editor/metadata/fuse_metadata.gd"],
	["EventMetadata", "Resource", "res://addons/fuse/editor/metadata/event_metadata.gd"],
	["ConditionMetadata", "Resource", "res://addons/fuse/editor/metadata/condition_metadata.gd"],
	["FusePoolItem", "RefCounted", "res://addons/fuse/core/pooling/fuse_pool_item.gd"],
	["FuseObjectPool", "RefCounted", "res://addons/fuse/core/pooling/fuse_object_pool.gd"],
	["FusePoolManager", "RefCounted", "res://addons/fuse/core/pooling/fuse_pool_manager.gd"],
	["ComponentRegistry", "RefCounted", "res://addons/fuse/editor/component_registry.gd"],
	["EventRegistry", "RefCounted", "res://addons/fuse/editor/event_registry.gd"],
	["ConditionRegistry", "RefCounted", "res://addons/fuse/editor/condition_registry.gd"],
	["InstructionMetadata", "Resource", "res://addons/fuse/editor/instruction_selector/instructions_metadata.gd"],
	["InstructionRegistry", "RefCounted", "res://addons/fuse/editor/instruction_selector/instruction_registry.gd"],
	["InstructionSearch", "RefCounted", "res://addons/fuse/editor/instruction_selector/instructions_search.gd"],
	["InstructionSelector", "AcceptDialog", "res://addons/fuse/editor/instruction_selector/instructions_selector.gd"],
	["ComponentSelector", "AcceptDialog", "res://addons/fuse/editor/component_selector/component_selector.gd"],
	["TriggerMerger", "RefCounted", "res://addons/fuse/editor/context_menu/trigger_merger.gd"],
	["TriggerSplitter", "RefCounted", "res://addons/fuse/editor/context_menu/trigger_splitter.gd"],
	["PropertyInfo", "RefCounted", "res://addons/fuse/utils/property_info.gd"],
	["TypeConverter", "RefCounted", "res://addons/fuse/utils/type_converter.gd"],
	["PropertyManager", "RefCounted", "res://addons/fuse/utils/property_manager.gd"],
	["SignalInfo", "Resource", "res://addons/fuse/utils/signal_info.gd"],
	["SignalManager", "RefCounted", "res://addons/fuse/utils/signal_manager.gd"],
	["FuseNodeUtils", "RefCounted", "res://addons/fuse/utils/fuse_node_utils.gd"],
	["FunctionInfo", "Resource", "res://addons/fuse/utils/function_info.gd"],
	["FunctionManager", "RefCounted", "res://addons/fuse/utils/function_manager.gd"],
	["InputKeySelector", "EditorProperty", "res://addons/fuse/editor/input_key_selector/input_key_selector.gd"],
	["InputKeyDialog", "AcceptDialog", "res://addons/fuse/editor/input_key_selector/input_key_dialog.gd"],
	["FusePreset", "Resource", "res://addons/fuse/core/resources/fuse_preset.gd"],
]

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin

## 注册所有自定义类型
func setup() -> void:
	for t in _TYPES:
		_plugin.add_custom_type(t[0], t[1], load(t[2]), _ICON)
	# 开发期校验：类型注册基类与脚本实际继承一致性
	if Engine.is_editor_hint():
		_validate_type_registrations()

## 注销所有自定义类型
func teardown() -> void:
	for t in _TYPES:
		_plugin.remove_custom_type(t[0])

## 校验 _TYPES 的注册基类与脚本实际继承是否一致
## 递归向上遍历继承链，直到找到直接继承引擎类的基类
func _validate_type_registrations() -> void:
	for t in _TYPES:
		var type_name: String = t[0]
		var registered_base: String = t[1]
		var script = load(t[2]) as GDScript
		if script == null:
			push_warning("[Fuse] 校验失败：无法加载 %s" % t[2])
			continue
		var actual_base := ""
		var base_script = script.get_base_script()
		if base_script != null:
			var current_script = base_script
			while true:
				var next_base = current_script.get_base_script()
				if next_base != null:
					current_script = next_base
				else:
					actual_base = current_script.get_instance_base_type()
					break
		else:
			actual_base = script.get_instance_base_type()
		if actual_base != registered_base:
			push_warning("[Fuse] 类型注册不一致：%s 注册为 %s，实际继承 %s" % [type_name, registered_base, actual_base])
