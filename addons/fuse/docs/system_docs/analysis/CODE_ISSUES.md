# 代码问题清单（CODE_ISSUES）

> 来源：2026-07-07 analysis 文档重写过程中，逐篇对比代码发现的实际问题
> 性质：这是**代码**问题清单（非文档问题），由文档审计副产物整理而来
> 核实状态图例：✅ 已读代码核实 ｜ 📋 据分析文档行号待核
> 严重度：高（功能性错误）/ 中（潜在风险或语义不一致）/ 低（性能/噪声/风格）

---

## 如何使用本清单

1. **✅ 已核实**项可直接进入修复排期
2. **📋 待核**项请开发者按行号读代码确认后再处置（部分可能是设计意图而非 bug）
3. 修复后请在对应 analysis 文档同步更新（删除"已知问题/注意点"中的相关条目）

---

## 一、✅ 已核实问题（5 项）

### B1. BaseVariable value setter 不 emit `value_modified` — 中
- **位置**：`addons/fuse/core/base/base_variable.gd:13-20`
- **现象**：`value` 字段 setter 只 `emit value_changed`（行 20），**不 emit `value_modified`**。直接赋值 `var.value = x` 时，监听 `value_modified` 的逻辑收不到通知
- **核实**：✅ 读代码确认 setter 仅 `value_changed.emit(old_value, new_value)`
- **建议**：setter 内补 `value_modified.emit(new_value)`，或文档约定修改值必须走 `set_value()`

### B2. BaseVariable set_value 双发 `value_changed` — 中
- **位置**：`addons/fuse/core/base/base_variable.gd:105-122`
- **现象**：`set_value` 内 `value = new_value`（行 107）触发 setter emit 一次 `value_changed`，随后行 116 又显式 `value_changed.emit` → 监听者收到**两次**
- **核实**：✅ 确认（与 B1 同源：setter 已 emit，set_value 又 emit）
- **建议**：set_value 不再显式 emit `value_changed`（让 setter 唯一负责），仅 emit `value_modified`

### B3. BaseVariable set_value 计数/时间戳重复更新 — 低
- **位置**：`base_variable.gd:108-109`（set_value）+ `:17-18`（setter）
- **现象**：set_value 路径下 `modification_count` +2、`last_modified_time` 更新两次（setter 一次 + set_value 一次）
- **核实**：✅ 确认
- **建议**：set_value 不重复更新计数/时间（交给 setter）

### B4. FuseThreadingConfig.get_instance 懒加载竞态 — 低-中
- **位置**：`addons/fuse/core/threading/fuse_threading_config.gd:65-70`
- **现象**：`if _instance == null: _instance = ...` 未加锁，多线程首次并发调用理论上可各创建一份实例
- **核实**：✅ 确认。对比 `GlobalVariableManager`（:14 `static var _instance = GlobalVariableManager.new()`）用静态初始化无此问题，两处风格不一致
- **建议**：改为静态初始化（`static var _instance = FuseThreadingConfig.new()`），与 GlobalVariableManager 统一

### B5. BaseVariable set_value 永远返回 true — 低
- **位置**：`base_variable.gd:105, 122`
- **现象**：返回类型 `bool` 暗示可能失败，但无任何失败路径（始终 `return true`）
- **核实**：✅ 确认
- **建议**：改为 `void`，或加入校验产生失败路径

---

## 二、📋 待核实问题（13 项）

> 以下据 analysis 文档标注（agent 给出行号），未逐一读码核实。鉴于抽核 5/5 准确，可信度较高，但仍建议修复前确认。

### 变量系统

#### B6. VariableContext 索引访问与 LOCAL 字典双轨不一致 — 中
- **位置**：`addons/fuse/core/base/variable_context.gd`（precompile_variable_access / set_variable_by_index / set_variable）
- **现象**：`precompile_variable_access` 后 `_variable_array` 与 `local_variables` 并存，常规 `set_variable` 写入路径未同步索引数组（仅 `set_variable_by_index` 走索引），存在数据不一致风险
- **建议**：核实两条写入路径是否同步；若索引仅用于读优化，注明写入失效条件

#### B7. VariableContext SCOPE→LOCAL 静默 fallback — 中
- **位置**：`variable_context.gd:188, 196`（_set_scope_variable / _get_scope_variable）
- **现象**：SCOPE 层未找到容器时仅 `push_warning` 后 fallback 到 LOCAL，生产环境若日志被屏蔽会导致变量"消失"到 LOCAL 层
- **建议**：考虑改为 `push_error` 或显式返回失败，避免静默错位

#### B8. GlobalVariableManager 静态初始化时序 — 低
- **位置**：`global_variable_manager.gd:14`
- **现象**：`static var _instance = GlobalVariableManager.new()` 在类加载时即构造，若脚本加载顺序异常可能早于 FuseLogger 初始化（注释自称"避免竞态"，指线程竞态；加载时序是另一维度）
- **核实**：✅ 静态初始化确认；加载时序风险存疑
- **建议**：核实 FuseLogger 是否同样静态可用，确认无跨依赖

#### B9. BaseVariable clone() 实例方法不完整 — 低
- **位置**：`base_variable.gd`（clone 实例方法 vs 静态 clone_variable）
- **现象**：实例 `clone()` 不拷贝 `scope` / `auto_create` / `creation_time`，与静态 `clone_variable()` 行为不一致
- **建议**：补齐字段或统一两路径

#### B10. VariableContainer 依赖图未迁移 — 低
- **位置**：`addons/fuse/core/base/variable_container.gd:947-1028`（@deprecated 类）
- **现象**：废弃类的 `_variable_dependencies` / `_dependents` 功能无取代者；若仍被使用将无法迁移
- **建议**：grep 确认是否仍有引用；若无则随废弃类移除

### 执行 / 触发器

#### B11. ExecutionContext duplicate 不复制 _diagnostics — 低
- **位置**：`addons/fuse/core/base/execution_context.gd`（duplicate）
- **现象**：`duplicate()` 的新 EC 诊断子系统为空白状态，依赖诊断连续性的场景受影响
- **建议**：按需补复制，或在文档注明限制

#### B12. BaseTrigger PER_OBJECT_COOLDOWN 无自动清理 — 低
- **位置**：`addons/fuse/core/base_trigger.gd`（object_cooldowns）
- **现象**：`object_cooldowns` 字典只在 `reset()` 时整体擦除，长时间运行 + 物体频繁进出（如 Area 触发器）会持续累积条目
- **建议**：加 TTL 或定期清理过期条目

#### B13. BaseTrigger 冷却 info 日志噪声 — 低
- **位置**：`base_trigger.gd`
- **现象**：GLOBAL/PER_OBJECT 冷却中每次触发都 `_log_info`，高频事件下日志噪声
- **建议**：降级为 debug 或加采样

#### B14. BaseTrigger trigger_manually 默认空实现 — 低
- **位置**：`base_trigger.gd:151`
- **现象**：基类钩子空实现，子类忘记覆盖则手动触发无效（Trigger 已覆盖转发 `_on_event_fired`，MultiEventTrigger 用 `trigger_binding`）
- **建议**：基类加 warning 提示未覆盖，或改 abstract

#### B15. BaseTrigger _create_execution_context 类型注解弱 — 低
- **位置**：`base_trigger.gd`（_create_execution_context）
- **现象**：返回 `RefCounted` 而非 `ExecutionContext` 类型注解，IDE 补全受限（实际返回 ExecutionContext 实例）
- **建议**：改返回类型注解为 `ExecutionContext`

### 线程 / 对象池

#### B16. ParallelConditionEvaluator 上下文快照无回写 — 中
- **位置**：`addons/fuse/core/threading/parallel_condition_evaluator.gd`
- **现象**：并行条件评估对变量的修改丢失（快照无回写路径）。这意味着"评估带副作用"的条件不应标记 `is_thread_safe`，但此约束未在 `_compute_thread_safety()` 默认实现或注释中显式声明
- **建议**：在 `_compute_thread_safety` 默认实现或类注释显式声明此约束

#### B17. FuseThreadSafe 无 try_lock 语义 — 低
- **位置**：`addons/fuse/core/threading/fuse_thread_safe.gd`
- **现象**：注释承认 Godot Mutex 限制，无法提供 `try_lock` 非阻塞语义
- **建议**：文档注明限制；需要非阻塞锁的场景由调用方自行设计

#### B18. FuseObjectPool 线性查找 — 低
- **位置**：`addons/fuse/core/pooling/fuse_object_pool.gd`（get_object / return_object）
- **现象**：通过遍历 `_pool_items` 查找项，大池高吞吐场景可能成为瓶颈
- **建议**：改用字典/索引查找

---

## 三、统计与优先级建议

| 严重度 | 数量 | 编号 |
|--------|------|------|
| 中 | 5 | B1, B2, B6, B7, B16 |
| 低-中 | 1 | B4 |
| 低 | 12 | B3, B5, B8-B15, B17, B18 |

### 建议修复顺序
1. **先修 B1+B2+B3**（BaseVariable 信号/计数不一致，同源，一次性修；影响变量监听逻辑正确性）
2. **核 B6+B7**（VariableContext 数据一致性 / 静默 fallback，若属实影响变量系统正确性）
3. **修 B4**（FuseThreadingConfig 竞态，改成静态初始化一行搞定）
4. **核 B16**（并行评估副作用约束未声明）
5. 其余低严重度项按需排期

### 共性
- **BaseVariable 信号问题是核心**：B1/B2/B3 同源（setter 与 set_value 职责重叠），建议一并重构——让 setter 唯一负责 emit + 计数，set_value 仅做额外逻辑
- **风格不一致**：单例两种写法（静态初始化 vs 懒加载），建议统一

---

## 四、不属 bug 的"设计注意"（不收入修复清单）

以下在 analysis 文档中标注，但实为设计意图或正常逻辑，记录于此避免误修：
- BaseTrigger `_on_trigger_ready` / `_on_trigger_exit_tree` 等空实现 —— 钩子设计，子类按需覆盖
- BaseInstruction `on_runtime_pause` / `on_runtime_resume` 空实现 —— 钩子设计
- BaseCondition `get_history` / `clear_history` / `get_performance_metrics().average_check_time` 基类占位 —— 子类可选实现
- BaseVariable `DEFAULT_VALUE=null` 占位、VariableContainer @deprecated —— 正常迁移状态
- ExecutionContext `get_tree` fallback —— 已实现，非缺陷

---

**维护**：修复后请同步更新对应 analysis 文档的"已知问题/注意点"段，并在此清单标注。最后更新：2026-07-07。
