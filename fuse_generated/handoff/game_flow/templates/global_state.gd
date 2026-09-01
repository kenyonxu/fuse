# 文件：addons/fuse/agent_skills/fuse-handoff-packer/assets/templates/global_state.gd
## 全局状态——Fuse global 层变量的脱离替代参考实现（推荐 autoload 命名 GlobalState）
##
## 对齐 Fuse global 层语义：全游戏持久、按名读写、不存在时自动创建（写路径）、
## 支持存档/读档（对应 LoadGlobalVariables / SaveGlobalVariables 的持久化用途）。
## 注意：Fuse 的 global 层读不存在的变量返回 null（不报错），本模板同行为。
extends Node

const SAVE_PATH := "user://global_state.cfg"

var _values: Dictionary = {}


func set_value(name: String, value: Variant) -> void:
	_values[name] = value


func get_value(name: String, default: Variant = null) -> Variant:
	return _values.get(name, default)


func has_value(name: String) -> bool:
	return _values.has(name)


func erase_value(name: String) -> void:
	_values.erase(name)


## 存档（对应 SaveGlobalVariables：全部 global 变量写盘）
## 注意：Fuse 的 SaveGlobalVariables 配 PERSISTENT_ONLY 时仅存 persistent 变量；
## 本模板 save_state 恒存全部，等价实现按 preset 配置自行加过滤。
func save_state() -> bool:
	var cfg := ConfigFile.new()
	for key in _values:
		cfg.set_value("state", key, _values[key])
	return cfg.save(SAVE_PATH) == OK


## 读档（对应 LoadGlobalVariables：从盘恢复，已有键会被盘上值覆盖）
func load_state() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	for key in cfg.get_section_keys("state"):
		_values[key] = cfg.get_value("state", key)
	return true
