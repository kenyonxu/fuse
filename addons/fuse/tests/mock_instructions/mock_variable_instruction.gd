@tool
class_name MockVariableInstruction extends BaseInstruction

var variable_name: String
var variable_value: Variant

func _init(name: String, value: Variant):
	variable_name = name
	variable_value = value

func _setup_metadata():
	metadata.name = "变量定义"
	metadata.description = "定义一个变量"
	metadata.category = "变量"

func _update_resource_name():
	resource_name = "VarDef: %s" % variable_name

func execute(context: ExecutionContext):
	_start_execution(context)
	if context:
		context.set_variable(variable_name, variable_value)
	_on_execution_completed()

func get_description() -> String:
	return "定义变量 %s = %s" % [variable_name, variable_value]

func get_defined_variables() -> Array[String]:
	return [variable_name]