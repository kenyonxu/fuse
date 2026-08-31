# ============================================================
# 由 Fuse 场景毕业导出器生成 — 委托数据块勿手工编辑
# System: game_flow | 源单元: GameManager/GameFlow (L4) @ res://demos/fuse/brickian/game_scene.tscn
# 原生覆盖率: 3/28 (11%) | 委托: CrossfadeToMusic, LoadGlobalVariables, PauseGame, GetPosition, MathOperation, GetAllChildrenPosition, WarmUpPool, WarmUpPool, WarmUpPool, WarmUpPool, WarmUpPool, WarmUpPool, WarmUpPool, WarmUpPool, RunRunner, MathOperation, MathOperation, SetVariable, SendEvent, IfThen, MathOperation, PauseGame, IfElse, MathOperation, IfElse
# 采用: 禁用源 Trigger 节点 → 本脚本挂到同路径节点 → 运行验证
# 回滚: 恢复源 Trigger → 移除本脚本
# 降级备案: b0 该绑定生成时由 RESTART 降级为 SKIP（运行中重触发忽略
#   而非重启；请人工确认重触发时上一轮执行已完成）
# ============================================================
extends Node

const FuseDelegation := preload("res://addons/fuse/core/graduation/fuse_delegation.gd")

# ---- 委托数据块（PresetValueCodec 重建为 BaseInstruction）----
const _DELEGATED := {"b0_d0":[{"bus":"Music","continue_during_pause":true,"crossfade_duration":2.0,"music_path":"uid://bi1lb4nvpv6gn","type":"CrossfadeToMusic","volume":1.0}],"b1_d0":[{"custom_path":"","load_source":0,"type":"LoadGlobalVariables"}],"b1_d1":[{"pause_menu_parent":"","pause_menu_scene":"","show_pause_menu":false,"type":"PauseGame","ui_node_path":"../../GameSceneCanvas"}],"b1_d10":[{"batch_delay":0.1,"batch_size":5,"pool_initial_size":20,"pool_max_size":100,"scene_path":"uid://pvuvnyrhmc36","type":"WarmUpPool","warm_up_count":10,"warm_up_mode":1}],"b1_d11":[{"batch_delay":0.1,"batch_size":5,"pool_initial_size":10,"pool_max_size":10,"scene_path":"uid://c3b28ywrqiogw","type":"WarmUpPool","warm_up_count":3,"warm_up_mode":0}],"b1_d12":[{"batch_delay":0.1,"batch_size":5,"pool_initial_size":20,"pool_max_size":30,"scene_path":"uid://dadlwb08j675g","type":"WarmUpPool","warm_up_count":10,"warm_up_mode":0}],"b1_d14":[{"context_node_path":"","custom_scope_id":"","result_variable_name":"","result_variable_scope":0,"scope_source":0,"store_result":false,"target_node_path":"","target_runner":"../SpawnEnemy","type":"RunRunner","wait_for_completion":true}],"b1_d2":[{"custom_scope_id":"","save_to_scope":1,"save_to_variable":"start_pos","scope_source":0,"target":"../../Game_Layer/PlayerShip","target_custom_scope_id":"","target_scope":0,"target_scope_source":0,"target_target_node_path":"","target_variable":"","type":"GetPosition","use_global_position":true,"use_variable":false}],"b1_d3":[{"custom_scope_id":"","operand_a_custom_scope_id":"","operand_a_scope":1,"operand_a_scope_source":0,"operand_a_source":1,"operand_a_variable":"current_wave","operand_b_custom_scope_id":"","operand_b_scope_source":0,"operand_b_source":0,"operand_b_target_node_path":"","operand_b_value":1.0,"operation_type":0,"save_to_scope":1,"save_to_variable":"current_wave","scope_source":0,"target_node_path":"","type":"MathOperation"}],"b1_d4":[{"custom_scope_id":"","recursive":false,"result_scope":1,"result_variable":"spawn_pos","scope_source":0,"target_custom_scope_id":"","target_node":"../../Game_Layer/Markers","target_scope":0,"target_scope_source":0,"target_target_node_path":"","target_variable":"","type":"GetAllChildrenPosition","use_global_position":true,"use_variable_for_target":false}],"b1_d5":[{"batch_delay":0.1,"batch_size":5,"pool_initial_size":20,"pool_max_size":100,"scene_path":"uid://bmfgotihlmfkw","type":"WarmUpPool","warm_up_count":20,"warm_up_mode":1}],"b1_d6":[{"batch_delay":0.1,"batch_size":5,"pool_initial_size":20,"pool_max_size":100,"scene_path":"uid://cq7h6ykrfu4kv","type":"WarmUpPool","warm_up_count":20,"warm_up_mode":1}],"b1_d7":[{"batch_delay":0.1,"batch_size":5,"pool_initial_size":20,"pool_max_size":100,"scene_path":"uid://ctimwhiu78cr8","type":"WarmUpPool","warm_up_count":20,"warm_up_mode":1}],"b1_d8":[{"batch_delay":0.1,"batch_size":100,"pool_initial_size":300,"pool_max_size":500,"scene_path":"uid://bd83gfasoidja","type":"WarmUpPool","warm_up_count":300,"warm_up_mode":1}],"b1_d9":[{"batch_delay":0.1,"batch_size":5,"pool_initial_size":20,"pool_max_size":100,"scene_path":"uid://b4e65c431qgjd","type":"WarmUpPool","warm_up_count":20,"warm_up_mode":1}],"b2_d0":[{"custom_scope_id":"","operand_a_custom_scope_id":"","operand_a_scope":1,"operand_a_scope_source":0,"operand_a_source":1,"operand_a_variable":"enemy_count","operand_b_custom_scope_id":"","operand_b_scope_source":0,"operand_b_source":0,"operand_b_target_node_path":"","operand_b_value":1.0,"operation_type":1,"save_to_scope":1,"save_to_variable":"enemy_count","scope_source":0,"target_node_path":"","type":"MathOperation"}],"b2_d1":[{"custom_scope_id":"","operand_a_custom_scope_id":"","operand_a_scope":1,"operand_a_scope_source":0,"operand_a_source":1,"operand_a_variable":"current_score","operand_b_custom_scope_id":"","operand_b_scope":0,"operand_b_scope_source":0,"operand_b_source":1,"operand_b_target_node_path":"","operand_b_variable":"event_score","operation_type":0,"save_to_scope":1,"save_to_variable":"current_score","scope_source":0,"target_node_path":"","type":"MathOperation"}],"b2_d2":[{"custom_scope_id":"","from_scope_source":0,"from_variable":"current_score","from_variable_scope":1,"scope_source":0,"set_with_another_variable":true,"target_node_path":"","target_variable":"c_score","target_variable_scope":0,"type":"SetVariable"}],"b2_d3":[{"deferred":false,"event_args":{"score":"$c_score"},"event_name":"ScoreUpdate","type":"SendEvent"}],"b2_d4":[{"condition":{"auto_convert_types":true,"cache_context_changes":true,"cache_duration":1.0,"case_sensitive":true,"check_with_another_variable":false,"compare_custom_scope_id":"","compare_scope_source":0,"compare_target_node_path":"","compare_variable":"","compare_variable_scope":0,"comparison_operator":3,"custom_scope_id":"","enable_cache":false,"enabled":true,"expected_value":1,"hash_all_variables":false,"negate_result":false,"scope_source":0,"target_node_path":"","treat_empty_as_null":false,"type":"CheckVariable","variable_name":"enemy_count","variable_scope":1},"instructions":[{"deferred":false,"event_args":{},"event_name":"AllEnemyDied","type":"SendEvent"}],"sequence_mode":1,"type":"IfThen"}],"b3_d0":[{"custom_scope_id":"","operand_a_custom_scope_id":"","operand_a_scope":1,"operand_a_scope_source":0,"operand_a_source":1,"operand_a_variable":"player_life","operand_b_custom_scope_id":"","operand_b_scope_source":0,"operand_b_source":0,"operand_b_target_node_path":"","operand_b_value":1.0,"operation_type":1,"save_to_scope":1,"save_to_variable":"player_life","scope_source":0,"target_node_path":"","type":"MathOperation"}],"b3_d2":[{"pause_menu_parent":"","pause_menu_scene":"","show_pause_menu":false,"type":"PauseGame","ui_node_path":"../../GameSceneCanvas"}],"b3_d4":[{"condition":{"auto_convert_types":true,"cache_context_changes":true,"cache_duration":1.0,"case_sensitive":true,"check_with_another_variable":false,"compare_custom_scope_id":"","compare_scope_source":0,"compare_target_node_path":"","compare_variable":"","compare_variable_scope":0,"comparison_operator":3,"custom_scope_id":"","enable_cache":false,"enabled":true,"expected_value":0,"hash_all_variables":false,"negate_result":false,"scope_source":0,"target_node_path":"","treat_empty_as_null":false,"type":"CheckVariable","variable_name":"player_life","variable_scope":1},"false_instructions":[{"deferred":false,"event_args":{},"event_name":"StartCountDown","type":"SendEvent"},{"custom_scope_id":"","scope_source":0,"target_node_path":"","type":"Wait","value_source":0,"wait_time":2.0},{"custom_scope_id":"","parent_node":"","position_mode":1,"position_scope":1,"position_scope_source":0,"position_variable":"start_pos","save_instance_id":false,"save_to_scope":0,"scene_path":"uid://c37gfmeoqbajm","scope_source":0,"spawn_offset":"(0.0, 0.0, 0.0)","spawn_position":"(0.0, 0.0, 0.0)","target_node_path":"","target_variable":"instance_id","type":"InstantiateScene","use_object_pool":false},{"custom_scope_id":"","scope_source":0,"target_node_path":"","type":"Wait","value_source":0,"wait_time":1.0},{"close_pause_menu":false,"pause_menu_node":"","type":"ResumeGame","ui_node_path":"../../GameSceneCanvas"}],"sequence_mode":1,"true_instructions":[{"condition":{"auto_convert_types":true,"cache_context_changes":true,"cache_duration":1.0,"case_sensitive":true,"check_with_another_variable":false,"compare_custom_scope_id":"","compare_scope_source":0,"compare_target_node_path":"","compare_variable":"","compare_variable_scope":0,"comparison_operator":2,"custom_scope_id":"","enable_cache":false,"enabled":true,"expected_value":0,"hash_all_variables":false,"negate_result":false,"scope_source":0,"target_node_path":"","treat_empty_as_null":false,"type":"CheckVariable","variable_name":"current_score","variable_scope":1},"instructions":[{"array_custom_scope_id":"","array_scope":2,"array_scope_source":0,"array_target_node_path":"","array_variable":"score_list","element_custom_scope_id":"","element_from_variable":"current_score","element_from_variable_scope":1,"element_scope_source":0,"element_target_node_path":"","element_value":null,"group_name":"","source_type":0,"target_node_path":"","type":"ArrayAdd","use_element_from_variable":true}],"sequence_mode":1,"type":"IfThen"},{"deferred":false,"event_args":{"end":"loss"},"event_name":"GameEnd","type":"SendEvent"}],"type":"IfElse"}],"b4_d0":[{"custom_scope_id":"","operand_a_custom_scope_id":"","operand_a_scope":1,"operand_a_scope_source":0,"operand_a_source":1,"operand_a_variable":"current_wave","operand_b_custom_scope_id":"","operand_b_scope_source":0,"operand_b_source":0,"operand_b_target_node_path":"","operand_b_value":1.0,"operation_type":0,"save_to_scope":1,"save_to_variable":"current_wave","scope_source":0,"target_node_path":"","type":"MathOperation"}],"b4_d1":[{"condition":{"auto_convert_types":true,"cache_context_changes":true,"cache_duration":1.0,"case_sensitive":true,"check_with_another_variable":false,"compare_custom_scope_id":"","compare_scope_source":0,"compare_target_node_path":"","compare_variable":"","compare_variable_scope":0,"comparison_operator":5,"custom_scope_id":"","enable_cache":false,"enabled":true,"expected_value":3,"hash_all_variables":false,"negate_result":false,"scope_source":0,"target_node_path":"","treat_empty_as_null":false,"type":"CheckVariable","variable_name":"current_wave","variable_scope":1},"false_instructions":[{"deferred":false,"event_args":{"end":"win"},"event_name":"GameEnd","type":"SendEvent"}],"sequence_mode":1,"true_instructions":[{"pause_menu_parent":"","pause_menu_scene":"","show_pause_menu":false,"type":"PauseGame","ui_node_path":"../../GameSceneCanvas"},{"context_node_path":"","custom_scope_id":"","result_variable_name":"","result_variable_scope":0,"scope_source":0,"store_result":false,"target_node_path":"","target_runner":"../SpawnEnemy","type":"RunRunner","wait_for_completion":false}],"type":"IfElse"}]}

var _delegated := {}
var _gate := {}

func _ready() -> void:
	_delegated = FuseDelegation.build_delegated(_DELEGATED)
	_setup_interval_b0()
	_on_b1.call_deferred()
	_sub_b2 = FuseDelegation.subscribe("EnemyDie", _on_evt_b2)
	_sub_b3 = FuseDelegation.subscribe("PlayerDie", _on_evt_b3)
	_sub_b4 = FuseDelegation.subscribe("AllEnemyDied", _on_evt_b4)

func _exit_tree() -> void:
	FuseDelegation.teardown(self)
	FuseDelegation.unsubscribe(_sub_b2)
	FuseDelegation.unsubscribe(_sub_b3)
	FuseDelegation.unsubscribe(_sub_b4)


func _on_b0(event_args: Dictionary = {}) -> void:
	if not FuseDelegation.gate_allows(_gate, "b0", false, 0, 1.0, get_instance_id()):
		return
	await FuseDelegation.run(self, _delegated["b0_d0"], 0, event_args)


func _on_b1(event_args: Dictionary = {}) -> void:
	if not FuseDelegation.gate_allows(_gate, "b1", false, 0, 1.0, get_instance_id()):
		return
	await FuseDelegation.run(self, _delegated["b1_d0"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b1_d1"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b1_d2"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b1_d3"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b1_d4"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b1_d5"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b1_d6"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b1_d7"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b1_d8"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b1_d9"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b1_d10"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b1_d11"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b1_d12"], 0, event_args)
	await get_tree().create_timer(0.1).timeout
	await FuseDelegation.run(self, _delegated["b1_d14"], 0, event_args)


func _on_b2(event_args: Dictionary = {}) -> void:
	if not FuseDelegation.gate_allows(_gate, "b2", false, 0, 1.0, get_instance_id()):
		return
	await FuseDelegation.run(self, _delegated["b2_d0"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b2_d1"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b2_d2"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b2_d3"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b2_d4"], 0, event_args)


func _on_b3(event_args: Dictionary = {}) -> void:
	if not FuseDelegation.gate_allows(_gate, "b3", false, 0, 1.0, get_instance_id()):
		return
	await FuseDelegation.run(self, _delegated["b3_d0"], 0, event_args)
	await get_tree().create_timer(0.5).timeout
	await FuseDelegation.run(self, _delegated["b3_d2"], 0, event_args)
	await get_tree().create_timer(0.1).timeout
	await FuseDelegation.run(self, _delegated["b3_d4"], 0, event_args)


func _on_b4(event_args: Dictionary = {}) -> void:
	if not FuseDelegation.gate_allows(_gate, "b4", false, 0, 1.0, get_instance_id()):
		return
	await FuseDelegation.run(self, _delegated["b4_d0"], 0, event_args)
	await FuseDelegation.run(self, _delegated["b4_d1"], 0, event_args)


var _timer_b0: Timer = null
var _repeats_b0: int = 0

func _setup_interval_b0() -> void:
	_timer_b0 = Timer.new()
	_timer_b0.wait_time = 25.0
	_timer_b0.one_shot = false
	_timer_b0.timeout.connect(_on_interval_b0)
	add_child(_timer_b0)
	_timer_b0.start()
	_on_interval_b0.call_deferred()

func _on_interval_b0() -> void:
	_repeats_b0 += 1
	_on_b0({})

func _stop_interval_b0() -> void:
	if _timer_b0 != null:
		_timer_b0.stop()


var _sub_b2: Variant = null

func _on_evt_b2(args: Dictionary) -> void:
	_on_b2(args)


var _sub_b3: Variant = null

func _on_evt_b3(args: Dictionary) -> void:
	_on_b3(args)


var _sub_b4: Variant = null

func _on_evt_b4(args: Dictionary) -> void:
	_on_b4(args)
