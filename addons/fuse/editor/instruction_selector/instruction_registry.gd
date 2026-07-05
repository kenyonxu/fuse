# 文件：instruction_registry.gd
class_name InstructionRegistry
extends RefCounted

## Instruction 注册器
##
## 提供便捷的 Instruction 注册方法，内部调用 ComponentRegistry
## 保持向后兼容的公共 API
##
## 使用示例：
## ```gdscript
## InstructionRegistry.register_instruction(MyInstructionScript)
## var all_instructions = InstructionRegistry.get_all_instructions()
## var my_instruction = InstructionRegistry.get_instruction_by_name("MyInstruction")
## ```

# ============================================================
# 注册方法
# ============================================================

## 注册 Instruction（内部调用 ComponentRegistry）
##
## 参数：
## - instruction_class: Instruction 类（GDScript）
##
## 保持向后兼容：调用此方法的现有代码无需修改
static func register_instruction(instruction_class: GDScript):
	ComponentRegistry.register(
		ComponentRegistry.ComponentType.INSTRUCTION,
		instruction_class,
		"_get_instruction_metadata"
	)

# ============================================================
# 查询方法（向后兼容）
# ============================================================

## 获取所有 Instruction（向后兼容方法）
##
## 返回：
## - Array[Dictionary] - Instruction 信息数组
static func get_all_instructions() -> Array[Dictionary]:
	return ComponentRegistry.get_all(ComponentRegistry.ComponentType.INSTRUCTION)

## 根据名称获取 Instruction（向后兼容方法）
##
## 参数：
## - name: Instruction 名称/标识符
##
## 返回：
## - Dictionary - Instruction 信息字典，未找到返回空字典
static func get_instruction_by_name(name: String) -> Dictionary:
	return ComponentRegistry.get_by_name(ComponentRegistry.ComponentType.INSTRUCTION, name)

## 获取 Instruction 数量（向后兼容方法）
##
## 返回：
## - int - Instruction 数量
static func get_instruction_count() -> int:
	return ComponentRegistry.get_count(ComponentRegistry.ComponentType.INSTRUCTION)

# ============================================================
# 搜索方法
# ============================================================

## 搜索 Instruction
##
## 参数：
## - query: 搜索关键词
## - search_by: 搜索字段（可选，默认搜索所有）
##   可选值："name", "category", "keywords" 或空字符串（搜索所有）
##
## 返回：
## - Array[Dictionary] - 匹配的 Instruction 信息数组
##
## 使用示例：
## ```gdscript
## # 搜索所有字段
## var results = InstructionRegistry.search_instructions("move")
##
## # 只搜索名称
## var results = InstructionRegistry.search_instructions("move", "name")
##
## # 只搜索分类
## var results = InstructionRegistry.search_instructions("move", "category")
## ```
static func search_instructions(query: String, search_by: String = "") -> Array[Dictionary]:
	return ComponentRegistry.search(ComponentRegistry.ComponentType.INSTRUCTION, query, search_by)

# ============================================================
# 清理方法
# ============================================================

## 清空所有 Instruction（用于插件卸载时）
static func clear_all():
	ComponentRegistry.clear_all(ComponentRegistry.ComponentType.INSTRUCTION)