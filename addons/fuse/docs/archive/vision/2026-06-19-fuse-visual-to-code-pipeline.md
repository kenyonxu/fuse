# Fuse Visual → JSON → Code 管道

**日期:** 2026-06-19
**触发:** Stage 6 多层级 Preset 设计讨论
**类型:** 架构愿景

---

## 1. 核心洞察

Fuse 不只是"无代码工具"。它是**逻辑规格设计器** — 用可视化做快速原型和需求表达，JSON 做规格交割，GDScript 做生产交付。原型和生产之间不再有"重写"过程，而是"编译"过程。

```
可视化编辑器         JSON Spec               GDScript 生产代码
──────────────────────────────────────────────────────────────
Trigger: OnCollision → {"event":{"type":  → func _on_area_entered(area):
  条件: CheckHealth     "OnCollision"},        if hp > max_hp * 0.5:
  指令: ApplyDamage     "conditions":[...],       _apply_damage(10)
       CameraShake      "instructions":[...]}     _camera_shake(0.5)
```

## 2. 三个表示层

| 阶段 | 表示形式 | 用途 | 受众 |
|------|---------|------|------|
| **Fuse 节点** | Godot 对象图 | 人机交互设计（拖拽、可视化连接） | 设计师 |
| **JSON Preset** | 结构化声明 | 无歧义的系统规格书，AI 可靠解读 | AI Agent |
| **GDScript** | 命令式代码 | 生产运行时，无插件依赖，性能最优 | 引擎 |

## 3. JSON 作为代码生成源的可靠性

三个关键属性让 JSON 成为可靠的代码生成输入：

### 3.1 完整语义

Event/Condition/Instruction 的类型名 + 参数名都是确定性的：

```json
{ "type": "ApplyDamage", "amount": 10 }
{ "type": "SetAnimationParameter", "param": "phase", "value": 2 }
```

AI 不需要"猜测"意图 — 类型名直接映射到可验证的行为。

### 3.2 组合可分析

多个 preset 的 JSON 放在一起，AI 可以分析出它们的共同 pattern：

```
输入: boss_phase1.json, boss_phase2.json, boss_phase3.json
输出: "Boss 生命周期状态机（3 阶段）"
      "SpawnMinion 指令在 phase1 和 phase2 都出现 → 建议合并为 SpawnController 子组件"
```

### 3.3 版本可 diff

生产脚本可以反向关联到其来源 preset：

```
git log -- boss_controller.gd
→ "根据 boss_phase1-3.json 生成，preset diff 显示 phase2 RageMode 新增"
```

CI 里可以比较"上次生成的脚本"和"新 preset 导出的脚本"。

## 4. 完整工作流

```
第 1 步：设计师在 Fuse 编辑器中快速原型
  ├── preset/boss_phase1.json  (OnInterval → SpawnMinion)
  ├── preset/boss_phase2.json  (OnHealthBelow → RageMode)
  └── preset/boss_phase3.json  (OnDeath → DropLoot + LoadScene)

第 2 步：AI Agent 读取 JSON 集合
  → 分析系统蓝图: "Boss 生命周期状态机（3 阶段）"
  → 识别冗余: SpawnMinion 指令共享 → 提取为子组件
  → 识别风险: phase1 无退出条件 → 可能死循环
  → 提出优化方案

第 3 步：AI 编写 boss_controller.gd
  → 无 Fuse 运行时依赖
  → 编译为 GDScript 原生性能
  → 可进一步手写优化

第 4 步：CI 校验
  → JSON diff 对应逻辑变更
  → 生成的脚本通过项目 lint 规则
  → 性能分析确认无 Fuse 中间层损失
```

## 5. 与 Fuse 其他系统的关系

```
Fuse 节点系统（Stage 1-4 构建的 183 个组件）
    │
    ├── 运行时: Trigger/Runner/MultiEventTrigger 在场景中直接执行
    │
    └── 设计时:
        ├── Preset 导出 (Stage 6) → JSON
        │     ├── 跨场景复用
        │     ├── AI 批量生成
        │     └── 版本控制（git diff 友好）
        │
        ├── 数据流可视化 (Stage 5) → 理解复杂逻辑
        │
        └── [未来] 代码生成 (Stage N) → JSON → GDScript 编译
              ├── template-based: 类型 → 代码模板映射
              ├── AI-driven: LLM 读取 JSON → 生成优化代码
              └── 反向同步: GDScript 修改 → 更新 preset
```

## 6. 关键里程碑

| 阶段 | 能力 | 状态 |
|------|------|:--:|
| Stage 1-4 | 183 个组件（完整逻辑词汇表） | ✅ |
| Stage 5 | 数据流可视化（理解复杂逻辑） | ✅ |
| Stage 6 | 多层级 Preset（JSON 表示层） | 设计中 |
| Stage N | JSON → GDScript 编译（代码生成） | 未来 |

## 7. 结论

Fuse 不是"无代码替代品"，而是**逻辑规格的渐进式精确化工具链**。设计师在可视化环境里用自然速度表达意图，JSON 把意图冻结为 AI 可操作的结构化规格，GDScript 把规格编译为引擎可执行的生产代码。三者之间没有信息损失，只有表示的转换。

---

**关联文档:**
- [Stage 6 设计文档](../specs/2026-06-19-fuse-stage6-design.md)
- [Fuse 推进路线图](../roadmap/2026-06-16-fuse-development-roadmap.md)
