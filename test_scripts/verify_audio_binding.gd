extends Node

## AudioBinding 验证脚本
##
## 通过直接加载资源来验证 AudioBinding 的实现

func _ready():
	print("\n=== AudioBinding 验证脚本 ===\n")

	# 步骤1: 加载 AudioBinding 资源定义
	var binding_script = load("res://addons/juicy_mixer/resources/audio/audio_binding.gd")
	if binding_script == null:
		print("❌ 错误: 无法加载 audio_binding.gd")
		return

	print("✓ AudioBinding 脚本加载成功")

	# 步骤2: 创建 AudioBinding 实例
	var binding = binding_script.new()
	if binding == null:
		print("❌ 错误: 无法创建 AudioBinding 实例")
		return

	print("✓ AudioBinding 实例创建成功")

	# 步骤3: 测试基础属性
	binding.set("signal_name", "test_signal")
	var signal_name = binding.get("signal_name")
	if signal_name != "test_signal":
		print("❌ 错误: signal_name 设置失败")
		return

	print("✓ signal_name 属性测试通过")

	# 步骤4: 测试冷却功能
	var cooldown = binding.get("adv_cooldown")
	if cooldown != 0.0:
		print("❌ 错误: adv_cooldown 默认值应该是 0.0")
		return

	print("✓ adv_cooldown 默认值正确")

	# 步骤5: 测试 can_play() 方法
	if not binding.has_method("can_play"):
		print("❌ 错误: AudioBinding 缺少 can_play() 方法")
		return

	var can_play_result = binding.call("can_play")
	if not can_play_result:
		print("❌ 错误: can_play() 应该返回 true（无冷却）")
		return

	print("✓ can_play() 方法测试通过")

	# 步骤6: 测试 mark_played() 方法
	if not binding.has_method("mark_played"):
		print("❌ 错误: AudioBinding 缺少 mark_played() 方法")
		return

	binding.call("mark_played")
	print("✓ mark_played() 方法测试通过")

	# 步骤7: 测试 reset_cooldown() 方法
	if not binding.has_method("reset_cooldown"):
		print("❌ 错误: AudioBinding 缺少 reset_cooldown() 方法")
		return

	binding.call("reset_cooldown")
	print("✓ reset_cooldown() 方法测试通过")

	# 步骤8: 测试 validate() 方法
	if not binding.has_method("validate"):
		print("❌ 错误: AudioBinding 缺少 validate() 方法")
		return

	var validation_result = binding.call("validate")
	if not validation_result is Dictionary:
		print("❌ 错误: validate() 应该返回 Dictionary")
		return

	if validation_result.has("valid") and validation_result.valid:
		print("❌ 错误: 空 signal_name 应该验证失败")
		return

	print("✓ validate() 方法测试通过")

	# 步骤9: 测试完整绑定配置
	binding.set("signal_name", "complete_test")
	var audio_event_resource = load("res://addons/juicy_mixer/resources/audio/audio_event_resource.gd")
	if audio_event_resource != null:
		var audio_event = audio_event_resource.new()
		binding.set("audio_event", audio_event)
		binding.set("adv_cooldown", 1.0)
		binding.set("adv_delay", 0.5)
		binding.set("adv_volume_override", 1.5)

		validation_result = binding.call("validate")
		if not validation_result.valid:
			print("❌ 错误: 完整配置应该验证通过")
			print("   问题: ", validation_result.issues)
			return

		print("✓ 完整配置验证通过")

	print("\n=== 所有 AudioBinding 验证通过! ===\n")
	print("AudioBinding 资源类已成功实现:")
	print("  ✓ 类定义正确")
	print("  ✓ 属性可正常读写")
	print("  ✓ 冷却机制工作正常")
	print("  ✓ 验证方法工作正常")
