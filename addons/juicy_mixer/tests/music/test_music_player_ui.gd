extends Control

## MusicPlayer UI 测试场景
##
## 测试 MusicPlayer 的所有功能：
## - 状态映射加载（场景中已预配置）
## - 压入/弹出状态
## - 优先级管理（支持枚举和自定义配置）
## - 堆栈信息显示
##
## 快捷键：
## - Backspace：运行测试场景 1（基本压入弹出）
## - Shift + Backspace：运行测试场景 2（优先级覆盖）
## - Shift + Alt + Backspace：运行测试场景 3（使用优先级名称）
##
## 配置：
## - 场景中预配置了 state_map（5 个状态：Menu, Exploring, Combat, Boss, Event）
## - 场景中预配置了 priority_config（优先级 0-4）

# =============================================================================
# 节点引用
# =============================================================================

@onready var music_player: MusicPlayer = $MusicPlayer

# UI 引用
@onready var state_map_status: Label = $UIPanel/HBoxContainer/VBoxContainer/StateMapSection/StateMapStatus
@onready var current_state_label: Label = $UIPanel/HBoxContainer/VBoxContainer2/InfoSection/CurrentStateLabel
@onready var current_priority_label: Label = $UIPanel/HBoxContainer/VBoxContainer2/InfoSection/CurrentPriorityLabel
@onready var stack_size_label: Label = $UIPanel/HBoxContainer/VBoxContainer2/InfoSection/StackSizeLabel
@onready var debug_info: Label = $UIPanel/HBoxContainer/VBoxContainer2/DebugSection/DebugInfo

# 播放信息更新定时器
var _playback_info_timer: Timer = null

# =============================================================================
# 配置
# =============================================================================

## 测试用状态映射路径（现在场景中已预配置）
const TEST_STATE_MAP_PATH = "res://addons/juicy_mixer/tests/music/test_music_state_map.tres"

## 优先级配置（与场景中的 priority_config 对应）
enum TestPriority {
	EXPLORING = 0,   ## 探索音乐
	COMBAT = 1,      ## 战斗音乐
	BOSS = 2,        ## Boss战音乐
	EVENT = 3,       ## 特殊事件音乐
	MENU = 4         ## 菜单音乐
}

# =============================================================================
# 生命周期
# =============================================================================

func _ready():
	print("\n=== MusicPlayer UI 测试场景启动 ===\n")

	# 连接 MusicPlayer 信号
	music_player.state_changed.connect(_on_state_changed)
	music_player.state_pushed.connect(_on_state_pushed)
	music_player.state_popped.connect(_on_state_popped)

	# 检查配置状态
	if music_player.state_map:
		var state_count = music_player.state_map.get_state_count()
		state_map_status.text = "已预配置 (%d 个状态)" % state_count
		print("✓ 状态映射已配置: %d 个状态" % state_count)
	else:
		state_map_status.text = "未配置"
		print("✗ 状态映射未配置")

	if music_player.priority_config:
		print("✓ 优先级配置已加载: %d 个优先级" % music_player.priority_config.get_priority_count())
		print("  ", music_player.priority_config.get_priority_info())
	else:
		print("⚠ 优先级配置未加载（将使用枚举默认值）")

	# 创建播放信息更新定时器
	_playback_info_timer = Timer.new()
	_playback_info_timer.wait_time = 0.1  # 每 100ms 更新一次
	_playback_info_timer.timeout.connect(_on_playback_info_timer)
	add_child(_playback_info_timer)
	_playback_info_timer.start()

	# 更新 UI
	_update_ui()

	print("\n测试场景初始化完成")
	print("音乐播放器: ", music_player)
	print("音乐管理器: ", MusicManager.get_instance())

# =============================================================================
# UI 事件处理
# =============================================================================

## 加载测试状态映射（场景中已预配置，此功能保留用于测试外部资源加载）
func _on_load_state_map():
	print("\n--- 加载外部测试状态映射 ---")

	if not ResourceLoader.exists(TEST_STATE_MAP_PATH):
		push_error("测试状态映射文件不存在: %s" % TEST_STATE_MAP_PATH)
		state_map_status.text = "错误：文件不存在"
		return

	var state_map = load(TEST_STATE_MAP_PATH) as MusicStateMap
	if not state_map:
		push_error("无法加载状态映射资源")
		state_map_status.text = "错误：加载失败"
		return

	music_player.state_map = state_map
	state_map_status.text = "外部加载 (%d 个状态)" % state_map.get_state_count()

	print("✓ 外部状态映射加载成功")
	print(state_map.get_state_info())

## 压入状态 - Menu (Priority 0)
func _on_push_menu():
	_perform_push(&"Menu", TestPriority.MENU)

## 压入状态 - Exploring (Priority 1)
func _on_push_exploring():
	_perform_push(&"Exploring", TestPriority.EXPLORING)

## 压入状态 - Combat (Priority 2)
func _on_push_combat():
	_perform_push(&"Combat", TestPriority.COMBAT)

## 压入状态 - Boss (Priority 3)
func _on_push_boss():
	_perform_push(&"Boss", TestPriority.BOSS)

## 压入状态 - Event (Priority 4)
func _on_push_event():
	_perform_push(&"Event", TestPriority.EVENT)

## 弹出状态 - Menu
func _on_pop_menu():
	_perform_pop(&"Menu")

## 弹出状态 - Exploring
func _on_pop_exploring():
	_perform_pop(&"Exploring")

## 弹出状态 - Combat
func _on_pop_combat():
	_perform_pop(&"Combat")

## 弹出状态 - Boss
func _on_pop_boss():
	_perform_pop(&"Boss")

## 弹出状态 - Event
func _on_pop_event():
	_perform_pop(&"Event")

## 停止所有音乐
func _on_stop_all():
	print("\n--- 停止所有音乐 ---")
	music_player.stop_all()
	_update_ui()

## 清空堆栈
func _on_clear_stack():
	print("\n--- 清空堆栈 ---")

	# 停止所有音乐并清空堆栈
	music_player.stop_all()

	print("堆栈已清空")
	_update_ui()

# =============================================================================
# MusicPlayer 信号处理
# =============================================================================

func _on_state_changed(old_state: StringName, new_state: StringName, track: MusicTrackResource):
	print("\n[信号] 状态切换: %s → %s" % [old_state, new_state])
	_update_ui()

func _on_state_pushed(state: StringName, priority: int):
	print("\n[信号] 状态压入: %s (优先级 %d)" % [state, priority])
	_update_ui()

func _on_state_popped(state: StringName):
	print("\n[信号] 状态弹出: %s" % state)
	_update_ui()

# =============================================================================
# 内部辅助方法
# =============================================================================

## 执行压入操作
func _perform_push(state: StringName, priority: int):
	print("\n--- 压入状态: %s (优先级 %d) ---" % [state, priority])

	var success = music_player.push_state(state, priority, 2.0)

	if success:
		print("✓ 压入成功")
	else:
		print("✗ 压入失败")

	_update_ui()

## 执行弹出操作
func _perform_pop(state: StringName):
	print("\n--- 弹出状态: %s ---" % state)

	var success = music_player.pop_state(state, 2.0)

	if success:
		print("✓ 弹出成功")
	else:
		print("✗ 弹出失败（状态不在堆栈中）")

	_update_ui()

## 更新 UI 显示
func _update_ui():
	# 更新当前状态信息
	var current_state = music_player.get_current_state()
	if current_state == &"":
		current_state_label.text = "当前状态: 无"
	else:
		current_state_label.text = "当前状态: %s" % current_state

	# 更新优先级
	var priority = music_player.get_current_priority()
	current_priority_label.text = "当前优先级: %d" % priority

	# 更新堆栈大小
	var stack_size = music_player.get_stack_size()
	stack_size_label.text = "堆栈大小: %d" % stack_size

	# 更新调试信息（包含播放信息）
	_update_debug_info()

## 播放信息定时器回调
func _on_playback_info_timer():
	"""定期更新播放信息"""
	_update_debug_info()

## 更新调试信息（包含播放详情）
func _update_debug_info():
	var info_lines: Array[String] = []

	# 堆栈信息
	var stack_info = music_player.get_stack_info()
	info_lines.append(stack_info)

	# 当前播放信息
	var current_state = music_player.get_current_state()
	if current_state != &"":
		info_lines.append("\n--- 当前播放 ---")

		# 获取播放详情
		var playback_details = _get_playback_details()
		if playback_details:
			info_lines.append(playback_details)

	debug_info.text = "\n".join(info_lines)

## 获取当前播放详情
func _get_playback_details() -> String:
	"""获取当前播放的详细信息"""
	var music_manager = MusicManager.get_instance()
	if not music_manager:
		return "MusicManager 未初始化"

	# 获取当前状态和优先级
	var current_state = music_player.get_current_state()
	var priority = music_player.get_current_priority()

	var details: Array[String] = []

	# 状态和优先级
	details.append("状态: %s" % current_state)
	details.append("优先级: %d" % priority)

	# 如果没有播放音乐，返回基础信息
	if current_state == &"":
		return "\n".join(details)

	# 从 state_map 获取当前状态的轨道资源
	if not music_player.state_map:
		return "\n".join(details)

	var track = music_player.state_map.get_track(current_state)
	if not track or not track.loop_stream:
		details.append("音频: 无")
		details.append("时长: --:--")
		details.append("进度: --:-- / --:--")
		return "\n".join(details)

	# 获取音频文件名
	var audio_stream_name = track.loop_stream.resource_path.get_file().get_basename()
	details.append("音频: %s" % audio_stream_name)

	# 获取音频总时长
	var stream_length = track.get_loop_duration()
	if stream_length <= 0:
		details.append("时长: --:--")
		details.append("进度: --:-- / --:--")
		return "\n".join(details)

	var total_minutes = int(stream_length) / 60
	var total_seconds = int(stream_length) % 60
	var total_time_str = "%d:%02d" % [total_minutes, total_seconds]

	# 尝试从场景树中找到当前播放的 AudioStreamPlayer
	var current_pos_str = "--:--"
	var progress_percent = "0%"

	# 在 MusicManager 下查找 AudioStreamPlayer
	var audio_players = []
	_find_audio_stream_players(music_manager, audio_players)

	if audio_players.size() > 0:
		var player = audio_players[0]  # 获取第一个播放器
		if player and player.playing:
			var current_pos = player.get_playback_position()
			var curr_minutes = int(current_pos) / 60
			var curr_seconds = int(current_pos) % 60
			current_pos_str = "%d:%02d" % [curr_minutes, curr_seconds]

			# 计算进度百分比
			var progress = (current_pos / stream_length) * 100
			progress_percent = "%.1f%%" % progress

	details.append("时长: %s" % total_time_str)
	details.append("进度: %s / %s (%s)" % [current_pos_str, total_time_str, progress_percent])

	return "\n".join(details)

## 递归查找 AudioStreamPlayer 节点
func _find_audio_stream_players(node: Node, result: Array):
	"""递归查找所有 AudioStreamPlayer 节点"""
	if node is AudioStreamPlayer:
		var player = node as AudioStreamPlayer
		if player.playing:  # 只添加正在播放的
			result.append(player)

	for child in node.get_children():
		_find_audio_stream_players(child, result)

# =============================================================================
# 测试场景
# =============================================================================

## 预定义的测试流程
func run_test_scenario_1():
	"""
	测试场景 1：基本压入弹出
	"""
	print("\n========== 测试场景 1：基本压入弹出 ==========\n")

	print("步骤 1: 压入 Exploring (优先级 1)")
	music_player.push_state(&"Exploring", TestPriority.EXPLORING)
	await get_tree().create_timer(3.0).timeout

	print("\n步骤 2: 压入 Combat (优先级 2)")
	music_player.push_state(&"Combat", TestPriority.COMBAT)
	await get_tree().create_timer(3.0).timeout

	print("\n步骤 3: 弹出 Combat")
	music_player.pop_state(&"Combat")
	await get_tree().create_timer(3.0).timeout

	print("\n✓ 测试场景 1 完成\n")

## 预定义的测试流程 2
func run_test_scenario_2():
	"""
	测试场景 2：优先级覆盖
	"""
	print("\n========== 测试场景 2：优先级覆盖 ==========\n")

	print("步骤 1: 压入 Menu (优先级 0)")
	music_player.push_state(&"Menu", TestPriority.MENU)
	await get_tree().create_timer(3.0).timeout

	print("\n步骤 2: 压入 Combat (优先级 2)")
	music_player.push_state(&"Combat", TestPriority.COMBAT)
	await get_tree().create_timer(3.0).timeout

	print("\n步骤 3: 压入 Boss (优先级 3)")
	music_player.push_state(&"Boss", TestPriority.BOSS)
	await get_tree().create_timer(3.0).timeout

	print("\n步骤 4: 弹出 Boss")
	music_player.pop_state(&"Boss")
	await get_tree().create_timer(3.0).timeout

	print("\n步骤 5: 弹出 Combat")
	music_player.pop_state(&"Combat")
	await get_tree().create_timer(3.0).timeout

	print("\n✓ 测试场景 2 完成\n")

## 预定义的测试流程 3 - 使用优先级名称
func run_test_scenario_3():
	"""
	测试场景 3：使用优先级名称（push_state_by_name）
	"""
	print("\n========== 测试场景 3：使用优先级名称 ==========\n")

	if not music_player.priority_config:
		print("⚠ 跳过：未配置 priority_config")
		return

	print("步骤 1: 使用优先级名称 'Exploring' 压入状态")
	music_player.push_state_by_name(&"Exploring", &"Exploring")
	await get_tree().create_timer(3.0).timeout

	print("\n步骤 2: 使用优先级名称 'Combat' 压入状态")
	music_player.push_state_by_name(&"Combat", &"Combat")
	await get_tree().create_timer(3.0).timeout

	print("\n步骤 3: 使用优先级名称 'Boss' 压入状态")
	music_player.push_state_by_name(&"Boss", &"Boss")
	await get_tree().create_timer(3.0).timeout

	print("\n步骤 4: 弹出 Boss")
	music_player.pop_state(&"Boss")
	await get_tree().create_timer(3.0).timeout

	print("\n✓ 测试场景 3 完成\n")

# =============================================================================
# 快捷键
# =============================================================================

func _input(event):
	if not event.is_pressed():
		return

	# 快捷键：按 Backspace 运行测试场景
	if event.is_action("ui_text_backspace"):
		if Input.is_key_pressed(KEY_SHIFT):
			if Input.is_key_pressed(KEY_ALT):
				# Shift + Alt + Backspace：运行测试场景 3（使用优先级名称）
				run_test_scenario_3()
			else:
				# Shift + Backspace：运行测试场景 2
				run_test_scenario_2()
		else:
			# Backspace：运行测试场景 1
			run_test_scenario_1()
