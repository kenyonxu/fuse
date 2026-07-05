# 组合系统、变体系统与条件系统使用指南
# 详细介绍如何使用JuicyMixer的组合系统、变体系统和条件系统
# 包含最佳实践、性能优化和常见问题解决方案

extends Node

# =============================================================================
# 第一章：基础概念
# =============================================================================

"""
组合系统 (Composite System)、变体系统 (Variant System) 和条件系统 (Condition System) 是JuicyMixer的核心功能：

组合系统：
- 允许将多个效果组合成一个复杂的效果
- 支持不同的混合模式（叠加、乘法、覆盖、加权平均）
- 提供参数映射功能，实现联觉效果
- 支持权重控制和动态调整

变体系统：
- 基于Data覆盖机制，避免Resource嵌套
- 支持细粒度的属性覆盖和替换
- 可以添加、移除、修改组合中的元素
- 支持参数映射继承

条件系统：
- 基于参数值、时间进度等条件控制效果的激活
- 支持参数条件、时间条件和复合条件
- 提供性能优化的缓存机制
- 支持复杂的逻辑表达式

主要优势：
1. 避免Resource嵌套，提高性能
2. 支持运行时动态修改
3. 细粒度的控制，精确到Data级别
4. 支持复杂的参数映射和联觉效果
5. 智能的条件控制，实现动态效果响应
"""

# =============================================================================
# 第二章：快速开始
# =============================================================================

# 示例1：创建基础组合效果
func quick_start_example_1():
	"""
	最简单的组合效果创建示例
	"""
	# 1. 创建组合资源
	var composite = JuicyCompositeResource.new()
	
	# 2. 创建效果项（使用代码创建而不是预加载）
	var shake_resource = JuicyShakeResource.new()
	var shake_data = ShakeData.new()
	shake_data.property = "position"
	shake_data.amplitude = 3.0
	shake_data.frequency = 12.0
	shake_data.duration = 0.3
	shake_resource.shake_data = [shake_data]
	
	var shake_item = JuicyCompositeItem.new()
	shake_item.resource = shake_resource
	shake_item.weight = 1.0
	
	var tween_resource = JuicyTweenResource.new()
	var tween_data = TweenData.new()
	tween_data.property = "scale"
	tween_data.start_value = Vector2.ONE
	tween_data.end_value = Vector2(1.1, 1.1)
	tween_data.duration = 0.2
	tween_resource.tween_data = [tween_data]
	
	var tween_item = JuicyCompositeItem.new()
	tween_item.resource = tween_resource
	tween_item.weight = 1.0
	
	# 3. 添加到组合
	composite.composite_items = [shake_item, tween_item]
	composite.blend_mode = JuicyCompositeResource.CompositeBlendMode.ADDITIVE
	
	# 4. 播放效果
	var context = JuicyMixer.play(composite, self)
	return context

# 示例2：创建变体效果
func quick_start_example_2():
	"""
	简单的变体效果创建示例
	"""
	# 1. 创建基础组合
	var base_composite = quick_start_example_1()
	
	# 2. 创建变体
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	
	# 3. 添加数据覆盖
	var override = DataOverride.new()
	override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
	override.target_item_index = 0  # 修改第一个效果
	override.target_data_index = 0
	override.property_overrides = {"amplitude": 10.0}  # 增加震动幅度
	
	variant.data_overrides = [override]
	
	# 4. 播放变体
	var context = JuicyMixer.play(variant, self)
	return context

# =============================================================================
# 第三章：详细使用步骤
# =============================================================================

# 步骤1：创建基础组合资源
func step1_create_composite():
	"""
	详细步骤：创建基础组合资源
	"""
	print("=== 步骤1：创建基础组合资源 ===")
	
	# 创建组合资源
	var composite = JuicyCompositeResource.new()
	
	# 配置基础属性
	composite.blend_mode = JuicyCompositeResource.CompositeBlendMode.ADDITIVE
	composite.normalize_weights = true
	composite.dynamic_weight_adjustment = false
	
	# 创建组合项
	var items = []
	
	# 震动效果
	var shake_resource = JuicyShakeResource.new()
	var shake_data = ShakeData.new()
	shake_data.property = "position"
	shake_data.amplitude = 5.0
	shake_data.frequency = 15.0
	shake_data.duration = 1.0
	shake_resource.shake_data = [shake_data]
	
	var shake_item = JuicyCompositeItem.new()
	shake_item.resource = shake_resource
	shake_item.weight = 1.0
	shake_item.enabled = true
	items.append(shake_item)
	
	# 弹簧效果
	var spring_resource = JuicySpringResource.new()
	var spring_data = SpringData.new()
	spring_data.property = "scale"
	spring_data.target_value = Vector2(1.2, 1.2)
	spring_data.stiffness = 200.0
	spring_data.damping = 15.0
	spring_data.duration = 1.0
	spring_resource.spring_data = [spring_data]
	
	var spring_item = JuicyCompositeItem.new()
	spring_item.resource = spring_resource
	spring_item.weight = 1.0
	spring_item.enabled = true
	items.append(spring_item)
	
	# 设置组合项
	composite.composite_items = items
	
	# 验证配置
	var validation = composite.validate_config()
	if validation.valid:
		print("✓ 组合资源配置有效")
	else:
		print("✗ 组合资源配置无效：", "\n".join(validation.issues))
	
	return composite

# 步骤2：添加参数映射
func step2_add_parameter_mapping(composite: JuicyCompositeResource):
	"""
	详细步骤：添加参数映射
	"""
	print("\n=== 步骤2：添加参数映射 ===")
	
	# 启用参数映射
	composite.enable_parameter_mapping = true
	composite.auto_update_parameters = true
	
	# 创建参数映射
	var mappings = []
	
	# 映射1：强度 -> 震动幅度
	var intensity_to_shake = JuicyParameterMapping.new()
	intensity_to_shake.input_parameter = "intensity"
	intensity_to_shake.target_item_index = 0  # 震动效果
	intensity_to_shake.target_property = "amplitude"
	
	# 创建映射曲线
	var shake_curve = Curve.new()
	shake_curve.add_point(Vector2(0, 0))
	shake_curve.add_point(Vector2(1, 10))
	intensity_to_shake.curve = shake_curve
	
	mappings.append(intensity_to_shake)
	
	# 映射2：强度 -> 弹簧强度
	var intensity_to_spring = JuicyParameterMapping.new()
	intensity_to_spring.input_parameter = "intensity"
	intensity_to_spring.target_item_index = 1  # 弹簧效果
	intensity_to_spring.target_property = "stiffness"
	
	# 创建映射曲线
	var spring_curve = Curve.new()
	spring_curve.add_point(Vector2(0, 100))
	spring_curve.add_point(Vector2(1, 300))
	intensity_to_spring.curve = spring_curve
	
	mappings.append(intensity_to_spring)
	
	# 设置参数映射
	composite.parameter_mappings = mappings
	
	print("✓ 添加了 ", mappings.size(), " 个参数映射")
	return composite

# 步骤3：创建变体
func step3_create_variant(base_composite: JuicyCompositeResource):
	"""
	详细步骤：创建变体
	"""
	print("\n=== 步骤3：创建变体 ===")
	
	# 创建变体
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	variant.inherit_parameter_bindings = true  # 继承参数映射
	
	# 创建数据覆盖
	var overrides = []
	
	# 覆盖1：修改震动频率
	var shake_freq_override = DataOverride.new()
	shake_freq_override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
	shake_freq_override.target_item_index = 0
	shake_freq_override.target_data_index = 0
	shake_freq_override.property_overrides = {"frequency": 20.0}
	overrides.append(shake_freq_override)
	
	# 覆盖2：替换弹簧目标值
	var spring_target_override = DataOverride.new()
	spring_target_override.override_mode = DataOverride.OverrideMode.REPLACE_DATA
	spring_target_override.target_item_index = 1
	spring_target_override.target_data_index = 0
	
	var new_spring_data = SpringData.new()
	new_spring_data.property = "scale"
	new_spring_data.target_value = Vector2(1.5, 1.5)
	new_spring_data.stiffness = 250.0
	new_spring_data.damping = 20.0
	new_spring_data.duration = 1.2
	spring_target_override.new_data = new_spring_data
	
	overrides.append(spring_target_override)
	
	# 覆盖3：添加新的效果项
	var new_effect_resource = JuicyTweenResource.new()
	var new_effect_data = TweenData.new()
	new_effect_data.property = "modulate"
	new_effect_data.start_value = Color.WHITE
	new_effect_data.end_value = Color.YELLOW
	new_effect_data.duration = 0.5
	new_effect_resource.tween_data = [new_effect_data]
	
	var new_item = JuicyCompositeItem.new()
	new_item.resource = new_effect_resource
	new_item.weight = 0.5
	new_item.enabled = true
	
	var add_item_override = DataOverride.new()
	add_item_override.override_mode = DataOverride.OverrideMode.ADD_TO_COMPOSITE
	add_item_override.new_composite_item = new_item
	
	overrides.append(add_item_override)
	
	# 设置覆盖
	variant.data_overrides = overrides
	
	print("✓ 创建了变体，包含 ", overrides.size(), " 个数据覆盖")
	return variant

# 步骤4：使用混音台功能
func step4_use_mixer(variant: JuicyResourceVariant):
	"""
	详细步骤：使用混音台功能
	"""
	print("\n=== 步骤4：使用混音台功能 ===")
	
	# 播放效果
	var context = JuicyMixer.play(variant, self)
	
	if context:
		print("✓ 效果已播放，上下文ID：", context.context_id)
		
		# 设置初始参数
		context.set_parameter("intensity", 0.5)
		print("✓ 设置初始强度参数：0.5")
		
		# 模拟实时参数更新
		var timer = Timer.new()
		timer.wait_time = 0.1
		timer.one_shot = false
		add_child(timer)
		
		var intensity = 0.5
		var increasing = true
		
		timer.timeout.connect(func():
			# 动态调整强度
			if increasing:
				intensity += 0.05
				if intensity >= 1.0:
					increasing = false
			else:
				intensity -= 0.05
				if intensity <= 0.0:
					increasing = true
			
			context.set_parameter("intensity", intensity)
		)
		
		timer.start()
		
		# 5秒后停止
		await get_tree().create_timer(5.0).timeout
		timer.stop()
		timer.queue_free()
		
		# 停止效果
		JuicyMixer.stop(context.context_id)
		print("✓ 效果已停止")
	
	return context

# =============================================================================
# 第八章：条件系统集成
# =============================================================================

# 条件系统与组合系统的集成示例
func demonstrate_condition_system_integration():
	"""
	展示条件系统如何与组合系统协同工作
	"""
	print("\n=== 条件系统集成示例 ===")
	
	# 创建基础组合
	var composite = JuicyCompositeResource.new()
	
	# 效果1：基础震动（无条件）
	var basic_shake = create_shake_item(3.0, 12.0, 0.5)
	composite.composite_items.append(basic_shake)
	
	# 效果2：强化震动（血量低时触发）
	var enhanced_shake = create_shake_item(8.0, 20.0, 0.8)
	
	# 添加血量条件
	var health_condition = JuicyParameterCondition.new()
	health_condition.parameter_name = "player_health"
	health_condition.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
	health_condition.target_value = 30.0
	health_condition.enabled = true
	
	enhanced_shake.condition = health_condition
	composite.composite_items.append(enhanced_shake)
	
	# 效果3：特殊效果（连击高且时间窗口内）
	var special_effect = create_scale_item(Vector2(1.5, 1.5), 0.3)
	
	# 创建复合条件
	var combo_time_condition = JuicyCompositeCondition.new()
	combo_time_condition.operator = JuicyCompositeCondition.LogicalOperator.AND
	
	# 连击条件
	var combo_condition = JuicyParameterCondition.new()
	combo_condition.parameter_name = "combo_count"
	combo_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
	combo_condition.target_value = 5.0
	combo_time_condition.conditions.append(combo_condition)
	
	# 时间条件
	var time_condition = JuicyTimeCondition.new()
	time_condition.time_operator = JuicyTimeCondition.TimeOperator.PROGRESS_GREATER
	time_condition.target_time = 0.3
	combo_time_condition.conditions.append(time_condition)
	
	special_effect.condition = combo_time_condition
	composite.composite_items.append(special_effect)
	
	# 测试不同条件下的效果
	test_condition_scenarios(composite)

# 测试不同条件场景
func test_condition_scenarios(composite: JuicyCompositeResource):
	"""
	测试不同条件下的效果表现
	"""
	print("\n--- 测试不同条件场景 ---")
	
	# 场景1：正常状态
	print("\n场景1：正常状态（血量80%，连击2）")
	var context1 = JuicyMixer.play(composite, self)
	if context1:
		context1.set_parameter("player_health", 80.0)
		context1.set_parameter("combo_count", 2.0)
		await get_tree().create_timer(1.0).timeout
		JuicyMixer.stop(context1.context_id)
	
	# 场景2：低血量状态
	print("\n场景2：低血量状态（血量25%，连击2）")
	var context2 = JuicyMixer.play(composite, self)
	if context2:
		context2.set_parameter("player_health", 25.0)
		context2.set_parameter("combo_count", 2.0)
		await get_tree().create_timer(1.0).timeout
		JuicyMixer.stop(context2.context_id)
	
	# 场景3：高连击状态
	print("\n场景3：高连击状态（血量80%，连击6）")
	var context3 = JuicyMixer.play(composite, self)
	if context3:
		context3.set_parameter("player_health", 80.0)
		context3.set_parameter("combo_count", 6.0)
		await get_tree().create_timer(1.0).timeout
		JuicyMixer.stop(context3.context_id)
	
	# 场景4：完美状态
	print("\n场景4：完美状态（血量25%，连击6）")
	var context4 = JuicyMixer.play(composite, self)
	if context4:
		context4.set_parameter("player_health", 25.0)
		context4.set_parameter("combo_count", 6.0)
		await get_tree().create_timer(1.0).timeout
		JuicyMixer.stop(context4.context_id)

# 条件系统与参数映射的协同工作
func demonstrate_condition_parameter_mapping():
	"""
	展示条件系统与参数映射的协同工作
	"""
	print("\n=== 条件系统与参数映射协同示例 ===")
	
	# 创建组合资源
	var composite = JuicyCompositeResource.new()
	composite.enable_parameter_mapping = true
	composite.auto_update_parameters = true
	
	# 基础效果
	var base_effect = create_shake_item(2.0, 10.0, 0.5)
	composite.composite_items.append(base_effect)
	
	# 条件效果
	var conditional_effect = create_scale_item(Vector2(1.2, 1.2), 0.3)
	
	# 添加条件
	var intensity_condition = JuicyParameterCondition.new()
	intensity_condition.parameter_name = "intensity"
	intensity_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	intensity_condition.target_value = 0.5
	conditional_effect.condition = intensity_condition
	
	composite.composite_items.append(conditional_effect)
	
	# 添加参数映射
	var mapping = JuicyParameterMapping.new()
	mapping.input_parameter = "intensity"
	mapping.target_item_index = 0
	mapping.target_property = "amplitude"
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 5))
	mapping.curve = curve
	
	composite.parameter_mappings = [mapping]
	
	# 测试动态参数变化
	var context = JuicyMixer.play(composite, self)
	if context:
		print("测试动态参数变化...")
		
		# 低强度
		context.set_parameter("intensity", 0.3)
		await get_tree().create_timer(1.0).timeout
		
		# 高强度（触发条件）
		context.set_parameter("intensity", 0.8)
		await get_tree().create_timer(1.0).timeout
		
		JuicyMixer.stop(context.context_id)

# 条件系统在变体中的应用
func demonstrate_conditions_in_variants():
	"""
	展示条件系统在变体中的应用
	"""
	print("\n=== 条件系统在变体中的应用示例 ===")
	
	# 创建基础组合
	var base_composite = create_reusable_base_composite()
	
	# 创建变体
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	variant.inherit_parameter_bindings = true
	
	# 添加条件覆盖
	var condition_override = DataOverride.new()
	condition_override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
	condition_override.target_item_index = 0
	condition_override.target_data_index = 0
	
	# 为第一个效果添加条件
	var weather_condition = JuicyParameterCondition.new()
	weather_condition.parameter_name = "weather"
	weather_condition.operator = JuicyParameterCondition.ComparisonOperator.EQUAL
	weather_condition.target_value = 2.0  # 雨天
	
	# 这里需要特殊处理，因为DataOverride主要用于属性覆盖
	# 实际项目中可能需要扩展DataOverride来支持条件覆盖
	condition_override.property_overrides = {"amplitude": 6.0, "frequency": 15.0}
	
	variant.data_overrides = [condition_override]
	
	# 测试变体
	print("测试变体效果...")
	var context = JuicyMixer.play(variant, self)
	if context:
		context.set_parameter("weather", 2.0)  # 设置雨天
		await get_tree().create_timer(1.0).timeout
		JuicyMixer.stop(context.context_id)

# 条件系统性能优化示例
func demonstrate_condition_performance_optimization():
	"""
	展示条件系统的性能优化技巧
	"""
	print("\n=== 条件系统性能优化示例 ===")
	
	# 创建复杂条件
	var complex_condition = JuicyCompositeCondition.new()
	complex_condition.operator = JuicyCompositeCondition.LogicalOperator.AND
	
	# 添加多个子条件
	for i in range(5):
		var param_condition = JuicyParameterCondition.new()
		param_condition.parameter_name = "param_" + str(i)
		param_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
		param_condition.target_value = 0.5
		complex_condition.conditions.append(param_condition)
	
	# 性能测试
	var context = JuicyContext.new()
	
	# 设置参数值
	for i in range(5):
		context.set_parameter("param_" + str(i), 0.8)
	
	# 测试评估性能
	var start_time = Time.get_ticks_msec()
	for i in range(1000):
		complex_condition.evaluate(context)
	var end_time = Time.get_ticks_msec()
	
	print("1000次复杂条件评估耗时：", end_time - start_time, "ms")
	print("平均每次评估：", (end_time - start_time) / 1000.0, "ms")
	
	# 测试缓存优化
	print("\n测试缓存优化...")
	var cache_start_time = Time.get_ticks_msec()
	for i in range(1000):
		complex_condition.evaluate(context)  # 相同参数，应该使用缓存
	var cache_end_time = Time.get_ticks_msec()
	
	print("1000次缓存条件评估耗时：", cache_end_time - cache_start_time, "ms")
	print("平均每次评估：", (cache_end_time - cache_start_time) / 1000.0, "ms")

# 条件系统调试工具
func debug_condition_system(condition: JuicyCondition, context: JuicyContext):
	"""
	条件系统调试工具
	"""
	print("\n=== 条件系统调试 ===")
	print("条件类型：", condition.get_class())
	print("条件描述：", condition.get_description())
	print("启用状态：", condition.enabled)
	
	# 验证条件
	var validation_error = condition.validate_condition()
	if not validation_error.is_empty():
		print("验证错误：", validation_error)
		return
	
	# 评估条件
	var result = condition.evaluate(context)
	print("评估结果：", result)
	
	# 如果是复合条件，显示子条件详情
	if condition is JuicyCompositeCondition:
		var composite = condition as JuicyCompositeCondition
		print("逻辑操作符：", "AND" if composite.operator == JuicyCompositeCondition.LogicalOperator.AND else "OR")
		print("子条件数量：", composite.conditions.size())
		
		for i in range(composite.conditions.size()):
			var sub_condition = composite.conditions[i]
			print("  子条件", i, "：", sub_condition.get_description())
			print("  评估结果：", sub_condition.evaluate(context))

# 条件系统最佳实践
func condition_system_best_practices():
	"""
	条件系统最佳实践总结
	"""
	print("\n=== 条件系统最佳实践 ===")
	
	"""
	1. 条件设计原则：
	   - 保持条件简单明了
	   - 使用有意义的参数名
	   - 避免过深的嵌套
	   - 合理使用缓存机制
	
	2. 性能优化：
	   - 将最可能失败的条件放在AND前面
	   - 将最可能成功的条件放在OR前面
	   - 使用容差值避免浮点数精度问题
	   - 禁用不需要的条件
	
	3. 调试技巧：
	   - 使用validate_condition()验证配置
	   - 利用get_description()获取可读描述
	   - 测试边界条件
	   - 监控性能指标
	
	4. 集成建议：
	   - 与参数映射系统协同使用
	   - 在变体系统中灵活应用
	   - 结合时间条件创建动态效果
	   - 使用复合条件实现复杂逻辑
	"""
	
	print("✓ 条件系统最佳实践已总结")

# 完整的条件系统集成示例
func complete_condition_system_example():
	"""
	完整的条件系统集成示例
	"""
	print("\n=== 完整的条件系统集成示例 ===")
	
	# 创建战斗效果组合
	var combat_composite = create_combat_effects_with_conditions()
	
	# 播放效果
	var context = JuicyMixer.play(combat_composite, self)
	if context:
		print("开始战斗效果演示...")
		
		# 模拟战斗过程
		await simulate_combat_sequence(context)
		
		# 停止效果
		JuicyMixer.stop(context.context_id)
		print("战斗效果演示结束")

# 创建带条件的战斗效果
func create_combat_effects_with_conditions() -> JuicyCompositeResource:
	"""
	创建带条件的战斗效果组合
	"""
	var composite = JuicyCompositeResource.new()
	composite.enable_parameter_mapping = true
	
	# 基础攻击效果
	var basic_attack = create_shake_item(2.0, 8.0, 0.2)
	composite.composite_items.append(basic_attack)
	
	# 重击效果（力量高时）
	var heavy_attack = create_shake_item(5.0, 15.0, 0.4)
	var power_condition = JuicyParameterCondition.new()
	power_condition.parameter_name = "attack_power"
	power_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_THAN
	power_condition.target_value = 0.7
	heavy_attack.condition = power_condition
	composite.composite_items.append(heavy_attack)
	
	# 连击效果（连击数高时）
	var combo_effect = create_scale_item(Vector2(1.3, 1.3), 0.3)
	var combo_condition = JuicyParameterCondition.new()
	combo_condition.parameter_name = "combo_count"
	combo_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
	combo_condition.target_value = 3.0
	combo_effect.condition = combo_condition
	composite.composite_items.append(combo_effect)
	
	# 终极技能效果（血量低且连击高时）
	var ultimate_effect = create_scale_item(Vector2(1.8, 1.8), 0.5)
	var ultimate_condition = JuicyCompositeCondition.new()
	ultimate_condition.operator = JuicyCompositeCondition.LogicalOperator.AND
	
	# 血量低
	var health_condition = JuicyParameterCondition.new()
	health_condition.parameter_name = "player_health"
	health_condition.operator = JuicyParameterCondition.ComparisonOperator.LESS_THAN
	health_condition.target_value = 30.0
	ultimate_condition.conditions.append(health_condition)
	
	# 连击高
	var high_combo_condition = JuicyParameterCondition.new()
	high_combo_condition.parameter_name = "combo_count"
	high_combo_condition.operator = JuicyParameterCondition.ComparisonOperator.GREATER_EQUAL
	high_combo_condition.target_value = 5.0
	ultimate_condition.conditions.append(high_combo_condition)
	
	ultimate_effect.condition = ultimate_condition
	composite.composite_items.append(ultimate_effect)
	
	# 添加参数映射
	var power_mapping = JuicyParameterMapping.new()
	power_mapping.input_parameter = "attack_power"
	power_mapping.target_item_index = 0
	power_mapping.target_property = "amplitude"
	
	var power_curve = Curve.new()
	power_curve.add_point(Vector2(0, 1))
	power_curve.add_point(Vector2(1, 8))
	power_mapping.curve = power_curve
	
	composite.parameter_mappings = [power_mapping]
	
	return composite

# 模拟战斗序列
func simulate_combat_sequence(context: JuicyContext):
	"""
	模拟战斗序列，展示条件系统的动态响应
	"""
	print("\n--- 模拟战斗序列 ---")
	
	# 初始状态
	context.set_parameter("player_health", 100.0)
	context.set_parameter("attack_power", 0.3)
	context.set_parameter("combo_count", 0.0)
	print("初始状态：血量100%，攻击力30%，连击0")
	await get_tree().create_timer(1.0).timeout
	
	# 普通攻击
	context.set_parameter("attack_power", 0.5)
	context.set_parameter("combo_count", 1.0)
	print("普通攻击：攻击力50%，连击1")
	await get_tree().create_timer(1.0).timeout
	
	# 连击
	context.set_parameter("attack_power", 0.6)
	context.set_parameter("combo_count", 3.0)
	print("连击：攻击力60%，连击3")
	await get_tree().create_timer(1.0).timeout
	
	# 重击
	context.set_parameter("attack_power", 0.8)
	context.set_parameter("combo_count", 4.0)
	print("重击：攻击力80%，连击4")
	await get_tree().create_timer(1.0).timeout
	
	# 危机状态
	context.set_parameter("player_health", 25.0)
	context.set_parameter("attack_power", 0.9)
	context.set_parameter("combo_count", 6.0)
	print("危机状态：血量25%，攻击力90%，连击6（触发终极技能）")
	await get_tree().create_timer(1.0).timeout

# =============================================================================
# 第七章：实用工具函数
# =============================================================================

# 工具1：创建可复用的基础组合
func create_reusable_base_composite() -> JuicyCompositeResource:
	"""
	创建一个可复用的基础组合模板
	"""
	var composite = JuicyCompositeResource.new()
	
	# 添加通用的震动效果
	var shake_item = create_shake_item(3.0, 12.0, 0.3)
	composite.composite_items.append(shake_item)
	
	# 添加通用的缩放效果
	var scale_item = create_scale_item(Vector2(1.1, 1.1), 0.2)
	composite.composite_items.append(scale_item)
	
	composite.blend_mode = JuicyCompositeResource.CompositeBlendMode.ADDITIVE
	composite.normalize_weights = true
	
	return composite

# 工具2：创建震动项
func create_shake_item(amplitude: float, frequency: float, duration: float) -> JuicyCompositeItem:
	"""
	创建震动效果项
	"""
	var shake_resource = JuicyShakeResource.new()
	var shake_data = ShakeData.new()
	shake_data.property = "position"
	shake_data.amplitude = amplitude
	shake_data.frequency = frequency
	shake_data.duration = duration
	shake_resource.shake_data = [shake_data]
	
	var shake_item = JuicyCompositeItem.new()
	shake_item.resource = shake_resource
	shake_item.weight = 1.0
	shake_item.enabled = true
	
	return shake_item

# 工具3：创建缩放项
func create_scale_item(target_scale: Vector2, duration: float) -> JuicyCompositeItem:
	"""
	创建缩放效果项
	"""
	var tween_resource = JuicyTweenResource.new()
	var tween_data = TweenData.new()
	tween_data.property = "scale"
	tween_data.start_value = Vector2.ONE
	tween_data.end_value = target_scale
	tween_data.duration = duration
	tween_data.ease_type = Tween.EASE_OUT
	tween_data.trans_type = Tween.TRANS_BACK
	tween_resource.tween_data = [tween_data]
	
	var tween_item = JuicyCompositeItem.new()
	tween_item.resource = tween_resource
	tween_item.weight = 1.0
	tween_item.enabled = true
	
	return tween_item

# 完整使用流程示例
func complete_usage_example():
	"""
	完整的使用流程示例
	"""
	print("=== 完整使用流程示例 ===")
	
	# 步骤1：创建基础组合
	var composite = step1_create_composite()
	
	# 步骤2：添加参数映射
	composite = step2_add_parameter_mapping(composite)
	
	# 步骤3：创建变体
	var variant = step3_create_variant(composite)
	
	# 步骤4：使用混音台（需要await因为函数是coroutine）
	var context = await step4_use_mixer(variant)
	
	# 验证配置
	var errors = validate_all_configurations([composite, variant])
	if errors.is_empty():
		print("✓ 所有配置验证通过")
	else:
		print("✗ 配置验证失败：", "\n".join(errors))
	
	return context

# 验证所有配置
func validate_all_configurations(resources: Array) -> Array[String]:
	"""
	验证一组资源的配置
	"""
	var errors = []
	
	for resource in resources:
		if resource.has_method("validate_config"):
			var result = resource.validate_config()
			if not result.valid:
				errors.append("Resource validation failed: " + "\n".join(result.issues))
	
	return errors

# 更新主演示函数
func _ready():
	# 原有演示
	complete_usage_example()
	
	# 新增条件系统演示
	print("\n" + "=".repeat(60))
	print("🔧 开始条件系统集成演示")
	print("=".repeat(60))
	
	demonstrate_condition_system_integration()
	demonstrate_condition_parameter_mapping()
	demonstrate_conditions_in_variants()
	demonstrate_condition_performance_optimization()
	condition_system_best_practices()
	complete_condition_system_example()
	
	print("\n" + "=".repeat(60))
	print("🎉 条件系统集成演示完成！")
	print("=".repeat(60))