> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/06-instruction-generator-guide.md)

# 指令生成器使用指南

通过右键场景树节点自动生成 Fuse 指令。选择节点的方法或属性，一键生成可用的指令文件，无需手写代码。

## 快速开始

1. 在场景树中**右键点击**任意节点
2. 选择 **"生成指令..."**
3. 在弹出对话框中选择方法或属性
4. 点击 **"生成指令"**

生成的指令自动注册到 Fuse 系统，可以在指令选择器的 **"用户生成"** 分类下找到。

---

## 对话框界面

对话框标题显示目标节点的名称和类名，例如 "为 Player (CharacterBody2D) 生成指令"。

界面分为两个标签页：

### 方法标签页

浏览节点的所有可用方法。方法按继承链分组显示，子类在前。

```
▸ CharacterBody2D (5)
    ▸ move_and_slide
    ▸ velocity
▸ Node2D (12)
    ▸ global_position
    ▸ look_at
    ▸ rotate
```

选中方法后，右侧信息面板显示方法签名、定义类和参数列表。

### 属性标签页

浏览节点的所有可写属性。同样按继承链分组。

选中属性后，右侧信息面板显示属性类型、提示类型、默认值和范围（数值类型）。

底部提供三种生成模式：

| 模式 | 说明 |
|------|------|
| SET | 生成设置属性值的指令 |
| GET | 生成读取属性值并存入变量的指令 |
| 两者都生成 | 同时生成 SET 和 GET 两个指令 |

---

## 生成选项

### 使用变量

对话框底部的 **"使用变量"** 复选框控制参数的来源方式。

**不勾选** — 生成直接赋值版本。参数值在 Inspector 中直接输入：

```gdscript
# 直接赋值版本 — speed_scale 在 Inspector 中设置固定值
@export var speed_scale_value: float = 1.0

func execute(context: ExecutionContext):
    node.speed_scale = speed_scale_value
```

**勾选** — 生成变量绑定版本。每个参数支持两种来源：

| 来源 | 说明 |
|------|------|
| 直接值 | 在 Inspector 中输入固定值 |
| 变量 | 运行时从变量读取值 |

选择"变量"来源后，可以指定变量名和作用域：

| 作用域 | 说明 |
|--------|------|
| Local | 读取局部变量 |
| Global | 读取全局变量 |
| Scope | 读取作用域变量 |

Scope 作用域支持四种来源定位：

| 来源 | 说明 |
|------|------|
| Nearest | 使用最近的作用域容器 |
| Custom ID | 指定自定义作用域 ID |
| Trigger Scope | 使用触发器所在作用域 |
| Target Node | 指定目标节点的路径 |

变量绑定版本在 Inspector 中的属性会根据选择动态显示和隐藏——选择"直接值"时隐藏变量相关字段，选择"变量"时隐藏直接值字段。这与内置指令的双轨行为完全一致，通用机制见[变量绑定使用指南](07-variable-binding-guide.md)。

### 方法标签页的变量绑定

为方法的每个参数独立生成来源选项。例如 `AnimatedSprite2D.play(name, custom_speed, from_end)` 会为三个参数分别生成来源枚举和对应的值/变量字段。

### 属性标签页的变量绑定

仅对 SET 模式生效。勾选后生成的 SET 指令支持从变量读取属性值。

GET 指令始终使用变量系统（因为 GET 的目的就是把值存入变量），不需要额外勾选。

---

## 生成的文件

### 存放位置

所有生成的指令保存在 `res://fuse_generated/instructions/` 下，按节点类名分子目录：

```
fuse_generated/instructions/
└── animatedsprite2d/
    ├── animated_sprite2d_play.gd                  # 方法指令
    ├── animated_sprite2d_play_with_variable.gd     # 方法指令（变量版）
    ├── set_animated_sprite2d_speed_scale.gd        # SET 指令
    ├── set_animated_sprite2d_speed_scale_with_variable.gd  # SET 指令（变量版）
    └── get_animated_sprite2d_speed_scale.gd        # GET 指令
```

### 文件命名规则

| 指令类型 | 命名格式 |
|----------|---------|
| 方法 | `{类名}_{方法名}.gd` |
| 方法（变量版） | `{类名}_{方法名}_with_variable.gd` |
| SET 属性 | `set_{类名}_{属性名}.gd` |
| SET 属性（变量版） | `set_{类名}_{属性名}_with_variable.gd` |
| GET 属性 | `get_{类名}_{属性名}.gd` |

### 自动注册

生成后指令自动注册到 InstructionRegistry，无需手动操作。重启编辑器时会重新扫描 `fuse_generated/instructions/` 目录加载所有生成指令。

---

## 文件冲突

如果目标文件已存在（之前生成过同名指令），点击"生成指令"时会弹出确认对话框：

```
以下指令文件已存在：
  res://fuse_generated/instructions/.../xxx.gd
是否覆盖？
```

- **确认** — 覆盖现有文件
- **跳过** — 取消操作

---

## 各类指令详解

### 方法指令

调用节点的指定方法。

**Inspector 配置项：**
- `target_node` — 目标节点的路径
- 各参数 — 方法的每个参数，类型和默认值与方法签名一致

**有返回值的方法**会额外提供：
- `result_variable` — 存储返回值的变量名（可选）
- `result_variable_scope` — 存储作用域（Local / Scope / Global）

### SET 属性指令

设置节点的属性值。

**直接赋值版本：**
- `target_node` — 目标节点路径
- `{属性名}_value` — 要设置的值，类型与属性匹配

**变量绑定版本：**
- `target_node` — 目标节点路径
- `{属性名}_source` — "直接值" 或 "变量"
- `{属性名}_value` — 直接值模式的输入
- `{属性名}_variable` — 变量名
- `{属性名}_scope` — 变量作用域

### GET 属性指令

读取节点的属性值并存入变量。

**Inspector 配置项：**

Target 分类：
- `target_node` — 目标节点路径

Save To 分类：
- `save_to_variable` — 存入的变量名
- `save_to_scope` — 存储作用域（Local / Scope / Global）
- `scope_source` — Scope 作用域的来源定位（仅 SCOPE 作用域时显示）
- `custom_scope_id` — 自定义作用域 ID（仅 Custom ID 模式时显示）
- `save_target_node_path` — 目标节点路径（仅 Target Node 模式时显示）

---

## 使用示例

### 示例 1：生成 play 方法指令

为目标节点 `AnimatedSprite2D` 生成 `play()` 方法调用：

1. 右键 AnimatedSprite2D 节点 → "生成指令..."
2. 在方法标签页找到 `play`
3. 信息面板显示签名：`play(name: StringName = &"", custom_speed: float = 0.0, from_end: bool = false)`
4. 点击"生成指令"

在 Trigger 中使用该指令时，设置 `target_node` 指向 AnimatedSprite2D 节点，配置各参数即可。

### 示例 2：生成带变量的 SET 指令

运行时从变量读取 `speed_scale` 值：

1. 右键 AnimatedSprite2D 节点 → "生成指令..."
2. 切换到属性标签页，找到 `speed_scale`
3. 勾选 **"使用变量"**
4. 生成模式选择 SET
5. 点击"生成指令"

在 Trigger 中使用时，将 `speed_scale_source` 设为"变量"，填入变量名和作用域即可在运行时动态读取值。

### 示例 3：生成 GET 指令读取位置

将 `CharacterBody2D` 的 `position` 存入变量：

1. 右键 CharacterBody2D 节点 → "生成指令..."
2. 切换到属性标签页，找到 `position`
3. 生成模式选择 GET
4. 点击"生成指令"

在 Trigger 中使用时，配置 `target_node` 和 `save_to_variable`（例如 "player_pos"），选择存储作用域。运行后该变量的值会更新为节点的当前位置。

---

## 搜索功能

方法和属性列表都支持搜索。输入关键词即可过滤，例如输入 "speed" 可以快速找到 `speed_scale`、`max_speed` 等属性。

搜索支持属性名和类型名匹配。输入 "vector" 可以找到所有 Vector2/Vector3 类型的属性。

---

## 注意事项

- 生成的文件标记为"自动生成"，手动修改可能在下次生成时被覆盖
- 生成指令不使用 `class_name`，通过文件路径注册，不会产生全局命名冲突
- 方法列表已自动过滤私有方法、虚方法和静态方法，只显示可直接调用的实例方法
- 属性列表仅显示可写属性，只读属性不会出现
- 内部属性（以 `_` 开头）已自动过滤

---

**最后更新**: 2026-03-17
