extends Node

# 预加载必要的类
const VariableScopeUtils = preload("res://addons/fuse/core/utils/variable_scope_utils.gd")

## 变量系统重构测试套件
##
## 测试目标：
## 1. 验证 get_variable() 统一返回值（不是对象）
## 2. 验证 get_variable_object() 返回对象
## 3. 验证局部和全局变量的一致性
## 4. 验证向后兼容性

func _ready():
	print("=== 开始变量系统重构测试 ===")
	print("")

	# 等待场景稳定
	await get_tree().process_frame
	await get_tree().process_frame

	# 执行所有测试
	await test_local_variable_get_returns_value()
	await test_global_variable_get_returns_value()
	await test_get_variable_object_returns_object()
	await test_mixed_scope_priority()
	await test_backward_compatibility()
	await test_variable_scope_utils()

	print("")
	print("=== 所有测试完成 ===")

	# 自动退出（用于CI/CD）
	# get_tree().quit()

## 测试1：局部变量 get_variable() 返回值
func test_local_variable_get_returns_value():
	print("[测试 1/6] 局部变量 get_variable() 返回值")

	var context = ExecutionContext.new()

	# 创建局部变量
	context.set_variable("score", 100, "local")

	# 获取变量
	var value = context.get_variable("score")

	# 验证返回的是值，不是对象
	assert(value == 100, "值应该等于 100")
	assert(typeof(value) == TYPE_INT, "类型应该是 TYPE_INT，实际: %s" % type_string(typeof(value)))
	assert(not (value is BaseVariable), "不应该返回 BaseVariable 对象")

	print("  ✅ 通过：局部变量返回值（类型: %s）" % type_string(typeof(value)))

	# 清理
	context.cleanup()

## 测试2：全局变量 get_variable() 返回值
func test_global_variable_get_returns_value():
	print("[测试 2/6] 全局变量 get_variable() 返回值")

	var assistant = GlobalVariableAssistant.get_instance()
	var context = ExecutionContext.new()
	context.global_variables = assistant

	# 创建全局变量
	var var_obj = BaseVariable.create("health", 100, BaseVariable.VariableScope.GLOBAL)
	assistant.add_global_variable("health", var_obj)

	# 等待一帧确保变量已添加
	await get_tree().process_frame

	# 获取变量
	var value = context.get_variable("health")

	# 验证返回的是值，不是对象
	assert(value == 100, "值应该等于 100，实际: %s" % str(value))
	assert(typeof(value) == TYPE_INT, "类型应该是 TYPE_INT，实际: %s" % type_string(typeof(value)))
	assert(not (value is BaseVariable), "不应该返回 BaseVariable 对象")

	print("  ✅ 通过：全局变量返回值（类型: %s）" % type_string(typeof(value)))

	# 清理
	assistant.remove_global_variable("health")
	context.cleanup()

## 测试3：get_variable_object() 返回对象
func test_get_variable_object_returns_object():
	print("[测试 3/6] get_variable_object() 返回对象")

	var assistant = GlobalVariableAssistant.get_instance()
	var context = ExecutionContext.new()
	context.global_variables = assistant

	# 创建全局变量
	assistant.add_global_variable("stamina", BaseVariable.create("stamina", 50, BaseVariable.VariableScope.GLOBAL))

	# 等待一帧
	await get_tree().process_frame

	# 获取变量对象
	var var_obj = context.get_variable_object("stamina")

	# 验证返回的是对象
	assert(var_obj != null, "应该返回对象")
	assert(var_obj is BaseVariable, "应该返回 BaseVariable 类型，实际: %s" % type_string(typeof(var_obj)))
	assert(var_obj.get_value() == 50, "对象的值应该是 50，实际: %s" % str(var_obj.get_value()))

	print("  ✅ 通过：返回 BaseVariable 对象（值: %s）" % str(var_obj.get_value()))

	# 清理
	assistant.remove_global_variable("stamina")
	context.cleanup()

## 测试4：混合作用域优先级
func test_mixed_scope_priority():
	print("[测试 4/6] 混合作用域优先级")

	var assistant = GlobalVariableAssistant.get_instance()
	var context = ExecutionContext.new()
	context.global_variables = assistant

	# 创建同名局部和全局变量
	context.set_variable("score", 10, "local")
	assistant.add_global_variable("score", BaseVariable.create("score", 100, BaseVariable.VariableScope.GLOBAL))

	# 等待一帧
	await get_tree().process_frame

	# 验证局部变量优先
	var value = context.get_variable("score")
	assert(value == 10, "局部变量应该优先（期望: 10，实际: %s）" % str(value))

	print("  ✅ 通过：局部变量优先（值: %s）" % str(value))

	# 清理
	assistant.remove_global_variable("score")
	context.cleanup()

## 测试5：向后兼容性
func test_backward_compatibility():
	print("[测试 5/6] 向后兼容性")

	var context = ExecutionContext.new()

	# 旧式用法：直接设置值
	context.set_variable("old_style", 42, "local")
	var value = context.get_variable("old_style")

	assert(value == 42, "旧式用法应该仍然有效（期望: 42，实际: %s）" % str(value))

	print("  ✅ 通过：向后兼容（值: %s）" % str(value))

	# 清理
	context.cleanup()

## 测试6：VariableScopeUtils 工具类
func test_variable_scope_utils():
	print("[测试 6/6] VariableScopeUtils 工具类")

	# 测试枚举转字符串
	var local_str = VariableScopeUtils.enum_to_string(BaseVariable.VariableScope.LOCAL)
	assert(local_str == "local", "LOCAL 应该转换为 'local'，实际: '%s'" % local_str)

	var global_str = VariableScopeUtils.enum_to_string(BaseVariable.VariableScope.GLOBAL)
	assert(global_str == "global", "GLOBAL 应该转换为 'global'，实际: '%s'" % global_str)

	# 测试字符串转枚举
	var local_enum = VariableScopeUtils.string_to_enum("local")
	assert(local_enum == BaseVariable.VariableScope.LOCAL, "'local' 应该转换为 LOCAL")

	var global_enum = VariableScopeUtils.string_to_enum("global")
	assert(global_enum == BaseVariable.VariableScope.GLOBAL, "'global' 应该转换为 GLOBAL")

	# 测试验证方法
	assert(VariableScopeUtils.is_valid_scope_string("local"), "local 应该是有效作用域")
	assert(VariableScopeUtils.is_valid_scope_string("global"), "global 应该是有效作用域")
	assert(not VariableScopeUtils.is_valid_scope_string("invalid"), "invalid 应该是无效作用域")

	print("  ✅ 通过：VariableScopeUtils 工具类正常工作")

## 辅助函数：获取类型字符串
func type_string(type_int: int) -> String:
	match type_int:
		TYPE_NIL: return "TYPE_NIL"
		TYPE_BOOL: return "TYPE_BOOL"
		TYPE_INT: return "TYPE_INT"
		TYPE_FLOAT: return "TYPE_FLOAT"
		TYPE_STRING: return "TYPE_STRING"
		TYPE_OBJECT: return "TYPE_OBJECT"
		_: return "TYPE_UNKNOWN(%d)" % type_int
