# CLAUDE.md 优化提案

## 执行摘要

当前 CLAUDE.md 文档约 730 行，建议精简至 ~350 行，拆分约 240 行技术细节到独立文档。

## 优化行动项

### Phase 1: 拆分技术文档 (高优先级)

- [ ] 将 "Bricks 多线程系统" 拆分到 `addons/bricks/docs/multithreading.md`
- [ ] 将 "Lambda 函数使用规范" 拆分到 `docs/coding-standards/gdscript-lambda.md`
- [ ] 将 "编辑器相关问题" 拆分到 `docs/development/editor-issues.md`

### Phase 2: 精简 CLAUDE.md (高优先级)

- [ ] 精简项目结构树
- [ ] 合并 "常见任务" 和 "开发工作流"
- [ ] 删除 Playwright CLI 章节（非核心）
- [ ] 删除冗余代码示例，保留链接
- [ ] 合并 "与 AI 协作建议" 到开头

### Phase 3: 重构权限配置 (中优先级)

- [ ] 将 Bash 命令白名单移至 `~/.claude/settings.json`
- [ ] 使用 `allowedTools` 配置而非文档说明

## 精简后的 CLAUDE.md 大纲

```markdown
# Project Juicy Godot - AI 开发规范

## 项目概述
- 一句话描述
- 核心系统列表（Juicy Mixer, Bricks, Sound Manager）
- Godot 版本：4.6
- 工作分支：Develop_brick

## 与 AI 协作要点
- 总是用中文回复
- 使用对应技能创建 Bricks 组件
- 提供上下文、明确目标、引用文件

## 核心系统快速参考
### Juicy Mixer
- 架构：Resource-based, Driver-driven, Track-based
- 关键类：JuicyFeedback, JuicyTrack, JuicyDriver, JuicyContext
- 详细文档：addons/juicy_mixer/docs/

### Bricks
- 架构：Event-driven, Instruction-based
- 关键类：BaseEvent, BaseInstruction, BaseCondition, ExecutionContext
- 详细文档：addons/bricks/docs/
- 多线程：见 addons/bricks/docs/multithreading.md

## 代码规范摘要
### 命名
- 文件：snake_case.gd
- 类名：PascalCase
- 私有变量：_underscore_prefix

### 格式
- 缩进：TAB（Godot 标准）
- 类型注解：必须使用
- 注释：## 三重斜杠用于文档

### GDScript 特定
- 使用 Godot 4.x / GDScript 2.0 语法
- 使用 @abstract 标记抽象类
- Lambda：简单回调可用，复杂逻辑提取方法
- 详见：docs/coding-standards/gdscript-lambda.md

## 开发工作流
### 创建 Bricks 组件
- Instruction → /bricks-instruction-generator
- Event → /bricks-event-generator
- Condition → /bricks-condition-generator

### 添加新功能
1. 创建文件（继承基类）
2. 实现必需方法
3. 注册到系统
4. 编写测试

### 测试
- 位置：addons/[system]/tests/
- 命名：test_[feature].gd
- 运行：Godot headless 模式

## 重要注意事项
### 编辑器开发
- ⚠️ 线程安全：避免在 _get_property_list() 中访问节点
- ⚠️ 属性访问：使用 get("property") 而非 get_material()
- 详见：docs/development/editor-issues.md

### 资源管理
- Resource 不持有节点引用
- 使用 NodePath 或字符串路径
- .uid 和 .import 文件必须提交

### 性能优化
- 使用对象池（JuicyPoolManager）
- 缓存节点引用和属性信息
- 避免频繁内存分配

## 文档索引
### 内部文档
- Bricks 系统：addons/bricks/docs/
- JuicyMixer：addons/juicy_mixer/docs/
- Godot API：docs/godot/

### 外部参考
- Godot 官方文档：https://docs.godotengine.org/
- Feel 插件：https://feel-docs.mopopi.com/
- Game Creator：https://gamecreator.io/

---
最后更新: 2026-03-16 | Godot 4.6 | 开发分支: Develop_brick
```

## 预期效果

| 指标 | 优化前 | 优化后 | 改善 |
|------|--------|--------|------|
| CLAUDE.md 行数 | ~730 | ~350 | -52% |
| 可读性 | 中 | 高 | ✅ |
| 查找效率 | 低 | 高 | ✅ |
| 维护成本 | 高 | 低 | ✅ |

## 执行建议

1. **先拆分**：创建独立技术文档，确保链接正确
2. **后精简**：更新 CLAUDE.md，删除重复内容
3. **验证**：确保所有链接有效，上下文完整
4. **迭代**：根据使用反馈继续优化
