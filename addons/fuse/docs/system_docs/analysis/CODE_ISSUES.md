# 代码问题清单（CODE_ISSUES）


> 来源：2026-07-07 analysis 文档重写过程中，逐篇对比代码发现的实际问题
> 性质：这是**代码**问题清单（非文档问题），由文档审计副产物整理而来
> 核实状态图例：✅ 已修 ｜ ⏸ skip（低优先） ｜ ⚠️ 设计意图（保留） ｜ ❌ 误判（剔除） ｜ 📋 据分析文档行号待核
> 严重度：高（功能性错误）/ 中（潜在风险或语义不一致）/ 低（性能/噪声/风格）

---

## 如何使用本清单

1. **✅ 已修**项：已修复并附 commit；同步在对应 analysis 文档删除/标注"已知问题"条目
2. **⏸ skip**项：低优先级，记录在册，未来按需排期
3. **⚠️ 设计意图**项：非 bug，记录于 §四 避免误修
4. **❌ 误判**项：剔除，原因见条目

---

## 顶部统计

| 状态 | 数量 | 编号 |
|------|------|------|
| ✅ 已修 | 12 | B1, B2, B3, B4, B6, B7, B9, B11, B12, B13, B14, B15, B16, B19 + 镜像 |
| ❌ 误判 | 1 | B8 |
| ⚠️ 设计意图 | 2 | B10, B17 |
| ⏸ 低优先 skip | 3 | B5, B18, clone set bypass |

> ✅ 已修 一栏含 1 项新发现（B19 + multi_event_trigger 镜像 bug），与原编号 B1–B18 不一一对应。

---

## 一、✅ 已修问题（含附 commit）

### B1. BaseVariable value setter 不 emit `value_modified` — 中 ✅
- **位置**：`addons/fuse/core/base/base_variable.gd`
- **修复**：setter 内补 `value_modified.emit(new_value)`，与 `set_value()` 统一信号语义
- **commit**：`e3c470d`（fix: unify BaseVariable signal emission in setter）

### B2. BaseVariable set_value 双发 `value_changed` — 中 ✅
- **位置**：`base_variable.gd`（set_value）
- **修复**：`set_value` 不再显式 emit `value_changed`，让 setter 唯一负责 emit；仅 emit `value_modified`
- **commit**：`e3c470d`

### B3. BaseVariable set_value 计数/时间戳重复更新 — 低 ✅
- **位置**：`base_variable.gd`（set_value）
- **修复**：set_value 不重复更新计数/时间，交给 setter 唯一负责
- **commit**：`e3c470d`

### B4. FuseThreadingConfig.get_instance 懒加载竞态 — 低-中 ✅
- **位置**：`addons/fuse/core/threading/fuse_threading_config.gd`
- **修复**：改为静态初始化（`static var _instance = FuseThreadingConfig.new()`），与 GlobalVariableManager 风格统一
- **commit**：`fb9b96a`

### B6. VariableContext 索引访问与 LOCAL 字典双轨不一致 — 中 ✅
- **位置**：`addons/fuse/core/base/variable_context.gd`（precompile_variable_access / set_variable_by_index / set_variable）
- **修复**：两条写入路径同步索引数组（`set_variable(name)` 路径也同步 `_variable_array`）
- **commit**：`4adf15b`
- **测试**：`tests/core/test_variable_context_index_sync.tscn`

### B7. VariableContext SCOPE→LOCAL 静默 fallback — 中 ✅
- **位置**：`variable_context.gd`（_set_scope_variable / _get_scope_variable）
- **修复**：`push_warning` 改为 `push_error`（仍 fallback，但生产环境不会被日志屏蔽吞掉）
- **commit**：`4adf15b`

### B9. BaseVariable clone() 实例方法不完整 — 低 ✅
- **位置**：`base_variable.gd`（clone 实例方法）
- **修复**：补齐 `scope` / `auto_create` / `creation_time` 字段拷贝，与静态 `clone_variable()` 行为一致
- **commit**：`e3c470d`

### B11. ExecutionContext duplicate 不复制 _diagnostics — 低 ✅
- **位置**：`addons/fuse/core/base/execution_context.gd`（duplicate）
- **修复**：duplicate 后补 _diagnostics 深拷贝，保留诊断历史/状态
- **commit**：`1ffe707`

### B12. BaseTrigger PER_OBJECT_COOLDOWN 无自动清理 — 低 ✅
- **位置**：`addons/fuse/core/base_trigger.gd`（object_cooldowns）
- **修复**：增加过期条目清理（_check_cooldown 路径自动清理已过期条目）
- **commit**：`0bd037b`
- **测试**：`tests/core/test_base_trigger_cooldown_cleanup.tscn`

### B13. BaseTrigger 冷却 info 日志噪声 — 低 ✅
- **位置**：`base_trigger.gd`
- **修复**：日志级别调整/采样降噪
- **commit**：`0bd037b`

### B14. BaseTrigger trigger_manually 默认空实现 — 低 ✅
- **位置**：`base_trigger.gd:151`
- **修复**：基类加 warning 提示未覆盖
- **commit**：`0bd037b`

### B15. BaseTrigger _create_execution_context 类型注解弱 — 低 ✅
- **位置**：`base_trigger.gd`（_create_execution_context）
- **修复**：返回类型注解改为 `ExecutionContext`，IDE 补全正确
- **commit**：`0bd037b`

### B16. ParallelConditionEvaluator 上下文快照无回写 — 中 ✅
- **位置**：`addons/fuse/core/threading/parallel_condition_evaluator.gd`
- **修复**：在 `_compute_thread_safety` 默认实现 / 类注释中**显式声明**"评估带副作用（修改变量）的条件不应标记 is_thread_safe"约束
- **commit**：`42cb339`
- **说明**：快照隔离本身是设计（防止并行评估污染主线程），改动是补齐"无副作用"约束声明，而非改回写路径

### B19.（新发现）ExecutionContext _init 缩进 → 仅 target 时 VC nil — 中 ✅
- **位置**：`execution_context.gd`（_init）
- **现象**：`_diagnostics` 与 `_variable_context` 创建语句缩进在 `if trigger_node:` 块内，导致 `ExecutionContext.new(target, null)` 时子系统未被创建，后续 `set_variable` 报 Nil
- **修复**：缩进提到块外，target-only 构造也创建子系统
- **commit**：`1ffe707`
- **测试**：`tests/core/test_execution_context_init.tscn`

### 镜像 bug（新发现）multi_event_trigger object_cooldowns 泄漏 — 低 ✅
- **位置**：`addons/fuse/core/multi_event_trigger.gd`
- **现象**：B12 同款问题在 MultiEventTrigger 中复现（`object_cooldowns` 字典在 PER_OBJECT_COOLDOWN 模式下持续累积）
- **修复**：复用 B12 清理逻辑
- **commit**：`9f61cef`
- **测试**：`tests/core/test_multi_event_trigger_cooldown_cleanup.tscn`

---

## 二、❌ 误判（剔除）

### B8. GlobalVariableManager 静态初始化时序 — 低 ❌
- **原据分析文档行号登记**：`global_variable_manager.gd:14`
- **剔除原因**：`FuseLogger` 纯静态（无实例状态、无依赖），`GlobalVariableManager` 静态初始化与其无时序依赖。"加载时序风险"为臆测，不存在实际触发路径。

---

## 三、⏸ 低优先 skip（记录，未来按需）

### B5. BaseVariable set_value 永远返回 true — 低 ⏸（保留 + 注释）
- **位置**：`base_variable.gd`（set_value）
- **决策**：**保留 bool 返回类型**。理由：调用方（指令层、事件层）已普遍按 `if set_value(...):` 模式消费返回值；改为 `void` 会破坏调用契约。在源码注释中说明"当前实现永远成功，保留 bool 以稳定 API"。
- **未来路径**：若引入值校验（类型/范围），自然产生失败路径，bool 类型即时启用

### B18. FuseObjectPool 线性查找 — 低 ⏸
- **位置**：`addons/fuse/core/pooling/fuse_object_pool.gd`（get_object / return_object）
- **决策**：skip。`_pool_items` 规模典型 n≤100，线性查找开销可忽略；改字典/索引查找增加内存开销与维护成本，收益有限。保留 pooling_analysis 中的注意点条目

### clone set bypass（quality suggestion）⏸
- **位置**：`base_variable.gd`（clone_variable / clone 内部）
- **现象**：克隆路径用 `new_variable.set("value", value)` 绕过 value setter，避免克隆时触发 emit/计数
- **决策**：latent 无害，skip。绕过是有意为之（克隆不应产生变更通知）；不需要修

---

## 四、⚠️ 设计意图（保留，不收入修复清单）

以下在 analysis 文档中标注，但实为设计意图或正常逻辑，记录于此避免误修：

- **B10. VariableContainer 依赖图未迁移** — `variable_container.gd:947-1028`（@deprecated 类）。grep 确认：依赖图字段（`_variable_dependencies` / `_dependents`）在仓库内**零外部引用**，废弃类无人使用，无迁移需求。随废弃类最终移除即可。
- **B17. FuseThreadSafe 无 try_lock 语义** — Godot Mutex API 限制，源码注释已声明此限制。需要非阻塞锁的场景由调用方自行设计。
- BaseTrigger `_on_trigger_ready` / `_on_trigger_exit_tree` 等空实现 —— 钩子设计，子类按需覆盖
- BaseInstruction `on_runtime_pause` / `on_runtime_resume` 空实现 —— 钩子设计
- BaseCondition `get_history` / `clear_history` / `get_performance_metrics().average_check_time` 基类占位 —— 子类可选实现
- BaseVariable `DEFAULT_VALUE=null` 占位、VariableContainer @deprecated —— 正常迁移状态
- ExecutionContext `get_tree` fallback —— 已实现，非缺陷

---

## 五、共性总结

- **BaseVariable 信号问题是核心**：B1/B2/B3 同源（setter 与 set_value 职责重叠），已一并重构（`e3c470d`）——让 setter 唯一负责 emit + 计数，set_value 仅做额外逻辑
- **风格统一**：单例两处写法（静态初始化 vs 懒加载）已统一为静态初始化（B4）
- **镜像 bug 经验**：B12 修 BaseTrigger 时未同步 MultiEventTrigger，事后补修（镜像 bug）。未来同类修复需 grep 检查并行子类

---

**维护**：修复后请同步更新对应 analysis 文档的"已知问题/注意点"段，并在此清单标注。最后更新：2026-07-07（阶段四收尾）。
