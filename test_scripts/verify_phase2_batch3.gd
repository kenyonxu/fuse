extends Node

## 验证 Phase 2 批次 3 的指令

func _ready():
	print("=== 验证 Phase 2 批次 3 指令 ===\n")

	verify_set_time_scale()
	verify_reload_scene()
	verify_add_scene_as_child()

	print("\n=== 所有指令验证完成！ ===")

## 验证 SetTimeScale 指令
func verify_set_time_scale():
	print("1. 验证 SetTimeScale 指令")

	var instruction_script = load("res://addons/fuse/instructions/set_time_scale.gd")
	assert(instruction_script != null, "指令文件应该存在")

	var instruction = instruction_script.new()

	# 验证元数据
	var metadata = instruction_script._get_instruction_metadata()
	assert(metadata != null, "应该有元数据")
	assert(metadata.name_key == "FUSE_INSTRUCTION_SET_TIME_SCALE_NAME", "名称键应该正确")
	assert(metadata.category_key == "FUSE_CATEGORY_TIME", "分类应该正确")
	assert(metadata.builtin_icon == "Time", "图标应该正确")

	# 验证属性
	assert("time_scale" in instruction, "应该有 time_scale 属性")
	assert("duration" in instruction, "应该有 duration 属性")

	# 验证方法
	assert(instruction.has_method("execute"), "应该有 execute 方法")
	assert(instruction.has_method("validate"), "应该有 validate 方法")
	assert(instruction.has_method("get_description"), "应该有 get_description 方法")
	assert(instruction.has_method("_cleanup_resources"), "应该有 _cleanup_resources 方法")

	print("   ✓ SetTimeScale 指令验证通过\n")

## 验证 ReloadScene 指令
func verify_reload_scene():
	print("2. 验证 ReloadScene 指令")

	var instruction_script = load("res://addons/fuse/instructions/reload_scene.gd")
	assert(instruction_script != null, "指令文件应该存在")

	var instruction = instruction_script.new()

	# 验证元数据
	var metadata = instruction_script._get_instruction_metadata()
	assert(metadata != null, "应该有元数据")
	assert(metadata.name_key == "FUSE_INSTRUCTION_RELOAD_SCENE_NAME", "名称键应该正确")
	assert(metadata.category_key == "FUSE_CATEGORY_SCENE", "分类应该正确")
	assert(metadata.builtin_icon == "Reload", "图标应该正确")

	# 验证属性
	assert("delay" in instruction, "应该有 delay 属性")

	# 验证方法
	assert(instruction.has_method("execute"), "应该有 execute 方法")
	assert(instruction.has_method("validate"), "应该有 validate 方法")
	assert(instruction.has_method("get_description"), "应该有 get_description 方法")
	assert(instruction.has_method("_cleanup_resources"), "应该有 _cleanup_resources 方法")

	print("   ✓ ReloadScene 指令验证通过\n")

## 验证 AddSceneAsChild 指令
func verify_add_scene_as_child():
	print("3. 验证 AddSceneAsChild 指令")

	var instruction_script = load("res://addons/fuse/instructions/add_scene_as_child.gd")
	assert(instruction_script != null, "指令文件应该存在")

	var instruction = instruction_script.new()

	# 验证元数据
	var metadata = instruction_script._get_instruction_metadata()
	assert(metadata != null, "应该有元数据")
	assert(metadata.name_key == "FUSE_INSTRUCTION_ADD_SCENE_AS_CHILD_NAME", "名称键应该正确")
	assert(metadata.category_key == "FUSE_CATEGORY_SCENE", "分类应该正确")
	assert(metadata.builtin_icon == "MakePacked", "图标应该正确")

	# 验证属性
	assert("scene_path" in instruction, "应该有 scene_path 属性")
	assert("target_parent" in instruction, "应该有 target_parent 属性")
	assert("new_node_name" in instruction, "应该有 new_node_name 属性")

	# 验证方法
	assert(instruction.has_method("execute"), "应该有 execute 方法")
	assert(instruction.has_method("validate"), "应该有 validate 方法")
	assert(instruction.has_method("get_description"), "应该有 get_description 方法")

	print("   ✓ AddSceneAsChild 指令验证通过\n")
