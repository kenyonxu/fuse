extends CharacterBody2D

## 演示脚本：CharacterBody2D 移动控制
## 此脚本仅用于可视化调试，实际移动由 Fuse 系统控制

@export var debug_mode: bool = true

func _physics_process(delta):
	if debug_mode:
		_print_debug_info()

func _print_debug_info():
	if Engine.is_editor_hint():
		return

	# 每 60 帧打印一次（约 1 秒）
	if Engine.get_process_frames() % 60 == 0:
		print("Player Position: ", position)
		print("Player Velocity: ", velocity)
