extends Node

## 简单的语法验证脚本

func _ready():
	print("开始验证 VariableContainer 语法...")

	# 尝试加载 VariableContainer
	var container = VariableContainer.new()

	# 检查新的统一存储变量是否存在
	if container.has_method("_get_variable_data"):
		print("✓ _get_variable_data 方法存在")
	else:
		print("✗ _get_variable_data 方法不存在")

	if "_variables_data" in container:
		print("✓ _variables_data 存在")
	else:
		print("✗ _variables_data 不存在")

	if "_scope_index" in container:
		print("✓ _scope_index 存在")
	else:
		print("✗ _scope_index 不存在")

	print("\n语法验证完成！")

	# 退出
	await get_tree().process_frame
	get_tree().quit()
