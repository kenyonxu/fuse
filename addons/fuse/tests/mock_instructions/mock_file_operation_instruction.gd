@tool
class_name MockFileOperationInstruction extends BaseInstruction

var operation_name: String

func _init(name: String):
	operation_name = name

func _setup_metadata():
	metadata.name = "文件操作"
	metadata.description = "执行文件操作"
	metadata.category = "文件"

func _update_resource_name():
	resource_name = "FileOp: %s" % operation_name

func execute(context: ExecutionContext):
	_start_execution(context)
	# 模拟文件操作
	_on_execution_completed()

func get_description() -> String:
	return "文件操作: %s" % operation_name