# JuicyTimeCondition - 时间条件类
# 用于基于时间的条件判断

@tool
class_name JuicyTimeCondition
extends JuicyCondition

# 时间比较操作符
enum TimeOperator {
	AFTER_START,        # 效果开始后
	BEFORE_END,         # 效果结束前
	DURATION_GREATER,   # 持续时间大于
	DURATION_LESS,       # 持续时间小于
	PROGRESS_GREATER,    # 进度大于
	PROGRESS_LESS        # 进度小于
}

# 时间条件配置
@export var time_operator: TimeOperator = TimeOperator.AFTER_START
@export var target_time: float = 0.0
@export var use_progress: bool = false  # 使用进度而非绝对时间

func evaluate(context: JuicyContext) -> bool:
	if not enabled:
		return false
	
	match time_operator:
		TimeOperator.AFTER_START:
			return context.current_time >= target_time
		TimeOperator.BEFORE_END:
			return context.current_time <= (context.duration - target_time)
		TimeOperator.DURATION_GREATER:
			return context.duration > target_time
		TimeOperator.DURATION_LESS:
			return context.duration < target_time
		TimeOperator.PROGRESS_GREATER:
			return context.progress > target_time
		TimeOperator.PROGRESS_LESS:
			return context.progress < target_time
		_:
			return false

func get_description() -> String:
	var op_str = ""
	match time_operator:
		TimeOperator.AFTER_START:
			op_str = "after %.2fs" % target_time
		TimeOperator.BEFORE_END:
			op_str = "before end by %.2fs" % target_time
		TimeOperator.DURATION_GREATER:
			op_str = "duration > %.2fs" % target_time
		TimeOperator.DURATION_LESS:
			op_str = "duration < %.2fs" % target_time
		TimeOperator.PROGRESS_GREATER:
			op_str = "progress > %.1f%%" % (target_time * 100)
		TimeOperator.PROGRESS_LESS:
			op_str = "progress < %.1f%%" % (target_time * 100)
	
	return "time %s" % op_str

func validate_condition() -> String:
	if not enabled:
		return ""
	if target_time < 0:
		return "Target time cannot be negative"
	return ""

func on_parameter_changed(parameter_name: String, old_value: float, new_value: float) -> void:
	# 时间条件不依赖参数变化，无需特殊处理
	pass