# addons/fuse/editor/graduation/derive_systems_cli.gd
extends Node

## System 推导 CLI 入口（M1 毕业导出器）
## 用法: godot --headless --path . res://addons/fuse/editor/graduation/derive_systems.tscn \
##        -- --scene res://<scene.tscn> [--out res://fuse_generated/systems/drafts]
## 落盘 <out>/<snake_case_name>.json（tab 缩进、UTF-8 无 BOM）；草稿不入库（.gitignore）
## 另落盘 <out>/_derive_report.json（终审 I1：skipped/components/warnings_by_unit 完整
## 报告——用户可据此构造 acknowledged_warnings 四元组，无需重跑推导）
## 退出码：0 = 成功；2 = 参数或 IO 错误

## 推导报告文件名（与草稿同目录，_ 前缀排序置顶区分非草稿）
const REPORT_NAME := "_derive_report.json"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := ""
	var out_dir := "res://fuse_generated/systems/drafts"
	var i := 0
	while i < args.size():
		match args[i]:
			"--scene":
				i += 1
				if i < args.size():
					scene_path = args[i]
			"--out":
				i += 1
				if i < args.size():
					out_dir = args[i]
		i += 1
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		printerr("用法: derive_systems.tscn -- --scene res://<scene.tscn> [--out <dir>]")
		get_tree().quit(2)
		return
	var scene: PackedScene = load(scene_path)
	if scene == null:
		printerr("场景加载失败: %s" % scene_path)
		get_tree().quit(2)
		return
	var inst := scene.instantiate()
	add_child(inst)
	var result: Dictionary = SystemDeriver.derive_systems(inst, scene_path)
	inst.queue_free()

	var mk_err := DirAccess.make_dir_recursive_absolute(out_dir)
	if mk_err != OK:
		printerr("无法创建输出目录: %s (err=%d)" % [out_dir, mk_err])
		get_tree().quit(2)
		return
	var written := 0
	for draft: Dictionary in result["drafts"]:
		var path := out_dir.path_join("%s.json" % draft["name"])
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			printerr("无法写入 %s (err=%d)" % [path, FileAccess.get_open_error()])
			get_tree().quit(2)
			return
		f.store_string(JSON.stringify(draft, "\t"))
		f.close()
		written += 1

	var report: Dictionary = result["report"]
	var report_err := write_report_file(out_dir, report)
	if report_err != OK:
		printerr("无法写入推导报告 %s (err=%d)" % [out_dir.path_join(REPORT_NAME), report_err])
		get_tree().quit(2)
		return
	var warn_total := 0
	for unit: String in report["warnings_by_unit"]:
		warn_total += (report["warnings_by_unit"][unit] as Array).size()
	print("systems → %s（草稿 %d 份；跳过 runner %d、嵌套 %d；竞态预警 %d 条待确认）" % [
		out_dir, written, report["skipped_runner"],
		(report["skipped_nested"] as Array).size(), warn_total])
	print("推导报告 → %s（warnings_by_unit 四元组可据此构造 acknowledged_warnings）"
		% out_dir.path_join(REPORT_NAME))
	get_tree().quit(0)


## 推导报告落盘（终审 I1）：out_dir/_derive_report.json（tab 缩进）。
## 独立 static 供测试直接断言（CLI 场景的 _ready 会 quit 进程，不可场景内驱动）。
## @return OK 或 FileAccess 错误码（目录不存在时自动创建）
static func write_report_file(out_dir: String, report: Dictionary) -> int:
	var mk_err := DirAccess.make_dir_recursive_absolute(out_dir)
	if mk_err != OK:
		return mk_err
	var f := FileAccess.open(out_dir.path_join(REPORT_NAME), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	return OK
