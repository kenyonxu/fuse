这是一份关于 **`JuicyAnimationTreeResource`** 和 **`JuicyAnimationTreeDriver`** 的设计草案。

与 `AnimationPlayer` 不同，`AnimationTree` 是一个状态机和混合树系统，它不是单纯的“播放”，而是“驱动参数”或“请求状态转换”。因此，这个 Driver 的设计重点在于**参数映射（Parameter Mapping）和状态机交互（State Machine Interaction）**。

-----

# JuicyAnimationTree 系统设计草案

## 1\. 设计核心理念

### 1.1 为什么需要独立的 Tree Driver？

`JuicyAnimationPlayDriver` 只能控制线性的 Clip 播放。但在现代动作游戏中，角色动画通常由 `AnimationTree` 接管（处理混合、状态机切换）。
我们需要一种机制，让 JuicyMixer 能够：

1.  **控制混合参数**：例如，在 Timeline 中通过曲线控制 `BlendSpace1D` 的值，实现“受击时身体后仰程度”的平滑变化。
2.  **触发 OneShot**：在反馈序列中触发一个 `OneShot` 节点（如受击动作层）。
3.  **状态跳转 (Travel)**：强制状态机跳转到特定状态。

### 1.2 两种核心工作模式

1.  **Drive Parameter (参数驱动模式 - Sync)**：
      * **行为**：在一段时间内，将 Tree 的某个参数（如 `parameters/blend_position`）从 A 变到 B。
      * **适用**：Timeline 驱动的混合效果（如：蓄力时改变 Pose 混合度）。
2.  **Trigger Action (动作触发模式 - Fire & Forget)**：
      * **行为**：触发 `OneShot` 节点，或调用 `StateMachinePlayback.travel()`。
      * **适用**：简单的受击反馈、状态切换。

-----

## 2\. 数据层：JuicyAnimationTreeResource

**文件路径**: `addons/juicy_mixer/resources/juicy_animation_tree_resource.gd`

### 2.1 核心属性设计

```gdscript
@tool
class_name JuicyAnimationTreeResource
extends JuicyFeedbackResource

# 目标 AnimationTree 节点
@export var target_tree_path: NodePath

# 操作类型枚举
enum OperationMode {
    SET_PARAMETER,  # 驱动参数 (float/vector2/bool)
    TRIGGER_ONESHOT, # 触发 OneShot 节点
    TRAVEL_STATE     # 状态机跳转
}
@export var operation_mode: OperationMode = OperationMode.SET_PARAMETER

# --- 1. 参数驱动配置 (针对 SET_PARAMETER) ---
@export_group("Parameter Driving")
@export var parameter_path: String = "" # 例如 "parameters/Idle/blend_position"
@export var start_value: Variant        # 支持 float, Vector2, bool
@export var end_value: Variant
@export var curve: Curve                # 变化曲线 (0-1)
@export var blend_mode: int = 1         # 0: Override, 1: Additive (如果 Tree 支持)

# --- 2. OneShot 配置 (针对 TRIGGER_ONESHOT) ---
@export_group("OneShot Trigger")
@export var oneshot_request_path: String = "" # 例如 "parameters/HitShot/request"
@export var fade_in_time: float = 0.1
@export var fade_out_time: float = 0.1

# --- 3. 状态机配置 (针对 TRAVEL_STATE) ---
@export_group("State Machine")
@export var playback_path: String = "parameters/playback" # 默认路径
@export var target_state: String = "" # 例如 "Attack"

# --- 编辑器辅助 ---
# 需要实现 _get_property_list 来动态隐藏不相关的属性组
```

### 2.2 编辑器痛点解决

  * **痛点**：`parameter_path` 手填极其容易出错。
  * **方案**：在 Resource 的 Inspector 插件中，实现一个 **Tree Parameter Picker**。遍历目标 `AnimationTree` 的所有属性，列出以 `parameters/` 开头的有效路径供用户选择。

-----

## 3\. 逻辑层：JuicyAnimationTreeDriver

**文件路径**: `addons/juicy_mixer/drivers/juicy_animation_tree_driver.gd`

### 3.1 核心逻辑流程

```gdscript
class_name JuicyAnimationTreeDriver
extends JuicyDriver

# 缓存 Tree 引用和 Playback 对象
class DriverState:
    var tree: AnimationTree
    var playback: AnimationNodeStateMachinePlayback
    var initial_val: Variant

func prepare(context: JuicyContext) -> void:
    var res = context.resource as JuicyAnimationTreeResource
    var tree = context.target.get_node(res.target_tree_path) as AnimationTree
    
    # 缓存状态
    var state = DriverState.new()
    state.tree = tree
    context.set_driver_data("tree_state", state)
    
    # 针对 Trigger 模式的立即执行
    if res.operation_mode == res.OperationMode.TRAVEL_STATE:
        state.playback = tree.get(res.playback_path)
        state.playback.travel(res.target_state)
        
    elif res.operation_mode == res.OperationMode.TRIGGER_ONESHOT:
        # OneShot 需要设置 request 为 OneShot.ONE_SHOT_REQUEST_FIRE
        tree.set(res.oneshot_request_path, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func process(context: JuicyContext, delta: float, buffer: JuicyPropertyBuffer) -> void:
    var res = context.resource as JuicyAnimationTreeResource
    var state = context.get_driver_data("tree_state")
    
    # 只有 Parameter 模式需要每帧更新
    if res.operation_mode == res.OperationMode.SET_PARAMETER:
        _process_parameter_tween(context, res, state, buffer)

func _process_parameter_tween(context, res, state, buffer):
    # 1. 计算进度 (0-1)
    var t = context.progress
    if res.curve:
        t = res.curve.sample(t)
    
    # 2. 计算当前值
    var current_val = lerp(res.start_value, res.end_value, t)
    
    # 3. 写入 PropertyBuffer
    # 注意：AnimationTree 的参数也是属性，可以直接用 Buffer 混合！
    # 如果多个 Timeline 同时想控制 BlendPosition，Buffer 会自动处理 Additive
    buffer.add_sample(
        state.tree, 
        res.parameter_path, 
        current_val, 
        res.blend_mode
    )
```

-----

## 4\. 关键设计重点与挑战

### 4.1 属性混合的特殊性

`AnimationTree` 的参数通常是输入，而不是直接的视觉属性。

  * **挑战**：如果游戏逻辑（玩家输入）正在设置 `blend_position` 为 `(1, 0)`（向右跑），而 JuicyMixer 想要叠加一个 `(0, -0.5)` 的偏移（后仰）。
  * **解决**：必须确保 `JuicyAnimationTreeDriver` 使用 **`JuicyPropertyBuffer`** 且模式为 **`ADDITIVE`**。
  * **注意**：`AnimationTree` 的参数通常没有 `get()` 初始值的概念（或者初始值就是当前帧的值）。在 Buffer 的 `Base Value` 阶段，需要正确获取游戏逻辑设置的值作为 Base。

### 4.2 类型支持

`AnimationTree` 参数类型多样：

  * `BlendSpace1D` -\> `float`
  * `BlendSpace2D` -\> `Vector2`
  * `Mix` / `Add` Node -\> `float` (0.0 - 1.0)
  * `Transition` Node -\> `int` (Index)
  * `OneShot` Node -\> `bool` (Active) 或内部 Enum

**Resource 必须使用 `Variant`** 来存储 `start_value` 和 `end_value`，并在编辑器中根据选择的 `parameter_path` 自动切换 Inspector 的输入框类型（例如检测到是 Vector2 就显示 Vector2 编辑框）。

### 4.3 时间控制 (TimeScale)

`AnimationTree` 默认使用物理帧或空闲帧更新。

  * 如果 JuicyContext 的 `time_scale` 变慢（例如 HitStop），`AnimationTree` **不会自动变慢**，因为它独立运行。
  * **解决方案**：
    1.  **简单方案**：不处理。Juicy 只驱动参数，Tree 照常播放。
    2.  **高级方案（Manual Advance）**：如果需要 Juicy 完全接管时间（如回放系统），需要将 Tree 的 `process_callback` 设为 `Manual`，然后由一个专门的 Global Driver 统一调用 `advance(delta * time_scale)`。但这侵入性太强，**建议 V3 暂不强制接管 Tree 的时间**，只控制 Tree 的参数。

-----

## 5\. 开发路线建议

1.  **第一步：实现 Resource 与 Editor Plugin**
      * 重点是 `_get_property_list` 的动态实现，以及一个 helper class 用于扫描 AnimationTree 的参数树。
2.  **第二步：实现基础 Driver (Set Parameter)**
      * 先打通 `float` 和 `Vector2` 的 Tween 功能。验证 `JuicyPropertyBuffer` 能否正确驱动 Tree 的参数。
3.  **第三步：实现 State/OneShot 触发**
      * 这是简单的 API 调用，容易实现。
4.  **第四步：集成到 Timeline Editor**
      * 在 Timeline 编辑器中，拖入 `JuicyAnimationTreeResource` 应显示为专门的轨道，最好能可视化参数曲线。

这个设计草案填补了 JuicyMixer 在“程序化动画混合”方面的空白，配合之前的 `AnimationPlayDriver`（处理 Clips）和 `Timeline`，你的系统将具备完整的动画导演能力。