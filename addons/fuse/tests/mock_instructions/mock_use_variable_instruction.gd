@tool
class_name MockUseVariableInstruction extends BaseInstruction

var variable_name: String

func _init(name: String):
	variable_name = name

func _setup_metadata():
	metadata.name = "变量使用"
	metadata.description = "使用一个变量"
	metadata.category = "变量"

func _update_resource_name():
	resource_name = "VarUse: %s" % variable_name

func execute(context: ExecutionContext):
	_start_execution(context)
	if context:
		var value = context.get_variable(variable_name)
		# 模拟使用变量
	_on_execution_completed()

func get_description() -> String:
	return "使用变量 %s" % variable_name

func get_used_variables() -> Array[String]:
	return [variable_name]