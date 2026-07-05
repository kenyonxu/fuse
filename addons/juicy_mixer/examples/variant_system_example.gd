# 变体系统与组合系统集成示例
# 展示如何使用JuicyResourceVariant创建不同变体的组合效果
# 包括火焰、冰霜、雷电等元素变体

extends Node

# =============================================================================
# 基础组合效果创建
# =============================================================================

# 创建基础攻击效果组合
func create_base_attack_composite() -> JuicyCompositeResource:
	"""
	创建一个基础的攻击效果组合，包含震动和缩放效果
	这个将作为所有变体的基础模板
	"""
	var composite = JuicyCompositeResource.new()
	
	# 基础震动效果
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
	shake_item.enabled = true
	
	# 基础缩放效果
	var tween_resource = JuicyTweenResource.new()
	var tween_data = TweenData.new()
	tween_data.property = "scale"
	tween_data.start_value = Vector2.ONE
	tween_data.end_value = Vector2(1.1, 1.1)
	tween_data.duration = 0.2
	tween_data.ease_type = Tween.EASE_OUT
	tween_data.trans_type = Tween.TRANS_BACK
	tween_resource.tween_data = [tween_data]
	
	var tween_item = JuicyCompositeItem.new()
	tween_item.resource = tween_resource
	tween_item.weight = 1.0
	tween_item.enabled = true
	
	# 设置组合
	composite.composite_items = [shake_item, tween_item]
	composite.blend_mode = JuicyCompositeResource.CompositeBlendMode.ADDITIVE
	composite.normalize_weights = true
	
	return composite

# =============================================================================
# 火焰变体创建
# =============================================================================

# 创建火焰攻击变体
func create_fire_attack_variant() -> JuicyResourceVariant:
	"""
	创建火焰攻击变体，在基础攻击上添加火焰特效
	"""
	var base_composite = create_base_attack_composite()
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	
	# 1. 修改震动效果的幅度（更强烈的火焰冲击）
	var shake_amplitude_override = DataOverride.new()
	shake_amplitude_override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
	shake_amplitude_override.target_item_index = 0  # 震动效果
	shake_amplitude_override.target_data_index = 0
	shake_amplitude_override.property_overrides = {
		"amplitude": 6.0,  # 增加震动幅度
		"frequency": 18.0,  # 增加频率
		"duration": 0.4     # 延长持续时间
	}
	
	# 2. 替换缩放效果为火焰爆发效果
	var fire_burst_data = TweenData.new()
	fire_burst_data.property = "scale"
	fire_burst_data.start_value = Vector2.ONE
	fire_burst_data.end_value = Vector2(1.3, 1.3)  # 更大的爆发
	fire_burst_data.duration = 0.15
	fire_burst_data.ease_type = Tween.EASE_OUT
	fire_burst_data.trans_type = Tween.TRANS_EXPO
	
	var fire_burst_override = DataOverride.new()
	fire_burst_override.override_mode = DataOverride.OverrideMode.REPLACE_DATA
	fire_burst_override.target_item_index = 1  # 缩放效果
	fire_burst_override.target_data_index = 0
	fire_burst_override.new_data = fire_burst_data
	
	# 3. 添加火焰粒子效果（使用Tween效果模拟）
	var particle_resource = JuicyTweenResource.new()
	var particle_data = TweenData.new()
	particle_data.property = "modulate"
	particle_data.start_value = Color.ORANGE_RED
	particle_data.end_value = Color.YELLOW
	particle_data.duration = 0.5
	particle_data.ease_type = Tween.EASE_OUT
	particle_data.trans_type = Tween.TRANS_EXPO
	particle_data.particle_count = 20
	particle_data.emission_rate = 50.0
	particle_data.lifetime = 0.8
	particle_data.start_color = Color.ORANGE_RED
	particle_data.end_color = Color.YELLOW
	particle_data.start_size = 0.1
	particle_data.end_size = 0.05
	particle_data.velocity = Vector2(100, -50)
	particle_data.gravity = Vector2(0, 200)
	particle_data.duration = 0.5
	particle_resource.particle_data = [particle_data]
	
	var particle_item = JuicyCompositeItem.new()
	particle_item.resource = particle_resource
	particle_item.weight = 0.8
	particle_item.enabled = true
	
	var particle_override = DataOverride.new()
	particle_override.override_mode = DataOverride.OverrideMode.ADD_TO_COMPOSITE
	particle_override.new_composite_item = particle_item
	
	# 4. 添加火焰闪烁效果（模拟音效视觉效果）
	var audio_resource = JuicyTweenResource.new()
	var audio_data = TweenData.new()
	audio_data.property = "self_modulate"
	audio_data.start_value = Color.WHITE
	audio_data.end_value = Color(1.0, 0.8, 0.0, 0.3)
	audio_data.duration = 0.4
	audio_data.ease_type = Tween.EASE_OUT
	audio_data.trans_type = Tween.TRANS_SINE
	audio_data.audio_path = "res://sounds/fire_whoosh.wav"  # 假设的音效路径
	audio_data.volume = 0.7
	audio_data.pitch = 1.2
	audio_data.duration = 0.4
	audio_resource.audio_data = [audio_data]
	
	var audio_item = JuicyCompositeItem.new()
	audio_item.resource = audio_resource
	audio_item.weight = 1.0
	audio_item.enabled = true
	
	var audio_override = DataOverride.new()
	audio_override.override_mode = DataOverride.OverrideMode.ADD_TO_COMPOSITE
	audio_override.new_composite_item = audio_item
	
	# 设置所有覆盖
	variant.data_overrides = [
		shake_amplitude_override,
		fire_burst_override,
		particle_override,
		audio_override
	]
	
	return variant

# =============================================================================
# 冰霜变体创建
# =============================================================================

# 创建冰霜攻击变体
func create_ice_attack_variant() -> JuicyResourceVariant:
	"""
	创建冰霜攻击变体，在基础攻击上添加冰霜特效
	"""
	var base_composite = create_base_attack_composite()
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	
	# 1. 修改震动效果（更缓慢、凝滞的感觉）
	var shake_slow_override = DataOverride.new()
	shake_slow_override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
	shake_slow_override.target_item_index = 0
	shake_slow_override.target_data_index = 0
	shake_slow_override.property_overrides = {
		"amplitude": 2.0,   # 减少震动幅度
		"frequency": 6.0,   # 降低频率
		"duration": 0.6     # 延长持续时间
	}
	
	# 2. 替换缩放效果为冰霜凝结效果
	var ice_form_data = TweenData.new()
	ice_form_data.property = "modulate"
	ice_form_data.start_value = Color.WHITE
	ice_form_data.end_value = Color(0.7, 0.9, 1.0, 1.0)  # 冰蓝色
	ice_form_data.duration = 0.3
	ice_form_data.ease_type = Tween.EASE_IN_OUT
	ice_form_data.trans_type = Tween.TRANS_SINE
	
	var ice_form_override = DataOverride.new()
	ice_form_override.override_mode = DataOverride.OverrideMode.REPLACE_DATA
	ice_form_override.target_item_index = 1
	ice_form_override.target_data_index = 0
	ice_form_override.new_data = ice_form_data
	
	# 3. 添加冰霜结晶效果（使用Tween模拟）
	var crystal_particle_resource = JuicyTweenResource.new()
	var crystal_data = TweenData.new()
	crystal_data.property = "modulate"
	crystal_data.start_value = Color(0.8, 0.9, 1.0, 0.8)
	crystal_data.end_value = Color(0.9, 0.95, 1.0, 0.0)
	crystal_data.duration = 0.7
	crystal_data.ease_type = Tween.EASE_IN_OUT
	crystal_data.trans_type = Tween.TRANS_SINE
	crystal_data.particle_count = 15
	crystal_data.emission_rate = 30.0
	crystal_data.lifetime = 1.0
	crystal_data.start_color = Color(0.8, 0.9, 1.0, 0.8)
	crystal_data.end_color = Color(0.9, 0.95, 1.0, 0.0)
	crystal_data.start_size = 0.05
	crystal_data.end_size = 0.02
	crystal_data.velocity = Vector2(50, -30)
	crystal_data.gravity = Vector2(0, 100)
	crystal_data.duration = 0.7
	crystal_particle_resource.particle_data = [crystal_data]
	
	var crystal_item = JuicyCompositeItem.new()
	crystal_item.resource = crystal_particle_resource
	crystal_item.weight = 0.6
	crystal_item.enabled = true
	
	var crystal_override = DataOverride.new()
	crystal_override.override_mode = DataOverride.OverrideMode.ADD_TO_COMPOSITE
	crystal_override.new_composite_item = crystal_item
	
	# 4. 添加冰霜闪烁效果
	var ice_audio_resource = JuicyTweenResource.new()
	var ice_audio_data = TweenData.new()
	ice_audio_data.property = "self_modulate"
	ice_audio_data.start_value = Color.WHITE
	ice_audio_data.end_value = Color(0.7, 0.9, 1.0, 0.4)
	ice_audio_data.duration = 0.5
	ice_audio_data.ease_type = Tween.EASE_IN_OUT
	ice_audio_data.trans_type = Tween.TRANS_SINE
	ice_audio_data.audio_path = "res://sounds/ice_crack.wav"
	ice_audio_data.volume = 0.6
	ice_audio_data.pitch = 0.8  # 降低音调
	ice_audio_data.duration = 0.5
	ice_audio_resource.audio_data = [ice_audio_data]
	
	var ice_audio_item = JuicyCompositeItem.new()
	ice_audio_item.resource = ice_audio_resource
	ice_audio_item.weight = 1.0
	ice_audio_item.enabled = true
	
	var ice_audio_override = DataOverride.new()
	ice_audio_override.override_mode = DataOverride.OverrideMode.ADD_TO_COMPOSITE
	ice_audio_override.new_composite_item = ice_audio_item
	
	# 设置所有覆盖
	variant.data_overrides = [
		shake_slow_override,
		ice_form_override,
		crystal_override,
		ice_audio_override
	]
	
	return variant

# =============================================================================
# 雷电变体创建
# =============================================================================

# 创建雷电攻击变体
func create_lightning_attack_variant() -> JuicyResourceVariant:
	"""
	创建雷电攻击变体，在基础攻击上添加雷电特效
	"""
	var base_composite = create_base_attack_composite()
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_composite
	
	# 1. 修改震动效果（快速、尖锐的雷电感）
	var shake_sharp_override = DataOverride.new()
	shake_sharp_override.override_mode = DataOverride.OverrideMode.MODIFY_DATA
	shake_sharp_override.target_item_index = 0
	shake_sharp_override.target_data_index = 0
	shake_sharp_override.property_overrides = {
		"amplitude": 4.0,   # 中等震动幅度
		"frequency": 25.0,  # 高频率
		"duration": 0.2     # 短持续时间
	}
	
	# 2. 替换缩放效果为雷电闪烁效果
	var lightning_flash_data = TweenData.new()
	lightning_flash_data.property = "modulate"
	lightning_flash_data.start_value = Color.WHITE
	lightning_flash_data.end_value = Color(0.9, 0.9, 1.0, 1.0)
	lightning_flash_data.duration = 0.05  # 极短闪烁
	lightning_flash_data.ease_type = Tween.EASE_OUT
	lightning_flash_data.trans_type = Tween.TRANS_LINEAR
	
	var lightning_flash_override = DataOverride.new()
	lightning_flash_override.override_mode = DataOverride.OverrideMode.REPLACE_DATA
	lightning_flash_override.target_item_index = 1
	lightning_flash_override.target_data_index = 0
	lightning_flash_override.new_data = lightning_flash_data
	
	# 3. 添加雷电闪烁效果
	var lightning_particle_resource = JuicyTweenResource.new()
	var lightning_data = TweenData.new()
	lightning_data.property = "self_modulate"
	lightning_data.start_value = Color(0.9, 0.9, 1.0, 1.0)
	lightning_data.end_value = Color(1.0, 1.0, 1.0, 0.0)
	lightning_data.duration = 0.2
	lightning_data.ease_type = Tween.EASE_OUT
	lightning_data.trans_type = Tween.TRANS_LINEAR
	lightning_data.particle_count = 8
	lightning_data.emission_rate = 100.0  # 高发射率
	lightning_data.lifetime = 0.3
	lightning_data.start_color = Color(0.9, 0.9, 1.0, 1.0)  # 亮白色
	lightning_data.end_color = Color(0.7, 0.7, 1.0, 0.0)
	lightning_data.start_size = 0.08
	lightning_data.end_size = 0.01
	lightning_data.velocity = Vector2(200, -100)  # 快速移动
	lightning_data.gravity = Vector2(0, 50)
	lightning_data.duration = 0.2
	lightning_particle_resource.particle_data = [lightning_data]
	
	var lightning_item = JuicyCompositeItem.new()
	lightning_item.resource = lightning_particle_resource
	lightning_item.weight = 0.9
	lightning_item.enabled = true
	
	var lightning_override = DataOverride.new()
	lightning_override.override_mode = DataOverride.OverrideMode.ADD_TO_COMPOSITE
	lightning_override.new_composite_item = lightning_item
	
	# 4. 添加雷电屏幕闪烁
	var lightning_audio_resource = JuicyTweenResource.new()
	var lightning_audio_data = TweenData.new()
	lightning_audio_data.property = "modulate"
	lightning_audio_data.start_value = Color.WHITE
	lightning_audio_data.end_value = Color(0.8, 0.8, 1.0, 0.2)
	lightning_audio_data.duration = 0.3
	lightning_audio_data.ease_type = Tween.EASE_OUT
	lightning_audio_data.trans_type = Tween.TRANS_SINE
	lightning_audio_data.audio_path = "res://sounds/lightning_crack.wav"
	lightning_audio_data.volume = 0.8
	lightning_audio_data.pitch = 1.5  # 高音频
	lightning_audio_data.duration = 0.3
	lightning_audio_resource.audio_data = [lightning_audio_data]
	
	var lightning_audio_item = JuicyCompositeItem.new()
	lightning_audio_item.resource = lightning_audio_resource
	lightning_audio_item.weight = 1.0
	lightning_audio_item.enabled = true
	
	var lightning_audio_override = DataOverride.new()
	lightning_audio_override.override_mode = DataOverride.OverrideMode.ADD_TO_COMPOSITE
	lightning_audio_override.new_composite_item = lightning_audio_item
	
	# 设置所有覆盖
	variant.data_overrides = [
		shake_sharp_override,
		lightning_flash_override,
		lightning_override,
		lightning_audio_override
	]
	
	return variant

# =============================================================================
# 参数映射继承示例
# =============================================================================

# 创建带有参数映射的基础组合
func create_base_composite_with_mapping() -> JuicyCompositeResource:
	"""
	创建一个带有参数映射的基础组合效果
	"""
	var composite = create_base_attack_composite()
	
	# 启用参数映射
	composite.enable_parameter_mapping = true
	composite.auto_update_parameters = true
	
	# 添加参数映射：攻击强度 -> 震动幅度
	var intensity_to_shake = JuicyParameterMapping.new()
	intensity_to_shake.input_parameter = "attack_intensity"
	intensity_to_shake.target_item_index = 0  # 震动效果
	intensity_to_shake.target_property = "amplitude"
	
	# 创建映射曲线：0-1 -> 0-8
	var shake_curve = Curve.new()
	shake_curve.add_point(Vector2(0, 0))
	shake_curve.add_point(Vector2(1, 8))
	intensity_to_shake.curve = shake_curve
	
	# 添加参数映射：攻击强度 -> 缩放强度
	var intensity_to_scale = JuicyParameterMapping.new()
	intensity_to_scale.input_parameter = "attack_intensity"
	intensity_to_scale.target_item_index = 1  # 缩放效果
	intensity_to_scale.target_property = "end_value"
	
	# 创建映射曲线：0-1 -> 1.0-1.4
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1.0))
	scale_curve.add_point(Vector2(1, 1.4))
	intensity_to_scale.curve = scale_curve
	
	composite.parameter_mappings = [intensity_to_shake, intensity_to_scale]
	
	return composite

# 创建继承参数映射的火焰变体
func create_fire_variant_with_inherited_mapping() -> JuicyResourceVariant:
	"""
	创建火焰变体，继承基础组合的参数映射
	"""
	var base_with_mapping = create_base_composite_with_mapping()
	var variant = JuicyResourceVariant.new()
	variant.base_composite_resource = base_with_mapping
	variant.inherit_parameter_bindings = true  # 继承参数绑定
	
	# 添加火焰特有的覆盖
	var fire_particle_override = DataOverride.new()
	fire_particle_override.override_mode = DataOverride.OverrideMode.ADD_TO_COMPOSITE
	
	var particle_resource = JuicyTweenResource.new()
	var particle_data = TweenData.new()
	particle_data.property = "modulate"
	particle_data.start_value = Color.ORANGE_RED
	particle_data.end_value = Color.YELLOW
	particle_data.duration = 0.5
	particle_data.ease_type = Tween.EASE_OUT
	particle_data.trans_type = Tween.TRANS_EXPO
	particle_data.particle_count = 20
	particle_data.start_color = Color.ORANGE_RED
	particle_data.duration = 0.5
	particle_resource.particle_data = [particle_data]
	
	var particle_item = JuicyCompositeItem.new()
	particle_item.resource = particle_resource
	particle_item.weight = 0.8
	particle_item.enabled = true
	
	fire_particle_override.new_composite_item = particle_item
	
	variant.data_overrides = [fire_particle_override]
	
	return variant

# =============================================================================
# 混音台功能示例
# =============================================================================

# 创建混音台示例
func create_mixer_example():
	"""
	展示如何使用混音台功能实时控制多个变体
	"""
	# 创建不同的变体
	var fire_variant = create_fire_attack_variant()
	var ice_variant = create_ice_attack_variant()
	var lightning_variant = create_lightning_attack_variant()
	
	# 播放多个变体
	var fire_context = JuicyMixer.play(fire_variant, self)
	var ice_context = JuicyMixer.play(ice_variant, self)
	var lightning_context = JuicyMixer.play(lightning_variant, self)
	
	# 使用混音台功能
	if fire_context:
		# 获取驱动器进行实时控制
		var driver = fire_context.get_driver()
		if driver and driver is JuicyCompositeDriver:
			# 实时调整参数
			driver.set_parameter(fire_context.context_id, "attack_intensity", 0.8)
	
	return {
		"fire_context": fire_context,
		"ice_context": ice_context,
		"lightning_context": lightning_context
	}

# =============================================================================
# 使用示例
# =============================================================================

# 示例：在游戏中使用变体系统
func example_usage():
	"""
	展示如何在实际游戏中使用变体系统
	"""
	# 创建玩家角色
	var player = $Player
	
	# 根据武器类型选择不同的攻击变体
	var attack_variant: JuicyResourceVariant
	
	match get_current_weapon_type():
		"fire":
			attack_variant = create_fire_attack_variant()
		"ice":
			attack_variant = create_ice_attack_variant()
		"lightning":
			attack_variant = create_lightning_attack_variant()
		_:
			# 默认使用基础组合
			var base_composite = create_base_attack_composite()
			var context = JuicyMixer.play(base_composite, player)
			return
	
	# 播放选中的变体
	var context = JuicyMixer.play(attack_variant, player)
	
	# 设置攻击强度参数
	if context:
		context.set_parameter("attack_intensity", get_attack_power())
		
		# 可以实时更新参数
		await get_tree().create_timer(0.1).timeout
		context.set_parameter("attack_intensity", get_attack_power() * 0.5)

# 获取当前武器类型（示例函数）
func get_current_weapon_type() -> String:
	# 这里应该根据游戏状态返回武器类型
	return "fire"

# 获取攻击力（示例函数）
func get_attack_power() -> float:
	# 这里应该根据游戏状态返回攻击力（0.0-1.0）
	return 0.8

# =============================================================================
# 验证和测试
# =============================================================================

# 验证所有变体的配置
func validate_all_variants() -> Array[String]:
	"""
	验证所有创建的变体配置是否正确
	"""
	var errors = []
	
	var variants = [
		create_fire_attack_variant(),
		create_ice_attack_variant(),
		create_lightning_attack_variant(),
		create_fire_variant_with_inherited_mapping()
	]
	
	for i in range(variants.size()):
		var variant = variants[i]
		var result = variant.validate_config()
		if not result.valid:
			errors.append("Variant %d validation failed: %s" % [i, "\n".join(result.issues)])
	
	return errors

# 获取变体描述信息
func get_variant_descriptions() -> Array[String]:
	"""
	获取所有变体的描述信息
	"""
	var descriptions = []
	
	var fire_variant = create_fire_attack_variant()
	descriptions.append("Fire Variant: " + fire_variant.get_description())
	
	var ice_variant = create_ice_attack_variant()
	descriptions.append("Ice Variant: " + ice_variant.get_description())
	
	var lightning_variant = create_lightning_attack_variant()
	descriptions.append("Lightning Variant: " + lightning_variant.get_description())
	
	return descriptions