@tool
extends RefCounted
class_name InstructionSerializer

## 指令序列化器
##
## 提供指令的序列化和反序列化功能，独立于编辑器工具类。
## 确保核心运行时代码不依赖编辑器模块。

# 静态属性缓存，以类型名为键存储属性列表
static var _property_cache: Dictionary = {}

# 序列化指令
## instruction: BaseInstruction - 要序列化的指令对象
## returns: Dictionary - 序列化后的字典数据
static func serialize_instruction(instruction: BaseInstruction) -> Dictionary:
	var data = {}
	
	if not instruction:
		return data
	
	var type_name = instruction.get_script().get_class_name()
	
	# 使用缓存的属性列表，如果缓存中没有则获取并缓存
	if not _property_cache.has(type_name):
		var properties = []
		var property_list = instruction.get_property_list()
		for property in property_list:
			if property.usage & PROPERTY_USAGE_STORAGE:
				properties.append(property.name)
		_property_cache[type_name] = properties
	
	# 从缓存中获取属性列表并序列化
	var properties = _property_cache[type_name]
	for property_name in properties:
		data[property_name] = instruction.get(property_name)
	
	# 添加类型信息
	data["type"] = type_name
	
	return data

# 从字典反序列化指令
## data: Dictionary - 序列化的指令数据
## returns: BaseInstruction - 反序列化的指令对象，如果数据无效则返回 null
static func deserialize_instruction(data: Dictionary) -> BaseInstruction:
	if not data or not data.has("type"):
		return null
	
	var type = data["type"]
	var instruction = _create_instruction(type)
	
	if not instruction:
		return null
	
	# 设置属性
	for property in data:
		if property != "type":
			instruction.set(property, data[property])
	
	return instruction

# 创建指令实例
## type: String - 指令类型名称
## returns: BaseInstruction - 创建的指令实例，如果类型不存在则返回 null
static func _create_instruction(type: String) -> BaseInstruction:
	if ClassDB.class_exists(type):
		return ClassDB.instantiate(type)
	else:
		push_error("Instruction type not found: %s" % type)
		return null

# 批量序列化指令
## instructions: Array[BaseInstruction] - 指令数组
## returns: Array[Dictionary] - 序列化后的指令数据数组
static func serialize_instructions_batch(instructions: Array[BaseInstruction]) -> Array[Dictionary]:
	var serialized = []
	for instruction in instructions:
		if instruction is BaseInstruction:
			serialized.append(serialize_instruction(instruction))
	return serialized

# 批量反序列化指令
## data_array: Array[Dictionary] - 序列化的指令数据数组
## returns: Array[BaseInstruction] - 反序列化的指令数组
static func deserialize_instructions_batch(data_array: Array[Dictionary]) -> Array[BaseInstruction]:
	var instructions = []
	for data in data_array:
		var instruction = deserialize_instruction(data)
		if instruction:
			instructions.append(instruction)
	return instructions

# 验证序列化数据
## data: Dictionary - 序列化的指令数据
## returns: bool - 数据是否有效
static func validate_serialized_data(data: Dictionary) -> bool:
	return data and data.has("type") and ClassDB.class_exists(data["type"])

# 获取指令描述
## instruction: BaseInstruction - 指令对象
## returns: String - 指令的描述文本
static func get_instruction_description(instruction: BaseInstruction) -> String:
	if not instruction:
		return "未知指令"
	
	var description = instruction.get_script().get_class_name()
	
	# 根据指令类型添加更多描述信息
	match instruction.get_script().get_class_name():
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
			var duration = instruction.get("duration")
			description += ": 强度 %.2f, 持续 %.2f秒" % [intensity, duration]
		"PrintInstruction":
			var message = instruction.get("message")
			if message:
				description += ": \"%s\"" % message
		"WaitInstruction":
			var duration = instruction.get("duration")
			if duration:
				description += ": %.2f秒" % duration
		"CountInstruction":
			var count = instruction.get("count")
			if count:
				description += ": %d次" % count
	
	return description