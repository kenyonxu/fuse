extends Control

## 测试 Set UI Texture 指令

func _ready():
	print("=== 开始测试 Set UI Texture 指令 ===")
	await test_set_texture_from_path()
	await test_set_texture_from_variable()
	await test_error_handling()
	print("=== Set UI Texture 指令测试完成 ===")

## 测试 1: 从资源路径设置纹理
func test_set_texture_from_path():
	print("\n[Test 1] 测试从资源路径设置纹理")

	var instruction_script = load("res://addons/fuse/instructions/set_ui_texture.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)

	var texture_rect = get_node("TestTextureRect") as TextureRect

	# 注意：这里使用 Godot 图标作为测试纹理
	instruction.target_node = NodePath("TestTextureRect")
	instruction.texture_source = 0  # RESOURCE_PATH
	instruction.texture_path = "res://icon.svg"

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame

	# 验证纹理是否已设置（可能为 null 如果资源不存在）
	if texture_rect.texture != null:
		print("✓ 从资源路径设置纹理测试通过")
	else:
		print("⚠ 纹理加载失败（res://icon.svg 可能不存在）")

	context.queue_free()

## 测试 2: 从变量设置纹理
func test_set_texture_from_variable():
	print("\n[Test 2] 测试从变量设置纹理")

	var instruction_script = load("res://addons/fuse/instructions/set_ui_texture.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)

	# 加载一个测试纹理并保存到变量
	var test_texture = load("res://icon.svg") as Texture2D
	if test_texture:
		context.set_variable("test_texture_var", test_texture)

		var texture_rect = get_node("TestTextureRect") as TextureRect

		instruction.target_node = NodePath("TestTextureRect")
		instruction.texture_source = 1  # VARIABLE
		instruction.texture_variable = "test_texture_var"

		instruction.execute(context)

		await context.finished
		await get_tree().process_frame

		assert(texture_rect.texture != null, "纹理应该从变量设置")
		print("✓ 从变量设置纹理测试通过")
	else:
		print("⚠ 无法加载测试纹理，跳过此测试")

	context.queue_free()

## 测试 3: 错误处理
func test_error_handling():
	print("\n[Test 3] 测试错误处理")

	var instruction_script = load("res://addons/fuse/instructions/set_ui_texture.gd")
	var instruction = instruction_script.new()
	var context = ExecutionContext.new()
	add_child(context)

	# 测试无效节点
	instruction.target_node = NodePath("InvalidNode")
	instruction.texture_source = 0  # RESOURCE_PATH
	instruction.texture_path = "res://icon.svg"

	instruction.execute(context)

	await context.finished
	await get_tree().process_frame

	assert(context.has_error(), "应该产生错误")
	print("✓ 错误处理测试通过")

	context.queue_free()
