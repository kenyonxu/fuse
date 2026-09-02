# Fuse 指令分类参考

> 各类 Fuse 指令的实现细节和示例参考

**最后更新**: 2026-01-28

---

## 目录

1. [节点操作类指令](#节点操作类指令)
2. [变量操作类指令](#变量操作类指令)
3. [流程控制类指令](#流程控制类指令)
4. [动画控制类指令](#动画控制类指令)
5. [音频控制类指令](#音频控制类指令)
6. [场景管理类指令](#场景管理类指令)
7. [UI 操作类指令](#ui-操作类指令)
8. [物理控制类指令](#物理控制类指令)
9. [数学运算类指令](#数学运算类指令)
10. [调试工具类指令](#调试工具类指令)

---

## 节点操作类指令

### 特点

- 操作 Node2D 或 Node3D 对象
- 需要支持相对路径解析
- 通常需要类型检查和验证
- 可能需要同时支持 2D 和 3D

### 常见模式

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 1. 验证目标节点
    if target_node.is_empty():
        _log_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", {})
        set_error_localized("FUSE_ERROR_TARGET_NODE_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        finished.emit()
        return

    # 2. 获取节点
    var node := context.get_node(target_node)
    if not node:
        _log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
        set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"node": str(target_node)})
        finished.emit()
        return

    # 3. 类型检查
    if not (node is Node2D or node is Node3D):
        var type_str = node.get_class()
        _log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": node.name, "actual_type": type_str})
        set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {"node": node.name, "actual_type": type_str})
        finished.emit()
        return

    # 4. 执行操作（分别处理 2D 和 3D）
    if node is Node2D:
        # 2D 操作
        pass
    elif node is Node3D:
        # 3D 操作
        pass

    _on_execution_completed()
```

### 示例指令

- **MoveBy** - 相对移动节点
- **SetPosition** - 设置节点位置
- **EnableDisableNode** - 启用/禁用节点
- **QueueFreeNode** - 释放节点

---

## 变量操作类指令

### 特点

- 需要区分本地变量和全局变量
- 支持变量类型检查
- 需要检测 GlobalVariableAssistant
- 可能支持变量到变量的赋值

### 常见模式

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 1. 验证变量名
    if variable_name.is_empty():
        _log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
        set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        finished.emit()
        return

    # 2. 如果是全局变量，检测 GlobalVariableAssistant
    if scope == BaseVariable.VariableScope.GLOBAL:
        if not _detect_and_validate_assistant():
            _log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": "GlobalVariableAssistant"})
            set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.CONFIGURATION_ERROR, {"node": "GlobalVariableAssistant"})
            finished.emit()
            return

    # 3. 执行变量操作
    match scope:
        BaseVariable.VariableScope.LOCAL:
            # 本地变量操作
            if context.has_variable(variable_name):
                value = context.get_variable(variable_name)
        BaseVariable.VariableScope.GLOBAL:
            # 全局变量操作
            if detected_assistant:
                var variable = detected_assistant.get_global_variable(variable_name)
                if variable:
                    value = variable.get_value()

    _on_execution_completed()

# 检测 GlobalVariableAssistant 的辅助方法
func _detect_and_validate_assistant() -> bool:
    detected_assistant = GlobalVariableAssistant.get_instance()
    if detected_assistant == null:
        return false

    if detected_assistant.current_resource == null:
        return false

    return true
```

### 示例指令

- **SetVariable** - 设置变量值
- **CreateVariable** - 创建变量
- **PrintVariableValue** - 打印变量值

---

## 流程控制类指令

### 特点

- 控制执行流程（循环、条件、等待）
- 可能是异步指令（等待）
- 需要正确处理子指令执行
- 需要特殊的资源名称构建

### 同步流程控制

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 执行条件判断
    if condition:
        # 执行 then 分支
        _on_execution_completed()
    else:
        # 执行 else 分支
        _on_execution_completed()
```

### 异步流程控制（定时器）

```gdscript
var _timer: SceneTreeTimer = null

func execute(context: ExecutionContext):
    _start_execution(context)

    var scene_tree = Engine.get_main_loop()
    if not scene_tree:
        _log_error_localized("FUSE_ERROR_CANNOT_CREATE_TIMER", {})
        finished.emit()
        return

    _timer = scene_tree.create_timer(delay)
    _timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout():
    _cleanup_resources()
    finished.emit()

func _cleanup_resources():
    if _timer and is_instance_valid(_timer):
        if _timer.timeout.is_connected(_on_timer_timeout):
            _timer.timeout.disconnect(_on_timer_timeout)
        _timer = null
```

### 示例指令

- **IfElse** - 条件分支
- **WhileLoop** - While 循环
- **ForLoop** - For 循环
- **Wait** - 等待（异步）
- **WaitUntil** - 等待直到条件满足（异步）

---

## 动画控制类指令

### 特点

- 操作 AnimationPlayer 节点
- 支持同步和异步播放
- 需要处理动画不存在的情况
- 可能需要支持混合动画

### 常见模式

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 1. 获取 AnimationPlayer
    var node := context.get_node(target_node)
    if not node or not node is AnimationPlayer:
        _log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": str(target_node), "actual_type": "Not AnimationPlayer"})
        set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {})
        finished.emit()
        return

    var animation_player := node as AnimationPlayer

    # 2. 验证动画存在
    if not animation_player.has_animation(animation_name):
        _log_error_localized("FUSE_ERROR_ANIMATION_NOT_FOUND", {"animation": animation_name})
        set_error_localized("FUSE_ERROR_ANIMATION_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"animation": animation_name})
        finished.emit()
        return

    # 3. 播放动画
    if wait_for_completion:
        animation_player.animation_finished.connect(_on_animation_finished)
        animation_player.play(animation_name)
        # 不调用 _on_execution_completed()，等待动画完成
    else:
        animation_player.play(animation_name)
        _on_execution_completed()

func _on_animation_finished(_animation_name: String):
    if _animation_name == animation_name:
        finished.emit()
```

### 示例指令

- **PlayAnimation** - 播放动画
- **StopAnimation** - 停止动画
- **BlendAnimation** - 混合动画
- **SetAnimationSpeed** - 设置动画速度

---

## 音频控制类指令

### 特点

- 操作 AudioStreamPlayer 节点
- 需要处理音频总线（Bus）
- 可能需要支持循环播放
- 支持音量控制

### 常见模式

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 1. 获取音频节点
    var node := context.get_node(target_node)
    if not node or not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
        _log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": str(target_node), "actual_type": "Not AudioStreamPlayer"})
        set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {})
        finished.emit()
        return

    var audio_player := node

    # 2. 设置音量（如果需要）
    audio_player.volume_db = volume_db

    # 3. 播放音频
    if wait_for_completion:
        audio_player.finished.connect(_on_audio_finished)
        audio_player.play()
    else:
        audio_player.play()
        _on_execution_completed()

func _on_audio_finished():
    finished.emit()
```

### 获取音频总线列表

```gdscript
func _get_bus_names() -> PackedStringArray:
    var bus_names = []
    for i in range(AudioServer.get_bus_count()):
        bus_names.append(AudioServer.get_bus_name(i))
    return bus_names
```

### 示例指令

- **PlaySound** - 播放音效
- **PlayMusic** - 播放音乐
- **StopAudio** - 停止音频
- **SetAudioVolume** - 设置音量
- **PauseResumeAudio** - 暂停/恢复音频

---

## 场景管理类指令

### 特点

- 操作场景树和场景加载
- 需要使用 SceneTree API
- 可能涉及后台加载（异步）
- 需要验证场景路径

### 常见模式

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 1. 验证场景路径
    if scene_path.is_empty():
        _log_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", {})
        set_error_localized("FUSE_ERROR_SCENE_PATH_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        finished.emit()
        return

    # 2. 验证场景文件存在
    if not ResourceLoader.exists(scene_path, "PackedScene"):
        _log_error_localized("FUSE_ERROR_SCENE_NOT_FOUND", {"scene": scene_path})
        set_error_localized("FUSE_ERROR_SCENE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {"scene": scene_path})
        finished.emit()
        return

    # 3. 获取 SceneTree
    var scene_tree = Engine.get_main_loop()
    if not scene_tree:
        _log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
        set_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", FuseError.ErrorType.RUNTIME_ERROR, {})
        finished.emit()
        return

    # 4. 切换场景
    scene_tree.change_scene_to_file(scene_path)
    _on_execution_completed()
```

### 后台加载场景（异步）

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    var scene_tree = Engine.get_main_loop()
    if not scene_tree:
        _log_error_localized("FUSE_ERROR_CANNOT_GET_SCENETREE", {})
        finished.emit()
        return

    # 后台加载
    ResourceLoader.load_threaded_request(scene_path, "PackedScene")
    _poll_load = true

func _process(_delta: float):
    if not _poll_load:
        return

    var status = ResourceLoader.load_threaded_get_status(scene_path)
    if status == ResourceLoader.THREAD_LOAD_LOADED:
        _poll_load = false
        var packed_scene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
        # 创建场景实例
        finished.emit()
```

### 示例指令

- **ChangeScene** - 切换场景
- **ReloadScene** - 重载当前场景
- **LoadSceneBackground** - 后台加载场景
- **AddSceneAsChild** - 添加场景为子节点
- **InstantiateScene** - 实例化场景

---

## UI 操作类指令

### 特点

- 操作 Control 节点（Button、Label、ProgressBar 等）
- 需要处理各种 UI 控件类型
- 支持 Texture 和 Text 修改
- 支持 Show/Hide 控制

### 常见模式

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 1. 获取 UI 节点
    var node := context.get_node(target_node)
    if not node or not node is Control:
        _log_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", {"node": str(target_node), "actual_type": "Not Control"})
        set_error_localized("FUSE_ERROR_NODE_TYPE_INVALID", FuseError.ErrorType.RUNTIME_ERROR, {})
        finished.emit()
        return

    var control := node as Control

    # 2. 执行 UI 操作
    if show:
        control.show()
    else:
        control.hide()

    _on_execution_completed()
```

### 示例指令

- **ShowHideUI** - 显示/隐藏 UI
- **SetUIText** - 设置 UI 文本
- **SetUITexture** - 设置 UI 纹理
- **SetUIProgress** - 设置 UI 进度条

---

## 物理控制类指令

### 特点

- 操作 PhysicsBody 节点
- 需要处理物理计算
- 支持力和冲量应用
- 可能需要碰撞层设置

### 常见模式

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 1. 获取物理节点
    var node := context.get_node(target_node)
    if not node:
        _log_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", {"node": str(target_node)})
        set_error_localized("FUSE_ERROR_TARGET_NODE_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
        finished.emit()
        return

    # 2. 应用物理效果（根据节点类型）
    if node is CharacterBody2D:
        var body := node as CharacterBody2D
        # 应用速度或力
    elif node is RigidBody3D:
        var body := node as RigidBody3D
        body.apply_central_impulse(force)

    _on_execution_completed()
```

### 示例指令

- **ApplyImpulse** - 应用冲量
- **ApplyForce** - 应用力
- **SetVelocity** - 设置速度
- **SetCollisionLayer** - 设置碰撞层
- **Raycast** - 射线检测

---

## 数学运算类指令

### 特点

- 不需要节点引用
- 执行数学计算
- 将结果保存到变量
- 支持多种数学类型

### 常见模式

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 1. 执行计算
    var result: Variant
    match operation:
        MathOperation.ADD:
            result = a + b
        MathOperation.MULTIPLY:
            result = a * b

    # 2. 保存到变量
    if not target_variable.is_empty():
        context.set_variable(target_variable, result)
    else:
        _log_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", {})
        set_error_localized("FUSE_ERROR_VAR_NAME_EMPTY", FuseError.ErrorType.VALIDATION_ERROR, {})
        finished.emit()
        return

    _on_execution_completed()
```

### 示例指令

- **MathOperation** - 数学运算
- **VectorOperation** - 向量运算
- **RandomNumber** - 随机数
- **ClampValue** - 限制数值范围
- **Lerp** - 线性插值

---

## 调试工具类指令

### 特点

- 用于调试和日志
- 不影响游戏逻辑
- 输出到控制台
- 支持变量值打印

### 常见模式

```gdscript
func execute(context: ExecutionContext):
    _start_execution(context)

    # 1. 格式化消息
    var message = format_message()

    # 2. 根据级别输出
    match log_level:
        LogLevel.INFO:
            _log_info(message)
        LogLevel.WARNING:
            _log_warning(message)
        LogLevel.ERROR:
            _log_error(message)

    _on_execution_completed()
```

### 示例指令

- **Print** - 打印消息
- **PrintVariableValue** - 打印变量值
- **GetDeltaTime** - 获取 Delta 时间

---

## 选择指令分类的指南

创建新指令时，根据功能选择合适的分类：

| 功能需求 | 推荐分类 | 参考示例 |
|---------|---------|---------|
| 修改节点属性 | 节点操作 | SetPosition, SetRotation |
| 创建/读取/修改变量 | 变量操作 | SetVariable, CreateVariable |
| 控制执行流程 | 流程控制 | IfElse, WhileLoop |
| 播放/停止动画 | 动画控制 | PlayAnimation, StopAnimation |
| 播放/停止音频 | 音频控制 | PlaySound, StopAudio |
| 加载/切换场景 | 场景管理 | ChangeScene, ReloadScene |
| 显示/隐藏 UI | UI 操作 | ShowHideUI, SetUIText |
| 应用物理效果 | 物理控制 | ApplyImpulse, SetVelocity |
| 数学计算 | 数学运算 | MathOperation, RandomNumber |
| 调试输出 | 调试工具 | Print, PrintVariableValue |

---

**最后更新**: 2026-01-28
