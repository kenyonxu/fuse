# addons/fuse/editor/preset_ai/regen_samples.gd
extends Node

## 从源场景重导污染样例（M3，spec §6.1）
## 用当前（已修复的）序列化管线替代 2026-07-08 的过期导出产物：
## 场景内嵌 Base* 资源（condition / 嵌套指令）序列化为 inline dict，
## 不再产出 "res://xxx.tscn::Resource_xx" 私有引用与字符串化指令。
##
## 用法: godot --headless --path . res://addons/fuse/editor/preset_ai/regen_samples.tscn

const CASES := [
	{"json": "res://addons/fuse/presets/gameplay/game_flow.json",
	 "scene": "res://demos/fuse/brickian/game_scene.tscn", "node": "GameManager/GameFlow"},
	{"json": "res://addons/fuse/presets/gameplay/spawn_enemy.json",
	 "scene": "res://demos/fuse/brickian/game_scene.tscn", "node": "GameManager/SpawnEnemy",
	 # SpawnEnemy 挂的是 Runner 脚本（detect_level 判 L3），但样例层级是 L1：
	 # 强制走 L1 提取路径，保持样例层级不变
	 "force_level": "L1"},
	{"json": "res://addons/fuse/presets/ui/hint_breath.json",
	 "scene": "res://demos/fuse/brickian/title_scene.tscn", "node": "Control/TitleHint/HintBreath"},
]

func _ready() -> void:
	for c in CASES:
		_regen(c)
	print("[regen_samples] 完成")
	get_tree().quit(0)


func _regen(c: Dictionary) -> void:
	var old_text := FileAccess.get_file_as_string(c["json"])
	var old: Dictionary = JSON.parse_string(old_text) if old_text != "" else {}
	var scene: PackedScene = load(c["scene"])
	if scene == null:
		push_error("场景加载失败: %s" % c["scene"])
		return
	var inst := scene.instantiate()
	var node := inst.get_node_or_null(NodePath(c["node"]))
	if node == null:
		push_error("节点不存在: %s" % c["node"])
		inst.free()
		return

	# force_level 优先（spawn_enemy 是挂 Runner 脚本的普通 Node，自动判级会得到 L3）
	var level: String = str(c.get("force_level", ""))
	if level == "":
		level = FusePresetSerializer.detect_level(node)

	var preset := FusePreset.new()
	# 元数据与版本统一从 old 继承（format_version 必须 "2.0"，否则 E_FORMAT_VERSION）
	preset.version = "2.0"
	preset.display_name = str(old.get("display_name", str(node.name)))
	preset.category = str(old.get("category", ""))
	preset.description = str(old.get("description", ""))
	preset.icon_name = str(old.get("icon_name", ""))
	preset.level = level

	if level == "L1":
		# L1 提取路径：从节点的 action_runner 取指令数组（子节点携带 action_runner 时兜底）
		var ar: Variant = node.get("action_runner")
		if ar == null:
			for ch in node.get_children():
				var child_ar: Variant = ch.get("action_runner")
				if child_ar is ActionRunner:
					ar = child_ar
					break
		if not (ar is ActionRunner):
			push_error("无法从 %s 提取指令（action_runner 缺失）" % c["node"])
			inst.free()
			return
		preset.instructions = (ar as ActionRunner).instructions
		preset.variables = old.get("variables", preset.collect_variables())
	else:
		var data: Dictionary = FusePresetSerializer.serialize(node)
		match level:
			"L2", "L3":
				var ar_data: Dictionary = data.get("action_runner", {})
				preset.instructions = PresetValueCodec.deserialize_instructions(ar_data.get("instructions", []))
				if level == "L2":
					preset.event_json = data.get("event", {})
					preset.trigger_config = data.get("trigger_config", {})
				elif level == "L3":
					preset.signal_binding = data.get("signal_binding", {})
			"L4":
				preset.trigger_config = data.get("trigger_config", {})
				preset.event_bindings_json = data.get("event_bindings", [])
		preset.variables = old.get("variables", preset.collect_variables())

	inst.free()
	_write(c["json"], preset)


func _write(json_path: String, preset: FusePreset) -> void:
	# 保序字段：display_name 等元数据在构造 preset 时已从 old 继承
	var f := FileAccess.open(json_path, FileAccess.WRITE)
	if f == null:
		push_error("无法写入: %s" % json_path)
		return
	f.store_string(JSON.stringify(preset.to_json(), "\t"))
	f.close()
	# 同步 sample_presets 平铺副本（若存在；目录无 gameplay/ui 子层级，用文件名拼接）
	var copy := "res://addons/fuse/preset_ai_context/sample_presets/" + json_path.get_file()
	if FileAccess.file_exists(copy):
		var fc := FileAccess.open(copy, FileAccess.WRITE)
		fc.store_string(FileAccess.get_file_as_string(json_path))
		fc.close()
	print("[regen] %s" % json_path)
