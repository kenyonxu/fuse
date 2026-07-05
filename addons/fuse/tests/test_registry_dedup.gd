extends Node

## ComponentRegistry 去重行为测试
## 验证：同一 identifier 重复注册后，get_all() 仅返回一份

const FixtureInstruction = preload("res://addons/fuse/tests/fixtures/fixture_instruction.gd")

var _passed := 0
var _failed := 0

func _ready():
	print("=== ComponentRegistry 去重测试 ===")
	_test_dedup_on_duplicate_identifier()
	_test_unique_identifiers_unchanged()
	_print_summary()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(1 if _failed > 0 else 0)

func _test_dedup_on_duplicate_identifier() -> void:
	ComponentRegistry.clear_all(ComponentRegistry.ComponentType.INSTRUCTION)

	# 同一脚本注册两次 → 同一 identifier
	ComponentRegistry.register(ComponentRegistry.ComponentType.INSTRUCTION, FixtureInstruction, "_get_instruction_metadata")
	ComponentRegistry.register(ComponentRegistry.ComponentType.INSTRUCTION, FixtureInstruction, "_get_instruction_metadata")

	var all = ComponentRegistry.get_all(ComponentRegistry.ComponentType.INSTRUCTION)
	var count = all.size()

	if count == 1:
		print("✓ 重复注册去重：get_all 返回 %d 项（期望 1）" % count)
		_passed += 1
	else:
		print("✗ 重复注册去重：get_all 返回 %d 项（期望 1）" % count)
		_failed += 1

	# map 查询应能命中且为最后一份
	var by_name = ComponentRegistry.get_by_name(ComponentRegistry.ComponentType.INSTRUCTION, "TestFixtureInstruction")
	if by_name.size() > 0:
		print("✓ get_by_name 命中")
		_passed += 1
	else:
		print("✗ get_by_name 未命中")
		_failed += 1

func _test_unique_identifiers_unchanged() -> void:
	ComponentRegistry.clear_all(ComponentRegistry.ComponentType.INSTRUCTION)
	# 单次注册
	ComponentRegistry.register(ComponentRegistry.ComponentType.INSTRUCTION, FixtureInstruction, "_get_instruction_metadata")
	var count = ComponentRegistry.get_all(ComponentRegistry.ComponentType.INSTRUCTION).size()
	if count == 1:
		print("✓ 单次注册：get_all 返回 %d 项（期望 1）" % count)
		_passed += 1
	else:
		print("✗ 单次注册：get_all 返回 %d 项（期望 1）" % count)
		_failed += 1

func _print_summary() -> void:
	print("\n=== 测试结果：%d 通过，%d 失败 ===" % [_passed, _failed])
