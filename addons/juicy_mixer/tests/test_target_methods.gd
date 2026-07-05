# 测试目标方法脚本
# 为Timeline示例测试提供测试目标和方法

extends RefCounted

# 信号
signal method_called(method_name: String, args: Array)

# 测试方法
func activate_power_up(type: String, duration: float):
	method_called.emit("activate_power_up", [type, duration])
	print("激活能力提升: %s, 持续时间: %.1f秒" % [type, duration])

func play_sound(sound_name: String, volume: float = 1.0):
	method_called.emit("play_sound", [sound_name, volume])
	print("播放声音: %s, 音量: %.1f" % [sound_name, volume])

func spawn_effect(effect_name: String, position: Vector3):
	method_called.emit("spawn_effect", [effect_name, position])
	print("生成特效: %s, 位置: %s" % [effect_name, position])

func set_game_state(state: String):
	method_called.emit("set_game_state", [state])
	print("设置游戏状态: %s" % state)

func damage_target(target: Node, damage: float):
	method_called.emit("damage_target", [target, damage])
	print("对目标造成伤害: %.1f" % damage)

func heal_character(character: Node, amount: float):
	method_called.emit("heal_character", [character, amount])
	print("治疗角色: %.1f" % amount)

func change_scene(scene_name: String):
	method_called.emit("change_scene", [scene_name])
	print("切换场景: %s" % scene_name)

func show_dialogue(dialogue_text: String):
	method_called.emit("show_dialogue", [dialogue_text])
	print("显示对话: %s" % dialogue_text)

func hide_ui_element(element_name: String):
	method_called.emit("hide_ui_element", [element_name])
	print("隐藏UI元素: %s" % element_name)

func show_ui_element(element_name: String):
	method_called.emit("show_ui_element", [element_name])
	print("显示UI元素: %s" % element_name)

func save_game(slot: int):
	method_called.emit("save_game", [slot])
	print("保存游戏到槽位: %d" % slot)

func load_game(slot: int):
	method_called.emit("load_game", [slot])
	print("从槽位加载游戏: %d" % slot)

func quit_game():
	method_called.emit("quit_game", [])
	print("退出游戏")

func pause_game():
	method_called.emit("pause_game", [])
	print("暂停游戏")

func resume_game():
	method_called.emit("resume_game", [])
	print("恢复游戏")

func restart_level():
	method_called.emit("restart_level", [])
	print("重新开始关卡")

func complete_level(level_name: String):
	method_called.emit("complete_level", [level_name])
	print("完成关卡: %s" % level_name)

func unlock_achievement(achievement_id: String):
	method_called.emit("unlock_achievement", [achievement_id])
	print("解锁成就: %s" % achievement_id)

func add_score(points: int):
	method_called.emit("add_score", [points])
	print("增加分数: %d" % points)

func set_lives(lives: int):
	method_called.emit("set_lives", [lives])
	print("设置生命值: %d" % lives)

func game_over():
	method_called.emit("game_over", [])
	print("游戏结束")

func victory():
	method_called.emit("victory", [])
	print("胜利")