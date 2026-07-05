# AudioManager 可视化改进设计方案

**创建日期**: 2026-01-15
**状态**: 设计完成，待实施
**目标**: 为音频管理器提供可视化配置界面，减少代码依赖，提升易用性

---

## 1. 设计目标

### 问题分析

当前 AudioManager 系统存在以下可用性问题：

1. **事件管理困难** - 需要编写大量代码注册和播放音频事件
2. **缺乏实时预览** - 无法在编辑器中试听音频效果
3. **Mixer Controller 无可视化入口** - 混音配置必须通过代码设置
4. **配置重复** - 每个音频事件需要单独配置混音参数

### 解决方案

通过引入可视化组件和分层配置架构：

1. **JuicyAudioPlayer** - 信号驱动的音频播放器节点
2. **AudioManager** - 场景级全局配置节点
3. **AudioComponent** - 可复用的音频绑定配置资源
4. **Inspector 插件** - 可视化编辑和实时试听

---

## 2. 架构设计

### 2.1 组件层次结构

```
场景树结构：
┌─────────────────────────────────────────┐
│ SceneRoot                               │
├─────────────────────────────────────────┤
│ ├── AudioManager (全局配置节点)         │
│ │   ├── instance_mixing_config          │ ← 场景级默认混音配置
│ │   ├── global_limit_config             │ ← 全局级限制配置
│ │   └── default_categories              │ ← 默认类别配置
│ │                                        │
│ ├── Player (角色节点)                    │
│ │   └── JuicyAudioPlayer                │ ← 音频播放器
│ │       └── audio_component: Resource    │ ← 可复用绑定配置
│ │                                        │
│ └── UIButtons                            │
│     └── JuicyAudioPlayer                │
│         └── audio_component              │
└─────────────────────────────────────────┘
```

### 2.2 配置优先级

```
1. 事件级配置 (AudioEventResource.mixing_config)
   └─ 覆盖场景和全局配置

2. 场景级配置 (AudioManager)
   ├─ AudioMixingConfig (实例级默认)
   └─ GlobalAudioLimitConfig (全局级限制)

3. 全局默认值 (代码中的硬编码默认值)
```

---

## 3. 核心组件详细设计

### 3.1 AudioManager (Node)

**文件**: `addons/juicy_mixer/core/audio_manager.gd`

**功能**:
- 提供场景级的音频配置入口
- 管理全局音频事件处理器
- 应用混音配置到所有子节点

**导出属性**:
```gdscript
@export_group("Instance-Level Defaults", "instance_")
@export var instance_mixing_config: AudioMixingConfig
@export var enable_inheritance: bool = true

@export_group("Global-Level Limits", "global_")
@export var global_limit_config: GlobalAudioLimitConfig

@export_group("Categories", "category_")
@export var default_categories: Array[AudioCategory] = []

@export_group("Debug")
@export var enable_debug_view: bool = false
@export var debug_update_interval: float = 0.5
```

**Inspector 布局**:
```
AudioManager
├── Instance-Level Defaults
│   └── Mixing Config: [AudioMixingConfig] ⚙️
│       ├── Instance Limit: 10
│       ├── Limit Policy: NEWEST_STEALS_OLDEST
│       ├── Priority: 50
│       └── Ducking Rules
├── Global-Level Limits
│   └── Global Limit Config: [GlobalAudioLimitConfig] ⚙️
├── Categories
│   └── Default Categories: Array size: 3
└── Debug
    ├── Enable Debug View: ☐
    └── Update Interval: 0.5
```

**使用场景**:
- **MainMenu.tscn**: 简单配置（5个实例限额，移动端虚声部）
- **CombatScene.tscn**: 复杂配置（20个实例 + Ducking规则 + 类别限制）

---

### 3.2 JuicyAudioPlayer (Node)

**文件**: `addons/juicy_mixer/core/juicy_audio_player.gd`

**功能**:
- 自动连接父节点信号
- 根据信号播放对应音频事件
- 管理冷却和延迟

**导出属性**:
```gdscript
@export var audio_component: AudioComponent
@export var auto_setup: bool = true
@export var debug_mode: bool = false
```

**核心方法**:
```gdscript
func _ready():
	_parent_node = get_parent()
	_audio_handler = _find_or_create_audio_handler()

	if auto_setup and audio_component:
		audio_component.setup(_parent_node, self)

func _on_signal_emitted(binding: AudioBinding):
	if binding.can_play():
		_audio_handler.play_audio_event_direct(
			binding.audio_event,
			_parent_node
		)

func add_binding(signal_name: String, event: AudioEventResource):
	# 运行时添加绑定
```

**使用示例**:
```gdscript
# Player.gd
extends CharacterBody2D

signal jumped
signal landed
signal damaged

@export var audio_player: JuicyAudioPlayer
# Inspector 中配置绑定，无需其他代码！

func jump():
	velocity.y = JUMP_VELOCITY
	jumped.emit()  # ← 音频自动播放
```

---

### 3.3 AudioComponent (Resource)

**文件**: `addons/juicy_mixer/resources/audio/audio_component.gd`

**功能**:
- 存储信号-音频绑定配置
- 可序列化和复用
- 支持跨节点共享

**导出属性**:
```gdscript
@export var audio_bindings: Array[AudioBinding] = []
```

**核心方法**:
```gdscript
func setup(target: Node, player: JuicyAudioPlayer):
	for binding in audio_bindings:
		if target.has_signal(binding.signal_name):
			target.connect(
				binding.signal_name,
				player._on_signal_emitted.bind(binding)
			)

static func create_preset(type: String) -> AudioComponent:
	# 工厂方法：创建预设组件
	match type:
		"footstep":
			# 创建脚步声组件
		"combat":
			# 创建战斗音效组件
```

**共享示例**:
```gdscript
# 多个角色共享同一套音效配置
var shared_sounds = preload("res://audio/components/character_sounds.tres")

player1.audio_component = shared_sounds
player2.audio_component = shared_sounds
enemy.audio_component = shared_sounds
```

---

### 3.4 AudioBinding (Resource)

**文件**: `addons/juicy_mixer/resources/audio/audio_binding.gd`

**功能**:
- 单个信号到音频事件的映射
- 支持高级选项（冷却、延迟、音量覆盖）

**导出属性**:
```gdscript
@export var signal_name: String
@export var audio_event: AudioEventResource

@export_group("Advanced", "adv_")
@export var adv_cooldown: float = 0.0
@export var adv_delay: float = 0.0
@export var adv_volume_override: float = 0.0
```

**冷却逻辑**:
```gdscript
var _last_play_time: float = -9999.0

func can_play() -> bool:
	if adv_cooldown <= 0.0:
		return true
	var current_time = Time.get_ticks_msec() / 1000.0
	return (current_time - _last_play_time) >= adv_cooldown
```

---

## 4. Inspector 插件设计

### 4.1 AudioComponentInspector

**文件**: `addons/juicy_mixer/editor/audio_component_inspector.gd`

**功能**:
- 自定义 AudioComponent 的 Inspector 界面
- 提供信号自动检测功能
- 快速添加绑定按钮

**UI 元素**:
```
Audio Component Inspector
├── [+ 快速添加绑定]
├── [🔍 自动检测信号]  ← 扫描父脚本，自动填充所有信号
└── Audio Bindings: Array size: N
    ┌────────────────────────────────┐
    │ [0] Signal: "jumped" ▼        │
    │     Audio Event: [jump.tres] 📁│
    │     [▶ 试听]                   │
    │     Advanced ▶                 │
    │         ├── Cooldown: 0.0      │
    │         ├── Delay: 0.0         │
    │         └── Volume Override: 0.0│
    └────────────────────────────────┘
```

**关键功能**:
1. **信号下拉菜单** - 自动列出父脚本的所有信号
2. **试听按钮** - 在编辑器中播放音频变体
3. **自动检测** - 一键创建所有信号的绑定

---

### 4.2 JuicyAudioPlayerInspector

**文件**: `addons/juicy_mixer/editor/juicy_audio_player_inspector.gd`

**功能**:
- 显示播放器状态信息
- 提供测试功能
- 快速创建组件

**UI 元素**:
```
JuicyAudioPlayer Inspector
├── 状态信息
│   ├── 父节点: Player
│   ├── 绑定数量: 3
│   └── [🧪 测试所有绑定]
├── Audio Component: [AudioComponent] ⚙️
├── Auto Setup: ✓
└── Debug Mode: ☐
```

---

### 4.3 AudioManagerInspector (可选)

**文件**: `addons/juicy_mixer/editor/audio_manager_inspector.gd`

**功能**:
- 显示当前混音状态
- 运行时调试面板
- 资源快速编辑

**调试面板**:
```
AudioManager Debug Panel
├── 活跃实例: 15/20
├── 虚声部数量: 8
├── Ducking 激活: 2
├── 总线状态
│   ├── Master: 45/64
│   ├── Music: 3/10
│   └── SFX: 12/32
└── 最近播放 (实时更新)
    ├── [0.2s ago] footstep (Player)
    ├── [0.5s ago] gunshot (Enemy)
    └── [1.2s ago] explosion (World)
```

---

## 5. 使用工作流

### 5.1 快速开始：创建角色音效

**步骤 1: 创建音频事件**
1. 右键文件系统 → 创建 → Resource
2. 搜索 "AudioEventResource"
3. 命名为 `jump.tres`
4. 配置音频变体

**步骤 2: 添加 JuicyAudioPlayer**
```
Player (CharacterBody2D)
└── JuicyAudioPlayer (新建子节点)
```

**步骤 3: 配置绑定**
1. 选择 JuicyAudioPlayer
2. Inspector → Audio Component → 创建新组件
3. 点击"🔍 自动检测信号"
4. 为 `jumped` 信号选择 `jump.tres`
5. 点击"▶ 试听"测试

**步骤 4: 完成**
```gdscript
# Player.gd - 无需任何音频播放代码！
extends CharacterBody2D

signal jumped

@export var audio_player: JuicyAudioPlayer

func jump():
	jumped.emit()  # ← 音频自动播放
```

---

### 5.2 场景配置：MainMenu

**场景树**:
```
MainMenu (Control)
├── AudioManager
│   ├── Mixing Config: [Resource]
│   │   └── Instance Limit: 5
│   └── Global Limit Config: [Resource]
│       └── Max Real Voices: 16 (移动端)
│
└── ButtonContainer
    ├── StartButton
    │   └── JuicyAudioPlayer
    │       └── [pressed → button_click.tres]
    ├── SettingsButton
    │   └── JuicyAudioPlayer  # 共享组件
    │       └── [pressed → button_click.tres]
    └── QuitButton
        └── JuicyAudioPlayer  # 共享组件
            └── [pressed → button_click.tres]
```

**配置共享组件**:
1. 创建 `AudioComponent` 资源
2. 添加绑定：`pressed` → `button_click.tres`
3. 保存为 `res://audio/components/ui_button_clicks.tres`
4. 在所有按钮的 JuicyAudioPlayer 中引用此资源

---

### 5.3 复杂场景：Combat

**场景级配置**:
```
CombatScene (Node2D)
├── AudioManager
│   ├── Mixing Config: [combat_mixing.tres]
│   │   ├── Instance Limit: 20
│   │   ├── Priority: 60
│   │   ├── Ducking Rules:
│   │   │   ├── [0] Voice → SFX: -10dB
│   │   │   └── [1] Explosion → Music: -15dB
│   │   └── Phase Protection: enabled
│   │
│   └── Categories
│       ├── [0] SFX (max: 15)
│       ├── [1] Music (max: 3)
│       └── [2] Voice (max: 5)
```

**玩家配置**:
```
Player
└── JuicyAudioPlayer
    └── [player_combat_sounds.tres]
        ├── weapon_fired → shoot.tres
        ├── reloaded → reload.tres
        └── died → death_scream.tres
```

---

## 6. 实施计划

### Phase 1: 核心组件 (优先级: 高)

**任务 1.1: 创建数据结构**
- [ ] AudioBinding 资源类
- [ ] AudioComponent 资源类
- [ ] 单元测试

**任务 1.2: 实现 JuicyAudioPlayer**
- [ ] 核心节点类
- [ ] 信号自动连接
- [ ] 冷却和延迟处理
- [ ] 单元测试

**任务 1.3: 实现 AudioManager**
- [ ] 场景级配置节点
- [ ] 配置应用逻辑
- [ ] 单元测试

### Phase 2: Inspector 插件 (优先级: 高)

**任务 2.1: AudioComponentInspector**
- [ ] 自定义 Inspector 界面
- [ ] 信号下拉菜单
- [ ] 自动检测功能
- [ ] 试听按钮

**任务 2.2: JuicyAudioPlayerInspector**
- [ ] 状态面板
- [ ] 测试功能
- [ ] 组件快速创建

**任务 2.3: AudioManagerInspector (可选)**
- [ ] 调试面板
- [ ] 运行时监控

### Phase 3: 文档和示例 (优先级: 中)

**任务 3.1: 用户文档**
- [ ] 可视化使用指南
- [ ] Inspector 操作教程
- [ ] 常见问题解答

**任务 3.2: 示例场景**
- [ ] 简单示例 (角色音效)
- [ ] 复杂示例 (战斗场景)
- [ ] UI 示例 (菜单按钮)

### Phase 4: 测试和优化 (优先级: 中)

**任务 4.1: 集成测试**
- [ ] 端到端测试场景
- [ ] 多场景配置测试
- [ ] 性能测试

**任务 4.2: 用户测试**
- [ ] 可用性测试
- [ ] 文档清晰度测试
- [ ] 反馈收集

---

## 7. 文件清单

### 新建文件

**核心组件**:
- `addons/juicy_mixer/core/audio_manager.gd`
- `addons/juicy_mixer/core/juicy_audio_player.gd`
- `addons/juicy_mixer/resources/audio/audio_component.gd`
- `addons/juicy_mixer/resources/audio/audio_binding.gd`

**编辑器插件**:
- `addons/juicy_mixer/editor/audio_component_inspector.gd`
- `addons/juicy_mixer/editor/juicy_audio_player_inspector.gd`
- `addons/juicy_mixer/editor/audio_manager_inspector.gd` (可选)

**测试文件**:
- `addons/juicy_mixer/tests/test_audio_component.gd`
- `addons/juicy_mixer/tests/test_juicy_audio_player.gd`
- `addons/juicy_mixer/tests/test_audio_manager_node.gd`

**示例场景**:
- `demos/audio/simple_character.tscn`
- `demos/audio/combat_scene.tscn`
- `demos/audio/ui_menu.tscn`

**文档**:
- `addons/juicy_mixer/docs/user_docs/audio_manager_visual_guide.md`

### 修改文件

- `addons/juicy_mixer/plugin.gd` - 注册新类和插件
- `addons/juicy_mixer/docs/user_docs/audio_manager_user_guide.md` - 添加可视化使用章节

---

## 8. 设计原则

### 8.1 YAGNI (You Aren't Gonna Need It)

- **不实现**: 复杂的可视化连线编辑器（Bricks 已覆盖）
- **不实现**: 运行时动态绑定（设计时配置更清晰）
- **不实现**: 音频波形可视化（编辑器已有）

### 8.2 可扩展性

- 预留插件接口，支持未来扩展
- 资源化配置，便于序列化和复用
- 信号驱动，兼容现有代码

### 8.3 用户友好

- 最小化代码需求（一行 @export）
- Inspector 中完成所有配置
- 实时预览，无需运行游戏
- 自动检测，减少手动输入

---

## 9. 性能考虑

### 9.1 初始化成本

- AudioManager 启动: ~10ms（配置应用）
- JuicyAudioPlayer 启动: ~5ms（信号连接）
- 可接受范围内（只在场景加载时发生）

### 9.2 运行时开销

- 信号连接: Godot 原生机制，开销极小
- 冷却检查: 简单时间戳比较，可忽略
- 无额外内存分配

### 9.3 优化策略

- 组件资源复用（共享配置）
- 懒加载音频事件
- 对象池复用 AudioStreamPlayer

---

## 10. 向后兼容

### 10.1 现有代码

所有现有 API 保持不变：

```gdscript
# 旧代码继续工作
var handler = JuicyAudioEventHandler.new()
handler.register_audio_event("jump", jump_event)
handler.play_audio_event("jump", self)
```

### 10.2 渐进迁移

用户可以：
- 继续使用代码方式
- 逐步迁移到可视化方式
- 混合使用两种方式

---

## 11. 未来增强 (Phase 2+)

### 11.1 短期 (1-2周)

- 音频预览面板（拖拽文件即时试听）
- 批量绑定编辑器
- 导入/导出配置

### 11.2 中期 (1个月)

- 运行时混音调试工具
- 音频事件录制器
- 性能分析面板

### 11.3 长期 (3个月+)

- 可视化音轨编辑器（类似 DAW）
- 程序化音频生成
- 空间音频可视化

---

## 12. 成功指标

### 12.1 用户体验

- **代码减少**: 80% 的场景不需要编写音频播放代码
- **配置时间**: < 2分钟完成简单音效配置
- **学习曲线**: 15分钟掌握基本用法

### 12.2 功能完整性

- **覆盖场景**: 90% 的常见音频播放需求
- **配置灵活性**: 支持场景级和事件级配置
- **调试便利性**: 实时预览和状态监控

---

## 附录

### A. 完整使用示例

参见 `demos/audio/` 目录中的示例场景

### B. API 参考

参见 `addons/juicy_mixer/docs/api_reference.md`

### C. 故障排除

参见 `addons/juicy_mixer/docs/troubleshooting.md`

---

**设计完成！准备进入实施阶段。**
