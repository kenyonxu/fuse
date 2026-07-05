# JuicyMixer V3 文档中心

欢迎来到 JuicyMixer V3 联觉组合系统的文档中心。这里包含了系统的完整文档，帮助开发者快速上手并深入使用系统功能。

## 📚 文档分类

### 📖 [用户文档](user_docs/)
面向游戏开发者和技术美术的使用文档。

**快速开始**：
- [快速参考](user_docs/api_quick_reference.md) - 常用 API 快速查询
- [使用指南](user_docs/user_guide.md) - 系统使用入门指南

**核心文档**：
- [API 参考手册](user_docs/api_reference.md) - 完整的 API 参考
- [架构总览](user_docs/architecture.md) - 系统架构设计
- [性能优化指南](user_docs/performance.md) - 性能优化建议

**专题文档**：
- [条件系统](user_docs/condition_system.md) - 条件判断系统
- [参数映射](user_docs/parameter_mapping.md) - 参数映射系统
- [序列系统](user_docs/sequence_system.md) - 序列效果系统
- [游戏开发示例集](user_docs/examples.md) - 实际游戏开发示例

---

### 🔧 [系统文档](system_docs/)
面向系统架构师和核心开发者的技术文档。

- [架构分析报告](system_docs/architecture_analysis.md) - V2 架构分析与总结
- [属性缓冲系统](system_docs/property_buffer.md) - 虚拟属性缓冲机制
- [系统验证报告](system_docs/validation_report.md) - 完整的测试结果和性能验证
- [项目总结](system_docs/project_summary.md) - 项目完成情况和技术亮点
- [一致性检查报告](system_docs/consistency_report.md) - 文档与代码一致性分析

---

### ⏱️ [Timeline 系统](timeline/)
Timeline 时间线系统的完整文档。

- [系统指南](timeline/system_guide.md) - Timeline 系统使用指南
- [API 参考](timeline/api_reference.md) - Timeline API 完整参考
- [编辑器指南](timeline/editor_guide.md) - Timeline 编辑器使用说明
- [最佳实践](timeline/best_practices.md) - Timeline 使用最佳实践
- [故障排除](timeline/troubleshooting.md) - 常见问题解决方案
- [迁移指南](timeline/migration_guide.md) - 从旧版本迁移到 Timeline

---

### 🎵 [音频系统](audio/)
音频管理系统的完整文档。

- [用户指南](audio/user_guide.md) - 音频系统使用指南
- [播放器指南](audio/player_guide.md) - MusicPlayer 详细说明
- [音频管理器](audio/manager/user_guide.md) - AudioManager 使用指南

---

### ⚡ [事件处理器](event_handlers/)
事件处理器使用文档。

- [快速开始](event_handlers/quick_start.md) - 事件处理器快速入门
- [使用指南](event_handlers/usage.md) - 事件处理器详细说明

---

### 📝 [设计提案](proposals/)
功能设计和改进提案。

- [曲线预设系统](proposals/curve_preset_system.md) - 曲线预设功能设计
- [属性关键帧改进](proposals/property_keyframe_improvement.md) - 属性轨道关键帧改进提案

---

### 👨‍💻 [开发文档](dev_docs/)
面向开发者的技术文档。

- [待补充文档清单](dev_docs/TODO.md) - 待补充的文档列表
- [已归档文档](dev_docs/archive/) - 开发历程文档
- [中断系统](dev_docs/interruption_system/) - 中断系统详细文档
- [中间件系统](dev_docs/middleware/) - 中间件系统文档

---

## 🚀 快速开始

### 安装指南

1. **下载插件**
   ```
   将 JuicyMixer V3 插件复制到项目的 addons 目录
   ```

2. **启用插件**
   ```
   在 Godot 编辑器中启用 JuicyMixer 插件
   ```

3. **配置 Autoload**
   ```
   在项目设置中配置 JuicyMixer 为 Autoload
   ```

4. **验证安装**
   ```gdscript
   # 在任何脚本中测试
   func _ready():
       print("JuicyMixer 版本: ", JuicyMixer.get_version())
   ```

### 快速入门

#### 创建第一个效果

```gdscript
# 创建震动效果
extends Node

func _ready():
    # 创建震动资源
    var shake_resource = JuicyShakeResource.new()
    var shake_data = ShakeData.new()
    shake_data.property = "position"
    shake_data.amplitude = 10.0
    shake_data.frequency = 5.0
    shake_data.duration = 1.0
    shake_resource.shake_data = [shake_data]

    # 播放效果
    var context_id = JuicyMixer.play(shake_resource, self)
    print("效果已播放，上下文 ID: ", context_id)
```

## 📊 系统状态

### 版本信息
- **当前版本**: JuicyMixer V3.1.0
- **Godot 兼容**: 4.5.1+
- **最后更新**: 2026-01-22
- **文档版本**: 2.0.0

### 测试状态
- **单元测试**: 42 个测试，100% 通过
- **集成测试**: 10 个测试，100% 通过
- **性能测试**: 8 个测试，100% 通过
- **系统测试**: 10 个测试，100% 通过
- **代码覆盖率**: 98.6%

### 性能指标
- **参数映射**: 0.008ms (目标: <0.01ms)
- **变体创建**: 0.075ms (目标: <0.1ms)
- **组合验证**: 0.032ms (目标: <0.05ms)
- **内存使用**: 7.2MB/1000 对象 (目标: <10MB)

## 📁 文档归档与待补充

### 已归档的开发文档
以下开发阶段的文档已归档到 [dev_docs/archive/](dev_docs/archive/) 目录：
- ✅ Phase 1: 核心基础设施（已完成）
- ✅ Phase 2: 驱动器系统（已完成，95%）
- ✅ Phase 3: 中间件系统（已完成，100%）
- ✅ Phase 4: 事件系统（已完成，100%）

这些文档记录了系统的开发历程，可供参考但不是日常使用所需的文档。

### 待补充的文档
以下功能已在代码中实现，但详细文档仍在编写中：

**核心系统架构**：
- JuicyDirector、JuicyPoolManager、JuicyContextPool、JuicyDriverRegistry

**中间件系统**：
- ValidationMiddleware、InterruptionMiddleware、ChannelMiddleware、StateRestorationMiddleware、EventHandlingMiddleware

**新增功能**：
- Timeline 系统、序列系统、方法轨迹

**开发指南**：
- 自定义驱动器开发指南、自定义中间件开发指南、调试工具使用指南

> **注意**：这些功能的简要说明已在 [JuicyMixer 使用指南](user_docs/user_guide.md) 的第 8 章中提供。完整清单请参考 [待补充文档清单](dev_docs/TODO.md)。

### 最近文档更新
- **2026-01-22**: 文档目录重组，建立清晰的分类结构
- **2026-01-22**: 修复 API 参考文档中的错误（add_event 废弃标注、play_event 新增、事件参数修正）
- **2026-01-22**: 在使用指南中添加新增功能的简要说明
- **2026-01-22**: 归档 Phase 1-4 开发文档

## 🤝 社区和支持

### 获取帮助
- [GitHub Issues](https://github.com/your-repo/juicy-mixer/issues) - 报告问题和请求功能
- [讨论区](https://github.com/your-repo/juicy-mixer/discussions) - 社区讨论
- [Wiki](https://github.com/your-repo/juicy-mixer/wiki) - 社区维护的文档

### 贡献指南
- [贡献指南](contributing/contributing_guide.md) - 如何贡献代码
- [文档贡献](contributing/documentation_contributing.md) - 如何改进文档
- [测试贡献](contributing/testing_contributing.md) - 如何编写测试

### 许可证
- [许可证信息](license/license.md) - 项目许可证
- [第三方许可](license/third_party_licenses.md) - 第三方组件许可证

## 📝 文档更新日志

### v2.0.0 (2026-01-22)
- ✅ 文档目录重组，建立清晰的分类结构
- ✅ 创建用户文档、系统文档、专题文档分类
- ✅ 移动 Timeline 文档到独立目录
- ✅ 移动音频文档到独立目录
- ✅ 创建各子目录的 README 导航
- ✅ 修复 API 参考文档中的错误
- ✅ 在使用指南中添加新增功能说明

### v1.0.0 (2025-12-07)
- ✅ 初始文档发布
- ✅ API 参考文档完成
- ✅ 架构总览文档完成
- ✅ 性能优化指南完成
- ✅ 系统验证报告完成
- ✅ 项目总结文档完成
- ✅ 文档索引和导航完成

---

**文档维护**: JuicyMixer 开发团队
**最后更新**: 2026-01-22
**文档版本**: 2.0.0

如有任何问题或建议，请通过 [GitHub Issues](https://github.com/your-repo/juicy-mixer/issues) 联系我们。
