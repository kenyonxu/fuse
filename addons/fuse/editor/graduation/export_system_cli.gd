# addons/fuse/editor/graduation/export_system_cli.gd
extends Node

## 毕业导出 CLI 入口（M2 收口，spec §7）
## 用法: godot --headless --path . res://addons/fuse/editor/graduation/export_system.tscn \
##        -- <system.json> [<system.json>...]
## 单个 System 流程：读 JSON → SystemValidator.validate_system（有 error 拒生成）→
## load 源场景实例化取 unit 节点 → GdscriptEmitter.emit_system →
## 写 emit.output_script + <stem>.report.md → headless load() 解析验证零错。
## 退出码：0 = 全部成功；1 = 校验/生成/解析 error；2 = 参数/IO 错误

const MARKER_WIDTH := 60


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var targets: Array[String] = []
	for a in args:
		if a != "--":
			targets.append(a)
	if targets.is_empty():
		printerr("用法: export_system.tscn -- <system.json> [<system.json>...]")
		get_tree().quit(2)
		return
	var io_error := false
	var gen_failed := false
	for raw in targets:
		var outcome := _export_one(_normalize(raw))
		if outcome == 2:
			io_error = true
		elif outcome == 1:
			gen_failed = true
	get_tree().quit(2 if io_error else 1 if gen_failed else 0)


# 相对路径转 res:// 前缀；res:// 与绝对路径原样保留
func _normalize(t: String) -> String:
	if t.begins_with("res://") or t.begins_with("user://") or t.is_absolute_path():
		return t
	return "res://" + t.trim_prefix("./")


## 导出单个 System；@return 0 成功 / 1 error / 2 IO 错
func _export_one(path: String) -> int:
	print("─".repeat(MARKER_WIDTH))
	print("export: %s" % path)

	# 1. 读 + 解析 System JSON
	if not FileAccess.file_exists(path):
		printerr("  [IO] System 文件不存在: %s" % path)
		return 2
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		printerr("  [IO] JSON 解析失败或顶层非对象: %s" % path)
		return 2
	var system: Dictionary = parsed

	# 2. 离线校验门禁（有 error 拒绝生成）
	var verdict: Dictionary = SystemValidator.validate_system(path)
	for f: Dictionary in verdict.findings:
		if f.severity != "info":
			print("  [%s] %s  %s  %s" % [f.severity, f.code, f.json_path, f.message])
	if verdict.errors > 0:
		print("  ✗ 拒绝生成：校验 error %d 项（先过 validate_system 再导出）" % verdict.errors)
		return 1

	# 3. load 源场景取 unit 节点（MVP 单单元）
	var units: Array = system.get("units", [])
	if units.size() != 1:
		print("  ✗ 拒绝生成：MVP 仅支持单单元 System（units=%d）" % units.size())
		return 1
	var unit: Dictionary = units[0]
	var scene_path: String = str(unit.get("scene", ""))
	var packed: PackedScene = load(scene_path) if ResourceLoader.exists(scene_path) else null
	if packed == null:
		printerr("  [IO] 源场景无法加载: %s" % scene_path)
		return 2
	var inst: Node = packed.instantiate()
	add_child(inst)
	var node_path: String = str(unit.get("node_path", ""))
	var unit_node: Node = inst if node_path.is_empty() else inst.get_node_or_null(NodePath(node_path))

	# 4. 发射（errors 非空拒生成）
	var result: Dictionary = GdscriptEmitter.emit_system(system, unit_node, scene_path)
	var report: Dictionary = result.get("report", {})
	var errors: Array = report.get("errors", [])
	inst.queue_free()
	if not errors.is_empty() or str(result.get("script_text", "")).is_empty():
		for e: Dictionary in errors:
			print("  [error] %s  %s" % [e.get("code", "?"), e.get("detail", "")])
		_print_full_lists(report)  # 终审 I4：拒生成也打印完整降级/跳过清单
		print("  ✗ 拒绝生成：发射器 error %d 项" % errors.size())
		return 1

	# 5. 写 output_script + <stem>.report.md（report 写失败计 IO 错误 → exit 2）
	var out_path: String = str(system.get("emit", {}).get("output_script", ""))
	var write_err := _write_text(out_path, str(result["script_text"]))
	if write_err != OK:
		printerr("  [IO] 无法写入 %s (err=%d)" % [out_path, write_err])
		return 2
	var report_path := out_path.get_base_dir().path_join(
		"%s.report.md" % out_path.get_file().get_basename())
	var report_err := _write_text(report_path, _render_report(report, out_path))
	if report_err != OK:
		printerr("  [IO] 无法写入报告 %s (err=%d)" % [report_path, report_err])
		push_error("report.md 写入失败: %s" % report_path)
		return 2

	# 6. headless load() 解析验证（can_instantiate = 零解析错）
	var script: GDScript = load(out_path)
	if script == null or not script.can_instantiate():
		printerr("  [error] 生成脚本解析失败（load/can_instantiate 不过）: %s" % out_path)
		return 1

	var total := int(report.get("total_instructions", 0))
	var native := int(report.get("native_count", 0))
	var pct := 100 if total == 0 else int(round(native * 100.0 / total))
	print("  ✓ %s（原生 %d/%d = %d%%，委托 %d 项，disabled 跳过 %d）→ %s" % [
		system.get("name", "?"), native, total, pct,
		int(report.get("delegated_count", 0)),
		(report.get("skipped_disabled_bindings", []) as Array).size(), out_path])
	# 终审 I4：成功路径同样打印完整清单（非仅数量）
	_print_full_lists(report)
	return 0


## 完整降级/跳过清单（终审 I4）：downgraded / disabled / local 全委托三类，
## 拒生成与成功路径共用——用户据打印即可核对全部非常规处置，无需另开 report
func _print_full_lists(report: Dictionary) -> void:
	var downgraded: Array = report.get("downgraded_restart_bindings", [])
	if not downgraded.is_empty():
		print("  降级 RESTART→SKIP: [%s]（详见 report）" % "、".join(PackedStringArray(downgraded)))
	var skipped: Array = report.get("skipped_disabled_bindings", [])
	if not skipped.is_empty():
		print("  跳过 disabled bindings: [%s]（未发射任何指令）" % "、".join(PackedStringArray(skipped)))
	var local_all: Array = report.get("local_delegated_bindings", [])
	if not local_all.is_empty():
		print("  LOCAL 整条委托: [%s]（LOCAL 变量单 ctx 贯穿，覆盖率数字因此下降）"
			% "、".join(PackedStringArray(local_all)))


func _write_text(path: String, text: String) -> int:
	var dir_err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if dir_err != OK:
		return dir_err
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	return OK


## 覆盖率报告 → markdown（emit.output_script 同目录 <stem>.report.md）。
## 风险行按 report 数据条件追加（终审 I3）：输入事件时序 / CheckAnyInput 即时
## 探测 / 条件失败不进冷却偏差 / LOCAL 整条委托备案。
func _render_report(report: Dictionary, out_path: String) -> String:
	var unit: Dictionary = report.get("unit", {})
	var total := int(report.get("total_instructions", 0))
	var native := int(report.get("native_count", 0))
	var pct := 100 if total == 0 else int(round(native * 100.0 / total))
	var delegated_names: Array = report.get("delegated_names", [])
	var skipped: Array = report.get("skipped_disabled_bindings", [])
	var downgraded: Array = report.get("downgraded_restart_bindings", [])
	var local_all: Array = report.get("local_delegated_bindings", [])
	var lines: Array[String] = []
	lines.append("# 毕业导出报告 — %s\n" % report.get("system_name", "?"))
	lines.append("- 源单元: `%s` (%s)" % [unit.get("node_path", "?"), unit.get("level", "?")])
	lines.append("- 生成脚本: `%s`（本报告同目录）" % out_path)
	lines.append("- 指令总数: %d（含 bindings，不含 disabled 跳过项）" % total)
	lines.append("- 原生覆盖率: **%d/%d (%d%%)**" % [native, total, pct])
	lines.append("- 委托指令: %d 项（经 FuseDelegation 桥执行）" % int(report.get("delegated_count", 0)))
	lines.append("- 跳过的 disabled bindings: %s" % (str(skipped) if not skipped.is_empty() else "无"))
	lines.append("- RESTART→SKIP 降级 bindings: %s" \
		% (str(downgraded) if not downgraded.is_empty() else "无"))
	if not local_all.is_empty():
		lines.append(("- LOCAL 整条委托 bindings: %s（binding 内 LOCAL 变量跨指令共享单 ctx，"
			+ "与源 Fuse 一致；原生覆盖率数字因此下降）") % str(local_all))
	lines.append("")
	var risks: Array[String] = []
	if bool(report.get("has_input_events", false)):
		risks.append("- 含输入事件：输入处理阶段时序与 Fuse 可能不同（_unhandled_input，"
			+ "Fuse 走事件实例输入回调）")
	for key: String in report.get("check_any_input_bindings", []):
		risks.append(("- binding %s：CheckAnyInput 即时探测语义（2×interval 窗口语义未复刻，"
			+ "生成代码每滴答即时检查）") % key)
	for key: String in report.get("cond_cooldown_deviation_bindings", []):
		risks.append(("- binding %s：条件失败不进冷却（Fuse 在条件检查前已消耗冷却时间戳，"
			+ "生成代码条件通过才 commit——条件反复失败的触发间隔比 Fuse 更密）") % key)
	if not risks.is_empty():
		lines.append("## 已知语义风险\n")
		for risk: String in risks:
			lines.append(risk)
		lines.append("")
	if not delegated_names.is_empty():
		lines.append("## 委托清单（按生成顺序）\n")
		for i: int in delegated_names.size():
			lines.append("%d. %s" % [i + 1, delegated_names[i]])
		lines.append("")
	lines.append("## 采用与回滚\n")
	lines.append("采用：禁用源 Trigger 节点 → 本脚本挂到同路径节点 → 运行验证。")
	lines.append("回滚：恢复源 Trigger → 移除本脚本。")
	lines.append("")
	return "\n".join(lines)
