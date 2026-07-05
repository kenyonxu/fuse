# Event RuntimeInstance 迁移检查清单

> **用途**: 帮助开发者判断是否需要迁移，以及如何正确迁移到 RuntimeInstance 架构

**适用对象**: Fuse Event 开发者、维护者

**最后更新**: 2026-02-03

---

## 📋 目录

1. [迁移决策检查清单](#迁移决策检查清单)
2. [迁移实施检查清单](#迁移实施检查清单)
3. [测试验证检查清单](#测试验证检查清单)
4. [文档更新检查清单](#文档更新检查清单)
5. [快速参考](#快速参考)

---

## 迁移决策检查清单

使用此清单判断 Event 是否需要迁移到 RuntimeInstance 架构。

### A. 评估 Event 状态

**A1. 检查是否有运行时状态变量**

查看 Event 类定义，是否有以下类型的成员变量：

- [ ] 触发状态标志（`_has_triggered`, `_is_hovered`, `_has_exited` 等）
- [ ] 计数器（`_trigger_count`, `_execution_count` 等）
- [ ] 时间戳（`_last_trigger_time`, `_last_execution_time` 等）
- [ ] 运行时对象引用（`_timer`, `_tween` 等）
- [ ] 其他运行时状态

**结果**:
- ✅ **有任何状态变量** → 进入 A2
- ❌ **无状态变量** → **不需要迁移**（Event 是无状态的）

---

**A2. 检查状态使用方式**

查看 Event 是否在代码中使用这些状态：

```gdscript
# 状态判断
if _has_triggered:
    return

# 状态修改
_has_triggered = true
_trigger_count += 1

# 状态重置
func reset():
    _has_triggered = false
```

- [ ] 在条件判断中使用状态
- [ ] 在事件处理中修改状态
- [ ] 在 `reset()` 中重置状态
- [ ] 在 `terminate()` 中清理状态

**结果**:
- ✅ **状态被使用** → 进入 A3
- ❌ **状态未被使用** → **可能不需要迁移**（考虑删除冗余状态）

---

**A3. 评估共享风险**

考虑此 Event 是否可能被多个 Trigger 共享：

- [ ] **常用 Event**（如 OnMouseEnter, OnInterval）
- [ ] **通用 Event**（适用于多种场景）
- [ ] **已有复用案例**（项目中已发现多个 Trigger 使用同一 Event 资源）
- [ ] **预期会被复用**（用户很可能复用此 Event）

**结果**:
- ✅ **高共享风险** → **强烈建议迁移**
- ⚠️ **中共享风险** → **建议迁移**
- ❌ **低共享风险** → **可选迁移**

---

### B. 决策矩阵

根据以上评估，使用决策矩阵确定是否迁移：

| 状态变量 | 共享风险 | 是否迁移 | 优先级 |
|---------|---------|---------|--------|
| ✅ 有状态 | ✅ 高 | **是** | 🔴 高 |
| ✅ 有状态 | ⚠️ 中 | **建议** | 🟡 中 |
| ✅ 有状态 | ❌ 低 | 可选 | 🟢 低 |
| ❌ 无状态 | 任何 | **否** | - |

---

### C. 特殊情况

**C1. 已知问题的 Event**
- [ ] 有用户报告状态共享问题
- [ ] 在测试中发现状态冲突
- [ ] 代码审查识别出潜在问题

**处理**: 立即迁移

---

**C2. 新开发的 Event**
- [ ] 正在开发中的 Event
- [ ] 有运行时状态
- [ ] 可能被多个 Trigger 使用

**处理**: 直接使用 RuntimeInstance 架构开发

---

**C3. 无状态 Event**
- [ ] 纯监听，无状态判断
- [ ] 直接触发信号
- [ ] 不存储任何运行时信息

**处理**: 不需要迁移

---

## 迁移实施检查清单

如果决定迁移，按以下步骤操作。

### Step 1: 准备阶段

**1.1 备份当前代码**
- [ ] 创建 Git 分支（`git checkout -b feature/migrate-xxx-to-runtime-instance`）
- [ ] 提交当前所有更改
- [ ] 确认代码可以正常工作

**1.2 分析当前状态**
- [ ] 列出所有运行时状态变量
- [ ] 记录状态使用位置（搜索 `_<状态名>`）
- [ ] 识别状态初始化位置
- [ ] 识别状态清理位置

**1.3 准备测试**
- [ ] 确认有测试场景
- [ ] 确认测试能通过
- [ ] 记录当前测试结果作为基线

---

### Step 2: 删除状态变量

**2.1 删除成员变量**
```gdscript
# ❌ 删除这些
var _has_triggered: bool = false
var _trigger_count: int = 0
var _last_trigger_time: float = 0.0
```

- [ ] 删除所有运行时状态变量
- [ ] 保留配置变量（`@export` 变量）
- [ ] 保留节点引用（如 `_signal_connections`）
- [ ] 保留临时变量（方法内局部变量）

**2.2 添加 RuntimeEventInstance 引用**
```gdscript
# ✅ 添加这个
var _runtime_instance_ref: RuntimeEventInstance = null
```

- [ ] 添加 `_runtime_instance_ref` 变量
- [ ] 确认类型为 `RuntimeEventInstance`

---

### Step 3: 实现 initialize_with_runtime_instance()

**3.1 创建方法签名**
```gdscript
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void:
```

- [ ] 方法签名正确
- [ ] 返回类型为 `void`

**3.2 添加编辑器检查**
```gdscript
if Engine.is_editor_hint():
    return
```

- [ ] 添加编辑器模式检查

**3.3 保存 RuntimeEventInstance 引用**
```gdscript
_runtime_instance_ref = runtime_instance
```

- [ ] 保存引用到 `_runtime_instance_ref`

**3.4 验证参数**
- [ ] 验证 `owner_node` 非空
- [ ] 验证目标节点（如果有）
- [ ] 创建适当的错误消息

**3.5 连接信号**
- [ ] 连接所有需要的信号
- [ ] 避免重复连接（使用 `is_connected()` 检查）

**3.6 记录日志**
- [ ] 记录初始化成功日志
- [ ] 使用本地化日志方法

---

### Step 4: 修改状态访问

**4.1 读取状态**
```gdscript
# ❌ 旧方式
if _has_triggered:
    return

# ✅ 新方式
var has_triggered: bool = false
if _runtime_instance_ref and _runtime_instance_ref.has_runtime_state("has_triggered"):
    has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered")

if has_triggered:
    return
```

对每个状态变量：
- [ ] 添加默认值变量
- [ ] 检查状态是否存在
- [ ] 从 RuntimeEventInstance 读取状态

**4.2 写入状态**
```gdscript
# ❌ 旧方式
_has_triggered = true

# ✅ 新方式
if _runtime_instance_ref:
    _runtime_instance_ref.set_runtime_state("has_triggered", true)
```

对每个状态变量：
- [ ] 检查 `_runtime_instance_ref` 非空
- [ ] 使用 `set_runtime_state()` 写入状态
- [ ] 更新复合状态（如计数器）

**4.3 状态命名映射**
确保状态键名称清晰：

| 原变量名 | 状态键名 |
|---------|---------|
| `_has_triggered` | `"has_triggered"` |
| `_is_hovered` | `"is_hovered"` |
| `_trigger_count` | `"trigger_count"` |

- [ ] 所有状态键名一致
- [ ] 使用 snake_case 命名

---

### Step 5: 在 RuntimeEventInstance 中初始化状态

**5.1 找到初始化方法**

打开 `addons/fuse/core/runtime_event_instance.gd`，找到 `_initialize_runtime_state()` 方法。

**5.2 添加事件类型分支**
```gdscript
match event_definition.get_event_type():
    "your_event":  # 替换为你的事件类型
        runtime_state["has_triggered"] = false
        runtime_state["trigger_count"] = 0
        runtime_state["last_trigger_time"] = 0.0
        _log_debug("YourEvent 状态已初始化")
```

- [ ] 添加事件类型分支
- [ ] 初始化所有状态变量
- [ ] 使用正确的初始值
- [ ] 添加日志记录

---

### Step 6: 清理状态

**6.1 在 terminate() 中清理**
```gdscript
func terminate(owner_node: Node) -> void:
    # 断开信号
    # ... 其他清理 ...

    # 清理 RuntimeEventInstance 的状态
    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("has_triggered", false)
        _runtime_instance_ref.set_runtime_state("trigger_count", 0)

    # 清理引用
    _runtime_instance_ref = null
```

- [ ] 重置所有状态到初始值
- [ ] 清理 `_runtime_instance_ref` 引用

**6.2 在 reset() 中清理**
```gdscript
func reset() -> void:
    super.reset()

    if _runtime_instance_ref:
        _runtime_instance_ref.set_runtime_state("has_triggered", false)
        _runtime_instance_ref.set_runtime_state("trigger_count", 0)
```

- [ ] 调用 `super.reset()`
- [ ] 重置所有状态
- [ ] 添加日志（可选）

---

## 测试验证检查清单

完成迁移后，使用此清单验证迁移是否成功。

### A. 基础功能测试

**A1. 单 Trigger 测试**
- [ ] 创建测试场景，添加单个 Trigger
- [ ] 运行场景，验证 Event 能正常触发
- [ ] 检查控制台日志，确认无错误
- [ ] 验证状态管理正确

**A2. 多 Trigger 共享测试**
- [ ] 创建测试场景，添加多个 Trigger
- [ ] 配置所有 Trigger 使用同一个 Event 资源（SubResource）
- [ ] 触发不同 Trigger 的 Event
- [ ] 验证每个 Trigger 的状态独立
- [ ] 验证无状态污染

---

### B. 状态隔离验证

**B1. 状态独立性**
```
测试步骤：
1. 创建 Trigger A 和 Trigger B，共享 Event X
2. Trigger A 触发 Event X，状态变为 S_A
3. Trigger B 触发 Event X，状态变为 S_B
4. 验证：S_A ≠ S_B（状态独立）
```

- [ ] 状态完全隔离
- [ ] 无相互影响

**B2. 状态持久性**
```
测试步骤：
1. Trigger A 触发 Event X，状态变为 S_A
2. Trigger B 触发 Event X，状态变为 S_B
3. 再次触发 Trigger A
4. 验证：Trigger A 的状态仍为 S_A（持久）
```

- [ ] 状态持久保持
- [ ] 不被其他 Trigger 覆盖

---

### C. 边界情况测试

**C1. 快速连续触发**
- [ ] 快速多次触发同一 Event
- [ ] 验证状态计数正确
- [ ] 验证无竞态条件

**C2. Trigger 动态创建/销毁**
- [ ] 运行时创建 Trigger
- [ ] 运行时销毁 Trigger
- [ ] 验证无内存泄漏
- [ ] 验证其他 Trigger 不受影响

**C3. Event 重置**
- [ ] 调用 `reset()` 方法
- [ ] 验证状态正确重置
- [ ] 验证可以重新触发

**C4. 场景切换**
- [ ] 切换场景
- [ ] 验证旧场景的状态已清理
- [ ] 验证新场景的状态独立

---

### D. 性能测试

**D1. 内存泄漏检查**
- [ ] 运行测试场景 5 分钟
- [ ] 反复创建/销毁 Trigger
- [ ] 使用 Godot 性能分析器检查内存
- [ ] 验证无内存泄漏

**D2. 性能影响**
- [ ] 对比迁移前后的帧率
- [ ] 测量状态访问耗时
- [ ] 验证性能影响 <1%

---

### E. 回归测试

**E1. 现有功能**
- [ ] 所有现有测试通过
- [ ] 所有现有场景正常工作
- [ ] 无破坏性更改

**E2. 向后兼容**
- [ ] 旧 Event 仍能正常工作
- [ ] 混合使用新旧 Event 无问题
- [ ] `initialize()` 方法仍可用

---

### F. 日志验证

**F1. 初始化日志**
- [ ] Event 初始化时记录日志
- [ ] RuntimeEventInstance 创建时记录日志
- [ ] 状态初始化时记录日志

**F2. 触发日志**
- [ ] Event 触发时记录日志
- [ ] 状态更新时记录日志
- [ ] 统计信息正确

**F3. 清理日志**
- [ ] Event 终止时记录日志
- [ ] 状态清理时记录日志

---

### G. 代码质量

**G1. 代码审查**
- [ ] 无硬编码状态键名（使用常量）
- [ ] 无遗漏的状态访问
- [ ] 无未使用的旧代码
- [ ] 注释清晰完整

**G2. 静态分析**
- [ ] 运行 GDScript linter
- [ ] 修复所有警告
- [ ] 无类型错误

---

## 文档更新检查清单

迁移完成后，更新相关文档。

### A. 代码文档

**A1. Event 类注释**
- [ ] 更新类描述，说明使用 RuntimeInstance
- [ ] 添加状态管理说明
- [ ] 更新使用示例

**A2. 方法注释**
- [ ] `initialize_with_runtime_instance()` 有完整注释
- [ ] 参数说明清晰
- [ ] 返回值说明清晰

---

### B. 迁移记录

**B1. 创建迁移文档**
- [ ] 记录迁移原因
- [ ] 记录迁移步骤
- [ ] 记录遇到的问题和解决方案
- [ ] 记录测试结果

**B2. 更新 CHANGELOG**
- [ ] 添加迁移条目
- [ ] 说明破坏性更改（如果有）
- [ ] 提供迁移指南链接

---

### C. 用户文档

**C1. 更新 Event 文档**
- [ ] 说明架构变更
- [ ] 更新使用示例
- [ ] 添加迁移指南（针对用户）

**C2. 更新最佳实践**
- [ ] 说明何时使用 RuntimeInstance
- [ ] 说明何时不使用
- [ ] 提供决策指导

---

## 快速参考

### 常见状态变量

| 状态类型 | 常见变量名 | 状态键建议 |
|---------|-----------|-----------|
| 触发标志 | `_has_triggered`, `_is_active` | `"has_triggered"`, `"is_active"` |
| 悬停状态 | `_is_hovered`, `_is_inside` | `"is_hovered"`, `"is_inside"` |
| 退出状态 | `_has_exited` | `"has_exited"` |
| 计数器 | `_trigger_count`, `_execution_count` | `"trigger_count"`, `"execution_count"` |
| 时间戳 | `_last_trigger_time`, `_last_time` | `"last_trigger_time"`, `"last_time"` |
| 运行状态 | `_is_running`, `_timer` | `"is_running"` |

### 常用代码片段

**读取状态（带默认值）**
```gdscript
var has_triggered = _runtime_instance_ref.get_runtime_state("has_triggered", false)
```

**检查状态是否存在**
```gdscript
if _runtime_instance_ref.has_runtime_state("has_triggered"):
    # 状态存在
    pass
```

**写入状态**
```gdscript
_runtime_instance_ref.set_runtime_state("has_triggered", true)
```

**更新计数器**
```gdscript
var count = _runtime_instance_ref.get_runtime_state("trigger_count", 0)
_runtime_instance_ref.set_runtime_state("trigger_count", count + 1)
```

**安全检查模式**
```gdscript
if _runtime_instance_ref:
    _runtime_instance_ref.set_runtime_state("key", value)
```

### 相关文档

- [迁移指南](../migration-guide-to-runtime-instance.md)
- [RuntimeInstance 架构模式](../architecture/runtime-instance-pattern.md)
- [Event 创建指南](development/event_creation_guide.md)
- [问题解决方案](../event-resource-sharing-solution.md)

---

## 附录：决策树

```
是否有运行时状态？
├─ 否 → 不需要迁移 ✅
└─ 是 → 是否可能被多个 Trigger 共享？
    ├─ 否（确定不会） → 可选迁移 ⚠️
    └─ 是（可能/确定会） → 强烈建议迁移 🔴
```

---

## 附录：状态检查脚本

```gdscript
# 检查 Event 是否有运行时状态的脚本

func _check_has_runtime_state(event_path: String) -> Dictionary:
    var result = {
        "has_state": false,
        "state_variables": [],
        "recommendation": ""
    }

    var event_script = load(event_path)
    var event = event_script.new()

    # 检查常见状态变量
    var state_patterns = [
        "_has_triggered", "_is_hovered", "_has_exited",
        "_trigger_count", "_execution_count",
        "_last_trigger_time", "_last_time",
        "_is_running", "_is_active"
    ]

    for pattern in state_patterns:
        if event.get(pattern) != null:
            result["state_variables"].append(pattern)
            result["has_state"] = true

    # 给出建议
    if result["has_state"]:
        result["recommendation"] = "建议迁移到 RuntimeInstance 架构"
    else:
        result["recommendation"] = "不需要迁移（无状态）"

    return result
```

---

**文档维护**: Fuse 开发团队
**最后更新**: 2026-02-03
