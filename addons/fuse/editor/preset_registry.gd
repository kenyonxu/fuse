# addons/fuse/editor/preset_registry.gd
class_name PresetRegistry
extends RefCounted

## 预设注册表 — 扫描 presets/ 目录,缓存所有 FusePreset

static var _presets: Array[FusePreset] = []


static func scan_presets() -> void:
	_presets.clear()
	var dir := DirAccess.open("res://addons/fuse/presets/")
	if dir == null:
		return
	_scan_recursive(dir, "res://addons/fuse/presets/")


static func _scan_recursive(dir: DirAccess, base_path: String) -> void:
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := base_path.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				var sub := DirAccess.open(full_path)
				if sub:
					_scan_recursive(sub, full_path)
		elif file_name.ends_with(".tres"):
			var preset = load(full_path) as FusePreset
			if preset:
				_presets.append(preset)
		file_name = dir.get_next()
	dir.list_dir_end()


static func get_all() -> Array[FusePreset]:
	return _presets


static func get_by_category(category: String) -> Array[FusePreset]:
	var result: Array[FusePreset] = []
	for p in _presets:
		if p.category == category:
			result.append(p)
	return result


static func get_categories() -> Array[String]:
	var result: Array[String] = []
	for p in _presets:
		if p.category not in result:
			result.append(p.category)
	return result


static func clear() -> void:
	_presets.clear()
