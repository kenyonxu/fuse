# Fuse user_docs 新增/合并指南规格说明（NEW_DOCS_SPEC）

> **用途：** 定义 `addons/fuse/docs/user_docs/guides/` 目录下待新增和合并的指南规格
> **状态：** 📋 计划中 | 创建日期：2026-07-07 | 维护：Fuse 开发团队

---

## 目录

1. [合并项 A：全局变量管理指南（覆盖管理 + 持久化）](#合并项-a全局变量管理指南覆盖管理--持久化)
2. [合并项 B：坐标系统概念 → 并入 transform-guide.md](#合并项-b坐标系统概念--并入-transform-guidemd)
3. [P0 新增项 A：Node Operations 指令指南](#p0a-node-operations-指令指南)
4. [P0 新增项 B：Lifecycle 事件指南](#p0b-lifecycle-事件指南)
5. [P1 新增项 A：Timing 事件指南](#p1a-timing-事件指南)
6. [P1 新增项 B：Node 事件指南](#p1b-node-事件指南)
7. [P1 新增项 C：Input 条件指南](#p1c-input-条件指南)
8. [P1 新增项 D：Node 条件指南](#p1d-node-条件指南)
9. [P1 新增项 E：Physics 条件指南](#p1e-physics-条件指南)
10. [P2 新增项 A：Animation 条件指南](#p2a-animation-条件指南)
11. [P2 新增项 B：Time 条件指南](#p2b-time-条件指南)
12. [P2 新增项 C：综合条件合集（9 小类合并）](#p2c-综合条件合集9-小类合并)

---

## 合并项 A：全局变量管理指南（覆盖管理 + 持久化）

### 状态

现有两份独立文档需要合并：

| 源文档 | 路径 | 行数 |
|--------|------|------|
| global_variable_manager_v2.md | `user_docs/guides/global_variable_manager_v2.md` | 533 |
| global-variable-persistence-guide.md | `user_docs/guides/global-variable-persistence-guide.md` | 214 |

### 目标读者

游戏开发者、游戏设计师，需要管理跨场景全局状态并实现存档/读档系统。

### 覆盖范围

覆盖 GlobalVariableManager 单例的完整使用（变量 CRUD、信号监听、调试）+
持久化系统（SaveGlobalVariables / LoadGlobalVariables 指令、GlobalVariableResource 资源文件、
GlobalVariableAssistant 自动存档）、最佳实践。

### 关键源文件

| 名称 | 源文件路径 |
|------|-----------|
| GlobalVariableManager（单例） | `addons/fuse/core/global_variables/global_variable_manager.gd` |
| SaveGlobalVariables（指令） | `addons/fuse/instructions/variables/save_global_variables.gd` |
| LoadGlobalVariables（指令） | `addons/fuse/instructions/variables/load_global_variables.gd` |
| GlobalVariableResource（资源） | `addons/fuse/core/global_variables/global_variable_resource.gd` |
| GlobalVariableAssistant（助手节点） | `addons/fuse/core/global_variables/global_variable_assistant.gd` |
| BaseVariable（基础变量类） | `addons/fuse/core/variables/base_variable.gd` |

### 章节大纲

| # | 章节 | 内容 | 来源 |
|---|------|------|------|
| 1 | 概述 | 全局变量的作用、管理+持久化整体架构 | 合并概述段 |
| 2 | 概念准备 | 三层变量系统简介（Local/Scope/Global） | `variable_system_guide.md` 中精简引用 |
| 3 | 快速开始 | 创建变量 → 设置值 → 保存 → 加载的完整流程 | 重写，融合两份文档的快速开始 |
| 4 | GlobalVariableManager 使用 | 单例模式、变量 CRUD、信号监听 | 从 `global_variable_manager_v2.md` 提取 |
| 5 | 持久化系统 | SaveGlobalVariables（保存目标/范围）、LoadGlobalVariables（加载来源） | 从 `persistence-guide.md` 提取并扩展 |
| 6 | GlobalVariableResource | 资源文件配置、持久化标记、自定义路径 | 合并 |
| 7 | GlobalVariableAssistant | 助手节点配置、自动保存、场景集成 | 从 `global_variable_manager_v2.md` 提取 |
| 8 | 完整示例 | 多存档槽位、自动保存、跨场景共享状态 | 合并 |
| 9 | 调试与监控 | get_debug_info()、get_statistics()、变量变化监听 | 从 `global_variable_manager_v2.md` 提取 |
| 10 | 最佳实践 | 命名规范、初始化模式、保存策略、性能优化 | 合并并精简 |
| 11 | 常见问题 | 文件不存在、路径错误、权限不足 | 从 `persistence-guide.md` 提取并扩展 |

### 预计行数：~500-600 行

### 合并后的文件名建议

`global-variables-guide.md`（删除 `global_variable_manager_v2.md` 和 `global-variable-persistence-guide.md`）

### 注意事项

- `global_variable_manager_v2.md` 中包含大量 GDScript API 示例（add_variable/get_variable 等），保留但精简
- `global-variable-persistence-guide.md` 中关于 `FusePoolManager`、`load_resource` 的章节保持独立
- 两层合并时注意去重概述段和示例节
- **删除** `global_variable_manager_v2.md` 中与持久化无关的冗余内容（如重复的 BaseVariable 创建示例）

---

## 合并项 B：坐标系统概念 → 并入 transform-guide.md

### 状态

| 源文档 | 路径 | 行数 | 处置 |
|--------|------|------|------|
| coordinate_systems_guide.md | `user_docs/guides/coordinate_systems_guide.md` | 284 | 合并到 transform-guide，删除源文件 |
| transform-guide.md | `user_docs/guides/transform-guide.md` | 64 | 接受前置章节 |
| movement-system-guide.md | `user_docs/guides/movement-system-guide.md` | 227 | 不动 |

### 目标读者

所有使用 Fuse 变换或移动指令的用户。

### 覆盖范围

Global/Local 坐标空间的概念讲解、决策树、最佳实践 → 作为 transform-guide.md 的"概念准备"
前置章节。movement-system-guide 已有独立的物理运动内容，不受影响。

### 章节大纲（transform-guide.md 新结构）

| # | 章节 | 内容 | 预计行数 |
|---|------|------|----------|
| 1 | 概念准备：坐标系统 | **(整体从 coordinate_systems_guide.md 移入)** | ~150 |
| 1.1 | Global（全局）坐标 | 定义、特点、使用场景 | |
| 1.2 | Local（局部）坐标 | 定义、特点、使用场景 | |
| 1.3 | 对比示例 | 层级示例、移动对比 | |
| 1.4 | 实际应用案例 | 武器系统、物品收集、平台游戏、载具 | |
| 1.5 | 常见陷阱 | 旋转混淆、嵌套父节点、混合使用 | |
| 1.6 | 决策树 | 坐标空间选择指南 | |
| 2 | 变换指令详解 | **(现有内容保留)** | ~60 |
| 3 | 常见用例 | **(现有内容保留 + 扩展)** | ~30 |

### 预计行数（合并后）：~350-400 行

### 合并后文件名

`transform-guide.md`（删除 `coordinate_systems_guide.md`）

### 注意事项

- 保留 `coordinate_systems_guide.md` 中"Godot 官方文档"的外部链接
- 删除 `coordinate_systems_guide.md` 中已有的死链（transform_instructions.md、3d_game_development.md）
- 合并后 transform-guide.md 的指令表格应引用前置章节的坐标概念
- movement-system-guide.md 不受影响，其内容不涉及坐标空间概念讲解

---

## P0-A：Node Operations 指令指南

### 目标读者

游戏设计师、关卡设计师，需要运行时操作节点树（克隆、查找、实例化、重父化、属性管理等）。

### 覆盖范围

`instructions/node_operations/` 目录下的 **21 个指令**，按功能分组覆盖：

1. **场景实例化**（3）：InstantiateScene、RecyclePooledScene、WarmUpPool
2. **节点查找与枚举**（7）：FindNode、GetAllChildren、GetAllChildrenPosition、GetChildByIndex、GetLastChild、GetRandomChild、GetChildCount
3. **组操作**（2）：GetNodesInGroup、GetGroupCount
4. **节点生命周期**（3）：CloneNode、QueueFreeNode、ReparentNode
5. **节点属性**（3）：SetPropertyValue、SetGlobalPosition、SetProcessMode
6. **节点控制**（2）：EnableDisableNode、EmitSignal
7. **高级操作**（1）：RunTargetNodeFunction

### 关键源文件

| 指令 | class_name | 源文件路径 |
|------|-----------|-----------|
| Clone Node | CloneNode | `instructions/node_operations/clone_node.gd` |
| Emit Signal | EmitSignal | `instructions/node_operations/emit_signal.gd` |
| Enable/Disable Node | EnableDisableNode | `instructions/node_operations/enable_disable_node.gd` |
| Find Node | FindNode | `instructions/node_operations/find_node.gd` |
| Get All Children | GetAllChildren | `instructions/node_operations/get_all_children.gd` |
| Get All Children Position | GetAllChildrenPosition | `instructions/node_operations/get_all_children_position.gd` |
| Get Child by Index | GetChildByIndex | `instructions/node_operations/get_child_by_index.gd` |
| Get Child Count | GetChildCount | `instructions/node_operations/get_child_count.gd` |
| Get Group Count | GetGroupCount | `instructions/node_operations/get_group_count.gd` |
| Get Last Child | GetLastChild | `instructions/node_operations/get_last_child.gd` |
| Get Nodes in Group | GetNodesInGroup | `instructions/node_operations/get_nodes_in_group.gd` |
| Get Random Child | GetRandomChild | `instructions/node_operations/get_random_child.gd` |
| Instantiate Scene | InstantiateScene | `instructions/node_operations/instantiate_scene.gd` |
| Queue Free Node | QueueFreeNode | `instructions/node_operations/queue_free_node.gd` |
| Recycle Pooled Scene | RecyclePooledScene | `instructions/node_operations/recycle_pooled_scene.gd` |
| Reparent Node | ReparentNode | `instructions/node_operations/reparent_node.gd` |
| Run Target Node Function | RunTargetNodeFunction | `instructions/node_operations/run_target_node_function.gd` |
| Set Global Position | SetGlobalPosition | `instructions/node_operations/set_global_position.gd` |
| Set Process Mode | SetProcessMode | `instructions/node_operations/set_process_mode.gd` |
| Set Property Value | SetPropertyValue | `instructions/node_operations/set_property_value.gd` |
| Warm Up Pool | WarmUpPool | `instructions/node_operations/warm_up_pool.gd` |

### 章节大纲

| # | 章节 | 内容 |
|---|------|------|
| 1 | 概述 | Node Operations 分类的整体作用和 21 个指令总览表 |
| 2 | 场景实例化 | InstantiateScene（场景路径/父节点/位置模式/对象池复用）、RecyclePooledScene、WarmUpPool 的详细参数说明 |
| 3 | 节点查找与枚举 | FindNode（SearchType/Scope/ErrorHandling 三种搜索维度）、GetAllChildren/Position、GetChildByIndex/Last/Random、GetChildCount |
| 4 | 组操作 | GetNodesInGroup（获取组中所有节点）、GetGroupCount |
| 5 | 节点生命周期 | CloneNode（源节点/父节点/变量保存）、QueueFreeNode、ReparentNode（保持全局变换） |
| 6 | 节点属性控制 | SetPropertyValue、SetGlobalPosition、SetProcessMode、EnableDisableNode |
| 7 | 节点通信 | EmitSignal 自定义信号发射 |
| 8 | 高级操作 | RunTargetNodeFunction（动态调用节点方法） |
| 9 | 常见用例 | 运行时动态创建敌人、场景切换时节点转移、批量查找子节点 |
| 10 | 注意事项 | 节点路径 vs 变量引用、实例化后延迟引用、组名大小写 |

### 预计行数：~500-600 行

### 参考风格

采用与 `transform-guide.md` 一致的指令功能表格式 + `scene-management-guide.md` 的用例编排方式。

---

## P0-B：Lifecycle 事件指南

### 目标读者

所有使用 Fuse 的用户，需要理解节点生命周期事件触发时机和性能影响。

### 覆盖范围

`events/lifecycle/` 目录下的 **7 个事件**：

| # | 事件 | class_name | 源文件路径 |
|---|------|-----------|-----------|
| 1 | OnReady | OnReady | `events/lifecycle/on_ready.gd` |
| 2 | OnProcess | OnProcess | `events/lifecycle/on_process.gd` |
| 3 | OnPhysicsProcess | OnPhysicsProcess | `events/lifecycle/on_physics_process.gd` |
| 4 | OnInterval | OnInterval | `events/lifecycle/on_interval.gd` |
| 5 | OnIntervalWithVariable | OnIntervalWithVariable | `events/lifecycle/on_interval_with_variable.gd` |
| 6 | OnEnterTree | OnEnterTree | `events/lifecycle/on_enter_tree.gd` |
| 7 | OnExitTree | OnExitTree | `events/lifecycle/on_exit_tree.gd` |

### 章节大纲

| # | 章节 | 内容 |
|---|------|------|
| 1 | 概述 | 生命周期事件的整体作用和 7 个事件总览表（含触发时机与性能影响等级） |
| 2 | 一次性触发事件 | OnReady（delay_seconds 参数、场景就绪后触发）、OnEnterTree（tree_entered 信号）、OnExitTree（cleanup_resources 参数） |
| 3 | 帧循环事件 | OnProcess（每帧触发、execution_interval 控制频率、⚠️性能影响极高）、OnPhysicsProcess（每物理帧、execution_interval） |
| 4 | 间隔执行事件 | OnInterval（interval_seconds/max_repeats/auto_start/trigger_on_start）、OnIntervalWithVariable（从变量动态读取间隔值、最小间隔保护 0.033s） |
| 5 | 性能分级建议 | 性能影响分级表：OnReady(低) < OnInterval(中) < OnProcess/OnPhysicsProcess(高) |
| 6 | 常见用例 | 初始化逻辑（OnReady）、持续检测（OnProcess 带间隔）、物理帧同步更新（OnPhysicsProcess+MoveCharacterBody） |
| 7 | 注意事项 | OnProcess 性能警告、PhysicsProcess 默认帧率 60FPS、OnExitTree 时资源清理 |

### 预计行数：~250-300 行

### 参考风格

采用与 `input-events-guide.md` 一致的事件表格分组的风格（分组展示、按触发时机分类）。

---

## P1-A：Timing 事件指南

### 目标读者

需要时间相关事件触发的游戏设计师（定时器、冷却、倒计时、现实时间）。

### 覆盖范围

`events/timing/` 目录下的 **4 个事件**：

| # | 事件 | class_name | 源文件路径 |
|---|------|-----------|-----------|
| 1 | OnTimer | OnTimer | `events/timing/on_timer.gd` |
| 2 | OnCooldownFinished | OnCooldownFinished | `events/timing/on_cooldown_finished.gd` |
| 3 | OnCountdown | OnCountdown | `events/timing/on_countdown.gd` |
| 4 | OnRealtime | OnRealtime | `events/timing/on_realtime.gd` |

### 章节大纲

| # | 章节 | 内容 |
|---|------|------|
| 1 | 概述 | 4 个时间事件的关系与适用场景对比表 |
| 2 | OnTimer（定时器） | wait_time/autostart/repeat_count（0=无限）、周期性任务 |
| 3 | OnCooldownFinished（冷却完成） | cooldown_seconds/manual_trigger/show_progress、技能冷却监听 |
| 4 | OnCountdown（倒计时） | countdown_seconds/auto_start/show_remaining_time/update_interval、进度更新 |
| 5 | OnRealtime（现实时间） | interval_seconds/max_triggers/emit_timestamp、不受 time_scale 影响 |
| 6 | 事件对比 | 时间尺度（游戏时间 vs 现实时间）、触发模式（单次 vs 重复）、适用场景 |
| 7 | 常见用例 | 技能冷却管理（OnCooldownFinished）、关卡倒计时（OnCountdown）、每日任务刷新（OnRealtime） |
| 8 | 注意事项 | OnRealtime 不受 time_scale/pause 影响、Cooldown 的 manual_trigger 模式、Timer 节点的 Godot 生命周期 |

### 预计行数：~200-250 行

### 参考风格

表格对比 + 文字详解 + 用例伪代码（类似 `input-events-guide.md` 的格式）。

---

## P1-B：Node 事件指南

### 目标读者

需要监听节点状态变化或信号触发的用户（属性变化、信号转发、场景实例化）。

### 覆盖范围

`events/node/` 目录下的 **4 个事件**：

| # | 事件 | class_name | 源文件路径 |
|---|------|-----------|-----------|
| 1 | OnPropertyChanged | OnPropertyChanged | `events/node/on_property_changed.gd` |
| 2 | OnSignalFromGroup | OnSignalFromGroup | `events/node/on_signal_from_group.gd` |
| 3 | OnTargetSignalEmit | OnTargetSignalEmit | `events/node/on_target_signal_emit.gd` |
| 4 | OnNodeInstance | OnNodeInstance | `events/node/on_node_instance.gd` |

### 章节大纲

| # | 章节 | 内容 |
|---|------|------|
| 1 | 概述 | 4 个节点事件的触发方式对比 |
| 2 | OnPropertyChanged（属性变化） | target_node/property_name/check_interval/emit_old_and_new |
| 3 | OnSignalFromGroup（组信号） | signal_name/group_name/emit_node/emit_signal_name、组内任意节点发射信号 |
| 4 | OnTargetSignalEmit（目标信号） | target_node/target_signal、编辑器中的信号缓存自动刷新 |
| 5 | OnNodeInstance（节点实例化） | scene_path/parent_node/emit_instance、场景实例化时触发 |
| 6 | 常见用例 | 监听血量变化触发 UI（OnPropertyChanged）、组内任意敌人死亡事件（OnSignalFromGroup）、场景预加载完成触发（OnNodeInstance） |
| 7 | 注意事项 | OnPropertyChanged 是轮询模式（check_interval），非信号绑定；OnTargetSignalEmit 需要目标节点有对应信号 |

### 预计行数：~200-250 行

---

## P1-C：Input 条件指南

### 目标读者

需要条件式判断输入状态而非事件驱动的用户（在 Trigger 条件中使用输入检测）。

### 覆盖范围

`conditions/input/` 目录下的 **6 个条件**：

| # | 条件 | class_name | 源文件路径 |
|---|------|-----------|-----------|
| 1 | CheckInputPressed | CheckInputPressed | `conditions/input/check_input_pressed.gd` |
| 2 | CheckInputHeld | CheckInputHeld | `conditions/input/check_input_held.gd` |
| 3 | CheckInputReleased | CheckInputReleased | `conditions/input/check_input_released.gd` |
| 4 | CheckInputDirection | CheckInputDirection | `conditions/input/check_input_direction.gd` |
| 5 | CheckInputMagnitude | CheckInputMagnitude | `conditions/input/check_input_magnitude.gd` |
| 6 | CheckAnyInput | CheckAnyInput | `conditions/input/check_any_input.gd` |

### 章节大纲

| # | 章节 | 内容 |
|---|------|------|
| 1 | 概述 | Input 条件 vs 输入事件的区别（条件用于判断，事件用于触发）、6 条件总览 |
| 2 | 三态检测 | CheckInputPressed（按下瞬间）、CheckInputHeld（按住中）、CheckInputReleased（释放瞬间） |
| 3 | 方向与幅度 | CheckInputDirection（摇杆/键盘方向向量）、CheckInputMagnitude（输入力度大小） |
| 4 | 任意输入 | CheckAnyInput（检测是否有任何输入动作被触发） |
| 5 | 常见用例 | 按住蓄力攻击（Held）、双击检测（Pressed+Countdown）、摇杆灵敏度判断（Magnitude） |
| 6 | 与 OnInputAction 的协作 | 事件+条件的组合用法，条件用于分支判断 |

### 预计行数：~150-200 行

---

## P1-D：Node 条件指南

### 目标读者

需要在条件判断中查询节点状态的用户（存在性、活动状态、组归属、属性值等）。

### 覆盖范围

`conditions/node/` 目录下的 **9 个条件**：

| # | 条件 | class_name | 源文件路径 |
|---|------|-----------|-----------|
| 1 | CheckNodeExists | CheckNodeExists | `conditions/node/check_node_exists.gd` |
| 2 | CheckNodeActive | CheckNodeActive | `conditions/node/check_node_active.gd` |
| 3 | CheckNodeInGroup | CheckNodeInGroup | `conditions/node/check_node_in_group.gd` |
| 4 | CheckNodeProperty | CheckNodeProperty | `conditions/node/check_node_property.gd` |
| 5 | CheckDirection | CheckDirection | `conditions/node/check_direction.gd` |
| 6 | CheckFacingDirection | CheckFacingDirection | `conditions/node/check_facing_direction.gd` |
| 7 | CheckIsChildOf | CheckIsChildOf | `conditions/node/check_is_child_of.gd` |
| 8 | CheckChildCount | CheckChildCount | `conditions/node/check_child_count.gd` |
| 9 | CheckGroupCount | CheckGroupCount | `conditions/node/check_group_count.gd` |

### 章节大纲

| # | 章节 | 内容 |
|---|------|------|
| 1 | 概述 | 9 个节点条件的功能分类：存在性检测、状态检测、层级关系、方位检测 |
| 2 | 存在与状态 | CheckNodeExists（节点是否存在）、CheckNodeActive（是否启用/禁用） |
| 3 | 组与属性 | CheckNodeInGroup（是否在指定组）、CheckNodeProperty（属性值比较）、CheckGroupCount（组内节点数量） |
| 4 | 层次关系 | CheckIsChildOf（是否是指定节点的子节点）、CheckChildCount（子节点数量） |
| 5 | 方位检测 | CheckDirection（节点相对于目标的方向）、CheckFacingDirection（节点是否朝向目标） |
| 6 | 常见用例 | 检查武器是否存在再攻击（Exists+Property）、判断 Boss 阶段的组人数（GroupCount）、双面角色朝向（FacingDirection） |

### 预计行数：~200-250 行

---

## P1-E：Physics 条件指南

### 目标读者

使用 CharacterBody 的游戏开发者，需要在条件分支中判断物理状态。

### 覆盖范围

`conditions/physics/` 目录下的 **7 个条件**：

| # | 条件 | class_name | 源文件路径 |
|---|------|-----------|-----------|
| 1 | CheckOnFloor | CheckOnFloor | `conditions/physics/check_on_floor.gd` |
| 2 | CheckOnWall | CheckOnWall | `conditions/physics/check_on_wall.gd` |
| 3 | CheckInAir | CheckInAir | `conditions/physics/check_in_air.gd` |
| 4 | CheckIsFalling | CheckIsFalling | `conditions/physics/check_is_falling.gd` |
| 5 | CheckVelocity | CheckVelocity | `conditions/physics/check_velocity.gd` |
| 6 | CheckSlope | CheckSlope | `conditions/physics/check_slope.gd` |
| 7 | CheckOverlapArea | CheckOverlapArea | `conditions/physics/check_overlap_area.gd` |

### 章节大纲

| # | 章节 | 内容 |
|---|------|------|
| 1 | 概述 | 7 个物理条件的功能总览、与 CharacterBody 的关系 |
| 2 | 地面/墙壁/空中 | CheckOnFloor（`is_on_floor()`）、CheckOnWall（`is_on_wall()`）、CheckInAir（不在墙不在面） |
| 3 | 下落与速度 | CheckIsFalling（垂直速度 < 阈值）、CheckVelocity（速度向量/标量比较） |
| 4 | 斜坡与区域 | CheckSlope（斜坡角度比较）、CheckOverlapArea（Area 重叠检测） |
| 5 | 常见用例 | 跳跃判定（OnFloor）、二段跳（InAir+Velocity）、攀墙（OnWall）、滑铲检测（Slope 角度） |
| 6 | 注意事项 | CheckInAir 与 CheckIsFalling 的区别（空中未必下落）、CheckOverlapArea 需要 Area 类型节点 |

### 预计行数：~180-230 行

---

## P2-A：Animation 条件指南

### 目标读者

使用动画系统的用户，需要在条件分支中判断动画状态。

### 覆盖范围

`conditions/animation/` 目录下的 **5 个条件**：

| # | 条件 | class_name | 源文件路径 |
|---|------|-----------|-----------|
| 1 | CheckIsPlaying | CheckIsPlaying | `conditions/animation/check_is_playing.gd` |
| 2 | CheckAnimationFinished | CheckAnimationFinished | `conditions/animation/check_animation_finished.gd` |
| 3 | CheckIsAnimation | CheckIsAnimation | `conditions/animation/check_is_animation.gd` |
| 4 | CheckAnimationTreeState | CheckAnimationTreeState | `conditions/animation/check_animation_tree_state.gd` |
| 5 | CheckAnimationTreeParameter | CheckAnimationTreeParameter | `conditions/animation/check_animation_tree_parameter.gd` |

### 章节大纲

| # | 章节 | 内容 |
|---|------|------|
| 1 | 概述 | 5 个动画条件分类：播放状态 / AnimationTree 状态 |
| 2 | 播放状态判断 | CheckIsPlaying（当前是否在播放动画）、CheckIsAnimation（当前播放的是否指定动画）、CheckAnimationFinished（指定动画是否播放完成） |
| 3 | AnimationTree 集成 | CheckAnimationTreeState（状态机状态检查）、CheckAnimationTreeParameter（参数检查，如 blend position） |
| 4 | 常见用例 | 攻击动画播放完后才能移动（Finished）、根据动画状态切换技能（IsAnimation）、AnimationTree 状态机驱动 AI 行为 |
| 5 | 注意事项 | AnimationTree 条件需要 AnimationTree 节点；IsAnimation 需要 AnimationPlayer |

### 预计行数：~120-160 行

---

## P2-B：Time 条件指南

### 目标读者

需要在流程控制中判断游戏内时间的用户（时间到达、时间段判断、倒计时结束）。

### 覆盖范围

`conditions/time/` 目录下的 **4 个条件**：

| # | 条件 | class_name | 源文件路径 |
|---|------|-----------|-----------|
| 1 | CheckTimeReached | CheckTimeReached | `conditions/time/check_time_reached.gd` |
| 2 | CheckTimeRange | CheckTimeRange | `conditions/time/check_time_range.gd` |
| 3 | CheckCountdownFinished | CheckCountdownFinished | `conditions/time/check_countdown_finished.gd` |
| 4 | CheckGameTime | CheckGameTime | `conditions/time/check_game_time.gd` |

### 章节大纲

| # | 章节 | 内容 |
|---|------|------|
| 1 | 概述 | 4 个时间条件的作用与适用场景 |
| 2 | 时间点与时间段 | CheckTimeReached（是否到达指定时间点）、CheckTimeRange（是否在指定时间段内） |
| 3 | 倒计时与游戏时间 | CheckCountdownFinished（倒计时是否已结束）、CheckGameTime（游戏运行时间比较） |
| 4 | 常见用例 | 限制战斗时长（TimeReached）、日夜循环逻辑（TimeRange）、技能冷却中判断（CountdownFinished）、游戏限时模式（GameTime） |
| 5 | 注意事项 | 游戏时间 vs 现实时间区别、倒计时需要对应 OnCountdown 事件配合 |

### 预计行数：~120-160 行

---

## P2-C：综合条件合集（9 小类合并）

### 目标读者

需要特定领域条件判断（距离、数学、导航、渲染、作用域、字符串、系统、场景、UI）的用户。

### 覆盖范围

将多个小型条件类别合并为单篇指南，共 **9 个小类、14 个条件**：

| 小类 | 条件数 | 条件名称 | 源文件路径 |
|------|--------|---------|-----------|
| **distance** | 1 | CheckDistance | `conditions/distance/check_distance.gd` |
| **math** | 1 | ExpressionCondition | `conditions/math/expression_condition.gd` |
| **navigation** | 1 | CheckPathAvailable | `conditions/navigation/check_path_available.gd` |
| **rendering** | 1 | CheckIsOnScreen | `conditions/rendering/check_is_on_screen.gd` |
| **scope** | 1 | CheckScopeVariable | `conditions/scope/check_scope_variable.gd` |
| **string** | 2 | CheckStringContains、CheckStringLength | `conditions/string/check_string_*.gd` |
| **system** | 2 | CheckFrameRate、CheckPlatform | `conditions/system/check_*.gd` |
| **scene** | 1 | CheckPreloadStatus | `conditions/scene/check_preload_status.gd` |
| **ui** | 1 | CheckUIVisible | `conditions/ui/check_ui_visible.gd` |

以及 `variable` 类别中的非核心条件（核心变量比较已在 `variable_system_guide.md` 覆盖）：

| 补充 | 条件数 | 条件名称 |
|------|--------|---------|
| variable 补充 | 2 | CheckVector2VariableAxis、CheckHealthValue、CompareHealthThreshold |

### 章节大纲

| # | 章节 | 小类 | 内容 |
|---|------|------|------|
| 1 | 概述 | — | 9 小类条件总览，指明各小类的适用场景 |
| 2 | 距离与导航 | distance / navigation | CheckDistance（两点距离比较）、CheckPathAvailable（导航路径可用性） |
| 3 | 数学表达式 | math | ExpressionCondition（使用 GDScript Expression 评估布尔条件） |
| 4 | 渲染与 UI | rendering / ui | CheckIsOnScreen（可见性）、CheckUIVisible（UI 元素可见性） |
| 5 | 作用域与变量 | scope / variable | CheckScopeVariable（作用域变量值检测）、CheckVector2VariableAxis（Vector2 轴提取）、CheckHealthValue（生命值比较） |
| 6 | 字符串 | string | CheckStringContains（包含子串）、CheckStringLength（长度比较） |
| 7 | 系统与场景 | system / scene | CheckFrameRate（帧率阈值）、CheckPlatform（运行时平台判断）、CheckPreloadStatus（预加载状态） |

### 预计行数：~250-300 行

### 注意事项

- 各小类之间用标题层级区分，避免信息密度过大
- 条件数较少（每类 1-2 个），无需为每类单独成篇
- 以距离、导航、渲染、UI 等"补充型条件"的 quick reference 定位
- 与 `animation-guide.md`、`physics-guide.md` 等大类的条件指南不重复：`variable` 类只取 CheckHealthValue 等补充条件，核心 CompareVariable 已在 `variable_system_guide.md` 覆盖
- `conditions/composite/` 已有 `composite-conditions-guide.md` 独立文档，不纳入此合集

---

## 执行顺序

```
Phase 1（合并项 → 清理现状）
  ├── 1. 合并 A：global-variables-guide.md（覆盖管理+持久化）
  └── 2. 合并 B：坐标系统概念并入 transform-guide.md

Phase 2（P0 核心新增 → 覆盖高需求主题）
  ├── 3. Node Operations 指令指南 (21指令)
  └── 4. Lifecycle 事件指南 (7事件)

Phase 3（P1 重要新增 → 补齐事件和条件系列）
  ├── 5. Timing 事件指南 (4)
  ├── 6. Node 事件指南 (4)
  ├── 7. Input 条件指南 (6)
  ├── 8. Node 条件指南 (9)
  └── 9. Physics 条件指南 (7)

Phase 4（P2 补充新增 → 锦上添花）
  ├── 10. Animation 条件指南 (5)
  ├── 11. Time 条件指南 (4)
  └── 12. 综合条件合集 (14条件/9小类)
```

---

## 去重检查清单

每篇新指南需确认不与以下现有文档重叠：

| 现有文档 | 已有内容 | 新文档不重复的范围 |
|---------|---------|------------------|
| `physics-guide.md` | 5 物理指令 + 10 物理事件 | P1-E 只有物理**条件**（7个），不重复指令/事件 |
| `input-events-guide.md` | 12 输入事件 | P1-C 只有输入**条件**（6个），不重复事件 |
| `animation-guide.md` | 动画指令 | P2-A 只有动画**条件**（5个），不重复指令 |
| `variable_system_guide.md` | 三层变量系统 | 合并 A 只覆盖 GlobalVariableManager 和持久化，不重复变量基础概念 |
| `composite-conditions-guide.md` | 4 组合条件 | P2-C 不包含 composite/ 目录的条件 |
| `transform-guide.md` | 7 变换指令 | P0-A 不包含 transform/ 目录的指令 |

---

## 附录：完整组件索引

### Instructions（全部 120+）

- `animation/` — 9 指令（已有 `animation-guide.md`）
- `arrays/` — 17 指令（已有 `array-operations-guide.md`）
- `audio/` — 8 指令（已有 `audio-guide.md`）
- `camera/` — 6 指令（已有 `camera-guide.md`）
- `debug/` — 3 指令（已有 `debugging-guide.md`、`breakpoint-guide.md`）
- `dictionaries/` — 17 指令（已有 `dictionary-operations-guide.md`）
- `event/` — 1 指令（引用 `event_bus_guide.md`）
- `flow_control/` — 12 指令（已有 `flow-control-guide.md`）
- `math/` — 8 指令（已有 `math-vector-guide.md`、`expression-guide.md`）
- `movement/` — 1 指令（已有 `movement-system-guide.md`）
- `navigation/` — 1 指令（P2-C 中涉及）
- `node_operations/` — **21 指令（P0-A 待新增）**
- `physics/` — 9 指令（已有 `physics-guide.md`）
- `rendering/` — 5 指令
- `scene/` — 5 指令（已有 `scene-management-guide.md`、`scene-preloading-guide.md`）
- `string/` — 6 指令
- `system/` — 3 指令
- `time/` — 2 指令
- `transform/` — 7 指令（已有 `transform-guide.md`）
- `tween/` — 14 指令（已有 `tween-animation-guide.md`）
- `ui/` — 6 指令（已有 `ui-guide.md`）
- `variables/` — 9 指令（已有 `variable_system_guide.md` + 合并 A）

### Events（全部 60+）

- `animation/` — 6 事件（已有 `animation-guide.md`）
- `audio/` — 4 事件（已有 `audio-guide.md`）
- `event/` — 1 事件（已有 `event_bus_guide.md`）
- `gameplay/` — 2 事件
- `input/` — 12 事件（已有 `input-events-guide.md`）
- `lifecycle/` — **7 事件（P0-B 待新增）**
- `navigation/` — 1 事件
- `node/` — **4 事件（P1-B 待新增）**
- `physics/` — 10 事件（已有 `physics-guide.md`）
- `scene/` — 4 事件（已有 `scene-management-guide.md`）
- `timing/` — **4 事件（P1-A 待新增）**
- `tween/` — 1 事件（已有 `tween-animation-guide.md`）
- `ui/` — 7 事件（已有 `ui-guide.md`）
- `variable/` — 1 事件（已有 `variable_system_guide.md`）

### Conditions（全部 50+）

- `animation/` — **5 条件（P2-A 待新增）**
- `arrays/` — 2 条件（已有 `array-operations-guide.md`）
- `composite/` — 4 条件（已有 `composite-conditions-guide.md`）
- `dictionaries/` — 2 条件（已有 `dictionary-operations-guide.md`）
- `distance/` — 1 条件（→ P2-C 综合合集）
- `input/` — **6 条件（P1-C 待新增）**
- `math/` — 1 条件（→ P2-C 综合合集）
- `navigation/` — 1 条件（→ P2-C 综合合集）
- `node/` — **9 条件（P1-D 待新增）**
- `physics/` — **7 条件（P1-E 待新增）**
- `rendering/` — 1 条件（→ P2-C 综合合集）
- `scene/` — 1 条件（→ P2-C 综合合集）
- `scope/` — 1 条件（→ P2-C 综合合集）
- `string/` — 2 条件（→ P2-C 综合合集）
- `system/` — 2 条件（→ P2-C 综合合集）
- `time/` — **4 条件（P2-B 待新增）**
- `ui/` — 1 条件（→ P2-C 综合合集）
- `variable/` — 5 条件（部分在 `variable_system_guide.md`，剩余 → P2-C 综合合集）

---

**文档版本**: 1.0
**最后更新**: 2026-07-07
**作者**: Fuse 开发团队
