# 文件：addons/fuse/editor/instruction_generator/conflict_handler.gd
@tool
class_name ConflictHandler extends RefCounted

## 冲突处理器
## 处理指令文件生成时的命名冲突

## 检查文件是否存在
## @param class_name: 目标类名
## @param method_name: 方法名
## @param output_dir: 输出目录
## @return: 冲突信息字典
static func check_conflict(p_class_name: String, p_method_name: String, p_output_dir: String, p_use_variables: bool = false) -> Dictionary:
	var file_name = generate_file_name(p_class_name, p_method_name, p_use_variables)
	var file_path = p_output_dir.path_join(file_name)

	if FileAccess.file_exists(file_path):
		return {
			"exists": true,
			"path": file_path,
			"action": "ask"  # ask, overwrite, skip, rename
		}

	return {"exists": false, "path": file_path}

## 生成文件名
## @param class_name: 目标类名
## @param method_name: 方法名
## @return: 文件名（不含路径）
static func generate_file_name(p_class_name: String, p_method_name: String, p_use_variables: bool = false) -> String:
	var safe_class = _to_snake_case(p_class_name)
	var safe_method = _to_snake_case(p_method_name)
	if p_use_variables:
		return "%s_%s_with_variable.gd" % [safe_class, safe_method]
	return "%s_%s.gd" % [safe_class, safe_method]

## 生成属性指令文件名
## @param p_class_name: 目标类名
## @param p_property_name: 属性名
## @param p_mode: 模式（"set" 或 "get"）
## @param p_use_variables: 是否使用变量
## @return: 文件名（不含路径）
static func generate_property_file_name(p_class_name: String, p_property_name: String, p_mode: String, p_use_variables: bool = false) -> String:
	var safe_class = _to_snake_case(p_class_name)
	var safe_property = _to_snake_case(p_property_name)

	match p_mode:
		"set":
			if p_use_variables:
				return "set_%s_%s_with_variable.gd" % [safe_class, safe_property]
			return "set_%s_%s.gd" % [safe_class, safe_property]
		"get":
			return "get_%s_%s.gd" % [safe_class, safe_property]
		_:
			push_warning("ConflictHandler: 未知的属性模式 '%s'，默认使用 set" % p_mode)
			return "%s_%s.gd" % [safe_class, safe_property]

## 检查属性指令文件是否存在
## @param p_class_name: 目标类名
## @param p_property_name: 属性名
## @param p_mode: 模式（"set" 或 "get"）
## @param p_output_dir: 输出目录
## @param p_use_variables: 是否使用变量
## @return: 冲突信息字典
static func check_property_conflict(p_class_name: String, p_property_name: String, p_mode: String, p_output_dir: String, p_use_variables: bool = false) -> Dictionary:
	var file_name = generate_property_file_name(p_class_name, p_property_name, p_mode, p_use_variables)
	var file_path = p_output_dir.path_join(file_name)

	if FileAccess.file_exists(file_path):
		return {
			"has_conflict": true,
			"file_path": file_path,
			"file_name": file_name,
			"action": "ask"  # ask, overwrite, skip, rename
		}

	return {"has_conflict": false, "file_path": file_path, "file_name": file_name}

## 生成唯一文件名
## @param class_name: 目标类名
## @param method_name: 方法名
## @param output_dir: 输出目录
## @return: 唯一文件名
static func generate_unique_file_name(p_class_name: String, p_method_name: String, p_output_dir: String) -> String:
	var base_name = generate_file_name(p_class_name, p_method_name)
	var file_path = p_output_dir.path_join(base_name)

	if not FileAccess.file_exists(file_path):
		return base_name

	# 添加数字后缀
	var counter = 1
	while true:
		var ext = base_name.get_extension()
		var base = base_name.get_basename()
		var new_name = "%s_%d.%s" % [base, counter, ext]
		var new_path = p_output_dir.path_join(new_name)

		if not FileAccess.file_exists(new_path):
			return new_name

		counter += 1
		if counter > 100:
			break

	return base_name

## 转换为 snake_case
## 处理规则：大写字母前插入下划线（除非前一个字符也是大写或非字母）
## 示例：Sprite2D → sprite_2d, RigidBody2D → rigid_body_2d, setPosition → set_position
static func _to_snake_case(s: String) -> String:
	var result := ""
	for i in range(s.length()):
		var c := s[i]
		var is_upper := c == c.to_upper()
		var is_alpha_lower := c >= "a" and c <= "z"
		if is_upper and c >= "A" and c <= "Z":
			# 在大写字母前插入下划线，但跳过连续大写（缩写词）
			if i > 0:
				var prev := s[i - 1]
				if prev >= "a" and prev <= "z":
					result += "_"
		result += c.to_lower()
	return result
