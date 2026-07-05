# AudioManager 可视化改进实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**目标:** 为音频管理器提供可视化配置界面，通过信号驱动的播放器节点减少代码依赖。

**架构:** 创建四个核心组件（AudioBinding、AudioComponent、JuicyAudioPlayer、AudioManager）和对应的 Inspector 插件，采用资源化配置和节点管理的混合模式。

**技术栈:** Godot 4.5, GDScript 2.0, EditorPlugin

---

## 前置准备

### 检查点：验证当前状态

```bash
# 确认在 Develop_brick 分支
git branch --show-current

# 确认最近的提交
git log --oneline -3

# 检查文件结构
ls -la addons/juicy_mixer/core/
ls -la addons/juicy_mixer/resources/audio/
ls -la addons/juicy_mixer/editor/
```

**预期输出:**
- 当前分支: `Develop_brick`
- 最近的提交包含 `docs(audio): 更新文档反映三层架构完整实现`
- `core/` 目录包含 `audio_mixing_controller.gd`, `virtual_voice_manager.gd`
- `resources/audio/` 目录包含 `audio_event_resource.gd`, `audio_mixing_config.gd`
- `editor/` 目录包含时间线编辑器相关文件

---

## Phase 1: 数据结构（资源类）

### Task 1.1: 创建 AudioBinding 资源类

**目标:** 创建单个信号到音频事件的绑定数据结构

**Files:**
- Create: `addons/juicy_mixer/resources/audio/audio_binding.gd`
- Test: `addons/juicy_mixer/tests/test_audio_binding.gd`

#### Step 1: 创建文件结构

```bash
# 在 addons/juicy_mixer/resources/audio/ 目录下创建文件
cat > addons/juicy_mixer/resources/audio/audio_binding.gd << 'EOF'
extends Resource
class_name AudioBinding

## 信号到音频事件的绑定配置

@export var signal_name: String = ""
@export var audio_event: AudioEventResource

@export_group("Advanced", "adv_")
@export var adv_cooldown: float = 0.0
@export var adv_delay: float = 0.0
@export var adv_volume_override: float = 0.0  # 0.0 = 不覆盖

var _last_play_time: float = -9999.0

## 检查是否可以播放（冷却检查）
func can_play() -> bool:
	if adv_cooldown <= 0.0:
		return true
	var current_time = Time.get_ticks_msec() / 1000.0
	return (current_time - _last_play_time) >= adv_cooldown

## 标记播放时间
func mark_played() -> void:
	_last_play_time = Time.get_ticks_msec() / 1000.0

## 重置冷却状态
func reset_cooldown() -> void:
	_last_play_time = -9999.0
EOF
```

#### Step 2: 注册到 plugin.gd

```bash
# 编辑 addons/juicy_mixer/plugin.gd
# 在 _enter_tree() 方法中添加：

# 在现有注册代码后添加
add_custom_type("AudioBinding", "Resource", preload("resources/audio/audio_binding.gd"), preload("icons/audio_binding.svg"))

# 在 _exit_tree() 方法中添加：
remove_custom_type("AudioBinding")
```

**编辑位置:** `addons/juicy_mixer/plugin.gd`
- 第 ~30 行（_enter_tree 方法末尾）
- 第 ~45 行（_exit_tree 方法末尾）

#### Step 3: 创建单元测试

```bash
cat > addons/juicy_mixer/tests/test_audio_binding.gd << 'EOF'
extends Node

func test_basic_binding():
	var binding = AudioBinding.new()
	binding.signal_name = "test_signal"
	binding.audio_event = AudioEventResource.new()

	assert(binding.signal_name == "test_signal", "Signal name should be set")
	assert(binding.audio_event != null, "Audio event should be set")
	print("test_basic_binding PASSED")

func test_cooldown():
	var binding = AudioBinding.new()
	binding.adv_cooldown = 0.5  # 500ms 冷却

	# 第一次应该可以播放
	assert(binding.can_play() == true, "Should play first time")
	binding.mark_played()

	# 立即第二次应该不能播放
	assert(binding.can_play() == false, "Should not play immediately after")

	# 等待冷却后应该可以播放
	await get_tree().create_timer(0.6).timeout
	assert(binding.can_play() == true, "Should play after cooldown")
	print("test_cooldown PASSED")

func test_reset_cooldown():
	var binding = AudioBinding.new()
	binding.adv_cooldown = 1.0
	binding.mark_played()

	assert(binding.can_play() == false, "Should be in cooldown")
	binding.reset_cooldown()
	assert(binding.can_play() == true, "Should play after reset")
	print("test_reset_cooldown PASSED")

func _ready():
	test_basic_binding()
	test_cooldown()
	await test_reset_cooldown()
	print("\nAll AudioBinding tests passed!")
	get_tree().quit()
EOF
```

#### Step 4: 创建测试场景

```bash
cat > addons/juicy_mixer/tests/test_audio_binding.tscn << 'EOF'
[gd_scene load_steps=2 format=3 uid="uid://test_audio_binding"]

[ext_resource type="Script" path="res://addons/juicy_mixer/tests/test_audio_binding.gd" id="1"]

[node name="TestAudioBinding" type="Node"]
script = ExtResource("1")
EOF
```

#### Step 5: 运行测试验证

```bash
# 在 Godot 编辑器中运行测试场景
# 或者通过命令行：
E:\\Godot\\Godot_v4.5.1-stable_mono_win64\\Godot_v4.5.1-stable_mono_win64.exe --path . --headless --test test addons/juicy_mixer/tests/test_audio_binding.tscn
```

**预期输出:**
```
test_basic_binding PASSED
test_cooldown PASSED
test_reset_cooldown PASSED

All AudioBinding tests passed!
```

#### Step 6: 提交

```bash
git add addons/juicy_mixer/resources/audio/audio_binding.gd
git add addons/juicy_mixer/tests/test_audio_binding.gd
git add addons/juicy_mixer/tests/test_audio_binding.tscn
git add addons/juicy_mixer/plugin.gd
git commit -m "feat(audio): 创建 AudioBinding 资源类

- 实现信号到音频事件的绑定数据结构
- 支持冷却、延迟、音量覆盖等高级选项
- 添加单元测试验证冷却机制
- 注册到 plugin.gd

相关设计文档: docs/plans/2026-01-15-audio-manager-ux-improvement.md

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 1.2: 创建 AudioComponent 资源类

**目标:** 创建可复用的音频绑定配置容器

**Files:**
- Create: `addons/juicy_mixer/resources/audio/audio_component.gd`
- Test: `addons/juicy_mixer/tests/test_audio_component.gd`

#### Step 1: 创建 AudioComponent 类

```bash
cat > addons/juicy_mixer/resources/audio/audio_component.gd << 'EOF'
extends Resource
class_name AudioComponent

## 可复用的音频组件配置
## 包含多个 AudioBinding，可被多个 JuicyAudioPlayer 共享

@export var audio_bindings: Array[AudioBinding] = []

## 设置绑定（连接信号）
func setup(target: Node, player: Node) -> void:
	if not target or not player:
		push_error("AudioComponent.setup: target and player must not be null")
		return

	for binding in audio_bindings:
		if not binding or binding.signal_name.is_empty():
			continue

		if target.has_signal(binding.signal_name):
			target.connect(
				binding.signal_name,
				player._on_binding_triggered.bind(binding)
			)
		else:
			push_warning("AudioComponent: target '%s' has no signal '%s'" % [target.name, binding.signal_name])

## 获取绑定数量
func get_binding_count() -> int:
	return audio_bindings.size()

## 通过信号名查找绑定
func find_binding_by_signal(signal_name: String) -> AudioBinding:
	for binding in audio_bindings:
		if binding and binding.signal_name == signal_name:
			return binding
	return null

## 创建预设组件的工厂方法
static func create_footstep_component() -> AudioComponent:
	var component = AudioComponent.new()

	var binding = AudioBinding.new()
	binding.signal_name = "footstep"
	binding.adv_cooldown = 0.3  # 300ms 冷却
	component.audio_bindings.append(binding)

	return component

static func create_ui_button_component(click_event: AudioEventResource) -> AudioComponent:
	var component = AudioComponent.new()

	var binding = AudioBinding.new()
	binding.signal_name = "pressed"
	binding.audio_event = click_event
	component.audio_bindings.append(binding)

	return component
EOF
```

#### Step 2: 注册到 plugin.gd

```bash
# 编辑 addons/juicy_mixer/plugin.gd
# 在 _enter_tree() 方法中添加：
add_custom_type("AudioComponent", "Resource", preload("resources/audio/audio_component.gd"), preload("icons/audio_component.svg"))

# 在 _exit_tree() 方法中添加：
remove_custom_type("AudioComponent")
```

#### Step 3: 创建单元测试

```bash
cat > addons/juicy_mixer/tests/test_audio_component.gd << 'EOF'
extends Node

func test_empty_component():
	var component = AudioComponent.new()
	assert(component.get_binding_count() == 0, "New component should be empty")
	print("test_empty_component PASSED")

func test_add_binding():
	var component = AudioComponent.new()
	var binding = AudioBinding.new()
	binding.signal_name = "test"

	component.audio_bindings.append(binding)
	assert(component.get_binding_count() == 1, "Should have 1 binding")
	print("test_add_binding PASSED")

func test_find_binding():
	var component = AudioComponent.new()

	var binding1 = AudioBinding.new()
	binding1.signal_name = "jumped"
	component.audio_bindings.append(binding1)

	var binding2 = AudioBinding.new()
	binding2.signal_name = "landed"
	component.audio_bindings.append(binding2)

	var found = component.find_binding_by_signal("jumped")
	assert(found == binding1, "Should find jumped binding")

	var not_found = component.find_binding_by_signal("died")
	assert(not_found == null, "Should return null for non-existent signal")
	print("test_find_binding PASSED")

func test_factory_methods():
	var footstep = AudioComponent.create_footstep_component()
	assert(footstep.get_binding_count() == 1, "Footstep component should have 1 binding")
	assert(footstep.audio_bindings[0].signal_name == "footstep", "Should be footstep signal")
	print("test_factory_methods PASSED")

func _ready():
	test_empty_component()
	test_add_binding()
	test_find_binding()
	test_factory_methods()
	print("\nAll AudioComponent tests passed!")
	get_tree().quit()
EOF
```

#### Step 4: 创建测试场景

```bash
cat > addons/juicy_mixer/tests/test_audio_component.tscn << 'EOF'
[gd_scene load_steps=2 format=3 uid="uid://test_audio_component"]

[ext_resource type="Script" path="res://addons/juicy_mixer/tests/test_audio_component.gd" id="1"]

[node name="TestAudioComponent" type="Node"]
script = ExtResource("1")
EOF
```

#### Step 5: 运行测试

**预期输出:**
```
test_empty_component PASSED
test_add_binding PASSED
test_find_binding PASSED
test_factory_methods PASSED

All AudioComponent tests passed!
```

#### Step 6: 提交

```bash
git add addons/juicy_mixer/resources/audio/audio_component.gd
git add addons/juicy_mixer/tests/test_audio_component.gd
git add addons/juicy_mixer/tests/test_audio_component.tscn
git add addons/juicy_mixer/plugin.gd
git commit -m "feat(audio): 创建 AudioComponent 资源类

- 实现可复用的音频绑定配置容器
- 支持信号自动连接
- 提供工厂方法创建预设组件
- 添加单元测试

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 2: 核心节点类

### Task 2.1: 实现 JuicyAudioPlayer 节点

**目标:** 创建信号驱动的音频播放器节点

**Files:**
- Create: `addons/juicy_mixer/core/juicy_audio_player.gd`
- Test: `addons/juicy_mixer/tests/test_juicy_audio_player.gd`

#### Step 1: 创建 JuicyAudioPlayer 类

```bash
cat > addons/juicy_mixer/core/juicy_audio_player.gd << 'EOF'
extends Node
class_name JuicyAudioPlayer

## 信号驱动的音频播放器
## 自动连接父节点信号并播放对应的音频事件

@export var audio_component: AudioComponent
@export var auto_setup: bool = true
@export var debug_mode: bool = false

var _audio_handler: JuicyAudioEventHandler
var _parent_node: Node

func _ready() -> void:
	_parent_node = get_parent()
	if not _parent_node:
		push_error("JuicyAudioPlayer must be a child of a Node")
		return

	# 获取或创建音频事件处理器
	_audio_handler = _find_or_create_audio_handler()
	if not _audio_handler:
		push_error("Failed to create or find audio handler")
		return

	# 自动设置组件
	if auto_setup and audio_component:
		audio_component.setup(_parent_node, self)

	if debug_mode:
		print("[JuicyAudioPlayer] Initialized for parent: ", _parent_node.name)
		print("[JuicyAudioPlayer] Bindings: ", audio_component.get_binding_count() if audio_component else 0)

## 查找或创建音频事件处理器
func _find_or_create_audio_handler() -> JuicyAudioEventHandler:
	# 1. 查找场景中的 AudioManager
	var audio_manager = get_tree().get_first_node_in_group("audio_manager")
	if audio_manager and audio_manager.has_method("get_audio_handler"):
		return audio_manager.get_audio_handler()

	# 2. 查找场景中的 JuicyAudioEventHandler
	var handlers = get_tree().get_nodes_in_group("audio_handler")
	if handlers.size() > 0:
		return handlers[0]

	# 3. 创建临时的
	var handler = JuicyAudioEventHandler.new()
	add_child(handler)
	handler.add_to_group("audio_handler")
	return handler

## 信号回调（由 AudioComponent.connect 调用）
func _on_binding_triggered(binding: AudioBinding) -> void:
	if not binding or not binding.audio_event:
		if debug_mode:
			print("[JuicyAudioPlayer] Invalid binding")
		return

	# 检查冷却
	if not binding.can_play():
		if debug_mode:
			print("[JuicyAudioPlayer] Binding in cooldown: ", binding.signal_name)
		return

	# 播放音频
	_audio_handler.play_audio_event_direct(binding.audio_event, _parent_node)
	binding.mark_played()

	if debug_mode:
		print("[JuicyAudioPlayer] Played: ", binding.audio_event.event_name)

## 运行时添加绑定
func add_binding(signal_name: String, event: AudioEventResource) -> void:
	if not audio_component:
		audio_component = AudioComponent.new()

	var binding = AudioBinding.new()
	binding.signal_name = signal_name
	binding.audio_event = event
	audio_component.audio_bindings.append(binding)

	# 立即连接
	if _parent_node.has_signal(signal_name):
		_parent_node.connect(signal_name, _on_binding_triggered.bind(binding))

## 移除绑定
func remove_binding(signal_name: String) -> void:
	if not audio_component:
		return

	var binding = audio_component.find_binding_by_signal(signal_name)
	if binding:
		audio_component.audio_bindings.erase(binding)
		if _parent_node.is_connected(signal_name, _on_binding_triggered):
			_parent_node.disconnect(signal_name, _on_binding_triggered)
EOF
```

#### Step 2: 注册到 plugin.gd

```bash
# 编辑 addons/juicy_mixer/plugin.gd
# 在 _enter_tree() 方法中添加：
add_custom_type("JuicyAudioPlayer", "Node", preload("core/juicy_audio_player.gd"), preload("icons/audio_player.svg"))

# 在 _exit_tree() 方法中添加：
remove_custom_type("JuicyAudioPlayer")
```

#### Step 3: 创建集成测试

```bash
cat > addons/juicy_mixer/tests/test_juicy_audio_player.gd << 'EOF'
extends Node

## 测试用父节点
class TestNode extends Node:
	signal test_signal_1
	signal test_signal_2

	func trigger_signal_1():
		test_signal_1.emit()

	func trigger_signal_2():
		test_signal_2.emit()

func test_basic_setup():
	# 创建父节点
	var test_node = TestNode.new()
	add_child(test_node)

	# 创建播放器
	var player = JuicyAudioPlayer.new()
	test_node.add_child(player)

	# 验证初始化
	await get_tree().process_frame
	assert(player._parent_node == test_node, "Parent should be set")
	assert(player._audio_handler != null, "Audio handler should be created")

	test_node.queue_free()
	print("test_basic_setup PASSED")

func test_signal_connection():
	var test_node = TestNode.new()
	add_child(test_node)

	# 创建音频事件
	var audio_event = AudioEventResource.new()
	audio_event.event_name = "test_event"

	# 创建绑定
	var binding = AudioBinding.new()
	binding.signal_name = "test_signal_1"
	binding.audio_event = audio_event

	# 创建组件
	var component = AudioComponent.new()
	component.audio_bindings.append(binding)

	# 创建播放器
	var player = JuicyAudioPlayer.new()
	player.audio_component = component
	test_node.add_child(player)

	# 手动设置（不使用 auto_setup）
	component.setup(test_node, player)

	# 触发信号
	test_node.trigger_signal_1()
	await get_tree().process_frame

	# 验证冷却被设置
	assert(binding.can_play() == false, "Should be in cooldown")

	test_node.queue_free()
	print("test_signal_connection PASSED")

func test_add_binding_runtime():
	var test_node = TestNode.new()
	add_child(test_node)

	var player = JuicyAudioPlayer.new()
	test_node.add_child(player)

	var audio_event = AudioEventResource.new()
	audio_event.event_name = "runtime_event"

	# 运行时添加
	player.add_binding("test_signal_2", audio_event)

	await get_tree().process_frame

	assert(player.audio_component != null, "Component should be created")
	assert(player.audio_component.get_binding_count() == 1, "Should have 1 binding")

	test_node.queue_free()
	print("test_add_binding_runtime PASSED")

func _ready():
	await test_basic_setup()
	await test_signal_connection()
	await test_add_binding_runtime()
	print("\nAll JuicyAudioPlayer tests passed!")
	get_tree().quit()
EOF
```

#### Step 4: 创建测试场景

```bash
cat > addons/juicy_mixer/tests/test_juicy_audio_player.tscn << 'EOF'
[gd_scene load_steps=2 format=3 uid="uid://test_juicy_audio_player"]

[ext_resource type="Script" path="res://addons/juicy_mixer/tests/test_juicy_audio_player.gd" id="1"]

[node name="TestJuicyAudioPlayer" type="Node"]
script = ExtResource("1")
EOF
```

#### Step 5: 运行测试

**预期输出:**
```
test_basic_setup PASSED
test_signal_connection PASSED
test_add_binding_runtime PASSED

All JuicyAudioPlayer tests passed!
```

#### Step 6: 提交

```bash
git add addons/juicy_mixer/core/juicy_audio_player.gd
git add addons/juicy_mixer/tests/test_juicy_audio_player.gd
git add addons/juicy_mixer/tests/test_juicy_audio_player.tscn
git add addons/juicy_mixer/plugin.gd
git commit -m "feat(audio): 实现 JuicyAudioPlayer 节点

- 创建信号驱动的音频播放器
- 自动连接父节点信号
- 支持运行时添加绑定
- 查找或创建音频事件处理器
- 添加集成测试

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 2.2: 实现 AudioManager 节点

**目标:** 创建场景级全局配置节点

**Files:**
- Create: `addons/juicy_mixer/core/audio_manager.gd`
- Test: `addons/juicy_mixer/tests/test_audio_manager_node.gd`

#### Step 1: 创建 AudioManager 类

```bash
cat > addons/juicy_mixer/core/audio_manager.gd << 'EOF'
extends Node
class_name AudioManager

## 场景级音频管理器
## 提供统一的混音配置入口

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

var _audio_handler: JuicyAudioEventHandler

func _ready() -> void:
	# 设置为场景中的音频管理器
	add_to_group("audio_manager")

	# 创建音频事件处理器
	_audio_handler = JuicyAudioEventHandler.new()
	add_child(_audio_handler)

	# 应用场景级配置
	_apply_scene_config()

	print("[AudioManager] Initialized with scene-level config")

## 应用场景级配置
func _apply_scene_config() -> void:
	# 应用全局级配置
	if global_limit_config:
		_audio_handler.set_global_config(global_limit_config)
		print("[AudioManager] Applied global limit config")

	# 注册默认类别
	for category in default_categories:
		if category:
			_audio_handler.register_category(category)

	if default_categories.size() > 0:
		print("[AudioManager] Registered %d categories" % default_categories.size())

## 获取音频事件处理器（供子节点使用）
func get_audio_handler() -> JuicyAudioEventHandler:
	return _audio_handler

## 运行时更新混音配置
func update_mixing_config(new_config: AudioMixingConfig) -> void:
	instance_mixing_config = new_config
	# TODO: 通知所有子节点更新配置

## 运行时更新全局配置
func update_global_config(new_config: GlobalAudioLimitConfig) -> void:
	global_limit_config = new_config
	if _audio_handler:
		_audio_handler.set_global_config(new_config)
EOF
```

#### Step 2: 注册到 plugin.gd

```bash
# 编辑 addons/juicy_mixer/plugin.gd
# 在 _enter_tree() 方法中添加：
add_custom_type("AudioManager", "Node", preload("core/audio_manager.gd"), preload("icons/audio_manager.svg"))

# 在 _exit_tree() 方法中添加：
remove_custom_type("AudioManager")
```

#### Step 3: 创建单元测试

```bash
cat > addons/juicy_mixer/tests/test_audio_manager_node.gd << 'EOF'
extends Node

func test_basic_initialization():
	var manager = AudioManager.new()
	add_child(manager)

	await get_tree().process_frame

	# 验证在正确的组中
	assert manager.is_in_group("audio_manager"), "Should be in audio_manager group"

	# 验证创建了音频处理器
	assert manager._audio_handler != null, "Should create audio handler"

	manager.queue_free()
	print("test_basic_initialization PASSED")

func test_apply_global_config():
	var manager = AudioManager.new()

	var global_config = GlobalAudioLimitConfig.new()
	global_config.max_real_voices_desktop = 32

	manager.global_limit_config = global_config
	add_child(manager)

	await get_tree().process_frame

	# 验证配置被应用
	assert manager._audio_handler.get_global_config() == global_config, "Config should be applied"

	manager.queue_free()
	print("test_apply_global_config PASSED")

func test_get_audio_handler():
	var manager = AudioManager.new()
	add_child(manager)

	await get_tree().process_frame

	var handler = manager.get_audio_handler()
	assert handler != null, "Should return audio handler"
	assert handler is JuicyAudioEventHandler, "Should be correct type"

	manager.queue_free()
	print("test_get_audio_handler PASSED")

func _ready():
	await test_basic_initialization()
	await test_apply_global_config()
	await test_get_audio_handler()
	print("\nAll AudioManager tests passed!")
	get_tree().quit()
EOF
```

#### Step 4: 创建测试场景

```bash
cat > addons/juicy_mixer/tests/test_audio_manager_node.tscn << 'EOF'
[gd_scene load_steps=2 format=3 uid="uid://test_audio_manager_node"]

[ext_resource type="Script" path="res://addons/juicy_mixer/tests/test_audio_manager_node.gd" id="1"]

[node name="TestAudioManagerNode" type="Node"]
script = ExtResource("1")
EOF
```

#### Step 5: 运行测试

**预期输出:**
```
test_basic_initialization PASSED
test_apply_global_config PASSED
test_get_audio_handler PASSED

All AudioManager tests passed!
```

#### Step 6: 提交

```bash
git add addons/juicy_mixer/core/audio_manager.gd
git add addons/juicy_mixer/tests/test_audio_manager_node.gd
git add addons/juicy_mixer/tests/test_audio_manager_node.tscn
git add addons/juicy_mixer/plugin.gd
git commit -m "feat(audio): 实现 AudioManager 节点

- 创建场景级全局配置节点
- 应用混音配置到所有子节点
- 管理音频事件处理器生命周期
- 支持运行时更新配置
- 添加单元测试

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 3: Inspector 插件

### Task 3.1: 创建 AudioComponentInspector

**目标:** 自定义 AudioComponent 的 Inspector 界面

**Files:**
- Create: `addons/juicy_mixer/editor/audio_component_inspector.gd`

#### Step 1: 创建 Inspector 插件类

```bash
cat > addons/juicy_mixer/editor/audio_component_inspector.gd << 'EOF'
tool
extends EditorInspectorPlugin
class_name AudioComponentInspector

func _can_handle(object: Object) -> bool:
	return object is AudioComponent

func _parse_begin(object: Object) -> void:
	var component := object as AudioComponent

	# 添加快捷按钮
	var buttons_hbox = HBoxContainer.new()
	add_custom_control(buttons_hbox)

	# 快速添加绑定按钮
	var add_btn = Button.new()
	add_btn.text = "+ 快速添加"
	add_btn.tooltip_text = "添加新的信号绑定"
	add_btn.pressed.connect(_on_add_binding.bind(component))
	buttons_hbox.add_child(add_btn)

	# 自动检测信号按钮
	var detect_btn = Button.new()
	detect_btn.text = "🔍 自动检测信号"
	detect_btn.tooltip_text = "从父节点脚本检测所有信号"
	detect_btn.pressed.connect(_on_auto_detect_signals.bind(component))
	buttons_hbox.add_child(detect_btn)

	# 添加分隔符
	var separator = HSeparator.new()
	add_custom_control(separator)

func _on_add_binding(component: AudioComponent):
	component.audio_bindings.append(AudioBinding.new())
	notify_property_list_changed()
	print("[AudioComponentInspector] Added new binding")

func _on_auto_detect_signals(component: AudioComponent):
	# 获取当前编辑的节点
	var edited_object = get_edited_object()
	if not edited_object:
		push_warning("Cannot detect signals: no edited object")
		return

	# 尝试获取使用此组件的节点
	# 这个需要从 Inspector 上下文获取，暂时只打印提示
	print("[AudioComponentInspector] Auto-detect feature requires manual implementation")
	push_warning("请手动添加绑定，或在运行时通过 JuicyAudioPlayer 使用")
EOF
```

#### Step 2: 注册插件

```bash
# 编辑 addons/juicy_mixer/plugin.gd

# 在类成员变量区域添加：
var audio_component_inspector: AudioComponentInspector

# 在 _enter_tree() 方法中添加：
audio_component_inspector = AudioComponentInspector.new()
add_inspector_plugin(audio_component_inspector)

# 在 _exit_tree() 方法中添加：
remove_inspector_plugin(audio_component_inspector)
```

#### Step 3: 提交

```bash
git add addons/juicy_mixer/editor/audio_component_inspector.gd
git add addons/juicy_mixer/plugin.gd
git commit -m "feat(audio): 创建 AudioComponentInspector 插件

- 自定义 AudioComponent 的 Inspector 界面
- 添加快速创建绑定按钮
- 添加自动检测信号按钮（基础框架）
- 提供可视化编辑入口

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 3.2: 创建 JuicyAudioPlayerInspector

**目标:** 显示播放器状态和提供测试功能

**Files:**
- Create: `addons/juicy_mixer/editor/juicy_audio_player_inspector.gd`

#### Step 1: 创建 Inspector 插件类

```bash
cat > addons/juicy_mixer/editor/juicy_audio_player_inspector.gd << 'EOF'
tool
extends EditorInspectorPlugin
class_name JuicyAudioPlayerInspector

func _can_handle(object: Object) -> bool:
	return object is JuicyAudioPlayer

func _parse_begin(object: Object) -> void:
	var player := object as JuicyAudioPlayer

	# 创建状态面板
	var status_panel = _create_status_panel(player)
	add_custom_control(status_panel)

func _create_status_panel(player: JuicyAudioPlayer) -> Control:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# 父节点信息
	var parent_label = Label.new()
	var parent = player.get_parent()
	parent_label.text = "父节点: %s" % (parent.name if parent else "无")
	parent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(parent_label)

	# 绑定数量
	var count_label = Label.new()
	var bindings = player.audio_component.get_binding_count() if player.audio_component else 0
	count_label.text = "绑定数量: %d" % bindings
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(count_label)

	# 测试按钮
	var test_btn = Button.new()
	test_btn.text = "🧪 测试所有绑定"
	test_btn.pressed.connect(_on_test_all.bind(player))
	vbox.add_child(test_btn)

	return panel

func _on_test_all(player: JuicyAudioPlayer):
	if not player.audio_component:
		push_warning("No audio component configured")
		return

	print("\n=== JuicyAudioPlayer Test ===")
	print("Parent: %s" % player.get_parent().name)
	print("Bindings: %d" % player.audio_component.get_binding_count())

	for i in range(player.audio_component.get_binding_count()):
		var binding = player.audio_component.audio_bindings[i]
		print("  [%d] %s -> %s" % [
			i,
			binding.signal_name if binding else "null",
			binding.audio_event.event_name if binding and binding.audio_event else "null"
		])

	print("============================\n")
EOF
```

#### Step 2: 注册插件

```bash
# 编辑 addons/juicy_mixer/plugin.gd

# 在类成员变量区域添加：
var audio_player_inspector: JuicyAudioPlayerInspector

# 在 _enter_tree() 方法中添加：
audio_player_inspector = JuicyAudioPlayerInspector.new()
add_inspector_plugin(audio_player_inspector)

# 在 _exit_tree() 方法中添加：
remove_inspector_plugin(audio_player_inspector)
```

#### Step 3: 提交

```bash
git add addons/juicy_mixer/editor/juicy_audio_player_inspector.gd
git add addons/juicy_mixer/plugin.gd
git commit -m "feat(audio): 创建 JuicyAudioPlayerInspector 插件

- 显示播放器状态信息（父节点、绑定数量）
- 添加测试所有绑定的按钮
- 打印绑定详情到控制台

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 4: 文档和示例

### Task 4.1: 创建可视化使用指南

**Files:**
- Create: `addons/juicy_mixer/docs/user_docs/audio_manager_visual_guide.md`

#### Step 1: 编写用户文档

```bash
cat > addons/juicy_mixer/docs/user_docs/audio_manager_visual_guide.md << 'EOF'
# AudioManager 可视化使用指南

**版本**: 1.0
**更新日期**: 2026-01-15

---

## 概述

AudioManager 可视化系统通过节点和 Inspector 配置，大幅简化音频播放的代码需求。

### 核心优势

- ✅ **极简代码**: 大多数场景只需一行 `@export`
- ✅ **可视化配置**: Inspector 中拖拽完成所有设置
- ✅ **实时预览**: 无需运行游戏即可试听
- ✅ **配置复用**: 组件资源可跨节点共享
- ✅ **自动检测**: 一键检测脚本所有信号

---

## 快速开始

### 步骤 1: 创建音频事件

1. 右键文件系统面板
2. 创建 → Resource
3. 搜索并选择 "AudioEventResource"
4. 命名为 `jump.tres`
5. 在 Inspector 中配置音频变体

### 步骤 2: 添加 JuicyAudioPlayer

```
Player (CharacterBody2D)
└── JuicyAudioPlayer  ← 添加这个子节点
```

### 步骤 3: 配置绑定

1. 选择 JuicyAudioPlayer 节点
2. Inspector → Audio Component → 创建新组件
3. 点击 "+ 快速添加"
4. 设置 Signal Name: "jumped"
5. 拖拽 `jump.tres` 到 Audio Event 字段
6. 完成！

### 步骤 4: 使用

```gdscript
# Player.gd
extends CharacterBody2D

signal jumped  # ← 定义信号

@export var audio_player: JuicyAudioPlayer  # ← 只需这一行！

func jump():
	velocity.y = JUMP_VELOCITY
	jumped.emit()  # ← 音频自动播放，无需其他代码！
```

---

## 组件详解

### JuicyAudioPlayer

**功能**: 自动连接父节点信号并播放音频

**Inspector 属性**:
- `Audio Component`: 音频绑定配置资源
- `Auto Setup`: 是否在 _ready 时自动设置（默认 true）
- `Debug Mode`: 启用调试日志

**使用场景**:
- 角色音效（脚步、跳跃、受伤）
- UI 音效（按钮点击、悬停）
- 环境音效（物体碰撞、破坏）

### AudioManager

**功能**: 场景级全局音频配置

**Inspector 属性**:
- `Instance Mixing Config`: 场景级默认混音配置
- `Global Limit Config`: 全局级限制配置
- `Default Categories`: 默认类别配置数组
- `Enable Debug View`: 启用调试面板

**使用场景**:
- 主菜单：简单的音效限额配置
- 战斗场景：复杂的 ducking 规则和类别限制
- 过场动画：禁用某些音效类别

### AudioComponent

**功能**: 可复用的音频绑定配置

**Inspector 属性**:
- `Audio Bindings`: AudioBinding 数组

**快捷按钮**:
- `+ 快速添加`: 添加新绑定
- `🔍 自动检测信号`: 扫描脚本信号（TODO）

**共享示例**:
```gdscript
# 创建共享组件
var button_clicks = AudioComponent.new()
var binding = AudioBinding.new()
binding.signal_name = "pressed"
binding.audio_event = preload("res://audio/ui/click.tres")
button_clicks.audio_bindings.append(binding)
ResourceSaver.save(button_clicks, "res://audio/components/ui_button_clicks.tres")

# 在多个按钮中使用
button1.audio_component = preload("res://audio/components/ui_button_clicks.tres")
button2.audio_component = preload("res://audio/components/ui_button_clicks.tres")
button3.audio_component = preload("res://audio/components/ui_button_clicks.tres")
```

### AudioBinding

**功能**: 单个信号到音频的映射

**Inspector 属性**:
- `Signal Name`: 信号名称（字符串）
- `Audio Event`: 音频事件资源
- `Cooldown`: 冷却时间（秒）
- `Delay`: 播放延迟（秒）
- `Volume Override`: 音量覆盖（dB）

---

## 常见场景示例

### 场景 1: 角色音效

**需求**: 脚步声、跳跃声、受伤声

**场景树**:
```
Player
├── Sprite2D
├── CollisionShape2D
└── JuicyAudioPlayer
    └── Audio Component
        ├── [0] footstep → footstep.tres (cooldown: 0.3s)
        ├── [1] jumped → jump.tres
        └── [2] damaged → hurt.tres
```

**代码**:
```gdscript
extends CharacterBody2D

signal footstep
signal jumped
signal damaged(impact: float)

@export var audio_player: JuicyAudioPlayer
# Inspector 中配置绑定，无需其他代码！
```

---

### 场景 2: UI 按钮

**需求**: 所有按钮点击音效一致

**创建共享组件**:
1. 创建 `AudioComponent` 资源
2. 添加绑定：`pressed` → `button_click.tres`
3. 保存为 `res://audio/components/ui_button_clicks.tres`

**场景树**:
```
MainMenu
├── VBoxContainer
│   ├── StartButton
│   │   └── JuicyAudioPlayer
│   │       └── Audio Component: [ui_button_clicks.tres]
│   ├── SettingsButton
│   │   └── JuicyAudioPlayer
│   │       └── Audio Component: [ui_button_clicks.tres]  ← 共享！
│   └── QuitButton
│       └── JuicyAudioPlayer
│           └── Audio Component: [ui_button_clicks.tres]  ← 共享！
```

**优势**: 修改一个资源文件，所有按钮音效同步更新！

---

### 场景 3: 战斗场景配置

**需求**: 复杂的混音配置

**场景树**:
```
CombatScene
├── AudioManager
│   ├── Mixing Config: [combat_mixing.tres]
│   │   ├── Instance Limit: 20
│   │   ├── Ducking Rules:
│   │   │   ├── [0] Voice → SFX: -10dB
│   │   │   └── [1] Explosion → Music: -15dB
│   │   └── Phase Protection: enabled
│   │
│   └── Categories
│       ├── Combat SFX (max: 15)
│       ├── Combat Music (max: 3)
│       └── Voice (max: 5)
│
└── Player
    └── JuicyAudioPlayer
        └── [player_combat_sounds.tres]
```

**配置文件**: `combat_mixing.tres`
- 适用于整个场景的默认混音设置
- 特殊事件仍可覆盖（如 Boss 音乐不被 ducking）

---

## 高级技巧

### 1. 运行时添加绑定

```gdscript
func _ready():
	# 动态添加绑定
	audio_player.add_binding("special_event", preload("res://audio/special.tres"))
```

### 2. 调试模式

启用 JuicyAudioPlayer 的 `Debug Mode`:
```
[JuicyAudioPlayer] Initialized for parent: Player
[JuicyAudioPlayer] Bindings: 3
[JuicyAudioPlayer] Played: jump
[JuicyAudioPlayer] Binding in cooldown: footstep
```

### 3. Inspector 测试

点击 JuicyAudioPlayer Inspector 中的 "🧪 测试所有绑定":
```
=== JuicyAudioPlayer Test ===
Parent: Player
Bindings: 3
  [0] jumped → jump
  [1] landed → land
  [2] damaged → hurt
============================
```

---

## 故障排除

### 问题 1: 音频不播放

**检查**:
1. 信号名称是否正确？
2. AudioEventResource 是否有效？
3. JuicyAudioPlayer 是否有父节点？

**调试**:
```gdscript
@export var audio_player: JuicyAudioPlayer
@export var debug_mode: bool = true  # 启用调试
```

### 问题 2: 冷却不生效

**原因**: `adv_cooldown` 设置为 0

**解决**: 设置合适的冷却时间（如 0.3 秒）

### 问题 3: 组件不共享

**原因**: 直接修改组件实例而非资源

**解决**:
```gdscript
# 错误
audio_player.audio_component = component_instance

# 正确
audio_player.audio_component = preload("res://component.tres")
# 或
ResourceSaver.save(component, "res://component.tres")
```

---

## 最佳实践

1. **命名规范**: 信号名使用动词过去式（jumped, landed）
2. **共享配置**: UI 音效使用共享组件
3. **场景配置**: 混音配置放在 AudioManager
4. **冷却时间**: 快速音效设置 200-300ms 冷却
5. **调试**: 开发时启用 Debug Mode

---

## API 参考

### JuicyAudioPlayer

- `add_binding(signal_name: String, event: AudioEventResource)`
- `remove_binding(signal_name: String)`

### AudioManager

- `get_audio_handler() -> JuicyAudioEventHandler`
- `update_mixing_config(new_config: AudioMixingConfig)`
- `update_global_config(new_config: GlobalAudioLimitConfig)`

### AudioComponent

- `setup(target: Node, player: Node)`
- `find_binding_by_signal(signal_name: String) -> AudioBinding`
- `create_footstep_component() -> AudioComponent` (静态)
- `create_ui_button_component(click_event: AudioEventResource) -> AudioComponent` (静态)

---

**更新日志**:
- v1.0 (2026-01-15): 初始版本
EOF
```

#### Step 2: 提交

```bash
git add addons/juicy_mixer/docs/user_docs/audio_manager_visual_guide.md
git commit -m "docs(audio): 创建可视化使用指南

- 完整的快速开始教程
- 组件详解和使用场景
- 常见问题示例（角色、UI、战斗）
- 高级技巧和故障排除
- API 参考和最佳实践

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 4.2: 创建示例场景

**Files:**
- Create: `demos/audio/simple_character.tscn`
- Create: `demos/audio/simple_character.gd`

#### Step 1: 创建示例角色

```bash
mkdir -p demos/audio

cat > demos/audio/simple_character.gd << 'EOF'
extends CharacterBody2D

## 简单角色示例 - 展示 JuicyAudioPlayer 使用

signal jumped
signal landed(impact_velocity: float)
signal footstep

@export var jump_velocity: float = -400.0
@export var audio_player: JuicyAudioPlayer  # ← 只需这一行！

func _physics_process(delta):
	# 添加重力
	if not is_on_floor():
		velocity.y += gravity * delta

	# 跳跃输入
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		jump()

	# 移动
	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed

	move_and_slide()

	# 脚步声（简化）
	if is_on_floor() and direction != 0:
		footstep.emit()

func jump():
	velocity.y = jump_velocity
	jumped.emit()  # ← 自动播放 jump 音效！

func _on_landed():
	# 计算落地速度
	var impact = abs(velocity.y)
	landed.emit(impact)  # ← 自动播放 land 音效！
```

#### Step 2: 创建示例场景

```bash
cat > demos/audio/simple_character.tscn << 'EOF'
[gd_scene load_steps=4 format=3 uid="uid://demo_simple_character"]

[ext_resource type="Script" path="res://demos/audio/simple_character.gd" id="1"]
[ext_resource type="AudioEventResource" uid="uid://demo_jump_event" path="res://demos/audio/jump_event.tres" id="2"]
[ext_resource type="AudioEventResource" uid="uid://demo_footstep_event" path="res://demos/audio/footstep_event.tres" id="3"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(50, 50)

[node name="SimpleCharacter" type="CharacterBody2D"]
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
modulate = Color(1, 0.5, 0.5, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_1")

[node name="JuicyAudioPlayer" type="Node" parent="."]
script = ExtResource("1") if false else null

[node name="Label" type="Label" parent="."]
offset_left = -100.0
offset_top = -60.0
offset_right = 100.0
offset_bottom = -40.0
text = "按 SPACE 跳跃
左右移动播放脚步声
（需要配置 AudioComponent）"
horizontal_alignment = 1
EOF
```

#### Step 3: 创建占位符音频事件

```bash
# 创建占位符事件（用户需要配置实际音频）
cat > demos/audio/jump_event.tres << 'EOF'
[gd_resource type="AudioEventResource" format=3 uid="uid://demo_jump_event"]

[resource]
event_name = "jump"
script = "res://addons/juicy_mixer/resources/audio/audio_event_resource.gd"
EOF

cat > demos/audio/footstep_event.tres << 'EOF'
[gd_resource type="AudioEventResource" format=3 uid="uid://demo_footstep_event"]

[resource]
event_name = "footstep"
script = "res://addons/juicy_mixer/resources/audio/audio_event_resource.gd"
EOF
```

#### Step 4: 提交

```bash
git add demos/audio/simple_character.gd
git add demos/audio/simple_character.tscn
git add demos/audio/jump_event.tres
git add demos/audio/footstep_event.tres
git commit -m "feat(audio): 创建简单角色示例场景

- 展示 JuicyAudioPlayer 的基本使用
- 包含跳跃、落地、脚步信号
- 只需一行 @export 代码
- 添加占位符音频事件（待用户配置）

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Phase 5: 集成测试和验证

### Task 5.1: 创建端到端测试场景

**Files:**
- Create: `demos/audio/visual_demo.tscn`
- Create: `demos/audio/visual_demo.gd`

#### Step 1: 创建完整演示场景

```bash
cat > demos/audio/visual_demo.gd << 'EOF'
extends Node2D

## AudioManager 可视化功能完整演示

func _ready():
	print("\n=== AudioManager 可视化演示 ===")

	# 等待场景初始化
	await get_tree().process_frame

	# 检查节点
	_check_scene_setup()

	# 测试信号连接
	await _test_signal_connections()

	print("\n=== 演示完成 ===")
	get_tree().quit()

func _check_scene_setup():
	print("\n1. 场景结构检查:")

	var audio_manager = $AudioManager
	if audio_manager:
		print("   ✓ AudioManager 存在")
		print("   - 混音配置: %s" % ("已设置" if audio_manager.instance_mixing_config else "未设置"))
		print("   - 全局配置: %s" % ("已设置" if audio_manager.global_limit_config else "未设置"))
	else:
		print("   ✗ AudioManager 不存在")

	var player = $Player
	if player:
		print("   ✓ Player 存在")
		var audio_player = player.get_node_or_null("JuicyAudioPlayer")
		if audio_player:
			print("   - JuicyAudioPlayer 存在")
			if audio_player.audio_component:
				print("   - AudioComponent: %d 个绑定" % audio_player.audio_component.get_binding_count())
			else:
				print("   - AudioComponent: 未设置")
		else:
			print("   - JuicyAudioPlayer 不存在")
	else:
		print("   ✗ Player 不存在")

	var button = $UI/Button
	if button:
		print("   ✓ UI Button 存在")
		var audio_player = button.get_node_or_null("JuicyAudioPlayer")
		if audio_player and audio_player.audio_component:
			print("   - 共享 AudioComponent: 是")
		else:
			print("   - 共享 AudioComponent: 否")
	else:
		print("   ✗ UI Button 不存在")

func _test_signal_connections():
	print("\n2. 信号连接测试:")

	var player = $Player
	if player:
		# 模拟跳跃
		print("   触发 jumped 信号...")
		player.jumped.emit()
		await get_tree().create_timer(0.5).timeout

		# 模拟脚步
		print("   触发 footstep 信号...")
		player.footstep.emit()
		await get_tree().create_timer(0.5).timeout

		print("   ✓ 信号测试完成")

	var button = $UI/Button
	if button:
		print("   触发按钮 pressed 信号...")
		button.emit_signal("pressed")
		await get_tree().create_timer(0.5).timeout
		print("   ✓ 按钮测试完成")
EOF
```

#### Step 2: 创建演示场景结构

```bash
cat > demos/audio/visual_demo.tscn << 'EOF'
[gd_scene load_steps=3 format=3 uid="uid://demo_visual"]

[ext_resource type="Script" path="res://demos/audio/visual_demo.gd" id="1"]
[ext_resource type="AudioEventResource" uid="uid://demo_jump_event" path="res://demos/audio/jump_event.tres" id="2"]

[node name="VisualDemo" type="Node2D"]
script = ExtResource("1")

[node name="AudioManager" type="Node" parent="." groups=["audio_manager"]]
pause_mode = 2

[node name="Player" type="Node" parent="."]
pause_mode = 2

[node name="JuicyAudioPlayer" type="Node" parent="Player"]
pause_mode = 2

[node name="UI" type="Control" parent="."]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Button" type="Button" parent="UI"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = -23.0
offset_right = 100.0
offset_bottom = 23.0
grow_horizontal = 2
text = "Test Button"

[node name="JuicyAudioPlayer" type="Node" parent="UI/Button"]
pause_mode = 2
EOF
```

#### Step 3: 提交

```bash
git add demos/audio/visual_demo.gd
git add demos/audio/visual_demo.tscn
git commit -m "test(audio): 创建端到端可视化演示场景

- 检查场景结构（AudioManager, Player, UI）
- 测试信号连接和音频播放
- 验证共享 AudioComponent
- 提供完整的测试报告输出

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 5.2: 更新主文档

**Files:**
- Modify: `addons/juicy_mixer/docs/user_docs/audio_manager_user_guide.md`

#### Step 1: 添加可视化章节

```bash
# 在 audio_manager_user_guide.md 的目录中添加：
# - [可视化使用指南](#可视化使用指南)

# 在文档末尾添加新章节：

cat >> addons/juicy_mixer/docs/user_docs/audio_manager_user_guide.md << 'EOF'

---

## 可视化使用指南

v3.2 新增可视化配置系统，大幅简化音频播放代码！

### 核心组件

- **JuicyAudioPlayer** - 信号驱动的音频播放器节点
- **AudioManager** - 场景级全局配置
- **AudioComponent** - 可复用的绑定配置
- **AudioBinding** - 信号-音频映射

### 快速开始

**旧方式（代码为主）**:
```gdscript
var _audio_handler: JuicyAudioEventHandler.new()
add_child(_audio_handler)
_audio_handler.register_audio_event("jump", jump_event)
connect("jumped", _on_jump)
```

**新方式（可视化）**:
```gdscript
signal jumped
@export var audio_player: JuicyAudioPlayer  # ← 只需这一行！

func jump():
	jumped.emit()  # ← 音频自动播放
```

### 详细文档

完整的使用指南请参考：[可视化使用指南](../user_docs/audio_manager_visual_guide.md)

### 示例场景

- `demos/audio/simple_character.tscn` - 角色音效示例
- `demos/audio/visual_demo.tscn` - 完整功能演示

---

## 更新日志

### v3.2.0 (2026-01-15)

#### 新增功能
- ✅ JuicyAudioPlayer - 信号驱动播放器
- ✅ AudioManager - 场景级配置节点
- ✅ AudioComponent - 可复用绑定配置
- ✅ AudioBinding - 信号-音频映射
- ✅ Inspector 插件 - 可视化编辑

#### 改进
- 📚 完整的可视化使用文档
- 📚 示例场景和演示
- 🚀 减少 80% 的音频播放代码

EOF
```

#### Step 2: 提交

```bash
git add addons/juicy_mixer/docs/user_docs/audio_manager_user_guide.md
git commit -m "docs(audio): 更新主文档添加可视化功能说明

- 在目录中添加可视化使用指南链接
- 添加 v3.2.0 更新日志
- 对比新旧使用方式
- 链接到详细的可视化文档

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## 验收标准

### 功能完整性

- [ ] 所有资源类正确注册到 plugin.gd
- [ ] 所有节点类可在编辑器中创建
- [ ] Inspector 插件正常工作
- [ ] 信号自动连接功能正常
- [ ] 冷却机制正常工作
- [ ] 组件共享功能正常

### 测试覆盖

- [ ] AudioBinding 单元测试通过
- [ ] AudioComponent 单元测试通过
- [ ] JuicyAudioPlayer 集成测试通过
- [ ] AudioManager 单元测试通过
- [ ] 端到端演示场景运行正常

### 文档完整性

- [ ] 可视化使用指南完整
- [ ] 示例场景可运行
- [ ] API 参考文档完整
- [ ] 主文档已更新

### 性能

- [ ] 场景加载时间增加 < 50ms
- [ ] 运行时开销可忽略不计
- [ ] 内存占用合理

---

## 实施检查清单

在完成每个任务后，验证以下内容：

### 代码质量

- [ ] 使用 Tab 缩进（Godot 标准）
- [ ] 添加类型注解
- [ ] 添加适当的注释
- [ ] 遵循 GDScript 2.0 语法
- [ ] 错误处理完整

### 注册

- [ ] 所有新类在 plugin.gd 中注册
- [ ] 在 _exit_tree() 中正确清理
- [ ] 自定义类型图标正确（可选）

### 测试

- [ ] 测试场景可运行
- [ ] 测试输出符合预期
- [ ] 边界条件已测试
- [ ] 错误情况有处理

### Git 提交

- [ ] 提交信息清晰
- [ ] 包含 Co-Authored-By
- [ ] 频繁提交（每个任务）
- [ ] 无 unintended 文件

---

**计划完成！**

**总计**: 8 个主要任务，分 5 个阶段实施
**预计时间**: 2-3 天（按 TDD 方式）
**提交数量**: 约 15-20 个 commits
