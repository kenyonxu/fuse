class_name JuicyTimelinePlayer
extends Node

@export var timeline :JuicyTimelineResource

var mixer: JuicyMixer

func _ready():
	call_deferred("get_mixer")
	print("mixer ready")

func play_timeline():
	var target = self
	if timeline:
		mixer.play(timeline, target)
	else:
		push_warning("need timeline setup!")

func get_mixer():
	mixer = JuicyMixer.instance