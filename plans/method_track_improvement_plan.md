# JuicyMixer Method Track 改进计划

## 目标
参考 Bricks 系统的 `RunTargetNodeFunction` 实现，为 JuicyMixer 的 Method Track 添加：
1. **方法选择器** - 从目标节点反射获取可用方法列表
2. **动态参数编辑器** - 根据方法签名自动生成参数输入 UI
3. **类型验证** - 运行时检查参数类型匹配

## 约束条件
- 不能依赖 Bricks 插件的类（`FunctionInfo`, `FunctionManager`）
- 需要创建 JuicyMixer 专属的辅助类
- 必须与现有的 Timeline 编辑器架构集成

---

## 阶段划分

### ✅ Phase 1: 需求分析与架构设计
**状态**: in_progress
**目标**: 理解现有架构，设计辅助类结构

**任务**:
- [x] 分析 Bricks 的实现机制
- [ ] 识别可复用的设计模式
- [ ] 设计 JuicyMixer 专属类结构
- [ ] 定义类接口和职责

---

### 📋 Phase 2: 创建核心辅助类
**状态**: pending
**目标**: 实现方法反射和参数管理的核心类

**任务**:
- [ ] 创建 `JuicyMethodInfo.gd` - 存储单个方法信息
- [ ] 创建 `JuicyMethodReflection.gd` - 反射工具类
- [ ] 创建 `JuicyParameterEditor.gd` - 参数属性生成器
- [ ] 编写单元测试

---

### 📋 Phase 3: 集成到 JuicyMethodTrack
**状态**: pending
**目标**: 让 Method Track 使用新的辅助类

**任务**:
- [ ] 重构 `JuicyMethodTrack._get_property_list()`
- [ ] 添加方法缓存机制
- [ ] 实现参数验证
- [ ] 更新序列化逻辑

---

### 📋 Phase 4: 增强 Timeline 编辑器
**状态**: pending
**目标**: 改进编辑器用户体验

**任务**:
- [ ] 创建方法选择对话框
- [ ] 创建参数编辑对话框
- [ ] 添加测试执行按钮
- [ ] 改进错误提示

---

### 📋 Phase 5: 测试与优化
**状态**: pending
**目标**: 确保功能完整和性能优化

**任务**:
- [ ] 功能测试
- [ ] 性能分析
- [ ] 文档更新
- [ ] 示例场景

---

## 关键设计决策

### 决策 1: 类结构设计
**选项**: 单一工具类 vs 分离关注点

**选择**: **分离关注点**
- `JuicyMethodInfo` - 数据容器（存储方法签名）
- `JuicyMethodReflection` - 反射引擎（获取节点方法）
- `JuicyParameterEditor` - UI生成器（创建属性）

**理由**:
- 符合单一职责原则
- 便于单元测试
- 可独立扩展

---

### 决策 2: 缓存策略
**选项**: 实时反射 vs 缓存机制

**选择**: **缓存 + 序列化**
- 编辑器时：缓存到 `serialized_method_cache`
- 运行时：从缓存恢复，避免反射开销
- 节点变化时：自动刷新缓存

**理由**:
- 性能优化（避免重复反射）
- 离线工作（缓存持久化）
- 参考 Bricks 的成熟方案

---

### 决策 3: 属性生成方式
**选项**: `_get_property_list()` vs 动态控件

**选择**: **动态属性 + 对话框结合**
- 简单参数：使用 `_get_property_list()` 生成 Inspector 属性
- 复杂参数：使用专用对话框编辑
- 方法选择：使用下拉菜单（PROPERTY_HINT_ENUM）

**理由**:
- Inspector 原生体验好
- 复杂场景需要更灵活的 UI
- 兼顾易用性和功能性

---

## 待解决问题

### 问题 1: 类型默认值创建
**描述**: 如何根据类型创建合适的默认值？

**方案**: 参考 `RunTargetNodeFunction._create_default_value_for_type()`
```gdscript
func _create_default_value_for_type(type: int) -> Variant:
    match type:
        TYPE_BOOL: return false
        TYPE_INT: return 0
        TYPE_FLOAT: return 0.0
        TYPE_STRING: return ""
        # ... 其他类型
```

---

### 问题 2: 线程安全问题
**描述**: 编辑器后台线程调用反射可能崩溃

**方案**:
- 仅在主线程刷新方法缓存
- 使用 `call_deferred()` 延迟节点查找
- 参考 Bricks 的 `serialized_method_cache` 机制

---

### 问题 3: 参数映射兼容性
**描述**: 现有的 `JuicyParameterMapping` 系统如何与新参数编辑器协同？

**方案**:
- 保持现有参数映射系统不变
- 在参数编辑器中添加"映射"选项
- 映射参数时显示特殊 UI 标识

---

## 技术债务追踪

| 项目 | 影响 | 优先级 | 备注 |
|------|------|--------|------|
| 无类型提示的 `args` 数组 | 高 | P0 | 用户体验差 |
| 手动输入方法名 | 高 | P0 | 容易出错 |
| 无参数验证 | 中 | P1 | 运行时错误风险 |
| 无测试执行功能 | 低 | P2 | 调试困难 |

---

## 成功标准

### 最小可行版本 (MVP)
- ✅ 方法选择下拉菜单
- ✅ 自动生成参数输入框
- ✅ 基本类型验证

### 完整版本
- ✅ 复杂类型支持（NodePath, Resource, 等）
- ✅ 参数映射 UI
- ✅ 测试执行按钮
- ✅ 错误提示和自动修复

### 优化版本
- ✅ 性能优化（缓存）
- ✅ 离线编辑支持
- ✅ 方法搜索和过滤
- ✅ 常用方法收藏

---

## 参考资料

### 内部参考
- `addons/bricks/instructions/run_target_node_function.gd` - 方法反射实现
- `addons/bricks/utils/function_info.gd` - 方法信息封装
- `addons/bricks/utils/function_manager.gd` - 反射工具类

### 外部参考
- Godot 官方文档 - `get_method_list()` API
- Godot 官方文档 - `callv()` 动态调用
- Godot 官方文档 - `_get_property_list()` 动态属性

---

## 下一步行动

**立即执行**:
1. 创建 `JuicyMethodInfo.gd` 骨架
2. 实现基础的反射功能
3. 在 Method Track 中集成测试

**本周目标**:
- 完成 Phase 1 和 Phase 2
- 产出可用的方法选择器原型
