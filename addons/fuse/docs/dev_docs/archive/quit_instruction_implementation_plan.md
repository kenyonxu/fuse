# 退出指令实现计划

## 概述
创建一个简单的退出指令 `QuitInstruction`，用于调用 `get_tree().quit()` 来结束当前运行的应用程序。

## 指令设计

### 基本信息
- **类名**: `QuitInstruction`
- **继承**: `BaseInstruction`
- **文件路径**: `addons/fuse/instructions/quit_instruction.gd`
- **分类**: "系统"
- **功能**: 退出应用程序

### 设计原则
1. **简单性**: 无需额外参数，直接执行退出操作
2. **安全性**: 确保在适当的上下文中执行
3. **可追溯性**: 提供完整的日志记录
4. **错误处理**: 处理无法获取场景树的情况

## 实现细节

### 必须实现的抽象方法

#### 1. `_setup_metadata()`
设置指令的基本元数据：
- name: "退出应用程序"
- description: "退出当前运行的应用程序"
- category: "系统"
- version: "1.0"
- author: "Fuse System"

#### 2. `_update_resource_name()`
更新资源名称，在编辑器中显示：
- resource_name: "退出应用程序"

#### 3. `execute(context: ExecutionContext)`
实现核心退出逻辑：
1. 调用 `_start_execution(context)` 开始执行
2. 获取场景树引用
3. 验证场景树可用性
4. 记录退出日志
5. 调用 `get_tree().quit()` 
6. 标记指令完成

### 推荐实现的方法

#### 1. `get_description() -> String`
返回指令描述：
- 返回: "退出应用程序"

#### 2. `validate() -> Array[String]`
验证指令参数：
- 调用基类验证
- 返回空数组（无参数需要验证）

## 代码实现

### 完整代码结构
```gdscript
@tool
extends BaseInstruction
class_name QuitInstruction

## 退出指令
##
## 一个简单的指令，用于退出当前运行的应用程序。
## 此指令会调用 get_tree().quit() 来终止应用程序。

## 更新资源名称
func _update_resource_name():
	resource_name = "退出应用程序"

## 设置指令元数据
func _setup_metadata():
	metadata.name = "退出应用程序"
	metadata.description = "退出当前运行的应用程序"
	metadata.category = "系统"
	metadata.version = "1.0"
	metadata.author = "Fuse System"

## 执行指令
func execute(context: ExecutionContext):
	_start_execution(context)
	
	_log_debug("开始执行 QuitInstruction")
	
	# 获取场景树
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		set_error("无法获取场景树", FuseError.ErrorType.RUNTIME_ERROR, {
			"instruction_name": metadata.name,
			"instruction_category": metadata.category
		})
		finished.emit()
		return
	
	# 记录退出信息
	var exit_message = "正在退出应用程序..."
	_log_info(exit_message)
	if context:
		context.print_message(exit_message)
	
	# 执行退出操作
	scene_tree.quit()
	
	_log_debug("QuitInstruction 执行完成")
	
	# 标记指令完成
	_on_execution_completed()

## 获取指令描述
func get_description() -> String:
	return "退出应用程序"

## 验证指令参数
func validate() -> Array[String]:
	var errors = super.validate()
	# 无需额外验证，此指令没有参数
	return errors

## 统一日志方法
func _log_debug(message: String):
	FuseLogger.log_debug("QuitInstruction", log_level, message)

func _log_info(message: String):
	FuseLogger.log_info("QuitInstruction", log_level, message)

func _log_warning(message: String):
	FuseLogger.log_warning("QuitInstruction", log_level, message)

func _log_error(message: String):
	FuseLogger.log_error("QuitInstruction", log_level, message)
```

## 测试计划

### 单元测试
1. **指令初始化测试**
   - 验证元数据设置正确
   - 验证资源名称更新

2. **指令执行测试**
   - 验证场景树获取
   - 验证退出调用
   - 验证日志记录

3. **错误处理测试**
   - 测试无法获取场景树的情况
   - 验证错误设置和信号发出

### 集成测试
1. **在场景中测试**
   - 创建测试场景
   - 执行退出指令
   - 验证应用程序退出

## 安全考虑

### 1. 执行环境验证
- 确保指令在适当的上下文中执行
- 验证场景树可用性

### 2. 日志记录
- 记录所有退出操作
- 提供审计跟踪

### 3. 错误处理
- 优雅处理异常情况
- 提供有意义的错误信息

## 使用示例

### 在视觉脚本中使用
1. 从指令库中选择"退出应用程序"
2. 拖拽到事件流程中
3. 连接到适当的事件触发器

### 在代码中使用
```gdscript
# 创建退出指令
var quit_instruction = QuitInstruction.new()

# 创建执行上下文
var context = ExecutionContext.new()

# 连接完成信号
quit_instruction.finished.connect(func(): 
    print("退出指令执行完成")
)

# 执行指令
quit_instruction.execute(context)
```

## 注意事项

1. **不可逆操作**: 退出操作是不可逆的，请谨慎使用
2. **资源清理**: 确保在退出前完成必要的资源清理
3. **数据保存**: 如果需要保存数据，请在执行退出指令前完成
4. **测试环境**: 在测试环境中谨慎使用此指令

## 后续扩展

### 可能的增强功能
1. **延迟退出**: 添加延迟参数，允许设置延迟退出时间
2. **退出代码**: 支持自定义退出代码
3. **确认对话框**: 添加退出确认选项
4. **条件退出**: 基于条件决定是否退出

### 实现优先级
1. **基础功能**: 实现基本的退出功能（当前计划）
2. **错误处理**: 完善错误处理机制
3. **日志增强**: 增加更详细的日志记录
4. **扩展功能**: 根据需求添加高级功能

## 总结

这个退出指令设计遵循了 Fuse Visual Programming 系统的最佳实践，提供了简单、安全、可靠的应用程序退出功能。通过完整的错误处理和日志记录，确保了指令的可维护性和可调试性。