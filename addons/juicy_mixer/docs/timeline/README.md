# Timeline 系统

欢迎来到 JuicyMixer Timeline 系统文档！Timeline 系统允许创建复杂的时间轴效果。

## 📚 文档目录

### 核心文档
1. [系统指南](system_guide.md) - Timeline 系统使用指南
2. [API 参考](api_reference.md) - Timeline API 完整参考

### 使用指南
3. [编辑器指南](editor_guide.md) - Timeline 编辑器使用说明
4. [最佳实践](best_practices.md) - Timeline 使用最佳实践
5. [故障排除](troubleshooting.md) - 常见问题解决方案
6. [迁移指南](migration_guide.md) - 从旧版本迁移到 Timeline

### 归档文档
- [归档文档](archive/) - 历史开发文档和计划

## 🚀 快速开始

```gdscript
# 创建 Timeline 资源
var timeline = JuicyTimelineResource.new()
timeline.auto_calculate_duration = true

# 添加轨道
var track = JuicyPropertyTrack.new()
track.target_path = NodePath(".")
track.property_name = "position"
timeline.add_track(track)

# 播放 Timeline
var context_id = JuicyMixer.play(timeline, target_node)
```

## 📖 相关文档

- [用户文档](../user_docs/) - JuicyMixer 通用文档
- [开发文档](../dev_docs/) - Timeline 开发相关文档

---

**返回**: [文档中心](../README.md)
