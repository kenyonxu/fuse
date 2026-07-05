# JuicyMixer Method Track 改进计划

**Created:** 2026-01-11
**Status:** Phase 3 - complete (60% done)
**Goal:** 为 JuicyMixer 的 Method Track 添加方法选择器和动态参数编辑器，提升用户体验

---

## 目标 (Goal)

参考 Bricks 系统的 `RunTargetNodeFunction` 实现，为 JuicyMixer 的 Method Track 添加：
1. **方法选择器** - 从目标节点反射获取可用方法列表
2. **动态参数编辑器** - 根据方法签名自动生成参数输入 UI
3. **类型验证** - 运行时检查参数类型匹配

**约束条件:**
- 不能依赖 Bricks 插件的类（`FunctionInfo`, `FunctionManager`）
- 需要创建 JuicyMixer 专属的辅助类
- 必须与现有的 Timeline 编辑器架构集成

---

## 阶段 (Phases)

### ✅ Phase 1: 需求分析与架构设计
**Status:** complete
**目标:** 理解现有架构，设计辅助类结构

**任务:**
- [x] 分析 Bricks 的实现机制
- [x] 识别可复用的设计模式
- [x] 设计 JuicyMixer 专属类结构
- [x] 定义类接口和职责

**输出:**
- ✅ 完成对 `run_target_node_function.gd` 的分析
- ✅ 创建 `findings.md` 记录关键发现
- ✅ 设计三个核心辅助类的接口
- ✅ 创建 `task_plan.md`, `findings.md`, `progress.md` 规划文件

---

### ✅ Phase 2: 创建核心辅助类
**Status:** complete
**目标:** 实现方法反射和参数管理的核心类

**任务:**
- [x] 创建 `JuicyMethodInfo.gd` - 存储单个方法信息
- [x] 创建 `JuicyMethodReflection.gd` - 反射工具类
- [x] 创建 `JuicyParameterEditor.gd` - 参数属性生成器
- [ ] 编写单元测试 (可选，暂缓)

**输出:**
- ✅ `addons/juicy_mixer/utils/juicy_method_info.gd` (340行)
- ✅ `addons/juicy_mixer/utils/juicy_method_reflection.gd` (410行)
- ✅ `addons/juicy_mixer/utils/juicy_parameter_editor.gd` (390行)
- 总代码量: ~1140 行

---

### ✅ Phase 3: 集成到 JuicyMethodTrack
**Status:** complete
**目标:** 让 Method Track 使用新的辅助类

**任务:**
- [x] 在 plugin.gd 中注册辅助类
- [x] 重构 `JuicyMethodTrack._get_property_list()`
- [x] 添加方法缓存机制 (`serialized_method_cache`)
- [x] 实现参数验证
- [x] 更新序列化逻辑

**输出:**
- ✅ 修改后的 `plugin.gd` - 辅助类已注册
- ✅ 更新后的 `juicy_method_track.gd` (+180行)
- ✅ 支持 `serialized_method_cache` 属性
- ✅ 动态生成参数属性
- ✅ 方法选择下拉菜单
- ✅ 参数默认值恢复

---

### 📋 Phase 4: 增强 Timeline 编辑器
**Status:** pending
**目标:** 改进编辑器用户体验

**任务:**
- [ ] 创建方法选择对话框
- [ ] 创建参数编辑对话框
- [ ] 添加测试执行按钮
- [ ] 改进错误提示

**输出:**
- `addons/juicy_mixer/editor/juicy_method_selector.gd`
- `addons/juicy_mixer/editor/juicy_parameter_dialog.gd`
- 更新 `juicy_timeline_editor.gd` 的编辑器 UI

---

### 📋 Phase 5: 测试与优化
**Status:** pending
**目标:** 确保功能完整和性能优化

**任务:**
- [ ] 功能测试
- [ ] 性能分析
- [ ] 文档更新
- [ ] 示例场景

**输出:**
- 测试场景 `test_method_track_enhancements.tscn`
- 性能优化报告
- 更新后的文档

---

## 关键设计决策 (Decisions)

### 决策 1: 类结构设计
**Date:** 2026-01-11
**Status:** ✅ 已确定

**选项:** 单一工具类 vs 分离关注点

**选择:** **分离关注点**

- `JuicyMethodInfo` - 数据容器（存储方法签名）
- `JuicyMethodReflection` - 反射引擎（获取节点方法）
- `JuicyParameterEditor` - UI生成器（创建属性）

**理由:**
- 符合单一职责原则
- 便于单元测试
- 可独立扩展

---

### 决策 2: 缓存策略
**Date:** 2026-01-11
**Status:** ✅ 已确定

**选项:** 实时反射 vs 缓存机制

**选择:** **缓存 + 序列化**

- 编辑器时：缓存到 `serialized_method_cache`
- 运行时：从缓存恢复，避免反射开销
- 节点变化时：自动刷新缓存

**理由:**
- 性能优化（避免重复反射）
- 离线工作（缓存持久化）
- 参考 Bricks 的成熟方案

---

### 决策 3: 属性生成方式
**Date:** 2026-01-11
**Status:** ✅ 已确定

**选项:** `_get_property_list()` vs 动态控件

**选择:** **动态属性 + 对话框结合**

- 简单参数：使用 `_get_property_list()` 生成 Inspector 属性
- 复杂参数：使用专用对话框编辑
- 方法选择：使用下拉菜单（PROPERTY_HINT_ENUM）

**理由:**
- Inspector 原生体验好
- 复杂场景需要更灵活的 UI
- 兼顾易用性和功能性

---

## 待解决问题 (Open Issues)

### 问题 1: 类型默认值创建
**描述:** 如何根据类型创建合适的默认值？

**方案:** 参考 `RunTargetNodeFunction._create_default_value_for_type()`
```gdscript
func _create_default_value_for_type(type: int) -> Variant:
    match type:
        TYPE_BOOL: return false
        TYPE_INT: return 0
        TYPE_FLOAT: return 0.0
        TYPE_STRING: return ""
        # ... 其他类型
```

**状态:** 待实现

---

### 问题 2: 线程安全问题
**描述:** 编辑器后台线程调用反射可能崩溃

**方案:**
- 仅在主线程刷新方法缓存
- 使用 `call_deferred()` 延迟节点查找
- 参考 Bricks 的 `serialized_method_cache` 机制

**状态:** 待实现

---

### 问题 3: 参数映射兼容性
**描述:** 现有的 `JuicyParameterMapping` 系统如何与新参数编辑器协同？

**方案:**
- 保持现有参数映射系统不变
- 在参数编辑器中添加"映射"选项
- 映射参数时显示特殊 UI 标识

**状态:** 待实现

---

## 错误追踪 (Errors Encountered)

| Error | Attempt | Resolution | Date |
|-------|---------|------------|------|
| 模板文件不存在 | 1 | 直接从文档创建计划文件 | 2026-01-11 |

---

## 技术债务 (Technical Debt)

| 项目 | 影响 | 优先级 | 备注 |
|------|------|--------|------|
| 无类型提示的 `args` 数组 | 高 | P0 | 用户体验差 |
| 手动输入方法名 | 高 | P0 | 容易出错 |
| 无参数验证 | 中 | P1 | 运行时错误风险 |
| 无测试执行功能 | 低 | P2 | 调试困难 |

---

## 成功标准 (Success Criteria)

### 最小可行版本 (MVP)
- [x] 方法选择下拉菜单
- [ ] 自动生成参数输入框
- [ ] 基本类型验证

### 完整版本
- [ ] 复杂类型支持（NodePath, Resource, 等）
- [ ] 参数映射 UI
- [ ] 测试执行按钮
- [ ] 错误提示和自动修复

### 优化版本
- [ ] 性能优化（缓存）
- [ ] 离线编辑支持
- [ ] 方法搜索和过滤
- [ ] 常用方法收藏

---

## 下一步行动 (Next Actions)

**立即执行:**
1. 创建 `JuicyMethodInfo.gd` 骨架
2. 实现基础的反射功能
3. 在 Method Track 中集成测试

**本周目标:**
- 完成 Phase 1 和 Phase 2
- 产出可用的方法选择器原型

---

## 参考资料 (References)

### 内部参考
- `addons/bricks/instructions/run_target_node_function.gd` - 方法反射实现
- `addons/bricks/utils/function_info.gd` - 方法信息封装
- `addons/bricks/utils/function_manager.gd` - 反射工具类
- `addons/juicy_mixer/resources/juicy_method_track.gd` - 当前实现
- `addons/juicy_mixer/editor/juicy_timeline_editor.gd` - 编辑器 UI

### 外部参考
- Godot 官方文档 - `get_method_list()` API
- Godot 官方文档 - `callv()` 动态调用
- Godot 官方文档 - `_get_property_list()` 动态属性
