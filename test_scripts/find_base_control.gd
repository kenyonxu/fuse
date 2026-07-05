class_name FindBaseControl
extends EditorPlugin

func get_output_panel() -> Control:
	return EditorInterface.get_base_control().find_child("AnimationPlayerEditor", true, false)


