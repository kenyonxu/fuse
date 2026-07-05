# Composite参数映射功能示例
# 展示如何使用新的参数映射系统

extends Node

# 示例：创建一个充能效果的组合
func create_charge_effect_example():
	# 创建组合资源
	var charge_composite = JuicyCompositeResource.new()
	
	# 添加震动效果
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
	
	# 添加弹簧效果
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
	
	# 设置组合项
	charge_composite.composite_items = [shake_item, spring_item]
	charge_composite.blend_mode = JuicyCompositeResource.CompositeBlendMode.ADDITIVE
	charge_composite.normalize_weights = true
	
	# 启用参数映射
	charge_composite.enable_parameter_mapping = true
	charge_composite.auto_update_parameters = true
	
	# 配置参数映射
	var charge_to_shake = JuicyParameterMapping.new()
	charge_to_shake.input_parameter = "charge_amount"
	charge_to_shake.target_item_index = 0  # 震动效果
	charge_to_shake.target_property = "amplitude"
	# 创建映射曲线：0-1 -> 0-10
	var shake_curve = Curve.new()
	shake_curve.add_point(Vector2(0, 0))
	shake_curve.add_point(Vector2(1, 10))
	charge_to_shake.curve = shake_curve
	
	var charge_to_spring = JuicyParameterMapping.new()
	charge_to_spring.input_parameter = "charge_amount"
	charge_to_spring.target_item_index = 1  # 弹簧效果
	charge_to_spring.target_property = "target_value"
	# 创建映射曲线：0-1 -> 1.0-1.5
	var spring_curve = Curve.new()
	spring_curve.add_point(Vector2(0, 1.0))
	spring_curve.add_point(Vector2(1, 1.5))
	charge_to_spring.curve = spring_curve
	
	charge_composite.parameter_mappings = [charge_to_shake, charge_to_spring]
	
	return charge_composite

# 示例：使用参数映射
func use_charge_effect():
	# 创建效果
	var charge_composite = create_charge_effect_example()
	
	# 播放效果
	var context_id = JuicyMixer.play(charge_composite, self)
	
	# 在游戏中更新参数
	if context_id:
		var context = JuicyMixer.get_context(context_id)
		if context:
			# 设置充能值（0.0-1.0）
			context.set_parameter("charge_amount", 0.5)
			
			# 驱动器会自动将charge_amount映射到：
			# - 震动效果的amplitude属性（通过曲线映射到5.0）
			# - 弹簧效果的target_value属性（通过曲线映射到1.25）
			
			# 可以实时更新参数
			await get_tree().create_timer(0.5).timeout
			context.set_parameter("charge_amount", 1.0)  # 完全充能

# 示例：混音台功能
func mixer_example():
	# 创建多个组合效果
	var charge_effect = create_charge_effect_example()
	var damage_effect = create_damage_effect_example()  # 假设有另一个效果
	
	# 播放多个效果
	var charge_context = JuicyMixer.play(charge_effect, self)
	var damage_context = JuicyMixer.play(damage_effect, self)
	
	# 使用混音台功能实时调整参数
	if charge_context and damage_context:
		# 调整充能效果
		charge_context.set_parameter("charge_amount", 0.8)
		
		# 调整伤害效果（假设有damage_amount参数）
		damage_context.set_parameter("damage_amount", 0.6)

# 创建伤害效果示例
func create_damage_effect_example():
	var damage_composite = JuicyCompositeResource.new()
	
	# 添加屏幕震动
	var shake_resource = JuicyShakeResource.new()
	var shake_data = ShakeData.new()
	shake_data.property = "position"
	shake_data.amplitude = 8.0
	shake_data.frequency = 20.0
	shake_data.duration = 0.5
	shake_resource.shake_data = [shake_data]
	
	var shake_item = JuicyCompositeItem.new()
	shake_item.resource = shake_resource
	shake_item.weight = 1.0
	shake_item.enabled = true
	
	# 添加Tween效果
	var tween_resource = JuicyTweenResource.new()
	var tween_data = TweenData.new()
	tween_data.property = "modulate"
	tween_data.start_value = Color.WHITE
	tween_data.end_value = Color.RED
	tween_data.duration = 0.3
	tween_resource.tween_data = [tween_data]
	
	var tween_item = JuicyCompositeItem.new()
	tween_item.resource = tween_resource
	tween_item.weight = 1.0
	tween_item.enabled = true
	
	damage_composite.composite_items = [shake_item, tween_item]
	damage_composite.enable_parameter_mapping = true
	
	# 配置伤害参数映射
	var damage_to_shake = JuicyParameterMapping.new()
	damage_to_shake.input_parameter = "damage_amount"
	damage_to_shake.target_item_index = 0
	damage_to_shake.target_property = "amplitude"
	
	var damage_to_tween = JuicyParameterMapping.new()
	damage_to_tween.input_parameter = "damage_amount"
	damage_to_tween.target_item_index = 1
	damage_to_tween.target_property = "duration"
	
	damage_composite.parameter_mappings = [damage_to_shake, damage_to_tween]
	
	return damage_composite