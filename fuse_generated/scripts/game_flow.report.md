# 毕业导出报告 — game_flow

- 源单元: `GameManager/GameFlow` (L4)
- 生成脚本: `res://fuse_generated/scripts/game_flow.gd`（本报告同目录）
- 指令总数: 28（含 bindings，不含 disabled 跳过项）
- 原生覆盖率: **3/28 (11%)**
- 委托指令: 25 项（经 FuseDelegation 桥执行）
- 跳过的 disabled bindings: 无
- RESTART→SKIP 降级 bindings: ["b0"]

## 委托清单（按生成顺序）

1. CrossfadeToMusic
2. LoadGlobalVariables
3. PauseGame
4. GetPosition
5. MathOperation
6. GetAllChildrenPosition
7. WarmUpPool
8. WarmUpPool
9. WarmUpPool
10. WarmUpPool
11. WarmUpPool
12. WarmUpPool
13. WarmUpPool
14. WarmUpPool
15. RunRunner
16. MathOperation
17. MathOperation
18. SetVariable
19. SendEvent
20. IfThen
21. MathOperation
22. PauseGame
23. IfElse
24. MathOperation
25. IfElse

## 采用与回滚

采用：禁用源 Trigger 节点 → 本脚本挂到同路径节点 → 运行验证。
回滚：恢复源 Trigger → 移除本脚本。
