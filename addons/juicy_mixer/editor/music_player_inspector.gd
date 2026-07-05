@tool
extends EditorInspectorPlugin

## MusicPlayer Inspector 插件
##
## 为 MusicPlayer 添加自定义 Inspector 控件
## 包括自动创建优先级配置的按钮

const MusicPlayer = preload("res://addons/juicy_mixer/core/music_player.gd")

var _current_music_player: MusicPlayer = null
var _create_button: Button = null
var _separator: HSeparator = null


func _can_handle(object: Object) -> bool:
	"""检查是否可以处理该对象"""
	return object is MusicPlayer


func _parse_begin(object: Object) -> void:
	"""开始解析对象属性"""
	_current_music_player = object as MusicPlayer

	if not _current_music_player:
		return

	# 添加分隔符
	_separator = HSeparator.new()
	add_custom_control(_separator)

	# 添加自定义按钮控件（始终显示）
	_create_button = Button.new()
	_create_button.text = "根据 StateMap 创建优先级列表"
	_create_button.tooltip_text = "从 StateMap 的键自动创建优先级配置"
	_create_button.pressed.connect(_on_create_priority_pressed)

	# 根据 state_map 配置状态启用/禁用按钮
	_update_button_state()

	# 添加到 Inspector
	add_custom_control(_create_button)


func _update_button_state() -> void:
	"""更新按钮的启用/禁用状态"""
	if not _create_button or not _current_music_player:
		return

	# 检查是否配置了 state_map
	var has_state_map = _current_music_player.state_map != null

	# 启用/禁用按钮
	_create_button.disabled = not has_state_map

	# 更新工具提示
	if has_state_map:
		_create_button.tooltip_text = "从 StateMap 的键自动创建优先级配置\n点击执行"
	else:
		_create_button.tooltip_text = "请先配置 State Map 属性"


func _on_create_priority_pressed() -> void:
	"""处理按钮点击事件"""
	if not _current_music_player:
		return

	# 再次检查 state_map 是否配置
	if not _current_music_player.state_map:
		push_error("[MusicPlayer] 请先配置 State Map 属性")
		return

	# 调用 MusicPlayer 的创建方法
	_current_music_player._create_priority_config_from_state_map()

	# Inspector 会自动刷新，无需手动操作
