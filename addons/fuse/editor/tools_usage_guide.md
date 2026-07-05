# Fuse 编辑器工具使用指南

本文档介绍如何使用 Fuse 插件的静态分析工具和调试可视化工具。

## 目录
1. [静态分析工具](#静态分析工具)
2. [调试可视化工具](#调试可视化工具)
3. [ActionRunner 调试集成](#actionrunner-调试集成)
4. [使用示例](#使用示例)
5. [最佳实践](#最佳实践)

## 静态分析工具

### 1. 指令验证器 (InstructionValidator)

指令验证器提供编程式接口进行静态分析，适用于自动化测试和构建流程。

#### 基本用法
```gdscript
# 获取指令验证器实例
var validator = InstructionValidator.new()

# 验证指令序列
var instructions = get_your_instructions()  # Array[BaseInstruction]
var results = validator.validate_instruction_sequence(instructions)

# 检查结果
if results.valid:
    print("✅ 指令序列验证通过")
else:
    print("❌ 发现 %d 个错误，%d 个警告，%d 个建议" % [
        results.errors.size(), 
        results.warnings.size(), 
        results.suggestions.size()
    ])

# 处理错误
for error in results.errors:
    print("错误: %s" % error)

# 处理警告
for warning in results.warnings:
    print("警告: %s" % warning)

# 处理建议
for suggestion in results.suggestions:
    print("建议: %s" % suggestion)
```

#### 验证结果结构
```gdscript
var results = {
    "valid": bool,           # 是否通过验证
    "errors": Array[String], # 错误信息数组
    "warnings": Array[String], # 警告信息数组
    "suggestions": Array[String] # 优化建议数组
}
```

### 2. 静态分析面板 (StaticAnalysisPanel)

静态分析面板提供图形化界面，适用于编辑器中的交互式分析。

#### 在编辑器中使用
1. **打开静态分析面板**：
   - 在 Godot 编辑器中，选择包含 ActionRunner 的节点
   - 静态分析面板会自动检测并显示当前 ActionRunner 的指令序列

2. **执行分析**：
   - 点击"分析指令序列"按钮
   - 等待分析完成（会显示进度条）

3. **查看结果**：
   - 错误：红色显示，必须修复
   - 警告：黄色显示，建议关注
   - 建议：青色显示，可选优化

4. **导出报告**：
   - 点击"导出报告"按钮
   - 报告将保存到 `user://` 目录下

#### 面板功能
- **自动刷新**：启用后可自动检测指令变化
- **清除结果**：清除当前分析结果
- **导出报告**：将分析结果保存为文本文件

## 调试可视化工具

### 1. 执行跟踪器 (ExecutionTracker)

执行跟踪器提供编程式接口记录和分析指令执行历史。

#### 基本用法
```gdscript
# 创建执行跟踪器
var tracker = ExecutionTracker.new()

# 配置跟踪选项（可选）
tracker.set_tracking_config({
    "max_history_size": 100,
    "track_performance_metrics": true,
    "track_memory_usage": false,
    "track_variable_changes": true
})

# 开始跟踪
var context = ExecutionContext.new()
tracker.start_tracking(context)

# 执行指令（在 ActionRunner 中会自动调用）
# tracker.record_instruction_start(instruction, context)
# tracker.record_instruction_complete(instruction, context)

# 记录自定义事件
tracker.record_custom_event("user_action", {"action": "button_click"})

# 记录性能瓶颈
tracker.record_performance_bottleneck("memory_usage", "high", {"usage": 500})

# 记录错误
tracker.record_error("指令执行失败", "runtime_error", {"instruction": "MoveNode"})

# 停止跟踪
tracker.stop_tracking()

# 获取执行历史
var history = tracker.get_execution_history()
for execution in history:
    print("执行耗时: %.3f 秒" % (execution.total_time / 1000.0))
    print("步骤数量: %d" % execution.steps.size())

# 获取统计信息
var stats = tracker.get_execution_stats()
print("总执行次数: %d" % stats.total_executions)
print("平均执行时间: %.3f 秒" % stats.average_time)

# 导出历史记录
var success = tracker.export_execution_history("user://execution_history.json")
if success:
    print("执行历史已导出")
```

#### 跟踪配置选项
```gdscript
var config = {
    "max_history_size": 100,          # 最大历史记录数
    "track_performance_metrics": true, # 跟踪性能指标
    "track_memory_usage": false,       # 跟踪内存使用
    "track_variable_changes": true     # 跟踪变量变化
}
```

### 2. 调试可视化面板 (DebugVisualizer)

调试可视化面板提供图形化界面显示执行历史和性能数据。

#### 在编辑器中使用
1. **打开调试可视化面板**：
   - 在 Godot 编辑器中，选择包含 ActionRunner 的节点
   - 确保 ActionRunner 已启用调试模式

2. **启用调试模式**：
   ```gdscript
   # 在代码中启用
   action_runner.enable_debug()
   
   # 检查调试状态
   if action_runner.is_debug_enabled():
       print("调试模式已启用")
   ```

3. **查看执行历史**：
   - 点击"刷新"按钮更新显示
   - 在执行树中查看历史记录
   - 点击具体执行查看详细信息

4. **分析性能数据**：
   - 查看内存使用变化
   - 分析执行时间分布
   - 识别性能瓶颈

#### 面板功能
- **执行树显示**：层次化显示执行历史和步骤
- **详细信息面板**：显示选中执行的详细数据
- **自动刷新**：定时更新显示内容
- **导出功能**：将执行历史导出为JSON文件
- **性能图表**：可视化显示性能指标（占位符）

## ActionRunner 调试集成

### 启用调试模式
```gdscript
# 创建 ActionRunner
var action_runner = ActionRunner.new()

# 启用调试模式
action_runner.enable_debug()

# 执行指令（会自动记录到执行跟踪器）
var context = ExecutionContext.new()
action_runner.run(context)

# 等待执行完成
await action_runner.execution_completed

# 获取执行跟踪器查看结果
var tracker = action_runner.get_execution_tracker()
var history = tracker.get_execution_history()

# 禁用调试模式
action_runner.disable_debug()
```

### 调试信息记录
```gdscript
# 在自定义指令中使用调试信息
func execute(context: ExecutionContext):
    # 获取 ActionRunner 的调试状态
    var action_runner = context.get_custom_data("action_runner")
    if action_runner and action_runner.is_debug_enabled():
        action_runner._log_debug_info("开始执行自定义逻辑")
    
    # 执行指令逻辑
    # ...
    
    if action_runner and action_runner.is_debug_enabled():
        action_runner._log_debug_info("自定义逻辑执行完成")
```

## 使用示例

### 示例1：完整的静态分析工作流程
```gdscript
extends Node

var action_runner: ActionRunner
var validator: InstructionValidator

func _ready():
    # 创建组件
    action_runner = ActionRunner.new()
    validator = InstructionValidator.new()
    
    # 添加一些指令
    _setup_instructions()
    
    # 执行静态分析
    _perform_static_analysis()
    
    # 如果分析通过，执行指令
    if _should_execute():
        _execute_with_debug()

func _setup_instructions():
    # 添加各种指令到 action_runner
    # 这里添加的指令可能包含潜在问题供分析
    
    var move_instruction = MoveNodeInstruction.new()
    move_instruction.target_path = "Player"
    move_instruction.new_position = Vector2(100, 200)
    action_runner.add_instruction(move_instruction)
    
    var variable_instruction = SetVariableInstruction.new()
    variable_instruction.variable_name = "score"
    variable_instruction.variable_value = 100
    action_runner.add_instruction(variable_instruction)
    
    # 可能添加一些有问题的指令用于测试
    # ...

func _perform_static_analysis():
    print("=== 执行静态分析 ===")
    
    var results = validator.validate_instruction_sequence(action_runner.instructions)
    
    if not results.valid:
        print("发现 %d 个错误，需要修复：" % results.errors.size())
        for error in results.errors:
            print("  ❌ %s" % error)
    
    if results.warnings.size() > 0:
        print("发现 %d 个警告：" % results.warnings.size())
        for warning in results.warnings:
            print("  ⚠️ %s" % warning)
    
    if results.suggestions.size() > 0:
        print("发现 %d 个优化建议：" % results.suggestions.size())
        for suggestion in results.suggestions:
            print("  💡 %s" % suggestion)
    
    return results.valid

func _should_execute() -> bool:
    # 可以添加额外的执行条件检查
    return true

func _execute_with_debug():
    print("=== 执行指令序列（启用调试）===")
    
    # 启用调试模式
    action_runner.enable_debug()
    
    # 创建执行上下文
    var context = ExecutionContext.new()
    context.target = self
    context.tree = get_tree()
    
    # 执行指令
    action_runner.run(context)
    
    # 等待执行完成
    await action_runner.execution_completed
    
    # 获取调试信息
    var tracker = action_runner.get_execution_tracker()
    if tracker:
        _display_debug_info(tracker)
    
    # 禁用调试模式
    action_runner.disable_debug()

func _display_debug_info(tracker):
    var history = tracker.get_execution_history()
    if history.size() == 0:
        print("没有执行历史")
        return
    
    var latest_execution = history[-1]
    print("最新执行信息：")
    print("  总耗时: %.3f 秒" % (latest_execution.total_time / 1000.0))
    print("  步骤数量: %d" % latest_execution.steps.size())
    
    var stats = tracker.get_execution_stats()
    if not stats.has("error"):
        print("  平均执行时间: %.3f 秒" % stats.average_time)
        print("  成功率: %.1f%%" % (100.0 - (stats.total_errors * 100.0 / stats.total_executions)))
```

### 示例2：运行时调试和性能监控
```gdscript
extends Node

var action_runner: ActionRunner
var performance_monitor: Timer

func _ready():
    # 设置性能监控
    performance_monitor = Timer.new()
    performance_monitor.wait_time = 5.0  # 每5秒检查一次
    performance_monitor.timeout.connect(_on_performance_check)
    add_child(performance_monitor)
    
    # 创建和配置 ActionRunner
    action_runner = ActionRunner.new()
    action_runner.enable_debug()  # 启用调试模式
    action_runner.enable_instruction_timeout = true
    action_runner.instruction_timeout = 10.0
    
    # 设置指令
    _setup_game_logic()
    
    # 开始性能监控
    performance_monitor.start()

func _setup_game_logic():
    # 添加游戏逻辑指令
    # 这些指令会在运行时自动被跟踪和记录
    
    var check_input = CheckInputInstruction.new()
    check_input.input_action = "ui_accept"
    action_runner.add_instruction(check_input)
    
    var update_score = SetVariableInstruction.new()
    update_score.variable_name = "player_score"
    update_score.variable_value = 10
    action_runner.add_instruction(update_score)
    
    # 更多指令...

func _on_performance_check():
    if not action_runner.is_debug_enabled():
        return
    
    var tracker = action_runner.get_execution_tracker()
    if not tracker:
        return
    
    # 获取最近的执行统计
    var stats = tracker.get_execution_stats()
    if stats.has("error"):
        return
    
    # 检查性能指标
    if stats.average_time > 0.1:  # 平均执行时间超过100ms
        print("⚠️ 性能警告: 平均执行时间较长 (%.3f秒)" % stats.average_time)
        
        # 获取详细的历史记录分析瓶颈
        var history = tracker.get_recent_executions(5)
        for execution in history:
            if execution.has("stats") and execution.stats.performance_issues > 0:
                print("  发现 %d 个性能问题" % execution.stats.performance_issues)
    
    # 检查错误率
    if stats.total_errors > 0:
        var error_rate = stats.total_errors * 100.0 / stats.total_executions
        if error_rate > 5.0:  # 错误率超过5%
            print("⚠️ 质量警告: 错误率较高 (%.1f%%)" % error_rate)

func _input(event):
    if event.is_action_pressed("ui_cancel"):
        # 手动触发调试信息导出
        _export_debug_info()

func _export_debug_info():
    if not action_runner.is_debug_enabled():
        print("调试模式未启用")
        return
    
    var tracker = action_runner.get_execution_tracker()
    if not tracker:
        return
    
    var file_path = "user://debug_info_%s.json" % Time.get_time_string_from_system().replace(":", "-")
    if tracker.export_execution_history(file_path):
        print("调试信息已导出到: %s" % file_path)
    else:
        print("导出失败")
```

## 最佳实践

### 1. 静态分析最佳实践
- **开发阶段频繁使用**：在每次修改指令序列后运行静态分析
- **修复所有错误**：静态分析发现的错误应该优先修复
- **关注警告信息**：警告可能指示潜在问题，需要评估是否需要处理
- **定期审查建议**：优化建议可以帮助提升代码质量和性能

### 2. 调试最佳实践
- **开发阶段启用调试**：在开发和测试阶段始终启用调试模式
- **生产环境禁用调试**：发布版本应该禁用调试以避免性能开销
- **定期导出调试信息**：定期导出执行历史用于分析和优化
- **监控关键指标**：关注执行时间、错误率和性能瓶颈

### 3. 性能优化建议
- **批量处理**：对于大量相似操作，考虑批量处理减少开销
- **缓存机制**：对于重复计算，考虑添加缓存机制
- **异步执行**：对于耗时操作，考虑使用异步模式
- **资源管理**：注意内存使用，及时清理不需要的对象

### 4. 错误处理策略
- **预防性检查**：使用静态分析提前发现问题
- **运行时监控**：使用调试工具监控运行时行为
- **优雅降级**：当检测到问题时，提供有意义的错误信息
- **日志记录**：充分利用日志系统记录关键信息

### 5. 团队协作
- **标准化流程**：建立使用这些工具的标准开发流程
- **代码审查**：将静态分析结果作为代码审查的一部分
- **知识分享**：定期分享调试和优化经验
- **工具改进**：根据使用反馈持续改进工具功能

## 故障排除

### 常见问题

1. **静态分析面板不显示结果**
   - 确保选择了包含 ActionRunner 的节点
   - 检查 ActionRunner 中是否有指令
   - 验证指令是否正确初始化

2. **调试可视化面板没有执行历史**
   - 确保启用了调试模式：`action_runner.enable_debug()`
   - 确认指令已经执行完成
   - 检查执行跟踪器是否正确初始化

3. **性能分析数据不准确**
   - 确保在合适的时机开始和停止跟踪
   - 考虑系统负载对性能数据的影响
   - 多次测量取平均值获得更准确结果

4. **导出功能失败**
   - 检查文件路径是否有写权限
   - 确保 `user://` 目录可访问
   - 验证数据格式是否正确

### 调试技巧

1. **逐步调试**：一次只启用一个功能，逐步验证
2. **对比分析**：对比启用和禁用工具时的性能差异
3. **日志记录**：充分利用日志系统跟踪问题
4. **最小复现**：创建最小可复现示例来定位问题

通过合理使用这些工具，可以显著提升开发效率和代码质量，减少运行时错误，并更好地理解和优化应用程序性能。