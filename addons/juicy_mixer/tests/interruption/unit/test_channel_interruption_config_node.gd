extends Node
# ChannelInterruptionConfig Node-based测试运行器
# 基于Node的测试运行器，可在Godot编辑器中直接运行

const OriginalTest = preload("res://addons/juicy_mixer/tests/interruption/unit/test_channel_interruption_config.gd")

var _original_test: OriginalTest

func _ready():
	print("=== ChannelInterruptionConfig Node-based测试开始 ===")
	
	# 创建原始测试实例
	_original_test = OriginalTest.new()
	
	# 运行所有测试
	var success = _original_test.run_all_tests()
	
	if success:
		print("✅ 所有测试通过！")
	else:
		print("❌ 部分测试失败！")
	
	print("=== ChannelInterruptionConfig Node-based测试完成 ===")

func _exit_tree():
	# 清理资源
	if _original_test:
		_original_test.free()