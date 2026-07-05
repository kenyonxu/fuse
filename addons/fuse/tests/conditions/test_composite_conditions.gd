extends Node2D

# 预加载 CheckComposite 类
const CheckComposite = preload("res://addons/fuse/conditions/composite/check_composite.gd")

## 测试复合条件 (NOT, ALL, ANY)

func _ready():
	test_not_condition()
	test_not_null_condition()
	test_all_condition()
	test_all_empty_condition()
	test_any_condition()
	test_any_empty_condition()
	# CheckComposite 测试
	test_composite_simple_and()
	test_composite_simple_or()
	test_composite_not()
	test_composite_empty()
	test_composite_nested()
	test_composite_validation()
	test_composite_dependencies()
	test_composite_description()
	print("复合条件测试完成")

## 测试 NOT 条件
func test_not_condition():
	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置测试变量
	context.set_variable("test_value", true)

	# 创建内部条件（变量检查）
	var inner_check = CheckVariable.new()
	inner_check.variable_name = "test_value"

	# 创建 NOT 条件
	var not_condition = CheckNot.new()
	not_condition.inner_condition = inner_check

	# 测试：变量为 true，NOT 后应该为 false
	var result1 = not_condition.check(context)
	print("NOT(true) = ", result1)
	assert(result1 == false, "NOT(true) 应该返回 false")

	# 修改变量值为 false
	context.set_variable("test_value", false)

	# 测试：变量为 false，NOT 后应该为 true
	var result2 = not_condition.check(context)
	print("NOT(false) = ", result2)
	assert(result2 == true, "NOT(false) 应该返回 true")

	print("NOT 条件测试通过！")

## 测试 NOT 条件为 null 的情况
func test_not_null_condition():
	# 创建执行上下文
	var context = ExecutionContext.new()

	# 创建 NOT 条件但不设置内部条件
	var not_condition = CheckNot.new()
	not_condition.inner_condition = null

	# 测试：内部条件为 null 时应该返回 false
	var result = not_condition.check(context)
	print("NOT(null) = ", result)
	assert(result == false, "NOT(null) 应该返回 false")

	print("NOT null 条件测试通过！")

## 测试 ALL (AND) 条件
func test_all_condition():
	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置测试变量
	context.set_variable("value_a", true)
	context.set_variable("value_b", true)
	context.set_variable("value_c", true)

	# 创建子条件
	var check_a = CheckVariable.new()
	check_a.variable_name = "value_a"

	var check_b = CheckVariable.new()
	check_b.variable_name = "value_b"

	var check_c = CheckVariable.new()
	check_c.variable_name = "value_c"

	# 创建 ALL 条件
	var all_condition = CheckAll.new()
	all_condition.conditions = [check_a, check_b, check_c]

	# 测试：所有条件都为 true
	var result1 = all_condition.check(context)
	print("ALL(true, true, true) = ", result1)
	assert(result1 == true, "ALL(true, true, true) 应该返回 true")

	# 测试：一个条件为 false
	context.set_variable("value_b", false)
	var result2 = all_condition.check(context)
	print("ALL(true, false, true) = ", result2)
	assert(result2 == false, "ALL(true, false, true) 应该返回 false")

	# 测试：短路求值 - 第一个条件为 false
	context.set_variable("value_a", false)
	var result3 = all_condition.check(context)
	print("ALL(false, true, true) = ", result3)
	assert(result3 == false, "ALL(false, true, true) 应该返回 false")

	print("ALL 条件测试通过！")

## 测试 ALL 空条件列表
func test_all_empty_condition():
	# 创建执行上下文
	var context = ExecutionContext.new()

	# 创建 ALL 条件但不添加子条件
	var all_condition = CheckAll.new()
	all_condition.conditions = []

	# 测试：空条件列表应该返回 false
	var result = all_condition.check(context)
	print("ALL() = ", result)
	assert(result == false, "ALL() 空条件列表应该返回 false")

	print("ALL 空条件列表测试通过！")

## 测试 ANY (OR) 条件
func test_any_condition():
	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置测试变量
	context.set_variable("value_a", false)
	context.set_variable("value_b", false)
	context.set_variable("value_c", false)

	# 创建子条件
	var check_a = CheckVariable.new()
	check_a.variable_name = "value_a"

	var check_b = CheckVariable.new()
	check_b.variable_name = "value_b"

	var check_c = CheckVariable.new()
	check_c.variable_name = "value_c"

	# 创建 ANY 条件
	var any_condition = CheckAny.new()
	any_condition.conditions = [check_a, check_b, check_c]

	# 测试：所有条件都为 false
	var result1 = any_condition.check(context)
	print("ANY(false, false, false) = ", result1)
	assert(result1 == false, "ANY(false, false, false) 应该返回 false")

	# 测试：一个条件为 true
	context.set_variable("value_b", true)
	var result2 = any_condition.check(context)
	print("ANY(false, true, false) = ", result2)
	assert(result2 == true, "ANY(false, true, false) 应该返回 true")

	# 测试：短路求值 - 第一个条件为 true
	context.set_variable("value_a", true)
	var result3 = any_condition.check(context)
	print("ANY(true, false, false) = ", result3)
	assert(result3 == true, "ANY(true, false, false) 应该返回 true")

	# 测试：多个条件为 true
	context.set_variable("value_c", true)
	var result4 = any_condition.check(context)
	print("ANY(true, true, true) = ", result4)
	assert(result4 == true, "ANY(true, true, true) 应该返回 true")

	print("ANY 条件测试通过！")

## 测试 ANY 空条件列表
func test_any_empty_condition():
	# 创建执行上下文
	var context = ExecutionContext.new()

	# 创建 ANY 条件但不添加子条件
	var any_condition = CheckAny.new()
	any_condition.conditions = []

	# 测试：空条件列表应该返回 false
	var result = any_condition.check(context)
	print("ANY() = ", result)
	assert(result == false, "ANY() 空条件列表应该返回 false")

	print("ANY 空条件列表测试通过！")

## 测试 CheckComposite - (A AND B) OR (C AND D)
func test_composite_and_or():
	# 这个测试比较复杂，暂时跳过
	# 需要更复杂的逻辑树构建支持
	print("跳过复杂的 AND/OR 组合测试（未来实现）")

## 测试 CheckComposite 简单 AND 组合
func test_composite_simple_and():
	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置测试变量
	context.set_variable("x", true)
	context.set_variable("y", true)
	context.set_variable("z", true)

	# 创建基础条件
	var check_x = CheckVariable.new()
	check_x.variable_name = "x"

	var check_y = CheckVariable.new()
	check_y.variable_name = "y"

	var check_z = CheckVariable.new()
	check_z.variable_name = "z"

	# 创建 AND 组合
	var composite = CheckComposite.create_and([check_x, check_y, check_z])

	# 测试：所有条件都为 true
	var result1 = composite.check(context)
	print("Composite AND(x=true, y=true, z=true) = ", result1)
	assert(result1 == true, "AND(all true) 应该返回 true")

	# 测试：一个条件为 false
	context.set_variable("y", false)
	var result2 = composite.check(context)
	print("Composite AND(x=true, y=false, z=true) = ", result2)
	assert(result2 == false, "AND(one false) 应该返回 false")

	print("Composite 简单 AND 测试通过！")

## 测试 CheckComposite 简单 OR 组合
func test_composite_simple_or():
	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置测试变量
	context.set_variable("x", false)
	context.set_variable("y", false)
	context.set_variable("z", false)

	# 创建基础条件
	var check_x = CheckVariable.new()
	check_x.variable_name = "x"

	var check_y = CheckVariable.new()
	check_y.variable_name = "y"

	var check_z = CheckVariable.new()
	check_z.variable_name = "z"

	# 创建 OR 组合
	var composite = CheckComposite.create_or([check_x, check_y, check_z])

	# 测试：所有条件都为 false
	var result1 = composite.check(context)
	print("Composite OR(x=false, y=false, z=false) = ", result1)
	assert(result1 == false, "OR(all false) 应该返回 false")

	# 测试：一个条件为 true
	context.set_variable("y", true)
	var result2 = composite.check(context)
	print("Composite OR(x=false, y=true, z=false) = ", result2)
	assert(result2 == true, "OR(one true) 应该返回 true")

	print("Composite 简单 OR 测试通过！")

## 测试 CheckComposite NOT 组合
func test_composite_not():
	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置测试变量
	context.set_variable("value", true)

	# 创建基础条件
	var check_value = CheckVariable.new()
	check_value.variable_name = "value"

	# 创建 NOT 组合
	var composite = CheckComposite.create_not(check_value)

	# 测试：变量为 true，NOT 后应该为 false
	var result1 = composite.check(context)
	print("Composite NOT(true) = ", result1)
	assert(result1 == false, "NOT(true) 应该返回 false")

	# 测试：变量为 false，NOT 后应该为 true
	context.set_variable("value", false)
	var result2 = composite.check(context)
	print("Composite NOT(false) = ", result2)
	assert(result2 == true, "NOT(false) 应该返回 true")

	print("Composite NOT 测试通过！")

## 测试 CheckComposite 空条件
func test_composite_empty():
	# 创建执行上下文
	var context = ExecutionContext.new()

	# 创建空的 Composite 条件
	var composite = CheckComposite.new()

	# 测试：空条件应该返回 false
	var result = composite.check(context)
	print("Composite(空) = ", result)
	assert(result == false, "Composite(空) 应该返回 false")

	print("Composite 空条件测试通过！")

## 测试 CheckComposite 复杂嵌套 - A AND (B OR C)
func test_composite_nested():
	# 这个测试需要手动构建逻辑树，暂时跳过
	# 需要更好的 API 支持
	print("跳过复杂的嵌套测试（未来实现）")

## 测试 CheckComposite 验证
func test_composite_validation():
	# 创建空的 Composite 条件
	var composite = CheckComposite.new()

	# 验证：空条件应该有错误
	var errors = composite.validate()
	print("Composite 验证错误: ", errors)
	assert(not errors.is_empty(), "空 Composite 应该有验证错误")

	# 创建有效的 Composite
	var context = ExecutionContext.new()
	context.set_variable("test", true)

	var check = CheckVariable.new()
	check.variable_name = "test"
	var valid_composite = CheckComposite.create_and([check])

	# 验证：有效条件应该没有错误
	var valid_errors = valid_composite.validate()
	print("有效 Composite 验证错误: ", valid_errors)
	assert(valid_errors.is_empty(), "有效 Composite 不应该有验证错误")

	print("Composite 验证测试通过！")

## 测试 CheckComposite 依赖收集
func test_composite_dependencies():
	# 创建执行上下文
	var context = ExecutionContext.new()

	# 设置测试变量
	context.set_variable("var1", true)
	context.set_variable("var2", true)
	context.set_variable("var3", true)

	# 创建基础条件
	var check1 = CheckVariable.new()
	check1.variable_name = "var1"

	var check2 = CheckVariable.new()
	check2.variable_name = "var2"

	var check3 = CheckVariable.new()
	check3.variable_name = "var3"

	# 创建 AND 组合
	var composite = CheckComposite.create_and([check1, check2, check3])

	# 获取依赖
	var deps = composite.get_dependencies()
	print("Composite 依赖变量: ", deps)
	assert(deps.size() == 3, "应该有 3 个依赖变量")
	assert("var1" in deps, "应该包含 var1")
	assert("var2" in deps, "应该包含 var2")
	assert("var3" in deps, "应该包含 var3")

	print("Composite 依赖收集测试通过！")

## 测试 CheckComposite 描述
func test_composite_description():
	# 创建基础条件
	var check1 = CheckVariable.new()
	check1.variable_name = "var1"

	var check2 = CheckVariable.new()
	check2.variable_name = "var2"

	# 创建 AND 组合
	var composite = CheckComposite.create_and([check1, check2])

	# 获取描述
	var desc = composite.get_description()
	print("Composite 描述: ", desc)
	assert(desc.contains("Composite"), "描述应该包含 'Composite'")
	assert(desc.length() <= 100, "描述长度应该 <= 100")

	print("Composite 描述测试通过！")
