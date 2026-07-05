# 文件：addons/fuse/editor/context_menu/trigger_splitter.gd
@tool
class_name TriggerSplitter extends RefCounted

## TriggerSplitter - MultiEventTrigger 拆分工具类
##
## 用于将 MultiEventTrigger 节点拆分为多个独立的 Trigger 节点。
## 支持 UndoRedo 操作，确保用户可以撤销拆分。

## ==================== 常量 ====================

const TriggerClass = preload("res://addons/fuse/core/trigger.gd")
const MultiEventTriggerClass = preload("res://addons/fuse/core/multi_event_trigger.gd")
const EventBindingClass = preload("res://addons/fuse/core/event_binding.gd")
const FuseLocalizationClass = preload("res://addons/fuse/localization/fuse_localization.gd")

## ==================== 成员变量 ====================

var _editor_interface: EditorInterface
var _undo_redo: EditorUndoRedoManager

## ==================== 初始化 ====================

func _init(editor_interface: EditorInterface, undo_redo: EditorUndoRedoManager) -> void:
	_editor_interface = editor_interface
	_undo_redo = undo_redo

## ==================== 静态检查方法 ====================

## 检查是否可以拆分指定的节点
## @param node 要检查的节点
## @return 是否可以拆分
static func can_split(node: Node) -> bool:
	# 必须是 MultiEventTrigger 类型
	if not node is MultiEventTrigger:
		return false

	# 必须有至少 2 个 EventBinding
	var multi_trigger: MultiEventTrigger = node as MultiEventTrigger
	if multi_trigger.event_bindings.size() < 2:
		return false

	return true

## ==================== 拆分操作 ====================

## 执行拆分操作
## @param node 要拆分的 MultiEventTrigger 节点
func split(node: Node) -> void:
	# 预检查
	if not can_split(node):
		push_error("TriggerSplitter: 无法拆分节点，检查失败")
		return

	var multi_trigger: MultiEventTrigger = node as MultiEventTrigger

	# 获取父节点和索引
	var parent: Node = multi_trigger.get_parent()
	if parent == null:
		push_error("TriggerSplitter: MultiEventTrigger 没有父节点")
		return

	var trigger_index: int = multi_trigger.get_index()

	# 创建备份数据（用于 Undo）
	var backup: Dictionary = _create_backup(multi_trigger)

	# 创建 Trigger 节点数组
	var triggers: Array[Node] = []
	for binding: EventBinding in multi_trigger.event_bindings:
		var trigger: Trigger = _create_trigger_from_binding(binding)
		triggers.append(trigger)

	# 添加 UndoRedo 操作
	_undo_redo.create_action("拆分 MultiEventTrigger")

	# Do 操作
	_undo_redo.add_do_method(self, "_do_split", parent, triggers, multi_trigger, trigger_index)

	# Undo 操作
	_undo_redo.add_undo_method(self, "_undo_split", parent, triggers, backup, trigger_index)

	# 提交操作
	_undo_redo.commit_action()

	# 选中所有新创建的 Trigger
	_select_nodes(triggers)

	print("[TriggerSplitter] %s" % FuseLocalizationClass.translate_format("FUSE_SPLIT_COMPLETED", {"count": triggers.size()}))

## ==================== 私有辅助方法 ====================

## 从 EventBinding 创建 Trigger
## @param binding 源 EventBinding
## @return 创建的 Trigger
func _create_trigger_from_binding(binding: EventBinding) -> Trigger:
	var trigger := Trigger.new()

	# 深拷贝事件定义
	if binding.event != null:
		trigger.event_definition = binding.event.duplicate(true)

	# 深拷贝 ActionRunner
	if binding.action_runner != null:
		trigger.action_runner = binding.action_runner.duplicate(true)

	# 复制其他属性
	trigger.trigger_once = binding.trigger_once
	trigger.cooldown_mode = binding.cooldown_mode
	trigger.cooldown_time = binding.cooldown_time
	# 注意：Trigger 类没有 enabled 属性，enabled 是 EventBinding 特有的

	return trigger

## 创建备份数据（用于 Undo）
## @param multi_trigger MultiEventTrigger 节点
## @return 备份数据字典
func _create_backup(multi_trigger: MultiEventTrigger) -> Dictionary:
	# 深拷贝所有 EventBinding
	var bindings_copy: Array[EventBinding] = []
	for binding: EventBinding in multi_trigger.event_bindings:
		var copy := EventBindingClass.new()
		if binding.event != null:
			copy.event = binding.event.duplicate(true)
		if binding.action_runner != null:
			copy.action_runner = binding.action_runner.duplicate(true)
		copy.trigger_once = binding.trigger_once
		copy.cooldown_mode = binding.cooldown_mode
		copy.cooldown_time = binding.cooldown_time
		copy.enabled = binding.enabled
		bindings_copy.append(copy)

	return {
		"name": multi_trigger.name,
		"index": multi_trigger.get_index(),
		"event_bindings": bindings_copy
	}

## 获取事件名称（用于 Trigger 命名）
## @param event 事件对象
## @return 事件类名
func _get_event_name(event: Resource) -> String:
	if event == null:
		return "Trigger"

	var script: Script = event.get_script()
	if script == null:
		# 尝试获取资源名称
		if event.resource_name.is_empty():
			return "Trigger"
		return event.resource_name

	var event_name: String = script.get_global_name()
	if event_name.is_empty():
		if script.resource_path.is_empty():
			return "Trigger"
		event_name = script.resource_path.get_file().get_basename()

	return event_name if not event_name.is_empty() else "Trigger"

## 生成唯一的 Trigger 名称
## @param base_name 基础名称（事件名）
## @param existing_names 已存在的名称集合
## @return 唯一名称
func _generate_unique_name(base_name: String, existing_names: Dictionary) -> String:
	if not existing_names.has(base_name):
		existing_names[base_name] = true
		return base_name

	var counter: int = 1
	while existing_names.has("%s_%d" % [base_name, counter]):
		counter += 1

	var unique_name: String = "%s_%d" % [base_name, counter]
	existing_names[unique_name] = true
	return unique_name

## Do 操作：执行拆分
func _do_split(parent: Node, triggers: Array[Node], multi_trigger: MultiEventTrigger, start_index: int) -> void:
	# 删除 MultiEventTrigger
	if is_instance_valid(multi_trigger):
		multi_trigger.get_parent().remove_child(multi_trigger)
		multi_trigger.queue_free()

	# 添加所有 Trigger 到父节点，使用事件名命名
	var used_names: Dictionary = {}
	for i in range(triggers.size()):
		var trigger: Node = triggers[i]
		if not is_instance_valid(trigger):
			continue
		# 使用事件名称命名
		var base_name: String = _get_event_name(trigger.event_definition)
		trigger.name = _generate_unique_name(base_name, used_names)
		parent.add_child(trigger)
		trigger.owner = parent.owner
		parent.move_child(trigger, start_index + i)

## Undo 操作：撤销拆分
func _undo_split(parent: Node, triggers: Array[Node], backup: Dictionary, start_index: int) -> void:
	# 删除所有 Trigger
	for trigger: Node in triggers:
		if is_instance_valid(trigger):
			trigger.get_parent().remove_child(trigger)
			trigger.queue_free()

	# 重建 MultiEventTrigger
	var multi_trigger := MultiEventTriggerClass.new()
	multi_trigger.name = backup.name

	# 恢复 EventBindings
	var bindings: Array[EventBinding] = []
	for binding: EventBinding in backup.event_bindings:
		bindings.append(binding)
	multi_trigger.event_bindings = bindings

	# 添加回父节点
	parent.add_child(multi_trigger)
	multi_trigger.owner = parent.owner
	parent.move_child(multi_trigger, start_index)

## 选中多个节点
## @param nodes 要选中的节点数组
func _select_nodes(nodes: Array[Node]) -> void:
	if _editor_interface == null:
		return

	var selection: EditorSelection = _editor_interface.get_selection()
	if selection == null:
		return

	selection.clear()
	for node: Node in nodes:
		if is_instance_valid(node):
			selection.add_node(node)
