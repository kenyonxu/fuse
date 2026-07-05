# 目标高亮系统使用文档

## 概述

目标高亮系统在 Timeline Editor 中选择轨道时，通过多种视觉方式标识目标节点，帮助用户直观地看到轨道控制哪个场景节点。

**支持的高亮位置：**
- **2D场景编辑器** - 在场景视口中显示彩色矩形框
- **场景树面板** - 在Scene Tree中显示彩色背景

## 功能特性

### 1. 自动高亮
- 在 Timeline Editor 中选择轨道时自动显示
- 取消选择时自动清除
- 无需手动操作

### 2. 多轨道支持
- 支持同时选择多个轨道（Ctrl+Click）
- 每个轨道使用不同的颜色
- 独立管理每个轨道的标记

### 3. 智能清理
- 节点被删除时自动清理标记
- 场景切换时自动清理
- Timeline 资源切换时清理所有高亮
- 避免内存泄漏

### 4. 双重视觉反馈
- 2D场景中的矩形框标记
- 场景树中的背景色标记
- 使用相同的轨道颜色保持一致性

## 视觉反馈

### 2D场景标记
- **外观**：半透明实心矩形（30%透明度）+ 3px宽边框
- **颜色**：使用轨道的 track_color
- **位置**：覆盖目标节点的边界
- **变换**：正确处理视口缩放和平移

### 场景树标记
- **外观**：30%透明度的背景色
- **颜色**：使用轨道的 track_color
- **位置**：目标节点的场景树项
- **更新**：每帧自动更新

### 多轨道示例
```
轨道1（红色）→ 2D场景显示红色矩形框 + 场景树显示红色背景
轨道2（蓝色）→ 2D场景显示蓝色矩形框 + 场景树显示蓝色背景
轨道3（绿色）→ 2D场景显示绿色矩形框 + 场景树显示绿色背景
```

## 技术实现

### 2D场景高亮
- **EditorPlugin**: 使用 `forward_canvas_draw_over_viewport()` 绘制
- **坐标转换**: 使用 `get_viewport_transform()` 转换世界坐标到视口坐标
- **边界缓存**: 缓存节点全局边界，避免每帧计算
- **视口裁剪**: 只绘制可见区域内的标记

### 场景树高亮
- **反射访问**: 通过反射获取 SceneTree Tree 控件
- **节点元数据**: 使用 `set_meta("timeline_track_highlight", color)` 存储颜色
- **每帧更新**: 在 `_process()` 中遍历场景树项并更新背景色
- **自动清理**: 清除高亮时移除节点元数据

### 核心组件
- **TargetHighlightManager**: 单例模式管理高亮列表
  - `add_highlight()` - 添加高亮并设置节点元数据
  - `remove_highlights_for_track()` - 移除高亮并清除元数据
  - `clear_all()` - 清除所有高亮和元数据
  - `cleanup_invalid_highlights()` - 清理无效节点的高亮

- **Plugin.gd**: 绘制场景叠加层和场景树高亮
  - `_forward_canvas_draw_over_viewport()` - 绘制2D场景矩形框
  - `_setup_scenetree_highlight()` - 初始化场景树控件
  - `_process_scenetree_highlights()` - 每帧更新场景树背景色

## 实现阶段

### Phase 1 - 2D场景高亮
- 在2D视口中绘制彩色矩形框
- 支持视口变换（缩放/平移）
- 多轨道同时高亮

### Phase 2 - 自动清理
- 轨道取消选择时清除对应高亮
- Timeline 切换时清理所有高亮
- 防止高亮累积

### Phase 3 - 场景树高亮
- 在 Scene Tree 中显示彩色背景
- 使用节点元数据存储颜色信息
- 与2D场景高亮颜色一致

## 相关文件

- `addons/juicy_mixer/editor/target_highlight_manager.gd` - 高亮管理器
- `addons/juicy_mixer/plugin.gd` - 插件绘制层和场景树高亮
- `addons/juicy_mixer/editor/juicy_timeline_editor.gd` - 集成点
- `docs/juicy_mixer/target-highlight-system.md` - 本文档
