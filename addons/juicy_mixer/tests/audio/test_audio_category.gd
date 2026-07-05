extends Node

func test_category_creation():
	var category = AudioCategory.new()

	# 设置类别
	category.category_name = "Explosions"
	category.max_instances = 3
	category.category_priority = AudioCategory.AudioCategoryPriority.HIGH

	# 验证
	assert(category.category_name == "Explosions", "Category name should be Explosions")
	assert(category.max_instances == 3, "Max instances should be 3")
	assert(category.category_priority == AudioCategory.AudioCategoryPriority.HIGH, "Priority should be HIGH")

	print("test_category_creation PASSED")

func test_category_validation():
	var category = AudioCategory.new()

	# 空名称应该失败
	var result = category.validate()
	assert(result.valid == false, "Empty category name should be invalid")
	assert(result.issues.size() > 0, "Should have issues")

	# 有效配置
	category.category_name = "Footsteps"
	category.max_instances = 5
	result = category.validate()
	assert(result.valid == true, "Valid category should pass")

	print("test_category_validation PASSED")

func test_priority_factors():
	var category = AudioCategory.new()

	# 设置权重
	category.distance_weight = 0.5
	category.importance_weight = 0.3
	category.recency_weight = 0.2

	var factors = category.get_priority_factors()
	assert(factors.distance_weight == 0.5, "Distance weight should be 0.5")
	assert(factors.importance_weight == 0.3, "Importance weight should be 0.3")
	assert(factors.recency_weight == 0.2, "Recency weight should be 0.2")

	print("test_priority_factors PASSED")

func test_category_clone():
	var category = AudioCategory.new()
	category.category_name = "Hit"
	category.max_instances = 4
	category.category_priority = AudioCategory.AudioCategoryPriority.CRITICAL
	category.distance_weight = 0.6
	category.importance_weight = 0.3
	category.recency_weight = 0.1
	category.shared_bus = "Master"

	var clone = category.clone()

	assert(clone.category_name == category.category_name, "Cloned category name should match")
	assert(clone.max_instances == category.max_instances, "Cloned max_instances should match")
	assert(clone.category_priority == category.category_priority, "Cloned priority should match")
	assert(clone.distance_weight == category.distance_weight, "Cloned distance_weight should match")
	assert(clone.importance_weight == category.importance_weight, "Cloned importance_weight should match")
	assert(clone.recency_weight == category.recency_weight, "Cloned recency_weight should match")
	assert(clone.shared_bus == category.shared_bus, "Cloned shared_bus should match")

	# 验证克隆是独立的
	clone.category_name = "Modified"
	assert(category.category_name == "Hit", "Original category should not be affected")

	print("test_category_clone PASSED")

func _ready():
	test_category_creation()
	test_category_validation()
	test_priority_factors()
	test_category_clone()

	print("\n=== All AudioCategory tests passed! ===")
