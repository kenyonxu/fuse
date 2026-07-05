extends Node

# 测试 RunTargetNodeFunction 参数验证失败问题的调试脚本

func _ready():
	print("=== 开始测试 RunTargetNodeFunction 参数验证问题 ===")
	
	# 创建一个简单的场景结构
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	add_child(sprite)
	
	# 创建 RunTargetNodeFunction 指令
	var instruction = RunTargetNodeFunction.new()
	
	# 配置指令
	instruction.target_node = "../Sprite2D"
	instruction.target_function = "set_position"
	
	# 设置参数 - 这里可能是问题所在
	print("设置参数之前...")
	instruction.function_args = [Vector2(100, 100)]
	print("设置参数之后: %s" % str(instruction.function_args))
	
	# 创建执行上下文
	var context = ExecutionContext.new()
	
	print("开始执行指令...")
	
	# 尝试执行指令
	instruction.execute(context)
	
	print("指令执行完成")

func _exit_tree():
	print("=== 测试结束 ===")