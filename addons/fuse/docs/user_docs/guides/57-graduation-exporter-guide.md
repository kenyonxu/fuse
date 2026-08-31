# 毕业导出器使用指南

毕业导出器提供**从 Fuse 原型到工程代码的晋升路径**：从场景拓扑推导出 System（系统）工件，按 System 生成可读、可验证、与 Fuse 运行时共存的 GDScript。它是"非破坏性"的——导出器只产出新文件，不改场景、不动源 Trigger；回滚就是反向操作。

> 适用场景：某块游戏逻辑已在 Fuse 里调稳（攻击时序、UI 呼吸、关卡流转），需要交给程序员接管或脱离可视化层维护时，用毕业导出器把它"毕业"为 GDScript。仍在频繁调参的逻辑建议留在 Fuse 侧——Inspector 拖滑块的反馈环更短。

---

## 核心概念

| 概念 | 说明 |
|------|------|
| **System 工件** | 一份可审阅的 JSON IR（`fuse_generated/systems/<name>.json`）：这个系统做什么（description）、包含哪些单元（units）、边界在哪（externals：外联事件/变量）、已确认的竞态警告。人（或 AI）可以在推导草稿上编辑它 |
| **桥接模式** | 生成的 GDScript 通过 `FuseDelegation`（`core/graduation/`）与 Fuse 运行时共存：变量走三层变量服务、事件走 FuseEventBus 总线、非白名单指令内嵌为数据并由运行时委托执行 |
| **混合指令委托** | 常用指令（Wait/Print/SendEvent/变量读写/MathOperation/UI 文本与显隐/全局变量存取）原生直译为可读代码；其余指令序列化为 JSON 内嵌，运行时重建执行——毕业是梯度不是门槛，覆盖率会随白名单扩充逐步提高 |
| **非破坏性** | 源 Trigger 节点保持原样（只是被禁用）；生成脚本的头注释带完整的采用与回滚步骤；代码副本离桥之后桥还在 |

## 工作流（四步）

```bash
# ① 推导草稿——每个 Trigger/MultiEventTrigger 单元一份（Runner 单元与嵌套场景单元暂不推导）
Godot --headless --path . res://addons/fuse/editor/graduation/derive_systems.tscn -- \
  --scene res://demos/fuse/brickian/game_scene.tscn
# 产物：fuse_generated/systems/drafts/<name>.json + _derive_report.json（含竞态警告四元组清单）

# ② 人工确认——从 drafts/ 拷贝想要的单元为正式 System（fuse_generated/systems/<name>.json），
#    填 description、把 _derive_report.json 里的 warnings_by_unit 条目整条拷入 acknowledged_warnings

# ③ 校验——单元存在性、层级一致、外联可解析、竞态已确认、topology_digest 未漂移
Godot --headless --path . res://addons/fuse/editor/graduation/validate_system.tscn -- <system.json>
# 退出码：0 = 通过；1 = 有 error；2 = 参数/IO 错误

# ④ 生成——先内部跑校验（不过拒绝生成），产出脚本 + 就绪报告
Godot --headless --path . res://addons/fuse/editor/graduation/export_system.tscn -- <system.json>
# 产物：fuse_generated/scripts/<name>.gd + <name>.report.md（覆盖率/委托清单/风险标注）
```

金样例：`fuse_generated/scripts/game_flow.gd`（L4 多事件）与 `hint_breath.gd`（L2 定时器）。

## 采用与回滚

生成的脚本头注释带有操作说明，展开如下：

**采用（把逻辑从 Fuse 移交给代码）：**
1. 在场景中**禁用**源 Trigger/MultiEventTrigger 节点（Inspector 顶部的开关，不要删除）
2. 把生成脚本挂载到**同路径节点**（委托指令的相对 NodePath 以挂载点为锚，换节点会失效）
3. 运行场景验证行为，对照 `.report.md` 的覆盖率与风险标注

**回滚：**
1. 恢复源 Trigger 节点的启用
2. 移除生成脚本（或先禁用观察）

## 就绪报告怎么读

`.report.md` 包含：

- **覆盖率**：原生直译指令数 / 总指令数（含嵌套）。金样例 game_flow 为 1/28——大量指令含 LOCAL 变量传递，整条 binding 保真委托（见下文"已知语义偏差"第 5 条）
- **委托清单**：哪些指令走了运行时委托
- **风险标注**（按需出现）：输入事件时序差异 / CheckAnyInput 停止条件探测窗口 / 条件失败不进冷却 / RESTART 降级 / LOCAL 整条委托

## 已知语义偏差（采用前必读）

生成代码与 Fuse 运行时在以下场景存在已备案的行为差异，采用前请对照自己的系统确认：

1. **RESTART 重触发策略降级为 SKIP**：源 binding 若配置了 RESTART（取消当前并重启），生成代码按 SKIP（运行中忽略新触发）处理——校验器会发 `W_RESTART_DEGRADED` 警告。请人工确认该绑定重触发时上一轮执行通常已完成
2. **输入事件时序**：生成代码在 `_unhandled_input` 中用 `Input` 单例判断（与 Fuse 同构），但与引擎输入处理的帧内顺序可能不同
3. **CheckAnyInput 停止条件**：Fuse 的 2×interval 探测窗口语义未完整复刻，生成代码为逐拍即时探测
4. **条件失败不进冷却**：Fuse 在冷却检查通过即计时（条件失败也进冷却）；生成代码条件失败时不消耗冷却，重试更积极
5. **LOCAL 变量与整条委托**：binding 内任一指令（含嵌套）读写 LOCAL 变量时，整条 binding 全部走运行时委托以保证变量连续性——覆盖率下降是代价，语义保真是目的
6. **不支持的事件/配置**：白名单四类事件（OnReady/OnInputAction/OnInterval/OnReceiveEvent）之外的事件类型、L3 Runner 单元、PARALLEL 混合原生行切批等场景会被拒绝生成并列出清单

## 二期展望

- **多单元物化模式**：同一连通分量的多个单元一起毕业时，共享变量物化为脚本成员、事件对转为直调（System 格式已按多单元设计）
- 白名单指令扩充、行为等价性评测（生成的代码 vs Fuse 运行时对照）

## 相关文档

- 设计 spec：[2026-08-30-preset-gdscript-graduation-design.md](../../superpowers/specs/2026-08-30-preset-gdscript-graduation-design.md)（含执行中修订记录）
- 场景拓扑面板：[00-editor-panels-overview.md](00-editor-panels-overview.md)
- 预设系统（去程）：[55-preset-system-guide.md](55-preset-system-guide.md)
