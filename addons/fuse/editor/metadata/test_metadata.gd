# test_metadata.gd
@tool
extends EditorScript

## 测试元数据系统

func _run():
	print("=== 测试 Fuse 元数据系统 ===")

	# 测试 FuseMetadata
	var FuseMetadata_script = load("res://addons/fuse/editor/metadata/fuse_metadata.gd")
	if FuseMetadata_script:
		print("✓ FuseMetadata 脚本加载成功")
	else:
		print("✗ FuseMetadata 脚本加载失败")
		return

	# 测试 EventMetadata
	var EventMetadata_script = load("res://addons/fuse/editor/metadata/event_metadata.gd")
	if EventMetadata_script:
		print("✓ EventMetadata 脚本加载成功")
	else:
		print("✗ EventMetadata 脚本加载失败")

	# 测试 ConditionMetadata
	var ConditionMetadata_script = load("res://addons/fuse/editor/metadata/condition_metadata.gd")
	if ConditionMetadata_script:
		print("✓ ConditionMetadata 脚本加载成功")
	else:
		print("✗ ConditionMetadata 脚本加载失败")

	# 测试 InstructionMetadata
	var InstructionMetadata_script = load("res://addons/fuse/editor/instruction_selector/instructions_metadata.gd")
	if InstructionMetadata_script:
		print("✓ InstructionMetadata 脚本加载成功")
	else:
		print("✗ InstructionMetadata 脚本加载失败")

	# 测试实例化
	print("\n=== 测试实例化 ===")

	var fuse_meta = FuseMetadata.new()
	if fuse_meta:
		print("✓ FuseMetadata 实例化成功")
		# 测试方法
		if fuse_meta.has_method("get_localized_name"):
			print("✓ get_localized_name() 方法存在")
		if fuse_meta.has_method("get_localized_category"):
			print("✓ get_localized_category() 方法存在")
		if fuse_meta.has_method("get_localized_description"):
			print("✓ get_localized_description() 方法存在")
		if fuse_meta.has_method("get_icon_texture"):
			print("✓ get_icon_texture() 方法存在")
		if fuse_meta.has_method("validate"):
			print("✓ validate() 方法存在")
	else:
		print("✗ FuseMetadata 实例化失败")

	# 测试 InstructionMetadata 实例化
	var inst_meta = InstructionMetadata.new()
	if inst_meta:
		print("✓ InstructionMetadata 实例化成功")
		# 验证继承的方法
		if inst_meta.has_method("get_localized_name"):
			print("✓ InstructionMetadata 继承了 get_localized_name() 方法")
		# 验证特有的字段
		if "execution_hint" in inst_meta:
			print("✓ InstructionMetadata 有 execution_hint 字段")
	else:
		print("✗ InstructionMetadata 实例化失败")

	print("\n=== 测试完成 ===")
