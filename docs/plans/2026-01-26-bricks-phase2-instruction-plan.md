# Bricks Phase 2 指令开发计划

**创建日期:** 2026-01-26
**计划版本:** 1.0
**基于评估报告:** [2026-01-25-instruction-evaluation-report-v2.md](../addons/bricks/docs/roadmap/2026-01-25-instruction-evaluation-report-v2.md)
**前置阶段:** Phase 0A, 0B, 1A, 1B, 1C, 1D ✅ 已完成

---

## ✅ 已完成阶段总结

### Phase 0A: 核心基础（4 个指令）✅

| 指令 | 总分 | 优先级 | 文件名 | 状态 |
|------|------|--------|--------|------|
| **Set Position** | 69.0 | P0 | set_position.gd | ✅ 已完成 |
| **For Loop** | 59.5 | P0 | for_loop.gd | ✅ 已完成 |
| **If/Else** | 59.0 | P0 | if_else.gd | ✅ 已完成 |
| **Find Node** | 59.0 | P0 | find_node.gd | ✅ 已完成 |

**预期成果：** ✅ 已实现
- ✅ 基础流程控制能力（循环、条件）
- ✅ 基础变换操作能力
- ✅ 节点查找和管理能力

---

### Phase 0B: 节点管理（4 个指令）✅

| 指令 | 总分 | 优先级 | 文件名 | 状态 |
|------|------|--------|--------|------|
| **Enable/Disable Node** | 64.0 | P1 | enable_disable_node.gd | ✅ 已完成 |
| **Queue Free Node** | 63.5 | P1 | queue_free_node.gd | ✅ 已完成 |
| **Instantiate Scene** | 61.5 | P1 | instantiate_scene.gd | ✅ 已完成 |
| **Find Node** | 59.0 | P0 | find_node.gd | ✅ 已完成（Phase 0A） |

**预期成果：** ✅ 已实现
- ✅ 完整的对象生命周期管理
- ✅ 动态对象生成和释放能力

---

### Phase 1A: 场景和变换（4 个指令）✅

| 指令 | 总分 | 优先级 | 文件名 | 状态 |
|------|------|--------|--------|------|
| **Change Scene** | 62.0 | P1 | change_scene.gd | ✅ 已完成 |
| **Set Rotation** | 60.0 | P1 | set_rotation.gd | ✅ 已完成 |
| **Set Scale** | 60.0 | P1 | set_scale.gd | ✅ 已完成 |
| **Look At** | 56.5 | P2 | look_at.gd | ✅ 已完成 |

**预期成果：** ✅ 已实现
- ✅ 场景切换能力
- ✅ 完整的变换操作（位置、旋转、缩放）

---

### Phase 1B: 音频系统（5 个指令）✅

| 指令 | 总分 | 优先级 | 文件名 | 状态 |
|------|------|--------|--------|------|
| **Play Sound** | 60.5 | P1 | play_sound.gd | ✅ 已完成 |
| **Stop Audio** | 60.0 | P1 | stop_audio.gd | ✅ 已完成 |
| **Set Audio Volume** | 60.0 | P1 | set_audio_volume.gd | ✅ 已完成 |
| **Play Music** | 57.0 | P2 | play_music.gd | ✅ 已完成 |
| **Pause/Resume Audio** | 56.0 | P2 | pause_resume_audio.gd | ✅ 已完成 |

**预期成果：** ✅ 已实现
- ✅ 完整的音效系统
- ✅ 音频管理能力

**代码质量：** ✅ 已完成审查和修复
- ✅ 所有硬编码错误消息已本地化
- ✅ 所有 AudioServer API 错误已修复（Godot 4.x 兼容）
- ✅ 所有 GDScript 2.0 语法错误已修复

---

### Phase 1C: 流程控制完善（3 个指令）✅

| 指令 | 总分 | 优先级 | 文件名 | 状态 |
|------|------|--------|--------|------|
| **Break Loop** | 56.0 | P2 | break_loop.gd | ✅ 已完成 |
| **Continue Loop** | 56.0 | P2 | continue_loop.gd | ✅ 已完成 |
| **Wait Until** | 57.0 | P2 | wait_until.gd | ✅ 已完成 |

**预期成果：** ✅ 已实现
- ✅ 完整的循环控制能力

**依赖验证：** ✅ For Loop（Phase 0A）已完成

---

### Phase 1D: 变换增强（2 个指令）✅

| 指令 | 总分 | 优先级 | 文件名 | 状态 |
|------|------|--------|--------|------|
| **Move By** | 52.0 | P2 | move_by.gd | ✅ 已完成 |
| **Rotate By** | 50.5 | P2 | rotate_by.gd | ✅ 已完成 |

**预期成果：** ✅ 已实现
- ✅ 相对变换能力

**依赖验证：** ✅ Set Position 和 Set Rotation（Phase 1A）已完成

**代码质量：** ✅ 已完成边界测试
- ✅ 添加 6 个新测试用例（NaN、Infinity、大数值）
- ✅ 测试文件：test_move_by.gd, test_rotate_by.gd

---

## 📊 完成统计

| 阶段 | 指令数 | 完成度 | 状态 |
|------|--------|--------|------|
| Phase 0A | 4 | 100% | ✅ 已完成 |
| Phase 0B | 4 | 100% | ✅ 已完成 |
| Phase 1A | 4 | 100% | ✅ 已完成 |
| Phase 1B | 5 | 100% | ✅ 已完成 |
| Phase 1C | 3 | 100% | ✅ 已完成 |
| Phase 1D | 2 | 100% | ✅ 已完成 |
| Phase 2A | 4 | 100% | ✅ 已完成 |
| Phase 2B | 2 | 100% | ✅ 已完成 |
| Phase 2C | 2 | 100% | ✅ 已完成 |
| **Phase 0-2 总计** | **30** | **100%** | **✅ 已完成** |

**代码质量总结：**
- ✅ Phase 1A-1D 代码审查完成（22 个指令）
- ✅ 22 项代码质量改进（本地化、测试、语法修复）
- ✅ 创建指令开发指南

**已实现的核心能力：**
- ✅ 完整的对象管理能力（生成、释放、启用、禁用、查找）
- ✅ 完整的变换操作（位置、旋转、缩放、相对变换）
- ✅ 核心流程控制（循环、条件、等待）
- ✅ 完整的音频控制系统（播放、停止、音量、暂停）
- ✅ 场景切换能力

---

## ✅ Phase 2 已完成总结

### Phase 2A: 场景管理增强（4 个指令）✅

| 指令 | 总分 | 优先级 | 文件名 | 状态 |
|------|------|--------|--------|------|
| **Get Scene Path** | 57.0 | P2 | get_scene_path.gd | ✅ 已完成 |
| **Reload Scene** | 56.0 | P2 | reload_scene.gd | ✅ 已完成 |
| **Add Scene as Child** | 56.0 | P2 | add_scene_as_child.gd | ✅ 已完成 |
| **Load Scene Background** | 48.5 | P2 | load_scene_background.gd | ✅ 已完成 |

**预期成果：** ✅ 已实现
- ✅ 完整的场景路径获取能力
- ✅ 场景重载能力
- ✅ 动态场景实例化能力
- ✅ 异步场景加载能力

---

### Phase 2B: 时间控制系统（2 个指令）✅

| 指令 | 总分 | 优先级 | 文件名 | 状态 |
|------|------|--------|--------|------|
| **Get Delta Time** | 57.0 | P2 | get_delta_time.gd | ✅ 已完成 |
| **Set Time Scale** | 57.0 | P2 | set_time_scale.gd | ✅ 已完成 |

**预期成果：** ✅ 已实现
- ✅ Delta 时间获取能力
- ✅ 游戏时间控制能力（慢动作/快进）

---

### Phase 2C: 动画和节点操作（2 个指令）✅

| 指令 | 总分 | 优先级 | 文件名 | 状态 |
|------|------|--------|--------|------|
| **Play Animation** | 58.5 | P2 | play_animation.gd | ✅ 已完成 |
| **Reparent Node** | 53.5 | P2 | reparent_node.gd | ✅ 已完成 |

**预期成果：** ✅ 已实现
- ✅ 动画播放能力
- ✅ 节点重父化能力

---

## 📋 执行摘要

### Phase 2 目标 ✅ 已完成
实现 8 个 P2（中优先级）指令，涵盖场景管理、时间控制、动画控制和节点操作。

### 关键指标
- **指令总数:** 8 个
- **预计时间:** 1-1.5 周
- **优先级:** 全部 P2（中优先级，50-59 分）
- **复杂度:** 低到中等（复杂度评分 2-4）
- **特点:** 高即用性（3-4 分），实现相对简单

### 分类分布
| 类别 | 数量 | 占比 |
|------|------|------|
| 场景管理 | 4 | 50% |
| 时间控制 | 2 | 25% |
| 动画控制 | 1 | 13% |
| 节点操作 | 1 | 12% |
| **总计** | **8** | **100%** |

---

## 🎯 Phase 2 指令清单

### 按总分排序

| 排名 | 指令 | 总分 | 需求 | 即用 | 复杂度 | 学习 | 性能 | 依赖 | 类别 |
|------|------|------|------|------|--------|------|------|------|------|
| 1 | **Play Animation** | **58.5** | 4 | 3 | 3 | 3 | 3 | 3 | 动画控制 |
| 2 | **Get Scene Path** | **57.0** | 2 | 4 | 4 | 4 | 5 | 1 | 场景管理 |
| 3 | **Get Delta Time** | **57.0** | 3 | 4 | 4 | 4 | 4 | 1 | 时间控制 |
| 4 | **Set Time Scale** | **57.0** | 3 | 4 | 4 | 4 | 4 | 1 | 时间控制 |
| 5 | **Reload Scene** | **56.0** | 4 | 4 | 3 | 3 | 3 | 1 | 场景管理 |
| 6 | **Add Scene as Child** | **56.0** | 4 | 4 | 3 | 3 | 3 | 1 | 场景管理 |
| 7 | **Reparent Node** | **53.5** | 3 | 4 | 3 | 3 | 3 | 1 | 节点操作 |
| 8 | **Load Scene Background** | **48.5** | 3 | 3 | 2 | 2 | 2 | 1 | 场景管理 |

**平均分:** 55.4 分
**平均复杂度:** 3.4/5（低到中等）

**已移除：** Wait (57.0分, 时间控制) - 已在之前阶段完成

---

## 📅 开发阶段划分

### Phase 2A: 场景管理增强（1 周）

**目标：** 完善场景管理系统

**指令列表：**

1. **Get Scene Path** (57.0分, P2)
   - 文件名: `get_scene_path.gd`
   - 功能：获取当前场景的路径或根节点路径
   - 复杂度：中等（4/5）
   - 即用性：高（4/5）

2. **Reload Scene** (56.0分, P2)
   - 文件名: `reload_scene.gd`
   - 功能：重新加载当前场景
   - 复杂度：低（3/5）
   - 即用性：高（4/5）

3. **Add Scene as Child** (56.0分, P2)
   - 文件名: `add_scene_as_child.gd`
   - 功能：将场景实例化为子节点
   - 复杂度：低（3/5）
   - 即用性：高（4/5）
   - 依赖：Phase 0B 的 Instantiate Scene

4. **Load Scene Background** (48.5分, P2)
   - 文件名: `load_scene_background.gd`
   - 功能：后台加载场景（异步）
   - 复杂度：低（2/5）
   - 即用性：中等（3/5）
   - **注意：** 需要处理 ResourceLoader.load_interactive()

**预期成果：**
- ✅ 完整的场景路径获取能力
- ✅ 场景重载能力
- ✅ 动态场景实例化能力
- ✅ 异步场景加载能力

---

### Phase 2B: 时间控制系统（0.5 周）

**目标：** 实现游戏时间控制

**指令列表：**

5. **Get Delta Time** (57.0分, P2)
   - 文件名: `get_delta_time.gd`
   - 功能：获取上一帧的 delta 时间
   - 复杂度：中等（4/5）
   - 即用性：高（4/5）
   - **注意：** 需要保存 delta 时间到变量

6. **Set Time Scale** (57.0分, P2)
   - 文件名: `set_time_scale.gd`
   - 功能：设置游戏时间缩放（慢动作/快进）
   - 复杂度：中等（4/5）
   - 即用性：高（4/5）
   - **注意：** 使用 Engine.time_scale

**预期成果：**
- ✅ Delta 时间获取能力
- ✅ 游戏时间控制能力（慢动作/快进）

**注意：** Wait 指令已在之前阶段完成，不包含在此阶段中。

---

### Phase 2C: 动画和节点操作（0.5 周）

**目标：** 实现动画播放和节点重父化

**指令列表：**

7. **Play Animation** (58.5分, P2)
   - 文件名: `play_animation.gd`
   - 功能：播放 AnimationPlayer 动画
   - 复杂度：低（3/5）
   - 即用性：中等（3/5）
   - **注意：** 需要支持 AnimationPlayer 节点查找

8. **Reparent Node** (53.5分, P2)
   - 文件名: `reparent_node.gd`
   - 功能：将节点从一个父节点移动到另一个父节点
   - 复杂度：低（3/5）
   - 即用性：高（4/5）
   - **注意：** 使用 Node.reparent()

**预期成果：**
- ✅ 动画播放能力
- ✅ 节点重父化能力

---

## 🔧 技术实现要点

### 参考 Phase 0B 经验

基于 [Phase 0B 经验总结](../addons/bricks/docs/development/instruction_creation_guide.md)，需要注意：

#### 必须实现的方法

1. **基础元数据方法**
```gdscript
static func _get_instruction_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "BRICKS_INSTRUCTION_XXX_NAME"
    metadata.category_key = "BRICKS_CATEGORY_XXX"
    metadata.description_key = "BRICKS_INSTRUCTION_XXX_DESC"
    metadata.keywords = ["keyword1", "keyword2"]
    metadata.builtin_icon = "IconName"
    return metadata

func _setup_metadata():
    pass  # 设置额外的元数据
```

2. **属性列表**
```gdscript
func _get_property_list() -> Array[Dictionary]:
    var properties := []
    # 动态生成属性列表
    return properties
```

3. **资源名称更新**
```gdscript
func _update_resource_name():
    resource_name = "描述性名称"
```

4. **执行方法**
```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)
    # 执行逻辑
    _on_execution_completed()
```

5. **验证方法**
```gdscript
func validate() -> Array[String]:
    var errors = super.validate()
    # 添加验证逻辑
    return errors
```

6. **描述方法**
```gdscript
func get_description() -> String:
    return "指令描述"
```

#### 关键技术点

1. **节点检索**
```gdscript
var node = context.get_node(target_node_path)
if not node:
    _log_error_localized("BRICKS_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node_path)})
    return
```

2. **场景树访问**
```gdscript
var scene_tree = Engine.get_main_loop()
if not scene_tree or not scene_tree.current_scene:
    _log_error_localized("BRICKS_ERROR_CANNOT_GET_CURRENT_SCENE", {})
    return
```

3. **AudioServer API（Godot 4.x）**
```gdscript
# ❌ 错误
var bus_names = AudioServer.get_bus_names()

# ✅ 正确
var bus_names = []
for i in range(AudioServer.get_bus_count()):
    bus_names.append(AudioServer.get_bus_name(i))
```

4. **GDScript 2.0 三元运算符**
```gdscript
# ❌ 错误（C 风格）
var result = condition ? true_value : false_value

# ✅ 正确（Python 风格）
var result = true_value if condition else false_value
```

5. **本地化错误消息**
```gdscript
# ❌ 错误（硬编码）
_log_error("无法获取当前场景")

# ✅ 正确（本地化）
_log_error_localized("BRICKS_ERROR_CANNOT_GET_CURRENT_SCENE", {})
```

### Phase 2 特定注意事项

#### 场景管理指令

1. **Get Scene Path**
   - 使用 `scene_tree.current_scene.scene_file_path`
   - 返回类型：String
   - 需要支持保存到变量

2. **Reload Scene**
   - 复用 `change_scene.gd` 的逻辑
   - 使用 `get_tree().reload_current_scene()`
   - 注意：这会重新加载整个场景

3. **Add Scene as Child**
   - 使用 `PackedScene.instantiate()`
   - 使用 `node.add_child()`
   - 需要支持场景路径和目标父节点

4. **Load Scene Background**
   - 使用 `ResourceLoader.load_interactive()`
   - 需要轮询加载进度
   - **可选：** 在 Phase 2 可以先实现简单版本，完整的后台加载可以延后

#### 时间控制指令

1. **Get Delta Time**
   - 使用 `_process(delta)` 的 delta 参数
   - **问题：** 指令是 Resource，无法直接访问 delta
   - **解决方案：** 从 `Engine.get_process_frames()` 或自定义时间管理器获取

2. **Set Time Scale**
   - 使用 `Engine.time_scale`
   - 范围：0.0 - 10.0（或更高）
   - 默认值：1.0

3. **Wait**
   - 与 `wait_until.gd` 类似，但更简单
   - 创建 Tween 或 Timer
   - 使用 `await` 等待完成

#### 动画和节点指令

1. **Play Animation**
   - 查找 AnimationPlayer 节点
   - 使用 `animation_player.play()`
   - 支持动画名称、速度、是否混合

2. **Reparent Node**
   - 使用 `node.reparent(new_parent)`
   - Godot 4.x 内置方法
   - 支持保持全局变换

---

## 📝 本地化字符串

### 需要添加的翻译 key

```csv
# Phase 2A: 场景管理增强
BRICKS_INSTRUCTION_GET_SCENE_PATH_NAME,获取场景路径,Get Scene Path
BRICKS_INSTRUCTION_GET_SCENE_PATH_DESC,获取当前场景的路径或根节点路径，可保存到变量,Gets the path of the current scene or root node, can save to variable
BRICKS_INSTRUCTION_RELOAD_SCENE_NAME,重载场景,Reload Scene
BRICKS_INSTRUCTION_RELOAD_SCENE_DESC,重新加载当前场景,Reloads the current scene
BRICKS_INSTRUCTION_ADD_SCENE_AS_CHILD_NAME,添加场景为子节点,Add Scene as Child
BRICKS_INSTRUCTION_ADD_SCENE_AS_CHILD_DESC,将场景实例化并添加为指定节点的子节点,Instantiates a scene and adds it as a child of the specified node
BRICKS_INSTRUCTION_LOAD_SCENE_BACKGROUND_NAME,后台加载场景,Load Scene Background
BRICKS_INSTRUCTION_LOAD_SCENE_BACKGROUND_DESC,在后台异步加载场景（不立即切换）,Loads a scene in the background asynchronously (without immediately switching)

# Phase 2B: 时间控制系统
BRICKS_INSTRUCTION_GET_DELTA_TIME_NAME,获取 Delta 时间,Get Delta Time
BRICKS_INSTRUCTION_GET_DELTA_TIME_DESC,获取上一帧的 delta 时间并保存到变量,Gets the delta time from the previous frame and saves it to a variable
BRICKS_INSTRUCTION_SET_TIME_SCALE_NAME,设置时间缩放,Set Time Scale
BRICKS_INSTRUCTION_SET_TIME_SCALE_DESC,设置游戏时间缩放（1.0 = 正常，0.5 = 慢动作，2.0 = 快进）,Sets the game time scale (1.0 = normal, 0.5 = slow motion, 2.0 = fast forward)

# Phase 2C: 动画和节点操作
BRICKS_INSTRUCTION_PLAY_ANIMATION_NAME,播放动画,Play Animation
BRICKS_INSTRUCTION_PLAY_ANIMATION_DESC,播放 AnimationPlayer 中的指定动画，支持速度和混合设置,Plays a specified animation from an AnimationPlayer with speed and blend settings
BRICKS_INSTRUCTION_REPARENT_NODE_NAME,重父化节点,Reparent Node
BRICKS_INSTRUCTION_REPARENT_NODE_DESC,将节点从一个父节点移动到另一个父节点，保持变换,Moves a node from one parent to another while preserving transform

# 类别
BRICKS_CATEGORY_TIME,时间,Time
BRICKS_CATEGORY_ANIMATION,动画,Animation

# 错误消息（可能需要）
BRICKS_ERROR_ANIMATION_PLAYER_NOT_FOUND,未找到 AnimationPlayer 节点,AnimationPlayer node not found
BRICKS_ERROR_INVALID_TIME_SCALE,无效的时间缩放值,Invalid time scale value
BRICKS_ERROR_SCENE_PATH_EMPTY,场景路径不能为空,Scene path cannot be empty
BRICKS_ERROR_TARGET_PARENT_NOT_FOUND,未找到目标父节点,Target parent node not found
```

---

## 🧪 测试要求

### 测试文件结构

每个指令需要创建对应的测试文件：

```
addons/bricks/tests/instructions/
├── test_get_scene_path.gd
├── test_reload_scene.gd
├── test_add_scene_as_child.gd
├── test_load_scene_background.gd
├── test_get_delta_time.gd
├── test_set_time_scale.gd
├── test_play_animation.gd
└── test_reparent_node.gd
```

### 测试用例模板

```gdscript
extends Node

## 测试指令名称
## 测试场景: test_[instruction_name].tscn

func _ready():
    await test_basic_functionality()
    await test_error_handling()
    print("All tests passed!")

## 测试 1: 基础功能
func test_basic_functionality():
    print("Test 1: Basic functionality")
    # 测试实现
    pass

## 测试 2: 错误处理
func test_error_handling():
    print("Test 2: Error handling")
    # 测试实现
    pass
```

### 边界测试要求

参考 Phase 1D 的边界测试经验，每个指令应测试：

1. **输入验证**
   - 空值、null、无效路径
   - NaN、Infinity 值（如适用）

2. **边界情况**
   - 极大值、极小值
   - 零值、负值（如适用）

3. **错误处理**
   - 节点不存在
   - 场景不存在
   - 权限问题

---

## ✅ 完成标准

### 代码质量标准

1. **代码风格**
   - ✅ 遵循 GDScript 编码规范（snake_case, Tab 缩进）
   - ✅ 添加类型注解
   - ✅ 添加注释和文档字符串

2. **本地化**
   - ✅ 所有用户可见字符串使用本地化系统
   - ✅ 所有错误消息使用 `_log_error_localized()`
   - ✅ 添加中英文翻译

3. **错误处理**
   - ✅ 完善的输入验证
   - ✅ 友好的错误消息
   - ✅ 使用 `set_error_localized()` 设置错误状态

4. **测试覆盖**
   - ✅ 每个指令有对应的测试文件
   - ✅ 基础功能测试
   - ✅ 错误处理测试
   - ✅ 边界情况测试

### 功能完整性标准

1. **必须功能**
   - ✅ 基础功能正常工作
   - ✅ 支持从变量读取参数（如适用）
   - ✅ 支持保存到变量（如适用）

2. **用户体验**
   - ✅ 清晰的资源名称（`_update_resource_name()`）
   - ✅ 详细的指令描述（`get_description()`）
   - ✅ 合理的默认值

3. **文档**
   - ✅ 代码注释完整
   - ✅ 更新评估报告
   - ✅ 更新用户文档（如需要）

---

## 📊 进度跟踪

### 开发检查清单 ✅ 已完成

#### Phase 2A: 场景管理增强（4 个指令）✅

- [x] Get Scene Path
  - [x] 指令文件创建
  - [x] 本地化字符串添加
  - [x] 测试文件创建
  - [x] 功能验证

- [x] Reload Scene
  - [x] 指令文件创建
  - [x] 本地化字符串添加
  - [x] 测试文件创建
  - [x] 功能验证

- [x] Add Scene as Child
  - [x] 指令文件创建
  - [x] 本地化字符串添加
  - [x] 测试文件创建
  - [x] 功能验证

- [x] Load Scene Background
  - [x] 指令文件创建
  - [x] 本地化字符串添加
  - [x] 测试文件创建
  - [x] 功能验证

#### Phase 2B: 时间控制系统（2 个指令）✅

- [x] Get Delta Time
  - [x] 指令文件创建
  - [x] 本地化字符串添加
  - [x] 测试文件创建
  - [x] 功能验证

- [x] Set Time Scale
  - [x] 指令文件创建
  - [x] 本地化字符串添加
  - [x] 测试文件创建
  - [x] 功能验证

#### Phase 2C: 动画和节点操作（2 个指令）✅

- [x] Play Animation
  - [x] 指令文件创建
  - [x] 本地化字符串添加
  - [x] 测试文件创建
  - [x] 功能验证

- [x] Reparent Node
  - [x] 指令文件创建
  - [x] 本地化字符串添加
  - [x] 测试文件创建
  - [x] 功能验证

---

## 📚 参考文档

### 内部文档

1. **指令创建指南**
   - [Instruction Creation Guide](../addons/bricks/docs/development/instruction_creation_guide.md)
   - 完整的指令开发步骤和最佳实践

2. **评估报告**
   - [Instruction Evaluation Report v2](../addons/bricks/docs/roadmap/2026-01-25-instruction-evaluation-report-v2.md)
   - Phase 2 指令的评分和优先级

3. **Phase 0B 经验总结**
   - 包含在指令创建指南中
   - 关键技术点和常见陷阱

### Godot API 参考

1. **场景管理**
   - [SceneTree.change_scene_to_file()](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-change-scene-to-file)
   - [SceneTree.reload_current_scene()](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-reload-current-scene)
   - [ResourceLoader.load_interactive()](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html#class-resourceloader-method-load-interactive)

2. **时间控制**
   - [Engine.time_scale](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-time-scale)
   - [SceneTree.create_timer()](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-create-timer)

3. **动画和节点**
   - [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html)
   - [Node.reparent()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-reparent)

---

## 🎯 预期成果

### Phase 2 完成后（1-1.5 周）

**新增能力：**
- ✅ 完整的场景管理系统（获取路径、重载、实例化、后台加载）
- ✅ 游戏时间控制（Delta 时间、时间缩放）
- ✅ 动画播放能力
- ✅ 节点重父化能力

**累计完成（Phase 0 + Phase 1 + Phase 2）：**
- ✅ **30 个指令**（Phase 0: 4 + Phase 1: 18 + Phase 2: 8）
- ✅ 覆盖 7 大类别（流程控制、节点操作、变换操作、场景管理、音频控制、时间控制、动画控制）

**支持的游戏类型：**
- 完整的 2D/3D 游戏场景管理
- 游戏时间控制（慢动作、快进）
- 基础动画播放
- 动态对象生成和管理

---

## 🚀 下一步

完成 Phase 2 后，可以考虑：

### Phase 3: 高级功能
- 物理碰撞指令（Apply Impulse, Set Velocity, Set Collision Layer）
- UI 控制指令（Show/Hide UI, Set UI Text, Set UI Texture, Set UI Progress）
- 数学运算指令（Clamp Value, Lerp, Random Range, Round, Abs）

### Phase 4: 数据管理
- Save/Load 系统（Load Game, Check Save Exists, Delete Save, Set Scene to Save）

---

**文档维护:** Bricks 开发团队
**最后更新:** 2026-01-27
**状态:** ✅ Phase 2 已完成
