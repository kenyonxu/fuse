# JuicyMixer 中间件系统

## 核心类

| 类 | 社区 | 说明 |
|----|------|------|
| `JuicyMiddlewarePipeline` | 5 | 中间件管道 |
| `PipelineState` | 5 | 管道状态枚举 |

## PipelineState 枚举

| 值 | 说明 |
|----|------|
| `IDLE` | 空闲状态 |
| `BUILDING` | 构建中 |
| `RUNNING` | 运行中 |
| `PAUSED` | 暂停 |

## 中间件类型

| 类型 | 说明 |
|------|------|
| `ValidationMiddleware` | 验证中间件 |
| `InterruptionMiddleware` | 中断中间件 |
| `ChannelMiddleware` | 通道中间件 |
| `StateRestorationMiddleware` | 状态恢复中间件 |
| `EventHandlingMiddleware` | 事件处理中间件 |

## 架构模式

中间件管道采用 **Chain of Responsibility** 模式:
1. 每个中间件处理特定职责
2. 按顺序链接形成管道
3. 可动态添加/移除中间件

## 社区结构

Community 5 (~125 nodes) 包含:
- JuicyMiddlewarePipeline
- PipelineState (IDLE, BUILDING)
- 各种中间件实现

## 查询示例

```bash
graphify explain "JuicyMiddlewarePipeline"
graphify explain "ValidationMiddleware"
```