@tool
extends Node2D

func _enter_tree() -> void:
	print("===enter tree===")
	var tool = FindBaseControl.new()
	var panel = tool.get_output_panel()
	print(panel)
	
