# 自动检测信号功能使用指南

## 功能概述

自动检测信号功能允许您从场景节点快速检测信号并批量创建 AudioBinding，大幅简化音频配置流程。

## 使用方式

### 方式 1：通过 JuicyAudioPlayer（推荐）

1. 在场景中添加 JuicyAudioPlayer 作为子节点
2. 选择 JuicyAudioPlayer
3. 在 Inspector 中：
   - 方式 A：直接设置 `target` 属性为目标节点
   - 方式 B：点击"🔄 设置为父节点"按钮
4. 选择 JuicyAudioPlayer 的 `audio_component` 属性
5. 在 Inspector 底部点击"🔍 自动检测信号"
6. 在对话框中搜索并勾选要绑定的信号
7. 点击"确定"创建绑定

### 方式 2：直接使用 AudioComponent

1. 创建 AudioComponent 资源
2. 设置 `target_path` 属性为目标节点
3. 在 Inspector 中点击"🔍 自动检测信号"
4. 在对话框中搜索并勾选信号
5. 点击"确定"创建绑定

## 目标节点优先级

系统按以下优先级获取目标节点：

1. **显式 target** - JuicyAudioPlayer 的 `target` 属性
2. **target_path** - AudioComponent 的 `target_path` 属性
3. **父节点** - JuicyAudioPlayer 的父节点（向后兼容）

## 对话框功能

### 搜索过滤
- 顶部搜索框实时过滤信号
- 支持信号名称模糊搜索
- 大小写不敏感

### 树形结构
- 按 class 分组显示信号
- 显示信号参数类型（例如：`jump (velocity: float)`）
- 默认全部展开
- 按字母顺序排序

### 多选
- 勾选要创建绑定的信号
- 确认按钮显示勾选数量
- 支持全选/全不选（手动勾选）

## 行为说明

### 自动过滤
- 内置信号（如 `ready`, `tree_entered`）会被自动过滤
- 以 `_` 开头的内部信号会被过滤
- 已存在的绑定会被跳过

### 创建结果
- 每个勾选的信号创建一个 AudioBinding
- 自动创建占位符 AudioEventResource
- 使用信号名称作为 event_name
- 需要后续手动分配实际的音频资源

## 常见问题

**Q: 为什么检测不到信号？**
A: 请确保：
- 目标节点已设置（target 或 target_path）
- 节点脚本中定义了自定义 signal
- 信号不是内置信号（会被过滤）

**Q: 如何批量修改音频事件？**
A:
1. 使用自动检测创建绑定
2. 在 Inspector 中逐个编辑 AudioBinding
3. 为每个绑定的 audio_event 分配实际的音频资源

**Q: target 和 target_path 有什么区别？**
A:
- `target` - Node 引用，运行时使用，不可序列化
- `target_path` - NodePath，可序列化到资源
- 系统会自动同步两者

## 示例

```gdscript
# 玩家脚本
extends CharacterBody2D

signal jump
signal footstep
signal hurt(damage: int)
signal died

func jump():
    jump.emit()

func _on_footstep():
    footstep.emit()
```

配置流程：
1. 添加 JuicyAudioPlayer 作为玩家子节点
2. 点击"🔄 设置为父节点"
3. 在 audio_component 中点击"🔍 自动检测信号"
4. 勾选 `jump`, `footstep`, `hurt`
5. 点击"确定"
6. 为每个绑定分配对应的音频事件资源

## 技术细节

### 支持的参数类型

自动检测支持以下参数类型的显示：
- 基本类型：bool, int, float, String
- 向量类型：Vector2, Vector2i, Vector3, Vector3i
- 其他：Color, Array, Dictionary, Object, Callable

### 过滤的内置信号

以下信号会被自动过滤：
- Node 生命周期：tree_entered, tree_exited, ready 等
- 属性变化：script_changed, size_changed 等
- 子节点管理：child_entered_tree, child_exiting_tree 等

### 性能考虑

- 信号检测使用 Godot 的 `get_signal_list()` API，性能良好
- 搜索过滤在内存中完成，响应迅速
- 批量创建绑定时会检查重复，避免数据冗余
