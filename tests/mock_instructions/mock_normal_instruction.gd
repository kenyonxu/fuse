@tool
class_name MockNormalInstruction extends BaseInstruction

var instruction_name: String

func _init(name: String):
	instruction_name = name

func _setup_metadata():
	metadata.name = "模拟指令"
	metadata.description = "用于测试的模拟指令"
	metadata.category = "测试"

func _update_resource_name():
	resource_name = "MockNormal: %s" % instruction_name

func execute(context: ExecutionContext):
	_start_execution(context)
	# 模拟简单的同步操作
	_on_execution_completed()

func get_description() -> String:
	return "模拟指令: %s" % instruction_name