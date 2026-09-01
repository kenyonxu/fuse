extends Node

## PauseGame 指令测试

## 简单的暂停菜单场景（用于测试）
var _pause_menu_scene_content = """
[gd_scene load_steps=2 format=3 uid="uid://test_pause_menu"]

[ext_resource type="Script" path="res://tests/instructions/test_pause_menu.gd" id="1"]

[node name="PauseMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1")

[node name="Label" type="Label" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = -25.0
offset_right = 100.0
offset_bottom = 25.0
grow_horizontal = 2
grow_vertical = 2
text = "游戏暂停"
horizontal_alignment = 1
vertical_alignment = 1
"""

## 暂停菜单脚本
var _pause_menu_script_content = """
extends Control

func _ready():
	print("  [PauseMenu] 暂停菜单已显示")
"""

func _ready():
	print("=== Testing PauseGame ===")

	# 创建测试用的暂停菜单场景
	_create_test_pause_menu_scene()

	test_pause_simple()
	test_pause_with_menu()
	test_pause_multiple_times()
	test_time_scale()

	# 清理测试场景
	_cleanup_test_pause_menu_scene()

	print("=== All PauseGame tests passed! ===")

## 测试 1: 简单暂停（不显示菜单）
func test_pause_simple():
	print("Test 1: Simple pause (no menu)")

	var instruction_script = load("res://addons/fuse/instructions/pause_game.gd")
	var instruction = instruction_script.new()
	instruction.show_pause_menu = false

	var context = ExecutionContext.new()
	add_child(context)

	# 保存原始时间缩放
	var original_scale = Engine.time_scale
	# 确保当前不是暂停状态
	Engine.time_scale = 1.0

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证时间缩放已设置为 0
	assert(Engine.time_scale == 0.0, "Time scale should be 0.0")
	print("  ✓ Game paused (time_scale = 0.0)")

	# 恢复正常时间
	Engine.time_scale = original_scale
	print("  ✓ Test 1 passed\n")

## 测试 2: 暂停并显示菜单
func test_pause_with_menu():
	print("Test 2: Pause with menu")

	var instruction_script = load("res://addons/fuse/instructions/pause_game.gd")
	var instruction = instruction_script.new()
	instruction.show_pause_menu = true
	instruction.pause_menu_scene = "user://test_pause_menu.tscn"
	instruction.pause_menu_parent = NodePath(".")

	var context = ExecutionContext.new()
	add_child(context)

	# 保存原始时间缩放
	var original_scale = Engine.time_scale
	Engine.time_scale = 1.0

	# 执行指令
	instruction.execute(context)
	await get_tree().process_frame

	# 验证时间缩放已设置为 0
	assert(Engine.time_scale == 0.0, "Time scale should be 0.0")
	print("  ✓ Game paused (time_scale = 0.0)")

	# 验证暂停菜单已显示
	var pause_menu = get_node_or_null("PauseMenu")
	assert(pause_menu != null, "Pause menu should be instantiated")
	assert(pause_menu is Control, "Pause menu should be a Control node")
	print("  ✓ Pause menu displayed")

	# 清理暂停菜单
	if pause_menu:
		pause_menu.queue_free()
		await get_tree().process_frame

	# 恢复正常时间
	Engine.time_scale = original_scale
	print("  ✓ Test 2 passed\n")

## 测试 3: 多次暂停
func test_pause_multiple_times():
	print("Test 3: Multiple pauses")

	var instruction_script = load("res://addons/fuse/instructions/pause_game.gd")
	var context = ExecutionContext.new()
	add_child(context)

	# 保存原始时间缩放
	var original_scale = Engine.time_scale
	Engine.time_scale = 1.0

	# 第一次暂停
	var instruction1 = instruction_script.new()
	instruction1.show_pause_menu = false
	instruction1.execute(context)
	await get_tree().process_frame

	assert(Engine.time_scale == 0.0, "Time scale should be 0.0 after first pause")
	print("  ✓ First pause successful")

	# 第二次暂停（应该保持暂停状态）
	var instruction2 = instruction_script.new()
	instruction2.show_pause_menu = false
	instruction2.execute(context)
	await get_tree().process_frame

	assert(Engine.time_scale == 0.0, "Time scale should still be 0.0 after second pause")
	print("  ✓ Second pause successful (still paused)")

	# 恢复正常时间
	Engine.time_scale = original_scale
	print("  ✓ Test 3 passed\n")

## 测试 4: 验证时间缩放
func test_time_scale():
	print("Test 4: Time scale verification")

	var instruction_script = load("res://addons/fuse/instructions/pause_game.gd")
	var instruction = instruction_script.new()
	instruction.show_pause_menu = false

	var context = ExecutionContext.new()
	add_child(context)

	# 测试不同的初始时间缩放值
	var test_scales = [0.5, 1.0, 2.0]

	for scale in test_scales:
		# 设置初始时间缩放
		Engine.time_scale = scale

		# 执行暂停指令
		var inst = instruction_script.new()
		inst.show_pause_menu = false
		inst.execute(context)
		await get_tree().process_frame

		# 验证时间缩放被设置为 0
		assert(Engine.time_scale == 0.0, "Time scale should be 0.0 regardless of initial scale")
		print("  ✓ Paused from %.1fx to 0.0x" % scale)

		# 恢复到正常速度进行下一次测试
		Engine.time_scale = 1.0
		await get_tree().process_frame

	print("  ✓ Test 4 passed\n")

## 创建测试用的暂停菜单场景
func _create_test_pause_menu_scene():
	# 创建暂停菜单脚本文件
	var script_file = FileAccess.open("user://test_pause_menu.gd", FileAccess.WRITE)
	if script_file:
		script_file.store_string(_pause_menu_script_content)
		script_file.close()

	# 创建暂停菜单场景文件
	var scene_file = FileAccess.open("user://test_pause_menu.tscn", FileAccess.WRITE)
	if scene_file:
		scene_file.store_string(_pause_menu_scene_content)
		scene_file.close()

	print("  [Setup] Test pause menu scene created")

## 清理测试用的暂停菜单场景
func _cleanup_test_pause_menu_scene():
	# 删除测试文件
	DirAccess.remove_absolute("user://test_pause_menu.gd")
	DirAccess.remove_absolute("user://test_pause_menu.tscn")
	print("  [Cleanup] Test pause menu scene removed")
