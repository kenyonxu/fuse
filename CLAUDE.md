# Project Juicy Godot - AI 开发规范

## 项目概述

基于 **Godot 4.7** 的游戏插件开发项目，包含以下核心系统：

- **Juicy Mixer** - 游戏特效系统（震动、弹簧、补间动画、时间线控制）
- **Fuse** - 可视化编程/事件系统（类似 Game Creator 的无代码脚本系统）

<CRITICAL>
	总是用中文回复
</CRITICAL>

## 与 AI 协作要点

1. **使用对应技能创建 Fuse 组件**
   - Instruction → `/fuse-instruction-generator`
   - Event → `/fuse-event-generator`
   - Condition → `/fuse-condition-generator`
2. **Godot 开发相关技能**
   - `/godot` - Godot 文件格式、架构模式、CLI 工具
   - `/godot-gdscript-patterns` - 状态机、对象池、组件系统等模式
   - `/gdscript-validate` - 编辑 GDScript 后验证代码
3. **提供上下文** - 说明修改哪个系统（JuicyMixer 或 Fuse）
4. **明确目标** - 清晰描述要实现的功能
5. **引用文件** - 提到具体文件路径或类名

## 环境配置

| 配置项 | 值 |
|--------|-----|
| Godot 版本 | 4.7 |
| Godot 路径 | `E:\Godot\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64_console.exe` |
| 主分支 | `master` |
| 开发分支 | `Develop_brick` |

## 项目结构

```
project-juicy-godot/
├── addons/
│   ├── juicy_mixer/     # 特效系统
│   ├── fuse/            # 可视化编程系统
│   └── sound_manager/   # 音频系统
├── docs/                # 项目文档
├── demos/               # 演示场景
└── plans/               # 开发计划
```

## 核心系统快速参考

### Juicy Mixer

**架构：** Resource-based, Driver-driven, Track-based, Context-managed

**关键类：**
- `JuicyFeedback` - 反馈资源（入口点）
- `JuicyTrack` - 轨道基类
- `JuicyDriver` - 驱动器基类
- `JuicyContext` - 运行时上下文

**详细文档：** [addons/juicy_mixer/docs/](addons/juicy_mixer/docs/)

### Fuse

**架构：** Event-driven, Instruction-based, Variable-container

**关键类：**
- `BaseEvent` - 事件基类
- `BaseInstruction` - 指令基类
- `BaseCondition` - 条件基类
- `ExecutionContext` - 执行上下文
- `ActionRunner` - 动作运行器

**详细文档：** [addons/fuse/docs/](addons/fuse/docs/)
**多线程支持：** [addons/fuse/docs/multithreading.md](addons/fuse/docs/multithreading.md)

## 代码规范摘要

### 命名约定

| 类型 | 规范 | 示例 |
|------|------|------|
| 文件名 | snake_case | `juicy_feedback_track.gd` |
| 类名 | PascalCase | `class_name JuicyFeedbackTrack` |
| 私有变量 | _前缀 | `var _private_var: int = 0` |
| 信号 | snake_case | `signal value_changed(new_value: float)` |

### 格式规范

- **缩进：** TAB（Godot 标准）
- **类型注解：** 必须使用
- **注释：** `##` 三重斜杠用于文档注释

### GDScript 特定规则

- 使用 **Godot 4.x / GDScript 2.0** 语法
- 不使用 `?` 代替 if-else
- 不使用 `class_name` 作为变量名（保留字）
- 使用 `@abstract` 标记抽象类和方法
- **Lambda 函数：** 简单回调可用，复杂逻辑提取方法
  - 详见：[docs/coding-standards/gdscript-lambda.md](docs/coding-standards/gdscript-lambda.md)

## 开发工作流

### 添加新功能

**JuicyMixer 新 Track/Driver:**
```gdscript
# 1. 在 resources/ 或 drivers/ 创建文件，继承基类
extends JuicyTrack

# 2. 实现必需方法
func get_track_type() -> String:
	return "MyType"

func validate_track() -> String:
	return ""  # 空字符串表示有效
```

**Fuse 新组件（必须使用对应技能）:**
```gdscript
# 1. 使用技能创建组件
# 2. 在对应目录创建文件
extends BaseInstruction  # 或 BaseEvent, BaseCondition

# 3. 实现必需方法
func execute(context: ExecutionContext) -> void:
	pass

static func get_metadata() -> Dictionary:
	return {"category": "MyCategory", "label": "My Label"}
```

### 测试规范

- **位置：** `addons/[system]/tests/`
- **命名：** `test_[feature].gd`
- **运行：** Godot headless 模式

## 重要注意事项

### 编辑器开发

⚠️ **线程安全：**
- 避免在 `_get_property_list()` 中访问节点
- 使用 `get("property")` 而非 `get_material()`
- 使用 `call_deferred()` 延迟节点操作
- 详见：[docs/development/editor-issues.md](docs/development/editor-issues.md)

### 资源管理

- **Resource 不持有节点引用** - 使用 NodePath 或字符串路径
- **元数据文件必须提交：** `.uid` 和 `.import` 文件

### 性能优化

- 使用对象池（`JuicyPoolManager`）
- 缓存节点引用和属性信息
- 使用 `@export_storage` 存储运行时数据

## 文档索引

### 开发技能

| 技能 | 用途 | 触发方式 |
|------|------|----------|
| Godot 核心 | 文件格式、架构模式、CLI | `/godot` |
| GDScript 模式 | 状态机、对象池、组件系统 | `/godot-gdscript-patterns` |
| GDScript 验证 | 编辑后验证代码 | `/gdscript-validate` |

### 内部文档

| 系统 | 路径 |
|------|------|
| Fuse 系统 | [addons/fuse/docs/](addons/fuse/docs/) |
| Fuse 多线程 | [addons/fuse/docs/multithreading.md](addons/fuse/docs/multithreading.md) |
| JuicyMixer | [addons/juicy_mixer/docs/](addons/juicy_mixer/docs/) |
| 编辑器问题 | [docs/development/editor-issues.md](docs/development/editor-issues.md) |
| Lambda 规范 | [docs/coding-standards/gdscript-lambda.md](docs/coding-standards/gdscript-lambda.md) |
| Godot API 参考 | [docs/godot/](docs/godot/) |

### 外部参考

- [Godot 官方文档](https://docs.godotengine.org/)
- [Feel 插件文档](https://feel-docs.mopopi.com/) - Unity 特效插件参考
- [Game Creator 文档](https://gamecreator.io/) - 可视化编程参考

---

**最后更新:** 2026-03-23 | **Godot 版本:** 4.7 | **开发分支:** Develop_brick

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)
