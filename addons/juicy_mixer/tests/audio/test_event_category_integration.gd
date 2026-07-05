extends Node

## 测试 AudioEventResource 与 AudioCategory 的集成

func test_event_with_category():
	var resource = AudioEventResource.new()
	resource.event_name = "explosion"

	# 创建类别
	var category = AudioCategory.new()
	category.category_name = "Explosions"
	category.max_instances = 3
	category.category_priority = AudioCategory.AudioCategoryPriority.HIGH

	# 关联类别
	resource.categories.append(category)

	# 验证
	assert(resource.categories.size() == 1, "Should have 1 category")
	assert(resource.get_effective_priority() == 70, "Priority should be 70 (HIGH)")

	print("test_event_with_category PASSED")

func test_priority_override():
	var resource = AudioEventResource.new()

	# 创建中优先级类别
	var category = AudioCategory.new()
	category.category_name = "Footsteps"
	category.category_priority = AudioCategory.AudioCategoryPriority.MEDIUM

	resource.categories.append(category)
	resource.category_priority_override = 80

	# 覆盖值应该更高
	assert(resource.get_effective_priority() == 80, "Override should take precedence")

	print("test_priority_override PASSED")

func test_multiple_categories():
	var resource = AudioEventResource.new()

	var category1 = AudioCategory.new()
	category1.category_priority = AudioCategory.AudioCategoryPriority.MEDIUM

	var category2 = AudioCategory.new()
	category2.category_priority = AudioCategory.AudioCategoryPriority.HIGH

	resource.categories.append(category1)
	resource.categories.append(category2)

	# 应该取最高优先级
	assert(resource.get_effective_priority() == 70, "Should use highest category priority")

	print("test_multiple_categories PASSED")

func test_no_categories():
	var resource = AudioEventResource.new()
	resource.category_priority_override = 60

	# 没有类别时应该使用覆盖值
	assert(resource.get_effective_priority() == 60, "Should use override when no categories")

	print("test_no_categories PASSED")

func test_category_validation():
	var resource = AudioEventResource.new()

	# 添加一个空类别引用
	resource.categories.append(null)

	# 添加一个有效的音频变体以通过基本验证
	var variant = AudioVariant.new()
	variant.stream = null  # 这会导致验证失败，但不影响类别验证测试
	resource.audio_variants.append(variant)

	var validation = resource.validate()
	# 应该有关于空类别的警告
	assert(validation.warnings.size() > 0, "Should have warning about null category")

	print("test_category_validation PASSED")

func _ready():
	print("开始运行 AudioEvent-Category 集成测试...")
	print("")

	test_event_with_category()
	test_priority_override()
	test_multiple_categories()
	test_no_categories()
	test_category_validation()

	print("")
	print("所有测试通过！")
