## ButtonAutoName
## 自动将按钮文本设置为节点名称的脚本
## 支持驼峰命名转空格分隔（例如：StartGame → Start Game）
@tool
class_name FuseButton
extends Button

## 按钮节点引用
var button: Button

## 是否在 _ready 时自动设置文本
@export var auto_set_on_ready: bool = true

## 自定义前缀（会被移除）
@export var remove_prefixes: Array[String] = ["btn_", "Button"]

## 自定义后缀（会被移除）
@export var remove_suffixes: Array[String] = ["_btn", "Button"]


func _ready() -> void:
	button = self

	if Engine.is_editor_hint():
		if auto_set_on_ready:
			_set_button_text()

		# 连接 rename 信号（如果按钮有这个信号）
		if button.has_signal("renamed") and not button.is_connected("renamed", _on_button_rename):
			button.renamed.connect(_on_button_rename)


## 当按钮发出 rename 信号时调用
func _on_button_rename() -> void:
	_set_button_text()


## 设置按钮文本
func _set_button_text() -> void:
	if not button:
		return

	var node_name: String = button.name
	var display_text: String = _format_node_name(node_name)
	button.text = display_text


## 格式化节点名称为显示文本
## 例如：StartGame → Start Game, btn_play → Play
func _format_node_name(name: String) -> String:
	var formatted: String = name

	# 移除前缀
	for prefix in remove_prefixes:
		if formatted.begins_with(prefix):
			formatted = formatted.substr(prefix.length())
			break

	# 移除后缀
	for suffix in remove_suffixes:
		if formatted.ends_with(suffix):
			formatted = formatted.substr(0, formatted.length() - suffix.length())
			break

	# 处理驼峰命名和下划线命名
	formatted = _camel_case_to_spaced(formatted)

	return formatted


## 将驼峰命名转换为空格分隔
## 例如：StartGame → Start Game, myVariable → my Variable
func _camel_case_to_spaced(text: String) -> String:
	if text.is_empty():
		return text

	var result: String = ""
	var chars: PackedStringArray = text.split("")

	for i in range(chars.size()):
		var c: String = chars[i]

		# 在大写字母前插入空格（除了第一个字符）
		if i > 0:
			# 检查是否是大写字母且前一个字符是小写字母或数字
			var prev_char: String = chars[i - 1]
			var is_upper: bool = c.to_upper() == c and c.to_lower() != c
			var prev_is_lower: bool = prev_char.to_lower() == prev_char and prev_char.to_upper() != prev_char
			var prev_is_digit: bool = prev_char.is_valid_int()

			# 驼峰命名：小写/数字后跟大写
			if is_upper and (prev_is_lower or prev_is_digit):
				result += " "

			# 全大写缩写后跟小写：XMLParser → XML Parser
			if i > 1:
				var prev_prev_char: String = chars[i - 2]
				var prev_prev_is_upper: bool = prev_prev_char.to_upper() == prev_prev_char and prev_prev_char.to_lower() != prev_prev_char
				var prev_is_upper: bool = prev_char.to_upper() == prev_char and prev_char.to_lower() != prev_char

				if prev_prev_is_upper and prev_is_upper and not is_upper:
					# 移除之前添加的空格（如果有）
					if result.length() > 0 and result[result.length() - 1] == " ":
						result = result.substr(0, result.length() - 1)
					result += " "

		# 下划线替换为空格
		if c == "_":
			result += " "
		else:
			result += c

	# 清理多余的空格
	result = result.replace("  ", " ")
	return result.strip_edges()
