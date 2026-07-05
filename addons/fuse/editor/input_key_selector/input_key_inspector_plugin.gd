# 文件：addons/fuse/editor/input_key_selector/input_key_inspector_plugin.gd
@tool
extends EditorInspectorPlugin

func _can_handle(object):
	return object is OnInputKey

func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	if name == "key_code" and object is OnInputKey:
		var selector = InputKeySelector.new()
		add_property_editor(name, selector)
		return true
	return false