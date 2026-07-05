# 条件系统使用示例
# 展示如何在实际游戏场景中使用各种条件类型
# 包括时间条件、参数条件和复合条件的使用

extends Node

# 示例场景：技能系统条件配置
func demonstrate_skill_system_conditions():
	print("=== 🎯 技能系统条件示例 ===")
	
	# 创建上下文
	var context = JuicyContext.new()
	context.set_parameter("player_level", 10.0)
	context.set_parameter("mana", 75.0)
	context.set_parameter("health", 80.0)
	context.set_parameter("combo_count", 3.0)
	context.duration = 5.0  # 技能持续时间
	
	# 示例1：基础技能解锁条件
	var basic_skill_condition = create_basic_skill_condition()
	test_condition("基础技能解锁", basic_skill_condition, context)
	
	# 示例2：高级技能组合条件
	var advanced_skill_condition = create_advanced_skill_condition()
	test_condition("高级技能解锁", advanced_skill_condition, context)
	
	# 示例3：终极技能时间窗口条件
	var ultimate_condition = create_ultimate_skill_condition()
	test_condition("终极技能时间窗口", ultimate_condition, context)
	
	# 示例4：动态条件变化测试
	test_dynamic_condition_changes(context)

# 创建基础技能条件：玩家等级要求
func create_basic_skill_condition() -> JuicyParameterCondition:
	var condition = JuicyParameterCondition.new()
	condition.parameter_name = "player_level"
	condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
	condition.target_value = 5.0  # 需要等级5+
	condition.enabled = true
	return condition

# 创建高级技能条件：多重要求组合
func create_advanced_skill_condition() -> JuicyCompositeCondition:
	var composite = JuicyCompositeCondition.new()
	composite.operator = JuicyCompositeCondition.LogicalOperator.AND
	
	# 等级要求
	var level_condition = JuicyParameterCondition.new()
	level_condition.parameter_name = "player_level"
	level_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
	level_condition.target_value = 10.0
	composite.conditions.append(level_condition)
	
	# 魔法值要求
	var mana_condition = JuicyParameterCondition.new()
	mana_condition.parameter_name = "mana"
	mana_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
	mana_condition.target_value = 50.0
	composite.conditions.append(mana_condition)
	
	# 连击数要求
	var combo_condition = JuicyParameterCondition.new()
	combo_condition.parameter_name = "combo_count"
	combo_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
	combo_condition.target_value = 3.0
	composite.conditions.append(combo_condition)
	
	composite.enabled = true
	return composite

# 创建终极技能条件：时间窗口 + 状态要求
func create_ultimate_skill_condition() -> JuicyCompositeCondition:
	var composite = JuicyCompositeCondition.new()
	composite.operator = JuicyCompositeCondition.LogicalOperator.AND
	
	# 时间窗口：技能开始后1-3秒内可用
	var time_window_condition = create_time_window_condition(1.0, 3.0)
	composite.conditions.append(time_window_condition)
	
	# 生命值要求：低于30%时可用（绝境反击）
	var health_condition = JuicyParameterCondition.new()
	health_condition.parameter_name = "health"
	health_condition.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
	health_condition.target_value = 30.0
	composite.conditions.append(health_condition)
	
	composite.enabled = true
	return composite

# 创建时间窗口条件
func create_time_window_condition(start_time: float, end_time: float) -> JuicyCompositeCondition:
	var composite = JuicyCompositeCondition.new()
	composite.operator = JuicyCompositeCondition.LogicalOperator.AND
	
	# 开始后条件
	var after_start = JuicyTimeCondition.new()
	after_start.time_operator = JuicyTimeCondition.TimeOperator.AFTER_START
	after_start.target_time = start_time
	composite.conditions.append(after_start)
	
	# 结束前条件
	var before_end = JuicyTimeCondition.new()
	before_end.time_operator = JuicyTimeCondition.TimeOperator.BEFORE_END
	before_end.target_time = end_time
	composite.conditions.append(before_end)
	
	return composite

# 测试条件并打印结果
func test_condition(test_name: String, condition: JuicyCondition, context: JuicyContext):
	var result = condition.evaluate(context)
	var description = condition.get_description()
	var validation = condition.validate_condition()
	
	print("📋 %s:" % test_name)
	print("  描述: %s" % description)
	print("  验证: %s" % ("通过" if validation.is_empty() else validation))
	print("  结果: %s" % ("✅ 满足" if result else "❌ 不满足"))
	print("")

# 测试动态条件变化
func test_dynamic_condition_changes(context: JuicyContext):
	print("=== 🔄 动态条件变化测试 ===")
	
	# 创建一个参数条件
	var condition = JuicyParameterCondition.new()
	condition.parameter_name = "mana"
	condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
	condition.target_value = 50.0
	condition.enabled = true
	
	# 初始状态
	context.set_parameter("mana", 30.0)
	print("初始魔法值: 30.0")
	test_condition("魔法值条件", condition, context)
	
	# 增加魔法值
	context.set_parameter("mana", 60.0)
	condition.on_parameter_changed("mana", 30.0, 60.0)
	print("更新魔法值: 60.0")
	test_condition("魔法值条件", condition, context)
	
	# 减少魔法值
	context.set_parameter("mana", 40.0)
	condition.on_parameter_changed("mana", 60.0, 40.0)
	print("更新魔法值: 40.0")
	test_condition("魔法值条件", condition, context)

# 示例场景：环境效果条件
func demonstrate_environment_conditions():
	print("=== 🌍 环境效果条件示例 ===")
	
	var context = JuicyContext.new()
	context.set_parameter("weather", 1.0)  # 1=晴天, 2=雨天, 3=雪天
	context.set_parameter("time_of_day", 18.5)  # 18:30
	context.set_parameter("temperature", 25.0)
	
	# 雨天效果条件
	var rain_condition = JuicyParameterCondition.new()
	rain_condition.parameter_name = "weather"
	rain_condition.operator = JuicyParameterCondition.ComparisonOperator.EQUAL
	rain_condition.target_value = 2.0  # 雨天
	rain_condition.enabled = true
	
	# 夜晚效果条件
	var night_condition = JuicyCompositeCondition.new()
	night_condition.operator = JuicyCompositeCondition.LogicalOperator.OR
	
	var evening = JuicyParameterCondition.new()
	evening.parameter_name = "time_of_day"
	evening.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
	evening.target_value = 6.0  # 6点前
	night_condition.conditions.append(evening)
	
	var morning = JuicyParameterCondition.new()
	morning.parameter_name = "time_of_day"
	morning.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
	morning.target_value = 20.0  # 20点后
	night_condition.conditions.append(morning)
	
	test_condition("雨天效果", rain_condition, context)
	test_condition("夜晚效果", night_condition, context)

# 示例场景：战斗系统条件
func demonstrate_combat_conditions():
	print("=== ⚔️ 战斗系统条件示例 ===")
	
	var context = JuicyContext.new()
	context.set_parameter("enemy_health", 35.0)
	context.set_parameter("player_health", 80.0)
	context.set_parameter("distance", 2.5)
	context.duration = 10.0
	context.current_time = 3.0
	
	# 处决技能条件：敌人血量低 + 距离近 + 战斗中期
	var execute_condition = JuicyCompositeCondition.new()
	execute_condition.operator = JuicyCompositeCondition.LogicalOperator.AND
	
	# 敌人血量低于20%
	var enemy_health_low = JuicyParameterCondition.new()
	enemy_health_low.parameter_name = "enemy_health"
	enemy_health_low.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
	enemy_health_low.target_value = 20.0
	execute_condition.conditions.append(enemy_health_low)
	
	# 距离在有效范围内
	var distance_close = JuicyParameterCondition.new()
	distance_close.parameter_name = "distance"
	distance_close.operator = JuicyParameterCondition.ComparisonOperator.LESS_EQUAL
	distance_close.target_value = 3.0
	execute_condition.conditions.append(distance_close)
	
	# 战斗开始1秒后
	var combat_mid = JuicyTimeCondition.new()
	combat_mid.time_operator = JuicyTimeCondition.TimeOperator.AFTER_START
	combat_mid.target_time = 1.0
	execute_condition.conditions.append(combat_mid)
	
	test_condition("处决技能", execute_condition, context)

# 性能优化示例：条件缓存
func demonstrate_condition_caching():
	print("=== ⚡ 条件缓存性能示例 ===")
	
	var context = JuicyContext.new()
	context.set_parameter("test_param", 50.0)
	
	# 创建参数条件（带缓存）
	var condition = JuicyParameterCondition.new()
	condition.parameter_name = "test_param"
	condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	condition.target_value = 30.0
	condition.enabled = true
	
	# 多次评估相同条件
	var start_time = Time.get_ticks_msec()
	for i in range(1000):
		condition.evaluate(context)
	var end_time = Time.get_ticks_msec()
	
	print("1000次条件评估耗时: %d ms" % (end_time - start_time))
	print("平均每次评估: %.3f ms" % ((end_time - start_time) / 1000.0))

# 条件验证示例
func demonstrate_condition_validation():
	print("=== ✅ 条件验证示例 ===")
	
	# 有效条件
	var valid_condition = JuicyParameterCondition.new()
	valid_condition.parameter_name = "health"
	valid_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	valid_condition.target_value = 0.0
	valid_condition.enabled = true
	
	var valid_errors = valid_condition.validate_condition()
	print("有效条件验证: %s" % ("通过" if valid_errors.is_empty() else valid_errors))
	
	# 无效条件
	var invalid_condition = JuicyParameterCondition.new()
	invalid_condition.parameter_name = ""  # 空参数名
	invalid_condition.enabled = true
	
	var invalid_errors = invalid_condition.validate_condition()
	print("无效条件验证: %s" % invalid_errors)
	
	# 复合条件验证
	var composite = JuicyCompositeCondition.new()
	composite.enabled = true
	# 注意：没有添加子条件，应该验证失败
	
	var composite_errors = composite.validate_condition()
	print("复合条件验证: %s" % composite_errors)

# 主演示函数
func demonstrate_all_examples():
	print("🚀 开始条件系统示例演示")
	print("==================================================")
	
	demonstrate_skill_system_conditions()
	demonstrate_environment_conditions()
	demonstrate_combat_conditions()
	demonstrate_condition_caching()
	demonstrate_condition_validation()
	
	print("==================================================")
	print("🎉 条件系统示例演示完成！")

func _ready():
	demonstrate_all_examples()