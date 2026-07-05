@tool
extends Control
class_name StaticAnalysisPanel

## 静态分析面板
##
## 提供用户友好的界面来执行指令序列的静态分析，
## 显示分析结果和建议。

var analyze_button: Button
var results_panel: RichTextLabel
var status_label: Label
var progress_bar: ProgressBar
var clear_button: Button
var export_button: Button

# UI 组件
var main_container: VBoxContainer
var button_container: HBoxContainer
var results_scroll: ScrollContainer

# 状态
var is_analyzing: bool = false
var current_results: Dictionary = {}

# 本地化
var _fuse_localization_class: RefCounted = null  # 缓存本地化类引用

func _ready() -> void:
	# 一次性加载本地化类
	if _fuse_localization_class == null:
		_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 刷新语言设置
	_refresh_locale_if_needed()

	_setup_ui()
	_update_ui_state()

## 刷新语言设置
##
## 每次打开静态分析面板时，重新检测编辑器语言并更新本地化系统
func _refresh_locale_if_needed() -> void:
	if not _fuse_localization_class or not _fuse_localization_class.has_method("set_locale"):
		return

	# 检测编辑器语言
	if OS.has_feature("editor"):
		var editor_settings = EditorInterface.get_editor_settings()
		if editor_settings:
			var editor_locale = editor_settings.get("interface/editor/editor_language")
			if editor_locale:
				# 根据编辑器语言设置 FuseLocalization
				if editor_locale.begins_with("en"):
					_fuse_localization_class.set_locale("en_US")
				elif editor_locale.begins_with("zh"):
					_fuse_localization_class.set_locale("zh_CN")

## 设置UI界面
func _setup_ui() -> void:
	# 创建主容器
	main_container = VBoxContainer.new()
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_container)

	# 创建标题
	var title_label = Label.new()
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		title_label.text = _fuse_localization_class.translate("FUSE_UI_STATIC_ANALYSIS_TITLE")
	else:
		title_label.text = "静态分析工具"  # 回退文本
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0))
	main_container.add_child(title_label)

	# 创建按钮容器
	button_container = HBoxContainer.new()
	button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(button_container)

	# 创建分析按钮
	analyze_button = Button.new()
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		analyze_button.text = _fuse_localization_class.translate("FUSE_UI_BTN_ANALYZE_INSTRUCTIONS")
	else:
		analyze_button.text = "分析指令序列"  # 回退文本
	analyze_button.pressed.connect(_on_analyze_pressed)
	button_container.add_child(analyze_button)

	# 创建清除按钮
	clear_button = Button.new()
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		clear_button.text = _fuse_localization_class.translate("FUSE_UI_BTN_CLEAR_RESULTS")
	else:
		clear_button.text = "清除结果"  # 回退文本
	clear_button.pressed.connect(_on_clear_pressed)
	button_container.add_child(clear_button)

	# 创建导出按钮
	export_button = Button.new()
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		export_button.text = _fuse_localization_class.translate("FUSE_UI_BTN_EXPORT_REPORT")
	else:
		export_button.text = "导出报告"  # 回退文本
	export_button.pressed.connect(_on_export_pressed)
	button_container.add_child(export_button)

	# 创建状态标签
	status_label = Label.new()
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		status_label.text = _fuse_localization_class.translate("FUSE_UI_STATUS_READY")
	else:
		status_label.text = "就绪"  # 回退文本
	main_container.add_child(status_label)

	# 创建进度条
	progress_bar = ProgressBar.new()
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.visible = false
	main_container.add_child(progress_bar)

	# 创建结果滚动容器
	results_scroll = ScrollContainer.new()
	results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(results_scroll)

	# 创建结果面板
	results_panel = RichTextLabel.new()
	results_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_panel.fit_content = true
	results_panel.scroll_active = true
	results_scroll.add_child(results_panel)

	# 设置初始文本
	_display_welcome_message()

## 显示欢迎信息
func _display_welcome_message() -> void:
	var welcome_text = ""

	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		welcome_text = "[color=cyan]%s[/color]\n\n" % _fuse_localization_class.translate("FUSE_UI_WELCOME_TITLE")
		welcome_text += _fuse_localization_class.translate("FUSE_UI_WELCOME_DESCRIPTION") + "\n"
		welcome_text += "• " + _fuse_localization_class.translate("FUSE_UI_WELCOME_FEATURE_1") + "\n"
		welcome_text += "• " + _fuse_localization_class.translate("FUSE_UI_WELCOME_FEATURE_2") + "\n"
		welcome_text += "• " + _fuse_localization_class.translate("FUSE_UI_WELCOME_FEATURE_3") + "\n"
		welcome_text += "• " + _fuse_localization_class.translate("FUSE_UI_WELCOME_FEATURE_4") + "\n\n"
		welcome_text += _fuse_localization_class.translate("FUSE_UI_WELCOME_INSTRUCTION")
	else:
		# 回退文本
		welcome_text = "[color=cyan]欢迎使用静态分析工具[/color]\n\n"
		welcome_text += "此工具可以帮助您在开发阶段发现潜在问题：\n"
		welcome_text += "• 变量引用错误\n"
		welcome_text += "• 潜在死循环\n"
		welcome_text += "• 性能问题\n"
		welcome_text += "• 资源使用问题\n\n"
		welcome_text += "点击'分析指令序列'按钮开始分析。"

	results_panel.text = welcome_text

## 分析按钮点击处理
func _on_analyze_pressed() -> void:
	if is_analyzing:
		return

	var action_runner = _get_current_action_runner()
	if not action_runner:
		var error_msg = "没有找到 ActionRunner"
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			error_msg = _fuse_localization_class.translate("FUSE_UI_ERROR_NO_ACTION_RUNNER")
		_display_error(error_msg)
		return

	if action_runner.instructions.is_empty():
		var error_msg = "没有指令可供分析"
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			error_msg = _fuse_localization_class.translate("FUSE_UI_ERROR_NO_INSTRUCTIONS")
		_display_error(error_msg)
		return

	# 开始分析
	_start_analysis(action_runner.instructions)

## 开始分析
func _start_analysis(instructions: Array[BaseInstruction]) -> void:
	is_analyzing = true
	_update_ui_state()

	# 显示进度
	progress_bar.visible = true
	progress_bar.value = 0
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		status_label.text = _fuse_localization_class.translate("FUSE_UI_STATUS_ANALYZING")
	else:
		status_label.text = "正在分析指令序列..."  # 回退文本

	# 模拟分析进度
	for i in range(10):
		progress_bar.value = (i + 1) * 10
		await get_tree().create_timer(0.05).timeout

	# 执行实际分析
	var instruction_validator = load("res://addons/fuse/editor/static_analysis/instruction_validator.gd")
	var results = instruction_validator.validate_instruction_sequence(instructions)
	current_results = results

	# 显示结果
	_display_results(results)

	# 完成分析
	is_analyzing = false
	progress_bar.visible = false
	_update_ui_state()

	# 构建完成消息
	var completion_msg = ""
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		completion_msg = _fuse_localization_class.translate("FUSE_UI_STATUS_ANALYSIS_COMPLETE") % [
			results.errors.size(), results.warnings.size(), results.suggestions.size()
		]
	else:
		completion_msg = "分析完成 - 发现 %d 个错误，%d 个警告，%d 个建议" % [
			results.errors.size(), results.warnings.size(), results.suggestions.size()
		]
	status_label.text = completion_msg

## 显示分析结果
func _display_results(results: Dictionary) -> void:
	var text = ""

	# 总体状态
	if results.valid:
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			text += "[color=green]✓ %s[/color]\n\n" % _fuse_localization_class.translate("FUSE_UI_VALIDATION_PASSED")
		else:
			text += "[color=green]✓ 指令序列验证通过[/color]\n\n"  # 回退文本
	else:
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			text += "[color=red]✗ %s[/color]\n\n" % _fuse_localization_class.translate("FUSE_UI_VALIDATION_FAILED")
		else:
			text += "[color=red]✗ 指令序列验证失败[/color]\n\n"  # 回退文本

	# 错误
	if results.errors.size() > 0:
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			text += "[color=red]%s (%d):[/color]\n" % [_fuse_localization_class.translate("FUSE_UI_ERRORS"), results.errors.size()]
		else:
			text += "[color=red]错误 (%d):[/color]\n" % results.errors.size()
		for error in results.errors:
			text += "• [color=red]%s[/color]\n" % error
		text += "\n"

	# 警告
	if results.warnings.size() > 0:
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			text += "[color=yellow]%s (%d):[/color]\n" % [_fuse_localization_class.translate("FUSE_UI_WARNINGS"), results.warnings.size()]
		else:
			text += "[color=yellow]警告 (%d):[/color]\n" % results.warnings.size()
		for warning in results.warnings:
			text += "• [color=yellow]%s[/color]\n" % warning
		text += "\n"

	# 建议
	if results.suggestions.size() > 0:
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			text += "[color=cyan]%s (%d):[/color]\n" % [_fuse_localization_class.translate("FUSE_UI_SUGGESTIONS"), results.suggestions.size()]
		else:
			text += "[color=cyan]建议 (%d):[/color]\n" % results.suggestions.size()
		for suggestion in results.suggestions:
			text += "• [color=cyan]%s[/color]\n" % suggestion
		text += "\n"

	# 统计信息
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		text += "[color=gray]%s:[/color]\n" % _fuse_localization_class.translate("FUSE_UI_STATISTICS")
		text += "• %s: %d\n" % [_fuse_localization_class.translate("FUSE_UI_TOTAL_INSTRUCTIONS"), _get_instruction_count()]
		var validation_status = _fuse_localization_class.translate("FUSE_UI_STATUS_PASSED") if results.valid else _fuse_localization_class.translate("FUSE_UI_STATUS_FAILED")
		text += "• %s: %s\n" % [_fuse_localization_class.translate("FUSE_UI_VALIDATION_STATUS"), validation_status]
		text += "• %s: %d\n" % [_fuse_localization_class.translate("FUSE_UI_TOTAL_ISSUES"), (results.errors.size() + results.warnings.size())]
	else:
		# 回退文本
		text += "[color=gray]统计信息:[/color]\n"
		text += "• 总指令数: %d\n" % _get_instruction_count()
		text += "• 验证状态: %s\n" % ("通过" if results.valid else "失败")
		text += "• 问题总数: %d\n" % (results.errors.size() + results.warnings.size())

	results_panel.text = text

## 显示错误信息
func _display_error(message: String) -> void:
	var error_prefix = "错误"
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		error_prefix = _fuse_localization_class.translate("FUSE_UI_ERROR_PREFIX")
	results_panel.text = "[color=red]%s: %s[/color]" % [error_prefix, message]
	status_label.text = "%s: %s" % [error_prefix, message]

## 清除按钮点击处理
func _on_clear_pressed() -> void:
	results_panel.text = ""
	current_results = {}
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		status_label.text = _fuse_localization_class.translate("FUSE_UI_STATUS_CLEARED")
	else:
		status_label.text = "结果已清除"  # 回退文本
	_display_welcome_message()

## 导出按钮点击处理
func _on_export_pressed() -> void:
	if current_results.is_empty():
		var error_msg = "没有可导出的分析结果"
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			error_msg = _fuse_localization_class.translate("FUSE_UI_ERROR_NO_RESULTS")
		_display_error(error_msg)
		return

	# 生成报告内容
	var report = _generate_report(current_results)

	# 保存到文件
	var file_path = "user://static_analysis_report_%s.txt" % Time.get_time_string_from_system().replace(":", "-")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(report)
		file.close()
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			status_label.text = _fuse_localization_class.translate("FUSE_UI_STATUS_EXPORTED") % file_path
		else:
			status_label.text = "报告已导出到: %s" % file_path  # 回退文本
	else:
		var error_msg = "无法保存报告文件"
		if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
			error_msg = _fuse_localization_class.translate("FUSE_UI_ERROR_SAVE_FAILED")
		_display_error(error_msg)

## 生成分析报告
func _generate_report(results: Dictionary) -> String:
	var report = ""

	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		report = _fuse_localization_class.translate("FUSE_UI_REPORT_TITLE") + "\n"
		report += _fuse_localization_class.translate("FUSE_UI_REPORT_TIME") % Time.get_time_string_from_system()
		report += str("=").repeat(50) + "\n\n"

		# 总体状态
		var validation_result = _fuse_localization_class.translate("FUSE_UI_STATUS_PASSED") if results.valid else _fuse_localization_class.translate("FUSE_UI_STATUS_FAILED")
		report += _fuse_localization_class.translate("FUSE_UI_REPORT_VALIDATION_RESULT") % validation_result
		report += _fuse_localization_class.translate("FUSE_UI_REPORT_ERROR_COUNT") % results.errors.size()
		report += _fuse_localization_class.translate("FUSE_UI_REPORT_WARNING_COUNT") % results.warnings.size()
		report += _fuse_localization_class.translate("FUSE_UI_REPORT_SUGGESTION_COUNT") % results.suggestions.size() + "\n"

		# 详细内容
		if results.errors.size() > 0:
			report += _fuse_localization_class.translate("FUSE_UI_REPORT_ERROR_DETAILS") + ":\n"
			for i in range(results.errors.size()):
				report += "%d. %s\n" % [i + 1, results.errors[i]]
			report += "\n"

		if results.warnings.size() > 0:
			report += _fuse_localization_class.translate("FUSE_UI_REPORT_WARNING_DETAILS") + ":\n"
			for i in range(results.warnings.size()):
				report += "%d. %s\n" % [i + 1, results.warnings[i]]
			report += "\n"

		if results.suggestions.size() > 0:
			report += _fuse_localization_class.translate("FUSE_UI_REPORT_SUGGESTION_DETAILS") + ":\n"
			for i in range(results.suggestions.size()):
				report += "%d. %s\n" % [i + 1, results.suggestions[i]]
			report += "\n"

		report += _fuse_localization_class.translate("FUSE_UI_REPORT_COMPLETED") + "\n"
	else:
		# 回退文本
		report = "Fuse 静态分析报告\n"
		report += "生成时间: %s\n" % Time.get_time_string_from_system()
		report += str("=").repeat(50) + "\n\n"

		# 总体状态
		report += "验证结果: %s\n" % ("通过" if results.valid else "失败")
		report += "错误数: %d\n" % results.errors.size()
		report += "警告数: %d\n" % results.warnings.size()
		report += "建议数: %d\n\n" % results.suggestions.size()

		# 详细内容
		if results.errors.size() > 0:
			report += "错误详情:\n"
			for i in range(results.errors.size()):
				report += "%d. %s\n" % [i + 1, results.errors[i]]
			report += "\n"

		if results.warnings.size() > 0:
			report += "警告详情:\n"
			for i in range(results.warnings.size()):
				report += "%d. %s\n" % [i + 1, results.warnings[i]]
			report += "\n"

		if results.suggestions.size() > 0:
			report += "建议详情:\n"
			for i in range(results.suggestions.size()):
				report += "%d. %s\n" % [i + 1, results.suggestions[i]]
			report += "\n"

		report += "分析完成\n"

	return report

## 更新UI状态
func _update_ui_state() -> void:
	analyze_button.disabled = is_analyzing
	clear_button.disabled = is_analyzing
	export_button.disabled = is_analyzing or current_results.is_empty()

## 获取当前ActionRunner
func _get_current_action_runner() -> ActionRunner:
	# 尝试从编辑器中获取当前的ActionRunner
	var editor_interface = Engine.get_singleton("EditorInterface")
	if editor_interface:
		var edited_scene_root = editor_interface.get_edited_scene_root()
		if edited_scene_root:
			# 在场景树中查找ActionRunner
			var runners = edited_scene_root.find_children("*", "ActionRunner", true, false)
			if runners.size() > 0:
				return runners[0]
	
	# 回退方案：尝试从选择的节点获取
	var selection = editor_interface.get_selection()
	if selection:
		var selected_nodes = selection.get_selected_nodes()
		if selected_nodes.size() > 0:
			var node = selected_nodes[0]
			# 检查节点本身是否是ActionRunner
			if node is ActionRunner:
				return node
			# 检查子节点
			var child_runners = node.find_children("*", "ActionRunner", true, false)
			if child_runners.size() > 0:
				return child_runners[0]
	
	return null

## 获取指令数量
func _get_instruction_count() -> int:
	var action_runner = _get_current_action_runner()
	if action_runner:
		return action_runner.instructions.size()
	return 0

## 设置日志级别
func set_log_level(level: FuseLogger.LogLevel):
	# 可以在这里设置日志级别
	pass

## 获取面板信息
func get_panel_info() -> Dictionary:
	return {
		"is_analyzing": is_analyzing,
		"has_results": not current_results.is_empty(),
		"instruction_count": _get_instruction_count(),
		"error_count": current_results.get("errors", []).size() if not current_results.is_empty() else 0,
		"warning_count": current_results.get("warnings", []).size() if not current_results.is_empty() else 0,
		"suggestion_count": current_results.get("suggestions", []).size() if not current_results.is_empty() else 0
	}
