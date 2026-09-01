@tool
class_name MockJumpInstruction extends BaseInstruction

var jump_target: int

func _init(target: int):
	jump_target = target

func _setup_metadata():
	metadata.name = "跳转指令"
	metadata.description = "跳转到指定指令"
	metadata.category = "控制流"

func _update_resource_name():
	resource_name = "Jump: %d" % jump_target

func execute(context: ExecutionContext):
	_start_execution(context)
	# 模拟跳转操作
	_on_execution_completed()

func get_description() -> String:
	return "跳转到指令 %d" % jump_target

func get_jump_target() -> int:
	return jump_target