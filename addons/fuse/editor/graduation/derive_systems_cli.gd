# addons/fuse/editor/graduation/derive_systems_cli.gd
extends Node

## System 推导 CLI 入口（M1 毕业导出器）
## 用法: godot --headless --path . res://addons/fuse/editor/graduation/derive_systems.tscn \
##        -- --scene res://<scene.tscn> [--out res://fuse_generated/systems/drafts]
## 落盘 <out>/<snake_case_name>.json（tab 缩进、UTF-8 无 BOM）；草稿不入库（.gitignore）
## 退出码：0 = 成功；2 = 参数或 IO 错误

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
	var warn_total := 0
	for unit: String in report["warnings_by_unit"]:
		warn_total += (report["warnings_by_unit"][unit] as Array).size()
	print("systems → %s（草稿 %d 份；跳过 runner %d、嵌套 %d；竞态预警 %d 条待确认）" % [
		out_dir, written, report["skipped_runner"],
		(report["skipped_nested"] as Array).size(), warn_total])
	get_tree().quit(0)
