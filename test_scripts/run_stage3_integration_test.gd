#!/usr/bin/env -S godot --script
extends SceneTree

## 运行阶段3集成测试的脚本

func _init():
	print("正在加载阶段3集成测试场景...")

	# 加载测试场景
	var test_scene = load("res://addons/fuse/tests/test_stage3_runtime_localization.tscn")

	if test_scene:
		var test_node = test_scene.instantiate()
		root.add_child(test_node)

		# 等待测试完成
		await test_node.ready
		await process_frame
		await process_frame

		# 退出
		quit()
	else:
		push_error("无法加载测试场景")
		quit(1)
