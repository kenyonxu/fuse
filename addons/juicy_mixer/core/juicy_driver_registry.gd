# JuicyDriverRegistry - 驱动器注册表
# 管理Driver的注册和发现机制
# 维护属性到Driver的映射关系，支持动态Driver管理

class_name JuicyDriverRegistry
extends RefCounted

# Driver存储
var _drivers: Dictionary = {}  # driver_name -> DriverInstance
var _property_mapping: Dictionary = {}  # property -> [driver_names]

# Driver实例数据
class DriverInstance:
	var driver: Object
	var instance_id: String
	var registration_time: float
	var is_active: bool = true

# 注册管理
func register_driver(driver: Object) -> bool:
	if not driver or not driver.has_method("get_driver_name"):
		push_error("Invalid driver for registration")
		return false
	
	var driver_name = driver.get_driver_name()
	if driver_name.is_empty():
		push_error("Driver name cannot be empty")
		return false
	
	if _drivers.has(driver_name):
		push_warning("Driver '" + driver_name + "' already registered, overriding")
	
	# 创建实例
	var instance = DriverInstance.new()
	instance.driver = driver
	instance.instance_id = _generate_instance_id()
	instance.registration_time = Time.get_ticks_msec() / 1000.0
	
	# 注册驱动器
	_drivers[driver_name] = instance
	
	# 更新属性映射
	if driver.has_method("get_supported_properties"):
		var properties = driver.get_supported_properties()
		_update_property_mapping(driver_name, properties)
	
	print("Registered driver: ", driver_name)
	return true

func unregister_driver(driver_name: String) -> bool:
	if not _drivers.has(driver_name):
		return false
	
	var instance = _drivers[driver_name]
	
	# 清理属性映射
	if instance.driver.has_method("get_supported_properties"):
		var properties = instance.driver.get_supported_properties()
		_remove_property_mapping(driver_name, properties)
	
	# 移除驱动器
	_drivers.erase(driver_name)
	
	print("Unregistered driver: ", driver_name)
	return true

# 查询接口
func get_driver(driver_name: String) -> Object:
	var instance = _drivers.get(driver_name)
	return instance.driver if instance and instance.is_active else null

func get_drivers_for_property(property: String) -> Array:
	var driver_names = _property_mapping.get(property, [])
	var drivers: Array = []
	
	for driver_name in driver_names:
		var driver = get_driver(driver_name)
		if driver:
			drivers.append(driver)
	
	return drivers

func get_all_drivers() -> Array:
	var drivers: Array = []
	
	for instance in _drivers.values():
		if instance.is_active:
			drivers.append(instance.driver)
	
	return drivers

# 自动发现
func auto_discover_drivers() -> int:
	var discovered_count = 0
	
	# 扫描项目中的Driver类
	var driver_classes = _scan_project_drivers()
	
	for driver_class in driver_classes:
		var driver = driver_class.new()
		if register_driver(driver):
			discovered_count += 1
	
	print("Auto-discovered ", discovered_count, " drivers")
	return discovered_count

func _scan_project_drivers() -> Array:
	# 这里需要实现项目扫描逻辑
	# 暂时返回空数组，后续实现
	return []

# 管理接口
func activate_driver(driver_name: String) -> bool:
	var instance = _drivers.get(driver_name)
	if not instance:
		return false
	
	instance.is_active = true
	return true

func deactivate_driver(driver_name: String) -> bool:
	var instance = _drivers.get(driver_name)
	if not instance:
		return false
	
	instance.is_active = false
	return true

# 内部方法
func _generate_instance_id() -> String:
	return "driver_inst_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 10000)

func _update_property_mapping(driver_name: String, properties: Array) -> void:
	for property in properties:
		if not _property_mapping.has(property):
			_property_mapping[property] = []
		
		if driver_name not in _property_mapping[property]:
			_property_mapping[property].append(driver_name)

func _remove_property_mapping(driver_name: String, properties: Array) -> void:
	for property in properties:
		if _property_mapping.has(property):
			var driver_names = _property_mapping[property]
			driver_names.erase(driver_name)
			
			if driver_names.is_empty():
				_property_mapping.erase(property)

# 调试和统计
func get_registry_stats() -> Dictionary:
	var active_drivers = 0
	var total_properties = 0
	
	for instance in _drivers.values():
		if instance.is_active:
			active_drivers += 1
		if instance.driver.has_method("get_supported_properties"):
			total_properties += instance.driver.get_supported_properties().size()
	
	return {
		"total_drivers": _drivers.size(),
		"active_drivers": active_drivers,
		"mapped_properties": _property_mapping.size(),
		"total_property_mappings": total_properties
	}