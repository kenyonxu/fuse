extends Node
class_name AudioManager

## AudioManager - 场景级音频配置节点
##
## 提供场景级的统一音频配置入口，管理实例级混合配置、全局限额和音频类别。
##
## 静态单例模式：
## - 使用 AudioManager.ensure_exists() 确保实例存在
## - 使用 AudioManager.get_instance() 获取当前实例
## - 使用 AudioManager.has_instance() 检查实例是否存在

# =============================================================================
# 静态单例管理
# =============================================================================

## 静态实例引用
static var _instance: AudioManager = null

## 获取单例实例
##
## 如果静态引用存在，直接返回
## 否则从场景树中查找 "audio_manager" 组的节点
##
## @return: AudioManager 实例，不存在返回 null
static func get_instance() -> AudioManager:
	# 优先返回静态引用
	if _instance:
		return _instance

	# 从场景树中查找
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		_instance = tree.get_first_node_in_group("audio_manager")

	return _instance

## 确保实例存在
##
## 如果实例不存在，自动创建并添加到当前场景根节点
## 注意：在编辑器中不会自动创建
##
## @return: AudioManager 实例，失败返回 null
static func ensure_exists() -> AudioManager:
	var instance = get_instance()

	if not instance:
		# 在编辑器中不自动创建
		if Engine.is_editor_hint():
			push_warning("[AudioManager] 在编辑器中无法自动创建，请手动添加到场景")
			return null

		# 检查场景树是否可用
		var tree = Engine.get_main_loop() as SceneTree
		if not tree or not tree.current_scene:
			push_error("[AudioManager] 当前场景不可用")
			return null

		# 创建新实例
		instance = AudioManager.new()
		instance.name = "AudioManager"

		# 使用 call_deferred 避免在父节点设置子节点时添加
		tree.current_scene.add_child.call_deferred(instance)
		_instance = instance

		print("[AudioManager] 自动创建默认实例到当前场景根节点")

	return instance

## 检查实例是否存在
##
## @return: 如果存在返回 true，否则返回 false
static func has_instance() -> bool:
	return get_instance() != null

## 重置静态引用
##
## 当实例被手动销毁时调用，清除静态引用
static func reset_instance() -> void:
	_instance = null



# =============================================================================
# 导出属性
# =============================================================================

## 实例级混合配置（默认应用于场景中所有音频播放）
@export var instance_mixing_config: AudioMixingConfig

## 是否启用配置继承（未来功能）
##
## 当启用时，此 AudioManager 可以从父场景的 AudioManager 继承配置。
## TODO: 实现配置继承机制，支持：
## - 从父 AudioManager 继承 global_limit_config
## - 合并父级和子级的 default_categories
## - 配置优先级规则
@export var enable_inheritance: bool = true

## 全局音频限额配置（虚声部、总线限额等）
@export var global_limit_config: GlobalAudioLimitConfig

## 默认音频类别列表
@export var default_categories: Array[AudioCategory] = []

## 是否启用调试视图（未来功能）
##
## 当启用时，在编辑器中显示实时音频状态信息。
## TODO: 实现调试视图面板，显示：
## - 当前播放的音频数量
## - 各类别的音频统计
## - 实时音量和总线状态
@export var enable_debug_view: bool = false

# =============================================================================
# 私有变量
# =============================================================================

## 音频事件处理器
var _audio_handler: JuicyAudioEventHandler

# =============================================================================
# 生命周期方法
# =============================================================================

func _ready() -> void:
	# 设置静态引用
	_instance = self

	add_to_group("audio_manager")

	_apply_scene_config()

	# 注册到 EventHandlingMiddleware（配置中心）
	_register_to_event_middleware()

	print("[AudioManager] Initialized with scene-level config")

# =============================================================================
# 场景配置应用
# =============================================================================

func _apply_scene_config() -> void:
	if global_limit_config:
		_audio_handler.set_global_config(global_limit_config)
		print("[AudioManager] Applied global limit config")

	for category in default_categories:
		if category:
			_audio_handler.register_category(category)

	if default_categories.size() > 0:
		print("[AudioManager] Registered %d categories" % default_categories.size())

# =============================================================================
# 公共 API
# =============================================================================

## 获取音频事件处理器
func get_audio_handler() -> JuicyAudioEventHandler:
	return _audio_handler

## 运行时更新混音配置
##
## 更新实例级混音配置。
## TODO: 实现配置变更通知机制，通知所有子节点更新其混音配置
##
## 可能的实现方式：
## 1. 发送信号通知配置已更新
## 2. 遍历子节点并调用其更新方法
## 3. 使用观察者模式
##
## 参数:
## new_config: 新的混音配置
func update_mixing_config(new_config: AudioMixingConfig) -> void:
	if not new_config:
		push_warning("[AudioManager] Attempted to set null mixing config, ignoring")
		return

	instance_mixing_config = new_config
	# TODO: 通知所有使用此配置的子节点

## 运行时更新全局限额配置
##
## 更新全局音频限额配置并立即应用到音频处理器。
##
## 参数:
## new_config: 新的全局限额配置
func update_global_config(new_config: GlobalAudioLimitConfig) -> void:
	if not new_config:
		push_warning("[AudioManager] Attempted to set null global limit config, ignoring")
		return

	global_limit_config = new_config
	if _audio_handler:
		_audio_handler.set_global_config(new_config)


# =============================================================================
# EventHandlingMiddleware 注册
# =============================================================================

## 注册 AudioEventHandler 到 EventHandlingMiddleware
##
## AudioManager 作为配置中心，将其配置好的 AudioEventHandler 注册到 JuicyMixer 事件系统
## 这样所有 JuicyAudioPlayer 都可以通过 JuicyMixer.play_event() 使用同一个 handler
func _register_to_event_middleware() -> void:
	# 获取 JuicyMixer 实例
	var juicy_mixer = JuicyMixer.instance
	if not juicy_mixer:
		push_warning("[AudioManager] JuicyMixer 未初始化，无法注册 EventHandler 到事件系统")
		return

	# 获取 EventHandlingMiddleware
	var event_middleware = juicy_mixer.get_middleware("EventHandlingMiddleware")
	if not event_middleware:
		push_warning("[AudioManager] EventHandlingMiddleware 未找到")
		return

	# 检查是否已注册
	var existing_handler = event_middleware.get_event_handler("AudioEventHandler")
	if existing_handler:
		# 已有 handler 注册，使用已注册的（可能是其他 AudioManager 注册的）
		if existing_handler != _audio_handler:
			print("[AudioManager] AudioEventHandler 已由其他 AudioManager 注册，使用已注册的 handler")
			_audio_handler = existing_handler as JuicyAudioEventHandler
		else:
			if enable_debug_view:
				print("[AudioManager] AudioEventHandler 已注册")
		return

	# 注册 AudioEventHandler（使用最高优先级 0，确保配置中心的 handler 优先使用）
	_audio_handler = JuicyAudioEventHandler.new()
	var register_success = event_middleware.register_event_handler(_audio_handler, 0)

	if register_success:
		print("[AudioManager] AudioEventHandler 已注册到 EventHandlingMiddleware（优先级 0 - 配置中心）")
	else:
		push_error("[AudioManager] 注册 AudioEventHandler 失败")
