# 代码修复规格说明（FIX_SPEC）


> **分析时点**：2026-07-07（经同日全量文档审计逐篇核对代码；此后实现演进以源码为准，近期已核对的机制性结论见 threading / runtime_instance / preset_nested 等篇）
> 用途：规范 CODE_ISSUES.md 中 18 个代码问题的核实与修复工作。
> 依据：[CODE_ISSUES.md](CODE_ISSUES.md)
> 性质：**代码修复**（非文档），涉及行为变更，需测试与影响评估
> 状态：待执行 | 创建日期：2026-07-07 | 维护：Fuse 开发团队

---

## 1. 背景与动机

analysis 文档重写过程中发现 18 个代码问题（[CODE_ISSUES.md](CODE_ISSUES.md)）：5 个已读码核实（B1-B5），13 个据分析文档行号待核（B6-B18）。

其中 **BaseVariable 信号/计数不一致（B1-B3）同源**，影响变量监听逻辑正确性；**FuseThreadingConfig 竞态（B4）** 与 GlobalVariableManager 风格不一致。本 spec 定义"先核实、再修复、全程测试"的流程。

⚠️ **本 spec 改代码而非文档**，风险高于前几轮文档工作：信号语义、单例生命周期、变量作用域 fallback 等改动可能破坏现有调用方，必须配合 grep 影响评估 + gdscript-validate + 测试。

---

## 2. 现状盘点（摘自 CODE_ISSUES）

### 2.1 按状态

| 状态 | 数量 | 编号 |
|------|------|------|
| ✅ 已核实 | 5 | B1, B2, B3, B4, B5 |
| 📋 待核实 | 13 | B6–B18 |

### 2.2 按系统

| 系统 | 编号 | 已核实/待核 |
|------|------|-------------|
| BaseVariable（变量基类） | B1, B2, B3, B5, B9 | 4 已核 / 1 待核 |
| VariableContext / Container | B6, B7, B10 | 0 / 3 |
| GlobalVariableManager | B8 | 0 / 1 |
| ExecutionContext | B11 | 0 / 1 |
| BaseTrigger | B12, B13, B14, B15 | 0 / 4 |
| 线程 | B4, B16, B17 | 1 / 2 |
| 对象池 | B18 | 0 / 1 |

### 2.3 严重度分布

中：B1, B2, B6, B7, B16（5）｜低-中：B4（1）｜低：其余 12

---

## 3. 修复目标

1. **待核项全部有结论**：13 项读码核实，三选一归类（属实→修复 / 误判→剔除 / 设计意图→移入"设计注意"）
2. **已核实 + 确认属实项全部修复**
3. **每修复一项三同步**：gdscript-validate 通过 + 测试通过 + CODE_ISSUES 与 analysis 文档更新
4. **零回归**：信号/单例/作用域等契约性改动须 grep 调用方评估

---

## 4. 详细修复项

### 4.1 阶段一：核实 13 待核项（前置，必须先做）

逐个读码核实 B6–B18，每项输出结论：
- ✅ **属实** → 进入修复队列（标严重度）
- ❌ **误判** → 从 CODE_ISSUES 剔除（如 agent 行号过期/理解错）
- ⚠️ **设计意图** → 移入 CODE_ISSUES §四"设计注意"

> 建议并行派子代理按系统分组核实（变量系统 / 触发器 / 线程池），每个 agent 读码 + 给结论。

### 4.2 阶段二：BaseVariable 信号重构（B1 + B2 + B3 + B5，同源一次性）

**根因**：setter（:13-20）与 set_value（:105-122）职责重叠 → 直接赋值漏 `value_modified`、set_value 双发 `value_changed`、计数翻倍。

**方案 A（推荐）— setter 唯一负责 emit + 计数**：
```gdscript
# setter：唯一 emit 点 + 唯一计数点
@export var value: Variant = null:
    set(new_value):
        var old_value = value
        value = new_value
        last_modified_time = Time.get_ticks_msec() / 1000.0
        modification_count += 1
        value_changed.emit(old_value, new_value)
        value_modified.emit(new_value)   # 补 B1

# set_value：仅封装（不再 emit / 不再计数）
func set_value(new_value: Variant) -> bool:
    value = new_value        # 触发 setter，由 setter 统一 emit + 计数
    return true              # B5：考虑改 void 或加校验
```

**方案 B — set_value 唯一负责**：setter 不 emit。**风险**：破坏所有 `var.value = x` 直接赋值后依赖信号的现有代码，不推荐。

**前置影响评估**：`grep -rn "value_changed\|value_modified" addons/fuse/` 列出所有监听者，逐一确认改动后行为正确（尤其值相同时是否仍需 emit——当前 setter 不判等，改动保持）。

**B9（clone 不完整）** 顺带修：实例 clone() 补齐 scope/auto_create/creation_time，或直接委托静态 clone_variable()。

### 4.3 阶段三：单例风格统一（B4 + B8）

- **B4 修复**：`FuseThreadingConfig`（:65-70）懒加载改静态初始化：
  ```gdscript
  static var _instance: FuseThreadingConfig = FuseThreadingConfig.new()
  static func get_instance() -> FuseThreadingConfig:
      return _instance
  ```
- **B8 核实**：确认 `FuseLogger` 静态可用（无跨依赖）后，B8 标"非问题"；若有依赖，加延迟初始化注解。

### 4.4 阶段四：VariableContext（B6 + B7 + B10，核实后修）

- **B6**：核实 `set_variable` 与 `set_variable_by_index` 是否同步 `_variable_array` 与 `local_variables`。若不同步：写入路径统一同步，或注明索引仅读优化 + 写入失效条件。
- **B7**：SCOPE→LOCAL fallback（:188,196）由 `push_warning` 改 `push_error` 并返回失败（避免静默错位）。**前置 grep**：确认无调用方依赖 fallback 行为。
- **B10**：`grep -rn "_variable_dependencies\|_dependents" addons/fuse/` 确认 VariableContainer（@deprecated）依赖图是否仍被引用；无引用则随废弃类 eventual 移除。

### 4.5 阶段五：BaseTrigger（B12-B15，核实后修，均低严重度）

- **B12**：PER_OBJECT_COOLDOWN 的 `object_cooldowns` 加 TTL 或定期清理（`_process` 检查过期）。
- **B13**：冷却 `_log_info` 降级 `_log_debug` 或加采样（每 N 次/秒一次）。
- **B14**：`trigger_manually` 基类默认实现加 `push_warning("trigger_manually 未覆盖")` 或改 abstract（需评估子类）。
- **B15**：`_create_execution_context` 返回类型注解改 `ExecutionContext`。

### 4.6 阶段六：线程 / 对象池（B16 + B17 + B18，核实后修）

- **B16**：在 `_compute_thread_safety()` 默认实现或类注释**显式声明约束**："评估带副作用的条件不应标 is_thread_safe，因并行快照修改不回写"。属文档性修复（代码注释/默认实现警告），风险低。
- **B17**：FuseThreadSafe 类注释注明"无 try_lock，Godot Mutex 限制"。纯文档。
- **B18**：FuseObjectPool get_object/return_object 改字典索引（按 pool_item 标识）。**需性能基准对比**，确认大池场景确实改善。

---

## 5. 不做的事（Out of Scope）

- ❌ 不改 CODE_ISSUES §四"设计注意"项（钩子空实现、占位常量、@deprecated 迁移等）
- ❌ 不重构无关代码（只修列出的 18 项）
- ❌ 不在无测试覆盖下改高风险契约（信号/单例/作用域）—— 先补测试
- ❌ 不修 B6/B7/B16/B18 之前跳过"核实"步骤

---

## 6. 验收标准

- [ ] 13 待核项全部归类（属实 / 误判 / 设计意图）
- [ ] 属实项全部修复
- [ ] BaseVariable B1+B2+B3+B5 一次性重构完成，监听者 grep 评估无破坏
- [ ] B4 单例改静态初始化
- [ ] 每个代码修复：`gdscript-validate` 通过 + Godot headless 测试通过
- [ ] 高风险改动（B1-B3 信号、B7 fallback、B4 单例）有新增/更新测试覆盖
- [ ] CODE_ISSUES.md 同步更新（已修项标注、误判项剔除）
- [ ] 对应 analysis 文档"已知问题/注意点"段同步删除已修项

---

## 7. 执行顺序

1. **决策**（§9）：范围、BaseVariable 方案、测试策略、执行方式
2. **阶段一**：并行核实 13 待核项（派子代理按系统分组）
3. **阶段二**：BaseVariable 重构（B1-B3+B5+B9，影响评估 + 测试 + 修复）
4. **阶段三**：单例统一（B4 修 + B8 核实）
5. **阶段四**：VariableContext（核实属实的修）
6. **阶段五**：BaseTrigger（低优先级批量）
7. **阶段六**：线程/对象池（B16/B17 文档性 + B18 性能）
8. 全量 gdscript-validate + 测试
9. 同步 CODE_ISSUES + analysis 文档 + 提交

---

## 8. 测试策略（遵循全局 TDD 规范）

- **B1-B3 信号**：先写测试断言 emit 次数 —— `var.value = x` 后 `value_changed` 与 `value_modified` 各恰好 1 次；`set_value(x)` 后各恰好 1 次；`modification_count` +1
- **B4 单例**：测试 `get_instance()` 多次返回同一对象
- **B7 fallback**：测试 SCOPE 未命中时返回失败（而非静默写 LOCAL）
- **B12 清理**：测试过期 object_cooldowns 条目被清
- 高风险改动前先 `grep` 调用方；改动后跑现有测试套件确认无回归

---

## 9. 需决策的事项

| # | 决策 | 选项 | 推荐 |
|---|------|------|------|
| 1 | 范围 | A 全 18 / B 已核实 5 + 中严重度 / C 仅已核实 5 | B（先清中等以上，低优先级排期） |
| 2 | BaseVariable 方案 | A setter 唯一 / B set_value 唯一 | A（不破坏直接赋值） |
| 3 | 待核项处理 | A 先全部核实 / B 边核边修 | A（避免修到误判项） |
| 4 | 测试策略 | A 严格 TDD / B 修复后补测试 / C 仅 validate | A（代码改动必 TDD，全局规则） |
| 5 | 执行方式 | A 并行子代理 / B 串行 | A（阶段一核实可并行；阶段二重构串行） |

---

## 10. 风险提示

- **信号契约变更（B1-B3）**：Fuse 可能有第三方/未来代码依赖 `value_modified` 在直接赋值时不触发（虽是 bug 但被依赖）。修复前 grep 全项目 + demos 确认。
- **单例初始化时机（B4）**：静态初始化在类加载时，若 FuseThreadingConfig 的 `_init` 依赖其他autoload，可能引入新问题。核实 _init 实现。
- **B7 fallback 行为变更**：从"静默成功"改"失败返回"，调用方若未检查返回值会行为不同。需评估所有 `_set_scope_variable` / `_get_scope_variable` 调用方。

**附**：完整问题清单见 [CODE_ISSUES.md](CODE_ISSUES.md)；核实依据见各 analysis 文档"已知问题/注意点"段。
