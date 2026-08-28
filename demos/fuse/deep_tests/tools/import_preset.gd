extends SceneTree

## deep_tests 通用 preset 导入工具（headless）
##
## 读 preset JSON，走与编辑器"导入预设"面板相同的反序列化管线
## （FusePreset.from_json + FusePresetDeserializer.deserialize），
## 把产出的节点挂到场景根并保存为 .tscn——每个测试场景的可 F5 产物。
##
## 用法：
##   Godot --headless --path <项目路径> --script res://demos/fuse/deep_tests/tools/import_preset.gd \
##     -- <preset.json> <out.tscn> [node2d|control]
## 退出码：0 成功 / 1 导入失败 / 2 参数或 IO 错误


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("[import_preset] 用法: -- <preset.json> <out.tscn> [node2d|control]")
		quit(2)
		return
	var json_path: String = args[0]
	var out_path: String = args[1]
	var root_kind: String = args[2] if args.size() > 2 else "node2d"

	var txt := FileAccess.get_file_as_string(json_path)
	if txt == "":
		push_error("[import_preset] 读不到 preset: %s" % json_path)
		quit(2)
		return
	var data: Variant = JSON.parse_string(txt)
	if not (data is Dictionary):
		push_error("[import_preset] JSON 解析失败: %s" % json_path)
		quit(2)
		return

	var preset := FusePreset.from_json(data)
	var imported: Object = FusePresetDeserializer.deserialize(preset, {})
	var node := imported as Node
	if node == null:
		push_error("[import_preset] 反序列化失败（level=%s）" % preset.level)
		quit(1)
		return

	var root: Node = Control.new() if root_kind == "control" else Node2D.new()
	root.name = String(out_path.get_file().get_basename())
	root.add_child(node)
	node.owner = root

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("[import_preset] PackedScene.pack 失败")
		quit(1)
		return
	if ResourceSaver.save(packed, out_path) != OK:
		push_error("[import_preset] 保存失败: %s" % out_path)
		quit(1)
		return
	print("[import_preset] %s -> %s (level=%s, 指令=%d)" % [
		json_path, out_path, preset.level, preset.instructions.size()])
	quit(0)
