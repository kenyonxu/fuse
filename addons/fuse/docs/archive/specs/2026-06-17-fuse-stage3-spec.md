# Fuse Stage 3: P1 组件批量填充 — 规格文档

**版本:** 1.0

> **📋 完成状态（2026-06-18）** — 23 个 P1 组件全部完成。指令 154(Stage 1+11+Stage 3+14)，事件 70(+4)，条件 49(+5)。
**日期:** 2026-06-17
**基线:** Stage 1-2 完成(143 组件), 架构整改全链闭环, 本地化 TranslationDomain, 预设系统可用
**目标:** 利用 Stage 1 打磨的组件开发流程,批量产出 23 个 P1 组件,反哺预设系统素材

> **For agentic workers:** 步骤使用复选框(`- [ ]`)语法跟踪。

---

## 1. 组件总览

| # | 组件名 | 类型 | 分类目录 | 基类 | 复杂度 | 工时 |
|---|--------|------|----------|------|:---:|:---:|
| 1 | **GroundSnap** | Instruction | physics/ | BaseInstruction | 低 | 0.5h |
| 2 | **CheckSlope** | Condition | physics/ | BaseCondition | 低 | 0.5h |
| 3 | **OnGroundStateChanged** | Event | physics/ | BaseEvent | 中 | 1h |
| 4 | **CheckAnimationTreeParameter** | Condition | animation/ | BaseCondition | 低 | 0.5h |
| 5 | **TweenPause** | Instruction | tween/ | BaseInstruction | 低 | 0.5h |
| 6 | **TweenResume** | Instruction | tween/ | BaseInstruction | 低 | 0.5h |
| 7 | **CameraFadeIn** | Instruction | camera/ | BaseInstruction | 低 | 0.5h |
| 8 | **CameraFadeOut** | Instruction | camera/ | BaseInstruction | 低 | 0.5h |
| 9 | **AddRemoveUIChild** | Instruction | ui/ | BaseInstruction | 低 | 0.5h |
| 10 | **OnUIMouseEntered** | Event | ui/ | BaseEvent | 低 | 0.5h |
| 11 | **OnUIMouseExited** | Event | ui/ | BaseEvent | 低 | 0.5h |
| 12 | **CheckUIVisible** | Condition | ui/ | BaseCondition | 低 | 0.5h |
| 13 | **StringFormat** | Instruction | string/ | BaseInstruction | 中 | 1h |
| 14 | **SetLight** | Instruction | rendering/ | BaseInstruction | 低 | 0.5h |
| 15 | **ControlParticles** | Instruction | rendering/ | BaseInstruction | 低 | 0.5h |
| 16 | **OnNavigationTargetReached** | Event | navigation/ | BaseEvent | 中 | 1h |
| 17 | **CheckPathAvailable** | Condition | navigation/ | BaseCondition | 低 | 0.5h |
| 18 | **CheckInputMagnitude** | Condition | input/ | BaseCondition | 低 | 0.5h |
| 19 | **OnDirectionalInputChanged** | Event | input/ | BaseEvent | 中 | 1h |
| 20 | **EmitSignal** | Instruction | node_operations/ | BaseInstruction | 低 | 0.5h |
| 21 | **GetViewportSize** | Instruction | system/ | BaseInstruction | 低 | 0.5h |
| 22 | **CloneNode** | Instruction | node_operations/ | BaseInstruction | 低 | 0.5h |
| 23 | **SwapVariables** | Instruction | variables/ | BaseInstruction | 低 | 0.5h |

> **总计:** 14 指令 + 5 条件 + 4 事件 = 23 组件,约 13.5h

---

## 2. 批量分组

按分类分 5 批,每批 4-5 个组件,同一批的基类和模式一致:

| 批次 | 组件 | 基类 |
|------|------|------|
| **A** | TweenPause, TweenResume, CameraFadeIn, CameraFadeOut | BaseInstruction |
| **B** | GroundSnap, SetLight, ControlParticles, CloneNode, EmitSignal | BaseInstruction |
| **C** | StringFormat, GetViewportSize, SwapVariables, AddRemoveUIChild | BaseInstruction |
| **D** | CheckSlope, CheckAnimationTreeParameter, CheckUIVisible, CheckPathAvailable, CheckInputMagnitude | BaseCondition |
| **E** | OnGroundStateChanged, OnUIMouseEntered, OnUIMouseExited, OnNavigationTargetReached, OnDirectionalInputChanged | BaseEvent |

---

## 3. 组件规格

### 批量 A: Tween/相机指令

#### 3.1 TweenPause / TweenResume

**文件:** `addons/fuse/instructions/tween/tween_pause.gd` / `tween_resume.gd`

**功能:** `TweenPause` 暂停目标节点的所有活跃 tween;`TweenResume` 恢复。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | 目标节点(空=当前节点) |

**核心逻辑:**
```gdscript
# TweenPause
var node = context.get_node(target_node) if not target_node.is_empty() else context.target
if node:
    var tweens = node.create_tween()  # 获取活跃的 SceneTreeTween
```

> **注意:** Godot 4.x 中 `Tween` 对象没有全局暂停 API。替代方案:通过 `Node.process_mode` 间接暂停,或使用 `Tween.set_speed_scale(0)` 来冻结动画。如果 `Tween` 引用无法获取,改为设置 `node.process_mode = PROCESS_MODE_DISABLED` 作为折中。

**图标:** `Tween`

#### 3.2 CameraFadeIn / CameraFadeOut

**文件:** `addons/fuse/instructions/camera/camera_fade_in.gd` / `camera_fade_out.gd`

**功能:** 创建全屏 ColorRect 覆盖层,渐变透明度实现淡入淡出。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `color` | Color | `Color.BLACK` | 覆盖颜色 |
| `duration` | float | `1.0` | 渐变时长(秒) |
| `easing_type` | int | `1` | 缓动类型 |

**核心逻辑:**
```gdscript
var canvas = CanvasLayer.new()
canvas.layer = 128
var rect = ColorRect.new()
rect.color = color
rect.modulate.a = 1.0 if fade_out else 0.0
# 创建 Tween 渐变 alpha
```

**新目录:** `addons/fuse/instructions/camera/`

---

### 批量 B: 物理/渲染/节点指令

#### 3.3 GroundSnap

**文件:** `addons/fuse/instructions/physics/ground_snap.gd`

**功能:** 对 CharacterBody2D/3D 执行贴地操作(调用 `move_and_slide()` 后强制 snap to floor)。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | CharacterBody2D/3D 节点 |

> **实现简化:** V1 不实现完整的 snap 物理,改为设置 `up_direction` 和调用 `is_on_floor()` 检查。实际贴地由 `move_and_slide()` 在下一帧处理。

#### 3.4 SetLight

**文件:** `addons/fuse/instructions/rendering/set_light.gd`

**功能:** 设置 Light2D/Light3D 的属性(能量/颜色/启用)。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | Light2D/Light3D 节点 |
| `energy` | float | `1.0` | 灯光能量 |
| `light_color` | Color | `Color.WHITE` | 灯光颜色 |
| `enabled` | bool | `true` | 是否启用 |

#### 3.5 ControlParticles

**文件:** `addons/fuse/instructions/rendering/control_particles.gd`

**功能:** 控制 GPUParticles2D/3D 的播放/停止/重启。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | GPUParticles2D/3D 节点 |
| `action` | enum | `RESTART` | RESTART / START / STOP |
| `one_shot` | bool | `false` | 一次性发射 |

#### 3.6 CloneNode

**文件:** `addons/fuse/instructions/node_operations/clone_node.gd`

**功能:** 运行时克隆目标节点并添加到场景。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `source_node` | NodePath | `NodePath("")` | 源节点 |
| `parent_node` | NodePath | `NodePath("")` | 父节点(空=源节点同级) |
| `save_to_variable` | String | `""` | 保存克隆节点引用到变量 |

#### 3.7 EmitSignal

**文件:** `addons/fuse/instructions/node_operations/emit_signal.gd`

**功能:** 在目标节点上发射自定义信号。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | 目标节点 |
| `signal_name` | String | `""` | 信号名 |
| `signal_args` | Array | `[]` | 信号参数 |

---

### 批量 C: 字符串/系统/UI/变量指令

#### 3.8 StringFormat

**文件:** `addons/fuse/instructions/string/string_format.gd`

**功能:** 使用变量值格式化字符串模板,结果保存到变量。RPG 对话/HUD 文本必备。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `template` | String | `""` | 模板字符串,用 `{var_name}` 占位 |
| `save_to_variable` | String | `""` | 结果保存到的变量名 |

**核心逻辑:** 解析模板中的 `{var_name}` → 从 context 查找变量值 → 替换 → 保存结果。

**新目录:** `addons/fuse/instructions/string/`

#### 3.9 GetViewportSize

**文件:** `addons/fuse/instructions/system/get_viewport_size.gd`

**功能:** 获取当前视口尺寸,保存到变量。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `save_to_variable_x` | String | `""` | 宽度保存到的变量 |
| `save_to_variable_y` | String | `""` | 高度保存到的变量 |

#### 3.10 SwapVariables

**文件:** `addons/fuse/instructions/variables/swap_variables.gd`

**功能:** 交换两个变量的值。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `variable_a` | String | `""` | 变量 A |
| `variable_b` | String | `""` | 变量 B |
| `variable_scope` | enum | `LOCAL` | 作用域 |

#### 3.11 AddRemoveUIChild

**文件:** `addons/fuse/instructions/ui/add_remove_ui_child.gd`

**功能:** 动态添加/移除 Control 子节点。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `parent_node` | NodePath | `NodePath("")` | 父 Control 节点 |
| `action` | enum | `ADD` | ADD / REMOVE |
| `child_scene` | String | `""` | 子场景路径(ADD 时使用) |
| `child_name` | String | `""` | 子节点名(REMOVE 时使用) |

---

### 批量 D: 条件(5 个)

> ⚠️ **条件组件注意:** `BaseCondition` **没有** `_log_error_localized`/`_log_debug_localized` 方法（这些是 `BaseInstruction` 的方法）。
> 条件组件应使用 `_create_fuse_error_localized(key, error_type, args)` 处理错误，
> 不需要日志输出（条件检查成功/失败由返回值体现，无需日志）。

所有条件遵循同一模板:
```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/<Icon>.png")
extends BaseCondition
class_name Check<Name>

var target_node: NodePath = NodePath(""):
    set(v): target_node = v; _update_resource_name()

static func _get_condition_metadata() -> ConditionMetadata:
    var m = ConditionMetadata.new()
    m.name_key = "FUSE_CONDITION_<NAME>_NAME"
    m.description_key = "FUSE_CONDITION_<NAME>_DESC"
    ...
    return m

func _evaluate_condition(context: ExecutionContext) -> bool:
    # 验证 → 获取数据 → 评估 → return true/false
```

#### 3.12 CheckSlope

**文件:** `addons/fuse/conditions/physics/check_slope.gd`

**功能:** 检查 CharacterBody 所在斜坡角度。

**参数:** `target_node`, `compare_type`(enum:>=/<=), `angle_degrees`(float)

#### 3.13 CheckAnimationTreeParameter

**文件:** `addons/fuse/conditions/animation/check_animation_tree_parameter.gd`

**功能:** 检查 AnimationTree 参数值。

**参数:** `target_node`, `parameter_name`, `compare_type`, `compare_value`(float), `parameter_type`(enum:FLOAT/BOOL/STRING)

#### 3.14 CheckUIVisible

**文件:** `addons/fuse/conditions/ui/check_ui_visible.gd`

**功能:** 检查 Control 节点是否可见。

**参数:** `target_node`

#### 3.15 CheckPathAvailable

**文件:** `addons/fuse/conditions/navigation/check_path_available.gd`

**功能:** 检查 NavigationAgent 是否有到目标的路径。

**参数:** `agent_node`, `target_position`(Vector2)

#### 3.16 CheckInputMagnitude

**文件:** `addons/fuse/conditions/input/check_input_magnitude.gd`

**功能:** 检查输入向量的大小(走/跑区分)。

**参数:** `input_action`(String), `compare_type`, `threshold`(float,0-1)

---

### 批量 E: 事件(4 个)

所有事件遵循同一模板:
```gdscript
@tool
@icon("res://addons/fuse/icons/builtin/<Icon>.png")
extends BaseEvent
class_name On<Event>

@export var <params>

static func _get_event_metadata() -> EventMetadata: ...

func initialize(owner_node: Node) -> void: ...
func initialize_with_runtime_instance(owner_node: Node, runtime_instance: RuntimeEventInstance) -> void: ...
func terminate(owner_node: Node) -> void: ...
```

#### 3.17 OnGroundStateChanged

**文件:** `addons/fuse/events/physics/on_ground_state_changed.gd`

**功能:** 监听 CharacterBody 的着地/离地状态变化(通过 `is_on_floor()` 轮询)。

**参数:** `target_node`, `trigger_on`(enum:LAND/LEAVE/BOTH), `check_interval`(float,默认0.1)

#### 3.18 OnUIMouseEntered

**文件:** `addons/fuse/events/ui/on_ui_mouse_entered.gd`

**功能:** 监听鼠标进入 Control 节点(连接 `mouse_entered` 信号)。

**参数:** `target_node`

#### 3.19 OnUIMouseExited

**文件:** `addons/fuse/events/ui/on_ui_mouse_exited.gd`

**功能:** 同上,`mouse_exited` 信号。

#### 3.20 OnNavigationTargetReached

**文件:** `addons/fuse/events/navigation/on_navigation_target_reached.gd`

**功能:** 监听 NavigationAgent 到达目的地(`navigation_finished` 信号)。

**参数:** `agent_node`

#### 3.21 OnDirectionalInputChanged

**文件:** `addons/fuse/events/input/on_directional_input_changed.gd`

**功能:** 监听方向输入变化(对比前后帧的 `Input.get_vector()`)。

**参数:** `input_actions`(Array[String],上下左右四个动作名), `check_interval`(float,默认0.1)

---

## 4. 新目录

| 目录 | 包含组件 |
|------|----------|
| `instructions/camera/` | `CameraFadeIn`, `CameraFadeOut` |
| `instructions/string/` | `StringFormat` |

---

## 5. 翻译条目

约 120 条新翻译键(23 组件 × 平均 5 条)。命名规范:`FUSE_{TYPE}_{NAME}_{PURPOSE}`。

> 追加到 `translations.csv` 后运行 `regenerate_translations.gd`(File > Run Script)重新生成 `.translation`。

---

## 6. 验证清单

- [ ] 所有 `.gd` 文件通过 LSP 解析
- [ ] 组件被 ComponentScanner 自动注册
- [ ] Inspector 选择器中可搜索到所有新组件
- [ ] 指令/事件/条件核心逻辑正确(编辑器内逐功能测试)
- [ ] 翻译条目完整(中英双语)
- [ ] 现有 143 组件不受影响(回归)

---


## 6.5 Scope 动态属性开发模式

涉及 variable_scope 的组件（如 `SwapVariables`）必须遵循：

1. 声明属性：`var scope_source: VariableScopeUtils.ScopeSource`, `var custom_scope_id`, `var target_node_path`
2. `_get_property_list()` 中当 `variable_scope == SCOPE` 时调用 `VariableScopeUtils.append_scope_source_properties(properties, scope_source)`
3. `_validate_property()` 中调用 `VariableScopeUtils.validate_scope_source_property(property, scope_source)`
4. `_set()` 中拦截 `scope_source`/`custom_scope_id`/`target_node_path` 变更

> 参考: `addons/fuse/instructions/variables/add_variable.gd`（已实现）

## 7. 文件清单

**新增(23 .gd + 2 新目录):**

```
addons/fuse/instructions/camera/                        (新目录)
addons/fuse/instructions/camera/camera_fade_in.gd
addons/fuse/instructions/camera/camera_fade_out.gd
addons/fuse/instructions/string/                         (新目录)
addons/fuse/instructions/string/string_format.gd
addons/fuse/instructions/physics/ground_snap.gd
addons/fuse/instructions/rendering/set_light.gd
addons/fuse/instructions/rendering/control_particles.gd
addons/fuse/instructions/node_operations/clone_node.gd
addons/fuse/instructions/node_operations/emit_signal.gd
addons/fuse/instructions/system/get_viewport_size.gd
addons/fuse/instructions/variables/swap_variables.gd
addons/fuse/instructions/ui/add_remove_ui_child.gd
addons/fuse/instructions/tween/tween_pause.gd
addons/fuse/instructions/tween/tween_resume.gd
addons/fuse/conditions/physics/check_slope.gd
addons/fuse/conditions/animation/check_animation_tree_parameter.gd
addons/fuse/conditions/ui/check_ui_visible.gd
addons/fuse/conditions/navigation/check_path_available.gd
addons/fuse/conditions/input/check_input_magnitude.gd
addons/fuse/events/physics/on_ground_state_changed.gd
addons/fuse/events/ui/on_ui_mouse_entered.gd
addons/fuse/events/ui/on_ui_mouse_exited.gd
addons/fuse/events/navigation/on_navigation_target_reached.gd
addons/fuse/events/input/on_directional_input_changed.gd
```

**修改:**

```
addons/fuse/localization/translations.csv — 追加约 120 条翻译
```

---

**文档版本:** 1.0
**最后更新:** 2026-06-17
**审核状态:** 待审核
