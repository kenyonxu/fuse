@icon("res://addons/fuse/icons/builtin/Debug.png")
@tool
extends BaseInstruction
class_name BreakpointInstruction

## 断点指令
##
## 调试工具指令。命中时输出变量信息到 Godot 输出窗口，可选暂停执行。
## 通过 ignore_count 跳过前 N 次命中，通过 condition 表达式实现条件断点。
## 通过 scope_source 指定作用域变量的来源。

## 作用域变量来源枚举
enum ScopeSource {
	NEAREST,        ## 最近的作用域容器（默认）
	CUSTOM_ID,      ## 指定 scope_id
	TRIGGER_SCOPE,  ## Trigger 节点上的作用域
	TARGET_NODE     ## Target 节点上的作用域
}

static func _get_instruction_metadata() -> InstructionMetadata:
	var metadata = InstructionMetadata.new()
	metadata.name_key = "FUSE_INSTRUCTION_BREAKPOINT_NAME"
	metadata.category_key = "FUSE_CATEGORY_DEBUG"
	metadata.description_key = "FUSE_INSTRUCTION_BREAKPOINT_DESC"
	metadata.keywords = ["断点", "调试", "暂停", "变量", "检查", "breakpoint", "debug", "pause", "inspect"]
	metadata.builtin_icon = "Debug"
	return metadata

# =============================================
# 参数定义
# =============================================

## 条件表达式（空字符串 = 无条件命中）
## 支持: {local:x}, {scope:x}, {global:x} 变量引用
## 例如: "{scope:health} < 50" 或 "{local:counter} > 10"
var condition: String = "":
	set(value):
		condition = value
		_update_resource_name()

## 是否启用条件断点
var use_expression_condition: bool = false:
	set(value):
		use_expression_condition = value
		notify_property_list_changed()

## 命中时是否输出变量信息到输出窗口
@export var log_variables: bool = true

## 命中时是否暂停执行（按 Enter 键恢复，仅编辑器模式有效）
@export var pause_execution: bool = true

## 忽略前 N 次命中
@export var ignore_count: int = 0

## 作用域变量的来源（同时用于变量输出和条件表达式的变量替换）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		notify_property_list_changed()

## 自定义作用域 ID（仅在 scope_source == CUSTOM_ID 时使用）
var custom_scope_id: String = ""

## 目标节点路径（仅在 scope_source == TARGET_NODE 时使用）
var target_node_path: NodePath = ""

## 自定义标签（用于在输出中标识断点）
@export var label: String = "":
	set(value):
		label = value
		_update_resource_name()

## 运行时命中计数（不序列化，每次 ActionRunner 执行开始时重置）
var _hit_count: int = 0

## 上一次的 execution_id，用于检测新的执行周期
var _last_execution_id: String = ""

# =============================================
# 初始化
# =============================================

func _init():
	_is_synchronous_hint = false
	_sync_hint_manually_set = true

func _setup_metadata():
	pass

# =============================================
# 属性列表
# =============================================

## 动态属性列表：根据 use_expression_condition 和 scope_source 显示/隐藏相关属性
func _get_property_list() -> Array[Dictionary]:
	var properties: Array = []

	# 条件断点分组
	properties.append({
		"name": "Condition",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		"name": "use_expression_condition",
		"type": TYPE_BOOL,
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if use_expression_condition:
		properties.append({
			"name": "condition",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_MULTILINE_TEXT,
			"hint_string": "",
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	# 断点设置分组
	properties.append({
		"name": "Scope Source Config",
		"type": TYPE_NIL,
		"hint": PROPERTY_HINT_NONE,
		"usage": PROPERTY_USAGE_CATEGORY
	})

	properties.append({
		"name": "scope_source",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Nearest,Custom ID,Trigger Scope,Target Node",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	if scope_source == ScopeSource.CUSTOM_ID:
		properties.append({
			"name": "custom_scope_id",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	elif scope_source == ScopeSource.TARGET_NODE:
		properties.append({
			"name": "target_node_path",
			"type": TYPE_NODE_PATH,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})

	return properties

## 属性验证：隐藏不应显示的属性
func _validate_property(property: Dictionary) -> void:
	# 隐藏 condition（当 use_expression_condition 为 false 时）
	if not use_expression_condition:
		if property.name == "condition":
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# 隐藏 scope_source 相关属性
	_hide_scope_source_properties(property, scope_source, "custom_scope_id", "target_node_path")

## 隐藏 ScopeSource 相关属性
func _hide_scope_source_properties(property: Dictionary, source: ScopeSource, custom_id_prop: String, target_node_prop: String) -> void:
	if source != ScopeSource.CUSTOM_ID:
		if property.name == custom_id_prop:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	if source != ScopeSource.TARGET_NODE:
		if property.name == target_node_prop:
			property.usage = PROPERTY_USAGE_NO_EDITOR

# =============================================
# 资源名称和描述
# =============================================

func _update_resource_name():
	resource_name = FuseLocalization.translate_format(
		"FUSE_INSTRUCTION_BREAKPOINT_RESOURCE_NAME",
		{"label": label, "condition": condition}
	)

func get_description() -> String:
	return FuseLocalization.translate_format(
		"FUSE_INSTRUCTION_BREAKPOINT_DESCRIPTION",
		{"label": label, "condition": condition}
	)

# =============================================
# 执行逻辑
# =============================================

func execute(context: ExecutionContext):
	_start_execution(context)

	# 检测新执行周期，重置命中计数
	if context and context.execution_id != _last_execution_id:
		_hit_count = 0
		_last_execution_id = context.execution_id

	_hit_count += 1

	# 忽略次数检查
	if ignore_count > 0 and _hit_count <= ignore_count:
		_log_debug_localized("FUSE_BREAKPOINT_HIT", {"hit": _hit_count, "ignore": ignore_count})
		_on_execution_completed()
		return

	# 条件表达式评估（仅在启用条件断点时）
	var condition_met = true
	if use_expression_condition and not condition.is_empty() and context:
		var eval_result = _evaluate_condition(condition, context)
		if eval_result == null:
			_log_warning_localized("FUSE_BREAKPOINT_CONDITION_FAILED")
		elif eval_result == false:
			_log_debug_localized("FUSE_BREAKPOINT_CONDITION_NOT_MET")
			_on_execution_completed()
			return
		condition_met = eval_result

	# 输出变量信息到输出窗口
	if log_variables and context:
		_print_breakpoint_info(context, condition_met)

	# 暂停执行（仅编辑器模式）
	if pause_execution and OS.has_feature("editor"):
		await _show_pause_dialog(context)
	elif pause_execution and not OS.has_feature("editor"):
		print_rich("[color=yellow][BREAKPOINT] ▌ %s[/color]" % FuseLocalization.translate("FUSE_BREAKPOINT_PAUSE_ONLY_EDITOR"))

	_on_execution_completed()

## 评估条件表达式
func _evaluate_condition(expr: String, context: ExecutionContext) -> Variant:
	var helper = ExpressionHelper.GameExprHelper.new()

	var processed = ExpressionHelper.replace_variables(
		expr,
		context,
		scope_source as VariableScopeUtils.ScopeSource,
		custom_scope_id,
		target_node_path,
		true
	)
	if processed == null:
		return null

	var error_text = ""
	var result = ExpressionHelper.evaluate(str(processed), helper, error_text)
	if result == null:
		_log_warning_localized("FUSE_BREAKPOINT_CONDITION_ERROR", {"error": error_text, "condition": expr})
		return null

	return result

## 输出断点信息到 Godot 输出窗口
func _print_breakpoint_info(context: ExecutionContext, condition_met: Variant) -> void:
	var output_parts: PackedStringArray = []

	# 标题行
	var label_text = "\"%s\"" % label if not label.is_empty() else FuseLocalization.translate("FUSE_BREAKPOINT_UNNAMED")
	output_parts.append("[color=cyan][BREAKPOINT][/color] " + FuseLocalization.translate_format(
		"FUSE_BREAKPOINT_TITLE", {"label": label_text, "hit": _hit_count}
	))

	# 条件行
	if use_expression_condition and not condition.is_empty():
		var result_text = "true" if condition_met else "false"
		output_parts.append("  [color=gray]%s: %s → %s[/color]" % [FuseLocalization.translate("FUSE_BREAKPOINT_CONDITION_LABEL"), condition, result_text])

	# 局部变量
	var local_vars = context.get_all_local_variables_snapshot()
	if not local_vars.is_empty():
		output_parts.append("  [color=gray]%s: %s[/color]" % [FuseLocalization.translate("FUSE_BREAKPOINT_LOCAL_VARS"), JSON.stringify(local_vars, "\t")])

	# 作用域变量（根据 scope_source 获取）
	var scope_container = VariableScopeUtils.get_scope_container_by_source(
		context,
		scope_source as VariableScopeUtils.ScopeSource,
		custom_scope_id,
		target_node_path
	)
	if scope_container:
		var scope_vars: Dictionary = {}
		for var_name in scope_container.get_variable_names():
			scope_vars[var_name] = scope_container.get_variable(var_name)
		if not scope_vars.is_empty():
			output_parts.append("  [color=gray]%s: %s[/color]" % [FuseLocalization.translate("FUSE_BREAKPOINT_SCOPE_VARS"), JSON.stringify(scope_vars, "\t")])

	# 全局变量
	var global_vars = context.get_all_global_variables_snapshot()
	if not global_vars.is_empty():
		output_parts.append("  [color=gray]%s: %s[/color]" % [FuseLocalization.translate("FUSE_BREAKPOINT_GLOBAL_VARS"), JSON.stringify(global_vars, "\t")])

	print_rich("\n".join(output_parts))

## 暂停执行并等待用户恢复
## 显示提示 UI 并通过 Input 单例轮询回车键。
## 动态创建的 Control 无法接收 GUI 输入事件（已验证），
## 因此使用 Input 单例检测按键，UI 仅作为视觉提示。
func _show_pause_dialog(context: ExecutionContext) -> void:
	var tree = Engine.get_main_loop() as SceneTree

	# 创建提示面板（纯视觉，不需要接收输入）
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 128
	var parent: Node = tree.current_scene if tree.current_scene else tree.root
	parent.add_child(canvas_layer)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_top = -50
	panel.offset_right = 220
	panel.offset_bottom = 50

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title = Label.new()
	title.text = FuseLocalization.translate("FUSE_BREAKPOINT_PAUSED_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)

	var hint = Label.new()
	hint.text = FuseLocalization.translate("FUSE_BREAKPOINT_PAUSED_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)

	var key_hint = Label.new()
	key_hint.text = FuseLocalization.translate("FUSE_BREAKPOINT_PAUSED_KEY_HINT")
	key_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_hint.add_theme_font_size_override("font_size", 14)

	vbox.add_child(title)
	vbox.add_child(hint)
	vbox.add_child(key_hint)
	panel.add_child(vbox)
	canvas_layer.add_child(panel)

	print_rich("[color=yellow][BREAKPOINT] ▌ %s[/color]" % FuseLocalization.translate("FUSE_BREAKPOINT_PAUSED_MESSAGE"))

	# 等待回车键
	while not Input.is_action_just_pressed("ui_accept"):
		await tree.process_frame

	print_rich("[color=green][BREAKPOINT] ▌ %s[/color]" % FuseLocalization.translate("FUSE_BREAKPOINT_RESUMED_MESSAGE"))
	canvas_layer.queue_free()

# =============================================
# 验证
# =============================================

func validate() -> Array[String]:
	return super.validate()

# =============================================
# 统一日志方法
# =============================================

func _log_debug(message: String):
	FuseLogger.log_debug("BreakpointInstruction", log_level, message)

func _log_info(message: String):
	FuseLogger.log_info("BreakpointInstruction", log_level, message)

func _log_warning(message: String):
	FuseLogger.log_warning("BreakpointInstruction", log_level, message)

func _log_error(message: String):
	FuseLogger.log_error("BreakpointInstruction", log_level, message)
