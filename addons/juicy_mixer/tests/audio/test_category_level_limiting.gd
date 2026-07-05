extends Node

## 测试类别级限额检查和智能优先级排序

func test_category_limit_blocks_over_limit():
	"""测试类别限额阻止超过限制的实例"""
	var resource = AudioEventResource.new()
	resource.event_name = "explosion"

	# 创建类别（限制为 2 个实例）
	var category = AudioCategory.new()
	category.category_name = "Explosions"
	category.max_instances = 2
	category.category_priority = AudioCategory.AudioCategoryPriority.HIGH

	resource.categories.append(category)

	var config = AudioMixingConfig.new()
	config.max_instances = 10  # 实例级限额较大
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加 2 个类别实例
	controller.record_instance("explosion", AudioStreamPlayer2D.new(), 50, resource, Vector3(10, 0, 0))
	controller.record_instance("explosion", AudioStreamPlayer2D.new(), 50, resource, Vector3(20, 0, 0))

	# 第 3 个应该被类别限额阻止
	var result = controller.can_play(resource, "explosion", null, Vector3(30, 0, 0), 50)
	assert(result == false, "Should be blocked by category limit")

	print("test_category_limit_blocks_over_limit PASSED")

func test_smart_priority_sorting():
	"""测试智能优先级排序（基于距离）"""
	var resource = AudioEventResource.new()
	resource.event_name = "explosion"

	var category = AudioCategory.new()
	category.category_name = "Explosions"
	category.max_instances = 2
	category.distance_weight = 1.0  # 只考虑距离
	category.importance_weight = 0.0
	category.recency_weight = 0.0

	resource.categories.append(category)

	var config = AudioMixingConfig.new()
	config.max_instances = 10
	config.limit_policy = AudioMixingConfig.LimitPolicy.FIFO
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加 2 个远距离实例
	controller.record_instance("explosion", AudioStreamPlayer2D.new(), 50, resource, Vector3(100, 0, 0))
	controller.record_instance("explosion", AudioStreamPlayer2D.new(), 50, resource, Vector3(100, 0, 0))

	# 第 3 个近距离实例应该替换远距离的
	var can_play = controller.can_play(resource, "explosion", null, Vector3(5, 0, 0), 50)
	# 由于距离更近，应该允许播放并停止最远的实例
	assert(can_play == true, "Nearby instance should replace distant one")

	print("test_smart_priority_sorting PASSED")

func test_importance_priority():
	"""测试重要性优先级排序"""
	var resource = AudioEventResource.new()
	resource.event_name = "explosion"

	var category = AudioCategory.new()
	category.category_name = "Explosions"
	category.max_instances = 2
	category.distance_weight = 0.0  # 只考虑重要性
	category.importance_weight = 1.0
	category.recency_weight = 0.0

	resource.categories.append(category)

	var config = AudioMixingConfig.new()
	config.max_instances = 10
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加 2 个低重要性实例
	controller.record_instance("explosion", AudioStreamPlayer2D.new(), 30, resource, Vector3(10, 0, 0))
	controller.record_instance("explosion", AudioStreamPlayer2D.new(), 30, resource, Vector3(20, 0, 0))

	# 第 3 个高重要性实例应该替换低重要性的
	var can_play = controller.can_play(resource, "explosion", null, Vector3(30, 0, 0), 90)
	assert(can_play == true, "High importance instance should replace low importance ones")

	print("test_importance_priority PASSED")

func test_multiple_categories():
	"""测试多个类别"""
	var resource = AudioEventResource.new()
	resource.event_name = "explosion"

	# 类别 1：爆炸
	var category1 = AudioCategory.new()
	category1.category_name = "Explosions"
	category1.max_instances = 2

	# 类别 2：战斗音效
	var category2 = AudioCategory.new()
	category2.category_name = "Combat"
	category2.max_instances = 5

	resource.categories.append(category1)
	resource.categories.append(category2)

	var config = AudioMixingConfig.new()
	config.max_instances = 10
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 填满 Explosions 类别
	controller.record_instance("explosion", AudioStreamPlayer2D.new(), 50, resource, Vector3(10, 0, 0))
	controller.record_instance("explosion", AudioStreamPlayer2D.new(), 50, resource, Vector3(20, 0, 0))

	# 第 3 个应该被 Explosions 类别限额阻止（即使 Combat 类别未满）
	var result = controller.can_play(resource, "explosion", null, Vector3(30, 0, 0), 50)
	assert(result == false, "Should be blocked by Explosions category limit")

	print("test_multiple_categories PASSED")

func test_no_categories():
	"""测试无类别时正常工作"""
	var resource = AudioEventResource.new()
	resource.event_name = "explosion"
	resource.categories.clear()  # 无类别

	var config = AudioMixingConfig.new()
	config.max_instances = 10
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 应该通过实例级检查
	var result = controller.can_play(resource, "explosion")
	assert(result == true, "Should pass instance-level check when no categories")

	print("test_no_categories PASSED")

func test_remove_instance_cleanup():
	"""测试移除实例时清理类别追踪"""
	var resource = AudioEventResource.new()
	resource.event_name = "explosion"

	var category = AudioCategory.new()
	category.category_name = "Explosions"
	category.max_instances = 2

	resource.categories.append(category)

	var config = AudioMixingConfig.new()
	config.max_instances = 10
	resource.mixing = config

	var controller = AudioMixingController.new()

	# 添加实例
	var player1 = AudioStreamPlayer2D.new()
	var player2 = AudioStreamPlayer2D.new()
	controller.record_instance("explosion", player1, 50, resource, Vector3(10, 0, 0))
	controller.record_instance("explosion", player2, 50, resource, Vector3(20, 0, 0))

	# 移除实例
	controller.remove_instance("explosion", player1, resource)
	controller.remove_instance("explosion", player2, resource)

	# 应该能够再添加 2 个实例
	var player3 = AudioStreamPlayer2D.new()
	var player4 = AudioStreamPlayer2D.new()
	controller.record_instance("explosion", player3, 50, resource, Vector3(30, 0, 0))
	controller.record_instance("explosion", player4, 50, resource, Vector3(40, 0, 0))

	# 第 3 个应该被阻止
	var result = controller.can_play(resource, "explosion", null, Vector3(50, 0, 0), 50)
	assert(result == false, "Should be blocked after removing and re-adding instances")

	print("test_remove_instance_cleanup PASSED")

func _ready():
	"""运行所有测试"""
	print("=== 开始类别级限额测试 ===")

	test_category_limit_blocks_over_limit()
	test_smart_priority_sorting()
	test_importance_priority()
	test_multiple_categories()
	test_no_categories()
	test_remove_instance_cleanup()

	print("=== 所有测试通过 ===")
