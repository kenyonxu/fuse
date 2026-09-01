# 属性系统通用类测试计划

## 📋 测试目标

为三个通用类（PropertyInfo、TypeConverter、PropertyManager）创建全面的测试用例，验证功能的正确性和稳定性。

## 🧪 测试范围

### 1. PropertyInfo 类测试
- **基础功能**：属性创建、信息获取、类型检查
- **属性分析**：可写性、可读性、类型判断
- **值验证**：类型兼容性、范围检查、错误处理
- **序列化**：to_dict/from_dict 功能

### 2. TypeConverter 类测试
- **类型转换**：所有支持类型的转换测试
- **兼容性检查**：类型兼容性矩阵验证
- **特殊转换**：字符串到 Vector、Color、NodePath
- **错误处理**：转换失败时的错误信息

### 3. PropertyManager 类测试
- **属性发现**：获取节点属性列表
- **属性过滤**：各种过滤器的正确性
- **属性操作**：安全设置、批量操作
- **缓存系统**：缓存性能和内存管理

## 🔧 测试用例设计

### PropertyInfo 测试用例

#### 基础功能测试
```gdscript
# 测试属性信息创建
func test_property_info_creation():
    var prop_dict = {
        "name": "test_prop",
        "type": TYPE_INT,
        "hint": PROPERTY_HINT_RANGE,
        "hint_string": "0,100,1",
        "usage": PROPERTY_USAGE_EDITOR,
        "default_value": 50
    }
    
    var prop_info = PropertyInfo.create(prop_dict)
    assert(prop_info.name == "test_prop")
    assert(prop_info.type == TYPE_INT)
    assert(prop_info.is_numeric() == true)
    assert(prop_info.is_writable() == true)

# 测试从节点属性创建
func test_property_info_from_node():
    var node = Node2D.new()
    var prop_info = PropertyInfo.from_node_property(node, "position")
    assert(prop_info != null)
    assert(prop_info.name == "position")
    assert(prop_info.is_vector() == true)
```

#### 值验证测试
```gdscript
# 测试数值范围验证
func test_numeric_validation():
    var prop_info = PropertyInfo.new()
    prop_info.name = "health"
    prop_info.type = TYPE_INT
    prop_info.min_value = 0
    prop_info.max_value = 100
    
    # 有效值
    var valid_result = prop_info.validate_value(50)
    assert(valid_result.valid == true)
    
    # 无效值
    var invalid_result = prop_info.validate_value(150)
    assert(invalid_result.valid == false)
    assert("值大于最大值" in invalid_result.error)

# 测试类型兼容性
func test_type_compatibility():
    var prop_info = PropertyInfo.new()
    prop_info.name = "score"
    prop_info.type = TYPE_INT
    
    # 兼容类型
    var compatible_result = prop_info.validate_value("123")
    assert(compatible_result.valid == true)
    
    # 不兼容类型
    var incompatible_result = prop_info.validate_value({"key": "value"})
    assert(incompatible_result.valid == false)
```

### TypeConverter 测试用例

#### 基础类型转换测试
```gdscript
# 测试数值转换
func test_numeric_conversions():
    # 字符串到整数
    var int_result = TypeConverter.safe_convert_to_int("123")
    assert(int_result == 123)
    
    # 浮点数到整数
    var float_to_int = TypeConverter.safe_convert_to_int(45.67)
    assert(float_to_int == 45)
    
    # 布尔值到整数
    var bool_to_int = TypeConverter.safe_convert_to_int(true)
    assert(bool_to_int == 1)

# 测试字符串转换
func test_string_conversions():
    # 数值到字符串
    var num_to_str = TypeConverter.safe_convert_to_string(42)
    assert(num_to_str == "42")
    
    # 布尔值到字符串
    var bool_to_str = TypeConverter.safe_convert_to_string(false)
    assert(bool_to_str == "false")
    
    # 对象到字符串
    var obj_to_str = TypeConverter.safe_convert_to_string(Vector2(1, 2))
    assert(obj_to_str == "(1, 2)")
```

#### 特殊类型转换测试
```gdscript
# 测试向量转换
func test_vector_conversions():
    # 字符串到 Vector2
    var str_to_vec2 = TypeConverter.safe_convert_to_vector2("1.5,2.5")
    assert(str_to_vec2.is_equal_approx(Vector2(1.5, 2.5)))
    
    # Vector3 到 Vector2
    var vec3_to_vec2 = TypeConverter.safe_convert_to_vector2(Vector3(1, 2, 3))
    assert(vec3_to_vec2.is_equal_approx(Vector2(1, 2)))
    
    # 颜色到 Vector3
    var color_to_vec3 = TypeConverter.safe_convert_to_vector3(Color.RED)
    assert(color_to_vec3.is_equal_approx(Vector3(1, 0, 0)))

# 测试颜色转换
func test_color_conversions():
    # 十六进制字符串
    var hex_to_color = TypeConverter.safe_convert_to_color("#FF0000")
    assert(hex_to_color.is_equal_approx(Color.RED))
    
    # HTML 颜色名
    var name_to_color = TypeConverter.safe_convert_to_color("blue")
    assert(name_to_color.is_equal_approx(Color.BLUE))
    
    # 数值到灰度
    var num_to_color = TypeConverter.safe_convert_to_color(128)
    assert(num_to_color.r > 0.4 and num_to_color.r < 0.6)
```

#### 兼容性检查测试
```gdscript
# 测试类型兼容性矩阵
func test_compatibility_matrix():
    # 数值类型互相兼容
    assert(TypeConverter.is_compatible(TYPE_INT, TYPE_FLOAT) == true)
    assert(TypeConverter.is_compatible(TYPE_FLOAT, TYPE_INT) == true)
    assert(TypeConverter.is_compatible(TYPE_BOOL, TYPE_INT) == true)
    
    # 字符串与基础类型兼容
    assert(TypeConverter.is_compatible(TYPE_STRING, TYPE_INT) == true)
    assert(TypeConverter.is_compatible(TYPE_STRING, TYPE_COLOR) == true)
    
    # 向量类型部分兼容
    assert(TypeConverter.is_compatible(TYPE_VECTOR2, TYPE_VECTOR3) == true)
    assert(TypeConverter.is_compatible(TYPE_VECTOR3, TYPE_VECTOR2) == true)
```

### PropertyManager 测试用例

#### 属性发现测试
```gdscript
# 测试获取所有属性
func test_get_all_properties():
    var node = Sprite2D.new()
    var properties = PropertyManager.get_all_properties(node)
    
    # 检查是否包含基本属性
    var has_position = false
    var has_rotation = false
    var has_scale = false
    
    for prop in properties:
        if prop.name == "position":
            has_position = true
            assert(prop.is_vector() == true)
        elif prop.name == "rotation":
            has_rotation = true
            assert(prop.is_numeric() == true)
        elif prop.name == "scale":
            has_scale = true
            assert(prop.is_vector() == true)
    
    assert(has_position and has_rotation and has_scale)

# 测试属性过滤
func test_property_filtering():
    var node = Control.new()
    
    # 测试可写属性过滤
    var writable_props = PropertyManager.get_writable_properties(node)
    for prop in writable_props:
        assert(prop.is_writable())
    
    # 测试数值属性过滤
    var numeric_props = PropertyManager.get_numeric_properties(node)
    for prop in numeric_props:
        assert(prop.is_numeric())
    
    # 测试向量属性过滤
    var vector_props = PropertyManager.get_filtered_properties(node, PropertyManager.PropertyFilter.CUSTOM_PROPERTIES)
    for prop in vector_props:
        assert(not prop.is_internal)
```

#### 属性操作测试
```gdscript
# 测试安全属性设置
func test_safe_property_setting():
    var node = Node2D.new()
    
    # 设置有效值
    var valid_result = PropertyManager.set_property_safe(node, "position", Vector2(100, 200))
    assert(valid_result.success == true)
    assert(node.position.is_equal_approx(Vector2(100, 200)))
    
    # 设置无效值
    var invalid_result = PropertyManager.set_property_safe(node, "position", "invalid_vector")
    assert(invalid_result.success == false)
    assert("类型不兼容" in invalid_result.error)

# 测试批量属性设置
func test_batch_property_setting():
    var source_node = Node2D.new()
    var target_node = Node2D.new()
    
    # 设置源节点属性
    source_node.position = Vector2(100, 200)
    source_node.rotation = 45.0
    source_node.scale = Vector2(2, 2)
    
    # 批量复制
    var results = PropertyManager.copy_properties(source_node, target_node)
    assert(results.copied_count >= 2)  # 至少复制了一些属性
    
    # 验证复制结果
    if results.copied_count > 0:
        assert(target_node.position.is_equal_approx(source_node.position))
```

#### 缓存系统测试
```gdscript
# 测试缓存功能
func test_caching_system():
    var node = Sprite2D.new()
    
    # 第一次获取，应该解析并缓存
    var start_time = Time.get_ticks_msec()
    var props1 = PropertyManager.get_all_properties(node)
    var first_time = Time.get_ticks_msec() - start_time
    
    # 第二次获取，应该使用缓存
    start_time = Time.get_ticks_msec()
    var props2 = PropertyManager.get_all_properties(node)
    var second_time = Time.get_ticks_msec() - start_time
    
    # 缓存应该更快
    assert(second_time < first_time)
    assert(props1.size() == props2.size())
    
    # 清除缓存
    PropertyManager.clear_cache(node)
    
    # 清除后应该重新解析
    start_time = Time.get_ticks_msec()
    var props3 = PropertyManager.get_all_properties(node)
    var third_time = Time.get_ticks_msec() - start_time
    
    # 时间应该接近第一次
    assert(abs(third_time - first_time) < 10)  # 允许小误差
```

## 🎯 集成测试

### 完整工作流测试
```gdscript
# 测试完整的属性操作工作流
func test_complete_property_workflow():
    # 1. 创建测试节点
    var node = Sprite2D.new()
    
    # 2. 获取属性信息
    var position_info = PropertyManager.find_property(node, "position")
    assert(position_info != null)
    assert(position_info.is_vector())
    assert(position_info.is_writable())
    
    # 3. 验证新值
    var new_position = Vector2(150, 250)
    var validation = position_info.validate_value(new_position)
    assert(validation.valid == true)
    
    # 4. 安全设置属性
    var set_result = PropertyManager.set_property_safe(node, "position", new_position)
    assert(set_result.success == true)
    
    # 5. 验证设置结果
    assert(node.position.is_equal_approx(new_position))
    
    # 6. 测试类型转换
    var string_pos = "200,300"
    var converted_pos = TypeConverter.safe_convert_to_vector2(string_pos)
    assert(converted_pos.is_equal_approx(Vector2(200, 300)))
    
    # 7. 设置转换后的值
    var convert_result = PropertyManager.set_property_safe(node, "position", converted_pos)
    assert(convert_result.success == true)
    assert(node.position.is_equal_approx(Vector2(200, 300)))
```

## 📊 性能测试

### 大量属性测试
```gdscript
# 测试大量属性的性能
func test_performance_with_many_properties():
    var node = Node.new()
    var large_dict = {}
    
    # 创建大量属性
    for i in range(1000):
        var prop_name = "prop_" + str(i)
        large_dict[prop_name] = i
    
    # 模拟大量属性节点
    # 注意：这需要在实际场景中测试
    
    # 测试属性发现性能
    var start_time = Time.get_ticks_msec()
    var properties = PropertyManager.get_all_properties(node)
    var discovery_time = Time.get_ticks_msec() - start_time
    
    # 测试过滤性能
    start_time = Time.get_ticks_msec()
    var writable_props = PropertyManager.get_writable_properties(node)
    var filter_time = Time.get_ticks_msec() - start_time
    
    print("属性发现时间: %d ms" % discovery_time)
    print("属性过滤时间: %d ms" % filter_time)
    
    # 性能应该在合理范围内
    assert(discovery_time < 100)  # 100ms 以内
    assert(filter_time < 50)     # 50ms 以内
```

## 🔍 边界测试

### 错误输入测试
```gdscript
# 测试各种错误输入
func test_error_inputs():
    # 测试空节点
    var null_props = PropertyManager.get_all_properties(null)
    assert(null_props.is_empty())
    
    # 测试无效属性名
    var node = Node2D.new()
    var invalid_prop = PropertyManager.find_property(node, "nonexistent_property")
    assert(invalid_prop == null)
    
    # 测试无效类型转换
    var invalid_conversion = TypeConverter.safe_convert_to_vector2("not_a_vector")
    assert(invalid_conversion == Vector2.ZERO)  # 应该返回默认值
    
    # 测试极端值
    var extreme_int = TypeConverter.safe_convert_to_int(999999999)
    assert(extreme_int == 999999999)  # 应该保持原值
```

## 📋 测试执行计划

### 阶段1：基础功能测试
1. PropertyInfo 基础功能
2. TypeConverter 基础转换
3. PropertyManager 基础操作

### 阶段2：高级功能测试
1. 复杂类型转换
2. 属性过滤和搜索
3. 批量操作

### 阶段3：集成和性能测试
1. 完整工作流测试
2. 性能基准测试
3. 边界和错误测试

### 阶段4：稳定性测试
1. 内存泄漏测试
2. 长时间运行测试
3. 并发访问测试

## 🎯 预期结果

### 功能正确性
- 所有基础功能正常工作
- 类型转换准确无误
- 属性操作安全可靠

### 性能指标
- 属性发现：<10ms（缓存命中）
- 类型转换：<1ms（基础类型）
- 批量操作：<50ms（100个属性）

### 稳定性
- 无内存泄漏
- 缓存系统稳定
- 错误处理完善

这个测试计划将全面验证三个通用类的功能正确性、性能表现和稳定性，确保它们能够在实际项目中可靠使用。