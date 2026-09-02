@tool
@icon("res://addons/fuse/icons/builtin/ItemList.png")
extends BaseEvent
class_name OnItemSelected

## Event: OnItemSelected
##
## 迁移到 RuntimeInstance: 2026-02-03
## 状态变量:
## - _selected_indices: Array (当前选中的索引数组)
##
## 架构版本: 自声明状态模式 v2.0
## 相关文档: addons/fuse/docs/zh_CN/dev_docs/guides/runtime-instance-migration-guide.md
##
## ItemList 选中项改变事件
##
## 当 ItemList 控件的选中项改变时触发，支持单选和多选模式

## 目标 ItemList 节点路径
@export var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_resource_name()

## 是否启用多选模式
@export var multi_select_mode: bool = false:
	set(value):
		multi_select_mode = value
		_update_resource_name()

## 是否传递选中的索引数组
@export var emit_indices: bool = true

## 是否传递选中的项数
@export var emit_count: bool = true

var _itemlist_ref: ItemList = null
var _optionbutton_ref: OptionButton = null

## 获取默认运行时状态
func get_default_runtime_state() -> Dictionary:
	var base = super.get_default_runtime_state()
	base["selected_indices"] = []
	return base

## 更新资源名称（必需）
func _update_resource_name():
	var mode_key = "FUSE_DESC_MULTI_SELECT" if multi_select_mode else "FUSE_DESC_SINGLE_SELECT"
	var mode_text = FuseLocalization.translate(mode_key)
	resource_name = FuseLocalization.translate_format("FUSE_EVENT_ON_ITEM_SELECTED_RESOURCE_NAME", {
		"path": _get_node_display_name(target_node_path),
		"mode": mode_text
	})

## 使用 RuntimeInstance 初始化（必需）
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
	if Engine.is_editor_hint():
		return

	_runtime_instance_ref = runtime_instance

	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点并按类型分流（OptionButton 单选 / ItemList 单/多选）
	var node = owner_node.get_node_or_null(target_node_path)
	if not node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return
	if not _connect_target(node):
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 按控件类型连接信号；返回是否为受支持类型
func _connect_target(node: Node) -> bool:
	if node is OptionButton:
		_optionbutton_ref = node
		if not _optionbutton_ref.item_selected.is_connected(_on_item_selected):
			_optionbutton_ref.item_selected.connect(_on_item_selected)
		return true
	if node is ItemList:
		_itemlist_ref = node
		# 设置多选模式
		_itemlist_ref.select_mode = ItemList.SELECT_MULTI if multi_select_mode else ItemList.SELECT_SINGLE

		# 连接信号
		if not _itemlist_ref.item_selected.is_connected(_on_item_selected):
			_itemlist_ref.item_selected.connect(_on_item_selected)

		if not _itemlist_ref.multi_selected.is_connected(_on_multi_selected):
			_itemlist_ref.multi_selected.connect(_on_multi_selected)

		if not _itemlist_ref.nothing_selected.is_connected(_on_nothing_selected):
			_itemlist_ref.nothing_selected.connect(_on_nothing_selected)
		return true
	return false

## 初始化事件监听（必需）- 保留向后兼容
func initialize(owner_node: Node) -> void:
	# 验证 owner_node
	if not owner_node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NULL", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 验证目标节点路径
	if target_node_path.is_empty():
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.CONFIGURATION_ERROR, {})
		return

	# 获取目标节点并按类型分流（OptionButton 单选 / ItemList 单/多选）
	var node = owner_node.get_node_or_null(target_node_path)
	if not node:
		_create_fuse_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return
	if not _connect_target(node):
		_create_fuse_error_localized("FUSE_ERROR_INVALID_TARGET", FuseError.ErrorType.CONFIGURATION_ERROR, {"node_path": str(target_node_path)})
		return

	_log_debug_localized("FUSE_LOG_EVENT_INITIALIZED", {"event_type": get_event_type()})

## 清理事件监听（必需）
func terminate(owner_node: Node) -> void:
	# 清理 RuntimeEventInstance 状态
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("selected_indices", [])

	# 断开信号连接
	if _itemlist_ref and is_instance_valid(_itemlist_ref):
		if _itemlist_ref.item_selected.is_connected(_on_item_selected):
			_itemlist_ref.item_selected.disconnect(_on_item_selected)

		if _itemlist_ref.multi_selected.is_connected(_on_multi_selected):
			_itemlist_ref.multi_selected.disconnect(_on_multi_selected)

		if _itemlist_ref.nothing_selected.is_connected(_on_nothing_selected):
			_itemlist_ref.nothing_selected.disconnect(_on_nothing_selected)

	if _optionbutton_ref and is_instance_valid(_optionbutton_ref):
		if _optionbutton_ref.item_selected.is_connected(_on_item_selected):
			_optionbutton_ref.item_selected.disconnect(_on_item_selected)

	# 清理引用
	_itemlist_ref = null
	_optionbutton_ref = null

	_log_debug_localized("FUSE_LOG_EVENT_TERMINATED", {"event_type": get_event_type()})

## 单选项选中回调
func _on_item_selected(index: int):
	var selected_indices = []
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("selected_indices"):
		selected_indices = _runtime_instance_ref.get_runtime_state("selected_indices")

	selected_indices = [index]
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("selected_indices", selected_indices)

	var count_text = ""
	if emit_count:
		count_text = ", 选中项数: 1"

	_log_info_localized("FUSE_LOG_EVENT_ITEM_SELECTED", {
		"index": str(index),
		"mode": "单选",
		"count_text": count_text
	})

	# 创建上下文节点传递事件信息
	var context_node = Node.new()
	context_node.name = "ItemSelectedContext"

	if emit_indices:
		context_node.set_meta("selected_indices", selected_indices)

	if emit_count:
		context_node.set_meta("selected_count", 1)

	context_node.set_meta("itemlist_node", _optionbutton_ref if _optionbutton_ref else _itemlist_ref)
	context_node.set_meta("is_multi_select", false)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 多选项选中回调
func _on_multi_selected(index: int, selected: bool):
	var selected_indices = []
	if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("selected_indices"):
		selected_indices = _runtime_instance_ref.get_runtime_state("selected_indices")

	# 更新选中的索引列表
	if selected:
		if not (selected_indices.has(index)):
			selected_indices.append(index)
	else:
		selected_indices.erase(index)

	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("selected_indices", selected_indices)

	var count_text = ""
	if emit_count:
		count_text = ", 选中项数: %d" % selected_indices.size()

	_log_info_localized("FUSE_LOG_EVENT_ITEM_SELECTED", {
		"index": str(index),
		"mode": "多选",
		"count_text": count_text
	})

	# 创建上下文节点传递事件信息
	var context_node = Node.new()
	context_node.name = "ItemSelectedContext"

	if emit_indices:
		context_node.set_meta("selected_indices", selected_indices.duplicate())

	if emit_count:
		context_node.set_meta("selected_count", selected_indices.size)

	context_node.set_meta("itemlist_node", _optionbutton_ref if _optionbutton_ref else _itemlist_ref)
	context_node.set_meta("is_multi_select", true)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 取消所有选中回调
func _on_nothing_selected():
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("selected_indices", [])

	_log_info_localized("FUSE_LOG_EVENT_ITEM_DESELECTED", {"mode": "多选" if multi_select_mode else "单选"})

	# 创建上下文节点传递事件信息
	var context_node = Node.new()
	context_node.name = "ItemSelectedContext"

	if emit_indices:
		context_node.set_meta("selected_indices", [])

	if emit_count:
		context_node.set_meta("selected_count", 0)

	context_node.set_meta("itemlist_node", _optionbutton_ref if _optionbutton_ref else _itemlist_ref)
	context_node.set_meta("is_multi_select", multi_select_mode)

	triggered.emit(context_node)

	# 清理上下文节点
	context_node.queue_free()

## 获取事件描述
func get_description() -> String:
	var itemlist_name = target_node_path if not target_node_path.is_empty() else FuseLocalization.translate("FUSE_TEXT_NOT_SPECIFIED")
	var mode_key = "FUSE_DESC_MULTI_SELECT_MODE" if multi_select_mode else "FUSE_DESC_SINGLE_SELECT_MODE"
	var mode_text = FuseLocalization.translate(mode_key)
	return FuseLocalization.translate_format("FUSE_EVENT_ON_ITEM_SELECTED_DESC", {
		"itemlist": itemlist_name,
		"mode": mode_text
	})

## 获取事件类型
func get_event_type() -> String:
	return "item_selected"

## 获取事件分类
func get_event_category() -> String:
	return "ui"

## 验证事件配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if target_node_path.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY"))

	return errors

## 重置事件状态
func reset() -> void:
	super.reset()
	if _runtime_instance_ref:
		_runtime_instance_ref.set_runtime_state("selected_indices", [])
	_log_debug_localized("FUSE_LOG_EVENT_RESET", {"event_type": get_event_type()})

## 获取事件元数据
static func _get_event_metadata() -> EventMetadata:
	var metadata = EventMetadata.new()
	metadata.name_key = "FUSE_EVENT_ON_ITEM_SELECTED_NAME"
	metadata.category_key = "FUSE_EVENT_CATEGORY_UI"
	metadata.description_key = "FUSE_EVENT_ON_ITEM_SELECTED_DESC"
	metadata.keywords = ["itemlist", "选中", "选择", "item", "list", "select", "ui", "interface"]
	metadata.builtin_icon = "ItemList"
	return metadata
