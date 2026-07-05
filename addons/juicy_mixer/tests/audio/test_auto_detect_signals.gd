@tool
extends Node

## 自动检测信号功能测试场景
##
## 完整测试端到端自动检测信号流程
##
## 使用方法:
## 1. 在编辑器中打开此场景
## 2. 选中的 AudioComponent 资源
## 3. 点击 Inspector 中的"🔍 自动检测信号"按钮
## 4. 在弹出的对话框中选择信号
## 5. 验证 AudioBinding 是否正确创建

func _ready():
	print("=== 自动检测信号功能测试 ===")
	print("\n此场景用于测试完整的自动检测信号流程")
	print("\n场景结构:")
	print("├─ TestAutoDetectSignals (根节点)")
	print("│  ├─ Player (Node2D - 包含自定义信号)")
	print("│  │  ├─ health_changed(new_health: float)")
	print("│  │  ├─ died()")
	print("│  │  ├─ jumped()")
	print("│  │  ├─ powerup_collected(powerup_type: String)")
	print("│  │  ├─ level_completed(level: int)")
	print("│  │  └─ checkpoint_reached(checkpoint_id: int)")
	print("│  │  └─ JuicyAudioPlayer (target = Player)")
	print("│  └─ AudioComponent (资源)")
	print("\n测试步骤:")
	print("1. 在 FileSystem dock 中双击打开 AudioComponent 资源")
	print("2. 在 Inspector 中点击 '🔍 自动检测信号' 按钮")
	print("3. 验证是否显示信号选择对话框")
	print("4. 尝试搜索功能（输入 'health'）")
	print("5. 勾选几个信号并点击确定")
	print("6. 验证是否在 AudioComponent 中创建了对应的 AudioBinding")
	print("\n预期结果:")
	print("- 对话框应该显示 6 个自定义信号")
	print("- 信号应该按 class 分组显示")
	print("- 搜索功能应该正常工作")
	print("- 确定后应该创建 AudioBinding")
	print("- AudioBinding 的 signal_name 应该正确设置")
	print("- AudioBinding 应该包含占位符 AudioEvent")

	# 自动创建并选中测试资源
	await get_tree().process_frame
	_setup_test_component()

func _setup_test_component():
	## 设置测试资源并选中

	# 查找场景中的 AudioComponent
	var player = get_node_or_null("Player")
	if not player:
		print("❌ 未找到 Player 节点")
		return

	var audio_player = player.get_node_or_null("JuicyAudioPlayer")
	if not audio_player:
		print("❌ 未找到 JuicyAudioPlayer 节点")
		return

	# 获取 AudioComponent 资源
	var test_component = audio_player.audio_component
	if not test_component:
		print("❌ JuicyAudioPlayer 没有 AudioComponent")
		return

	print("\n✓ 测试资源已找到")
	print("  Player: ", player.name)
	print("  JuicyAudioPlayer: ", audio_player.name)
	print("  AudioComponent: ", test_component.resource_name)
	print("\n✓ 在 Inspector 中查看 AudioComponent 资源")
	print("  点击 '🔍 自动检测信号' 按钮开始测试")

	# 在编辑器中选中和显示资源
	if Engine.is_editor_hint():
		if EditorInterface:
			EditorInterface.inspect_object(test_component)
			print("✓ AudioComponent 已在 Inspector 中显示")
		else:
			print("⚠ 警告: 无法获取 EditorInterface")
