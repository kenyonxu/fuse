# 文件：addons/fuse/editor/graduation/codegen/event_mapper.gd
@tool
class_name EventMapper
extends RefCounted

## 白名单事件 → 原生接线形态映射器（M2 毕业导出器）
##
## 四类白名单事件（OnReady / OnInputAction / OnInterval / OnReceiveEvent）映射为
## 生成脚本的三段代码片段；白名单外事件返回 mode="unsupported"，
## 由 GdscriptEmitter 以 E_EVENT_UNSUPPORTED 拒绝生成整个 System。
##
## 片段缩进约定：setup_code/teardown_code/input_branch 不带基础缩进
## （组装方逐行加 1 tab）；wiring_code 为自含缩进的顶层成员/函数块原样追加。
##
## OnInterval 带 stop_condition 时仍走原生：每滴答 FuseDelegation.check_condition
## 检查（JSON 内嵌常量），满足即停 Timer——对齐 on_interval.gd 的独立 ctx 检查语义。

const PresetValueCodec := preload("res://addons/fuse/core/serialization/preset_value_codec.gd")

const TAB := "\t"


## 映射单个事件对象为生成代码片段。
## @param event_obj: BaseEvent - 事件对象（export 阶段实取）
## @param gate_key: String - 门控/入口键（L2 为 "u1"，L4 为 "b<i>"）
## @return: Dictionary {
##   "mode": "ready"|"input"|"interval"|"receive"|"unsupported",
##   "params": {...事件参数快照...},
##   "setup_code": String（进 _ready 体；可空），
##   "teardown_code": String（进 _exit_tree 体；可空），
##   "wiring_code": String（文件尾追加的顶层成员/函数块；可空），
##   "input_branch": String（mode=="input" 时 _unhandled_input 的分支），
##   "error": String（mode=="unsupported" 时的原因说明）}
static func map_event(event_obj: BaseEvent, gate_key: String) -> Dictionary:
	if event_obj == null:
		return _unsupported("事件定义为空")
	if event_obj is OnReady:
		return _map_ready(event_obj as OnReady, gate_key)
	if event_obj is OnInputAction:
		return _map_input(event_obj as OnInputAction, gate_key)
	if event_obj is OnInterval:
		return _map_interval(event_obj as OnInterval, gate_key)
	if event_obj is OnReceiveEvent:
		return _map_receive(event_obj as OnReceiveEvent, gate_key)
	return _unsupported("事件类型 %s 不在白名单（OnReady/OnInputAction/OnInterval/OnReceiveEvent）" \
		% event_obj.get_script().get_global_name())


static func _unsupported(reason: String) -> Dictionary:
	return {
		"mode": "unsupported",
		"params": {},
		"setup_code": "",
		"teardown_code": "",
		"wiring_code": "",
		"input_branch": "",
		"error": reason,
	}


# ============================================================
# OnReady：delay=0 → call_deferred 一帧延迟（对齐 Fuse）；
# delay>0 → one-shot Timer
# ============================================================

static func _map_ready(ev: OnReady, key: String) -> Dictionary:
	var setup := ""
	if ev.delay_seconds > 0.0:
		var timer_var := "_rdy_%s" % key
		setup = _join_lines([
			"var %s: Timer = Timer.new()" % timer_var,
			"%s.wait_time = %s" % [timer_var, str(ev.delay_seconds)],
			"%s.one_shot = true" % timer_var,
			"%s.timeout.connect(_on_%s)" % [timer_var, key],
			"add_child(%s)" % timer_var,
			"%s.start()" % timer_var,
		])
	else:
		setup = "_on_%s.call_deferred()" % key
	return {
		"mode": "ready",
		"params": {"delay_seconds": ev.delay_seconds},
		"setup_code": setup,
		"teardown_code": "",
		"wiring_code": "",
		"input_branch": "",
		"error": "",
	}


# ============================================================
# OnInputAction：Input 单例判断 + event.is_action 过滤（HOLD=持续触发）
# ============================================================

static func _map_input(ev: OnInputAction, key: String) -> Dictionary:
	if ev.target_input_action.is_empty():
		return _unsupported("OnInputAction 的 target_input_action 为空")
	var action := ev.target_input_action
	var probe := ""
	match ev.trigger_mode:
		OnInputAction.TriggerMode.JUST_PRESSED:
			probe = 'Input.is_action_just_pressed("%s")' % action
		OnInputAction.TriggerMode.JUST_RELEASED:
			probe = 'Input.is_action_just_released("%s")' % action
		OnInputAction.TriggerMode.HOLD:
			probe = 'Input.is_action_pressed("%s")' % action
		OnInputAction.TriggerMode.PRESSED_OR_RELEASED:
			probe = 'Input.is_action_just_pressed("%s") or Input.is_action_just_released("%s")' \
				% [action, action]
		_:
			return _unsupported("未知 trigger_mode: %s" % str(ev.trigger_mode))
	var branch := '%sif event.is_action("%s") and %s:\n%s_on_%s({})' \
		% [TAB, action, probe, TAB + TAB, key]
	return {
		"mode": "input",
		"params": {"action": action, "trigger_mode": ev.trigger_mode},
		"setup_code": "",
		"teardown_code": "",
		"wiring_code": "",
		"input_branch": branch,
		"error": "",
	}


# ============================================================
# OnInterval：Timer 成员 + 滴答函数（max_repeats 计数 + stop_condition 原生检查）
# ============================================================

static func _map_interval(ev: OnInterval, key: String) -> Dictionary:
	var timer_var := "_timer_%s" % key
	var repeats_var := "_repeats_%s" % key
	var stop_json := ""
	if ev.stop_condition != null:
		stop_json = JSON.stringify(PresetValueCodec.serialize_condition(ev.stop_condition))

	var setup_lines: Array[String] = [
		"%s = Timer.new()" % timer_var,
		"%s.wait_time = %s" % [timer_var, _first_interval_expr(ev)],
		"%s.one_shot = %s" % [timer_var, str(ev.use_random_interval).to_lower()],
		"%s.timeout.connect(_on_interval_%s)" % [timer_var, key],
		"add_child(%s)" % timer_var,
		"%s.start()" % timer_var,
	]
	if ev.trigger_on_start:
		setup_lines.append("_on_interval_%s.call_deferred()" % key)

	var tick_lines: Array[String] = []
	if ev.max_repeats > 0:
		tick_lines.append("if %s >= %d:" % [repeats_var, ev.max_repeats])
		tick_lines.append(TAB + "_stop_interval_%s()" % key)
		tick_lines.append(TAB + "return")
	tick_lines.append("%s += 1" % repeats_var)
	if not stop_json.is_empty():
		# 滴答检查 ctx 注入 repeat_count/max_repeats/is_last_trigger
		# （对齐 on_interval.gd 的独立检查 ctx；CheckAnyInput 型分支不复刻——报告备案）
		var last_expr := "%s >= %d" % [repeats_var, ev.max_repeats] if ev.max_repeats > 0 else "false"
		var extras := '{"repeat_count": %s, "max_repeats": %d, "is_last_trigger": %s}' \
			% [repeats_var, ev.max_repeats, last_expr]
		tick_lines.append("if FuseDelegation.check_condition(self, %s, {}, %s):" % [stop_json, extras])
		tick_lines.append(TAB + "_stop_interval_%s()" % key)
		tick_lines.append(TAB + "return")
	if ev.max_repeats > 0:
		# 最后一拍当帧停 Timer（对齐 on_interval：递增后达 max_repeats 即 timer.stop()，
		# 此前实现要等下一拍兜底才停——触发次数等价，停拍时机提前一拍）
		tick_lines.append("if %s >= %d:" % [repeats_var, ev.max_repeats])
		tick_lines.append(TAB + "_stop_interval_%s()" % key)
	tick_lines.append("_on_%s({})" % key)
	if ev.use_random_interval:
		if ev.max_repeats > 0:
			# 最后一拍不重启（对齐 on_interval 的 not is_last_trigger 守卫）
			tick_lines.append("if %s < %d:" % [repeats_var, ev.max_repeats])
			tick_lines.append(TAB + "%s.wait_time = randf_range(%s, %s)" \
				% [timer_var, str(ev.min_interval_seconds), str(ev.max_interval_seconds)])
			tick_lines.append(TAB + "%s.start()" % timer_var)
		else:
			tick_lines.append("%s.wait_time = randf_range(%s, %s)" \
				% [timer_var, str(ev.min_interval_seconds), str(ev.max_interval_seconds)])
			tick_lines.append("%s.start()" % timer_var)

	var wiring := "\n\nvar %s: Timer = null\nvar %s: int = 0\n\n" % [timer_var, repeats_var]
	wiring += "func _setup_interval_%s() -> void:\n%s" % [key, _indent_block(_join_lines(setup_lines))]
	wiring += "\n\nfunc _on_interval_%s() -> void:\n%s" % [key, _indent_block(_join_lines(tick_lines))]
	wiring += "\n\nfunc _stop_interval_%s() -> void:\n%sif %s != null:\n%s%s.stop()" \
		% [key, TAB, timer_var, TAB + TAB, timer_var]

	return {
		"mode": "interval",
		"params": {
			"interval_seconds": ev.interval_seconds,
			"max_repeats": ev.max_repeats,
			"auto_start": ev.auto_start,
			"trigger_on_start": ev.trigger_on_start,
			"use_random_interval": ev.use_random_interval,
			"min_interval_seconds": ev.min_interval_seconds,
			"max_interval_seconds": ev.max_interval_seconds,
			"has_stop_condition": ev.stop_condition != null,
		},
		"setup_code": "_setup_interval_%s()" % key if ev.auto_start else "",
		"teardown_code": "",
		"wiring_code": wiring,
		"input_branch": "",
		"error": "",
	}


# ============================================================
# OnReceiveEvent：_ready 订阅 / _exit_tree 退订（args 透传入口）
# ============================================================

static func _map_receive(ev: OnReceiveEvent, key: String) -> Dictionary:
	if ev.event_name.is_empty():
		return _unsupported("OnReceiveEvent 的 event_name 为空")
	var sub_var := "_sub_%s" % key
	return {
		"mode": "receive",
		"params": {"event_name": ev.event_name, "trigger_once": ev.trigger_once},
		"setup_code": '%s = FuseDelegation.subscribe("%s", _on_evt_%s)' \
			% [sub_var, ev.event_name, key],
		"teardown_code": "FuseDelegation.unsubscribe(%s)" % sub_var,
		"wiring_code": "\n\nvar %s: Variant = null\n\nfunc _on_evt_%s(args: Dictionary) -> void:\n%s_on_%s(args)" \
			% [sub_var, key, TAB, key],
		"input_branch": "",
		"error": "",
	}


# ============================================================
# 工具
# ============================================================

## 首次间隔表达式：随机模式首拍即 randf_range（对齐 on_interval._create_timer
## 的 wait_time = _get_next_interval()——原实现误用 interval_seconds 字段值）；
## 固定模式直设 interval_seconds
static func _first_interval_expr(ev: OnInterval) -> String:
	if ev.use_random_interval:
		return "randf_range(%s, %s)" % [str(ev.min_interval_seconds), str(ev.max_interval_seconds)]
	return str(ev.interval_seconds)


## 行列表 → 单个代码块（行间换行，不加缩进）
static func _join_lines(lines: Array[String]) -> String:
	return "\n".join(lines)


## 代码块逐行加 1 tab 缩进（空行不加）
static func _indent_block(block: String) -> String:
	if block.is_empty():
		return ""
	var lines := block.split("\n")
	var out: Array[String] = []
	for line: String in lines:
		out.append(TAB + line if not line.is_empty() else line)
	return "\n".join(out)
