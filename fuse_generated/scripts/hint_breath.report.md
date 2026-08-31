# 毕业导出报告 — hint_breath

- 源单元: `Control/TitleHint/HintBreath` (L2)
- 生成脚本: `res://fuse_generated/scripts/hint_breath.gd`（本报告同目录）
- 指令总数: 2（含 bindings，不含 disabled 跳过项）
- 原生覆盖率: **0/2 (0%)**
- 委托指令: 2 项（经 FuseDelegation 桥执行）
- 跳过的 disabled bindings: 无
- RESTART→SKIP 降级 bindings: 无

## 已知语义风险

- binding u1：CheckAnyInput 即时探测语义（2×interval 窗口语义未复刻，生成代码每滴答即时检查）

## 委托清单（按生成顺序）

1. TweenFadeIn
2. TweenFadeOut

## 采用与回滚

采用：禁用源 Trigger 节点 → 本脚本挂到同路径节点 → 运行验证。
回滚：恢复源 Trigger → 移除本脚本。
