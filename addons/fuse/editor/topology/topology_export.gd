# addons/fuse/editor/topology/topology_export.gd
@tool
class_name TopologyExport
extends RefCounted

## 拓扑 report 的 JSON 导出（CLI 与拓扑面板共用）
##
## report 字典不保证全 JSON 可序列化（NodePath / Object 引用），
## sanitize 递归净化后再落盘。

## 递归净化：NodePath→str，Object→浅字典，其余原样
static func sanitize_for_json(value: Variant) -> Variant:
	if value is NodePath:
		return str(value)
	if value is Object:
		var entry := {"__object__": value.get_class()}
		var script := value.get_script() as GDScript
		if script != null and not script.get_global_name().is_empty():
			entry["__object__"] = script.get_global_name()
		if "resource_name" in value:
			entry["resource_name"] = value.resource_name
		return entry
	if value is Dictionary:
		var out := {}
		for k in value:
			out[k] = sanitize_for_json(value[k])
		return out
	if value is Array:
		var arr: Array = []
		for item in value:
			arr.append(sanitize_for_json(item))
		return arr
	return value

## 导出 topology 到 <out_dir>/<scene_name>.json，返回路径（失败 ""）
static func export_to_json(topology: Dictionary, out_dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var file_name: String = str(topology.get("scene_name", "scene"))
	var path := out_dir.path_join(file_name + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[TopologyExport] 无法写入 %s (err=%d)" % [path, FileAccess.get_open_error()])
		return ""
	f.store_string(JSON.stringify(sanitize_for_json(topology), "\t"))
	f.close()
	return path
