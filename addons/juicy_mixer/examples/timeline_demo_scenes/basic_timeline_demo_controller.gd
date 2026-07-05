# 基础Timeline演示控制器

extends Node

# 引用Timeline资源
@export var timeline_resource: JuicyTimelineResource

# UI元素
var play_button: Button
var stop_button: Button
var pause_button: Button
var resume_button: Button
var progress_label: Label
var status_label: Label

# 播放状态
var current_context_id: String = ""
var is_playing: bool = false

func _ready():
	# 创建UI
	setup_ui()
	
	# 连接信号
	connect_ui_signals()

func setup_ui():
	# 创建UI容器
	var ui_container = VBoxContainer.new()
	ui_container.position = Vector2(0, 100)
	add_child(ui_container)
	
	# 创建按钮
	play_button = Button.new()
	play_button.text = "播放Timeline"
	ui_container.add_child(play_button)
	
	pause_button = Button.new()
	pause_button.text = "暂停"
	ui_container.add_child(pause_button)
	
	resume_button = Button.new()
	resume_button.text = "恢复"
	ui_container.add_child(resume_button)
	
	stop_button = Button.new()
	stop_button.text = "停止"
	ui_container.add_child(stop_button)
	
	# 创建状态标签
	status_label = Label.new()
	status_label.text = "状态: 已停止"
	ui_container.add_child(status_label)
	
	progress_label = Label.new()
	progress_label.text = "进度: 0.0%"
	ui_container.add_child(progress_label)
	
	# 初始状态
	update_ui_state()

func connect_ui_signals():
	play_button.pressed.connect(_on_play_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	stop_button.pressed.connect(_on_stop_pressed)

func _on_play_pressed():
	print("播放Timeline")
	
	if timeline_resource:
		# 获取目标节点
		var target_node = get_parent().get_node("Sprite2D")
		if target_node:
			current_context_id = JuicyMixer.play(timeline_resource, target_node)
			is_playing = true
			update_ui_state()
			
			# 连接完成信号
			var context = JuicyMixer.get_context(current_context_id)
			if context:
				context.completed.connect(_on_timeline_completed)
		else:
			print("无法获取Timeline上下文")

func _on_pause_pressed():
	print("暂停Timeline")
	
	if not current_context_id.is_empty():
		JuicyMixer.pause(current_context_id)
		is_playing = false
		update_ui_state()

func _on_resume_pressed():
	print("恢复Timeline")
	
	if not current_context_id.is_empty():
		JuicyMixer.resume(current_context_id)
		is_playing = true
		update_ui_state()

func _on_stop_pressed():
	print("停止Timeline")
	
	if not current_context_id.is_empty():
		JuicyMixer.stop(current_context_id)
		current_context_id = ""
		is_playing = false
		update_ui_state()

func _on_timeline_completed():
	print("Timeline播放完成")
	current_context_id = ""
	is_playing = false
	update_ui_state()

func _process(_delta):
	# 更新进度显示
	if is_playing and not current_context_id.is_empty():
		var context = JuicyMixer.get_context(current_context_id)
		if context:
			var progress = context.progress * 100.0
			progress_label.text = "进度: " + str(snapped(progress, 0.1)) + "%"

func update_ui_state():
	if is_playing:
		status_label.text = "状态: 播放中"
		play_button.disabled = true
		pause_button.disabled = false
		resume_button.disabled = true
		stop_button.disabled = false
	else:
		status_label.text = "状态: 已停止"
		play_button.disabled = false
		pause_button.disabled = true
		resume_button.disabled = true
		stop_button.disabled = true