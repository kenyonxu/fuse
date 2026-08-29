# Fuse 深度测试策略

> 🦊 知惠编写 · 2026-07-09
> 🦊 2026-08-28 复核更新：组件总数 298 → 310（指令 +11、事件 +1），阶段场景表按当前注册表重新核算，新增第七节 Headless 可验证性分层，第九节补充 fuse_adventure 实战验证清单
> 📋 配套执行计划：《Fuse深度测试计划.md》（23 场景 × preset × headless 分层的落地排期）
> 用途：Fuse 全组件深度测试的执行框架与资源清单
> 核心原则：**全 Fuse 化测试——不写一行代码，每个场景用 Fuse 面板搭建**

---

## 一、测试理念

Fuse 是面向用户的 Godot 可视化编程插件。传统 GDScript 自动化测试可以验证函数返回值，但无法验证**用户在编辑器中拖拽组件、配置参数、按下 F5 看到效果**这条完整体验链。

因此深度测试不采用 `assert_equal` 模式，而是按组件分类搭建独立的 Fuse 测试场景——每个场景 = 一个 Trigger + 该分类全部指令/事件/条件 + 可视化反馈（动画、音效、颜色变化、日志输出）。

**一个场景，一个分类，一键 F5，目视验收。**

---

## 二、覆盖总览

| 类型 | 总数 | 已自动化测试 | 深度测试覆盖 |
|------|------|-------------|-------------|
| 指令 | 185 | ~101 (54%) | 全部 185 |
| 条件 | 55 | ~28 (51%) | 全部 55 |
| 事件 | 70 | ~62 (89%) | 全部 70 |
| **合计** | **310** | **~191 (61%)** | **310** |

> 🦊 2026-08-28 注：总数按 `preset_ai_context/fuse_components.json`（2026-08-25 dump）计；「已自动化测试」由 tests/ 目录测试代码中的组件类名/脚本引用粗估（2026-07-09 原审计值为 65/4/55 = 124）。

---

## 三、测试阶段与外部资源需求

### 🔵 第一阶段：核心交互（5 场景，~63 组件）

> 目标：验证用户最常接触的交互体验——动画播放、音效、相机、变换、UI

| 场景 | 组件数 | 需要的外部资源 |
|------|--------|---------------|
| **Animation** | 13 指令 + 6 事件 + 5 条件 | 🎨 带 AnimationPlayer 的精灵节点（2D）或模型（3D）；建议准备一个简单的 Sprite2D + 两帧动画 |
| **Audio** | 7 指令 + 4 事件 | 🔊 **音频文件**：一个短音效（如按钮点击声 `.wav`）、一段背景音乐（`.ogg`）、一个带节拍的音乐用于 OnMusicBeat 事件 |
| **Camera** | 7 指令 | 🎨 一个较大的场景或 TileMap（用于测试 set_camera_limit / camera_follow / camera_shake / zoom / fade） |
| **Transform** | 7 指令 | 🎨 至少两个 2D 节点（Sprite2D 或 Control），用于测试 set_position / move_by / rotate / scale / look_at / get_position |
| **UI** | 6 指令 + 7 事件 + 1 条件 | 🎨 **UI 控件集**：Button、Label、ProgressBar、TextureRect、OptionButton、LineEdit |

### 🟢 第二阶段：逻辑与数据（6 场景，~96 组件）

> 目标：验证变量系统、数据结构操作、数学表达式、流程控制等纯逻辑组件

| 场景 | 组件数 | 需要的外部资源 |
|------|--------|---------------|
| **Variables** | 10 指令 + 6 条件 + 4 事件 | 无（纯逻辑，用 Fuse 内置变量面板验证；事件含变量变化类 OnVariableChanged 等） |
| **Arrays** | 18 指令 + 2 条件 | 无（纯逻辑，建议用 Print 指令输出数组内容到控制台） |
| **Dictionaries** | 16 指令 + 2 条件 | 无（纯逻辑，同上） |
| **Math** | 8 指令 + 2 条件 | 无（纯逻辑，建议配合 SetUIText 显示计算结果） |
| **String** | 6 指令 + 2 条件 | 无（纯逻辑，建议输出到 Label） |
| **Flow Control** | 16 指令 + 4 条件 | 无（纯逻辑，但需要耐心——循环和分支的交互验证最耗时；含 CheckAll/CheckAny/CheckNot/CheckComposite 组合条件） |

### 🟡 第三阶段：物理与节点（5 场景，~98 组件）

> 目标：验证物理模拟、节点操作、场景管理、输入事件

| 场景 | 组件数 | 需要的外部资源 |
|------|--------|---------------|
| **Physics** | 11 指令 + 7 条件 + 11 事件 | 🎨 **2D 物理场景**：CharacterBody2D / RigidBody2D + 地面（StaticBody2D） + 墙壁 + Area2D；建议用简单的方块/球体系 |
| **Movement** | 1 指令 | 🎨 同上物理场景（Movement 是复合指令，依赖物理环境） |
| **Node Operations** | 22 指令 + 9 条件 + 4 事件 | 🎨 场景中预置若干节点（用于 find_node / reparent / clone / queue_free / get_nodes_in_group 等测试；事件含节点生命周期类） |
| **Scene** | 6 指令 + 1 条件 + 5 事件 | 🎨 **至少两个独立场景**（用于 change_scene / reload_scene / preload / background_load 测试） |
| **Input** | 15 事件 + 6 条件 | ⌨️ 键盘 + 🖱️ 鼠标 + 🎮 手柄（如果有）；建议准备 Input Map 中已配置的动作名 |

### 🟣 第四阶段：高级系统（7 场景，~46 组件）

> 目标：验证 Tween、调试、粒子、渲染、定时、导航等高级功能
>
> 🦊 注：Lifecycle 类 7 个事件（OnReady / OnProcess / OnInterval 等）不设独立场景——每个测试场景的 TestTrigger 都以它们驱动，天然全覆盖。

| 场景 | 组件数 | 需要的外部资源 |
|------|--------|---------------|
| **Tween** | 13 指令 + 1 事件 | 🎨 至少一个带可视属性的节点（如 Sprite2D 的 modulate / position / scale） |
| **Debug** | 3 指令 | 无（用控制台输出验证） |
| **System** | 6 指令 + 2 条件 | 无（get_viewport_size / set_window_size / quit / load_resource 等纯系统调用） |
| **Time** | 2 指令 + 4 条件 + 4 事件 | 无（定时器类，需要等待时间验证） |
| **Rendering** | 5 指令 + 1 条件 | 🎨 **粒子节点**（GPUParticles2D）+ **灯光节点**（PointLight2D）+ **材质**（ShaderMaterial）；用于 set_material_property / control_particles / screen_flash 测试 |
| **Navigation** | 1 指令 + 1 事件 + 1 条件 | 🎨 **NavigationRegion2D + Agent**：需要一个带导航网格的场景 |
| **Event** | 1 指令 + 1 事件 | 无（SendEvent / OnReceiveEvent 纯逻辑） |

---

## 四、外部资源汇总清单

### 🎨 美术资源

| 资源 | 用途 | 建议规格 |
|------|------|---------|
| 精灵（Sprite2D） | Animation / Transform / Tween 测试 | 64×64 或 128×128 PNG |
| 动画（AnimationPlayer） | Animation 场景 | 至少两帧的简单动画 |
| 地面/墙壁（StaticBody2D） | Physics 场景 | 简单的矩形碰撞体 |
| 角色（CharacterBody2D） | Physics / Movement 场景 | 带有 CollisionShape2D |
| 区域（Area2D） | Physics 事件测试 | 简单的圆形或矩形区域 |
| UI 控件集 | UI 场景 | Button / Label / ProgressBar / TextureRect / OptionButton / LineEdit |
| 独立场景 A/B | Scene 场景 | 两个最简单的场景（如红蓝方块场景） |
| 粒子（GPUParticles2D） | Rendering 场景 | Godot 默认粒子材质即可 |
| 灯光（PointLight2D） | Rendering 场景 | 默认灯光 |
| 导航网格 | Navigation 场景 | NavigationRegion2D + 烘培 |

### 🔊 音频资源

| 资源 | 用途 | 建议规格 |
|------|------|---------|
| 短音效 | Audio 指令测试（play_sound） | `.wav` 或 `.ogg`，< 1 秒 |
| 背景音乐 | Audio 指令测试（play_music / crossfade） | `.ogg`，> 10 秒 |
| 带节拍音乐 | OnMusicBeat 事件测试 | 有明显节拍的音频 |

### ⌨️ 输入设备

| 设备 | 用途 |
|------|------|
| 键盘 | Input 事件（按键/组合键/文本输入） |
| 鼠标 | Input 事件（点击/移动/滚轮） |
| 手柄（可选） | Gamepad 事件测试 |

---

## 五、场景模板

每个测试场景遵循统一结构：

```
场景根节点 (Node2D 或 Control)
├── TestTrigger (Trigger 或 MultiEventTrigger)
│   ├── 触发事件（如 OnReady / OnTimer / OnInputKey）
│   └── ActionRunner
│       ├── 初始化指令（如变量声明、场景准备）
│       ├── 🧪 测试目标：该分类全部指令
│       ├── 🧪 测试目标：该分类全部条件
│       └── 清理/反馈指令（如 Print 结果、恢复状态）
└── 测试目标节点（Sprite、AudioStreamPlayer、物理体等）
```

### 验收标准

- ✅ 场景在 Godot 编辑器中按 F5 可正常运行
- ✅ 所有组件在运行时没有报错（控制台无红色 error）
- ✅ 可视化反馈符合预期（动画动、声音响、颜色变、UI 更新）
- ✅ 条件分支在两种情况（满足/不满足）下均行为正确

---

## 六、执行建议

1. **先搭最简单的**：从 Animation 和 Audio 开始——这两个场景依赖的资源明确，验收反馈最直接
2. **需要美术/音频资源时**：用 Godot 内置的 icon.svg 做精灵、用 CSGBox3D 做物理体——不要等待外部资源
3. **每完成一个场景就 F5 一次**：不要攒到最后批量跑
4. **条件测试要点**：每个条件至少搭建两个 Trigger——一个满足条件、一个不满足——确保真假分支都走过

---

## 七、Headless 可验证性分层

> 🦊 2026-08-28 注：headless 能验的是**状态正确 + 控制台无报错**，验不了**看到 / 听到 / 感觉到**。按 headless 验收面把 23 个场景分四层——约 44% 组件可直接 headless 判定，约 45% 可 headless 验状态、F5 只补感官项，真正绕不开 F5 的只有 Rendering 与各场景的感官验收项。

| 分层 | 场景（组件数） | headless 验收面 | F5 仍需要吗 |
|------|--------------|----------------|------------|
| **A · 直接 headless**（~136） | 逻辑与数据全部 6 场景（96）、Debug（3）、System（8）、Time（10）、Event（2）、Navigation（3）、Transform（7）、Lifecycle 事件（7） | Print / print_variable_value 的 stdout 输出 | 不需要 |
| **B · 状态级 headless**（~140） | Physics + Movement（30）、Node Operations（35）、Scene（12）、Tween（14）、Animation（24）、Camera（7）、Audio（11）、UI 内容类（7） | 状态与属性读数：get_position 结果、check_\* 条件真假、playing / volume_db / 播完标志、动画帧与播放状态 | 需要——手感 / 听感 / 观感 headless 验不了，F5 抽查感官项 |
| **C · 需注入手段**（28） | Input（21）、UI 交互事件（7） | 注入输入 / 信号后同 B 层 | 同 B 层 |
| **D · 必须 F5**（6） | Rendering（6） | 无——Dummy RenderingServer 下 GPUParticles2D 不模拟（CPUParticles2D 可验 emitting 状态），screen_flash / 材质效果只能属性级确认 | 必须 |

### 7.1 实操要点

1. **廉价回归门禁**：23 个场景全部先 headless 跑一遍——「控制台无红色 error」这条验收标准本身可 grep（`push_error` / `SCRIPT ERROR`），长场景配 `--quit-after` 截断
2. **PASS/FAIL 标记法（纯 Fuse 自检链）**：目标指令 → RunConditionCheck（预期结果作条件）→ 两分支各接 `Print("PASS: 组件名")` / `Print("FAIL: 组件名")`，跑完 grep FAIL——把目视验收升级为可回归的 stdout 断言，不违背「不写一行代码」
3. **C 层输入驱动是唯一绕不开的代码**：写一次通用驱动脚本（十几行：`Input.action_press` / `Input.parse_input_event` 注入键盘鼠标、`button.pressed.emit()`），全部 Input 场景复用
4. **UI 交互可纯 Fuse 合成**：OnButtonPressed 类事件用 run_target_node_function 对 Button 调 `emit_signal("pressed")` 即可触发，不需要驱动
5. **Preset 前置门禁**：生成的 preset JSON 先跑 validate_preset.tscn 离线校验（本身就是 headless 的），通过后再进编辑器导入
6. **音频注意**：headless 走 Dummy 音频驱动——playing / volume_db / 播完事件照常可验，听感验不了

---

## 八、利用 Preset 系统批量生成测试场景

> 🦊 知惠注（2026-07-09）：主人散步时提出的方案——用 Fuse Preset 的 JSON 格式让 AI 批量生成测试场景，比手搭 Godot 场景更快更稳。

### 8.1 核心优势

- **AI 友好**：Preset 是结构化 JSON，不涉及 Godot UID 引用、节点缩进、资源路径校验——AI 不会搞砸
- **批量生成**：一个分类一个 preset 文件，23 个分类场景 preset 覆盖全部 310 个组件
- **一键导入**：Godot 中打开 Fuse Preset 导入面板，选中 preset 文件即可自动生成完整测试场景
- **可复用**：测试通过的 preset 文件可直接分享给用户——相当于 Fuse 官方验收的示例场景包

### 8.2 Preset 测试场景标准结构

```json
{
  "category": "animation",
  "version": "1.0",
  "nodes": {
    "TestTrigger": {
      "type": "Trigger",
      "events": [
        {"type": "on_ready"}
      ],
      "action_runner": {
        "instructions": [
          // 该分类全部指令在此列出
        ]
      }
    }
  }
}
```

### 8.3 生成与验收流程

1. **生成**：按策略文档的四阶段顺序，每类生成一个 preset JSON 文件
2. **导入**：Godot 编辑器 → Fuse Preset 导入面板 → 选择 preset → 自动创建测试场景
3. **F5 验收**：运行场景，目视确认所有组件无报错、行为符合预期
4. **导出修正**：如有问题，在编辑器中修正后重新导出 preset，覆盖原始文件

### 8.4 与手搭场景的互补

| 方式 | 适用场景 |
|------|---------|
| Preset 批量生成 | 纯逻辑组件（variables / arrays / dictionaries / math / flow_control / string）—— 结构明确、AI 可直接产出 |
| 编辑器手搭 | 需要外部资源的组件（physics / navigation / rendering）—— 需要在 Godot 中先布置目标节点再导入 preset |

---

## 九、已验证组件清单（实战 Demo）

> 🦊 知惠注（2026-07-09）：Brickian 是 Fuse 自带的完整射击小游戏 demo——标题画面 → 玩家飞船 → 敌人生成 → 子弹碰撞 → 爆炸特效 → 计分。全程用 Fuse 搭建，已通过实战验证的组件可直接复用。
>
> 🦊 2026-08-28 补充：fuse_adventure 横版平台 demo（标题画面 → 关卡 01/02 → 移动平台/锯齿 → 收集品/血量 UI → 死亡爆炸/重生链 → 跨关卡续播音乐）已实战跑通，其新增覆盖的组件列于下文「fuse_adventure · 补充验证」，与 Brickian 合并去重统计。

### Brickian · 已验证指令（45个）

animation: —
**arrays**: array_add
**audio**: play_sound, play_random_sound, crossfade_to_music
camera: —
**debug**: print, print_variable_value
dictionaries: —
**event**: send_event
**flow_control**: if_else, if_then, for_each, wait, run_runner, run_condition_check, pause_game, resume_game
**math**: math_operation, math_expression, get_random_point_in_range, vector_operation
**movement**: move_character_body_2d_composite
navigation: —
**node_operations**: instantiate_scene, queue_free_node, recycle_pooled_scene, warm_up_pool, find_node, get_all_children_position, get_child_count, get_group_count, get_last_child, get_random_child, run_target_node_function
physics: —
rendering: —
**scene**: preload_scene_instruction
**scene_management**: change_scene
string: —
system: —
**time**: get_delta_time
**transform**: move_by, get_position
**tween**: tween_fade_in, tween_fade_out, tween_move_to, tween_property
**ui**: set_ui_text, show_hide_ui
**variables**: set_variable, save_global_variables, load_global_variables

### Brickian · 已验证事件（9个）

**event**: on_receive_event
**input**: on_input_action, on_input_action_composite
**lifecycle**: on_ready, on_process, on_interval, on_interval_with_variable
**node**: on_target_signal_emit
**physics**: on_area_2d_enter

### Brickian · 已验证条件（7个）

**composite**: check_any
**input**: check_any_input
**node**: check_child_count, check_group_count
**scene**: check_preload_status
**variable**: check_variable, check_vector2_variable_axis

### fuse_adventure · 补充验证（2026-08，24个）

> 🦊 注：以下为 fuse_adventure 场景实际引用并在实战跑通的组件（以 2026-08 提交记录为准），均不在上方 Brickian 清单内。

**新增已验证指令（15个）**

animation: animated_sprite_2d_play, get_animation_length, set_animation_tree_parameter, set_sprite_flip
**arrays**: array_get
**camera**: camera_follow, set_camera_limit_from_area2d
**node_operations**: enable_disable_node, get_node, get_nodes_in_group, set_process_mode, set_property_value
**physics**: add_velocity
**system**: set_viewport_size
**variables**: create_variable

**新增已验证事件（4个）**

**node**: on_path_follow_2d_progress_ratio
**physics**: on_ground_state_changed
**state**: on_variable_changed
**ui**: on_button_pressed

**新增已验证条件（5个）**

**composite**: check_all
**node_operations**: check_node_property
**physics**: check_in_air, check_velocity
**scope_variables**: check_scope_variable

### deep_tests 深度测试验证（2026-08-29，26 场景）

> 🦊 M0-M4 全程完成后的覆盖审计（`demos/fuse/deep_tests/`）：26 个 `test_deep_*.tscn` + 25 个 preset JSON 的组件引用提取，与 310 项注册表做差集。**deep_tests 覆盖 306 项（遗留专项全清后），为两个实战 Demo 已验证 85 项的超集**——过程累计修复产品缺陷 53 个（详见《Fuse深度测试计划.md》执行记录）。

| 类型 | 总数 | deep_tests 覆盖 | 说明 |
|------|------|-----------------|------|
| 指令 | 185 | 184 (99%) | 未覆盖：RecyclePooledScene（编辑器验）、ReloadScene（F5 验） |
| 事件 | 70 | 61 (87%) | 未覆盖：3D×2、触摸×2、OnInputAction(单动作版)、OnProcess/OnPhysicsProcess/OnIntervalWithVariable/OnEnterTree/OnExitTree、OnSceneLoaded、OnScreenEnteredExited（已知崩溃专项） |
| 条件 | 55 | 54 (98%) | 未覆盖：CheckDirection/CheckFacingDirection/CheckIsChildOf/CheckAnimationTreeState/CheckChildCount/CheckGroupCount/CheckNodeInGroup（多为已测指令的条件变体） |

**验收口径**（四查，`tools/check_log.sh`）：SCRIPT ERROR/push_error = 0、FAIL = 0、`Error calling from signal` = 0（信号签名类错误，OnOverlappingBodies 教训后新增）、PASS 唯一标记达标。当前 26 场景全绿（tween 4 个数值断言 FAIL 为已立项遗留，F5 观感正确）。

### 验证状态总结（合并去重）

| 类型 | 总数 | 实战 Demo | deep_tests 深测 | 综合已验证 |
|------|------|-----------|-----------------|------------|
| 指令 | 185 | 60 (32%) | 183 (99%) | 183 (99%) |
| 事件 | 70 | 13 (19%) | 58 (83%) | 58 (83%) |
| 条件 | 55 | 12 (22%) | 48 (87%) | 48 (87%) |

> deep_tests 覆盖为两 Demo 已验证（85 个）的超集，综合以 deep_tests 计：**306/310 (99%)**（遗留专项全清后；2026-08-29 晚）。剩余 4 项各有原因：OnExitTree（驱动链待查）、CheckAnimationTreeState（需 StateMachine 场景）、RecyclePooledScene（编辑器验）、ReloadScene（F5 验）。

---

*🦊 知惠注：这是面向用户的视觉验收测试，不是面向 CI 的自动化测试。场景的「通过」标准是在 Godot 编辑器中 F5 后主人看到的、听到的、感觉到的——而不是 green checkmark。*
