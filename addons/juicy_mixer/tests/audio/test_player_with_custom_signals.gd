extends Node2D
class_name TestPlayerWithCustomSignals

## 测试玩家节点 - 包含自定义信号
##
## 用于测试自动检测信号功能

## 自定义信号列表
signal health_changed(new_health: float)
signal died()
signal jumped()
signal powerup_collected(powerup_type: String)
signal level_completed(level: int)
signal checkpoint_reached(checkpoint_id: int)

## 测试属性
var health: float = 100.0

## 测试方法 - 用于触发信号
func take_damage(amount: float):
	health -= amount
	health_changed.emit(health)
	if health <= 0:
		died.emit()

func jump():
	jumped.emit()

func collect_powerup(type: String):
	powerup_collected.emit(type)

func complete_level(level: int):
	level_completed.emit(level)

func reach_checkpoint(checkpoint_id: int):
	checkpoint_reached.emit(checkpoint_id)
