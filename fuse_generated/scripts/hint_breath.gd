# ============================================================
# 由 Fuse 场景毕业导出器生成 — 委托数据块勿手工编辑
# System: hint_breath | 源单元: Control/TitleHint/HintBreath (L2) @ res://demos/fuse/brickian/title_scene.tscn
# 原生覆盖率: 0/2 (0%) | 委托: TweenFadeIn, TweenFadeOut
# 采用: 禁用源 Trigger 节点 → 本脚本挂到同路径节点 → 运行验证
# 回滚: 恢复源 Trigger → 移除本脚本
# ============================================================
extends Node

const FuseDelegation := preload("res://addons/fuse/core/graduation/fuse_delegation.gd")

# ---- 委托数据块（PresetValueCodec 重建为 BaseInstruction）----
const _DELEGATED := {"u1_d0":[{"duration":0.5,"easing_type":1,"from_alpha":0.0,"target_custom_scope_id":"","target_node":"..","target_scope":0,"target_scope_source":0,"target_target_node_path":"","target_variable":"","to_alpha":1.0,"trans_type":1,"type":"TweenFadeIn","use_physics_process":false,"use_variable_for_target":false},{"auto_free":false,"duration":0.5,"easing_type":1,"target_custom_scope_id":"","target_node":"..","target_scope":0,"target_scope_source":0,"target_target_node_path":"","target_variable":"","trans_type":3,"type":"TweenFadeOut","use_physics_process":false,"use_variable_for_target":false}]}

var _delegated := {}
var _gate := {}
var _busy_u1 := false

func _ready() -> void:
	_delegated = FuseDelegation.build_delegated(_DELEGATED)
	_setup_interval_u1()

func _exit_tree() -> void:
	FuseDelegation.teardown(self)


func _on_u1(event_args: Dictionary = {}) -> void:
	if _busy_u1:
		return
	if not FuseDelegation.gate_allows(_gate, "u1", false, 0, 1.0, get_instance_id()):
		return
	_busy_u1 = true
	await _body_u1(event_args)
	_busy_u1 = false


func _body_u1(event_args: Dictionary) -> void:
	await FuseDelegation.run(self, _delegated["u1_d0"], 0, event_args)


var _timer_u1: Timer = null
var _repeats_u1: int = 0

func _setup_interval_u1() -> void:
	_timer_u1 = Timer.new()
	_timer_u1.wait_time = 1.3
	_timer_u1.one_shot = false
	_timer_u1.timeout.connect(_on_interval_u1)
	add_child(_timer_u1)
	_timer_u1.start()

func _on_interval_u1() -> void:
	_repeats_u1 += 1
	if FuseDelegation.check_condition(self, {"cache_context_changes":true,"cache_duration":1.0,"check_input_map_actions":true,"check_raw_gamepad":false,"check_raw_keyboard":false,"check_raw_mouse":false,"enable_cache":false,"enabled":true,"gamepad_device":-1,"hash_all_variables":false,"negate_result":false,"type":"CheckAnyInput"}, {}, {"repeat_count": _repeats_u1, "max_repeats": 0, "is_last_trigger": false}):
		_stop_interval_u1()
		return
	_on_u1({})

func _stop_interval_u1() -> void:
	if _timer_u1 != null:
		_timer_u1.stop()
