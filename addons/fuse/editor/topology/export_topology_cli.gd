# addons/fuse/editor/topology/export_topology_cli.gd
extends Node

## 场景拓扑 JSON 导出 CLI 入口
## 用法: godot --headless --path . res://addons/fuse/editor/topology/export_topology.tscn \
##        -- --scene res://<scene.tscn> [--out res://fuse_reports/topology]
## 退出码：0 = 成功；2 = 参数或 IO 错误

const TopologyExport := preload("res://addons/fuse/editor/topology/topology_export.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := ""
	var out_dir := "res://fuse_reports/topology"
	var i := 0
	while i < args.size():
		match args[i]:
			"--scene":
				i += 1
				if i < args.size(): scene_path = args[i]
			"--out":
				i += 1
				if i < args.size(): out_dir = args[i]
		i += 1
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		printerr("用法: export_topology.tscn -- --scene res://<scene.tscn> [--out <dir>]")
		get_tree().quit(2)
		return
	var scene: PackedScene = load(scene_path)
	if scene == null:
		printerr("场景加载失败: %s" % scene_path)
		get_tree().quit(2)
		return
	var inst := scene.instantiate()
	add_child(inst)
	var topology: Dictionary = InstructionAnalyzer.build_topology(inst)
	var path: String = TopologyExport.export_to_json(topology, out_dir)
	inst.queue_free()
	if path.is_empty():
		get_tree().quit(2)
		return
	print("topology → %s (triggers: %d, cross_refs: %d)" % [path,
		topology.triggers.size(), topology.cross_references.size()])
	get_tree().quit(0)
