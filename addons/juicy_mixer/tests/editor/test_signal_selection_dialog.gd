## 信号选择对话框测试脚本
@tool
extends Control

## UI 引用
@onready var result_label: Label = $Panel/VBoxContainer/ResultLabel

## 测试信号数据
var _test_signal_data: Dictionary = {}

func _ready() -> void:
	# 准备测试数据
	_prepare_test_data()

	# 连接按钮信号
	$Panel/VBoxContainer/ButtonContainer/TestEmptyDialog.pressed.connect(_on_test_empty_dialog)
	$Panel/VBoxContainer/ButtonContainer/TestWithSignals.pressed.connect(_on_test_with_signals)

## 准备测试数据
func _prepare_test_data() -> void:
	_test_signal_data = {
		"Button": [
			{
				"name": "pressed",
				"source_class": "Button",
				"args": []
			},
			{
				"name": "button_up",
				"source_class": "Button",
				"args": []
			},
			{
				"name": "button_down",
				"source_class": "Button",
				"args": []
			}
		],
		"Control": [
			{
				"name": "resized",
				"source_class": "Control",
				"args": []
			},
			{
				"name": "focus_entered",
				"source_class": "Control",
				"args": []
			},
			{
				"name": "mouse_entered",
				"source_class": "Control",
				"args": []
			},
			{
				"name": "gui_input",
				"source_class": "Control",
				"args": [{"name": "event", "type": TYPE_OBJECT}]
			}
		],
		"Node": [
			{
				"name": "ready",
				"source_class": "Node",
				"args": []
			},
			{
				"name": "tree_entered",
				"source_class": "Node",
				"args": []
			},
			{
				"name": "renamed",
				"source_class": "Node",
				"args": []
			}
		],
		"Area2D": [
			{
				"name": "area_entered",
				"source_class": "Area2D",
				"args": [{"name": "area", "type": TYPE_OBJECT}]
			},
			{
				"name": "area_exited",
				"source_class": "Area2D",
				"args": [{"name": "area", "type": TYPE_OBJECT}]
			},
			{
				"name": "body_shape_entered",
				"source_class": "Area2D",
				"args": [
					{"name": "body_rid", "type": TYPE_INT},
					{"name": "body", "type": TYPE_OBJECT},
					{"name": "body_shape_index", "type": TYPE_INT},
					{"name": "local_shape_index", "type": TYPE_INT}
				]
			}
		]
	}

## 测试空列表对话框
func _on_test_empty_dialog() -> void:
	print("[Test] 测试空信号列表...")

	var dialog = SignalSelectionDialog.new()
	dialog.set_signals({}, "EmptyNode")

	dialog.confirmed.connect(func():
		var selected = dialog.get_selected_signals()
		_update_result("空列表测试 - 选择了 %d 个信号" % selected.size())
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		_update_result("空列表测试 - 用户取消")
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()

## 测试有信号的对话框
func _on_test_with_signals() -> void:
	print("[Test] 测试有信号列表...")

	var dialog = SignalSelectionDialog.new()
	dialog.set_signals(_test_signal_data, "Button")

	dialog.confirmed.connect(func():
		var selected = dialog.get_selected_signals()
		print("[Test] 用户选择了 %d 个信号:" % selected.size())
		for signal_info in selected:
			print("  - %s.%s" % ["TestNode", signal_info.name])

		_update_result("信号测试 - 选择了 %d 个信号" % selected.size())
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		_update_result("信号测试 - 用户取消")
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()

## 更新结果标签
func _update_result(text: String) -> void:
	result_label.text = "结果：%s" % text
	print("[Test] %s" % text)
