@tool
extends EditorInspectorPlugin
class_name JuicyAudioPlayerInspector

## JuicyAudioPlayer 自定义检查器插件
##
## 为 JuicyAudioPlayer 节点提供自定义检查器 UI，包含：
## - 状态面板（父节点名称、绑定数量）
## - 测试按钮（打印所有绑定信息）

# =============================================================================
# EditorInspectorPlugin 重写方法
# =============================================================================

func _can_handle(object: Object) -> bool:
	## 检查是否可以处理此对象
	## @param object: 要检查的对象
	## @return: 如果对象是 JuicyAudioPlayer 返回 true，否则返回 false

	if object is JuicyAudioPlayer:
		return true
	return false


func _parse_begin(object: Object) -> void:
	## 开始解析对象，添加自定义控件
	## @param object: 要解析的对象（应为 JuicyAudioPlayer）

	# 类型转换
	var player: JuicyAudioPlayer = object

	# 创建状态面板
	var status_panel := _create_status_panel(player)

	# 添加到检查器
	add_custom_control(status_panel)


# =============================================================================
# UI 创建方法
# =============================================================================

func _create_status_panel(player: JuicyAudioPlayer) -> Control:
	## 创建状态面板
	## @param player: JuicyAudioPlayer 实例
	## @return: 包含状态信息的 PanelContainer

	# 创建面板容器
	var panel := PanelContainer.new()

	# 创建垂直布局容器
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	# 添加父节点标签
	var parent_label := Label.new()
	var parent_node := player.get_parent()
	parent_label.text = "父节点: %s" % (parent_node.name if parent_node else "无")
	parent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(parent_label)

	# 添加目标节点标签（新增）
	var target_label := Label.new()
	if player.target:
		target_label.text = "目标节点: %s (显式指定)" % player.target.name
	elif parent_node:
		target_label.text = "目标节点: %s (默认父节点)" % parent_node.name
	else:
		target_label.text = "目标节点: 未设置"
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(target_label)

	# 添加绑定数量标签
	var binding_label := Label.new()
	var binding_count := 0
	if player.audio_component:
		binding_count = player.audio_component.get_binding_count()
	binding_label.text = "绑定数量: %d" % binding_count
	binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(binding_label)

	# 按钮容器（新增）
	var button_hbox := HBoxContainer.new()
	vbox.add_child(button_hbox)

	# 添加"设置为父节点"按钮（新增）
	var set_parent_button := Button.new()
	set_parent_button.text = "🔄 设置为父节点"
	set_parent_button.tooltip_text = "将父节点设置为 target"
	set_parent_button.pressed.connect(_on_set_parent_as_target.bind(player))
	button_hbox.add_child(set_parent_button)

	# 添加测试按钮
	var test_button := Button.new()
	test_button.text = "🧪 测试所有绑定"
	test_button.tooltip_text = "打印所有绑定的详细信息"
	test_button.pressed.connect(_on_test_all.bind(player))
	button_hbox.add_child(test_button)

	return panel


# =============================================================================
# 按钮回调方法
# =============================================================================

func _on_test_all(player: JuicyAudioPlayer) -> void:
	## 处理"测试所有绑定"按钮点击事件
	## @param player: JuicyAudioPlayer 实例

	# 检查是否有 audio_component
	if not player.audio_component:
		push_warning("JuicyAudioPlayer: 没有分配 AudioComponent")
		return

	# 打印测试信息头部
	print("\n=== JuicyAudioPlayer Test ===")

	# 打印父节点信息
	var parent_node := player.get_parent()
	print("Parent: %s" % (parent_node.name if parent_node else "无"))

	# 打印绑定数量
	var binding_count := player.audio_component.get_binding_count()
	print("Bindings: %d" % binding_count)

	# 循环打印每个绑定
	for i in range(binding_count):
		var binding: AudioBinding = player.audio_component.audio_bindings[i]

		# 处理绑定可能为 null 的情况
		if not binding:
			print("  [%d] null" % i)
			continue

		var signal_name := binding.signal_name if binding.signal_name else "null"
		var event_name := "null"
		if binding.audio_event:
			event_name = binding.audio_event.event_name if binding.audio_event.event_name else "null"

		print("  [%d] Signal: %s, Event: %s" % [i, signal_name, event_name])

	# 打印测试信息尾部
	print("============================\n")


func _on_set_parent_as_target(player: JuicyAudioPlayer) -> void:
	## 处理"设置为父节点"按钮点击
	## @param player: 目标 JuicyAudioPlayer 实例

	var parent_node := player.get_parent()
	if not parent_node:
		push_warning("JuicyAudioPlayer 没有父节点")
		return

	player.target = parent_node
	print("[JuicyAudioPlayerInspector] Target 已设置为父节点: ", parent_node.name)

	# 刷新 Inspector 显示
	notify_property_list_changed()
