# JuicyDriverRegistry 单元测试
# 测试驱动器注册、查询和管理功能

extends Node

var _registry: JuicyDriverRegistry

# 模拟驱动器类
class MockDriver:
	var driver_name: String
	var supported_properties: Array
	
	func _init(name: String, properties: Array):
		driver_name = name
		supported_properties = properties
	
	func get_driver_name() -> String:
		return driver_name
	
	func get_supported_properties() -> Array:
		return supported_properties
	
	func is_active() -> bool:
		return true

func _ready():
	_registry = JuicyDriverRegistry.new()
	
	# 运行测试
	_test_driver_registration()
	_test_driver_queries()
	_test_property_mapping()
	_test_driver_activation()
	_test_registry_stats()
	
	print("✅ All JuicyDriverRegistry tests passed!")

func _test_driver_registration():
	print("Testing driver registration...")
	
	# 创建测试驱动器
	var driver1 = MockDriver.new("TestDriver1", ["position", "rotation"])
	var driver2 = MockDriver.new("TestDriver2", ["scale", "position"])
	
	# 测试注册
	assert(_registry.register_driver(driver1), "Driver1 should be registered successfully")
	assert(_registry.register_driver(driver2), "Driver2 should be registered successfully")
	
	# 测试重复注册（应该覆盖）
	var driver1_new = MockDriver.new("TestDriver1", ["position"])
	assert(_registry.register_driver(driver1_new), "Re-registration should succeed")
	
	print("✅ Driver registration test passed")

func _test_driver_queries():
	print("Testing driver queries...")
	
	# 创建并注册测试驱动器
	var driver1 = MockDriver.new("QueryDriver1", ["position"])
	var driver2 = MockDriver.new("QueryDriver2", ["scale"])
	
	_registry.register_driver(driver1)
	_registry.register_driver(driver2)
	
	# 测试单个驱动器查询
	var retrieved_driver1 = _registry.get_driver("QueryDriver1")
	assert(retrieved_driver1 == driver1, "Should retrieve correct driver")
	
	var retrieved_driver2 = _registry.get_driver("QueryDriver2")
	assert(retrieved_driver2 == driver2, "Should retrieve correct driver")
	
	# 测试不存在的驱动器
	var non_existent = _registry.get_driver("NonExistent")
	assert(non_existent == null, "Non-existent driver should return null")
	
	# 测试获取所有驱动器
	var all_drivers = _registry.get_all_drivers()
	assert(all_drivers.size() >= 2, "Should have at least 2 drivers")
	
	print("✅ Driver queries test passed")

func _test_property_mapping():
	print("Testing property mapping...")
	
	# 清空注册表
	_registry = JuicyDriverRegistry.new()
	
	# 创建并注册具有不同属性的驱动器
	var driver1 = MockDriver.new("PropDriver1", ["position", "rotation"])
	var driver2 = MockDriver.new("PropDriver2", ["scale", "position"])
	var driver3 = MockDriver.new("PropDriver3", ["rotation", "modulate"])
	
	_registry.register_driver(driver1)
	_registry.register_driver(driver2)
	_registry.register_driver(driver3)
	
	# 测试属性到驱动器的映射
	var position_drivers = _registry.get_drivers_for_property("position")
	assert(position_drivers.size() == 2, "Should have 2 drivers for position")
	
	var rotation_drivers = _registry.get_drivers_for_property("rotation")
	assert(rotation_drivers.size() == 2, "Should have 2 drivers for rotation")
	
	var scale_drivers = _registry.get_drivers_for_property("scale")
	assert(scale_drivers.size() == 1, "Should have 1 driver for scale")
	
	var modulate_drivers = _registry.get_drivers_for_property("modulate")
	assert(modulate_drivers.size() == 1, "Should have 1 driver for modulate")
	
	# 测试不存在的属性
	var non_existent_drivers = _registry.get_drivers_for_property("non_existent")
	assert(non_existent_drivers.size() == 0, "Should have 0 drivers for non-existent property")
	
	print("✅ Property mapping test passed")

func _test_driver_activation():
	print("Testing driver activation/deactivation...")
	
	# 创建并注册测试驱动器
	var driver = MockDriver.new("ActivationDriver", ["position"])
	_registry.register_driver(driver)
	
	# 测试停用
	assert(_registry.deactivate_driver("ActivationDriver"), "Should deactivate driver")
	var deactivated_driver = _registry.get_driver("ActivationDriver")
	assert(deactivated_driver == null, "Deactivated driver should not be retrievable")
	
	# 测试激活
	assert(_registry.activate_driver("ActivationDriver"), "Should activate driver")
	var activated_driver = _registry.get_driver("ActivationDriver")
	assert(activated_driver == driver, "Activated driver should be retrievable")
	
	# 测试不存在的驱动器
	assert(not _registry.deactivate_driver("NonExistent"), "Should fail to deactivate non-existent driver")
	assert(not _registry.activate_driver("NonExistent"), "Should fail to activate non-existent driver")
	
	print("✅ Driver activation test passed")

func _test_registry_stats():
	print("Testing registry statistics...")
	
	# 清空注册表
	_registry = JuicyDriverRegistry.new()
	
	# 创建并注册测试驱动器
	var driver1 = MockDriver.new("StatsDriver1", ["position", "rotation"])
	var driver2 = MockDriver.new("StatsDriver2", ["scale"])
	var driver3 = MockDriver.new("StatsDriver3", ["modulate", "position"])
	
	_registry.register_driver(driver1)
	_registry.register_driver(driver2)
	_registry.register_driver(driver3)
	
	# 停用其中一个
	_registry.deactivate_driver("StatsDriver2")
	
	# 获取统计信息
	var stats = _registry.get_registry_stats()
	
	assert(stats.total_drivers == 3, "Should have 3 total drivers")
	assert(stats.active_drivers == 2, "Should have 2 active drivers")
	assert(stats.mapped_properties == 4, "Should have 4 mapped properties") # position, rotation, scale, modulate
	assert(stats.total_property_mappings == 5, "Should have 5 total mappings") # position appears twice
	
	print("✅ Registry stats test passed")

func _exit_tree():
	pass