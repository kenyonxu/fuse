# JuicyMiddlewareConfig 使用指南

## 概述

`JuicyMiddlewareConfig` 是一个配置节点，允许用户在 Godot 检视器中通过拖拽脚本文件来配置中间件。它提供了类型安全的中间件配置和动态属性生成功能。

## 核心特性

- **类型安全**：直接拖拽 `.gd` 脚本文件，避免字符串错误
- **动态配置**：根据选择的中间件自动显示配置选项
- **优先级管理**：支持中间件优先级排序
- **实时预览**：编辑器中可以实时调整配置参数
- **默认配置**：自动加载中间件的默认配置值

## 使用方法

### 1. 创建配置节点

在场景中添加 `JuicyMiddlewareConfig` 节点：

```gdscript
var config_node = JuicyMiddlewareConfig.new()
add_child(config_node)
```

### 2. 配置中间件

在检视器中进行配置：

1. **添加条目**：点击 `middleware_entries` 数组的 "+" 按钮
2. **选择脚本**：拖拽中间件 `.gd` 文件到 `middleware_script` 字段
3. **设置优先级**：调整 `priority` 值（数字越小优先级越高）
4. **启用/禁用**：使用 `enabled` 复选框
5. **配置参数**：在 `config_data` 部分调整具体配置

### 3. 支持的中间件类型

任何继承自 `JuicyMiddleware` 的脚本都可以使用：

- `ChannelMiddleware` - 通道管理中间件
- `ExampleMiddleware` - 示例中间件
- `LODMiddleware` - LOD优化中间件
- 自定义中间件

### 4. 配置示例

```gdscript
# 创建配置节点
var config = JuicyMiddlewareConfig.new()
add_child(config)

# 创建配置条目
var entry = JuicyMiddlewareConfig.MiddlewareEntry.new()
entry.middleware_script = load("res://addons/juicy_mixer/middleware/channel_middleware.gd")
entry.enabled = true
entry.priority = 100
entry.config_data = {
    "enable_channel_monitoring": true,
    "max_concurrent": 3
}

# 添加到配置
config.middleware_entries.append(entry)
```

## 动态属性系统

当选择中间件脚本后，系统会自动：

1. **扫描配置模式**：读取中间件的 `_configuration_schema`
2. **生成属性**：在检视器中显示相应的配置字段
3. **加载默认值**：自动填充中间件的默认配置
4. **验证类型**：确保配置值类型正确

### 配置模式示例

中间件可以定义自己的配置模式：

```gdscript
# 在自定义中间件中
func _setup_default_configuration() -> void:
    _default_configuration = {
        "enable_effect": true,
        "intensity": 1.0,
        "max_distance": 100.0
    }
    
    set_configuration_schema({
        "enable_effect": {"type": "bool"},
        "intensity": {"type": "float", "hint": "range", "hint_string": "0.1,10.0,0.1"},
        "max_distance": {"type": "float", "hint": "range", "hint_string": "1.0,1000.0,1.0"}
    })
```

## 运行时行为

- **自动应用**：在 `_ready()` 时自动应用配置到全局中间件管道
- **优先级排序**：按优先级从小到大排序执行
- **错误处理**：配置错误时会记录错误信息，不会崩溃
- **性能监控**：支持中间件性能统计

## 编辑器使用技巧

### 拖拽脚本
- 直接从文件系统拖拽 `.gd` 文件到 `middleware_script` 字段
- 系统会自动过滤显示继承自 `JuicyMiddleware` 的脚本

### 批量配置
- 可以添加多个中间件条目
- 使用不同的优先级控制执行顺序
- 可以随时启用/禁用特定中间件

### 配置验证
- 红色边框表示配置错误
- 黄色边框表示配置警告
- 绿色边框表示配置有效

## 最佳实践

### 1. 优先级设置
```gdscript
# 高优先级中间件（先执行）
entry.priority = 50  # 如验证中间件

# 中等优先级中间件
entry.priority = 100  # 如通道管理

# 低优先级中间件（后执行）
entry.priority = 200  # 如效果处理
```

### 2. 配置组织
```gdscript
# 按功能分组配置
var channel_config = {
    "max_concurrent": 3,
    "allow_interruption": true,
    "auto_stop_previous": false
}

var effect_config = {
    "intensity": 1.5,
    "duration": 2.0,
    "fade_in_time": 0.2
}
```

### 3. 错误处理
```gdscript
# 检查配置是否成功
var stats = config_node.get_config_stats()
if stats.valid_entries == 0:
    push_error("没有有效的中间件配置")
```

## 常见问题

### Q: 为什么我的脚本不能拖拽？
A: 确保脚本继承自 `JuicyMiddleware` 基类，并且有正确的类名定义。

### Q: 配置没有生效？
A: 检查：
- 中间件是否启用 (`enabled = true`)
- 脚本是否有效且继承正确
- 是否有配置错误信息

### Q: 如何调试配置问题？
A: 使用以下方法：
```gdscript
# 获取配置统计
var stats = config_node.get_config_stats()
print("配置统计: ", stats)

# 获取具体条目信息
for entry in config_node.middleware_entries:
    var entry_stats = entry.get_config_stats()
    print("条目统计: ", entry_stats)
```

## 高级用法

### 动态配置更新
```gdscript
# 运行时更新配置
func update_middleware_config():
    # 清空现有配置
    config_node.middleware_entries.clear()
    
    # 添加新配置
    var new_entry = JuicyMiddlewareConfig.MiddlewareEntry.new()
    # ... 配置新条目
    
    # 重新应用
    config_node._apply_middleware_configs()
```

### 条件配置
```gdscript
# 根据游戏状态调整配置
if GameState.is_performance_mode():
    entry.config_data["quality_level"] = "low"
    entry.config_data["max_effects"] = 5
else:
    entry.config_data["quality_level"] = "high"
    entry.config_data["max_effects"] = 20
```

## 性能考虑

- 配置节点在 `_ready()` 时一次性应用配置
- 运行时修改配置需要手动调用 `_apply_middleware_configs()`
- 建议在游戏初始化时完成所有配置
- 避免频繁修改配置，可能影响性能

## 扩展开发

要创建自定义的可配置中间件：

1. 继承 `JuicyMiddleware`
2. 实现 `_setup_default_configuration()`
3. 定义配置模式（可选）
4. 在配置节点中使用

示例：
```gdscript
# MyCustomMiddleware.gd
extends JuicyMiddleware

func _init():
    middleware_name = "MyCustomMiddleware"
    priority = 150

func _setup_default_configuration() -> void:
    _default_configuration = {
        "custom_param": 42,
        "enable_feature": true
    }
    
    set_configuration_schema({
        "custom_param": {"type": "int"},
        "enable_feature": {"type": "bool"}
    })
```

然后在配置节点中拖拽这个脚本即可使用。