@tool
class_name FixtureInstruction extends BaseInstruction

## 测试专用指令，固定 identifier，用于 ComponentRegistry 去重测试
## 放在 tests/fixtures/ 不被 _register_all_instructions 扫描（instructions/ 目录外）

static func _get_instruction_metadata() -> InstructionMetadata:
	var meta = InstructionMetadata.new()
	meta.name_key = "TestFixtureInstruction"
	meta.name = "测试夹具指令"
	meta.category = "Test"
	meta.description = "仅供 ComponentRegistry 去重测试使用"
	return meta

## 抽象方法桩实现（测试专用，无实际操作）
func _update_resource_name():
	resource_name = "FixtureInstruction"

## 抽象方法桩实现（测试专用，无实际操作）
func _setup_metadata():
	pass

## 抽象方法桩实现（测试专用，无实际操作）
func execute(context: ExecutionContext):
	pass
