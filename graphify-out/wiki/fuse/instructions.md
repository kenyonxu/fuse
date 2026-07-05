# Fuse 指令系统

## 核心类

| 类 | 社区 | 说明 |
|----|------|------|
| `BaseInstruction` | 11 | 所有指令的基类，提供 execute(), validate(), reset() 等方法 |
| `RuntimeInstructionInstance` | 43 | 运行时指令实例包装器 |
| `InstructionInstancePool` | - | 指令实例对象池 |
| `InstructionSelector` | - | 指令选择器 |

## 主要方法

- `.execute(context)` - 执行指令
- `.get_metadata()` - 获取元数据（类别、标签、图标）
- `.validate()` - 验证配置
- `.reset()` - 重置状态

## 关系

- `BaseInstruction` → uses → `ExecutionContext`
- `RuntimeInstructionInstance` → wraps → `BaseInstruction`
- `InstructionInstancePool` → manages → `RuntimeInstructionInstance`

## 社区结构

Community 11 (~95 nodes) 包含:
- BaseInstruction 基类
- FuseLocalization 本地化
- VariableOperations 变量操作
- VariableScopeUtils 作用域工具

## 查询示例

```bash
graphify explain "BaseInstruction"
graphify path "BaseInstruction" "ExecutionContext"
```