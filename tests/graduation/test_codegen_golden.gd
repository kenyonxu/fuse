# tests/graduation/test_codegen_golden.gd
extends Node

## 金样例测试（T7 M2 收口；终审 C1/C2 后基线更新）
##
## 1. 首跑 Wait 探针（controller ruling 1）：进程内第一次 await
##    FuseDelegation.run(Wait 0.5) 的时长语义断言 + 根因数据打印。
##    结论备案：偏差源 = headless 下 Wait 相关脚本首次加载那一帧的 delta 膨胀
##    （编译耗时计入帧 delta）× SceneTreeTimer 按帧 delta 累积计时——帧 0 裸
##    SceneTreeTimer 同样提前完成，**非桥中继设计引入**；同进程次跑时长精确。
## 2. 金样例（game_flow L4 / hint_breath L2）生成脚本 load() 解析零错 + 委托结构在。
## 3. 覆盖率数字钉死（对账入库 report.md）。
## 4. 结构级守恒（controller ruling 5）：源场景单元序列化指令总数（含嵌套与
##    bindings，排除 disabled）== 委托 JSON 内指令数 + 原生发射数——防静默丢失。
##    终审 C1 起委托形态 = 段（LOCAL 用途 binding 整条全委托 + 连续委托合并），
##    守恒按段内指令数计，另钉段数、busy 卫语句、LOCAL 备案与 I3 风险行。

## 控制流指令的嵌套指令字段（与 SystemDeriver._SUB_INSTRUCTIONS 对齐）
const _SUB_KEYS := ["instructions", "true_instructions", "false_instructions",
	"else_instructions", "loop_instructions"]

## 金样例钉死基线（export CLI 实际生成产物；重跑生成若数字漂移，本测试挂）。
## 口径：total = 源场景全量指令数（含嵌套）；top = 顶层槽位数（emitter 发射单位，
## 嵌套指令作为委托 JSON 的一部分随顶层指令整体重建）；
## delegated = 委托 JSON 内顶层指令数（终审 C1 后 LOCAL 用途 binding 整条全委托 +
## 连续委托合并段——b2/b3 全委托使 b3 原本原生的 2 个 Wait 转委托，native 由 3 降 1）；
## segments = _DELEGATED 条目数（委托段数；连续委托合并后远小于逐指令一段）
const GOLDEN := {
	"game_flow": {
		"scene": "res://demos/fuse/brickian/game_scene.tscn",
		"node_path": "GameManager/GameFlow",
		"delegated": 27, "native": 1, "top": 28, "total": 40, "segments": 6,
		"local_bindings": ["b2", "b3"],
	},
	"hint_breath": {
		"scene": "res://demos/fuse/brickian/title_scene.tscn",
		"node_path": "Control/TitleHint/HintBreath",
		"delegated": 2, "native": 0, "top": 2, "total": 2, "segments": 1,
		"local_bindings": [],
	},
}

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("✓ " + msg)
	else:
		_fail += 1
		push_error("✗ " + msg)


func _ready() -> void:
	print("=== test_codegen_golden ===")
	# 探针必须第一个跑：其后任何 Wait 都不是进程首跑
	await _probe_first_run_wait()
	_test_golden_generation()
	_test_golden_structure_count()
	print("=== test_codegen_golden 完成（失败 %d）===" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


# ============================================================
# 首跑 Wait 探针（ruling 1：时长语义 + 根因数据）
# ============================================================

func _probe_first_run_wait() -> void:
	print("--- 首跑 Wait 探针 ---")
	var holder := Node.new()
	add_child(holder)
	var delegated: Dictionary = FuseDelegation.build_delegated({
		"w": [{"type": "Wait", "wait_time": 0.5}]})

	# 首跑：Wait 内部经 SceneTreeTimer 计时（create_timer + timeout 回调）。
	# headless 下脚本首次加载那一帧 delta 膨胀（实测 ~0.15s），膨胀 delta 被
	# 计入 timer 预算 → 0.5s 实测 ~0.35-0.38s 完成。裸 SceneTreeTimer 同位置
	# 同样偏差（354ms，探针实证）→ 引擎属性，桥无责，豁免。
	# 下限 250ms 抓"更严重的提前"（T3 曾观察 0.05-0.07s 级异常）。
	var frame0 := Engine.get_process_frames()
	var t0 := Time.get_ticks_msec()
	await FuseDelegation.run(holder, delegated["w"], 0)
	var first_ms := Time.get_ticks_msec() - t0
	var frame1 := Engine.get_process_frames()
	print("  首跑 elapsed=%.0fms（frames %d→%d，当前帧 delta=%.4f）" \
		% [first_ms, frame0, frame1, get_process_delta_time()])
	_check(first_ms >= 250,
		"首跑 Wait 0.5s 偏差有界（%.0fms ≥ 250ms，SceneTreeTimer 首跑帧膨胀豁免）" % first_ms)

	# 次跑（热路径）：时长精确——一次性偏差 + 游戏运行非首跑不受影响的证据
	var t1 := Time.get_ticks_msec()
	await FuseDelegation.run(holder, delegated["w"], 0)
	var second_ms := Time.get_ticks_msec() - t1
	print("  次跑 elapsed=%.0fms（脚本已加载，delta 正常）" % second_ms)
	_check(second_ms >= 450 and second_ms <= 900,
		"次跑 Wait 0.5s 时长精确（%.0fms，非首跑不受影响）" % second_ms)
	holder.queue_free()


# ============================================================
# 金样例生成物
# ============================================================

func _test_golden_generation() -> void:
	for system_name: String in GOLDEN:
		var script_path := "res://fuse_generated/scripts/%s.gd" % system_name
		var script: Variant = load(script_path)
		_check(script is GDScript and script.can_instantiate(),
			"%s 生成脚本 load() 解析零错" % system_name)
		var text := FileAccess.get_file_as_string(script_path)
		_check(text.contains("FuseDelegation") and text.contains("_DELEGATED"),
			"%s 委托结构在（FuseDelegation + _DELEGATED）" % system_name)
		var report_path := "res://fuse_generated/scripts/%s.report.md" % system_name
		_check(FileAccess.file_exists(report_path), "%s 覆盖率报告入库" % system_name)


# ============================================================
# 结构级守恒（ruling 5）+ 覆盖率钉死
# ============================================================

func _test_golden_structure_count() -> void:
	for system_name: String in GOLDEN:
		var pinned: Dictionary = GOLDEN[system_name]

		# 1) 源场景独立计数（不挂树：_ready 游戏逻辑不跑，无写盘副作用）
		var packed: PackedScene = load(str(pinned["scene"]))
		var inst: Node = packed.instantiate()
		var unit: Node = inst.get_node_or_null(NodePath(str(pinned["node_path"])))
		var src_total := _count_unit_instructions(unit)
		var src_top := _count_unit_top_level(unit)
		inst.free()
		_check(src_total == int(pinned["total"]),
			"%s 源场景全量指令数（含嵌套）== %d（实测 %d）"
			% [system_name, pinned["total"], src_total])
		_check(src_top == int(pinned["top"]),
			"%s 源场景顶层槽位数 == %d（实测 %d）" % [system_name, pinned["top"], src_top])

		# 2) 产物对账——顶层守恒：委托 JSON 内顶层指令数 + 原生数 == 顶层槽位
		#    （防槽位静默丢失；终审 C1 后连续委托合并段，条目数≠指令数）
		var text := FileAccess.get_file_as_string(
			"res://fuse_generated/scripts/%s.gd" % system_name)
		var delegated_json := {}
		for line: String in text.split("\n"):
			if line.begins_with("const _DELEGATED := "):
				var parsed: Variant = JSON.parse_string(
					line.trim_prefix("const _DELEGATED := "))
				if parsed is Dictionary:
					delegated_json = parsed
		var delegated_count: int = 0
		for entries_v: Variant in delegated_json.values():
			if entries_v is Array:
				delegated_count += (entries_v as Array).size()
		var coverage := _parse_report_coverage(
			"res://fuse_generated/scripts/%s.report.md" % system_name)

		_check(delegated_json.size() == int(pinned["segments"]),
			"%s 委托段数 == %d（实测 %d；连续委托合并+LOCAL 整条委托）"
			% [system_name, pinned["segments"], delegated_json.size()])
		_check(text.count("await FuseDelegation.run(") == int(pinned["segments"]),
			"%s 入口体 run 行数 == 段数 %d（实测 %d）"
			% [system_name, pinned["segments"], text.count("await FuseDelegation.run(")])
		_check(delegated_count == int(pinned["delegated"]),
			"%s 委托 JSON 内顶层指令数 == %d（实测 %d）"
			% [system_name, pinned["delegated"], delegated_count])
		_check(coverage[0] == int(pinned["native"]) and coverage[1] == int(pinned["top"]),
			"%s report.md 覆盖率钉死 %d/%d（实测 %s）"
			% [system_name, pinned["native"], pinned["top"], str(coverage)])
		_check(delegated_count + coverage[0] == src_top,
			"%s 顶层守恒：源顶层 %d == 委托 %d + 原生 %d（防槽位静默丢失）"
			% [system_name, src_top, delegated_count, coverage[0]])

		# 3) 产物对账——全量守恒：委托 JSON 内指令 dict 数（含嵌套）+ 原生数 ==
		#    源全量（嵌套指令只能随委托整体带走；原生白名单均无嵌套）
		var json_inst_total := 0
		for entries: Variant in delegated_json.values():
			if entries is Array:
				json_inst_total += _count_json_instructions(entries as Array)
		_check(json_inst_total + coverage[0] == src_total,
			"%s 全量守恒：源全量 %d == 委托 JSON 内 %d + 原生 %d（嵌套不丢失）"
			% [system_name, src_total, json_inst_total, coverage[0]])
		_check((delegated_json.values() as Array).all(
			func(v): return v is Array and (v as Array).size() >= 1),
			"%s 委托块每段至少 1 条指令（合并段为多指令长数组）" % system_name)

		# 4) 终审 C1/C2 结构断言：LOCAL 整条委托备案 + 每入口 busy 卫语句
		var local_line := ""
		if text.contains("LOCAL 连续性: "):
			local_line = text.get_slice("LOCAL 连续性: ", 1).get_slice(" ", 0)
		var expect_local := "、".join(PackedStringArray(pinned["local_bindings"]))
		_check(local_line == expect_local,
			"%s 头注释 LOCAL 整条委托清单 == %s（实测 %s）"
			% [system_name, str(pinned["local_bindings"]), local_line])
		var entry_keys: Array[String] = []
		for line: String in text.split("\n"):
			if line.begins_with("func _on_"):
				var fn := line.trim_prefix("func _on_").get_slice("(", 0)
				if not fn.begins_with("interval") and not fn.begins_with("evt"):
					entry_keys.append(fn)
		for key: String in entry_keys:
			_check(text.contains("if _busy_%s:" % key)
				and text.contains("await _body_%s(event_args)" % key)
				and text.contains("_busy_%s = false" % key),
				"%s 入口 %s busy 卫语句三件套（置位检查/await body/复位）在" % [system_name, key])

		# 5) 终审 I3：hint_breath 的 CheckAnyInput 风险行入 report.md
		if system_name == "hint_breath":
			var report_md := FileAccess.get_file_as_string(
				"res://fuse_generated/scripts/hint_breath.report.md")
			_check(report_md.contains("CheckAnyInput 即时探测语义"),
				"hint_breath report.md 含 CheckAnyInput 风险行（I3）")


## report.md 的"- 原生覆盖率: **n/t (p%)**"行 → [native, total]；解析失败 [-1, -1]
func _parse_report_coverage(path: String) -> Array:
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if not line.contains("原生覆盖率"):
			continue
		var inner := line.get_slice("**", 1)  # "3/28 (11%)"
		var nums := inner.get_slice("(", 0).strip_edges()  # "3/28"
		return [int(nums.get_slice("/", 0)), int(nums.get_slice("/", 1))]
	return [-1, -1]


# ============================================================
# 源指令计数（与 GdscriptEmitter 绑定归集同语义）
# ============================================================

## 单元全部可导出指令数（全量，含嵌套）：L4 为 event_bindings[].action_runner
## （跳过 disabled），L2 为主 action_runner；每棵指令树含嵌套字段递归
func _count_unit_instructions(unit_node: Node) -> int:
	var runners := _unit_runners(unit_node)
	if runners.is_empty():
		return -1
	var total := 0
	for ar in runners:
		if ar != null:
			total += _count_instructions(ar.get("instructions"))
	return total


## 单元顶层槽位数（不递归嵌套——emitter 的发射与 report.total_instructions 口径）
func _count_unit_top_level(unit_node: Node) -> int:
	var runners := _unit_runners(unit_node)
	if runners.is_empty():
		return -1
	var total := 0
	for ar in runners:
		if ar != null:
			var instructions: Array = ar.get("instructions")
			if instructions != null:
				for inst in instructions:
					if inst != null:
						total += 1
	return total


func _unit_runners(unit_node: Node) -> Array:
	if unit_node == null:
		return []
	var runners: Array = []
	if "event_bindings" in unit_node:
		for b in unit_node.get("event_bindings"):
			if b == null or not bool(b.get("enabled")):
				continue
			runners.append(b.get("action_runner"))
	elif "event_definition" in unit_node:
		runners.append(unit_node.get("action_runner"))
	return runners


func _count_instructions(instructions: Variant) -> int:
	if instructions == null:
		return 0
	var n := 0
	for inst in instructions:
		if inst == null:
			continue
		n += 1
		for sub_key: String in _SUB_KEYS:
			if sub_key in inst:
				n += _count_instructions(inst.get(sub_key))
	return n


## 委托 JSON（PresetValueCodec 产物）内指令 dict 总数，含嵌套字段递归
func _count_json_instructions(entries: Array) -> int:
	var n := 0
	for entry_v: Variant in entries:
		if not (entry_v is Dictionary) or not (entry_v as Dictionary).has("type"):
			continue
		n += 1
		var entry: Dictionary = entry_v
		for sub_key: String in _SUB_KEYS:
			if entry.has(sub_key) and entry[sub_key] is Array:
				n += _count_json_instructions(entry[sub_key] as Array)
	return n
