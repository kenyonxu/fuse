@tool
class_name InstructionValidator extends RefCounted

## 指令验证器
##
## 提供静态分析功能，用于在开发阶段检测指令序列中的潜在问题。
## 包括变量引用验证、死循环检测、性能问题分析等。

## 验证指令序列
## 对给定的指令序列进行全面的静态分析
## @param instructions: Array[BaseInstruction] - 要验证的指令序列
## @return: Dictionary - 验证结果，包含错误、警告和建议
static func validate_instruction_sequence(instructions: Array[BaseInstruction]) -> Dictionary:
	var result = {
		"valid": true,
		"errors": [],
		"warnings": [],
		"suggestions": []
	}
	
	# 检查变量引用
	var variable_errors = _validate_variable_references(instructions)
	result.errors.append_array(variable_errors)
	
	# 检查潜在死循环
	var loop_warnings = _detect_potential_loops(instructions)
	result.warnings.append_array(loop_warnings)
	
	# 性能建议
	var performance_suggestions = _analyze_performance_issues(instructions)
	result.suggestions.append_array(performance_suggestions)
	
	result.valid = result.errors.is_empty()
	return result

## 验证变量引用
## 检查指令序列中的变量定义和使用是否一致
## @param instructions: Array[BaseInstruction] - 指令序列
## @return: Array[String] - 错误信息数组
static func _validate_variable_references(instructions: Array[BaseInstruction]) -> Array[String]:
	var errors: Array[String] = []
	var defined_variables: Dictionary = {}
	var used_variables: Dictionary = {}
	
	# 收集变量定义和使用
	for i in range(instructions.size()):
		var instruction = instructions[i]
		if not instruction:
			errors.append(FuseLocalization.translate_format("FUSE_ERROR_INSTRUCTION_INDEX_EMPTY", {"index": i}))
			continue
		
		# 获取指令定义的变量
		var defined = _get_defined_variables(instruction)
		for var_name in defined:
			if not defined_variables.has(var_name):
				defined_variables[var_name] = []
			defined_variables[var_name].append(i)
		
		# 获取指令使用的变量
		var used = _get_used_variables(instruction)
		for var_name in used:
			if not used_variables.has(var_name):
				used_variables[var_name] = []
			used_variables[var_name].append(i)
	
	# 检查未定义的变量使用
	for var_name in used_variables:
		if not defined_variables.has(var_name):
			var usage_positions = used_variables[var_name]
			var positions_str = ", ".join(usage_positions.map(func(pos): return str(pos)))
			errors.append(FuseLocalization.translate_format("FUSE_ERROR_UNDEFINED_VARIABLE_USAGE", {"variable": var_name, "positions": positions_str}))
	
	return errors

## 检测潜在死循环
## 分析指令序列中可能导致无限循环的模式
## @param instructions: Array[BaseInstruction] - 指令序列
## @return: Array[String] - 警告信息数组
static func _detect_potential_loops(instructions: Array[BaseInstruction]) -> Array[String]:
	var warnings: Array[String] = []
	
	# 简单的循环检测逻辑
	var jump_instructions = []
	for i in range(instructions.size()):
		var instruction = instructions[i]
		if not instruction:
			continue
		
		if _is_jump_instruction(instruction):
			jump_instructions.append({"index": i, "instruction": instruction})
	
	# 分析跳转指令
	for jump_info in jump_instructions:
		var target = _get_jump_target(jump_info.instruction)
		if target != null and target < jump_info.index:
			warnings.append("检测到可能的循环: 指令 %d 跳转到更早的指令 %d" % [jump_info.index, target])
	
	return warnings

## 分析性能问题
## 识别可能导致性能问题的指令模式
## @param instructions: Array[BaseInstruction] - 指令序列
## @return: Array[String] - 性能建议数组
static func _analyze_performance_issues(instructions: Array[BaseInstruction]) -> Array[String]:
	var suggestions: Array[String] = []
	
	# 检查高频操作
	var high_frequency_operations = _detect_high_frequency_operations(instructions)
	suggestions.append_array(high_frequency_operations)
	
	# 检查资源密集型操作
	var resource_intensive_ops = _detect_resource_intensive_operations(instructions)
	suggestions.append_array(resource_intensive_ops)
	
	return suggestions

## 获取指令定义的变量
## @param instruction: BaseInstruction - 指令对象
## @return: Array[String] - 定义的变量名数组
static func _get_defined_variables(instruction: BaseInstruction) -> Array[String]:
	var variables: Array[String] = []
	
	# 检查指令是否有 get_defined_variables 方法
	if instruction.has_method("get_defined_variables"):
		var result = instruction.call("get_defined_variables")
		if result is Array:
			variables.append_array(result)
	
	# 通过分析指令属性来推断定义的变量
	var script = instruction.get_script()
	if script and script.has_source_code():
		var source_code = script.source_code
		# 简单的模式匹配来检测变量定义
		var patterns = [
			'set_variable\\("([^"]+)"',
			'add_variable\\("([^"]+)"'
		]
		
		for pattern in patterns:
			var regex = RegEx.new()
			regex.compile(pattern)
			var matches = regex.search_all(source_code)
			for match in matches:
				if match.strings.size() > 1:
					var var_name = match.strings[1]
					if not variables.has(var_name):
						variables.append(var_name)
	
	return variables

## 获取指令使用的变量
## @param instruction: BaseInstruction - 指令对象
## @return: Array[String] - 使用的变量名数组
static func _get_used_variables(instruction: BaseInstruction) -> Array[String]:
	var variables: Array[String] = []
	
	# 检查指令是否有 get_used_variables 方法
	if instruction.has_method("get_used_variables"):
		var result = instruction.call("get_used_variables")
		if result is Array:
			variables.append_array(result)
	
	# 通过分析指令属性来推断使用的变量
	var script = instruction.get_script()
	if script and script.has_source_code():
		var source_code = script.source_code
		# 简单的模式匹配来检测变量使用
		var patterns = [
			'get_variable\\("([^"]+)"',
			'has_variable\\("([^"]+)"'
		]
		
		for pattern in patterns:
			var regex = RegEx.new()
			regex.compile(pattern)
			var matches = regex.search_all(source_code)
			for match in matches:
				if match.strings.size() > 1:
					var var_name = match.strings[1]
					if not variables.has(var_name):
						variables.append(var_name)
	
	return variables

## 检查是否为跳转指令
## @param instruction: BaseInstruction - 指令对象
## @return: bool - 是否为跳转指令
static func _is_jump_instruction(instruction: BaseInstruction) -> bool:
	# 检查指令类型名称
	var script = instruction.get_script()
	if not script:
		return false
	
	# 使用 get_global_name() 替代 get_class_name()
	var instruction_class_name = script.get_global_name() if script.has_method("get_global_name") else ""
	var jump_keywords = ["jump", "goto", "branch", "loop", "repeat", "cycle"]
	
	for keyword in jump_keywords:
		if instruction_class_name.to_lower().find(keyword) >= 0:
			return true
	
	# 检查指令是否有跳转相关的方法
	if instruction.has_method("get_jump_target"):
		return true
	
	return false

## 获取跳转目标
## @param instruction: BaseInstruction - 指令对象
## @return: int - 跳转目标索引，如果没有则返回 -1
static func _get_jump_target(instruction: BaseInstruction) -> int:
	if instruction.has_method("get_jump_target"):
		var target = instruction.call("get_jump_target")
		if target is int and target >= 0:
			return target
	
	return -1

## 检测高频操作
## @param instructions: Array[BaseInstruction] - 指令序列
## @return: Array[String] - 高频操作建议数组
static func _detect_high_frequency_operations(instructions: Array[BaseInstruction]) -> Array[String]:
	var suggestions: Array[String] = []
	
	var operation_counts = {}
	
	# 统计操作类型
	for instruction in instructions:
		if not instruction:
			continue
		
		var operation_type = _get_operation_type(instruction)
		if operation_type:
			if not operation_counts.has(operation_type):
				operation_counts[operation_type] = 0
			operation_counts[operation_type] += 1
	
	# 检查高频操作
	for operation_type in operation_counts:
		var count = operation_counts[operation_type]
		if count > 10:
			suggestions.append("检测到大量 %s 操作 (%d 次)，考虑批量处理或缓存优化" % [operation_type, count])
	
	return suggestions

## 检测资源密集型操作
## @param instructions: Array[BaseInstruction] - 指令序列
## @return: Array[String] - 资源密集型操作建议数组
static func _detect_resource_intensive_operations(instructions: Array[BaseInstruction]) -> Array[String]:
	var suggestions: Array[String] = []
	
	for i in range(instructions.size()):
		var instruction = instructions[i]
		if not instruction:
			continue
		
		# 检查是否为资源密集型操作
		if _is_resource_intensive(instruction):
			suggestions.append("指令 %d (%s) 可能是资源密集型操作，考虑添加进度指示或分段处理" % [
				i, instruction.get_description()
			])
	
	return suggestions

## 获取操作类型
## @param instruction: BaseInstruction - 指令对象
## @return: String - 操作类型
static func _get_operation_type(instruction: BaseInstruction) -> String:
	var script = instruction.get_script()
	if not script:
		return ""
	
	# 使用 get_global_name() 替代 get_class_name()
	var instruction_class_name = script.get_global_name() if script.has_method("get_global_name") else ""
	
	# 简单的操作类型分类
	if instruction_class_name.to_lower().find("file") >= 0:
		return "文件操作"
	elif instruction_class_name.to_lower().find("network") >= 0:
		return "网络操作"
	elif instruction_class_name.to_lower().find("database") >= 0:
		return "数据库操作"
	elif instruction_class_name.to_lower().find("render") >= 0:
		return "渲染操作"
	elif instruction_class_name.to_lower().find("audio") >= 0:
		return "音频操作"
	
	return "通用操作"

## 检查是否为资源密集型操作
## @param instruction: BaseInstruction - 指令对象
## @return: bool - 是否为资源密集型
static func _is_resource_intensive(instruction: BaseInstruction) -> bool:
	var script = instruction.get_script()
	if not script:
		return false
	
	# 使用 get_global_name() 替代 get_class_name()
	var instruction_class_name = script.get_global_name() if script.has_method("get_global_name") else ""
	var intensive_keywords = ["large", "heavy", "complex", "batch", "bulk", "massive"]
	
	for keyword in intensive_keywords:
		if instruction_class_name.to_lower().find(keyword) >= 0:
			return true
	
	return false
