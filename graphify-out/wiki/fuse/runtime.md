# Fuse 运行时

## 核心类

| 类 | 社区 | 说明 |
|----|------|------|
| `ExecutionContext` | 4 | 执行上下文，管理变量和执行状态 |
| `ActionRunner` | 13 | 动作运行器，执行编译后的指令序列 |
| `CompiledInstructionSequence` | 13 | 编译后的指令序列 |

## ExecutionContext

**职责**: 管理运行时变量、执行状态、取消请求

**关键属性**:
- `local_variables` - 局部变量
- `execution_state` - 执行状态
- `cancel_requested` - 取消请求标志

**关键方法**:
- `execute()` - 执行
- `cancel()` - 取消执行
- `get_variable()` / `set_variable()` - 变量访问

## ActionRunner

**职责**: 管理和执行指令序列

**关键属性**:
- `instructions` - 指令列表
- `execution_mode` - 执行模式

## 社区结构

Community 4 (~136 nodes) 包含:
- ExecutionContext
- cancel_requested 信号
- execution_state_changed 信号

Community 13 (~95 nodes) 包含:
- ActionRunner
- CompiledInstructionSequenceClass
- instructions 属性

## 查询示例

```bash
graphify explain "ExecutionContext"
graphify path "ExecutionContext" "ActionRunner"
```