@tool
extends Control
class_name DebugVisualizer

## 调试可视化面板
##
## 提供图形化界面来显示执行历史、性能指标和调试信息，
## 帮助开发者理解和调试复杂的指令序列执行流程。

var execution_tracker: ExecutionTracker
var execution_tree: Tree
var detail_panel: RichTextLabel
var control_panel: HBoxContainer
var refresh_button: Button
var clear_button: Button
var export_button: Button
var auto_refresh_check: CheckBox
var performance_chart: Control

# UI 组件
var main_split: HSplitContainer
var left_panel: VBoxContainer
var right_panel: VBoxContainer
var tree_scroll: ScrollContainer
var detail_scroll: ScrollContainer

# 状态
var auto_refresh: bool = false
var refresh_timer: Timer
var selected_execution_index: int = -1
var selected_step_index: int = -1

# 本地化
var _fuse_localization_class: RefCounted = null  # 缓存本地化类引用

func _ready() -> void:
	# 一次性加载本地化类
	if _fuse_localization_class == null:
		_fuse_localization_class = load("res://addons/fuse/localization/fuse_localization.gd")

	# 刷新语言设置
	_refresh_locale_if_needed()

	execution_tracker = ExecutionTracker.new()
	_setup_ui()
	_setup_timer()
	_update_display()

## 刷新语言设置
##
## 每次打开调试可视化器时，重新检测编辑器语言并更新本地化系统
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

## 翻译指定键
##
## 本地化类未就绪时返回键名（与 FuseLocalization.translate 缺键行为一致）；
## 带格式占位符的键（CSV 值内为 %d/%s/%.1f 风格）在调用点用 % 运算符填参
func _t(key: String) -> String:
	if _fuse_localization_class and _fuse_localization_class.has_method("translate"):
		return str(_fuse_localization_class.translate(key))
	return key

## 设置UI界面
func _setup_ui() -> void:
	# 创建主分割容器
	main_split = HSplitContainer.new()
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.split_offset = 300
	add_child(main_split)

	# 创建左侧面板
	left_panel = VBoxContainer.new()
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.add_child(left_panel)

	# 创建控制面板
	control_panel = HBoxContainer.new()
	control_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_child(control_panel)

	# 创建刷新按钮
	refresh_button = Button.new()
	refresh_button.text = _t("FUSE_UI_BTN_REFRESH")
	refresh_button.pressed.connect(_on_refresh_pressed)
	control_panel.add_child(refresh_button)

	# 创建清除按钮
	clear_button = Button.new()
	clear_button.text = _t("FUSE_UI_BTN_CLEAR")
	clear_button.pressed.connect(_on_clear_pressed)
	control_panel.add_child(clear_button)

	# 创建导出按钮
	export_button = Button.new()
	export_button.text = _t("FUSE_UI_BTN_EXPORT")
	export_button.pressed.connect(_on_export_pressed)
	control_panel.add_child(export_button)

	# 创建自动刷新复选框
	auto_refresh_check = CheckBox.new()
	auto_refresh_check.text = _t("FUSE_UI_DEBUG_AUTO_REFRESH")
	auto_refresh_check.toggled.connect(_on_auto_refresh_toggled)
	control_panel.add_child(auto_refresh_check)

	# 创建执行树滚动容器
	tree_scroll = ScrollContainer.new()
	tree_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_child(tree_scroll)

	# 创建执行树
	execution_tree = Tree.new()
	execution_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	execution_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	execution_tree.item_selected.connect(_on_tree_item_selected)
	tree_scroll.add_child(execution_tree)

	# 创建右侧面板
	right_panel = VBoxContainer.new()
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.add_child(right_panel)

	# 创建详情滚动容器
	detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_child(detail_scroll)

	# 创建详情面板
	detail_panel = RichTextLabel.new()
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.fit_content = true
	detail_panel.scroll_active = true
	detail_scroll.add_child(detail_panel)

	# 创建性能图表占位符
	performance_chart = Control.new()
	performance_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	performance_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	performance_chart.custom_minimum_size = Vector2(0, 200)
	right_panel.add_child(performance_chart)

	# 设置初始文本
	_display_welcome_message()

## 设置定时器
func _setup_timer() -> void:
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 1.0
	refresh_timer.timeout.connect(_on_refresh_timer_timeout)
	add_child(refresh_timer)

## 显示欢迎信息
func _display_welcome_message() -> void:
	var welcome_text = "[color=cyan]%s[/color]\n\n" % _t("FUSE_UI_DEBUG_WELCOME_TITLE")
	welcome_text += _t("FUSE_UI_DEBUG_WELCOME_DESCRIPTION") + "\n"
	welcome_text += "• " + _t("FUSE_UI_DEBUG_FEATURE_1") + "\n"
	welcome_text += "• " + _t("FUSE_UI_DEBUG_FEATURE_2") + "\n"
	welcome_text += "• " + _t("FUSE_UI_DEBUG_FEATURE_3") + "\n"
	welcome_text += "• " + _t("FUSE_UI_DEBUG_FEATURE_4") + "\n\n"
	welcome_text += _t("FUSE_UI_DEBUG_WELCOME_INSTRUCTION")

	detail_panel.text = welcome_text

## 更新显示
func _update_display() -> void:
	_update_execution_tree()
	_update_detail_panel()

## 更新执行树
func _update_execution_tree() -> void:
	execution_tree.clear()

	var history = execution_tracker.get_execution_history()
	if history.is_empty():
		var root = execution_tree.create_item()
		root.set_text(0, _t("FUSE_UI_DEBUG_NO_HISTORY"))
		return

	var root = execution_tree.create_item()
	root.set_text(0, _t("FUSE_UI_DEBUG_HISTORY_TITLE"))

	for i in range(history.size()):
		var execution = history[i]
		var exec_item = execution_tree.create_item(root)

		# 设置执行项文本
		var exec_text = _t("FUSE_UI_DEBUG_EXECUTION_ITEM") % [i + 1, execution.total_time / 1000.0]
		if execution.has("stats"):
			var stats = execution.stats
			exec_text += " - " + _t("FUSE_UI_DEBUG_EXEC_STATS") % [stats.instruction_count, stats.error_count]

		exec_item.set_text(0, exec_text)

		# 根据执行结果设置颜色
		if execution.has("stats"):
			var stats = execution.stats
			if stats.error_count > 0:
				exec_item.set_custom_color(0, Color(1.0, 0.3, 0.3))  # 红色表示有错误
			elif stats.performance_issues > 0:
				exec_item.set_custom_color(0, Color(1.0, 0.8, 0.2))  # 黄色表示有性能问题
			else:
				exec_item.set_custom_color(0, Color(0.2, 1.0, 0.2))  # 绿色表示成功

		# 添加步骤
		if execution.has("steps"):
			for j in range(execution.steps.size()):
				var step = execution.steps[j]
				var step_item = execution_tree.create_item(exec_item)

				var step_text = ""
				var step_color = Color(1.0, 1.0, 1.0)

				match step.type:
					"instruction_start":
						step_text = _t("FUSE_UI_DEBUG_STEP_START") % step.instruction
						step_color = Color(0.8, 0.8, 1.0)  # 浅蓝色
					"instruction_complete":
						var success_symbol = "✓" if step.success else "✗"
						var time_text = "%.3fs" % step.execution_time if step.execution_time > 0 else ""
						step_text = _t("FUSE_UI_DEBUG_STEP_COMPLETE") % [success_symbol, step.instruction, time_text]
						if step.has_error:
							step_color = Color(1.0, 0.3, 0.3)  # 红色
						elif not step.success:
							step_color = Color(1.0, 0.5, 0.2)  # 橙色
						else:
							step_color = Color(0.2, 1.0, 0.2)  # 绿色
					"error":
						step_text = _t("FUSE_UI_DEBUG_STEP_ERROR") % step.error_message
						step_color = Color(1.0, 0.2, 0.2)  # 红色
					"performance_bottleneck":
						step_text = _t("FUSE_UI_DEBUG_STEP_PERFORMANCE") % [step.bottleneck_type, step.severity]
						step_color = Color(1.0, 0.8, 0.2)  # 黄色
					"custom_event":
						step_text = _t("FUSE_UI_DEBUG_STEP_EVENT") % step.event_type
						step_color = Color(0.8, 0.8, 0.8)  # 灰色

				step_item.set_text(0, step_text)
				step_item.set_custom_color(0, step_color)

				# 存储索引信息用于详情显示
				step_item.set_metadata(0, {"execution_index": i, "step_index": j})

## 更新详情面板
func _update_detail_panel() -> void:
	if selected_execution_index < 0:
		_display_welcome_message()
		return

	var history = execution_tracker.get_execution_history()
	if selected_execution_index >= history.size():
		return

	var execution = history[selected_execution_index]
	var text = _format_execution_details(execution)

	# 如果有选中的步骤，添加步骤详情
	if selected_step_index >= 0 and execution.has("steps"):
		if selected_step_index < execution.steps.size():
			var step = execution.steps[selected_step_index]
			text += "\n\n" + _format_step_details(step)

	detail_panel.text = text

## 格式化执行详情
func _format_execution_details(execution: Dictionary) -> String:
	var text = "[color=cyan]%s[/color]\n" % _t("FUSE_UI_DEBUG_EXEC_DETAILS_TITLE")
	text += str("=").repeat(40) + "\n\n"

	# 基本信息
	text += "[color=yellow]%s[/color]\n" % _t("FUSE_UI_DEBUG_BASIC_INFO")
	text += "• %s: %s\n" % [_t("FUSE_UI_DEBUG_START_TIME"), _format_timestamp(execution.start_time)]
	if execution.has("end_time"):
		text += "• %s: %s\n" % [_t("FUSE_UI_DEBUG_END_TIME"), _format_timestamp(execution.end_time)]
		text += "• %s: %.3f %s\n" % [
			_t("FUSE_UI_DEBUG_TOTAL_TIME"), execution.total_time / 1000.0, _t("FUSE_UI_DEBUG_SECONDS")
		]
	text += "• %s: %s\n" % [_t("FUSE_UI_DEBUG_CONTEXT_ID"), execution.get("context_id", "unknown")]
	text += "• %s: %d\n\n" % [_t("FUSE_UI_DEBUG_STEP_COUNT"), execution.steps.size()]

	# 统计信息
	if execution.has("stats"):
		var stats = execution.stats
		text += "[color=yellow]%s[/color]\n" % _t("FUSE_UI_DEBUG_STATS")
		text += "• %s: %d\n" % [_t("FUSE_UI_DEBUG_INSTRUCTION_COUNT"), stats.instruction_count]
		text += "• %s: %d\n" % [_t("FUSE_UI_DEBUG_ERROR_COUNT"), stats.error_count]
		text += "• %s: %d\n" % [_t("FUSE_UI_DEBUG_PERF_ISSUES"), stats.performance_issues]
		text += "• %s: %.1f%%\n" % [_t("FUSE_UI_DEBUG_SUCCESS_RATE"), stats.success_rate]
		text += "• %s: %.3f %s\n" % [
			_t("FUSE_UI_DEBUG_AVG_TIME"), stats.average_execution_time, _t("FUSE_UI_DEBUG_SECONDS")
		]

	# 性能指标
	if execution.has("performance_metrics"):
		var metrics = execution.performance_metrics
		text += "[color=yellow]%s[/color]\n" % _t("FUSE_UI_DEBUG_PERF_METRICS")
		if metrics.has("initial") and metrics.has("final"):
			var initial = metrics.initial
			var final = metrics.final
			var memory_diff = final.memory_usage - initial.memory_usage
			text += "• %s: %s bytes\n" % [_t("FUSE_UI_DEBUG_MEMORY_CHANGE"), _format_memory(memory_diff)]
		text += "\n"

	# 内存快照
	if execution.has("memory_snapshots") and execution.memory_snapshots.size() > 0:
		text += "[color=yellow]%s[/color]\n" % _t("FUSE_UI_DEBUG_MEMORY_SNAPSHOTS")
		for snapshot in execution.memory_snapshots:
			text += "• %s: %s\n" % [snapshot.phase, _format_memory(snapshot.static_memory)]
		text += "\n"

	return text

## 格式化步骤详情
func _format_step_details(step: Dictionary) -> String:
	var text = "[color=cyan]%s[/color]\n" % _t("FUSE_UI_DEBUG_STEP_DETAILS_TITLE")
	text += str("=").repeat(40) + "\n\n"

	# 基本信息
	text += "[color=yellow]%s[/color]\n" % _t("FUSE_UI_DEBUG_BASIC_INFO")
	text += "• %s: %s\n" % [_t("FUSE_UI_DEBUG_TYPE"), step.type]
	text += "• %s: %s\n" % [_t("FUSE_UI_DEBUG_TIME"), _format_timestamp(step.timestamp)]

	if step.has("instruction"):
		text += "• %s: %s\n" % [_t("FUSE_UI_DEBUG_INSTRUCTION"), step.instruction]

	if step.has("instruction_type"):
		text += "• %s: %s\n" % [_t("FUSE_UI_DEBUG_INSTRUCTION_TYPE"), step.instruction_type]

	if step.has("context_id"):
		text += "• %s: %s\n" % [_t("FUSE_UI_DEBUG_CONTEXT_ID"), step.context_id]

	if step.has("instruction_index") and step.instruction_index >= 0:
		text += "• %s: %d\n" % [_t("FUSE_UI_DEBUG_INSTRUCTION_INDEX"), step.instruction_index]

	text += "\n"

	# 执行结果
	if step.has("success"):
		text += "[color=yellow]%s[/color]\n" % _t("FUSE_UI_DEBUG_EXECUTION_RESULT")
		var success_text = _t("FUSE_UI_DEBUG_YES") if step.success else _t("FUSE_UI_DEBUG_NO")
		text += "• %s: %s\n" % [_t("FUSE_UI_DEBUG_SUCCESS"), success_text]

		if step.has("execution_time"):
			text += "• %s: %.3f %s\n" % [
				_t("FUSE_UI_DEBUG_EXECUTION_TIME"), step.execution_time, _t("FUSE_UI_DEBUG_SECONDS")
			]

		if step.has("has_error") and step.has_error:
			text += "• %s: %s\n" % [_t("FUSE_UI_DEBUG_ERROR"), step.error_message]

		text += "\n"

	# 性能数据
	if step.has("performance_data") and step.performance_data:
		var perf_data = step.performance_data
		text += "[color=yellow]%s[/color]\n" % _t("FUSE_UI_DEBUG_PERF_DATA")
		text += "• %s: %s\n" % [_t("FUSE_UI_DEBUG_MEMORY_USAGE"), _format_memory(perf_data.memory_usage)]
		text += "• %s: %.1f%%\n" % [_t("FUSE_UI_DEBUG_CPU_USAGE"), perf_data.cpu_usage]
		text += "\n"

	# 变量状态
	if step.has("variable_state"):
		var var_state = step.variable_state
		text += "[color=yellow]%s[/color]\n" % _t("FUSE_UI_DEBUG_VARIABLE_STATE")
		if var_state.has("local_variables") and var_state.local_variables:
			text += "• %s: %d %s\n" % [
				_t("FUSE_UI_DEBUG_LOCAL_VARIABLES"),
				var_state.local_variables.size(),
				_t("FUSE_UI_DEBUG_COUNT")
			]
		if var_state.has("global_variables") and var_state.global_variables:
			text += "• %s: %d %s\n" % [
				_t("FUSE_UI_DEBUG_GLOBAL_VARIABLES"),
				var_state.global_variables.size(),
				_t("FUSE_UI_DEBUG_COUNT")
			]
		text += "\n"

	# 变量变化
	if step.has("variable_changes") and step.variable_changes:
		text += "[color=yellow]%s[/color]\n" % _t("FUSE_UI_DEBUG_VARIABLE_CHANGES")
		for change in step.variable_changes:
			text += "• %s: %s → %s\n" % [change.variable, str(change.old_value), str(change.new_value)]
		text += "\n"

	# 自定义事件数据
	if step.has("data") and step.data:
		text += "[color=yellow]%s[/color]\n" % _t("FUSE_UI_DEBUG_EVENT_DATA")
		for key in step.data:
			text += "• %s: %s\n" % [key, str(step.data[key])]
		text += "\n"

	# 错误上下文
	if step.has("context") and step.context:
		text += "[color=yellow]%s[/color]\n" % _t("FUSE_UI_DEBUG_ERROR_CONTEXT")
		for key in step.context:
			text += "• %s: %s\n" % [key, str(step.context[key])]
		text += "\n"

	return text

## 格式化时间戳
func _format_timestamp(timestamp: int) -> String:
	var elapsed = (Time.get_ticks_msec() - timestamp) / 1000.0

	if elapsed < 60:
		return _t("FUSE_UI_DEBUG_SECONDS_AGO") % elapsed
	return _t("FUSE_UI_DEBUG_MINUTES_AGO") % (elapsed / 60.0)

## 格式化内存大小
func _format_memory(bytes: int) -> String:
	if bytes < 1024:
		return "%d bytes" % bytes
	elif bytes < 1024 * 1024:
		return "%.1f KB" % (bytes / 1024.0)
	else:
		return "%.1f MB" % (bytes / (1024.0 * 1024.0))

## 树项选择处理
func _on_tree_item_selected() -> void:
	var selected = execution_tree.get_selected()
	if not selected:
		return

	# 获取元数据
	var metadata = selected.get_metadata(0)
	if metadata:
		selected_execution_index = metadata.get("execution_index", -1)
		selected_step_index = metadata.get("step_index", -1)
		_update_detail_panel()

	# 更新性能图表
	_update_performance_chart()

## 刷新按钮点击处理
func _on_refresh_pressed() -> void:
	_update_display()

## 清除按钮点击处理
func _on_clear_pressed() -> void:
	execution_tracker.clear_execution_history()
	_update_display()
	selected_execution_index = -1
	selected_step_index = -1

## 导出按钮点击处理
func _on_export_pressed() -> void:
	var file_path = "user://execution_history_%s.json" % Time.get_time_string_from_system().replace(":", "-")
	if execution_tracker.export_execution_history(file_path):
		detail_panel.text = "[color=green]%s[/color]" % (_t("FUSE_UI_DEBUG_EXPORT_SUCCESS") % file_path)
	else:
		detail_panel.text = "[color=red]%s[/color]" % _t("FUSE_UI_DEBUG_EXPORT_FAILED")

## 自动刷新切换处理
func _on_auto_refresh_toggled(toggled_on: bool) -> void:
	auto_refresh = toggled_on
	if auto_refresh:
		refresh_timer.start()
	else:
		refresh_timer.stop()

## 刷新定时器超时处理
func _on_refresh_timer_timeout() -> void:
	if auto_refresh:
		_update_display()

## 更新性能图表
func _update_performance_chart() -> void:
	# 这里可以实现实际的性能图表
	# 目前只是一个占位符
	pass

## 获取面板信息
func get_panel_info() -> Dictionary:
	var history = execution_tracker.get_execution_history()
	return {
		"execution_count": history.size(),
		"is_tracking": execution_tracker.get_tracking_config().is_tracking,
		"selected_execution": selected_execution_index,
		"selected_step": selected_step_index,
		"auto_refresh": auto_refresh
	}

## 设置跟踪配置
func set_tracking_config(config: Dictionary) -> void:
	execution_tracker.set_tracking_config(config)

## 获取跟踪配置
func get_tracking_config() -> Dictionary:
	return execution_tracker.get_tracking_config()
