# 验收清单 — game_flow

> 来源：`presets/game_flow.json`（下称 preset，5 个 binding，顶层指令 28 条、含嵌套共 40 条）
> 与 `system.json`。枚举值以 `components.json` 各组件 schema 的 hint 序为准，本文已直译。
> 交付前逐条核对，对每条标注"已实现 / 不适用（附原因）"。

## 事件序列
- [ ] EnemyDie 触发 → 依次发出 ScoreUpdate 与（敌数 < 1 时）AllEnemyDied：ScoreUpdate 的参数
      `score = $c_score`，`$c_score` 解析自 local 变量 c_score 当前值（= scope current_score 的本次累加结果）；
      AllEnemyDied 无参数。两次发送均为同步派发（SendEvent deferred=false）
      （来源：preset event_bindings[2] 第 4 条 SendEvent + 嵌套 IfThen 内 SendEvent）
- [ ] PlayerDie 死亡分支（player_life 减 1 后 < 0）→ 若 current_score > 0 先把 current_score 追加进
      global 数组 score_list，随后发出 GameEnd(end="loss")
      （来源：preset event_bindings[3] IfElse true 分支：嵌套 IfThen + SendEvent）
- [ ] PlayerDie 重生分支（player_life ≥ 0）→ 依次发出 StartCountDown（无参数）→ 等 2.0s →
      在 start_pos（scope 变量）处实例化 player_ship.tscn → 等 1.0s → ResumeGame
      （来源：preset event_bindings[3] IfElse false 分支 5 条指令）
- [ ] AllEnemyDied 触发 → current_wave 加 1；若 current_wave ≤ 3 则推进下一波（无事件），
      否则发出 GameEnd(end="win")
      （来源：preset event_bindings[4]）

## 变量终值
- [ ] OnReady：current_wave（scope）+ 1；start_pos（scope）= Game_Layer/PlayerShip 的全局位置；
      spawn_pos（scope）= Game_Layer/Markers 全部子节点的全局位置数组（recursive=false）
      （来源：preset event_bindings[1] 第 3/4/5 条）
- [ ] EnemyDie：enemy_count（scope）- 1；current_score（scope）+ event_score（local，事件参数注入值）；
      c_score（local）← current_score（scope 复制）
      （来源：preset event_bindings[2] 前 3 条：MathOperation×2 + SetVariable）
- [ ] PlayerDie：player_life（scope）- 1（写入先于 0.5s 等待与分支判断）
      （来源：preset event_bindings[3] 首条 MathOperation，operation_type=Subtract）
- [ ] AllEnemyDied：current_wave（scope）+ 1（判断"≤ 3"使用加 1 后的新值）
      （来源：preset event_bindings[4] 首条 MathOperation + IfElse 条件）
- [ ] 死亡分支且 current_score > 0：score_list（global 层数组）追加 current_score（scope 当前值）
      （来源：preset event_bindings[3] 嵌套 IfThen 内 ArrayAdd，array_scope=GLOBAL）

## 触发-效果对
- [ ] b0 OnInterval（51s 周期、自动开始、立即触发、无限重复）→ CrossfadeToMusic：向 Music 总线
      交叉淡入淡出到背景音乐（uid://bi1lb4nvpv6gn），crossfade 2.0s，暂停期间继续播放
      （来源：preset event_bindings[0]）
- [ ] b1 OnReady（delay 0）→ LoadGlobalVariables（从助手资源读档）→ PauseGame（仅暂停，
      UI 节点 ../../GameSceneCanvas 设为暂停时运行）→ 记录 start_pos → current_wave+1 →
      收集 spawn_pos → 预热 8 个对象池 → 等 0.1s → 运行 ../SpawnEnemy 并等待其完成
      （来源：preset event_bindings[1]，15 条顶层指令）
- [ ] b2 OnReceiveEvent EnemyDie（参数存 local，前缀 event_）→ 扣敌数 → 加分 → 复制 c_score →
      发 ScoreUpdate → 敌数 < 1 时发 AllEnemyDied
      （来源：preset event_bindings[2]）
- [ ] b3 OnReceiveEvent PlayerDie → 扣命 → 等 0.5s → PauseGame → 等 0.1s →
      player_life < 0 走死亡结算分支，否则走重生分支
      （来源：preset event_bindings[3]）
- [ ] b4 OnReceiveEvent AllEnemyDied（不存事件参数）→ 波次 +1 → 波次 ≤ 3：PauseGame 后调用
      ../SpawnEnemy（不等待完成）；波次 > 3：GameEnd(win)
      （来源：preset event_bindings[4]）

## 时序约束
- [ ] b1 链内：8 个池预热完成后再等 0.1s 才运行 ../SpawnEnemy，且 wait_for_completion=true
      （等待 SpawnEnemy 整链跑完才算 b1 结束）
      （来源：preset event_bindings[1] 倒数第 2/1 条）
- [ ] b3 等待链：扣命后 0.5s → 暂停 → 0.1s → 分支；重生分支内 StartCountDown 后 2.0s 实例化、
      实例化后 1.0s 才恢复游戏——四段等待必须保持先后与时长
      （来源：preset event_bindings[3] 各 Wait 指令）
- [ ] b0 周期 = interval_seconds 51.0s，trigger_on_start=true（启动即先触发一次），max_repeats=0
      （无限重复）；注意 topology.json 快照显示源场景当前为 25.0s，本清单按 preset 51.0s 断言，
      差异说明见 README-for-agent.md「已知数据差异」
      （来源：preset event_bindings[0].event）

## 边界条件
- [ ] 全部 5 个 binding 的 binding_config 均为 cooldown_mode=NONE、cooldown_time=1.0、
      trigger_once=false：无冷却与一次性消耗约束；但等价实现仍须满足 semantics.md §2 的
      通用门控语义（若后续配置了冷却）
      （来源：preset 各 event_bindings[i].binding_config）
- [ ] b0 源配 RESTART（源场景校验告警 W_RESTART_DEGRADED 证实；preset 导出不携带该字段）：
      51s 到点时若上一轮 CrossfadeToMusic 仍在执行，源行为为取消上一轮并重启，且取消推迟到
      条件检查通过之后、新一轮帧末启动（semantics.md §1）；实现为 SKIP 须在交付说明中标注差异
      （来源：打包时 system 校验输出 + semantics.md §1）
- [ ] b1–b4 重触发为默认 SKIP：上一轮未结束时同类事件再触发被忽略；b3 含长等待链（约 3.6s+），
      SKIP 语义对连续 PlayerDie 的行为影响需与源一致
      （来源：semantics.md §1 默认行为；preset 无 RESTART 配置）
- [ ] 事件参数注入差异：b2/b3 的 OnReceiveEvent store_args_to_local=true 且前缀 event_
      （EnemyDie 的 score → event_score；PlayerDie 参数同规则）；b4 store_args_to_local=false
      不注入任何 event_* 变量
      （来源：preset event_bindings[2][3][4].event）
- [ ] 条件算子（comparison_operator，按 components.json CheckVariable schema hint 序
      Equals:0/Not Equals:1/Greater Than:2/Less Than:3/Greater Equal:4/Less Equal:5）：
      b2 用 enemy_count < 1（LESS_THAN）；b3 外层用 player_life < 0（LESS_THAN）、内层用
      current_score > 0（GREATER_THAN）；b4 用 current_wave ≤ 3（LESS_EQUAL）——均为 scope 层
      变量与常量比较、auto_convert_types=true
      （来源：preset 各嵌套 condition）
