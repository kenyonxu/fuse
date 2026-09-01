# 验收清单提炼指引（打包 agent 用）

从 bundle 的 preset / system 数据提炼**静态可对照**的行为断言，产出 `acceptance.md`。
每条断言一行、可勾选（`- [ ]`），**注明来源**（preset 文件名 + 定位信息）。

## 必须覆盖的五类断言

1. **事件序列**：每个 SendEvent 的 event_name、顺序、参数值；`$var` 引用需注明
   解析来源变量（例：`args.score = $c_score ← local 变量 c_score 当前值`）。
2. **变量终值**：SetVariable / MathOperation 的写入目标、期望值、所在分支条件。
3. **触发-效果对**：每个 binding 一行摘要——「OnReceiveEvent X → 扣命 → 若命=0 → GameEnd("loss")」。
4. **时序约束**：Wait 链与时长、OnInterval 周期、冷却时长、跨指令延迟。
5. **边界条件**：重触发行为（SKIP / RESTART）、trigger_once、条件失败后的重试约束。

## 格式模板

```markdown
# 验收清单 — {{系统名}}

## 事件序列
- [ ] EnemyDie 触发 → 依次发出 ScoreUpdate(score=当前分) 与（敌数=0 时）AllEnemyDied
      （来源：game_flow.json binding b2）

## 变量终值
- [ ] PlayerDie 后 player_life 减 1；=0 走死亡分支，>0 走重生分支
      （来源：game_flow.json binding b3 的 IfElse 条件）

## 触发-效果对
- [ ] ...

## 时序约束
- [ ] ...

## 边界条件
- [ ] ...
```

## 度量
- 每个顶层 binding 至少产出 1 条触发-效果对断言
- 每个 SendEvent 至少出现在 1 条事件序列断言中
- 清单条数 = max(10, 指令数 / 3) 左右为宜——过少覆盖不足，过多稀释重点
