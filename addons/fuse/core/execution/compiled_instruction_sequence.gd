# 文件：addons/fuse/core/execution/compiled_instruction_sequence.gd
class_name CompiledInstructionSequence extends RefCounted

## CompiledInstructionSequence - 指令序列编译缓存
##
## Phase 3 性能优化：预编译指令序列的描述和方法绑定
## 减少 RuntimeActionRunnerInstance 执行时的重复计算开销
##
## 优化内容：
## - 预缓存描述字符串（避免每帧重复调用 get_description()）
## - 预绑定执行方法（避免运行时方法查找）
## - 指令数量变化检测（快速缓存失效）

## ==================== 缓存数据 ====================

## 预缓存的描述字符串
var _descriptions: PackedStringArray = []

## 预绑定的执行方法（预留，Phase 3.2 使用）
var _execution_callables: Array[Callable] = []

## 编译时的指令数量（用于缓存失效检查）
var _instruction_count: int = 0

## 缓存是否有效
var _is_valid: bool = false

## ==================== 核心方法 ====================

## 编译指令序列
##
## 遍历 ActionRunner 的指令，预生成描述字符串和方法绑定
## 返回编译是否成功
##
## 参数：
## - action_runner: ActionRunner - 要编译的动作运行器
##
## 返回：
## - bool - 编译是否成功
func compile(action_runner: ActionRunner) -> bool:
	if action_runner == null:
		_is_valid = false
		return false

	_descriptions.clear()
	_execution_callables.clear()

	for instruction in action_runner.instructions:
		# 预生成描述字符串（避免运行时重复调用）
		_descriptions.append(instruction.get_description() if instruction else "")

		# 预绑定执行方法（Phase 3.2：为轻量级执行上下文预留）
		if instruction and instruction.has_method("execute"):
			_execution_callables.append(instruction.execute)
		else:
			_execution_callables.append(Callable())

	_instruction_count = action_runner.instructions.size()
	_is_valid = true
	return true

## 检查缓存是否对给定 ActionRunner 有效
##
## 使用指令数量进行快速失效检查
##
## 参数：
## - action_runner: ActionRunner - 要检查的动作运行器
##
## 返回：
## - bool - 缓存是否有效
func is_valid_for(action_runner: ActionRunner) -> bool:
	if not _is_valid or action_runner == null:
		return false
	return _instruction_count == action_runner.instructions.size()

## 获取缓存的描述（带索引边界检查）
##
## 参数：
## - index: int - 指令索引
##
## 返回：
## - String - 缓存的描述字符串，索引无效时返回空字符串
func get_cached_description(index: int) -> String:
	if index < 0 or index >= _descriptions.size():
		return ""
	return _descriptions[index]

## 获取缓存的可调用对象（Phase 3.2 预留）
##
## 参数：
## - index: int - 指令索引
##
## 返回：
## - Callable - 缓存的可调用对象，索引无效时返回空 Callable
func get_cached_callable(index: int) -> Callable:
	if index < 0 or index >= _execution_callables.size():
		return Callable()
	return _execution_callables[index]

## ==================== 辅助方法 ====================

## 获取缓存的指令数量
##
## 返回：
## - int - 缓存的指令数量
func get_instruction_count() -> int:
	return _instruction_count

## 检查缓存是否有效
##
## 返回：
## - bool - 缓存是否有效
func is_valid() -> bool:
	return _is_valid

## 使缓存失效
##
## 清除缓存状态，强制下次使用时重新编译
func invalidate() -> void:
	_is_valid = false
	_descriptions.clear()
	_execution_callables.clear()
	_instruction_count = 0

## 获取缓存统计信息（用于调试）
##
## 返回：
## - Dictionary - 缓存统计信息
func get_cache_stats() -> Dictionary:
	return {
		"is_valid": _is_valid,
		"instruction_count": _instruction_count,
		"description_count": _descriptions.size(),
		"callable_count": _execution_callables.size()
	}

## 获取所有缓存的描述（用于调试显示）
##
## 返回：
## - PackedStringArray - 所有缓存的描述字符串
func get_all_descriptions() -> PackedStringArray:
	return _descriptions
