@tool
class_name MockHeavyOperationInstruction extends BaseInstruction

var operation_name: String

func _init(name: String):
	operation_name = name

func _setup_metadata():
	metadata.name = "大型操作"
	metadata.description = "执行资源密集型操作"
	metadata.category = "大型"

func _update_resource_name():
	resource_name = "HeavyOp: %s" % operation_name

func execute(context: ExecutionContext):
	_start_execution(context)
	# 模拟大型操作
	_on_execution_completed()

func get_description() -> String:
	return "大型操作: %s" % operation_name