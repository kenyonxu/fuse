extends Node2D

## 测试时间到达条件

func _ready():
	test_time_reached_condition_relative()
	await get_tree().create_timer(0.5).timeout  # 等待一下，让测试清晰分离
	test_time_reached_condition_absolute()
	print("时间到达条件测试完成")

## 测试相对时间模式
func test_time_reached_condition_relative():
	print("\n--- 测试相对时间模式 ---")

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 创建条件（0.5 秒）
	var condition = CheckTimeReached.new()
	condition.target_time = 0.5
	condition.time_mode = CheckTimeReached.TimeMode.RELATIVE

	# 测试：时间未到
	var result1 = condition.check(context)
	print("0 秒时检查 => ", result1)
	assert(result1 == false, "0 秒时应该未到达")

	# 等待 0.3 秒
	await get_tree().create_timer(0.3).timeout
	var result2 = condition.check(context)
	print("0.3 秒时检查 => ", result2)
	assert(result2 == false, "0.3 秒时应该未到达")

	# 等待 0.3 秒（总共 0.6 秒）
	await get_tree().create_timer(0.3).timeout
	var result3 = condition.check(context)
	print("0.6 秒时检查 => ", result3)
	assert(result3 == true, "0.6 秒时应该已到达")

	# 测试重置
	condition.reset()
	var result4 = condition.check(context)
	print("重置后检查 => ", result4)
	assert(result4 == false, "重置后应该重新开始计时")

	print("✓ 相对时间模式测试通过")

## 测试绝对时间模式
func test_time_reached_condition_absolute():
	print("\n--- 测试绝对时间模式 ---")

	# 创建执行上下文
	var context = ExecutionContext.new()

	# 获取当前时间
	var current_time = Time.get_ticks_msec() / 1000.0

	# 创建条件（设置为 1 秒后的时间）
	var condition = CheckTimeReached.new()
	condition.target_time = current_time + 1.0
	condition.time_mode = CheckTimeReached.TimeMode.ABSOLUTE

	# 测试：时间未到
	var result1 = condition.check(context)
	print("当前时间检查 => ", result1)
	assert(result1 == false, "应该未到达目标时间")

	# 等待 1.2 秒
	await get_tree().create_timer(1.2).timeout
	var result2 = condition.check(context)
	print("1.2 秒后检查 => ", result2)
	assert(result2 == true, "1.2 秒后应该已到达目标时间")

	# 测试获取剩余时间
	var remaining = condition.get_remaining_time()
	print("剩余时间: ", remaining)
	assert(remaining == 0.0, "时间到达后剩余时间应该为 0")

	# 测试获取已过时间
	var elapsed = condition.get_elapsed_time()
	print("已过时间: ", elapsed)
	assert(elapsed >= 1.0, "已过时间应该大于等于 1 秒")

	print("✓ 绝对时间模式测试通过")
	print("时间到达条件测试通过!")
