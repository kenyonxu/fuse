# Fuse Instruction 开发路线图

**创建日期:** 2026-01-24
**Godot 版本:** 4.5
**系统状态:** 活跃开发中

## 概述

本文档定义了 Fuse 可视化编程系统后续可开发的 Instruction（指令）列表。这些指令基于常见 Godot 游戏开发需求，按功能类别组织，涵盖各类游戏开发场景。

**当前已实现的指令（11 个）：**
- create_variable, set_variable, set_int_variable, print_variable_value
- set_property_value, run_target_node_function
- wait, count, run_condition_check
- print, quit

**Phase 0-1 已完成的指令（23 个）：**
- ✅ Set Position, For Loop, If/Else, Find Node（Phase 0A）
- ✅ Enable/Disable Node, Queue Free Node, Instantiate Scene（Phase 0B）
- ✅ Change Scene, Set Rotation, Set Scale, Look At（Phase 1A）
- ✅ Play Sound, Stop Audio, Set Audio Volume, Play Music, Pause/Resume Audio（Phase 1B）
- ✅ Break Loop, Continue Loop, Wait Until（Phase 1C）
- ✅ Move By, Rotate By（Phase 1D）
- ✅ Wait（已在早期完成，从 Phase 2 移除）

**计划开发指令总数:** 约 80+

## 开发优先级说明

本文档专注于指令的功能规格说明。关于开发优先级的评估和排序，请参考最新的评估报告：

- **[Instruction 评估报告 v2](./2026-01-26-instruction-evaluation-report-v2.md)** - 使用6维评估体系（需求频率、即用性、复杂度、学习曲线、性能影响、依赖性）对所有指令进行优先级排序
- **[评估框架文档](./2026-01-26-fuse-evaluation-framework.md)** - 评估体系的完整说明

**关键发现（基于评估报告 v2）：**
- **P0 级（核心基础）**：Set Position、For Loop、If/Else、Find Node - 必须首先开发
- **P1 级（高优先级）**：Enable/Disable Node、Queue Free Node、Change Scene、Instantiate Scene 等
- **P2 级（中优先级）**：Break Loop、Continue Loop、Move By、Rotate By 等
- 依赖关系已正确处理：基础功能评分高于依赖功能（如 For Loop > Break Loop）

---

## 一、节点操作类

控制场景中节点生命周期的核心指令。

### 1.1 Instantiate Scene（实例化场景）✅ **已完成（Phase 0B）**

**功能描述：** 动态加载并实例化场景文件

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| scene_path | String | 场景文件路径 |
| parent_node | NodePath | 父节点路径（可选） |
| save_instance_id | bool | 是否保存实例 ID 到变量 |
| target_variable | String | 保存实例 ID 的变量名 |
| variable_scope | Enum | Local/Global 变量作用域 |

**使用场景：** 生成敌人、子弹、道具等动态对象

**实现要点：**
- 使用 `load()` 和 `instantiate()` 加载场景
- 支持 PackedScene 预加载优化
- 处理节点路径解析（相对/绝对）
- 自动处理父节点附加

**相关指令：** Queue Free Node, Find Node

---

### 1.2 Queue Free Node（释放节点）✅ **已完成（Phase 0B）**

**功能描述：** 延迟释放指定节点

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点路径 |
| delay | float | 延迟时间（秒） |

**使用场景：** 销毁敌人、清理临时对象

**实现要点：**
- 使用 `call_deferred("queue_free")` 安全释放
- 延迟释放使用 SceneTreeTimer
- 检查节点有效性

---

### 1.3 Reparent Node（重新设置父节点）✅ **已完成（Phase 2C）**

**功能描述：** 将节点从一个父节点移动到另一个父节点

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| new_parent | NodePath | 新父节点 |
| keep_global_transform | bool | 保持全局变换 |

**使用场景：** 拾取物品、角色切换场景

**实现要点：**
- 使用 `reparent()` 方法（Godot 4.2+）
- 变换保持逻辑
- 处理 null 父节点（移到场景根）

---

### 1.4 Enable/Disable Node（启用/禁用节点）✅ **已完成（Phase 0B）**

**功能描述：** 设置节点的处理模式或可见性

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| enable | bool | 启用或禁用 |
| mode | Enum | Processing/Visible |

**使用场景：** 暂停游戏逻辑、隐藏 UI

**实现要点：**
- Processing 模式：设置 `process_mode`
- Visible 模式：设置 `visible` 属性
- 区分 CanvasItem 和 Node

---

### 1.5 Find Node（查找节点）✅ **已完成（Phase 0A）**

**功能描述：** 按名称、类型或组查找节点，并保存到变量

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| search_type | Enum | ByName/ByType/ByGroup |
| search_value | String | 搜索值 |
| target_variable | String | 保存结果的变量名 |
| variable_scope | Enum | Local/Global |
| search_scope | Enum | Children/Scene/Global |

**使用场景：** 动态查找游戏对象

**实现要点：**
- ByName: 使用 `find_child()`
- ByType: 遍历节点检查 `get_class()`
- ByGroup: 使用 `get_tree().get_nodes_in_group()`
- 保存节点路径到变量

---

## 二、变换操作类

控制节点位置、旋转、缩放的指令。

### 2.1 Set Position（设置位置）✅ **已完成（Phase 0A）**

**功能描述：** 设置节点的全局或局部位置

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| position | Vector2/Vector3 | 目标位置 |
| space | Enum | Global/Local |
| use_variable | bool | 是否使用变量 |
| position_variable | String | 位置变量名 |

**使用场景：** 传送角色、放置物品

**实现要点：**
- 根据 space 选择 `global_position` 或 `position`
- 支持变量模式
- 自动检测 2D/3D 节点类型

---

### 2.2 Move By（相对移动）✅ **已完成（Phase 1D）**

**功能描述：** 相对于当前位置移动节点，支持动画

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| offset | Vector2/Vector3 | 移动偏移量 |
| duration | float | 移动持续时间（秒） |
| easing | Enum | 缓动类型 |
| use_process | bool | 是否使用 _process 而非 tween |

**使用场景：** 平滑移动、冲刺效果

**实现要点：**
- duration = 0 时瞬时移动
- duration > 0 时使用 Tween 或手动插值
- 支持多种缓动类型（Linear、EaseIn、EaseOut、InOut）

---

### 2.3 Set Rotation（设置旋转）✅ **已完成（Phase 1A）**

**功能描述：** 设置节点的旋转角度

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| rotation | float | 旋转角度（度） |
| space | Enum | Global/Local |

**使用场景：** 朝向目标、固定角度

**实现要点：**
- 2D: `rotation_degrees`
- 3D: `rotation_degrees.y` 或使用 Vector3

---

### 2.4 Rotate By（相对旋转）✅ **已完成（Phase 1D）**

**功能描述：** 相对于当前旋转角度旋转，支持动画

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| angle_delta | float | 旋转增量（度） |
| duration | float | 持续时间 |
| easing | Enum | 缓动类型 |

**使用场景：** 平滑转向、旋转动画

---

### 2.5 Set Scale（设置缩放）✅ **已完成（Phase 1A）**

**功能描述：** 设置节点的缩放比例

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| scale | Vector2/Vector3 | 缩放比例 |

**使用场景：** 放大缩小、弹跳效果

---

### 2.6 Look At（朝向目标）✅ **已完成（Phase 1A）**

**功能描述：** 让节点朝向目标位置或节点

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 要旋转的节点 |
| look_at_target | NodePath/Vector3 | 朝向目标 |
| target_type | Enum | Node/Position |
| up_direction | Vector3 | 上方向（仅 3D） |

**使用场景：** 敌人朝向玩家、炮台瞄准

**实现要点：**
- 使用 `look_at()` 方法
- 2D 需要计算角度

---

## 三、流程控制类

控制指令执行流程的指令。

### 3.1 If/Else（条件分支）✅ **已完成（Phase 0A）**

**功能描述：** 根据条件执行不同的指令序列

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| condition_type | Enum | 条件类型 |
| variable_name | String | 变量名 |
| comparison_operator | Enum | 比较运算符 |
| compare_value | Variant | 比较值 |
| true_instructions | Array[Instruction] | 条件为真时执行 |
| false_instructions | Array[Instruction] | 条件为假时执行 |

**条件类型：**
- Variable Comparison: 变量值比较
- Node Property Check: 节点属性检查
- Has Signal: 信号检查
- Node Exists: 节点存在性检查

**使用场景：** 血量检查、钥匙判断、状态判断

**实现要点：**
- 嵌套指令序列管理
- 支持多种条件类型
- 编辑器可视化嵌套结构

---

### 3.2 For Loop（计数循环）✅ **已完成（Phase 0A）**

**功能描述：** 重复执行指令序列固定次数

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| loop_count | int | 循环次数 |
| use_variable | bool | 是否使用变量 |
| count_variable | String | 循环次数变量名 |
| loop_index_variable | String | 保存当前索引 |
| loop_instructions | Array[Instruction] | 循环体指令 |

**使用场景：** 批量生成对象、多次攻击

**实现要点：**
- 索引从 0 开始
- 支持嵌套循环
- 循环变量作用域管理

---

### 3.3 For Each（遍历循环）✅ **已完成（Phase 3B）**

**功能描述：** 遍历数组或组中的每个元素

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| iteration_type | Enum | Array/NodeGroup |
| target_array | String | 目标数组变量名 |
| target_group | String | 目标组名 |
| current_item_variable | String | 保存当前元素 |
| loop_instructions | Array[Instruction] | 循环体指令 |

**使用场景：** 遍历敌人列表、批量处理

---

### 3.4 While Loop（条件循环）✅ **已完成（Phase 3B）**

**功能描述：** 当条件为真时重复执行

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| condition_variable | String | 条件变量名 |
| condition_check | Enum | IsTrue/IsFalse/IsNotNull |
| max_iterations | int | 最大迭代次数 |
| loop_instructions | Array[Instruction] | 循环体指令 |

**使用场景：** 等待条件满足、持续检测

**安全限制：**
- max_iterations 防止死循环
- 默认值 1000

---

### 3.5 Break Loop（跳出循环）✅ **已完成（Phase 1C）**

**功能描述：** 跳出当前循环

**参数：** 无

**使用场景：** 满足特定条件时提前结束循环

---

### 3.6 Continue Loop（继续下一次循环）✅ **已完成（Phase 1C）**

**功能描述：** 跳过本次循环剩余部分，进入下一次

**参数：** 无

**使用场景：** 过滤特定元素

---

### 3.7 Wait Until（等待条件）✅ **已完成（Phase 1C）**

**功能描述：** 等待直到条件满足或超时

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| condition_variable | String | 条件变量名 |
| condition_check | Enum | IsTrue/IsFalse/EqualTo |
| compare_value | Variant | 比较值 |
| timeout | float | 超时时间（秒） |
| check_interval | float | 检查间隔（秒） |

**使用场景：** 等待动画完成、等待加载

---

## 四、场景管理类

处理场景切换、加载、重载等场景生命周期管理。

### 4.1 Change Scene（切换场景）✅ **已完成（Phase 1A）**

**功能描述：** 加载并切换到新场景

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| scene_path | String | 目标场景路径 |
| use_current_variables | bool | 保留变量到新场景 |
| show_loading_screen | bool | 显示加载界面 |
| loading_screen_scene | String | 加载界面场景路径 |

**使用场景：** 关卡切换、从主菜单进入游戏

**实现要点：**
- 使用 `get_tree().change_scene_to_packed()`
- 变量传递机制
- 加载界面管理

---

### 4.2 Reload Scene（重载当前场景）✅ **已完成（Phase 2A）**

**功能描述：** 重新加载当前场景

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| preserve_variables | bool | 保留全局变量 |
| reset_position | bool | 重置玩家位置 |

**使用场景：** 重新开始关卡、死亡后复活

---

### 4.3 Add Scene as Child（添加子场景）✅ **已完成（Phase 2A）**

**功能描述：** 将场景实例化并添加为指定节点的子节点

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| scene_path | String | 场景路径 |
| parent_node | NodePath | 父节点 |
| save_instance_id | bool | 保存实例 ID |
| target_variable | String | 变量名 |
| variable_scope | Enum | Local/Global |

**使用场景：** 动态加载 UI、添加武器附件

---

### 4.4 Load Scene in Background（后台加载场景）✅ **已完成（Phase 2A）**

**功能描述：** 后台预加载场景，不立即切换

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| scene_path | String | 场景路径 |
| resource_name | String | 加载资源标识符 |
| use_threads | bool | 使用线程加载 |

**使用场景：** 预加载下一关、后台加载资源

**实现要点：**
- 使用 `ResourceLoader.load_threaded()`
- 资源管理器存储加载的资源

---

### 4.5 Get Scene Path（获取当前场景路径）✅ **已完成（Phase 2A）**

**功能描述：** 获取当前场景的文件路径

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_variable | String | 保存路径的变量名 |
| variable_scope | Enum | Local/Global |
| path_type | Enum | FullPath/FileName |

**使用场景：** 记录当前位置、保存游戏

---

### 4.6 Set Scene to Save（设置场景存档状态）

**功能描述：** 标记场景需要保存到存档文件

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| scene_name | String | 场景标识名 |
| save_variables | bool | 保存场景变量 |
| save_node_states | bool | 保存节点状态 |

**使用场景：** 检查点系统、存档系统

---

## 五、音频控制类

### 5.1 Play Sound（播放音效）✅ **已完成（Phase 1B）**

**功能描述：** 播放一次性音效

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| audio_resource | AudioStream | 音频资源 |
| bus_name | String | 音频总线 |
| volume_db | float | 音量（分贝） |
| pitch_scale | float | 音调 |
| position | Vector3 | 3D 位置（可选） |

**使用场景：** 播放脚步声、攻击音效

**实现要点：**
- 使用 Sound Manager 或创建临时 AudioStreamPlayer
- 支持 2D/3D 音频
- 自动清理播放完成的音频

---

### 5.2 Play Music（播放音乐）✅ **已完成（Phase 1B）**

**功能描述：** 播放背景音乐，支持淡入淡出

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| music_resource | AudioStream | 音乐资源 |
| bus_name | String | 音频总线 |
| volume_db | float | 音量 |
| fade_in_duration | float | 淡入时间 |
| loop | bool | 循环播放 |

**使用场景：** 播放关卡背景音乐

---

### 5.3 Stop Audio（停止音频）✅ **已完成（Phase 1B）**

**功能描述：** 停止指定音频播放

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_type | Enum | AllMusic/AllSound/Specific |
| specific_player | NodePath | 特定播放器节点 |
| fade_out_duration | float | 淡出时间 |

---

### 5.4 Set Audio Volume（设置音量）✅ **已完成（Phase 1B）**

**功能描述：** 控制主音量或音轨音量

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_bus | String | 目标音频总线 |
| volume_db | float | 音量（分贝） |
| fade_duration | float | 渐变时间 |

---

### 5.5 Pause/Resume Audio（暂停/恢复音频）✅ **已完成（Phase 1B）**

**功能描述：** 暂停或恢复音频播放

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| action | Enum | Pause/Resume |
| target_type | Enum | All/Music/Sound |

---

## 六、时间控制类

### 6.1 Set Time Scale（设置时间缩放）✅ **已完成（Phase 2B）**

**功能描述：** 控制游戏速度

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| time_scale | float | 时间缩放比例（1.0 = 正常） |
| duration | float | 持续时间（0 = 永久） |

**使用场景：** 慢动作效果、快进

**实现要点：**
- 使用 `Engine.time_scale`

---

### 6.2 Pause Game（暂停游戏）✅ **已完成（Phase 4C）**

**功能描述：** 暂停游戏逻辑

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| show_pause_menu | bool | 显示暂停菜单 |
| pause_menu_scene | String | 暂停菜单场景路径 |

---

### 6.3 Resume Game（恢复游戏）✅ **已完成（Phase 4C）**

**功能描述：** 恢复游戏逻辑

**参数：** 无

---

### 6.4 Get Delta Time（获取帧时间）✅ **已完成（Phase 2B）**

**功能描述：** 获取上一帧的时间差并保存到变量

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_variable | String | 变量名 |
| variable_scope | Enum | Local/Global |
| use_unscaled | bool | 使用不受时间缩放的时间 |

---

## 七、物理和碰撞类

### 7.1 Apply Force（施加力）✅ **已完成（Phase 6）**

**功能描述：** 对物理体施加持续力

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标物理体 |
| force | Vector2/Vector3 | 力向量 |
| position | Vector2/Vector3 | 施力位置（可选） |
| use_local_space | bool | 使用局部坐标系 |

**使用场景：** 风力、推进器

**实现要点：**
- 检查节点是否为 PhysicsBody2D/3D
- 使用 `apply_force()` 或 `apply_central_force()`

---

### 7.2 Apply Impulse（施加冲量）✅ **已完成（Phase 6）**

**功能描述：** 瞬间施加力

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标物理体 |
| impulse | Vector2/Vector3 | 冲量向量 |
| position | Vector2/Vector3 | 施力位置（可选） |

**使用场景：** 爆炸冲击、跳跃

---

### 7.3 Set Velocity（设置速度）✅ **已完成（Phase 6）**

**功能描述：** 直接设置物体速度

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标物理体 |
| velocity | Vector2/Vector3 | 速度向量 |
| use_local_space | bool | 使用局部坐标系 |

---

### 7.4 Raycast 2D/3D（射线检测）✅ **已完成（Phase 6）**

**功能描述：** 发射射线检测碰撞

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| origin | Vector2/Vector3 | 射线起点 |
| destination | Vector2/Vector3 | 射线终点 |
| collision_mask | int | 碰撞层掩码 |
| exclude_target | NodePath | 排除的节点 |
| save_result | bool | 保存结果到变量 |
| result_variable | String | 结果变量名 |

**返回结果：**
- collider: 碰撞对象
- point: 碰撞点
- normal: 碰撞法线

**使用场景：** 瞄准检测、视线检查

---

### 7.5 Set Collision Layer/Mask（设置碰撞层）✅ **已完成（Phase 6）**

**功能描述：** 配置节点的碰撞层级

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | 目标节点 |
| set_type | Enum | Layer/Mask/Both |
| layer_value | int | 层值（1-32） |
| mask_value | int | 掩码值 |

---

## 八、动画控制类

### 8.1 Play Animation（播放动画）✅ **已完成（Phase 2C）**

**功能描述：** 播放指定动画

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | AnimationPlayer 节点 |
| animation_name | String | 动画名称 |
| blend_mode | Enum | Blend/Mixed |
| custom_speed | float | 播放速度 |
| from_end | bool | 从末尾播放 |

---

### 8.2 Stop Animation（停止动画）✅ **已完成（Phase 3D）**

**功能描述：** 停止当前动画

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | AnimationPlayer 节点 |
| reset_state | bool | 是否重置状态 |

---

### 8.3 Set Animation Speed（设置动画速度）✅ **已完成（Phase 3D）**

**功能描述：** 控制动画播放速度

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | AnimationPlayer 节点 |
| speed_scale | float | 速度比例（1.0 = 正常） |

---

### 8.4 Set Animation Position（设置动画位置）

**功能描述：** 跳转到指定帧或时间

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | AnimationPlayer 节点 |
| position | float | 位置（秒） |

---

### 8.5 Blend Animation（混合动画）✅ **已完成（Phase 4D）**

**功能描述：** 混合多个动画

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | AnimationTree 节点 |
| blend_path | NodePath | 混合路径 |
| blend_amount | float | 混合量（0-1） |

---

## 九、相机控制类

### 9.1 Camera Follow（相机跟随）✅ **已完成（Phase 4B）**

**功能描述：** 设置相机跟随目标

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| camera_node | NodePath | Camera2D/3D 节点 |
| target_node | NodePath | 跟随目标 |
| follow_mode | Enum | Lock/Smooth/Damped |
| smooth_speed | float | 平滑速度 |

---

### 9.2 Camera Shake（相机抖动）✅ **已完成（Phase 4B）**

**功能描述：** 触发相机抖动效果

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| camera_node | NodePath | 相机节点 |
| intensity | float | 抖动强度 |
| duration | float | 持续时间 |
| use_juicy_mixer | bool | 使用 JuicyMixer 系统 |

**实现要点：**
- 可集成 JuicyMixer Shake Driver
- 或使用简单实现

---

### 9.3 Set Camera Zoom（设置相机缩放）✅ **已完成（Phase 3D）**

**功能描述：** 控制相机视野

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| camera_node | NodePath | 相机节点 |
| zoom_level | float | 缩放级别 |
| animate | bool | 是否动画过渡 |
| duration | float | 过渡时间 |

---

### 9.4 Set Camera Limit（设置相机限制）✅ **已完成（Phase 4B）**

**功能描述：** 限制相机移动范围

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| camera_node | NodePath | Camera2D 节点 |
| limit_type | Enum | Top/Bottom/Left/Right |
| limit_value | int | 限制值 |

---

## 十、数学运算类

### 10.1 Math Operation（数学运算）✅ **已完成（Phase 4A）**

**功能描述：** 基本四则运算

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| operation | Enum | Add/Subtract/Multiply/Divide/Modulo |
| operand_a | Variant | 操作数 A |
| operand_b | Variant | 操作数 B |
| use_variables | bool | 使用变量 |
| variable_a | String | 变量 A |
| variable_b | String | 变量 B |
| save_result | bool | 保存结果 |
| result_variable | String | 结果变量名 |

---

### 10.2 Random Number（随机数）✅ **已完成（Phase 3C）**

**功能描述：** 生成随机数

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| min_value | float | 最小值 |
| max_value | float | 最大值 |
| integer_only | bool | 仅整数 |
| save_result | bool | 保存结果 |
| result_variable | String | 结果变量名 |

---

### 10.3 Vector Operation（向量运算）✅ **已完成（Phase 4A）**

**功能描述：** 向量加减、归一化等

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| operation | Enum | Add/Subtract/Normalize/Length/Distance |
| vector_a | Vector2/Vector3 | 向量 A |
| vector_b | Vector2/Vector3 | 向量 B |
| save_result | bool | 保存结果 |
| result_variable | String | 结果变量名 |

---

### 10.4 Clamp Value（数值限制）✅ **已完成（Phase 3C）**

**功能描述：** 限制数值在指定范围

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| input_value | Variant | 输入值 |
| min_value | float | 最小值 |
| max_value | float | 最大值 |
| save_result | bool | 保存结果 |
| result_variable | String | 结果变量名 |

---

### 10.5 Lerp（线性插值）✅ **已完成（Phase 3C）**

**功能描述：** 在两个值之间插值

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| from_value | Variant | 起始值 |
| to_value | Variant | 目标值 |
| weight | float | 权重（0-1） |
| save_result | bool | 保存结果 |
| result_variable | String | 结果变量名 |

---

## 十一、UI 控制类

### 11.1 Show/Hide UI（显示/隐藏 UI）✅ **已完成（Phase 3A）**

**功能描述：** 控制 UI 可见性

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | UI 节点 |
| action | Enum | Show/Hide/Toggle |
| animate | bool | 是否动画 |

---

### 11.2 Set UI Text（设置 UI 文本）✅ **已完成（Phase 3A）**

**功能描述：** 更新文本内容

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | Label/RichTextLabel 节点 |
| text_source | Enum | Direct/Variable |
| text | String | 文本内容 |
| text_variable | String | 文本变量名 |

---

### 11.3 Set UI Progress（设置 UI 进度）✅ **已完成（Phase 3A）**

**功能描述：** 更新进度条

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | ProgressBar/TextureProgressBar 节点 |
| value | float | 进度值（0-100） |
| use_variable | bool | 使用变量 |
| value_variable | String | 变量名 |

---

### 11.4 Set UI Texture（设置 UI 图像）✅ **已完成（Phase 3A）**

**功能描述：** 更新图片

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| target_node | NodePath | TextureRect 节点 |
| texture | Texture2D | 图片资源 |
| use_variable | bool | 使用变量 |

---

## 十二、数据存取类

### 12.1 Save Game（保存游戏）

**功能描述：** 保存当前游戏状态

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| save_slot | int | 存档槽位（1-99） |
| save_name | String | 存档名称 |
| save_variables | bool | 保存全局变量 |
| save_scene | bool | 保存当前场景 |
| custom_data | Dictionary | 自定义数据 |

---

### 12.2 Load Game（加载游戏）

**功能描述：** 加载存档

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| save_slot | int | 存档槽位 |
| verify_exists | bool | 检查存档存在 |

---

### 12.3 Delete Save（删除存档）

**功能描述：** 删除指定存档

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| save_slot | int | 存档槽位 |

---

### 12.4 Check Save Exists（检查存档存在）

**功能描述：** 判断存档是否存在

**参数：**
| 参数名 | 类型 | 说明 |
|--------|------|------|
| save_slot | int | 存档槽位 |
| save_result | bool | 保存结果到变量 |
| result_variable | String | 结果变量名 |

---

## 实施建议

**重要提示：** 本 roadmap 文档专注于指令的功能规格说明。关于具体实施顺序和阶段划分，请参考 **[Instruction 评估报告 v2](./2026-01-26-instruction-evaluation-report-v2.md)**。

该评估报告提供了：
- ✅ **6 维评估体系** - 需求频率、即用性、复杂度、学习曲线、性能影响、依赖性
- ✅ **P0-P3 优先级分类** - 基于综合评分的优先级排序
- ✅ **依赖关系分析** - 确保基础功能优先开发
- ✅ **详细开发计划** - Phase 0A-1D 的分阶段实施方案
- ✅ **预期成果** - 各阶段完成后系统能力

**快速开始建议：**
如果需要立即开始开发，请参考评估报告中的 **Phase 0A: 核心基础** 阶段，包含 4 个 P0 级指令：
1. Set Position (69.0分) - 变换操作基础
2. For Loop (59.5分) - 循环控制基础
3. If/Else (59.0分) - 条件判断基础
4. Find Node (59.0分) - 节点查找基础

## 技术要点

### 1. 指令元数据系统
每个指令需要实现 `_get_instruction_metadata()` 静态方法：
```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_XXX_NAME"
    metadata.category_key = "FUSE_CATEGORY_XXX"
    metadata.description_key = "FUSE_INSTRUCTION_XXX_DESC"
    metadata.keywords = ["关键词1", "关键词2"]
    return metadata
```

### 2. 本地化支持
所有指令需要支持多语言：
- 在 `translations.csv` 中添加翻译
- 使用 `FuseLocalization.translate()` 方法
- 使用本地化日志方法

### 3. 编辑器集成
- 使用 `_get_property_list()` 动态属性
- 使用 `notify_property_list_changed()` 刷新
- 实现 `_update_resource_name()` 更新资源名称

### 4. 执行上下文
所有指令需要正确使用 `ExecutionContext`：
- 变量读写
- 日志输出
- 错误处理

### 5. 异步执行
对于需要异步执行的指令：
- 继承异步执行基类
- 正确发出 `finished` 信号
- 实现取消逻辑

### 6. 资源清理
实现 `_cleanup_resources()` 方法：
- 清理临时对象
- 断开信号连接
- 释放引用

## 与其他系统集成

### JuicyMixer 集成
- Camera Shake 可使用 JuicyMixer Shake Driver
- Play Effect 指令播放 JuicyFeedback

### Sound Manager 集成
- 音频指令应使用 Sound Manager
- 支持音频总线系统

### 全局变量系统
- 所有变量相关指令使用 GlobalVariableAssistant
- 支持本地和全局变量作用域

## 测试策略

每个指令需要创建对应的测试场景：
```
addons/fuse/tests/test_<instruction_name>.tscn
addons/fuse/tests/test_<instruction_name>.gd
```

测试内容：
- 基本功能测试
- 边界条件测试
- 错误处理测试
- 性能测试

## 文档要求

每个指令需要：
1. **设计文档** - 在 `addons/fuse/docs/system_docs/architecture/` 下
2. **使用示例** - 在 `addons/fuse/docs/user_docs/guides/` 下
3. **API 文档** - GDScript 注释
4. **本地化** - 在 `translations.csv` 中添加翻译

## 总结

本路线图定义了约 80+ 个指令，涵盖 12 个主要类别，为 Fuse 系统提供完整的游戏开发能力。

这些指令将使开发者能够通过可视化编程实现：
- ✅ 完整的对象管理（生成、释放、启用、禁用、查找）
- ✅ 完整的变换操作（位置、旋转、缩放、相对变换）
- ✅ 核心流程控制（循环、条件、等待）
- ✅ 场景管理和切换
- ✅ 音频和动画控制
- ✅ 物理和碰撞系统
- ✅ UI 控制和数据存取
- ✅ 相机和数学运算

**与其他系统的集成：**


## 已完成指令统计（截至 2026-01-27）

### Phase 0-1 已完成（22 个指令）

**节点操作类（4 个）：**
- ✅ Instantiate Scene（Phase 0B）
- ✅ Queue Free Node（Phase 0B）
- ✅ Enable/Disable Node（Phase 0B）
- ✅ Find Node（Phase 0A）

**变换操作类（6 个）：**
- ✅ Set Position（Phase 0A）
- ✅ Move By（Phase 1D）
- ✅ Set Rotation（Phase 1A）
- ✅ Rotate By（Phase 1D）
- ✅ Set Scale（Phase 1A）
- ✅ Look At（Phase 1A）

**流程控制类（5 个）：**
- ✅ If/Else（Phase 0A）
- ✅ For Loop（Phase 0A）
- ✅ Break Loop（Phase 1C）
- ✅ Continue Loop（Phase 1C）
- ✅ Wait Until（Phase 1C）

**场景管理类（1 个）：**
- ✅ Change Scene（Phase 1A）

**音频控制类（5 个）：**
- ✅ Play Sound（Phase 1B）
- ✅ Play Music（Phase 1B）
- ✅ Stop Audio（Phase 1B）
- ✅ Set Audio Volume（Phase 1B）
- ✅ Pause/Resume Audio（Phase 1B）

**其他已完成（1 个）：**
- ✅ Wait（已在早期完成）

---

### Phase 2 已完成（8 个指令）✅

**场景管理类（4 个）：**
- ✅ Get Scene Path（Phase 2A）
- ✅ Reload Scene（Phase 2A）
- ✅ Add Scene as Child（Phase 2A）
- ✅ Load Scene Background（Phase 2A）

**时间控制类（2 个）：**
- ✅ Set Time Scale（Phase 2B）
- ✅ Get Delta Time（Phase 2B）

**动画控制类（1 个）：**
- ✅ Play Animation（Phase 2C）

**节点操作类（1 个）：**
- ✅ Reparent Node（Phase 2C）

---

### Phase 3 已完成（12 个指令）✅

**UI 控制类（4 个）：**
- ✅ Show/Hide UI（Phase 3A）
- ✅ Set UI Text（Phase 3A）
- ✅ Set UI Progress（Phase 3A）
- ✅ Set UI Texture（Phase 3A）

**流程控制类（2 个）：**
- ✅ For Each（Phase 3B）
- ✅ While Loop（Phase 3B）

**数学运算类（3 个）：**
- ✅ Random Number（Phase 3C）
- ✅ Clamp Value（Phase 3C）
- ✅ Lerp（Phase 3C）

**动画控制类（2 个）：**
- ✅ Stop Animation（Phase 3D）
- ✅ Set Animation Speed（Phase 3D）

**相机控制类（4 个）：**
- ✅ Set Camera Zoom（Phase 3D）
- ✅ Set Camera Limit（Phase 4B）
- ✅ Camera Follow（Phase 4B）
- ✅ Camera Shake（Phase 4B）

**总计：**
- ✅ 已完成：45 个指令（Phase 0-1: 22 + Phase 2: 8 + Phase 3: 12 + Phase 4B: 3）
- 📊 总进度：45 / 约 80+ 指令
- 🎯 Phase 0-3 + 4B 完成度：100%
- 🎯 整体系统完成度：约 56%（45/80）

**代码质量：**
- ✅ Phase 1A-1D 代码审查完成
- ✅ 22 项代码质量改进（本地化、测试、语法修复）
- ✅ 创建指令开发指南
- ✅ 修复 AudioServer API 兼容性问题（5 个文件，10 处修复）
- ✅ 统一错误消息到本地化系统（4 个新键）
- ✅ 添加边缘情况测试（6 个新测试）

**相关文档：**
- [指令评估报告 v2](./2026-01-26-instruction-evaluation-report-v2.md) - 详细评估记录
- [Phase 4 开发计划](../../../docs/plans/2026-01-27-fuse-phase4-instruction-plan.md) - Phase 4 计划
- [指令创建指南](../development/instruction_creation_guide.md) - 开发者指南

---

### Phase 4B 已完成（3 个指令）✅

**相机控制类（3 个）：**
- ✅ Set Camera Limit（Phase 4B）
- ✅ Camera Follow（Phase 4B）
- ✅ Camera Shake（Phase 4B）

**Phase 4B 代码质量优化：**
- ✅ Camera Shake 异步回调安全性修复（is_instance_valid 检查）
- ✅ Camera Shake 资源管理完善（cancel 和 _cleanup_resources）
- ✅ Camera Shake Tween 性能优化（60 FPS → 30 FPS）
- ✅ Camera Follow smooth_speed 验证添加
- ✅ Set Camera Limit 代码重构（消除重复，添加常量）
- ✅ 代码质量从 B 级提升至 A- 级（90+/100）

---

### Phase 4D 已完成（1 个指令）✅

**动画控制类（1 个）：**
- ✅ Blend Animation（Phase 4D）

---

### Phase 6 已完成（5 个指令）✅

**物理和碰撞类（5 个）：**
- ✅ Apply Force（Phase 6）
- ✅ Apply Impulse（Phase 6）
- ✅ Set Velocity（Phase 6）
- ✅ Raycast 2D/3D（Phase 6）
- ✅ Set Collision Layer/Mask（Phase 6）

**总计：**
- ✅ 已完成：51 个指令（Phase 0-1: 22 + Phase 2: 8 + Phase 3: 12 + Phase 4B: 3 + Phase 4C: 2 + Phase 4D: 1 + Phase 6: 5）
- 📊 总进度：51 / 约 80+ 指令
- 🎯 Phase 0-4D + Phase 6 完成度：100%
- 🎯 整体系统完成度：约 64%（51/80）

---

## 相关文档

### 评估与规划
- **[Instruction 评估报告 v2](./2026-01-26-instruction-evaluation-report-v2.md)** - 6维评估体系，完整的优先级排序和开发计划
- **[评估框架文档](./2026-01-26-fuse-evaluation-framework.md)** - 评估体系的完整说明和评分标准
- **[Event Roadmap](./2026-01-26-fuse-event-roadmap.md)** - 事件系统开发路线图

### 开发指南
- **指令元数据系统** - 见上方"技术要点"部分
- **本地化支持** - 使用 `FuseLocalization.translate()` 方法
- **编辑器集成** - 使用 `_get_property_list()` 等方法
- **测试策略** - 每个指令需要创建测试场景
- **文档要求** - 设计文档、使用示例、API 文档、本地化

---

**下一步行动：**
1. 参考 **[Instruction 评估报告 v2](./2026-01-26-instruction-evaluation-report-v2.md)** 了解详细的优先级排序
2. 查看 **Phase 0A: 核心基础** 阶段的开发计划
3. 为 Phase 0A 的 4 个指令创建详细的设计文档
4. 开始实施核心基础功能

---

**文档版本:** 1.4
**最后更新:** 2026-01-27
**更新内容:** 标记 Phase 4D + Phase 6 完成（6 个指令）；更新已完成指令统计（51 个指令）
