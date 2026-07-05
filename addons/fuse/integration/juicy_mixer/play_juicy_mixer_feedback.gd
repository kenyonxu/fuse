# 文件：addons/fuse/integration/juicy_mixer/play_juicy_mixer_feedback.gd
@tool
@icon("res://addons/fuse/icons/instruct.png")
extends BaseInstruction
class_name PlayJuicyMixerFeedback

# 关键：实现这个静态方法，用于指令选择器
static func _get_instruction_metadata() -> InstructionMetadata:
	metadata = InstructionMetadata.new()
	metadata.name = "播放JuicyMixer反馈"
	metadata.category = "JuicyMixer集成"
	metadata.description = "使用JuicyMixer系统播放反馈效果，支持各种视觉和音频效果。"
	# 正确初始化 Array[String] 类型
	metadata.keywords = ["juicy", "反馈", "效果", "播放", "动画", "音频", "视觉"]
	return metadata

## 播放JuicyMixer反馈指令
##
## 一个集成指令，用于通过JuicyMixer系统播放各种反馈效果。
## 支持视觉动画、音频效果、屏幕震动等多种效果类型。
## 使用同步执行模式，播放后立即完成。

## 反馈资源
@export var feedback: JuicyFeedbackResource = null:
	set(value):
		feedback = value
		_update_resource_name()

## 目标节点路径
@export var target_node: NodePath = "":
	set(value):
		target_node = value
		_update_resource_name()

## 拥有者节点路径（可选）
@export var owner_node: NodePath = "":
	set(value):
		owner_node = value
		_update_resource_name()

## 播放上下文ID（运行时）
var _context_id: String = ""

## 中间件管道引用（用于监听完成信号）
var _middleware_pipeline: Object = null

## 防止重复执行的保护标志
var _is_executing: bool = false

## 设置指令元数据
func _setup_metadata():
	pass

## 更新资源名称
## 重写基类方法，提供 PlayJuicyMixerFeedback 的自定义资源名称
func _update_resource_name():
	var parts = []
	
	# 基础信息
	parts.append("播放JuicyMixer反馈")
	
	# 反馈资源信息
	if feedback != null:
		var resource_type = feedback.get_resource_type()
		parts.append("[%s]" % resource_type)
	else:
		parts.append("[未选择反馈]")
	
	# 目标节点信息
	if not target_node.is_empty():
		parts.append("→ %s" % _get_node_display_name(target_node))
	else:
		parts.append("→ [未选择目标]")
	
	# 拥有者信息（如果有）
	if not owner_node.is_empty():
		parts.append("(拥有者: %s)" % _get_node_display_name(owner_node))
	
	# 组合最终名称
	resource_name = " ".join(parts)

## 执行指令
## context: ExecutionContext - 执行上下文
func execute(context: ExecutionContext):
	# 防止重复执行
	if _is_executing:
		_log_warning("指令正在执行中，跳过重复调用")
		return
	
	_is_executing = true
	
	# 调用基类的执行初始化方法
	_start_execution(context)
	
	_log_debug("开始执行 PlayJuicyMixerFeedback 指令")
	
	# 验证参数
	var errors = validate()
	if not errors.is_empty():
		var error_message = "参数验证失败: " + ", ".join(errors)
		set_error(error_message)
		finished.emit()
		return
	
	# 获取目标节点
	var target = _get_target_node()
	if not target:
		var error_message = "无法找到目标节点: " + str(target_node)
		set_error(error_message)
		finished.emit()
		return
	
	# 获取拥有者节点（可选）
	var owner = _get_owner_node()
	
	# 输出执行信息到上下文
	if context:
		var feedback_info = _get_feedback_info()
		context.print_message("播放JuicyMixer反馈: %s" % feedback_info)
	
	# 使用JuicyMixer播放反馈效果
	_context_id = _play_feedback(target, owner)
	
	# 检查播放结果
	if _context_id.is_empty():
		# 播放失败，记录警告但继续执行（根据用户要求）
		_log_warning("JuicyMixer反馈播放失败，但继续执行")
		if context:
			context.print_message("警告: JuicyMixer反馈播放失败")
	else:
		_log_info("成功启动JuicyMixer反馈，上下文ID: %s" % _context_id)
		if context:
			context.print_message("JuicyMixer反馈已启动 (ID: %s)" % _context_id)
	
	# 异步执行模式：等待效果播放完成
	_log_debug("PlayJuicyMixerFeedback 指令启动完成，等待效果播放完成")
	# 不在这里调用 _on_execution_completed()，而是等待效果完成

## 获取目标节点
func _get_target_node() -> Node:
	if target_node.is_empty():
		_log_error("目标节点路径为空")
		return null
	
	# 获取场景根节点
	var scene_root = Engine.get_main_loop().current_scene
	if not scene_root:
		_log_error("无法获取场景根节点")
		return null
	
	# 将相对NodePath变换为绝对NodePath
	var root_path = scene_root.get_path()
	var target_path = NodePath(str(root_path) + str(target_node).replace("..", ""))
	
	var target = scene_root.get_node_or_null(target_path)
	if not target:
		_log_error("无法找到目标节点: %s" % str(target_node))
		return null
	
	return target

## 获取拥有者节点
func _get_owner_node() -> Node:
	if owner_node.is_empty():
		return null
	
	# 获取场景根节点
	var scene_root = Engine.get_main_loop().current_scene
	if not scene_root:
		_log_warning("无法获取场景根节点，拥有者节点将被忽略")
		return null
	
	# 将相对NodePath变换为绝对NodePath
	var root_path = scene_root.get_path()
	var owner_path = NodePath(str(root_path) + str(owner_node).replace("..", ""))
	
	var owner = scene_root.get_node_or_null(owner_path)
	if not owner:
		_log_warning("无法找到拥有者节点: %s" % str(owner_node))
		return null
	
	return owner

## 播放反馈效果
func _play_feedback(target: Node, owner: Node = null) -> String:
	if not feedback:
		_log_error("反馈资源为空")
		return ""
	
	# 验证反馈资源配置
	var validation_result = feedback.validate_config()
	if not validation_result.valid:
		_log_error("反馈资源配置验证失败: " + ", ".join(validation_result.issues))
		return ""
	
	# 如果有警告，记录它们
	if not validation_result.warnings.is_empty():
		for warning in validation_result.warnings:
			_log_warning("反馈资源警告: %s" % warning)
	
	# 使用JuicyMixer单例播放反馈效果
	# 关键：通过JuicyMixer.instance获取实例，然后调用play方法
	var juicy_mixer = JuicyMixer.instance
	if not juicy_mixer:
		_log_error("无法获取JuicyMixer实例")
		return ""
	
	# 调用JuicyMixer的play方法
	var context_id = juicy_mixer.play(feedback, target, owner)
	
	if context_id.is_empty():
		_log_error("JuicyMixer.play 返回空上下文ID")
		return ""
	
	# 获取JuicyContext实例并连接到其完成信号
	var context = JuicyMixer.get_context(context_id)
	if context and context.has_signal("execute_complete"):
		# 连接到Context的execute_complete信号
		if not context.execute_complete.is_connected(_on_context_execute_complete):
			context.execute_complete.connect(_on_context_execute_complete)
			_log_debug("已连接JuicyContext execute_complete信号")
	else:
		_log_warning("无法获取JuicyContext实例或没有execute_complete信号")
	
	return context_id

## JuicyContext执行完成回调
func _on_context_execute_complete(context_id: String):
	# 检查是否是我们的上下文
	if context_id != _context_id:
		return
	
	_log_info("JuicyMixer效果执行完成 (ID: %s)" % _context_id)
	
	# 重置执行标志
	_is_executing = false
	
	# 标记指令完成
	_on_execution_completed()

## 获取反馈信息
func _get_feedback_info() -> String:
	if not feedback:
		return "未选择反馈资源"
	
	var info_parts = []
	
	# 资源类型
	info_parts.append(feedback.get_resource_type())
	
	# 持续时间
	info_parts.append("持续时间: %.1f秒" % feedback.get_duration())
	
	# 通道信息
	if not feedback.channel.is_empty() and feedback.channel != "default":
		info_parts.append("通道: %s" % feedback.channel)
	
	# 优先级信息
	if feedback.priority != 0:
		info_parts.append("优先级: %d" % feedback.priority)
	
	return ", ".join(info_parts)

## 获取指令描述
## returns: String - 指令描述
func get_description() -> String:
	if not feedback:
		return "播放JuicyMixer反馈 (未选择反馈资源)"
	
	var target_desc = _get_node_display_name(target_node) if not target_node.is_empty() else "未选择目标"
	var feedback_desc = _get_feedback_info()
	
	return "播放 %s 到目标 %s" % [feedback_desc, target_desc]

## 验证指令参数
## returns: Array[String] - 错误信息数组
func validate() -> Array[String]:
	var errors = super.validate()
	
	# 验证反馈资源
	if feedback == null:
		errors.append(FuseLocalization.translate("FUSE_ERROR_FEEDBACK_RESOURCE_EMPTY"))
	
	# 验证目标节点路径
	if target_node.is_empty():
		errors.append(FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_PATH_EMPTY"))
	
	return errors

## 取消指令执行
func cancel():
	if is_running():
		_log_debug("取消 PlayJuicyMixerFeedback 指令")
		
		# 如果已经启动了反馈效果，尝试停止它
		if not _context_id.is_empty():
			_stop_feedback()
		
		# 重置执行标志
		_is_executing = false
		
		super.cancel()

## 停止反馈效果
func _stop_feedback():
	if _context_id.is_empty():
		return
	
	# 使用JuicyMixer单例停止反馈效果
	var juicy_mixer = JuicyMixer.instance
	if juicy_mixer:
		var success = juicy_mixer.stop(_context_id)
		if success:
			_log_info("成功停止反馈效果 (ID: %s)" % _context_id)
		else:
			_log_warning("停止反馈效果失败 (ID: %s)" % _context_id)
	else:
		_log_warning("无法获取JuicyMixer实例来停止反馈效果")
	
	_context_id = ""

## 资源清理
func _cleanup_resources():
	super._cleanup_resources()
	
	# 断开JuicyContext信号连接
	if not _context_id.is_empty():
		var context = JuicyMixer.get_context(_context_id)
		if context and context.has_signal("execute_complete"):
			if context.execute_complete.is_connected(_on_context_execute_complete):
				context.execute_complete.disconnect(_on_context_execute_complete)
				_log_debug("已断开JuicyContext execute_complete信号连接")
	
	# 注意：不要在这里停止反馈效果，因为指令执行完成不等于效果播放完成
	# 效果应该继续播放直到自然结束或被外部停止
	# _stop_feedback()  # 注释掉这行，让效果继续播放
	
	_log_debug("PlayJuicyMixerFeedback 资源清理完成（保持效果运行）")

## 手动停止反馈效果
## 可以在指令执行完成后调用，用于提前停止效果
func stop_feedback_effect():
	if not _context_id.is_empty():
		_log_info("手动停止反馈效果 (ID: %s)" % _context_id)
		_stop_feedback()
	else:
		_log_warning("没有正在播放的反馈效果可以停止")

## 获取当前播放的上下文ID
func get_context_id() -> String:
	return _context_id

## 检查是否有正在播放的效果
func is_effect_playing() -> bool:
	return not _context_id.is_empty() and JuicyMixer.is_context_active(_context_id)

## 重置指令状态
func reset():
	super.reset()
	
	# 重置上下文ID
	_context_id = ""
	
	# 重置执行标志
	_is_executing = false
	
	# 清理中间件管道引用
	_middleware_pipeline = null
	
	_log_debug("PlayJuicyMixerFeedback 状态已重置")

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("PlayJuicyMixerFeedback", log_level, message)

func _log_info(message: String):
	FuseLogger.log_info("PlayJuicyMixerFeedback", log_level, message)

func _log_warning(message: String):
	FuseLogger.log_warning("PlayJuicyMixerFeedback", log_level, message)

func _log_error(message: String):
	FuseLogger.log_error("PlayJuicyMixerFeedback", log_level, message)
