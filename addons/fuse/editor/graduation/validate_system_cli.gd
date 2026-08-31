# addons/fuse/editor/graduation/validate_system_cli.gd
extends Node

## System 离线校验 CLI 入口（M1 毕业导出器，spec §7）
## 用法: godot --headless --path . res://addons/fuse/editor/graduation/validate_system.tscn \
##        -- <file-or-dir> [<file-or-dir>...] [--report <out.json>]
## 退出码：0 = 无 error；1 = 有 error finding；2 = 参数/IO 错误
## stdout 只输出逐文件 PASS/FAIL + findings 行 + summary（引擎/场景加载的 warning 走 stderr）

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var targets: Array[String] = []
	var report := ""
	var i := 0
	while i < args.size():
		match args[i]:
			"--report":
				i += 1
				if i < args.size():
					report = args[i]
			"--":
				pass
			_:
				targets.append(args[i])
		i += 1
	if targets.is_empty():
		printerr("用法: validate_system.tscn -- <file-or-dir> [<file-or-dir>...] [--report <out.json>]")
		get_tree().quit(2)
		return
	for t in targets.size():
		targets[t] = _normalize_target(targets[t])
	# 多目标：逐个校验后合并，报告一次落盘（避免每个目标覆写报告）
	var all_files: Array = []
	var io_error := false
	for target in targets:
		var result: Dictionary = SystemValidator.validate_path(target)
		all_files.append_array(result.files)
		if result.summary.total == 0:
			io_error = true  # 目标不存在（validate_path 已 push_error 到 stderr）
	var failed := all_files.filter(func(f): return f.errors > 0).size()
	for f in all_files:
		var tag := "PASS" if f.errors == 0 else "FAIL"
		print("[%s] %s (errors=%d warnings=%d)" % [tag, f.path, f.errors, f.warnings])
		for fd in f.findings:
			if fd.severity != "info":
				print("    %-28s %-7s %s  %s" % [fd.code, fd.severity, fd.json_path, fd.message])
	var summary := {"total": all_files.size(), "passed": all_files.size() - failed, "failed": failed}
	print("summary: %s" % JSON.stringify(summary))
	if report != "":
		_write_report(report, all_files, summary)
		print("report → %s" % report)
	if io_error:
		get_tree().quit(2)
	else:
		get_tree().quit(1 if summary.failed > 0 else 0)


# 相对路径转 res:// 前缀；res:// user:// 与绝对路径原样保留
func _normalize_target(t: String) -> String:
	if t.begins_with("res://") or t.begins_with("user://") or t.is_absolute_path():
		return t
	return "res://" + t.trim_prefix("./")


func _write_report(report_path: String, files: Array, summary: Dictionary) -> void:
	var out := FileAccess.open(report_path, FileAccess.WRITE)
	if out == null:
		printerr("报告文件无法写入: %s" % report_path)
		return
	out.store_string(JSON.stringify({"files": files, "summary": summary}, "\t"))
	out.close()
