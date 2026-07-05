extends Sprite2D
class_name QuickAutoDetectTest

## 快速测试节点 - 包含简单信号
signal simple_signal()
signal signal_with_param(value: int)

func _ready():
	print("[QuickAutoDetectTest] Ready - 我有 2 个自定义信号")
