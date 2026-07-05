# Project Juicy Godot - 知识图谱

## 概览

本知识图谱包含 **20,676 个节点** 和 **32,908 条边**，来自 942 个源码和文档文件，分为 **880 个社区**。

## 核心系统

| 系统 | 说明 | 关键概念 |
|------|------|---------|
| **Fuse** | 可视化编程/事件系统 | BaseInstruction, ActionRunner, ExecutionContext |
| **JuicyMixer** | 游戏特效系统 | JuicyFeedback, JuicyTrack, JuicyDriver |

## 主要社区

| 社区 | 大小 | 主要内容 |
|------|------|---------|
| [Fuse 指令系统](fuse/instructions.md) | ~95 节点 | BaseInstruction, VariableOperations, FuseLocalization |
| [Fuse 运行时](fuse/runtime.md) | ~136 节点 | ExecutionContext, ActionRunner, CompiledInstructionSequence |
| [Fuse 条件系统](fuse/conditions.md) | ~93 节点 | BaseCondition, CheckVariable, ComparisonOperator |
| [Fuse 变量系统](fuse/variables.md) | ~98 节点 | VariableContainer, BaseVariable, GlobalVariableAssistant |
| [JuicyMixer 时间轴](juicymixer/timeline.md) | ~181 节点 | juicy_timeline_canvas, JuicyTimelineEditor, playback |
| [JuicyMixer 中间件](juicymixer/middleware.md) | ~125 节点 | JuicyMiddlewarePipeline, PipelineState |
| [JuicyMixer 轨道](juicymixer/tracks.md) | ~136 节点 | JuicyPropertyTrack, JuicyCurveFactory |

## 使用方法

```bash
# 查询某个概念
graphify explain "BaseInstruction"

# 查找两个概念之间的关系
graphify path "BaseInstruction" "ActionRunner"

# 更新图谱（代码修改后）
graphify update .
```

## 图谱统计

- **Token 消耗**: 0 (纯 AST 提取)
- **提取率**: 91% EXTRACTED, 9% INFERRED
- **更新时间**: 2026-04-19