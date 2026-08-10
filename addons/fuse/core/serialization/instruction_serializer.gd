@tool
extends RefCounted
class_name InstructionSerializer

## 指令序列化器
##
## 提供指令的序列化和反序列化功能，独立于编辑器工具类。
## 现在内部调用 PresetValueCodec，确保嵌套条件/子指令也能正确 round-trip。

const _PRESET_VALUE_CODEC := preload("res://addons/fuse/core/serialization/preset_value_codec.gd")

const _BASE_PROPERTIES := [
	"log_level",
	"completion_timing",
	"execution_mode",
	"script",
	"resource_local_to_scene",
	"resource_name",
	"metadata"
]


static func serialize_instruction(instruction: BaseInstruction) -> Dictionary:
	if not instruction:
		return {}
	return _PRESET_VALUE_CODEC.serialize_instruction(instruction)


static func deserialize_instruction(data: Dictionary) -> BaseInstruction:
	if not data or not data.has("type"):
		return null
	return _PRESET_VALUE_CODEC.deserialize_instruction(data)


static func serialize_instructions_batch(instructions: Array[BaseInstruction]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for instruction in instructions:
		if instruction is BaseInstruction:
			serialized.append(serialize_instruction(instruction))
	return serialized


static func deserialize_instructions_batch(data_array: Array[Dictionary]) -> Array[BaseInstruction]:
	var instructions: Array[BaseInstruction] = []
	for data in data_array:
		var instruction := deserialize_instruction(data)
		if instruction:
			instructions.append(instruction)
	return instructions


static func validate_serialized_data(data: Dictionary) -> bool:
	return data and data.has("type") and ClassDB.class_exists(data["type"])


static func get_instruction_description(instruction: BaseInstruction) -> String:
	if not instruction:
		return "未知指令"
	var description: String = instruction.get_script().get_class_name()
	match description:
		"PlaySoundInstruction":
			var sound_resource = instruction.get("sound_resource")
			if sound_resource:
				description += ": " + sound_resource.resource_path.get_file()
		"PlayAnimationInstruction":
			var animation_name = instruction.get("animation_name")
			if animation_name:
				description += ": " + animation_name
		"ScreenShakeInstruction":
			var intensity = instruction.get("intensity")
			if intensity != null:
				description += ": " + str(intensity)
	return description
