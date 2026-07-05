# 文件：addons/fuse/editor/context_menu/trigger_merger.gd
@tool
class_name TriggerMerger extends RefCounted

## TriggerMerger - Trigger 合并工具类
##
## 用于将多个 Trigger 节点合并为一个 MultiEventTrigger 节点。
## 支持 UndoRedo 操作，确保用户可以撤销合并。

## ==================== 常量 ====================

const MultiEventTriggerClass = preload("res://addons/fuse/core/multi_event_trigger.gd")
const EventBindingClass = preload("res://addons/fuse/core/event_binding.gd")
const FuseLocalizationClass = preload("res://addons/fuse/localization/fuse_localization.gd")

## ==================== 成员变量 ====================

var _editor_interface: EditorInterface
var _undo_redo: EditorUndoRedoManager

## ==================== 初始化 ====================

## 构造函数
## @param editor_interface 编辑器接口
## @param undo_redo UndoRedo 管理器
func _init(editor_interface: EditorInterface, undo_redo: EditorUndoRedoManager) -> void:
	_editor_interface = editor_interface
	_undo_redo = undo_redo

## ==================== 静态检查方法 ====================

## 检查是否可以合并指定的节点列表
## @param nodes 要检查的节点数组
## @return 是否可以合并
static func can_merge(nodes: Array[Node]) -> bool:
	# 检查节点数量：至少需要 2 个节点
	if nodes.size() < 2:
		return false

	# 检查是否所有节点都是 Trigger 类型
	for node: Node in nodes:
		if not node is Trigger:
			return false

	# 检查是否所有节点有相同的父节点
	var parent: Node = nodes[0].get_parent()
	if parent == null:
		return false

	for node: Node in nodes:
		if node.get_parent() != parent:
			return false

	return true

## ==================== 合并操作 ====================

## 执行合并操作
## @param nodes 要合并的 Trigger 节点数组
func merge(nodes: Array[Node]) -> void:
	# 预检查
	if not can_merge(nodes):
		push_error("TriggerMerger: 无法合并节点，检查失败")
		return

	# 按场景树索引排序（保持原始顺序）
	var sorted_nodes: Array[Node] = _sort_by_index(nodes)

	# 获取父节点和第一个节点的索引
	var parent: Node = sorted_nodes[0].get_parent()
	var first_index: int = sorted_nodes[0].get_index()

	# 创建 MultiEventTrigger 节点
	var multi_trigger: MultiEventTrigger = MultiEventTriggerClass.new()
	multi_trigger.name = "MultiEventTrigger"

	# 创建备份数据（用于 Undo）
	var backup: Array[Dictionary] = _create_backup(sorted_nodes)

	# 创建 EventBinding 数组
	var bindings: Array[EventBinding] = []
	for node: Node in sorted_nodes:
		var trigger: Trigger = node as Trigger
		var binding: EventBinding = _create_binding_from_trigger(trigger)
		bindings.append(binding)

	# 验证复制结果
	var validation_errors: Array[String] = _validate_bindings(sorted_nodes, bindings)
	if not validation_errors.is_empty():
		push_error("[TriggerMerger] %s" % FuseLocalizationClass.translate("FUSE_MERGE_VALIDATION_FAILED"))
		for error in validation_errors:
			push_error("  - ", error)
		return

	print("[TriggerMerger] %s" % FuseLocalizationClass.translate_format("FUSE_MERGE_VALIDATION_PASSED", {"count": sorted_nodes.size()}))

	multi_trigger.event_bindings = bindings

	# 添加 UndoRedo 操作
	_undo_redo.create_action("合并 Trigger 节点")

	# Do 操作
	_undo_redo.add_do_method(self, "_do_merge", parent, multi_trigger, sorted_nodes, first_index)

	# Undo 操作
	_undo_redo.add_undo_method(self, "_undo_merge", parent, multi_trigger, backup)

	# 提交操作
	_undo_redo.commit_action()

	# 选中新创建的 MultiEventTrigger
	_select_node(multi_trigger)

	print("[TriggerMerger] %s" % FuseLocalizationClass.translate("FUSE_MERGE_COMPLETED"))

## ==================== 私有辅助方法 ====================

## 按场景树索引排序节点
## @param nodes 要排序的节点数组
## @return 排序后的节点数组
func _sort_by_index(nodes: Array[Node]) -> Array[Node]:
	var sorted: Array[Node] = []
	sorted.append_array(nodes)

	# 按索引升序排序
	sorted.sort_custom(func(a: Node, b: Node) -> bool:
		return a.get_index() < b.get_index()
	)

	return sorted

## 从 Trigger 创建 EventBinding
## @param trigger 源 Trigger 节点
## @return 创建的 EventBinding
func _create_binding_from_trigger(trigger: Trigger) -> EventBinding:
	var binding: EventBinding = EventBindingClass.new()

	# 深拷贝事件定义
	if trigger.event_definition != null:
		binding.event = trigger.event_definition.duplicate(true)

	# 深拷贝 ActionRunner
	if trigger.action_runner != null:
		binding.action_runner = trigger.action_runner.duplicate(true)

	# 复制其他属性
	binding.trigger_once = trigger.trigger_once
	binding.cooldown_mode = trigger.cooldown_mode
	binding.cooldown_time = trigger.cooldown_time
	binding.enabled = true

	return binding

## 验证 EventBinding 数据完整性
## @param triggers 原始 Trigger 节点数组
## @param bindings 创建的 EventBinding 数组
## @return 错误信息数组（为空表示验证通过）
func _validate_bindings(triggers: Array[Node], bindings: Array[EventBinding]) -> Array[String]:
	var errors: Array[String] = []

	for i in range(triggers.size()):
		var trigger: Trigger = triggers[i] as Trigger
		var binding: EventBinding = bindings[i]

		# 验证 event_definition
		if trigger.event_definition != null and binding.event == null:
			errors.append(FuseLocalizationClass.translate_format("FUSE_MERGE_ERROR_EVENT_COPY_FAILED", {"name": trigger.name}))

		# 验证 action_runner
		if trigger.action_runner != null and binding.action_runner == null:
			errors.append(FuseLocalizationClass.translate_format("FUSE_MERGE_ERROR_ACTION_RUNNER_COPY_FAILED", {"name": trigger.name}))

		# 验证简单属性
		if trigger.trigger_once != binding.trigger_once:
			errors.append(FuseLocalizationClass.translate_format("FUSE_MERGE_ERROR_TRIGGER_ONCE_MISMATCH", {"name": trigger.name, "original": trigger.trigger_once, "copy": binding.trigger_once}))

		if trigger.cooldown_mode != binding.cooldown_mode:
			errors.append(FuseLocalizationClass.translate_format("FUSE_MERGE_ERROR_COOLDOWN_MODE_MISMATCH", {"name": trigger.name, "original": trigger.cooldown_mode, "copy": binding.cooldown_mode}))

		if not is_equal_approx(trigger.cooldown_time, binding.cooldown_time):
			errors.append(FuseLocalizationClass.translate_format("FUSE_MERGE_ERROR_COOLDOWN_TIME_MISMATCH", {"name": trigger.name, "original": trigger.cooldown_time, "copy": binding.cooldown_time}))

	return errors

## 创建备份数据（用于 Undo）
## @param triggers Trigger 节点数组
## @return 备份数据数组
func _create_backup(triggers: Array[Node]) -> Array[Dictionary]:
	var backup: Array[Dictionary] = []

	for trigger_node: Node in triggers:
		var trigger: Trigger = trigger_node as Trigger

		# 预先计算深拷贝（避免在字典内使用三元运算符）
		var event_def_copy = null
		if trigger.event_definition != null:
			event_def_copy = trigger.event_definition.duplicate(true)

		var action_runner_copy = null
		if trigger.action_runner != null:
			action_runner_copy = trigger.action_runner.duplicate(true)

		var data: Dictionary = {
			"index": trigger_node.get_index(),
			"event_definition": event_def_copy,
			"action_runner": action_runner_copy,
			"trigger_once": trigger.trigger_once,
			"cooldown_mode": trigger.cooldown_mode,
			"cooldown_time": trigger.cooldown_time,
			"name": trigger_node.name
		}
		backup.append(data)

	return backup

## Do 操作：执行合并
## @param parent 父节点
## @param multi_trigger 新创建的 MultiEventTrigger
## @param triggers 要删除的 Trigger 节点数组
## @param first_index 第一个 Trigger 的原始索引
func _do_merge(parent: Node, multi_trigger: MultiEventTrigger, triggers: Array[Node], first_index: int) -> void:
	# 添加 MultiEventTrigger 到父节点
	parent.add_child(multi_trigger)
	multi_trigger.owner = parent.owner

	# 移动到正确位置
	parent.move_child(multi_trigger, first_index)

	# 删除所有 Trigger 节点
	for trigger: Node in triggers:
		trigger.get_parent().remove_child(trigger)
		trigger.queue_free()

## Undo 操作：撤销合并
## @param parent 父节点
## @param multi_trigger 要删除的 MultiEventTrigger
## @param backup 备份数据
func _undo_merge(parent: Node, multi_trigger: MultiEventTrigger, backup: Array[Dictionary]) -> void:
	# 恢复所有 Trigger 节点（创建新节点）
	for data: Dictionary in backup:
		var trigger := Trigger.new()
		trigger.name = data.name

		# 恢复属性
		trigger.event_definition = data.event_definition
		trigger.action_runner = data.action_runner
		trigger.trigger_once = data.trigger_once
		trigger.cooldown_mode = data.cooldown_mode
		trigger.cooldown_time = data.cooldown_time

		# 添加回父节点
		parent.add_child(trigger)
		trigger.owner = parent.owner

		# 移动到原始位置
		parent.move_child(trigger, data.index)

	# 删除 MultiEventTrigger
	if is_instance_valid(multi_trigger):
		multi_trigger.get_parent().remove_child(multi_trigger)
		multi_trigger.queue_free()

## 选中新节点
## @param node 要选中的节点
func _select_node(node: Node) -> void:
	if _editor_interface == null:
		return

	var selection: EditorSelection = _editor_interface.get_selection()
	if selection == null:
		return

	selection.clear()
	selection.add_node(node)
