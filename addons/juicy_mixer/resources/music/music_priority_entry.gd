@tool
class_name MusicPriorityEntry
extends Resource

## 音乐优先级条目
##
## 定义单个优先级的配置（名称、数值、描述）

# =============================================================================
# 属性
# =============================================================================

## 优先级名称（如 &"exploring"）
@export var name: StringName = &"":
	set(new_name):
		name = new_name
		_update_resource_name()
		# 不调用 notify_property_list_changed() 以避免触发父级 setter 导致循环

## 优先级数值（越高越优先）
@export var value: int = 0:
	set(new_value):
		value = new_value
		_update_resource_name()
		# 不调用 notify_property_list_changed() 以避免触发父级 setter 导致循环

## 描述
@export var description: String = ""

# =============================================================================
# 初始化
# =============================================================================

func _init(n: StringName = &"", v: int = 0, d: String = ""):
	name = n
	value = v
	description = d

# =============================================================================
# 字符串表示
# =============================================================================

func _to_string() -> String:
	return "MusicPriorityEntry(%s, value=%d)" % [name, value]

# =============================================================================
# 更新资源显示名
# =============================================================================
func _update_resource_name():
	resource_name = "%s [%s]" % [name, value]