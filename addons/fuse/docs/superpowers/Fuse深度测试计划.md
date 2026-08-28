# Fuse 深度测试计划

> 🦊 2026-08-28 制定 · 配套文档：《Fuse深度测试策略.md》（第三节场景表 / 第七节 Headless 分层 / 第九节已验证清单）
> 目标：**310 组件 × 23 场景全覆盖**。preset 一律用工程自带技能生成；外部资源取自 `demos/fuse/fuse_adventure/resources/`。

---

## 一、总览：23 场景 × 测试方式 × preset

测试方式四种（对应策略文档第七节分层）：

- **纯 headless**：断言全在 stdout（PASS/FAIL 标记 + 无报错），不需要开窗口
- **headless + F5**：先 headless 验状态与无报错，再 F5 手动验收感官项
- **驱动 + headless + F5**：同上，headless 阶段需 `input_driver.gd` 注入输入/信号
- **纯 F5**：headless 只跑"无报错"回归，验收全靠目视

| # | 场景 | 组件数 | 测试方式 | preset 文件 |
|---|------|--------|---------|------------|
| 1 | Animation | 24 | headless + F5 | deep_animation.json |
| 2 | Audio | 11 | headless + F5 | deep_audio.json |
| 3 | Camera | 7 | headless + F5 | deep_camera.json |
| 4 | Transform | 7 | 纯 headless | deep_transform.json |
| 5 | UI | 14 | headless + F5（交互事件纯 Fuse 合成） | deep_ui.json |
| 6 | Variables | 20 | 纯 headless | deep_variables.json |
| 7 | Arrays | 20 | 纯 headless | deep_arrays.json |
| 8 | Dictionaries | 18 | 纯 headless | deep_dictionaries.json |
| 9 | Math | 10 | 纯 headless | deep_math.json |
| 10 | String | 8 | 纯 headless | deep_string.json |
| 11 | Flow Control | 20 | 纯 headless | deep_flow_control.json |
| 12 | Physics | 29 | headless + F5 | deep_physics.json |
| 13 | Movement | 1 | headless + F5（与 Physics 共骨架） | deep_movement.json |
| 14 | Node Operations | 35 | headless + F5 | deep_node_operations.json |
| 15 | Scene | 12 | headless + F5 | deep_scene.json（+ 跳转目标场景 A/B） |
| 16 | Input | 21 | 驱动 + headless + F5 | deep_input_keyboard / mouse / gamepad.json（3 件） |
| 17 | Tween | 14 | headless + F5 | deep_tween.json |
| 18 | Debug | 3 | 纯 headless | deep_debug.json |
| 19 | System | 8 | 纯 headless | deep_system.json（quit 拆 mini 场景） |
| 20 | Time | 10 | 纯 headless（需等待） | deep_time.json |
| 21 | Rendering | 6 | 纯 F5 | deep_rendering.json |
| 22 | Navigation | 3 | 纯 headless | deep_navigation.json |
| 23 | Event | 2 | 纯 headless | deep_event.json |

> Lifecycle 类 7 个事件（OnReady / OnProcess / OnRealtime / OnPhysicsProcess / OnInterval / OnEnterTree / OnExitTree）不设独立场景——它们是全部 23 个场景 TestTrigger 的驱动源，天然全覆盖，覆盖审计时计入累计。

---

## 二、目录与产物约定

```
demos/fuse/deep_tests/
├── presets/
│   ├── deep_<category>.json        # preset（技能生成，validate 过门禁）
│   └── deep_input_keyboard.json …  # Input 按设备族拆 3 件
├── scenes/
│   ├── test_deep_<category>.tscn   # 测试场景（手搭骨架 + 导入 preset）
│   ├── test_deep_scene_a.tscn      # Scene 场景跳转目标 A（Blue 底）
│   └── test_deep_scene_b.tscn      # Scene 场景跳转目标 B（Brown 底）
├── tools/
│   └── input_driver.gd             # C 层唯一手写代码（输入/信号注入，全场景复用）
└── reports/                        # validate 报告 + headless 运行日志
```

- **preset 落盘**：技能默认落 `res://addons/fuse/presets/<category>/`（用户 preset 库）；本计划的测试 preset 统一落 `demos/fuse/deep_tests/presets/`，避免测试资产混入用户库。技能工作流其余步骤不变。
- **资源引用**：场景/preset 内一律 `res://demos/fuse/fuse_adventure/resources/...` 绝对路径。
- **命名**：preset 用 `deep_` 前缀（与用户 preset 区分），场景用 `test_deep_` 前缀（与插件 GDScript 测试 `test_` 区分）。

---

## 三、标准工作流（每场景六步，缺一不可）

### 第 1 步：生成 preset —— 必须用工程自带技能

⚠️ **`.claude/skills/fuse-preset-generator/SKILL.md`**（ZCode 的 Skill 工具注册表不含它，以 Read 该 SKILL.md 并遵循的方式使用）：

1. 先读技能指定的两份结构文档：`preset_ai_context/preset_structure_cheatsheet.md` + `skill_workflow_brief.md`
2. 组件选择不靠记忆——从 `preset_ai_context/fuse_components.json` 按 `category_key`（如 `FUSE_CATEGORY_ANIMATION`）过滤出该类目**全部**组件，逐个进 preset；参数查 `fuse_component_schemas.json`，枚举查 `fuse_enums.json`
3. 结构：单 Trigger 主链用 **L2**（event: OnReady + action_runner 长指令序列）；事件验证拆独立 L2 子件或用 **L4**（多事件绑定）
4. 技能易错点表硬约束：`type` 用 class_name；Vector2/Color 写 `"(x, y)"` 字符串规范形；IfThen/IfElse 的 condition 用 inline dict（禁止 `.tscn::Resource_*` 引用）；NodePath 用 `../Targets/...` 相对占位

### 第 2 步：headless 校验 preset（门禁）

```bash
Godot --headless --path <项目路径> res://addons/fuse/editor/preset_ai/validate_preset.tscn \
  -- demos/fuse/deep_tests/presets/deep_<category>.json \
  --report demos/fuse/deep_tests/reports/validate_<category>.json
```

退出码 0 才继续；报错按错误码回技能修正（`E_REPR_NONCANONICAL` → 改字符串规范形，`E_SCENE_PRIVATE_REF` → 去场景私有引用）。

### 第 3 步：手搭骨架 + 导入

编辑器中建场景（`Targets/` 下目标节点按第六节），Fuse Preset 导入面板导入 preset 生成 Trigger/ActionRunner；NodePath 占位符由 NodePathResolver 兜底映射。

> 🦊 M0 实测（2026-08-28）：**无外部资源的纯逻辑场景可以全程 headless**——`tools/import_preset.gd`（M0 产出）走与编辑器面板相同的反序列化管线（`FusePreset.from_json` + `FusePresetDeserializer.deserialize`），一条命令把 preset JSON 生成 .tscn。需要手搭目标节点的场景仍走编辑器面板。

### 第 4 步：headless 回归

```bash
Godot --headless --path <项目路径> demos/fuse/deep_tests/scenes/test_deep_<category>.tscn \
  --quit-after 600 > demos/fuse/deep_tests/reports/run_<category>.log 2>&1
```

对 log **验收三查**：

| 检查 | 判定 |
|------|------|
| `grep -E "SCRIPT ERROR\|push_error"` | 必须为空 |
| `grep "FAIL:"` | 必须为空 |
| `grep -c "PASS:"` | 等于该场景可断言组件数 |

### 第 5 步：F5 手动验收（B/C/D 层场景）

感官项逐项过（各场景明细里列出的 F5 验收点）。

### 第 6 步：回填

更新本文档场景状态 + 策略文档第九节覆盖清单。

---

## 四、通用场景结构（模板）

```
test_deep_<category>.tscn（Node2D；UI 类用 Control）
├── Targets/                          # 手搭目标节点（各场景明细见第六节）
├── TestTrigger (Trigger)             # preset 导入生成
│   └── ActionRunner
│       ├── 初始化：CreateVariable / SetVariable（测试数据）
│       ├── 组件X → RunConditionCheck(预期条件)
│       │              ├─ 成立 → Print("PASS: X")
│       │              └─ 不成立 → Print("FAIL: X")
│       ├── ……该类目全部可断言组件……
│       └── Print("=== <category> DONE ===")
└── （事件类子 Trigger：OnXxx 触发 → Print("PASS: OnXxx")）
```

约定：

- **可断言组件**（输出/状态可读）逐个包 RunConditionCheck 自检链；**感官类组件**（震动观感/闪光/缓动手感）只执行不断言，接 `Print("PASS(m): X")`（m = manual，留给 F5）
- **事件组件**不挂 OnReady 主链：每个事件独立子 Trigger，触发后打 PASS 标记
- **System 的 quit 指令**单独放 mini 场景最后执行，避免截断主链断言
- **Time 类**依赖真实等待，主链用 Wait 拉开时距，headless 命令配足 `--quit-after`

---

## 五、资源映射表（全部取自 fuse_adventure）

| 资源 | 路径（res://demos/fuse/fuse_adventure/resources/ 下） | 服务场景 |
|------|------|---------|
| AnimatedSprite 资源 | animatedSprites/player.tres、saw.tres | Animation / Tween / Transform / Node Operations |
| AnimationPlayer 库 | animationLibs/player.res | Animation |
| AnimationTree 状态机 | animation_stm/player_normal.tres | Animation（set_animation_tree_parameter / check_animation_tree_state / on_animation_blend） |
| TileSet | tilesets/fuse_adventure_tile_set.tres | Camera / Physics 的大场景地面 |
| 角色精灵图 | arts/…/Main Characters/{Mask Dude,Ninja Frog,Pink Man,Virtual Guy}/（Idle/Run/Jump/Fall/Hit…32×32） | Transform / Tween / Physics 目标 |
| 陷阱图 | arts/…/Traps/{Saw,Spikes,Fan,Fire,Trampoline,Falling Platforms}/ | Physics / Node Operations |
| 水果图 | arts/…/Items/Fruits/（Bananas/Apple/Cherries…） | UI 图标 / Area2D 收集目标 |
| 心形图标 | arts/…/Other/hearts/ | UI（血量 ProgressBar / TextureRect） |
| 菜单按钮图 | arts/…/Menu/Buttons/（Play/Settings/Volume…） | UI（纹理 Button） |
| 背景图 | arts/…/Background/{Blue,Brown,Gray…}.png | Scene 跳转目标 A/B 底图、Camera 远景 |
| 音效家族 | sfx/coins、sfx/jumps、sfx/explosions、sfx/footsteps、sfx/impacts | Audio（play_sound / play_random_sound） |
| 长曲（带节拍） | music/SpaceBattle_8bit_final.wav | Audio（play_music / crossfade / OnMusicBeat） |
| 现成场景 | scenes/ 下 player.tscn（CharacterBody2D+AnimationTree）、saw.tscn（PathFollow2D）、moving_platform.tscn、item_banana.tscn（Area2D）、death_explosion.tscn + respawn_effect.tscn（CPUParticles2D）、ui_life.tscn、ui_collectables.tscn | Physics / Movement / Node Operations（instantiate_scene）/ Rendering（CPU 粒子）/ Tween |

**资源缺口**（需编辑器内新建，fuse_adventure 没有）：

| 缺口 | 用于 |
|------|------|
| GPUParticles2D + 默认粒子材质、PointLight2D、ShaderMaterial | Rendering 场景 |
| NavigationRegion2D（简单矩形导航网格，编辑器烘培）+ NavigationAgent2D | Navigation 场景 |
| 手柄无实物：OnGamepad\* 事件由 input_driver.gd 注入 InputEventJoypadButton/Motion | Input 场景 |

**InputMap 现状**：工程已配置 `Up / Down / Left / Right / Jump`（WASD + Space），Input 场景直接沿用；缺的动作（如 attack）在 project.godot 补。

---

## 六、场景明细（23 个）

> 每场景的组件清单以 `fuse_components.json` 按 category_key 过滤为准（本文档不手抄名单，防止再过期）；下表只写结构、资源与验收面。

### 第一阶段 · 核心交互

**1. Animation（24 · headless + F5）**
- Targets：`AnimatedSprite2D`（player.tres）+ `AnimationPlayer`（animationLibs/player.res）+ `AnimationTree`（player_normal.tres）
- headless 断言面：播放状态布尔、帧号、`get_animation_length` 数值、`set_sprite_flip` 后属性回读、AnimationTree 参数回读、on_animation_finished/marker 触发标记
- F5 验收：动画肉眼正确，循环/帧标记时机对

**2. Audio（11 · headless + F5）**
- Targets：无需手搭（play_sound 自建播放器节点）；资源 sfx/jumps + music/SpaceBattle
- headless 断言面：playing / volume_db / 播放器节点存在性、crossfade 前后音量迁移、on_audio_finished 触发标记（Dummy 驱动下状态照常推进）
- F5 验收：音量听感、crossfade 平滑、节拍事件踩点

**3. Camera（7 · headless + F5）**
- Targets：TileMap 铺大场景（tileset）+ 角色精灵（Mask Dude）
- headless 断言面：zoom / limit / camera 全局位置读数、follow 后位置跟随断言
- F5 验收：跟随手感、震动观感、fade 过渡

**4. Transform（7 · 纯 headless）**
- Targets：两个 Sprite2D（Mask Dude / Ninja Frog Idle）
- 断言面：set_position / move_by / rotate / scale / look_at 后 `get_position` 与属性回读

**5. UI（14 · headless + F5）**
- Targets：Button（Play.png 纹理）、Label、ProgressBar（hearts）、TextureRect（Fruits）、OptionButton、LineEdit
- headless 断言面：set_ui_text / set_ui_progress / show_hide_ui 后属性回读、check_ui_visible 真假两分支；**OnButtonPressed 用 run_target_node_function 对 Button 调 `emit_signal("pressed")` 纯 Fuse 合成触发**
- F5 验收：布局、鼠标进出高亮、OptionButton 展开交互

### 第二阶段 · 逻辑与数据（6 · 全部纯 headless）

**6–11. Variables(20) / Arrays(20) / Dictionaries(18) / Math(10) / String(8) / Flow Control(20)**
- Targets：无（可选一个 Label 供 String 显示）
- 结构：变量初始化 → 全部指令逐一执行 → RunConditionCheck 断言结果变量值 → PASS/FAIL；Flow Control 的 if/for/wait/嵌套指令各配真假双分支；Variables 场景含 on_variable_changed 事件子 Trigger（0 代码纯 Fuse）
- 断言面全部在 stdout

### 第三阶段 · 物理与节点

**12. Physics（29 · headless + F5）**
- Targets：TileMap 地面 + 墙（StaticBody2D）、player.tscn（CharacterBody2D）、RigidBody2D（Box 图）、item_banana.tscn（Area2D）、saw.tscn
- headless 断言面：add_velocity / apply_impulse 后 `check_velocity` 断言、`check_on_floor / check_in_air / check_on_wall` 真假分支、on_area_2d_enter / on_body_entered / on_collision 触发标记、on_ground_state_changed 触发
- F5 验收：碰撞表现、击退手感、锯齿链视觉

**13. Movement（1 · headless + F5，与 Physics 共骨架）**
- 复用 Physics 场景目标节点；move_character_body_2d_composite 接 Up/Down/Left/Right 动作
- headless：input_driver 注入 action_press 后位置变化断言；F5：手感

**14. Node Operations（35 · headless + F5）**
- Targets：预置节点树（若干精灵，部分进 `test_targets` 组）
- headless 断言面：get_node / find_node / get_nodes_in_group / get_child_count / get_last_child 结果断言；instantiate_scene 实例化 item_banana.tscn 与 death_explosion.tscn 后子节点计数；enable_disable_node / set_property_value / set_process_mode 后属性回读；on_enter_tree / on_exit_tree / on_tree_changed 触发标记
- F5 验收：实例化特效的视觉表现

**15. Scene（12 · headless + F5）**
- Targets：主场景 + 跳转目标 A（Blue 底 + Label "A"）/ B（Brown 底 + Label "B"）
- headless 断言面：preload_scene 后 check_preload_status 真假分支、change_scene 后 `get_tree().current_scene.name` 打印断言、on_scene_loaded / on_scene_about_to_change 触发标记、background_load 进度
- F5 验收：切换过渡观感

**16. Input（21 · 驱动 + headless + F5）**
- preset 按设备族拆 3 件：deep_input_keyboard.json（OnInputKey/OnInputText/OnInputCombo/OnInputBuffered/OnDirectionalInputChanged + check_input_\* 条件）、deep_input_mouse.json（OnMouseButton/OnMouseMove/OnMouseEnter/OnMouseExit/OnUIMouse\*）、deep_input_gamepad.json（OnGamepadAxis/OnGamepadButton）
- headless：input_driver.gd 注入 `Input.action_press` / `Input.parse_input_event`（键盘鼠标）/ joypad 事件，事件触发与条件真假全打 PASS 标记
- F5 验收：真实键鼠手感（手柄无实物，只验注入路径）

### 第四阶段 · 高级系统

**17. Tween（14 · headless + F5）**
- Targets：Sprite2D（modulate / position / scale / rotation 可视属性）
- headless 断言面：tween 启动后逐帧属性轨迹（Wait + get_position 采样）、on_tween_completed 触发标记
- F5 验收：缓动手感

**18. Debug（3 · 纯 headless）**：print / print_variable_value 直接收 stdout

**19. System（8 · 纯 headless）**：get_viewport_size / set_viewport_size / set_window_size / load_resource 属性回读断言；**quit 单独 mini 场景**跑退出码

**20. Time（10 · 纯 headless）**：主链 Wait 拉时距，get_delta_time / 计时类条件到点断言、on_countdown / on_cooldown_finished 触发标记；`--quit-after` 给足

**21. Rendering（6 · 纯 F5）**
- Targets：手搭 GPUParticles2D + PointLight2D + ShaderMaterial；CPUParticles2D 复用 death_explosion.tscn
- headless：只验无报错（GPUParticles2D 在 Dummy RenderingServer 下不模拟；CPUParticles2D 可断言 emitting 布尔）
- F5 验收：粒子、灯光、材质、screen_flash 全感官

**22. Navigation（3 · 纯 headless）**
- Targets：手搭 NavigationRegion2D（烘培简单网格）+ NavigationAgent2D + 目标点精灵
- 断言面：寻路路径非空/路径点数打印断言、check_path_available 真假分支、on_navigation_target_reached 触发标记（寻路是 CPU 运算，headless 完整可行）

**23. Event（2 · 纯 headless）**：send_event → on_receive_event 闭环 + 参数透传断言

---

## 七、执行顺序与里程碑

| 里程碑 | 内容 | 出口标准 |
|--------|------|---------|
| **M0 打样** | Arrays 场景走通全部六步（纯逻辑、无外部资源、preset 技能练手） | 打样 preset 过 validate，headless 三查全绿 |
| **M1** | A 层 12 场景（纯 headless）：Variables / Arrays / Dictionaries / Math / String / Flow Control / Transform / Debug / System / Time / Event / Navigation | 12 份 log 三查全绿 |
| **M2** | B 层 8 场景（headless + F5）：Animation / Audio / Camera / Physics / Movement / Node Operations / Scene / Tween | headless 三查全绿 + F5 感官项勾选 |
| **M3** | C 层 2（Input 驱动 / UI 合成）+ D 层 1（Rendering） | 同上 |
| **M4** | 覆盖审计 + 回填 | 差集为空（见下节） |

顺序理由：A 层无感官依赖、可批量自动化，先用它把 preset 生产线（技能 → validate → 导入 → headless 三查）跑稳；B/C/D 需要 F5，集中在后段人工时段一次过。

---

## 八、完成标准（Definition of Done）

1. 全部 preset 过 `validate_preset.tscn`（退出码 0）
2. 全部场景 headless log 三查通过（无 SCRIPT ERROR / 无 push_error / 无 FAIL: / PASS 计数达标）
3. **覆盖审计差集为空**：从 23 个 `test_deep_*.tscn` 提取组件脚本引用 + preset JSON 的 type 引用，与 `fuse_components.json` 310 项做差集（方法已验证可行——2026-08-28 复核策略文档即用此法）
4. B/C/D 层感官项 F5 逐项勾选
5. 结果回填《Fuse深度测试策略.md》第九节（新验证组件并入清单，更新百分比）
6. （可选）测试 preset 整理为官方示例场景包对外发布

---

## 九、执行记录

### M1 · A 层 12 场景（2026-08-28）✅ 全部完成

| 场景 | 结果 | 场景 | 结果 |
|------|------|------|------|
| Arrays(M0) | 23/23 | FlowControl | 23/23 |
| Debug | 3/3 | System | 10/10 |
| String | 10/10 | Time | 14/14 |
| Dictionaries | 18/18 | Event | 2/2 |
| Math | 12/12 | Transform | 6/6 |
| Variables | 24/25* | Navigation | 2+1(m)* |

全部 12 个 preset 过 validate 门禁；运行 0 SCRIPT ERROR / 0 FAIL。*两个带已知问题（下）。

**M1 挖出并修复的产品 bug（11 处，全部独立提交）**：

1. 10 个条件（String/Distance/Input/Physics/System/UI/Navigation/Animation 类）缺 `_get_property_list` 注册——参数在 .tres/.tscn 序列化时**静默丢失**（实测存 hello 取回空）
2. String 指令全族 + 2 String 条件 + CloneNode/GetViewportSize/LoadResourceByPath 调不存在的 `context.get_local/set_local`（正确 API get_variable/set_variable）——6 个指令一跑即崩
3. CheckVariable 等值比较 Packed*Array==Array 运行时崩溃（StringSplit 产出 PackedStringArray）
4. VectorOperation 直填向量值恒报类型错误（Variant 属性收字符串不转换，补运行时解析）
5. CheckDistance 把位于原点的节点误判为"没有 global_position"（GDScript 零向量为假值）
6. AddVariable/SwapVariables 实参互反（scope/value 交换）——AddVariable 一跑即崩（5+3=8 被当 scope 越界）
7. OnHealthChanged 调 Object 不存在的 has_property()
8. LOCAL 变量 Trigger meta 桥接只有写侧没有读侧——事件轮询恒 null
9. BreakLoop/ContinueLoop 调不存在的 is_in_loop + 错误方法名——BreakLoop 一进循环即崩
10. CheckComposite 内联条件字典从不反序列化，逻辑树无叶子恒假
11. MouseWorldPosition 调不存在的 context.has_node；OnNavigationTargetReached 缺属性注册（存储丢失病第 12 例）

**已知问题（M1 遗留，待专项）**：

1. **OnVariableChanged 在 L4+LOCAL 下不触发**——meta 桥接修复后读值仍 null，监控态藏于 RuntimeEventInstance 深处
2. **ContinueLoop 语义缺陷**——标志仅在迭代顶消费，"跳过下一迭代"而非"跳过本次剩余指令"（断言已按当前行为校准看守）
3. **NavigateToPosition / OnNavigationTargetReached 依赖外部轮询**——探针实证 NavigationAgent2D 的 `is_finished=true` 后 `navigation_finished` 信号仅在有人调用 `get_next_path_position()` 时才发射；Fuse 侧无轮询则指令永不完成（正常游戏由玩家移动代码的每帧轮询掩盖）

### M0 · Arrays 打样（2026-08-28）✅

六步全流程走通，出口标准全部达成：

| 项 | 结果 |
|----|------|
| preset | `presets/deep_arrays.json`（L2，75 条顶层指令，覆盖 Arrays 全部 18 指令 + 2 条件；ArrayRemove 验 INDEX/VALUE 双模式，两条件各验正反两例） |
| validate | 退出码 0，无 error（变量声明补全后无 W_VARIABLE_UNDECLARED；余 W_MISSING_PARAM 为省略默认参数的提示性告警，不阻断） |
| 场景 | `scenes/test_deep_arrays.tscn`，由 `tools/import_preset.gd` headless 生成（无需编辑器） |
| headless 三查 | 0 个 SCRIPT ERROR / push_error；0 个 FAIL；**23/23 唯一 PASS 标记**，与预期清单逐一对应；`deep_arrays DONE` 收尾 |
| lint | import_preset.gd gdlint 零违规 |

**M0 沉淀的两条硬经验**（后续场景通用）：

1. **Variant 属性收不到 Vector2 字面量**：`element_value` / `reference_position` 这类无类型 Variant 属性，JSON 里写 `"(1.0, 0.0)"` 会保持 String 不转换（PresetValueCodec 的引擎类型解析只对**类型化** Vector2 属性生效，如 `vector_b_value`）。向量数据须经 `MathExpression`（`expression: "Vector2(1, 0)"` + `output_type: 2`）运行时构造后以变量传递；断言用 CheckVariable 的 `check_with_another_variable` 做同型比较。
2. **PASS 行会双计**：每条指令的 Fuse INFO 日志会回显 Print 消息（带 ANSI 色码），grep 计数须去重（`sort -u`），验收以唯一标记数为准。

---

*🦊 知惠注：本计划的可回归部分（M0/M1）可以完全无人值守跑完；需要主人到场的只有 M2/M3 的 F5 感官验收——把它们攒到一批做，别一个场景叫一次。*

