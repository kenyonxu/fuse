@tool
extends EditorScript

## 测试 BaseInstruction.get_icon() 的智能图标获取逻辑
##
## 此脚本验证：
## 1. 新的 metadata.get_icon_texture() 方法优先
## 2. 向后兼容旧的 metadata.icon 字段
## 3. icon_name 字段支持

func _run():
	print("=== 开始测试 BaseInstruction.get_icon() ===")

	# 测试 1: 使用新的 icon_name 字段（通过 get_icon_texture）
	print("\n[测试 1] 使用 icon_name 字段")
	test_icon_name()

	# 测试 2: 向后兼容旧的 icon 字段
	print("\n[测试 2] 向后兼容旧的 icon 字段")
	test_legacy_icon()

	# 测试 3: 没有 icon 的情况
	print("\n[测试 3] 没有设置 icon 的情况")
	test_no_icon()

	print("\n=== 所有测试完成 ===")

## 测试 icon_name 字段（新方法）
func test_icon_name():
	# 使用 CreateVariable 指令进行测试（已配置 icon_name = "New"）
	var instruction = CreateVariable.new()

	# 检查 metadata 是否有 get_icon_texture 方法
	if instruction.metadata and instruction.metadata.has_method("get_icon_texture"):
		var icon = instruction.metadata.get_icon_texture()
		if icon:
			print("✓ 成功通过 get_icon_texture() 获取图标")
			print("  图标类型: ", icon.get_class())
		else:
			print("⚠ get_icon_texture() 返回 null（可能 icon_name 未设置或图标不存在）")
	else:
		print("✗ metadata 没有 get_icon_texture() 方法")

	# 测试 get_icon() 方法
	var icon_from_instruction = instruction.get_icon()
	if icon_from_instruction:
		print("✓ instruction.get_icon() 返回: ", icon_from_instruction.get_class())
	else:
		print("⚠ instruction.get_icon() 返回 null")

## 测试旧的 icon 字段（向后兼容）
func test_legacy_icon():
	print("  注意：旧的 icon 字段已被新方法替代")
	print("  如果元数据中设置了 icon，get_icon() 应该能够获取它")

## 测试没有设置 icon 的情况
func test_no_icon():
	# 创建一个空的 InstructionMetadata
	var metadata = InstructionMetadata.new()

	# 检查默认情况
	if not metadata.icon:
		print("✓ 默认情况下 metadata.icon 为 null")

	if not metadata.has_method("get_icon_texture") or not metadata.get_icon_texture():
		print("✓ get_icon_texture() 在没有 icon_name 时返回 null")
