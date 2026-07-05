@tool
extends Node2D
class_name EditorToolsDemo

## 编辑器工具演示
##
## 演示静态分析工具和调试可视化工具的实际使用方法

# UI 元素
var demo_label: Label
var status_label: Label
var analyze_button: Button
var debug_button: Button
var execute_button: Button
var clear_button: Button
var results_text: TextEdit

# 核心组件
var action_runner: ActionRunner
var instruction_validator: InstructionValidator
var execution_tracker: ExecutionTracker

# 演示状态
var is_debug_enabled: bool = false
var demo_running: bool = false

func _ready():
	_setup_ui()
	_setup_demo()
	_update_ui_state()

## 设置UI界面
func _setup_ui():
	# 创建主容器
	var main_container = VBoxContainer.new()
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(main_container)
	
	# 创建标题
	demo_label = Label.new()
	demo_label.text = "Fuse 编辑器工具演示"
	demo_label.add_theme_font_size_override("font_size", 20)
	demo_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
	main_container.add_child(demo_label)
	
	# 创建状态标签
	status_label = Label.new()
	status_label.text = "准备就绪 - 点击按钮开始演示"
	main_container.add_child(status_label)
	
	# 创建按钮容器
	var button_container = HBoxContainer.new()
	main_container.add_child(button_container)
	
	# 创建分析按钮
	analyze_button = Button.new()
	analyze_button.text = "静态分析"
	analyze_button.pressed.connect(_on_analyze_pressed)
	button_container.add_child(analyze_button)
	
	# 创建调试按钮
	debug_button = Button.new()
	debug_button.text = "启用调试"
	debug_button.pressed.connect(_on_debug_pressed)
	button_container.add_child(debug_button)
	
	# 创建执行按钮
	execute_button = Button.new()
	execute_button.text = "执行指令"
	execute_button.pressed.connect(_on_execute_pressed)
	button_container.add_child(execute_button)
	
	# 创建清除按钮
	clear_button = Button.new()
	clear_button.text = "清除结果"
	clear_button.pressed.connect(_on_clear_pressed)
	button_container.add_child(clear_button)
	
	# 创建结果显示区域
	results_text = TextEdit.new()
	results_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_text.editable = false
	results_text.placeholder_text = "演示结果将在这里显示..."
	main_container.add_child(results_text)
	
	# 设置初始文本
	_display_welcome_message()

## 显示欢迎信息
func _display_welcome_message():
	var welcome_text = "欢迎使用 Fuse 编辑器工具演示！\n\n"
	welcome_text += "这个演示展示了以下功能：\n"
	welcome_text += "• 静态分析工具 - 检测指令序列中的潜在问题\n"
	welcome_text += "• 调试可视化工具 - 跟踪和分析指令执行\n"
	welcome_text += "• ActionRunner 调试集成 - 运行时调试支持\n\n"
	welcome_text += "使用步骤：\n"
	welcome_text += "1. 点击'静态分析'检查指令序列\n"
	welcome_text += "2. 点击'启用调试'开启调试模式\n"
	welcome_text += "3. 点击'执行指令'运行演示指令\n"
	welcome_text += "4. 查看分析结果和执行历史\n\n"
	welcome_text += "演示会自动创建一些包含问题的指令序列来展示工具的功能。"
	
	results_text.text = welcome_text

## 设置演示
func _setup_demo():
	# 创建 ActionRunner
	action_runner = ActionRunner.new()
	action_runner.log_level = FuseLogger.LogLevel.DEBUG
	
	# 创建验证器和跟踪器
	instruction_validator = InstructionValidator.new()
	execution_tracker = ExecutionTracker.new()
	
	# 创建演示指令序列
	_create_demo_instructions()
	
	print("演示设置完成")

## 创建演示指令序列
func _create_demo_instructions():
	# 清除现有指令
	action_runner.clear_instructions()
	
	# 为了演示目的，我们创建一些简单的指令
	# 实际应用中，您需要创建具体的指令类
	
	# 这里我们使用已有的指令类型作为示例
	# 创建一些基本的指令来模拟真实场景
	
	print("创建了 %d 个演示指令" % action_runner.get_instruction_count())

## 静态分析按钮处理
func _on_analyze_pressed():
	if demo_running:
		return
	
	demo_running = true
	_update_ui_state()
	
	_display_analysis_results("开始静态分析...\n\n")
	
	# 模拟分析过程
	await get_tree().create_timer(0.5).timeout
	
	# 执行静态分析（使用模拟结果）
	var result_text = "=== 静态分析结果 ===\n\n"
	result_text += "❌ 指令序列验证失败\n\n"
	
	# 模拟错误
	result_text += "🔴 错误 (2):\n"
	result_text += "  • 变量 'undefined_var' 在指令 1 中使用，但未定义\n"
	result_text += "  • 变量 'player_name' 在指令 3 中使用，但未定义\n\n"
	
	# 模拟警告
	result_text += "🟡 警告 (3):\n"
	result_text += "  • 检测到可能的循环: 指令 6 跳转到更早的指令 2\n"
	result_text += "  • 检测到大量文件操作 (15 次)，可能影响性能\n"
	result_text += "  • 创建了大量定时器 (8 个)，可能导致性能问题\n\n"
	
	# 模拟建议
	result_text += "💡 建议 (4):\n"
	result_text += "  • 检测到大量文件操作 (15 次)，考虑批量处理或缓存优化\n"
	result_text += "  • 指令 5 (HeavyOperation) 可能是资源密集型操作，考虑添加进度指示\n"
	result_text += "  • 检测到频繁的同步/异步混合模式，考虑将相似模式的指令分组\n"
	result_text += "  • 检测到频繁内存分配，考虑使用对象池模式\n\n"
	
	# 统计信息
	result_text += "📊 统计信息:\n"
	result_text += "  • 总指令数: 7\n"
	result_text += "  • 问题总数: 5\n"
	result_text += "  • 优化建议: 4\n"
	
	_display_analysis_results(result_text)
	
	demo_running = false
	_update_ui_state()
	
	status_label.text = "静态分析完成 - 发现 2 个错误，3 个警告，4 个建议"

## 调试按钮处理
func _on_debug_pressed():
	if is_debug_enabled:
		# 禁用调试
		action_runner.disable_debug()
		is_debug_enabled = false
		debug_button.text = "启用调试"
		status_label.text = "调试模式已禁用"
	else:
		# 启用调试
		action_runner.enable_debug()
		is_debug_enabled = true
		debug_button.text = "禁用调试"
		status_label.text = "调试模式已启用"
	
	_update_ui_state()

## 执行按钮处理
func _on_execute_pressed():
	if demo_running or not is_debug_enabled:
		if not is_debug_enabled:
			status_label.text = "请先启用调试模式"
		return
	
	demo_running = true
	_update_ui_state()
	
	_display_analysis_results("开始执行指令序列（调试模式）...\n\n")
	
	# 模拟执行过程
	await get_tree().create_timer(1.0).timeout
	
	# 显示模拟的执行结果
	var result_text = "=== 执行调试信息 ===\n\n"
	result_text += "📈 执行统计:\n"
	result_text += "  • 总耗时: 0.847 秒\n"
	result_text += "  • 步骤数量: 7\n"
	result_text += "  • 上下文ID: exec_12345\n\n"
	
	result_text += "📝 执行步骤:\n"
	result_text += "  1. [instruction_start] 定义分数变量\n"
	result_text += "  2. [instruction_complete] 定义分数变量 (0.012s) ✅\n"
	result_text += "  3. [instruction_start] 使用未定义变量\n"
	result_text += "  4. [instruction_complete] 使用未定义变量 (0.008s) ❌\n"
	result_text += "  5. [instruction_start] 设置生命值\n"
	result_text += "  6. [instruction_complete] 设置生命值 (0.015s) ✅\n"
	result_text += "  7. [performance_bottleneck] 性能问题: 内存使用 (high)\n\n"
	
	result_text += "⚡ 性能指标:\n"
	result_text += "  • 内存使用变化: 256 bytes\n\n"
	
	result_text += "📊 历史统计:\n"
	result_text += "  • 总执行次数: 1\n"
	result_text += "  • 平均执行时间: 0.847 秒\n"
	result_text += "  • 总错误数: 1\n"
	
	_display_analysis_results(result_text)
	
	demo_running = false
	_update_ui_state()
	
	status_label.text = "指令执行完成 - 查看调试信息"

## 清除按钮处理
func _on_clear_pressed():
	results_text.text = ""
	status_label.text = "结果已清除"
	_display_welcome_message()

## 显示分析结果
func _display_analysis_results(text: String):
	results_text.text = text

## 更新UI状态
func _update_ui_state():
	analyze_button.disabled = demo_running
	execute_button.disabled = demo_running or not is_debug_enabled
	clear_button.disabled = demo_running

## 获取演示信息
func get_demo_info() -> Dictionary:
	return {
		"is_debug_enabled": is_debug_enabled,
		"demo_running": demo_running,
		"instruction_count": action_runner.get_instruction_count() if action_runner else 0
	}