@tool
extends EditorInspectorPlugin
class_name AudioComponentInspector

## AudioComponent 自定义检查器插件
##
## 为 AudioComponent 资源提供自定义检查器 UI，包含：
## - 快速添加绑定按钮
## - 自动检测信号按钮（完整实现）

# =============================================================================
# EditorInspectorPlugin 重写方法
# =============================================================================

func _can_handle(object: Object) -> bool:
	## 检查是否可以处理此对象
	## @param object: 要检查的对象
	## @return: 如果对象是 AudioComponent 返回 true，否则返回 false

	if object is AudioComponent:
		return true
	return false


func _parse_begin(object: Object) -> void:
	## 开始解析对象，添加自定义控件
	## @param object: 要解析的对象（应为 AudioComponent）

	# 类型转换和验证
	var component: AudioComponent = object
	if not component:
		return

	# 创建按钮容器
	var button_hbox := HBoxContainer.new()
	add_custom_control(button_hbox)

	# 创建"快速添加"按钮
	var add_button := Button.new()
	add_button.text = "+ 快速添加"
	add_button.tooltip_text = "添加新的信号绑定"
	add_button.pressed.connect(_on_add_binding.bind(component))
	button_hbox.add_child(add_button)

	# 创建"自动检测信号"按钮
	var detect_button := Button.new()
	detect_button.text = "🔍 自动检测信号"
	detect_button.tooltip_text = "从父节点脚本检测所有信号"
	detect_button.pressed.connect(_on_auto_detect_signals.bind(component))
	button_hbox.add_child(detect_button)

	# 添加分隔线以增强视觉分离
	var separator := HSeparator.new()
	add_custom_control(separator)


# =============================================================================
# 按钮回调方法
# =============================================================================

func _on_add_binding(component: AudioComponent) -> void:
	## 处理"快速添加"按钮点击事件
	## @param component: 目标 AudioComponent

	# 创建新的 AudioBinding 实例
	var new_binding := AudioBinding.new()

	# 添加到组件的绑定列表
	component.audio_bindings.append(new_binding)

	# 通知属性列表已更改，触发检查器刷新
	component.notify_property_list_changed()

	# 打印成功消息
	print("[AudioComponentInspector] Added new binding")


func _on_auto_detect_signals(component: AudioComponent) -> void:
	## 处理"自动检测信号"按钮点击事件
	## @param component: 目标 AudioComponent

	print("[AudioComponentInspector] 自动检测信号按钮被点击")

	# 1. 获取目标节点
	var target_node = _get_target_node_for_detection(component)
	print("[AudioComponentInspector] 目标节点: ", target_node.name if target_node else "null")

	if not target_node:
		_show_warning_dialog(
			"未设置目标节点",
			"请先设置目标节点：\n\n1. 在 JuicyAudioPlayer 中设置 target 属性\n2. 或在 AudioComponent 中设置 target_path 属性"
		)
		return

	# 2. 检测信号
	var custom_signals = SignalDetector.detect_custom_signals(target_node)

	if custom_signals.is_empty():
		_show_info_dialog(
			"未找到信号",
			"节点 '%s' 没有可绑定的信号。\n\n提示：内置信号（如 ready, tree_entered）会被自动过滤。" % target_node.name
		)
		return

	# 3. 按 class 分组
	var grouped = SignalDetector.group_signals_by_class(custom_signals)

	# 4. 显示选择对话框
	var dialog = SignalSelectionDialog.new()
	EditorInterface.get_base_control().add_child(dialog)
	dialog.set_signals(grouped, target_node.name)
	dialog.popup_centered()

	print("[AudioComponentInspector] 等待用户确认...")

	# 等待用户确认或关闭对话框
	# 使用 timeout 信号来检测对话框被关闭（没有点击确认）
	var dialog_closed := false

	# 当对话框隐藏时，标记为已关闭
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			dialog_closed = true
	)

	var user_confirmed := false

	# 等待对话框关闭
	while not dialog_closed and dialog.visible:
		await Engine.get_main_loop().process_frame

	# 如果对话框还在可见状态但用户点击了确认，confirmed 会触发
	# 我们通过检查对话框是否仍然存在且可见来判断
	# 实际上，用户点击确认后，confirmed 会触发，对话框会隐藏

	# 等待一帧以确保 confirmed 信号处理完成
	await Engine.get_main_loop().process_frame

	# 检查用户是否确认了（通过检查选中的信号数量）
	if is_instance_valid(dialog):
		var selected_count = dialog.get_selected_signals().size()
		user_confirmed = selected_count > 0 and dialog.visible == false
		print("[AudioComponentInspector] 对话框已关闭，user_confirmed = ", user_confirmed, "，选中数量 = ", selected_count)
	else:
		print("[AudioComponentInspector] 对话框已被释放")
		user_confirmed = false

	# 如果用户确认了，创建绑定
	if user_confirmed:
		print("[AudioComponentInspector] 用户确认了选择")
		var selected = dialog.get_selected_signals()
		print("[AudioComponentInspector] 选中的信号数量: ", selected.size())
		_create_bindings_for_signals(component, selected)
	else:
		print("[AudioComponentInspector] 用户取消了选择或关闭了对话框")

	# 手动释放对话框
	if is_instance_valid(dialog):
		dialog.queue_free()

## 获取用于检测的目标节点
func _get_target_node_for_detection(component: AudioComponent) -> Node:
	# 尝试从 JuicyAudioPlayer 获取 target
	var player = _find_audio_player()
	print("[AudioComponentInspector] 找到的 player: ", player.name if player else "null")

	if player and player.target:
		print("[AudioComponentInspector] 使用 player.target: ", player.target.name)
		return player.target

	# 尝试从 AudioComponent 的 target_path 获取
	print("[AudioComponentInspector] component.target_path: ", component.target_path)
	if not component.target_path.is_empty():
		var edited_root = EditorInterface.get_edited_scene_root()
		if edited_root:
			var target = component.get_target_node(edited_root)
			print("[AudioComponentInspector] 从 target_path 解析: ", target.name if target else "null")
			return target

	# 回退到父节点（如果找到 JuicyAudioPlayer）
	if player:
		var parent = player.get_parent()
		print("[AudioComponentInspector] 回退到 player.get_parent(): ", parent.name if parent else "null")
		return parent

	print("[AudioComponentInspector] 无法找到任何目标节点")
	return null

## 查找当前场景中的 JuicyAudioPlayer
func _find_audio_player() -> JuicyAudioPlayer:
	var edited_root = EditorInterface.get_edited_scene_root()
	if not edited_root:
		return null

	var players = edited_root.find_children("*", "JuicyAudioPlayer", true, false)
	if players.size() > 0:
		return players[0]

	return null

## 为信号创建绑定
func _create_bindings_for_signals(component: AudioComponent, signals: Array) -> void:
	var created_count = 0
	var skipped_count = 0

	for signal_info in signals:
		var signal_name = signal_info.name

		# 检查是否已存在
		var existing = component.find_binding_by_signal(signal_name)
		if existing:
			skipped_count += 1
			continue

		# 创建新绑定
		var binding = AudioBinding.new()
		binding.signal_name = signal_name

		# 创建占位符 AudioEvent
		var audio_event = AudioEventResource.new()
		audio_event.event_name = signal_name
		binding.audio_event = audio_event

		component.audio_bindings.append(binding)
		created_count += 1

	# 刷新 Inspector
	component.notify_property_list_changed()

	# 显示结果
	var message = "成功创建 %d 个绑定" % created_count
	if skipped_count > 0:
		message += "\n跳过 %d 个已存在的绑定" % skipped_count

	_show_info_dialog("完成", message)

	print("[AudioComponentInspector] 自动创建绑定: %d 个创建, %d 个跳过" % [created_count, skipped_count])

## 显示警告对话框
func _show_warning_dialog(title: String, message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.size = Vector2i(400, 150)
	dialog.unresizable = true

	var label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.add_child(label)

	EditorInterface.get_base_control().add_child(dialog)
	var confirmed = await dialog.confirmed
	if is_instance_valid(dialog):
		dialog.queue_free()

## 显示信息对话框
func _show_info_dialog(title: String, message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.size = Vector2i(400, 150)
	dialog.unresizable = true

	var label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.add_child(label)

	EditorInterface.get_base_control().add_child(dialog)
	var confirmed = await dialog.confirmed
	if is_instance_valid(dialog):
		dialog.queue_free()
