# 文件：addons/fuse/editor/instruction_generator/instruction_generator.gd
@tool
class_name InstructionGenerator extends RefCounted

## 指令生成器
## 根据节点类和方法信息生成 Fuse 指令文件

## 预加载依赖
const FuseLocalization = preload("res://addons/fuse/localization/fuse_localization.gd")

## 默认输出目录
const DEFAULT_OUTPUT_DIR := "res://fuse_generated/instructions"

## 生成指令文件
## @param target_class: 目标类名
## @param method_info: 方法信息字典
## @param output_dir: 输出目录（可选，默认为 res://fuse_generated/instructions）
## @param use_variables: 是否生成变量绑定版本
## @return: 生成结果字典 {"success": bool, "path": String, "error": String}
static func generate_instruction(target_class: String, method_info: Dictionary, output_dir: String = "", use_variables: bool = false) -> Dictionary:
	if output_dir.is_empty():
		output_dir = DEFAULT_OUTPUT_DIR

	# 确保输出目录存在
	var class_dir = output_dir.path_join(target_class.to_lower())
	if not _ensure_directory(class_dir):
		return {"success": false, "path": "", "error": "无法创建输出目录: %s" % class_dir}

	# 生成文件内容
	var code = _generate_code(target_class, method_info, use_variables)
	if code.is_empty():
		return {"success": false, "path": "", "error": "无法生成代码"}

	# 生成文件名
	var method_name = method_info.get("name", "")
	var file_name = ConflictHandler.generate_file_name(target_class, method_name, use_variables)
	var file_path = class_dir.path_join(file_name)

	# 写入文件
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "path": "", "error": "无法打开文件: %s" % file_path}

	file.store_string(code)
	file.close()

	return {"success": true, "path": file_path, "error": ""}

## 确保目录存在
static func _ensure_directory(path: String) -> bool:
	var abs_path = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(abs_path):
		return true
	var dir := DirAccess.open("res://")
	if dir == null:
		return false
	return dir.make_dir_recursive_absolute(abs_path) == OK

## 生成指令代码
static func _generate_code(target_class: String, method_info: Dictionary, use_variables: bool = false) -> String:
	var method_name = method_info.get("name", "")
	var args = method_info.get("args", [])
	var return_info = method_info.get("return", {})

	# 生成类名（仅用于内部引用，不使用 class_name 避免全局冲突）
	var suffix = "_WithVariable" if use_variables else ""
	var instruction_class = "Call%s%s%s" % [target_class, method_name.to_pascal_case(), suffix]

	# 生成代码
	var code = ""

	# 文件头（不使用 class_name，避免全局命名空间污染和重复生成冲突）
	code += "@tool\n"
	code += "@icon(\"res://addons/fuse/icons/instruction.svg\")\n"
	code += "extends BaseInstruction\n\n"

	# 类文档
	code += "## 调用 %s.%s 方法\n" % [target_class, method_name]
	if use_variables:
		code += "## 变量绑定版本 - 每个参数支持直接值或变量读取\n"
	code += "## 自动生成 - 请勿手动修改\n\n"

	# 目标节点路径
	code += "## 目标节点路径\n"
	code += "@export var target_node: NodePath = NodePath(\"\")\n\n"

	# 参数属性
	if args.size() > 0:
		if use_variables:
			for arg in args:
				var var_lines = TypeMapper.param_to_variable_properties(arg)
				for line in var_lines:
					code += line + "\n"
				code += "\n"
		else:
			code += "## 方法参数\n"
			for arg in args:
				code += TypeMapper.param_to_property(arg) + "\n"
			code += "\n"

	# 返回值变量
	var return_type = return_info.get("type", TYPE_NIL)
	if return_type != TYPE_NIL:
		code += "## 返回值存储变量名（可选）\n"
		code += "@export var result_variable: String = \"\"\n"
		code += "## 返回值存储作用域\n"
		code += "@export var result_variable_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:\n"
		code += "\tset(value):\n"
		code += "\t\tresult_variable_scope = value\n"
		code += "\t\tnotify_property_list_changed()\n"
		code += "## 作用域来源（仅 SCOPE 作用域时生效）\n"
		code += "enum ScopeSource { NEAREST, CUSTOM_ID, TRIGGER_SCOPE, TARGET_NODE }\n"
		code += "@export var scope_source: ScopeSource = ScopeSource.NEAREST:\n"
		code += "\tset(value):\n"
		code += "\t\tscope_source = value\n"
		code += "\t\tnotify_property_list_changed()\n"
		code += "## 自定义作用域 ID（仅 CUSTOM_ID 模式时生效）\n"
		code += "@export var custom_scope_id: String = \"\"\n\n"

	# _get_property_list 方法（变量绑定版本需要动态属性列表）
	if use_variables:
		code += _generate_get_property_list_method(args)

	# 元数据方法
	code += _generate_metadata_method(target_class, method_name, args, use_variables)

	# _setup_metadata 方法
	code += "func _setup_metadata():\n"
	code += "\tpass\n\n"

	# _update_resource_name 方法
	code += _generate_update_resource_name(instruction_class)

	# execute 方法
	code += _generate_execute_method(target_class, method_name, args, return_info, use_variables)

	# get_description 方法
	code += _generate_get_description(target_class, method_name)

	# validate 方法
	code += _generate_validate_method(args)

	# _validate_property 方法
	var needs_validate = return_type != TYPE_NIL or (use_variables and args.size() > 0)
	if needs_validate:
		code += _generate_validate_property_method(args, return_type, use_variables)

	return code

## 生成 _get_property_list 方法（变量绑定版本，动态属性列表）
static func _generate_get_property_list_method(args: Array) -> String:
	var code = "func _get_property_list() -> Array[Dictionary]:\n"
	code += "\tvar properties: Array[Dictionary] = []\n\n"

	for arg in args:
		var param_name = arg.get("name", "param")
		var arg_type = arg.get("type", TYPE_NIL)
		var hint = arg.get("hint", PROPERTY_HINT_NONE)
		var hint_string = arg.get("hint_string", "")
		var enum_name = param_name.to_pascal_case() + "Source"

		# 属性列表中使用的类型（StringName 用 String 代替）
		var prop_type = arg_type
		var prop_hint = hint
		var prop_hint_str = hint_string
		if prop_type == TYPE_STRING_NAME:
			prop_type = TYPE_STRING
			prop_hint = PROPERTY_HINT_NONE
			prop_hint_str = ""

		# 参数分类标题
		code += "\tproperties.append({\n"
		code += "\t\tname = \"%s\",\n" % param_name.capitalize()
		code += "\t\ttype = TYPE_NIL,\n"
		code += "\t\thint = PROPERTY_HINT_NONE,\n"
		code += "\t\tusage = PROPERTY_USAGE_CATEGORY\n"
		code += "\t})\n\n"

		# 来源选择下拉框
		code += "\tproperties.append({\n"
		code += "\t\tname = \"%s_source\",\n" % param_name
		code += "\t\ttype = TYPE_INT,\n"
		code += "\t\thint = PROPERTY_HINT_ENUM,\n"
		code += "\t\thint_string = \"直接值,变量\",\n"
		code += "\t\tusage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE\n"
		code += "\t})\n\n"

		# VALUE 模式：显示直接值
		code += "\tif %s_source == %s.VALUE:\n" % [param_name, enum_name]
		code += "\t\tproperties.append({\n"
		code += "\t\t\tname = \"%s_value\",\n" % param_name
		code += "\t\t\ttype = %d,\n" % prop_type
		code += "\t\t\thint = %d,\n" % prop_hint
		if not prop_hint_str.is_empty():
			code += "\t\t\thint_string = \"%s\",\n" % prop_hint_str
		code += "\t\t\tusage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE\n"
		code += "\t\t})\n"

		# VARIABLE 模式：显示变量相关属性
		code += "\telse:\n"
		code += "\t\tproperties.append({\n"
		code += "\t\t\tname = \"%s_variable\",\n" % param_name
		code += "\t\t\ttype = TYPE_STRING,\n"
		code += "\t\t\thint = PROPERTY_HINT_NONE,\n"
		code += "\t\t\tusage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE\n"
		code += "\t\t})\n\n"

		code += "\t\tproperties.append({\n"
		code += "\t\t\tname = \"%s_scope\",\n" % param_name
		code += "\t\t\ttype = TYPE_INT,\n"
		code += "\t\t\thint = PROPERTY_HINT_ENUM,\n"
		code += "\t\t\thint_string = \"Local,Scope,Global\",\n"
		code += "\t\t\tusage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE\n"
		code += "\t\t})\n\n"

		# SCOPE 时显示 scope_source
		code += "\t\tif %s_scope == BaseVariable.VariableScope.SCOPE:\n" % param_name
		code += "\t\t\tproperties.append({\n"
		code += "\t\t\t\tname = \"%s_scope_source\",\n" % param_name
		code += "\t\t\t\ttype = TYPE_INT,\n"
		code += "\t\t\t\thint = PROPERTY_HINT_ENUM,\n"
		code += "\t\t\t\thint_string = \"Nearest,Custom ID,Trigger Scope,Target Node\",\n"
		code += "\t\t\t\tusage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE\n"
		code += "\t\t\t})\n\n"

		code += "\t\t\tif %s_scope_source == VariableScopeUtils.ScopeSource.CUSTOM_ID:\n" % param_name
		code += "\t\t\t\tproperties.append({\n"
		code += "\t\t\t\t\tname = \"%s_custom_scope_id\",\n" % param_name
		code += "\t\t\t\t\ttype = TYPE_STRING,\n"
		code += "\t\t\t\t\thint = PROPERTY_HINT_NONE,\n"
		code += "\t\t\t\t\tusage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE\n"
		code += "\t\t\t\t})\n"

		code += "\t\t\telif %s_scope_source == VariableScopeUtils.ScopeSource.TARGET_NODE:\n" % param_name
		code += "\t\t\t\tproperties.append({\n"
		code += "\t\t\t\t\tname = \"%s_target_node_path\",\n" % param_name
		code += "\t\t\t\t\ttype = TYPE_NODE_PATH,\n"
		code += "\t\t\t\t\thint = PROPERTY_HINT_NONE,\n"
		code += "\t\t\t\t\tusage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE\n"
		code += "\t\t\t\t})\n\n"

	code += "\treturn properties\n\n"

	return code

## 生成元数据方法
static func _generate_metadata_method(target_class: String, method_name: String, args: Array, use_variables: bool = false) -> String:
	var suffix = " (变量)" if use_variables else ""
	var code = "static func _get_instruction_metadata() -> InstructionMetadata:\n"
	code += "\tvar md = InstructionMetadata.new()\n"
	code += "\tmd.name = \"调用 %s.%s%s\"\n" % [target_class, method_name, suffix]
	code += "\tmd.category = \"用户生成\"\n"
	code += "\tmd.description = \"调用 %s 节点的 %s 方法%s\"\n" % [target_class, method_name, suffix]
	code += "\tmd.keywords = [\"%s\", \"%s\", \"%s\"]\n" % [target_class.to_lower(), method_name.to_lower(), "call"]
	code += "\treturn md\n\n"

	return code

## 生成 _update_resource_name 方法
static func _generate_update_resource_name(instruction_class: String) -> String:
	var code = "func _update_resource_name():\n"
	code += "\tresource_name = \"%s\"\n\n" % instruction_class

	return code

## 生成 execute 方法
static func _generate_execute_method(target_class: String, method_name: String, args: Array, return_info: Dictionary, use_variables: bool = false) -> String:
	var code = "func execute(context: ExecutionContext):\n"
	code += "\t_start_execution(context)\n\n"

	# 验证目标节点
	code += "\t# 验证目标节点\n"
	code += "\tif target_node.is_empty():\n"
	code += "\t\tset_error(\"目标节点路径为空\")\n"
	code += "\t\tfinished.emit()\n"
	code += "\t\treturn\n\n"

	# 获取目标节点
	code += "\t# 获取目标节点\n"
	code += "\tvar node := context.get_node(target_node)\n"
	code += "\tif node == null:\n"
	code += "\t\tset_error(\"找不到目标节点: %s\" % str(target_node))\n"
	code += "\t\tfinished.emit()\n"
	code += "\t\treturn\n\n"

	# 类型检查
	code += "\t# 类型检查\n"
	code += "\tif not node is %s:\n" % target_class
	code += "\t\tset_error(\"目标节点不是 %s 类型\")\n" % target_class
	code += "\t\tfinished.emit()\n"
	code += "\t\treturn\n\n"

	# 读取参数值
	var return_type = return_info.get("type", TYPE_NIL)
	var has_args = args.size() > 0

	if use_variables and has_args:
		code += "\t# 从变量读取参数值\n"
		for arg in args:
			code += _generate_param_read_code(arg)
		code += "\n"

	# 调用方法
	code += "\t# 调用方法\n"

	if has_args:
		var arg_list = []
		for arg in args:
			var arg_name = arg.get("name", "param")
			if use_variables:
				arg_list.append(arg_name + "_val")
			else:
				arg_list.append(arg_name)
		var call_str = "node.%s(%s)" % [method_name, ", ".join(arg_list)]
		if return_type != TYPE_NIL:
			code += "\tvar result = %s\n" % call_str
		else:
			code += "\t%s\n" % call_str
	else:
		var call_str = "node.%s()" % method_name
		if return_type != TYPE_NIL:
			code += "\tvar result = %s\n" % call_str
		else:
			code += "\t%s\n" % call_str

	code += "\n"

	# 处理返回值
	if return_type != TYPE_NIL:
		code += "\t# 存储返回值\n"
		code += "\tif not result_variable.is_empty():\n"
		code += "\t\tmatch result_variable_scope:\n"
		code += "\t\t\tBaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:\n"
		code += "\t\t\t\tVariableOperations.set_variable(context, result_variable, result_variable_scope, result)\n"
		code += "\t\t\tBaseVariable.VariableScope.SCOPE:\n"
		code += "\t\t\t\tif scope_source == ScopeSource.NEAREST:\n"
		code += "\t\t\t\t\tVariableOperations.set_variable(context, result_variable, BaseVariable.VariableScope.SCOPE, result)\n"
		code += "\t\t\t\telse:\n"
		code += "\t\t\t\t\tvar utils_scope_source = scope_source as VariableScopeUtils.ScopeSource\n"
		code += "\t\t\t\t\tvar scope_container = VariableScopeUtils.get_scope_container_by_source(context, utils_scope_source, custom_scope_id, target_node)\n"
		code += "\t\t\t\t\tif scope_container == null:\n"
		code += "\t\t\t\t\t\tset_error(\"找不到作用域容器\")\n"
		code += "\t\t\t\t\t\tfinished.emit()\n"
		code += "\t\t\t\t\t\treturn\n"
		code += "\t\t\t\t\tscope_container.set_variable(result_variable, result)\n\n"

	code += "\t_on_execution_completed()\n\n"

	return code

## 生成单个参数的变量读取代码
static func _generate_param_read_code(arg: Dictionary) -> String:
	var param_name = arg.get("name", "param")
	var arg_type = arg.get("type", TYPE_NIL)
	var type_decl = TypeMapper.get_type_declaration(arg_type, arg.get("hint", PROPERTY_HINT_NONE), arg.get("hint_string", ""))
	var default_val = TypeMapper.get_default_value(arg_type)
	var enum_name = param_name.to_pascal_case() + "Source"

	var code = ""
	code += "\tvar %s_val: %s = %s_value\n" % [param_name, type_decl, param_name]
	code += "\tif %s_source == %s.VARIABLE and not %s_variable.is_empty():\n" % [param_name, enum_name, param_name]
	code += "\t\tif %s_scope == BaseVariable.VariableScope.SCOPE:\n" % param_name
	code += "\t\t\tif %s_scope_source == VariableScopeUtils.ScopeSource.NEAREST:\n" % param_name
	code += "\t\t\t\t%s_val = VariableOperations.get_variable(context, %s_variable, BaseVariable.VariableScope.SCOPE, %s_val)\n" % [param_name, param_name, param_name]
	code += "\t\t\telse:\n"
	code += "\t\t\t\tvar scope_container = VariableScopeUtils.get_scope_container_by_source(context, %s_scope_source as VariableScopeUtils.ScopeSource, %s_custom_scope_id, %s_target_node_path)\n" % [param_name, param_name, param_name]
	code += "\t\t\t\tif scope_container == null:\n"
	code += "\t\t\t\t\tset_error(\"找不到参数 %s 的作用域容器\")\n" % param_name
	code += "\t\t\t\t\tfinished.emit()\n"
	code += "\t\t\t\t\treturn\n"
	code += "\t\t\t\t%s_val = scope_container.get_variable(%s_variable, %s_val)\n" % [param_name, param_name, param_name]
	code += "\t\telse:\n"
	code += "\t\t\t%s_val = VariableOperations.get_variable(context, %s_variable, %s_scope, %s_val)\n" % [param_name, param_name, param_name, param_name]
	code += "\n"

	return code

## 生成 get_description 方法
static func _generate_get_description(target_class: String, method_name: String) -> String:
	var code = "func get_description() -> String:\n"
	code += "\treturn \"调用 %s.%s on \" + _get_node_display_name(target_node)\n\n" % [target_class, method_name]

	return code

## 生成 validate 方法
static func _generate_validate_method(args: Array) -> String:
	var code = "func validate() -> Array[String]:\n"
	code += "\tvar errors = super.validate()\n"

	code += "\tif target_node.is_empty():\n"
	code += "\t\terrors.append(\"目标节点路径为空\")\n"

	code += "\treturn errors\n\n"

	return code

## 生成 _validate_property 方法（控制作用域相关属性的显隐）
static func _generate_validate_property_method(args: Array, return_type: int, use_variables: bool) -> String:
	var code = "func _validate_property(property: Dictionary) -> void:\n"

	# 参数的作用域显隐
	if use_variables:
		for arg in args:
			var param_name = arg.get("name", "param")
			var enum_name = param_name.to_pascal_case() + "Source"

			# 非 VARIABLE 模式时隐藏变量相关属性
			code += "\tif %s_source != %s.VARIABLE:\n" % [param_name, enum_name]
			code += "\t\tif property.name in [\"%s_variable\", \"%s_scope\", \"%s_scope_source\", \"%s_custom_scope_id\", \"%s_target_node_path\"]:\n" % [param_name, param_name, param_name, param_name, param_name]
			code += "\t\t\tproperty.usage = PROPERTY_USAGE_NO_EDITOR\n"
			code += "\t\t\treturn\n"

			# 非 SCOPE 作用域时隐藏 scope_source / custom_scope_id / target_node_path
			code += "\tif %s_scope != BaseVariable.VariableScope.SCOPE:\n" % param_name
			code += "\t\tif property.name in [\"%s_scope_source\", \"%s_custom_scope_id\", \"%s_target_node_path\"]:\n" % [param_name, param_name, param_name]
			code += "\t\t\tproperty.usage = PROPERTY_USAGE_NO_EDITOR\n"
			code += "\t\t\treturn\n"

			# SCOPE 作用域下进一步细化
			code += "\tif %s_scope == BaseVariable.VariableScope.SCOPE and %s_source == %s.VARIABLE:\n" % [param_name, param_name, enum_name]
			code += "\t\tVariableScopeUtils.validate_scope_source_property(property, %s_scope_source as VariableScopeUtils.ScopeSource)\n" % param_name
			code += "\n"

	# 返回值的作用域显隐（保持现有逻辑）
	if return_type != TYPE_NIL:
		code += "\tif result_variable_scope != BaseVariable.VariableScope.SCOPE:\n"
		code += "\t\tif property.name in [\"scope_source\", \"custom_scope_id\"]:\n"
		code += "\t\t\tproperty.usage = PROPERTY_USAGE_NONE\n"
		code += "\t\t\treturn\n"
		code += "\tif scope_source != ScopeSource.CUSTOM_ID and property.name == \"custom_scope_id\":\n"
		code += "\t\tproperty.usage = PROPERTY_USAGE_NONE\n\n"

	return code
