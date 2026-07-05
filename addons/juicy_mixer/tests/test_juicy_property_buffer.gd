# JuicyPropertyBuffer 单元测试
# 测试属性缓冲区的混合算法和批处理功能

extends Node

var _buffer: JuicyPropertyBuffer
var _test_target: Node2D

func _ready():
	_buffer = JuicyPropertyBuffer.new()
	_test_target = Node2D.new()
	_test_target.position = Vector2(100, 100)
	_test_target.scale = Vector2(1, 1)
	_test_target.rotation = 0.0
	add_child(_test_target)

	# 运行测试
	_test_basic_blending()
	_test_additive_blending()
	_test_multiplicative_blending()
	_test_complex_blending()
	_test_context_cleanup()
	_test_buffer_stats()

	# 🔧 新增测试：问题1-5的修复验证
	_test_multiplicative_null_safety()      # 问题1：null 处理
	_test_color_additive_blending()          # Color ADDITIVE
	_test_color_multiplicative_alpha_modes() # 问题2：Color alpha_mode
	_test_cross_blend_mode_priority()        # 问题3：跨混合模式优先级
	_test_advanced_middleware_cleanup()      # 问题4：高级清理
	_test_context_id_replacement()           # context_id 替换行为

	print("✅ All JuicyPropertyBuffer tests passed!")

func _test_basic_blending():
	print("Testing basic property blending...")
	
	# 测试基础覆盖
	_buffer.add_sample(_test_target, "position", Vector2(200, 200), JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE, "ctx1")
	_buffer.flush_target_samples(_test_target)
	
	assert(_test_target.position == Vector2(200, 200), "Position should be overridden")
	
	# 测试后来的覆盖优先级
	_buffer.add_sample(_test_target, "position", Vector2(300, 300), JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE, "ctx2")
	_buffer.flush_target_samples(_test_target)
	
	assert(_test_target.position == Vector2(300, 300), "Later override should take precedence")
	
	print("✅ Basic blending test passed")

func _test_additive_blending():
	print("Testing additive property blending...")
	
	# 重置目标
	_test_target.position = Vector2(100, 100)
	_buffer.clear_target_samples(_test_target)
	
	# 测试加法混合
	_buffer.add_sample(_test_target, "position", Vector2(50, 50), JuicyPropertyBuffer.BlendMode.ADDITIVE, "ctx1")
	_buffer.flush_target_samples(_test_target)
	
	assert(_test_target.position == Vector2(150, 150), "Position should be added to base")
	
	# 测试多个加法
	_buffer.add_sample(_test_target, "position", Vector2(25, 25), JuicyPropertyBuffer.BlendMode.ADDITIVE, "ctx2")
	_buffer.flush_target_samples(_test_target)
	
	assert(_test_target.position == Vector2(175, 175), "Multiple additions should accumulate")
	
	print("✅ Additive blending test passed")

func _test_multiplicative_blending():
	print("Testing multiplicative property blending...")
	
	# 重置目标
	_test_target.scale = Vector2(2, 2)
	_buffer.clear_target_samples(_test_target)
	
	# 测试乘法混合
	_buffer.add_sample(_test_target, "scale", Vector2(1.5, 1.5), JuicyPropertyBuffer.BlendMode.MULTIPLICATIVE, "ctx1")
	_buffer.flush_target_samples(_test_target)
	
	assert(_test_target.scale == Vector2(3, 3), "Scale should be multiplied")
	
	# 测试多个乘法
	_buffer.add_sample(_test_target, "scale", Vector2(0.5, 0.5), JuicyPropertyBuffer.BlendMode.MULTIPLICATIVE, "ctx2")
	_buffer.flush_target_samples(_test_target)
	
	assert(_test_target.scale == Vector2(1.5, 1.5), "Multiple multiplications should compound")
	
	print("✅ Multiplicative blending test passed")

func _test_complex_blending():
	print("Testing complex property blending...")
	
	# 重置目标
	_test_target.position = Vector2(100, 100)
	_test_target.scale = Vector2(1, 1)
	_buffer.clear_target_samples(_test_target)
	
	# 测试混合模式组合
	_buffer.add_sample(_test_target, "position", Vector2(200, 200), JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE, "ctx1")
	_buffer.add_sample(_test_target, "position", Vector2(50, 50), JuicyPropertyBuffer.BlendMode.ADDITIVE, "ctx2")
	_buffer.flush_target_samples(_test_target)
	
	assert(_test_target.position == Vector2(250, 250), "Override + Additive should work correctly")
	
	print("✅ Complex blending test passed")

func _test_context_cleanup():
	print("Testing context cleanup...")
	
	# 重置目标到已知状态
	_test_target.position = Vector2(100, 100)
	_buffer.clear_target_samples(_test_target)
	
	# 添加多个上下文的采样
	_buffer.add_sample(_test_target, "position", Vector2(500, 500), JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE, "ctx1")
	_buffer.add_sample(_test_target, "position", Vector2(100, 100), JuicyPropertyBuffer.BlendMode.ADDITIVE, "ctx2")
	_buffer.add_sample(_test_target, "rotation", 1.0, JuicyPropertyBuffer.BlendMode.ADDITIVE, "ctx1")
	
	# 移除一个上下文的所有采样
	_buffer.remove_context_samples("ctx1")
	_buffer.flush_target_samples(_test_target)
	
	# 应该只剩下ctx2的加法采样（基础值100,100 + 加法100,100 = 200,200）
	assert(_test_target.position == Vector2(200, 200), "Context cleanup should remove specified context samples")
	
	print("✅ Context cleanup test passed")

func _test_buffer_stats():
	print("Testing buffer statistics...")
	
	_buffer.clear_target_samples(_test_target)
	
	# 添加一些采样
	_buffer.add_sample(_test_target, "position", Vector2(100, 100), JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE, "ctx1")
	_buffer.add_sample(_test_target, "scale", Vector2(2, 2), JuicyPropertyBuffer.BlendMode.MULTIPLICATIVE, "ctx2")
	_buffer.add_sample(_test_target, "rotation", 0.5, JuicyPropertyBuffer.BlendMode.ADDITIVE, "ctx3")
	
	var stats = _buffer.get_buffer_stats()
	
	assert(stats.total_targets == 1, "Should have 1 target")
	assert(stats.total_properties == 3, "Should have 3 properties")
	assert(stats.total_samples == 3, "Should have 3 samples")
	
	print("✅ Buffer stats test passed")

func _exit_tree():
	if _test_target:
		_test_target.queue_free()

## 🔧 问题1：测试 MULTIPLICATIVE 模式的 null 处理
func _test_multiplicative_null_safety():
	print("Testing multiplicative null safety (问题1)...")

	# 创建一个新节点，position 未初始化
	var new_node = Node2D.new()
	add_child(new_node)

	_buffer.clear_target_samples(new_node)

	# 测试：对 null 属性应用 MULTIPLICATIVE
	# 期望：应该优雅处理，使用 ZERO 作为 base_value
	_buffer.add_sample(new_node, "position", Vector2(2.0, 2.0), JuicyPropertyBuffer.BlendMode.MULTIPLICATIVE, "test")
	_buffer.flush_target_samples(new_node)

	# 验证：position 应该是 ZERO * 2.0 = ZERO
	assert(new_node.position == Vector2.ZERO, "Null base_value should default to ZERO")

	new_node.queue_free()
	print("✅ Multiplicative null safety test passed")

## 测试 Color ADDITIVE 混合
func _test_color_additive_blending():
	print("Testing Color additive blending...")

	# 创建一个 Sprite2D（有 modulate 属性）
	var sprite = Sprite2D.new()
	sprite.modulate = Color(0.5, 0.5, 0.5, 1.0)
	add_child(sprite)

	_buffer.clear_target_samples(sprite)

	# 测试多个 ADDITIVE Color 样本
	_buffer.add_sample(sprite, "modulate", Color(0.2, 0.1, 0.0, 0.9), JuicyPropertyBuffer.BlendMode.ADDITIVE, "ctx1")
	_buffer.add_sample(sprite, "modulate", Color(0.1, 0.2, 0.0, 0.8), JuicyPropertyBuffer.BlendMode.ADDITIVE, "ctx2")
	_buffer.flush_target_samples(sprite)

	# 验证：RGB 累积，alpha 使用最后一个样本
	var expected = Color(0.8, 0.8, 0.5, 0.8)  # RGB: 0.5+0.2+0.1, 0.5+0.1+0.2, 0.5+0.0+0.0, alpha: 0.8
	assert(abs(sprite.modulate.r - expected.r) < 0.01, "Red channel should accumulate")
	assert(abs(sprite.modulate.g - expected.g) < 0.01, "Green channel should accumulate")
	assert(abs(sprite.modulate.b - expected.b) < 0.01, "Blue channel should accumulate")
	assert(abs(sprite.modulate.a - expected.a) < 0.01, "Alpha should use last sample")

	sprite.queue_free()
	print("✅ Color additive blending test passed")

## 🔧 问题2：测试 Color MULTIPLICATIVE alpha_mode
func _test_color_multiplicative_alpha_modes():
	print("Testing Color multiplicative alpha modes (问题2)...")

	var sprite = Sprite2D.new()
	sprite.modulate = Color(1.0, 0.5, 0.5, 0.5)
	add_child(sprite)

	# 测试 alpha_mode=0 (乘法 alpha)
	_buffer.clear_target_samples(sprite)
	# 注意：由于 add_sample 不支持设置 alpha_mode，这里只测试默认行为
	_buffer.add_sample(sprite, "modulate", Color(0.5, 0.5, 0.5, 0.5), JuicyPropertyBuffer.BlendMode.MULTIPLICATIVE, "test")
	_buffer.flush_target_samples(sprite)

	# 验证：RGB 和 alpha 都被乘法
	var expected = Color(0.5, 0.25, 0.25, 0.25)  # 1.0*0.5, 0.5*0.5, 0.5*0.5, 0.5*0.5
	assert(abs(sprite.modulate.r - expected.r) < 0.01, "Red should multiply")
	assert(abs(sprite.modulate.g - expected.g) < 0.01, "Green should multiply")
	assert(abs(sprite.modulate.b - expected.b) < 0.01, "Blue should multiply")
	assert(abs(sprite.modulate.a - expected.a) < 0.01, "Alpha should multiply (mode 0)")

	sprite.queue_free()
	print("✅ Color multiplicative alpha modes test passed")

## 🔧 问题3：测试跨混合模式优先级
func _test_cross_blend_mode_priority():
	print("Testing cross-blend-mode priority (问题3)...")

	_buffer.clear_target_samples(_test_target)
	_test_target.scale = Vector2(1, 1)

	# 高优先级 OVERRIDE_BASE
	_buffer.add_middleware_sample(_test_target, "scale", Vector2(2, 2),
		JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE, "middleware_A", 10)

	# 低优先级 ADDITIVE
	_buffer.add_middleware_sample(_test_target, "scale", Vector2(1, 1),
		JuicyPropertyBuffer.BlendMode.ADDITIVE, "middleware_B", 0)

	_buffer.flush_target_samples(_test_target)

	# 验证：结果是 2 + 1 = 3（低优先级的 ADDITIVE 仍会影响结果）
	# 这证明了优先级只在混合模式内工作，不影响跨模式
	assert(_test_target.scale == Vector2(3, 3), "Cross-blend-mode: lower priority ADDITIVE still affects result")

	print("✅ Cross-blend-mode priority test passed")

## 🔧 问题4：测试高级中间件清理
func _test_advanced_middleware_cleanup():
	print("Testing advanced middleware cleanup (问题4)...")

	_buffer.clear_target_samples(_test_target)
	_test_target.position = Vector2(100, 100)
	_test_target.scale = Vector2(1, 1)

	# 添加中间件样本（多个混合模式）
	_buffer.add_middleware_sample(_test_target, "position", Vector2(200, 200),
		JuicyPropertyBuffer.BlendMode.OVERRIDE_BASE, "test_middleware", 0)
	_buffer.add_middleware_sample(_test_target, "position", Vector2(10, 0),
		JuicyPropertyBuffer.BlendMode.ADDITIVE, "test_middleware", 0)
	_buffer.add_middleware_sample(_test_target, "scale", Vector2(1.5, 1.5),
		JuicyPropertyBuffer.BlendMode.MULTIPLICATIVE, "test_middleware", 0)

	# 测试1：只移除 ADDITIVE 样本
	_buffer.remove_middleware_samples_by_mode("test_middleware", JuicyPropertyBuffer.BlendMode.ADDITIVE)
	_buffer.flush_target_samples(_test_target)

	# 验证：position 应该是 200（OVERRIDE_BASE），没有 ADDITIVE 的 10
	# scale 应该是 1 * 1.5 = 1.5（MULTIPLICATIVE 仍在）
	assert(_test_target.position == Vector2(200, 200), "Only ADDITIVE should be removed")
	assert(_test_target.scale == Vector2(1.5, 1.5), "MULTIPLICATIVE should remain")

	# 测试2：移除特定属性
	_buffer.add_middleware_sample(_test_target, "position", Vector2(10, 0),
		JuicyPropertyBuffer.BlendMode.ADDITIVE, "test_middleware", 0)
	_buffer.remove_middleware_samples_for_property("test_middleware", "position")
	_buffer.flush_target_samples(_test_target)

	# 验证：position 的所有样本被移除，应该回到原始值
	assert(_test_target.position == Vector2(100, 100), "All position samples should be removed")
	# scale 应该不受影响
	assert(_test_target.scale == Vector2(1.5, 1.5), "scale samples should remain")

	print("✅ Advanced middleware cleanup test passed")

## 测试 context_id 替换行为
func _test_context_id_replacement():
	print("Testing context ID replacement behavior...")

	_buffer.clear_target_samples(_test_target)
	_test_target.position = Vector2(100, 100)

	# 相同 context_id 的 ADDITIVE 样本应该替换
	_buffer.add_sample(_test_target, "position", Vector2(10, 0), JuicyPropertyBuffer.BlendMode.ADDITIVE, "same_ctx")
	_buffer.add_sample(_test_target, "position", Vector2(20, 0), JuicyPropertyBuffer.BlendMode.ADDITIVE, "same_ctx")
	_buffer.flush_target_samples(_test_target)

	# 验证：应该使用最后一个值 (20)，而不是累积 (10 + 20)
	assert(_test_target.position == Vector2(120, 100), "Same context_id should replace, not accumulate")

	# 不同 context_id 应该累积
	_buffer.add_sample(_test_target, "position", Vector2(10, 0), JuicyPropertyBuffer.BlendMode.ADDITIVE, "ctx1")
	_buffer.add_sample(_test_target, "position", Vector2(20, 0), JuicyPropertyBuffer.BlendMode.ADDITIVE, "ctx2")
	_buffer.flush_target_samples(_test_target)

	# 验证：两个不同 context_id 应该累积
	assert(_test_target.position == Vector2(150, 100), "Different context_ids should accumulate")

	print("✅ Context ID replacement test passed")

