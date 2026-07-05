@tool
class_name FuseLocalization extends RefCounted

## Fuse 本地化管理器(Godot TranslationDomain 包装)
##
## 基于 Godot 4.6 原生 TranslationDomain(官方推荐的编辑器插件本地化方案),
## 保留 Fuse 现有 API 签名兼容。

const DOMAIN_NAME: StringName = &"fuse"

static var _domain: TranslationDomain = null
static var _translation_keys: Array[String] = []
static var _initialized: bool = false
static var _current_locale: String = "zh_CN"


static func init() -> void:
	if _initialized:
		return

	_domain = TranslationServer.get_or_add_domain(DOMAIN_NAME)
	_domain.set_locale_override(TranslationServer.get_tool_locale())
	_current_locale = TranslationServer.get_tool_locale()

	var dir := DirAccess.open("res://addons/fuse/localization/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".translation") and file_name.begins_with("fuse."):
				var res = load("res://addons/fuse/localization/" + file_name)
				if res is Translation:
					_domain.add_translation(res)
					if _translation_keys.is_empty():
						for msg_key in res.get_message_list():
							_translation_keys.append(msg_key)
			file_name = dir.get_next()
		dir.list_dir_end()

	_initialized = true
	print("FuseLocalization initialized: %d keys, locale: %s" % [_translation_keys.size(), _current_locale])


static func cleanup() -> void:
	if _domain:
		_domain.clear()
		if TranslationServer.has_domain(DOMAIN_NAME):
			TranslationServer.remove_domain(DOMAIN_NAME)
		_domain = null
	_initialized = false
	_translation_keys.clear()


static func translate(key: String) -> String:
	if not _initialized:
		init()
	if _domain:
		return _domain.translate(key, "")
	return key


static func translate_format(key: String, args: Dictionary = {}) -> String:
	var template = translate(key)
	for arg_key in args:
		template = template.replace("{%s}" % arg_key, str(args[arg_key]))
	return template


static func tr_format(key: String, args: Dictionary = {}) -> String:
	return translate_format(key, args)


static func set_locale(locale_string: String) -> void:
	if locale_string != _current_locale:
		_current_locale = locale_string
		if _domain:
			_domain.set_locale_override(locale_string)
		_notify_cache_changed()
		print("FuseLocalization: locale switched to %s" % locale_string)


static func get_current_locale() -> String:
	return _current_locale


static func get_locale_code() -> String:
	return _current_locale


static func refresh_locale() -> void:
	var new_locale := TranslationServer.get_tool_locale()
	if new_locale != _current_locale:
		set_locale(new_locale)


static func reload_translations() -> void:
	cleanup()
	init()


static func get_translation_stats() -> Dictionary:
	var total_keys = _translation_keys.size()
	return {
		"total_keys": total_keys,
		"zh_CN_coverage": 100.0 if total_keys > 0 else 0,
		"en_US_coverage": 100.0 if total_keys > 0 else 0,
		"current_locale": _current_locale
	}


static func get_missing_translations() -> Array:
	return []


static func clear_missing_translations() -> void:
	pass


static func get_supported_locales() -> Array[String]:
	return ["zh_CN", "en_US"]


static func get_locale_display_name(locale: String) -> String:
	match locale:
		"zh_CN": return "简体中文"
		"en_US": return "English"
		_: return locale


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		cleanup()


static func _notify_cache_changed() -> void:
	pass
