# Task 6: 运行时测试指南

**任务：** 验证 Trigger 的 `initialize_with_runtime_instance()` 集成
**预计时间：** 5-10 分钟
**难度：** 简单

---

## 测试前准备

### 1. 启动 Godot 编辑器

```bash
E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe --path "e:\Godot\GodotProjects\project-juicy-godot"
```

### 2. 打开项目

等待编辑器加载完成，确保没有错误或警告。

---

## 测试 1: 场景加载测试

### 目标
验证场景可以正常加载，没有初始化错误。

### 步骤

1. 在编辑器中，导航到 `demos/fuse/`
2. 双击打开 `brick_ui_demo.tscn`
3. 观察编辑器输出面板

### 预期结果

✅ **成功：**
- 场景正常加载
- 没有错误或警告
- 可以看到两个按钮节点

❌ **失败：**
- 出现 "无法加载场景" 错误
- 出现 "初始化失败" 错误
- 场景树显示红色错误图标

---

## 测试 2: 鼠标悬停功能测试

### 目标
验证鼠标悬停功能正常工作，事件可以正确触发。

### 步骤

1. 确保已打开 `brick_ui_demo.tscn`
2. 按 **F6** 运行场景（或点击 "运行当前场景" 按钮）
3. 将鼠标移动到左侧按钮上
4. 观察编辑器输出面板的日志
5. 将鼠标移出按钮
6. 再次将鼠标移入按钮
7. 重复测试右侧按钮

### 预期结果

✅ **成功：**
```
[DEBUG] [OnMouseEnter] 鼠标进入节点触发: Button
[INFO] [Trigger] 事件触发: OnMouseEnter
[DEBUG] [RuntimeEventInstance] 更新触发统计: instance_id=12345
```

❌ **失败：**
- 没有任何日志输出
- 出现 "信号未连接" 错误
- 出现 "RuntimeEventInstance 为空" 错误

---

## 测试 3: 状态隔离测试（重要）

### 目标
验证两个按钮完全独立，互不干扰。

### 步骤

1. 确保场景正在运行
2. 快速在两个按钮之间来回移动鼠标
3. 观察每个按钮是否独立触发事件
4. 检查日志中的 RuntimeEventInstance ID

### 预期结果

✅ **成功（状态隔离正确）：**
- 每个按钮独立触发事件
- 日志显示不同的 RuntimeEventInstance ID，例如：
  ```
  [Button A] RuntimeEventInstance ID: 12345
  [Button B] RuntimeEventInstance ID: 67890
  ```
- 从按钮 A 移到按钮 B 时，两个按钮都会触发

❌ **失败（状态隔离错误）：**
- 只有第一个按钮能触发
- 从按钮 A 移到按钮 B 时，按钮 B 不触发
- 日志显示相同的 RuntimeEventInstance ID
- 出现 "状态已存在" 警告

---

## 测试 4: 重复触发测试

### 目标
验证 `trigger_once_per_enter` 参数是否正确工作。

### 步骤

1. 确保场景正在运行
2. 将鼠标移入按钮 A
3. 保持鼠标在按钮 A 内，不要移出
4. 来回移动鼠标（但不离开按钮）
5. 观察日志输出

### 预期结果

✅ **成功（trigger_once_per_enter = true）：**
- 第一次进入时触发一次
- 之后在按钮内移动鼠标不再触发
- 日志显示：
  ```
  [DEBUG] 鼠标进入节点触发: Button (第1次)
  [DEBUG] 事件已进入，跳过触发 (第2次及之后)
  ```

❌ **失败：**
- 每次移动鼠标都会触发
- 出现重复的事件日志

---

## 测试 5: 向后兼容性测试

### 目标
验证其他使用旧 `initialize()` 方法的事件仍然正常工作。

### 步骤

1. 打开 `demos/fuse/brick_demo_basic.tscn`
2. 运行场景（F6）
3. 测试场景中的各种事件
4. 观察是否有任何错误

### 预期结果

✅ **成功：**
- 所有事件正常工作
- 没有出现 "方法未找到" 错误
- 没有出现任何向后兼容性问题

❌ **失败：**
- 某些事件不工作
- 出现 "initialize() 方法未实现" 错误

---

## 测试结果记录

请记录你的测试结果：

| 测试项 | 状态 | 备注 |
|--------|------|------|
| 测试 1: 场景加载 | ⬜ 通过 / ⬜ 失败 |  |
| 测试 2: 鼠标悬停功能 | ⬜ 通过 / ⬜ 失败 |  |
| 测试 3: 状态隔离 | ⬜ 通过 / ⬜ 失败 |  |
| 测试 4: 重复触发 | ⬜ 通过 / ⬜ 失败 |  |
| 测试 5: 向后兼容性 | ⬜ 通过 / ⬜ 失败 |  |

---

## 常见问题排查

### 问题 1: 场景加载失败

**可能原因：**
- RuntimeEventInstance 类未找到
- 编译错误

**解决方法：**
1. 检查 `addons/fuse/core/runtime_event_instance.gd` 是否存在
2. 在编辑器中点击 "项目 > 工具 > 重新编译脚本"
3. 重启 Godot 编辑器

### 问题 2: 鼠标悬停不触发

**可能原因：**
- 信号未连接
- 目标节点路径错误
- Event 资源未配置

**解决方法：**
1. 检查 Trigger 节点的 Event 资源是否已配置
2. 检查目标节点路径是否正确
3. 查看编辑器输出面板的错误信息

### 问题 3: 状态隔离失败

**可能原因：**
- OnMouseEnter/OnMouseExit 未正确重写 `initialize_with_runtime_instance()`
- RuntimeEventInstance 创建失败

**解决方法：**
1. 检查 `_runtime_instance_ref` 是否为 null
2. 添加调试日志输出 RuntimeEventInstance ID
3. 确认每个 Trigger 都创建了自己的 RuntimeEventInstance

### 问题 4: 向后兼容性问题

**可能原因：**
- BaseEvent 的默认实现有问题
- 旧事件类的方法签名不匹配

**解决方法：**
1. 检查 BaseEvent 的 `initialize_with_runtime_instance()` 实现
2. 确认默认实现调用了 `initialize()`
3. 检查旧事件类的方法签名

---

## 调试技巧

### 启用详细日志

在 Trigger 节点的属性面板中：
- 将 `Log Level` 设置为 `DEBUG`
- 运行场景，查看详细日志

### 检查 RuntimeEventInstance

在脚本中添加调试代码：

```gdscript
# OnMouseEnter._on_mouse_entered_with_context()
func _on_mouse_entered_with_context(owner: Node):
    # 添加调试日志
    if _runtime_instance_ref:
        _log_debug("RuntimeEventInstance ID: %d" % _runtime_instance_ref.get_instance_id())
    else:
        _log_error("RuntimeEventInstance 为空！")
```

### 使用断点调试

1. 在 `initialize_with_runtime_instance()` 方法中设置断点
2. 运行场景（F5）
3. 检查调用堆栈和变量值
4. 确认 `_runtime_instance_ref` 是否正确设置

---

## 测试完成后

### 如果所有测试通过

✅ **恭喜！集成验证成功！**

你可以：
1. 创建验证提交（可选）
2. 进入下一个任务
3. 向团队报告测试结果

### 如果有测试失败

⚠️ **请记录失败信息：**

1. 复制完整的错误日志
2. 记录复现步骤
3. 截图错误界面
4. 向开发团队报告问题

---

## 需要帮助？

如果测试过程中遇到任何问题：

1. 查看详细文档：
   - `addons/fuse/docs/development/task-6-trigger-integration-verification.md`
   - `addons/fuse/docs/development/task-6-final-report.md`

2. 查看代码示例：
   - `addons/fuse/core/trigger.gd`
   - `addons/fuse/events/input/on_mouse_enter.gd`
   - `addons/fuse/events/input/on_mouse_exit.gd`

3. 联系开发团队

---

**祝测试顺利！** 🎉
