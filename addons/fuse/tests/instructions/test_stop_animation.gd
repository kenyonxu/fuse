## Fuse Phase 3D 动画和相机指令测试
##
## 测试 Stop Animation、Set Animation Speed 和 Set Camera Zoom 指令

extends Node

## 测试结果统计
var test_results: Array[Dictionary] = []
var current_test_index: int = 0

## 测试场景节点
var test_scene: Node2D
var animation_player: AnimationPlayer
var camera: Camera2D

func _ready() -> void:
	var separator = "================================================================================"
	print("\n" + separator)
	print("Fuse Phase 3D - 动画和相机指令测试")
	print(separator + "\n")

	# 创建测试场景
	setup_test_scene()

	# 等待几帧后开始测试
	await get_tree().process_frame
	await get_tree().process_frame

	# 运行所有测试
	await run_all_tests()

	# 输出测试结果摘要
	print_test_summary()

	# 清理测试场景
	cleanup_test_scene()


## 设置测试场景
func setup_test_scene() -> void:
	# 创建测试场景根节点
	test_scene = Node2D.new()
	test_scene.name = "TestScene"
	add_child(test_scene)

	# 创建 AnimationPlayer
	animation_player = AnimationPlayer.new()
	animation_player.name = "TestAnimationPlayer"
	test_scene.add_child(animation_player)

	# 创建一个简单的动画
	var animation = Animation.new()
	animation.length = 1.0
	animation.loop = true
	animation.track_insert_key(0, 0.0, Vector2(0, 0))
	animation.track_insert_key(0, 1.0, Vector2(100, 100))
	animation_player.add_animation("test_anim", animation)

	# 创建 Camera2D
	camera = Camera2D.new()
	camera.name = "TestCamera"
	camera.zoom = Vector2(1.0, 1.0)
	test_scene.add_child(camera)

	print("测试场景已创建")


## 清理测试场景
func cleanup_test_scene() -> void:
	if test_scene:
		test_scene.queue_free()
		print("测试场景已清理")


## 运行所有测试
func run_all_tests() -> void:
	print("\n开始运行测试...\n")

	# 测试1: Stop Animation 指令 - 停止模式
	await test_stop_animation_stop()

	# 测试2: Stop Animation 指令 - 暂停模式
	await test_stop_animation_pause()

	# 测试3: Set Animation Speed 指令
	await test_set_animation_speed()

	# 测试4: Set Camera Zoom 指令 - 直接值
	await test_set_camera_zoom_direct()

	# 测试5: Set Camera Zoom 指令 - 变量值
	await test_set_camera_zoom_variable()

	# 测试6: Set Camera Zoom 指令 - 不同缩放模式
	await test_set_camera_zoom_modes()

	print("\n所有测试完成!\n")


## 测试1: Stop Animation 指令 - 停止模式
func test_stop_animation_stop() -> void:
	current_test_index = 1
	print("测试 %d: Stop Animation - 停止模式" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 创建指令
	var instruction = StopAnimation.new()
	instruction.target_node = ^"../../TestScene/TestAnimationPlayer"
	instruction.keep_position = false

	# 播放动画
	animation_player.play("test_anim")
	await get_tree().process_frame

	# 验证动画正在播放
	if not animation_player.is_playing():
		errors.append("动画应该正在播放")
		test_pass = false

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.owner_node = test_scene

	# 连接完成信号
	var completed = false
	instruction.finished.connect(func(): completed = true)

	# 执行指令
	instruction.execute(context)

	# 等待执行完成
	await get_tree().process_frame

	# 验证动画已停止
	if animation_player.is_playing():
		errors.append("动画应该已停止")
		test_pass = false
	else:
		print("  ✓ 动画已停止")

	# 验证当前位置已重置
	if animation_player.get_current_animation_position() != 0.0:
		errors.append("动画位置应该已重置为 0")
		test_pass = false
	else:
		print("  ✓ 动画位置已重置")

	# 记录测试结果
	record_test_result("Stop Animation (停止模式)", test_pass, errors)

	# 清理
	instruction.queue_free()


## 测试2: Stop Animation 指令 - 暂停模式
func test_stop_animation_pause() -> void:
	current_test_index = 2
	print("\n测试 %d: Stop Animation - 暂停模式" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 创建指令
	var instruction = StopAnimation.new()
	instruction.target_node = ^"../../TestScene/TestAnimationPlayer"
	instruction.keep_position = true

	# 播放动画并等待一段时间
	animation_player.play("test_anim")
	await get_tree().create_timer(0.5).timeout

	# 获取当前位置
	var current_position = animation_player.get_current_animation_position()

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.owner_node = test_scene

	# 连接完成信号
	var completed = false
	instruction.finished.connect(func(): completed = true)

	# 执行指令
	instruction.execute(context)

	# 等待执行完成
	await get_tree().process_frame

	# 验证动画已暂停
	if animation_player.is_playing():
		errors.append("动画应该已暂停")
		test_pass = false
	else:
		print("  ✓ 动画已暂停")

	# 验证位置保持不变
	var new_position = animation_player.get_current_animation_position()
	if abs(new_position - current_position) > 0.01:
		errors.append("动画位置应该保持不变")
		test_pass = false
	else:
		print("  ✓ 动画位置已保持")

	# 记录测试结果
	record_test_result("Stop Animation (暂停模式)", test_pass, errors)

	# 清理
	instruction.queue_free()


## 测试3: Set Animation Speed 指令
func test_set_animation_speed() -> void:
	current_test_index = 3
	print("\n测试 %d: Set Animation Speed" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 创建指令
	var instruction = SetAnimationSpeed.new()
	instruction.target_node = ^"../../TestScene/TestAnimationPlayer"
	instruction.speed_scale = 2.5

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.owner_node = test_scene

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证速度已设置
	if abs(animation_player.speed_scale - 2.5) > 0.01:
		errors.append("动画速度应该为 2.5，实际为 %.2f" % animation_player.speed_scale)
		test_pass = false
	else:
		print("  ✓ 动画速度已设置为 %.2f" % animation_player.speed_scale)

	# 测试另一个速度值
	instruction.speed_scale = 0.5
	instruction.execute(context)
	await get_tree().process_frame

	if abs(animation_player.speed_scale - 0.5) > 0.01:
		errors.append("动画速度应该为 0.5，实际为 %.2f" % animation_player.speed_scale)
		test_pass = false
	else:
		print("  ✓ 动画速度已更新为 %.2f" % animation_player.speed_scale)

	# 记录测试结果
	record_test_result("Set Animation Speed", test_pass, errors)

	# 清理
	instruction.queue_free()


## 测试4: Set Camera Zoom 指令 - 直接值
func test_set_camera_zoom_direct() -> void:
	current_test_index = 4
	print("\n测试 %d: Set Camera Zoom - 直接值" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 创建指令
	var instruction = SetCameraZoom.new()
	instruction.target_node = ^"../../TestScene/TestCamera"
	instruction.zoom_source = SetCameraZoom.ZoomSource.DIRECT
	instruction.zoom = 2.0
	instruction.zoom_mode = SetCameraZoom.ZoomMode.BOTH

	# 创建执行上下文
	var context = ExecutionContext.new()
	context.owner_node = test_scene

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证缩放已设置
	if abs(camera.zoom.x - 2.0) > 0.01 or abs(camera.zoom.y - 2.0) > 0.01:
		errors.append("相机缩放应该为 (2.0, 2.0)，实际为 (%.2f, %.2f)" % [camera.zoom.x, camera.zoom.y])
		test_pass = false
	else:
		print("  ✓ 相机缩放已设置为 (%.2f, %.2f)" % [camera.zoom.x, camera.zoom.y])

	# 记录测试结果
	record_test_result("Set Camera Zoom (直接值)", test_pass, errors)

	# 清理
	instruction.queue_free()


## 测试5: Set Camera Zoom 指令 - 变量值
func test_set_camera_zoom_variable() -> void:
	current_test_index = 5
	print("\n测试 %d: Set Camera Zoom - 变量值" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 创建指令
	var instruction = SetCameraZoom.new()
	instruction.target_node = ^"../../TestScene/TestCamera"
	instruction.zoom_source = SetCameraZoom.ZoomSource.VARIABLE
	instruction.zoom_variable = "zoom_value"
	instruction.zoom_mode = SetCameraZoom.ZoomMode.BOTH

	# 创建执行上下文并设置变量
	var context = ExecutionContext.new()
	context.owner_node = test_scene
	context.set_variable("zoom_value", 1.5)

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证缩放已设置
	if abs(camera.zoom.x - 1.5) > 0.01 or abs(camera.zoom.y - 1.5) > 0.01:
		errors.append("相机缩放应该为 (1.5, 1.5)，实际为 (%.2f, %.2f)" % [camera.zoom.x, camera.zoom.y])
		test_pass = false
	else:
		print("  ✓ 相机缩放已从变量设置为 (%.2f, %.2f)" % [camera.zoom.x, camera.zoom.y])

	# 记录测试结果
	record_test_result("Set Camera Zoom (变量值)", test_pass, errors)

	# 清理
	instruction.queue_free()


## 测试6: Set Camera Zoom 指令 - 不同缩放模式
func test_set_camera_zoom_modes() -> void:
	current_test_index = 6
	print("\n测试 %d: Set Camera Zoom - 不同缩放模式" % current_test_index)

	var test_pass: bool = true
	var errors: Array[String] = []

	# 重置缩放
	camera.zoom = Vector2(1.0, 1.0)

	# 测试水平缩放
	var instruction_h = SetCameraZoom.new()
	instruction_h.target_node = ^"../../TestScene/TestCamera"
	instruction_h.zoom_source = SetCameraZoom.ZoomSource.DIRECT
	instruction_h.zoom = 2.0
	instruction_h.zoom_mode = SetCameraZoom.ZoomMode.HORIZONTAL

	var context = ExecutionContext.new()
	context.owner_node = test_scene

	instruction_h.execute(context)
	await get_tree().process_frame

	if abs(camera.zoom.x - 2.0) > 0.01:
		errors.append("相机水平缩放应该为 2.0，实际为 %.2f" % camera.zoom.x)
		test_pass = false
	else:
		print("  ✓ 水平缩放已设置为 %.2f" % camera.zoom.x)

	if abs(camera.zoom.y - 1.0) > 0.01:
		errors.append("相机垂直缩放应该保持 1.0，实际为 %.2f" % camera.zoom.y)
		test_pass = false
	else:
		print("  ✓ 垂直缩放保持为 %.2f" % camera.zoom.y)

	# 测试垂直缩放
	camera.zoom = Vector2(1.0, 1.0)

	var instruction_v = SetCameraZoom.new()
	instruction_v.target_node = ^"../../TestScene/TestCamera"
	instruction_v.zoom_source = SetCameraZoom.ZoomSource.DIRECT
	instruction_v.zoom = 3.0
	instruction_v.zoom_mode = SetCameraZoom.ZoomMode.VERTICAL

	instruction_v.execute(context)
	await get_tree().process_frame

	if abs(camera.zoom.y - 3.0) > 0.01:
		errors.append("相机垂直缩放应该为 3.0，实际为 %.2f" % camera.zoom.y)
		test_pass = false
	else:
		print("  ✓ 垂直缩放已设置为 %.2f" % camera.zoom.y)

	if abs(camera.zoom.x - 1.0) > 0.01:
		errors.append("相机水平缩放应该保持 1.0，实际为 %.2f" % camera.zoom.x)
		test_pass = false
	else:
		print("  ✓ 水平缩放保持为 %.2f" % camera.zoom.x)

	# 记录测试结果
	record_test_result("Set Camera Zoom (不同模式)", test_pass, errors)

	# 清理
	instruction_h.queue_free()
	instruction_v.queue_free()


## 记录测试结果
func record_test_result(test_name: String, passed: bool, errors: Array[String]) -> void:
	var result = {
		"name": test_name,
		"passed": passed,
		"errors": errors
	}
	test_results.append(result)

	var status = "通过" if passed else "失败"
	print("  结果: %s\n" % status)

	if not passed and errors.size() > 0:
		print("  错误:")
		for error in errors:
			print("    - %s" % error)


## 打印测试结果摘要
func print_test_summary() -> void:
	var separator = "================================================================================"
	print("\n" + separator)
	print("测试结果摘要")
	print(separator + "\n")

	var total_tests = test_results.size()
	var passed_tests = 0
	var failed_tests = 0

	for result in test_results:
		if result.passed:
			passed_tests += 1
		else:
			failed_tests += 1

	print("总测试数: %d" % total_tests)
	print("通过: %d" % passed_tests)
	print("失败: %d" % failed_tests)
	print("成功率: %.1f%%\n" % (float(passed_tests) / float(total_tests) * 100.0))

	if failed_tests > 0:
		print("失败的测试:")
		for result in test_results:
			if not result.passed:
				print("  - %s" % result.name)
				for error in result.errors:
					print("    * %s" % error)
		print("")

	print(separator)
