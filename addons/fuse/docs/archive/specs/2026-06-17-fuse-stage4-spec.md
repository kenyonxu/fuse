# Fuse Stage 4: P2 组件补全 — 规格文档

**版本:** 1.0

> **📋 完成状态（2026-06-18）** — 18 个 P2 组件全部完成。指令 164(Stage 3+10)，事件 71(+1)，条件 56(+7)。组件 54/54 规划全部完成。
**日期:** 2026-06-17
**基线:** Stage 1-3 完成(166 组件), 架构整改全链闭环, 预设系统可用
**目标:** 完成最后 17 个 P2 组件,组件总数达到 183,54/54 组件规划全部完成

> **For agentic workers:** 步骤使用复选框(`- [ ]`)语法跟踪。

---

## 1. 组件总览

| # | 组件名 | 类型 | 分类目录 | 基类 | 复杂度 | 工时 |
|---|--------|------|----------|------|:---:|:---:|
| 1 | **SetGravityDirection** | Instruction | physics/ | BaseInstruction | 低 | 0.5h |
| 2 | **SetAnimationBlendPosition** | Instruction | animation/ | BaseInstruction | 低 | 0.5h |
| 3 | **SetSpriteFrame** | Instruction | animation/ | BaseInstruction | 低 | 0.5h |
| 4 | **StringSplit** | Instruction | string/ | BaseInstruction | 低 | 0.5h |
| 5 | **StringJoin** | Instruction | string/ | BaseInstruction | 低 | 0.5h |
| 6 | **StringContains** | Condition | string/ | BaseCondition | 低 | 0.5h |
| 7 | **StringReplace** | Instruction | string/ | BaseInstruction | 低 | 0.5h |
| 8 | **StringLength** | Instruction | string/ | BaseInstruction | 低 | 0.5h |
| 9 | **CheckStringContains** | Condition | string/ | BaseCondition | 低 | 0.5h |
| 10 | **CheckStringLength** | Condition | string/ | BaseCondition | 低 | 0.5h |
| 11 | **SetZIndex** | Instruction | rendering/ | BaseInstruction | 低 | 0.5h |
| 12 | **ScreenFlash** | Instruction | rendering/ | BaseInstruction | 中 | 1h |
| 13 | **OnInputCombo** | Event | input/ | BaseEvent | 中 | 1h |
| 14 | **CheckInputDirection** | Condition | input/ | BaseCondition | 低 | 0.5h |
| 15 | **LoadResourceByPath** | Instruction | system/ | BaseInstruction | 低 | 0.5h |
| 16 | **SetGlobalPosition** | Instruction | node_operations/ | BaseInstruction | 低 | 0.5h |
| 17 | **CheckPlatform** | Condition | system/ | BaseCondition | 低 | 0.5h |
| 18 | **CheckFrameRate** | Condition | system/ | BaseCondition | 低 | 0.5h |

> **总计:** 10 指令 + 7 条件 + 1 事件 = 18 组件,约 10h

---

## 2. 批量分组

| 批次 | 组件 | 基类 |
|------|------|------|
| **A** | StringSplit, StringJoin, StringReplace, StringLength, StringContains, CheckStringContains, CheckStringLength | 指令/条件混,字符串分类集中 |
| **B** | SetGravityDirection, SetAnimationBlendPosition, SetSpriteFrame, SetZIndex, SetGlobalPosition, LoadResourceByPath | BaseInstruction |
| **C** | ScreenFlash, CheckInputDirection, CheckPlatform, CheckFrameRate | 指令/条件混 |
| **D** | OnInputCombo | BaseEvent(单独,复杂度最高) |

---

## 3. 组件规格


> ⚠️ **条件组件注意:** `BaseCondition` **没有** `_log_error_localized`/`_log_debug_localized` 方法。
> 条件组件应使用 `_create_fuse_error_localized(key, error_type, args)` 处理错误。
### 批量 A: 字符串全家桶(7 个)

**已有目录:** `addons/fuse/instructions/string/`(Stage 3 创建)

#### 3.1 StringSplit

**文件:** `addons/fuse/instructions/string/string_split.gd`

**功能:** 按分隔符分割字符串,结果保存为 Array 变量。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `source_variable` | String | `""` | 源字符串变量名 |
| `delimiter` | String | `","` | 分隔符 |
| `save_to_variable` | String | `""` | 保存 Array 到变量 |

**核心逻辑:**
```gdscript
var source: String = VariableOperations.get_variable(context, source_variable, LOCAL, "")
var parts = source.split(delimiter)
VariableOperations.set_variable(context, save_to_variable, LOCAL, parts)
```

#### 3.2 StringJoin

**文件:** `addons/fuse/instructions/string/string_join.gd`

**功能:** 用连接符合并 Array 为字符串,结果保存为变量。

**参数:** `source_variable`(Array), `connector`(String,默认`","`), `save_to_variable`

**核心逻辑:**
```gdscript
var arr: Array = VariableOperations.get_variable(context, source_variable, LOCAL, [])
var result = connector.join(arr)
```

#### 3.3 StringReplace

**文件:** `addons/fuse/instructions/string/string_replace.gd`

**功能:** 在字符串中查找替换子串,结果保存回变量。

**参数:** `variable_name`, `search`(String), `replace`(String)

#### 3.4 StringLength

**文件:** `addons/fuse/instructions/string/string_length.gd`

**功能:** 获取字符串长度,保存到变量。

**参数:** `source_variable`, `save_to_variable`

#### 3.5 StringContains(条件)

**文件:** `addons/fuse/conditions/string/check_string_contains.gd`

**功能:** 检查字符串是否包含子串。

**参数:** `source_variable`, `search`(String), `case_sensitive`(bool,默认true)

**新目录:** `addons/fuse/conditions/string/`

#### 3.6 CheckStringLength(条件)

**文件:** `addons/fuse/conditions/string/check_string_length.gd`

**功能:** 检查字符串长度。

**参数:** `source_variable`, `compare_type`(enum), `threshold`(int)

---

### 批量 B: 快速指令(6 个)

#### 3.7 SetGravityDirection

**文件:** `addons/fuse/instructions/physics/set_gravity_direction.gd`

**功能:** 设置 CharacterBody2D/3D 的 `up_direction`(改变重力方向)。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | CharacterBody 节点 |
| `use_2d` | bool | `true` | 2D 或 3D |
| `direction_x` | float | `0.0` | X 分量 |
| `direction_y` | float | `-1.0` | Y 分量 |
| `direction_z` | float | `0.0` | Z 分量(3D) |

> 复盘检查:与 SetGravityScale(Stage 1)互补,SetGravityScale 改变量,SetGravityDirection 改方向。

#### 3.8 SetAnimationBlendPosition

**文件:** `addons/fuse/instructions/animation/set_animation_blend_position.gd`

**功能:** 设置 AnimationTree 的 BlendSpace2D/1D 位置。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | AnimationTree 节点 |
| `blend_node` | String | `""` | BlendSpace 节点路径(如 `"parameters/IdleWalk/blend_position"`) |
| `x` | float | `0.0` | X 混合值 |
| `y` | float | `0.0` | Y 混合值(1D 忽略) |

#### 3.9 SetSpriteFrame

**文件:** `addons/fuse/instructions/animation/set_sprite_frame.gd`

**功能:** 直接设置 Sprite2D/AnimatedSprite2D 的帧。

**参数:** `target_node`, `frame`(int)

#### 3.10 SetZIndex

**文件:** `addons/fuse/instructions/rendering/set_z_index.gd`

**功能:** 设置 CanvasItem 的 `z_index` 属性。

**参数:** `target_node`, `z_index`(int), `relative`(bool,相对调整)

#### 3.11 SetGlobalPosition

**文件:** `addons/fuse/instructions/node_operations/set_global_position.gd`

**功能:** 设置 Node2D/3D 的全局位置。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `target_node` | NodePath | `NodePath("")` | 目标节点 |
| `use_3d` | bool | `false` | 是否 3D |
| `position_2d` | Vector2 | `Vector2.ZERO` | 2D 位置 |
| `position_3d` | Vector3 | `Vector3.ZERO` | 3D 位置 |

#### 3.12 LoadResourceByPath

**文件:** `addons/fuse/instructions/system/load_resource_by_path.gd`

**功能:** 按文件路径加载 Resource 并保存到变量。

**参数:** `resource_path`(String), `save_to_variable`

---

### 批量 C: 特效/条件(4 个)

#### 3.13 ScreenFlash

**文件:** `addons/fuse/instructions/rendering/screen_flash.gd`

**功能:** 全屏闪烁效果。创建 CanvasLayer + ColorRect,Tween alpha 实现脉冲。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `color` | Color | `Color.WHITE` | 闪烁颜色 |
| `duration` | float | `0.15` | 闪烁时长 |
| `flash_count` | int | `1` | 闪烁次数 |

**核心逻辑:**
```gdscript
var canvas = CanvasLayer.new()
canvas.layer = 128
# 异步:Tween → alpha 0→1→0,循环 flash_count 次 → queue_free
_is_synchronous_hint = false
```

> **复杂度中:** 异步执行,Tween 完成后 `_on_execution_completed()`。

#### 3.14 CheckInputDirection

**文件:** `addons/fuse/conditions/input/check_input_direction.gd`

**功能:** 检查当前输入方向(摇杆/键盘)。

**参数:** `input_actions`(Array[String],4个方向动作), `expected_direction`(enum:UP/DOWN/LEFT/RIGHT), `tolerance`(float,默认0.3)

#### 3.15 CheckPlatform

**文件:** `addons/fuse/conditions/system/check_platform.gd`

**功能:** 检查当前运行平台(Windows/macOS/Linux/Android/iOS/Web)。

**参数:** `platform`(enum:WINDOWS/MACOS/LINUX/ANDROID/IOS/WEB)

**核心逻辑:** `OS.get_name()`

**新目录:** `addons/fuse/conditions/system/`

#### 3.16 CheckFrameRate

**文件:** `addons/fuse/conditions/system/check_frame_rate.gd`

**功能:** 检查当前帧率。

**参数:** `compare_type`(enum), `threshold_fps`(float)

**核心逻辑:** `Engine.get_frames_per_second()`

---

### 批量 D: 输入连招事件

#### 3.17 OnInputCombo

**文件:** `addons/fuse/events/input/on_input_combo.gd`

**功能:** 检测输入序列(搓招)。在时间窗口内按顺序检测一组输入动作。

**参数:**
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `combo_sequence` | Array[String] | `[]` | 输入序列(如 `["ui_down","ui_right","ui_accept"]`) |
| `time_window` | float | `0.5` | 整个序列的时间窗口(秒) |
| `reset_on_fail` | bool | `true` | 输入错误时是否重置序列 |

**核心逻辑:**
```gdscript
# 通过 Input.is_action_just_pressed() 检测
# 跟踪当前序列位置和时间戳
# 序列完成 → triggered.emit()
```

> **复杂度中:** 需要运行时状态跟踪(序列位置、最后输入时间)。参考 OnInputBuffered(Stage 1)的运行时状态模式。

---

## 4. 新目录

| 目录 | 包含组件 |
|------|----------|
| `conditions/string/` | `CheckStringContains`, `CheckStringLength` |

---

## 5. 翻译条目

约 90 条新翻译键(18 组件 × 平均 5 条)。

---

## 6. 验证清单

- [ ] 所有 `.gd` 文件通过 LSP 解析
- [ ] 组件被 ComponentScanner 自动注册
- [ ] Inspector 选择器中可搜索到所有新组件
- [ ] ScreenFlash 异步执行正常(Tween 完成 + finished 信号)
- [ ] OnInputCombo 输入序列检测准确
- [ ] 翻译条目完整
- [ ] 现有 166 组件不受影响(Stage 3 完成后)

---


## 6.5 Scope 动态属性开发模式

同 Stage 3 §6.5。涉及变量操作的组件必须使用 `VariableScopeUtils.append_scope_source_properties()` 进行 scope 动态显示。

## 7. 文件清单

**新增(18 .gd + 1 新目录):**

```
addons/fuse/instructions/physics/set_gravity_direction.gd
addons/fuse/instructions/animation/set_animation_blend_position.gd
addons/fuse/instructions/animation/set_sprite_frame.gd
addons/fuse/instructions/string/string_split.gd
addons/fuse/instructions/string/string_join.gd
addons/fuse/instructions/string/string_replace.gd
addons/fuse/instructions/string/string_length.gd
addons/fuse/instructions/rendering/set_z_index.gd
addons/fuse/instructions/rendering/screen_flash.gd
addons/fuse/instructions/node_operations/set_global_position.gd
addons/fuse/instructions/system/load_resource_by_path.gd
addons/fuse/conditions/string/                         (新目录)
addons/fuse/conditions/string/check_string_contains.gd
addons/fuse/conditions/string/check_string_length.gd
addons/fuse/conditions/input/check_input_direction.gd
addons/fuse/conditions/system/                        (新目录)
addons/fuse/conditions/system/check_platform.gd
addons/fuse/conditions/system/check_frame_rate.gd
addons/fuse/events/input/on_input_combo.gd
```

**修改:**

```
addons/fuse/localization/translations.csv — 追加约 90 条翻译
```

---

**文档版本:** 1.0
**最后更新:** 2026-06-17
**审核状态:** 待审核
