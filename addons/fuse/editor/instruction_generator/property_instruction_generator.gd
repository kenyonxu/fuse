# 文件：addons/fuse/editor/instruction_generator/property_instruction_generator.gd
@tool
class_name PropertyInstructionGenerator extends RefCounted

## 属性指令生成器
## 根据节点类和属性信息生成 GET/SET Fuse 指令文件
## 与 InstructionGenerator（方法指令）配合使用

## 默认输出目录
const DEFAULT_OUTPUT_DIR := "res://fuse_generated/instructions"

# ============================================================
# SET 指令
# ============================================================

## 生成 SET 属性指令文件
## @param target_class: 目标类名（如 "AnimatedSprite2D"）
## @param property_dict: 属性字典（含 name, type, hint, hint_string, default_value）
## @param output_dir: 输出目录（可选）
## @param use_variables: 是否生成变量绑定版本
## @return: {"success": bool, "path": String, "error": String}
static func generate_set_instruction(target_class: String, property_dict: Dictionary, output_dir: String = "", use_variables: bool = false) -> Dictionary:
	if output_dir.is_empty():
		output_dir = DEFAULT_OUTPUT_DIR

	# 确保输出目录存在
	var class_dir = output_dir.path_join(target_class.to_lower())
	if not InstructionGenerator._ensure_directory(class_dir):
		return {"success": false, "path": "", "error": "无法创建输出目录: %s" % class_dir}

	# 生成文件内容
	var code = _generate_set_code(target_class, property_dict, use_variables)
	if code.is_empty():
		return {"success": false, "path": "", "error": "无法生成代码"}

	# 生成文件名
	var property_name = property_dict.get("name", "")
	var file_name = ConflictHandler.generate_property_file_name(target_class, property_name, "set", use_variables)
	var file_path = class_dir.path_join(file_name)

	# 写入文件
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "path": "", "error": "无法打开文件: %s" % file_path}

	file.store_string(code)
	file.close()

	return {"success": true, "path": file_path, "error": ""}

## 生成 SET 指令的完整 GDScript 代码
static func _generate_set_code(target_class: String, property_dict: Dictionary, use_variables: bool) -> String:
	var property_name = property_dict.get("name", "")
	var prop_type = property_dict.get("type", TYPE_NIL)
	var prop_hint = property_dict.get("hint", PROPERTY_HINT_NONE)
	var prop_hint_string = property_dict.get("hint_string", "")

	# 生成类名（仅用于内部引用，不使用 class_name 避免全局冲突）
	var suffix = "_WithVariable" if use_variables else ""
	var instruction_class = "Set%s%s%s" % [target_class, property_name.to_pascal_case(), suffix]

	# 生成代码
	var code = ""

	# 文件头
	code += "@tool\n"
	code += "@icon(\"res://addons/fuse/icons/instruction.svg\")\n"
	code += "extends BaseInstruction\n\n"

	# 类文档
	code += "## 设置 %s.%s\n" % [target_class, property_name]
	if use_variables:
		code += "## 变量绑定版本 - 值支持直接输入或从变量读取\n"
	code += "## 自动生成 - 请勿手动修改\n\n"

	# 目标节点路径
	code += "## 目标节点路径\n"
	code += "@export var target_node: NodePath = NodePath(\"\")\n\n"

	# 属性值
	if use_variables:
		# 变量绑定版本：使用 TypeMapper 生成变量绑定属性
		var var_lines = TypeMapper.param_to_variable_properties(property_dict)
		for line in var_lines:
			code += line + "\n"
		code += "\n"
	else:
		# 普通版本：直接导出属性值
		var type_decl = TypeMapper.get_type_declaration(prop_type, prop_hint, prop_hint_string)
		var default_val = TypeMapper.get_default_value(prop_type)
		var export_annotation = TypeMapper.get_export_annotation(prop_type, prop_hint, prop_hint_string)
		code += "## 属性值\n"
		code += "%s var %s_value: %s = %s\n\n" % [export_annotation, property_name, type_decl, default_val]

	# _get_property_list 方法（仅变量绑定版本需要）
	if use_variables:
		code += InstructionGenerator._generate_get_property_list_method([property_dict])

	# 元数据方法
	var display_suffix = " (变量)" if use_variables else ""
	var desc_suffix = " (变量)" if use_variables else ""
	code += "static func _get_instruction_metadata() -> InstructionMetadata:\n"
	code += "\tvar md = InstructionMetadata.new()\n"
	code += "\tmd.name = \"设置 %s.%s%s\"\n" % [target_class, property_name, display_suffix]
	code += "\tmd.category = \"用户生成\"\n"
	code += "\tmd.description = \"设置 %s 节点的 %s 属性%s\"\n" % [target_class, property_name, desc_suffix]
	code += "\tmd.keywords = [\"%s\", \"%s\", \"set\"]\n" % [target_class.to_lower(), property_name.to_lower()]
	code += "\treturn md\n\n"

	# _setup_metadata 方法
	code += "func _setup_metadata():\n"
	code += "\tpass\n\n"

	# _update_resource_name 方法
	code += "func _update_resource_name():\n"
	code += "\tresource_name = \"%s\"\n\n" % instruction_class

	# execute 方法
	code += _generate_set_execute_method(target_class, property_dict, use_variables)

	# get_description 方法
	code += "func get_description() -> String:\n"
	code += "\treturn \"设置 %s.%s on \" + _get_node_display_name(target_node)\n\n" % [target_class, property_name]

	# validate 方法
	code += "func validate() -> Array[String]:\n"
	code += "\tvar errors = super.validate()\n"
	code += "\tif target_node.is_empty():\n"
	code += "\t\terrors.append(\"目标节点路径为空\")\n"
	code += "\treturn errors\n\n"

	# _validate_property 方法（仅变量绑定版本需要）
	if use_variables:
		code += InstructionGenerator._generate_validate_property_method([property_dict], TYPE_NIL, true)

	return code

## 生成 SET 指令的 execute 方法
static func _generate_set_execute_method(target_class: String, property_dict: Dictionary, use_variables: bool) -> String:
	var property_name = property_dict.get("name", "")

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

	# 赋值
	if use_variables:
		code += "\t# 从变量读取值\n"
		code += InstructionGenerator._generate_param_read_code(property_dict)
		code += "\tnode.%s = %s_val\n\n" % [property_name, property_name]
	else:
		code += "\t# 设置属性值\n"
		code += "\tnode.%s = %s_value\n\n" % [property_name, property_name]

	code += "\t_on_execution_completed()\n\n"

	return code

# ============================================================
# GET 指令
# ============================================================

## 生成 GET 属性指令文件
## @param target_class: 目标类名（如 "AnimatedSprite2D"）
## @param property_dict: 属性字典（含 name, type, hint, hint_string, default_value）
## @param output_dir: 输出目录（可选）
## @return: {"success": bool, "path": String, "error": String}
static func generate_get_instruction(target_class: String, property_dict: Dictionary, output_dir: String = "") -> Dictionary:
	if output_dir.is_empty():
		output_dir = DEFAULT_OUTPUT_DIR

	# 确保输出目录存在
	var class_dir = output_dir.path_join(target_class.to_lower())
	if not InstructionGenerator._ensure_directory(class_dir):
		return {"success": false, "path": "", "error": "无法创建输出目录: %s" % class_dir}

	# 生成文件内容
	var code = _generate_get_code(target_class, property_dict)
	if code.is_empty():
		return {"success": false, "path": "", "error": "无法生成代码"}

	# 生成文件名
	var property_name = property_dict.get("name", "")
	var file_name = ConflictHandler.generate_property_file_name(target_class, property_name, "get")
	var file_path = class_dir.path_join(file_name)

	# 写入文件
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "path": "", "error": "无法打开文件: %s" % file_path}

	file.store_string(code)
	file.close()

	return {"success": true, "path": file_path, "error": ""}

## 生成 GET 指令的完整 GDScript 代码
static func _generate_get_code(target_class: String, property_dict: Dictionary) -> String:
	var property_name = property_dict.get("name", "")

	# 生成类名（仅用于内部引用，不使用 class_name 避免全局冲突）
	var instruction_class = "Get%s%s" % [target_class, property_name.to_pascal_case()]

	# 生成代码
	var code = ""

	# 文件头
	code += "@tool\n"
	code += "@icon(\"res://addons/fuse/icons/instruction.svg\")\n"
	code += "extends BaseInstruction\n\n"

	# 类文档
	code += "## 获取 %s.%s\n" % [target_class, property_name]
	code += "## 自动生成 - 请勿手动修改\n\n"

	# 目标节点路径（由 _get_property_list 管理，不用 @export 避免重复显示）
	code += "## 目标节点路径\n"
	code += "var target_node: NodePath = NodePath(\"\")\n\n"

	# 保存变量相关属性
	code += "## 保存到的变量名\n"
	code += "var save_to_variable: String = \"\"\n\n"
	code += "## 保存到的变量作用域\n"
	code += "var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:\n"
	code += "\tset(value):\n"
	code += "\t\tsave_to_scope = value\n"
	code += "\t\tnotify_property_list_changed()\n\n"
	code += "## 作用域来源枚举\n"
	code += "enum ScopeSource { NEAREST, CUSTOM_ID, TRIGGER_SCOPE, TARGET_NODE }\n\n"
	code += "## 保存作用域来源（仅当 save_to_scope == SCOPE 时使用）\n"
	code += "var scope_source: ScopeSource = ScopeSource.NEAREST:\n"
	code += "\tset(value):\n"
	code += "\t\tscope_source = value\n"
	code += "\t\tnotify_property_list_changed()\n\n"
	code += "## 保存自定义作用域 ID（CUSTOM_ID 模式使用）\n"
	code += "var custom_scope_id: String = \"\"\n\n"
	code += "## 保存目标节点路径（TARGET_NODE 模式使用）\n"
	code += "var save_target_node_path: NodePath = NodePath(\"\")\n\n"

	# _get_property_list 方法
	code += _generate_get_property_list_method(target_class)

	# 元数据方法
	code += "static func _get_instruction_metadata() -> InstructionMetadata:\n"
	code += "\tvar md = InstructionMetadata.new()\n"
	code += "\tmd.name = \"获取 %s.%s\"\n" % [target_class, property_name]
	code += "\tmd.category = \"用户生成\"\n"
	code += "\tmd.description = \"获取 %s 节点的 %s 属性值并保存到变量\"\n" % [target_class, property_name]
	code += "\tmd.keywords = [\"%s\", \"%s\", \"get\"]\n" % [target_class.to_lower(), property_name.to_lower()]
	code += "\treturn md\n\n"

	# _setup_metadata 方法
	code += "func _setup_metadata():\n"
	code += "\tpass\n\n"

	# _update_resource_name 方法
	code += "func _update_resource_name():\n"
	code += "\tresource_name = \"%s\"\n\n" % instruction_class

	# execute 方法
	code += _generate_get_execute_method(target_class, property_dict)

	# get_description 方法
	code += "func get_description() -> String:\n"
	code += "\treturn \"获取 %s.%s on \" + _get_node_display_name(target_node)\n\n" % [target_class, property_name]

	# validate 方法
	code += "func validate() -> Array[String]:\n"
	code += "\tvar errors = super.validate()\n"
	code += "\tif target_node.is_empty():\n"
	code += "\t\terrors.append(\"目标节点路径为空\")\n"
	code += "\tif save_to_variable.is_empty():\n"
	code += "\t\terrors.append(\"保存变量名不能为空\")\n"
	code += "\treturn errors\n\n"

	# _validate_property 方法（控制作用域相关属性的显隐）
	code += _generate_get_validate_property_method()

	return code

## 生成 GET 指令的 _get_property_list 方法
static func _generate_get_property_list_method(target_class: String) -> String:
	var code = "func _get_property_list() -> Array[Dictionary]:\n"
	code += "\tvar properties: Array[Dictionary] = []\n\n"

	# Target 分类
	code += "\t# Target 分类\n"
	code += "\tproperties.append({\n"
	code += "\t\tname = \"Target\",\n"
	code += "\t\ttype = TYPE_NIL,\n"
	code += "\t\thint = PROPERTY_HINT_NONE,\n"
	code += "\t\tusage = PROPERTY_USAGE_CATEGORY\n"
	code += "\t})\n\n"

	# target_node
	code += "\tproperties.append({\n"
	code += "\t\tname = \"target_node\",\n"
	code += "\t\ttype = TYPE_NODE_PATH,\n"
	code += "\t\thint = PROPERTY_HINT_NODE_PATH_VALID_TYPES,\n"
	code += "\t\thint_string = \"%s\",\n" % target_class
	code += "\t\tusage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE\n"
	code += "\t})\n\n"

	# Save To 分类
	code += "\t# Save To 分类\n"
	code += "\tproperties.append({\n"
	code += "\t\tname = \"Save To\",\n"
	code += "\t\ttype = TYPE_NIL,\n"
	code += "\t\thint = PROPERTY_HINT_NONE,\n"
	code += "\t\tusage = PROPERTY_USAGE_CATEGORY\n"
	code += "\t})\n\n"

	# save_to_variable
	code += "\tproperties.append({\n"
	code += "\t\tname = \"save_to_variable\",\n"
	code += "\t\ttype = TYPE_STRING,\n"
	code += "\t\thint = PROPERTY_HINT_NONE,\n"
	code += "\t\tusage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE\n"
	code += "\t})\n\n"

	# save_to_scope
	code += "\tproperties.append({\n"
	code += "\t\tname = \"save_to_scope\",\n"
	code += "\t\ttype = TYPE_INT,\n"
	code += "\t\thint = PROPERTY_HINT_ENUM,\n"
	code += "\t\thint_string = \"Local,Scope,Global\",\n"
	code += "\t\tusage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE\n"
	code += "\t})\n\n"

	# save_to_scope == SCOPE 时显示 scope_source 相关属性
	code += "\t# 仅当 save_to_scope == SCOPE 时显示作用域来源属性\n"
	code += "\tif save_to_scope == BaseVariable.VariableScope.SCOPE:\n"
	code += "\t\tproperties.append({\n"
	code += "\t\t\tname = \"scope_source\",\n"
	code += "\t\t\ttype = TYPE_INT,\n"
	code += "\t\t\thint = PROPERTY_HINT_ENUM,\n"
	code += "\t\t\thint_string = \"Nearest,Custom ID,Trigger Scope,Target Node\",\n"
	code += "\t\t\tusage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE\n"
	code += "\t\t})\n\n"

	code += "\t\t# 根据 scope_source 添加额外属性\n"
	code += "\t\tif scope_source == ScopeSource.CUSTOM_ID:\n"
	code += "\t\t\tproperties.append({\n"
	code += "\t\t\t\tname = \"custom_scope_id\",\n"
	code += "\t\t\t\ttype = TYPE_STRING,\n"
	code += "\t\t\t\thint = PROPERTY_HINT_NONE,\n"
	code += "\t\t\t\tusage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE\n"
	code += "\t\t\t})\n"
	code += "\t\telif scope_source == ScopeSource.TARGET_NODE:\n"
	code += "\t\t\tproperties.append({\n"
	code += "\t\t\t\tname = \"save_target_node_path\",\n"
	code += "\t\t\t\ttype = TYPE_NODE_PATH,\n"
	code += "\t\t\t\thint = PROPERTY_HINT_NONE,\n"
	code += "\t\t\t\tusage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE\n"
	code += "\t\t\t})\n\n"

	code += "\treturn properties\n\n"

	return code

## 生成 GET 指令的 execute 方法
static func _generate_get_execute_method(target_class: String, property_dict: Dictionary) -> String:
	var property_name = property_dict.get("name", "")

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

	# 读取属性值
	code += "\t# 读取属性值\n"
	code += "\tvar value = node.%s\n\n" % property_name

	# 保存到变量
	code += "\t# 保存到变量\n"
	code += "\tif save_to_variable.is_empty():\n"
	code += "\t\tset_error(\"保存变量名不能为空\")\n"
	code += "\t\tfinished.emit()\n"
	code += "\t\treturn\n\n"

	code += "\tmatch save_to_scope:\n"
	code += "\t\tBaseVariable.VariableScope.LOCAL, BaseVariable.VariableScope.GLOBAL:\n"
	code += "\t\t\tVariableOperations.set_variable(context, save_to_variable, save_to_scope, value)\n"
	code += "\t\tBaseVariable.VariableScope.SCOPE:\n"
	code += "\t\t\tif scope_source == ScopeSource.NEAREST:\n"
	code += "\t\t\t\tVariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, value)\n"
	code += "\t\t\telse:\n"
	code += "\t\t\t\tvar utils_scope_source = scope_source as VariableScopeUtils.ScopeSource\n"
	code += "\t\t\t\tvar scope_container = VariableScopeUtils.get_scope_container_by_source(context, utils_scope_source, custom_scope_id, save_target_node_path)\n"
	code += "\t\t\t\tif scope_container == null:\n"
	code += "\t\t\t\t\tset_error(\"找不到作用域容器\")\n"
	code += "\t\t\t\t\tfinished.emit()\n"
	code += "\t\t\t\t\treturn\n"
	code += "\t\t\t\tscope_container.set_variable(save_to_variable, value)\n\n"

	code += "\t_on_execution_completed()\n\n"

	return code

## 生成 GET 指令的 _validate_property 方法
## 控制作用域相关属性的显隐（内联生成，不复用 InstructionGenerator 的方法）
static func _generate_get_validate_property_method() -> String:
	var code = "func _validate_property(property: Dictionary) -> void:\n"
	# 非 SCOPE 作用域时隐藏 scope_source / custom_scope_id / save_target_node_path
	code += "\t# 非 SCOPE 作用域时隐藏作用域来源属性\n"
	code += "\tif save_to_scope != BaseVariable.VariableScope.SCOPE:\n"
	code += "\t\tif property.name in [\"scope_source\", \"custom_scope_id\", \"save_target_node_path\"]:\n"
	code += "\t\t\tproperty.usage = PROPERTY_USAGE_NO_EDITOR\n"
	code += "\t\t\treturn\n\n"
	# SCOPE 作用域下进一步细化（使用 VariableScopeUtils）
	code += "\t# SCOPE 作用域下使用 VariableScopeUtils 控制属性显隐\n"
	code += "\tif save_to_scope == BaseVariable.VariableScope.SCOPE:\n"
	code += "\t\tVariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)\n\n"

	return code
