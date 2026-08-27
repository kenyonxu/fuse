# 文件：addons/fuse/core/event_binding.gd
@tool
class_name EventBinding extends Resource

## EventBinding - 单个 Event + ActionRunner 的配置单元
##
## 用于 MultiEventTrigger 中配置一个事件绑定，
## 包含事件定义、动作运行器以及触发控制参数。
##
## 注意：CooldownMode 定义在 BaseTrigger 中，通过 BaseTrigger.CooldownMode 访问。


## 运行中重新触发策略
enum RetriggerPolicy {
	SKIP,     ## ActionRunner 运行中忽略新触发（默认，旧行为）
	RESTART,  ## ActionRunner 运行中取消当前执行并重新开始
}

## ==================== 导出属性 ====================

## 事件定义
@export var event: BaseEvent:
	set(value):
		event = value
		_update_resource_name()
		emit_changed()

## 动作运行器
@export var action_runner: ActionRunner:
	set(value):
		action_runner = value
		emit_changed()

## 是否启用
@export var enabled: bool = true:
	set(value):
		enabled = value
		emit_changed()

## 是否只触发一次
@export var trigger_once: bool = false:
	set(value):
		trigger_once = value
		emit_changed()

## 运行中重新触发策略
## 事件在 ActionRunner 尚未执行完时再次触发的处理方式
@export var retrigger_policy: RetriggerPolicy = RetriggerPolicy.SKIP:
	set(value):
		retrigger_policy = value
		emit_changed()

## 冷却模式
@export var cooldown_mode: BaseTrigger.CooldownMode = BaseTrigger.CooldownMode.NONE:
	set(value):
		cooldown_mode = value
		emit_changed()

## 冷却时间（秒）
@export_range(0.0, 60.0, 0.1) var cooldown_time: float = 0.0:
	set(value):
		cooldown_time = value
		emit_changed()

## 是否启用条件检查
@export var use_conditions: bool = false:
	set(value):
		use_conditions = value
		emit_changed()
		notify_property_list_changed()

## 条件列表（用于并行条件评估）
## 触发事件前会检查所有条件，只有全部满足才执行 ActionRunner
var conditions: Array[BaseCondition] = []:
	set(value):
		conditions = value
		emit_changed()

## ==================== 编辑器属性 ====================

func _get_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if use_conditions:
		list.append({
			"name": "conditions",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	return list

## ==================== 生命周期 ====================

func _init() -> void:
	resource_name = "EventBinding"
	_update_resource_name()

## ==================== 私有方法 ====================

## 更新资源名称
func _update_resource_name() -> void:
	if event != null:
		var event_name := event.get_description() if event.has_method("get_description") else event.resource_name
		resource_name = event_name if not event_name.is_empty() else "EventBinding"
	else:
		resource_name = "EventBinding"

## ==================== 辅助方法 ====================

## 获取描述信息
func get_description() -> String:
	var desc: String = ""

	if event != null:
		desc = event.get_description()
	else:
		desc = FuseLocalization.translate("FUSE_TRIGGER_NO_EVENT")

	if trigger_once:
		desc += " [触发一次]"

	if retrigger_policy == RetriggerPolicy.RESTART:
		desc += " [运行中重启]"

	if cooldown_mode != BaseTrigger.CooldownMode.NONE and cooldown_time > 0.0:
		var mode_text: String = ""
		match cooldown_mode:
			BaseTrigger.CooldownMode.GLOBAL_COOLDOWN:
				mode_text = "全局冷却"
			BaseTrigger.CooldownMode.PER_OBJECT_COOLDOWN:
				mode_text = "每物体冷却"
		desc += " [%s %.1fs]" % [mode_text, cooldown_time]

	return desc

## 验证配置
func validate() -> Array[String]:
	var errors: Array[String] = []

	if event == null:
		errors.append(FuseLocalization.translate("FUSE_ERROR_EVENT_DEFINITION_NOT_SPECIFIED"))

	if action_runner == null:
		errors.append(FuseLocalization.translate("FUSE_ERROR_ACTION_RUNNER_NOT_SPECIFIED"))

	if event != null:
		errors.append_array(event.validate())

	return errors
