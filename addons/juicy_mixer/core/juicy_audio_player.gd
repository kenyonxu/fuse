## 音频播放器节点
##
## 将此节点作为子节点添加到任何节点，自动监听信号并播放音频
##
## 使用示例:
## 1. 将 JuicyAudioPlayer 作为子节点添加到目标节点
## 2. 在 Inspector 中分配 AudioComponent
## 3. (可选) 启用 debug_mode 查看日志
@tool
class_name JuicyAudioPlayer
extends Node

# =============================================================================
# 导出属性
# =============================================================================

## 音频组件资源，包含信号到音频的映射
@export var audio_component: AudioComponent

## 显式指定的目标节点（可选）
##
## 如果设置，优先使用此节点而非父节点
## 允许 JuicyAudioPlayer 在场景树的任意位置
##
## 设置时会自动同步到 audio_component.target_path
@export var target: Node = null:
	set(value):
		target = value
		_sync_audio_component()

## 是否在 _ready 时自动设置音频组件
@export var auto_setup: bool = true

## 启用调试模式以查看详细日志
@export var debug_mode: bool = false

# =============================================================================
# 私有成员
# =============================================================================

var _parent_node: Node
var _mixer_instance: JuicyMixer
# =============================================================================
# 生命周期
# =============================================================================

func _ready() -> void:
	_parent_node = _get_effective_target()

	if not _parent_node:
		push_error("JuicyAudioPlayer: 请设置 target 或作为子节点添加到目标节点")
		return

	# 确保音频组件存在并同步 target_path
	_sync_audio_component()

	# 只在运行时验证 EventHandlingMiddleware（延迟执行，等待场景准备完成）
	if not Engine.is_editor_hint():
		call_deferred("_verify_event_system_deferred")

	# 自动设置组件
	if auto_setup and audio_component:
		audio_component.setup(_parent_node, self)

	if debug_mode:
		print("[JuicyAudioPlayer] Initialized for parent: ", _parent_node.name)
		print("[JuicyAudioPlayer] Bindings: ", audio_component.get_binding_count() if audio_component else 0)

# =============================================================================
# 私有方法
# =============================================================================

## 获取有效的目标节点
##
## 优先使用显式指定的 target，回退到父节点
## 保持向后兼容性
##
## @return: 有效的目标节点，失败返回 null
func _get_effective_target() -> Node:
	# 1. 优先使用显式指定的 target
	if target:
		return target

	# 2. 回退到父节点（原有逻辑）
	return get_parent()

## 同步音频组件和目标节点
##
## 确保 audio_component 存在，并同步 target 到 target_path
## 这样即使 player 在场景树中的位置改变，引用也能保持正确
func _sync_audio_component() -> void:
	# 如果没有 audio_component，创建一个
	if not audio_component:
		audio_component = AudioComponent.new()
		if debug_mode:
			print("[JuicyAudioPlayer] 创建了新的 AudioComponent")

	# 如果设置了显式 target，同步到 target_path
	if target:
		# 检查节点是否已在场景树中
		if not is_inside_tree():
			# 节点还未添加到场景树，等待 _ready 时再同步
			return

		# 获取场景根节点用于计算相对路径
		var root_node = get_tree().current_scene if get_tree() else null
		if not root_node and Engine.is_editor_hint():
			root_node = EditorInterface.get_edited_scene_root()

		if root_node and root_node.is_ancestor_of(target):
			var relative_path = root_node.get_path_to(target)
			audio_component.target_path = relative_path
			if debug_mode:
				print("[JuicyAudioPlayer] 同步 target_path: ", relative_path)
		else:
			push_warning("JuicyAudioPlayer: 无法将 target 同步到 target_path（节点不在场景树中或不是后代的节点）")
	notify_property_list_changed()


# =============================================================================
# EventHandlingMiddleware 验证
# =============================================================================

## 延迟验证 EventHandlingMiddleware
##
## 通过多次 call_deferred 调用，确保 AudioManager 完成初始化
func _verify_event_system_deferred() -> void:
	# 再次延迟，确保 AudioManager._ready() 已经执行完成
	call_deferred("_verify_event_system_final")

## 最终验证 EventHandlingMiddleware
##
## 执行实际的验证，如果失败则输出错误
func _verify_event_system_final() -> void:
	# 使用轮询等待 AudioEventHandler 注册完成
	_verify_with_retry()

## 轮询验证 EventHandlingMiddleware
##
## 最多等待 10 帧，确保 AudioManager 完成初始化
func _verify_with_retry(max_retries: int = 10) -> void:
	var retries := 0

	while retries < max_retries:
		if _verify_event_system():
			if debug_mode:
				print("[JuicyAudioPlayer] 事件系统验证成功（重试 %d 次）" % retries)
			return

		retries += 1
		await Engine.get_main_loop().process_frame

	push_error("JuicyAudioPlayer: EventHandlingMiddleware 未初始化，请确保场景中有 AudioManager")

## 验证 EventHandlingMiddleware 是否存在
##
## 使用 AudioManager.ensure_exists() 确保 AudioManager 存在
## AudioManager 会自动注册 AudioEventHandler 到 EventHandlingMiddleware
##
## @return: 事件系统可用返回 true，否则返回 false
func _verify_event_system() -> bool:
	# 1. 确保 AudioManager 存在（自动创建）
	var audio_manager = AudioManager.ensure_exists()
	if not audio_manager:
		push_error("JuicyAudioPlayer: 无法获取或创建 AudioManager")
		return false

	if debug_mode:
		print("[JuicyAudioPlayer] AudioManager 已确保存在")

	# 2. 验证 JuicyMixer 存在
	_mixer_instance = JuicyMixer.instance
	if not _mixer_instance:
		push_error("JuicyAudioPlayer: JuicyMixer 实例未初始化")
		return false

	# 3. 验证 EventHandlingMiddleware 存在
	var event_middleware = _mixer_instance.get_middleware("EventHandlingMiddleware")
	if not event_middleware:
		push_error("JuicyAudioPlayer: EventHandlingMiddleware 未找到")
		return false

	# 4. 验证 AudioEventHandler 已注册
	var handler = event_middleware.get_event_handler("AudioEventHandler")
	if not handler:
		if debug_mode:
			print("[JuicyAudioPlayer] 警告: AudioEventHandler 未注册")
		return false

	if debug_mode:
		print("[JuicyAudioPlayer] 事件系统验证完成，AudioEventHandler 已注册")

	return true


# =============================================================================
# 信号回调（由 AudioComponent.connect 调用）
# =============================================================================

## 信号触发回调
##
## 当绑定的信号被触发时，AudioComponent 会调用此方法
## 使用正确的 JuicyMixer 事件流程：
## 1. 创建 JuicyEvent
## 2. 通过 JuicyMixer.play_event() 播放
## 3. EventHandlingMiddleware 自动处理并分发到 EventHandler
##
## @param binding: 被触发的 AudioBinding
func _on_binding_triggered(binding: AudioBinding) -> void:
	# 确保只在运行时执行
	if Engine.is_editor_hint():
		return

	if not binding or not binding.audio_event:
		if debug_mode:
			print("[JuicyAudioPlayer] Invalid binding")
		return

	# 确保 _mixer_instance 已初始化
	if not _mixer_instance:
		_mixer_instance = JuicyMixer.instance
		if not _mixer_instance:
			push_error("JuicyAudioPlayer: JuicyMixer 实例未初始化")
			return

	# 检查冷却
	if not binding.can_play():
		if debug_mode:
			print("[JuicyAudioPlayer] Binding in cooldown: ", binding.signal_name)
		return

	# 创建 JuicyEvent
	var juicy_event = JuicyEvent.new()
	juicy_event.event_type = JuicyEvent.EventType.AUDIO_PLAY
	juicy_event.event_data = {
		"audio_event_resource": binding.audio_event,
		"target": _parent_node,
		"position": _get_target_position(_parent_node)
	}

	# 通过 JuicyMixer.play_event() 播放事件（使用完整的中间件流程）
	var context_id = _mixer_instance.play_event(juicy_event, _parent_node, self)
	var success = not context_id.is_empty()

	if success:
		binding.mark_played()
		if debug_mode:
			print("[JuicyAudioPlayer] Played audio event via JuicyMixer: ", binding.audio_event.event_name, " (context: ", context_id, ")")
	else:
		push_error("JuicyAudioPlayer: Failed to play audio event via JuicyMixer")

# =============================================================================
# 运行时绑定管理
# =============================================================================

## 运行时添加绑定
##
## @param signal_name: 要监听的信号名称
## @param event: 信号触发时播放的音频事件
func add_binding(signal_name: String, event: AudioEventResource) -> void:
	if not audio_component:
		audio_component = AudioComponent.new()

	var binding = AudioBinding.new()
	binding.signal_name = signal_name
	binding.audio_event = event
	audio_component.audio_bindings.append(binding)

	# 立即连接
	if _parent_node and _parent_node.has_signal(signal_name):
		_parent_node.connect(signal_name, _on_binding_triggered.bind(binding))
		if debug_mode:
			print("[JuicyAudioPlayer] Added runtime binding: ", signal_name)

## 移除绑定
##
## @param signal_name: 要移除的信号名称
func remove_binding(signal_name: String) -> void:
	if not audio_component:
		return

	var binding = audio_component.find_binding_by_signal(signal_name)
	if binding:
		audio_component.audio_bindings.erase(binding)

		# 注意：由于无法可靠地检测特定的 Callable 连接状态，
		# 我们依赖 Godot 的信号系统在目标对象或绑定对象被销毁时自动清理连接
		# 如果需要立即断开连接，建议重新创建父节点或 player

		if debug_mode:
			print("[JuicyAudioPlayer] Removed binding: ", signal_name)

# =============================================================================
# 工具方法
# =============================================================================

## 手动触发绑定播放（用于测试或特殊情况）
##
## @param signal_name: 要触发的信号名称
func trigger_binding(signal_name: String) -> void:
	if not audio_component:
		return

	var binding = audio_component.find_binding_by_signal(signal_name)
	if binding:
		_on_binding_triggered(binding)
	else:
		push_warning("JuicyAudioPlayer: No binding found for signal: ", signal_name)

# =============================================================================
# 辅助方法
# =============================================================================

## 获取目标节点的位置（用于3D音频）
##
## @param target: 目标节点
## @return: 位置（Vector3 或 Vector2）
func _get_target_position(target: Node) -> Variant:
	if target is Node3D:
		return target.global_position
	elif target is Node2D:
		return target.global_position
	else:
		# 对于普通 Node，返回 Vector2.ZERO（2D 播放器默认值）
		return Vector2.ZERO
