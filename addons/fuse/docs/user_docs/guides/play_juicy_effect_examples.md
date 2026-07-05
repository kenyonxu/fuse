# PlayJuicyEffectTask 使用示例和最佳实践

## 概述

本文档提供了 `PlayJuicyEffectTask` 指令的详细使用示例和最佳实践指南，帮助开发者快速上手并充分利用该指令的功能。

## 基础使用示例

### 1. 简单效果播放

```gdscript
# 创建 PlayJuicyEffectTask 指令
var play_effect = PlayJuicyEffectTask.new()

# 设置预配置的任务配置
play_effect.task_config = preload("res://configs/screen_shake.tres")

# 设置播放器ID（可选，如果不设置会自动查找）
play_effect.player_id = "main_effects"

# 创建执行上下文
var context = ExecutionContext.new()

# 执行指令
play_effect.execute(context)

# 等待指令完成
await play_effect.finished

print("效果播放完成")
```

### 2. 在指令序列中使用

```gdscript
# 创建指令序列
var instruction_sequence = [
    CreateVariable.new(),
    PlayJuicyEffectTask.new(),
    Print.new(),
    Wait.new()
]

# 配置变量创建指令
var create_var = instruction_sequence[0] as CreateVariable
create_var.variable_name = "effect_count"
create_var.variable_type = BaseVariable.VariableType.INT
create_var.default_value = 0

# 配置 Juicy 效果指令
var play_effect = instruction_sequence[1] as PlayJuicyEffectTask
play_effect.task_config = preload("res://configs/explosion_effect.tres")
play_effect.player_id = "combat_effects"  # 使用ID指定播放器
play_effect.wait_for_completion = true
play_effect.timeout_seconds = 3.0

# 配置打印指令
var print_msg = instruction_sequence[2] as Print
print_msg.message = "效果播放完成！"

# 配置等待指令
var wait = instruction_sequence[3] as Wait
wait.wait_time = 1.0

# 执行序列
var context = ExecutionContext.new()
for instruction in instruction_sequence:
    instruction.execute(context)
    await instruction.finished
```

## 高级使用示例

### 1. 动态效果选择

```gdscript
# 根据游戏状态选择不同的效果
func play_effect_by_state(game_state: String) -> void:
    var instruction = PlayJuicyEffectTask.new()
    
    # 根据状态选择效果配置
    var config_path = match game_state:
        "victory":
            "res://configs/victory_celebration.tres"
        "defeat":
            "res://configs/defeat_screen_shake.tres"
        "level_up":
            "res://configs/level_up_effect.tres"
        _:
            "res://configs/default_effect.tres"
    
    instruction.task_config = load(config_path)
    instruction.wait_for_completion = true
    
    # 执行指令
    var context = ExecutionContext.new()
    instruction.execute(context)
    await instruction.finished
```

### 2. 与事件系统集成

```gdscript
# 在输入事件中使用
extends OnInputAction

@export var jump_effect_config: JuicyTaskConfig

func _ready():
    super._ready()
    
    # 创建 Juicy 效果指令
    var jump_effect = PlayJuicyEffectTask.new()
    jump_effect.task_config = jump_effect_config
    jump_effect.wait_for_completion = false  # 不等待，立即响应
    
    # 添加到指令序列
    instruction_sequence = [jump_effect]

# 当输入事件触发时，会自动执行指令序列
```

### 3. 批量效果播放

```gdscript
# 播放多个相关效果
func play_combo_effects() -> void:
    var effects = [
        "screen_shake.tres",
        "flash_effect.tres",
        "sound_effect.tres"
    ]
    
    var context = ExecutionContext.new()
    
    for effect_path in effects:
        var instruction = PlayJuicyEffectTask.new()
        instruction.task_config = load(effect_path)
        instruction.wait_for_completion = true
        instruction.timeout_seconds = 2.0
        
        instruction.execute(context)
        await instruction.finished
        
        print("效果播放完成: %s" % effect_path)
```

## 错误处理示例

### 1. 基本错误处理

```gdscript
func play_effect_with_error_handling() -> bool:
    var instruction = PlayJuicyEffectTask.new()
    instruction.task_config = preload("res://configs/test_effect.tres")
    instruction.wait_for_completion = true
    instruction.timeout_seconds = 5.0
    
    var context = ExecutionContext.new()
    instruction.execute(context)
    await instruction.finished
    
    # 检查执行结果
    if instruction.has_error():
        print("效果播放失败: %s" % instruction.get_error_message())
        return false
    elif instruction.is_completed():
        print("效果播放成功")
        return true
    else:
        print("效果播放状态未知")
        return false
```

### 2. 高级错误处理

```gdscript
func play_effect_with_advanced_error_handling() -> Dictionary:
    var instruction = PlayJuicyEffectTask.new()
    instruction.task_config = preload("res://configs/complex_effect.tres")
    instruction.wait_for_completion = true
    instruction.timeout_seconds = 10.0
    instruction.stop_on_failure = true
    
    # 预验证
    var validation_errors = instruction.validate()
    if not validation_errors.is_empty():
        return {
            "success": false,
            "error": "验证失败",
            "details": validation_errors
        }
    
    var context = ExecutionContext.new()
    instruction.execute(context)
    await instruction.finished
    
    # 收集执行结果
    var result = {
        "success": instruction.is_completed(),
        "error_message": instruction.get_error_message(),
        "execution_time": instruction.get_execution_time(),
        "task_id": instruction._task_id,
        "state": instruction._juicy_task_state
    }
    
    if not result.success:
        # 获取详细的 FuseError 信息
        if instruction.has_method("get_fuse_error"):
            var fuse_error = instruction.get_fuse_error()
            if fuse_error:
                result["fuse_error"] = fuse_error.get_error_details()
    
    return result
```

## 性能优化示例

### 1. 资源预加载

```gdscript
# 在游戏启动时预加载所有效果配置
class EffectManager:
    static var loaded_configs: Dictionary = {}
    
    static func preload_effects():
        var effect_paths = [
            "res://configs/jump_effect.tres",
            "res://configs/attack_effect.tres",
            "res://configs/damage_effect.tres",
            "res://configs/heal_effect.tres"
        ]
        
        for path in effect_paths:
            var config = load(path)
            if config:
                loaded_configs[path.get_file()] = config
                print("预加载效果配置: %s" % path.get_file())
    
    static func get_effect_config(name: String) -> JuicyTaskConfig:
        return loaded_configs.get(name, null)

# 使用预加载的配置
func play_preloaded_effect(effect_name: String) -> void:
    var config = EffectManager.get_effect_config(effect_name)
    if not config:
        push_error("效果配置未找到: %s" % effect_name)
        return
    
    var instruction = PlayJuicyEffectTask.new()
    instruction.task_config = config
    instruction.wait_for_completion = true
    
    var context = ExecutionContext.new()
    instruction.execute(context)
    await instruction.finished
```

### 3. 使用 Player ID 的播放器复用

```gdscript
# 创建带ID的播放器实例
func setup_player_with_id():
    var main_player = JuicyPlayerV2.new()
    main_player.player_id = "main_effects"
    add_child(main_player)
    
    var ui_player = JuicyPlayerV2.new()
    ui_player.player_id = "ui_effects"
    add_child(ui_player)

# 使用ID指定播放器
func play_main_effect():
    var instruction = PlayJuicyEffectTask.new()
    instruction.task_config = preload("res://configs/main_effect.tres")
    instruction.player_id = "main_effects"  # 使用ID指定播放器
    instruction.wait_for_completion = true
    
    var context = ExecutionContext.new()
    instruction.execute(context)
    await instruction.finished

# 使用ID指定UI播放器
func play_ui_effect():
    var instruction = PlayJuicyEffectTask.new()
    instruction.task_config = preload("res://configs/ui_effect.tres")
    instruction.player_id = "ui_effects"  # 使用ID指定UI播放器
    instruction.wait_for_completion = false  # UI效果不等待
    
    var context = ExecutionContext.new()
    instruction.execute(context)
```

### 4. 批量效果播放

```gdscript
# 在场景中设置全局 JuicyPlayerV2
extends Node

@onready var juicy_player: JuicyPlayerV2 = $JuicyPlayerV2

func _ready():
    # 将播放器注册到全局变量
    var context = ExecutionContext.new()
    context.add_variable("global_juicy_player", juicy_player, "global")

# 在指令中使用全局播放器
func play_effect_with_global_player() -> void:
    var instruction = PlayJuicyEffectTask.new()
    instruction.task_config = preload("res://configs/global_effect.tres")
    instruction.wait_for_completion = true
    
    # 指令会自动查找全局播放器
    var context = ExecutionContext.new()
    instruction.execute(context)
    await instruction.finished
```

## 调试和监控示例

### 1. 详细日志记录

```gdscript
func play_effect_with_debugging() -> void:
    var instruction = PlayJuicyEffectTask.new()
    instruction.task_config = preload("res://configs/debug_effect.tres")
    instruction.wait_for_completion = true
    instruction.timeout_seconds = 5.0
    
    # 启用详细日志
    instruction.log_level = FuseLogger.LogLevel.DEBUG
    
    var context = ExecutionContext.new()
    context.log_level = FuseLogger.LogLevel.DEBUG
    
    # 记录开始时间
    var start_time = Time.get_ticks_msec()
    
    instruction.execute(context)
    await instruction.finished
    
    # 记录执行统计
    var end_time = Time.get_ticks_msec()
    var execution_time = (end_time - start_time) / 1000.0
    
    print("效果执行统计:")
    print("  执行时间: %.2f 秒" % execution_time)
    print("  任务ID: %s" % instruction._task_id)
    print("  最终状态: %s" % instruction._juicy_task_state)
    print("  是否成功: %s" % instruction.is_completed())
    
    if instruction.has_error():
        print("  错误信息: %s" % instruction.get_error_message())
```

### 2. 性能监控

```gdscript
# 性能监控器
class EffectPerformanceMonitor:
    static var execution_history: Array[Dictionary] = []
    static var max_history_size: int = 100
    
    static func record_execution(instruction: PlayJuicyEffectTask):
        var record = {
            "timestamp": Time.get_ticks_msec(),
            "effect_name": instruction.task_config.get_effect_type_name() if instruction.task_config else "unknown",
            "execution_time": instruction.get_execution_time(),
            "success": instruction.is_completed(),
            "task_id": instruction._task_id,
            "state": instruction._juicy_task_state
        }
        
        execution_history.append(record)
        
        # 限制历史记录大小
        if execution_history.size() > max_history_size:
            execution_history.pop_front()
    
    static func get_performance_stats() -> Dictionary:
        if execution_history.is_empty():
            return {}
        
        var total_time = 0.0
        var success_count = 0
        var effect_stats = {}
        
        for record in execution_history:
            total_time += record.execution_time
            if record.success:
                success_count += 1
            
            var effect_name = record.effect_name
            if not effect_stats.has(effect_name):
                effect_stats[effect_name] = {
                    "count": 0,
                    "total_time": 0.0,
                    "success_count": 0
                }
            
            effect_stats[effect_name].count += 1
            effect_stats[effect_name].total_time += record.execution_time
            if record.success:
                effect_stats[effect_name].success_count += 1
        
        return {
            "total_executions": execution_history.size(),
            "average_execution_time": total_time / execution_history.size(),
            "success_rate": float(success_count) / execution_history.size() * 100.0,
            "effect_stats": effect_stats
        }

# 使用性能监控
func play_effect_with_monitoring() -> void:
    var instruction = PlayJuicyEffectTask.new()
    instruction.task_config = preload("res://configs/monitored_effect.tres")
    instruction.wait_for_completion = true
    
    var context = ExecutionContext.new()
    instruction.execute(context)
    await instruction.finished
    
    # 记录执行数据
    EffectPerformanceMonitor.record_execution(instruction)
    
    # 打印性能统计
    var stats = EffectPerformanceMonitor.get_performance_stats()
    print("性能统计: %s" % str(stats))
```

## 最佳实践指南

### 1. 资源管理

**推荐做法：**
- 在游戏启动时预加载常用的效果配置
- 使用资源管理器统一管理效果配置
- 为不同类型的效果创建配置模板

```gdscript
# 好的做法：预加载和缓存
class EffectConfigCache:
    static var cache: Dictionary = {}
    
    static func get_config(path: String) -> JuicyTaskConfig:
        if not cache.has(path):
            cache[path] = load(path)
        return cache[path]
```

**避免做法：**
- 在每次播放时重新加载资源
- 硬编码资源路径
- 不进行资源有效性检查

### 2. 错误处理

**推荐做法：**
- 始终检查指令执行结果
- 提供有意义的错误信息
- 实现优雅的降级方案

```gdscript
# 好的做法：完整的错误处理
func safe_play_effect(effect_path: String) -> bool:
    var config = load(effect_path)
    if not config:
        push_error("无法加载效果配置: %s" % effect_path)
        return false
    
    var instruction = PlayJuicyEffectTask.new()
    instruction.task_config = config
    instruction.wait_for_completion = true
    
    var context = ExecutionContext.new()
    instruction.execute(context)
    await instruction.finished
    
    return instruction.is_completed()
```

**避免做法：**
- 忽略错误检查
- 不提供错误上下文
- 让错误导致程序崩溃

### 3. Player ID 使用最佳实践

**推荐做法：**
- 为不同类型的效果创建专用的播放器实例
- 使用有意义的ID名称，如 `"main_effects"`、`"ui_effects"`、`"character_effects"`
- 在场景初始化时设置好播放器ID
- 使用统一的ID命名规范

```gdscript
# 好的做法：有意义的ID命名
var main_player = JuicyPlayerV2.new()
main_player.player_id = "main_effects"

var ui_player = JuicyPlayerV2.new()
ui_player.player_id = "ui_effects"

var character_player = JuicyPlayerV2.new()
character_player.player_id = "character_effects"
```

**避免做法：**
- 使用过于简单或模糊的ID，如 `"player1"`、`"effects"`
- 在运行时频繁更改播放器ID
- 使用特殊字符和空格

### 4. 性能优化

**推荐做法：**
- 合理设置超时时间
- 复用播放器实例
- 批量处理相关效果

```gdscript
# 好的做法：批量处理
func play_effect_batch(effect_paths: Array[String]) -> void:
    var context = ExecutionContext.new()
    
    for path in effect_paths:
        var instruction = PlayJuicyEffectTask.new()
        instruction.task_config = load(path)
        instruction.wait_for_completion = true
        
        instruction.execute(context)
        await instruction.finished
```

**避免做法：**
- 设置过长的超时时间
- 频繁创建和销毁播放器
- 不必要的同步等待

### 4. 调试和维护

**推荐做法：**
- 使用有意义的变量和函数名
- 添加适当的注释
- 实现日志记录功能

```gdscript
# 好的做法：清晰的代码结构
## 播放玩家跳跃效果
func play_player_jump_effect() -> void:
    var jump_config = EffectConfigCache.get_config("player_jump.tres")
    var instruction = create_effect_instruction(jump_config)
    
    var context = ExecutionContext.new()
    execute_with_logging(instruction, context)
```

**避免做法：**
- 使用模糊的命名
- 缺少注释和文档
- 忽视调试信息

## 常见问题和解决方案

### 1. 任务配置加载失败

**问题：** `task_config` 为 null 或无效
**解决方案：**
```gdscript
# 检查配置有效性
if not instruction.task_config:
    push_error("任务配置未设置")
    return

# 验证配置
var validation = instruction.task_config.validate_config()
if not validation.valid:
    push_error("任务配置无效: %s" % str(validation.issues))
    return
```

### 2. 播放器未找到

**问题：** 无法找到 `JuicyPlayerV2` 实例
**解决方案：**
```gdscript
# 方法1：使用Player ID（推荐）
# 确保播放器设置了ID
var player = JuicyPlayerV2.new()
player.player_id = "main_effects"
add_child(player)

# 在指令中使用ID
instruction.player_id = "main_effects"

# 方法2：确保播放器在场景树中（自动查找）
# 指令会自动查找场景中的第一个JuicyPlayerV2
@onready var juicy_player: JuicyPlayerV2 = $JuicyPlayerV2
```

### 3. Player ID 查找失败

**问题：** 设置了 player_id 但找不到对应的播放器
**解决方案：**
```gdscript
# 检查播放器是否正确创建和设置ID
var player = JuicyPlayerV2.find_player_by_id("your_id")
if not player:
    push_error("未找到ID为 'your_id' 的播放器")
    return

# 确保在播放器_ready()之后进行查找
# 检查ID是否包含非法字符
# 确保ID不为空字符串
```

### 3. 任务超时

**问题：** 效果播放时间过长
**解决方案：**
```gdscript
# 根据效果类型设置合理的超时时间
var timeout = match effect_type:
    "simple_effect": 2.0
    "complex_effect": 5.0
    "cinematic_effect": 15.0
    _: 3.0

instruction.timeout_seconds = timeout
```

## 总结

`PlayJuicyEffectTask` 指令提供了强大而灵活的 Juicy 效果播放功能。通过遵循这些最佳实践，开发者可以：

1. **提高开发效率**：使用预配置资源和模板快速创建效果
2. **确保稳定性**：通过完善的错误处理和验证机制
3. **优化性能**：通过资源缓存和播放器复用
4. **便于维护**：通过清晰的代码结构和调试支持

合理使用这些示例和最佳实践，将帮助您充分发挥 `PlayJuicyEffectTask` 指令的潜力，创建出色的游戏体验。

---

**文档版本：1.0**
**创建日期：2025年11月13日**
**作者：Juicy Team**

---
> 最后更新: 2026-03-19
> 注意: Juicy Effect 相关指令可能已随 JuicyMixer 系统更新而变化，建议验证实际使用效果。