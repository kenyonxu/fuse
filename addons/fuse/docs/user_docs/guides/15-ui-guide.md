# UI 系统使用指南

Fuse UI 系统提供 4 个 UI 指令和 5 个 UI 事件，覆盖文本设置、纹理切换、进度条控制、可见性管理以及按钮点击、值变化、文本变化、选项选择和焦点监听等常见 UI 交互需求。

## 指令列表

| 名称 | 功能描述 | 关键参数 |
|------|----------|----------|
| **SetUIText** | 设置 UI 节点的文本内容 | `target_node`（目标 UI 节点）、`use_variable`（是否从变量读取文本）、`text`（直接文本）、`text_variable` / `text_scope`（文本变量名和作用域） |
| **SetUITexture** | 设置 TextureRect 的纹理资源 | `target_node`（目标 TextureRect）、`texture_source`（纹理来源：Resource Path/Variable）、`texture_path`（纹理文件路径）、`texture_variable` / `texture_scope`（纹理变量名和作用域） |
| **SetUIProgress** | 设置 ProgressBar 的进度值 | `target_node`（目标 ProgressBar）、`use_variable`（是否从变量读取进度值）、`value`（直接进度值 0.0-1.0）、`value_variable` / `value_scope`（进度值变量名和作用域） |
| **ShowHideUI** | 控制 UI 节点的可见性 | `target_node`（目标 UI 节点）、`action`（动作：Show/Hide/Toggle） |

### 指令使用说明

**SetUIText：**
- 支持 Label、RichTextLabel、Button、LineEdit、TextEdit 等带有 `text` 属性的控件
- 变量模式下，自动将非字符串类型转为字符串

**SetUITexture 纹理来源：**
- `RESOURCE_PATH`：从文件路径加载纹理
- `VARIABLE`：从变量中获取纹理资源（需变量值为 CompressedTexture2D 等）

**ShowHideUI 动作类型：**
- `SHOW`：显示节点
- `HIDE`：隐藏节点
- `TOGGLE`：切换当前可见状态

---

## 事件列表

| 名称 | 触发条件 | 输出数据 |
|------|----------|----------|
| **OnButtonPressed** | Button 节点被按下时触发 | `button`（按钮节点，可选） |
| **OnValueChanged** | Slider/SpinBox/ProgressBar 值改变时触发 | `value`（当前值）、`old_value`（旧值）、`delta`（变化量） |
| **OnTextChanged** | LineEdit/TextEdit 文本改变时触发 | `text`（当前文本）、`old_text`（旧文本） |
| **OnItemSelected** | ItemList 控件选中项改变时触发 | `selected_indices`（选中索引数组）、`selected_count`（选中数量） |
| **OnFocus** | Control 节点获得或失去焦点时触发 | `target_node`（目标节点）、`focus_type`（"entered" / "exited"） |

### 事件使用说明

**OnButtonPressed：**
- `require_enabled`：启用时仅在按钮处于非禁用状态下触发
- `emit_button`：启用时将按钮节点作为事件数据传递

**OnValueChanged 触发模式：**
- `ON_ANY_CHANGE`：任何值变化都触发
- `ON_THRESHOLD`：值达到指定阈值时触发（`threshold_value`）
- `ON_MIN_REACHED`：值达到最小阈值时触发（`min_threshold`）
- `ON_MAX_REACHED`：值达到最大阈值时触发（`max_threshold`）

**OnTextChanged 触发模式：**
- `ON_CHANGE`：文本改变时触发
- `ON_EMPTY`：文本为空时触发
- `ON_MAX_LENGTH`：达到最大长度时触发（`max_length`）
- `ON_PATTERN_MATCH`：匹配正则表达式模式时触发（`pattern`）

**OnItemSelected：**
- `multi_select_mode`：启用多选模式
- `emit_indices`：是否传递选中的索引数组
- `emit_count`：是否传递选中的项数

**OnFocus 监听模式：**
- `ON_ENTERED`：仅焦点进入时触发
- `ON_EXITED`：仅焦点离开时触发
- `ON_BOTH`：焦点进入和离开都触发

---

## 常见用例

### 1. HP 血条更新

使用 `SetUIProgress` 配合变量实时更新血条：

```
# 更新血条
SetUIProgress → target_node: HPBar, use_variable: true, value_variable: hp_ratio, value_scope: Local
```

### 2. 分数显示

使用 `SetUIText` 配合变量显示当前分数：

```
# 更新分数文本
SetUIText → target_node: ScoreLabel, use_variable: true, text_variable: score_text, text_scope: Local
```

### 3. 暂停菜单切换

使用 `ShowHideUI` 的 Toggle 模式切换暂停面板：

```
# 切换暂停菜单
ShowHideUI → target_node: PausePanel, action: Toggle
```
